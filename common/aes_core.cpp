// ========================================================================================
// COMANDOS DE COMPILACIÓN SUGERIDOS (junto con test_aes_core.cpp):
// - Con g++ (MinGW):
//   g++ -O3 -o bin/test_aes_core.exe common/test_aes_core.cpp common/aes_core.cpp
//
// - Con cl (MSVC Developer Command Prompt):
//   cl /EHsc /O2 /Fe:bin\test_aes_core.exe common\test_aes_core.cpp common\aes_core.cpp
// ========================================================================================

#include "aes_core.h"


// Tabla S-Box Rijndael estándar
const unsigned char sbox[256] = {





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

// Constantes de Rondas para Expansión de Claves
static const unsigned char rcon[10] = {
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
};




// Multiplicación en Campo de Galois (GF(2^8)) por 2
HD_QUALIFIER static inline unsigned char galois_mul2(unsigned char x) {
    return (x & 0x80) ? ((x << 1) ^ 0x1b) : (x << 1);
}

// Multiplicación en Campo de Galois (GF(2^8)) por 3
HD_QUALIFIER static inline unsigned char galois_mul3(unsigned char x) {
    return galois_mul2(x) ^ x;
}

// Expansión de clave estándar AES-128 (16 bytes -> 176 bytes)
void aes128_expand_key(const unsigned char* key, AESKeySchedule* schedule) {

    for (int i = 0; i < 16; ++i) {
        schedule->round_keys[i] = key[i];
    }

    int bytesGenerated = 16;
    int rconIteration = 1;
    unsigned char temp[4];

    while (bytesGenerated < 176) {
        for (int i = 0; i < 4; ++i) {
            temp[i] = schedule->round_keys[bytesGenerated - 4 + i];
        }

        if (bytesGenerated % 16 == 0) {
            // RotWord
            unsigned char k = temp[0];
            temp[0] = temp[1];
            temp[1] = temp[2];
            temp[2] = temp[3];
            temp[3] = k;

            // SubWord
            temp[0] = sbox[temp[0]];
            temp[1] = sbox[temp[1]];
            temp[2] = sbox[temp[2]];
            temp[3] = sbox[temp[3]];

            // XOR con Rcon
            temp[0] ^= rcon[rconIteration - 1];
            rconIteration++;
        }

        for (int i = 0; i < 4; ++i) {
            schedule->round_keys[bytesGenerated] = schedule->round_keys[bytesGenerated - 16] ^ temp[i];
            bytesGenerated++;
        }
    }
}

// Desplazamiento de filas en la matriz de estado AES (ShiftRows)
HD_QUALIFIER static inline void shift_rows(unsigned char* state) {
    unsigned char temp;

    // Fila 1: Rotar a la izquierda por 1
    temp = state[1];
    state[1] = state[5];
    state[5] = state[9];
    state[9] = state[13];
    state[13] = temp;

    // Fila 2: Rotar a la izquierda por 2
    temp = state[2];
    state[2] = state[10];
    state[10] = temp;
    temp = state[6];
    state[6] = state[14];
    state[14] = temp;

    // Fila 3: Rotar a la izquierda por 3
    temp = state[15];
    state[15] = state[11];
    state[11] = state[7];
    state[7] = state[3];
    state[3] = temp;
}

// Mezcla de columnas en la matriz de estado AES (MixColumns)
HD_QUALIFIER static inline void mix_columns(unsigned char* state) {
    unsigned char a, b, c, d;
    for (int col = 0; col < 4; ++col) {
        int idx = col * 4;
        a = state[idx + 0];
        b = state[idx + 1];
        c = state[idx + 2];
        d = state[idx + 3];

        state[idx + 0] = galois_mul2(a) ^ galois_mul3(b) ^ c ^ d;
        state[idx + 1] = a ^ galois_mul2(b) ^ galois_mul3(c) ^ d;
        state[idx + 2] = a ^ b ^ galois_mul2(c) ^ galois_mul3(d);
        state[idx + 3] = galois_mul3(a) ^ b ^ c ^ galois_mul2(d);
    }
}

// Cifrado de un bloque de 16 bytes (AES Standard)
void aes128_encrypt_block(const AESKeySchedule* schedule, const unsigned char* plaintext, unsigned char* ciphertext) {

    unsigned char state[16];

    for (int i = 0; i < 16; ++i) {
        state[i] = plaintext[i];
    }

    // Ronda 0: AddRoundKey
    for (int i = 0; i < 16; ++i) {
        state[i] ^= schedule->round_keys[i];
    }

    // Rondas 1 a 9
    for (int round = 1; round < 10; ++round) {
        // SubBytes
        for (int i = 0; i < 16; ++i) {
            state[i] = sbox[state[i]];
        }

        // ShiftRows
        shift_rows(state);

        // MixColumns
        mix_columns(state);

        // AddRoundKey
        int round_key_offset = round * 16;
        for (int i = 0; i < 16; ++i) {
            state[i] ^= schedule->round_keys[round_key_offset + i];
        }
    }

    // Ronda Final (Ronda 10)
    // SubBytes
    for (int i = 0; i < 16; ++i) {
        state[i] = sbox[state[i]];
    }

    // ShiftRows
    shift_rows(state);

    // AddRoundKey
    for (int i = 0; i < 16; ++i) {
        state[i] ^= schedule->round_keys[160 + i];
    }

    for (int i = 0; i < 16; ++i) {
        ciphertext[i] = state[i];
    }
}

// Cifrado de un bloque de 16 bytes con S-Box local (para Shared Memory en CUDA)
HD_QUALIFIER void aes128_encrypt_block_shared(const AESKeySchedule* schedule, const unsigned char* plaintext, unsigned char* ciphertext, const unsigned char* sbox_shared) {
    unsigned char state[16];

    for (int i = 0; i < 16; ++i) {
        state[i] = plaintext[i];
    }

    // Ronda 0: AddRoundKey
    for (int i = 0; i < 16; ++i) {
        state[i] ^= schedule->round_keys[i];
    }

    // Rondas 1 a 9
    for (int round = 1; round < 10; ++round) {
        // SubBytes usando la sbox de memoria compartida
        for (int i = 0; i < 16; ++i) {
            state[i] = sbox_shared[state[i]];
        }

        // ShiftRows
        shift_rows(state);

        // MixColumns
        mix_columns(state);

        // AddRoundKey
        int round_key_offset = round * 16;
        for (int i = 0; i < 16; ++i) {
            state[i] ^= schedule->round_keys[round_key_offset + i];
        }
    }

    // Ronda Final (Ronda 10)
    // SubBytes usando la sbox de memoria compartida
    for (int i = 0; i < 16; ++i) {
        state[i] = sbox_shared[state[i]];
    }

    // ShiftRows
    shift_rows(state);

    // AddRoundKey
    for (int i = 0; i < 16; ++i) {
        state[i] ^= schedule->round_keys[160 + i];
    }

    for (int i = 0; i < 16; ++i) {
        ciphertext[i] = state[i];
    }
}
