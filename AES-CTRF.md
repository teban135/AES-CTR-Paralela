#  GUÍA COMPLETA: AES-CTR CIFRADO SIMÉTRICO
## De la teoría fundamental a la paralelización en GPU

**Nivel:** Intermedio | **Público:** Sin conocimiento criptográfico | **Duración:** 12-20 horas | **Plataforma:** Windows + Visual Studio

---

#  TABLA DE CONTENIDOS

1. **MÓDULO 0:** Fundamentos para profanos
2. **MÓDULO 1:** Criptografía y matemáticas de AES-CTR
3. **MÓDULO 2:** Implementación secuencial (pseudocódigo)
4. **MÓDULO 3:** Paralelización con OpenMP
5. **MÓDULO 4:** Paralelización con CUDA
6. **MÓDULO 5:** Optimizaciones por nivel
7. **MÓDULO 6:** Benchmarking, validación y análisis

---

---

# MÓDULO 0: FUNDAMENTOS PARA PROFANOS

##  Objetivo
Entender **conceptos básicos de criptografía** sin necesidad de formación matemática previa.

---

## 0.1 ¿QUÉ ES CRIPTOGRAFÍA? (ANALOGÍA DEL MUNDO REAL)

### Escenario: Enviar un mensaje secreto

**Sin cifrado (inseguro):**
```
Tu amigo: "Hola, me duele la cabeza"
↓ (Cualquiera puede leer)
Correo postal: Carta abierta
↓
Compañero en autobús: Lee el contenido
```

**Con cifrado (seguro):**
```
Tu amigo: "Hola, me duele la cabeza"
↓ (Transformación secreta)
Máquina de cifrado: "A7F3K9M2Q1R8"
↓ (Nadie entiende)
Correo postal: Carta incomprensible
↓
Compañero en autobús: Ve "A7F3K9M2Q1R8", no entiende nada
↓
Tu amigo recibe: "A7F3K9M2Q1R8"
↓
Máquina de descifrado: "Hola, me duele la cabeza"
↓
Tu amigo: Lee el mensaje original
```

**Idea clave:** La transformación es reversible solo con una **clave secreta**.

---

## 0.2 CONCEPTOS FUNDAMENTALES

| Término | Significado Simple | Ejemplo |
|---------|-------------------|---------|
| **Texto plano** | Información original que entienden todos | "Voy al banco" |
| **Texto cifrado** | Información transformada, ilegible | "K9F2M7Q1X3" |
| **Clave** | Contraseña secreta para cifrar/descifrar | "Password123" |
| **Algoritmo** | Conjunto de reglas matemáticas | AES (Advanced Encryption Standard) |
| **Cifrado simétrico** | Misma clave para cifrar y descifrar | Candado: misma llave abre y cierra |
| **Bloque** | Fragmento de datos procesado de una vez | 16 bytes (128 bits) para AES |

---

## 0.3 XOR: LA OPERACIÓN MÁGICA (SIN MATEMÁTICA COMPLEJA)

### ¿Qué es XOR?

Es una operación que compara **dos bits**:

```
Regla simple (piensa en "diferente"):
  0 XOR 0 = 0  (iguales → 0)
  0 XOR 1 = 1  (diferentes → 1)
  1 XOR 0 = 1  (diferentes → 1)
  1 XOR 1 = 0  (iguales → 0)
```

### Propiedad mágica de XOR:

```
Si:  A XOR B = C
Entonces: C XOR B = A
```

**Ejemplo práctico:**

```
Mis datos:        0101 1010
Mi clave:         1100 0011
─────────────────────────────
Datos cifrados:   1001 1001  (resultado de XOR)

Ahora, para descifrar:
Datos cifrados:   1001 1001
Mi clave:         1100 0011
─────────────────────────────
Datos originales: 0101 1010  (¡recuperados!)
```

**Analogía:** Es como un espejo mágico. Si XOR tu espejo y ves algo raro, XOR de nuevo con el espejo y ves la realidad original.

---

## 0.4 ¿POR QUÉ USAR AES-CTR?

| Característica | Beneficio | Comparación |
|---|---|---|
| **Paralelizable** | Cada dato se cifra independiente | Vs ECB: cada bloque necesita el anterior |
| **Rápido** | Ideal para grandes volúmenes | Vs DES: 8x más lento |
| **Streaming** | Puedes cifrar mientras recibes datos | Ideal para video, audio, descargas |
| **Hardware** | Procesadores modernos lo aceleran | AES-NI en Intel/AMD |

---

## 0.5 ANALOGÍA: FÁBRICA DE CIFRADO

Imagina una fábrica con este flujo:

```
ENTRADA: Datos legibles
   ↓
MÁQUINA 1: Generador de números pseudoaleatorios
   • Usa: Clave secreta + Contador
   • Produce: Secuencia de números "aleatorios"
   ↓
MÁQUINA 2: Operación XOR
   • Entrada 1: Datos originales
   • Entrada 2: Números "aleatorios"
   • Salida: Datos cifrados
   ↓
SALIDA: Datos cifrados
```

**Observación:** Si ejecutas MÁQUINA 1 con los mismos parámetros (clave + contador) obtienes los mismos números "aleatorios". Así funciona el descifrado.

---

---

# MÓDULO 1: CRIPTOGRAFÍA Y MATEMÁTICAS DE AES-CTR

## 🎯 Objetivo
Entender **cómo funciona AES-CTR a nivel matemático** con complejidad intermedia-alta.

---

## 1.1 ¿QUÉ ES AES?

**AES** = *Advanced Encryption Standard*

### Características técnicas:

```
Función: E(K, P) → C
  Donde:
    K = Clave (128, 192 o 256 bits)
    P = Plaintext (16 bytes)
    C = Ciphertext (16 bytes)
    
Propiedad: E es una permutación pseudoaleatoria
           E es invertible: E⁻¹(K, C) → P
           Resistente a criptoanálisis
```

### ¿Por qué AES es seguro?

AES usa **4 transformaciones matemáticas complejas**:

1. **SubBytes** - Sustitución no lineal (S-box)
   ```
   Entrada:  1 byte
   Salida:   1 byte cifrado
   Efecto:   Confunde la entrada
   ```

2. **ShiftRows** - Permutación de filas
   ```
   Rota filas del bloque de forma específica
   Efecto:   Difunde los bits
   ```

3. **MixColumns** - Multiplicación en GF(2⁸)
   ```
   Multiplica columnas en campo finito Galois(256)
   Efecto:   Dispersa información
   ```

4. **AddRoundKey** - XOR con clave derivada
   ```
   XOR(bloque, clave_ronda) 
   Efecto:   Introduce la clave
   ```

Estas 4 transformaciones se repiten **10, 12 o 14 veces** (rounds) según tamaño de clave.

---

## 1.2 CTR MODE: CONTADOR

### ¿Qué es Counter Mode?

**Convierte AES de un cipher de bloque en un stream cipher.**

```
Antes (ECB/CBC - block cipher):
  Entrada:     bloque_1, bloque_2, bloque_3
  Proceso:     AES(bloque_i)
  Dependencia: bloque_{i} depende de bloque_{i-1}
  Paralelizar: NO se puede (secuencial)

Después (CTR - stream cipher):
  Entrada:     bloque_1, bloque_2, bloque_3
  Proceso:     AES(nonce + contador_i)
  Dependencia: Ninguna (completamente independiente)
  Paralelizar: SÍ se puede (paralelo perfecto)
```

---

## 1.3 ESTRUCTURA MATEMÁTICA DE AES-CTR

### Definición formal:

```
C[i] = P[i] ⊕ E(K, N ∥ i)

Donde:
  C[i]      = i-ésimo bloque de ciphertext
  P[i]      = i-ésimo bloque de plaintext
  E(K, x)   = AES con clave K y entrada x
  N         = Nonce (número único, 64-128 bits)
  i         = Contador (incrementa cada bloque)
  ⊕         = Operación XOR
  ∥         = Concatenación
```

### Ejemplo concreto (primeros 3 bloques):

