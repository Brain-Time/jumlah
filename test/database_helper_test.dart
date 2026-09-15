import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/models/quiz_session.dart';
import 'package:jumlah/models/word.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    // databaseFactoryFfi delegiert an einen separaten Isolate, der die
    // open.overrideFor()-Registrierung aus diesem Isolate nicht sieht.
    // databaseFactoryFfiNoIsolate laeuft im selben Isolate.
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_db_test_');
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
  const wordC = Word(
    id: 3,
    arabic: 'دَرَسَ',
    german: 'studieren',
    root: 'د-ر-س',
    group: 'A2',
    frequencyRank: 501,
    transliteration: 'darasa',
  );

  test(
    'insertWords + getWordsByGroup filtert und sortiert nach frequency_rank',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordC, wordB, wordA]);

      final a1Words = await helper.getWordsByGroup('A1');
      expect(a1Words.map((w) => w.id).toList(), [1, 2]);

      final a2Words = await helper.getWordsByGroup('A2');
      expect(a2Words, hasLength(1));
      expect(a2Words.first.arabic, 'دَرَسَ');
    },
  );

  test(
    'searchWords findet ueber arabisch, deutsch und Umschrift (Task H2)',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordA, wordB, wordC]);

      // Arabisch (mit Harakat)
      var hits = await helper.searchWords('كَتَبَ');
      expect(hits.map((w) => w.id), contains(1));

      // Arabisch OHNE Harakat: 'كتب' muss 'كَتَبَ' finden (harakat-insensitiv)
      hits = await helper.searchWords('كتب');
      expect(hits.map((w) => w.id), contains(1));

      // Deutsch
      hits = await helper.searchWords('lesen');
      expect(hits.map((w) => w.id), [2]);

      // Umschrift (DIN 31635) — exakte wissenschaftliche Form
      hits = await helper.searchWords('qaraʾa');
      expect(hits.map((w) => w.id), contains(2));

      // Umschrift — gebräuchliche, ohne Sonderzeichen eintippbare Form
      // ('qara' / 'qaraa' sollen auf 'qaraʾa' treffen)
      hits = await helper.searchWords('qara');
      expect(hits.map((w) => w.id), contains(2));
      hits = await helper.searchWords('qaraa');
      expect(hits.map((w) => w.id), contains(2));

      // Ergebnis nach frequency_rank sortiert ('en' kommt in allen drei vor:
      // ids 1, 2, 3 -> Ränge 1, 2, 501)
      hits = await helper.searchWords('en');
      expect(hits.map((w) => w.id).toList(), [1, 2, 3]);

      // Leerer Query -> keine Treffer
      expect(await helper.searchWords(''), isEmpty);
      expect(await helper.searchWords('   '), isEmpty);

      // Kein Treffer
      expect(await helper.searchWords('xyzNichtVorhanden'), isEmpty);
    },
  );

  test(
    'insertWords mit ConflictAlgorithm.replace ueberschreibt bestehenden Eintrag',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordA]);

      const updated = Word(
        id: 1,
        arabic: 'كَتَبَ',
        german: 'schreiben (aktualisiert)',
        root: 'ك-ت-ب',
        group: 'A1',
        frequencyRank: 1,
        transliteration: 'kataba',
      );
      await helper.insertWords([updated]);

      final words = await helper.getWordsByGroup('A1');
      expect(words, hasLength(1));
      expect(words.first.german, 'schreiben (aktualisiert)');
    },
  );

  test(
    'updateProgress zaehlt richtig/falsch hoch, getProgress liest zurueck',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordA]);

      expect(await helper.getProgress(wordA.id), isNull);

      await helper.updateProgress(wordA.id, true);
      await helper.updateProgress(wordA.id, true);
      await helper.updateProgress(wordA.id, false);

      final progress = await helper.getProgress(wordA.id);
      expect(progress, isNotNull);
      expect(progress!.correctCount, 2);
      expect(progress.wrongCount, 1);
      expect(progress.lastSeen, isNotNull);
    },
  );

  test('resetProgress loescht alle Fortschritts-Eintraege', () async {
    final helper = DatabaseHelper.instance;
    await helper.insertWords([wordA]);
    await helper.updateProgress(wordA.id, true);

    await helper.resetProgress();

    expect(await helper.getProgress(wordA.id), isNull);
  });

  test('DatabaseHelper.instance ist ein Singleton', () {
    expect(identical(DatabaseHelper.instance, DatabaseHelper.instance), isTrue);
  });

  test('Onboarding-Flag: Default false, nach markOnboardingSeen true', () async {
    final helper = DatabaseHelper.instance;

    // Beim allerersten Start ist das First-Run-Onboarding noch nicht gesehen.
    expect(await helper.isOnboardingSeen(), isFalse);

    await helper.markOnboardingSeen();
    expect(await helper.isOnboardingSeen(), isTrue);

    // Mehrfaches Markieren ist unschädlich.
    await helper.markOnboardingSeen();
    expect(await helper.isOnboardingSeen(), isTrue);
  });

  test('getLatestLearnPosition: leer, eine Zeile, zuletzt gespeicherte gewinnt',
      () async {
    final helper = DatabaseHelper.instance;

    // Ohne Lernposition: null.
    expect(await helper.getLatestLearnPosition(), isNull);

    // Eine Lernposition wird zurückgegeben.
    await helper.saveLearnPosition('A1', 0, 3);
    var latest = await helper.getLatestLearnPosition();
    expect(latest?.group, 'A1');
    expect(latest?.batchIndex, 0);
    expect(latest?.currentIndex, 3);

    // Eine zweite, spätere Lernposition (anderer Batch) gewinnt — rowid DESC.
    await helper.saveLearnPosition('A1', 1, 1);
    latest = await helper.getLatestLearnPosition();
    expect(latest?.group, 'A1');
    expect(latest?.batchIndex, 1);
    expect(latest?.currentIndex, 1);

    // Erneutes Speichern derselben (group, batch) Zeile ist weiterhin die
    // neueste (ConflictAlgorithm.replace → neue rowid).
    await helper.saveLearnPosition('A1', 0, 5);
    latest = await helper.getLatestLearnPosition();
    expect(latest?.batchIndex, 0);
    expect(latest?.currentIndex, 5);
  });

  test(
    'Freischaltung: Einstiegs-Stufe A1 immer frei, weitere per unlockLevel',
    () async {
      final helper = DatabaseHelper.instance;

      // Seit der App kostenlos ist: die Einstiegs-Stufe (A1) ist ohne
      // Kauf/Code-Freischaltung immer offen; weitere Stufen erst nach
      // unlockLevel (gesetzt durch quiz_provider beim Stufen-Abschluss).
      expect(await helper.isLevelUnlocked('A1'), isTrue);
      expect(await helper.getUnlockedLevels(), {'A1'});

      await helper.unlockLevel('A2');
      // Erneutes Freischalten desselben Niveaus darf nicht fehlschlagen.
      await helper.unlockLevel('A2');

      expect(await helper.isLevelUnlocked('A1'), isTrue);
      expect(await helper.isLevelUnlocked('A2'), isTrue);
      expect(await helper.isLevelUnlocked('B1'), isFalse);
      expect(await helper.getUnlockedLevels(), {'A1', 'A2'});
    },
  );

  test(
    'getGroupProgress berechnet Anteil der Woerter mit mind. 1 richtiger Antwort',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordA, wordB]);

      expect(await helper.getGroupProgress('A1'), 0);
      expect(await helper.getGroupProgress('C1'), 0);

      await helper.updateProgress(wordA.id, true);
      expect(await helper.getGroupProgress('A1'), 0.5);

      await helper.updateProgress(wordB.id, false);
      // wordB nur falsch beantwortet -> zaehlt noch nicht als gemeistert.
      expect(await helper.getGroupProgress('A1'), 0.5);

      await helper.updateProgress(wordB.id, true);
      expect(await helper.getGroupProgress('A1'), 1.0);
    },
  );

  test(
    'getRankRangeProgress berechnet Block-Fortschritt nur ueber den Rangbereich',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordA, wordB]); // Rang 1 und 2 (beide Block 0)

      expect(await helper.getRankRangeProgress('A1', 1, 100), 0);
      // Nicht vorhandener Bereich liefert 0, kein Absturz.
      expect(await helper.getRankRangeProgress('A1', 101, 200), 0);

      await helper.updateProgress(wordA.id, true);
      // Nur wordA (Rang 1) liegt im engen Bereich 1–1.
      expect(await helper.getRankRangeProgress('A1', 1, 1), 1.0);
      // Bricht mit anderer Gruppe nichts hervor, gleicher Rangbereich.
      expect(await helper.getRankRangeProgress('B1', 1, 100), 0);

      await helper.updateProgress(wordB.id, true);
      expect(await helper.getRankRangeProgress('A1', 1, 100), 1.0);
    },
  );

  test(
    'markBatchPassed/getPassedBatchIndexes/highestUnlockedBatchIndex tracken sequenzielle Freischaltung',
    () async {
      final helper = DatabaseHelper.instance;

      expect(await helper.getPassedBatchIndexes('A1'), isEmpty);
      // Batch 0 ist immer offen, auch ohne bestandene Batches.
      expect(await helper.highestUnlockedBatchIndex('A1'), 0);

      await helper.markBatchPassed('A1', 0);
      expect(await helper.getPassedBatchIndexes('A1'), {0});
      expect(await helper.highestUnlockedBatchIndex('A1'), 1);

      // Luecke (Batch 2 ohne bestandenen Batch 1) darf Batch 3 nicht
      // freischalten.
      await helper.markBatchPassed('A1', 2);
      expect(await helper.highestUnlockedBatchIndex('A1'), 1);

      await helper.markBatchPassed('A1', 1);
      expect(await helper.highestUnlockedBatchIndex('A1'), 3);

      // Andere Gruppe bleibt unberuehrt.
      expect(await helper.getPassedBatchIndexes('A2'), isEmpty);

      // Erneutes Markieren ist unschaedlich (ConflictAlgorithm.replace).
      await helper.markBatchPassed('A1', 0);
      expect(await helper.getPassedBatchIndexes('A1'), {0, 1, 2});
    },
  );

  test(
    'isGroupFullyPassed vergleicht bestandene Batches mit der Gesamt-Batch-Anzahl',
    () async {
      final helper = DatabaseHelper.instance;

      expect(await helper.isGroupFullyPassed('A1', 0, 10), isFalse);
      expect(await helper.isGroupFullyPassed('A1', 25, 10), isFalse);

      await helper.markBatchPassed('A1', 0);
      await helper.markBatchPassed('A1', 1);
      // 25 Woerter / 10 = 3 Batches (aufgerundet) -> Batch 2 fehlt noch.
      expect(await helper.isGroupFullyPassed('A1', 25, 10), isFalse);

      await helper.markBatchPassed('A1', 2);
      expect(await helper.isGroupFullyPassed('A1', 25, 10), isTrue);
    },
  );

  test(
    'markBatchLearned/getLearnedBatchIndexes tracken abgeschlossene Lernpfade '
    'unabhaengig von markBatchPassed',
    () async {
      final helper = DatabaseHelper.instance;

      expect(await helper.getLearnedBatchIndexes('A1'), isEmpty);

      await helper.markBatchLearned('A1', 0);
      expect(await helper.getLearnedBatchIndexes('A1'), {0});
      // Quiz-Bestehen und Lernpfad-Abschluss sind getrennte Zustaende.
      expect(await helper.getPassedBatchIndexes('A1'), isEmpty);

      await helper.markBatchLearned('A1', 1);
      expect(await helper.getLearnedBatchIndexes('A1'), {0, 1});

      // Andere Gruppe bleibt unberuehrt.
      expect(await helper.getLearnedBatchIndexes('A2'), isEmpty);

      // Erneutes Markieren ist unschaedlich (ConflictAlgorithm.replace).
      await helper.markBatchLearned('A1', 0);
      expect(await helper.getLearnedBatchIndexes('A1'), {0, 1});
    },
  );

  test(
    'saveQuizSession/getQuizSession/clearQuizSession persistieren einen '
    'unterbrochenen Quiz-Zwischenstand (Task G3, Anti-Cheat)',
    () async {
      final helper = DatabaseHelper.instance;

      expect(await helper.getQuizSession('A1', 0), isNull);

      await helper.saveQuizSession(
        const QuizSession(
          group: 'A1',
          batchIndex: 0,
          stage: 'germanToArabic',
          attempts: {1: 2, 2: 1},
          stageResolvedWordIds: {3, 4},
          finalWrongWordIds: {5},
          correctCount: 7,
          wrongCount: 3,
        ),
      );

      final loaded = await helper.getQuizSession('A1', 0);
      expect(loaded, isNotNull);
      expect(loaded!.stage, 'germanToArabic');
      expect(loaded.attempts, {1: 2, 2: 1});
      expect(loaded.stageResolvedWordIds, {3, 4});
      expect(loaded.finalWrongWordIds, {5});
      expect(loaded.correctCount, 7);
      expect(loaded.wrongCount, 3);

      // Ueberschreiben (gleicher Batch) statt Duplikat.
      await helper.saveQuizSession(
        const QuizSession(
          group: 'A1',
          batchIndex: 0,
          stage: 'mixed',
          attempts: {},
          stageResolvedWordIds: {},
          finalWrongWordIds: {5},
          correctCount: 10,
          wrongCount: 3,
        ),
      );
      expect((await helper.getQuizSession('A1', 0))!.stage, 'mixed');

      // Andere Gruppe/Batch bleibt unberuehrt.
      expect(await helper.getQuizSession('A1', 1), isNull);
      expect(await helper.getQuizSession('A2', 0), isNull);

      await helper.clearQuizSession('A1', 0);
      expect(await helper.getQuizSession('A1', 0), isNull);
    },
  );

  test(
    'importSentencesIfNeeded/getSentencesByWordIds importieren echte '
    'sentences.json einmalig in SQLite (Task D1)',
    () async {
      final helper = DatabaseHelper.instance;

      expect(await helper.getSentencesByWordIds({1}), isEmpty);

      await helper.importSentencesIfNeeded();
      final sentences = await helper.getSentencesByWordIds({1, 2});
      // word_id 1 (كَتَبَ) hat seit Task A2 3 Saetze.
      expect(sentences[1], hasLength(3));
      expect(sentences[1]!.first.wordId, 1);
      expect(sentences[1]!.first.arabic, isNotEmpty);
      expect(sentences[2], isNotNull);

      // Erneuter Aufruf importiert nicht doppelt (Tabelle bereits befuellt).
      await helper.importSentencesIfNeeded();
      expect((await helper.getSentencesByWordIds({1}))[1], hasLength(3));

      // Unbekannte word_id liefert keinen Eintrag.
      expect(await helper.getSentencesByWordIds({999999}), isEmpty);
    },
  );

  test(
    'importRootsIfNeeded/getRootsByKeys importieren echte roots.json '
    'einmalig in SQLite (Task D1)',
    () async {
      final helper = DatabaseHelper.instance;

      expect(await helper.getRootsByKeys({'ك-ت-ب'}), isEmpty);

      await helper.importRootsIfNeeded();
      final roots = await helper.getRootsByKeys({'ك-ت-ب', 'ق-ر-أ'});
      expect(roots['ك-ت-ب'], isNotNull);
      expect(roots['ك-ت-ب']!.classicalDefinition, isNotEmpty);
      expect(roots['ك-ت-ب']!.relatedWordIds, isNotEmpty);
      expect(roots['ق-ر-أ'], isNotNull);

      // Erneuter Aufruf importiert nicht doppelt.
      await helper.importRootsIfNeeded();
      expect((await helper.getRootsByKeys({'ك-ت-ب'})).length, 1);

      // Unbekannte Wurzel liefert keinen Eintrag.
      expect(await helper.getRootsByKeys({'x-x-x'}), isEmpty);
    },
  );

  test(
    'reimportAssetDataIfVersionChanged importiert nur bei geaenderter '
    'Asset-Version neu, sonst bleiben bestehende Daten unangetastet '
    '(Task D1, Versions-Check)',
    () async {
      final helper = DatabaseHelper.instance;

      expect(await helper.getStoredDataAssetVersion(), isNull);

      // Erststart: keine gespeicherte Version -> gilt als "geaendert",
      // Tabellen (aktuell leer) werden fuer den Neu-Import freigegeben,
      // aktuelle Version wird gespeichert.
      await helper.reimportAssetDataIfVersionChanged();
      expect(
        await helper.getStoredDataAssetVersion(),
        DatabaseHelper.dataAssetVersion,
      );

      // Eigene Testdaten einfuegen (steht hier fuer einen echten Import).
      await helper.insertWords([wordA]);

      // Erneuter Aufruf bei UNVERAENDERTER Version darf bestehende
      // Wort-Daten nicht loeschen.
      await helper.reimportAssetDataIfVersionChanged();
      expect(await helper.getWordsByGroup('A1'), hasLength(1));

      // Simulierter Versionswechsel (z.B. App-Update mit neuen Woertern):
      // gespeicherte Version manuell auf einen alten Stand zuruecksetzen.
      final db = await helper.database;
      await db.insert('metadata', {
        'key': 'data_asset_version',
        'value': '0',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await helper.reimportAssetDataIfVersionChanged();
      // Wort-Tabelle wurde geleert, damit importWordsIfNeeded() sie aus den
      // aktuellen Assets neu befuellt.
      expect(await helper.getWordsByGroup('A1'), isEmpty);
      expect(
        await helper.getStoredDataAssetVersion(),
        DatabaseHelper.dataAssetVersion,
      );
    },
  );

  test(
    'Migration von Schema-Version 1 auf 2 ergaenzt transliteration-Spalte und '
    'batch_progress-Tabelle, ohne bestehende Daten zu verlieren',
    () async {
      final path = p.join(tempDir.path, DatabaseHelper.databaseName);
      final oldDb = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE words (
                id INTEGER PRIMARY KEY,
                arabic TEXT NOT NULL,
                german TEXT NOT NULL,
                root TEXT NOT NULL,
                "group" TEXT NOT NULL,
                frequency_rank INTEGER NOT NULL
              )
            ''');
            await db.execute('CREATE TABLE purchases (group_name TEXT PRIMARY KEY)');
          },
        ),
      );
      await oldDb.insert('words', {
        'id': 1,
        'arabic': 'كَتَبَ',
        'german': 'schreiben',
        'root': 'ك-ت-ب',
        'group': 'A1',
        'frequency_rank': 1,
      });
      await oldDb.close();

      final helper = DatabaseHelper.instance;
      final words = await helper.getWordsByGroup('A1');
      expect(words, hasLength(1));
      expect(words.first.arabic, 'كَتَبَ');
      // Alt-Datensaetze ohne transliteration bekommen den Spalten-Default.
      expect(words.first.transliteration, '');

      // batch_progress existiert jetzt und ist voll nutzbar.
      await helper.markBatchPassed('A1', 0);
      expect(await helper.getPassedBatchIndexes('A1'), {0});

      // learn_progress (Schema-Version 3) existiert ebenfalls und ist voll
      // nutzbar, auch beim direkten Sprung von Version 1 aus.
      await helper.markBatchLearned('A1', 0);
      expect(await helper.getLearnedBatchIndexes('A1'), {0});

      // quiz_session (Schema-Version 4) ebenfalls, auch beim direkten Sprung
      // von Version 1 aus.
      await helper.saveQuizSession(
        const QuizSession(
          group: 'A1',
          batchIndex: 0,
          stage: 'arabicToGerman',
          attempts: {},
          stageResolvedWordIds: {},
          finalWrongWordIds: {},
          correctCount: 0,
          wrongCount: 0,
        ),
      );
      expect((await helper.getQuizSession('A1', 0))?.stage, 'arabicToGerman');

      // sentences/roots (Schema-Version 5) ebenfalls, auch beim direkten
      // Sprung von Version 1 aus.
      await helper.importSentencesIfNeeded();
      await helper.importRootsIfNeeded();
      expect((await helper.getSentencesByWordIds({1}))[1], hasLength(3));
      expect((await helper.getRootsByKeys({'ك-ت-ب'}))['ك-ت-ب'], isNotNull);

      // metadata (Schema-Version 6) ebenfalls, auch beim direkten Sprung
      // von Version 1 aus.
      expect(await helper.getStoredDataAssetVersion(), isNull);
      await helper.reimportAssetDataIfVersionChanged();
      expect(
        await helper.getStoredDataAssetVersion(),
        DatabaseHelper.dataAssetVersion,
      );

      // study_activity (Schema-Version 12) ebenfalls, auch beim direkten
      // Sprung von Version 1 aus.
      await helper.trackStudyActivity(wordsViewed: 1);
      expect(
        (await helper.getStudyDayActivity(DateTime.now())).wordsViewed,
        1,
      );

      // sm2_state (Schema-Version 13) ebenfalls, auch beim direkten
      // Sprung von Version 1 aus — die Wörter der (bestandenen) Lektion 1
      // sind fällig. (reimportAssetDataIfVersionChanged hatte words zuvor
      // geleert → erst aus den Assets importieren.)
      await helper.importWordsIfNeeded();
      await helper.seedSm2ForBatch('A1', 0);
      expect(await helper.getDueSm2Count(DateTime.now()), 10);
    },
  );

  test(
    'trackStudyActivity: mehrfache Aufrufe am selben Tag summieren sich '
    '(UPSERT, keine Duplikat-Zeilen)',
    () async {
      final helper = DatabaseHelper.instance;
      final today = DateTime.now();
      final todayKey = DatabaseHelper.studyDateKey(today);
      // Differenzmessung: die DB kann durch den vorherigen Migrationstest
      // schon eine study_activity-Zeile für heute enthalten — nur die
      // Zuwächse dieses Tests sind deterministisch.
      final before = await helper.getStudyDayActivity(today);

      await helper.trackStudyActivity(wordsViewed: 2, quizAnswers: 3);
      await helper.trackStudyActivity(
        wordsViewed: 1,
        quizAnswers: 4,
        lessonsCompleted: 1,
      );

      final after = await helper.getStudyDayActivity(today);
      expect(after.wordsViewed - before.wordsViewed, 3);
      expect(after.quizAnswers - before.quizAnswers, 7);
      expect(after.lessonsCompleted - before.lessonsCompleted, 1);
      // activity_count ist die Summe aller Argumente: 2+3 + 1+4+1 = 11.
      expect(after.activityCount - before.activityCount, 11);

      // Nur EINE Zeile für heute existiert weiterhin.
      final range = await helper.getStudyActivityForRange(today, today);
      expect(range[todayKey], before.activityCount + 11);

      // Kein Aktivitäts-Argument -> kein Schreibzugriff (Zähler unverändert).
      await helper.trackStudyActivity();
      expect(
        (await helper.getStudyDayActivity(today)).activityCount,
        after.activityCount,
      );
    },
  );

  test('computeStudyStats: Streak-, Tages- und Heute-Logik (pure)', () {
    final today = DateTime(2026, 9, 13); // Samstag

    // Durchgehend aktiv (heute, gestern, vorgestern) -> aktuelle Serie 3.
    final series3 = DatabaseHelper.computeStudyStats({
      '2026-09-11': 1,
      '2026-09-12': 4,
      '2026-09-13': 2,
    }, today);
    expect(series3.currentStreak, 3);
    expect(series3.bestStreak, 3);
    expect(series3.activeDays, 3);
    expect(series3.todayCount, 2);

    // Unterbrochen: heute/gestern leer, davor drei Tage am Stück -> aktuell 0,
    // beste Serie bleibt 3.
    final broken = DatabaseHelper.computeStudyStats({
      '2026-09-08': 1,
      '2026-09-09': 3,
      '2026-09-10': 2,
    }, today);
    expect(broken.currentStreak, 0);
    expect(broken.bestStreak, 3);
    expect(broken.activeDays, 3);

    // Heute leer, aber gestern (und vorgestern) aktiv -> Serie am Morgen wird
    // noch weitergezählt, bis um Mitternacht eine Lücke entsteht.
    final morning = DatabaseHelper.computeStudyStats({
      '2026-09-11': 1,
      '2026-09-12': 1,
    }, today);
    expect(morning.currentStreak, 2);

    // Zwei getrennte Serien -> die längere gewinnt als "beste".
    final twoRuns = DatabaseHelper.computeStudyStats({
      '2026-09-01': 1,
      '2026-09-02': 1,
      '2026-09-03': 1,
      '2026-09-05': 1,
      '2026-09-06': 1,
    }, DateTime(2026, 9, 6));
    expect(twoRuns.bestStreak, 3);
    expect(twoRuns.currentStreak, 2);

    // Leere Map -> alles 0.
    final none = DatabaseHelper.computeStudyStats(const {}, today);
    expect(none.activeDays, 0);
    expect(none.currentStreak, 0);
    expect(none.bestStreak, 0);
    expect(none.todayCount, 0);
  });
test(
    'SM-2: seedSm2ForBatch befuellt den Pool mit den Woertern einer '
    'bestandenen Lektion und ist idempotent',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordA, wordB]);
      // Bewusst dynamisch statt hartkodiert: seedSm2ForBatch setzt due_date =
      // DateTime.now() (lokaler Tag); ein fixiertes Datum würde den Test nach
      // Mitternacht brechen (latenter Datums-Bug, gefunden am 15.09.2026).
      final today = DateTime.now();

      await helper.seedSm2ForBatch('A1', 0);
      expect(await helper.getDueSm2Count(today), 2);
      final due = await helper.getDueSm2Words(today);
      expect(due.map((item) => item.word.id).toList(), [1, 2]);
      expect(due.first.state.dueDate, DatabaseHelper.studyDateKey(today));
      expect(due.first.state.intervalDays, 0);
      expect(due.first.state.repetitions, 0);

      // Erneutes Bestehen derselben Lektion darf Intervalle nicht zurueck-/
      // neu setzen (Ignore statt Replace).
      await helper.seedSm2ForBatch('A1', 0);
      expect(await helper.getDueSm2Count(today), 2);

      // Lektion 2 (Rang 11-20) ist leer -> nichts weiter gepoolt.
      await helper.seedSm2ForBatch('A1', 1);
      expect(await helper.getDueSm2Count(today), 2);
    },
  );

  test('SM-2: recordSm2Review folgt dem SM-2-Intervall-Schema', () async {
    final helper = DatabaseHelper.instance;
    await helper.insertWords([wordA]);
    await helper.seedSm2ForBatch('A1', 0);
    final today = DateTime(2026, 9, 14);

    // Erster Erfolg (q=4): Intervall 1 Tag -> morgen faellig.
    await helper.recordSm2Review(1, 4, today);
    var state = await helper.getSm2State(1);
    expect(state?.repetitions, 1);
    expect(state?.intervalDays, 1);
    expect(state?.dueDate, '2026-09-15');
    expect(await helper.getDueSm2Count(today), 0);

    // Zweiter Erfolg am Folgetag (q=5): Intervall 6 Tage.
    await helper.recordSm2Review(1, 5, today.add(const Duration(days: 1)));
    state = await helper.getSm2State(1);
    expect(state?.repetitions, 2);
    expect(state?.intervalDays, 6);
    expect(state?.dueDate, '2026-09-21');

    // Dritter Erfolg: round(6 * 2.7) = 16 Tage.
    await helper.recordSm2Review(1, 5, today.add(const Duration(days: 7)));
    state = await helper.getSm2State(1);
    expect(state?.repetitions, 3);
    expect(state?.intervalDays, 16);
  });

  test(
    'SM-2: Fehlversuch (q<3) setzt repetitions zurueck und macht sofort '
    'wieder faellig',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordB]);
      await helper.seedSm2ForBatch('A1', 0);
      final today = DateTime(2026, 9, 14);

      await helper.recordSm2Review(2, 5, today);
      await helper.recordSm2Review(2, 2, today);

      final state = await helper.getSm2State(2);
      expect(state?.repetitions, 0);
      expect(state?.intervalDays, 1);
      expect(state?.lastQuality, 2);
      // q=5 hat den EF zuerst auf 2.6 angehoben, q=2 senkt dann um -0.32
      // (delta = 0.1 - 3*(0.08+3*0.02)) → 2.28.
      expect(state?.easeFactor, closeTo(2.28, 1e-9));
      // Naechste Faelligkeit: morgen.
      expect(state?.dueDate, '2026-09-15');
      expect(await helper.getDueSm2Count(today), 0);
      expect(
        await helper.getDueSm2Count(today.add(const Duration(days: 1))),
        1,
      );
    },
  );

  test(
    'SM-2: Wiederholungen staerken den Wort-Fortschritt (updateProgress)',
    () async {
      final helper = DatabaseHelper.instance;
      await helper.insertWords([wordA]);
      await helper.seedSm2ForBatch('A1', 0);

      await helper.updateProgress(1, true);
      expect(await helper.getGroupProgress('A1'), 1.0);
    },
  );
}
