import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BenchmarkChartWidget extends StatelessWidget {
  final double singleThreadSpeed;
  final double multiThreadSpeed;
  final int singleThreadTimeMs;
  final int multiThreadTimeMs;
  final int dataSizeMB;

  const BenchmarkChartWidget({
    super.key,
    required this.singleThreadSpeed,
    required this.multiThreadSpeed,
    required this.singleThreadTimeMs,
    required this.multiThreadTimeMs,
    required this.dataSizeMB,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final speedup = multiThreadSpeed / singleThreadSpeed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, size: 18, color: primary),
                const SizedBox(width: 8),
                Text('性能对比', style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              AppColors.neonGreen.withValues(alpha: 0.2),
                              AppColors.neonGreen.withValues(alpha: 0.05),
                            ]
                          : [
                              AppColors.brandTeal.withValues(alpha: 0.15),
                              AppColors.brandTeal.withValues(alpha: 0.05),
                            ],
                    ),
                  ),
                  child: Text(
                    '${speedup.toStringAsFixed(1)}x 加速',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.neonGreen : AppColors.brandTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 柱状对比图 ──
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceEvenly,
                  maxY: (multiThreadSpeed * 1.3),
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(1)} MB/s',
                          TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final labels = ['单线程', 'OpenMP\n多线程'];
                          if (value.toInt() < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[value.toInt()],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: multiThreadSpeed / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: singleThreadSpeed,
                          width: 40,
                          color: isDark
                              ? primary.withValues(alpha: 0.6)
                              : primary.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: multiThreadSpeed * 1.3,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.03),
                          ),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: multiThreadSpeed,
                          width: 40,
                          gradient: LinearGradient(
                            colors: isDark
                                ? [primary, secondary]
                                : [primary, AppColors.brandTeal],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: multiThreadSpeed * 1.3,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.03),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              ),
            ),

            const SizedBox(height: 16),

            // ── 详细数据行 ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.03),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ResultColumn(
                      label: '单线程',
                      speed: singleThreadSpeed,
                      timeMs: singleThreadTimeMs,
                      color: isDark ? primary.withValues(alpha: 0.7) : primary,
                      isDark: isDark,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  Expanded(
                    child: _ResultColumn(
                      label: 'OpenMP 多线程',
                      speed: multiThreadSpeed,
                      timeMs: multiThreadTimeMs,
                      color: isDark ? secondary : AppColors.brandTeal,
                      isDark: isDark,
                    ),
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

class _ResultColumn extends StatelessWidget {
  final String label;
  final double speed;
  final int timeMs;
  final Color color;
  final bool isDark;

  const _ResultColumn({
    required this.label,
    required this.speed,
    required this.timeMs,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${speed.toStringAsFixed(1)} MB/s',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          '${(timeMs / 1000).toStringAsFixed(2)}s',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white24 : Colors.black38,
          ),
        ),
      ],
    );
  }
}
