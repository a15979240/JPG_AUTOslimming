import 'package:flutter/material.dart';
import 'package:jpg_slimming/models/app_settings.dart';
import 'package:jpg_slimming/screens/home_screen.dart';
import 'package:jpg_slimming/services/background_service.dart';
import 'package:jpg_slimming/services/settings_service.dart';
import 'package:workmanager/workmanager.dart';

/// WorkManager background callback - 必須為頂層函式
@pragma('vm:entry-point')
void callbackDispatcher() {
  jpgSlimmingBackgroundCallback();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 WorkManager 背景任務（不阻塞 UI）
  try {
    await Workmanager().initialize(callbackDispatcher);
  } catch (e) {
    debugPrint('WorkManager 初始化失敗: $e');
  }

  runApp(const JpgSlimmingApp());
}

class JpgSlimmingApp extends StatefulWidget {
  const JpgSlimmingApp({super.key});

  @override
  State<JpgSlimmingApp> createState() => _JpgSlimmingAppState();
}

class _JpgSlimmingAppState extends State<JpgSlimmingApp> {
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    // 讀取已儲存的主題設定
    SettingsService.load().then((settings) {
      if (mounted) setState(() => _settings = settings);
    });
  }

  /// 主題切換：更新根層級主題並儲存
  void _onThemeChanged(AppTheme theme) {
    final updated = _settings?.copyWith(theme: theme) ??
        const AppSettings().copyWith(theme: theme);
    setState(() => _settings = updated);
    SettingsService.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _settings?.theme == AppTheme.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    return MaterialApp(
      title: 'JPG 瘦身工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: HomeScreen(
        theme: _settings?.theme ?? AppTheme.light,
        onThemeChanged: _onThemeChanged,
      ),
    );
  }
}