```
Parámetros:
  K     = 128 bits = 0x0F0E0D0C0B0A09080706050403020100
  N     = 64 bits  = 0x0123456789ABCDEF
  P[0]  = 0x4865_6C6C_6F20_576F (equivalente: "Hello Wo")
  P[1]  = 0x726C_6421_0000_0000 (equivalente: "rld!...")
  P[2]  = 0x0000_0000_0000_0000

Paso 1: Construir contadores
  Counter[0] = N ∥ 0  = 0x0123456789ABCDEF 0000000000000000
  Counter[1] = N ∥ 1  = 0x0123456789ABCDEF 0000000000000001
  Counter[2] = N ∥ 2  = 0x0123456789ABCDEF 0000000000000002

Paso 2: Cifrar contadores
  KS[0] = AES(K, Counter[0]) = 0x8A9C_5B3F_2E1D_7C4B_9F2A_3E5C_1B8D_6A4F
  KS[1] = AES(K, Counter[1]) = 0xF1E2_3D4C_5B6A_7988_0C1A_2B3E_4D5C_6B7A
  KS[2] = AES(K, Counter[2]) = 0xA5B4_C3D2_E1F0_8796_5C4B_3A29_1807_F6E5

Paso 3: XOR
  C[0] = P[0] ⊕ KS[0] = 0x4865_6C6C_6F20_576F ⊕ 0x8A9C_5B3F_2E1D_7C4B
       = 0xC2F9_1753_41FD_2B24
  C[1] = P[1] ⊕ KS[1] = 0x726C_6421_0000_0000 ⊕ 0xF1E2_3D4C_5B6A_7988
       = 0x838E_580D_5B6A_7988
  C[2] = P[2] ⊕ KS[2] = 0x0000_0000_0000_0000 ⊕ 0xA5B4_C3D2_E1F0_8796
       = 0xA5B4_C3D2_E1F0_8796
```

---

## 1.4 PROPIEDADES CRÍTICAS DE AES-CTR

### ✅ Seguridad (Si se usa correctamente):
- El nonce NUNCA debe repetirse con la misma clave
- Si N ∥ i se repite: `C ⊕ C' = P ⊕ P'` (revela información)
- Por eso: **cada mensaje necesita nonce único**

### ✅ Simetría cifrado/descifrado:
```
Descifrado = Cifrado (matemáticamente)

P[i] = C[i] ⊕ E(K, N ∥ i)  (mismo cálculo que cifrado)

Porque: A ⊕ B ⊕ B = A
```

### ✅ Paralelizable:
```
C[0] = P[0] ⊕ E(K, N ∥ 0)  ← Thread 0
C[1] = P[1] ⊕ E(K, N ∥ 1)  ← Thread 1
C[2] = P[2] ⊕ E(K, N ∥ 2)  ← Thread 2
...

Sin dependencias entre bloques (ideal para GPU)
```

---

## 1.5 AMENAZAS QUE MITIGA

| Amenaza | Explicación | Mitigación |
|---------|-------------|-----------|
| **Lectura pasiva** | Atacante captura datos en tránsito | ✅ Cifrado, atacante ve basura |
| **Espionaje de tráfico** | Análisis de patrones de comunicación | ✅ XOR pseudoaleatorio oculta patrones |
| **Robo de información en reposo** | Disco duro robado | ✅ Datos en disco son ilegibles |
| **Modificación de clave** | Reutilizar nonce | ❌ **CRÍTICO:** Rompe seguridad |
| **Integridad de datos** | Modificación de bits sin detección | ❌ AES-CTR no detecta cambios (usar GCM) |

---

## 1.6 COMPLEJIDAD MATEMÁTICA

### Complejidad temporal de AES:
```
E(K, x) = O(1)  (constante, bloque fijo de 128 bits)
```

### Complejidad temporal de AES-CTR:
```
Para m bloques:

Secuencial:
  T_seq = m × O(1) = O(m)

Paralelo (ilimitado):
  T_par = O(1)  (todos los bloques en paralelo)
  
Speedup ideal:
  S = T_seq / T_par = m
```

### Complejidad espacial:
```
Por bloque:
  Memoria = O(16) bytes plaintext + O(16) bytes keystream
  
Total para m bloques:
  O(m) bytes
```

---

---

# MÓDULO 2: IMPLEMENTACIÓN SECUENCIAL (PSEUDOCÓDIGO)

## 🎯 Objetivo
Escribir **pseudocódigo detallado** que sea fundación para C++, OpenMP y CUDA.

---

## 2.1 ESTRUCTURA DE DATOS

### Definiciones básicas:

```pseudocode
TIPOS:
  Byte         = Entero de 8 bits (0-255)
  Block        = Array de 16 bytes (128 bits)
  Nonce        = Array de 8 bytes (64 bits)
  Key          = Array de 16/24/32 bytes (128/192/256 bits)
  AESContext   = Estructura que contiene:
                   - Clave AES expandida
                   - Tablas de sustitución (S-boxes)
                   - Constantes de rondas

CONSTANTES:
  BLOCK_SIZE   = 16  (bytes)
  NONCE_SIZE   = 8   (bytes)
  KEY_SIZE     = 16  (bytes, para AES-128)
  ROUNDS       = 10  (para AES-128)
```

---

## 2.2 FUNCIONES AUXILIARES

### 2.2.1 Función para generar contador

```pseudocode
FUNCIÓN GenerarContador(nonce, contador_número)
  ENTRADA: 
    nonce          : Array de 8 bytes
    contador_número: Entero (0, 1, 2, ...)
  SALIDA: 
    counter        : Block (16 bytes)
  
  ALGORITMO:
    counter ← Array vacío de 16 bytes
    
    // Primeros 8 bytes = nonce
    PARA i = 0 HASTA 7 HACER
      counter[i] ← nonce[i]
    FIN PARA
    
    // Últimos 8 bytes = contador en big-endian
    counter[8]  ← (contador_número >> 56) & 0xFF
    counter[9]  ← (contador_número >> 48) & 0xFF
    counter[10] ← (contador_número >> 40) & 0xFF
    counter[11] ← (contador_número >> 32) & 0xFF
    counter[12] ← (contador_número >> 24) & 0xFF
    counter[13] ← (contador_número >> 16) & 0xFF
    counter[14] ← (contador_número >> 8)  & 0xFF
    counter[15] ← contador_número & 0xFF
    
    RETORNA counter
FIN FUNCIÓN
```

**Ejemplo visual:**
```
Nonce:          [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
Contador_número: 42 = 0x000000000000002A

Resultado:
[0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A]
```

---

### 2.2.2 Función XOR de bloques

```pseudocode
FUNCIÓN XORBloque(bloque_a, bloque_b)
  ENTRADA:
    bloque_a: Block (16 bytes)
    bloque_b: Block (16 bytes)
  SALIDA:
    resultado: Block (16 bytes)
  
  ALGORITMO:
    resultado ← Array de 16 bytes
    
    PARA i = 0 HASTA 15 HACER
      resultado[i] ← bloque_a[i] XOR bloque_b[i]
    FIN PARA
    
    RETORNA resultado
FIN FUNCIÓN
```

**Ejemplo numérico:**
```
Bloque A: [0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F, ...]
Bloque B: [0x8A, 0x9C, 0x5B, 0x3F, 0x2E, 0x1D, 0x7C, 0x4B, ...]

XOR bytewise:
  0x48 XOR 0x8A = 0xC2
  0x65 XOR 0x9C = 0xF9
  0x6C XOR 0x5B = 0x17
  ...

Resultado: [0xC2, 0xF9, 0x17, 0x53, 0x41, 0xFD, 0x2B, 0x24, ...]
```

---

### 2.2.3 Inicialización de contexto AES

```pseudocode
FUNCIÓN InicializarAES(clave)
  ENTRADA:
    clave: Array de 16 bytes (128 bits)
  SALIDA:
    contexto: AESContext
  
  ALGORITMO:
    contexto ← Nueva AESContext()
    
    // Expansión de clave (Key Schedule)
    // Esto genera 11 sub-claves a partir de la clave original
    // Cada sub-clave tiene 16 bytes
    
    contexto.sub_claves ← ExpansionDeClaves(clave)
    
    // Tablas de sustitución (S-boxes)
    // Tablas precalculadas para SubBytes transformation
    contexto.s_boxes ← CargarSBoxes()
    
    RETORNA contexto
FIN FUNCIÓN

FUNCIÓN ExpansionDeClaves(clave)
  // Esta función es compleja, la explicamos después
  // Por ahora, asumir que genera 11 sub-claves
  // NOTA: En práctica, usar OpenSSL, no implementar
  ...
FIN FUNCIÓN
```

---

## 2.3 CIFRADO SECUENCIAL

### 2.3.1 Función principal de cifrado

