import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/models/sentence.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/providers/learn_provider.dart';
import 'package:jumlah/providers/quiz_provider.dart';
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
    tempDir = Directory.systemTemp.createTempSync('jumlah_quiz_provider_test_');
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
    arabic: 'قَالَ',
    german: 'sagen',
    root: 'ق-و-ل',
    group: 'A1',
    frequencyRank: 3,
    transliteration: 'qāla',
  );
  final words = [wordA, wordB, wordC];

  /// Drei Beispiel-Sätze (einer je Wort) zur Versorgung der Satz-Stufen.
  Map<int, List<Sentence>> sentencesFor(List<Word> ws) {
    const sentences = [
      Sentence(
        wordId: 1,
        arabic: 'كَتَبَ الطَّالِبُ الدَّرْسَ.',
        german: 'Der Student schrieb die Lektion.',
        transliteration: 'Kataba aṭ-ṭālibu ad-darsa.',
        wordAnalysis: [WordAnalysis(word: 'كَتَبَ', translation: 'schrieb')],
        targetIndex: 0,
      ),
      Sentence(
        wordId: 2,
        arabic: 'قَرَأَ الْوَلَدُ الْكِتَابَ.',
        german: 'Der Junge las das Buch.',
        transliteration: 'Qaraʾa al-waladu al-kitāba.',
        wordAnalysis: [WordAnalysis(word: 'قَرَأَ', translation: 'las')],
        targetIndex: 0,
      ),
      Sentence(
        wordId: 3,
        arabic: 'قَالَ الرَّجُلُ الْحَقَّ.',
        german: 'Der Mann sagte die Wahrheit.',
        transliteration: 'Qāla ar-raǧulu al-ḥaqqa.',
        wordAnalysis: [WordAnalysis(word: 'قَالَ', translation: 'sagte')],
        targetIndex: 0,
      ),
    ];
    return {
      for (final s in sentences) s.wordId: [s],
    };
  }

  test('startQuiz initialisiert Stufe 1 (AR->DE) mit einer Frage je Wort', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    notifier.startQuiz(words, random: Random(1));
    final state = container.read(quizProvider);

    expect(state.stage, QuizStage.arabicToGerman);
    expect(state.words, words);
    expect(state.currentQuestion, isNotNull);
    expect(state.currentQuestion!.direction, QuizDirection.arabicToGerman);
    expect(state.queue.length + 1, words.length);
    expect(
      state.currentQuestion!.options,
      contains(state.currentQuestion!.correctAnswer),
    );
    expect(
      state.currentQuestion!.options.toSet(),
      hasLength(state.currentQuestion!.options.length),
    );
  });

  test('richtige Antwort erhoeht score und loest das Wort fuer die Stufe', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    notifier.startQuiz(words, random: Random(1));
    final question = container.read(quizProvider).currentQuestion!;
    notifier.submitAnswer(question.correctAnswer);

    final state = container.read(quizProvider);
    expect(state.score, 1);
    expect(state.lastAnswerCorrect, isTrue);
    expect(state.stageResolvedWordIds, contains(question.word.id));
  });

  test(
    'falsche Antwort zaehlt in den Gesamt-Fehlerstand, ohne das Wort zu wiederholen',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(quizProvider.notifier);

      notifier.startQuiz([wordA], random: Random(1));

      final question = container.read(quizProvider).currentQuestion!;
      notifier.submitAnswer('__falsche_antwort__');
      final state = container.read(quizProvider);

      expect(state.lastAnswerCorrect, isFalse);
      // Kein Requeue (Prüfung): Warteschlange bleibt leer.
      expect(state.queue, isEmpty);
      expect(state.wrongCount, 1);
      expect(state.finalWrongWordIds, contains(question.word.id));
      expect(state.stageResolvedWordIds, contains(question.word.id));
    },
  );

  test(
    'nextQuestion durchlaeuft alle 6 Stufen und markiert das Quiz als beendet',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(quizProvider.notifier);

      notifier.startQuiz(words, random: Random(42));

      final seenStages = <QuizStage>{};
      var guard = 0;
      while (!container.read(quizProvider).isFinished && guard < 300) {
        guard++;
        final state = container.read(quizProvider);
        seenStages.add(state.stage);
        final question = state.currentQuestion;
        if (question == null) break;
        notifier.submitAnswer(question.correctAnswer);
        notifier.nextQuestion();
      }

      final finalState = container.read(quizProvider);
      expect(finalState.isFinished, isTrue);
      expect(finalState.currentQuestion, isNull);
      // Ohne Sätze werden die Satz-Stufen (wholeSentence, audio, story)
      // übersprungen -> nur die 3 Wort-Stufen.
      expect(
        seenStages,
        {
          QuizStage.arabicToGerman,
          QuizStage.germanToArabic,
          QuizStage.mixed,
        },
      );
      expect(finalState.score, 9);
      expect(finalState.wrongWords, isEmpty);
      expect(finalState.wrongCount, 0);
      expect(finalState.passed, isTrue);
      expect(finalState.groupNowComplete, isFalse);
    },
  );

  test(
    'Satz-Stufen werden uebersprungen, wenn keine Saetze uebergeben wurden',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(quizProvider.notifier);

      notifier.startQuiz(words, random: Random(7));
      var guard = 0;
      while (!container.read(quizProvider).isFinished && guard < 300) {
        guard++;
        final question = container.read(quizProvider).currentQuestion;
        if (question == null) break;
        notifier.submitAnswer(question.correctAnswer);
        notifier.nextQuestion();
      }

      expect(container.read(quizProvider).isFinished, isTrue);
    },
  );

  test('Audio-Stufe erzeugt Hoerverstaendnis-Fragen, wenn Saetze uebergeben werden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    notifier.startQuiz(words, random: Random(9), sentencesByWordId: sentencesFor(words));

    var guard = 0;
    var sawAudio = false;
    while (!container.read(quizProvider).isFinished && guard < 300) {
      guard++;
      final state = container.read(quizProvider);
      final question = state.currentQuestion;
      if (question == null) break;
      if (state.stage == QuizStage.audio) {
        sawAudio = true;
        expect(question.isAudio, isTrue);
        expect(question.correctAnswer, question.sentence!.german);
        expect(question.options, contains(question.correctAnswer));
      }
      notifier.submitAnswer(question.correctAnswer);
      notifier.nextQuestion();
    }

    expect(sawAudio, isTrue);
    expect(container.read(quizProvider).isFinished, isTrue);
  });

  test(
      'Audio-Stufe funktioniert für spätere Lektionen (Lektion 21, Wort-IDs 201–210) mit echten 3 Sätzen/Wort',
      () async {
    // Importierte echte Asset-Daten statt künstlicher Fixtures: verifiziert die
    // Audio-Mechanik (Satz → MP3-Datei via `AudioService`) für den neuen
    // Lektions-Ausbau 21–50, wo jedes Wort genau 3 Kontext-Sätze hat.
    final helper = DatabaseHelper.instance;
    await helper.importWordsIfNeeded();
    await helper.importSentencesIfNeeded();

    final allWords = await helper.getWordsByGroup('A1');
    final lesson21 =
        allWords.where((w) => w.id >= 201 && w.id <= 210).toList();
    expect(lesson21, hasLength(10),
        reason: 'Lektion 21 = Wort-IDs 201–210 des neuen Ausbaus');

    final sentences = await sentencesForWords(lesson21);
    // Jedes Wort muss genau 3 Sätze haben (deterministische Datei-Nummerierung
    // 1–3 je Wort, Reihenfolge aus `getSentencesByWordIds` with orderBy id).
    for (final w in lesson21) {
      expect(sentences[w.id], hasLength(3),
          reason: 'Wort ${w.id} muss 3 Kontext-Sätze haben');
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);
    notifier.startQuiz(lesson21,
        sentencesByWordId: sentences, batchIndex: 20);

    final expectedStoryIds = [for (var id = 201; id <= 210; id++) id];
    var guard = 0;
    var audioQuestions = 0;
    while (!container.read(quizProvider).isFinished && guard < 400) {
      guard++;
      final state = container.read(quizProvider);
      final q = state.currentQuestion;
      if (q == null) break;
      if (state.stage == QuizStage.audio) {
        audioQuestions++;
        expect(q.isAudio, isTrue);
        // Gewählter Satz liegt innerhalb der 3 Sätze je Wort → gültiger
        // MP3-Dateinummer-Bereich (1..3 je Wort).
        expect(q.sentenceIndex, inInclusiveRange(0, 2));
        expect(q.correctAnswer, q.sentence!.german);
        expect(q.options, contains(q.correctAnswer));
      }
      notifier.submitAnswer(q.correctAnswer);
      notifier.nextQuestion();
    }

    expect(audioQuestions, greaterThan(0),
        reason: 'Audio-Stufe muss für Lektion 21 Fragen erzeugen');
    expect(container.read(quizProvider).isFinished, isTrue);

    // Die Stufe-6-Geschichte der Lektion 21 ist ebenfalls eigenständig/kompakt.
    final storyIds = container
        .read(quizProvider)
        .storySentences
        .map((s) => s.wordId)
        .toSet();
    expect(storyIds.containsAll(expectedStoryIds), isTrue,
        reason: 'Geschichte von Lektion 21 enthält deren 10 Wörter');
  });

  test('Geschichten-Stufe erzeugt Zuordnungs-Fragen aus der Geschichte', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    notifier.startQuiz(words, random: Random(3), sentencesByWordId: sentencesFor(words));

    var guard = 0;
    var sawStory = false;
    while (!container.read(quizProvider).isFinished && guard < 300) {
      guard++;
      final state = container.read(quizProvider);
      final question = state.currentQuestion;
      if (question == null) break;
      if (state.stage == QuizStage.story) {
        sawStory = true;
        expect(state.storySentences, isNotEmpty);
        expect(question.isStory, isTrue);
        expect(question.correctAnswer, question.sentence!.german);
        expect(question.options, contains(question.correctAnswer));
      }
      notifier.submitAnswer(question.correctAnswer);
      notifier.nextQuestion();
    }

    expect(sawStory, isTrue);
    expect(container.read(quizProvider).isFinished, isTrue);
  });

  test('Ganze-Saetze-Stufe uebersetzt den kompletten Satz, wenn Saetze uebergeben werden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    notifier.startQuiz(words, random: Random(9), sentencesByWordId: sentencesFor(words));

    var guard = 0;
    var sawWholeSentence = false;
    while (!container.read(quizProvider).isFinished && guard < 300) {
      guard++;
      final state = container.read(quizProvider);
      final question = state.currentQuestion;
      if (question == null) break;
      if (state.stage == QuizStage.wholeSentence) {
        sawWholeSentence = true;
        expect(question.isWholeSentence, isTrue);
        final sentence = question.sentence!;
        if (question.direction == QuizDirection.arabicToGerman) {
          expect(question.prompt, sentence.arabic);
          expect(question.correctAnswer, sentence.german);
        } else {
          expect(question.prompt, sentence.german);
          expect(question.correctAnswer, sentence.arabic);
        }
        expect(question.options, contains(question.correctAnswer));
      }
      notifier.submitAnswer(question.correctAnswer);
      notifier.nextQuestion();
    }

    expect(sawWholeSentence, isTrue);
    expect(container.read(quizProvider).isFinished, isTrue);
  });

  test('bis maxAllowedErrors Fehler bestandener Batch wird in SQLite als bestanden markiert', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    expect(await DatabaseHelper.instance.getPassedBatchIndexes('A1'), isEmpty);

    notifier.startQuiz(words, random: Random(5), group: 'A1', batchIndex: 0);
    var guard = 0;
    var answeredWrong = 0;
    while (!container.read(quizProvider).isFinished && guard < 300) {
      guard++;
      final question = container.read(quizProvider).currentQuestion;
      if (question == null) break;
      if (answeredWrong < maxAllowedErrors) {
        final wrong = question.options.firstWhere(
          (o) => o != question.correctAnswer,
          orElse: () => '__falsch__',
        );
        notifier.submitAnswer(wrong);
        answeredWrong++;
      } else {
        notifier.submitAnswer(question.correctAnswer);
      }
      notifier.nextQuestion();
    }

    expect(answeredWrong, maxAllowedErrors);
    expect(container.read(quizProvider).passed, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await DatabaseHelper.instance.getPassedBatchIndexes('A1'), {0});
  });

  test('mehr als maxAllowedErrors Fehler -> Batch wird NICHT bestanden, Gesamt-Neustart noetig', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    notifier.startQuiz(words, random: Random(9), group: 'A1', batchIndex: 1);

    var guard = 0;
    while (!container.read(quizProvider).isFinished && guard < 300) {
      guard++;
      final question = container.read(quizProvider).currentQuestion;
      if (question == null) break;
      final wrong = question.options.firstWhere(
        (o) => o != question.correctAnswer,
        orElse: () => '__falsch__',
      );
      notifier.submitAnswer(wrong);
      if (container.read(quizProvider).lastAnswerCorrect != null) {
        notifier.nextQuestion();
      }
    }

    expect(container.read(quizProvider).wrongCount, greaterThan(maxAllowedErrors));
    expect(container.read(quizProvider).passed, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await DatabaseHelper.instance.getPassedBatchIndexes('A1'), isEmpty);
  });

  test('startOrResumeQuiz setzt nach einem simulierten App-Neustart mit dem Fehlerstand fort', () async {
    final container1 = ProviderContainer();
    final notifier1 = container1.read(quizProvider.notifier);
    await notifier1.startOrResumeQuiz(words, random: Random(1), group: 'A1', batchIndex: 0);
    notifier1.submitAnswer('__falsch_1__');
    expect(container1.read(quizProvider).wrongCount, 1);

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final notifier2 = container2.read(quizProvider.notifier);
    await notifier2.startOrResumeQuiz(words, random: Random(2), group: 'A1', batchIndex: 0);

    expect(container2.read(quizProvider).wrongCount, 1);
  });

  test('startOrResumeQuiz setzt eine in der Story-Stufe (6/6) unterbrochene Sitzung fort, ohne zu crashen', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    // Durch die Wort-Stufen laufen, bis die Story-Stufe erreicht ist.
    await notifier.startOrResumeQuiz(
      words,
      random: Random(7),
      group: 'A1',
      batchIndex: 0,
      sentencesByWordId: sentencesFor(words),
    );
    var guard = 0;
    while (container.read(quizProvider).stage != QuizStage.story && guard < 300) {
      guard++;
      final q = container.read(quizProvider).currentQuestion;
      if (q == null) break;
      notifier.submitAnswer(q.correctAnswer);
      notifier.nextQuestion();
    }
    expect(container.read(quizProvider).stage, QuizStage.story);
    expect(container.read(quizProvider).currentQuestion, isNotNull);

    // Eine Story-Frage beantworten -> Wort der Stufe als gelöst persistiert.
    notifier.submitAnswer(container.read(quizProvider).currentQuestion!.correctAnswer);
    final resolved = container.read(quizProvider).stageResolvedWordIds;
    expect(resolved, isNotEmpty);

    // Simulierter App-Neustart: Fragen danach nur für noch nicht gelöste Sätze.
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final notifier2 = container2.read(quizProvider.notifier);
    await notifier2.startOrResumeQuiz(
      words,
      random: Random(8),
      group: 'A1',
      batchIndex: 0,
      sentencesByWordId: sentencesFor(words),
    );

    final resumed = container2.read(quizProvider);
    expect(resumed.stage, QuizStage.story);
    expect(resumed.stageResolvedWordIds, resolved);
    expect(resumed.currentQuestion, isNotNull);
    // Kein bereits gelöstes Story-Wort darf erneut als Frage auftauchen.
    expect(resolved, isNot(contains(resumed.currentQuestion!.word.id)));
  });

  test('startOrResumeQuiz beginnt ohne vorhandene Sitzung wie startQuiz von vorn', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    await notifier.startOrResumeQuiz(words, random: Random(1), group: 'A1', batchIndex: 2);

    final state = container.read(quizProvider);
    expect(state.stage, QuizStage.arabicToGerman);
    expect(state.attempts, isEmpty);
    expect(state.wrongCount, 0);
    expect(state.currentQuestion, isNotNull);
  });

  test('regulär beendetes (getracktes) Quiz loescht die Zwischenstands-Sitzung', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    await notifier.startOrResumeQuiz(words, random: Random(5), group: 'A1', batchIndex: 0);
    var guard = 0;
    while (!container.read(quizProvider).isFinished && guard < 300) {
      guard++;
      final question = container.read(quizProvider).currentQuestion;
      if (question == null) break;
      notifier.submitAnswer(question.correctAnswer);
      notifier.nextQuestion();
    }

    expect(container.read(quizProvider).isFinished, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await DatabaseHelper.instance.getQuizSession('A1', 0), isNull);
  });

  test('letzter, bestandener Batch (isLastBatch) markiert die Gruppe als komplett', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(quizProvider.notifier);

    notifier.startQuiz(words, random: Random(11), group: 'A1', batchIndex: 4, isLastBatch: true);
    var guard = 0;
    while (!container.read(quizProvider).isFinished && guard < 300) {
      guard++;
      final question = container.read(quizProvider).currentQuestion;
      if (question == null) break;
      notifier.submitAnswer(question.correctAnswer);
      notifier.nextQuestion();
    }

    expect(container.read(quizProvider).passed, isTrue);
    expect(container.read(quizProvider).groupNowComplete, isTrue);
  });
