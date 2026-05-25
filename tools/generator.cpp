// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS:
// - Con g++ (MinGW):
//   g++ -O3 -o bin/generator.exe tools/generator.cpp
//
// - Con cl (MSVC Developer Command Prompt):
//   cl /EHsc /O2 /Fe:bin\generator.exe tools\generator.cpp
// ========================================================================================

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cstdlib>

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cout << "Uso: " << argv[0] << " <ruta_salida> <tamaño_en_MB>" << std::endl;
        std::cout << "Ejemplo: " << argv[0] << " data/input/test_100mb.txt 100" << std::endl;
        return 1;
    }

    std::string ruta_salida = argv[1];
    int tamaño_mb = std::atoi(argv[2]);

    if (tamaño_mb <= 0) {
        std::cerr << "[-] Error: El tamaño en MB debe ser mayor a 0." << std::endl;
        return 1;
    }

    size_t tamaño_bytes = static_cast<size_t>(tamaño_mb) * 1024 * 1024;
    std::ofstream archivo(ruta_salida, std::ios::binary);

    if (!archivo) {
        std::cerr << "[-] Error: No se pudo crear el archivo en " << ruta_salida << std::endl;
        return 1;
    }

    std::cout << "[*] Generando archivo de " << tamaño_mb << " MB en: " << ruta_salida << " ..." << std::endl;

    // Buffer de 1 MB para escritura optimizada y rápida en disco
    const size_t tamaño_chunk = 1024 * 1024;
    std::vector<char> buffer(tamaño_chunk);

    // Patrón de texto plano para llenar el archivo
    const std::string patron = "TEXTO_DE_PRUEBA_AES_CTR_COMPUTACION_PARALELA_8VO_SEMESTRE_UNIVERSIDAD_ING_SISTEMAS_";
    for (size_t i = 0; i < tamaño_chunk; ++i) {
        buffer[i] = patron[i % patron.length()];
    }

    size_t escritos = 0;
    while (escritos < tamaño_bytes) {
        size_t a_escribir = std::min(tamaño_chunk, tamaño_bytes - escritos);
        archivo.write(buffer.data(), a_escribir);
        escritos += a_escribir;
    }

    archivo.close();
    std::cout << "[+] ¡Archivo generado exitosamente con " << escritos << " bytes!" << std::endl;
    return 0;
}
