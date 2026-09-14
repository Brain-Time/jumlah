import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/desktop_sqlite.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeSqliteForDesktopIfNeeded();
  runApp(const ProviderScope(child: JumlahApp()));
}

class JumlahApp extends StatelessWidget {
  const JumlahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jumlah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      // Task E2: SplashScreen importiert die Asset-Daten im Hintergrund und
      // navigiert danach selbst zu HomeScreen (siehe splash_screen.dart).
      home: const SplashScreen(),
    );
  }
}
