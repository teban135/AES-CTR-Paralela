// ========================================================================================
// NOTA: Cabecera para el Cifrador AES-CTR Paralelo con OpenMP y optimización SIMD.
// Se compila junto con 'aes_openmp.cpp', 'common/aes_core.cpp' y 'main_omp.cpp'.
//
// Comando de compilación sugerido:
// - MinGW: g++ -O3 -fopenmp -o bin/aes_omp.exe openmp/main_omp.cpp openmp/aes_openmp.cpp common/aes_core.cpp
// - MSVC:  cl /EHsc /O2 /openmp /Fe:bin\aes_omp.exe openmp\main_omp.cpp openmp\aes_openmp.cpp common\aes_core.cpp
// ========================================================================================

#ifndef AES_OPENMP_H
#define AES_OPENMP_H

#include <string>

// Procesa (cifra/descifra) un archivo usando AES-128-CTR en paralelo con hilos de CPU (OpenMP).
// Retorna true si tiene éxito, false en caso contrario.
bool encrypt_decrypt_aes_ctr_openmp(const std::string& input_path, 
                                    const std::string& output_path, 
                                    const unsigned char* key, 
                                    const unsigned char* nonce,
                                    int num_threads,
                                    double& total_omp_time_ms);

#endif // AES_OPENMP_H

