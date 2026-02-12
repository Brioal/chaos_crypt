import 'package:flutter/material.dart';
import '../../main.dart'; // To access ChaosCryptApp.toggleTheme/isDarkMode

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

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
                      child: Icon(Icons.settings, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('设置', style: theme.textTheme.headlineMedium),
                          Text(
                            'Settings & About',
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
                        '偏好设置',
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
            '本应用采用基于混沌映射（Logistic Map / Henon Map）的序列生成算法作为伪随机数发生器 (PRNG)。\n\n'
            '1. 密钥扩展：将用户密钥映射为混沌系统的初始值和控制参数。\n'
            '2. 序列生成：迭代混沌方程生成高熵的密钥流。\n'
            '3. 加密操作：将明文数据与密钥流进行异或 (XOR) 及置乱操作。\n\n'
            '优势：对初始条件极度敏感（蝴蝶效应），抗统计分析能力强。',
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
