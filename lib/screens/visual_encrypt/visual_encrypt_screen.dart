import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/services/crypto_service.dart';
import 'widgets/histogram_widget.dart';
import 'widgets/image_compare_widget.dart';
import 'widgets/password_dialog.dart';

class VisualEncryptScreen extends StatefulWidget {
  final ValueNotifier<String?>? intentImageNotifier;

  const VisualEncryptScreen({super.key, this.intentImageNotifier});

  @override
  State<VisualEncryptScreen> createState() => _VisualEncryptScreenState();
}

class _VisualEncryptScreenState extends State<VisualEncryptScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _leftBytes;
  Uint8List? _rightBytes;
  Map<String, List<int>>? _leftHist;
  Map<String, List<int>>? _rightHist;

  bool _isEncryptMode = true;
  bool _isProcessing = false;
  String? _sourceName;
  String? _resultPath;
  String? _decryptInputPath;
  String? _statusMessage;

  late AnimationController _pulseController;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    widget.intentImageNotifier?.addListener(_onIntentImageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onIntentImageChanged();
    });
  }

  @override
  void dispose() {
    widget.intentImageNotifier?.removeListener(_onIntentImageChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onIntentImageChanged() {
    final path = widget.intentImageNotifier?.value;
    if (path == null || path.isEmpty) {
      return;
    }
    widget.intentImageNotifier?.value = null;

    if (!_isSupportedDecryptFile(path)) {
      _showError('不支持的文件类型，仅支持 .lzu_image');
      return;
    }

    _switchMode(false);
    _decryptInputPath = path;
    _decryptFromLzuPng(path);
  }

  void _switchMode(bool toEncrypt) {
    setState(() {
      _isEncryptMode = toEncrypt;
      _leftBytes = null;
      _rightBytes = null;
      _leftHist = null;
      _rightHist = null;
      _sourceName = null;
      _resultPath = null;
      _statusMessage = null;
      _decryptInputPath = null;
    });
  }

  Future<String?> _askDecryptPassword() async {
    final defaultKey = await CryptoService.getStoredKeyForUi();
    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (_) => PasswordDialog(title: '解密密码', defaultKey: defaultKey),
    );
  }

  Future<void> _loadSampleImage(String name) async {
    _prepareForNewOperation();
    try {
      final data = await rootBundle.load('assets/images/$name.png');
      final bytes = data.buffer.asUint8List();
      final tempPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}${name}_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);
      await _encryptFromPath(tempPath, sourceName: name);
      await _safeDelete(tempFile);
    } catch (e) {
      _showError('加载样本图失败: $e');
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;

    _prepareForNewOperation();
    try {
      await _encryptFromPath(picked.path, sourceName: '拍摄照片');
    } catch (e) {
      _showError('加密失败: $e');
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;

    _prepareForNewOperation();
    try {
      await _encryptFromPath(picked.path, sourceName: '相册图片');
    } catch (e) {
      _showError('加密失败: $e');
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _encryptFromPath(
    String imagePath, {
    required String sourceName,
  }) async {
    final originalBytes = await File(imagePath).readAsBytes();
    final result = await CryptoService.encryptImageFileToLzuImage(
      inputPath: imagePath,
      outputBaseName: p.basename(imagePath),
    );

    final leftHist = await CryptoService.computeHistogram(originalBytes);
    final rightHist = await CryptoService.computeHistogram(
      result.previewPngBytes,
    );

    if (!mounted) return;
    setState(() {
      _leftBytes = originalBytes;
      _rightBytes = result.previewPngBytes;
      _leftHist = leftHist;
      _rightHist = rightHist;
      _sourceName = sourceName;
      _resultPath = result.path;
      _statusMessage = '已使用全局默认密码加密\n输出路径: ${result.path}';
    });
  }

  Future<void> _pickDecryptFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    if (!_isSupportedDecryptFile(path)) {
      _showError('仅支持 .lzu_image 文件');
      return;
    }

    _prepareForNewOperation(decryptInputPath: path);
    await _decryptFromLzuPng(path);
  }

  Future<void> _decryptFromLzuPng(String path) async {
    _prepareForNewOperation(decryptInputPath: path);
    try {
      final password = await _askDecryptPassword();
      if (password == null || password.isEmpty) {
        return;
      }

      final encryptedPreview = await CryptoService.buildEncryptedImagePreview(
        path,
      );
      final result = await CryptoService.decryptLzuImageToImage(
        inputPath: path,
        key: password,
      );

      if (!mounted) return;
      setState(() {
        _leftBytes = encryptedPreview;
        _rightBytes = result.decryptedImageBytes;
        _leftHist = null;
        _rightHist = null;
        _sourceName = p.basename(path);
        _resultPath = result.path;
        _statusMessage =
            '已使用全局默认密码解密: ${result.originalFileName}\n输出路径: ${result.path}';
        _decryptInputPath = path;
      });
    } on ImageDecryptException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('解密失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _shareResult() async {
    if (_resultPath == null) return;
    try {
      await Share.shareXFiles(
        [XFile(_resultPath!)],
        text: _isEncryptMode
            ? 'ChaosCrypt 加密图像 (.lzu_image)'
            : 'ChaosCrypt 解密图像',
      );
    } catch (e) {
      _showError('分享失败: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _prepareForNewOperation({String? decryptInputPath}) {
    setState(() {
      _isProcessing = true;
      _leftBytes = null;
      _rightBytes = null;
      _leftHist = null;
      _rightHist = null;
      _sourceName = null;
      _resultPath = null;
      _statusMessage = null;
      _decryptInputPath = decryptInputPath;
    });
  }

  void _showImagePreview(Uint8List bytes, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isSupportedDecryptFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.lzu_image');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  primaryColor.withValues(alpha: 0.2),
                                  primaryColor.withValues(alpha: 0.05),
                                ]
                              : [
                                  primaryColor.withValues(alpha: 0.1),
                                  primaryColor.withValues(alpha: 0.03),
                                ],
                        ),
                      ),
                      child: Icon(Icons.visibility, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('图像加密', style: theme.textTheme.headlineMedium),
                          Text(
                            _isEncryptMode
                                ? 'Image Encryption (.lzu_image)'
                                : 'Image Decryption (.lzu_image)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? primaryColor.withValues(alpha: 0.7)
                                  : theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: '加密',
                            icon: Icons.lock_outline,
                            isSelected: _isEncryptMode,
                            onTap: _isProcessing
                                ? null
                                : () => _switchMode(true),
                          ),
                        ),
                        Expanded(
                          child: _ModeButton(
                            label: '解密',
                            icon: Icons.lock_open,
                            isSelected: !_isEncryptMode,
                            onTap: _isProcessing
                                ? null
                                : () => _switchMode(false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (_isEncryptMode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.image_search,
                                size: 18,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text('选择图片源', style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SourceChip(
                                icon: Icons.camera_alt,
                                label: '拍照',
                                onTap: _isProcessing ? null : _pickFromCamera,
                              ),
                              _SourceChip(
                                icon: Icons.photo_library,
                                label: '相册',
                                onTap: _isProcessing ? null : _pickFromGallery,
                              ),
                              _SourceChip(
                                icon: Icons.science,
                                label: 'Lena',
                                onTap: _isProcessing
                                    ? null
                                    : () => _loadSampleImage('lena'),
                              ),
                              _SourceChip(
                                icon: Icons.pets,
                                label: 'Mandrill',
                                onTap: _isProcessing
                                    ? null
                                    : () => _loadSampleImage('mandrill'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (!_isEncryptMode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 18,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '选择 .lzu_image 文件',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isProcessing
                                  ? null
                                  : _pickDecryptFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('从文件系统选择 .lzu_image'),
                            ),
                          ),
                          if (_decryptInputPath != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              p.basename(_decryptInputPath!),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_isProcessing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(
                                    alpha: 0.3 + _pulseController.value * 0.3,
                                  ),
                                  blurRadius: 12 + _pulseController.value * 12,
                                  spreadRadius: _pulseController.value * 4,
                                ),
                              ],
                            ),
                            child: CircularProgressIndicator(
                              color: primaryColor,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isEncryptMode ? '图像加密处理中...' : '图像解密处理中...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_isEncryptMode &&
                _leftBytes != null &&
                _rightBytes != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ImageCompareWidget(
                    originalBytes: _leftBytes!,
                    encryptedBytes: _rightBytes!,
                    sourceName: _sourceName ?? '',
                    onOriginalTap: () => _showImagePreview(_leftBytes!, '明文图'),
                    onEncryptedTap: () =>
                        _showImagePreview(_rightBytes!, '密文图'),
                  ),
                ),
              ),
              if (_leftHist != null && _rightHist != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: HistogramWidget(
                      originalHist: _leftHist!,
                      encryptedHist: _rightHist!,
                    ),
                  ),
                ),
            ],

            if (!_isEncryptMode && _leftBytes != null && _rightBytes != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('解密结果预览', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ImagePanel(
                                  bytes: _leftBytes!,
                                  label: '密文图',
                                  onTap: () =>
                                      _showImagePreview(_leftBytes!, '密文图'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ImagePanel(
                                  bytes: _rightBytes!,
                                  label: '明文图',
                                  onTap: () =>
                                      _showImagePreview(_rightBytes!, '明文图'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_statusMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _statusMessage!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ),

            if (_resultPath != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.share),
                      label: Text(_isEncryptMode ? '分享加密结果' : '分享解密结果'),
                    ),
                  ),
                ),
              ),

            if (_leftBytes == null && !_isProcessing)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Opacity(
                          opacity: 0.3 + _pulseController.value * 0.4,
                          child: Icon(
                            _isEncryptMode
                                ? Icons.lock_outline
                                : Icons.lock_open,
                            size: 80,
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isEncryptMode ? '选择一张图片开始加密' : '选择 .lzu_image 开始解密',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
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
  final VoidCallback? onTap;

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

class _SourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SourceChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary.withValues(alpha: isDark ? 0.3 : 0.2),
            ),
            color: primary.withValues(alpha: isDark ? 0.08 : 0.04),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  final VoidCallback? onTap;

  const _ImagePanel({required this.bytes, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              height: 150,
              width: double.infinity,
              gaplessPlayback: true,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
