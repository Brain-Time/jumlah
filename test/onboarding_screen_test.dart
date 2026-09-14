import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/screens/info/info_screen.dart';
import 'package:jumlah/screens/onboarding/onboarding_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'sqlite_ffi_test_setup.dart';

/// Test-Fake für `package:url_launcher`: zeichnet alle Launch-Aufrufe auf,
/// statt einen echten Browser zu öffnen (gleiches Muster wie in
/// `info_screen_test.dart`).
class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeUrlLauncherPlatform fakeLauncher;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_onboarding_test_');
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
    fakeLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  testWidgets('OnboardingScreen zeigt die erklärenden Sektionen und CTA', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );
      await tester.pump();
    });

    // Sichtbarer Kopfbereich.
    expect(find.text('Willkommen bei Jumlah'), findsOneWidget);
    expect(find.text('Klassisches Arabisch'), findsOneWidget);

    // Die unteren Sektionen + Support-Hinweis + CTA liegen im Test-Viewport
    // unterhalb des Folds und werden von der ListView lazy gebaut — erst
    // herscrollen, dann prüfen.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Lektion für Lektion'),
      200,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Offline & kostenlos'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Unterstütze die Entwicklung'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Entwickler unterstützen ☕'),
      200,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Los geht’s'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Los geht’s'), findsOneWidget);
  });

  testWidgets('Support-Tile öffnet die Ko-fi-URL im Browser', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );
      await tester.pump();

      // Support-Tile ist am Ende der Seite — erst hinscrollen.
      await tester.scrollUntilVisible(
        find.text('Entwickler unterstützen ☕'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Entwickler unterstützen ☕'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(fakeLauncher.launchedUrls, [InfoScreen.supportUrl]);
  });

  testWidgets(
    '„Los geht’s“ navigiert zur Startseite',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
        );
        await tester.pump();

        // CTA am Ende der Seite — erst hinscrollen.
        await tester.scrollUntilVisible(
          find.text('Los geht’s'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        // DB vorab in runAsync öffnen (Schema-Erstellung): Der HomeScreen
        // löst in seinem initState echte SQLite-I/O aus; das Lazy-Öffnen der
        // DB im FakeAsync-Kontext würde hängen (bewährtes Muster aus
        // home_screen_test/splash_screen_test).
        await DatabaseHelper.instance.isOnboardingSeen();

        // CTA führt zum HomeScreen (dessen initState echte SQLite-I/O auslöst).
        await tester.tap(find.text('Los geht’s'));
        await tester.pump(); // Navigation anstoßen
        // Echte Wartezeit: Routen-Transition + HomeScreen-InitState.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400)); // Transition
      });

      expect(find.text('Sprachniveau A1 · Grundstufe'), findsOneWidget);
    },
  );
}
