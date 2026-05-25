# Cifrador Masivo Paralelo AES-128-CTR (CPU vs GPU)

Este proyecto implementa y compara tres paradigmas de computación de alto rendimiento para el cifrado y descifrado de archivos de gran tamaño (desde megabytes hasta gigabytes) mediante el algoritmo **AES-128 en modo CTR (Counter)**:
1. **Secuencial (CPU)**: Optimizado con intrínsecos de hardware **SIMD SSE2 (128 bits)** a nivel de registro.
2. **OpenMP (CPU Multihilo)**: Amortización de hilos mediante buffers alineados en caché de 8 MB y vectorización paralela SSE2.
3. **CUDA (GPU)**: Kernel masivamente paralelo con optimizaciones de **Shared Memory** y buffers **Host-Pinned (Page-Locked)** para máximo ancho de banda PCIe.

---

## ⚙️ Estructura de Parámetros Común

Las tres implementaciones comparten la misma firma de ejecución desde la consola. La sintaxis exacta es:

```powershell
./bin/<ejecutable>.exe <archivo_entrada> <archivo_salida> <clave_hex> <nonce_hex> [argumentos_opcionales]
```

### 📋 Explicación de los Parámetros:
* **`<archivo_entrada>`**: La ruta de cualquier archivo que desees procesar (por ejemplo: `data/input/test_10mb.txt`). **¡Soporta cualquier formato (.txt, .bin, .pdf, .png, .mp4)!** Debido a que el modo CTR no requiere relleno (*No Padding*), el archivo cifrado y descifrado conservará exactamente el mismo tamaño en bytes.
* **`<archivo_salida>`**: La ruta donde se escribirá el archivo resultante.
* **`<clave_hex>`**: Exactamente **32 caracteres hexadecimales** que representan la clave simétrica de 128 bits (16 bytes). Ejemplo: `000102030405060708090a0b0c0d0e0f`.
* **`<nonce_hex>`**: Exactamente **16 caracteres hexadecimales** que representan el vector de inicialización/contador base de 64 bits (8 bytes). Ejemplo: `0123456789abcdef`.
* **`[num_hilos]`** *(Sólo para OpenMP)*: Parámetro opcional para forzar el número de hilos lógicos en la CPU. Si se omite, el sistema utilizará el máximo disponible en el hardware.

> [!IMPORTANT]
> **Naturaleza Simétrica de AES-CTR (Cifrado == Descifrado)**:
> En el modo CTR, el algoritmo cifra un contador secuencial para generar un keystream y luego realiza una operación `XOR` bit a bit con los datos. Por lo tanto, **el descifrado se realiza ejecutando exactamente el mismo comando** con la misma clave y nonce; solo debes intercambiar las rutas de los archivos de entrada y salida.

---

## 🚀 Guía de Compilación y Ejecución Manual

### 1. Versión Secuencial (CPU con SSE2)
* **Compilación (g++):**
  ```powershell
  g++ -O3 -o bin/aes_seq.exe sequential/main_seq.cpp sequential/aes_sequential.cpp common/aes_core.cpp
  ```
* **Ejecución (Cifrar):**
  ```powershell
  ./bin/aes_seq.exe data/input/test_10mb.txt data/output/encrypted_seq.bin 000102030405060708090a0b0c0d0e0f 0123456789abcdef
  ```
* **Ejecución (Descifrar):**
  ```powershell
  ./bin/aes_seq.exe data/output/encrypted_seq.bin data/output/decrypted_seq.txt 000102030405060708090a0b0c0d0e0f 0123456789abcdef
  ```

---

### 2. Versión OpenMP (CPU Multihilo + SIMD)
* **Compilación (g++):**
  ```powershell
  g++ -O3 -fopenmp -o bin/aes_omp.exe openmp/main_omp.cpp openmp/aes_openmp.cpp common/aes_core.cpp
  ```
* **Ejecución (Cifrar usando 8 hilos):**
  ```powershell
  ./bin/aes_omp.exe data/input/test_10mb.txt data/output/encrypted_omp.bin 000102030405060708090a0b0c0d0e0f 0123456789abcdef 8
  ```
* **Ejecución (Descifrar):**
  ```powershell
  ./bin/aes_omp.exe data/output/encrypted_omp.bin data/output/decrypted_omp.txt 000102030405060708090a0b0c0d0e0f 0123456789abcdef 8
  ```

---

### 3. Versión CUDA (GPU Acelerada)
* **Compilación (nvcc):**
  ```powershell
  nvcc -O3 -o bin/aes_cuda.exe cuda/main_cuda.cu cuda/aes_cuda.cu
  ```
