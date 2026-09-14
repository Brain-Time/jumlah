import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/main.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_app_test_');
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
    'JumlahApp startet mit Splash, dann Onboarding (Erststart) und danach das Hauptmenü',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const ProviderScope(child: JumlahApp()));
        await tester.pump();

        // SplashScreen (Task E2) importiert die Assets im Hintergrund und
        // navigiert erst danach per pushReplacement weiter.
        expect(find.text('Jumlah'), findsOneWidget);

        // Wartet, bis Mindestanzeigedauer + Asset-Import abgeschlossen sind.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // Frische DB → erst der einmalige Erklär-Screen (First-Run-Onboarding).
        expect(find.text('Willkommen bei Jumlah'), findsOneWidget);

        // Onboarding abschließen → Startseite. CTA liegt im Test-Viewport
        // unterhalb des Folds → erst hinscrollen, dann tappen.
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
      expect(find.text('Lernen'), findsWidgets);
      expect(find.text('Quiz'), findsWidgets);
      expect(find.text('Info'), findsWidgets);
      expect(find.text('Store'), findsNothing);
    },
  );
}
