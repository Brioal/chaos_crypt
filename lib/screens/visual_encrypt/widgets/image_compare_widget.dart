import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageCompareWidget extends StatelessWidget {
  final Uint8List originalBytes;
  final Uint8List encryptedBytes;
  final String sourceName;

  const ImageCompareWidget({
    super.key,
    required this.originalBytes,
    required this.encryptedBytes,
    required this.sourceName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Text('图像对比', style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: primaryColor.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    sourceName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ImagePanel(
                    bytes: originalBytes,
                    label: '明文图',
                    borderColor: isDark
                        ? primaryColor
                        : theme.colorScheme.primary,
                    isDark: isDark,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        color: secondaryColor,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '混沌\n加密',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                          color: secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _ImagePanel(
                    bytes: encryptedBytes,
                    label: '密文图',
                    borderColor: isDark
                        ? secondaryColor
                        : theme.colorScheme.secondary,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  final Color borderColor;
  final bool isDark;

  const _ImagePanel({
    required this.bytes,
    required this.label,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 150,
              gaplessPlayback: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: borderColor.withValues(alpha: isDark ? 0.15 : 0.08),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: borderColor,
              letterSpacing: isDark ? 1.5 : 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
