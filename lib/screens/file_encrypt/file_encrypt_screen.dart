import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../../core/services/crypto_service.dart';
import '../../core/theme/app_colors.dart';

class FileEncryptScreen extends StatefulWidget {
  const FileEncryptScreen({super.key});

  @override
  State<FileEncryptScreen> createState() => _FileEncryptScreenState();
}

class _FileEncryptScreenState extends State<FileEncryptScreen>
    with SingleTickerProviderStateMixin {
  bool _isEncryptMode = true; // true=加密, false=解密
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isProcessing = false;
  String? _resultPath;
  String? _resultMessage;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    if (_isEncryptMode) {
      result = await FilePicker.platform.pickFiles();
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['lzu'],
      );
    }

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result!.files.single.path;
        _selectedFileName = result.files.single.name;
        _resultPath = null;
        _resultMessage = null;
      });
    }
  }

  Future<void> _processFile() async {
    if (_selectedFilePath == null) return;
    setState(() {
      _isProcessing = true;
      _resultPath = null;
      _resultMessage = null;
    });

    try {
      final inputFile = File(_selectedFilePath!);
      CryptoResult result;
      if (_isEncryptMode) {
        // Enforce output to ChaosCrypt folder
        final dir = await CryptoService.getOutputDirectory();
        final baseName = p.basenameWithoutExtension(
          _selectedFileName ?? 'file',
        );
        final outPath = '${dir.path}/$baseName.lzu';
        result = await CryptoService.encryptFile(inputFile.path, outPath);
      } else {
        // Decrypt handles path generation internally (to ChaosCrypt folder)
        result = await CryptoService.decryptFile(inputFile.path);
      }

      final fileSize = await File(result.path).length();
      final sizeMB = fileSize / (1024 * 1024);

      setState(() {
        _resultPath = result.path;
        _resultMessage =
            'Time: ${result.timeMs} ms\n'
            'Speed: ${result.speedGbps.toStringAsFixed(3)} Gb/s\n'
            'Size: ${sizeMB.toStringAsFixed(2)} MB\n'
            'Path: ${result.path}';
      });
    } catch (e) {
      setState(() => _resultMessage = '操作失败: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareResult() async {
    if (_resultPath == null) return;
    await Share.shareXFiles([
      XFile(_resultPath!),
    ], text: _isEncryptMode ? 'ChaosCrypt 加密文件 (.lzu)' : 'ChaosCrypt 解密文件');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 标题 ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                primary.withValues(alpha: 0.2),
                                primary.withValues(alpha: 0.05),
                              ]
                            : [
                                primary.withValues(alpha: 0.1),
                                primary.withValues(alpha: 0.03),
                              ],
                      ),
                    ),
                    child: Icon(Icons.lock, color: primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('文件加密', style: theme.textTheme.headlineMedium),
                        Text(
                          'File Encryption (.lzu)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? primary.withValues(alpha: 0.7)
                                : secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 加密/解密模式切换 ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeButton(
                          label: '加密',
                          icon: Icons.lock_outline,
                          isSelected: _isEncryptMode,
                          onTap: () => setState(() {
                            _isEncryptMode = true;
                            _selectedFilePath = null;
                            _selectedFileName = null;
                            _resultPath = null;
                            _resultMessage = null;
                          }),
                        ),
                      ),
                      Expanded(
                        child: _ModeButton(
                          label: '解密',
                          icon: Icons.lock_open,
                          isSelected: !_isEncryptMode,
                          onTap: () => setState(() {
                            _isEncryptMode = false;
                            _selectedFilePath = null;
                            _selectedFileName = null;
                            _resultPath = null;
                            _resultMessage = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 文件选择区 ──
              _buildFileDropZone(theme, isDark, primary),
              const SizedBox(height: 16),

              // ── 处理进度 ──
              if (_isProcessing) _buildProgressSection(theme, isDark, primary),

              // ── 结果展示 ──
              if (_resultMessage != null && !_isProcessing)
                _buildResultSection(theme, isDark, primary),

              const SizedBox(height: 16),

              // ── 操作按钮 ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_selectedFilePath != null && !_isProcessing)
                          ? _processFile
                          : null,
                      icon: Icon(
                        _isEncryptMode
                            ? Icons.enhanced_encryption
                            : Icons.lock_open,
                      ),
                      label: Text(_isEncryptMode ? '开始加密' : '开始解密'),
                    ),
                  ),
                  if (_resultPath != null) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.share),
                      label: const Text('分享'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileDropZone(ThemeData theme, bool isDark, Color primary) {
    return GestureDetector(
      onTap: _isProcessing ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedFilePath != null
                ? primary
                : (isDark ? Colors.white12 : Colors.black12),
            width: _selectedFilePath != null ? 2 : 1,
          ),
          color: _selectedFilePath != null
              ? primary.withValues(alpha: isDark ? 0.08 : 0.04)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02)),
        ),
        child: Column(
          children: [
            Icon(
              _selectedFilePath != null
                  ? (_isEncryptMode ? Icons.insert_drive_file : Icons.lock)
                  : Icons.cloud_upload_outlined,
              size: 48,
              color: _selectedFilePath != null
                  ? primary
                  : (isDark ? Colors.white24 : Colors.black26),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFileName ?? '点击选择文件',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _selectedFilePath != null
                    ? primary
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedFilePath == null) ...[
              const SizedBox(height: 4),
              Text(
                _isEncryptMode ? '支持任意文件类型' : '仅支持 .lzu 文件',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme, bool isDark, Color primary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _isEncryptMode ? '正在加密...' : '正在解密...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(ThemeData theme, bool isDark, Color primary) {
    final isSuccess = _resultPath != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSuccess
                    ? AppColors.green.withValues(alpha: 0.15)
                    : AppColors.red.withValues(alpha: 0.15),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? AppColors.green : AppColors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSuccess ? '操作成功' : '操作失败',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSuccess ? AppColors.green : AppColors.red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _resultMessage ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [
                          primary.withValues(alpha: 0.3),
                          primary.withValues(alpha: 0.1),
                        ]
                      : [
                          primary.withValues(alpha: 0.15),
                          primary.withValues(alpha: 0.05),
                        ],
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? primary
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? primary
                    : (isDark ? Colors.white38 : Colors.black38),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