```pseudocode
FUNCIÓN CifrarAES_CTR(plaintext, clave, nonce)
  ENTRADA:
    plaintext: Array de N bytes (mensaje original)
    clave:     Array de 16 bytes
    nonce:     Array de 8 bytes
  SALIDA:
    ciphertext: Array de N bytes (mensaje cifrado)
  
  ALGORITMO:
    // Paso 1: Inicializar contexto AES
    contexto_aes ← InicializarAES(clave)
    
    // Paso 2: Calcular número de bloques
    numero_bloques ← CEIL(LONGITUD(plaintext) / BLOCK_SIZE)
    
    // Paso 3: Crear array para ciphertext
    ciphertext ← Array de LONGITUD(plaintext) bytes
    
    // Paso 4: Procesar cada bloque
    PARA bloque_idx = 0 HASTA numero_bloques - 1 HACER
      
      // Paso 4.1: Generar contador
      contador ← GenerarContador(nonce, bloque_idx)
      
      // Paso 4.2: Cifrar contador con AES
      keystream ← AES_Encrypt(contexto_aes, contador)
      
      // Paso 4.3: Extraer plaintext del bloque actual
      inicio ← bloque_idx * BLOCK_SIZE
      fin    ← MIN(inicio + BLOCK_SIZE, LONGITUD(plaintext))
      tamaño_bloque ← fin - inicio
      
      plaintext_bloque ← plaintext[inicio:fin]
      
      // Paso 4.4: Rellenar con ceros si es último bloque incompleto
      SI tamaño_bloque < BLOCK_SIZE ENTONCES
        plaintext_bloque ← Rellenar_Ceros(plaintext_bloque, BLOCK_SIZE)
      FIN SI
      
      // Paso 4.5: XOR
      ciphertext_bloque ← XORBloque(plaintext_bloque, keystream)
      
      // Paso 4.6: Guardar en resultado
      ciphertext[inicio:fin] ← ciphertext_bloque[0:tamaño_bloque]
    
    FIN PARA
    
    RETORNA ciphertext
FIN FUNCIÓN
```

---

### 2.3.2 Función de desencriptación

```pseudocode
FUNCIÓN DescifrarAES_CTR(ciphertext, clave, nonce)
  ENTRADA:
    ciphertext: Array de N bytes (mensaje cifrado)
    clave:      Array de 16 bytes
    nonce:      Array de 8 bytes
  SALIDA:
    plaintext:  Array de N bytes (mensaje original)
  
  ALGORITMO:
    // ¡NOTA CRÍTICA!
    // En AES-CTR, descifrado = cifrado
    // Porque: C[i] ⊕ KS[i] = (P[i] ⊕ KS[i]) ⊕ KS[i] = P[i]
    
    plaintext ← CifrarAES_CTR(ciphertext, clave, nonce)
    
    RETORNA plaintext
FIN FUNCIÓN
```

---

## 2.4 EJEMPLO DETALLADO PASO A PASO

### Escenario:
```
Plaintext: "HOLA" (4 bytes)
Clave:     "1234567890ABCDEF" (16 bytes)
Nonce:     0x0123456789ABCDEF (8 bytes)
```

### Ejecución:

```pseudocode
PASO 1: Inicializar AES
  contexto_aes ← InicializarAES("1234567890ABCDEF")
  
PASO 2: Calcular bloques
  numero_bloques = CEIL(4 / 16) = 1 bloque

PASO 3: Procesar bloque 0
  
  3.1. Generar contador
    contador ← GenerarContador(0x0123456789ABCDEF, 0)
    contador = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  
  3.2. Cifrar contador
    keystream ← AES_Encrypt(contexto_aes, contador)
    keystream = [0x8A, 0x9C, 0x5B, 0x3F, 0x2E, 0x1D, 0x7C, 0x4B,
                 0x9F, 0x2A, 0x3E, 0x5C, 0x1B, 0x8D, 0x6A, 0x4F]
    (Estos valores son ejemplos, AES generará valores reales)
  
  3.3. Extraer plaintext del bloque
    plaintext_bloque = "HOLA" = [0x48, 0x4F, 0x4C, 0x41]
    tamaño_bloque = 4
  
  3.4. Rellenar con ceros
    plaintext_bloque = [0x48, 0x4F, 0x4C, 0x41,
                        0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00]
  
  3.5. XOR
    ciphertext_bloque = XORBloque(plaintext_bloque, keystream)
    
    0x48 XOR 0x8A = 0xC2
    0x4F XOR 0x9C = 0xD3
    0x4C XOR 0x5B = 0x17
    0x41 XOR 0x3F = 0x7E
    0x00 XOR 0x2E = 0x2E
    ...
    
    ciphertext_bloque = [0xC2, 0xD3, 0x17, 0x7E, 0x2E, 0x1D, 0x7C, 0x4B, ...]
  
  3.6. Guardar resultado
    ciphertext[0:4] = [0xC2, 0xD3, 0x17, 0x7E]

RESULTADO FINAL:
  ciphertext = [0xC2, 0xD3, 0x17, 0x7E]
```

---

## 2.5 COMPLEJIDAD Y ANÁLISIS

### Complejidad temporal:

```
T(n) = O(n)

Donde n = número de bloques

Desglose:
  - InicializarAES():     O(1)  (cálculo de sub-claves, hecho una sola vez)
  - Loop sobre bloques:   O(n)
    - GenerarContador():  O(1)  (8 XORs simples)
    - AES_Encrypt():      O(1)  (constante para 16 bytes)
    - XORBloque():        O(1)  (16 XORs simples)
```

### Complejidad espacial:

```
S(n) = O(n)

Desglose:
  - contexto_aes:  O(1)     (~200 bytes, constante)
  - plaintext:     O(n)     (N bytes)
  - ciphertext:    O(n)     (N bytes)
  - buffers temp:  O(1)     (máx 16 bytes por bloque)
  
Total: O(n) - proporcional al tamaño de entrada
```

---

## 2.6 ESTRUCTURA DE CARPETAS Y ARCHIVOS

```
sequential/
├── main.cpp              (Punto de entrada)
├── aes_ctr.h             (Declaraciones)
├── aes_ctr.cpp           (Implementación)
├── aes_utils.h           (Funciones auxiliares)
├── aes_utils.cpp         (Implementación auxiliares)
└── test_sequential.txt   (Datos de prueba)
```

---

---

# MÓDULO 3: PARALELIZACIÓN CON OPENMP

## 🎯 Objetivo
Convertir el código secuencial a **paralelo en CPU** usando OpenMP con análisis de speedup.

---

## 3.1 ¿POR QUÉ OPENMP FUNCIONA PARA AES-CTR?

### Independencia de bloques:

```
Secuencial:
  Bloque 0 → [AES, XOR] → Salida 0
  Bloque 1 → [AES, XOR] → Salida 1
  Bloque 2 → [AES, XOR] → Salida 2
  
  Orden: 0 → 1 → 2 (SECUENCIAL)
  
Paralelo (OpenMP):
  Bloque 0 → [AES, XOR] → Salida 0  ← Thread 0
  Bloque 1 → [AES, XOR] → Salida 1  ← Thread 1
  Bloque 2 → [AES, XOR] → Salida 2  ← Thread 2
  
  Orden: 0 ∥ 1 ∥ 2 (PARALELO, sin sincronización)
```

**Clave:** No hay dependencias de datos entre bloques.

---

## 3.2 INTRODUCCIÓN A OPENMP

### ¿Qué es OpenMP?

Una API para paralelización en **CPU**:
- Usa múltiples hilos (threads) en el mismo procesador
- Comparte memoria entre hilos (shared memory)
- Directivas `#pragma` para marcar secciones paralelas

### Conceptos clave:

| Concepto | Significado |
|----------|-------------|
| **Thread** | Flujo de ejecución independiente en una CPU |
| **Shared memory** | Toda la RAM es visible para todos los threads |
| **Race condition** | Dos threads escriben la misma memoria al mismo tiempo |
| **Barrier** | Punto de sincronización: todos los threads esperan |
| **Schedule** | Cómo se distribuyen iteraciones entre threads |

---

## 3.3 PSEUDOCÓDIGO PARALELO CON OPENMP

### 3.3.1 Función de cifrado paralela

