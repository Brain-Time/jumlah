import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/screens/learn/learn_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_learn_screen_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);

    // audioplayers (Task H3): Der AudioPlayer in AudioService initialisiert beim
    // allerersten Zugriff das Plugin global über den Platform-Kanal
    // `xyz.luan/audioplayers.global` und legt danach den spielerspezifischen
    // Kanal `xyz.luan/audioplayers` an. In diesem reinen Dart-Test-Host hat kein
    // Kanal eine Plattform-Implementierung — ohne Mock würde nach Test-Ende eine
    // MissingPluginException geworfen (die App selbst läuft nur mit echter
    // Plattform, z.B. Android). Wir mocken daher die beiden MethodChannels, damit
    // der Konstruktor sauber durchläuft. Wiedergabe wird im LearnScreen-Test
    // ohnehin nicht gestartet.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => call.method == 'create' ? call.arguments : 0,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
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

  testWidgets('LearnScreen zeigt Wort, Uebersetzung und Wurzel-Definition', (
    tester,
  ) async {
    // Jeder echte SQLite-/Asset-I/O-Aufruf (sqflite_common_ffi, rootBundle)
    // haengt sich im von testWidgets simulierten FakeAsync-Zeitrahmen auf,
    // wenn er ausserhalb von runAsync gestartet wird — daher inklusive
    // insertWords komplett innerhalb von runAsync.
    await tester.runAsync(() async {
      await DatabaseHelper.instance.insertWords([wordA]);
      // sentences/roots werden seit Task D1 aus SQLite gelesen statt direkt
      // aus den Assets — hier einmalig aus den echten Assets importiert.
      await DatabaseHelper.instance.importSentencesIfNeeded();
      await DatabaseHelper.instance.importRootsIfNeeded();
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LearnScreen(group: 'A1')),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(find.text('كَتَبَ'), findsOneWidget);
    expect(find.text('schreiben'), findsOneWidget);
    expect(find.textContaining('schreiben, aufzeichnen'), findsOneWidget);
    // sentences.json enthaelt seit Task A2 (Claude-generiert) echte Saetze
    expect(find.text('كَتَبَ الطَّالِبُ الدَّرْسَ.'), findsOneWidget);
    expect(find.text('Der Student schrieb die Lektion.'), findsOneWidget);
    // Transliteration wird bei A1 angezeigt (showsTransliteration) — sowohl
    // fürs Wort als auch für den ganzen Kontext-Satz.
    expect(find.text('kataba'), findsOneWidget);
    expect(find.text('Kataba aṭ-ṭālibu ad-darsa.'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets(
    'LearnScreen zeigt KEINE Transliteration ab B1 (showsTransliteration)',
    (tester) async {
      const wordB1 = Word(
        id: 2,
        arabic: 'كَتَبَ',
        german: 'schreiben',
        root: 'ك-ت-ب',
        group: 'B1',
        frequencyRank: 1001,
        transliteration: 'kataba',
      );
      await tester.runAsync(() async {
        await DatabaseHelper.instance.insertWords([wordB1]);
        await DatabaseHelper.instance.importSentencesIfNeeded();
        await DatabaseHelper.instance.importRootsIfNeeded();
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: LearnScreen(group: 'B1')),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });

      expect(find.text('كَتَبَ'), findsOneWidget);
      expect(find.text('kataba'), findsNothing);
      // word_id 2 hat echte Saetze (Qaraʾa...) — auch deren Transliteration
      // darf ab B1 nicht angezeigt werden.
      expect(find.text('Qaraʾa al-waladu al-kitāba.'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    },
  );

  testWidgets('LearnScreen zeigt Hinweis bei leerer Gruppe', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LearnScreen(group: 'C1')),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(
      find.textContaining('Keine Wörter in dieser Gruppe'),
      findsOneWidget,
    );
  });
}
