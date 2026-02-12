#include <iostream>
#include <sstream>
#include <fstream>
#include <vector>
#include <string>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <algorithm>
#include <cstdlib>
#include "chaos.h"
#include "sha256.h"
#include "crc32.h"




const double multiplier = pow(10, 16);
const double divisor = 255.0;


inline double realmod(double x, double y);

double realmod(double x, double y) {
    double result = fmod(x, y);
    return result >= 0 ? result : result + y;
}

// 16进制转10进制
int hextoDec(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    } else if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    } else if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    } else {
        return -1;
    }
}

// 16进制字符串逐位异或
int multBitXor(std::string str) {
    int len = str.length();
    int result = hextoDec(str[0]);
    // cout << "mulxor:" << endl;
    for (int i = 1; i < len; i++) {
        // cout << "1: " << hextoDec(str[i]) << " 2: " << result << endl;
        result = result ^ hextoDec(str[i]);
        // cout << "result: " << result << endl;
    }
    return result;
}

// 获取当前时间的毫秒时间戳
std::string GetCurrentTimestamp() {
    auto now = std::chrono::system_clock::now();
    auto milliseconds = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
    return std::to_string(milliseconds);
}



void returnInit(std::string hash, double &x0, double &y0, double &u, double &r) {

    int sor = multBitXor(hash.substr(0, 16));
    double h1 = sor / 256.0 * 8;
    sor = multBitXor(hash.substr(16, 16));
    double h2 = h1 + sor / 256.0 * 4;
    sor = multBitXor(hash.substr(32, 16));
    double h3 = h2 + sor / 256.0 * 2;
    sor = multBitXor(hash.substr(48, 16));
    double h4 = h3 + sor / 256.0;
    double u0 = 4;
    u = u0 + realmod((h1 + h2) * pow(10, 14), 255) / 256.0;
    double r0 = 4;
    r = r0 + realmod((h1 + h3) * pow(10, 14), 255) / 256.0;

    double x00 = 0.2;
    double y00 = 0.3;
    x0 = x00 + realmod((h2 + h4) * pow(10, 4), 255) / 256.0;
    y0 = y00 + realmod((h3 + h4) * pow(10, 4), 255) / 256.0;
}

// 根据hash初始化系统参数
void generateRandom(std::string hash, double &x0, double &y0, double &u, double &r) {
    int sor = multBitXor(hash.substr(0, 16));
    double h1 = sor / 256.0 * 8;
    sor = multBitXor(hash.substr(16, 16));
    double h2 = h1 + sor / 256.0 * 4;
    sor = multBitXor(hash.substr(32, 16));
    double h3 = h2 + sor / 256.0 * 2;
    sor = multBitXor(hash.substr(48, 16));
    double h4 = h3 + sor / 256.0;
    double u0 = 4;
    u = u0 + realmod((h1 + h2) * pow(10, 14), 255) / 256.0 * 16;
    double r0 = 4;
    r = r0 + realmod((h1 + h3) * pow(10, 14), 255) / 256.0 * 16;

    x0 = realmod((h2 + h4) * pow(10, 4), 255) / 256.0;
    y0 = realmod((h3 + h4) * pow(10, 4), 255) / 256.0;
}

// 根据hash初始化系统参数 3维混沌系统的初始值计算
void generateRandom3(std::string hash, double &x0, double &y0,double &z0, double &u, double &r, double &l) {
    int sor = multBitXor(hash.substr(0, 16));
    double h1 = sor / 256.0 * 8;
    sor = multBitXor(hash.substr(16, 16));
    double h2 = h1 + sor / 256.0 * 4;
    sor = multBitXor(hash.substr(32, 16));
    double h3 = h2 + sor / 256.0 * 2;
    sor = multBitXor(hash.substr(48, 16));
    double h4 = h3 + sor / 256.0;
    // u
    double u0 = 6;
    u = u0 + realmod((h1 + h4) * pow(10, 4), 255) / 256.0 * 16;
    // r
    double r0 = 9;
    r = r0 + realmod((h2 + h3) * pow(10, 4), 255) / 256.0 * 16;
    // l
    double l0 = 15;
    l = l0 + realmod((h1 + h3) * pow(10, 4), 255) / 256.0 * 16;
	// x0
    x0 = realmod((h2 + h4) * pow(10, 4), 255) / 256.0;
    // y0
    y0 = realmod((h3 + h4) * pow(10, 4), 255) / 256.0;
    // z0
    z0 = realmod((h1 + h2) * pow(10, 4), 255) / 256.0;
}


