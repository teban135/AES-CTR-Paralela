// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS:
// - Con g++ (MinGW):
//   g++ -O3 -fopenmp -o bin/aes_omp.exe openmp/main_omp.cpp openmp/aes_openmp.cpp common/aes_core.cpp
//
// - Con cl (MSVC Developer Command Prompt):
//   cl /EHsc /O2 /openmp /Fe:bin\aes_omp.exe openmp\main_omp.cpp openmp\aes_openmp.cpp common\aes_core.cpp
// ========================================================================================

#include <iostream>
#include <fstream>
#include <chrono>
#include <string>
#include <cstdlib>
#include <omp.h>
#include "aes_openmp.h"

// Función auxiliar para convertir una cadena hexadecimal en un array de bytes
bool hex_to_bytes(const std::string& hex, unsigned char* bytes, size_t target_len) {
    if (hex.length() != target_len * 2) return false;
    for (size_t i = 0; i < target_len; ++i) {
        std::string byteString = hex.substr(i * 2, 2);
        char* end;
        long byte = std::strtol(byteString.c_str(), &end, 16);
        if (*end != '\0') return false;
        bytes[i] = static_cast<unsigned char>(byte);
    }
    return true;
}

int main(int argc, char* argv[]) {
    std::cout << "======================================================================" << std::endl;
    std::cout << "  CIFRADOR PARALELO AES-128-CTR CON OPENMP Y SIMD (FASE 3)             " << std::endl;
    std::cout << "======================================================================" << std::endl;

    if (argc < 5) {
        std::cout << "Uso: " << argv[0] << " <arch_entrada> <arch_salida> <clave_hex> <nonce_hex> [num_hilos]" << std::endl;
        std::cout << "Parámetros:" << std::endl;
        std::cout << "  - <clave_hex> : 32 caracteres hexadecimales (128 bits / 16 bytes)" << std::endl;
        std::cout << "  - <nonce_hex> : 16 caracteres hexadecimales (64 bits / 8 bytes)" << std::endl;
        std::cout << "  - [num_hilos] : (Opcional) Número de hilos. Por defecto usa el máximo disponible." << std::endl;
        std::cout << "\nEjemplo rápido de cifrado:" << std::endl;
        std::cout << "  " << argv[0] << " data/input/test_100mb.txt data/output/encrypted_100mb.bin 000102030405060708090a0b0c0d0e0f 0123456789abcdef 8" << std::endl;
        return 1;
    }

    std::string input_path = argv[1];
    std::string output_path = argv[2];
    std::string key_hex = argv[3];
    std::string nonce_hex = argv[4];

    int max_threads = omp_get_max_threads();
    int num_threads = max_threads;
    if (argc >= 6) {
        num_threads = std::atoi(argv[5]);
        if (num_threads <= 0) {
            std::cerr << "[-] Advertencia: Hilos inválidos. Usando máximo disponible (" << max_threads << ")." << std::endl;
            num_threads = max_threads;
        }
    }

    unsigned char key[16];
    unsigned char nonce[8];

    // Validar y parsear clave hexadecimal
    if (!hex_to_bytes(key_hex, key, 16)) {
        std::cerr << "[-] Error: La clave hexadecimal debe tener exactamente 32 caracteres hexadecimales válidos." << std::endl;
        return 1;
    }

    // Validar y parsear nonce hexadecimal
    if (!hex_to_bytes(nonce_hex, nonce, 8)) {
        std::cerr << "[-] Error: El nonce hexadecimal debe tener exactamente 16 caracteres hexadecimales válidos." << std::endl;
        return 1;
    }

    std::cout << "[*] Iniciando cifrado/descifrado en paralelo..." << std::endl;
    std::cout << "    Archivo Entrada : " << input_path << std::endl;
    std::cout << "    Archivo Salida  : " << output_path << std::endl;
    std::cout << "    Hilos Activos   : " << num_threads << " (Máximo en hardware: " << max_threads << ")" << std::endl;

    // Medición de rendimiento
    double total_omp_time_ms = 0.0;
    auto start_time = std::chrono::high_resolution_clock::now();

    bool success = encrypt_decrypt_aes_ctr_openmp(input_path, output_path, key, nonce, num_threads, total_omp_time_ms);

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> duration = end_time - start_time;

    if (success) {
        std::cout << "[+] ¡Proceso completado exitosamente!" << std::endl;

        // Calcular tamaño de archivo para Throughput
        std::ifstream file(input_path, std::ios::binary | std::ios::ate);
        if (file) {
            std::streamsize file_size = file.tellg();
            double size_mb = static_cast<double>(file_size) / (1024.0 * 1024.0);
            double seconds = duration.count() / 1000.0;
            double throughput = size_mb / seconds;

            double omp_seconds = total_omp_time_ms / 1000.0;
            double net_throughput = (omp_seconds > 0) ? (size_mb / omp_seconds) : 0.0;

            std::cout << "\n=================== MÉTRICAS DE RENDIMIENTO (OMP) ==============" << std::endl;
            std::cout << "  Tamaño del Archivo   : " << size_mb << " MB (" << file_size << " bytes)" << std::endl;
            std::cout << "  Tiempo total (E/S)   : " << duration.count() << " ms (" << seconds << " segundos)" << std::endl;
            std::cout << "  Tiempo de CPU Neto   : " << total_omp_time_ms << " ms (" << omp_seconds << " segundos)" << std::endl;
            std::cout << "  Throughput (E/S)     : " << throughput << " MB/s" << std::endl;
            std::cout << "  Throughput CPU Neto  : " << net_throughput << " MB/s" << std::endl;
            std::cout << "===============================================================" << std::endl;
        }
    } else {
        std::cerr << "[-] Error: El proceso de cifrado/descifrado falló." << std::endl;
        return 1;
    }

    return 0;
}