```pseudocode
FUNCIÓN CifrarAES_CTR_OpenMP(plaintext, clave, nonce, num_threads)
  ENTRADA:
    plaintext:   Array de N bytes
    clave:       Array de 16 bytes
    nonce:       Array de 8 bytes
    num_threads: Número de threads a usar
  SALIDA:
    ciphertext:  Array de N bytes
  
  ALGORITMO:
    // Paso 1: Inicializar
    contexto_aes ← InicializarAES(clave)
    numero_bloques ← CEIL(LONGITUD(plaintext) / BLOCK_SIZE)
    ciphertext ← Array de LONGITUD(plaintext) bytes
    
    // Paso 2: SECCIÓN PARALELA
    PARALELIZAR con num_threads threads:
      
      // Cada thread recibe un rango de bloques
      // OpenMP automáticamente distribuye iteraciones
      
      PARA bloque_idx = 0 HASTA numero_bloques - 1 HACER (EN PARALELO)
        
        // NOTA: Cada thread tiene su propia copia de variables locales
        // contador, keystream, plaintext_bloque son PRIVADAS
        
        LOCAL:  // Estas variables son locales a cada thread
          contador: Block
          keystream: Block
          plaintext_bloque: Block
          ciphertext_bloque: Block
        
        // Paso 2.1: Generar contador
        contador ← GenerarContador(nonce, bloque_idx)
        
        // Paso 2.2: Cifrar contador
        keystream ← AES_Encrypt(contexto_aes, contador)
        
        // Paso 2.3: Extraer plaintext
        inicio ← bloque_idx * BLOCK_SIZE
        fin ← MIN(inicio + BLOCK_SIZE, LONGITUD(plaintext))
        tamaño_bloque ← fin - inicio
        plaintext_bloque ← plaintext[inicio:fin]
        
        // Paso 2.4: Rellenar ceros
        SI tamaño_bloque < BLOCK_SIZE ENTONCES
          plaintext_bloque ← Rellenar_Ceros(plaintext_bloque, BLOCK_SIZE)
        FIN SI
        
        // Paso 2.5: XOR
        ciphertext_bloque ← XORBloque(plaintext_bloque, keystream)
        
        // Paso 2.6: Guardar resultado
        // ¡CRÍTICO! Cada thread escribe en posición diferente
        // NO HAY RACE CONDITION (bloques no solapan)
        ciphertext[inicio:fin] ← ciphertext_bloque[0:tamaño_bloque]
      
      FIN PARA (implícita barrera de sincronización)
    
    FIN PARALELIZAR
    
    RETORNA ciphertext
FIN FUNCIÓN
```

---

## 3.4 SINTAXIS OPENMP EN PSEUDOCÓDIGO

### Directivas principales:

```pseudocode
// Paralelizar un loop
#pragma omp parallel for
FOR i = 0 HASTA n-1 HACER
  ... (cada iteración puede ejecutarse en paralelo)
FIN FOR

// Con especificaciones de scheduling
#pragma omp parallel for schedule(static, chunk_size)
FOR i = 0 HASTA n-1 HACER
  ... 
FIN FOR

// Variables compartidas vs privadas
#pragma omp parallel for private(var1, var2) shared(var3)
FOR i = 0 HASTA n-1 HACER
  ... (var1, var2 son privadas; var3 es compartida)
FIN FOR
```

---

## 3.5 TÉCNICAS DE OPTIMIZACIÓN OPENMP

### 3.5.1 Schedule strategies

El `schedule` controla cómo OpenMP distribuye iteraciones entre threads:

```pseudocode
// ESTRATEGIA 1: Static (mejor para trabajo balanceado)
#pragma omp parallel for schedule(static, chunk_size)
FOR bloque = 0 HASTA n_bloques - 1 HACER
  Procesar(bloque)
FIN FOR

Distribución:
  Bloque 0   → Thread 0
  Bloque 1   → Thread 0
  ...
  Bloque 5   → Thread 1
  Bloque 6   → Thread 1
  (Predecible, bajo overhead)

// ESTRATEGIA 2: Dynamic (mejor para trabajo variable)
#pragma omp parallel for schedule(dynamic, chunk_size)
FOR bloque = 0 HASTA n_bloques - 1 HACER
  Procesar(bloque)
FIN FOR

Distribución:
  Thread 0 toma Bloque 0, termina, toma Bloque 3
  Thread 1 toma Bloque 1, termina, toma Bloque 4
  (Adaptativo, más overhead pero balance perfecto)

// ESTRATEGIA 3: Guided (balance entre ambas)
#pragma omp parallel for schedule(guided, chunk_size)
FOR bloque = 0 HASTA n_bloques - 1 HACER
  Procesar(bloque)
FIN FOR
```

### 3.5.2 Chunk size tuning

```
Chunk size = número de iteraciones por lote

Pequeño (1):
  - Overhead: ALTO (muchos cambios de contexto)
  - Balance: PERFECTO
  - Cache: MALO

Grande (n_bloques/num_threads):
  - Overhead: BAJO
  - Balance: PUEDE SER MALO (algunos threads ociosos)
  - Cache: MEJOR

Óptimo: Experimentar
  - Típico: 16, 32, 64
```

### 3.5.3 Minimizar overhead

```pseudocode
// ❌ MAL: Crear threads en cada iteración
PARA i = 0 HASTA millones HACER
  #pragma omp parallel for
  Procesar(i)
FIN PARA

// ✅ BIEN: Crear threads una sola vez
#pragma omp parallel for
PARA i = 0 HASTA millones HACER
  Procesar(i)
FIN PARA
```

---

## 3.6 ANÁLISIS DE SPEEDUP

### Ley de Amdahl:

```
Supuestos:
  - Programa tiene 2 secciones:
    * Paralela (puede optimizarse): 90%
    * Secuencial (no puede optimizarse): 10%
  - Num threads = 4

Cálculo:
  f_seq = 0.1 (10% secuencial)
  f_par = 0.9 (90% paralela)
  p = 4 threads
  
  Speedup = 1 / (f_seq + f_par/p)
          = 1 / (0.1 + 0.9/4)
          = 1 / (0.1 + 0.225)
          = 1 / 0.325
          ≈ 3.08x
```

**Para AES-CTR (muy bueno):**
```
f_seq ≈ 0.01 (inicialización AES)
f_par ≈ 0.99 (cifrado de bloques)
p = 8 threads

Speedup = 1 / (0.01 + 0.99/8)
        = 1 / (0.01 + 0.12375)
        ≈ 7.79x (casi lineal)
```

---

## 3.7 PROBLEMAS COMUNES Y SOLUCIONES

| Problema | Causa | Solución |
|----------|-------|----------|
| **Race condition** | Múltiples threads escriben mismo dato | Usar `private` o `atomic` |
| **False sharing** | Datos en mismo cache line | Alinear datos |
| **Bajo speedup** | Demasiado overhead, poco trabajo | Aumentar chunk size |
| **Desbalance** | Algunos threads ociosos | Usar `dynamic` schedule |
| **Contenida en memoria** | Cuello de botella en RAM | Optimizar acceso a memoria |

---

## 3.8 ESTIMACIÓN DE RENDIMIENTO

### Caso: Cifrar 1 GB de datos

**Hardware:**
```
CPU: Intel i7 (8 cores)
RAM: DDR4 3200 MHz
```

**Análisis:**

```
Tamaño del mensaje: 1 GB = 1,024 * 1,024 * 1,024 bytes
Bloques: 1,024 * 1,024 * 1,024 / 16 ≈ 67 millones de bloques

Tiempo por bloque:
  AES_Encrypt(): ~1000 ciclos (estimado)
  CPU: 3 GHz = 3,000 millones ciclos/seg
  Tiempo por bloque: 1000/3,000,000,000 ≈ 0.33 microsegundos
  
Tiempo secuencial:
  67,000,000 bloques × 0.33 µs ≈ 22 segundos
  
Tiempo paralelo (8 threads):
  22 seg / 8 ≈ 2.75 segundos (speedup ideal)
  
Realista (90% paralelismo):
  22 / (0.1 + 0.9/8) ≈ 18 segundos (speedup 1.22x)
  
Throughput:
  Realista: 1 GB / 18 seg ≈ 55 MB/s
  Ideal: 1 GB / 2.75 seg ≈ 363 MB/s
```

---

---

# MÓDULO 4: PARALELIZACIÓN CON CUDA

##  Objetivo
Migrar AES-CTR a **GPU** usando CUDA con explicación de arquitectura y optimizaciones.

---

## 4.1 ¿POR QUÉ CUDA PARA AES-CTR?

### Comparación CPU vs GPU:

| Característica | CPU | GPU |
|---|---|---|
| **Cores** | 8-16 | 1000-10000 |
| **Threads** | Decenas | Millones |
| **Latencia** | Baja | Alta |
| **Throughput** | Medio | Muy alto |
| **AES-CTR** | 90% paralelo | 99% paralelo =  Ideal |

### GPU domina cuando:

```
✅ Paralelismo masivo (millones de operaciones)
✅ Poca dependencia de datos (AES-CTR = perfecta independencia)
✅ Operaciones simples por thread (AES simple = 10 líneas)
✅ Mucho cálculo, poco movimiento de datos

❌ Poco paralelismo
❌ Lógica compleja por thread
❌ Movimiento frecuente de datos CPU ↔ GPU
```

---

## 4.2 ARQUITECTURA DE CUDA (SIMPLIFICADA)

### Jerarquía de ejecución:

```
GPU (tarjeta gráfica)
├── Grid (todas las tareas lanzadas)
│   ├── Block 0
│   │   ├── Thread 0
│   │   ├── Thread 1
│   │   ├── ...
│   │   └── Thread 255
│   ├── Block 1
│   │   ├── Thread 0
│   │   ├── Thread 1
│   │   ...
│   └── Block N
│       ...
└── (Miles de blocks, cada uno con cientos de threads)
```