* **Ejecución (Cifrar masivo en GPU):**
  ```powershell
  ./bin/aes_cuda.exe data/input/test_10mb.txt data/output/encrypted_cuda.bin 000102030405060708090a0b0c0d0e0f 0123456789abcdef
  ```
* **Ejecución (Descifrar):**
  ```powershell
  
  ```

---

## 📂 ¿Cómo probar con un archivo propio personalizado?

Si deseas procesar un archivo de texto o binario propio que no sea de los generados sintéticamente, solo debes pasar su **ruta absoluta o relativa** en el primer parámetro de la línea de comandos.

### Ejemplo Práctico Paso a Paso:
Supongamos que tienes un PDF pesado o un documento de texto personalizado en tu computadora en la ruta `C:\MisDocumentos\proyecto_final.pdf`. 

#### 🔐 Paso 1: Cifrarlo usando CUDA (GPU)
Utilizaremos una clave y un nonce personalizados de prueba:
```powershell
./bin/aes_cuda.exe "C:\MisDocumentos\proyecto_final.pdf" "C:\MisDocumentos\proyecto_final_CIFRADO.bin" aabbccddeeff00112233445566778899 0011223344556677
```
* **Resultado:** Se generará un archivo `proyecto_final_CIFRADO.bin` completamente ilegible con exactamente el mismo tamaño que el original.

#### 🔓 Paso 2: Descifrarlo de vuelta (mismos parámetros)
Para recuperar tu archivo PDF original intacto:
```powershell
./bin/aes_cuda.exe "C:\MisDocumentos\proyecto_final_CIFRADO.bin" "C:\MisDocumentos\proyecto_final_RECUPERADO.pdf" aabbccddeeff00112233445566778899 0011223344556677
```
* **Resultado:** `proyecto_final_RECUPERADO.pdf` es idéntico byte a byte a tu archivo original.

---

## ⚖️ Comparación Justa y Métricas de Cómputo Netas (CPU vs GPU)

Para realizar un análisis de rendimiento computacional académicamente riguroso, tanto la versión **OpenMP** como la versión **CUDA** reportan por separado sus métricas de cómputo neto:
1. **Tiempo total (E/S)**: Tiempo de extremo a extremo que incluye la apertura de archivos, la lectura de disco, la inicialización del hardware, el cómputo del cifrado, la transferencia de datos y la escritura en disco.
2. **Tiempo de Cómputo Neto**: Tiempo absoluto en el que los núcleos de procesamiento (CPU o GPU) están calculando activamente el algoritmo AES (medido envolviendo únicamente el bucle paralelo `omp parallel for` o el kernel de CUDA con sincronización).

### Ejemplo real comparando 1.03 GB (1,036 MB) en tu hardware:
* **En CPU Multihilo (OpenMP - 16 Hilos)**:
  - **Tiempo Total (con E/S)**: `1.73 segundos` (Throughput: `597.6 MB/s`)
  - **Tiempo CPU Neto (Cómputo)**: `963.59 milisegundos` (Throughput: **`1,075.4 MB/s`** o **1.07 GB/s**)

* **En GPU Acelerada (CUDA - RTX 5060)**:
  - **Tiempo Total (con E/S y PCIe)**: `1.64 segundos` (Throughput: `628.6 MB/s`)
  - **Tiempo GPU Neto (Cómputo)**: `34.19 milisegundos` (Throughput: **¡30,305.6 MB/s!** o **30.3 GB/s**)

### 🔬 Conclusiones Científicas Clave:
* **¡La GPU es 28 veces más rápida que 16 hilos de CPU!** Si restamos la E/S de disco y los cuellos de botella de hardware, la GPU procesa los datos en **34 ms** frente a los **963 ms** del CPU multihilo.
* **El cuello de botella PCIe y de Almacenamiento**: Aunque la GPU calcula a una velocidad colosal de **30 GB/s**, el tiempo de extremo a extremo en ambas versiones es muy cercano (~1.6s - 1.7s) debido a que la velocidad de lectura y escritura en el almacenamiento local en disco domina el flujo.


---

## ⚡ Suite de Benchmarking Automatizada

Para ejecutar todas las versiones en una sola pasada y comparar su rendimiento en megabytes por segundo (MB/s) sobre tu hardware, puedes ejecutar nuestro script automatizado en PowerShell:

```powershell
powershell -File .\run_benchmarks.ps1
```

Este script compilará lo que falte, correrá las pruebas en los archivos de 10 MB y 100 MB, e imprimirá una tabla comparativa impecable, además de guardar un reporte en `data/output/benchmark_report.md`.

