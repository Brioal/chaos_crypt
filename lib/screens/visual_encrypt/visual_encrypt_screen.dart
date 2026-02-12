import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/services/crypto_service.dart';
import 'widgets/image_compare_widget.dart';
import 'widgets/histogram_widget.dart';

class VisualEncryptScreen extends StatefulWidget {
  const VisualEncryptScreen({super.key});

  @override
  State<VisualEncryptScreen> createState() => _VisualEncryptScreenState();
}

class _VisualEncryptScreenState extends State<VisualEncryptScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _originalBytes;
  Uint8List? _encryptedBytes;
  Map<String, List<int>>? _originalHist;
  Map<String, List<int>>? _encryptedHist;
  bool _isProcessing = false;
  String? _sourceName;
  late AnimationController _pulseController;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSampleImage(String name) async {
    setState(() => _isProcessing = true);
    try {
      final data = await rootBundle.load('assets/images/$name.png');
      final bytes = data.buffer.asUint8List();
      await _processImage(bytes, name);
    } catch (e) {
      _showError('加载样本图失败: $e');
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      setState(() => _isProcessing = true);
      final bytes = await picked.readAsBytes();
      await _processImage(bytes, '拍摄照片');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      setState(() => _isProcessing = true);
      final bytes = await picked.readAsBytes();
      await _processImage(bytes, '相册图片');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(Uint8List bytes, String name) async {
    // 模拟加密延迟
    // await Future.delayed(const Duration(milliseconds: 300)); // Remove fake delay, real encryption takes time
    final encrypted = await CryptoService.encryptImageBytes(bytes);
    final origHist = await CryptoService.computeHistogram(bytes);
    final encHist = await CryptoService.computeHistogram(encrypted);

    if (mounted) {
      setState(() {
        _originalBytes = bytes;
        _encryptedBytes = encrypted;
        _originalHist = origHist;
        _encryptedHist = encHist;
        _sourceName = name;
      });
    }
  }

  Future<void> _shareResult() async {
    if (_encryptedBytes == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/encrypted_${_sourceName ?? "image"}.png');
      await file.writeAsBytes(_encryptedBytes!);
      await Share.shareXFiles([XFile(file.path)], text: 'ChaosCrypt 加密图像');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── 标题栏 ──
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
                          Text('可视化加密', style: theme.textTheme.headlineMedium),
                          Text(
                            'Visual Encryption Demo',
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

            // ── 图片来源选择 ──
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

            // ── 处理中指示 ──
            if (_isProcessing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Container(
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
                        Text('混沌置乱加密中...', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),

            // ── 图片对比 ──
            if (_originalBytes != null && _encryptedBytes != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ImageCompareWidget(
                    originalBytes: _originalBytes!,
                    encryptedBytes: _encryptedBytes!,
                    sourceName: _sourceName ?? '',
                  ),
                ),
              ),

              // ── 直方图 ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: HistogramWidget(
                    originalHist: _originalHist!,
                    encryptedHist: _encryptedHist!,
                  ),
                ),
              ),

              // ── 分享按钮 ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.share),
                      label: const Text('分享加密结果'),
                    ),
                  ),
                ),
              ),
            ],

            // ── 空状态 ──
            if (_originalBytes == null && !_isProcessing)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) => Opacity(
                          opacity: 0.3 + _pulseController.value * 0.4,
                          child: Icon(
                            Icons.lock_outline,
                            size: 80,
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '选择一张图片开始加密演示',
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
