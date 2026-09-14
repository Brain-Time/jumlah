import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/screens/home/home_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_home_screen_test_');
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

  testWidgets('Lernen-Tab zeigt alle Sprachniveaus (A1 offen, A2 gesperrt)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DatabaseHelper.instance.insertWords([wordA]);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    // Einstiegs-Stufe A1 ist ohne Kauf freigeschaltet (Antippbar-Chevron).
    expect(find.text('Sprachniveau A1 · Grundstufe'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);

    // Geplante/gesperrte Stufe A2 zeigt den Hinweis-Chip statt Kauf-Chip.
    await tester.runAsync(() async {
      await tester.scrollUntilVisible(
        find.text('Sprachniveau A2 · Sehr häufig'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    });
    expect(
      find.textContaining('Vorheriges Niveau abschließen'),
      findsWidgets,
    );
    expect(find.textContaining('im Store freischalten'), findsNothing);
  });

  testWidgets('Tippen auf das Sprachniveau oeffnet LearnScreen', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DatabaseHelper.instance.insertWords([wordA]);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    // Der Push oeffnet zunaechst BatchListScreen (sequenzielle
    // Lektions-Freischaltung), dessen initState() echte SQLite-I/O ausloest —
    // Tap + Warten muessen deshalb komplett innerhalb von runAsync laufen.
    await tester.runAsync(() async {
      // Der Learn-Tab ist durch die neuen Home-Karten länger geworden — die
      // A1-Kachel liegt daher u.U. unterhalb des Folds (Bottom-Navigation).
      await tester.scrollUntilVisible(
        find.text('Sprachniveau A1 · Grundstufe'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Sprachniveau A1 · Grundstufe'));
      // Der eigentliche Seitenwechsel passiert erst beim naechsten pump().
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    // BatchListScreen zeigt den (einzigen) Batch mit dem 1 eingefuegten Wort.
    // (Der „Beginne zu lernen“-Untertitel auf der Homepage enthält ebenfalls
    // „Lektion 1 · Wörter…“ — deshalb hier die eindeutige Batch-Beschriftung.)
    expect(find.text('Lektion 1 · Wörter 1–1'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Lektion 1 · Wörter 1–1'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    // LearnScreen zeigt das Wort direkt an.
    expect(find.text('كَتَبَ'), findsOneWidget);
    expect(find.text('schreiben'), findsOneWidget);
  });

  testWidgets('Bottom Navigation wechselt zwischen Lernen/Quiz/Info', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();
    });

    // Start-Tab ist "Lernen".
    expect(find.text('Sprachniveau A1 · Grundstufe'), findsOneWidget);

    await tester.tap(find.text('Quiz'));
    await tester.pump();
    expect(find.text('Sprachniveau A1 · Grundstufe'), findsOneWidget);

    await tester.tap(find.text('Info'));
    await tester.pump();
    expect(find.text('Support & Rechtliches'), findsOneWidget);

    // Der Store-Tab existiert nicht mehr.
    expect(find.text('Store'), findsNothing);
  });

  testWidgets(
    'Lernen-Tab: Hero-Banner-Statistik + „Beginne zu lernen“ ohne Lernposition',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: HomeScreen())),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();
      });

      // Hero-Banner mit Begrüßung + Statistik-Zeile (aktives Niveau A1:
      // 500 Wörter / 50 Lektionen).
      expect(find.text('Willkommen bei Jumlah'), findsOneWidget);
      expect(find.text('Wörter'), findsOneWidget);
      expect(find.text('Lektionen'), findsOneWidget);
      expect(find.text('Fortschritt'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);

      // Ohne gespeicherte Lernposition: „Beginne zu lernen“ (Lektion 1).
      expect(find.text('Beginne zu lernen'), findsOneWidget);
      expect(find.text('Lektion 1 · Wörter 1–10 · A1'), findsOneWidget);
    },
  );

  testWidgets(
    '„Weiter lernen“ zeigt die gespeicherte Lernposition und öffnet LearnScreen',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords([wordA]);
        await DatabaseHelper.instance.saveLearnPosition('A1', 0, 0);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: HomeScreen())),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();
      });

      // Resume-Karte zeigt „Weiter lernen“ mit Lektions-/Wort-Position.
      expect(find.text('Weiter lernen'), findsOneWidget);
      expect(find.text('Lektion 1 · Wort 1 von 10 · A1'), findsOneWidget);

      // Tap öffnet direkt den LearnScreen der gespeicherten Lektion
      // (dessen initState echte SQLite-I/O auslöst — alles in runAsync).
      await tester.runAsync(() async {
        await tester.tap(find.text('Weiter lernen'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });
      expect(find.text('كَتَبَ'), findsOneWidget);
      expect(find.text('schreiben'), findsOneWidget);
    },
  );

  testWidgets('Statistik-Tab: Tap auf das Statistik-Icon zeigt den StatsTab', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    // 4. Destination „Statistik“ ist in der Bottom Navigation vorhanden
    // (das Diagramm-Icon erscheint nur im Navigations-Tab).
    expect(find.byIcon(Icons.insert_chart), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.insert_chart));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    // Statistik-Tab-Inhalt sichtbar: AppBar-Titel, Leer-Zustand (keine
    // Aktivität) und die Heatmap-Karte.
    expect(find.text('Statistik'), findsWidgets);
    expect(find.textContaining('Noch keine Lernaktivität'), findsOneWidget);
    expect(find.text('Tage Serie'), findsOneWidget);
    expect(find.text('Deine Lernaktivität'), findsOneWidget);
  });
testWidgets(
    'Lernen-Tab zeigt die Wiederholen-Karte und oeffnet die SM-2-Session',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords([wordA]);
        await DatabaseHelper.instance.seedSm2ForBatch('A1', 0);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: HomeScreen())),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      // Wiederholen-Karte mit Fälligkeits-Zähler (1 Wort nach seedSm2ForBatch).
      expect(find.text('Wiederholen'), findsOneWidget);
      expect(
        find.text('1 Wort fällig — Zeit für eine Wiederholung.'),
        findsOneWidget,
      );

      // Antippen öffnet den ReviewScreen mit dem ersten fälligen Wort.
      await tester.runAsync(() async {
        await tester.scrollUntilVisible(
          find.text('Wiederholen'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(find.text('Wiederholen'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });
      expect(find.text('كَتَبَ'), findsOneWidget);
      expect(find.text('Antwort zeigen'), findsOneWidget);
    },
  );

  testWidgets(
    'Wiederholen-Karte ohne faellige Woerter zeigt den Leer-Hinweis',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords([wordA]);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: HomeScreen())),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      expect(find.text('Wiederholen'), findsOneWidget);
      expect(
        find.text('Bestehe Lektionen, um Wörter hier zu wiederholen.'),
        findsOneWidget,
      );
    },
  );
}
