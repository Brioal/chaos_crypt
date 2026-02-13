import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/crypto_service.dart';
import 'widgets/benchmark_chart_widget.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkResultItem {
  final int iteration;
  final bool isMultiThread;
  double? speedGbps;
  int? timeMs;
  bool isRunning;

  _BenchmarkResultItem({
    required this.iteration,
    required this.isMultiThread,
    this.speedGbps,
    this.timeMs,
    this.isRunning = true,
  });
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  int _selectedSizeMB = 100;
  int _selectedIterations = 5;
  final _sizes = [10, 100, 500, 1024];
  final _iterationOptions = [1, 3, 5, 10];

  bool _isTesting = false;
  String _statusMessage = "";

  // Results
  final List<_BenchmarkResultItem> _singleThreadResults = [];
  final List<_BenchmarkResultItem> _multiThreadResults = [];

  // Final summary
  double? _finalSingleAvg;
  double? _finalMultiAvg;
  int? _finalSingleTime;
  int? _finalMultiTime;

  StreamSubscription<BenchmarkProgress>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _startBenchmark() async {
    setState(() {
      _isTesting = true;
      _statusMessage = "初始化...";
      _singleThreadResults.clear();
      _multiThreadResults.clear();
      _finalSingleAvg = null;
      _finalMultiAvg = null;
      _finalSingleTime = null;
      _finalMultiTime = null;
    });

    try {
      // 1. Single Thread
      await _runBatch(false);

      // 2. Multi Thread
      if (mounted) await _runBatch(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('测试出错: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _statusMessage = "测试完成";
        });
      }
    }
  }

  Future<void> _runBatch(bool multiThread) async {
    setState(() {
      _statusMessage = multiThread ? "准备多线程测试..." : "准备单线程测试...";
    });

    final completer = Completer<void>();
    final targetList = multiThread ? _multiThreadResults : _singleThreadResults;

    _subscription =
        CryptoService.runBenchmark(
          dataSizeMB: _selectedSizeMB,
          multiThread: multiThread,
          iterations: _selectedIterations,
        ).listen(
          (p) {
            if (!mounted) return;

            // Update Status
            if (p.speedGbps == -1.0) {
              setState(() => _statusMessage = "正在生成测试文件 (不计入耗时)...");
              return;
            }

            if (p.iteration > 0) {
              setState(() {
                _statusMessage = multiThread ? "正在运行多线程测试..." : "正在运行单线程测试...";

                // Find or add item
                var resultIndex = targetList.indexWhere(
                  (r) => r.iteration == p.iteration,
                );
                if (resultIndex == -1) {
                  targetList.add(
                    _BenchmarkResultItem(
                      iteration: p.iteration,
                      isMultiThread: multiThread,
                    ),
                  );
                  resultIndex = targetList.length - 1;
                }

                final item = targetList[resultIndex];
                if (p.speedGbps > 0) {
                  // Completed this iteration
                  item.speedGbps = p.speedGbps;
                  item.timeMs = p.elapsedMs;
                  item.isRunning = false;
                }
              });
            }

            if (p.isComplete &&
                p.iteration == p.totalIterations &&
                p.speedGbps > 0) {
              // Batch complete
              _calculateAverage(multiThread);
              completer.complete();
              _subscription?.cancel();
            }
          },
          onError: (e) {
            debugPrint("Benchmark Error: $e");
            completer.complete();
          },
        );

    await completer.future;
  }

  void _calculateAverage(bool multiThread) {
    final list = multiThread ? _multiThreadResults : _singleThreadResults;
    if (list.isEmpty) return;

    double totalSpeed = 0;
    int totalTime = 0;
    int count = 0;
    for (var item in list) {
      if (item.speedGbps != null) {
        totalSpeed += item.speedGbps!;
        totalTime += item.timeMs ?? 0;
        count++;
      }
    }

    if (count > 0) {
      setState(() {
        if (multiThread) {
          _finalMultiAvg = totalSpeed / count;
          _finalMultiTime = (totalTime / count).round();
        } else {
          _finalSingleAvg = totalSpeed / count;
          _finalSingleTime = (totalTime / count).round();
        }
      });
    }
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
              // Header
              _buildHeader(theme, isDark, primary, secondary),
              const SizedBox(height: 24),

              // Settings
              _buildSettingsCard(theme, primary, isDark),
              const SizedBox(height: 16),

              // Status Indicator
              if (_isTesting && _statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Single Thread Section
              if (_singleThreadResults.isNotEmpty) ...[
                _buildSectionTitle(theme, "单线程测试 (Native)", icon: Icons.person),
                const SizedBox(height: 8),
                ..._singleThreadResults.map(
                  (item) => _buildResultBar(context, item, _finalSingleAvg),
                ),
                if (_finalSingleAvg != null)
                  _buildSummaryRow(
                    context,
                    _finalSingleAvg!,
                    _finalSingleTime,
                    false,
                  ),
                const SizedBox(height: 24),
              ],

              // Multi Thread Section
              if (_multiThreadResults.isNotEmpty) ...[
                _buildSectionTitle(theme, "多线程测试 (OpenMP)", icon: Icons.people),
                const SizedBox(height: 8),
                ..._multiThreadResults.map(
                  (item) => _buildResultBar(context, item, _finalMultiAvg),
                ),
                if (_finalMultiAvg != null)
                  _buildSummaryRow(
                    context,
                    _finalMultiAvg!,
                    _finalMultiTime,
                    true,
                  ),
                const SizedBox(height: 24),
              ],

              // Chart
              if (_finalSingleAvg != null && _finalMultiAvg != null)
                BenchmarkChartWidget(
                  singleThreadSpeed: _finalSingleAvg!,
                  multiThreadSpeed: _finalMultiAvg!,
                  singleThreadTimeMs: _finalSingleTime ?? 0,
                  multiThreadTimeMs: _finalMultiTime ?? 0,
                  dataSizeMB: _selectedSizeMB,
                ),

              const SizedBox(height: 32),

              // Start Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isTesting ? null : _startBenchmark,
                  icon: Icon(
                    _isTesting ? Icons.hourglass_empty : Icons.rocket_launch,
                  ),
                  label: Text(_isTesting ? '测试进行中...' : '开始基准测试'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBar(
    BuildContext context,
    _BenchmarkResultItem item,
    double? maxSpeedRef,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Calculate primitive fill width if we had a max reference,
    // but since it's streaming, just show full width progress or text.
    // User requested horizontal progress bars.

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            "R${item.iteration}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: item.isRunning
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(minHeight: 8),
                  )
                : LayoutBuilder(
                    builder: (ctx, constraints) {
                      // Simple bar based on visual aesthetic (max value scaling?)
                      // We don't have a definitive MAX yet until all are done.
                      // Let's simplify: Just a filled colored bar with the text inside/beside.
                      double pct = 1.0;
                      if (maxSpeedRef != null &&
                          maxSpeedRef > 0 &&
                          item.speedGbps != null) {
                        pct = (item.speedGbps! / (maxSpeedRef * 1.5)).clamp(
                          0.0,
                          1.0,
                        );
                      }

                      return Stack(
                        children: [
                          Container(
                            height: 16,
                            width: constraints.maxWidth * pct,
                            decoration: BoxDecoration(
                              color: item.isMultiThread
                                  ? Colors.purpleAccent
                                  : Colors.blueAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              item.isRunning
                  ? "..."
                  : "${item.speedGbps?.toStringAsFixed(2)} Gb/s",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    double avgSpeed,
    int? avgTime,
    bool isMulti,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isMulti ? Colors.purple : Colors.blue).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isMulti ? Colors.purple : Colors.blue).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isMulti ? "平均速度 (Multi)" : "平均速度 (Single)",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${avgSpeed.toStringAsFixed(3)} Gb/s",
                style: TextStyle(
                  fontSize: 16,
                  color: isMulti ? Colors.purple : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "平均耗时: ${avgTime ?? 0} ms",
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    String title, {
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    return Row(
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
                'Speed Benchmark · I/O & CPU',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? primary.withValues(alpha: 0.7) : secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(ThemeData theme, Color primary, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Iterations
            Row(
              children: [
                Icon(Icons.repeat, size: 18, color: primary),
                const SizedBox(width: 8),
                Text('测试轮数', style: theme.textTheme.titleMedium),
                const Spacer(),
                DropdownButton<int>(
                  value: _selectedIterations,
                  underline: const SizedBox(),
                  items: _iterationOptions
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text('$e 次')),
                      )
                      .toList(),
                  onChanged: _isTesting
                      ? null
                      : (v) {
                          if (v != null)
                            setState(() => _selectedIterations = v);
                        },
                ),
              ],
            ),
            const Divider(height: 24),
            // Size
            Row(
              children: [
                Icon(Icons.data_usage, size: 18, color: primary),
                const SizedBox(width: 8),
                Text('数据量', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: _sizes.map((size) {
                final isSelected = size == _selectedSizeMB;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: _isTesting
                          ? null
                          : () => setState(() => _selectedSizeMB = size),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? primary
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                        child: Text(
                          _formatSize(size),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
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
    );
  }
}
