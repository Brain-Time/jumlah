import 'dart:io';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/screens/home/home_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_audioplayers_platform.dart';
import 'sqlite_ffi_test_setup.dart';

/// Task F1 — Integrationstest „Kompletter Lerndurchlauf“.
///
/// Faehrt den echten Fluss durch die echten Screens (mit echten SQLite-Daten
/// aus den JSON-Assets) ab: HomeScreen → Sprachniveau A1 → Lektions-Liste →
/// Lektion 1 (Lern-Screen, durch alle 10 Woerter) → „Zum Quiz“ → Quiz-Screen
/// oeffnet mit Stufe 1/6. Der 6-stufige Quiz-Durchlauf selbst wird separat in
/// `quiz_screen_test.dart`/`quiz_story_phase_test.dart` abgedeckt.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_flow_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);

    // audioplayers-Mock: Der Learn-/Quiz-Screen erzeugt beim ersten Aufruf
    // den `AudioService`-Singleton mit einem echten `AudioPlayer`. Dessen
    // Konstruktor abonniert Plattform-EventStreams (`…/global/events` und das
    // dynamische `…/events/<playerId>`); ohne Mock wuerde das im Widget-Test
    // MissingPluginExceptions ausloesen. Wir ersetzen die beiden
    // audioplayers-Plattform-Interfaces deshalb durch deterministische
    // No-op-Fakes (offizieller Test-Ansatz der Bibliothek). Wiedergabe wird
    // in diesem Durchlauf ohnehin nie gestartet.
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
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
    'Kompletter Lerndurchlauf: Home → A1 → Lektion 1 → alle Woerter → Zum Quiz',
    (tester) async {
      // Echte Daten aus den JSON-Assets in SQLite importieren (wie beim
      // realen App-Start ueber den SplashScreen).
      await tester.runAsync(() async {
        await DatabaseHelper.instance.reimportAssetDataIfVersionChanged();
        await DatabaseHelper.instance.importWordsIfNeeded();
        await DatabaseHelper.instance.importSentencesIfNeeded();
        await DatabaseHelper.instance.importRootsIfNeeded();
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: HomeScreen())),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      // 1) Home-Screen zeigt das (einzige aktive) Sprachniveau A1.
      expect(find.text('Sprachniveau A1 · Grundstufe'), findsOneWidget);

      // 2) Tippen oeffnet die Lektions-Liste (BatchListScreen, learn-Modus).
      await tester.runAsync(() async {
        // Der Learn-Tab ist durch die Home-Karten länger geworden — die
        // A1-Kachel liegt im Test-Viewport u.U. unterhalb des Folds.
        await tester.scrollUntilVisible(
          find.text('Sprachniveau A1 · Grundstufe'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(find.text('Sprachniveau A1 · Grundstufe'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });
      // Lektion 1 (Rang 1–10) ist gratis offen (Liste ist lazy — spätere,
      // gesperrte Lektionen werden erst nach Scrollen gerendert).
      expect(find.text('Lektion 1 · Wörter 1–10'), findsOneWidget);

      // 3) Lektion 1 oeffnen → Learn-Screen mit dem ersten Wort (كَتَبَ).
      await tester.runAsync(() async {
        await tester.tap(find.text('Lektion 1 · Wörter 1–10'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });
      expect(find.text('كَتَبَ'), findsOneWidget);
      expect(find.text('schreiben'), findsOneWidget);
      expect(find.text('1 / 10'), findsOneWidget);

      // 4) Durch alle 10 Woerter der Lektion blättern („Weiter“). Der letzte
      //    Wortwechsel markiert den Lernpfad (markBatchLearned) — daher der
      //    ganze Durchlauf innerhalb von runAsync.
      for (var i = 0; i < 9; i++) {
        await tester.runAsync(() async {
          await tester.tap(find.text('Weiter'));
          await tester.pump(const Duration(milliseconds: 350));
        });
      }

      // Am letzten Wort erscheint statt „Weiter“ der „Zum Quiz“-Button.
      expect(find.text('10 / 10'), findsOneWidget);
      expect(find.text('Zum Quiz'), findsOneWidget);

      // 5) „Zum Quiz“ pusht den Quiz-Screen mit den echten Batch-Daten und
      //    laedt dabei (getrackt: group/A1 + batchIndex) die Geschichte.
      await tester.runAsync(() async {
        await tester.tap(find.text('Zum Quiz'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();
      });

      // Quiz-Screen oeffnet mit Stufe 1 der 6-Stufen-Schulpruefung.
      expect(find.text('Stufe 1/6 · Arabisch → Deutsch'), findsOneWidget);
    },
  );
}
