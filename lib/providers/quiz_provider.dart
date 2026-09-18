import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_helper.dart';
import '../core/word_groups.dart' show nextLevelAfter;
import '../models/quiz_session.dart';
import '../models/sentence.dart';
import '../models/word.dart';
import '../screens/learn/learn_audio_constants.dart' show sentencesPerLesson;

/// Richtung einer einzelnen Vokabel-/Satz-Frage.
enum QuizDirection { arabicToGerman, germanToArabic }

/// Die sechs Stufen der „Prüfung“ (Nutzer-Vorgabe, 29. August 2026):
///  1. Arabisch → Deutsch (Wort)
///  2. Deutsch → Arabisch (Wort)
///  3. Wort Arabisch/Deutsch abwechselnd
///  4. Sätze Arabisch/Deutsch abwechselnd
///  5. Arabische Audio → deutsche Textoption
///  6. Kurze Geschichte aus den gelernten Wörtern → Sätze aus dem Text,
///     passende Bedeutung wählen
enum QuizStage {
  arabicToGerman,
  germanToArabic,
  mixed,
  wholeSentence,
  audio,
  story,
}

/// Anzahl erlaubter Fehler über den gesamten Prüfungslauf. Mehr Fehler ->
/// nicht bestanden (Prüfungs-Modell, Nutzer-Vorgabe: 3 sind erlaubt).
const int maxAllowedErrors = 3;

class QuizQuestion {
  const QuizQuestion({
    required this.word,
    this.direction,
    this.sentence,
    this.sentenceIndex = 0,
    required this.options,
    this.isWholeSentence = false,
    this.isAudio = false,
    this.isStory = false,
  });

  final Word word;

  /// Für Vokabel-Fragen sowie für [QuizStage.wholeSentence] gesetzt (dort
  /// bestimmt es, ob der ganze Satz auf Arabisch oder Deutsch als Prompt
  /// gezeigt wird).
  final QuizDirection? direction;

  /// Für Satz-Fragen ([QuizStage.wholeSentence]), Audio- ([QuizStage.audio])
  /// und Geschichten-Fragen ([QuizStage.story]) gesetzt.
  final Sentence? sentence;

  /// 0-basierter Index des Satzes innerhalb der Sätze desselben Worts —
  /// nötig für die Audio-Zuordnung (Datei `\audio\lektion_N\datei.mp3`,
  /// siehe `AudioService`). Relevante Konstante: [learn_audio_constants].
  final int sentenceIndex;

  final List<String> options;

  /// [QuizStage.wholeSentence] — ganze Sätze abwechselnd übersetzen.
  final bool isWholeSentence;

  /// [QuizStage.audio] — arabischen Satz anhören, deutsche Bedeutung wählen.
  final bool isAudio;

  /// [QuizStage.story] — Satz aus der Geschichte, passende Bedeutung wählen.
  final bool isStory;

  bool get isStoryOrAudio => isAudio || isStory;

  String get prompt {
    final sentence = this.sentence;
    if (sentence != null) {
      if (isWholeSentence) {
        return direction == QuizDirection.arabicToGerman
            ? sentence.arabic
            : sentence.german;
      }
      return sentence.arabic;
    }
    return direction == QuizDirection.arabicToGerman ? word.arabic : word.german;
  }

  String get correctAnswer {
    final sentence = this.sentence;
    if (sentence != null) {
      if (isWholeSentence) {
        return direction == QuizDirection.arabicToGerman
            ? sentence.german
            : sentence.arabic;
      }
      // Audio- und Geschichten-Fragen: arabischer Satz als Prompt,
      // deutsche Übersetzung ist die richtige Antwort.
      return sentence.german;
    }
    return direction == QuizDirection.arabicToGerman ? word.german : word.arabic;
  }
}

class QuizState {
  const QuizState({
    this.words = const [],
    this.sentencesByWordId = const {},
    this.storyWords = const [],
    this.storySentences = const [],
    this.group,
    this.batchIndex,
    this.isLastBatch = false,
    this.stage = QuizStage.arabicToGerman,
    this.queue = const [],
    this.currentQuestion,
    this.attempts = const {},
    this.correctCount = 0,
    this.wrongCount = 0,
    this.stageResolvedWordIds = const {},
    this.finalWrongWordIds = const {},
    this.lastAnswerCorrect,
    this.isFinished = false,
    this.passed,
    this.groupNowComplete = false,
  });

  final List<Word> words;

  /// Sätze je Wort-ID, Grundlage für die Satz-Stufen
  /// (`learn_provider.dart#sentencesForWords`, von dort geladen und übergeben).
  final Map<int, List<Sentence>> sentencesByWordId;

  /// Wortschatz-Pool für die Geschichten-Stufe ([QuizStage.story]): enthält
  /// bei getrackten Läufen alle bisher gelernten Wörter der Gruppe (Lektionen
  /// 1..N, via [QuizNotifier.startOrResumeQuiz] aus SQLite geladen), damit die
  /// kumulative Geschichte („Lektion N nutzt Wörter aus Lektion 1..N“) Fragen
  /// zu all diesen Wörtern bauen kann. Bei ungetrackten/synchronen
  /// [QuizNotifier.startQuiz]-Aufrufen (z.B. Tests, Gesamtprüfung) fällt es
  /// auf den aktuellen Batch [words] zurück.
  final List<Word> storyWords;

  /// Die Geschichte der Stufe 6 ([QuizStage.story]): die arabischen Sätze
  /// (1 je Wort des Batches), die zusammen als „kurze Geschichte“ angezeigt
  /// werden. Die daraus abgeleiteten Fragen stehen in [queue].
  final List<Sentence> storySentences;

  /// Gruppe/Batch-Index für das Freischalt-Tracking — null bei ungetrackten
  /// Läufen (z.B. Gesamtprüfung nach Abschluss einer Gruppe).
  final String? group;
  final int? batchIndex;

  /// Ob dies der letzte Batch der Gruppe ist — bestimmt, ob nach dem
  /// Bestehen die Gesamtprüfung angeboten wird ([groupNowComplete]).
  final bool isLastBatch;

  final QuizStage stage;
  final List<QuizQuestion> queue;
  final QuizQuestion? currentQuestion;
  final Map<int, int> attempts;
  final int correctCount;
  final int wrongCount;
  final Set<int> stageResolvedWordIds;
  final Set<int> finalWrongWordIds;
  final bool? lastAnswerCorrect;
  final bool isFinished;

  /// Nur bei [isFinished] gesetzt: true, wenn der Batch fehlerfrei bestanden
  /// wurde (keine [finalWrongWordIds]) — Voraussetzung fürs Freischalten des
  /// nächsten Batches.
  final bool? passed;

  /// True, wenn mit diesem (fehlerfreien) Abschluss die gesamte Gruppe
  /// bestanden ist ([isLastBatch] und [passed]).
  final bool groupNowComplete;

  int get score => correctCount;

  /// Fortschritt innerhalb der aktuellen Stufe, 0.0–1.0.
  double get stageProgress =>
      words.isEmpty ? 0 : stageResolvedWordIds.length / words.length;

  List<Word> get wrongWords =>
      words.where((w) => finalWrongWordIds.contains(w.id)).toList();

  QuizState copyWith({
    List<Word>? words,
    Map<int, List<Sentence>>? sentencesByWordId,
    List<Word>? storyWords,
    List<Sentence>? storySentences,
    String? group,
    int? batchIndex,
    bool? isLastBatch,
    QuizStage? stage,
    List<QuizQuestion>? queue,
    QuizQuestion? currentQuestion,
    bool clearCurrentQuestion = false,
    Map<int, int>? attempts,
    int? correctCount,
    int? wrongCount,
    Set<int>? stageResolvedWordIds,
    Set<int>? finalWrongWordIds,
    bool? lastAnswerCorrect,
    bool clearLastAnswer = false,
    bool? isFinished,
    bool? passed,
    bool? groupNowComplete,
  }) {
    return QuizState(
      words: words ?? this.words,
      sentencesByWordId: sentencesByWordId ?? this.sentencesByWordId,
      storyWords: storyWords ?? this.storyWords,
      storySentences: storySentences ?? this.storySentences,
      group: group ?? this.group,
      batchIndex: batchIndex ?? this.batchIndex,
      isLastBatch: isLastBatch ?? this.isLastBatch,
      stage: stage ?? this.stage,
      queue: queue ?? this.queue,
      currentQuestion: clearCurrentQuestion
          ? null
          : (currentQuestion ?? this.currentQuestion),
      attempts: attempts ?? this.attempts,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      stageResolvedWordIds: stageResolvedWordIds ?? this.stageResolvedWordIds,
      finalWrongWordIds: finalWrongWordIds ?? this.finalWrongWordIds,
      lastAnswerCorrect: clearLastAnswer
          ? null
          : (lastAnswerCorrect ?? this.lastAnswerCorrect),
      isFinished: isFinished ?? this.isFinished,
      passed: passed ?? this.passed,
      groupNowComplete: groupNowComplete ?? this.groupNowComplete,
    );
  }
}

class QuizNotifier extends Notifier<QuizState> {
  Random _random = Random();

  @override
  QuizState build() => const QuizState();

  /// Startet ein neues Quiz mit [words] (Stufe 1: Arabisch → Deutsch).
  /// [random] optional für deterministische Tests. [group]/[batchIndex]
  /// aktivieren das Freischalt-Tracking (siehe [QuizState.group]); ohne sie
  /// bleibt der Lauf ungetrackt (z.B. Gesamtprüfung). [sentencesByWordId]
  /// speist die Satz-Lückentext-Stufe — ohne Sätze wird diese Stufe
  /// übersprungen. [storyWords] ist der Wortschatz-Pool für die
  /// Geschichten-Stufe (Standard: [words]); getrackte Läufe reichen dort die
  /// über [startOrResumeQuiz] geladenen, bisher gelernten Wörter durch.
  void startQuiz(
    List<Word> words, {
    Random? random,
    String? group,
    int? batchIndex,
    bool isLastBatch = false,
    Map<int, List<Sentence>> sentencesByWordId = const {},
    List<Word>? storyWords,
  }) {
    if (random != null) {
      _random = random;
    }
    state = QuizState(
      words: words,
      sentencesByWordId: sentencesByWordId,
      storyWords: storyWords ?? words,
      group: group,
      batchIndex: batchIndex,
      isLastBatch: isLastBatch,
      stage: QuizStage.arabicToGerman,
    );
    final queue = _buildQueue(words, QuizStage.arabicToGerman);
    state = state.copyWith(
      queue: queue.isEmpty ? const [] : queue.sublist(1),
      currentQuestion: queue.isEmpty ? null : queue.first,
    );
  }

  /// Lädt die bisher gelernten Wörter der [group] bis einschließlich der
  /// aktuellen Lektion ([batchIndex] 0-basiert, daher +1) aus SQLite — der
  /// Wortschatz-Pool für eine kumulative Geschichte. Liefert `null`, wenn
  /// keine Wörter gefunden werden (dann bleibt die Story auf den Batch
  /// beschränkt).
  Future<List<Word>?> _loadLearnedWords(String group, int batchIndex) async {
    final maxRank = (batchIndex + 1) * sentencesPerLesson;
    final words = await DatabaseHelper.instance
        .getWordsByGroupUpToRank(group, maxRank);
    return words.isEmpty ? null : words;
  }

  /// Wie [startQuiz], aber für getrackte Batches (Task G3, Anti-Cheat): lädt
  /// zuerst eine evtl. vorhandene, unterbrochene Sitzung aus SQLite
  /// ([DatabaseHelper.getQuizSession]) und setzt exakt dort fort (Stufe,
  /// bereits verbrauchte Fehlversuche, bereits gelöste/endgültig falsche
  /// Wörter). Ohne vorhandene Sitzung entspricht das Verhalten [startQuiz].
  /// Verhindert, dass ein App-Neustart mitten im Quiz bereits verbrauchte
  /// Fehlversuche der 3-Fehler-Regel zurücksetzt.
  Future<void> startOrResumeQuiz(
    List<Word> words, {
    Random? random,
    required String group,
    required int batchIndex,
    bool isLastBatch = false,
    Map<int, List<Sentence>> sentencesByWordId = const {},
  }) async {
    final session = await DatabaseHelper.instance.getQuizSession(
      group,
      batchIndex,
    );
    // Wortschatz-Pool für die (kumulative) Geschichte: alle bisher gelernten
    // Wörter der Gruppe bis einschließlich dieser Lektion.
    final learnedWords = await _loadLearnedWords(group, batchIndex);
    // Lernstatistik (Task: Heatmap/Streak): jeder gestartete/fortgesetzte
    // Quiz-Lauf zählt als Aktivität für den heutigen Tag. Bewusst hier
    // (awaited, einmal pro Lauf) statt in [submitAnswer] — dort würde ein
    // fire-and-forget-DB-Zugriff aus dem Tap-Pfad hängen bleiben (bekanntes
    // FakeAsync-Muster, siehe Test-Erkenntnisse).
    await DatabaseHelper.instance.trackStudyActivity(quizAnswers: 1);
    if (session == null) {
      startQuiz(
        words,
        random: random,
        group: group,
        batchIndex: batchIndex,
        isLastBatch: isLastBatch,
        sentencesByWordId: sentencesByWordId,
        storyWords: learnedWords,
      );
      return;
    }

    if (random != null) {
      _random = random;
    }
    final stage = QuizStage.values.byName(session.stage);
    state = QuizState(
      words: words,
      sentencesByWordId: sentencesByWordId,
      storyWords: learnedWords ?? words,
      group: group,
      batchIndex: batchIndex,
      isLastBatch: isLastBatch,
      stage: stage,
      attempts: session.attempts,
      correctCount: session.correctCount,
      wrongCount: session.wrongCount,
      stageResolvedWordIds: session.stageResolvedWordIds,
      finalWrongWordIds: session.finalWrongWordIds,
    );

    final remainingWords = words
        .where((w) => !session.stageResolvedWordIds.contains(w.id))
        .toList();
    if (remainingWords.isEmpty) {
      // Alle Wörter dieser Stufe waren schon gelöst -> direkt weiter zur
      // nächsten Stufe (oder Quiz-Ende), analog zum Stufenwechsel in
      // nextQuestion().
      nextQuestion();
      return;
    }
    // Story-Stufe: Die Geschichten-Queue wird über _buildStory/_buildStoryQueue
    // gebaut (wie in nextQuestion) — _buildQueue wirft für `story` bewusst
    // (siehe _directionFor). Bereits in der Stufe gelöste Sätze werden nicht
    // erneut eingereiht. Ohne diesen Zweig stürzte das Fortsetzen einer in der
    // 6. Stufe unterbrochenen Sitzung mit „story hat keine QuizDirection“ ab.
    final queue = stage == QuizStage.story
        ? _buildStoryQueue(
            _buildStory()
                .where(
                  (s) => !session.stageResolvedWordIds.contains(s.wordId),
                )
                .toList(),
          )
        : _buildQueue(remainingWords, stage);
    state = state.copyWith(
      queue: queue.isEmpty ? const [] : queue.sublist(1),
      currentQuestion: queue.isEmpty ? null : queue.first,
    );
  }

  /// Verwirft eine evtl. vorhandene, unterbrochene Sitzung dieses Batches
  /// und beginnt das Quiz fest bei Stufe 1 — für Nutzer, die bewusst von
  /// vorne beginnen möchten, statt automatisch fortzusetzen ([startOrResumeQuiz]).
  Future<void> restartQuiz(
    List<Word> words, {
    Random? random,
    String? group,
    int? batchIndex,
    bool isLastBatch = false,
    Map<int, List<Sentence>> sentencesByWordId = const {},
  }) async {
    if (group != null && batchIndex != null) {
      await DatabaseHelper.instance.clearQuizSession(group, batchIndex);
    }
    final learnedWords = (group != null && batchIndex != null)
        ? await _loadLearnedWords(group, batchIndex)
        : null;
    startQuiz(
      words,
      random: random,
      group: group,
      batchIndex: batchIndex,
      isLastBatch: isLastBatch,
      sentencesByWordId: sentencesByWordId,
      storyWords: learnedWords,
    );
  }

  /// Prüft [answer] gegen die aktuelle Frage. Es gibt **kein** Sofort-Feedback
  /// und **kein** Wiederholen (Requeue) mehr wie früher — pro Frage nur ein
  /// Versuch, falsche Antworten zählen in den Gesamt-Fehlerstand [QuizState.wrongCount].
  /// Das Wort zählt als endgültig falsch ([QuizState.finalWrongWordIds]) für
  /// die Ergebnismenge.
  void submitAnswer(String answer) {
    final question = state.currentQuestion;
    if (question == null || state.lastAnswerCorrect != null) {
      return;
    }

    final isCorrect =
        answer.trim().toLowerCase() ==
        question.correctAnswer.trim().toLowerCase();
    final wordId = question.word.id;

    // Unabhängig vom Ausgang zählt die Frage als in dieser Stufe gelöst.
    final resolved = {...state.stageResolvedWordIds, wordId};
    state = state.copyWith(
      stageResolvedWordIds: resolved,
      lastAnswerCorrect: isCorrect,
    );

    if (isCorrect) {
      state = state.copyWith(correctCount: state.correctCount + 1);
    } else {
      state = state.copyWith(
        wrongCount: state.wrongCount + 1,
        finalWrongWordIds: {...state.finalWrongWordIds, wordId},
      );
    }
    _persistTrackedSession();
  }

  /// Schreibt den aktuellen Zwischenstand eines getrackten Laufs (Task G3,
  /// Anti-Cheat) nach SQLite — Fire-and-forget, analog zu
  /// [DatabaseHelper.markBatchPassed] in [nextQuestion]. Ungetrackte Läufe
  /// (z.B. Gesamtprüfung, kein `batchIndex`) werden nicht persistiert.
  void _persistTrackedSession() {
    final group = state.group;
    final batchIndex = state.batchIndex;
    if (group == null || batchIndex == null) {
      return;
    }
    DatabaseHelper.instance.saveQuizSession(
      QuizSession(
        group: group,
        batchIndex: batchIndex,
        stage: state.stage.name,
        attempts: state.attempts,
        stageResolvedWordIds: state.stageResolvedWordIds,
        finalWrongWordIds: state.finalWrongWordIds,
        correctCount: state.correctCount,
        wrongCount: state.wrongCount,
      ),
    );
  }

  /// Wechselt zur nächsten Frage in der Warteschlange, zur nächsten Stufe
  /// (bei leerer Warteschlange — Stufen ohne Fragen, z.B. wenn keine Sätze
  /// übergeben wurden, werden übersprungen) oder markiert das Quiz als
  /// beendet (nach der letzten Stufe). Bestanden gilt bei
  /// [QuizState.wrongCount] ≤ [maxAllowedErrors]; bei getracktem Abschluss
  /// wird der Batch in SQLite entsprechend markiert.
  void nextQuestion() {
    if (state.queue.isNotEmpty) {
      final nextQueue = List<QuizQuestion>.from(state.queue);
      final next = nextQueue.removeAt(0);
      state = state.copyWith(
        queue: nextQueue,
        currentQuestion: next,
        clearLastAnswer: true,
      );
      _persistTrackedSession();
      return;
    }

    var nextStage = _nextStage(state.stage);
    while (nextStage != null) {
      if (nextStage == QuizStage.story) {
        final story = _buildStory();
        if (story.isEmpty) {
          nextStage = _nextStage(nextStage);
          continue;
        }
        final queue = _buildStoryQueue(story);
        state = state.copyWith(
          stage: nextStage,
          storySentences: story,
          queue: queue.sublist(1),
          currentQuestion: queue.first,
          attempts: const {},
          stageResolvedWordIds: const {},
          clearLastAnswer: true,
        );
        _persistTrackedSession();
        return;
      }

      final queue = _buildQueue(state.words, nextStage);
      if (queue.isNotEmpty) {
        state = state.copyWith(
          stage: nextStage,
          queue: queue.sublist(1),
          currentQuestion: queue.first,
          attempts: const {},
          stageResolvedWordIds: const {},
          clearLastAnswer: true,
        );
        _persistTrackedSession();
        return;
      }
      nextStage = _nextStage(nextStage);
    }

    final passed = state.wrongCount <= maxAllowedErrors;
    final groupNowComplete = passed && state.isLastBatch;
    state = state.copyWith(
      clearCurrentQuestion: true,
      clearLastAnswer: true,
      isFinished: true,
      passed: passed,
      groupNowComplete: groupNowComplete,
    );

    final group = state.group;
    final batchIndex = state.batchIndex;
    if (group != null && batchIndex != null) {
      if (passed) {
        DatabaseHelper.instance.markBatchPassed(group, batchIndex);
        // Spaced Repetition (Task: SM-2): die Wörter der bestandenen Lektion
        // wandern in den Wiederholungs-Pool, damit sie nach SM-2 fällig
        // abgefragt werden können (fire-and-forget, analog markBatchPassed).
        DatabaseHelper.instance.seedSm2ForBatch(group, batchIndex);
        // Lernstatistik (Task: Heatmap/Streak): eine fehlerfrei bestandene
        // Lektion zählt als Aktivität (fire-and-forget, analog markBatchPassed).
        DatabaseHelper.instance.trackStudyActivity(lessonsCompleted: 1);
        // Stufen-Freischaltung durch Abschluss (seit 10. September 2026 keine
        // Käufe mehr): Ist die letzte Lektion einer Stufe bestanden, wird die
        // nächste Stufe (z.B. A2 nach A1) automatisch freigeschaltet.
        if (groupNowComplete) {
          final next = nextLevelAfter(group);
          if (next != null) {
            DatabaseHelper.instance.unlockLevel(next.group);
          }
        }
      }
      // Regulär beendeter Lauf (bestanden oder nicht) -> keine unterbrochene
      // Sitzung mehr, die fortgesetzt werden müsste (Task G3).
      DatabaseHelper.instance.clearQuizSession(group, batchIndex);
    }
  }

