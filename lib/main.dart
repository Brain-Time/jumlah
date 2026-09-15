import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/desktop_sqlite.dart';
import 'core/theme/app_theme.dart';
import 'l10n/l10n.dart';
import 'providers/locale_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeSqliteForDesktopIfNeeded();
  runApp(const ProviderScope(child: JumlahApp()));
}

class JumlahApp extends ConsumerStatefulWidget {
  const JumlahApp({super.key});

  @override
  ConsumerState<JumlahApp> createState() => _JumlahAppState();
}

class _JumlahAppState extends ConsumerState<JumlahApp> {
  @override
  void initState() {
    super.initState();
    // H1 — Mehrsprachige UI: die zuletzt vom Nutzer gewählte Sprache wird
    // asynchron aus SQLite wiederhergestellt (Default ist Deutsch).
    Future.microtask(() => ref.read(localeProvider.notifier).restoreSaved());
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'Jumlah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      // H1 — Mehrsprachige UI (DE/EN/AR): Die aktive Sprache kommt aus dem
      // Riverpod-Provider; `AppLocalizations.localizationsDelegates` enthält
      // die App-Strings (ARB/gen_l10n) plus die Material/Built-in-Widget-
      // Übersetzungen und ermöglicht RTL für Arabisch.
      locale: locale,
      supportedLocales: LocaleNotifier.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Task E2: SplashScreen importiert die Asset-Daten im Hintergrund und
      // navigiert danach selbst zu HomeScreen (siehe splash_screen.dart).
      home: const SplashScreen(),
    );
  }
}
