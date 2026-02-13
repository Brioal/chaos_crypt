import 'dart:async';
// import 'dart:convert'; // Unused
import 'dart:ffi'; // For FFI
import 'dart:io'; // For Platform
import 'package:ffi/ffi.dart'; // For Utf8
import 'package:flutter/foundation.dart'; // For compute
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// FFI signatures
typedef EncryptStringC =
    Pointer<Utf8> Function(Pointer<Utf8> key, Pointer<Utf8> input);
typedef EncryptStringDart =
    Pointer<Utf8> Function(Pointer<Utf8> key, Pointer<Utf8> input);

typedef EncryptFileC =
    Pointer<Utf8> Function(
      Pointer<Utf8> key,
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
    );
typedef EncryptFileDart =
    Pointer<Utf8> Function(
      Pointer<Utf8> key,
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
    );

typedef EncryptFileMTC =
    Pointer<Utf8> Function(
      Int32 threads,
      Pointer<Utf8> key,
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
    );
typedef EncryptFileMTDart =
    Pointer<Utf8> Function(
      int threads,
      Pointer<Utf8> key,
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
    );

typedef FreeMemoryC = Void Function(Pointer<Void> ptr);
typedef FreeMemoryDart = void Function(Pointer<Void> ptr);

// Load the dynamic library
final DynamicLibrary _nativeLib = Platform.isAndroid
    ? DynamicLibrary.open("libchaos_crypt.so")
    : DynamicLibrary.process(); // iOS/MacOS linkage

// Look up functions
final EncryptFileDart _encryptFile = _nativeLib
    .lookup<NativeFunction<EncryptFileC>>('encrypt_file')
    .asFunction();

final EncryptFileDart _decryptFile = _nativeLib
    .lookup<NativeFunction<EncryptFileC>>('decrypt_file')
    .asFunction();

final EncryptFileMTDart _encryptFileMT = _nativeLib
    .lookup<NativeFunction<EncryptFileMTC>>('encrypt_file_mt')
    .asFunction();

final FreeMemoryDart _freeMemory = _nativeLib
    .lookup<NativeFunction<FreeMemoryC>>('free_memory')
    .asFunction();

class BenchmarkProgress {
  final double speedGbps;
  final double progress;
  final int elapsedMs;
  final int iteration;
  final int totalIterations;

  BenchmarkProgress(
    this.speedGbps,
    this.progress,
    this.elapsedMs, {
    this.iteration = 1,
    this.totalIterations = 1,
  });

  bool get isComplete => progress >= 1.0;
}

class CryptoResult {
  final String path;
  final bool success;
  final int timeMs;
  final double speedGbps; // native speed (Gb/s)
  final String? message;

  CryptoResult({
    required this.path,
    required this.success,
    this.timeMs = 0,
    this.speedGbps = 0.0,
    this.message,
  });
}

class CryptoService {
  static const String _defaultKey = "ChaosCryptDefaultKey123";

