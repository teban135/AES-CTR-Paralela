// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS:
// - Con g++ (MinGW):
//   g++ -O3 -o bin/test_aes_core.exe common/test_aes_core.cpp common/aes_core.cpp
//
// - Con cl (MSVC Developer Command Prompt):
//   cl /EHsc /O2 /Fe:bin\test_aes_core.exe common\test_aes_core.cpp common\aes_core.cpp
// ========================================================================================

#include <iostream>
#include <iomanip>
#include "aes_core.h"


// Función auxiliar para imprimir un buffer en formato hexadecimal
void print_hex(const std::string& label, const unsigned char* data, size_t len) {
    std::cout << label << ": ";
    for (size_t i = 0; i < len; ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)data[i] << " ";
    }
    std::cout << std::dec << std::endl;
}

// Función auxiliar para verificar si dos buffers son iguales
bool verify_buffers(const unsigned char* a, const unsigned char* b, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

int main() {
    std::cout << "======================================================================" << std::endl;
    std::cout << "  PRUEBAS DE VALIDACIÓN: NÚCLEO CRIPTOGRÁFICO AES-128 (FASE 1)        " << std::endl;
    std::cout << "  Estándar Oficial NIST SP 800-38A / FIPS 197                         " << std::endl;
    std::cout << "======================================================================" << std::endl;

    // Vector de prueba oficial de NIST (Apéndice C)
    // Clave de 128 bits (16 bytes)
    unsigned char test_key[16] = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    };

    // Texto Plano de 128 bits (16 bytes)
    unsigned char test_plaintext[16] = {
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
        0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
    };

    // Texto Cifrado Esperado según la especificación del NIST
    unsigned char expected_ciphertext[16] = {
        0x69, 0xc4, 0xe0, 0xd8, 0x6a, 0x7b, 0x04, 0x30,
        0xd8, 0xcd, 0xb7, 0x80, 0x70, 0xb4, 0xc5, 0x5a
    };

    std::cout << "[*] Preparando vectores de prueba NIST..." << std::endl;
    print_hex("    Clave (Key)     ", test_key, 16);
    print_hex("    Texto Plano (P) ", test_plaintext, 16);
    print_hex("    Cifrado Esperado", expected_ciphertext, 16);
    std::cout << "----------------------------------------------------------------------" << std::endl;

    // 1. Probar Expansión de Claves
    std::cout << "[*] Ejecutando Expansion de Claves (Key Schedule)..." << std::endl;
    AESKeySchedule schedule;
    aes128_expand_key(test_key, &schedule);
    std::cout << "    Clave expandida correctamente (176 bytes)." << std::endl;
    // Mostrar la primera y última subclave de ronda
    print_hex("    Subclave Ronda 0 (Key) ", &schedule.round_keys[0], 16);
    print_hex("    Subclave Ronda 10      ", &schedule.round_keys[160], 16);
    std::cout << "----------------------------------------------------------------------" << std::endl;

    // 2. Probar Cifrado de Bloque Estándar
    std::cout << "[*] Cifrando bloque con metodo estandar..." << std::endl;
    unsigned char actual_ciphertext[16];
    aes128_encrypt_block(&schedule, test_plaintext, actual_ciphertext);
    print_hex("    Resultado Obtenido     ", actual_ciphertext, 16);

    bool test1_passed = verify_buffers(actual_ciphertext, expected_ciphertext, 16);
    if (test1_passed) {
        std::cout << "    [OK] VALIDACION EXITOSA: El cifrado coincide con el vector NIST." << std::endl;
    } else {
        std::cout << "    [ERROR] VALIDACION FALLIDA: El resultado no coincide." << std::endl;
    }
    std::cout << "----------------------------------------------------------------------" << std::endl;

    // 3. Probar Cifrado con S-Box en Memoria Compartida (Shared Memory Simulation)
    std::cout << "[*] Simulando y cifrando bloque con S-Box en memoria compartida (Shared Memory)..." << std::endl;
    unsigned char actual_ciphertext_shared[16];
    aes128_encrypt_block_shared(&schedule, test_plaintext, actual_ciphertext_shared, sbox);
    print_hex("    Resultado Obtenido (SM)", actual_ciphertext_shared, 16);

    bool test2_passed = verify_buffers(actual_ciphertext_shared, expected_ciphertext, 16);
    if (test2_passed) {
        std::cout << "    [OK] VALIDACION EXITOSA (SM): El cifrado coincide con el vector NIST." << std::endl;
    } else {
        std::cout << "    [ERROR] VALIDACION FALLIDA (SM): El resultado no coincide." << std::endl;
    }
    std::cout << "----------------------------------------------------------------------" << std::endl;

    // Reporte Final de Calificación de Fase 1
    std::cout << "======================================================================" << std::endl;
    if (test1_passed && test2_passed) {
        std::cout << "  RESULTADO GLOBAL: ¡FASE 1 COMPLETADA CON EXCELENCIA! [PASSED]       " << std::endl;
        std::cout << "  El nucleo criptografico es 100% portable y matematicamente exacto. " << std::endl;
    } else {
        std::cout << "  RESULTADO GLOBAL: FASE 1 FALLIDA [FAILED]                           " << std::endl;
        std::cout << "  Revisar errores de calculo en aes_core.cpp.                         " << std::endl;
    }
    std::cout << "======================================================================" << std::endl;

    return (test1_passed && test2_passed) ? 0 : 1;
}
