// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS:
// - Con g++ (MinGW):
//   g++ -O3 -fopenmp -o bin/aes_omp.exe openmp/main_omp.cpp openmp/aes_openmp.cpp common/aes_core.cpp
//
// - Con cl (MSVC Developer Command Prompt):
//   cl /EHsc /O2 /openmp /Fe:bin\aes_omp.exe openmp\main_omp.cpp openmp\aes_openmp.cpp common\aes_core.cpp
// ========================================================================================

#include "aes_openmp.h"
#include "../common/aes_core.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <omp.h>
#include <emmintrin.h>
#include <chrono>

bool encrypt_decrypt_aes_ctr_openmp(const std::string& input_path, 
                                    const std::string& output_path, 
                                    const unsigned char* key, 
                                    const unsigned char* nonce,
                                    int num_threads,
                                    double& total_omp_time_ms) {
    total_omp_time_ms = 0.0;

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

    // Expandir la clave AES
    AESKeySchedule schedule;
    aes128_expand_key(key, &schedule);

    // Buffer de 8 MB (es múltiplo perfecto de 16: 524,288 bloques)
    // El buffer más grande amortiza la creación y sincronización de hilos en OpenMP
    const size_t BUFFER_SIZE = 8 * 1024 * 1024;
    std::vector<unsigned char> buffer(BUFFER_SIZE);

    size_t global_block_idx = 0;

    // Configurar número de hilos de OpenMP
    omp_set_num_threads(num_threads);

    while (input_file) {
        input_file.read(reinterpret_cast<char*>(buffer.data()), BUFFER_SIZE);
        std::streamsize bytes_read = input_file.gcount();
        if (bytes_read <= 0) break;

        size_t num_blocks = bytes_read / 16;
        size_t remaining_bytes = bytes_read % 16;

        if (num_blocks > 0) {
            auto omp_start = std::chrono::high_resolution_clock::now();

            // Paralelización del procesamiento de bloques usando OpenMP
            // schedule(static, 64) distribuye el trabajo en chunks de 1 KB para evitar False Sharing
            #pragma omp parallel for schedule(static, 64)
            for (long long block_idx = 0; block_idx < (long long)num_blocks; ++block_idx) {
                // Variables locales (privadas por hilo)
                unsigned char counter_block[16];
                unsigned char keystream[16];

                // Copiar el nonce
                for (int i = 0; i < 8; ++i) counter_block[i] = nonce[i];

                size_t current_global_idx = global_block_idx + block_idx;
                
                // Generar el contador en big-endian
                for (int i = 0; i < 8; ++i) {
                    counter_block[15 - i] = (unsigned char)((current_global_idx >> (i * 8)) & 0xFF);
                }

                // Cifrar el contador
                aes128_encrypt_block(&schedule, counter_block, keystream);

                // Vectorización SIMD (SSE2) a nivel de cada hilo
                __m128i data_vec = _mm_loadu_si128(reinterpret_cast<const __m128i*>(buffer.data() + block_idx * 16));
                __m128i key_vec = _mm_loadu_si128(reinterpret_cast<const __m128i*>(keystream));
                __m128i result_vec = _mm_xor_si128(data_vec, key_vec);
                _mm_storeu_si128(reinterpret_cast<__m128i*>(buffer.data() + block_idx * 16), result_vec);
            }

            auto omp_end = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> omp_dur = omp_end - omp_start;
            total_omp_time_ms += omp_dur.count();
        }

        // Bloque parcial ejecutado de forma secuencial segura al final del archivo
        if (remaining_bytes > 0) {
            unsigned char counter_block[16];
            unsigned char keystream[16];
            for (int i = 0; i < 8; ++i) counter_block[i] = nonce[i];
            
            size_t current_global_idx = global_block_idx + num_blocks;
            for (int i = 0; i < 8; ++i) {
                counter_block[15 - i] = (unsigned char)((current_global_idx >> (i * 8)) & 0xFF);
            }
            
            aes128_encrypt_block(&schedule, counter_block, keystream);

            size_t offset = num_blocks * 16;
            for (size_t i = 0; i < remaining_bytes; ++i) {
                buffer[offset + i] ^= keystream[i];
            }
            
            global_block_idx += 1;
        }

        // Escribir los datos cifrados/descifrados en el archivo de salida
        output_file.write(reinterpret_cast<const char*>(buffer.data()), bytes_read);

        global_block_idx += num_blocks;
    }

    input_file.close();
    output_file.close();
    return true;
}
