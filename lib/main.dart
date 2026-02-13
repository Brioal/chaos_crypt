import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChaosCryptApp());
}

class ChaosCryptApp extends StatefulWidget {
  const ChaosCryptApp({super.key});

  /// Global key for theme switching
  static final GlobalKey<_ChaosCryptAppState> appKey =
      GlobalKey<_ChaosCryptAppState>();

  static void toggleTheme(BuildContext context) {
    context.findAncestorStateOfType<_ChaosCryptAppState>()?.toggleTheme();
  }

  static bool isDarkMode(BuildContext context) {
    return context
            .findAncestorStateOfType<_ChaosCryptAppState>()
            ?._isDarkMode ??
        true;
  }

  @override
  State<ChaosCryptApp> createState() => _ChaosCryptAppState();
}

class _ChaosCryptAppState extends State<ChaosCryptApp> {
  bool _isDarkMode = true;

  void toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPassword();
    });
  }

  Future<void> _checkPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('encryption_key');
    if (key == null || key.isEmpty) {
      if (!mounted) return;
      _showSetupPasswordDialog();
    }
  }

  void _showSetupPasswordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('设置初始密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('欢迎使用兰州大学混沌加密演示软件。\n为了您的数据安全，请设置一个初始加密密码（至少8位）。'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final pwd = controller.text;
                if (pwd.length < 8) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('密码长度不能少于8位')));
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('encryption_key', pwd);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '兰州大学混沌加密演示软件',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainShell(),
    );
  }
}