### Memoria en CUDA:

```
Jerarquía de memoria (rápida → lenta):

1. Registers (por thread)
   - Velocidad: ~1 ciclo
   - Tamaño: ~256 bytes/thread
   - Uso: Variables locales

2. Shared memory (por block)
   - Velocidad: ~20 ciclos
   - Tamaño: 48-96 KB/block
   - Uso: Datos compartidos entre threads

3. Global memory (todo el GPU)
   - Velocidad: ~200+ ciclos
   - Tamaño: GB
   - Uso: Datos CPU ↔ GPU

4. Constant memory
   - Velocidad: ~20 ciclos (con cache)
   - Tamaño: 64 KB
   - Uso: Claves, constantes
```

---

## 4.3 PSEUDOCÓDIGO CUDA

### 4.3.1 Kernel (función que ejecuta en GPU)

```pseudocode
// Esta función corre EN LA GPU
// Cada thread ejecuta el mismo código con diferente thread_idx
KERNEL AES_CTR_Kernel_GPU(plaintext_gpu, 
                          ciphertext_gpu, 
                          clave, 
                          nonce, 
                          num_bloques)
  
  ENTRADA (en GPU global memory):
    plaintext_gpu:  Array de N bytes
    ciphertext_gpu: Array de N bytes
    clave:          Array de 16 bytes
    nonce:          Array de 8 bytes
    num_bloques:    Entero
  
  ALGORITMO:
    // Cada thread computa su índice único
    thread_idx ← blockIdx.x * blockDim.x + threadIdx.x
    
    // Verificar que el thread es válido
    SI thread_idx >= num_bloques ENTONCES
      RETORNA  // Este thread no hace nada
    FIN SI
    
    // VARIABLES LOCALES (privadas a cada thread)
    contador:           Block
    keystream:          Block
    plaintext_bloque:   Block
    ciphertext_bloque:  Block
    
    // Paso 1: Generar contador
    contador ← GenerarContador(nonce, thread_idx)
    
    // Paso 2: Cifrar contador con AES
    // ¡NOTA! AES_Encrypt se ejecuta 1000x más rápido en GPU
    keystream ← AES_Encrypt(clave, contador)
    
    // Paso 3: Extraer plaintext
    inicio ← thread_idx * BLOCK_SIZE
    fin ← MIN(inicio + BLOCK_SIZE, tamaño_total)
    tamaño_bloque ← fin - inicio
    
    plaintext_bloque ← plaintext_gpu[inicio:fin]
    
    // Paso 4: Rellenar ceros si es necesario
    SI tamaño_bloque < BLOCK_SIZE ENTONCES
      plaintext_bloque ← Rellenar_Ceros(plaintext_bloque, BLOCK_SIZE)
    FIN SI
    
    // Paso 5: XOR
    ciphertext_bloque ← XORBloque(plaintext_bloque, keystream)
    
    // Paso 6: Escribir resultado
    // SEGURO: Solo este thread escribe en ciphertext[inicio:fin]
    ciphertext_gpu[inicio:fin] ← ciphertext_bloque[0:tamaño_bloque]

FIN KERNEL
```

---

### 4.3.2 Función host (CPU) que lanza kernel

```pseudocode
FUNCIÓN CifrarAES_CTR_CUDA(plaintext, clave, nonce)
  ENTRADA (en CPU):
    plaintext: Array de N bytes
    clave:     Array de 16 bytes
    nonce:     Array de 8 bytes
  SALIDA (en CPU):
    ciphertext: Array de N bytes
  
  ALGORITMO:
    // PASO 1: Preparar datos en CPU
    numero_bloques ← CEIL(LONGITUD(plaintext) / BLOCK_SIZE)
    tamaño_datos ← LONGITUD(plaintext) bytes
    
    // PASO 2: Asignar memoria en GPU
    plaintext_gpu  ← CudaMalloc(tamaño_datos)
    ciphertext_gpu ← CudaMalloc(tamaño_datos)
    
    // PASO 3: Copiar datos CPU → GPU
    CudaMemcpy(plaintext_gpu, plaintext, tamaño_datos, CPU_a_GPU)
    
    // PASO 4: Calcular configuración de threads
    THREADS_POR_BLOQUE ← 256  (número típico)
    NUMERO_BLOQUES_GPU ← CEIL(numero_bloques / THREADS_POR_BLOQUE)
    
    // PASO 5: Lanzar kernel en GPU
    AES_CTR_Kernel_GPU <<<NUMERO_BLOQUES_GPU, THREADS_POR_BLOQUE>>> 
                       (plaintext_gpu, ciphertext_gpu, clave, nonce, numero_bloques)
    
    // PASO 6: Esperar a que GPU termine
    CudaSynchronize()
    
    // PASO 7: Copiar resultado GPU → CPU
    CudaMemcpy(ciphertext, ciphertext_gpu, tamaño_datos, GPU_a_CPU)
    
    // PASO 8: Liberar memoria GPU
    CudaFree(plaintext_gpu)
    CudaFree(ciphertext_gpu)
    
    RETORNA ciphertext
FIN FUNCIÓN
```

---

## 4.4 VISUALIZACIÓN DE EJECUCIÓN

### Distribución de threads:

```
Ejemplo: 67 millones de bloques, 256 threads/block

Número de blocks en GPU: CEIL(67,000,000 / 256) = 261,719 blocks

Grid layout (simplificado):
┌─────────────────────────────────────┐
│ CUDA Grid                           │
├─────────────────────────────────────┤
│ Block 0       Block 1       Block 2 │
│ [T0...T255]   [T0...T255]   [T0...T255]
│                                     │
│ Block 3       Block 4       ...     │
│ [T0...T255]   [T0...T255]          │
│                                     │
│ ...                                 │
│                                     │
│ Block 261,718                       │
│ [T0...T?]  (solo algunos threads)   │
└─────────────────────────────────────┘

Ejecución (conceptualmente):
  Todos los blocks ejecutan en paralelo
  Dentro de cada block, 256 threads ejecutan en paralelo
  Total threads activos simultáneamente: ~261,719 × 256 (limitado por GPU)
```

---

## 4.5 DIFERENCIAS CLAVE CUDA vs OpenMP

| Aspecto | OpenMP | CUDA |
|--------|--------|------|
| **Lenguaje** | C/C++ normal | C/C++ extendido |
| **Ejecución** | Múltiples cores CPU | Miles de cores GPU |
| **Memoria** | RAM compartida | RAM (CPU) + VRAM (GPU) |
| **Sincronización** | Barreras implícitas | Explícita |
| **Transferencia datos** | Automática | Manual (CPU ↔ GPU) |
| **Latencia de datos** | Baja (RAM rápida) | Alta (necesita copiar) |
| **Overhead** | Bajo | Más alto (por transferencia) |

---

## 4.6 COMPLEJIDAD DE CUDA

### Complejidad temporal:

```
Operaciones CPU:
  - Asignación memoria GPU:  O(1) constante
  - Copia CPU → GPU:         O(n) lineal (limitado por ancho de banda)
  - Copia GPU → CPU:         O(n) lineal

Operaciones GPU:
  - Ejecución kernel:        O(n/p) donde p = número de threads activos

Total:
  T_cuda = O(n) (dominado por transferencia de memoria)
  
  Comparación:
    T_secuencial = O(n)
    T_openmp = O(n/8) (8 cores)
    T_cuda = O(n) + overhead de transferencia
    
  Si n es grande:
    T_cuda puede ser mejor que T_openmp
    Si n es pequeño:
    T_openmp puede ser mejor (menos overhead)
```

---

## 4.7 ANÁLISIS DE TRANSFERENCIA DE DATOS

### Cuello de botella: PCIe

```
Ancho de banda PCIe 3.0 (típico):
  16x slots: 16 GB/s

Para 1 GB de datos:
  Copia CPU → GPU: 1 GB / 16 GB/s = 62.5 ms
  Copia GPU → CPU: 1 GB / 16 GB/s = 62.5 ms
  Total transferencia: 125 ms

Tiempo de cómputo en GPU:
  67,000,000 bloques / 1000 threads ≈ 67,000 ejecuciones de bloque
  Tiempo estimado: ~100 ms

PROBLEMA:
  Transferencia (125 ms) > Cómputo (100 ms)
  La GPU espera más en transferencia que haciendo trabajo
  
SOLUCIÓN:
  Para archivos > 1-10 GB, la GPU es más eficiente
  Para archivos < 100 MB, OpenMP probablemente es mejor
```

---

## 4.8 OPTIMIZACIÓN CUDA BÁSICA

### 4.8.1 Aumentar threads por block

