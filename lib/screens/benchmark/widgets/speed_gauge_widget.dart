import 'dart:math';
import 'package:flutter/material.dart';

class SpeedGaugeWidget extends StatelessWidget {
  final double speed;
  final double progress;
  final bool isRunning;
  final bool isMultiThread;
  final int elapsedMs;
  final Animation<double> glowAnimation;

  const SpeedGaugeWidget({
    super.key,
    required this.speed,
    required this.progress,
    required this.isRunning,
    required this.isMultiThread,
    required this.elapsedMs,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 模式标签
            if (isRunning)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: (isMultiThread ? secondary : primary).withValues(
                    alpha: 0.15,
                  ),
                ),
                child: Text(
                  isMultiThread ? '⚡ 多线程 (OpenMP)' : '🔧 单线程',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMultiThread ? secondary : primary,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 仪表盘
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: glowAnimation,
                    builder: (_, __) {
                      return CustomPaint(
                        painter: _GaugePainter(
                          speed: speed,
                          maxSpeed: 1200,
                          progress: progress,
                          isRunning: isRunning,
                          glowFactor: glowAnimation.value,
                          primaryColor: primary,
                          secondaryColor: secondary,
                          isDark: isDark,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                speed.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: isRunning
                                      ? primary
                                      : (isDark
                                            ? Colors.white24
                                            : Colors.black12),
                                  height: 1,
                                ),
                              ),
                              Text(
                                'MB/s',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isRunning
                                      ? primary.withValues(alpha: 0.7)
                                      : (isDark
                                            ? Colors.white12
                                            : Colors.black12),
                                  letterSpacing: isDark ? 2 : 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final double progress;
  final bool isRunning;
  final double glowFactor;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  _GaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.progress,
    required this.isRunning,
    required this.glowFactor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const startAngle = 2.3; // ~132 degrees
    const sweepAngle = 4.5; // ~258 degrees

    // 背景弧
    final bgPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    if (!isRunning && speed == 0) return;

    // 速度弧
    final speedRatio = (speed / maxSpeed).clamp(0.0, 1.0);
    final speedSweep = sweepAngle * speedRatio;

    // 发光效果
    if (isDark) {
      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.15 + glowFactor * 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        speedSweep,
        false,
        glowPaint,
      );
    }

    // 主弧
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      speedSweep,
      false,
      arcPaint,
    );

    // 刻度线
    for (int i = 0; i <= 12; i++) {
      final tickAngle = startAngle + (sweepAngle / 12) * i;
      final isMajor = i % 3 == 0;
      final innerR = radius - (isMajor ? 18 : 12);
      final outerR = radius - 6;

      final p1 = Offset(
        center.dx + innerR * cos(tickAngle),
        center.dy + innerR * sin(tickAngle),
      );
      final p2 = Offset(
        center.dx + outerR * cos(tickAngle),
        center.dy + outerR * sin(tickAngle),
      );

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = isDark
              ? Colors.white.withValues(alpha: isMajor ? 0.3 : 0.1)
              : Colors.black.withValues(alpha: isMajor ? 0.2 : 0.08)
          ..strokeWidth = isMajor ? 2 : 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // 进度外环
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 12),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.progress != progress ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.glowFactor != glowFactor;
  }
}
