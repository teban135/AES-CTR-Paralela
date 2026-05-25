// ========================================================================================
// NOTA: Cabecera para el Cifrador AES-CTR Paralelo con CUDA en GPU.
// Se compila junto con 'aes_cuda.cu', 'common/aes_core.cpp' y 'main_cuda.cu'.
//
// Comando de compilación sugerido (con NVIDIA nvcc):
//   nvcc -O3 -o bin/aes_cuda.exe cuda/main_cuda.cu cuda/aes_cuda.cu
// ========================================================================================

#ifndef AES_CUDA_H
#define AES_CUDA_H

#include <string>

// Procesa (cifra/descifra) un archivo usando AES-128-CTR en paralelo con GPU (CUDA).
// Retorna true si tiene éxito, false en caso contrario.
bool encrypt_decrypt_aes_ctr_cuda(const std::string& input_path, 
                                  const std::string& output_path, 
                                  const unsigned char* key, 
                                  const unsigned char* nonce,
                                  double& total_kernel_time_ms,
                                  double& total_transfer_time_ms);

#endif // AES_CUDA_H

