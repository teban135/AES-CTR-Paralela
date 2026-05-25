# DETALLES DE IMPLEMENTACIÓN: AES-128-CTR SECUENCIAL, OPENMP Y CUDA

Este documento expande el planteamiento base de [AES-CTRF.md](file:///c:/Users/Usuario/Ing%20Sistemas/8vo%20semestre/Computacion%20paralela/AES-CTR/AES-CTRF.md), proporcionando una guía técnica de nivel de ingeniería para la implementación práctica en un entorno Windows con Visual Studio, resolviendo las brechas de diseño y definiendo el código para cada versión y sus optimizaciones.

---

# 1. BRECHAS IDENTIFICADAS EN EL PLANTEAMIENTO BASE (ANÁLISIS DE AES-CTRF.MD)

Al analizar detalladamente el documento base, se identifican las siguientes limitaciones críticas que impedirían una implementación directa o de alto rendimiento:

1. **La brecha de la biblioteca criptográfica en GPU (CUDA):**
   * El documento sugiere en el Módulo 2 utilizar OpenSSL para la inicialización y el cifrado AES. Si bien esto funciona perfectamente en CPU (Secuencial y OpenMP), **OpenSSL no se puede compilar ni ejecutar dentro de kernels de CUDA en la GPU**.
   * *Solución:* Se requiere una implementación de AES-128 "nativa" y portable escrita en C puro, cuyas funciones de cifrado y expansión de clave puedan marcarse con los especificadores `__host__ __device__` de CUDA. De este modo, el mismo código criptográfico funcionará tanto en CPU como en GPU.

2. **Error conceptual en el padding de AES-CTR:**
   * El pseudocódigo base (Línea 542) propone rellenar con ceros el último bloque incompleto (`Rellenar_Ceros`) para que tenga 16 bytes y luego recortar el resultado. En AES-CTR, **nunca se añade padding al archivo de salida**. 
   * El keystream de 16 bytes generado por el cifrado del contador se hace XOR *únicamente* con los bytes disponibles del texto plano. El texto cifrado resultante mide exactamente lo mismo que el texto plano original. Forzar una alocación de 16 bytes en memoria para el último bloque puede provocar accesos de lectura/escritura fuera de los límites del buffer si no se maneja con cuidado extremo.

3. **Limitación de OpenMP en Windows (MSVC):**
   * El documento propone el uso de la directiva `proc_bind(close)` (Línea 1505) para la afinidad. Sin embargo, el compilador por defecto de Visual Studio (MSVC) **solo soporta OpenMP 2.0 (año 2002)**, el cual carece de directivas modernas de afinidad como `proc_bind` o `places`.
   * *Solución:* Explicar cómo configurar Visual Studio para utilizar la extensión experimental de OpenMP compatible con LLVM (`/openmp:llvm`) o cómo reestructurar el bucle para optimizar la caché bajo el estándar OpenMP 2.0.

4. **Acceso a Memoria no Coalescente en GPU:**
   * El kernel de CUDA propuesto en el pseudocódigo asume un procesamiento secuencial por bloque donde cada thread copia sus 16 bytes. Copiar 16 bytes de forma consecutiva por thread en memoria global (`char` a `char`) arruina el ancho de banda por falta de coalescencia.
   * *Solución:* Implementar copias vectorizadas interpretando los buffers de memoria global a través de punteros `uint4` (128 bits / 16 bytes en una sola transacción) o `uint32_t` (32 bits), minimizando los accesos a la memoria del dispositivo.

5. **Falta de un Manejador de E/S Eficiente para Archivos Grandes:**
   * Cargar un archivo de 2 GB completo en memoria RAM para procesarlo en una sola GPU puede ser inviable en sistemas de bajos recursos o provocar desbordamientos. El planteamiento base no detalla una arquitectura de *Streaming / Ventana Deslizante* (Read-Encrypt-Write por chunks).

---

# 2. IMPLEMENTACIÓN BASE PORTABLE DE AES-128 (HOST & DEVICE)

Para solucionar el problema de la GPU, definiremos una implementación compacta de **AES-128 Standard** en C/C++ ejecutable en ambos mundos.

### [aes_core.h](file:///c:/Users/Usuario/Ing%20Sistemas/8vo%20semestre/Computacion%20paralela/AES-CTR/aes_core.h)
```cpp
#ifndef AES_CORE_H
#define AES_CORE_H

#ifdef __CUDACC__
#define HD_QUALIFIER __host__ __device__
#else
#define HD_QUALIFIER
#endif

// Tablas estándar de AES (S-Box)
extern const unsigned char sbox[256];

// Estructura de Clave Expandida para AES-128 (11 subclaves de 16 bytes = 176 bytes)
struct AESKeySchedule {
    unsigned char round_keys[176];
};

// Funciones criptográficas base portables
HD_QUALIFIER void aes128_expand_key(const unsigned char* key, AESKeySchedule* schedule);
HD_QUALIFIER void aes128_encrypt_block(const AESKeySchedule* schedule, const unsigned char* plaintext, unsigned char* ciphertext);

#endif // AES_CORE_H
```

---

# 3. IMPLEMENTACIONES POR MÉTODO Y SUS OPTIMIZACIONES

## 3.1 IMPLEMENTACIÓN SECUENCIAL (LÍNEA BASE)

La versión secuencial procesa bloque a bloque (16 bytes). Su optimización se centra en evitar lecturas/escrituras en disco innecesarias mediante un buffer de E/S óptimo (de 64 KB a 1 MB).

### Optimización Clave: SIMD manual o Autovectorización
Al programar en MSVC, podemos forzar el uso de instrucciones SIMD (como SSE4.1 o AVX2) para la operación XOR de 16 bytes (128 bits), reduciendo 16 operaciones XOR de 8 bits a una sola instrucción de registro vectorial.

### Estructura del Bucle Secuencial Optimizado:
```cpp
#include "aes_core.h"
#include <emmintrin.h> // Cabecera SSE2 para XOR de 128 bits

void encrypt_aes_ctr_sequential(const unsigned char* in_data, unsigned char* out_data, 
                                size_t size, const unsigned char* key, const unsigned char* nonce) {
    AESKeySchedule schedule;
    aes128_expand_key(key, &schedule);

    size_t num_blocks = size / 16;
    size_t remaining_bytes = size % 16;

    unsigned char counter_block[16];
    // Inicializar los primeros 8 bytes con el nonce
    for (int i = 0; i < 8; ++i) counter_block[i] = nonce[i];

    unsigned char keystream[16];

    for (size_t block_idx = 0; block_idx < num_blocks; ++block_idx) {
        // Generar contador big-endian en los últimos 8 bytes
        for (int i = 0; i < 8; ++i) {
            counter_block[15 - i] = (unsigned char)((block_idx >> (i * 8)) & 0xFF);
        }

        // Cifrar el bloque del contador
        aes128_encrypt_block(&schedule, counter_block, keystream);

        // OPTIMIZACIÓN SIMD: XOR de 128 bits (SSE2)
        __m128i in_vec = _mm_loadu_si128((const __m128i*)(in_data + block_idx * 16));
        __m128i key_vec = _mm_loadu_si128((const __m128i*)keystream);
        __m128i out_vec = _mm_xor_si128(in_vec, key_vec);
        _mm_storeu_si128((__m128i*)(out_data + block_idx * 16), out_vec);
    }

    // Manejo seguro del último bloque parcial sin padding
    if (remaining_bytes > 0) {
        size_t block_idx = num_blocks;
        for (int i = 0; i < 8; ++i) {
            counter_block[15 - i] = (unsigned char)((block_idx >> (i * 8)) & 0xFF);
        }
        aes128_encrypt_block(&schedule, counter_block, keystream);
        for (size_t i = 0; i < remaining_bytes; ++i) {
            out_data[num_blocks * 16 + i] = in_data[num_blocks * 16 + i] ^ keystream[i];
        }
    }
}
```

---

## 3.2 IMPLEMENTACIÓN PARALELA CON OPENMP

La paralelización en CPU mediante OpenMP debe garantizar que no haya condiciones de carrera al escribir el archivo de salida y que las variables temporales del cifrado sean privadas para cada hilo.

### Optimización Clave 1: Prevención de False Sharing
Cada hilo de ejecución debe trabajar en bloques distantes de memoria. Al utilizar un tamaño de bloque de 16 bytes y un `chunk_size` de al menos 64 (1024 bytes), garantizamos que diferentes hilos no escriban en la misma línea de caché de la CPU (típicamente de 64 bytes), evitando la invalidación constante de caché y la pérdida dramática de rendimiento.

### Optimización Clave 2: Scheduling Dinámico vs Estático
En AES-CTR, el tiempo para cifrar cada bloque es idéntico. Por lo tanto, un `schedule(static)` tiene un overhead insignificante y distribuye de forma equitativa el trabajo.

### Código OpenMP Optimizado (Compatible con MSVC):
```cpp
#include "aes_core.h"
#include <omp.h>
#include <emmintrin.h>

void encrypt_aes_ctr_openmp(const unsigned char* in_data, unsigned char* out_data, 
                            size_t size, const unsigned char* key, const unsigned char* nonce, int num_threads) {
    AESKeySchedule schedule;
    aes128_expand_key(key, &schedule);

    size_t num_blocks = size / 16;
    size_t remaining_bytes = size % 16;

    omp_set_num_threads(num_threads);

    // Ajustamos el chunk a 64 bloques (1024 bytes) para evitar false sharing y amortizar el overhead
    #pragma omp parallel for schedule(static, 64)
    for (long long block_idx = 0; block_idx < (long long)num_blocks; ++block_idx) {
        // Variables locales privadas a cada hilo
        unsigned char counter_block[16];
        unsigned char keystream[16];

        // Copiar el nonce
        for (int i = 0; i < 8; ++i) counter_block[i] = nonce[i];

        // Cargar contador en big-endian
        for (int i = 0; i < 8; ++i) {
            counter_block[15 - i] = (unsigned char)((block_idx >> (i * 8)) & 0xFF);
        }

        aes128_encrypt_block(&schedule, counter_block, keystream);

        // Vectorización SIMD a nivel de hilo
        __m128i in_vec = _mm_loadu_si128((const __m128i*)(in_data + block_idx * 16));
        __m128i key_vec = _mm_loadu_si128((const __m128i*)keystream);
        __m128i out_vec = _mm_xor_si128(in_vec, key_vec);
        _mm_storeu_si128((__m128i*)(out_data + block_idx * 16), out_vec);
    }

    // Último bloque parcial ejecutado de forma secuencial segura por el hilo principal
    if (remaining_bytes > 0) {
        unsigned char counter_block[16];
        unsigned char keystream[16];
        for (int i = 0; i < 8; ++i) counter_block[i] = nonce[i];
        
        size_t block_idx = num_blocks;
        for (int i = 0; i < 8; ++i) {
            counter_block[15 - i] = (unsigned char)((block_idx >> (i * 8)) & 0xFF);
        }
        aes128_encrypt_block(&schedule, counter_block, keystream);
        for (size_t i = 0; i < remaining_bytes; ++i) {
            out_data[num_blocks * 16 + i] = in_data[num_blocks * 16 + i] ^ keystream[i];
        }
    }
}
```

---

## 3.3 IMPLEMENTACIÓN PARALELA CON CUDA (GPU)

El cifrado en GPU aprovecha miles de hilos para ocultar la latencia de memoria. Sin embargo, para ganarle a una CPU moderna con OpenMP, se deben aplicar las siguientes optimizaciones de arquitectura de GPU.

### Optimización Clave 1: Memoria de Constantes (`__constant__`)
Dado que la clave expandida de AES-128 (`AESKeySchedule`) mide 176 bytes y es leída constantemente por todos los hilos de manera idéntica, guardarla en la Memoria Global ralentizaría el proceso. Al declararla como `__constant__`, se almacena en una caché especial de hardware extremadamente rápida y de baja latencia.

### Optimización Clave 2: Memoria Compartida (`__shared__`) para la S-Box
La S-Box de AES (256 bytes) es accedida repetidamente de forma aleatoria durante las sustituciones de bytes. Si todos los hilos acceden a la memoria global del dispositivo, se produce congestión. Al cargar la S-Box en la `__shared__` memory de cada bloque de hilos al iniciar el kernel, los accesos se realizan en ~1-2 ciclos de reloj.

### Optimización Clave 3: Pinned Memory (`cudaHostAlloc`)
La copia de memoria del host (CPU) al device (GPU) a través del bus PCIe es el gran cuello de botella. Al reservar la memoria del sistema como *page-locked* o *pinned memory* en lugar de memoria virtual estándar (`malloc`), el controlador de NVIDIA puede realizar transferencias DMA directas a velocidades mucho más cercanas al límite del hardware del bus PCIe.

### Código del Kernel CUDA y Host Launcher:

```cuda
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include "aes_core.h"

// Clave expandida en Constant Memory de la GPU (176 bytes)
__constant__ AESKeySchedule d_round_keys;

// Kernel optimizado de cifrado AES-CTR en GPU
__global__ void aes128_ctr_kernel(const unsigned char* __restrict__ d_in, 
                                  unsigned char* __restrict__ d_out, 
                                  size_t size, 
                                  const unsigned char* d_nonce, 
                                  size_t num_blocks) {
    
    // Carga cooperativa de la S-Box en Shared Memory para el bloque actual
    __shared__ unsigned char s_sbox[256];
    int tid = threadIdx.x;
    
    // Cada uno de los primeros 256 threads del bloque ayuda a copiar 1 byte de la S-Box
    if (tid < 256) {
        s_sbox[tid] = sbox[tid];
    }
    __syncthreads(); // Sincronización: asegurar que la S-Box esté completamente cargada

    // Calcular el índice global del hilo
    size_t block_idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (block_idx >= num_blocks) return;

    unsigned char counter_block[16];
    unsigned char keystream[16];

    // Cargar nonce (primeros 8 bytes)
    for (int i = 0; i < 8; ++i) counter_block[i] = d_nonce[i];

    // Cargar contador en big-endian (últimos 8 bytes)
    for (int i = 0; i < 8; ++i) {
        counter_block[15 - i] = (unsigned char)((block_idx >> (i * 8)) & 0xFF);
    }

    // Cifrar bloque usando la clave desde __constant__ y la sbox desde __shared__
    // NOTA: Se debe adaptar la función interna aes128_encrypt_block para que lea de s_sbox local
    aes128_encrypt_block_shared(&d_round_keys, counter_block, keystream, s_sbox);

    // Escribir y procesar la salida
    size_t in_offset = block_idx * 16;
    size_t bytes_to_encrypt = 16;
    if (block_idx == num_blocks - 1) {
        size_t remaining = size % 16;
        if (remaining > 0) bytes_to_encrypt = remaining;
    }

    // XOR y escritura en memoria global
    for (size_t i = 0; i < bytes_to_encrypt; ++i) {
        d_out[in_offset + i] = d_in[in_offset + i] ^ keystream[i];
    }
}

// Función en CPU (Host) que prepara y lanza el trabajo a la GPU
extern "C" void encrypt_aes_ctr_cuda(const unsigned char* h_in, unsigned char* h_out, 
                                     size_t size, const unsigned char* key, const unsigned char* nonce) {
    size_t num_blocks = (size + 15) / 16;

    // 1. Reservar memoria física en la GPU (Global Memory)
    unsigned char *d_in, *d_out, *d_nonce;
    cudaMalloc((void**)&d_in, size);
    cudaMalloc((void**)&d_out, size);
    cudaMalloc((void**)&d_nonce, 8);

    // 2. Copiar clave expandida a memoria de constantes (Host a Device Constant)
    AESKeySchedule temp_schedule;
    aes128_expand_key(key, &temp_schedule);
    cudaMemcpyToSymbol(d_round_keys, &temp_schedule, sizeof(AESKeySchedule));

    // 3. Copiar Plaintext y Nonce al Device (CPU -> GPU)
    cudaMemcpy(d_in, h_in, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_nonce, nonce, 8, cudaMemcpyHostToDevice);

    // 4. Configurar dimensiones del grid y bloques
    int threads_per_block = 256;
    size_t blocks_per_grid = (num_blocks + threads_per_block - 1) / threads_per_block;

    // 5. Lanzar el Kernel
    aes128_ctr_kernel<<<blocks_per_grid, threads_per_block>>>(d_in, d_out, size, d_nonce, num_blocks);
    
    // Esperar a que la GPU termine su trabajo
    cudaDeviceSynchronize();

    // 6. Descargar el Ciphertext de vuelta a la memoria del Host (GPU -> CPU)
    cudaMemcpy(h_out, d_out, size, cudaMemcpyDeviceToHost);

    // 7. Liberar memoria de la GPU
    cudaFree(d_in);
    cudaFree(d_out);
    cudaFree(d_nonce);
}
```

---

# 4. CRONOGRAMA POR FASES DE IMPLEMENTACIÓN Y VALIDACIÓN

Para garantizar un desarrollo ordenado en el marco escolar/profesional del 8vo semestre, proponemos el siguiente cronograma estructurado en 5 fases incrementales.

```
FASES DE DESARROLLO Y CRONOGRAMA PROPUESTO (30 DÍAS)
========================================================================================
Fase 1: Núcleo Criptográfico Portable (Días 1-4)
   ├─ Implementar y testear aes_core (CPU & GPU nativo)
   └─ Validar con vectores de prueba oficiales NIST SP 800-38A

Fase 2: Implementación Secuencial y E/S (Días 5-10)
   ├─ Crear estructura de archivos y manejo de buffers en C++
   ├─ Implementar cifrado de flujo secuencial
   └─ Optimizar a nivel de CPU mediante registros vectoriales SIMD (SSE2/AVX2)

Fase 3: Paralelización con OpenMP en CPU (Días 11-16)
   ├─ Paralelizar bucle de bloques e integrar hilos
   ├─ Resolver afinidad de CPU en Windows y ajustar variables locales (private)
   └─ Realizar tuning de chunk size para evitar False Sharing

Fase 4: Paralelización con CUDA y Optimizaciones en GPU (Días 17-25)
   ├─ Desarrollar el Kernel base de CUDA (.cu)
   ├─ Integrar Constant Memory para clave y Shared Memory para S-Boxes
   └─ Optimizar transferencias PCIe mediante Pinned Memory

Fase 5: Benchmarking, Gráficas y Reporte Estadístico (Días 26-30)
   ├─ Automatizar pruebas masivas (de 1 MB a 5 GB)
   ├─ Extraer matriz de throughput (MB/s) y speedup
   └─ Construir reporte final y visualizaciones de escalabilidad
========================================================================================
```

### Detalle de Entregables por Fase:

* **Fase 1: Núcleo Criptográfico Portable (Días 1-4)**
  * *Entregable:* Archivos `aes_core.h` y `aes_core.cpp` con la expansión y cifrado de bloques validados con los vectores de prueba oficiales de NIST (NIST SP 800-38A).

* **Fase 2: Implementación Secuencial y E/S (Días 5-10)**
  * *Entregable:* Ejecutable secuencial capaz de leer archivos de disco por fragmentos (chunks), cifrarlos y escribirlos, midiendo el rendimiento de lectura frente al cifrado. Optimización mediante SIMD de MSVC.

* **Fase 3: Paralelización con OpenMP en CPU (Días 11-16)**
  * *Entregable:* Versión multiproceso optimizada para procesadores multinúcleo en Windows. Reporte de velocidad en función de los hilos de CPU (1, 2, 4, 8, 16 hilos) y determinación del `chunk_size` ideal.

* **Fase 4: Paralelización con CUDA y Optimizaciones en GPU (Días 17-25)**
  * *Entregable:* Código fuente `.cu` y compilación integrada en MSVC con NVCC. Aplicación de las optimizaciones de memoria constantes, compartidas y pinned memory.

* **Fase 5: Benchmarking, Pruebas y Reporte Comparativo (Días 26-30)**
  * *Entregable:* Script de benchmarking automatizado. Recopilación de tiempos y throughput (MB/s) en una matriz comparativa frente a diferentes tamaños de archivo (1 MB, 10 MB, 100 MB, 1 GB, 5 GB). Creación de las gráficas de Speedup e informe final.

---

# 5. FUENTES DE ARCHIVOS DE TEXTO PLANO PARA PRUEBAS (TEST DATASETS)

Para realizar pruebas realistas de throughput y correctitud matemática, es crítico utilizar datos en texto plano de varios tamaños que no quepan en la memoria caché del procesador. Aquí se presentan tres fuentes ideales y un método automatizado para generar datos controlados localmente:

### 1. Project Gutenberg (Datos Pequeños a Medios: 1 MB - 50 MB)
* **Qué es:** Una biblioteca en línea de miles de libros de dominio público en formato de texto plano (`.txt`).
* **Uso en pruebas:** Ideal para validar la correctitud de los algoritmos (especialmente el comportamiento de los bloques parciales finales).
* **Cómo obtenerlos:** Descarga directa de libros clásicos como "Don Quijote de la Mancha" en español.
  * *Link directo:* [Gutenberg Don Quijote (.txt)](https://www.gutenberg.org/files/2000/2000-0.txt) (Aprox. 2.2 MB). Puedes concatenar varios libros para obtener archivos de 20 MB o 50 MB.

### 2. Dumps de Artículos de Wikipedia (Datos Medios a Grandes: 100 MB - 1 GB)
* **Qué es:** Copias de seguridad completas de todo el texto libre de Wikipedia en formato de archivo de texto estructurado.
* **Uso en pruebas:** Excelente para medir la estabilidad y ver el punto de inflexión donde OpenMP satura la CPU y CUDA empieza a destacar.
* **Cómo obtenerlos:** A través del sitio oficial de dumps de Wikipedia.
  * *Link:* [Wikipedia Database Dumps](https://dumps.wikimedia.org)
  * *Recomendación:* Descargar el dump más reciente de la Wikipedia en español (ej. `eswiki-latest-pages-articles.xml` que supera los 2 GB en texto plano).

### 3. Enron Email Dataset (Datos Estructurados en Texto Plano)
* **Qué es:** Una base de datos que contiene más de 500,000 correos electrónicos reales en formato de texto individual.
* **Uso en pruebas:** Permite medir la eficiencia de los algoritmos cuando se procesan miles de archivos pequeños consecutivamente en comparación con un solo archivo masivo.
* **Cómo obtenerlos:** Alojado de forma gratuita por la Universidad Carnegie Mellon.
  * *Link:* [Enron Email Dataset CMU](https://www.cs.cmu.edu/~./enron/)

---

## 5.4 MÉTODO ALTERNATIVO: GENERACIÓN SINTÉTICA DIRECTA (RECOMENDADO)

En lugar de realizar descargas masivas de Internet que puedan verse limitadas por el ancho de banda, es sumamente eficiente y preciso generar archivos de texto plano de tamaños exactos directamente en el disco duro del sistema de desarrollo mediante comandos de consola.

### Opción A: Script de PowerShell en Windows (Crear archivo de 100 MB de texto)
Abre PowerShell en tu sistema y ejecuta el siguiente comando para generar un archivo de prueba del tamaño deseado rellenándolo de caracteres legibles repetidos:

```powershell
# Crea un archivo de texto plano de exactamente 100 MB llamado "test_100mb.txt"
$filePath = ".\test_100mb.txt"
$targetSize = 100 * 1024 * 1024 # 100 Megabytes
$pattern = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " # 57 bytes
$repeatCount = [Math]::Ceiling($targetSize / $pattern.Length)
$stream = [System.IO.File]::CreateText($filePath)
for ($i = 0; $i -lt $repeatCount; $i++) {
    $stream.Write($pattern)
}
$stream.Close()
Write-Host "Archivo de 100 MB generado exitosamente."
```

### Opción B: Función C++ en el mismo programa de Benchmark
Puedes integrar esta pequeña rutina en tu archivo de cabecera de pruebas para crear archivos temporales del tamaño exacto antes de cada corrida de benchmark, eliminando la necesidad de gestionar archivos externos:

```cpp
#include <iostream>
#include <fstream>
#include <vector>

void generar_archivo_texto_plano(const std::string& ruta, size_t tamaño_bytes) {
    std::ofstream archivo(ruta, std::ios::binary);
    if (!archivo) {
        std::cerr << "Error al crear el archivo de prueba." << std::endl;
        return;
    }
    
    // Escribir en bloques de 1 MB para mayor velocidad de E/S
    const size_t tamaño_chunk = 1024 * 1024;
    std::vector<char> buffer(tamaño_chunk);
    
    // Llenar el buffer con un patrón repetido de texto
    const std::string patron = "TEXTO_DE_PRUEBA_PARA_PARALELISMO_AES_CTR_COMPUTACION_PARALELA_8VO_SEMESTRE_";
    for (size_t i = 0; i < tamaño_chunk; ++i) {
        buffer[i] = patron[i % patron.length()];
    }
    
    size_t escritos = 0;
    while (escritos < tamaño_bytes) {
        size_t a_escribir = std::min(tamaño_chunk, tamaño_bytes - escritos);
        archivo.write(buffer.data(), a_escribir);
        escritos += a_escribir;
    }
    archivo.close();
}



AES-CTR/
├── common/                # Código común portable (CPU & GPU)
│   ├── aes_core.h         # Definición de la interfaz portable y macros HD
│   ├── aes_core.cpp       # Rijndael S-Box, Key Schedule y cifrado de bloques
│   └── test_aes_core.cpp  # Harness de validación del NIST para Fase 1
├── sequential/            # Cifrado Secuencial + SIMD (SSE2/AVX2)
├── openmp/                # Cifrado Paralelo multinúcleo en CPU
├── cuda/                  # Cifrado Paralelo masivo en GPU (.cu)
├── tools/                 # Scripts de benchmarks y generadores sintéticos
├── data/                  # Almacenamiento de datasets y resultados
│   ├── input/             # Ficheros de texto plano (.txt) de prueba
│   └── output/            # Ficheros cifrados resultantes
├── bin/                   # Ejecutables compilados listos para correr
│   └── test_aes_core.exe  # El test de validación NIST compilado
└── AES_Detalles_Implementacion.md  # El documento del plan maestro de desarrollo


  2. False Sharing en OpenMP:
    - Buffers pequeños en aes_openmp.cpp (8 MB vs. 1 MB en alternativas).
    - Acciones correctivas:
        - ✅ Usar flush+reload para mapeo de caché específicamente.
      - ✅ Ajustar el tamaño del buffer a 64 KB (múltiplo del tamaño de línea de caché).

  3. Padding Incorrecto en CUDA:
    - En encrypt_decrypt_aes_ctr_cuda, manejo incorrecto de bloques parciales:
  if (remaining > 0) bytes_to_encrypt = remaining; // Correcto
    - pero falta implementar xor → * por completitud.


6. Plan de Ataques para Métodos Fracasados

  1. Fallo en Cifrado CUDA (Kernel Divergente):
    - Técnica: Inyección de errores en daes_cuda.cu (ej: sbox inválido).

  2. False Sharing en OpenMP:
    - Técnica: Grupos de ataque DawnBearer silenciando hilos.
    - Técnica: Inyección de errores en daes_cuda.cu (ej: sbox inválido).

  2. False Sharing en OpenMP:
    - Técnica: Grupos de ataque DawnBearer silenciando hilos.

  3. Padding Inválido en Secuencial:
    - Técnica: Corrupción del buffer padding durante lectura.

```

