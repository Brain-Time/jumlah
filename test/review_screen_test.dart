import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/screens/review/review_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

/// Widget-Tests für den SM-2-Wiederholungs-Screen (Task: Spaced Repetition).
/// Der Screen lädt seine Queue über FutureBuilder/I/O aus einer echten
/// SQLite-DB — deshalb laufen pump-/Ladevorgänge wie in den anderen
/// Screen-Tests innerhalb von `tester.runAsync(...)`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_review_screen_test_');
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

  const wordA = Word(
    id: 1,
    arabic: 'كَتَبَ',
    german: 'schreiben',
    root: 'ك-ت-ب',
    group: 'A1',
    frequencyRank: 1,
    transliteration: 'kataba',
  );
  const wordB = Word(
    id: 2,
    arabic: 'قَرَأَ',
    german: 'lesen',
    root: 'ق-ر-أ',
    group: 'A1',
    frequencyRank: 2,
    transliteration: 'qaraʾa',
  );

  Future<void> pumpReviewScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ReviewScreen())),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
    });
  }

  testWidgets(
    'ReviewScreen zeigt den Leer-Zustand ohne faellige Woerter',
    (tester) async {
      await pumpReviewScreen(tester);

      expect(find.text('Alles erledigt'), findsOneWidget);
      expect(find.textContaining('keine Wörter fällig'), findsOneWidget);
    },
  );

  testWidgets(
    'ReviewScreen fuehrt durch die Wiederholung bis zur Zusammenfassung',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords([wordA, wordB]);
        await DatabaseHelper.instance.seedSm2ForBatch('A1', 0);
      });
      await pumpReviewScreen(tester);

      // Erstes Wort: Arabisch sichtbar, Antwort noch verdeckt.
      expect(find.text('كَتَبَ'), findsOneWidget);
      expect(find.text('schreiben'), findsNothing);

      await tester.runAsync(() async {
        await tester.tap(find.text('Antwort zeigen'));
        await tester.pump();
      });
      expect(find.text('schreiben'), findsOneWidget);
      expect(find.text('kataba'), findsOneWidget);

      // Bewertung q=4 -> naechstes Wort.
      await tester.runAsync(() async {
        await tester.tap(find.text('Perfekt'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await tester.pump();
      });
      expect(find.text('قَرَأَ'), findsOneWidget);

      // Zweites Wort bewerten -> Zusammenfassung.
      await tester.runAsync(() async {
        await tester.tap(find.text('Antwort zeigen'));
        await tester.pump();
        await tester.tap(find.text('Gut'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await tester.pump();
      });
      expect(find.text('Session abgeschlossen'), findsOneWidget);
      expect(find.text('2 von 2 Wörtern erinnert.'), findsOneWidget);

      // Beide Wörter haben jetzt Intervall > 0 und sind nicht mehr fällig.
      await tester.runAsync(() async {
        expect(await DatabaseHelper.instance.getDueSm2Count(DateTime.now()), 0);
      });
    },
  );

  testWidgets('ReviewScreen zaehlt vergessene Woerter nicht als erinnert', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DatabaseHelper.instance.insertWords([wordA]);
      await DatabaseHelper.instance.seedSm2ForBatch('A1', 0);
    });
    await pumpReviewScreen(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Antwort zeigen'));
      await tester.pump();
      await tester.tap(find.text('Vergessen'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await tester.pump();
    });

    expect(find.text('Session abgeschlossen'), findsOneWidget);
    expect(find.text('0 von 1 Wörtern erinnert.'), findsOneWidget);
    expect(find.textContaining('kommen morgen automatisch wieder'), findsOneWidget);

    // Vergessen (q=0): Intervall 1 Tag, EF sinkt auf 1.7.
    await tester.runAsync(() async {
      final state = await DatabaseHelper.instance.getSm2State(1);
      expect(state?.repetitions, 0);
      expect(state?.intervalDays, 1);
      expect(state?.easeFactor, closeTo(1.7, 1e-9));
    });
  });
}