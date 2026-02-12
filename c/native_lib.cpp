#include <cstring>
#include <cstdlib>
#include <iostream>
#include <string>
#include <fstream>
#include <vector>
#include <cmath>
#include <algorithm>
#include <filesystem>
#include "chaos.h"
#include "sha256.h" // Needed for sha256_hash in file impl

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "ChaosCryptNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#define LOGI(...)
#define LOGE(...)
#endif

namespace fs = std::filesystem;

// Missing implementations from chaos.cpp, ported from chaos_omp.cpp (Single Threaded)

CHAOS_OPERATION_RESULT encryptFileWithKey(std::string key, std::string inputPath, std::string outputPath) {
    CHAOS_OPERATION_RESULT result = {0, "", ""};

    if (key.length() < 8 || key.length() > 256) {
        result.errorMsg = "Key must be between 8 and 256 characters.";
        return result; 
    }
    if (inputPath.empty() || outputPath.empty()) {
        result.errorMsg = "File paths cannot be empty.";
        return result;
    }

    uint64_t fileLength = 0;
    auto start = std::chrono::steady_clock::now();

    // Cross-platform file path handling
    // Android/Linux use standard paths. Windows might need wstring (handled in chaos_omp but here we simplify for mobile)
    std::ifstream file(inputPath, std::ios::binary);
    std::ofstream outputFile(outputPath, std::ios::binary);

    if (!file) {
        result.success = 0;
        result.errorMsg = "Cannot open input file.";
        return result;
    }
    if (!outputFile) {
        result.success = 0;
        result.errorMsg = "Cannot open output file.";
        return result;
    }

    double x0, y0, z0, u, r, l;
    std::string hash = sha256_hash(key);
    generateRandom3(hash, x0, y0, z0, u, r, l);

    file.seekg(0, std::ios::end);
    std::streampos fileSize = file.tellg();
    fileLength = (uint64_t) fileSize;
    
    // Write header
    std::string emLenStr = "";
    Len_t lenBit;
    lenBit.len64 = static_cast<uint64_t>(fileSize);
    getEmLenStr(lenBit, emLenStr);
    outputFile.write(emLenStr.c_str(), emLenStr.length() * sizeof(char));

    file.seekg(0, std::ios::beg);

    // Single threaded processing
    std::vector<int> blockSizeArr = splitBlockSize(fileLength);
    int blockIndex = 0;
    int indexAll = blockSizeArr.size();
    
    // Buffer for reading
    // reuse logic
    for (blockIndex = 0; blockIndex < indexAll; blockIndex = blockIndex + 2) {
        int currBlockSize = blockSizeArr[blockIndex];
        unsigned char *buffer = (unsigned char *) malloc(currBlockSize * sizeof(unsigned char));
        memset(buffer, 48, currBlockSize);

        file.read(reinterpret_cast<char *>(buffer), currBlockSize);
        // Handle read count? splitBlockSize ensures exact fit? 
        // splitBlockSize creates blocks that sum up to size.
        // But read might fail? 
        // chaos_omp logic uses complex read/seek. Simple read should work if blocks are sequential.
        
        encode_Block3(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0, z0, u, r, l);
        
        outputFile.write(reinterpret_cast<char *>(buffer), currBlockSize * sizeof(char));
        free(buffer);
    }

    file.close();
    outputFile.close();

    auto end = std::chrono::steady_clock::now();
    auto durationMill = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    // Speed in Gbit/s
    auto speed = static_cast<float>(fileLength) * 8 / 1024 / 1024 / 1024 / static_cast<float>(durationMill.count()) * 1000;
    
    result.mill = durationMill.count();
    result.size = fileLength;
    result.speed = speed;
    result.success = 1;
    return result;
}

CHAOS_OPERATION_RESULT decryptFileWithKey(std::string key, std::string inputPath, std::string outputPath) {
    CHAOS_OPERATION_RESULT result = {0, "", ""};

    if (key.length() < 8 || key.length() > 256) {
        result.errorMsg = "Key invalid.";
        return result; 
    }

    auto start = std::chrono::steady_clock::now();
    uint64_t fileLength = 0;

    std::ifstream file(inputPath, std::ios::binary);
    std::ofstream outputFile(outputPath, std::ios::binary);

    if (!file) {
        result.errorMsg = "Cannot open input file.";
        return result;
    }

    double x0, y0, z0, u, r, l;
    std::string hash = sha256_hash(key);
    generateRandom3(hash, x0, y0, z0, u, r, l);

    // Read header
    // 2 bytes for len8
    char lenbf[3];
    file.read(lenbf, 2);
    lenbf[2] = '\0';
    int len8 = std::stoi(lenbf, 0, 16);
    
    int lenBufferLen = len8 / 4;
    char *lenBuffer = (char *) malloc((lenBufferLen + 1) * sizeof(char));
    file.read(lenBuffer, lenBufferLen);
    lenBuffer[lenBufferLen] = '\0';
    
    uint64_t len64 = static_cast<uint64_t>(std::stoi(lenBuffer, 0, 16));
    uint64_t fileSize = len64;
    fileLength = fileSize;
    
    free(lenBuffer);
    
    std::vector<int> blockSizeArr = splitBlockSize(fileSize);
    int blockIndex = 0;
    int indexAll = blockSizeArr.size();

    for (blockIndex = 0; blockIndex < indexAll; blockIndex = blockIndex + 2) {
        int currBlockSize = blockSizeArr[blockIndex];
        unsigned char *buffer = (unsigned char *) malloc(currBlockSize * sizeof(unsigned char));
        memset(buffer, 48, currBlockSize);

        file.read(reinterpret_cast<char *>(buffer), currBlockSize);
        
        decode_Block3(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0, z0, u, r, l);
        
        outputFile.write(reinterpret_cast<char *>(buffer), currBlockSize * sizeof(char));
        free(buffer);
    }

    file.close();
    outputFile.close();

    auto end = std::chrono::steady_clock::now();
    auto durationMill = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    result.mill = durationMill.count();
    result.size = fileLength;
    result.success = 1;
    return result;
}


