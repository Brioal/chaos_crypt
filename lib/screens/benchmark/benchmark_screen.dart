import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/crypto_service.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/speed_gauge_widget.dart';
import 'widgets/benchmark_chart_widget.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen>
    with TickerProviderStateMixin {
  int _selectedSizeMB = 100;
  int _selectedIterations = 1;
  int _currentIteration = 1;
  int _totalIterations = 1;
  final _sizes = [10, 100, 500, 1024];
  final _iterationOptions = [1, 3, 5, 10];
  bool _isRunning = false;
  double _currentSpeed = 0;
  double _progress = 0;
  int _elapsedMs = 0;
  StreamSubscription<BenchmarkProgress>? _subscription;

  // 多线程/单线程结果
  double? _singleThreadResult;
  double? _multiThreadResult;
  int? _singleThreadTime;
  int? _multiThreadTime;
  bool _currentIsMulti = true;

  late AnimationController _glowController;
  late AnimationController _speedController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _speedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _glowController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  Future<void> _startBenchmark() async {
    // 先跑单线程再跑多线程
    setState(() {
      _isRunning = true;
      _singleThreadResult = null;
      _multiThreadResult = null;
      _singleThreadTime = null;
      _multiThreadTime = null;
    });

    // 单线程测试
    await _runSingle(false);
    // 多线程测试
    if (mounted) await _runSingle(true);

    if (mounted) setState(() => _isRunning = false);
  }

  Future<void> _runSingle(bool multiThread) async {
    setState(() {
      _currentIsMulti = multiThread;
      _currentSpeed = 0;
      _progress = 0;
      _elapsedMs = 0;
      _currentIteration = 0;
      _totalIterations = _selectedIterations;
    });

    final completer = Completer<void>();
    double totalSpeed = 0;
    int speedCount = 0;

    _subscription =
        CryptoService.runBenchmark(
          dataSizeMB: _selectedSizeMB,
          multiThread: multiThread,
          iterations: _selectedIterations,
        ).listen((p) {
          if (!mounted) return;
          setState(() {
            _currentSpeed = p.speedGbps;
            _progress = p.progress;
            _elapsedMs = p.elapsedMs;
            _currentIteration = p.iteration;
            _totalIterations = p.totalIterations;
          });
          if (p.speedGbps > 0) {
            totalSpeed += p.speedGbps;
            speedCount++;
          }

          if (p.isComplete && p.iteration == p.totalIterations) {
            final avgSpeed = speedCount > 0 ? totalSpeed / speedCount : 0.0;
            setState(() {
              if (multiThread) {
                _multiThreadResult = avgSpeed;
                _multiThreadTime = p.elapsedMs;
              } else {
                _singleThreadResult = avgSpeed;
                _singleThreadTime = p.elapsedMs;
              }
            });
            completer.complete();
          }
        }, onError: (_) => completer.complete());

    await completer.future;
    _subscription?.cancel();
  }

  String _formatSize(int mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '$mb MB';
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
                    child: Icon(Icons.speed, color: primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('极限性能', style: theme.textTheme.headlineMedium),
                        Text(
                          'Speed Benchmark · OpenMP',
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

              // ── 迭代次数选择 ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.repeat, size: 18, color: primary),
                          const SizedBox(width: 8),
                          Text(
                            '测试轮数 (取平均值)',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      DropdownButton<int>(
                        value: _selectedIterations,
                        underline: const SizedBox(),
                        items: _iterationOptions.map((e) {
                          return DropdownMenuItem(
                            value: e,
                            child: Text('$e 次'),
                          );
                        }).toList(),
                        onChanged: _isRunning
                            ? null
                            : (v) {
                                if (v != null)
                                  setState(() => _selectedIterations = v);
                              },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 数据大小选择 ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.data_usage, size: 18, color: primary),
                          const SizedBox(width: 8),
                          Text('虚拟数据量', style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _sizes.map((size) {
                          final isSelected = size == _selectedSizeMB;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: GestureDetector(
                                onTap: _isRunning
                                    ? null
                                    : () => setState(
                                        () => _selectedSizeMB = size,
                                      ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: isDark
                                                ? [primary, secondary]
                                                : [
                                                    primary,
                                                    primary.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                  ],
                                          )
                                        : null,
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                            color: isDark
                                                ? Colors.white12
                                                : Colors.black12,
                                          ),
                                  ),
                                  child: Text(
                                    _formatSize(size),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? (isDark
                                                ? Colors.black
                                                : Colors.white)
                                          : (isDark
                                                ? Colors.white54
                                                : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 速度仪表盘 ──
              SpeedGaugeWidget(
                speed: _currentSpeed,
                progress: _progress,
                isRunning: _isRunning,
                isMultiThread: _currentIsMulti,
                elapsedMs: _elapsedMs,
                glowAnimation: _glowController,
              ),
              const SizedBox(height: 16),

              // ── 实时数据卡片 ──
              if (_isRunning)
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: '实时速率',
                        value: '${_currentSpeed.toStringAsFixed(3)} Gb/s',
                        icon: Icons.bolt,
                        color: isDark
                            ? AppColors.neonGreen
                            : AppColors.brandTeal,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: '已用时间',
                        value: '${(_elapsedMs / 1000).toStringAsFixed(1)}s',
                        icon: Icons.timer,
                        color: isDark
                            ? AppColors.neonAmber
                            : AppColors.brandIndigo,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: '进度',
                        value:
                            '${(_progress * 100).toStringAsFixed(0)}% ($_currentIteration/$_totalIterations)',
                        icon: Icons.trending_up,
                        color: isDark
                            ? AppColors.neonPurple
                            : AppColors.accentRose,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

              // ── 对比图表 ──
              if (_singleThreadResult != null &&
                  _multiThreadResult != null) ...[
                const SizedBox(height: 16),
                BenchmarkChartWidget(
                  singleThreadSpeed: _singleThreadResult!,
                  multiThreadSpeed: _multiThreadResult!,
                  singleThreadTimeMs: _singleThreadTime ?? 0,
                  multiThreadTimeMs: _multiThreadTime ?? 0,
                  dataSizeMB: _selectedSizeMB,
                ),
              ],

              const SizedBox(height: 24),

              // ── 开始按钮 ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (_, __) {
                    return Container(
                      decoration: _isRunning
                          ? null
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(
                                    alpha: 0.2 + _glowController.value * 0.2,
                                  ),
                                  blurRadius: 12 + _glowController.value * 8,
                                  spreadRadius: _glowController.value * 2,
                                ),
                              ],
                            ),
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _startBenchmark,
                        icon: Icon(
                          _isRunning
                              ? Icons.hourglass_top
                              : Icons.rocket_launch,
                        ),
                        label: Text(_isRunning ? '测试运行中...' : '开始性能测试'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