  QuizStage? _nextStage(QuizStage stage) {
    switch (stage) {
      case QuizStage.arabicToGerman:
        return QuizStage.germanToArabic;
      case QuizStage.germanToArabic:
        return QuizStage.mixed;
      case QuizStage.mixed:
        return QuizStage.wholeSentence;
      case QuizStage.wholeSentence:
        return QuizStage.audio;
      case QuizStage.audio:
        return QuizStage.story;
      case QuizStage.story:
        return null;
    }
  }

  List<QuizQuestion> _buildQueue(List<Word> words, QuizStage stage) {
    if (stage == QuizStage.wholeSentence) {
      return _buildWholeSentenceQueue(words);
    }
    if (stage == QuizStage.audio) {
      return _buildAudioQueue(words);
    }
    // Wort-Stufen (arabicToGerman/germanToArabic/mixed).
    return words.map((word) {
      final direction = _directionFor(stage);
      return QuizQuestion(
        word: word,
        direction: direction,
        options: _buildOptions(word, direction, words),
      );
    }).toList();
  }

  /// Eine Ganze-Sätze-Frage je Wort (ein zufällig gewählter Satz davon),
  /// Richtung wechselt pro Frage wie bei [QuizStage.mixed]. Der komplette
  /// Satz wird übersetzt, nicht nur ein Zielwort. Wörter ohne Sätze werden
  /// übersprungen.
  List<QuizQuestion> _buildWholeSentenceQueue(List<Word> words) {
    final chosen = <Word, Sentence>{};
    for (final word in words) {
      final sentences = state.sentencesByWordId[word.id];
      if (sentences == null || sentences.isEmpty) {
        continue;
      }
      chosen[word] = sentences[_random.nextInt(sentences.length)];
    }

    return chosen.entries.map((entry) {
      final word = entry.key;
      final sentence = entry.value;
      final direction = _random.nextBool()
          ? QuizDirection.arabicToGerman
          : QuizDirection.germanToArabic;
      String fieldOf(Sentence s) =>
          direction == QuizDirection.arabicToGerman ? s.german : s.arabic;

      final correct = fieldOf(sentence);
      final distractorPool =
          (chosen.values.where((s) => s != sentence).map(fieldOf).toSet()
                ..remove(correct))
              .toList()
            ..shuffle(_random);
      final options = <String>{correct, ...distractorPool.take(3)}.toList()
        ..shuffle(_random);

      return QuizQuestion(
        word: word,
        direction: direction,
        sentence: sentence,
        options: options,
        isWholeSentence: true,
      );
    }).toList();
  }

  /// Eine Audio-Frage je Wort: ein zufällig gewählter Satz wird als
  /// arabisches Audio abgespielt, die deutschen Übersetzungen stehen zur
  /// Auswahl. Wörter ohne Sätze werden übersprungen.
  List<QuizQuestion> _buildAudioQueue(List<Word> words) {
    final chosen = <Word, Sentence>{};
    final chosenIndex = <Word, int>{};
    for (final word in words) {
      final sentences = state.sentencesByWordId[word.id];
      if (sentences == null || sentences.isEmpty) {
        continue;
      }
      final index = _random.nextInt(sentences.length);
      chosen[word] = sentences[index];
      chosenIndex[word] = index;
    }

    final germanPool = chosen.values.map((s) => s.german).toSet().toList();

    return chosen.entries.map((entry) {
      final word = entry.key;
      final sentence = entry.value;
      final correct = sentence.german;
      final distractorPool = germanPool
          .where((g) => g != correct)
          .toList()
        ..shuffle(_random);
      final options = <String>{correct, ...distractorPool.take(3)}.toList()
        ..shuffle(_random);

      return QuizQuestion(
        word: word,
        sentence: sentence,
        sentenceIndex: chosenIndex[word] ?? 0,
        options: options,
        isAudio: true,
      );
    }).toList();
  }

  /// Liefert die eigenständige Kurzgeschichte zur Lektion [batchIndex]
  /// (0-basiert) oder `null`, wenn für diese Lektion keine eigens verfasste
  /// Geschichte existiert.
  List<Sentence>? _storyForBatch(int? batchIndex) {
    switch (batchIndex) {
      case 0:
        return _lessonOneStory;
      case 1:
        return _lessonTwoStory;
      case 2:
        return _lessonThreeStory;
      case 3:
        return _lessonFourStory;
      case 4:
        return _lessonFiveStory;
      case 5:
        return _lessonSixStory;
      case 6:
        return _lessonSevenStory;
      case 7:
        return _lessonEightStory;
      case 8:
        return _lessonNineStory;
      case 9:
        return _lessonTenStory;
      case 10:
        return _lessonElevenStory;
      case 11:
        return _lessonTwelveStory;
      case 12:
        return _lessonThirteenStory;
      case 13:
        return _lessonFourteenStory;
      case 14:
        return _lessonFifteenStory;
      case 15:
        return _lessonSixteenStory;
      case 16:
        return _lessonSeventeenStory;
      case 17:
        return _lessonEighteenStory;
      case 18:
        return _lessonNineteenStory;
      case 19:
        return _lessonTwentyStory;
      case 20:
        return _lessonTwentyOneStory;
      case 21:
        return _lessonTwentyTwoStory;
      case 22:
        return _lessonTwentyThreeStory;
      case 23:
        return _lessonTwentyFourStory;
      case 24:
        return _lessonTwentyFiveStory;
      case 25:
        return _lessonTwentySixStory;
      case 26:
        return _lessonTwentySevenStory;
      case 27:
        return _lessonTwentyEightStory;
      case 28:
        return _lessonTwentyNineStory;
      case 29:
        return _lessonThirtyStory;
      case 30:
        return _lessonThirtyOneStory;
      case 31:
        return _lessonThirtyTwoStory;
      case 32:
        return _lessonThirtyThreeStory;
      case 33:
        return _lessonThirtyFourStory;
      case 34:
        return _lessonThirtyFiveStory;
      case 35:
        return _lessonThirtySixStory;
      case 36:
        return _lessonThirtySevenStory;
      case 37:
        return _lessonThirtyEightStory;
      case 38:
        return _lessonThirtyNineStory;
      case 39:
        return _lessonFortyStory;
      case 40:
        return _lessonFortyOneStory;
      case 41:
        return _lessonFortyTwoStory;
      case 42:
        return _lessonFortyThreeStory;
      case 43:
        return _lessonFortyFourStory;
      case 44:
        return _lessonFortyFiveStory;
      case 45:
        return _lessonFortySixStory;
      case 46:
        return _lessonFortySevenStory;
      case 47:
        return _lessonFortyEightStory;
      case 48:
        return _lessonFortyNineStory;
      case 49:
        return _lessonFiftyStory;
      case 100:
        return _lessonHundredOneStory;
      case 101:
        return _lessonHundredTwoStory;
      case 102:
        return _lessonHundredThreeStory;
    }
    return null;
  }

  /// Die kurze „Geschichte“ der Stufe 6 ([QuizStage.story]): ein
  /// zusammenhängender arabischer Text, der fast ausschließlich aus den
  /// gelernten Wörtern des aktuellen Batches besteht (mit sehr wenigen
  /// Füllwörtern). Für jede Lektion existiert eine eigens verfasste,
  /// **kompakte** Kurzgeschichte (ca. 10 Sätze aus den zehn Wörtern eben dieser
  /// Lektion) — sie sammelt bewusst NICHT die Sätze aller bisherigen Lektionen
  /// an (die Geschichte wächst nicht mit der Anzahl der gelernten Sätze). Die
  /// passende Geschichte wird anhand des aktuellen [QuizState.batchIndex]
  /// gewählt. Die Sätze werden als Lesetext angezeigt und dienen als Grundlage
  /// der Zuordnungs-Fragen.
  List<Sentence> _buildStory() {
    // Word-IDs, für die Wortobjekte (für die Zuordnungs-Fragen) vorhanden sind.
    final poolIds = state.storyWords.map((w) => w.id).toSet();

    // Eigenständige Kurzgeschichte der aktuellen Lektion (batchIndex 0-basiert),
    // sofern die betroffenen Wörter im Wortschatz-Pool vorhanden sind (in der
    // echten App ist das die aktuelle Lektion; bei künstlichen Test-Konfigurationen
    // ohne passende Wörter fällt die Auswahl auf den ID-/Kontext-Fallback zurück).
    final storyForLesson = _storyForBatch(state.batchIndex);
    if (storyForLesson != null &&
        storyForLesson.every((s) => poolIds.contains(s.wordId))) {
      return storyForLesson;
    }

    // Ohne passende batchIndex-Geschichte: wähle eine Geschichte, deren
    // Wort-IDs vollständig im verfügbaren Wortschatz enthalten sind (deckt
    // ungetrackte Läufe und einfache Testläufe ab).
    final batchIds = state.words.map((w) => w.id).toSet();
    final stories = [
      _lessonOneStory,
      _lessonTwoStory,
      _lessonThreeStory,
      _lessonFourStory,
      _lessonFiveStory,
      _lessonSixStory,
      _lessonSevenStory,
      _lessonEightStory,
      _lessonNineStory,
      _lessonTenStory,
      _lessonElevenStory,
      _lessonTwelveStory,
      _lessonThirteenStory,
      _lessonFourteenStory,
      _lessonFifteenStory,
      _lessonSixteenStory,
      _lessonSeventeenStory,
      _lessonEighteenStory,
      _lessonNineteenStory,
      _lessonTwentyStory,
      _lessonTwentyOneStory,
      _lessonTwentyTwoStory,
      _lessonTwentyThreeStory,
      _lessonTwentyFourStory,
      _lessonTwentyFiveStory,
      _lessonTwentySixStory,
      _lessonTwentySevenStory,
      _lessonTwentyEightStory,
      _lessonTwentyNineStory,
      _lessonThirtyStory,
      _lessonThirtyOneStory,
      _lessonThirtyTwoStory,
      _lessonThirtyThreeStory,
      _lessonThirtyFourStory,
      _lessonThirtyFiveStory,
      _lessonThirtySixStory,
      _lessonThirtySevenStory,
      _lessonThirtyEightStory,
      _lessonThirtyNineStory,
      _lessonFortyStory,
      _lessonFortyOneStory,
      _lessonFortyTwoStory,
      _lessonFortyThreeStory,
      _lessonFortyFourStory,
      _lessonFortyFiveStory,
      _lessonFortySixStory,
      _lessonFortySevenStory,
      _lessonFortyEightStory,
      _lessonFortyNineStory,
      _lessonFiftyStory,
      _lessonHundredOneStory,
      _lessonHundredTwoStory,
      _lessonHundredThreeStory,
    ];
    for (final story in stories) {
      if (story.every((s) => batchIds.contains(s.wordId))) {
        return story;
      }
    }

    // Fallback: zufällige Kontext-Sätze aus dem aktuellen Batch.
    final sentences = state.sentencesByWordId;
    return [
      for (final word in state.words)
        if (sentences[word.id]?.isNotEmpty ?? false)
          sentences[word.id]![_random.nextInt(sentences[word.id]!.length)],
    ];
  }

  /// Eine Zuordnungs-Frage je Satz der Geschichte: der arabische Satz wird
  /// gezeigt, der Nutzer wählt aus 2 ähnlichen deutschen Übersetzungen der
  /// übrigen Geschichten-Sätze die passende Bedeutung (3 Optionen gesamt).
  List<QuizQuestion> _buildStoryQueue(List<Sentence> story) {
    final germanPool = story.map((s) => s.german).toSet().toList();
    // Wortobjekte können aus früheren Lektionen stammen (kumulativ), daher aus
    // dem Wortschatz-Pool statt nur aus dem aktuellen Batch beziehen.
    final wordsById = {for (final w in state.storyWords) w.id: w};

    return story.map((sentence) {
      final word = wordsById[sentence.wordId];
      if (word == null) {
        return null;
      }
      final correct = sentence.german;
      final distractorPool = germanPool
          .where((g) => g != correct)
          .toList()
        ..shuffle(_random);
      final options = <String>{correct, ...distractorPool.take(2)}.toList()
        ..shuffle(_random);

      return QuizQuestion(
        word: word,
        sentence: sentence,
        options: options,
        isStory: true,
      );
    }).whereType<QuizQuestion>().toList();
  }

  QuizDirection _directionFor(QuizStage stage) {
    switch (stage) {
      case QuizStage.arabicToGerman:
        return QuizDirection.arabicToGerman;
      case QuizStage.germanToArabic:
        return QuizDirection.germanToArabic;
      case QuizStage.mixed:
        return _random.nextBool()
            ? QuizDirection.arabicToGerman
            : QuizDirection.germanToArabic;
      case QuizStage.wholeSentence:
        throw StateError(
          'wholeSentence waehlt seine Richtung selbst in _buildWholeSentenceQueue',
        );
      case QuizStage.audio:
        throw StateError('audio hat keine QuizDirection');
      case QuizStage.story:
        throw StateError('story hat keine QuizDirection');
    }
  }

  /// 4 Antwortmöglichkeiten (1 richtige + bis zu 3 Distraktoren aus dem
  /// restlichen Batch), gemischt.
  List<String> _buildOptions(
    Word word,
    QuizDirection direction,
    List<Word> pool,
  ) {
    String fieldOf(Word w) =>
        direction == QuizDirection.arabicToGerman ? w.german : w.arabic;

    final correct = fieldOf(word);
    final distractorPool =
        (pool.where((w) => w.id != word.id).map(fieldOf).toSet()
              ..remove(correct))
            .toList()
          ..shuffle(_random);

    final options = <String>{correct, ...distractorPool.take(3)}.toList()
      ..shuffle(_random);
    return options;
  }
}

final quizProvider = NotifierProvider<QuizNotifier, QuizState>(
  QuizNotifier.new,
);