```pseudocode
// ❌ Bajo paralelismo
THREADS_POR_BLOQUE ← 32

// ✅ Mejor paralelismo
THREADS_POR_BLOQUE ← 256  (estándar)

// ✅✅ Máximo paralelismo
THREADS_POR_BLOQUE ← 512 o 1024 (si el kernel lo permite)
```

### 4.8.2 Minimizar transferencias

```pseudocode
// ❌ Muchas transferencias
PARA i = 0 HASTA 1000 HACER
  CudaMemcpy(data_gpu, data_cpu[i], pequeño_tamaño)
  Kernel_GPU(data_gpu)
  CudaMemcpy(data_cpu[i], data_gpu, pequeño_tamaño)
FIN PARA

// ✅ Una transferencia
CudaMemcpy(data_gpu, data_cpu, tamaño_total)
PARA i = 0 HASTA 1000 HACER
  Kernel_GPU(data_gpu[i*offset: (i+1)*offset])
FIN PARA
CudaMemcpy(data_cpu, data_gpu, tamaño_total)
```

### 4.8.3 Usar coalesced memory access

```
Acceso NO coalescente:
  Thread 0 lee posición 0
  Thread 1 lee posición 1000000
  Thread 2 lee posición 2000000
  ...
  Resultado: N accesos a memoria, muy lento

Acceso coalescente:
  Thread 0 lee posición 0
  Thread 1 lee posición 1
  Thread 2 lee posición 2
  ...
  Resultado: 1 acceso a memoria combinado, muy rápido
```

---

---

# MÓDULO 5: OPTIMIZACIONES POR NIVEL

## 🎯 Objetivo
Técnicas específicas de optimización para **secuencial**, **OpenMP** y **CUDA**.

---

## 5.1 OPTIMIZACIONES SECUENCIALES

### 5.1.1 AES-NI (Hardware acceleration)

```pseudocode
// ❌ AES por software (lento)
keystream ← AES_Encrypt_Software(clave, contador)
// ~1000 ciclos por bloque

// ✅ AES-NI por hardware (rápido)
keystream ← AES_Encrypt_NI(clave, contador)
// ~10-30 ciclos por bloque
```

**Mejora: 30-100x más rápido**

### 5.1.2 Buffering y I/O

```pseudocode
// ❌ Sin buffering (archivo pequeño)
ARCHIVO ← Abrir("datos.bin")
PARA i = 0 HASTA 1 millón HACER
  byte ← ARCHIVO.Leer(1 byte)
  ...
FIN PARA
ARCHIVO.Cerrar()
// Millón de llamadas a disco

// ✅ Con buffering (bloque grande)
ARCHIVO ← Abrir("datos.bin")
buffer ← ARCHIVO.Leer(1 MB)  // 1 llamada a disco
PARA i = 0 HASTA 1 millón HACER
  byte ← buffer[i]
  ...
FIN PARA
ARCHIVO.Cerrar()
// Una sola llamada a disco
```

**Mejora: 100-1000x más rápido para I/O**

### 5.1.3 Alineación de memoria

```pseudocode
// ❌ Mal alineada (16 bytes en posición impar)
data = Malloc(100)  // Puede empezar en 0x7FD3
// CPU necesita 2 accesos para leer 16 bytes

// ✅ Bien alineada (16 bytes en múltiplo de 16)
data = Malloc_Aligned(100, 16)  // Siempre en 0x7FD0, 0x7FE0, etc.
// CPU accede en 1 ciclo
```

**Mejora: 2x más rápido en acceso a memoria**

### 5.1.4 SIMD (Single Instruction Multiple Data)

```pseudocode
// ❌ Bucle secuencial
PARA i = 0 HASTA 15 HACER
  resultado[i] ← a[i] XOR b[i]  // 16 XORs
FIN PARA

// ✅ SIMD (procesar 128 bits a la vez)
__m128i a_vec ← LoadSIMD(a, 16)
__m128i b_vec ← LoadSIMD(b, 16)
__m128i res ← SIMD_XOR(a_vec, b_vec)  // 16 XORs en 1 instrucción
StoreSIMD(resultado, res)
```

**Mejora: 4-8x más rápido (128/32 = 4 ints simultáneos)**

---

## 5.2 OPTIMIZACIONES OPENMP

### 5.2.1 Chunk size tuning

```pseudocode
// Pruebas de rendimiento con 1 GB de datos

schedule(static, 1):      // Cada thread toma 1 iteración
  - Overhead: MUY ALTO
  - Resultado: 10 MB/s

schedule(static, 64):     // Cada thread toma 64 iteraciones
  - Overhead: BAJO
  - Load balance: BUENO
  - Resultado: 380 MB/s  ✅

schedule(static, 1024):   // Cada thread toma 1024 iteraciones
  - Overhead: MUY BAJO
  - Load balance: MALO (algunos threads ociosos)
  - Resultado: 350 MB/s

schedule(dynamic, 64):    // Threads toman trabajo dinámicamente
  - Overhead: MEDIO
  - Load balance: PERFECTO
  - Resultado: 375 MB/s
```

**Recomendación: schedule(static, chunk_size) con chunk_size = 64**

### 5.2.2 Reducción de false sharing

```pseudocode
// ❌ False sharing (comparten cache line)
SHARED: data[0], data[1], data[2], data[3]

Thread 0 modifica data[0]
Thread 1 modifica data[1]
// Ambas en la misma cache line (64 bytes)
// Invalidación mutua: muy lento

// ✅ Evitar false sharing
PRIVATE: result[0], result[1], result[2], result[3]
#pragma omp parallel for private(result)
FOR thread = 0 HASTA num_threads-1 HACER
  result[thread] ← local_calculation()
  // Cada thread escribe en su propia variable privada
FIN PARA
```

**Mejora: 2-10x dependiendo de contención**

### 5.2.3 Afinidad de threads

```pseudocode
// ❌ Sin afinidad (threads saltan entre cores)
#pragma omp parallel for
FOR bloque = 0 HASTA n-1 HACER
  ...
FIN PARA

// ✅ Con afinidad (threads fijos en cores)
#pragma omp parallel for proc_bind(close)
FOR bloque = 0 HASTA n-1 HACER
  ...
FIN PARA
// Mejor localidad de caché
```

**Mejora: 5-20% dependiendo de configuración**

---

## 5.3 OPTIMIZACIONES CUDA

### 5.3.1 Aumentar occupancy (uso de GPU)

```
Occupancy = (threads activos) / (threads máximos de GPU)

GPU NVIDIA (ejemplo):
  - Max threads: 128 × 1024 = 131,072
  - Threads por block: 256
  - Max blocks: 128
  
  Si usamos 256 threads/block:
    Occupancy = 256/1024 = 25% (bajo)
  
  Si usamos 1024 threads/block:
    Occupancy = 1024/1024 = 100% (óptimo)
    Pero: Necesitamos suficientes bloques
    Max blocks = 131,072 / 1024 = 128
    Para n_bloques iteraciones: ocupancy = min(n_bloques, 128) × 1024 / 131,072
```

**Recomendación: Aumentar threads/block a máximo permitido**

### 5.3.2 Usar shared memory para tablas AES

```pseudocode
// ❌ Leer S-boxes de global memory (200 ciclos)
KERNEL kernel_sin_optim(...)
  FOR i = 0 HASTA 9 HACER  // 10 rondas
    byte = s_box_global[valor]  // 200 ciclos × 10 = 2000 ciclos
  FIN PARA
FIN KERNEL

// ✅ Copiar S-boxes a shared memory (20 ciclos)
KERNEL kernel_optimizado(...)
  LOCAL shared s_box[256]  // Shared memory, solo 96 KB/block
  
  // Cada thread copia un dato a shared memory
  SI threadIdx.x < 256 ENTONCES
    s_box[threadIdx.x] = s_box_global[threadIdx.x]
  FIN SI
  
  __syncthreads()  // Todos esperan a que se copie
  
  FOR i = 0 HASTA 9 HACER
    byte = s_box[valor]  // 20 ciclos × 10 = 200 ciclos
  FIN PARA
FIN KERNEL

// Mejora: 2000/200 = 10x más rápido
```

### 5.3.3 Constant memory para clave

```pseudocode
// Declarar la clave como constante en GPU
__constant__ unsigned char clave_gpu[16];

KERNEL kernel_con_const(...)
  // Leer de constant memory (20 ciclos con cache)
  byte = clave_gpu[i]
FIN KERNEL

// Host (CPU):
CudaMemcpyToSymbol(clave_gpu, clave_cpu, 16)  // Copiar clave
```

**Beneficio: Acceso cacheable, más rápido que global memory**

### 5.3.4 Pinned memory para transferencias

