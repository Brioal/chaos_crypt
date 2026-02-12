import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HistogramWidget extends StatelessWidget {
  final Map<String, List<int>> originalHist;
  final Map<String, List<int>> encryptedHist;

  const HistogramWidget({
    super.key,
    required this.originalHist,
    required this.encryptedHist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, size: 18, color: primary),
                const SizedBox(width: 8),
                Text('RGB 直方图分析', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '明文图直方图应有明显峰谷，密文图应呈均匀分布',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 16),

            // 明文图直方图
            _buildSection(context, '明文图 直方图', originalHist, isDark),
            const SizedBox(height: 16),

            // 密文图直方图
            _buildSection(context, '密文图 直方图', encryptedHist, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    Map<String, List<int>> hist,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
              letterSpacing: isDark ? 1.0 : 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: Row(
            children: [
              Expanded(
                child: _ChannelHistogram(
                  data: hist['r']!,
                  color: AppColors.red,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ChannelHistogram(
                  data: hist['g']!,
                  color: AppColors.green,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ChannelHistogram(
                  data: hist['b']!,
                  color: AppColors.blue,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelHistogram extends StatelessWidget {
  final List<int> data;
  final Color color;
  final bool isDark;

  const _ChannelHistogram({
    required this.data,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // 下采样到 32 个 bins 以提升性能
    final binCount = 32;
    final binSize = 256 ~/ binCount;
    final bins = List.filled(binCount, 0);
    for (int i = 0; i < 256; i++) {
      bins[i ~/ binSize] += data[i];
    }
    final maxVal = bins.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxVal == 0) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
      ),
      padding: const EdgeInsets.all(4),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: maxVal,
          minY: 0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(binCount, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bins[i].toDouble(),
                  color: color.withValues(alpha: isDark ? 0.8 : 0.6),
                  width: 4,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}