/// Die zusammenhängende kleine Geschichte für die Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 1 (word_ids 1–10) — **nur** aus dem
/// Wortschatz der Lektion 1 (kumulative Regel: Lektion N nutzt die Wörter der
/// Lektionen 1..N; hier ist der Pool eben nur Lektion 1). Gezeigt wird eine
/// realistische Morgen-Szene: Der Mann schreibt einen Brief, liest, grüßt,
/// führt seinen Tagesablauf und isst am Ende zu Mittag.
///
/// Jeder Satz verwendet genau eines der 10 gelernten Verben und ist mit sehr
/// wenigen Füllwörtern/Nomen ergänzt. Die deutschen Übersetzungen sind bewusst
/// ähnlich strukturiert (alle „Der Mann …“), damit sie als ähnliche
/// Auswahloptionen für die Zuordnungs-Fragen dienen.
const List<Sentence> _lessonOneStory = [
  Sentence(
    wordId: 1,
    arabic: 'كَتَبَ الرَّجُلُ رِسَالَةً.',
    german: 'Der Mann schrieb einen Brief.',
    transliteration: 'kataba ar-raǧulu risālatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 2,
    arabic: 'قَرَأَ الرَّجُلُ الْكِتَابَ.',
    german: 'Der Mann las das Buch.',
    transliteration: 'qaraʾa ar-raǧulu al-kitāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 3,
    arabic: 'قَالَ الرَّجُلُ: أَهْلًا.',
    german: 'Der Mann sagte: Hallo.',
    transliteration: 'qāla ar-raǧulu: ʾahlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 5,
    arabic: 'جَاءَ صَدِيقُهُ بِسُرُورٍ.',
    german: 'Sein Freund kam voller Freude.',
    transliteration: 'ǧāʾa ṣadīquhu bisurūrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 4,
    arabic: 'ذَهَبَ الرَّجُلُ إِلَى الْبَيْتِ.',
    german: 'Der Mann ging nach Hause.',
    transliteration: 'ḏahaba ar-raǧulu ʾilā al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 6,
    arabic: 'عَلِمَ الرَّجُلُ الْخَبَرَ.',
    german: 'Der Mann erfuhr die Nachricht.',
    transliteration: 'ʿalima ar-raǧulu al-ḫabara.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 7,
    arabic: 'فَعَلَ الرَّجُلُ عَمَلًا.',
    german: 'Der Mann tat eine Arbeit.',
    transliteration: 'faʿala ar-raǧulu ʿamalan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 8,
    arabic: 'رَأَى الرَّجُلُ كِتَابًا جَمِيلًا.',
    german: 'Der Mann sah ein schönes Buch.',
    transliteration: 'raʾā ar-raǧulu kitāban ǧamīlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 9,
    arabic: 'سَمِعَ الرَّجُلُ صَوْتًا.',
    german: 'Der Mann hörte ein Geräusch.',
    transliteration: 'samiʿa ar-raǧulu ṣawtan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 10,
    arabic: 'أَكَلَ الرَّجُلُ الطَّعَامَ.',
    german: 'Der Mann aß das Essen.',
    transliteration: 'ʾakala ar-raǧulu aṭ-ṭaʿāma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 2 (word_ids 11–20): eine kompakte, zusammenhängende
/// Erzählung, die hauptsächlich die zehn Wörter dieser Lektion verwendet —
/// sie sammelt NICHT alle Sätze der vorherigen Lektionen an (die Geschichte
/// soll nicht mit der Anzahl der bisher gelernten Sätze mitwachsen).
/// Jeder Satz verwendet genau eines der zehn gelernten Verben; die deutschen
/// Übersetzungen sind bewusst ähnlich strukturiert („Der Mann …“ bzw.
/// „Allah …“), damit sie als ähnliche Auswahloptionen für die
/// Zuordnungs-Fragen dienen. „Allah“ bleibt wie im gesamten Projekt unübersetzt.
final List<Sentence> _lessonTwoStory = [
  Sentence(
    wordId: 11,
    arabic: 'شَرِبَ الرَّجُلُ مِنَ الْمَاءِ الْعَذْبِ.',
    german: 'Der Mann trank von dem frischen Wasser.',
    transliteration: 'šariba ar-raǧulu mina al-māʾi al-ʿaḏbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 12,
    arabic: 'خَلَقَ اللهُ السَّمَاوَاتِ وَالْأَرْضَ.',
    german: 'Allah erschuf die Himmel und die Erde.',
    transliteration: 'ḫalaqa allāhu as-samāwāti wa-l-arḍa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 13,
    arabic: 'عَبَدَ الرَّجُلُ اللهَ وَحْدَهُ.',
    german: 'Der Mann betete Allah allein an.',
    transliteration: 'ʿabada ar-raǧulu allāha waḥdahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 14,
    arabic: 'آمَنَ الرَّجُلُ بِاللهِ وَرَسُولِهِ.',
    german: 'Der Mann glaubte an Allah und seinen Gesandten.',
    transliteration: 'ʾāmana ar-raǧulu bi-allāhi wa-rasūlihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 15,
    arabic: 'كَفَرَ الرَّجُلُ بِنِعْمَةِ اللهِ بَعْدَ الْهُدَى.',
    german: 'Der Mann verleugnete nach der Rechtleitung Allahs Gnade.',
    transliteration: 'kafara ar-raǧulu biniʿmati allāhi baʿda al-hudā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 16,
    arabic: 'رَحِمَ اللهُ عِبَادَهُ الْمُؤْمِنِينَ.',
    german: 'Allah erbarmte sich seiner gläubigen Diener.',
    transliteration: 'raḥima allāhu ʿibādahu al-muʾminīna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 17,
    arabic: 'غَفَرَ اللهُ لِلرَّجُلِ ذَنْبَهُ.',
    german: 'Allah vergab dem Mann seine Sünde.',
    transliteration: 'ġafara allāhu li-r-raǧuli ḏanbahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 18,
    arabic: 'هَدَى اللهُ الرَّجُلَ إِلَى الصِّرَاطِ الْمُسْتَقِيمِ.',
    german: 'Allah leitete den Mann auf den rechten Weg.',
    transliteration: 'hadā allāhu ar-raǧula ilā aṣ-ṣirāṭi al-mustaqīmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 19,
    arabic: 'ضَلَّ الرَّجُلُ عَنِ الطَّرِيقِ الْقَوِيمِ.',
    german: 'Der Mann verirrte sich vom geraden Weg.',
    transliteration: 'ḍalla ar-raǧulu ʿani ṭ-ṭarīqi al-qawīmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 20,
    arabic: 'نَزَلَتِ الرَّحْمَةُ مِنَ السَّمَاءِ.',
    german: 'Die Barmherzigkeit stieg vom Himmel herab.',
    transliteration: 'nazalat ar-raḥmatu mina as-samāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

];
/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 3 (word_ids 21–30): eine kompakte, zusammenhängende
/// Erzählung, die hauptsächlich die zehn Wörter dieser Lektion verwendet —
/// sie sammelt NICHT alle Sätze der vorherigen Lektionen an (die Geschichte
/// soll nicht mit der Anzahl der bisher gelernten Sätze mitwachsen).
/// Jeder Satz verwendet genau eines der zehn gelernten Verben; die deutschen
/// Übersetzungen sind bewusst ähnlich strukturiert („Der Mann …“ bzw.
/// „Allah …“), damit sie als ähnliche Auswahloptionen für die
/// Zuordnungs-Fragen dienen. „Allah“ bleibt wie im gesamten Projekt unübersetzt.
final List<Sentence> _lessonThreeStory = [
  Sentence(
    wordId: 23,
    arabic: 'خَرَجَ الرَّجُلُ مِنَ الْغُرْفَةِ.',
    german: 'Der Mann verließ das Zimmer.',
    transliteration: 'ḫaraǧa ar-raǧulu mina al-ġurfati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 26,
    arabic: 'مَشَى الرَّجُلُ إِلَى السُّوقِ.',
    german: 'Der Mann ging zum Markt.',
    transliteration: 'mašā ar-raǧulu ʾilā as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 22,
    arabic: 'دَخَلَ الرَّجُلُ السُّوقَ.',
    german: 'Der Mann betrat den Markt.',
    transliteration: 'daḫala ar-raǧulu as-sūqa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 27,
    arabic: 'وَجَدَ الرَّجُلُ صَدِيقَهُ فِي السُّوقِ.',
    german: 'Der Mann fand seinen Freund auf dem Markt.',
    transliteration: 'waǧada ar-raǧulu ṣadīqahu fī as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 24,
    arabic: 'جَلَسَ الرَّجُلُ مَعَ صَدِيقِهِ.',
    german: 'Der Mann setzte sich zu seinem Freund.',
    transliteration: 'ǧalasa ar-raǧulu maʿa ṣadīqihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 29,
    arabic: 'سَأَلَ الرَّجُلُ صَدِيقَهُ سُؤَالًا.',
    german: 'Der Mann stellte seinem Freund eine Frage.',
    transliteration: 'saʾala ar-raǧulu ṣadīqahu suʾālan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 30,
    arabic: 'أَجَابَ صَدِيقُهُ بِسُرُورٍ.',
    german: 'Sein Freund antwortete voller Freude.',
    transliteration: 'ʾaǧāba ṣadīquhu bisurūrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 28,
    arabic: 'طَلَبَ الرَّجُلُ الْمُسَاعَدَةَ.',
    german: 'Der Mann verlangte Hilfe.',
    transliteration: 'ṭalaba ar-raǧulu al-musāʿadata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 21,
    arabic: 'صَعِدَ الرَّجُلُ إِلَى السَّطْحِ.',
    german: 'Der Mann stieg aufs Dach.',
    transliteration: 'ṣaʿida ar-raǧulu ʾilā as-saṭḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 25,
    arabic: 'قَامَ الرَّجُلُ وَقْتَ الصَّلَاةِ.',
    german: 'Der Mann stand zur Gebetszeit auf.',
    transliteration: 'qāma ar-raǧulu waqta aṣ-ṣalāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

];
/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 4 (word_ids 31–40): eine kompakte, zusammenhängende
/// Erzählung, die hauptsächlich die zehn Wörter dieser Lektion verwendet —
/// sie sammelt NICHT alle Sätze der vorherigen Lektionen an (die Geschichte
/// soll nicht mit der Anzahl der bisher gelernten Sätze mitwachsen).
/// Jeder Satz verwendet genau eines der zehn gelernten Verben; die deutschen
/// Übersetzungen sind bewusst ähnlich strukturiert („Der Mann …“ bzw.
/// „Allah …“), damit sie als ähnliche Auswahloptionen für die
/// Zuordnungs-Fragen dienen. „Allah“ bleibt wie im gesamten Projekt unübersetzt.
final List<Sentence> _lessonFourStory = [
  Sentence(
    wordId: 31,
    arabic: 'فَهِمَ الرَّجُلُ حِكْمَةَ الْيَوْمِ.',
    german: 'Der Mann verstand die Weisheit des Tages.',
    transliteration: 'fahima ar-raǧulu ḥikmata al-yawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 32,
    arabic: 'ظَنَّ الرَّجُلُ خَيْرًا.',
    german: 'Der Mann vermutete Gutes.',
    transliteration: 'ẓanna ar-raǧulu ḫayran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 33,
    arabic: 'حَسِبَ الرَّجُلُ أَنَّهُ مُخْطِئٌ.',
    german: 'Der Mann meinte, dass er sich geirrt habe.',
    transliteration: 'ḥasiba ar-raǧulu ʾannahu muḫṭiʾun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 34,
    arabic: 'أَرَادَ الرَّجُلُ شُكْرَ رَبِّهِ.',
    german: 'Der Mann wollte seinem Herrn danken.',
    transliteration: 'ʾarāda ar-raǧulu šukra rabbihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 35,
    arabic: 'اسْتَطَاعَ الرَّجُلُ تَنْفِيذَ الْعَمَلِ.',
    german: 'Der Mann konnte die Arbeit ausführen.',
    transliteration: 'istaṭāʿa ar-raǧulu tanfīḏa al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 36,
    arabic: 'حَبَّ الرَّجُلُ أُمَّهُ كَثِيرًا.',
    german: 'Der Mann liebte seine Mutter sehr.',
    transliteration: 'ḥabba ar-raǧulu ʾummahu kaṯīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 37,
    arabic: 'كَرِهَ الرَّجُلُ الْكَذِبَ.',
    german: 'Der Mann hasste die Lüge.',
    transliteration: 'kariha ar-raǧulu al-kaḏiba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 38,
    arabic: 'خَافَ الرَّجُلُ مِنَ الْفَقْرِ.',
    german: 'Der Mann fürchtete die Armut.',
    transliteration: 'ḫāfa ar-raǧulu mina al-faqri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 39,
    arabic: 'أَمِنَ الرَّجُلُ فِي بَيْتِهِ.',
    german: 'Der Mann fühlte sich in seinem Haus sicher.',
    transliteration: 'ʾamina ar-raǧulu fī baytihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 40,
    arabic: 'صَبَرَ الرَّجُلُ عَلَى الشِّدَّةِ.',
    german: 'Der Mann war angesichts der Not geduldig.',
    transliteration: 'ṣabara ar-raǧulu ʿalā aš-šiddati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

];
/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 5 (word_ids 41–50): eine kompakte, zusammenhängende
/// Erzählung, die hauptsächlich die zehn Wörter dieser Lektion verwendet —
/// sie sammelt NICHT alle Sätze der vorherigen Lektionen an (die Geschichte
/// soll nicht mit der Anzahl der bisher gelernten Sätze mitwachsen).
/// Jeder Satz verwendet genau eines der zehn gelernten Verben; die deutschen
/// Übersetzungen sind bewusst ähnlich strukturiert („Der Mann …“ bzw.
/// „Allah …“), damit sie als ähnliche Auswahloptionen für die
/// Zuordnungs-Fragen dienen. „Allah“ bleibt wie im gesamten Projekt unübersetzt.
final List<Sentence> _lessonFiveStory = [
  Sentence(
    wordId: 47,
    arabic: 'وَلَدَتِ الْمَرْأَةُ وَلَدًا جَمِيلًا.',
    german: 'Die Frau gebar einen schönen Jungen.',
    transliteration: 'waladat al-marʾatu waladan ǧamīlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 45,
    arabic: 'عَاشَ الرَّجُلُ سَنَوَاتٍ طَوِيلَةً فِي السَّلَامِ.',
    german: 'Der Mann lebte lange Jahre in Frieden.',
    transliteration: 'ʿāša ar-raǧulu sanawātin ṭawīlatin fī as-salāmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 42,
    arabic: 'عَمِلَ الرَّجُلُ بِاجْتِهَادٍ فِي حَقْلِهِ.',
    german: 'Der Mann arbeitete fleißig auf seinem Feld.',
    transliteration: 'ʿamila ar-raǧulu bi-ǧtihādin fī ḥaqlihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 43,
    arabic: 'بَنَى الرَّجُلُ بَيْتًا لِأُسْرَتِهِ.',
    german: 'Der Mann baute ein Haus für seine Familie.',
    transliteration: 'banā ar-raǧulu baytan li-ʾusratihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 41,
    arabic: 'شَكَرَ الرَّجُلُ رَبَّهُ عَلَى كُلِّ خَيْرٍ.',
    german: 'Der Mann dankte seinem Herrn für alles Gute.',
    transliteration: 'šakara ar-raǧulu rabbahu ʿalā kulli ḫayrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 48,
    arabic: 'نَصَرَ الرَّجُلُ صَدِيقَهُ فِي الشِّدَّةِ.',
    german: 'Der Mann half seinem Freund in der Not.',
    transliteration: 'naṣara ar-raǧulu ṣadīqahu fī aš-šiddati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 49,
    arabic: 'حَكَمَ الرَّجُلُ بَيْنَ النَّاسِ بِالْحَقِّ.',
    german: 'Der Mann urteilte zwischen den Menschen mit Wahrheit.',
    transliteration: 'ḥakama ar-raǧulu bayna an-nāsi bi-l-ḥaqqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 50,
    arabic: 'عَدَلَ الرَّجُلُ فِي حُكْمِهِ بَيْنَ الْقَوْمِ.',
    german: 'Der Mann war gerecht in seinem Urteil unter den Leuten.',
    transliteration: 'ʿadala ar-raǧulu fī ḥukmihi bayna al-qawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 46,
    arabic: 'مَاتَ الرَّجُلُ بَعْدَ حَيَاةٍ مُبَارَكَةٍ.',
    german: 'Der Mann starb nach einem gesegneten Leben.',
    transliteration: 'māta ar-raǧulu baʿda ḥayātin mubārakatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 44,
    arabic: 'هَلَكَ الظَّالِمُ بِسَبَبِ ظُلْمِهِ.',
    german: 'Der Ungerechte ging durch sein Unrecht zugrunde.',
    transliteration: 'halaka aẓ-ẓālimu bisababi ẓulmihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

];
/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 6 (word_ids 51–60): eine kompakte, zusammenhängende
/// Erzählung, die hauptsächlich die zehn Wörter dieser Lektion verwendet —
/// sie sammelt NICHT alle Sätze der vorherigen Lektionen an (die Geschichte
/// soll nicht mit der Anzahl der bisher gelernten Sätze mitwachsen).
/// Jeder Satz verwendet genau eines der zehn gelernten Verben; die deutschen
/// Übersetzungen sind bewusst ähnlich strukturiert („Der Mann …“ bzw.
/// „Allah …“), damit sie als ähnliche Auswahloptionen für die
/// Zuordnungs-Fragen dienen. „Allah“ bleibt wie im gesamten Projekt unübersetzt.
final List<Sentence> _lessonSixStory = [
  Sentence(
    wordId: 51,
    arabic: 'ذَكَرَ الرَّجُلُ اسْمَ صَدِيقِهِ.',
    german: 'Der Mann erwähnte den Namen seines Freundes.',
    transliteration: 'ḏakara ar-raǧulu sma ṣadīqihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 58,
    arabic: 'أَخَذَ الرَّجُلُ الْمِفْتَاحَ.',
    german: 'Der Mann nahm den Schlüssel.',
    transliteration: 'ʾaḫaḏa ar-raǧulu al-miftāḥa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 53,
    arabic: 'فَتَحَ الرَّجُلُ الْبَابَ.',
    german: 'Der Mann öffnete die Tür.',
    transliteration: 'fataḥa ar-raǧulu al-bāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 52,
    arabic: 'نَظَرَ الرَّجُلُ إِلَى السُّوقِ.',
    german: 'Der Mann betrachtete den Markt.',
    transliteration: 'naẓara ar-raǧulu ʾilā as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 56,
    arabic: 'حَمَلَ الرَّجُلُ الْحَقِيبَةَ.',
    german: 'Der Mann trug die Tasche.',
    transliteration: 'ḥamala ar-raǧulu al-ḥaqībata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 60,
    arabic: 'بَاعَ الرَّجُلُ بَضَاعَتَهُ.',
    german: 'Der Mann verkaufte seine Waren.',
    transliteration: 'bāʿa ar-raǧulu baḍāʿatahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 59,
    arabic: 'أَعْطَى الرَّجُلُ الْفَقِيرَ طَعَامًا.',
    german: 'Der Mann gab dem Armen Essen.',
    transliteration: 'ʾaʿṭā ar-raǧulu al-faqīra ṭaʿāman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 55,
    arabic: 'كَسَرَ الْوَلَدُ الزُّجَاجَ.',
    german: 'Der Junge brach das Glas.',
    transliteration: 'kasara al-waladu az-zuǧāǧa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 57,
    arabic: 'رَمَى الرَّجُلُ الزُّجَاجَ الْمَكْسُورَ.',
    german: 'Der Mann warf das zerbrochene Glas weg.',
    transliteration: 'ramā ar-raǧulu az-zuǧāǧa al-maksūra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 54,
    arabic: 'غَلَقَ الرَّجُلُ الْبَابَ.',
    german: 'Der Mann schloss die Tür.',
    transliteration: 'ġalaqa ar-raǧulu al-bāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

];

/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 7 (word_ids 61–70): eine kompakte,
/// zusammenhängende Erzählung, die hauptsächlich die zehn Wörter dieser
/// Lektion verwendet (kaufen/schlagen/töten/bewahren – auswendig lernen/
/// vergessen/verbergen/anziehen/schlafen/aufwachen/lachen). Sie sammelt
/// bewusst NICHT die Sätze früherer Lektionen an (die Geschichte wächst
/// nicht mit der Anzahl der gelernten Sätze). Jeder Satz verwendet genau
/// eines der zehn gelernten Wörter; die deutschen Übersetzungen sind
/// bewusst ähnlich strukturiert („Der Mann …“), damit sie als ähnliche
/// Auswahloptionen für die Zuordnungs-Fragen dienen.
final List<Sentence> _lessonSevenStory = [
  Sentence(
    wordId: 69,
    arabic: 'اسْتَيْقَظَ الرَّجُلُ بَاكِرًا.',
    german: 'Der Mann wachte früh auf.',
    transliteration: 'istayqaẓa ar-raǧulu bākiran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 67,
    arabic: 'لَبِسَ الرَّجُلُ ثَوْبَهُ.',
    german: 'Der Mann zog sein Gewand an.',
    transliteration: 'labisa ar-raǧulu ṯawbahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 61,
    arabic: 'اشْتَرَى الرَّجُلُ خُبْزًا مِنَ السُّوقِ.',
    german: 'Der Mann kaufte Brot auf dem Markt.',
    transliteration: 'ištarā ar-raǧulu ḫubzan mina as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 62,
    arabic: 'ضَرَبَ اللِّصُّ الرَّجُلَ.',
    german: 'Ein Dieb schlug den Mann.',
    transliteration: 'ḍaraba al-liṣṣu ar-raǧula.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 70,
    arabic: 'ضَحِكَ الرَّجُلُ ضَحِكًا.',
    german: 'Der Mann lachte laut.',
    transliteration: 'ḍaḥika ar-raǧulu ḍaḥikan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 65,
    arabic: 'نَسِيَ الرَّجُلُ مَالَهُ.',
    german: 'Der Mann vergaß sein Geld.',
    transliteration: 'nasiya ar-raǧulu mālahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 64,
    arabic: 'حَفِظَ الرَّجُلُ بَضَائِعَهُ.',
    german: 'Der Mann bewahrte seine Waren.',
    transliteration: 'ḥafiẓa ar-raǧulu baḍāʾiʿahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 66,
    arabic: 'كَتَمَ الرَّجُلُ الْخَوْفَ.',
    german: 'Der Mann verbarg die Furcht.',
    transliteration: 'katama ar-raǧulu al-ḫawfa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 68,
    arabic: 'نَامَ الرَّجُلُ فِي الْمَسَاءِ.',
    german: 'Am Abend schlief der Mann.',
    transliteration: 'nāma ar-raǧulu fī al-masāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 63,
    arabic: 'قَتَلَ الصَّيَّادُ الذِّئْبَ.',
    german: 'Der Jäger tötete den Wolf.',
    transliteration: 'qatala aṣ-ṣayyādu aḏ-ḏiʾba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

];

/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 8 (word_ids 71–80): eine kompakte,
/// zusammenhängende Erzählung, die hauptsächlich die zehn Wörter dieser
/// Lektion verwendet (weinen/spielen/unterrichten/zurückkehren/verlassen/
/// beginnen/enden/siegen/verlieren/treffen). Sie sammelt bewusst NICHT die
/// Sätze früherer Lektionen an (die Geschichte wächst nicht mit der Anzahl
/// der gelernten Sätze). Jeder Satz verwendet genau eines der zehn gelernten
/// Wörter; die deutschen Übersetzungen sind bewusst ähnlich strukturiert
/// („Der Mann …“), damit sie als ähnliche Auswahloptionen für die
/// Zuordnungs-Fragen dienen.
final List<Sentence> _lessonEightStory = [
  Sentence(
    wordId: 75,
    arabic: 'تَرَكَ الرَّجُلُ بَيْتَهُ فِي الصَّبَاحِ.',
    german: 'Der Mann verließ sein Haus am Morgen.',
    transliteration: 'taraka ar-raǧulu baytahu fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 76,
    arabic: 'بَدَأَ الرَّجُلُ عَمَلَهُ الْجَدِيدَ.',
    german: 'Der Mann begann seine neue Arbeit.',
    transliteration: 'badaʾa ar-raǧulu ʿamalahu al-ǧadīda.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 73,
    arabic: 'دَرَّسَ الرَّجُلُ الطُّلَّابَ.',
    german: 'Der Mann unterrichtete die Schüler.',
    transliteration: 'darrasa ar-raǧulu aṭ-ṭullāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 72,
    arabic: 'لَعِبَ الْوَلَدُ مَعَ أَصْدِقَائِهِ.',
    german: 'Der Junge spielte mit seinen Freunden.',
    transliteration: 'laʿiba al-waladu maʿa aṣdiqāʾihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 71,
    arabic: 'بَكَى الْوَلَدُ لِأَنَّهُ خَسِرَ.',
    german: 'Der Junge weinte, weil er verlor.',
    transliteration: 'bakā al-waladu liʾannahu ḫasira.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 79,
    arabic: 'خَسِرَ الرَّجُلُ الْمُنَافَسَةَ.',
    german: 'Der Mann verlor den Wettbewerb.',
    transliteration: 'ḫasira ar-raǧulu al-munāfasata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 78,
    arabic: 'فَازَ صَدِيقُهُ بِالْجَائِزَةِ.',
    german: 'Sein Freund gewann den Preis.',
    transliteration: 'fāza ṣadīquhu bil-ǧāʾizati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 80,
    arabic: 'لَقِيَ الرَّجُلُ صَدِيقَهُ فِي السُّوقِ.',
    german: 'Der Mann traf seinen Freund auf dem Markt.',
    transliteration: 'laqiya ar-raǧulu ṣadīqahu fī as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 77,
    arabic: 'انْتَهَى الْيَوْمُ بِسُرُورٍ.',
    german: 'Der Tag endete voller Freude.',
    transliteration: 'intahā al-yawmu bisurūrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 74,
    arabic: 'رَجَعَ الرَّجُلُ إِلَى بَيْتِهِ.',
    german: 'Der Mann kehrte zu seinem Haus zurück.',
    transliteration: 'raǧaʿa ar-raǧulu ʾilā baytihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 9 (word_ids 81–90): eine kompakte,
/// zusammenhängende Erzählung, die hauptsächlich die zehn Wörter dieser
/// Lektion verwendet (kennen/erkennen, brauchen, besitzen/herrschen, zornig
/// sein, zufrieden sein, kämpfen/sich anstrengen, herstellen, pflanzen,
/// ernten, kochen). Sie sammelt bewusst NICHT die Sätze früherer Lektionen an
/// (die Geschichte wächst nicht mit der Anzahl der gelernten Sätze). Jeder
/// Satz verwendet genau eines der zehn gelernten Wörter; die deutschen
/// Übersetzungen sind bewusst ähnlich strukturiert („Der Bauer …“), damit sie
/// als ähnliche Auswahloptionen für die Zuordnungs-Fragen dienen.
final List<Sentence> _lessonNineStory = [
  Sentence(
    wordId: 81,
    arabic: 'عَرَفَ الْفَلَّاحُ أَرْضَهُ جَيِّدًا.',
    german: 'Der Bauer kannte sein Land gut.',
    transliteration: 'ʿarafa al-fallāḥu arḍahu ǧayyidan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 83,
    arabic: 'مَلَكَ الْفَلَّاحُ حَقْلًا وَاسِعًا.',
    german: 'Der Bauer besaß ein weites Feld.',
    transliteration: 'malaka al-fallāḥu ḥaqlan wāsiʿan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 82,
    arabic: 'احْتَاجَ الْفَلَّاحُ إِلَى الْمَاءِ.',
    german: 'Der Bauer brauchte Wasser.',
    transliteration: 'iḥtāǧa al-fallāḥu ʾilā al-māʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 84,
    arabic: 'غَضِبَ الْفَلَّاحُ مِنَ الْجَفَافِ.',
    german: 'Der Bauer wurde über die Dürre zornig.',
    transliteration: 'ġaḍiba al-fallāḥu mina al-ǧafāfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 85,
    arabic: 'رَضِيَ الْفَلَّاحُ عِنْدَمَا جَاءَ الْمَطَرُ.',
    german: 'Der Bauer war zufrieden, als der Regen kam.',
    transliteration: 'raḍiya al-fallāḥu ʿindamā ǧāʾa al-maṭaru.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 86,
    arabic: 'جَاهَدَ الْفَلَّاحُ فِي عَمَلِهِ.',
    german: 'Der Bauer gab sich in seiner Arbeit Mühe.',
    transliteration: 'ǧāhada al-fallāḥu fī ʿamalihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 88,
    arabic: 'زَرَعَ الْفَلَّاحُ الْبُذُورَ.',
    german: 'Der Bauer pflanzte die Samen.',
    transliteration: 'zaraʿa al-fallāḥu al-buḏūra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 89,
    arabic: 'حَصَدَ الْفَلَّاحُ الْقَمْحَ.',
    german: 'Der Bauer erntete den Weizen.',
    transliteration: 'ḥaṣada al-fallāḥu al-qamḥa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 87,
    arabic: 'صَنَعَ الْفَلَّاحُ خُبْزًا مِنَ الْقَمْحِ.',
    german: 'Der Bauer machte Brot aus dem Weizen.',
    transliteration: 'ṣanaʿa al-fallāḥu ḫubzan mina al-qamḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),

  Sentence(
    wordId: 90,
    arabic: 'طَبَخَ الْفَلَّاحُ طَعَامًا لِأُسْرَتِهِ.',
    german: 'Der Bauer kochte Essen für seine Familie.',
    transliteration: 'ṭabaḫa al-fallāḥu ṭaʿāman liʾusratihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];
// Kurzgeschichte Lektion 10 (word_ids 91-100) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonTenStory = [
  Sentence(
    wordId: 91,
    arabic: 'غَسَلَ الرَّجُلُ سَيَّارَتَهُ.',
    german: 'Der Mann wusch sein Auto.',
    transliteration: 'Ġasala ar-raǧulu sayyāratahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 92,
    arabic: 'لَبِثَ الرَّجُلُ فِي الْمَدِينَةِ سَنَةً.',
    german: 'Der Mann verweilte ein Jahr in der Stadt.',
    transliteration: 'Labiṯa ar-raǧulu fī al-madīnati sanatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 93,
    arabic: 'سَافَرَ الرَّجُلُ إِلَى مِصْرَ.',
    german: 'Der Mann reiste nach Ägypten.',
    transliteration: 'Sāfara ar-raǧulu ilā miṣra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 94,
    arabic: 'رَجَا الرَّجُلُ رَحْمَةَ اللَّهِ.',
    german: 'Der Mann erhoffte Allahs Erbarmen.',
    transliteration: 'Raǧā ar-raǧulu raḥmata Allāhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 95,
    arabic: 'طَارَ الطَّائِرُ إِلَى السَّمَاءِ.',
    german: 'Der Vogel flog zum Himmel.',
    transliteration: 'Ṭāra aṭ-ṭāʾiru ilā as-samāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 96,
    arabic: 'سَبَحَ الْوَلَدُ فِي النَّهْرِ.',
    german: 'Der Junge schwamm im Fluss.',
    transliteration: 'Sabaḥa al-waladu fī an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 97,
    arabic: 'جَرَى الْمَاءُ فِي النَّهْرِ.',
    german: 'Das Wasser floss im Fluss.',
    transliteration: 'Ǧarā al-māʾu fī an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 98,
    arabic: 'أَحْرَقَ الرَّجُلُ الْأَوْرَاقَ.',
    german: 'Der Mann verbrannte die Papiere.',
    transliteration: 'ʾAḥraqa ar-raǧulu al-awrāqa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 99,
    arabic: 'قَطَعَ الرَّجُلُ الْحَبْلَ.',
    german: 'Der Mann schnitt das Seil durch.',
    transliteration: 'Qaṭaʿa ar-raǧulu al-ḥabla.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 100,
    arabic: 'صَلَحَ حَالُ الرَّجُلِ بَعْدَ السَّفَرِ.',
    german: 'Der Zustand des Mannes besserte sich nach der Reise.',
    transliteration: 'Ṣalaḥa ḥālu ar-raǧuli baʿda as-safari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 11 (word_ids 101-110) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonElevenStory = [
  Sentence(
    wordId: 101,
    arabic: 'دَخَلَ رَجُلٌ الْبَيْتَ.',
    german: 'Ein Mann betrat das Haus.',
    transliteration: 'Daḫala raǧulun al-bayta.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 102,
    arabic: 'دَخَلَتِ امْرَأَةٌ الْمَدْرَسَةَ.',
    german: 'Eine Frau betrat die Schule.',
    transliteration: 'Daḫalati imraʾatun al-madrasata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 103,
    arabic: 'اشْتَرَى الرَّجُلُ بَيْتًا صَغِيرًا.',
    german: 'Der Mann kaufte ein kleines Haus.',
    transliteration: 'Ištarā ar-raǧulu baytan ṣaġīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 104,
    arabic: 'شَرِبَ الْوَلَدُ مَاءً بَارِدًا.',
    german: 'Der Junge trank kaltes Wasser.',
    transliteration: 'Šariba al-waladu māʾan bāridan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 105,
    arabic: 'جَاءَ يَوْمٌ جَدِيدٌ.',
    german: 'Ein neuer Tag kam.',
    transliteration: 'Ǧāʾa yawmun ǧadīdun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 106,
    arabic: 'قَلْبُ الرَّجُلِ طَيِّبٌ.',
    german: 'Das Herz des Mannes ist gut.',
    transliteration: 'Qalbu ar-raǧuli ṭayyibun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 107,
    arabic: 'عَيْنُ الْوَلَدِ زَرْقَاءُ.',
    german: 'Das Auge des Jungen ist blau.',
    transliteration: 'ʿAynu al-waladi zarqāʾu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 108,
    arabic: 'سَبَحَ الْوَلَدُ فِي الْبَحْرِ.',
    german: 'Der Junge schwamm im Meer.',
    transliteration: 'Sabaḥa al-waladu fī al-baḥri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 109,
    arabic: 'نَزَلَ الثَّلْجُ عَلَى الْجَبَلِ.',
    german: 'Der Schnee fiel auf den Berg.',
    transliteration: 'Nazala aṯ-ṯalǧu ʿalā al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 110,
    arabic: 'طَلَعَتِ الشَّمْسُ صَبَاحًا.',
    german: 'Die Sonne ging morgens auf.',
    transliteration: 'Ṭalaʿati aš-šamsu ṣabāḥan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 12 (word_ids 111-120) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonTwelveStory = [
  Sentence(
    wordId: 111,
    arabic: 'طَلَعَ الْقَمَرُ لَيْلًا.',
    german: 'Der Mond ging nachts auf.',
    transliteration: 'Ṭalaʿa al-qamaru laylan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 112,
    arabic: 'جَاءَ اللَّيْلُ بَعْدَ النَّهَارِ.',
    german: 'Die Nacht kam nach dem Tag.',
    transliteration: 'Ǧāʾa al-laylu baʿda an-nahāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 113,
    arabic: 'عَمِلَ الرَّجُلُ طَوَالَ النَّهَارِ.',
    german: 'Der Mann arbeitete den ganzen Tag.',
    transliteration: 'ʿAmila ar-raǧulu ṭawāla an-nahāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 114,
    arabic: 'سَافَرْنَا إِلَى مَدِينَةٍ كَبِيرَةٍ.',
    german: 'Wir reisten in eine große Stadt.',
    transliteration: 'Sāfarnā ilā madīnatin kabīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 115,
    arabic: 'مَشَى الرَّجُلُ فِي الطَّرِيقِ.',
    german: 'Der Mann ging auf dem Weg.',
    transliteration: 'Mašā ar-raǧulu fī aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 116,
    arabic: 'غَلَقَتِ الْمَرْأَةُ الْبَابَ بِقُوَّةٍ.',
    german: 'Die Frau schloss die Tür kräftig.',
    transliteration: 'Ġalaqati al-marʾatu al-bāba biqūwatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 117,
    arabic: 'الرَّبُّ رَحِيمٌ بِعِبَادِهِ.',
    german: 'Der Herr ist barmherzig zu Seinen Dienern.',
    transliteration: 'Ar-rabbu raḥīmun biʿibādihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 118,
    arabic: 'كَتَبَ الرَّجُلُ كَلِمَةً عَلَى الْوَرَقَةِ.',
    german: 'Der Mann schrieb ein Wort auf das Blatt.',
    transliteration: 'Kataba ar-raǧulu kalimatan ʿalā al-waraqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 119,
    arabic: 'عَرَفْنَا الْحَقَّ مِنَ الْبَاطِلِ.',
    german: 'Wir erkannten die Wahrheit vom Falschen.',
    transliteration: 'ʿArafnā al-ḥaqqa mina al-bāṭili.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 120,
    arabic: 'اشْتَعَلَتِ النَّارُ فِي الْغَابَةِ.',
    german: 'Das Feuer entzündete sich im Wald.',
    transliteration: 'Ištaʿalati an-nāru fī al-ġābati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 13 (word_ids 121-130) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonThirteenStory = [
  Sentence(
    wordId: 121,
    arabic: 'مَلَكَ الرَّجُلُ مَالًا كَثِيرًا.',
    german: 'Der Mann besaß viel Geld.',
    transliteration: 'Malaka ar-raǧulu mālan kaṯīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 122,
    arabic: 'لَيْسَ عِنْدَنَا وَقْتٌ.',
    german: 'Wir haben keine Zeit.',
    transliteration: 'Laysa ʿindanā waqtun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 123,
    arabic: 'حَمَلَتِ الطَّالِبَةُ كِتَابًا ثَقِيلًا.',
    german: 'Die Studentin trug ein schweres Buch.',
    transliteration: 'Ḥamalati aṭ-ṭālibatu kitāban ṯaqīlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 124,
    arabic: 'كَانَ الْمَلِكُ عَادِلًا.',
    german: 'Der König war gerecht.',
    transliteration: 'Kāna al-maliku ʿādilan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 125,
    arabic: 'نَشَرَ الْعَالِمُ الْعِلْمَ.',
    german: 'Der Gelehrte verbreitete das Wissen.',
    transliteration: 'Našara al-ʿālimu al-ʿilma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 126,
    arabic: 'مَنَعَ الْأَبُ وَلَدَهُ مِنَ اللَّعِبِ.',
    german: 'Der Vater hinderte seinen Sohn am Spielen.',
    transliteration: 'Manaʿa al-abu waladahu mina al-laʿibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 127,
    arabic: 'أَمَرَ الْمَلِكُ الْجُنُودَ بِالسَّفَرِ.',
    german: 'Der König befahl den Soldaten zu reisen.',
    transliteration: 'Amara al-maliku al-ǧunūda bis-safari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 128,
    arabic: 'وَعَدَ الرَّجُلُ صَدِيقَهُ بِالْمُسَاعَدَةِ.',
    german: 'Der Mann versprach seinem Freund Hilfe.',
    transliteration: 'Waʿada ar-raǧulu ṣadīqahu bil-musāʿadati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 129,
    arabic: 'دَعَا الرَّجُلُ اللَّهَ بِالشِّفَاءِ.',
    german: 'Der Mann bat Allah um Heilung.',
    transliteration: 'Daʿā ar-raǧulu Allāha biš-šifāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 130,
    arabic: 'شَهِدَ الرَّجُلُ بِالْحَقِّ.',
    german: 'Der Mann bezeugte die Wahrheit.',
    transliteration: 'Šahida ar-raǧulu bil-ḥaqqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 14 (word_ids 131-140) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonFourteenStory = [
  Sentence(
    wordId: 131,
    arabic: 'كَذَبَ الْوَلَدُ عَلَى وَالِدِهِ.',
    german: 'Der Junge log seinen Vater an.',
    transliteration: 'Kaḏaba al-waladu ʿalā wālidihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 132,
    arabic: 'صَدَقَ الرَّجُلُ فِي وَعْدِهِ.',
    german: 'Der Mann war wahrhaftig in seinem Versprechen.',
    transliteration: 'Ṣadaqa ar-raǧulu fī waʿdihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 133,
    arabic: 'حَرَسَ الْجُنْدِيُّ الْبَابَ.',
    german: 'Der Soldat bewachte die Tür.',
    transliteration: 'Ḥarasa al-ǧundiyyu al-bāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 134,
    arabic: 'جَمَعَ الرَّجُلُ الْكُتُبَ.',
    german: 'Der Mann sammelte die Bücher.',
    transliteration: 'Ǧamaʿa ar-raǧulu al-kutuba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 135,
    arabic: 'فَرَقَ الرَّجُلُ بَيْنَ الصَّحِيحِ وَالْخَطَإِ.',
    german: 'Der Mann unterschied zwischen richtig und falsch.',
    transliteration: 'Faraqa ar-raǧulu bayna aṣ-ṣaḥīḥi wal-ḫaṭaʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 136,
    arabic: 'لَمَعَ الْبَرْقُ فِي السَّمَاءِ.',
    german: 'Der Blitz blitzte am Himmel.',
    transliteration: 'Lamaʿa al-barqu fī as-samāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 137,
    arabic: 'خَلَقَ اللَّهُ الْأَرْضَ.',
    german: 'Allah erschuf die Erde.',
    transliteration: 'Ḫalaqa Allāhu al-arḍa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 138,
    arabic: 'عَرَفَ الرَّجُلُ نَفْسَهُ.',
    german: 'Der Mann kannte sich selbst.',
    transliteration: 'ʿArafa ar-raǧulu nafsahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 139,
    arabic: 'حَمَلَ الرَّجُلُ الْكِتَابَ بِيَدِهِ.',
    german: 'Der Mann trug das Buch in seiner Hand.',
    transliteration: 'Ḥamala ar-raǧulu al-kitāba biyadihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 140,
    arabic: 'غَسَلَ الرَّجُلُ وَجْهَهُ.',
    german: 'Der Mann wusch sein Gesicht.',
    transliteration: 'Ġasala ar-raǧulu waǧhahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 15 (word_ids 141-150) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonFifteenStory = [
  Sentence(
    wordId: 141,
    arabic: 'رَفَعَ الرَّجُلُ رَأْسَهُ.',
    german: 'Der Mann hob seinen Kopf.',
    transliteration: 'Rafaʿa ar-raǧulu raʾsahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 142,
    arabic: 'دَخَلَ الْمُؤْمِنُ الْجَنَّةَ.',
    german: 'Der Gläubige betrat das Paradies.',
    transliteration: 'Daḫala al-muʾminu al-ǧannata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 143,
    arabic: 'هَذَا الدِّينُ سَهْلٌ.',
    german: 'Diese Religion ist einfach.',
    transliteration: 'Hāḏā ad-dīnu sahlun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 144,
    arabic: 'سَافَرَ الرَّجُلُ شَهْرًا كَامِلًا.',
    german: 'Der Mann reiste einen ganzen Monat.',
    transliteration: 'Sāfara ar-raǧulu šahran kāmilan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 145,
    arabic: 'مَرَّتْ سَنَةٌ مُنْذُ سَفَرِنَا.',
    german: 'Ein Jahr ist seit unserer Reise vergangen.',
    transliteration: 'Marrat sanatun munḏu safarinā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 146,
    arabic: 'شَرِبْنَا مِنَ الْمَاءِ الْبَارِدِ.',
    german: 'Wir tranken von dem kalten Wasser.',
    transliteration: 'Šaribnā mina al-māʾi al-bāridi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 147,
    arabic: 'جَلَسَ الرَّجُلُ فِي الْبَيْتِ.',
    german: 'Der Mann saß im Haus.',
    transliteration: 'Ǧalasa ar-raǧulu fī al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 148,
    arabic: 'وَضَعْنَا الْكِتَابَ عَلَى الطَّاوِلَةِ.',
    german: 'Wir legten das Buch auf den Tisch.',
    transliteration: 'Waḍaʿnā al-kitāba ʿalā aṭ-ṭāwilati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 149,
    arabic: 'نَظَرَتِ الْمَرْأَةُ إِلَى الْقَمَرِ.',
    german: 'Die Frau schaute zum Mond.',
    transliteration: 'Naẓarati al-marʾatu ilā al-qamari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 150,
    arabic: 'تَحَدَّثَ الرَّجُلُ عَنْ رِحْلَتِهِ.',
    german: 'Der Mann erzählte über seine Reise.',
    transliteration: 'Taḥaddaṯa ar-raǧulu ʿan riḥlatihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 16 (word_ids 151-160) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonSixteenStory = [
  Sentence(
    wordId: 151,
    arabic: 'لَعِبَ الْوَلَدُ مَعَ أَصْدِقَائِهِ.',
    german: 'Der Junge spielte mit seinen Freunden.',
    transliteration: 'Laʿiba al-waladu maʿa aṣdiqāʾihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 152,
    arabic: 'رَجَعَ الرَّجُلُ بَعْدَ السَّفَرِ.',
    german: 'Der Mann kehrte nach der Reise zurück.',
    transliteration: 'Raǧaʿa ar-raǧulu baʿda as-safari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 153,
    arabic: 'اسْتَيْقَظَ الرَّجُلُ قَبْلَ الْفَجْرِ.',
    german: 'Der Mann wachte vor der Morgendämmerung auf.',
    transliteration: 'Istayqaẓa ar-raǧulu qabla al-faǧri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 154,
    arabic: 'جَلَسْنَا عِنْدَ النَّهْرِ.',
    german: 'Wir saßen am Fluss.',
    transliteration: 'Ǧalasnā ʿinda an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 155,
    arabic: 'جَلَسَ الرَّجُلُ بَيْنَ وَلَدَيْهِ.',
    german: 'Der Mann saß zwischen seinen beiden Söhnen.',
    transliteration: 'Ǧalasa ar-raǧulu bayna waladayhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 156,
    arabic: 'انْتَظَرْنَا حَتَّى الصَّبَاحِ.',
    german: 'Wir warteten bis zum Morgen.',
    transliteration: 'Intaẓarnā ḥattā aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 157,
    arabic: 'إِذَا جَاءَ اللَّيْلُ نِمْنَا.',
    german: 'Wenn die Nacht kam, schliefen wir.',
    transliteration: 'Iḏā ǧāʾa al-laylu nimnā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 158,
    arabic: 'طَلَعَتِ الشَّمْسُ خَلْفَ الْجَبَلِ.',
    german: 'Die Sonne ging hinter dem Berg auf.',
    transliteration: 'Ṭalaʿati aš-šamsu ḫalfa al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 159,
    arabic: 'غَرَبَتِ الشَّمْسُ خَلْفَ الْبَحْرِ.',
    german: 'Die Sonne ging hinter dem Meer unter.',
    transliteration: 'Ġarabati aš-šamsu ḫalfa al-baḥri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 160,
    arabic: 'وَصَلَ الرَّجُلُ إِلَى الْمَدِينَةِ.',
    german: 'Der Mann kam in der Stadt an.',
    transliteration: 'Waṣala ar-raǧulu ilā al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 17 (word_ids 161-170) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonSeventeenStory = [
  Sentence(
    wordId: 161,
    arabic: 'وَضَعَ الرَّجُلُ الْمِفْتَاحَ عَلَى الطَّاوِلَةِ.',
    german: 'Der Mann legte den Schlüssel auf den Tisch.',
    transliteration: 'Waḍaʿa ar-raǧulu al-miftāḥa ʿalā aṭ-ṭāwilati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 162,
    arabic: 'رَفَعَ الرَّجُلُ الْحَجَرَ.',
    german: 'Der Mann hob den Stein.',
    transliteration: 'Rafaʿa ar-raǧulu al-ḥaǧara.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 163,
    arabic: 'خَفَضَ الرَّجُلُ صَوْتَهُ.',
    german: 'Der Mann senkte seine Stimme.',
    transliteration: 'Ḫafaḍa ar-raǧulu ṣawtahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 164,
    arabic: 'نَظَّفَ الرَّجُلُ الْبَيْتَ.',
    german: 'Der Mann putzte das Haus.',
    transliteration: 'Naẓẓafa ar-raǧulu al-bayta.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 165,
    arabic: 'فَكَّرَ الرَّجُلُ فِي الْمُشْكِلَةِ.',
    german: 'Der Mann dachte über das Problem nach.',
    transliteration: 'Fakkara ar-raǧulu fī al-muškilati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 166,
    arabic: 'أَشَارَ الرَّجُلُ إِلَى الْبَابِ.',
    german: 'Der Mann zeigte auf die Tür.',
    transliteration: 'Ašāra ar-raǧulu ilā al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 167,
    arabic: 'زَارَ الرَّجُلُ صَدِيقَهُ.',
    german: 'Der Mann besuchte seinen Freund.',
    transliteration: 'Zāra ar-raǧulu ṣadīqahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 168,
    arabic: 'دَافَعَ الرَّجُلُ عَنْ أُسْرَتِهِ.',
    german: 'Der Mann verteidigte seine Familie.',
    transliteration: 'Dāfaʿa ar-raǧulu ʿan usratihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 169,
    arabic: 'اجْتَمَعَ الرِّجَالُ فِي السَّاحَةِ.',
    german: 'Die Männer versammelten sich auf dem Platz.',
    transliteration: 'Iǧtamaʿa ar-riǧālu fī as-sāḥati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 170,
    arabic: 'لِهَذَا الرَّجُلِ وَلَدٌ وَاحِدٌ.',
    german: 'Dieser Mann hat einen einzigen Sohn.',
    transliteration: 'Lihāḏā ar-raǧuli waladun wāḥidun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 18 (word_ids 171-180) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonEighteenStory = [
  Sentence(
    wordId: 171,
    arabic: 'بَكَى الطِّفْلُ فِي اللَّيْلِ.',
    german: 'Das Kind weinte in der Nacht.',
    transliteration: 'Bakā aṭ-ṭiflu fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 172,
    arabic: 'زَارَ الرَّجُلُ صَدِيقَهُ الْقَدِيمَ.',
    german: 'Der Mann besuchte seinen alten Freund.',
    transliteration: 'Zāra ar-raǧulu ṣadīqahu al-qadīma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 173,
    arabic: 'دَرَسَ الطَّالِبُ فِي الْمَكْتَبَةِ.',
    german: 'Der Student lernte in der Bibliothek.',
    transliteration: 'Darasa aṭ-ṭālibu fī al-maktabati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 174,
    arabic: 'طَبَخَتِ الْأُمُّ الطَّعَامَ.',
    german: 'Die Mutter kochte das Essen.',
    transliteration: 'Ṭabaḫati al-ummu aṭ-ṭaʿāma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 175,
    arabic: 'عَمِلَ الْأَبُ فِي السُّوقِ.',
    german: 'Der Vater arbeitete auf dem Markt.',
    transliteration: 'ʿAmila al-abu fī as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 176,
    arabic: 'سَاعَدَ الرَّجُلُ أَخَاهُ.',
    german: 'Der Mann half seinem Bruder.',
    transliteration: 'Sāʿada ar-raǧulu aḫāhu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 177,
    arabic: 'نَمَتِ الشَّجَرَةُ بِسُرْعَةٍ.',
    german: 'Der Baum wuchs schnell.',
    transliteration: 'Namati aš-šaǧaratu bisurʿatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 178,
    arabic: 'لَعِبَ الْأَطْفَالُ فِي الْحَدِيقَةِ.',
    german: 'Die Kinder spielten im Garten.',
    transliteration: 'Laʿiba al-aṭfālu fī al-ḥadīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 179,
    arabic: 'بَنَتِ الْحُكُومَةُ مَدْرَسَةً جَدِيدَةً.',
    german: 'Die Regierung baute eine neue Schule.',
    transliteration: 'Banati al-ḥukūmatu madrasatan ǧadīdatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 180,
    arabic: 'بَاعَتِ الْمَرْأَةُ الْخُضْرَاوَاتِ فِي السُّوقِ.',
    german: 'Die Frau verkaufte das Gemüse auf dem Markt.',
    transliteration: 'Bāʿati al-marʾatu al-ḫuḍrāwāti fī as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 19 (word_ids 181-190) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonNineteenStory = [
  Sentence(
    wordId: 181,
    arabic: 'شَرِبَتِ الْأَغْنَامُ مِنَ النَّهْرِ.',
    german: 'Die Schafe tranken vom Fluss.',
    transliteration: 'Šaribati al-aġnāmu mina an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 182,
    arabic: 'هَذَا بَيْتٌ كَبِيرٌ.',
    german: 'Das ist ein großes Haus.',
    transliteration: 'Hāḏā baytun kabīrun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 183,
    arabic: 'هَذَا بَيْتٌ صَغِيرٌ.',
    german: 'Das ist ein kleines Haus.',
    transliteration: 'Hāḏā baytun ṣaġīrun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 184,
    arabic: 'هَذَا مَنْظَرٌ جَمِيلٌ.',
    german: 'Das ist ein schöner Anblick.',
    transliteration: 'Hāḏā manẓarun ǧamīlun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 185,
    arabic: 'هَذَا رَجُلٌ طَوِيلٌ.',
    german: 'Das ist ein großgewachsener Mann.',
    transliteration: 'Hāḏā raǧulun ṭawīlun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 186,
    arabic: 'اشْتَرَى الرَّجُلُ بَيْتًا جَدِيدًا.',
    german: 'Der Mann kaufte ein neues Haus.',
    transliteration: 'Ištarā ar-raǧulu baytan ǧadīdan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 187,
    arabic: 'هَذَا بَيْتٌ قَدِيمٌ.',
    german: 'Das ist ein altes Haus.',
    transliteration: 'Hāḏā baytun qadīmun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 188,
    arabic: 'عِنْدَهُ مَالٌ كَثِيرٌ.',
    german: 'Er hat viel Geld.',
    transliteration: 'ʿIndahu mālun kaṯīrun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 189,
    arabic: 'هَذَا طَعَامٌ جَيِّدٌ.',
    german: 'Das ist gutes Essen.',
    transliteration: 'Hāḏā ṭaʿāmun ǧayyidun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 190,
    arabic: 'الْجَوُّ حَارٌّ الْيَوْمَ.',
    german: 'Das Wetter ist heute heiß.',
    transliteration: 'Al-ǧawwu ḥārrun al-yawma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

// Kurzgeschichte Lektion 20 (word_ids 191-200) — je ein
// validierter Kontext-Satz pro Wort aus sentences.json (zusammenhängend durch
// die Erzähl-Auswahl; korrektes Arabisch/Transliteration garantiert).
final List<Sentence> _lessonTwentyStory = [
  Sentence(
    wordId: 191,
    arabic: 'الْجَوُّ بَارِدٌ فِي الشِّتَاءِ.',
    german: 'Das Wetter ist kalt im Winter.',
    transliteration: 'Al-ǧawwu bāridun fī aš-šitāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 192,
    arabic: 'هَلْ أَنْتَ بِخَيْرٍ؟',
    german: 'Geht es dir gut?',
    transliteration: 'Hal anta biḫayrin?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 193,
    arabic: 'كَيْفَ حَالُكَ؟',
    german: 'Wie geht es dir?',
    transliteration: 'Kayfa ḥāluka?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 194,
    arabic: 'أَيْنَ بَيْتُكَ؟',
    german: 'Wo ist dein Haus?',
    transliteration: 'Ayna baytuka?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 195,
    arabic: 'مَتَى تَرْجِعُ؟',
    german: 'Wann kehrst du zurück?',
    transliteration: 'Matā tarǧiʿu?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 196,
    arabic: 'لِمَاذَا بَكَيْتَ؟',
    german: 'Warum hast du geweint?',
    transliteration: 'Limāḏā bakayta?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 197,
    arabic: 'مَنْ هَذَا الرَّجُلُ؟',
    german: 'Wer ist dieser Mann?',
    transliteration: 'Man hāḏā ar-raǧulu?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 198,
    arabic: 'مَاذَا فَعَلْتَ الْيَوْمَ؟',
    german: 'Was hast du heute getan?',
    transliteration: 'Māḏā faʿalta al-yawma?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 199,
    arabic: 'كُلُّ رَجُلٍ لَهُ رَأْيٌ.',
    german: 'Jeder Mann hat eine Meinung.',
    transliteration: 'Kullu raǧulin lahu raʾyun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 200,
    arabic: 'لَا أَعْرِفُ الْجَوَابَ.',
    german: 'Ich weiß die Antwort nicht.',
    transliteration: 'Lā aʿrifu al-ǧawāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];



final List<Sentence> _lessonTwentyOneStory = [
  Sentence(
    wordId: 201,
    arabic: 'كَانَ الرَّجُلُ طَبِيبًا.',
    german: 'Der Mann war Arzt.',
    transliteration: 'Kāna ar-raǧulu ṭabīban.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 202,
    arabic: 'جَعَلَ اللَّهُ اللَّيْلَ سَكَنًا.',
    german: 'Allah machte die Nacht zur Ruhestätte.',
    transliteration: 'Ǧaʿala Allāhu al-layla sakanan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 203,
    arabic: 'ظَهَرَ الْقَمَرُ فِي اللَّيْلِ.',
    german: 'Der Mond erschien in der Nacht.',
    transliteration: 'Ẓahara al-qamaru fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 204,
    arabic: 'وَقَفَ الرَّجُلُ عِنْدَ الْبَابِ.',
    german: 'Der Mann stand an der Tür.',
    transliteration: 'Waqafa ar-raǧulu ʿinda al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 205,
    arabic: 'سَبَقَ الْوَلَدُ أَصْدِقَاءَهُ.',
    german: 'Der Junge übertraf seine Freunde.',
    transliteration: 'Sabaqa al-waladu aṣdiqāʾahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 206,
    arabic: 'نَجَا الرَّجُلُ مِنَ الْخَطَرِ.',
    german: 'Der Mann entkam der Gefahr.',
    transliteration: 'Naǧā ar-raǧulu mina al-ḫaṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 207,
    arabic: 'هَرَبَ الرَّجُلُ مِنَ الْحَرْبِ.',
    german: 'Der Mann floh vor dem Krieg.',
    transliteration: 'Haraba ar-raǧulu mina al-ḥarbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 208,
    arabic: 'سَكَنَ الرَّجُلُ فِي الْمَدِينَةِ.',
    german: 'Der Mann wohnte in der Stadt.',
    transliteration: 'Sakana ar-raǧulu fī al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 209,
    arabic: 'مَرَّ الرَّجُلُ بِالْبَيْتِ.',
    german: 'Der Mann ging am Haus vorbei.',
    transliteration: 'Marra ar-raǧulu bil-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 210,
    arabic: 'هَذِهِ الْحَيَاةُ قَصِيرَةٌ.',
    german: 'Dieses Leben ist kurz.',
    transliteration: 'Hāḏihi al-ḥayātu qaṣīratun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonTwentyTwoStory = [
  Sentence(
    wordId: 211,
    arabic: 'رَأَيْنَا نُورًا فِي الظَّلَامِ.',
    german: 'Wir sahen ein Licht in der Dunkelheit.',
    transliteration: 'Raʾaynā nūran fī aẓ-ẓalāmi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 212,
    arabic: 'فَعَلَ الرَّجُلُ خَيْرًا.',
    german: 'Der Mann tat Gutes.',
    transliteration: 'Faʿala ar-raǧulu ḫayran.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 213,
    arabic: 'لِلرَّجُلِ عَقْلٌ قَوِيٌّ.',
    german: 'Der Mann hat einen starken Verstand.',
    transliteration: 'Lir-raǧuli ʿaqlun qawiyyun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 214,
    arabic: 'لِلْإِنْسَانِ رُوحٌ وَجَسَدٌ.',
    german: 'Der Mensch hat eine Seele und einen Körper.',
    transliteration: 'Lil-insāni rūḥun wa-ǧasadun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 215,
    arabic: 'هَذَا اللِّسَانُ عَرَبِيٌّ.',
    german: 'Diese Sprache ist Arabisch.',
    transliteration: 'Hāḏā al-lisānu ʿarabiyyun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 216,
    arabic: 'خَرَجَ الدَّمُ مِنَ الْجُرْحِ.',
    german: 'Das Blut floss aus der Wunde.',
    transliteration: 'Ḫaraǧa ad-damu mina al-ǧurḥi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 217,
    arabic: 'رَمَى الْوَلَدُ حَجَرًا.',
    german: 'Der Junge warf einen Stein.',
    transliteration: 'Ramā al-waladu ḥaǧaran.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 218,
    arabic: 'هَبَّتِ الرِّيحُ بِقُوَّةٍ.',
    german: 'Der Wind wehte stark.',
    transliteration: 'Habbati ar-rīḥu biquwwatin.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 219,
    arabic: 'نَزَلَ الْمَطَرُ عَلَى الْمَدِينَةِ.',
    german: 'Der Regen fiel auf die Stadt.',
    transliteration: 'Nazala al-maṭaru ʿalā al-madīnati.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 220,
    arabic: 'رَأَيْنَا نَجْمًا فِي السَّمَاءِ.',
    german: 'Wir sahen einen Stern am Himmel.',
    transliteration: 'Raʾaynā naǧman fī as-samāʾi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonTwentyThreeStory = [
  Sentence(
    wordId: 221,
    arabic: 'أَكَلَ الرَّجُلُ طَعَامًا لَذِيذًا.',
    german: 'Der Mann aß ein leckeres Essen.',
    transliteration: 'Akala ar-raǧulu ṭaʿāman laḏīḏan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 222,
    arabic: 'هَذَا رَجُلٌ عَظِيمٌ.',
    german: 'Das ist ein bedeutender Mann.',
    transliteration: 'Hāḏā raǧulun ʿaẓīmun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 223,
    arabic: 'هَذَا الرَّجُلُ قَوِيٌّ.',
    german: 'Dieser Mann ist stark.',
    transliteration: 'Hāḏā ar-raǧulu qawiyyun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 224,
    arabic: 'هَذَا الْوَلَدُ ضَعِيفٌ.',
    german: 'Dieser Junge ist schwach.',
    transliteration: 'Hāḏā al-waladu ḍaʿīfun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 225,
    arabic: 'هَذَا الرَّجُلُ غَنِيٌّ.',
    german: 'Dieser Mann ist reich.',
    transliteration: 'Hāḏā ar-raǧulu ġaniyyun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 226,
    arabic: 'هَذَا الرَّجُلُ فَقِيرٌ.',
    german: 'Dieser Mann ist arm.',
    transliteration: 'Hāḏā ar-raǧulu faqīrun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 227,
    arabic: 'هَذَا الدَّرْسُ سَهْلٌ.',
    german: 'Diese Lektion ist leicht.',
    transliteration: 'Hāḏā ad-darsu sahlun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 228,
    arabic: 'هَذَا الْبَيْتُ بَعِيدٌ.',
    german: 'Dieses Haus ist weit entfernt.',
    transliteration: 'Hāḏā al-baytu baʿīdun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 229,
    arabic: 'بَيْتُنَا قَرِيبٌ مِنَ الْمَدْرَسَةِ.',
    german: 'Unser Haus ist nahe an der Schule.',
    transliteration: 'Baytunā qarībun mina al-madrasati.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 230,
    arabic: 'قَالَ الرَّجُلُ: نَعَمْ.',
    german: 'Der Mann sagte: Ja.',
    transliteration: 'Qāla ar-raǧulu: naʿam.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonTwentyFourStory = [
  Sentence(
    wordId: 231,
    arabic: 'وَجَبَ عَلَى الرَّجُلِ أَنْ يَعْمَلَ.',
    german: 'Es war dem Mann zur Pflicht, zu arbeiten.',
    transliteration: 'Wajaba ʿalā ar-raǧuli an yaʿmala.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 232,
    arabic: 'حَدَثَ أَمْرٌ عَظِيمٌ.',
    german: 'Eine gewaltige Sache geschah.',
    transliteration: 'Ḥadaṯa amrun ʿaẓīmun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 233,
    arabic: 'بَقِيَ الرَّجُلُ فِي الْبَيْتِ.',
    german: 'Der Mann blieb im Haus.',
    transliteration: 'Baqiya ar-raǧulu fī al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 234,
    arabic: 'تَبِعَ الْوَلَدُ أَبَاهُ.',
    german: 'Der Junge folgte seinem Vater.',
    transliteration: 'Tabiʿa al-waladu abāhu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 235,
    arabic: 'أَرْسَلَ الْمَلِكُ رَسُولًا.',
    german: 'Der König sandte einen Gesandten.',
    transliteration: 'Arsala al-maliku rasūlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 236,
    arabic: 'نَادَى الرَّجُلُ صَدِيقَهُ.',
    german: 'Der Mann rief seinen Freund.',
    transliteration: 'Nādā ar-raǧulu ṣadīqahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 237,
    arabic: 'زَادَ الْمَاءُ فِي النَّهْرِ.',
    german: 'Das Wasser im Fluss nahm zu.',
    transliteration: 'Zāda al-māʾu fī an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 238,
    arabic: 'كَشَفَ الطَّبِيبُ عَنِ الْمَرَضِ.',
    german: 'Der Arzt deckte die Krankheit auf.',
    transliteration: 'Kašafa aṭ-ṭabību ʿani al-maraḍi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 239,
    arabic: 'هَذَا الرَّجُلُ عَدُوٌّ لَنَا.',
    german: 'Dieser Mann ist ein Feind für uns.',
    transliteration: 'Hāḏā ar-raǧulu ʿaduwwun lanā.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 240,
    arabic: 'سَمِعْنَا صَوْتًا مِنَ الْبَعِيدِ.',
    german: 'Wir hörten eine Stimme aus der Ferne.',
    transliteration: 'Samiʿnā ṣawtan mina al-baʿīdi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonTwentyFiveStory = [
  Sentence(
    wordId: 241,
    arabic: 'كَانَ الرَّسُولُ صَادِقًا.',
    german: 'Der Gesandte war wahrhaftig.',
    transliteration: 'Kāna ar-rasūlu ṣādiqan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 242,
    arabic: 'بَدَأَتِ الْحَرْبُ فِي ذَلِكَ الْعَامِ.',
    german: 'Der Krieg begann in jenem Jahr.',
    transliteration: 'Badaʾati al-ḥarbu fī ḏālika al-ʿāmi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 243,
    arabic: 'أَرَادَ الْمَلِكُ السِّلْمَ لَا الْحَرْبَ.',
    german: 'Der König wollte Frieden, nicht Krieg.',
    transliteration: 'Arāda al-maliku as-silma lā al-ḥarba.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 244,
    arabic: 'أَكَلْنَا لَحْمًا وَخُبْزًا.',
    german: 'Wir aßen Fleisch und Brot.',
    transliteration: 'Akalnā laḥman wa-ḫubzan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 245,
    arabic: 'أَكَلَ الطِّفْلُ الْخُبْزَ.',
    german: 'Das Kind aß das Brot.',
    transliteration: 'Akala aṭ-ṭiflu al-ḫubza.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 246,
    arabic: 'هَذَا الْعَسَلُ حُلْوٌ.',
    german: 'Dieser Honig ist süß.',
    transliteration: 'Hāḏā al-ʿasalu ḥulwun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 247,
    arabic: 'اشْتَرَتِ الْمَرْأَةُ ذَهَبًا.',
    german: 'Die Frau kaufte Gold.',
    transliteration: 'Ištarati al-marʾatu ḏahaban.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 248,
    arabic: 'رَأَيْنَا طَيْرًا جَمِيلًا.',
    german: 'Wir sahen einen schönen Vogel.',
    transliteration: 'Raʾaynā ṭayran ǧamīlan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 249,
    arabic: 'هَذَا الْجَوَابُ صَحِيحٌ.',
    german: 'Diese Antwort ist richtig.',
    transliteration: 'Hāḏā al-ǧawābu ṣaḥīḥun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 250,
    arabic: 'الْوَلَدُ سَعِيدٌ بِهَدِيَّتِهِ.',
    german: 'Der Junge ist glücklich über sein Geschenk.',
    transliteration: 'Al-waladu saʿīdun bi-hadiyyatihi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonTwentySixStory = [
  Sentence(
    wordId: 251,
    arabic: 'كَانَ الرَّجُلُ حَزِينًا عَلَى صَدِيقِهِ.',
    german: 'Der Mann war traurig um seinen Freund.',
    transliteration: 'Kāna ar-raǧulu ḥazīnan ʿalā ṣadīqihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 252,
    arabic: 'هَذَا الرَّجُلُ جَاهِلٌ بِالْحَقِّ.',
    german: 'Dieser Mann ist unwissend über die Wahrheit.',
    transliteration: 'Hāḏā ar-raǧulu ǧāhilun bil-ḥaqqi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 253,
    arabic: 'الرَّجُلُ الْعَاقِلُ يَصْبِرُ.',
    german: 'Der vernünftige Mann ist geduldig.',
    transliteration: 'Ar-raǧulu al-ʿāqilu yaṣbiru.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 254,
    arabic: 'هَذَا الطَّعَامُ حَلَالٌ.',
    german: 'Diese Speise ist erlaubt.',
    transliteration: 'Hāḏā aṭ-ṭaʿāmu ḥalālun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 255,
    arabic: 'أَكْلُ الرِّبَا حَرَامٌ.',
    german: 'Das Essen von Zins ist verboten.',
    transliteration: 'Aklu ar-ribā ḥarāmun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 256,
    arabic: 'الرَّجُلُ الْمُؤْمِنُ يَصْبِرُ عَلَى الْبَلَاءِ.',
    german: 'Der gläubige Mann erträgt geduldig die Prüfung.',
    transliteration: 'Ar-raǧulu al-muʾminu yaṣbiru ʿalā al-balāʾi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 257,
    arabic: 'هَلْ تُرِيدُ مَاءً أَوْ عَسَلًا؟',
    german: 'Willst du Wasser oder Honig?',
    transliteration: 'Hal turīdu māʾan aw ʿasalan?',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 258,
    arabic: 'دَخَلَ الْبَيْتَ ثُمَّ جَلَسَ.',
    german: 'Er betrat das Haus, dann setzte er sich.',
    transliteration: 'Daḫala al-bayta ṯumma ǧalasa.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 259,
    arabic: 'ذَهَبَ إِلَى السُّوقِ لَكِنْ لَمْ يَجِدْ شَيْئًا.',
    german: 'Er ging zum Markt, aber fand nichts.',
    transliteration: 'Ḏahaba ilā as-sūqi lākin lam yaǧid šayʾan.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 260,
    arabic: 'قَدْ فَهِمْتُ الدَّرْسَ.',
    german: 'Ich habe die Lektion bereits verstanden.',
    transliteration: 'Qad fahimtu ad-darsa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

final List<Sentence> _lessonTwentySevenStory = [
  Sentence(
    wordId: 261,
    arabic: 'وَهَبَ اللَّهُ لَهُ وَلَدًا.',
    german: 'Allah schenkte ihm einen Sohn.',
    transliteration: 'Wahaba Allāhu lahu waladan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 262,
    arabic: 'قَصَدَ الرَّجُلُ الْمَدِينَةَ.',
    german: 'Der Mann steuerte die Stadt an.',
    transliteration: 'Qaṣada ar-raǧulu al-madīnata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 263,
    arabic: 'شَرَحَ الْمُعَلِّمُ الدَّرْسَ.',
    german: 'Der Lehrer erklärte die Lektion.',
    transliteration: 'Šaraḥa al-muʿallimu ad-darsa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 264,
    arabic: 'سَرَقَ الرَّجُلُ مَالًا.',
    german: 'Der Mann stahl Geld.',
    transliteration: 'Saraqa ar-raǧulu mālan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 265,
    arabic: 'خَانَ الرَّجُلُ صَدِيقَهُ.',
    german: 'Der Mann verriet seinen Freund.',
    transliteration: 'Ḫāna ar-raǧulu ṣadīqahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 266,
    arabic: 'هَاجَرَ الرَّجُلُ إِلَى مَدِينَةٍ أُخْرَى.',
    german: 'Der Mann wanderte in eine andere Stadt aus.',
    transliteration: 'Hāǧara ar-raǧulu ilā madīnatin uḫrā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 267,
    arabic: 'فَرِحَ الْوَلَدُ بِهَدِيَّتِهِ.',
    german: 'Der Junge freute sich über sein Geschenk.',
    transliteration: 'Fariḥa al-waladu bi-hadiyyatihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 268,
    arabic: 'اسْتَرَاحَ الرَّجُلُ بَعْدَ الْعَمَلِ.',
    german: 'Der Mann ruhte sich nach der Arbeit aus.',
    transliteration: 'Istarāḥa ar-raǧulu baʿda al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 269,
    arabic: 'حَمَلَ الْجُنْدِيُّ سَيْفًا.',
    german: 'Der Soldat trug ein Schwert.',
    transliteration: 'Ḥamala al-ǧundiyyu sayfan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 270,
    arabic: 'كَانَ جَيْشُ الْمَلِكِ عَظِيمًا.',
    german: 'Das Heer des Königs war gewaltig.',
    transliteration: 'Kāna ǧayšu al-maliki ʿaẓīman.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonTwentyEightStory = [
  Sentence(
    wordId: 271,
    arabic: 'الْعَدْلُ أَسَاسُ الْحُكْمِ.',
    german: 'Gerechtigkeit ist die Grundlage der Herrschaft.',
    transliteration: 'Al-ʿadlu asāsu al-ḥukmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 272,
    arabic: 'الظُّلْمُ حَرَامٌ.',
    german: 'Ungerechtigkeit ist verboten.',
    transliteration: 'Aẓ-ẓulmu ḥarāmun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 273,
    arabic: 'تَكَلَّمَ بِصِدْقٍ.',
    german: 'Er sprach mit Wahrhaftigkeit.',
    transliteration: 'Takallama bi-ṣidqin.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 274,
    arabic: 'الْكَذِبُ حَرَامٌ.',
    german: 'Lüge ist verboten.',
    transliteration: 'Al-kaḏibu ḥarāmun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 275,
    arabic: 'رَحْمَةُ اللَّهِ وَاسِعَةٌ.',
    german: 'Die Barmherzigkeit Allahs ist weit.',
    transliteration: 'Raḥmatu Allāhi wāsiʿatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 276,
    arabic: 'الصَّبْرُ مِفْتَاحُ الْفَرَجِ.',
    german: 'Geduld ist der Schlüssel zur Erleichterung.',
    transliteration: 'Aṣ-ṣabru miftāḥu al-faraǧi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 277,
    arabic: 'الشُّكْرُ لِلَّهِ.',
    german: 'Der Dank gebührt Allah.',
    transliteration: 'Aš-šukru lillāhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 278,
    arabic: 'الْإِيمَانُ فِي الْقَلْبِ.',
    german: 'Der Glaube ist im Herzen.',
    transliteration: 'Al-īmānu fī al-qalbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 279,
    arabic: 'لَا خَوْفَ عَلَيْهِمْ.',
    german: 'Keine Furcht soll auf ihnen sein.',
    transliteration: 'Lā ḫawfa ʿalayhim.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 280,
    arabic: 'الْحُبُّ فِي الْقَلْبِ.',
    german: 'Die Liebe ist im Herzen.',
    transliteration: 'Al-ḥubbu fī al-qalbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

final List<Sentence> _lessonTwentyNineStory = [
  Sentence(
    wordId: 281,
    arabic: 'جَلَسَ الشَّيْخُ أَمَامَ الْبَيْتِ.',
    german: 'Der alte Mann saß vor dem Haus.',
    transliteration: 'Ǧalasa aš-šayḫu amāma al-bayti.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 282,
    arabic: 'لَهُ أَجْرٌ عَظِيمٌ.',
    german: 'Für ihn gibt es einen gewaltigen Lohn.',
    transliteration: 'Lahu aǧrun ʿaẓīmun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 283,
    arabic: 'الْمَاءُ طَاهِرٌ.',
    german: 'Das Wasser ist rein.',
    transliteration: 'Al-māʾu ṭāhirun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 284,
    arabic: 'هَذَا الرَّجُلُ شَرِيفٌ.',
    german: 'Dieser Mann ist edel.',
    transliteration: 'Hāḏā ar-raǧulu šarīfun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 285,
    arabic: 'الْجُنْدِيُّ شُجَاعٌ.',
    german: 'Der Soldat ist mutig.',
    transliteration: 'Al-ǧundiyyu šuǧāʿun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 286,
    arabic: 'لَيْسَ هَذَا الرَّجُلُ جَبَانًا.',
    german: 'Dieser Mann ist nicht feige.',
    transliteration: 'Laysa hāḏā ar-raǧulu ǧabānan.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 287,
    arabic: 'هَذَا الرَّجُلُ كَرِيمٌ.',
    german: 'Dieser Mann ist großzügig.',
    transliteration: 'Hāḏā ar-raǧulu karīmun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 288,
    arabic: 'هَذَا الرَّجُلُ بَخِيلٌ.',
    german: 'Dieser Mann ist geizig.',
    transliteration: 'Hāḏā ar-raǧulu baḫīlun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 289,
    arabic: 'عَاشَ ذَلِيلًا بَعْدَ الْهَزِيمَةِ.',
    german: 'Er lebte erniedrigt nach der Niederlage.',
    transliteration: 'ʿĀša ḏalīlan baʿda al-hazīmati.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 290,
    arabic: 'هَذَا الْبَيْتُ نَظِيفٌ.',
    german: 'Dieses Haus ist sauber.',
    transliteration: 'Hāḏā al-baytu naẓīfun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonThirtyStory = [
  Sentence(
    wordId: 291,
    arabic: 'فَقَدَ الرَّجُلُ مَالَهُ.',
    german: 'Der Mann verlor sein Geld.',
    transliteration: 'Faqada ar-raǧulu mālahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 292,
    arabic: 'حَصَلَ الطَّالِبُ عَلَى الْكِتَابِ.',
    german: 'Der Student erhielt das Buch.',
    transliteration: 'Ḥaṣala aṭ-ṭālibu ʿalā al-kitābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 293,
    arabic: 'بَحَثَ الرَّجُلُ عَنْ عَمَلٍ.',
    german: 'Der Mann suchte nach Arbeit.',
    transliteration: 'Baḥaṯa ar-raǧulu ʿan ʿamalin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 294,
    arabic: 'غَيَّرَ الرَّجُلُ رَأْيَهُ.',
    german: 'Der Mann änderte seine Meinung.',
    transliteration: 'Ġayyara ar-raǧulu raʾyahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 295,
    arabic: 'عَادَ الرَّجُلُ إِلَى بَيْتِهِ.',
    german: 'Der Mann kehrte zu seinem Haus zurück.',
    transliteration: 'ʿĀda ar-raǧulu ilā baytihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 296,
    arabic: 'رَدَّ الرَّجُلُ الْكِتَابَ إِلَى صَاحِبِهِ.',
    german: 'Der Mann gab das Buch seinem Besitzer zurück.',
    transliteration: 'Radda ar-raǧulu al-kitāba ilā ṣāḥibihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 297,
    arabic: 'عَلَّمَ الشَّيْخُ الطُّلَّابَ.',
    german: 'Der Scheich lehrte die Studenten.',
    transliteration: 'ʿAllama aš-šayḫu aṭ-ṭullāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 298,
    arabic: 'لَاحَظَ الْمُعَلِّمُ خَطَأَ الطَّالِبِ.',
    german: 'Der Lehrer bemerkte den Fehler des Studenten.',
    transliteration: 'Lāḥaẓa al-muʿallimu ḫaṭaʾa aṭ-ṭālibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 299,
    arabic: 'أَخَذَ الرَّجُلُ مِفْتَاحَ الْبَيْتِ.',
    german: 'Der Mann nahm den Hausschlüssel.',
    transliteration: 'Aḫaḏa ar-raǧulu miftāḥa al-bayti.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 300,
    arabic: 'دَخَلَ الْوَلَدُ الْغُرْفَةَ.',
    german: 'Der Junge betrat das Zimmer.',
    transliteration: 'Daḫala al-waladu al-ġurfata.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonThirtyOneStory = [
  Sentence(
    wordId: 301,
    arabic: 'فَتَحَ الْوَلَدُ النَّافِذَةَ.',
    german: 'Der Junge öffnete das Fenster.',
    transliteration: 'Fataḥa al-waladu an-nāfiḏata.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 302,
    arabic: 'بَنَى الرَّجُلُ جِدَارًا.',
    german: 'Der Mann baute eine Wand.',
    transliteration: 'Banā ar-raǧulu ǧidāran.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 303,
    arabic: 'جَلَسَتِ الْمَرْأَةُ عَلَى الْكُرْسِيِّ.',
    german: 'Die Frau setzte sich auf den Stuhl.',
    transliteration: 'Ǧalasati al-marʾatu ʿalā al-kursiyyi.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 304,
    arabic: 'نَامَ الطِّفْلُ عَلَى الْفِرَاشِ.',
    german: 'Das Kind schlief auf dem Bett.',
    transliteration: 'Nāma aṭ-ṭiflu ʿalā al-firāši.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 305,
    arabic: 'أَضَاءَ الرَّجُلُ الْمِصْبَاحَ.',
    german: 'Der Mann zündete die Lampe an.',
    transliteration: 'Aḍāʾa ar-raǧulu al-miṣbāḥa.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 306,
    arabic: 'رَبَطَ الرَّجُلُ الْحَبْلَ.',
    german: 'Der Mann band das Seil fest.',
    transliteration: 'Rabaṭa ar-raǧulu al-ḥabla.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 307,
    arabic: 'خَاطَتِ الْمَرْأَةُ بِالْإِبْرَةِ.',
    german: 'Die Frau nähte mit der Nadel.',
    transliteration: 'Ḫāṭati al-marʾatu bil-ibrati.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 308,
    arabic: 'نَظَرَتِ الْمَرْأَةُ فِي الْمِرْآةِ.',
    german: 'Die Frau schaute in den Spiegel.',
    transliteration: 'Naẓarati al-marʾatu fī al-mirʾāti.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 309,
    arabic: 'نَظَرَ إِلَى السَّاعَةِ.',
    german: 'Er schaute auf die Uhr.',
    transliteration: 'Naẓara ilā as-sāʿati.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 310,
    arabic: 'وَجَدَ الرَّجُلُ فُرْصَةً جَيِّدَةً.',
    german: 'Der Mann fand eine gute Gelegenheit.',
    transliteration: 'Waǧada ar-raǧulu furṣatan ǧayyidatan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonThirtyTwoStory = [
  Sentence(
    wordId: 311,
    arabic: 'حَلَلْنَا الْمُشْكِلَةَ.',
    german: 'Wir lösten das Problem.',
    transliteration: 'Ḥalalnā al-muškilata.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 312,
    arabic: 'وَجَدْنَا حَلًّا لِلْمُشْكِلَةِ.',
    german: 'Wir fanden eine Lösung für das Problem.',
    transliteration: 'Waǧadnā ḥallan lil-muškilati.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 313,
    arabic: 'هَذَا السُّؤَالُ صَعْبٌ.',
    german: 'Diese Frage ist schwierig.',
    transliteration: 'Hāḏā as-suʾālu ṣaʿbun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 314,
    arabic: 'هَذَا الْأَمْرُ مُمْكِنٌ.',
    german: 'Diese Sache ist möglich.',
    transliteration: 'Hāḏā al-amru mumkinun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 315,
    arabic: 'هَذَا الْأَمْرُ مُهِمٌّ.',
    german: 'Diese Sache ist wichtig.',
    transliteration: 'Hāḏā al-amru muhimmun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 316,
    arabic: 'هَذَا الطَّرِيقُ خَطِيرٌ.',
    german: 'Dieser Weg ist gefährlich.',
    transliteration: 'Hāḏā aṭ-ṭarīqu ḫaṭīrun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 317,
    arabic: 'هَذَا الْبَلَدُ آمِنٌ.',
    german: 'Dieses Land ist sicher.',
    transliteration: 'Hāḏā al-baladu āminun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 318,
    arabic: 'لِلنَّاسِ آرَاءٌ مُخْتَلِفَةٌ.',
    german: 'Die Menschen haben unterschiedliche Meinungen.',
    transliteration: 'Lin-nāsi ārāʾun muḫtalifatun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 319,
    arabic: 'هَذَا الْوَضْعُ مُشَابِهٌ لِلْأَوَّلِ.',
    german: 'Diese Situation ist ähnlich der ersten.',
    transliteration: 'Hāḏā al-waḍʿu mušābihun lil-awwali.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 320,
    arabic: 'الْجَوَابُ وَاضِحٌ.',
    german: 'Die Antwort ist klar.',
    transliteration: 'Al-ǧawābu wāḍiḥun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonThirtyThreeStory = [
  Sentence(
    wordId: 321,
    arabic: 'أَسْرَعَ الرَّجُلُ فِي الطَّرِيقِ.',
    german: 'Der Mann eilte auf dem Weg.',
    transliteration: 'Asraʿa ar-raǧulu fī aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 322,
    arabic: 'بَطُؤَ الرَّجُلُ فِي عَمَلِهِ.',
    german: 'Der Mann war langsam bei seiner Arbeit.',
    transliteration: 'Baṭuʾa ar-raǧulu fī ʿamalihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 323,
    arabic: 'دَنَا الْمَسَاءُ.',
    german: 'Der Abend näherte sich.',
    transliteration: 'Danā al-masāʾu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 324,
    arabic: 'بَعَثَ الْمَلِكُ رَسُولًا إِلَى الْقَوْمِ.',
    german: 'Der König sandte einen Boten zum Volk.',
    transliteration: 'Baʿaṯa al-maliku rasūlan ilā al-qawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 325,
    arabic: 'بَلَغَ الرَّجُلُ الْمَدِينَةَ.',
    german: 'Der Mann erreichte die Stadt.',
    transliteration: 'Balaġa ar-raǧulu al-madīnata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 326,
    arabic: 'خَتَمَ الرَّجُلُ الرِّسَالَةَ.',
    german: 'Der Mann versiegelte den Brief.',
    transliteration: 'Ḫatama ar-raǧulu ar-risālata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 327,
    arabic: 'سَقَطَ الْوَلَدُ عَلَى الْأَرْضِ.',
    german: 'Der Junge fiel auf den Boden.',
    transliteration: 'Saqaṭa al-waladu ʿalā al-arḍi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 328,
    arabic: 'رَبَطَ الرَّجُلُ الْحِصَانَ.',
    german: 'Der Mann band das Pferd fest.',
    transliteration: 'Rabaṭa ar-raǧulu al-ḥiṣāna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 329,
    arabic: 'غَطَّى السَّحَابُ السَّمَاءَ.',
    german: 'Die Wolken bedeckten den Himmel.',
    transliteration: 'Ġaṭṭā as-saḥābu as-samāʾa.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 330,
    arabic: 'رَأَيْنَا الْبَرْقَ فِي السَّمَاءِ.',
    german: 'Wir sahen den Blitz am Himmel.',
    transliteration: 'Raʾaynā al-barqa fī as-samāʾi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonThirtyFourStory = [
  Sentence(
    wordId: 331,
    arabic: 'كَانَ الرَّعْدُ عَالِيًا.',
    german: 'Der Donner war laut.',
    transliteration: 'Kāna ar-raʿdu ʿāliyan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 332,
    arabic: 'غَطَّى الثَّلْجُ الْجَبَلَ.',
    german: 'Der Schnee bedeckte den Berg.',
    transliteration: 'Ġaṭṭā aṯ-ṯalǧu al-ǧabala.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 333,
    arabic: 'سَافَرْنَا إِلَى جَزِيرَةٍ بَعِيدَةٍ.',
    german: 'Wir reisten zu einer fernen Insel.',
    transliteration: 'Sāfarnā ilā ǧazīratin baʿīdatin.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 334,
    arabic: 'حَفَرَ الرَّجُلُ بِئْرًا.',
    german: 'Der Mann grub einen Brunnen.',
    transliteration: 'Ḥafara ar-raǧulu biʾran.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 335,
    arabic: 'عَبَرَ الرَّجُلُ الْجِسْرَ.',
    german: 'Der Mann überquerte die Brücke.',
    transliteration: 'ʿAbara ar-raǧulu al-ǧisra.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 336,
    arabic: 'انْكَسَرَ عَظْمُ رِجْلِهِ.',
    german: 'Der Knochen seines Beins brach.',
    transliteration: 'Inkasara ʿaẓmu riǧlihi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 337,
    arabic: 'شَعْرُهَا طَوِيلٌ.',
    german: 'Ihr Haar ist lang.',
    transliteration: 'Šaʿruhā ṭawīlun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 338,
    arabic: 'قَصَّتِ الْأُمُّ أَظْفَارَ طِفْلِهَا.',
    german: 'Die Mutter schnitt die Fingernägel ihres Kindes.',
    transliteration: 'Qaṣṣati al-ummu aẓfāra ṭiflihā.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 339,
    arabic: 'كَسَرَ الصَّيَّادُ جَنَاحَ الطَّيْرِ.',
    german: 'Der Jäger brach den Flügel des Vogels.',
    transliteration: 'Kasara aṣ-ṣayyādu ǧanāḥa aṭ-ṭayri.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 340,
    arabic: 'غَطَّى التُّرَابُ الطَّرِيقَ.',
    german: 'Der Staub bedeckte den Weg.',
    transliteration: 'Ġaṭṭā at-turābu aṭ-ṭarīqa.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonThirtyFiveStory = [
  Sentence(
    wordId: 341,
    arabic: 'مَشَيْنَا عَلَى الرَّمْلِ.',
    german: 'Wir liefen auf dem Sand.',
    transliteration: 'Mašaynā ʿalā ar-ramli.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 342,
    arabic: 'دَخَلَ الرَّجُلُ الْغَارَ.',
    german: 'Der Mann betrat die Höhle.',
    transliteration: 'Daḫala ar-raǧulu al-ġāra.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 343,
    arabic: 'هَذَا الطَّرِيقُ عَرِيضٌ.',
    german: 'Dieser Weg ist breit.',
    transliteration: 'Hāḏā aṭ-ṭarīqu ʿarīḍun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 344,
    arabic: 'كَانَ النَّهْرُ عَمِيقًا.',
    german: 'Der Fluss war tief.',
    transliteration: 'Kāna an-nahru ʿamīqan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 345,
    arabic: 'هَذَا الْحَجَرُ خَشِنٌ.',
    german: 'Dieser Stein ist rau.',
    transliteration: 'Hāḏā al-ḥaǧaru ḫašinun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 346,
    arabic: 'الْبَيْتُ مُظْلِمٌ لَيْلًا.',
    german: 'Das Haus ist nachts dunkel.',
    transliteration: 'Al-baytu muẓlimun laylan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 347,
    arabic: 'هَذَا الرَّجُلُ قَصِيرٌ.',
    german: 'Dieser Mann ist klein.',
    transliteration: 'Hāḏā ar-raǧulu qaṣīrun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 348,
    arabic: 'هَذَا الْخُبْزُ يَابِسٌ.',
    german: 'Dieses Brot ist trocken.',
    transliteration: 'Hāḏā al-ḫubzu yābisun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 349,
    arabic: 'هَذَا الطَّعَامُ رَطْبٌ.',
    german: 'Diese Speise ist weich.',
    transliteration: 'Hāḏā aṭ-ṭaʿāmu raṭbun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 350,
    arabic: 'عِنْدَنَا مَاءٌ قَلِيلٌ.',
    german: 'Wir haben wenig Wasser.',
    transliteration: 'ʿIndanā māʾun qalīlun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonThirtySixStory = [
  Sentence(
    wordId: 351,
    arabic: 'حَجَّ الرَّجُلُ إِلَى مَكَّةَ.',
    german: 'Der Mann pilgerte nach Mekka.',
    transliteration: 'Ḥajja ar-raǧulu ilā makkata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 352,
    arabic: 'صَامَ الرَّجُلُ يَوْمًا كَامِلًا.',
    german: 'Der Mann fastete einen ganzen Tag.',
    transliteration: 'Ṣāma ar-raǧulu yawman kāmilan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 353,
    arabic: 'صَلَّى الرَّجُلُ فِي الْمَسْجِدِ.',
    german: 'Der Mann betete in der Moschee.',
    transliteration: 'Ṣallā ar-raǧulu fī al-masǧidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 354,
    arabic: 'زَكَا الزَّرْعُ بَعْدَ الْمَطَرِ.',
    german: 'Die Saat gedieh nach dem Regen.',
    transliteration: 'Zakā az-zarʿu baʿda al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 355,
    arabic: 'طَافَ الْحَاجُّ حَوْلَ الْكَعْبَةِ.',
    german: 'Der Pilger umrundete die Kaaba.',
    transliteration: 'Ṭāfa al-ḥāǧǧu ḥawla al-kaʿbati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 356,
    arabic: 'سَجَدَ الرَّجُلُ لِلَّهِ.',
    german: 'Der Mann warf sich vor Allah nieder.',
    transliteration: 'Saǧada ar-raǧulu lillāhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 357,
    arabic: 'حَمَى الرَّجُلُ بَيْتَهُ.',
    german: 'Der Mann schützte sein Haus.',
    transliteration: 'Ḥamā ar-raǧulu baytahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 358,
    arabic: 'وَلِيَ الرَّجُلُ أَمْرَ الْقَوْمِ.',
    german: 'Der Mann übernahm die Verwaltung des Volkes.',
    transliteration: 'Waliya ar-raǧulu amra al-qawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 359,
    arabic: 'بَنَى الْمُسْلِمُونَ مَسْجِدًا.',
    german: 'Die Muslime bauten eine Moschee.',
    transliteration: 'Banā al-muslimūna masǧidan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 360,
    arabic: 'حَمَلَ الْجُنْدِيُّ رُمْحًا.',
    german: 'Der Soldat trug einen Speer.',
    transliteration: 'Ḥamala al-ǧundiyyu rumḥan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonThirtySevenStory = [
  Sentence(
    wordId: 361,
    arabic: 'أَعْطَى الرَّجُلُ زَكَاةَ مَالِهِ.',
    german: 'Der Mann gab die Zakat seines Vermögens.',
    transliteration: 'Aʿṭā ar-raǧulu zakāta mālihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 362,
    arabic: 'كَانَ الرَّجُلُ إِمَامًا لِقَوْمِهِ.',
    german: 'Der Mann war ein Anführer seines Volkes.',
    transliteration: 'Kāna ar-raǧulu imāman li-qawmihi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 363,
    arabic: 'كَانَ الرَّجُلُ خَلِيفَةَ الْمَلِكِ.',
    german: 'Der Mann war der Nachfolger des Königs.',
    transliteration: 'Kāna ar-raǧulu ḫalīfata al-maliki.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 364,
    arabic: 'حَارَبَ الْجُنْدِيُّ بِشَجَاعَةٍ.',
    german: 'Der Soldat kämpfte tapfer.',
    transliteration: 'Ḥāraba al-ǧundiyyu bi-šaǧāʿatin.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 365,
    arabic: 'حَمَلَ الْجُنُودُ السِّلَاحَ.',
    german: 'Die Soldaten trugen die Waffe.',
    transliteration: 'Ḥamala al-ǧunūdu as-silāḥa.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 366,
    arabic: 'لَبِسَ الْمَلِكُ التَّاجَ.',
    german: 'Der König trug die Krone.',
    transliteration: 'Labisa al-maliku at-tāǧa.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 367,
    arabic: 'جَلَسَ الْمَلِكُ عَلَى الْعَرْشِ.',
    german: 'Der König saß auf dem Thron.',
    transliteration: 'Ǧalasa al-maliku ʿalā al-ʿarši.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 368,
    arabic: 'بَنَى الْمَلِكُ قَصْرًا.',
    german: 'Der König baute einen Palast.',
    transliteration: 'Banā al-maliku qaṣran.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 369,
    arabic: 'عَمِلَ الرَّجُلُ فِي التِّجَارَةِ.',
    german: 'Der Mann arbeitete im Handel.',
    transliteration: 'ʿAmila ar-raǧulu fī at-tiǧārati.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 370,
    arabic: 'اشْتَرَتِ الْمَرْأَةُ خَاتَمًا مِنْ فِضَّةٍ.',
    german: 'Die Frau kaufte einen Ring aus Silber.',
    transliteration: 'Ištarati al-marʾatu ḫātaman min fiḍḍatin.',
    wordAnalysis: [],
    targetIndex: 4,
  ),
];

final List<Sentence> _lessonThirtyEightStory = [
  Sentence(
    wordId: 371,
    arabic: 'وَجَدَ الرَّجُلُ جَوْهَرًا ثَمِينًا.',
    german: 'Der Mann fand ein wertvolles Juwel.',
    transliteration: 'Waǧada ar-raǧulu ǧawharan ṯamīnan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 372,
    arabic: 'قُدْسُ هَذَا الْمَكَانِ مَعْرُوفٌ.',
    german: 'Die Heiligkeit dieses Ortes ist bekannt.',
    transliteration: 'Qudsu hāḏā al-makāni maʿrūfun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 373,
    arabic: 'كَانَ الرَّجُلُ حَلِيمًا مَعَ أَوْلَادِهِ.',
    german: 'Der Mann war nachsichtig mit seinen Kindern.',
    transliteration: 'Kāna ar-raǧulu ḥalīman maʿa awlādihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 374,
    arabic: 'اللَّهُ رَحِيمٌ بِعِبَادِهِ.',
    german: 'Allah ist barmherzig zu Seinen Dienern.',
    transliteration: 'Allāhu raḥīmun bi-ʿibādihi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 375,
    arabic: 'اللَّهُ غَفُورٌ رَحِيمٌ.',
    german: 'Allah ist sehr vergebend und barmherzig.',
    transliteration: 'Allāhu ġafūrun raḥīmun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 376,
    arabic: 'كَانَ الرَّجُلُ صَابِرًا عَلَى الْأَلَمِ.',
    german: 'Der Mann war geduldig gegenüber dem Schmerz.',
    transliteration: 'Kāna ar-raǧulu ṣābiran ʿalā al-alami.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 377,
    arabic: 'كَانَ الرَّجُلُ شَاكِرًا لِرَبِّهِ.',
    german: 'Der Mann war dankbar gegenüber seinem Herrn.',
    transliteration: 'Kāna ar-raǧulu šākiran li-rabbihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 378,
    arabic: 'هَذَا الرَّجُلُ أَمِينٌ.',
    german: 'Dieser Mann ist vertrauenswürdig.',
    transliteration: 'Hāḏā ar-raǧulu amīnun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 379,
    arabic: 'كَانَ الرَّجُلُ حَكِيمًا.',
    german: 'Der Mann war weise.',
    transliteration: 'Kāna ar-raǧulu ḥakīman.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 380,
    arabic: 'اللَّهُ عَلِيمٌ بِكُلِّ شَيْءٍ.',
    german: 'Allah ist allwissend über alle Dinge.',
    transliteration: 'Allāhu ʿalīmun bi-kulli šayʾin.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonThirtyNineStory = [
  Sentence(
    wordId: 381,
    arabic: 'نَظَمَتِ الْمَرْأَةُ اللُّؤْلُؤَ.',
    german: 'Die Frau reihte die Perlen auf.',
    transliteration: 'Naẓamati al-marʾatu al-luʾluʾa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 382,
    arabic: 'طَالَ شَعْرُهُ.',
    german: 'Sein Haar wurde lang.',
    transliteration: 'Ṭāla šaʿruhu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 383,
    arabic: 'ثَقُلَ الْحَجَرُ عَلَيْهِ.',
    german: 'Der Stein war ihm zu schwer.',
    transliteration: 'Ṯaqula al-ḥaǧaru ʿalayhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 384,
    arabic: 'خَفَّ وَزْنُ الصُّنْدُوقِ.',
    german: 'Das Gewicht der Kiste wurde leicht.',
    transliteration: 'Ḫaffa waznu aṣ-ṣundūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 385,
    arabic: 'حَلَا الطَّعَامُ بِالْعَسَلِ.',
    german: 'Das Essen wurde süß durch den Honig.',
    transliteration: 'Ḥalā aṭ-ṭaʿāmu bil-ʿasali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 386,
    arabic: 'سَاعَدَ الرَّجُلُ صَدِيقَهُ.',
    german: 'Der Mann half seinem Freund.',
    transliteration: 'Sāʿada ar-raǧulu ṣadīqahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 387,
    arabic: 'تَعَلَّمَ الْوَلَدُ الْقِرَاءَةَ.',
    german: 'Der Junge lernte das Lesen.',
    transliteration: 'Taʿallama al-waladu al-qirāʾata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 388,
    arabic: 'تَذَكَّرَ الرَّجُلُ صَدِيقَهُ الْقَدِيمَ.',
    german: 'Der Mann erinnerte sich an seinen alten Freund.',
    transliteration: 'Taḏakkara ar-raǧulu ṣadīqahu al-qadīma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 389,
    arabic: 'سَمِعَ الرَّجُلُ بِأُذُنِهِ.',
    german: 'Der Mann hörte mit seinem Ohr.',
    transliteration: 'Samiʿa ar-raǧulu bi-uḏunihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 390,
    arabic: 'عُنُقُهُ طَوِيلٌ.',
    german: 'Sein Hals ist lang.',
    transliteration: 'ʿUnuquhu ṭawīlun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

final List<Sentence> _lessonFortyStory = [
  Sentence(
    wordId: 391,
    arabic: 'حَمَلَ الرَّجُلُ الْحَقِيبَةَ عَلَى ظَهْرِهِ.',
    german: 'Der Mann trug die Tasche auf seinem Rücken.',
    transliteration: 'Ḥamala ar-raǧulu al-ḥaqībata ʿalā ẓahrihi.',
    wordAnalysis: [],
    targetIndex: 4,
  ),
  Sentence(
    wordId: 392,
    arabic: 'أَلَمٌ فِي بَطْنِهِ.',
    german: 'Ein Schmerz in seinem Bauch.',
    transliteration: 'Alamun fī baṭnihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 393,
    arabic: 'جَرَحَ الرَّجُلُ إِصْبَعَهُ.',
    german: 'Der Mann verletzte seinen Finger.',
    transliteration: 'Ǧaraḥa ar-raǧulu iṣbaʿahu.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 394,
    arabic: 'فَتَحَ الطِّفْلُ فَمَهُ.',
    german: 'Das Kind öffnete seinen Mund.',
    transliteration: 'Fataḥa aṭ-ṭiflu famahu.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 395,
    arabic: 'أَنْفُهُ طَوِيلٌ.',
    german: 'Seine Nase ist lang.',
    transliteration: 'Anfuhu ṭawīlun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 396,
    arabic: 'قَبَّلَتِ الْأُمُّ خَدَّ طِفْلِهَا.',
    german: 'Die Mutter küsste die Wange ihres Kindes.',
    transliteration: 'Qabbalati al-ummu ḫadda ṭiflihā.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 397,
    arabic: 'انْكَسَرَتْ سَاقُهُ.',
    german: 'Sein Bein brach.',
    transliteration: 'Inkasarat sāquhu.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 398,
    arabic: 'وَضَعَ يَدَهُ عَلَى كَتِفِهِ.',
    german: 'Er legte seine Hand auf seine Schulter.',
    transliteration: 'Waḍaʿa yadahu ʿalā katifihi.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 399,
    arabic: 'هَذَا زَوْجِي.',
    german: 'Dies ist mein Ehemann.',
    transliteration: 'Hāḏā zawǧī.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 400,
    arabic: 'كَانَتِ الْعَرُوسُ جَمِيلَةً.',
    german: 'Die Braut war schön.',
    transliteration: 'Kānati al-ʿarūsu ǧamīlatan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonFortyOneStory = [
  Sentence(
    wordId: 401,
    arabic: 'جِلْدُهُ خَشِنٌ.',
    german: 'Seine Haut ist rau.',
    transliteration: 'Ǧilduhu ḫašinun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 402,
    arabic: 'شَفَتُهُ جَافَّةٌ.',
    german: 'Seine Lippe ist trocken.',
    transliteration: 'Šafatuhu ǧāffatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 403,
    arabic: 'كَانَ الْوَلَدُ جَائِعًا.',
    german: 'Der Junge war hungrig.',
    transliteration: 'Kāna al-waladu ǧāʾiʿan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 404,
    arabic: 'كَانَ الرَّجُلُ عَطْشَانَ.',
    german: 'Der Mann war durstig.',
    transliteration: 'Kāna ar-raǧulu ʿaṭšāna.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 405,
    arabic: 'كَانَ الرَّجُلُ مَرِيضًا.',
    german: 'Der Mann war krank.',
    transliteration: 'Kāna ar-raǧulu marīḍan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 406,
    arabic: 'عَادَ الْجُنْدِيُّ سَلِيمًا.',
    german: 'Der Soldat kehrte unversehrt zurück.',
    transliteration: 'ʿĀda al-ǧundiyyu salīman.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 407,
    arabic: 'كَانَ الرَّجُلُ تَعْبَانَ.',
    german: 'Der Mann war müde.',
    transliteration: 'Kāna ar-raǧulu taʿbāna.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 408,
    arabic: 'هَذَا الثَّوْبُ وَسِخٌ.',
    german: 'Dieses Kleid ist schmutzig.',
    transliteration: 'Hāḏā aṯ-ṯawbu wasiḫun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 409,
    arabic: 'هَذَا الطَّعَامُ حَامِضٌ.',
    german: 'Diese Speise ist sauer.',
    transliteration: 'Hāḏā aṭ-ṭaʿāmu ḥāmiḍun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 410,
    arabic: 'كَانَ الْوَلَدُ نَشِيطًا.',
    german: 'Der Junge war aktiv.',
    transliteration: 'Kāna al-waladu našīṭan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonFortyTwoStory = [
  Sentence(
    wordId: 411,
    arabic: 'رَبِحَ الرَّجُلُ فِي التِّجَارَةِ.',
    german: 'Der Mann gewann im Handel.',
    transliteration: 'Rabiḥa ar-raǧulu fī at-tiǧārati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 412,
    arabic: 'غَادَرَ الرَّجُلُ الْمَدِينَةَ.',
    german: 'Der Mann verließ die Stadt.',
    transliteration: 'Ġādara ar-raǧulu al-madīnata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 413,
    arabic: 'حَذَّرَ الْأَبُ ابْنَهُ مِنَ الْخَطَرِ.',
    german: 'Der Vater warnte seinen Sohn vor der Gefahr.',
    transliteration: 'Ḥaḏḏara al-abu ibnahu mina al-ḫaṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 414,
    arabic: 'نَذَرَ الرَّجُلُ أَنْ يَصُومَ.',
    german: 'Der Mann gelobte zu fasten.',
    transliteration: 'Naḏara ar-raǧulu an yaṣūma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 415,
    arabic: 'سَتَرَتِ الْمَرْأَةُ وَجْهَهَا.',
    german: 'Die Frau verhüllte ihr Gesicht.',
    transliteration: 'Satarati al-marʾatu waǧhahā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 416,
    arabic: 'نَجَحَ الطَّالِبُ فِي دَرْسِهِ.',
    german: 'Der Student war erfolgreich in seiner Lektion.',
    transliteration: 'Naǧaḥa aṭ-ṭālibu fī darsihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 417,
    arabic: 'فَشِلَ الرَّجُلُ فِي عَمَلِهِ.',
    german: 'Der Mann scheiterte bei seiner Arbeit.',
    transliteration: 'Fašila ar-raǧulu fī ʿamalihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 418,
    arabic: 'كَمَلَ عَمَلُهُ.',
    german: 'Seine Arbeit wurde vollständig.',
    transliteration: 'Kamala ʿamaluhu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 419,
    arabic: 'زَارَ الرَّجُلُ الطَّبِيبَ.',
    german: 'Der Mann besuchte den Arzt.',
    transliteration: 'Zāra ar-raǧulu aṭ-ṭabība.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 420,
    arabic: 'رَكِبَ الرَّجُلُ الْحِصَانَ.',
    german: 'Der Mann ritt das Pferd.',
    transliteration: 'Rakiba ar-raǧulu al-ḥiṣāna.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonFortyThreeStory = [
  Sentence(
    wordId: 421,
    arabic: 'لَبِسَ الرَّجُلُ قَمِيصًا.',
    german: 'Der Mann trug ein Hemd.',
    transliteration: 'Labisa ar-raǧulu qamīṣan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 422,
    arabic: 'شَرِبَ الرَّجُلُ مِنَ الْكُوبِ.',
    german: 'Der Mann trank aus dem Becher.',
    transliteration: 'Šariba ar-raǧulu mina al-kūbi.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 423,
    arabic: 'وَضَعَتِ الْمَرْأَةُ الطَّعَامَ عَلَى الْمَائِدَةِ.',
    german: 'Die Frau stellte das Essen auf den Tisch.',
    transliteration: 'Waḍaʿati al-marʾatu aṭ-ṭaʿāma ʿalā al-māʾidati.',
    wordAnalysis: [],
    targetIndex: 4,
  ),
  Sentence(
    wordId: 424,
    arabic: 'وَضَعَ الطَّعَامَ فِي الصَّحْنِ.',
    german: 'Er stellte das Essen auf den Teller.',
    transliteration: 'Waḍaʿa aṭ-ṭaʿāma fī aṣ-ṣaḥni.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 425,
    arabic: 'وَضَعَتِ الْمَرْأَةُ الْمِلْحَ فِي الطَّعَامِ.',
    german: 'Die Frau gab Salz in das Essen.',
    transliteration: 'Waḍaʿati al-marʾatu al-milḥa fī aṭ-ṭaʿāmi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 426,
    arabic: 'طَبَخَتِ الْمَرْأَةُ بِالزَّيْتِ.',
    german: 'Die Frau kochte mit Öl.',
    transliteration: 'Ṭabaḫati al-marʾatu biz-zayti.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 427,
    arabic: 'أَكَلَ الطِّفْلُ تُفَّاحَةً.',
    german: 'Das Kind aß einen Apfel.',
    transliteration: 'Akala aṭ-ṭiflu tuffāḥatan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 428,
    arabic: 'أَكَلْنَا عِنَبًا.',
    german: 'Wir aßen Trauben.',
    transliteration: 'Akalnā ʿinaban.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 429,
    arabic: 'أَكَلَ الرَّجُلُ تَمْرًا.',
    german: 'Der Mann aß Datteln.',
    transliteration: 'Akala ar-raǧulu tamran.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 430,
    arabic: 'صَمَّمَ الْمُهَنْدِسُ الْبَيْتَ.',
    german: 'Der Ingenieur entwarf das Haus.',
    transliteration: 'Ṣammama al-muhandisu al-bayta.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonFortyFourStory = [
  Sentence(
    wordId: 431,
    arabic: 'وَضَعَتِ الْمَرْأَةُ السُّكَّرَ فِي الْمَاءِ.',
    german: 'Die Frau gab Zucker ins Wasser.',
    transliteration: 'Waḍaʿati al-marʾatu as-sukkara fī al-māʾi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 432,
    arabic: 'كَتَبَ الْوَلَدُ بِالْقَلَمِ.',
    german: 'Der Junge schrieb mit dem Stift.',
    transliteration: 'Kataba al-waladu bil-qalami.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 433,
    arabic: 'كَانَ الرَّجُلُ سَرِيعًا فِي عَمَلِهِ.',
    german: 'Der Mann war schnell bei seiner Arbeit.',
    transliteration: 'Kāna ar-raǧulu sarīʿan fī ʿamalihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 434,
    arabic: 'هَذَا الْقَمِيصُ رَخِيصٌ.',
    german: 'Dieses Hemd ist billig.',
    transliteration: 'Hāḏā al-qamīṣu raḫīṣun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 435,
    arabic: 'كَانَ الرَّجُلُ لَطِيفًا مَعَ ضُيُوفِهِ.',
    german: 'Der Mann war freundlich zu seinen Gästen.',
    transliteration: 'Kāna ar-raǧulu laṭīfan maʿa ḍuyūfihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 436,
    arabic: 'هَذَا أَمْرٌ عَجِيبٌ.',
    german: 'Dies ist eine erstaunliche Sache.',
    transliteration: 'Hāḏā amrun ʿaǧībun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 437,
    arabic: 'جَاءَ رَجُلٌ غَرِيبٌ إِلَى الْمَدِينَةِ.',
    german: 'Ein fremder Mann kam in die Stadt.',
    transliteration: 'Ǧāʾa raǧulun ġarībun ilā al-madīnati.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 438,
    arabic: 'هُوَ جَدِيرٌ بِالثِّقَةِ.',
    german: 'Er ist des Vertrauens würdig.',
    transliteration: 'Huwa ǧadīrun biṯ-ṯiqati.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 439,
    arabic: 'كَانَ الرَّجُلُ شَهِيرًا فِي مَدِينَتِهِ.',
    german: 'Der Mann war berühmt in seiner Stadt.',
    transliteration: 'Kāna ar-raǧulu šahīran fī madīnatihi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 440,
    arabic: 'كَانَ الطُّلَّابُ حَاضِرِينَ.',
    german: 'Die Studenten waren anwesend.',
    transliteration: 'Kāna aṭ-ṭullābu ḥāḍirīna.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonFortyFiveStory = [
  Sentence(
    wordId: 441,
    arabic: 'قَفَزَ الْوَلَدُ فَوْقَ الْجِدَارِ.',
    german: 'Der Junge sprang über die Mauer.',
    transliteration: 'Qafaza al-waladu fawqa al-ǧidāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 442,
    arabic: 'زَحَفَ الطِّفْلُ عَلَى الْأَرْضِ.',
    german: 'Das Kind kroch auf dem Boden.',
    transliteration: 'Zaḥafa aṭ-ṭiflu ʿalā al-arḍi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 443,
    arabic: 'صَرَخَ الرَّجُلُ مِنَ الْأَلَمِ.',
    german: 'Der Mann schrie vor Schmerz.',
    transliteration: 'Ṣaraḫa ar-raǧulu mina al-alami.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 444,
    arabic: 'هَمَسَ الرَّجُلُ فِي أُذُنِ صَدِيقِهِ.',
    german: 'Der Mann flüsterte ins Ohr seines Freundes.',
    transliteration: 'Hamasa ar-raǧulu fī uḏuni ṣadīqihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 445,
    arabic: 'رَقَصَ الرِّجَالُ فِي الْعُرْسِ.',
    german: 'Die Männer tanzten auf der Hochzeit.',
    transliteration: 'Raqaṣa ar-riǧālu fī al-ʿursi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 446,
    arabic: 'غَنَّى الرَّجُلُ أُغْنِيَةً جَمِيلَةً.',
    german: 'Der Mann sang ein schönes Lied.',
    transliteration: 'Ġannā ar-raǧulu uġniyatan ǧamīlatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 447,
    arabic: 'كَنَسَتِ الْمَرْأَةُ الْبَيْتَ.',
    german: 'Die Frau fegte das Haus.',
    transliteration: 'Kanasati al-marʾatu al-bayta.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 448,
    arabic: 'طَرَقَ الرَّجُلُ الْبَابَ.',
    german: 'Der Mann klopfte an die Tür.',
    transliteration: 'Ṭaraqa ar-raǧulu al-bāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 449,
    arabic: 'غَطَّى الْغَيْمُ السَّمَاءَ.',
    german: 'Die Wolke bedeckte den Himmel.',
    transliteration: 'Ġaṭṭā al-ġaymu as-samāʾa.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 450,
    arabic: 'الصَّيْفُ فَصْلٌ حَارٌّ.',
    german: 'Der Sommer ist eine heiße Jahreszeit.',
    transliteration: 'Aṣ-ṣayfu faṣlun ḥārrun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonFortySixStory = [
  Sentence(
    wordId: 451,
    arabic: 'الصَّيْفُ حَارٌّ.',
    german: 'Der Sommer ist heiß.',
    transliteration: 'Aṣ-ṣayfu ḥārrun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 452,
    arabic: 'الشِّتَاءُ بَارِدٌ.',
    german: 'Der Winter ist kalt.',
    transliteration: 'Aš-šitāʾu bāridun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 453,
    arabic: 'الرَّبِيعُ فَصْلُ الْأَزْهَارِ.',
    german: 'Der Frühling ist die Jahreszeit der Blumen.',
    transliteration: 'Ar-rabīʿu faṣlu al-azhāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 454,
    arabic: 'تَسْقُطُ الْأَوْرَاقُ فِي الْخَرِيفِ.',
    german: 'Die Blätter fallen im Herbst.',
    transliteration: 'Tasquṭu al-awrāqu fī al-ḫarīfi.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 455,
    arabic: 'رَأَيْنَا الْهِلَالَ فِي السَّمَاءِ.',
    german: 'Wir sahen die Mondsichel am Himmel.',
    transliteration: 'Raʾaynā al-hilāla fī as-samāʾi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 456,
    arabic: 'ذَهَبْنَا إِلَى الْغَابَةِ.',
    german: 'Wir gingen in den Wald.',
    transliteration: 'Ḏahabnā ilā al-ġābati.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 457,
    arabic: 'جَلَسَ الرَّجُلُ عَلَى الصَّخْرَةِ.',
    german: 'Der Mann saß auf dem Felsen.',
    transliteration: 'Ǧalasa ar-raǧulu ʿalā aṣ-ṣaḫrati.',
    wordAnalysis: [],
    targetIndex: 3,
  ),
  Sentence(
    wordId: 458,
    arabic: 'اسْتَيْقَظْنَا عِنْدَ الْفَجْرِ.',
    german: 'Wir wachten bei Morgendämmerung auf.',
    transliteration: 'Istayqaẓnā ʿinda al-faǧri.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 459,
    arabic: 'أَكَلْنَا عِنْدَ الظُّهْرِ.',
    german: 'Wir aßen zu Mittag.',
    transliteration: 'Akalnā ʿinda aẓ-ẓuhri.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 460,
    arabic: 'زُرْنَا صَدِيقَنَا مَسَاءً.',
    german: 'Wir besuchten unseren Freund am Abend.',
    transliteration: 'Zurnā ṣadīqanā masāʾan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonFortySevenStory = [
  Sentence(
    wordId: 461,
    arabic: 'رَأَيْنَا ضَوْءًا فِي الظَّلَامِ.',
    german: 'Wir sahen ein Licht in der Dunkelheit.',
    transliteration: 'Raʾaynā ḍawʾan fī aẓ-ẓalāmi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 462,
    arabic: 'جَلَسْنَا فِي ظِلِّ الشَّجَرَةِ.',
    german: 'Wir saßen im Schatten des Baumes.',
    transliteration: 'Ǧalasnā fī ẓilli aš-šaǧarati.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 463,
    arabic: 'هَذَا الْقَمِيصُ أَحْمَرُ.',
    german: 'Dieses Hemd ist rot.',
    transliteration: 'Hāḏā al-qamīṣu aḥmaru.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 464,
    arabic: 'السَّمَاءُ زَرْقَاءُ.',
    german: 'Der Himmel ist blau.',
    transliteration: 'As-samāʾu zarqāʾu.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 465,
    arabic: 'الشَّمْسُ صَفْرَاءُ.',
    german: 'Die Sonne ist gelb.',
    transliteration: 'Aš-šamsu ṣafrāʾu.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 466,
    arabic: 'الْعُشْبُ أَخْضَرُ.',
    german: 'Das Gras ist grün.',
    transliteration: 'Al-ʿušbu aḫḍaru.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 467,
    arabic: 'هَذَا الْقِطُّ أَسْوَدُ.',
    german: 'Diese Katze ist schwarz.',
    transliteration: 'Hāḏā al-qiṭṭu aswadu.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 468,
    arabic: 'الثَّلْجُ أَبْيَضُ.',
    german: 'Der Schnee ist weiß.',
    transliteration: 'Aṯ-ṯalǧu abyaḍu.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 469,
    arabic: 'هَذَا الْخُبْزُ جَافٌّ.',
    german: 'Dieses Brot ist trocken.',
    transliteration: 'Hāḏā al-ḫubzu ǧāffun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 470,
    arabic: 'كَانَتِ الْحَقِيبَةُ ثَقِيلَةً.',
    german: 'Die Tasche war schwer.',
    transliteration: 'Kānati al-ḥaqībatu ṯaqīlatan.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
];

final List<Sentence> _lessonFortyEightStory = [
  Sentence(
    wordId: 471,
    arabic: 'اِخْتَارَ الرَّجُلُ الطَّرِيقَ الْقَصِيرَ.',
    german: 'Der Mann wählte den kurzen Weg.',
    transliteration: 'Iḫtāra ar-raǧulu aṭ-ṭarīqa al-qaṣīra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 472,
    arabic: 'اسْتَمَعَ الطُّلَّابُ إِلَى الْمُعَلِّمِ.',
    german: 'Die Studenten hörten dem Lehrer zu.',
    transliteration: 'Istamaʿa aṭ-ṭullābu ilā al-muʿallimi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 473,
    arabic: 'أَصْلَحَ الرَّجُلُ الْبَابَ.',
    german: 'Der Mann reparierte die Tür.',
    transliteration: 'Aṣlaḥa ar-raǧulu al-bāba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 474,
    arabic: 'رَسَمَ الْوَلَدُ بَيْتًا.',
    german: 'Der Junge zeichnete ein Haus.',
    transliteration: 'Rasama al-waladu baytan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 475,
    arabic: 'اعْتَذَرَ الرَّجُلُ عَنْ تَأَخُّرِهِ.',
    german: 'Der Mann entschuldigte sich für seine Verspätung.',
    transliteration: 'Iʿtaḏara ar-raǧulu ʿan taʾaḫḫurihi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 476,
    arabic: 'اِسْتَقْبَلَ الرَّجُلُ ضُيُوفَهُ.',
    german: 'Der Mann empfing seine Gäste.',
    transliteration: 'Istaqbala ar-raǧulu ḍuyūfahu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 477,
    arabic: 'هَدَمَ الْعُمَّالُ الْبَيْتَ الْقَدِيمَ.',
    german: 'Die Arbeiter rissen das alte Haus ab.',
    transliteration: 'Hadama al-ʿummālu al-bayta al-qadīma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 478,
    arabic: 'نَحَتَ الرَّجُلُ تِمْثَالًا مِنَ الْحَجَرِ.',
    german: 'Der Mann schnitzte eine Statue aus Stein.',
    transliteration: 'Naḥata ar-raǧulu timṯālan mina al-ḥaǧari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 479,
    arabic: 'زَارَ الْوَلَدُ جَدَّهُ.',
    german: 'Der Junge besuchte seinen Großvater.',
    transliteration: 'Zāra al-waladu ǧaddahu.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 480,
    arabic: 'طَبَخَتِ الْجَدَّةُ طَعَامًا لَذِيذًا.',
    german: 'Die Großmutter kochte leckeres Essen.',
    transliteration: 'Ṭabaḫati al-ǧaddatu ṭaʿāman laḏīḏan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonFortyNineStory = [
  Sentence(
    wordId: 481,
    arabic: 'لِلْجَدِّ حَفِيدٌ صَغِيرٌ.',
    german: 'Der Großvater hat einen kleinen Enkel.',
    transliteration: 'Lil-ǧaddi ḥafīdun ṣaġīrun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 482,
    arabic: 'لِي أُخْتٌ صَغِيرَةٌ.',
    german: 'Ich habe eine kleine Schwester.',
    transliteration: 'Lī uḫtun ṣaġīratun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 483,
    arabic: 'زَارَنَا عَمِّي أَمْسِ.',
    german: 'Mein Onkel besuchte uns gestern.',
    transliteration: 'Zāranā ʿammī amsi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 484,
    arabic: 'يَعْمَلُ خَالِي فِي التِّجَارَةِ.',
    german: 'Mein Onkel arbeitet im Handel.',
    transliteration: 'Yaʿmalu ḫālī fī at-tiǧārati.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 485,
    arabic: 'زَوْجَتُهُ مُعَلِّمَةٌ.',
    german: 'Seine Ehefrau ist Lehrerin.',
    transliteration: 'Zawǧatuhu muʿallimatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 486,
    arabic: 'وَضَعَ الرَّجُلُ يَدَهُ عَلَى صَدْرِهِ.',
    german: 'Der Mann legte seine Hand auf seine Brust.',
    transliteration: 'Waḍaʿa ar-raǧulu yadahu ʿalā ṣadrihi.',
    wordAnalysis: [],
    targetIndex: 4,
  ),
  Sentence(
    wordId: 487,
    arabic: 'كَسَرَ الْوَلَدُ رِجْلَهُ.',
    german: 'Der Junge brach sich das Bein.',
    transliteration: 'Kasara al-waladu riǧlahu.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 488,
    arabic: 'كَانَ الرَّجُلُ رَئِيسَ الْقَرْيَةِ.',
    german: 'Der Mann war der Anführer des Dorfes.',
    transliteration: 'Kāna ar-raǧulu raʾīsa al-qaryati.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 489,
    arabic: 'عَمِلَ الْعَامِلُ فِي الْمَصْنَعِ.',
    german: 'Der Arbeiter arbeitete in der Fabrik.',
    transliteration: 'ʿAmila al-ʿāmilu fī al-maṣnaʿi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 490,
    arabic: 'زَرَعَ الْفَلَّاحُ الْقَمْحَ.',
    german: 'Der Bauer pflanzte den Weizen.',
    transliteration: 'Zaraʿa al-fallāḥu al-qamḥa.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];

final List<Sentence> _lessonFiftyStory = [
  Sentence(
    wordId: 491,
    arabic: 'لِلْكَلْبِ ذَنَبٌ طَوِيلٌ.',
    german: 'Der Hund hat einen langen Schwanz.',
    transliteration: 'Lil-kalbi ḏanabun ṭawīlun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 492,
    arabic: 'كَتَبَ الرَّجُلُ بِالْحِبْرِ الْأَسْوَدِ.',
    german: 'Der Mann schrieb mit schwarzer Tinte.',
    transliteration: 'Kataba ar-raǧulu bil-ḥibri al-aswadi.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 493,
    arabic: 'الرَّجُلُ مَشْغُولٌ الْيَوْمَ.',
    german: 'Der Mann ist heute beschäftigt.',
    transliteration: 'Ar-raǧulu mašġūlun al-yawma.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 494,
    arabic: 'الْكُوبُ فَارِغٌ.',
    german: 'Der Becher ist leer.',
    transliteration: 'Al-kūbu fāriġun.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 495,
    arabic: 'الْجَبَلُ عَالٍ جِدًّا.',
    german: 'Der Berg ist sehr hoch.',
    transliteration: 'Al-ǧabalu ʿālin ǧiddan.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 496,
    arabic: 'هَذَا الْجَبَلُ مُنْخَفِضٌ.',
    german: 'Dieser Berg ist niedrig.',
    transliteration: 'Hāḏā al-ǧabalu munḫafiḍun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 497,
    arabic: 'الْكُوبُ مُمْتَلِئٌ بِالْمَاءِ.',
    german: 'Der Becher ist voll mit Wasser.',
    transliteration: 'Al-kūbu mumtaliʾun bil-māʾi.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
  Sentence(
    wordId: 498,
    arabic: 'لَهُ بَيْتٌ خَاصٌّ.',
    german: 'Er hat ein privates Haus.',
    transliteration: 'Lahu baytun ḫāṣṣun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 499,
    arabic: 'هَذَا طَرِيقٌ عَامٌّ.',
    german: 'Dies ist ein öffentlicher Weg.',
    transliteration: 'Hāḏā ṭarīqun ʿāmmun.',
    wordAnalysis: [],
    targetIndex: 2,
  ),
  Sentence(
    wordId: 500,
    arabic: 'الْبَحْرُ سَاكِنٌ الْيَوْمَ.',
    german: 'Das Meer ist heute ruhig.',
    transliteration: 'Al-baḥru sākinun al-yawma.',
    wordAnalysis: [],
    targetIndex: 1,
  ),
];
/// Die eigenständige Kurzgeschichte der Geschichten-Stufe
/// ([QuizStage.story]) der Lektion 101 (word_ids 1001–1010): eine kompakte,
/// zusammenhängende Erzählung — „Die gescheiterte Expedition“. Ein Mann
/// beschliesst eine Seereise, bereitet alles vor, doch die Expedition endet
/// tragisch. Jeder Satz verwendet genau eines der zehn gelernten Verben.
final List<Sentence> _lessonHundredOneStory = [
  Sentence(
    wordId: 1003,
    arabic: 'عَزَمَ الرَّجُلُ عَلَى رِحْلَةٍ بَحْرِيَّةٍ.',
    german: 'Der Mann beschloss eine Seereise.',
    transliteration: 'ʿAzama ar-raǧulu ʿalā riḥlatin baḥriyyatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1008,
    arabic: 'أَعَدَّ الرَّجُلُ السَّفِينَةَ لِلرِّحْلَةِ.',
    german: 'Der Mann bereitete das Schiff für die Reise vor.',
    transliteration: 'ʾAʿadda ar-raǧulu as-safīnata lir-riḥlati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1004,
    arabic: 'رَغِبَ الرَّجُلُ فِي السَّفَرِ إِلَى جَزِيرَةٍ.',
    german: 'Der Mann wünschte, zu einer Insel zu reisen.',
    transliteration: 'Raġiba ar-raǧulu fī as-safari ʾilā ǧazīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1002,
    arabic: 'عَرَضَ الرَّجُلُ خِطَّتَهُ عَلَى الْأَصْدِقَاءِ.',
    german: 'Der Mann zeigte den Freunden seinen Plan.',
    transliteration: 'ʿAraḍa ar-raǧulu ḫiṭṭatahū ʿalā al-ʾaṣdiqāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1010,
    arabic: 'اِخْتَلَفَ الْأَصْدِقَاءُ فِي الرَّأْيِ حَوْلَ الرِّحْلَةِ.',
    german: 'Die Freunde waren unterschiedlicher Meinung über die Reise.',
    transliteration: 'Iḫtalafa al-ʾaṣdiqāʾu fī ar-raʾyi ḥawla ar-riḥlati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1009,
    arabic: 'سَمَحَ الْأَبُ لِابْنِهِ بِالذَّهَابِ.',
    german: 'Der Vater erlaubte seinem Sohn zu gehen.',
    transliteration: 'Samaḥa al-ʾabu li-ibnihī bi-aḏ-ḏahābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1001,
    arabic: 'حَاوَلَ الرَّجُلُ أَنْ يُبْحِرَ فِي الْبَحْرِ.',
    german: 'Der Mann versuchte, im Meer zu segeln.',
    transliteration: 'Ḥāwala ar-raǧulu ʾan yubḥira fī al-baḥri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1005,
    arabic: 'اِنْفَجَرَتِ السَّفِينَةُ فِي وَسَطِ الْبَحْرِ.',
    german: 'Das Schiff explodierte mitten im Meer.',
    transliteration: 'Infaǧarati as-safīnatu fī wasaṭi al-baḥri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1006,
    arabic: 'غَرِقَ الرَّجُلُ فِي الْبَحْرِ الْعَمِيقِ.',
    german: 'Der Mann ertrank im tiefen Meer.',
    transliteration: 'Ġariqa ar-raǧulu fī al-baḥri al-ʿamīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1007,
    arabic: 'أَدَّى الْأَبُ أَمَانَتَهُ بِصَبْرٍ.',
    german: 'Der Vater erfüllte seine Pflicht mit Geduld.',
    transliteration: 'ʾAddā al-ʾabu ʾamānatahū bi-ṣabrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];
/// Lektion 102 (word_ids 1011–1020): „Der Geschäftswettbewerb".
/// Ein Student beginnt ein Geschäftsprojekt, Freunde machen mit, am Ende
/// profitieren alle. Jeder Satz verwendet genau eines der zehn gelernten Verben.
final List<Sentence> _lessonHundredTwoStory = [
  Sentence(
    wordId: 1014,
    arabic: 'اِبْتَدَأَ الطَّالِبُ مَشْرُوعًا تِجَارِيًّا.',
    german: 'Der Student begann ein Geschäftsprojekt.',
    transliteration: 'Ibtadaʾa aṭ-ṭālibu mašrūʿan tiǧāriyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1016,
    arabic: 'اِقْتَرَحَ الطَّالِبُ فِكْرَتَهُ عَلَى الْأَصْدِقَاءِ.',
    german: 'Der Student schlug seine Idee den Freunden vor.',
    transliteration: 'Iqtaraḥa aṭ-ṭālibu fikratahū ʿalā al-ʾaṣdiqāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1017,
    arabic: 'شَارَكَ الْأَصْدِقَاءُ فِي الْمَشْرُوعِ الْجَدِيدِ.',
    german: 'Die Freunde nahmen am neuen Projekt teil.',
    transliteration: 'Šāraka al-ʾaṣdiqāʾu fī al-mašrūʿi al-ǧadīdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1018,
    arabic: 'أَضَافَ الْأَصْدِقَاءُ أَفْكَارًا جَدِيدَةً لِلْمَشْرُوعِ.',
    german: 'Die Freunde fügten neue Ideen für das Projekt hinzu.',
    transliteration: 'ʾAḍāfa al-ʾaṣdiqāʾu ʾafkāran ǧadīdatan lil-mašrūʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1011,
    arabic: 'صَرَفَ الطَّالِبُ الْمَالَ عَلَى الْمَشْرُوعِ.',
    german: 'Der Student gab das Geld für das Projekt aus.',
    transliteration: 'Ṣarafa aṭ-ṭālibu al-māla ʿalā al-mašrūʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1015,
    arabic: 'أَعْلَنَ الطَّالِبُ بَدْءَ الْعَمَلِ فِي الْمَشْرُوعِ.',
    german: 'Der Student kündigte den Beginn der Arbeit am Projekt an.',
    transliteration: 'ʾAʿlana aṭ-ṭālibu badʾa al-ʿamali fī al-mašrūʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1012,
    arabic: 'شَاهَدَ النَّاسُ الْمَشْرُوعَ الْجَمِيلَ.',
    german: 'Die Leute sahen das schöne Projekt.',
    transliteration: 'Šāhada an-nāsu al-mašrūʿa al-ǧamīla.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1013,
    arabic: 'اِعْتَرَفَ الطَّالِبُ بِفَضْلِ أَصْدِقَائِهِ.',
    german: 'Der Student gab das Verdienst seiner Freunde zu.',
    transliteration: 'Iʿtarafa aṭ-ṭālibu bi-faḍli ʾaṣdiqāʾihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1019,
    arabic: 'اِسْتَفَادَ الْجَمِيعُ مِنَ الْمَشْرُوعِ النَّاجِحِ.',
    german: 'Alle profitierten von dem erfolgreichen Projekt.',
    transliteration: 'Istatāda al-ǧamīʿu mina al-mašrūʿi an-nāǧiḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1020,
    arabic: 'هَبَطَتِ الْأَسْعَارُ فِي السُّوقِ بِسَبَبِ الْمَشْرُوعِ.',
    german: 'Die Preise sanken auf dem Markt wegen des Projekts.',
    transliteration: 'Habaṭati al-ʾasʿāru fī as-sūqi bisababi al-mašrūʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 103 (word_ids 1021–1030): „Die Dürre im Dorf".
/// Nach einer Dürre trocknet alles aus, doch mit Regen füllt sich das
/// Leben wieder. Jeder Satz verwendet genau eines der zehn gelernten Verben.
final List<Sentence> _lessonHundredThreeStory = [
  Sentence(
    wordId: 1021,
    arabic: 'يَبِسَتِ الْأَرْضُ بَعْدَ الْجَفَافِ الطَّوِيلِ.',
    german: 'Die Erde trocknete nach der langen Dürre aus.',
    transliteration: 'Yabisati al-ʾarḍu baʿda al-ǧafāfi aṭ-ṭawīli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1022,
    arabic: 'اِمْتَلَأَتِ السُّوقُ بِالنَّاسِ بَعْدَ الْمَطَرِ.',
    german: 'Der Markt füllte sich nach dem Regen mit Menschen.',
    transliteration: 'Imtalaʾati as-sūqu bi-n-nāsi baʿda al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1023,
    arabic: 'اِسْتَحَقَّ الْفَلَّاحُ الْمَدْحَ بِعَمَلِهِ.',
    german: 'Der Bauer verdiente das Lob für seine Arbeit.',
    transliteration: 'Istaḥaqqa al-fallāḥu al-madḥa bi-ʿamalihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1024,
    arabic: 'اِنْقَطَعَ الْحَبْلُ فِي وَسَطِ الْبِئْرِ.',
    german: 'Das Seil riss mitten am Brunnen ab.',
    transliteration: 'Inqaṭaʿa al-ḥablu fī wasaṭi al-biʾri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1025,
    arabic: 'تَغَيَّرَ الْجَوُّ بَعْدَ أَيَّامٍ قَلِيلَةٍ.',
    german: 'Das Wetter änderte sich nach wenigen Tagen.',
    transliteration: 'Taġayyara al-ǧawwu baʿda ʾayyāmin qalīlatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1026,
    arabic: 'رَفَضَ الْفَلَّاحُ الِاسْتِسْلَامَ لِلْجَفَافِ.',
    german: 'Der Bauer lehnte es ab, sich der Dürre zu ergeben.',
    transliteration: 'Rafaḍa al-fallāḥu al-istislāma lil-ǧafāfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1027,
    arabic: 'اِنْكَسَرَ الْإِنَاءُ فِي الْبِئْرِ الْعَمِيقَةِ.',
    german: 'Das Gefäß zerbrach im tiefen Brunnen.',
    transliteration: 'Inkasara al-ʾināʾu fī al-biʾri al-ʿamīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1028,
    arabic: 'اِعْتَنَى الْفَلَّاحُ بِأَرْضِهِ بِصَبْرٍ كَبِيرٍ.',
    german: 'Der Bauer kümmerte sich mit großer Geduld um sein Land.',
    transliteration: 'Iʿtanā al-fallāḥu bi-ʾarḍihī bi-ṣabrin kabīrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1029,
    arabic: 'هَدَّدَ الْجَفَافُ الْحَيَاةَ فِي الْقَرْيَةِ.',
    german: 'Die Dürre bedrohte das Leben im Dorf.',
    transliteration: 'Haddada al-ǧafāfu al-ḥayāta fī al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1030,
    arabic: 'أَنْجَزَ الْفَلَّاحُ الْعَمَلَ قَبْلَ الْمَطَرِ.',
    german: 'Der Bauer erledigte die Arbeit vor dem Regen.',
    transliteration: 'ʾAnǧaza al-fallāḥu al-ʿamala qabla al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];
