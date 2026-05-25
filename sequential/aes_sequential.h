// ========================================================================================
// NOTA: Cabecera para el Cifrador AES-CTR Secuencial con optimización SIMD.
// Se compila junto con 'aes_sequential.cpp', 'common/aes_core.cpp' y 'main_seq.cpp'.
//
// Comando de compilación sugerido:
// - MinGW: g++ -O3 -o bin/aes_seq.exe sequential/main_seq.cpp sequential/aes_sequential.cpp common/aes_core.cpp
// - MSVC:  cl /EHsc /O2 /Fe:bin\aes_seq.exe sequential\main_seq.cpp sequential\aes_sequential.cpp common\aes_core.cpp
// ========================================================================================

#ifndef AES_SEQUENTIAL_H
#define AES_SEQUENTIAL_H

#include <string>

// Procesa (cifra/descifra) un archivo usando AES-128-CTR de forma secuencial y optimizada.
// Retorna true si tiene éxito, false en caso contrario.
bool encrypt_decrypt_aes_ctr_sequential(const std::string& input_path, 
                                        const std::string& output_path, 
                                        const unsigned char* key, 
                                        const unsigned char* nonce);

#endif // AES_SEQUENTIAL_H
