import 'package:flutter/material.dart';
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