// 行间异或
template<typename T>
inline void XOR_BR(T *a, T *b, T *c, int n) {
    for (int i = 0; i < n; ++i) {
        *(a + i) = *(a + i) ^ *(b + i);
        *(a + i) = *(a + i) ^ *(c + i);
    }
}

// 行与0异或
template<typename T>
inline void XOR_BR_ZERO(T *a, T *b, int n) {
    for (int i = 0; i < n; ++i) {
        *(a + i) = *(a + i) ^ *(b + i);
        *(a + i) = *(a + i) ^ 0;
    }
}

// 列间异或
template<typename T>
inline void XOR_BC(T *a, T *b, T *c, int n) {
    int t;
    for (int i = 0; i < n; ++i) {
        t = i * n;
        *(a + t) = *(a + t) ^ *(b + i);
        // c为列向量
        *(a + t) = *(a + t) ^ *(c + t);
        // t += (n + 1);
    }
}

// 列与0异或
template<typename T>
inline void XOR_BC_ZERO(T *a, T *b, int n) {
    int t;
    for (int i = 0; i < n; ++i) {
        t = i * n;
        *(a + t) = *(a + t) ^ *(b + i);
        *(a + t) = *(a + t) ^ 0;
    }
}

// 分割块大小
std::vector<int> splitBlockSize(uint64_t size) {
    std::vector<int> blocksSize;
    int Max_Size = MAX_BLOCKROW * MAX_BLOCKCOL;
    int Min_Size = MIN_BLOCKROW * MIN_BLOCKCOL;
    while (size > Min_Size) {
        int maxBlockSize = std::min(size, (uint64_t) Max_Size); // 最大块大小为1024*1024
        int blockSize = std::sqrt(maxBlockSize);               // 开方取整
        int blockValue = blockSize * blockSize;
        blocksSize.push_back(blockValue);
        blocksSize.push_back(blockSize);
        size -= blockValue;
    }
    if (size > 0) {
        blocksSize.push_back(Min_Size);
        blocksSize.push_back(MIN_BLOCKROW);
    }
    return blocksSize;
}

// 计算密文前的前缀密文长度位数和密文长度
void getEmLenStr(Len_t &lenBit, std::string &lenBitStr) {
    int bitloc;
    //从高位往低位找，找到第一个值不为0的位置
    for (int i = 7; i >= 0; i--) {
        if (lenBit.len8[i] != 0) {
            bitloc = i;
            break;
        }
    }
    for (int i = bitloc; i >= 0; i--) {
        if (i == bitloc) {
            std::stringstream ss;
            ss << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << (bitloc + 1) * 8;
            std::string m = ss.str();
            lenBitStr += ss.str();
        }
        std::stringstream ss;
        ss << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(lenBit.len8[i]);
        std::string m = ss.str();
        lenBitStr += ss.str();
    }
//    std::cout << "密文长度: " << lenBit.len64 << " Lenbit：" << lenBitStr << std::endl;
}

