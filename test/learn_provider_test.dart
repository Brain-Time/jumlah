import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/providers/learn_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_learn_test_');
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
    // sentences/roots werden seit Task D1 aus SQLite gelesen statt direkt
    // aus den Assets — hier einmalig aus den echten Assets importiert,
    // genau wie main.dart es beim App-Start tut.
    await DatabaseHelper.instance.importSentencesIfNeeded();
    await DatabaseHelper.instance.importRootsIfNeeded();
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

  test(
    'loadBatch laedt Woerter aus SQLite und Wurzel-Definition aus roots.json',
    () async {
      await DatabaseHelper.instance.insertWords([wordA, wordB]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnProvider.notifier).loadBatch('A1', 0);
      final state = container.read(learnProvider);

      expect(state.words, hasLength(2));
      expect(state.currentWord?.arabic, wordA.arabic);
      expect(state.currentRoot, isNotNull);
      expect(state.currentRoot!.root, 'ك-ت-ب');
      // sentences.json enthaelt seit Task A2 (Claude-generiert) 3 Saetze je Wort
      expect(state.currentSentence, isNotNull);
      expect(state.currentSentence!.wordId, wordA.id);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'nextWord/prevWord navigieren korrekt und blockieren an den Raendern',
    () async {
      await DatabaseHelper.instance.insertWords([wordA, wordB]);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(learnProvider.notifier);

      await notifier.loadBatch('A1', 0);
      expect(container.read(learnProvider).currentIndex, 0);

      notifier.nextWord();
      expect(container.read(learnProvider).currentIndex, 1);
      expect(container.read(learnProvider).currentWord?.arabic, wordB.arabic);

      notifier.nextWord(); // am Ende, sollte nichts tun
      expect(container.read(learnProvider).currentIndex, 1);

      notifier.prevWord();
      expect(container.read(learnProvider).currentIndex, 0);

      notifier.prevWord(); // am Anfang, sollte nichts tun
      expect(container.read(learnProvider).currentIndex, 0);
    },
  );

  test(
    'toggleAnalysis schaltet um und wird bei Wortwechsel zurueckgesetzt',
    () async {
      await DatabaseHelper.instance.insertWords([wordA, wordB]);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(learnProvider.notifier);

      await notifier.loadBatch('A1', 0);
      expect(container.read(learnProvider).showAnalysis, isFalse);

      notifier.toggleAnalysis();
      expect(container.read(learnProvider).showAnalysis, isTrue);

      notifier.nextWord();
      expect(container.read(learnProvider).showAnalysis, isFalse);
    },
  );

  test(
    'letztes Wort eines Batches markiert den Lernpfad als abgeschlossen '
    '(Sicherheitsregel: Quiz erst nach fertigem Lernpfad)',
    () async {
      await DatabaseHelper.instance.insertWords([wordA, wordB]);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(learnProvider.notifier);

      await notifier.loadBatch('A1', 0);
      // Erstes von zwei Woertern -> noch nicht als gelernt markiert.
      expect(await DatabaseHelper.instance.getLearnedBatchIndexes('A1'), isEmpty);

      notifier.nextWord();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Letztes Wort erreicht -> Batch gilt jetzt als gelernt.
      expect(await DatabaseHelper.instance.getLearnedBatchIndexes('A1'), {0});
    },
  );

  test(
    'Ein-Wort-Batch wird bereits beim Laden als gelernt markiert',
    () async {
      await DatabaseHelper.instance.insertWords([wordA]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnProvider.notifier).loadBatch('A1', 0);

      expect(await DatabaseHelper.instance.getLearnedBatchIndexes('A1'), {0});
    },
  );

  test(
    'loadBatch mit leerer Gruppe liefert leere Wortliste ohne Fehler',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnProvider.notifier).loadBatch('C1', 0);
      final state = container.read(learnProvider);

      expect(state.words, isEmpty);
      expect(state.currentWord, isNull);
      expect(state.errorMessage, isNull);
    },
  );
}
