import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/core/theme/app_theme.dart';
import 'package:jumlah/providers/theme_provider.dart';
import 'package:jumlah/screens/info/info_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

/// Test-Harness, das wie `main.dart` den aktiven Design-Modus aus dem Provider
/// in die `MaterialApp` reicht und die `AppColors`-Palette umschaltet — nur so
/// lässt sich der komplette Dark/Light-Flow (Provider → Theme → MaterialApp)
/// in einem Widget-Test prüfen.
class _ThemeAwareApp extends ConsumerWidget {
  const _ThemeAwareApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    AppColors.use(theme);
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme == ThemeKind.light ? ThemeMode.light : ThemeMode.dark,
      // Keine animierten Übergänge, damit der Theme-Wechsel im Test sofort
      // am Element ablesbar ist.
      themeAnimationStyle: AnimationStyle.noAnimation,
      home: home,
    );
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_theme_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dbFile = File(p.join(tempDir.path, DatabaseHelper.databaseName));
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  tearDown(() {
    // Globale AppColors-Palette nicht in andere Tests des Files leaken.
    AppColors.use(ThemeKind.dark);
  });

  test('ThemeNotifier startet mit Dunkel und persistiert die Wahl', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Default ohne gespeichertes Design: Dunkel (bisheriger App-Look).
    expect(container.read(themeProvider), ThemeKind.dark);
    expect(AppColors.activeTheme, ThemeKind.dark);

    // Wechseln + Persistenz in der SQLite-metadata-Tabelle.
    await container.read(themeProvider.notifier).setTheme(ThemeKind.light);
    expect(container.read(themeProvider), ThemeKind.light);
    expect(await DatabaseHelper.instance.getThemeMode(), 'light');

    // Zurück auf Dunkel + Persistenz.
    await container.read(themeProvider.notifier).setTheme(ThemeKind.dark);
    expect(container.read(themeProvider), ThemeKind.dark);
    expect(await DatabaseHelper.instance.getThemeMode(), 'dark');
  });

  test('restoreSaved stellt den gespeicherten Design-Modus wieder her',
      () async {
    // Light zuerst persistieren.
    await DatabaseHelper.instance.saveThemeMode('light');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeProvider), ThemeKind.dark);
    await container.read(themeProvider.notifier).restoreSaved();
    expect(container.read(themeProvider), ThemeKind.light);
  });

  test('restoreSaved ohne gespeicherten Wert bleibt bei Dunkel (Standard)',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeProvider.notifier).restoreSaved();
    expect(container.read(themeProvider), ThemeKind.dark);
  });

  testWidgets(
    'Design-Karte im Info-Screen wechselt die App sofort (Dunkel → Hell → '
        'Dunkel)',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(
            child: _ThemeAwareApp(home: InfoScreen()),
          ),
        );
        await tester.pump();
      });

      // Dunkel aktiv: deutsche Design-Karte sichtbar, Theme dunkel.
      expect(find.text('Design'), findsOneWidget);
      expect(find.text('Dunkel'), findsOneWidget);
      expect(find.text('Hell'), findsOneWidget);
      expect(AppColors.activeTheme, ThemeKind.dark);
      expect(
        Theme.of(tester.element(find.text('Design'))).brightness,
        Brightness.dark,
      );

      // Auf Hell umschalten → MaterialApp-Theme und AppColors-Palette wechseln.
      await tester.tap(find.text('Hell'));
      await tester.pump();
      await tester.pump();
      expect(AppColors.activeTheme, ThemeKind.light);
      expect(
        Theme.of(tester.element(find.text('Design'))).brightness,
        Brightness.light,
      );

      // Zurück auf Dunkel.
      await tester.tap(find.text('Dunkel'));
      await tester.pump();
      await tester.pump();
      expect(AppColors.activeTheme, ThemeKind.dark);
      expect(
        Theme.of(tester.element(find.text('Design'))).brightness,
        Brightness.dark,
      );
    },
  );
}