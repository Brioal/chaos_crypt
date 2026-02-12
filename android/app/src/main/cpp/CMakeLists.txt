cmake_minimum_required(VERSION 3.10.2)

project(chaos_crypt_native)

# Use absolute paths or relative to CMakeLists.txt
# Since CMakeLists.txt is in android/app/src/main/cpp, and sources are in d:/Projects/11Test/chaos_crypt/c
# We need to reference them correctly.
# The path provided is relative to where gradle calls cmake.
# But source sets in gradle usually point to CMakeLists.txt.
# Let's assume sources are copied or referenced. referencing outside module root might be tricky in Android Studio structure sometimes,
# but using relative paths usually works.
# ../../../../../../c/  -> android/app/src/main/cpp/../../../../../../c
# c is in root/c
# android/app/src/main/cpp is 5 levels deep from root?
# root/android/app/src/main/cpp
# so root is ../../../../../

set(SRC_DIR "../../../../../c")

# Optimization flags for Release/Debug to improve performance statistics
add_compile_options(-O3 -ffast-math)

add_library( # Sets the name of the library.
             chaos_crypt

             # Sets the library as a shared library.
             SHARED

             # Provides a relative path to your source file(s).
             ${SRC_DIR}/native_lib.cpp
             ${SRC_DIR}/chaos.cpp
             ${SRC_DIR}/chaos_omp.cpp
             ${SRC_DIR}/sha256.cpp
             ${SRC_DIR}/crc32.cpp
             )

include_directories(${SRC_DIR})

# Search for the log library
find_library( # Sets the name of the path variable.
              log-lib

              # Specifies the name of the NDK library that
              # you want CMake to locate.
              log )

# Link libraries
target_link_libraries( # Specifies the target library.
                       chaos_crypt

                       # Links the log library to the target library.
                       ${log-lib} )

# OpenMP support
find_package(OpenMP)
if(OpenMP_CXX_FOUND)
    target_link_libraries(chaos_crypt OpenMP::OpenMP_CXX)
endif()