test('Geschichte der Lektion ist eigenständig und kompakt (nicht kumulativ)',
      () {
    // Fuer jede Lektion 1..6 pruefen: die Stufe-6-Geschichte besteht nur aus
    // den zehn Wörtern DIESER Lektion (kompakte Kurzgeschichte, nicht die
    // angesammelten Saetze aller bisherigen Lektionen).
    Word w(int id) => Word(
      id: id,
      arabic: 'wort_$id',
      german: 'deutsch_$id',
      root: 'wurzel',
      group: 'A1',
      frequencyRank: id,
      transliteration: 'wort',
    );

    for (var lesson = 1; lesson <= 50; lesson++) {
      final lo = (lesson - 1) * 10 + 1;
      final hi = lesson * 10;
      final batch = [for (var id = lo; id <= hi; id++) w(id)];
      // Wortschatz-Pool: alle bisher gelernten Wörter (Lektionen 1..lesson),
      // wie sie `startOrResumeQuiz` in der echten App aus SQLite nachlade.
      final storyPool = [for (var id = 1; id <= hi; id++) w(id)];
      final sentences = {
        for (final word in batch)
          word.id: [
            Sentence(
              wordId: word.id,
              arabic: 'satz_${word.id}',
              german: 'Satz Deutsch ${word.id}',
              transliteration: 'satz',
              wordAnalysis: const [],
              targetIndex: 0,
            ),
          ],
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(quizProvider.notifier);
      notifier.startQuiz(batch,
          sentencesByWordId: sentences,
          storyWords: storyPool,
          batchIndex: lesson - 1);

      var guard = 0;
      while (!container.read(quizProvider).isFinished && guard < 300) {
        guard++;
        final question = container.read(quizProvider).currentQuestion;
        if (question == null) {
          notifier.nextQuestion();
          continue;
        }
        notifier.submitAnswer(question.correctAnswer);
        notifier.nextQuestion();
      }

      final state = container.read(quizProvider);
      // Kompakte Kurzgeschichte: genau 10 Saetze (Word-IDs der Lektion).
      expect(state.storySentences, hasLength(10),
          reason: 'Lektion $lesson: Geschichte soll nicht kumulativ wachsen.');
      final ids = state.storySentences.map((s) => s.wordId).toSet();
      expect(ids, hasLength(10));
      expect(ids, containsAll([for (var id = lo; id <= hi; id++) id]),
          reason: 'Lektion $lesson: enthaelt die Wörter der Lektion');
      // bewusst KEINE Wörter frueherer Lektionen (nicht kumulativ):
      for (final id in ids) {
        expect(id >= lo && id <= hi, isTrue,
            reason: 'Lektion $lesson: Geschichte ist nicht kumulativ.');
      }
    }
  });
test('Geschichte der B1-Lektionen 101-103 ist eigenstandig und kompakt (nicht kumulativ)',
      () {
    Word w(int id) => Word(
      id: id,
      arabic: 'wort_$id',
      german: 'deutsch_$id',
      root: 'wurzel',
      group: 'B1',
      frequencyRank: id,
      transliteration: 'wort',
    );

    for (var lesson = 101; lesson <= 103; lesson++) {
      final batchIndex = lesson - 1;
      final wordLo = 1000 + (lesson - 100) * 10 - 9;
      final wordHi = wordLo + 9;
      final batch = [for (var id = wordLo; id <= wordHi; id++) w(id)];
      final storyPool = [for (var id = wordLo; id <= wordHi; id++) w(id)];
      final sentences = {
        for (final word in batch)
          word.id: [
            Sentence(
              wordId: word.id,
              arabic: 'satz_${word.id}',
              german: 'Satz Deutsch ${word.id}',
              transliteration: 'satz',
              wordAnalysis: const [],
              targetIndex: 0,
            ),
          ],
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(quizProvider.notifier);
      notifier.startQuiz(batch,
          sentencesByWordId: sentences,
          storyWords: storyPool,
          batchIndex: batchIndex);

      var guard = 0;
      while (!container.read(quizProvider).isFinished && guard < 300) {
        guard++;
        final question = container.read(quizProvider).currentQuestion;
        if (question == null) {
          notifier.nextQuestion();
          continue;
        }
        notifier.submitAnswer(question.correctAnswer);
        notifier.nextQuestion();
      }

      final state = container.read(quizProvider);
      expect(state.storySentences, hasLength(10),
          reason: 'Lektion $lesson: Geschichte soll nicht kumulativ wachsen.');
      final ids = state.storySentences.map((s) => s.wordId).toSet();
      expect(ids, hasLength(10));
      expect(ids, containsAll([for (var id = wordLo; id <= wordHi; id++) id]),
          reason: 'Lektion $lesson: enthaelt die Woerter der Lektion');
      for (final id in ids) {
        expect(id >= wordLo && id <= wordHi, isTrue,
            reason: 'Lektion $lesson: Geschichte ist nicht kumulativ.');
      }
    }
  });
}
