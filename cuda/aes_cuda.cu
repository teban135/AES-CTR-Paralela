// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS:
// - Con NVIDIA nvcc:
//   nvcc -O3 -o bin/aes_cuda.exe cuda/main_cuda.cu cuda/aes_cuda.cu
// ========================================================================================

#include "aes_cuda.h"
#include "../common/aes_core.cpp"

#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>
#include <cuda_runtime.h>

#include <device_launch_parameters.h>

// Definir constante para la clave expandida en la memoria de constantes de la GPU
__constant__ AESKeySchedule d_schedule;

// Tabla S-Box de Rijndael para uso exclusivo de la GPU
__device__ const unsigned char d_sbox[256] = {
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
};

// Kernel de CUDA para el cifrado/descifrado AES-128-CTR
__global__ void aes_ctr_kernel(const unsigned char* d_input, 
                               unsigned char* d_output, 
                               size_t num_blocks, 
                               size_t global_block_idx, 
                               unsigned long long nonce_val) {
    
    // Calcular el identificador global del hilo
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    // Declaración de memoria compartida para almacenar la S-Box
    __shared__ unsigned char s_sbox[256];
    
    // Carga cooperativa de la S-Box en la memoria compartida por los hilos del bloque
    if (threadIdx.x < 256) {
        s_sbox[threadIdx.x] = d_sbox[threadIdx.x];
    }

    
    // Asegurar que todos los hilos del bloque cargaron la S-Box antes de continuar
    __syncthreads();
    
    if (idx < num_blocks) {
        unsigned char counter_block[16];
        unsigned char keystream[16];
        
        // 1. Reconstruir el nonce (primeros 8 bytes del contador)
        for (int i = 0; i < 8; ++i) {
            counter_block[i] = (unsigned char)((nonce_val >> (i * 8)) & 0xFF);
        }
        
        // 2. Reconstruir el índice de bloque (últimos 8 bytes en Big-Endian)
        size_t current_global_idx = global_block_idx + idx;
        for (int i = 0; i < 8; ++i) {
            counter_block[15 - i] = (unsigned char)((current_global_idx >> (i * 8)) & 0xFF);
        }
        
        // 3. Cifrar el bloque contador usando la clave constante y S-Box local en Shared Memory
        aes128_encrypt_block_shared(&d_schedule, counter_block, keystream, s_sbox);
        
        // 4. Operación XOR y almacenamiento de vuelta en memoria global
        size_t offset = idx * 16;
        for (int i = 0; i < 16; ++i) {
            d_output[offset + i] = d_input[offset + i] ^ keystream[i];
        }
    }
}