extern "C" {

    // Helper to duplicate string for return to Dart (Dart will free this)
    char* string_to_char(const std::string& str) {
        char* cstr = (char*)malloc(str.length() + 1);
        if (cstr == nullptr) return nullptr;
        std::strcpy(cstr, str.c_str());
        return cstr;
    }

    // Free memory allocated by this library
    void free_memory(void* ptr) {
        if (ptr != nullptr) {
            free(ptr);
        }
    }

    // Encrypt string with key
    // Returns a newly allocated char* that must be freed by caller using free_memory
    char* encrypt_string(char* key, char* input) {
        if (key == nullptr || input == nullptr) return nullptr;
        std::string keyStr(key);
        std::string inputStr(input);
        
        CHAOS_OPERATION_RESULT result = encryptStrWithKey(keyStr, inputStr);
        
        if (result.success) {
            return string_to_char(result.result);
        } else {
            LOGE("Encrypt string failed: %s", result.errorMsg.c_str());
            return nullptr;
        }
    }

    // Decrypt string with key
    char* decrypt_string(char* key, char* input) {
        if (key == nullptr || input == nullptr) return nullptr;
        std::string keyStr(key);
        std::string inputStr(input);
        
        CHAOS_OPERATION_RESULT result = decryptStrWithKey(keyStr, inputStr);
        
        if (result.success) {
            return string_to_char(result.result);
        } else {
            LOGE("Decrypt string failed: %s", result.errorMsg.c_str());
            return nullptr;
        }
    }

    // Encrypt file with key
    // Returns "SUCCESS|mill|speed" or "ERROR|msg"
    char* encrypt_file(char* key, char* inputPath, char* outputPath) {
        if (key == nullptr || inputPath == nullptr || outputPath == nullptr) return string_to_char("ERROR|Invalid arguments");
        std::string keyStr(key);
        std::string input(inputPath);
        std::string output(outputPath);

        CHAOS_OPERATION_RESULT result = encryptFileWithKey(keyStr, input, output);
        
        if (result.success) {
            std::string res = "SUCCESS|" + std::to_string(result.mill) + "|" + std::to_string(result.speed);
            return string_to_char(res);
        } else {
             return string_to_char("ERROR|" + result.errorMsg);
        }
    }

    // Decrypt file with key
    char* decrypt_file(char* key, char* inputPath, char* outputPath) {
        if (key == nullptr || inputPath == nullptr || outputPath == nullptr) return string_to_char("ERROR|Invalid arguments");
        std::string keyStr(key);
        std::string input(inputPath);
        std::string output(outputPath);

        CHAOS_OPERATION_RESULT result = decryptFileWithKey(keyStr, input, output);
        
        if (result.success) {
            // Calculate speed for decryption if not set
            if (result.speed == 0 && result.mill > 0) {
                 result.speed = static_cast<float>(result.size) * 8 / 1024 / 1024 / 1024 / static_cast<float>(result.mill) * 1000;
            }
             std::string res = "SUCCESS|" + std::to_string(result.mill) + "|" + std::to_string(result.speed);
             return string_to_char(res);
        } else {
             return string_to_char("ERROR|" + result.errorMsg);
        }
    }

    // Multi-threaded File Encryption (Android Only - OpenMP)
    // Returns formatted string: "SUCCESS|time_ms|speed_mbps" or "ERROR|msg"
    char* encrypt_file_mt(int threads, char* key, char* inputPath, char* outputPath) {
        if (key == nullptr || inputPath == nullptr || outputPath == nullptr) return string_to_char("ERROR|Invalid arguments");
        
        std::string keyStr(key);
        std::string input(inputPath);
        std::string output(outputPath);

        CHAOS_OPERATION_RESULT result;

        #ifdef _OPENMP
        // If threads is 1, we can still use OMP or fallback. OMP with 1 thread is fine.
        result = encryptFileWithKey_OMP(threads, keyStr, input, output);
        #else
        // Fallback for non-OMP platforms
        LOGI("OpenMP not supported, falling back to single thread");
        result = encryptFileWithKey(keyStr, input, output);
        #endif

        if (result.success) {
            std::string res = "SUCCESS|" + std::to_string(result.mill) + "|" + std::to_string(result.speed);
            return string_to_char(res);
        } else {
            return string_to_char("ERROR|" + result.errorMsg);
        }
    }
}
