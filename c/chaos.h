#ifndef __CHAOS_H__
#define __CHAOS_H__

#include <iostream>
#include <sstream>
#include <fstream>
#include <vector>
#include <chrono>
#include <string>
#include <cmath>
#include <cstring>
#include <algorithm>
#include <zlib.h>
#include <iomanip>

#define MAX_BLOCKROW 1024
#define MAX_BLOCKCOL 1024
#define MIN_BLOCKROW 4
#define MIN_BLOCKCOL 4
// 最小并行加密大小
#define MIN_PARALLEL_SIZE 1024

typedef union {
    uint64_t len64;
    uint8_t len8[8];
} Len_t;

// 操作结果实体
struct CHAOS_OPERATION_RESULT {
    // 是否成功
    int success;
    // 错误信息
    std::string errorMsg;
    // 结果 加密、解密结果
    std::string result;
    // 耗费时间，毫秒值
    long long mill;
    // 文件大小
    uint64_t size;
    // 加密速率 Gbit/s
    float speed;
};

// ================================================== 通用的工具类 ==================================================

int multBitXor(std::string str);

std::vector<int> splitBlockSize(uint64_t size);

std::string GetHardWareInfo();

std::string GetCurrentTimestamp();

void transHash(const std::string &input, std::string &hash);

void decode_Block(uint8_t *matrix, int m, int n, double &x0, double &y0, double &u, double &r);

void decode_Block3(uint8_t *matrix, int m, int n, double &x0, double &y0, double &z0, double &u, double &r, double &l);

void encode_Block(uint8_t *matrix, int m, int n, double &x0, double &y0, double &u, double &r);

void encode_Block3(uint8_t *matrix, int m, int n, double &x0, double &y0, double &z0, double &u, double &r, double &l);

std::string GetMemoryUsage();

void returnInit(std::string hash, double &x0, double &y0, double &u, double &r);

std::string GetCPUFrequency();

std::string calculateCRC32(const std::string &emstr);

std::string GetCPUUsage();

int hextoDec(char c);

bool judgeCRC32(const std::string &emstr);

void generateRandom(std::string hash, double &x0, double &y0, double &u, double &r);

void generateRandom3(std::string hash, double &x0, double &y0, double &z0, double &u, double &r, double &l);

void getEmLenStr(Len_t &lenBit, std::string &lenBitStr);

// ================================================== start 软件加密 ==================================================
// ========================字符串加密
// =============有密钥

/**
 * 加密
 * @param key  密钥 8~256
 * @param inputStr 待加密字符串
 * @return
 */
CHAOS_OPERATION_RESULT encryptStrWithKey(std::string key, std::string inputStr);

/**
 * 解密
 * @param key 密钥 8~256
 * @param inputStr 待解密字符串
 * @return
 */
CHAOS_OPERATION_RESULT decryptStrWithKey(const std::string& key, const std::string& inputStr);

// =============无密钥


// ========================文件加密
// =============有密钥
/**
 * 密钥-文件-加密
 * @param key 密钥
 * @param inputPath 待加密文件
 * @param outputPath 加密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT encryptFileWithKey(std::string key, std::string inputPath, std::string outputPath);

/**
 * 密钥-文件-解密
 * @param key 密钥
 * @param inputPath 待解密文件
 * @param outputPath 解密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT decryptFileWithKey(std::string key, std::string inputPath, std::string outputPath);


// =============无密钥
/**
 * 无密钥-文件-加密
 * @param inputPath 待加密文件
 * @param outputPath 加密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT encryptFileNoKey(std::string inputPath, std::string outputPath);

/**
 * 无密钥-文件-解密
 * @param inputPath 待解密文件
 * @param outputPath 解密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT decryptFileNoKey(std::string inputPath, std::string outputPath);

// ================================================== end 软件加密 ==================================================


// ================================================== start 多线程加密 ==================================================
// ========================文件加密-多线程

// =============有密钥
/**
 * 有密钥-文件加密-多线程
 * @param THREAD_NUM 线程数量
 * @param key 密钥
 * @param inputPath 待加密文件
 * @param outputPath 加密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT
encryptFileWithKey_OMP(int THREAD_NUM, std::string key, std::string inputPath, std::string outputPath);

/**
 * 有密钥-文件解密-多线程
 * @param THREAD_NUM 线程数量
 * @param key 密钥
 * @param inputPath 待解密文件
 * @param outputPath 解密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT
decryptFileWithKey_OMP(int THREAD_NUM, std::string key, std::string inputPath, std::string outputPath);

// =============无密钥
/**
 * 无密钥-文件加密-多线程
 * @param THREAD_NUM 线程数量
 * @param inputPath 待加密文件
 * @param outputPath 加密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT encryptFileNoKey_OMP(int THREAD_NUM, std::string inputPath, std::string outputPath);




// ================================================== end 多线程加密 ==================================================


// ================================================== start 硬件加密 ==================================================


/**
 * 检查硬件设备是否在线
 * @return
 */
CHAOS_OPERATION_RESULT check_hardware();

/**
 * 文件加密-硬件
 * @param inputPath 待加密文件
 * @param outputPath 加密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT encryptFile_hardware(std::string inputPath, std::string outputPath);

/**
 * 文件解密-硬件
 * @param inputPath 待解密文件
 * @param outputPath 解密后的文件
 * @return
 */
CHAOS_OPERATION_RESULT decryptFile_hardware(std::string inputPath, std::string outputPath);


// ========================字符串加密-硬件

/**
 * 字符串加密-硬件
 * @param inputStr 待加密字符串
 * @return
 */
CHAOS_OPERATION_RESULT encryptStr_hardware(std::string inputStr);

/**
 * 字符串解密-硬件
 * @param inputStr 待解密字符串
 * @return
 */
CHAOS_OPERATION_RESULT decryptStr_hardware(std::string inputStr);


// ================================================== end 硬件加密 ==================================================

#endif
