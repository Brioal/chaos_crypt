import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart'; // Added import
import '../../core/services/crypto_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_utils.dart';

class FileEncryptScreen extends StatefulWidget {
  final ValueNotifier<String?>? intentFileNotifier;

  const FileEncryptScreen({super.key, this.intentFileNotifier});

  @override
  State<FileEncryptScreen> createState() => FileEncryptScreenState();
}

class FileEncryptScreenState extends State<FileEncryptScreen>
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
    // Listen to external notifier
    widget.intentFileNotifier?.addListener(_onIntentFileChanged);
    // Check initial value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onIntentFileChanged();
    });
  }

  @override
  void dispose() {
    widget.intentFileNotifier?.removeListener(_onIntentFileChanged);
    super.dispose();
  }

  void _onIntentFileChanged() {
    final path = widget.intentFileNotifier?.value;
    if (path != null && path.isNotEmpty) {
      handleSharedFile(path);
      // Consume the event
      widget.intentFileNotifier?.value = null;
    }
  }

  // Public method to handle shared file path
  void handleSharedFile(String path) {
    if (path.isNotEmpty) {
      setState(() {
        _isEncryptMode = false; // Switch to Decrypt mode
        _selectedFilePath = path;
        _selectedFileName = path.split(Platform.pathSeparator).last;
        _resultPath = null;
        _resultMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已加载文件: $_selectedFileName')));
      }
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    if (_isEncryptMode) {
      result = await FilePicker.platform.pickFiles();
    } else {
      result = await FilePicker.platform.pickFiles(type: FileType.any);
    }

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;

      // Validation for Decrypt mode
      if (!_isEncryptMode) {
        if (!path.toLowerCase().endsWith('.lzu')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('不支持的文件类型：仅支持 .lzu 文件'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final name = result.files.single.name;

      setState(() {
        _selectedFilePath = path;
        _selectedFileName = name;
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
        final fileName = _selectedFileName ?? 'file';
        final outPath = '${dir.path}/$fileName.lzu';
        result = await CryptoService.encryptFile(inputFile.path, outPath);
      } else {
        // Decrypt handles path generation internally (to ChaosCrypt folder)
        result = await CryptoService.decryptFile(inputFile.path);
      }

      final outSize = await File(result.path).length();
      final inSize = await inputFile.length();
      final name = result.path.split(Platform.pathSeparator).last;

      setState(() {
        _resultPath = result.path;
        final inLabel = _isEncryptMode ? '原始大小' : '加密大小';
        final outLabel = _isEncryptMode ? '加密大小' : '解密大小';

        _resultMessage =
            '文件名称: $name\n'
            '耗时: ${FormatUtils.formatTime(result.timeMs)}\n'
            '速度: ${FormatUtils.formatSpeedGbps(result.speedGbps)}\n'
            '$inLabel: ${FormatUtils.formatSize(inSize)}\n'
            '$outLabel: ${FormatUtils.formatSize(outSize)}\n'
            '输出路径: ${result.path}';
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

  // Added View File method
  Future<void> _viewFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('打开文件失败: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件出错: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            if (_selectedFilePath != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _viewFile(_selectedFilePath!),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('系统查看'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                ),
              ),
            ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isSuccess && _resultPath != null) ...[
              const SizedBox(height: 12),
              // Separator
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _viewFile(_resultPath!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('系统查看'),
                  ),
                ],
              ),
            ],
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
