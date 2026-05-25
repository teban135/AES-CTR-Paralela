// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS:
// - Con NVIDIA nvcc:
//   nvcc -O3 -o bin/aes_cuda.exe cuda/main_cuda.cu cuda/aes_cuda.cu
// ========================================================================================


#include <iostream>
#include <fstream>
#include <chrono>
#include <string>
#include <cstdlib>
#include <cuda_runtime.h>
#include "aes_cuda.h"

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
    std::cout << "  CIFRADOR PARALELO MASIVO AES-128-CTR CON CUDA EN GPU (FASE 4)        " << std::endl;
    std::cout << "======================================================================" << std::endl;

    if (argc < 5) {
        std::cout << "Uso: " << argv[0] << " <arch_entrada> <arch_salida> <clave_hex> <nonce_hex>" << std::endl;
        std::cout << "Parámetros:" << std::endl;
        std::cout << "  - <clave_hex> : 32 caracteres hexadecimales (128 bits / 16 bytes)" << std::endl;
        std::cout << "  - <nonce_hex> : 16 caracteres hexadecimales (64 bits / 8 bytes)" << std::endl;
        std::cout << "\nEjemplo rápido de cifrado:" << std::endl;
        std::cout << "  " << argv[0] << " data/input/test_100mb.txt data/output/encrypted_100mb_cuda.bin 000102030405060708090a0b0c0d0e0f 0123456789abcdef" << std::endl;
        return 1;
    }

    std::string input_path = argv[1];
    std::string output_path = argv[2];
    std::string key_hex = argv[3];
    std::string nonce_hex = argv[4];

    // Mostrar información de la GPU asignada por el sistema
    int deviceId;
    cudaGetDevice(&deviceId);
    cudaDeviceProp props;
    cudaGetDeviceProperties(&props, deviceId);
    
    std::cout << "[*] Dispositivo CUDA Activo: " << props.name << std::endl;
    std::cout << "    Memoria Global Total   : " << props.totalGlobalMem / (1024 * 1024) << " MB" << std::endl;
    std::cout << "    Capacidad de Cómputo   : " << props.major << "." << props.minor << std::endl;

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

    std::cout << "[*] Iniciando cifrado/descifrado masivo en GPU..." << std::endl;
    std::cout << "    Archivo Entrada : " << input_path << std::endl;
    std::cout << "    Archivo Salida  : " << output_path << std::endl;

    // Medición de rendimiento
    double total_kernel_time_ms = 0.0;
    double total_transfer_time_ms = 0.0;

    auto start_time = std::chrono::high_resolution_clock::now();

    bool success = encrypt_decrypt_aes_ctr_cuda(input_path, output_path, key, nonce, total_kernel_time_ms, total_transfer_time_ms);

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> duration = end_time - start_time;

    if (success) {
        std::cout << "[+] ¡Proceso completado exitosamente en GPU!" << std::endl;

        // Calcular tamaño de archivo para Throughput
        std::ifstream file(input_path, std::ios::binary | std::ios::ate);
        if (file) {
            std::streamsize file_size = file.tellg();
            double size_mb = static_cast<double>(file_size) / (1024.0 * 1024.0);
            double seconds = duration.count() / 1000.0;
            double throughput = size_mb / seconds;

            double kernel_seconds = total_kernel_time_ms / 1000.0;
            double transfer_seconds = total_transfer_time_ms / 1000.0;
            double net_throughput = (kernel_seconds > 0) ? (size_mb / kernel_seconds) : 0.0;

            std::cout << "\n=================== MÉTRICAS DE RENDIMIENTO (CUDA) =============" << std::endl;
            std::cout << "  Tamaño del Archivo   : " << size_mb << " MB (" << file_size << " bytes)" << std::endl;
            std::cout << "  Tiempo total (E/S)   : " << duration.count() << " ms (" << seconds << " segundos)" << std::endl;
            std::cout << "  Tiempo de GPU Neto   : " << total_kernel_time_ms << " ms (" << kernel_seconds << " segundos)" << std::endl;
            std::cout << "  Tiempo de Copia PCIe : " << total_transfer_time_ms << " ms (" << transfer_seconds << " segundos)" << std::endl;
            std::cout << "  Throughput (E/S)     : " << throughput << " MB/s" << std::endl;
            std::cout << "  Throughput GPU Neto  : " << net_throughput << " MB/s" << std::endl;
            std::cout << "===============================================================" << std::endl;
        }
    } else {
        std::cerr << "[-] Error: El proceso de cifrado/descifrado en GPU falló." << std::endl;
        return 1;
    }

    return 0;
}
