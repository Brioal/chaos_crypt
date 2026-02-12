#ifdef _WIN32
#include <windows.h>
#endif
#include <iostream>
#include <filesystem>
#include <sstream>
#include <fstream>
#include <vector>
#include <chrono>
#include <string>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <algorithm>
#include <omp.h>
#include "chaos.h"
#include "sha256.h"
#include <set>

const double multiplier = pow(10, 16);
const double divisor = 255.0;
namespace fs = std::filesystem;
#ifdef _WIN32
// 字符串转宽字符串
std::wstring utf8_to_wstring(const std::string& str) {
    int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
    std::wstring wstr(size, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &wstr[0], size);
    wstr.pop_back(); // 去掉多余的\0
    return wstr;
}
#endif


/**
 * 有密钥-文件加密-多线程
 * @param THREAD_NUM 线程数量
 * @param key 密钥
 * @param inputPath 待加密文件
 * @param outputPath 加密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT
encryptFileWithKey_OMP(int THREAD_NUM, std::string key, std::string inputPath, std::string outputPath) {

    // 初始化结果为失败,错误信息为空
    CHAOS_OPERATION_RESULT result = {0, "", ""};

    // 必备参数检查
    // 1.密钥
    if (key.length() < 8 || key.length() > 256) {
        result.errorMsg = "Key must be between 8 and 256 characters.";
        return result;  // 如果key的长度不在8到256之间,返回错误信息
    }
    // 2.输入地址
    if (inputPath.empty()) {
        result.errorMsg = "Input file path cannot be empty.";
        return result;
    }
    // 3.输出地址
    if (inputPath.empty()) {
        result.errorMsg = "Output file path cannot be empty.";
        return result;
    }

    // 计算一个加密时间
    uint64_t fileLength = 0;
    auto start = std::chrono::steady_clock::now();
//     #ifdef _WIN32
//         std::wstring wInput = utf8_to_wstring(inputPath);
//         std::wstring wOutput = utf8_to_wstring(outputPath);
//         std::ifstream file(wInput, std::ios::binary);
//         std::ofstream outputFile(wOutput, std::ios::binary);
//     #else
       std::ifstream file(fs::u8path(inputPath).wstring(), std::ios::binary);
               std::ofstream outputFile(fs::u8path(outputPath).wstring(), std::ios::binary);
//     #endif
    if (!file) {
        result.success = 0;
        result.errorMsg = "无法打开文件,加密失败";
        return result;
    }
//     printf("执行进入了 生成随机数\n");
    double x0, y0, z0,  u, r, l;
    std::string hash = sha256_hash(key);
    generateRandom3(hash, x0, y0,  z0,u, r,l);


    // 确定文件大小
    file.seekg(0, std::ios::end);
    std::streampos fileSize = file.tellg();
    fileLength = (uint64_t) fileSize;
    // 到文件开头,写入密文前缀
    std::string emLenStr = "";
    Len_t lenBit;
    lenBit.len64 = static_cast<uint64_t>(fileSize);
    getEmLenStr(lenBit, emLenStr);
    outputFile.write(emLenStr.c_str(), emLenStr.length() * sizeof(char));
    // file.close();
    omp_set_num_threads(THREAD_NUM);
#pragma omp parallel firstprivate(x0, y0,z0, u, r,l)
    {
        std::ifstream localfile(fs::u8path(inputPath).wstring(), std::ios::binary);
        // std::ifstream threadFile = file;
        int numThreads = omp_get_num_threads();
//         printf( "Thread NUMS: %d\n", numThreads);
//         std::cout << "Thread NUMS: " << numThreads << std::endl;
        int id = omp_get_thread_num();
        // std::cout << "id: " << id << " 线程数目：" << numThreads << std::endl;

        uint64_t fileSize_own = fileSize / numThreads;
        // std::cout << "input file size: " << (uint64_t)fileSize << " B" << std::endl;
        std::vector<int> blockSizeArr = splitBlockSize(fileSize_own);

        int blockIndex = 0;
        int indexAll = blockSizeArr.size();
        uint64_t read_offset = 0;
        uint64_t write_offset = 0;
        uint64_t startLoc = id * fileSize_own;
        uint64_t limitLoc = (id + 1) * fileSize_own;
        uint64_t resetSize;
        // 实际获取长度
        int realSize;
        // std::cout << "ID: " << id << " 读取位置：" << id * fileSize_own << std::endl;
        for (blockIndex = 0; blockIndex < indexAll; blockIndex = blockIndex + 2) {
            // if (!localfile.good())
            // {
            //     std::cerr << "ID: " << id << "Error with file state." << std::endl;
            //     return 0;
            //     // 可能需要退出或采取其他措施
            //     // exit;
            // }
            // 读取当前数据块的字节数据
            int currBlockSize = blockSizeArr[blockIndex];
            unsigned char *buffer = (unsigned char *) malloc(currBlockSize * sizeof(unsigned char));
            memset(buffer, 48, currBlockSize);
            // #pragma omp critical
            //             {
            // // 更新文件状态
            // std::cout << "ID:" << id << " open: " << outputFile.is_open() << " eof: " << outputFile.eof() << " bad: " << outputFile.bad() << " fail: " << outputFile.fail() << std::endl;
            // std::cout << "ID:" << id << " open: " << file.is_open() << " eof: " << file.eof() << " bad: " << file.bad() << " fail: " << file.fail() << std::endl;

            localfile.seekg(startLoc + read_offset, std::ios::beg);
            // 获取当前文件指针的位置
            // std::cout << "ID: " << id << " 开始位置：" << startLoc + read_offset;
            std::streampos currentPosition = localfile.tellg();
            // std::cout << " 当前位置：" << currentPosition << " 限制位置: " << limitLoc - 1 << std::endl;
            resetSize = limitLoc - static_cast<uint64_t>(currentPosition);
            localfile.read(reinterpret_cast<char *>(buffer), currBlockSize);
            realSize = resetSize > currBlockSize ? localfile.gcount() : resetSize;
            // if (resetSize > currBlockSize)
            // {
            //     realSize = localfile.gcount();
            // }
            // else
            // {
            //     realSize = resetSize;
            // }

            // std::cout << "ID: " << id << " 当前位置：" << currentPosition << " 限制位置：" << limitLoc << " 剩余长度：" << resetSize << " 实际长度：" << realSize << " buffer大小：" << currBlockSize << " 矩阵宽度： " << blockSizeArr[blockIndex + 1] << std::endl;
            encode_Block3(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0,z0, u, r,l);
#pragma omp critical
            {
                outputFile.seekp(emLenStr.length() + startLoc + write_offset, std::ios::beg);
                outputFile.write(reinterpret_cast<char *>(buffer), realSize * sizeof(char));
                free(buffer);
            }

            read_offset += realSize;
            write_offset += realSize;
            // #pragma omp barrier
        }
        // }
        // #pragma omp barrier
        localfile.close();
    }
    // 剩余内容直接写入
    uint64_t reSize = fileSize - (fileSize / THREAD_NUM) * THREAD_NUM;
    if (reSize) {
        file.seekg((fileSize / THREAD_NUM) * THREAD_NUM, std::ios::beg);
        outputFile.seekp(emLenStr.length() + (fileSize / THREAD_NUM) * THREAD_NUM, std::ios::beg);
        char *buffer = (char *) malloc(reSize * sizeof(char));
        file.read(buffer, reSize);
        outputFile.write(buffer, reSize * sizeof(char));
        free(buffer);
    }
    // 关闭文件
    file.close();
    outputFile.close();
    // 计算速度
    auto end = std::chrono::steady_clock::now();
    auto durationMill = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    auto speed =
            static_cast<float >(fileLength) * 8 / 1024 / 1024 / 1024 / static_cast<float>(durationMill.count()) * 1000;
    result.mill = durationMill.count();
    result.size = fileLength;
    result.speed = speed;
    result.success = 1;
    return result;
}

CHAOS_OPERATION_RESULT
decryptFileWithKey_OMP(int THREAD_NUM, std::string key, std::string inputPath, std::string outputPath) {
    // 初始化结果为失败,错误信息为空
    CHAOS_OPERATION_RESULT result = {0, "", ""};
    // 必备参数检查
    // 1.密钥
    if (key.length() < 8 || key.length() > 256) {
        result.errorMsg = "Key must be between 8 and 256 characters.";
        return result;  // 如果key的长度不在8到256之间,返回错误信息
    }
    // 2.输入地址
    if (inputPath.empty()) {
        result.errorMsg = "Input file path cannot be empty.";
        return result;
    }
    // 3.输出地址
    if (inputPath.empty()) {
        result.errorMsg = "Output file path cannot be empty.";
        return result;
    }
    // 计算一个加密时间
    uint64_t fileLength = 0;
    auto start = std::chrono::steady_clock::now();
//     #ifdef _WIN32
//         std::wstring wInput = utf8_to_wstring(inputPath);
//         std::wstring wOutput = utf8_to_wstring(outputPath);
//         std::ifstream file(wInput, std::ios::binary);
//         std::ofstream outputFile(wOutput, std::ios::binary);
//     #else
        std::ifstream file(fs::u8path(inputPath).wstring(), std::ios::binary);
                       std::ofstream outputFile(fs::u8path(outputPath).wstring(), std::ios::binary);
//     #endif
    if (!file) {
        result.success = 0;
        result.errorMsg = "无法打开文件,加密失败";
        return result;
    }

    double x0, y0,z0, u, r,l;
    std::string hash = sha256_hash(key);
    generateRandom3(hash, x0, y0,z0, u, r,l);

    // 读取密文前缀长
    file.seekg(0, std::ios::beg);
    char *lenbf = (char *) malloc(3 * sizeof(char));
    file.read(lenbf, 2 * sizeof(char));
    lenbf[2] = '\0';
    int len8 = static_cast<int>(std::stoi(lenbf, 0, 16));
    char *lenBuffer = (char *) malloc((len8 / 4 + 1) * sizeof(char));
    file.read(lenBuffer, len8 / 4 * sizeof(char));
    lenBuffer[len8 / 4] = '\0';
    uint64_t len64 = static_cast<uint64_t>(std::stoi(lenBuffer, 0, 16));
    uint64_t fileSize = len64;
    fileLength = (uint64_t) fileSize;
    uint64_t read_loc_start_up = 2 + len8 / 4;
    std::cout << "input file size: " << (uint64_t)fileSize << " B" << std::endl;
    free(lenBuffer);
    free(lenbf);

    omp_set_num_threads(THREAD_NUM);
#pragma omp parallel firstprivate(x0, y0,z0, u, r,l)
    {
        std::ifstream localfile(fs::u8path(inputPath).wstring(), std::ios::binary);
        int numThreads = omp_get_num_threads();
//        std::cout << "Thread NUMS: " << numThreads << std::endl;
        int id = omp_get_thread_num();
        // std::cout << "id: " << id << " 线程数目：" << numThreads << std::endl;
        uint64_t fileSize_own = fileSize / numThreads;

        std::vector<int> blockSizeArr = splitBlockSize(fileSize_own);

        int blockIndex = 0;
        int indexAll = blockSizeArr.size();
        uint64_t read_offset = 0;
        uint64_t write_offset = 0;
        uint64_t startLoc = read_loc_start_up + id * fileSize_own;
        uint64_t limitLoc = read_loc_start_up + (id + 1) * fileSize_own;
        uint64_t resetSize;

        // 实际获取长度
        int realSize;

        for (blockIndex = 0; blockIndex < indexAll; blockIndex = blockIndex + 2) {
            // if (!localfile.good())
            // {
            //     std::cerr << "ID: " << id << "Error with file state." << std::endl;
            //     return 0;
            //     // 可能需要退出或采取其他措施
            //     // exit;
            // }
            // 读取当前数据块的字节数据
            int currBlockSize = blockSizeArr[blockIndex];

            unsigned char *buffer = (unsigned char *) malloc(currBlockSize * sizeof(unsigned char));
            // std::cout << "ID: " << id << " 创建分区： " << currBlockSize << std::endl;
            memset(buffer, 48, currBlockSize);

            localfile.seekg(startLoc + read_offset, std::ios::beg);
            // std::cout << "前缀长度：" << read_loc_start_up << " 写入位置：" << id * fileSize_own << std::endl;
            //  获取当前文件指针的位置
            // std::cout << "ID: " << id << " 开始位置：" << startLoc + read_offset;
            std::streampos currentPosition = localfile.tellg();
            // std::cout << " 当前位置：" << currentPosition << " 限制位置: " << limitLoc - 1 << std::endl;
            resetSize = limitLoc - static_cast<uint64_t>(currentPosition);
            localfile.read(reinterpret_cast<char *>(buffer), currBlockSize);
            realSize = resetSize > currBlockSize ? localfile.gcount() : resetSize;
            // if (resetSize > currBlockSize)
            // {
            //     realSize = localfile.gcount();
            // }
            // else
            // {
            //     realSize = resetSize;
            // }
            // std::cout << "ID: " << id << " 当前位置：" << currentPosition << " 限制位置：" << limitLoc << " 剩余长度：" << resetSize << " 实际长度：" << realSize << " buffer大小：" << currBlockSize << " 矩阵宽度： " << blockSizeArr[blockIndex + 1] << std::endl;
            decode_Block3(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0,z0, u, r,l);
#pragma omp critical
            {
                outputFile.seekp(id * fileSize_own + write_offset, std::ios::beg);
                outputFile.write(reinterpret_cast<char *>(buffer), realSize * sizeof(char));
                free(buffer);
            }

            read_offset += realSize;
            write_offset += realSize;
            // std::cout << "ID: " << id << " 释放分区：" << currBlockSize << std ::endl;
        }

        // #pragma omp barrier
        localfile.close();
    }
    // 剩余内容直接写入
    uint64_t reSize = fileSize - (fileSize / THREAD_NUM) * THREAD_NUM;
    if (reSize) {
        file.seekg(read_loc_start_up + (fileSize / THREAD_NUM) * THREAD_NUM, std::ios::beg);
        outputFile.seekp((fileSize / THREAD_NUM) * THREAD_NUM, std::ios::beg);
        char *buffer = (char *) malloc(reSize * sizeof(char));
        file.read(buffer, reSize);
        outputFile.write(buffer, reSize * sizeof(char));
        free(buffer);
    }

    // 关闭文件
    file.close();
    outputFile.close();
    // 计算速度
    auto end = std::chrono::steady_clock::now();
    auto durationMill = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    auto speed =
            static_cast<float >(fileLength) * 8 / 1024 / 1024 / 1024 / static_cast<float>(durationMill.count()) * 1000;
    result.mill = durationMill.count();
    result.size = fileLength;
    result.speed = speed;
    result.success = 1;
    return result;
}


