import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/screens/splash/splash_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_splash_screen_test_');
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

  testWidgets(
    'Erststart: Splash importiert Assets und führt dann zum Onboarding-Screen',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SplashScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('Jumlah'), findsOneWidget);
        expect(find.text('جُمْلَة'), findsOneWidget);

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      });

      // Frische DB (onboarding_seen nicht gesetzt): nach dem Splash erscheint
      // der Erklär-Screen, noch nicht die Startseite.
      expect(find.text('Willkommen bei Jumlah'), findsOneWidget);
      expect(find.text('Sprachniveau A1 · Grundstufe'), findsNothing);

      // DB-Abfragen zwingend in runAsync (echte SQLite-I/O hängt sonst im
      // FakeAsync-Kontext und hält das sqflite-Serialisierungs-Lock).
      await tester.runAsync(() async {
        // Mark-on-show: das Flag wird bereits beim Anzeigen des Onboardings
        // vom Splash gesetzt, damit es nur beim allerersten Start erscheint.
        expect(await DatabaseHelper.instance.isOnboardingSeen(), isTrue);
        // Die drei Asset-Import-Tabellen wurden tatsächlich befüllt.
        expect(
          await DatabaseHelper.instance.getWordsByGroup('A1'),
          isNotEmpty,
        );
      });

      // Abschluss des Onboardings → Startseite. Der CTA liegt im Test-Viewport
      // unterhalb des Folds → erst hinscrollen, dann tappen (HomeScreen löst
      // in seinem initState echte SQLite-I/O aus — alles in runAsync).
      await tester.runAsync(() async {
        await tester.scrollUntilVisible(
          find.text('Los geht’s'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(find.text('Los geht’s'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      });
      expect(find.text('Sprachniveau A1 · Grundstufe'), findsOneWidget);
    },
  );

  testWidgets(
    'Folgestart: Onboarding bereits gesehen → Splash führt direkt zur Startseite',
    (tester) async {
      await tester.runAsync(() async {
        // Robuste, saubere DB-Basis: einen evtl. offenen Singleton-DB-Handle
        // aus dem vorherigen Test schließen, damit das Flag garantiert in
        // eine frische Datenbank geschrieben und vom Splash gelesen wird.
        await DatabaseHelper.instance.close();
        await DatabaseHelper.instance.markOnboardingSeen();

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SplashScreen()),
          ),
        );
        await tester.pump();

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      });

      // Kein Onboarding mehr (dessen CTA fehlt) — direkt das Hauptmenü.
      // (Hinweis: „Willkommen bei Jumlah“ steht auch im Home-Hero-Banner,
      // daher ist der Onboarding-CTA der eindeutige Unterscheider.)
      expect(find.text('Los geht’s'), findsNothing);
      expect(find.text('Sprachniveau A1 · Grundstufe'), findsOneWidget);
    },
  );
}