```pseudocode
// ❌ Memoria pageable (lenta)
plaintext = malloc(1 GB)
CudaMemcpy(plaintext_gpu, plaintext, 1 GB)
// Velocidad: ~6 GB/s (depende de CPU)

// ✅ Memoria pinned (rápida)
CudaMallocHost(plaintext, 1 GB)  // Asignación especial
CudaMemcpy(plaintext_gpu, plaintext, 1 GB)
// Velocidad: ~12 GB/s (casi el doble)
```

**Mejora: 1.5-2x más rápido en transferencias**

### 5.3.5 CUDA Streams (overlap)

```pseudocode
// ❌ Secuencial (esperar cada paso)
CudaMemcpy(data_gpu, data_cpu, N)      // 100 ms
Kernel(data_gpu)                        // 100 ms
CudaMemcpy(data_cpu, data_gpu, N)      // 100 ms
Total: 300 ms

// ✅ Con streams (overlap)
Stream 0: CudaMemcpy(data_gpu, data_cpu, N)  // 100 ms
Stream 1: Kernel(data_gpu)                    // 100 ms (overlap con copia anterior)
Stream 0: CudaMemcpy(data_cpu, data_gpu, N)  // 100 ms (overlap con kernel)
Total: ~200 ms (30% mejora)
```

**Mejora: 20-40% en casos óptimos**

---

## 5.4 TABLA COMPARATIVA DE OPTIMIZACIONES

| Optimización | Técnica | Mejora | Dificultad | Aplicable a |
|---|---|---|---|---|
| AES-NI | Hardware | 30-100x | Fácil | Secuencial |
| Buffering I/O | Software | 100-1000x | Fácil | Secuencial |
| SIMD | Hardware | 4-8x | Medio | Secuencial |
| Alineación | Memoria | 2x | Fácil | Todas |
| Chunk size | Scheduling | 2-4x | Fácil | OpenMP |
| Afinidad | Scheduling | 5-20% | Fácil | OpenMP |
| Occupancy | GPU config | 2-4x | Medio | CUDA |
| Shared memory | GPU memoria | 5-10x | Difícil | CUDA |
| Constant memory | GPU memoria | 2x | Fácil | CUDA |
| Pinned memory | Transferencia | 2x | Medio | CUDA |
| CUDA Streams | Async | 20-40% | Difícil | CUDA |

---

---

# MÓDULO 6: BENCHMARKING, VALIDACIÓN Y ANÁLISIS

## 🎯 Objetivo
Medir rendimiento, validar resultados y comparar implementaciones.

---

## 6.1 VALIDACIÓN DE CORRECTITUD

### 6.1.1 Propiedad fundamental AES-CTR

```pseudocode
FUNCIÓN ValidarPropiedad()
  // Propiedad: decrypt(encrypt(x)) == x
  
  plaintext_original ← "Mensaje secreto 123456789"
  clave ← "0123456789ABCDEF"
  nonce ← 0x0123456789ABCDEF
  
  // Cifrar
  ciphertext ← CifrarAES_CTR(plaintext_original, clave, nonce)
  
  // Descifrar
  plaintext_recuperado ← DescifrarAES_CTR(ciphertext, clave, nonce)
  
  // Verificar igualdad byte por byte
  SI plaintext_original == plaintext_recuperado ENTONCES
    IMPRIME "✅ VALIDACIÓN EXITOSA"
    RETORNA verdadero
  SINO
    IMPRIME "❌ VALIDACIÓN FALLIDA"
    IMPRIME "Original:    " + plaintext_original
    IMPRIME "Recuperado:  " + plaintext_recuperado
    RETORNA falso
  FIN SI
FIN FUNCIÓN
```

### 6.1.2 Validación con nonce diferente (debe fallar)

```pseudocode
FUNCIÓN ValidarNonceMismatch()
  // Si usamos nonce diferente, debe fallar
  
  plaintext ← "Mensaje"
  clave ← "Clave123"
  nonce1 ← 0x0123456789ABCDEF
  nonce2 ← 0xFEDCBA9876543210  // Diferente
  
  ciphertext ← CifrarAES_CTR(plaintext, clave, nonce1)
  
  plaintext_falso ← DescifrarAES_CTR(ciphertext, clave, nonce2)
  
  SI plaintext_falso != plaintext ENTONCES
    IMPRIME "✅ NONCE DIFERENTE RECHAZADO (correcto)"
  SINO
    IMPRIME "❌ ERROR: Nonce diferente pero descifró igual (MAL)"
  FIN SI
FIN FUNCIÓN
```

### 6.1.3 Validación con bloque parcial (último bloque < 16 bytes)

```pseudocode
FUNCIÓN ValidarBloqueIncompleto()
  // Mensaje que no es múltiplo de 16 bytes
  
  plaintext ← "Hola"         // 4 bytes (no 16)
  clave ← "1234567890ABCDEF"  // 16 bytes
  nonce ← 0x0000000000000000
  
  ciphertext ← CifrarAES_CTR(plaintext, clave, nonce)
  plaintext_recuperado ← DescifrarAES_CTR(ciphertext, clave, nonce)
  
  SI plaintext_recuperado == plaintext ENTONCES
    IMPRIME "✅ BLOQUE INCOMPLETO VALIDADO"
  SINO
    IMPRIME "❌ ERROR CON BLOQUE INCOMPLETO"
  FIN SI
FIN FUNCIÓN
```

---

## 6.2 MÉTRICAS DE RENDIMIENTO

### 6.2.1 Throughput (MB/s)

```pseudocode
FUNCIÓN MedirThroughput(tamaño_datos_MB, tiempo_seg)
  RETORNA tamaño_datos_MB / tiempo_seg  // MB/s
FIN FUNCIÓN

EJEMPLO:
  Datos: 1000 MB
  Tiempo: 2.5 segundos
  Throughput = 1000 / 2.5 = 400 MB/s
```

### 6.2.2 Speedup relativo

```pseudocode
FUNCIÓN CalcularSpeedup(tiempo_secuencial, tiempo_paralelo)
  RETORNA tiempo_secuencial / tiempo_paralelo
FIN FUNCIÓN

EJEMPLO:
  Secuencial: 10 segundos
  OpenMP:     1.5 segundos
  Speedup = 10 / 1.5 = 6.67x
  
  (En 8 cores, speedup lineal sería 8x, actual es 6.67x → 83% eficiencia)
```

### 6.2.3 Eficiencia

```pseudocode
FUNCIÓN CalcularEficiencia(speedup, num_procesadores)
  RETORNA (speedup / num_procesadores) × 100  // Porcentaje
FIN FUNCIÓN

EJEMPLO:
  Speedup: 6.67x
  Cores: 8
  Eficiencia = (6.67 / 8) × 100 = 83%
  
  Interpretación:
    - 100% = Paralelismo perfecto (speedup = cores)
    - 83% = Muy bueno (pérdida mínima por overhead)
    - 50% = Aceptable
    - < 20% = Mala paralelización
```

---

## 6.3 SCRIPT DE BENCHMARKING (PSEUDOCÓDIGO)

```pseudocode
FUNCIÓN BenchmarkCompleto()
  
  // Configuración
  tamaños ← [1 MB, 10 MB, 100 MB, 1 GB]
  repeticiones ← 3
  
  // Resultados
  resultados ← []
  
  PARA tamaño EN tamaños HACER
    IMPRIME "Probando con tamaño: " + tamaño
    
    // Generar datos
    plaintext ← GenerarDatosAleatorios(tamaño)
    clave ← "1234567890ABCDEF"
    nonce ← 0x0123456789ABCDEF
    
    // VALIDACIÓN RÁPIDA
    ciphertext_test ← CifrarAES_CTR(plaintext, clave, nonce)
    plaintext_test ← DescifrarAES_CTR(ciphertext_test, clave, nonce)
    
    SI plaintext_test != plaintext ENTONCES
      IMPRIME "❌ Error de validación, saltando"
      CONTINUAR
    FIN SI
    
    // BENCHMARKS
    // 1. Secuencial
    tiempos_seq ← []
    PARA rep = 1 HASTA repeticiones HACER
      inicio_time ← ObtenerTiempoActual()
      CifrarAES_CTR(plaintext, clave, nonce)
      fin_time ← ObtenerTiempoActual()
      tiempos_seq.Agregar(fin_time - inicio_time)
    FIN PARA
    tiempo_promedio_seq ← Promedio(tiempos_seq)
    
    // 2. OpenMP
    tiempos_omp ← []
    PARA rep = 1 HASTA repeticiones HACER
      inicio_time ← ObtenerTiempoActual()
      CifrarAES_CTR_OpenMP(plaintext, clave, nonce, 8)
      fin_time ← ObtenerTiempoActual()
      tiempos_omp.Agregar(fin_time - inicio_time)
    FIN PARA
    tiempo_promedio_omp ← Promedio(tiempos_omp)
    
    // 3. CUDA
    tiempos_cuda ← []
    PARA rep = 1 HASTA repeticiones HACER
      inicio_time ← ObtenerTiempoActual()
      CifrarAES_CTR_CUDA(plaintext, clave, nonce)
      fin_time ← ObtenerTiempoActual()
      tiempos_cuda.Agregar(fin_time - inicio_time)
    FIN PARA
    tiempo_promedio_cuda ← Promedio(tiempos_cuda)
    
    // Calcular métricas
    throughput_seq ← tamaño / tiempo_promedio_seq
    throughput_omp ← tamaño / tiempo_promedio_omp
    throughput_cuda ← tamaño / tiempo_promedio_cuda
    
    speedup_omp ← tiempo_promedio_seq / tiempo_promedio_omp
    speedup_cuda ← tiempo_promedio_seq / tiempo_promedio_cuda
    
    // Guardar resultados
    resultados.Agregar({
      tamaño: tamaño,
      tiempo_seq: tiempo_promedio_seq,
      tiempo_omp: tiempo_promedio_omp,
      tiempo_cuda: tiempo_promedio_cuda,
      throughput_seq: throughput_seq,
      throughput_omp: throughput_omp,
      throughput_cuda: throughput_cuda,
      speedup_omp: speedup_omp,
      speedup_cuda: speedup_cuda
    })
  FIN PARA
  
  // Mostrar resultados
  ImprimirResultados(resultados)
  GuardarEnCSV(resultados, "benchmark_resultados.csv")
  
FIN FUNCIÓN
```

