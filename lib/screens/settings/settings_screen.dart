import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../main.dart'; // To access ChaosCryptApp.toggleTheme/isDarkMode

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  int _threadCount = 4;
  bool _isLoading = true;
  // Recommended core count
  late int _recommendedThreads;

  @override
  void initState() {
    super.initState();
    _recommendedThreads = Platform.numberOfProcessors;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _passwordController.text =
          prefs.getString('encryption_key') ?? "ChaosCryptDefaultKey123";
      _threadCount = prefs.getInt('thread_count') ?? _recommendedThreads;
      _isLoading = false;
    });
  }

  Future<void> _savePassword(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('encryption_key', value);
  }

  Future<void> _saveThreadCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('thread_count', value);
    setState(() {
      _threadCount = value;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──
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
                                  primary.withValues(alpha: 0.2),
                                  primary.withValues(alpha: 0.05),
                                ]
                              : [
                                  primary.withValues(alpha: 0.1),
                                  primary.withValues(alpha: 0.03),
                                ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const BackButton(),
                          Icon(Icons.settings, color: primary),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('设置', style: theme.textTheme.headlineMedium),
                          Text(
                            'Settings & Configuration',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? primary.withValues(alpha: 0.7)
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

            // ── Encryption Settings ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '加密配置 (File Encryption)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          // Password
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: '全局加密密码',
                                helperText: '用于所有文件加密操作，请谨记此密码！',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              onChanged: _savePassword,
                            ),
                          ),
                          const Divider(height: 1),
                          // Thread Count
                          ListTile(
                            title: const Text('并行线程数'),
                            subtitle: Text(
                              '当前设置: $_threadCount 线程\n推荐: $_recommendedThreads (核心数)',
                            ),
                            trailing: DropdownButton<int>(
                              value: _threadCount,
                              underline: const SizedBox(),
                              items: [1, 2, 4, 6, 8, 12, 16].map((e) {
                                bool isRec = e == _recommendedThreads;
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    '$e${isRec ? " (推荐)" : ""}',
                                    style: TextStyle(
                                      fontWeight: isRec
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isRec ? primary : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) _saveThreadCount(v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Preferences ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '应用偏好',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('深色模式'),
                            subtitle: const Text('切换应用主题外观'),
                            secondary: const Icon(Icons.dark_mode_outlined),
                            value: isDark,
                            onChanged: (_) =>
                                ChaosCryptApp.toggleTheme(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── About ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '关于',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('版本'),
                            trailing: Text(
                              '1.0.0',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.security),
                            title: const Text('加密算法'),
                            subtitle: const Text('基于混沌理论 (Chaos Theory) 的混合加密'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () => _showAlgorithmInfo(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.code),
                            title: const Text('核心实现'),
                            subtitle: const Text('C++ Native Layer (FFI)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Powered by Flutter & C++',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlgorithmInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于混沌加密'),
        content: const SingleChildScrollView(
          child: Text(
            '本应用采用兰州大学完全自主研发的超混沌随机数生成算法和加密算法。\n\n'
            '技术亮点：\n'
            '1. 超混沌系统：引入更高维度的混沌映射，大幅提升系统的复杂度和熵值。\n'
            '2. 动态密钥空间：基于用户输入的初始密钥，动态生成海量的混沌参数空间。\n'
            '3. 混合加密机制：结合流密码与分组密码的特性，实现高效且安全的加密过程。\n\n'
            '该方案在随机性检测（NIST SP800-22）和抗攻击能力上均表现优异。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
}