// 加密块部分
void encode_Block(uint8_t *matrix, int m, int n, double &x0, double &y0, double &u, double &r) {
    int t = 200;
    double pi = 3.1415926;
    double x1, y1;
    int size = m;
    uint8_t *random_num = (uint8_t *) malloc(2 * size * sizeof(uint8_t));
    uint8_t *x = random_num;
    uint8_t *y = random_num + m;
    for (int i = 1; i <= size + t; ++i) {
        x1 = sin(pi * (y0 + r * x0)) + u * (y0 + r * x0) * (1 - (y0 + r * x0));
        x1 = realmod(x1, 1);
        y1 = sin(pi * (x1 + r * y0)) + u * (x1 + r * y0) * (1 - (x1 + r * y0));
        y1 = realmod(y1, 1);
        x0 = x1;
        y0 = y1;
        if (i > t) {
            *(x + i - t - 1) = round(realmod(x1 * multiplier, 255));
            *(y + i - t - 1) = round(realmod(y1 * multiplier, 255));
        }
    }
    uint8_t *store = (uint8_t *) malloc(7 * n * sizeof(uint8_t));
    int board = 6;
    uint8_t *e1 = store + m;
    uint8_t *e3 = store + 4 * m;
    uint8_t *e_value = store + board * m;
    uint8_t *p_value;
    uint8_t *c_value_p;
    memcpy(e1 - m, x, m * sizeof(uint8_t));
    memcpy(e1, x, m * sizeof(uint8_t));
    memcpy(e1 + m, x, m * sizeof(uint8_t));
    memcpy(e3 - m, y, m * sizeof(uint8_t));
    memcpy(e3, y, m * sizeof(uint8_t));
    memcpy(e3 + m, y, m * sizeof(uint8_t));
    int k = 1;
    int shift;
    for (int i = 0; i < m; ++i) {
        // 循环右移减，循环左移加
        shift = i * k % m;
        memcpy(e_value, e1 - shift, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i * n;
            c_value_p = matrix + (i - 1) * n;
            XOR_BR(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i * n;
            XOR_BR_ZERO(p_value, e_value, n);
        }
    }
    for (int i = 0; i < m; ++i) {
        shift = i * k % m;
        memcpy(e_value, e3 - shift, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i;
            c_value_p = matrix + (i - 1);
            XOR_BC(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i;
            XOR_BC_ZERO(p_value, e_value, n);
        }
    }
    free(store);
    free(random_num);
}

// 加密块部分 3维混沌系统的加密
void encode_Block3(uint8_t *matrix, int m, int n, double &x0, double &y0, double &z0, double &u, double &r, double &l) {
    int t = 200;
    double pi = 3.1415926;
    double x1, y1, z1;
    int size = m;
    uint8_t *random_num = (uint8_t *) malloc(2 * size * sizeof(uint8_t));
    uint8_t *x = random_num;
    uint8_t *y = random_num + m;
    for (int i = 1; i <= size + t; ++i) {
        x1 = u*x0+u*y0;
        x1 = realmod(x1, 1);
        y1 = u*y0+r*z0;
        y1 = realmod(y1, 1);
        z1 = l*z0+l*x0;
        z1 = realmod(y1, 1);

        x0 = x1;
        y0 = y1;
        z0 = 01;
        if (i > t) {
            *(x + i - t - 1) = round(realmod(x1 * multiplier, 255));
            *(y + i - t - 1) = round(realmod(y1 * multiplier, 255));
        }
    }
    uint8_t *store = (uint8_t *) malloc(7 * n * sizeof(uint8_t));
    int board = 6;
    uint8_t *e1 = store + m;
    uint8_t *e3 = store + 4 * m;
    uint8_t *e_value = store + board * m;
    uint8_t *p_value;
    uint8_t *c_value_p;
    memcpy(e1 - m, x, m * sizeof(uint8_t));
    memcpy(e1, x, m * sizeof(uint8_t));
    memcpy(e1 + m, x, m * sizeof(uint8_t));
    memcpy(e3 - m, y, m * sizeof(uint8_t));
    memcpy(e3, y, m * sizeof(uint8_t));
    memcpy(e3 + m, y, m * sizeof(uint8_t));
    int k = 1;
    int shift;
    for (int i = 0; i < m; ++i) {
        // 循环右移减，循环左移加
        shift = i * k % m;
        memcpy(e_value, e1 - shift, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i * n;
            c_value_p = matrix + (i - 1) * n;
            XOR_BR(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i * n;
            XOR_BR_ZERO(p_value, e_value, n);
        }
    }
    for (int i = 0; i < m; ++i) {
        shift = i * k % m;
        memcpy(e_value, e3 - shift, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i;
            c_value_p = matrix + (i - 1);
            XOR_BC(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i;
            XOR_BC_ZERO(p_value, e_value, n);
        }
    }
    free(store);
    free(random_num);
}

// 解密块部分
void decode_Block(uint8_t *matrix, int m, int n, double &x0, double &y0, double &u, double &r) {
    int channel = 1;
    int t = 200;
    double pi = 3.1415926;
    double x1, y1;
    int size = m * channel;
    uint8_t *random_num = (uint8_t *) malloc(2 * size * sizeof(uint8_t));
    uint8_t *x = random_num;
    uint8_t *y = random_num + m;
    for (int i = 1; i <= size + t; ++i) {
        x1 = sin(pi * (y0 + r * x0)) + u * (y0 + r * x0) * (1 - (y0 + r * x0));
        x1 = realmod(x1, 1);
        y1 = sin(pi * (x1 + r * y0)) + u * (x1 + r * y0) * (1 - (x1 + r * y0));
        y1 = realmod(y1, 1);
        x0 = x1;
        y0 = y1;
        if (i > t) {
            *(x + i - t - 1) = round(realmod(x1 * multiplier, 255));
            *(y + i - t - 1) = round(realmod(y1 * multiplier, 255));
        }
    }
    uint8_t *store = (uint8_t *) malloc(7 * n * sizeof(uint8_t));
    int board = 6 * channel;
    uint8_t *e1 = store + m;
    uint8_t *e3 = store + 4 * m;
    uint8_t *e_value = store + board * m;
    uint8_t *p_value;
    uint8_t *c_value_p;
    memcpy(e1 - m, x, m * sizeof(uint8_t));
    memcpy(e1, x, m * sizeof(uint8_t));
    memcpy(e1 + m, x, m * sizeof(uint8_t));
    memcpy(e3 - m, y, m * sizeof(uint8_t));
    memcpy(e3, y, m * sizeof(uint8_t));
    memcpy(e3 + m, y, m * sizeof(uint8_t));
    int k = 1;
    int shift;
    int cnt = 0;
    for (int i = m - 1; i >= 0; --i) {
        shift = cnt * k % m;
        memcpy(e_value, e3 + shift + 1, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i;
            c_value_p = matrix + (i - 1);
            XOR_BC(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i;
            XOR_BC_ZERO(p_value, e_value, n);
        }

        cnt++;
    }
    cnt = 0;
    for (int i = m - 1; i >= 0; --i) {
        // 循环右移减，循环左移加
        shift = cnt * k % m;
        memcpy(e_value, e1 + shift + 1, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i * n;
            c_value_p = matrix + (i - 1) * n;
            XOR_BR(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i * n;
            XOR_BR_ZERO(p_value, e_value, n);
        }
        cnt++;
    }
    free(store);
    free(random_num);
}

// 解密块部分 3维混沌系统的解密
void decode_Block3(uint8_t *matrix, int m, int n, double &x0, double &y0,double &z0,  double &u, double &r, double &l) {
    int channel = 1;
    int t = 200;
    double pi = 3.1415926;
    double x1, y1 , z1;
    int size = m * channel;
    uint8_t *random_num = (uint8_t *) malloc(2 * size * sizeof(uint8_t));
    uint8_t *x = random_num;
    uint8_t *y = random_num + m;
    for (int i = 1; i <= size + t; ++i) {
        x1 = u*x0+u*y0;
        x1 = realmod(x1, 1);
        y1 = u*y0+r*z0;
        y1 = realmod(y1, 1);
        z1 = l*z0+l*x0;
        z1 = realmod(y1, 1);

        x0 = x1;
        y0 = y1;
        z0 = 01;
        if (i > t) {
            *(x + i - t - 1) = round(realmod(x1 * multiplier, 255));
            *(y + i - t - 1) = round(realmod(y1 * multiplier, 255));
        }
    }
    uint8_t *store = (uint8_t *) malloc(7 * n * sizeof(uint8_t));
    int board = 6 * channel;
    uint8_t *e1 = store + m;
    uint8_t *e3 = store + 4 * m;
    uint8_t *e_value = store + board * m;
    uint8_t *p_value;
    uint8_t *c_value_p;
    memcpy(e1 - m, x, m * sizeof(uint8_t));
    memcpy(e1, x, m * sizeof(uint8_t));
    memcpy(e1 + m, x, m * sizeof(uint8_t));
    memcpy(e3 - m, y, m * sizeof(uint8_t));
    memcpy(e3, y, m * sizeof(uint8_t));
    memcpy(e3 + m, y, m * sizeof(uint8_t));
    int k = 1;
    int shift;
    int cnt = 0;
    for (int i = m - 1; i >= 0; --i) {
        shift = cnt * k % m;
        memcpy(e_value, e3 + shift + 1, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i;
            c_value_p = matrix + (i - 1);
            XOR_BC(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i;
            XOR_BC_ZERO(p_value, e_value, n);
        }

        cnt++;
    }
    cnt = 0;
    for (int i = m - 1; i >= 0; --i) {
        // 循环右移减，循环左移加
        shift = cnt * k % m;
        memcpy(e_value, e1 + shift + 1, m * sizeof(uint8_t));
        if (i > 0) {
            p_value = matrix + i * n;
            c_value_p = matrix + (i - 1) * n;
            XOR_BR(p_value, e_value, c_value_p, n);
        } else {
            p_value = matrix + i * n;
            XOR_BR_ZERO(p_value, e_value, n);
        }
        cnt++;
    }
    free(store);
    free(random_num);
}


// 计算CRC32
//std::string calculateCRC32(std::string emstr) {
//    uLong crc = crc32(0L, Z_NULL, 0);
//    crc = crc32(crc, (const Bytef *) emstr.c_str(), emstr.length());
//    std::stringstream stream;
//    stream << std::uppercase << std::setfill('0') << std::setw(8) << std::hex << crc;
//    return stream.str();
//}

std::string calculateCRC32(const std::string& emstr) {
    CRC32 crc32;
//    std::cout << "CRC32计算中..." << std::endl;
    return crc32(emstr);
}

// 校验CRC32
//bool judgeCRC32(std::string emstr) {
//    uint64_t len = emstr.length();
//    std::string subEmstr = emstr.substr(0, len - 8);
//    if (calculateCRC32(subEmstr) != emstr.substr(len - 8, 8)) {
//        return false;
//    } else {
//        return true;
//    }
//}

bool judgeCRC32(const std::string& emstr) {
    if (emstr.size() < 8)
        return false;

    std::string data = emstr.substr(0, emstr.size() - 8);
    std::string crc  = emstr.substr(emstr.size() - 8);

    return calculateCRC32(data) == crc;
}

/**
 * 加密
 * @param key  密钥 8~256
 * @param inputStr 待加密字符串
 * @return
 */
CHAOS_OPERATION_RESULT encryptStrWithKey(std::string key, std::string inputStr) {
    // 初始化结果为失败，错误信息为空
    CHAOS_OPERATION_RESULT result = {0, "", ""};
    // 必备参数检查
    // 1.密钥
    if (key.length() < 8 || key.length() > 256) {
        result.errorMsg = "Key must be between 8 and 256 characters.";
        return result;  // 如果key的长度不在8到256之间，返回错误信息
    }
    // 2.输入参数
    if (inputStr.empty()) {  // 如果inputstr为空字符串
        result.errorMsg = "Input string cannot be empty.";
        return result;  // 返回错误信息
    }
    double x0, y0, u, r;
    std::string hash = sha256_hash(key);
    generateRandom(hash, x0, y0, u, r);
    uint64_t strLen = inputStr.length();
    unsigned char *dstStr = (unsigned char *) std::malloc((strLen + 1) * sizeof(unsigned char));
    strcpy(reinterpret_cast<char *>(dstStr), inputStr.c_str());
    std::vector<int> blockSizeArr = splitBlockSize((uint64_t) strLen);
    int blockIndex = 0;
    int indexAll = blockSizeArr.size();
    int loc = 0;
    for (blockIndex = 0; blockIndex < indexAll; blockIndex = blockIndex + 2) {
        // 读取当前数据块的字节数据
        int currBlockSize = blockSizeArr[blockIndex];
        unsigned char *buffer = (unsigned char *) malloc(currBlockSize * sizeof(unsigned char));
        memset(buffer, 48, currBlockSize);
        if (loc + currBlockSize + 1 > strLen) {
            memcpy(buffer, dstStr + loc, (strLen - loc) * sizeof(unsigned char));
            encode_Block(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0, u, r);
            memcpy(dstStr + loc, buffer, (strLen - loc) * sizeof(unsigned char));
            loc += currBlockSize;
        } else {
            memcpy(buffer, dstStr + loc, currBlockSize * sizeof(unsigned char));
            encode_Block(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0, u, r);
            memcpy(dstStr + loc, buffer, currBlockSize * sizeof(unsigned char));
            loc += currBlockSize;
        }
        free(buffer);
    }
    std::string res = "";
    for (uint64_t i = 0; i < strLen; i++) {
        std::stringstream ss;
        ss << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(dstStr[i]);
        std::string m = ss.str();
        res += ss.str();
    }
    // 密文长度
    std::string emLenStr = "";
    uint64_t emLen = res.length();
    Len_t lenBit;
    lenBit.len64 = emLen;
    getEmLenStr(lenBit, emLenStr);
    res = emLenStr + res;
    res = res + calculateCRC32(res);
    free(dstStr);
    result.success = 1;
    result.result = res;
    return std::move(result);
}

/**
 * 解密
 * @param key 密钥 8~256
 * @param inputStr 待解密字符串
 * @return
 */
CHAOS_OPERATION_RESULT decryptStrWithKey(const std::string& key, const std::string& inputStr) {
    // 初始化结果为失败，错误信息为空
    CHAOS_OPERATION_RESULT result = {0, "", ""};
    // 必备参数检查
    // 1.密钥
    if (key.length() < 8 || key.length() > 256) {
        result.errorMsg = "Key must be between 8 and 256 characters.";
        return result;  // 如果key的长度不在8到256之间，返回错误信息
    }
    // 2.输入参数
    if (inputStr.empty()) {  // 如果inputstr为空字符串
        result.errorMsg = "Input string cannot be empty.";
        return result;  // 返回错误信息
    }
    if (judgeCRC32(inputStr)) {
//        std::cout << "CRC verification success" << std::endl;
        double x0, y0, u, r;
        std::string hash = sha256_hash(key);
        generateRandom(hash, x0, y0, u, r);
        // 除crc32外的前面的文本
        std::string subEmstr = inputStr.substr(0, inputStr.length() - 8);
        int len8 = static_cast<int>(std::stoi(subEmstr.substr(0, 2), 0, 16));
        // len8/8 = char num; char num * 2 = hex num;
        uint64_t len64 = static_cast<uint64_t>(std::stoi(subEmstr.substr(2, len8 / 4), 0, 16));
        // 密文文本
        std::string EmStr = subEmstr.substr(2 + len8 / 4, len64);
        uint64_t strLen = len64;
        strLen = strLen / 2;
        auto *dstStr = (unsigned char *) malloc((strLen + 1) * sizeof(unsigned char));
        // 每两个hex转换为unsigned char
        for (int i = 0; i < strLen; i++) {
            std::string byte_string = EmStr.substr(i * 2, 2);
            dstStr[i] = static_cast<unsigned char>(std::stoi(byte_string, 0, 16));
        }
        dstStr[strLen] = '\0';

        std::vector<int> blockSizeArr = splitBlockSize((uint64_t) strLen);
        int blockIndex = 0;
        int indexAll = blockSizeArr.size();
        int loc = 0;
        for (blockIndex = 0; blockIndex < indexAll; blockIndex = blockIndex + 2) {
            // 读取当前数据块的字节数据
            int currBlockSize = blockSizeArr[blockIndex];
            auto *buffer = (unsigned char *) malloc(currBlockSize * sizeof(unsigned char));
            memset(buffer, 48, currBlockSize);
            if (loc + currBlockSize + 1 > strLen) {
                memcpy(buffer, dstStr + loc, (strLen - loc) * sizeof(unsigned char));
                decode_Block(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0, u, r);
                memcpy(dstStr + loc, buffer, (strLen - loc) * sizeof(unsigned char));
            } else {
                memcpy(buffer, dstStr + loc, currBlockSize * sizeof(unsigned char));
                decode_Block(buffer, blockSizeArr[blockIndex + 1], blockSizeArr[blockIndex + 1], x0, y0, u, r);
                memcpy(dstStr + loc, buffer, currBlockSize * sizeof(unsigned char));
                loc += currBlockSize;
            }
            free(buffer);
        }
        std::string res(reinterpret_cast<char *>(dstStr));
        result.success = 1;
        result.result = res;
        free(dstStr);
        return std::move(result);
    } else {
        result.success = 0;
        result.errorMsg = "密文校验失败,无法解密";
        return std::move(result);
    }

}

//
//int main(int argc, char *argv[])
//{
//    std::string key1 = "12345";
//    std::string key2 = "12345";
//    std::string inputpath1 = "./need.mp4";
//    std::string outputpath1 = "./encode.mp4";
//    std::string inputpath2 = "./encode.mp4";
//    std::string outputpath2 = "./decode.mp4";
//    auto start = std::chrono::steady_clock::now();
//    encryptFileWithKey(key1, inputpath1, outputpath1);
//    decryptFileWithKey(key2, inputpath2, outputpath2);
//    encryptFileNoKey(inputpath1, outputpath1);
//    decryptFileNoKey(inputpath2, outputpath2);
//
//    std::string emstr, dmstr;
//    encryptStrWithKey(key1, "Hello it is me!原神启动", emstr);
//    decryptStrWithKey(key2, "0824C39947E8462F27F023B0BEDFF407A9B04EF7211BAF2C", dmstr);
//
//    encryptStrNoKey("Hello it is me!原神启动", emstr);
//    decryptStrNoKey(emstr, dmstr);
//
//    std::cout << dmstr << std::endl;
//    auto end = std::chrono::steady_clock::now();
//    auto time_diff = end - start;
//    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(time_diff) / 1000000.0;
//    std::cout << "\nOperation cost : " << duration.count() << "s" << std::endl;
//    return 0;
//}