---

## 6.4 TABLA DE RESULTADOS ESPERADOS

**Hardware de referencia:**
```
CPU: Intel i7-9700K (8 cores, 3.6 GHz)
GPU: NVIDIA RTX 2080 (2944 CUDA cores)
RAM: 32 GB DDR4
PCIe: 3.0 16x (16 GB/s teórico)
```

**Resultados típicos:**

| Tamaño | Sec (ms) | OMP (ms) | CUDA (ms) | Tput Sec (MB/s) | Tput OMP (MB/s) | Tput CUDA (MB/s) | Speedup OMP | Speedup CUDA |
|--------|----------|----------|-----------|-----------------|-----------------|------------------|-------------|--------------|
| 1 MB | 0.003 | 0.050 | 50 | 333 | 20 | 0.02 | 0.06x | 0.00006x |
| 10 MB | 0.030 | 0.045 | 65 | 333 | 222 | 154 | 0.67x | 0.46x |
| 100 MB | 0.300 | 0.045 | 70 | 333 | 2222 | 1429 | 6.67x | 4.29x |
| 1 GB | 3.0 | 0.45 | 0.5 | 333 | 2222 | 2000 | 6.67x | 6.0x |

**Análisis:**

```
Para 1 MB:
  - Overhead CUDA (transferencia) domina
  - OpenMP es mejor que CUDA
  - Usar: Secuencial o OpenMP

Para 100 MB - 1 GB:
  - CUDA se vuelve competitivo
  - OpenMP tiene mejor throughput
  - Usar: OpenMP para CPU, CUDA para GPU si hay disponibilidad

Observaciones:
  1. CUDA mejora con datos más grandes
  2. Transferencia PCIe es cuello de botella
  3. Después de 100 MB, CUDA empieza a ganar
```

---

## 6.5 GRÁFICAS Y VISUALIZACIÓN

### 6.5.1 Gráfica de throughput vs tamaño

```
Throughput (MB/s)
    |
2500|                            ╱ CUDA
    |                          ╱
2000|                        ╱
    |                  ╱CUDA OpenMP
1500|            ╱ ╱
    |          ╱
1000|      OpenMP
    |    ╱
500 | Sec
    |
    └─────────────────────────────────
      1MB  10MB 100MB 1GB  10GB
      
Interpretación:
  - Secuencial: constante ~333 MB/s
  - OpenMP: mejora con paralelismo
  - CUDA: mejora dramática con datos grandes
```

### 6.5.2 Gráfica de speedup vs cores

```
Speedup
    |
 8x |           Ideal (1:1)
    |         ╱
 6x |      ╱ OpenMP (real)
    |    ╱
 4x |  ╱
    |╱ ╱
 2x |
    |
 1x |─────────────
    |
    └─────────────────────────────────
      1   2   4   8   16   32
      Cores / Threads
      
Interpretación:
  - Ideal: Speedup = N cores → Línea diagonal
  - Real: Sub-lineal por overhead
  - OpenMP típico: ~83% de ideal para 8 cores
```

---

## 6.6 CHECKLIST DE VALIDACIÓN ANTES DE PRODUCCIÓN

```
VALIDACIONES FUNCIONALES:
  ☐ decrypt(encrypt(x)) == x para todos los tamaños
  ☐ Diferentes nonces producen diferentes ciphertexts
  ☐ Clave incorrecta produce plaintext incorrecto
  ☐ Bloque incompleto (< 16 bytes) funciona
  ☐ Datos muy grandes (> 10 GB) funcionan
  ☐ Datos pequeños (< 16 bytes) funcionan
  ☐ Datos vacíos (0 bytes) no causan error

VALIDACIONES DE SEGURIDAD:
  ☐ Nonce nunca se repite en 2^64 mensajes
  ☐ Clave nunca se imprime en logs
  ☐ Clave se borra de memoria después de usar
  ☐ No hay información sensible en salidas

VALIDACIONES DE RENDIMIENTO:
  ☐ Throughput crece linealmente con datos
  ☐ Speedup OpenMP está entre 4-8x (8 cores)
  ☐ CUDA es más rápido que OpenMP para > 100 MB
  ☐ No hay fugas de memoria (memoria liberada correctamente)
  ☐ GPU memory se libera después de usar

VALIDACIONES DE COMPILACIÓN:
  ☐ Compila sin warnings
  ☐ Sin undefined behavior (analizado con sanitizers)
  ☐ Código funciona en MSVC 2022
  ☐ OpenSSL linkea correctamente
  ☐ CUDA compila sin errores
```

---

## 6.7 TABLA DE RESUMEN COMPARATIVO

| Aspecto | Secuencial | OpenMP | CUDA |
|--------|-----------|--------|------|
| **Complejidad implementación** | Baja | Media | Alta |
| **Mejor para** | < 10 MB | 10-1000 MB | > 100 MB |
| **Throughput típico** | 300 MB/s | 2000 MB/s | 1500-2000 MB/s |
| **Overhead** | Mínimo | Bajo | Alto (transferencia) |
| **Requiere GPU** | No | No | Sí |
| **Mantenibilidad** | Excelente | Buena | Difícil |
| **Portabilidad** | Excelente | Buena | Solo NVIDIA |
| **Recomendación** | Desarrollo, pruebas | Producción CPU | Producción masiva |

---

---

# CONCLUSIÓN Y ROADMAP

## Lo que aprendiste en esta guía:

1. ✅ **MÓDULO 0:** Criptografía para profanos (XOR, nonce, bloques)
2. ✅ **MÓDULO 1:** Matemáticas de AES-CTR con complejidad intermedia-alta
3. ✅ **MÓDULO 2:** Pseudocódigo secuencial paso a paso
4. ✅ **MÓDULO 3:** Paralelización OpenMP con análisis de speedup
5. ✅ **MÓDULO 4:** Paralelización CUDA con arquitectura GPU
6. ✅ **MÓDULO 5:** Optimizaciones específicas para cada nivel
7. ✅ **MÓDULO 6:** Benchmarking, validación y análisis comparativo

---

## Próximos pasos prácticos:

1. **Semana 1-2:** Implementar secuencial en C++ (Módulo 2)
2. **Semana 2-3:** Validar resultados y hacer benchmarks básicos
3. **Semana 3-4:** Agregar OpenMP y comparar rendimiento
4. **Semana 4-6:** Implementar CUDA si tienes GPU disponible
5. **Semana 6+:** Optimizaciones específicas por nivel

---

## Recursos complementarios:

- OpenSSL: https://www.openssl.org/
- CUDA: https://developer.nvidia.com/cuda-toolkit
- OpenMP: https://www.openmp.org/
- Visual Studio: https://visualstudio.microsoft.com/

---

## Errores más comunes a evitar:

1. ❌ **Reutilizar nonce:** Rompe la seguridad completamente
2. ❌ **Asumir que CUDA es siempre más rápido:** Solo para datos grandes
3. ❌ **Olvidar liberar memoria GPU:** Memory leak grave
4. ❌ **No validar desencriptación:** Hay que verificar correctitud
5. ❌ **Transferir datos CPU ↔ GPU innecesariamente:** Cuello de botella

---

**Documento completado. Duración de aprendizaje: 12-20 horas de estudio + 20-30 horas de implementación práctica.**