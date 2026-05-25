// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS:
// - Con g++ (MinGW):
//   g++ -O3 -o bin/aes_seq.exe sequential/main_seq.cpp sequential/aes_sequential.cpp common/aes_core.cpp
//
// - Con cl (MSVC Developer Command Prompt):
//   cl /EHsc /O2 /Fe:bin\aes_seq.exe sequential\main_seq.cpp sequential\aes_sequential.cpp common\aes_core.cpp
// ========================================================================================

#include "aes_sequential.h"
#include "../common/aes_core.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <emmintrin.h> // Cabecera para intrínsecos SSE2 (SIMD)


bool encrypt_decrypt_aes_ctr_sequential(const std::string& input_path, 
                                        const std::string& output_path, 
                                        const unsigned char* key, 
                                        const unsigned char* nonce) {
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

    // Buffer de 1 MB (es múltiplo perfecto de 16: 65,536 bloques)
    const size_t BUFFER_SIZE = 1024 * 1024;
    std::vector<unsigned char> buffer(BUFFER_SIZE);

    unsigned char counter_block[16];
    // Rellenar los primeros 8 bytes con el nonce
    for (int i = 0; i < 8; ++i) counter_block[i] = nonce[i];

    unsigned char keystream[16];
    size_t global_block_idx = 0;

    while (input_file) {
        input_file.read(reinterpret_cast<char*>(buffer.data()), BUFFER_SIZE);
        std::streamsize bytes_read = input_file.gcount();
        if (bytes_read <= 0) break;

        size_t num_blocks = bytes_read / 16;
        size_t remaining_bytes = bytes_read % 16;

        // 1. Procesar todos los bloques completos del buffer usando SIMD (SSE2)
        for (size_t block_idx = 0; block_idx < num_blocks; ++block_idx) {
            size_t current_global_idx = global_block_idx + block_idx;

            // Generar el contador en big-endian (últimos 8 bytes)
            for (int i = 0; i < 8; ++i) {
                counter_block[15 - i] = (unsigned char)((current_global_idx >> (i * 8)) & 0xFF);
            }

            // Cifrar el contador para obtener el keystream
            aes128_encrypt_block(&schedule, counter_block, keystream);

            // Cargar 16 bytes de datos y 16 bytes de keystream en registros vectoriales SSE2 (128 bits)
            __m128i data_vec = _mm_loadu_si128(reinterpret_cast<const __m128i*>(buffer.data() + block_idx * 16));
            __m128i key_vec = _mm_loadu_si128(reinterpret_cast<const __m128i*>(keystream));
            
            // Operación XOR paralela de 128 bits en una sola instrucción de CPU
            __m128i result_vec = _mm_xor_si128(data_vec, key_vec);
            
            // Almacenar el resultado de vuelta en el buffer
            _mm_storeu_si128(reinterpret_cast<__m128i*>(buffer.data() + block_idx * 16), result_vec);
        }

        // 2. Procesar el bloque parcial restante si es el fin del archivo
        if (remaining_bytes > 0) {
            size_t current_global_idx = global_block_idx + num_blocks;
            
            // Generar contador big-endian para el bloque final parcial
            for (int i = 0; i < 8; ++i) {
                counter_block[15 - i] = (unsigned char)((current_global_idx >> (i * 8)) & 0xFF);
            }
            
            aes128_encrypt_block(&schedule, counter_block, keystream);

            size_t offset = num_blocks * 16;
            for (size_t i = 0; i < remaining_bytes; ++i) {
                buffer[offset + i] ^= keystream[i];
            }
            
            global_block_idx += 1; // Contabilizar el bloque parcial
        }

        // Escribir los datos procesados en el archivo de salida
        output_file.write(reinterpret_cast<const char*>(buffer.data()), bytes_read);

        global_block_idx += num_blocks;
    }

    input_file.close();
    output_file.close();
    return true;
}
