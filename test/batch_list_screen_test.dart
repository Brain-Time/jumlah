import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/screens/home/batch_list_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync(
      'jumlah_batch_list_screen_test_',
    );
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

  // 15 Woerter -> 2 Batches (10 + 5), Grundlage fuer die sequenzielle
  // Freischaltung.
  List<Word> buildWords() => [
    for (var i = 1; i <= 15; i++)
      Word(
        id: i,
        arabic: 'ك$i',
        german: 'wort$i',
        root: 'ك-ت-ب',
        group: 'A1',
        frequencyRank: i,
        transliteration: 'kalima$i',
      ),
  ];

  testWidgets('erster Batch ist offen, zweiter Batch ist gesperrt', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DatabaseHelper.instance.insertWords(buildWords());
      // Lernpfad von Batch 1 abgeschlossen (Sicherheitsregel: Quiz erst nach
      // fertigem Lernpfad spielbar).
      await DatabaseHelper.instance.markBatchLearned('A1', 0);
      await tester.pumpWidget(
        const MaterialApp(
          home: BatchListScreen(group: 'A1', mode: BatchListMode.quiz),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    expect(find.textContaining('Lektion 1 · Wörter 1–10'), findsOneWidget);
    expect(find.textContaining('Lektion 2 · Wörter 11–15'), findsOneWidget);
    // Batch 1 offen (Pfeil), Batch 2 gesperrt (Schloss).
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    // Tap auf gesperrten Batch loest Hinweis statt Navigation aus.
    await tester.tap(find.textContaining('Lektion 2'));
    await tester.pump();
    expect(
      find.textContaining('Erst die vorherige Lektion fehlerfrei bestehen'),
      findsOneWidget,
    );
  });

  testWidgets(
    'bestandener Batch zeigt Haken, dadurch ist der naechste Batch offen',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords(buildWords());
        await DatabaseHelper.instance.markBatchPassed('A1', 0);
        await DatabaseHelper.instance.markBatchLearned('A1', 1);
        await tester.pumpWidget(
          const MaterialApp(
            home: BatchListScreen(group: 'A1', mode: BatchListMode.quiz),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      // Batch 1 bestanden (Haken), Batch 2 dadurch offen (Pfeil), keine
      // Gesamtpruefung-Kachel (noch nicht alle Batches bestanden).
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.text('Gesamtprüfung'), findsNothing);
    },
  );

  testWidgets(
    'alle Batches bestanden zeigt zusaetzlich die Gesamtpruefung-Kachel',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords(buildWords());
        await DatabaseHelper.instance.markBatchPassed('A1', 0);
        await DatabaseHelper.instance.markBatchPassed('A1', 1);
        await tester.pumpWidget(
          const MaterialApp(
            home: BatchListScreen(group: 'A1', mode: BatchListMode.quiz),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      expect(find.text('Gesamtprüfung'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.lock), findsNothing);
    },
  );

  testWidgets(
    'Quiz von Batch 1 ist gesperrt, solange dessen Lernpfad nicht fertig ist',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords(buildWords());
        await tester.pumpWidget(
          const MaterialApp(
            home: BatchListScreen(group: 'A1', mode: BatchListMode.quiz),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      // Batch 1 ist der erste Batch (Vorgänger-Regel erfüllt), aber sein
      // Lernpfad wurde nie abgeschlossen -> trotzdem gesperrt.
      expect(find.byIcon(Icons.lock), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.tap(find.textContaining('Lektion 1'));
      await tester.pump();
      expect(
        find.textContaining('Zuerst diese Lektion lernen'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Lernpfad von Batch 1 abgeschlossen ohne bestandenes Quiz schaltet nur Batch 1 frei',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords(buildWords());
        await DatabaseHelper.instance.markBatchLearned('A1', 0);
        await tester.pumpWidget(
          const MaterialApp(
            home: BatchListScreen(group: 'A1', mode: BatchListMode.quiz),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Batch 2 ist gesperrt, weil Batch 1 noch nicht bestanden wurde (nicht
      // wegen des Lernpfads) -> ursprünglicher Hinweistext.
      await tester.tap(find.textContaining('Lektion 2'));
      await tester.pump();
      expect(
        find.textContaining('Erst die vorherige Lektion fehlerfrei bestehen'),
        findsOneWidget,
      );
    },
  );

  // 110 Wörter -> 11 Lektionen. Seit der App kostenlos ist (10. September
  // 2026) gibt es kein Kauf-Gate mehr: Die Einstiegs-Stufe A1 ist immer
  // freigeschaltet, alle Lektionen folgen nur der sequenziellen
  // Vorgänger-Regel.
  List<Word> buildLevelWords() => [
    for (var i = 1; i <= 110; i++)
      Word(
        id: i,
        arabic: 'ب$i',
        german: 'levelwort$i',
        root: 'ب-ي-ن',
        group: 'A1',
        frequencyRank: i,
        transliteration: 'kalima$i',
      ),
  ];

  testWidgets(
    'Freie Einstiegs-Stufe: Lektion 11 ist ohne Kauffreischaltung offen',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords(buildLevelWords());
        // Vorgänger-Regel erfüllen (Batch 0–9 bestanden) — ohne jeden Kauf.
        for (var b = 0; b < 10; b++) {
          await DatabaseHelper.instance.markBatchPassed('A1', b);
        }
        await tester.pumpWidget(
          const MaterialApp(
            home: BatchListScreen(group: 'A1', mode: BatchListMode.learn),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      // Lektion 11 (Rang 101–110) ist jetzt offen (kein Schloss) — no reject.
      await tester.runAsync(() async {
        await tester.scrollUntilVisible(
          find.textContaining('Lektion 11 · Wörter'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
      });
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    },
  );

  testWidgets(
    'getUnlockedLevels: Einstiegs-Stufe A1 immer frei, naechste nach Abschluss',
    (tester) async {
      await tester.runAsync(() async {
        // Ohne jegliche Einträge ist die Einstiegs-Stufe bereits freigeschaltet.
        expect(await DatabaseHelper.instance.getUnlockedLevels(), {'A1'});
        // Nächste Stufe erst nach Abschluss der vorherigen (via unlockLevel,
        // gesetzt durch quiz_provider beim Abschluss der letzten Lektion).
        await DatabaseHelper.instance.unlockLevel('A2');
        expect(await DatabaseHelper.instance.getUnlockedLevels(), {'A1', 'A2'});
        expect(await DatabaseHelper.instance.isLevelUnlocked('A1'), isTrue);
        expect(await DatabaseHelper.instance.isLevelUnlocked('A2'), isTrue);
        expect(await DatabaseHelper.instance.isLevelUnlocked('B1'), isFalse);
      });
    },
  );
}