  // Helper to call native file function
  static String _callFileFunc(
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>) func,
    String key,
    String inputPath,
    String outputPath,
  ) {
    final keyPtr = key.toNativeUtf8();
    final inputPtr = inputPath.toNativeUtf8();
    final outputPtr = outputPath.toNativeUtf8();

    try {
      final resultPtr = func(keyPtr, inputPtr, outputPtr);
      final result = resultPtr.toDartString();
      _freeMemory(resultPtr.cast()); // Wrapper allocates, we free
      return result;
    } finally {
      calloc.free(keyPtr);
      calloc.free(inputPtr);
      calloc.free(outputPtr);
    }
  }

  // Helper to get output directory
  static Future<Directory> getOutputDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/ChaosCrypt');
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dir = Directory('${docDir.path}/ChaosCrypt');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // --- Image Encryption (Visual) ---
  // Since C++ operates on strings/files, we need to adapt.
  // Visual encrypt: Convert pixels to bytes -> Base64 string -> Encrypt -> Base64 String -> Bytes -> Bitmap?
  // Problem: The C++ string encryption adds headers/CRC. It returns "len + ciphertext + crc".
  // This might not be valid image data if we just write it back.
  // AND the visual encryption needs to show "snow".
  // The C++ logic: `encode_Block` shuffles and diffuses.
  // If we encrypt the raw bytes of the image (RGB), the result will be high entropy bytes.
  // If we try to display these bytes as an image, it depends on headers.
  //
  // APPROACH:
  // 1. Get raw RGBA bytes.
  // 2. Encrypt them using C++ `encrypt_string` (treating bytes as char string? careful with nulls).
  //    Wait, `encryptStrWithKey` takes `std::string`. `std::string` can handle nulls if constructed with length, but `inputStr.c_str()` usage in C++ might stop at null.
  //    CHECK C++: `strcpy(reinterpret_cast<char *>(dstStr), inputStr.c_str());` -> KABOOM on binary data with nulls.
  //
  //    CRITICAL FINDING: C++ `encryptStrWithKey` uses `strcpy` and string functions dependent on null termination.
  //    IT IS NOT SAFE FOR BINARY DATA.
  //
  //    However, `encryptFileWithKey` handles binary files correctly using streams.
  //
  //    Workaround for Image Visual:
  //    Save image to temp file -> Encrypt File -> Read encrypted file -> Show as Image?
  //    But encrypted file has header/CRC. It's not a valid PNG/JPG.
  //    To display "snow", we want raw pixel values that are randomized.
  //
  //    If I want to visualize the *result*, I should probably just take the encrypted bytes and force-interpret them as RGB.
  //    But the `encryptFile` adds a header. I can skip the header in Dart.
  //
  //    Let's implement `encryptImageBytes` via temp file for robustness.

  static Future<Uint8List> encryptImageBytes(Uint8List imageBytes) async {
    // 1. Write temp file
    final tempDir = Directory.systemTemp;
    final inFile = File('${tempDir.path}/temp_img.dat');
    await inFile.writeAsBytes(imageBytes);
    final outFile = File('${tempDir.path}/temp_img.enc');

    // 2. Encrypt file
    final result =
        await compute(_encryptFileIsolate, {
          'key': _defaultKey,
          'input': inFile.path,
          'output': outFile.path,
        }).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Encryption timed out');
          },
        );
    // Add timeout/error check?
    // compute might throw if isolate fails.
    print('[CryptoService] Image Encryption Result: $result');

    // 3. Read result
    if (await outFile.exists()) {
      final encBytes = await outFile.readAsBytes();

      // 4. Transform to displayable "noise" image
      // The Encrypted file is: [Len Header][Ciphertext][CRC]
      // We want to extract [Ciphertext] and display it.
      // But [Ciphertext] is just randomized bytes.
      // To show it as an image, we can just take the raw bytes and wrap a BMP/PNG header or just fill a matrix.
      //
      // Simpler approach for "Visual Encryption" demo:
      // The goal is to show it looks like noise.
      // Just re-encoding the raw encrypted bytes as a PNG usually fails because it's random data.
      // We need to create a *valid* image where pixel data comes from the encrypted bytes.

      img.Image? original = img.decodeImage(imageBytes);
      if (original == null) return Uint8List(0);

      // Create new noise image of same size
      img.Image noiseImg = img.Image(
        width: original.width,
        height: original.height,
      );

      // Fill noise image with bytes from encBytes
      // We cycle through encBytes to fill pixels
      int byteIdx = 0;
      // Skip header?
      // C++ format: 2 chars (length of length), then length hex, then data...
      // It's complicated to parse without C++ logic.
      // Let's just blindly use bytes from the middle.

      for (int y = 0; y < noiseImg.height; y++) {
        for (int x = 0; x < noiseImg.width; x++) {
          if (byteIdx >= encBytes.length) byteIdx = 0;
          int r = encBytes[byteIdx];
          int g = (byteIdx + 1 < encBytes.length) ? encBytes[byteIdx + 1] : 0;
          int b = (byteIdx + 2 < encBytes.length) ? encBytes[byteIdx + 2] : 0;
          noiseImg.setPixelRgb(x, y, r, g, b);
          byteIdx += 3;
        }
      }

      return Uint8List.fromList(img.encodePng(noiseImg));
    }
    return Uint8List(0);
  }

  // Isolated entry point for file encryption
  static String _encryptFileIsolate(Map<String, dynamic> args) {
    return _callFileFunc(
      _encryptFile,
      args['key'],
      args['input'],
      args['output'],
    );
  }

  // --- Histogram ---
  static Future<Map<String, List<int>>> computeHistogram(
    Uint8List bytes,
  ) async {
    return compute(_computeHistogramRunning, bytes);
  }

  static Map<String, List<int>> _computeHistogramRunning(Uint8List bytes) {
    // Check if it's a valid image first to get pixel data
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      // If not valid image (e.g. encrypted raw bytes), treat bytes as stream of RGB?
      // For the "encrypted" visualization which returns a PNG (from encryptImageBytes), it IS a valid image.
      // So we can decode it.
      // BUT, if we passed the RAW .lzu file bytes, decoding fails.
      // The VisualEncryptScreen passes the result of encryptImageBytes, which is a PNG.
      // So decodeImage should work.
      return {'r': [], 'g': [], 'b': []};
    }

    final red = List.filled(256, 0);
    final green = List.filled(256, 0);
    final blue = List.filled(256, 0);

    for (final pixel in image) {
      red[pixel.r.toInt()]++;
      green[pixel.g.toInt()]++;
      blue[pixel.b.toInt()]++;
    }
    return {'r': red, 'g': green, 'b': blue};
  }

  // --- File Encryption ---
  static Future<CryptoResult> encryptFile(
    String inputPath,
    String outputPath,
  ) async {
    print('[CryptoService] Start encryptFile: $inputPath -> $outputPath');
    final stopwatch = Stopwatch()..start();

    final result = await compute(_encryptFileIsolate, {
      'key': _defaultKey,
      'input': inputPath,
      'output': outputPath,
    });

    stopwatch.stop();
    print(
      '[CryptoService] Native result: $result (Dart elapsed: ${stopwatch.elapsedMilliseconds}ms)',
    );

    if (result.startsWith("SUCCESS")) {
      // SUCCESS|time|speed
      final parts = result.split('|');
      int timeMs = 0;
      double speed = 0.0;
      if (parts.length >= 3) {
        timeMs = int.tryParse(parts[1]) ?? 0;
        speed = double.tryParse(parts[2]) ?? 0.0;
      }
      // speed (native) is in Gbit/s usually?
      // native_lib line 105: speed = ... * 1000? No.
      // It calculates Gbit/s? "fileLength * 8 / ... / time * 1000".
      // Yes.
      // Let's keep it as is. UI can convert.

      return CryptoResult(
        path: outputPath,
        success: true,
        timeMs: timeMs,
        speedGbps: speed, // Native returns Gbit/s
      );
    } else {
      print('[CryptoService] Encryption FAILED: $result');
      throw Exception(result);
    }
  }

  static Future<CryptoResult> decryptFile(String inputPath) async {
    final outDir = await getOutputDirectory();
    final fileName = p.basename(inputPath);

    String baseName = fileName;
    if (fileName.endsWith('.lzu')) {
      baseName = fileName.substring(0, fileName.length - 4);
    } else {
      baseName = "$fileName.decrypted";
    }

    final outputPath = '${outDir.path}/$baseName';

    // Generate unique output path to prevent overwrite
    String finalPath = await _ensureUniquePath(outputPath);
    print('[CryptoService] Start decryptFile: $inputPath -> $finalPath');
    final stopwatch = Stopwatch()..start();

    final result = await compute(_decryptFileIsolate, {
      'key': _defaultKey,
      'input': inputPath,
      'output': finalPath,
    });

    stopwatch.stop();
    print(
      '[CryptoService] Native result: $result (Dart elapsed: ${stopwatch.elapsedMilliseconds}ms)',
    );

    if (result.startsWith("SUCCESS")) {
      // decryptFile returns just "SUCCESS" in native_lib currently.
      // Wait, native_lib.cpp line 262: return string_to_char("SUCCESS");
      // So no stats for decryption in current native_lib!
      // I should update native_lib.cpp to return stats for decryption too?
      // Yes, otherwise I can't show stats.
      // For now I'll use Dart stopwatch as fallback.

      return CryptoResult(
        path: finalPath,
        success: true,
        timeMs: stopwatch.elapsedMilliseconds,
        speedGbps: 0.0, // unknown from native
      );
    } else {
      print('[CryptoService] Decryption FAILED: $result');
      throw Exception(result);
    }
  }

  static Future<String> _ensureUniquePath(String path) async {
    if (!await File(path).exists()) return path;

    final dir = File(path).parent.path;
    final name = path.split(Platform.pathSeparator).last;
    String baseName = name;
    String extension = "";

    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1) {
      baseName = name.substring(0, dotIndex);
      extension = name.substring(dotIndex);
    }

    int counter = 1;
    while (true) {
      final newPath =
          '$dir${Platform.pathSeparator}$baseName($counter)$extension';
      if (!await File(newPath).exists()) {
        return newPath;
      }
      counter++;
    }
  }

  static String _decryptFileIsolate(Map<String, dynamic> args) {
    return _callFileFunc(
      _decryptFile,
      args['key'],
      args['input'],
      args['output'],
    );
  }

  // --- Benchmark ---
  // Returns stream of progress.
  // Since C++ is blocking, we can't get real PROGRESS events from the C++ function itself unless we modify it.
  // But native_wrapper returns "SUCCESS|time|speed".
  // So we will just show "Processing..." and then the final result.
  // To make the chart interesting, we can simulate progress while waiting,
  // OR we can rely on the fact that for large files it takes time.
  //
  // Problem: The BenchmarkScreen expects a STREAM of progress.
  // If we just await the result, the gauge will sit at 0 then jump to 100.
  // We can emit fake progress while waiting, then emit final real result.

  // --- Benchmark ---
  // Returns stream of progress.
  // We emit:
  // - Speed = -1.0 means "Generating file..."
  // - Speed >= 0 means result.
  static Stream<BenchmarkProgress> runBenchmark({
    required int dataSizeMB,
    required bool multiThread,
    int iterations = 1,
  }) async* {
    final outDir = await getOutputDirectory();
    final fileName = 'benchmark_test_${dataSizeMB}MB.dat';
    final filePath = '${outDir.path}/$fileName';
    final encPath = '$filePath.enc';
    final file = File(filePath);

    // 1. Check/Generate Test File
    bool fileExists = await file.exists();
    if (fileExists) {
      // Check size
      final len = await file.length();
      if (len != dataSizeMB * 1024 * 1024) {
        fileExists = false;
        await file.delete();
      }
    }

    if (!fileExists) {
      // Notify UI: Generating...
      yield BenchmarkProgress(
        -1.0, // Signal for "Generating"
        0.0,
        0,
        iteration: 0,
        totalIterations: iterations,
      );

      final chunkSize = 4 * 1024 * 1024; // 4MB chunks
      final chunk = List<int>.filled(chunkSize, 65); // 'A'
      final sink = file.openWrite();
      int written = 0;
      final totalBytes = dataSizeMB * 1024 * 1024;

      while (written < totalBytes) {
        int toWrite = totalBytes - written;
        if (toWrite > chunkSize) toWrite = chunkSize;
        sink.add(chunk.sublist(0, toWrite));
        written += toWrite;
      }
      await sink.close();
    }

    // 2. Run Encryption Loop
    for (int i = 1; i <= iterations; i++) {
      // Yield "Running" state for this iteration (speed 0, progress 0)
      yield BenchmarkProgress(
        0,
        0.0,
        0,
        iteration: i,
        totalIterations: iterations,
      );

      final stopwatch = Stopwatch()..start();

      // Use _encryptFileIsolate to match exact logic of encryptFile if single thread
      // Or use _encryptFileMT if multi-thread.
      // NOTE: encryptFile uses _encryptFileIsolate (single thread).
      // The user wants to match "File Encryption" module rate.
      // If the user selects "Multi-thread" we use MT.

      final String resultStr;
      if (multiThread) {
        // Native MT
        resultStr = await compute(_benchmarkIsolate, {
          'useOMP': true,
          'threads':
              4, // Default to 4 or auto? User didn't specify thread count control.
          'key': _defaultKey,
          'input': filePath,
          'output': encPath,
        });
      } else {
        // Exact same path as encryptFile
        resultStr = await compute(_encryptFileIsolate, {
          'key': _defaultKey,
          'input': filePath,
          'output': encPath,
        });
      }

      stopwatch.stop();

      if (resultStr.startsWith("SUCCESS")) {
        final parts = resultStr.split('|');
        // parts[1] is native ms, parts[2] is native speed
        final nativeTimeMs =
            int.tryParse(parts[1]) ?? stopwatch.elapsedMilliseconds;
        final nativeSpeed = double.tryParse(parts[2]) ?? 0.0;

        // Recalculate speed using Dart time if needed, but Native time is more accurate for "core" work.
        // User complained about "Test module rate is few M, Encrypt module is 1.5G".
        // Likely because Test module included generation time? OR used temp dir (emulated storage overhead?).
        // Using native speed return is safest if logic is correct.

        yield BenchmarkProgress(
          nativeSpeed,
          1.0,
          nativeTimeMs,
          iteration: i,
          totalIterations: iterations,
        );
      } else {
        // Error
        yield BenchmarkProgress(
          0.0,
          0.0,
          0,
          iteration: i,
          totalIterations: iterations,
        );
      }

      // Cleanup enc file for next run
      final fEnc = File(encPath);
      if (await fEnc.exists()) await fEnc.delete();
    }

    // Convert logic: keep the source file for next time?
    // User said: "Check if already exists, if not generate". implies KEEP IT.
    // So we do NOT delete 'file' (input).
  }

  static String _benchmarkIsolate(Map<String, dynamic> args) {
    if (args['useOMP'] == true) {
      final keyPtr = (args['key'] as String).toNativeUtf8();
      final inputPtr = (args['input'] as String).toNativeUtf8();
      final outputPtr = (args['output'] as String).toNativeUtf8();
      try {
        final resPtr = _encryptFileMT(
          args['threads'],
          keyPtr,
          inputPtr,
          outputPtr,
        );
        final res = resPtr.toDartString();
        _freeMemory(resPtr.cast());
        return res;
      } finally {
        calloc.free(keyPtr);
        calloc.free(inputPtr);
        calloc.free(outputPtr);
      }
    } else {
      return _callFileFunc(
        _encryptFile,
        args['key'],
        args['input'],
        args['output'],
      );
    }
  }
}

class FutureBox<T> {
  T? value;
}
