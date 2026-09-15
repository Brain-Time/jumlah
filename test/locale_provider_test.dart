import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/l10n/l10n.dart';
import 'package:jumlah/providers/locale_provider.dart';
import 'package:jumlah/screens/info/info_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

/// Test-Harness, das wie `main.dart` die aktive Sprache aus dem Provider in die
/// `MaterialApp` reicht — nur so lässt sich der komplette H1-Flow (Provider →
/// Locale → Localizations → UI-Texte) in einem Widget-Test prüfen.
class _LocaleAwareApp extends ConsumerWidget {
  const _LocaleAwareApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      locale: locale,
      supportedLocales: LocaleNotifier.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
    tempDir = Directory.systemTemp.createTempSync('jumlah_locale_test_');
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

  test('LocaleNotifier startet mit Deutsch und persistiert die Wahl', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Default ohne gespeicherte Sprache: Deutsch.
    expect(container.read(localeProvider).languageCode, 'de');

    // Wechseln + Persistenz in der SQLite-metadata-Tabelle.
    await container
        .read(localeProvider.notifier)
        .setLocale(const Locale('en'));
    expect(container.read(localeProvider).languageCode, 'en');
    expect(await DatabaseHelper.instance.getLocaleCode(), 'en');
  });

  test('restoreSaved stellt die gespeicherte Sprache wieder her', () async {
    // Sprache zuerst persistieren.
    await DatabaseHelper.instance.saveLocaleCode('ar');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(localeProvider.notifier).restoreSaved();
    expect(container.read(localeProvider).languageCode, 'ar');
    expect(LocaleNotifier.supportedLocales, [
      const Locale('de'),
      const Locale('en'),
      const Locale('ar'),
    ]);
  });

  testWidgets(
    'Sprachumschalter im Info-Screen wechselt die UI sofort (DE → EN → AR, RTL)',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(
            child: _LocaleAwareApp(home: InfoScreen()),
          ),
        );
        await tester.pump();
      });

      // Deutsch aktiv: deutscher Support-Eintrag sichtbar.
      expect(find.text('Entwickler unterstützen ☕'), findsOneWidget);
      expect(find.text('Sprache'), findsOneWidget);

      // Auf Englisch umschalten.
      await tester.tap(find.text('English'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Support the developer ☕'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Entwickler unterstützen ☕'), findsNothing);

      // Auf Arabisch umschalten → RTL + arabische Texte.
      await tester.tap(find.text('العربية'));
      await tester.pump();
      await tester.pump();
      expect(find.text('ادعم المطوّر ☕'), findsOneWidget);
      expect(find.text('اللغة'), findsOneWidget);
      // RTL ist über die MaterialApp-Locale aktiv (BuildContext-Directionality).
      final directionality = Directionality.of(
        tester.element(find.text('ادعم المطوّر ☕')),
      );
      expect(directionality, TextDirection.rtl);

      // Zurück zu Deutsch.
      await tester.tap(find.text('Deutsch'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Entwickler unterstützen ☕'), findsOneWidget);
    },
  );

  testWidgets(
    'Screens ohne Localizations-Delegates fallen auf Deutsch zurück',
    (tester) async {
      // Bewusste Abwesenheit der Delegates: `context.l10n` muss trotzdem
      // deterministisch die deutsche Vorlage liefern (bestehende Tests &
      // Screens bleiben kompatibel).
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: InfoScreen())),
      );
      await tester.pump();
      expect(find.text('Entwickler unterstützen ☕'), findsOneWidget);
    },
  );
}