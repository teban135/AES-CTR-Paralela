// ========================================================================================
// NOTA: Archivo de cabecera portable (CPU/GPU).
// Se compila junto con 'aes_core.cpp' y el programa principal ('test_aes_core.cpp', etc.).
//
// Comando de compilación de prueba (con test_aes_core):
// - MinGW: g++ -O3 -o bin/test_aes_core.exe common/test_aes_core.cpp common/aes_core.cpp
// - MSVC:  cl /EHsc /O2 /Fe:bin\test_aes_core.exe common\test_aes_core.cpp common\aes_core.cpp
// ========================================================================================

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
void aes128_expand_key(const unsigned char* key, AESKeySchedule* schedule);
void aes128_encrypt_block(const AESKeySchedule* schedule, const unsigned char* plaintext, unsigned char* ciphertext);
HD_QUALIFIER void aes128_encrypt_block_shared(const AESKeySchedule* schedule, const unsigned char* plaintext, unsigned char* ciphertext, const unsigned char* sbox_shared);

#endif // AES_CORE_H