bool encrypt_decrypt_aes_ctr_cuda(const std::string& input_path, 
                                  const std::string& output_path, 
                                  const unsigned char* key, 
                                  const unsigned char* nonce,
                                  double& total_kernel_time_ms,
                                  double& total_transfer_time_ms) {
    total_kernel_time_ms = 0.0;
    total_transfer_time_ms = 0.0;

    std::ifstream input_file(input_path, std::ios::binary);
    if (!input_file) {
        std::cerr << "[-] Error: No se pudo abrir el archivo de entrada: " << input_path << std::endl;
        return false;
    }

    std::ofstream output_file(output_path, std::ios::binary);
    if (!output_file) {
        std::cerr << "[-] Error: No se pudo abrir o crear el archivo de salida: " << output_path << std::endl;
        return false;
    }

    // 1. Cargar clave expandida en la CPU
    AESKeySchedule h_schedule;
    aes128_expand_key(key, &h_schedule);

    // 2. Copiar la clave expandida a la memoria de constantes (Constant Memory) de la GPU
    cudaError_t err = cudaMemcpyToSymbol(d_schedule, &h_schedule, sizeof(AESKeySchedule));
    if (err != cudaSuccess) {
        std::cerr << "[-] Error al copiar clave a Constant Memory: " << cudaGetErrorString(err) << std::endl;
        return false;
    }

    // Codificar el nonce en un uint64_t de 64 bits para el paso por valor rápido al Kernel
    unsigned long long nonce_val = 0;
    for (int i = 0; i < 8; ++i) {
        nonce_val |= (static_cast<unsigned long long>(nonce[i]) << (i * 8));
    }

    // Buffer de 16 MB para un streaming masivo óptimo a la GPU
    const size_t BUFFER_SIZE = 16 * 1024 * 1024;
    
    // Asignación de Memoria Pinned (Host Page-Locked) para transferencias PCIe ultra-rápidas (DMA)
    unsigned char* h_buffer = nullptr;
    err = cudaMallocHost(reinterpret_cast<void**>(&h_buffer), BUFFER_SIZE);
    if (err != cudaSuccess) {
        std::cerr << "[-] Error al asignar Host Pinned Memory: " << cudaGetErrorString(err) << std::endl;
        return false;
    }

    // Asignación de memoria en la GPU (Device Memory)
    unsigned char* d_input = nullptr;
    unsigned char* d_output = nullptr;
    cudaMalloc(reinterpret_cast<void**>(&d_input), BUFFER_SIZE);
    cudaMalloc(reinterpret_cast<void**>(&d_output), BUFFER_SIZE);

    size_t global_block_idx = 0;

    while (input_file) {
        input_file.read(reinterpret_cast<char*>(h_buffer), BUFFER_SIZE);
        std::streamsize bytes_read = input_file.gcount();
        if (bytes_read <= 0) break;

        size_t num_blocks = bytes_read / 16;
        size_t remaining_bytes = bytes_read % 16;

        if (num_blocks > 0) {
            auto t_start = std::chrono::high_resolution_clock::now();

            // Transferencia de datos Host-to-Device (H2D) a través de PCIe
            cudaMemcpy(d_input, h_buffer, num_blocks * 16, cudaMemcpyHostToDevice);

            auto t_mid1 = std::chrono::high_resolution_clock::now();

            // Configuración del Kernel de CUDA (Bloques de 256 hilos)
            int threadsPerBlock = 256;
            int blocksPerGrid = (num_blocks + threadsPerBlock - 1) / threadsPerBlock;

            // Lanzamiento del Kernel en la GPU
            aes_ctr_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_input, d_output, num_blocks, global_block_idx, nonce_val);
            
            // Esperar sincronización y comprobar errores de ejecución
            cudaDeviceSynchronize();

            auto t_mid2 = std::chrono::high_resolution_clock::now();

            err = cudaGetLastError();
            if (err != cudaSuccess) {
                std::cerr << "[-] Error en ejecucion del Kernel CUDA: " << cudaGetErrorString(err) << std::endl;
                cudaFree(d_input);
                cudaFree(d_output);
                cudaFreeHost(h_buffer);
                return false;
            }

            // Transferencia de datos Device-to-Host (D2H) de vuelta a la CPU
            cudaMemcpy(h_buffer, d_output, num_blocks * 16, cudaMemcpyDeviceToHost);

            auto t_end = std::chrono::high_resolution_clock::now();

            std::chrono::duration<double, std::milli> transfer_h2d = t_mid1 - t_start;
            std::chrono::duration<double, std::milli> kernel_dur = t_mid2 - t_mid1;
            std::chrono::duration<double, std::milli> transfer_d2h = t_end - t_mid2;

            total_kernel_time_ms += kernel_dur.count();
            total_transfer_time_ms += transfer_h2d.count() + transfer_d2h.count();
        }


        // Bloque parcial ejecutado en el Host (CPU) al final del archivo
        if (remaining_bytes > 0) {
            unsigned char counter_block[16];
            unsigned char keystream[16];
            for (int i = 0; i < 8; ++i) counter_block[i] = nonce[i];
            
            size_t current_global_idx = global_block_idx + num_blocks;
            for (int i = 0; i < 8; ++i) {
                counter_block[15 - i] = (unsigned char)((current_global_idx >> (i * 8)) & 0xFF);
            }
            
            aes128_encrypt_block(&h_schedule, counter_block, keystream);

            size_t offset = num_blocks * 16;
            for (size_t i = 0; i < remaining_bytes; ++i) {
                h_buffer[offset + i] ^= keystream[i];
            }
            
            global_block_idx += 1;
        }

        // Escribir los datos cifrados/descifrados al archivo de salida
        output_file.write(reinterpret_cast<const char*>(h_buffer), bytes_read);

        global_block_idx += num_blocks;
    }

    // Liberar recursos
    cudaFree(d_input);
    cudaFree(d_output);
    cudaFreeHost(h_buffer);

    input_file.close();
    output_file.close();
    return true;
}
