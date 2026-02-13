import 'package:flutter/material.dart';
// import '../main.dart'; // Unused
import 'visual_encrypt/visual_encrypt_screen.dart';
import 'file_encrypt/file_encrypt_screen.dart';
import 'benchmark/benchmark_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // 默认中间 tab（可视化加密）
  final _pageController = PageController(initialPage: 1);

  final _pages = const [
    FileEncryptScreen(),
    VisualEncryptScreen(),
    BenchmarkScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('兰州大学混沌加密演示软件'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? primaryColor.withValues(alpha: 0.2)
                  : theme.dividerColor,
              width: 1,
            ),
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.lock_outline, 0),
              activeIcon: _buildNavIcon(Icons.lock, 0, active: true),
              label: '文件加密',
            ),
            BottomNavigationBarItem(
              icon: _buildCenterNavIcon(false),
              activeIcon: _buildCenterNavIcon(true),
              label: '可视化',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.speed_outlined, 2),
              activeIcon: _buildNavIcon(Icons.speed, 2, active: true),
              label: '性能测试',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool active = false}) {
    return Icon(icon, size: 24);
  }

  Widget _buildCenterNavIcon(bool active) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? LinearGradient(
                colors: isDark
                    ? [primaryColor, theme.colorScheme.secondary]
                    : [primaryColor, primaryColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active ? null : primaryColor.withValues(alpha: 0.1),
        boxShadow: active
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.visibility,
        size: 26,
        color: active
            ? (isDark ? Colors.black : Colors.white)
            : primaryColor.withValues(alpha: 0.7),
      ),
    );
  }
}
