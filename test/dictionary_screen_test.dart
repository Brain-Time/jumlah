import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/core/word_groups.dart'
    show levelForRank, normalizeTransliterationForSearch, stripHarakat;
import 'package:jumlah/models/word.dart';
import 'package:jumlah/screens/dictionary/dictionary_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_dict_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);

    // Echte Assets importieren (500 Wörter, Sätze, Wurzeln), damit die
    // Block-Zuordnung über `frequency_rank` real prüfbar ist.
    await DatabaseHelper.instance.importWordsIfNeeded();
    await DatabaseHelper.instance.importSentencesIfNeeded();
    await DatabaseHelper.instance.importRootsIfNeeded();
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpDictionary(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: DictionaryScreen())),
      );
    });
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), query);
      // Debounce (250ms) + echte SQLite-Abfrage vollständig in runAsync.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await tester.pump();
    });
  }

  testWidgets(
    'Suche findet freigeschaltetes Wort; Tippen oeffnet Detail mit Wurzel und Saetzen',
    (tester) async {
      await pumpDictionary(tester);
      await search(tester, 'schreiben');

      // Treffer-Kachel zeigt arabisches Wort + deutsche Bedeutung.
      expect(find.text('كَتَبَ'), findsOneWidget);
      expect(find.text('schreiben'), findsWidgets);

      // Harakat-insensitive arabische Suche: 'كتب' (ohne Harakat) findet
      // ebenfalls 'كَتَبَ'.
      await search(tester, 'كتب');
      expect(find.text('كَتَبَ'), findsOneWidget);

      // Transliteration-Suche: 'kataba' findet das arabische Wort.
      await search(tester, 'kataba');
      expect(find.text('كَتَبَ'), findsOneWidget);

      // Detailansicht oeffnen (Navigation anhand des Back-Buttons pruefbar).
      await tester.runAsync(() async {
        await tester.tap(find.text('كَتَبَ'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();
      });
      expect(find.byType(BackButton), findsOneWidget);

      // Wurzel-Definition vorhanden; Sätze liegen weiter unten und werden erst
      // nach dem Scrollen des (obersten) ListView gebaut.
      expect(find.textContaining('Wurzel'), findsWidgets);
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pump();
      expect(find.text('Kontext-Sätze'), findsOneWidget);
    },
  );

  testWidgets(
    'Wörter aller verfügbaren Daten werden gefunden (keine Freischalt-Filterung)',
    (tester) async {
      // Ein weiteres Wort (gruppiert als A2, Rang 501) wird ebenfalls
      // gefunden — die App ist komplett kostenlos, die Suche filtert nicht
      // mehr nach freigeschalteten Sprachniveaus (12. September 2026).
      const wordA2 = Word(
        id: 600,
        arabic: 'بُنْدُقِيَّةٌ',
        german: 'quatschwort',
        root: 'ب-ن-د',
        group: 'A2',
        frequencyRank: 501,
        transliteration: 'bunduqiyya',
      );
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords([wordA2]);
      });

      await pumpDictionary(tester);
      await search(tester, 'quatschwort');

      // Kein Sperr-Hinweis; das Wort ist direkt als Treffer-Kachel sichtbar
      // (Treffer-Kachel + das Suchfeld enthält den Query-Text „quatschwort“).
      expect(find.text('بُنْدُقِيَّةٌ'), findsOneWidget);
      expect(find.text('quatschwort'), findsWidgets);
      expect(
        find.textContaining('freigeschalteten Sprachniveaus'),
        findsNothing,
      );
    },
  );

  test('levelForRank ordnet Rang dem Sprachniveau zu', () {
    expect(levelForRank(1)?.group, 'A1');
    expect(levelForRank(100)?.group, 'A1');
    expect(levelForRank(500)?.group, 'A1');
    // Geplante Stufen: A2–C1 decken höhere Rangbereiche ab.
    expect(levelForRank(501)?.group, 'A2');
    expect(levelForRank(1000)?.group, 'A2');
    expect(levelForRank(1001)?.group, 'B1');
    expect(levelForRank(2000)?.group, 'B1');
    expect(levelForRank(2001)?.group, 'B2');
    expect(levelForRank(3000)?.group, 'B2');
    expect(levelForRank(3001)?.group, 'C1');
    expect(levelForRank(5000)?.group, 'C1');
    expect(levelForRank(5001), isNull);
  });

  test('stripHarakat entfernt Harakat, auch bei mehreren Buchstaben', () {
    // Regressionsschutz: `stripHarakat` darf NICHT über ein `r`-Raw-String
    // definiert sein (sonst bliebe `\u064B` wörtlich und es würde nie matchen).
    expect(stripHarakat('كَتَبَ'), 'كتب');
    expect(stripHarakat('قَرَأَ'), 'قرأ');
    expect(stripHarakat('دَرَسَ'), 'درس');
    // Query bereits ohne Harakat bleibt unverändert.
    expect(stripHarakat('كتب'), 'كتب');
  });

  test('normalizeTransliterationForSearch vereinheitlicht DIN-Sonderzeichen', () {
    expect(
      normalizeTransliterationForSearch('qaraʾa'),
      'qaraa',
    );
    expect(
      normalizeTransliterationForSearch('ḏahaba'),
      'dhahaba',
    );
    expect(normalizeTransliterationForSearch('ǧāʾa'), 'jaa');
  });
}