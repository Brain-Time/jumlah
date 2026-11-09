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
      case 103:
        return _lessonHundredFourStory;
      case 104:
        return _lessonHundredFiveStory;
      case 105:
        return _lessonHundredSixStory;
      case 106:
        return _lessonHundredSevenStory;
      case 107:
        return _lessonHundredEightStory;
      case 108:
        return _lessonHundredNineStory;
      case 109:
        return _lessonHundredTenStory;
      case 110:
        return _lessonHundredElevenStory;
      case 111:
        return _lessonHundredTwelveStory;
      case 112:
        return _lessonHundredThirteenStory;
      case 113:
        return _lessonHundredFourteenStory;
      case 114:
        return _lessonHundredFifteenStory;
      case 115:
        return _lessonHundredSixteenStory;
      case 116:
        return _lessonHundredSeventeenStory;
      case 117:
        return _lessonHundredEighteenStory;
      case 118:
        return _lessonHundredNineteenStory;
      case 119:
        return _lessonHundredTwentyStory;
      case 120:
        return _lessonHundredTwentyOneStory;
      case 121:
        return _lessonHundredTwentyTwoStory;
      case 122:
        return _lessonHundredTwentyThreeStory;
      case 123:
        return _lessonHundredTwentyFourStory;
      case 124:
        return _lessonHundredTwentyFiveStory;
      case 125:
        return _lessonHundredTwentySixStory;
      case 126:
        return _lessonHundredTwentySevenStory;
      case 127:
        return _lessonHundredTwentyEightStory;
      case 128:
        return _lessonHundredTwentyNineStory;
      case 129:
        return _lessonHundredThirtyStory;
      case 130:
        return _lessonHundredThirtyOneStory;
      case 131:
        return _lessonHundredThirtyTwoStory;
      case 132:
        return _lessonHundredThirtyThreeStory;
      case 133:
        return _lessonHundredThirtyFourStory;
      case 134:
        return _lessonHundredThirtyFiveStory;
      case 135:
        return _lessonHundredThirtySixStory;
      case 136:
        return _lessonHundredThirtySevenStory;
      case 137:
        return _lessonHundredThirtyEightStory;
      case 138:
        return _lessonHundredThirtyNineStory;
      case 139:
        return _lessonHundredFortyStory;
      case 140:
        return _lessonHundredFortyOneStory;
      case 141:
        return _lessonHundredFortyTwoStory;
      case 142:
        return _lessonHundredFortyThreeStory;
      case 143:
        return _lessonHundredFortyFourStory;
      case 144:
        return _lessonHundredFortyFiveStory;
      case 145:
        return _lessonHundredFortySixStory;
      case 146:
        return _lessonHundredFortySevenStory;
      case 147:
        return _lessonHundredFortyEightStory;
      case 148:
        return _lessonHundredFortyNineStory;
      case 149:
        return _lessonHundredFiftyStory;
      case 150:
        return _lessonHundredFiftyOneStory;
      case 151:
        return _lessonHundredFiftyTwoStory;
      case 152:
        return _lessonHundredFiftyThreeStory;
      case 153:
        return _lessonHundredFiftyFourStory;
      case 154:
        return _lessonHundredFiftyFiveStory;
      case 155:
        return _lessonHundredFiftySixStory;
      case 156:
        return _lessonHundredFiftySevenStory;
      case 157:
        return _lessonHundredFiftyEightStory;
      case 158:
        return _lessonHundredFiftyNineStory;
      case 159:
        return _lessonHundredSixtyStory;
      case 160:
        return _lessonHundredSixtyOneStory;
      case 161:
        return _lessonHundredSixtyTwoStory;
      case 162:
        return _lessonHundredSixtyThreeStory;
      case 163:
        return _lessonHundredSixtyFourStory;
      case 164:
        return _lessonHundredSixtyFiveStory;
      case 165:
        return _lessonHundredSixtySixStory;
      case 166:
        return _lessonHundredSixtySevenStory;
      case 167:
        return _lessonHundredSixtyEightStory;
      case 168:
        return _lessonHundredSixtyNineStory;
      case 169:
        return _lessonHundredSeventyStory;
      case 170:
        return _lessonHundredSeventyOneStory;
      case 171:
        return _lessonHundredSeventyTwoStory;
      case 172:
        return _lessonHundredSeventyThreeStory;
      case 173:
        return _lessonHundredSeventyFourStory;
      case 174:
        return _lessonHundredSeventyFiveStory;
      case 175:
        return _lessonHundredSeventySixStory;
      case 176:
        return _lessonHundredSeventySevenStory;
      case 177:
        return _lessonHundredSeventyEightStory;
      case 178:
        return _lessonHundredSeventyNineStory;
      case 179:
        return _lessonHundredEightyStory;
      case 180:
        return _lessonHundredEightyOneStory;
      case 181:
        return _lessonHundredEightyTwoStory;
      case 182:
        return _lessonHundredEightyThreeStory;
      case 183:
        return _lessonHundredEightyFourStory;
      case 184:
        return _lessonHundredEightyFiveStory;
      case 185:
        return _lessonHundredEightySixStory;
      case 186:
        return _lessonHundredEightySevenStory;
      case 187:
        return _lessonHundredEightyEightStory;
      case 188:
        return _lessonHundredEightyNineStory;
      case 189:
        return _lessonHundredNinetyStory;
      case 190:
        return _lessonHundredNinetyOneStory;
      case 191:
        return _lessonHundredNinetyTwoStory;
      case 192:
        return _lessonHundredNinetyThreeStory;
      case 193:
        return _lessonHundredNinetyFourStory;
      case 194:
        return _lessonHundredNinetyFiveStory;
      case 195:
        return _lessonHundredNinetySixStory;
      case 196:
        return _lessonHundredNinetySevenStory;
      case 197:
        return _lessonHundredNinetyEightStory;
      case 198:
        return _lessonHundredNinetyNineStory;
      case 199:
        return _lessonTwoHundredStory;
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
      _lessonHundredFourStory,
      _lessonHundredFiveStory,
      _lessonHundredSixStory,
      _lessonHundredSevenStory,
      _lessonHundredEightStory,
      _lessonHundredNineStory,
      _lessonHundredTenStory,
      _lessonHundredElevenStory,
      _lessonHundredTwelveStory,
      _lessonHundredThirteenStory,
      _lessonHundredFourteenStory,
      _lessonHundredFifteenStory,
      _lessonHundredSixteenStory,
      _lessonHundredSeventeenStory,
      _lessonHundredEighteenStory,
      _lessonHundredNineteenStory,
      _lessonHundredTwentyStory,
      _lessonHundredTwentyOneStory,
      _lessonHundredTwentyTwoStory,
      _lessonHundredTwentyThreeStory,
      _lessonHundredTwentyFourStory,
      _lessonHundredTwentyFiveStory,
      _lessonHundredTwentySixStory,
      _lessonHundredTwentySevenStory,
      _lessonHundredTwentyEightStory,
      _lessonHundredTwentyNineStory,
      _lessonHundredThirtyStory,
      _lessonHundredThirtyOneStory,
      _lessonHundredThirtyTwoStory,
      _lessonHundredThirtyThreeStory,
      _lessonHundredThirtyFourStory,
      _lessonHundredThirtyFiveStory,
      _lessonHundredThirtySixStory,
      _lessonHundredThirtySevenStory,
      _lessonHundredThirtyEightStory,
      _lessonHundredThirtyNineStory,
      _lessonHundredFortyStory,
      _lessonHundredFortyOneStory,
      _lessonHundredFortyTwoStory,
      _lessonHundredFortyThreeStory,
      _lessonHundredFortyFourStory,
      _lessonHundredFortyFiveStory,
      _lessonHundredFortySixStory,
      _lessonHundredFortySevenStory,
      _lessonHundredFortyEightStory,
      _lessonHundredFortyNineStory,
      _lessonHundredFiftyStory,
      _lessonHundredFiftyOneStory,
      _lessonHundredFiftyTwoStory,
      _lessonHundredFiftyThreeStory,
      _lessonHundredFiftyFourStory,
      _lessonHundredFiftyFiveStory,
      _lessonHundredFiftySixStory,
      _lessonHundredFiftySevenStory,
      _lessonHundredFiftyEightStory,
      _lessonHundredFiftyNineStory,
      _lessonHundredSixtyStory,
      _lessonHundredSixtyOneStory,
      _lessonHundredSixtyTwoStory,
      _lessonHundredSixtyThreeStory,
      _lessonHundredSixtyFourStory,
      _lessonHundredSixtyFiveStory,
      _lessonHundredSixtySixStory,
      _lessonHundredSixtySevenStory,
      _lessonHundredSixtyEightStory,
      _lessonHundredSixtyNineStory,
      _lessonHundredSeventyStory,
      _lessonHundredSeventyOneStory,
      _lessonHundredSeventyTwoStory,
      _lessonHundredSeventyThreeStory,
      _lessonHundredSeventyFourStory,
      _lessonHundredSeventyFiveStory,
      _lessonHundredSeventySixStory,
      _lessonHundredSeventySevenStory,
      _lessonHundredSeventyEightStory,
      _lessonHundredSeventyNineStory,
      _lessonHundredEightyStory,
      _lessonHundredEightyOneStory,
      _lessonHundredEightyTwoStory,
      _lessonHundredEightyThreeStory,
      _lessonHundredEightyFourStory,
      _lessonHundredEightyFiveStory,
      _lessonHundredEightySixStory,
      _lessonHundredEightySevenStory,
      _lessonHundredEightyEightStory,
      _lessonHundredEightyNineStory,
      _lessonHundredNinetyStory,
      _lessonHundredNinetyOneStory,
      _lessonHundredNinetyTwoStory,
      _lessonHundredNinetyThreeStory,
      _lessonHundredNinetyFourStory,
      _lessonHundredNinetyFiveStory,
      _lessonHundredNinetySixStory,
      _lessonHundredNinetySevenStory,
      _lessonHundredNinetyEightStory,
      _lessonHundredNinetyNineStory,
      _lessonTwoHundredStory,
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

/// Lektion 104 (word_ids 1031–1040): „Der Wettbewerb um die Stelle".
/// Ein junger Mann tritt in einem Wettbewerb an und gewinnt eine Stelle.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter an erster Stelle.
final List<Sentence> _lessonHundredFourStory = [
  Sentence(
    wordId: 1031,
    arabic: 'اِسْتَكْمَلَ الشَّابُّ دِرَاسَتَهُ قَبْلَ الْمُسَابَقَةِ.',
    german: 'Der junge Mann vervollständigte sein Studium vor dem Wettbewerb.',
    transliteration: 'Istakmala aš-šābbu dirāsatahū qabla al-musābaqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1040,
    arabic: 'مُسَابَقَةٌ كَبِيرَةٌ جَمَعَتِ الشَّبَابَ فِي الْمَدِينَةِ.',
    german: 'Ein großer Wettbewerb versammelte die jungen Leute in der Stadt.',
    transliteration: 'Musābaqatun kabīratun ǧamaʿati aš-šabāba fī al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1034,
    arabic: 'اِمْتَحَنَ الْمُدِيرُ الْمُتَسَابِقِينَ بِأَسْئِلَةٍ صَعْبَةٍ.',
    german: 'Der Direktor prüfte die Teilnehmer mit schwierigen Fragen.',
    transliteration:
        'Imtaḥana al-mudīru al-mutasābiqīna bi-ʾasʾilatin ṣaʿbatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1035,
    arabic: 'أَوْضَحَ الْمُدِيرُ الشُّرُوطَ لِكُلِّ الْمُشَارِكِينَ.',
    german: 'Der Direktor erklärte allen Teilnehmern die Bedingungen.',
    transliteration: 'ʾAwḍaḥa al-mudīru aš-šurūṭa li-kulli al-mušārikīna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1039,
    arabic: 'حُدُودٌ وَاضِحَةٌ تُنَظِّمُ وَقْتَ الْإِجَابَةِ.',
    german: 'Klare Grenzen regeln die Zeit für die Antwort.',
    transliteration: 'Ḥudūdun wāḍiḥatun tunaẓẓimu waqta al-ʾiǧābati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1032,
    arabic: 'أَثَّرَ جَوَابُ الشَّابِّ فِي لَجْنَةِ التَّحْكِيمِ.',
    german: 'Die Antwort des jungen Mannes beeinflusste die Jury.',
    transliteration: 'ʾAṯṯara ǧawābu aš-šābbi fī laǧnati at-taḥkīmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1033,
    arabic: 'عَالَجَ الشَّابُّ الْمَسْأَلَةَ بِهُدُوءٍ وَثِقَةٍ.',
    german:
        'Der junge Mann behandelte die Aufgabe mit Ruhe und Selbstvertrauen.',
    transliteration: 'ʿĀlaǧa aš-šābbu al-masʾalata bi-hudūʾin wa-ṯiqatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1037,
    arabic: 'ثَرْوَةٌ حَقِيقِيَّةٌ هِيَ الْعِلْمُ وَالصَّبْرُ.',
    german: 'Wahrer Reichtum sind Wissen und Geduld.',
    transliteration: 'Ṯarwatun ḥaqīqiyyatun hiya al-ʿilmu wa-ṣ-ṣabru.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1038,
    arabic: 'وِظِيفَةٌ جَيِّدَةٌ كَانَتْ جَائِزَةَ الْفَائِزِ.',
    german: 'Eine gute Stelle war der Preis des Siegers.',
    transliteration: 'Wiẓīfatun ǧayyidatun kānat ǧāʾizata al-fāʾizi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1036,
    arabic: 'مَصِيرٌ جَدِيدٌ بَدَأَ لِلشَّابِّ بَعْدَ الْفَوْزِ.',
    german: 'Ein neues Schicksal begann für den jungen Mann nach dem Sieg.',
    transliteration: 'Maṣīrun ǧadīdun badaʾa li-š-šābbi baʿda al-fawzi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 105 (word_ids 1041–1050): „Der Botschafter in der Stadt".
/// Ein neuer Botschafter besucht ein fremdes Land und lernt Menschen, Natur und Alltag kennen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter an erster Stelle.
final List<Sentence> _lessonHundredFiveStory = [
  Sentence(
    wordId: 1041,
    arabic: 'دَلِيلٌ مَاهِرٌ رَافَقَ السَّفِيرَ فِي الرِّحْلَةِ.',
    german: 'Ein geschickter Führer begleitete den Botschafter auf der Reise.',
    transliteration: 'Dalīlun māhirun rāfaqa as-safīra fī ar-riḥlati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1042,
    arabic: 'سَفِيرٌ جَدِيدٌ وَصَلَ إِلَى الْمَدِينَةِ أَمْسِ.',
    german: 'Ein neuer Botschafter kam gestern in der Stadt an.',
    transliteration: 'Safīrun ǧadīdun waṣala ʾilā al-madīnati ʾamsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1043,
    arabic: 'رَأْيُ السَّفِيرِ كَانَ وَاضِحًا لِلْجَمِيعِ.',
    german: 'Die Meinung des Botschafters war allen klar.',
    transliteration: 'Raʾyu as-safīri kāna wāḍiḥan lil-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1044,
    arabic: 'شُرْطَةٌ كَثِيرَةٌ حَمَتِ الطَّرِيقَ إِلَى الْمَطَارِ.',
    german: 'Viel Polizei schützte den Weg zum Flughafen.',
    transliteration: 'Šurṭatun kaṯīratun ḥamat aṭ-ṭarīqa ʾilā al-maṭāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1045,
    arabic: 'مُوَظَّفٌ فِي السَّفَارَةِ فَتَحَ الْبَابَ لِلضَّيْفِ.',
    german: 'Ein Angestellter der Botschaft öffnete dem Gast die Tür.',
    transliteration: 'Muwaẓẓafun fī as-safārati fataḥa al-bāba lil-ḍayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1046,
    arabic: 'طَبِيعَةُ الْبَلَدِ جَمِيلَةٌ وَهَادِئَةٌ.',
    german: 'Die Natur des Landes ist schön und ruhig.',
    transliteration: 'Ṭabīʿatu al-baladi ǧamīlatun wa-hādiʾatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1047,
    arabic: 'حَيَوَانٌ نَادِرٌ ظَهَرَ قَرِيبًا مِنَ النَّهْرِ.',
    german: 'Ein seltenes Tier zeigte sich nahe am Fluss.',
    transliteration: 'Ḥayawānun nādirun ẓahara qarīban mina an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1048,
    arabic: 'نَبَاتٌ غَرِيبٌ نَمَا فِي الْجَبَلِ.',
    german: 'Eine fremdartige Pflanze wuchs im Gebirge.',
    transliteration: 'Nabātun ġarībun namā fī al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1049,
    arabic: 'مُسْتَشْفًى صَغِيرٌ قَدَّمَ الْمُسَاعَدَةَ لِلزُّوَّارِ.',
    german: 'Ein kleines Krankenhaus bot den Besuchern Hilfe an.',
    transliteration: 'Mustašfan ṣaġīrun qaddama al-musāʿadata liz-zuwwāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1050,
    arabic: 'وَسِيلَةٌ سَرِيعَةٌ أَعَادَتِ السَّفِيرَ إِلَى بَيْتِهِ.',
    german: 'Ein schnelles Mittel brachte den Botschafter nach Hause zurück.',
    transliteration: 'Wasīlatun sarīʿatun ʾaʿādat as-safīra ʾilā baytihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 106 (word_ids 1051–1060): „Der Händler und sein Produkt".
/// Ein Händler bringt ein neues Produkt heraus und verdankt den Erfolg Freunden und guten Beziehungen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter an erster Stelle.
final List<Sentence> _lessonHundredSixStory = [
  Sentence(
    wordId: 1051,
    arabic: 'طَرِيقَةٌ ذَكِيَّةٌ سَاعَدَتِ التَّاجِرَ فِي عَمَلِهِ.',
    german: 'Eine kluge Methode half dem Händler bei seiner Arbeit.',
    transliteration: 'Ṭarīqatun ḏakiyyatun sāʿadat at-tāǧira fī ʿamalihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1052,
    arabic: 'عِلَاقَةٌ طَيِّبَةٌ رَبَطَتِ التَّاجِرَ بِجِيرَانِهِ.',
    german: 'Eine gute Beziehung verband den Händler mit seinen Nachbarn.',
    transliteration: 'ʿIlāqatun ṭayyibatun rabaṭat at-tāǧira bi-ǧīrānihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1053,
    arabic: 'صَدَاقَةٌ قَدِيمَةٌ جَمَعَتْهُ بِرَجُلٍ مِنَ الْقَرْيَةِ.',
    german: 'Eine alte Freundschaft verband ihn mit einem Mann aus dem Dorf.',
    transliteration: 'Ṣadāqatun qadīmatun ǧamaʿathu bi-raǧulin mina al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1054,
    arabic: 'عَدَاوَةٌ قَصِيرَةٌ اِنْتَهَتْ بِكَلِمَةٍ طَيِّبَةٍ.',
    german: 'Eine kurze Feindschaft endete mit einem guten Wort.',
    transliteration: 'ʿAdāwatun qaṣīratun intahat bi-kalimatin ṭayyibatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1055,
    arabic: 'مُنْتَجٌ جَدِيدٌ وَصَلَ إِلَى السُّوقِ.',
    german: 'Ein neues Produkt kam auf den Markt.',
    transliteration: 'Muntaǧun ǧadīdun waṣala ʾilā as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1056,
    arabic: 'هَاتِفٌ صَغِيرٌ رَنَّ فِي الْمَكْتَبِ.',
    german: 'Ein kleines Telefon klingelte im Büro.',
    transliteration: 'Hātifun ṣaġīrun ranna fī al-maktabi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1057,
    arabic: 'اِخْتِبَارٌ صَعْبٌ كَانَ يَنْتَظِرُ الْمُنْتَجَ.',
    german: 'Ein schwerer Test erwartete das Produkt.',
    transliteration: 'Iḫtibārun ṣaʿbun kāna yantaẓiru al-muntaǧa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1058,
    arabic: 'نَصِيحَةٌ مِنْ صَدِيقٍ قَدِيمٍ غَيَّرَتِ الْخُطَّةَ.',
    german: 'Ein Ratschlag eines alten Freundes änderte den Plan.',
    transliteration: 'Naṣīḥatun min ṣadīqin qadīmin ġayyarat al-ḫuṭṭata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1059,
    arabic: 'صَحِيفَةُ الْمَدِينَةِ كَتَبَتْ عَنِ النَّجَاحِ.',
    german: 'Die Zeitung der Stadt schrieb über den Erfolg.',
    transliteration: 'Ṣaḥīfatu al-madīnati katabat ʿani an-naǧāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1060,
    arabic: 'مَجْلِسٌ كَبِيرٌ كَرَّمَ التَّاجِرَ فِي النِّهَايَةِ.',
    german: 'Ein großer Rat ehrte den Händler am Ende.',
    transliteration: 'Maǧlisun kabīrun karrama at-tāǧira fī an-nihāyati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 107 (word_ids 1061–1070): „Die Hochzeitsfeier".
/// Eine Familie bereitet eine Hochzeit vor: Einladungen, Essen und ein großes Fest.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter an erster Stelle.
final List<Sentence> _lessonHundredSevenStory = [
  Sentence(
    wordId: 1061,
    arabic: 'اِجْتِمَاعٌ عَائِلِيٌّ جَرَى فِي بَيْتِ الْجَدِّ.',
    german: 'Ein Familientreffen fand im Haus des Großvaters statt.',
    transliteration: 'Iǧtimāʿun ʿāʾiliyyun ǧarā fī bayti al-ǧaddi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1062,
    arabic: 'مُوَاطِنٌ مِنَ الْحَيِّ أَحْضَرَ الْوُرُودَ.',
    german: 'Ein Bürger aus dem Viertel brachte die Blumen.',
    transliteration: 'Muwāṭinun mina al-ḥayyi ʾaḥḍara al-wurūda.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1063,
    arabic: 'دَعْوَةٌ جَمِيلَةٌ وَصَلَتْ إِلَى كُلِّ الْأَقَارِبِ.',
    german: 'Eine schöne Einladung erreichte alle Verwandten.',
    transliteration: 'Daʿwatun ǧamīlatun waṣalat ʾilā kulli al-ʾaqāribi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1064,
    arabic: 'عَشَاءٌ كَبِيرٌ اِنْتَظَرَ الضُّيُوفَ فِي الْمَسَاءِ.',
    german: 'Ein großes Abendessen erwartete die Gäste am Abend.',
    transliteration: 'ʿAšāʾun kabīrun intaẓara aḍ-ḍuyūfa fī al-masāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1065,
    arabic: 'فُطُورٌ بَسِيطٌ جَمَعَ الْعَائِلَةَ فِي الصَّبَاحِ.',
    german: 'Ein einfaches Frühstück versammelte die Familie am Morgen.',
    transliteration: 'Fuṭūrun basīṭun ǧamaʿa al-ʿāʾilata fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1066,
    arabic: 'حَفْلَةٌ صَغِيرَةٌ أَسْعَدَتِ الْأَطْفَالَ كَثِيرًا.',
    german: 'Eine kleine Feier machte die Kinder sehr glücklich.',
    transliteration: 'Ḥaflatun ṣaġīratun ʾasʿadat al-ʾaṭfāla kaṯīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1067,
    arabic: 'عُرْسٌ جَمِيلٌ وَحَّدَ الْعَائِلَتَيْنِ.',
    german: 'Eine schöne Hochzeit vereinte die beiden Familien.',
    transliteration: 'ʿUrsun ǧamīlun waḥḥada al-ʿāʾilatayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1068,
    arabic: 'سِكِّينٌ حَادٌّ قَطَعَ الْخُبْزَ عَلَى الْمَائِدَةِ.',
    german: 'Ein scharfes Messer schnitt das Brot auf dem Tisch.',
    transliteration: 'Sikkīnun ḥādun qaṭaʿa al-ḫubza ʿalā al-māʾidati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1069,
    arabic: 'شَوْكَةٌ نَظِيفَةٌ كَانَتْ بِجَانِبِ الْكُوبِ.',
    german: 'Eine saubere Gabel lag neben dem Becher.',
    transliteration: 'Šawkatun naẓīfatun kānat bi-ǧānibi al-kūbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1070,
    arabic: 'طَبَقٌ كَبِيرٌ اِمْتَلَأَ بِالْأَرُزِّ.',
    german: 'Ein großer Teller füllte sich mit Reis.',
    transliteration: 'Ṭabaqun kabīrun imtalaʾa bi-l-ʾaruzzi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 108 (word_ids 1071–1080): „Die Köchin und die Regel".
/// In der Küche der Großmutter lernt man Regeln und Grundsätze fürs Leben.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter an erster Stelle.
final List<Sentence> _lessonHundredEightStory = [
  Sentence(
    wordId: 1071,
    arabic: 'مِرْوَحَةٌ قَدِيمَةٌ بَرَّدَتِ الْغُرْفَةَ الْحَارَّةَ.',
    german: 'Ein alter Fächer kühlte den heißen Raum.',
    transliteration: 'Mirwaḥatun qadīmatun barradat al-ġurfata al-ḥārrata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1072,
    arabic: 'وَجْبَةٌ سَاخِنَةٌ جَهَّزَتْهَا الطَّبَّاخَةُ لِلْأَطْفَالِ.',
    german: 'Eine warme Mahlzeit bereitete die Köchin für die Kinder zu.',
    transliteration: 'Waǧbatun sāḫinatun ǧahhazat-hā aṭ-ṭabbāḫatu lil-ʾaṭfāli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1073,
    arabic: 'فِنْجَانٌ صَغِيرٌ وُضِعَ أَمَامَ الْجَدَّةِ.',
    german: 'Eine kleine Tasse wurde vor die Großmutter gestellt.',
    transliteration: 'Finǧānun ṣaġīrun wuḍiʿa ʾamāma al-ǧaddati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1074,
    arabic: 'حَلِيبٌ بَارِدٌ كَانَ فِي الثَّلَّاجَةِ.',
    german: 'Kalte Milch war im Kühlschrank.',
    transliteration: 'Ḥalībun bāridun kāna fī aṯ-ṯallāǧati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1075,
    arabic: 'عَصِيرٌ طَازَجٌ شَرِبَهُ الْأَوْلَادُ بِسُرْعَةٍ.',
    german: 'Frischen Saft tranken die Jungen schnell.',
    transliteration: 'ʿAṣīrun ṭāziǧun šaribahu al-ʾawlādu bi-surʿatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1076,
    arabic: 'مَفْهُومٌ جَدِيدٌ شَرَحَتْهُ الْمُعَلِّمَةُ فِي الدَّرْسِ.',
    german: 'Einen neuen Begriff erklärte die Lehrerin im Unterricht.',
    transliteration: 'Mafhūmun ǧadīdun šaraḥat-hu al-muʿallimatu fī ad-darsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1077,
    arabic: 'مَعْلُومَةٌ مُفِيدَةٌ وَجَدَهَا الطَّالِبُ فِي الْكِتَابِ.',
    german: 'Eine nützliche Information fand der Student im Buch.',
    transliteration: 'Maʿlūmatun mufīdatun waǧadahā aṭ-ṭālibu fī al-kitābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1078,
    arabic: 'خِبْرَةٌ طَوِيلَةٌ جَعَلَتِ الطَّبَّاخَةَ مَاهِرَةً.',
    german: 'Lange Erfahrung machte die Köchin geschickt.',
    transliteration: 'Ḫibratun ṭawīlatun ǧaʿalat aṭ-ṭabbāḫata māhiratan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1079,
    arabic: 'قَاعِدَةٌ بَسِيطَةٌ ذَكَرَتْهَا الْجَدَّةُ لِلْجَمِيعِ.',
    german: 'Eine einfache Regel nannte die Großmutter allen.',
    transliteration: 'Qāʿidatun basīṭatun ḏakarat-hā al-ǧaddatu lil-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1080,
    arabic: 'مَبْدَأٌ ثَابِتٌ حَكَمَ الْمَطْبَخَ كُلَّهُ.',
    german: 'Ein fester Grundsatz bestimmte die ganze Küche.',
    transliteration: 'Mabdaʾun ṯābitun ḥakama al-maṭbaḫa kullahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 109 (word_ids 1081–1090): „Das Experiment im Labor".
/// Ein Gelehrter prüft eine neue Theorie in mehreren Phasen mit einem Versuch.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter an erster Stelle.
final List<Sentence> _lessonHundredNineStory = [
  Sentence(
    wordId: 1081,
    arabic: 'نَظَرِيَّةٌ جَدِيدَةٌ شَرَحَهَا الْعَالِمُ فِي الْمُحَاضَرَةِ.',
    german: 'Eine neue Theorie erklärte der Gelehrte in der Vorlesung.',
    transliteration: 'Naẓariyyatun ǧadīdatun šaraḥahā al-ʿālimu fī al-muḥāḍarati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1082,
    arabic: 'تَجْرِبَةٌ صَغِيرَةٌ أَثْبَتَتِ الْفِكْرَةَ.',
    german: 'Ein kleiner Versuch bestätigte die Idee.',
    transliteration: 'Taǧribatun ṣaġīratun ʾaṯbatat al-fikrata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1083,
    arabic: 'دَرَجَةٌ عَالِيَةٌ ظَهَرَتْ فِي النَّتِيجَةِ.',
    german: 'Ein hoher Grad zeigte sich im Ergebnis.',
    transliteration: 'Daraǧatun ʿāliyatun ẓaharat fī an-natīǧati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1084,
    arabic: 'مَرْحَلَةٌ أُولَى اِنْتَهَتْ بِنَجَاحٍ.',
    german: 'Eine erste Phase endete mit Erfolg.',
    transliteration: 'Marḥalatun ʾūlā intahat bi-naǧāḥin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1085,
    arabic: 'وِحْدَةٌ خَاصَّةٌ قَاسَتِ الْحَرَارَةَ.',
    german: 'Eine besondere Einheit maß die Wärme.',
    transliteration: 'Wiḥdatun ḫāṣṣatun qāsat al-ḥarārata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1086,
    arabic: 'نَوْعٌ آخَرُ مِنَ الْأَوْرَاقِ دَخَلَ الْمُخْتَبَرَ.',
    german: 'Eine andere Sorte Blätter kam ins Labor.',
    transliteration: 'Nawʿun ʾāḫaru mina al-ʾawrāqi daḫala al-muḫtabara.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1087,
    arabic: 'مِقْدَارٌ قَلِيلٌ مِنَ الْمَاءِ كَفَى لِلْعَمَلِ.',
    german: 'Eine geringe Menge Wasser reichte für die Arbeit.',
    transliteration: 'Miqdārun qalīlun mina al-māʾi kafā lil-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1088,
    arabic: 'عَدَدٌ كَبِيرٌ مِنَ الطُّلَّابِ حَضَرَ الْعَرْضَ.',
    german: 'Eine große Zahl von Studenten besuchte die Vorführung.',
    transliteration: 'ʿAdadun kabīrun mina aṭ-ṭullābi ḥaḍara al-ʿarḍa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1089,
    arabic: 'مَصْدَرٌ مَوْثُوقٌ أَكَّدَ الْخَبَرَ.',
    german: 'Eine verlässliche Quelle bestätigte die Nachricht.',
    transliteration: 'Maṣdarun mawṯūqun ʾakkada al-ḫabara.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1090,
    arabic: 'قِيمَةُ الْعِلْمِ أَكْبَرُ مِنْ قِيمَةِ الْمَالِ.',
    german: 'Der Wert des Wissens ist größer als der Wert des Geldes.',
    transliteration: 'Qīmatu al-ʿilmi ʾakbaru min qīmati al-māli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 110 (word_ids 1091–1100): „Der Bergsteiger".
/// Ein Bergsteiger kämpft mit Höhe, Hunger und Schmerz, bis er am Gipfel Kraft findet.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter an erster Stelle.
final List<Sentence> _lessonHundredTenStory = [
  Sentence(
    wordId: 1091,
    arabic: 'سَقْفُ الْكُوخِ حَمَى الرَّجُلَ مِنَ الْمَطَرِ.',
    german: 'Das Dach der Hütte schützte den Mann vor dem Regen.',
    transliteration: 'Saqfu al-kūḫi ḥamā ar-raǧula mina al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1092,
    arabic: 'طَابَقٌ عَالٍ فِي الْفُنْدُقِ كَانَ هَادِئًا.',
    german: 'Ein hohes Stockwerk im Hotel war ruhig.',
    transliteration: 'Ṭābaqun ʿālin fī al-funduqi kāna hādiʾan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1093,
    arabic: 'اِتِّجَاهُ الرِّيحِ تَغَيَّرَ فَجْأَةً.',
    german: 'Die Richtung des Windes änderte sich plötzlich.',
    transliteration: 'Ittiǧāhu ar-rīḥi taġayyara faǧʾatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1094,
    arabic: 'اِرْتِفَاعُ الْجَبَلِ أَتْعَبَ الْمُتَسَلِّقَ.',
    german: 'Die Höhe des Berges erschöpfte den Bergsteiger.',
    transliteration: 'Irtifāʿu al-ǧabali ʾatʿaba al-mutasalliqa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1095,
    arabic: 'أُفُقٌ بَعِيدٌ ظَهَرَ مِنَ الْقِمَّةِ.',
    german: 'Ein ferner Horizont zeigte sich vom Gipfel.',
    transliteration: 'ʾUfuqun baʿīdun ẓahara mina al-qimmati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1096,
    arabic: 'فَضَاءٌ وَاسِعٌ اِمْتَدَّ فَوْقَ رَأْسِهِ.',
    german: 'Ein weiter Raum erstreckte sich über seinem Kopf.',
    transliteration: 'Faḍāʾun wāsiʿun imtadda fawqa raʾsihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1097,
    arabic: 'مَعِدَةُ الْمُتَسَلِّقِ كَانَتْ فَارِغَةً مُنْذُ يَوْمَيْنِ.',
    german: 'Der Magen des Bergsteigers war seit zwei Tagen leer.',
    transliteration: 'Maʿidatu al-mutasalliqi kānat fāriġatan munḏu yawmayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1098,
    arabic: 'قُوَّةٌ جَدِيدَةٌ عَادَتْ إِلَيْهِ بَعْدَ الْأَكْلِ.',
    german: 'Neue Kraft kehrte nach dem Essen zu ihm zurück.',
    transliteration: 'Quwwatun ǧadīdatun ʿādat ʾilayhi baʿda al-ʾakli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1099,
    arabic: 'أَلَمٌ شَدِيدٌ أَصَابَ رِجْلَهُ عِنْدَ النُّزُولِ.',
    german: 'Ein starker Schmerz traf sein Bein beim Abstieg.',
    transliteration: 'ʾAlamun šadīdun ʾaṣāba riǧlahū ʿinda an-nuzūli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1100,
    arabic: 'نَوْمٌ عَمِيقٌ أَخَذَهُ فِي اللَّيْلِ.',
    german: 'Tiefer Schlaf nahm ihn in der Nacht.',
    transliteration: 'Nawmun ʿamīqun ʾaḫaḏahū fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 111 (word_ids 1101–1110): „Der Sturm im Dorf".
/// Ein Unwetter trifft ein Dorf, und die Menschen helfen einander.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredElevenStory = [
  Sentence(
    wordId: 1101,
    arabic: 'أَرْسَلَتِ الْوِزَارَةُ فَرِيقًا إِلَى الْقَرْيَةِ.',
    german: 'Das Ministerium schickte ein Team ins Dorf.',
    transliteration: 'ʾArsalati al-wizāratu farīqan ʾilā al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1102,
    arabic: 'هَذَا شَأْنٌ مُهِمٌّ لِكُلِّ أَهْلِ الْقَرْيَةِ.',
    german: 'Das ist eine wichtige Angelegenheit für alle Dorfbewohner.',
    transliteration: 'Hāḏā šaʾnun muhimmun li-kulli ʾahli al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1103,
    arabic: 'الصَّبْرُ صِفَةٌ جَمِيلَةٌ عِنْدَ الشِّدَّةِ.',
    german: 'Geduld ist eine schöne Eigenschaft in der Not.',
    transliteration: 'Aṣ-ṣabru ṣifatun ǧamīlatun ʿinda aš-šiddati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1104,
    arabic: 'اِجْتَمَعَ النَّاسُ فِي الْقَاعَةِ الْكَبِيرَةِ.',
    german: 'Die Leute versammelten sich im großen Saal.',
    transliteration: 'Iǧtamaʿa an-nāsu fī al-qāʿati al-kabīrati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1105,
    arabic: 'حَمَلَ الْوَلَدُ دَلْوًا مِنَ الْمَاءِ إِلَى الْبَيْتِ.',
    german: 'Der Junge trug einen Eimer Wasser ins Haus.',
    transliteration: 'Ḥamala al-waladu dalwan mina al-māʾi ʾilā al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1106,
    arabic: 'أَخَذَتِ الْمَرْأَةُ الْمِكْنَسَةَ وَنَظَّفَتِ الْمَدْخَلَ.',
    german: 'Die Frau nahm den Besen und reinigte den Eingang.',
    transliteration: 'ʾAḫaḏati al-marʾatu al-miknasata wa-naẓẓafati al-madḫala.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1107,
    arabic: 'سَقَطَ بَرَدٌ كَبِيرٌ عَلَى الْحُقُولِ.',
    german: 'Großer Hagel fiel auf die Felder.',
    transliteration: 'Saqaṭa baradun kabīrun ʿalā al-ḥuqūli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1108,
    arabic: 'فَيَضَانُ النَّهْرِ غَطَّى الطُّرُقَ كُلَّهَا.',
    german: 'Die Überschwemmung des Flusses bedeckte alle Straßen.',
    transliteration: 'Fayaḍānu an-nahri ġaṭṭā aṭ-ṭuruqa kullahā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1109,
    arabic: 'زَلْزَالٌ قَوِيٌّ هَزَّ الْبُيُوتَ فِي اللَّيْلِ.',
    german: 'Ein starkes Erdbeben erschütterte nachts die Häuser.',
    transliteration: 'Zalzālun qawiyyun hazza al-buyūta fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1110,
    arabic: 'التَّاجِرُ أَعْطَى الْفُقَرَاءَ طَعَامًا وَمَاءً.',
    german: 'Der Kaufmann gab den Armen Essen und Wasser.',
    transliteration: 'At-tāǧiru ʾaʿṭā al-fuqarāʾa ṭaʿāman wa-māʾan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 112 (word_ids 1111–1120): „Die Reise".
/// Eine Gruppe aus Nachbarn, Kollegen und Partnern reist zum Hafen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwelveStory = [
  Sentence(
    wordId: 1111,
    arabic: 'الْجَزَّارُ يَبِيعُ اللَّحْمَ فِي السُّوقِ الْقَدِيمِ.',
    german: 'Der Metzger verkauft Fleisch auf dem alten Markt.',
    transliteration: 'Al-ǧazzāru yabīʿu al-laḥma fī as-sūqi al-qadīmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1112,
    arabic: 'جِيرَانُنَا يُحِبُّونَ الرِّحْلَاتِ الطَّوِيلَةَ.',
    german: 'Unsere Nachbarn lieben lange Reisen.',
    transliteration: 'Ǧīrānunā yuḥibbūna ar-riḥlāti aṭ-ṭawīlata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1113,
    arabic: 'رَفِيقِي فِي الطَّرِيقِ رَجُلٌ هَادِئٌ.',
    german: 'Mein Begleiter auf dem Weg ist ein ruhiger Mann.',
    transliteration: 'Rafīqī fī aṭ-ṭarīqi raǧulun hādiʾun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1114,
    arabic: 'زَمِيلِي فِي الْعَمَلِ سَافَرَ مَعَنَا.',
    german: 'Mein Kollege von der Arbeit reiste mit uns.',
    transliteration: 'Zamīlī fī al-ʿamali sāfara maʿanā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1115,
    arabic: 'شَرِيكِي فِي التِّجَارَةِ حَجَزَ الْفُنْدُقَ.',
    german: 'Mein Geschäftspartner buchte das Hotel.',
    transliteration: 'Šarīkī fī at-tiǧārati ḥaǧaza al-funduqa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1116,
    arabic: 'سَائِحٌ أَلْمَانِيٌّ سَأَلَ عَنِ الْمَتْحَفِ.',
    german: 'Ein deutscher Tourist fragte nach dem Museum.',
    transliteration: 'Sāʾiḥun ʾalmāniyyun saʾala ʿani al-matḥafi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1117,
    arabic: 'مُسَافِرٌ تَعْبَانُ نَامَ فِي الْقِطَارِ.',
    german: 'Ein müder Reisender schlief im Zug.',
    transliteration: 'Musāfirun taʿbānu nāma fī al-qiṭāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1118,
    arabic: 'جَوَازُ السَّفَرِ كَانَ فِي الْحَقِيبَةِ.',
    german: 'Der Reisepass war in der Tasche.',
    transliteration: 'Ǧawāzu as-safari kāna fī al-ḥaqībati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1119,
    arabic: 'وَصَلَتِ السَّفِينَةُ إِلَى الْمِينَاءِ صَبَاحًا.',
    german: 'Das Schiff erreichte morgens den Hafen.',
    transliteration: 'Waṣalati as-safīnatu ʾilā al-mīnāʾi ṣabāḥan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1120,
    arabic: 'دَفَعْتُ نِصْفَ الثَّمَنِ قَبْلَ الرِّحْلَةِ.',
    german: 'Ich zahlte die Hälfte des Preises vor der Reise.',
    transliteration: 'Dafaʿtu niṣfa aṯ-ṯamani qabla ar-riḥlati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 113 (word_ids 1121–1130): „Nützliche Dinge".
/// Alltägliche Sätze mit Adjektiven über Nützliches, Notwendiges und Wunderbares.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirteenStory = [
  Sentence(
    wordId: 1121,
    arabic: 'قَرَأْتُ ثُلُثَ الْكِتَابِ فِي يَوْمٍ وَاحِدٍ.',
    german: 'Ich las ein Drittel des Buches an einem Tag.',
    transliteration: 'Qaraʾtu ṯuluṯa al-kitābi fī yawmin wāḥidin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1122,
    arabic: 'هَذَا الْكِتَابُ مُفِيدٌ لِلطُّلَّابِ.',
    german: 'Dieses Buch ist nützlich für Studenten.',
    transliteration: 'Hāḏā al-kitābu mufīdun liṭ-ṭullābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1123,
    arabic: 'الْمَاءُ ضَرُورِيٌّ لِكُلِّ إِنْسَانٍ.',
    german: 'Wasser ist für jeden Menschen notwendig.',
    transliteration: 'Al-māʾu ḍarūriyyun li-kulli ʾinsānin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1124,
    arabic: 'هَذَا الْوَقْتُ مُنَاسِبٌ لِلسَّفَرِ.',
    german: 'Diese Zeit ist passend zum Reisen.',
    transliteration: 'Hāḏā al-waqtu munāsibun lis-safari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1125,
    arabic: 'اِشْتَرَى الْأَبُ سَيَّارَةً حَدِيثَةً.',
    german: 'Der Vater kaufte ein modernes Auto.',
    transliteration: 'Ištarā al-ʾabu sayyāratan ḥadīṯatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1126,
    arabic: 'كَانَ الْفِيلْمُ مُمْتِعًا لِلْأَطْفَالِ.',
    german: 'Der Film war unterhaltsam für die Kinder.',
    transliteration: 'Kāna al-fīlmu mumtiʿan lil-ʾaṭfāli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1127,
    arabic: 'مَنْظَرُ الْبَحْرِ رَائِعٌ فِي الصَّبَاحِ.',
    german: 'Der Anblick des Meeres ist morgens wunderbar.',
    transliteration: 'Manẓaru al-baḥri rāʾiʿun fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1128,
    arabic: 'الطَّالِبُ الْمُجْتَهِدُ قَادِرٌ عَلَى النَّجَاحِ.',
    german: 'Der fleißige Student ist zum Erfolg fähig.',
    transliteration: 'Aṭ-ṭālibu al-muǧtahidu qādirun ʿalā an-naǧāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1129,
    arabic: 'الْجَوَابُ الْخَاطِئُ لَيْسَ نِهَايَةَ الدَّرْسِ.',
    german: 'Eine falsche Antwort ist nicht das Ende der Lektion.',
    transliteration: 'Al-ǧawābu al-ḫāṭiʾu laysa nihāyata ad-darsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1130,
    arabic: 'الْجَبَلُ مُرْتَفِعٌ جِدًّا وَالطَّرِيقُ طَوِيلٌ.',
    german: 'Der Berg ist sehr hoch und der Weg lang.',
    transliteration: 'Al-ǧabalu murtafiʿun ǧiddan wa-aṭ-ṭarīqu ṭawīlun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 114 (word_ids 1131–1140): „Die verspätete Antwort".
/// Ein Tag voller Wartens: Antworten bleiben unklar, Züge sind spät.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFourteenStory = [
  Sentence(
    wordId: 1131,
    arabic: 'الْمَالُ كَافٍ لِشِرَاءِ الْخُبْزِ.',
    german: 'Das Geld reicht, um Brot zu kaufen.',
    transliteration: 'Al-mālu kāfin li-širāʾi al-ḫubzi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1132,
    arabic: 'الْقَائِمَةُ نَاقِصَةٌ وَتَحْتَاجُ إِلَى كَلِمَاتٍ جَدِيدَةٍ.',
    german: 'Die Liste ist unvollständig und braucht neue Wörter.',
    transliteration: 'Al-qāʾimatu nāqiṣatun wa-taḥtāǧu ʾilā kalimātin ǧadīdatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1133,
    arabic: 'الْقِطَارُ مُتَأَخِّرٌ سَاعَةً كَامِلَةً.',
    german: 'Der Zug ist eine ganze Stunde verspätet.',
    transliteration: 'Al-qiṭāru mutaʾaḫḫirun sāʿatan kāmilatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1134,
    arabic: 'كَلَامُهُ غَامِضٌ وَلَا أَفْهَمُهُ.',
    german: 'Seine Rede ist unklar und ich verstehe sie nicht.',
    transliteration: 'Kalāmuhū ġāmiḍun wa-lā ʾafhamuhū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1135,
    arabic: 'جَلَسَ الْعَجُوزُ وَحِيدًا تَحْتَ الشَّجَرَةِ.',
    german: 'Der alte Mann saß allein unter dem Baum.',
    transliteration: 'Ǧalasa al-ʿaǧūzu waḥīdan taḥta aš-šaǧarati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1136,
    arabic: 'أُرِيدُ جَوَابًا مُحَدَّدًا مِنَ الْمُدِيرِ.',
    german: 'Ich möchte eine bestimmte Antwort vom Direktor.',
    transliteration: 'ʾUrīdu ǧawāban muḥaddadan mina al-mudīri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1137,
    arabic: 'هَذَا مَوْضُوعٌ عُمُومِيٌّ يَهُمُّ الْجَمِيعَ.',
    german: 'Das ist ein allgemeines Thema, das alle angeht.',
    transliteration: 'Hāḏā mawḍūʿun ʿumūmiyyun yahummu al-ǧamīʿa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1138,
    arabic: 'زَارَنَا ضَيْفٌ خَارِجِيٌّ مِنْ بَلَدٍ بَعِيدٍ.',
    german: 'Uns besuchte ein ausländischer Gast aus einem fernen Land.',
    transliteration: 'Zāranā ḍayfun ḫāriǧiyyun min baladin baʿīdin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1139,
    arabic: 'وَصَلَتْ رِسَالَةٌ رَسْمِيَّةٌ مِنَ الْمَدْرَسَةِ.',
    german: 'Ein offizieller Brief von der Schule kam an.',
    transliteration: 'Waṣalat risālatun rasmiyyatun mina al-madrasati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1140,
    arabic: 'الْقِطُّ كَسْلَانُ وَيَنَامُ طُولَ النَّهَارِ.',
    german: 'Die Katze ist faul und schläft den ganzen Tag.',
    transliteration: 'Al-qiṭṭu kaslānu wa-yanāmu ṭūla an-nahāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 115 (word_ids 1141–1150): „Das letzte Wort".
/// Sätze über Wertvolles, Endgültiges und darüber, wie oft etwas geschieht.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFifteenStory = [
  Sentence(
    wordId: 1141,
    arabic: 'اِشْتَرَتِ الْأُمُّ خَاتَمًا ثَمِينًا لِابْنَتِهَا.',
    german: 'Die Mutter kaufte ihrer Tochter einen wertvollen Ring.',
    transliteration: 'Ištarat al-ʾummu ḫātaman ṯamīnan li-bnatihā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1142,
    arabic: 'هَذَا الْعَمَلُ مُسْتَحِيلٌ فِي يَوْمٍ وَاحِدٍ.',
    german: 'Diese Arbeit ist an einem Tag unmöglich.',
    transliteration: 'Hāḏā al-ʿamalu mustaḥīlun fī yawmin wāḥidin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1143,
    arabic: 'الْقَرَارُ نِهَائِيٌّ وَلَا يَتَغَيَّرُ.',
    german: 'Die Entscheidung ist endgültig und ändert sich nicht.',
    transliteration: 'Al-qarāru nihāʾiyyun wa-lā yataġayyaru.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1144,
    arabic: 'هَذَا آخِرُ يَوْمٍ فِي الْعَامِ.',
    german: 'Das ist der letzte Tag im Jahr.',
    transliteration: 'Hāḏā ʾāḫiru yawmin fī al-ʿāmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1145,
    arabic: 'هَذَا أَوَّلُ دَرْسٍ فِي الْكِتَابِ.',
    german: 'Das ist die erste Lektion im Buch.',
    transliteration: 'Hāḏā ʾawwalu darsin fī al-kitābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1146,
    arabic: 'هُوَ يَصِلُ دَائِمًا قَبْلَ الْجَمِيعِ.',
    german: 'Er kommt immer vor allen an.',
    transliteration: 'Huwa yaṣilu dāʾiman qabla al-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1147,
    arabic: 'أَزُورُ جَدِّي أَحْيَانًا فِي الصَّيْفِ.',
    german: 'Ich besuche meinen Großvater manchmal im Sommer.',
    transliteration: 'ʾAzūru ǧaddī ʾaḥyānan fī aṣ-ṣayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1148,
    arabic: 'نَرَى الثَّلْجَ نَادِرًا فِي هَذِهِ الْمَدِينَةِ.',
    german: 'Schnee sehen wir in dieser Stadt selten.',
    transliteration: 'Narā aṯ-ṯalǧa nādiran fī hāḏihi al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1149,
    arabic: 'وَقَفَ الْوَلَدُ خَلْفَ الْبَابِ.',
    german: 'Der Junge stand hinter der Tür.',
    transliteration: 'Waqafa al-waladu ḫalfa al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1150,
    arabic: 'تَرَكْنَا الْمَدِينَةَ وَرَاءَنَا.',
    german: 'Wir ließen die Stadt hinter uns.',
    transliteration: 'Tarakna al-madīnata warāʾanā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 116 (word_ids 1151–1160): „Die Konferenz".
/// Eine Konferenz findet statt, Gäste kommen, und ein Autor wird berühmt.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixteenStory = [
  Sentence(
    wordId: 1151,
    arabic: 'اِسْتَفْهَمَ الضَّيْفُ عَنْ مَوْعِدِ الْمُؤْتَمَرِ.',
    german: 'Der Gast erkundigte sich nach dem Termin der Konferenz.',
    transliteration: 'Istafhama aḍ-ḍayfu ʿan mawʿidi al-muʾtamari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1152,
    arabic: 'اِسْتَدْعَى الْمُدِيرُ الْمُهَنْدِسِينَ إِلَى الْمَكْتَبِ.',
    german: 'Der Direktor rief die Ingenieure ins Büro.',
    transliteration: 'Istadʿā al-mudīru al-muhandisīna ʾilā al-maktabi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1153,
    arabic: 'اِبْتَعَدَ الرَّجُلُ عَنِ الضَّجِيجِ.',
    german: 'Der Mann entfernte sich vom Lärm.',
    transliteration: 'Ibtaʿada ar-raǧulu ʿani aḍ-ḍaǧīǧi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1154,
    arabic: 'اِقْتَصَدَتِ الْعَائِلَةُ فِي الْمَصْرُوفِ هَذَا الشَّهْرَ.',
    german: 'Die Familie sparte diesen Monat bei den Ausgaben.',
    transliteration: 'Iqtaṣadati al-ʿāʾilatu fī al-maṣrūfi hāḏā aš-šahra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1155,
    arabic: 'اِنْعَقَدَ الْمُؤْتَمَرُ فِي الْعَاصِمَةِ.',
    german: 'Die Konferenz fand in der Hauptstadt statt.',
    transliteration: 'Inʿaqada al-muʾtamaru fī al-ʿāṣimati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1156,
    arabic: 'اِشْتَهَرَ الْكَاتِبُ بَعْدَ رِوَايَتِهِ الْجَدِيدَةِ.',
    german: 'Der Autor wurde nach seinem neuen Roman bekannt.',
    transliteration: 'Ištahara al-kātibu baʿda riwāyatihī al-ǧadīdati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1157,
    arabic: 'اِمْتَنَعَ الطَّبِيبُ عَنِ الْكَلَامِ فِي الْمَوْضُوعِ.',
    german: 'Der Arzt weigerte sich, über das Thema zu sprechen.',
    transliteration: 'Imtanaʿa aṭ-ṭabību ʿani al-kalāmi fī al-mawḍūʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1158,
    arabic: 'مَا اِحْتَمَلَ الْجَالِسُونَ الْحَرَّ فِي الْخَيْمَةِ.',
    german: 'Die Sitzenden ertrugen die Hitze im Zelt nicht.',
    transliteration: 'Mā iḥtamala al-ǧālisūna al-ḥarra fī al-ḫaymati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1159,
    arabic: 'اِسْتَمْتَعَ الْحَاضِرُونَ بِالْعَرْضِ الْجَمِيلِ.',
    german: 'Die Anwesenden genossen die schöne Vorführung.',
    transliteration: 'Istamtaʿa al-ḥāḍirūna bi-l-ʿarḍi al-ǧamīli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1160,
    arabic: 'تَعَلَّقَ الطِّفْلُ بِأُمِّهِ عِنْدَ الْبَابِ.',
    german: 'Das Kind klammerte sich an seine Mutter an der Tür.',
    transliteration: 'Taʿallaqa aṭ-ṭiflu bi-ʾummihī ʿinda al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 117 (word_ids 1161–1170): „Das Fußballspiel".
/// Eine kleine Mannschaft kämpft in einem großen Stadion um den Sieg.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventeenStory = [
  Sentence(
    wordId: 1161,
    arabic: 'اِنْتَصَرَ الْفَرِيقُ الصَّغِيرُ فِي الْمُبَارَاةِ.',
    german: 'Die kleine Mannschaft siegte im Spiel.',
    transliteration: 'Intaṣara al-farīqu aṣ-ṣaġīru fī al-mubārāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1162,
    arabic: 'اِسْتَوْعَبَ الْمَلْعَبُ آلَافَ الْمُشَجِّعِينَ.',
    german: 'Das Stadion fasste Tausende Fans.',
    transliteration: 'Istawʿaba al-malʿabu ʾālāfa al-mušaǧǧiʿīna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1163,
    arabic: 'اِسْتَعَانَ الْحَارِسُ بِأَصْدِقَائِهِ.',
    german: 'Der Torwart bat seine Freunde um Hilfe.',
    transliteration: 'Istaʿāna al-ḥārisu bi-ʾaṣdiqāʾihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1164,
    arabic: 'اِسْتَوْلَى الْخَصْمُ عَلَى الْكُرَةِ فَجْأَةً.',
    german: 'Der Gegner bemächtigte sich plötzlich des Balls.',
    transliteration: 'Istawlā al-ḫaṣmu ʿalā al-kurati faǧʾatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1165,
    arabic: 'لَمْ يَنْتَقِمِ اللَّاعِبُ مِنْ خَصْمِهِ.',
    german: 'Der Spieler rächte sich nicht an seinem Gegner.',
    transliteration: 'Lam yantaqimi al-lāʿibu min ḫaṣmihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1166,
    arabic: 'اِنْحَنَى الْحَكَمُ لِيَرْفَعَ الصَّفَّارَةَ.',
    german: 'Der Schiedsrichter beugte sich, um die Pfeife aufzuheben.',
    transliteration: 'Inḥanā al-ḥakamu li-yarfaʿa aṣ-ṣaffārata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1167,
    arabic: 'اِطْمَأَنَّ الْمُدَرِّبُ بَعْدَ الْهَدَفِ.',
    german: 'Der Trainer beruhigte sich nach dem Tor.',
    transliteration: 'Iṭmaʾanna al-mudarribu baʿda al-hadafi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1168,
    arabic: 'اِعْتَادَ اللَّاعِبُونَ عَلَى التَّمْرِينِ كُلَّ صَبَاحٍ.',
    german: 'Die Spieler gewöhnten sich daran, jeden Morgen zu trainieren.',
    transliteration: 'Iʿtāda al-lāʿibūna ʿalā at-tamrīni kulla ṣabāḥin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1169,
    arabic: 'تَخَيَّلَ الْوَلَدُ نَفْسَهُ بَطَلًا كَبِيرًا.',
    german: 'Der Junge stellte sich als großen Helden vor.',
    transliteration: 'Taḫayyala al-waladu nafsahū baṭalan kabīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1170,
    arabic: 'تَفَادَى الْمُدَافِعُ الْخَطَأَ فِي اللَّحْظَةِ الْأَخِيرَةِ.',
    german: 'Der Verteidiger vermied den Fehler im letzten Moment.',
    transliteration: 'Tafādā al-mudāfiʿu al-ḫaṭaʾa fī al-laḥẓati al-ʾaḫīrati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 118 (word_ids 1171–1180): „Das Erbe des Großvaters".
/// Nach dem Tod des Großvaters kommt die Familie zusammen und streitet ums Erbe.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEighteenStory = [
  Sentence(
    wordId: 1171,
    arabic: 'تَجَمَّعَ الْأَقَارِبُ فِي بَيْتِ الْجَدِّ بَعْدَ وَفَاتِهِ.',
    german: 'Die Verwandten versammelten sich nach seinem Tod im Haus des Großvaters.',
    transliteration: 'Taǧammaʿa al-ʾaqāribu fī bayti al-ǧaddi baʿda wafātihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1172,
    arabic: 'تَوَزَّعَ الْأَبْنَاءُ الْغُرَفَ بَيْنَهُمْ.',
    german: 'Die Kinder verteilten die Zimmer unter sich.',
    transliteration: 'Tawazzaʿa al-ʾabnāʾu al-ġurafa baynahum.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1173,
    arabic: 'اِمْتَلَكَ الْجَدُّ أَرْضًا وَاسِعَةً قُرْبَ النَّهْرِ.',
    german: 'Der Großvater besaß weites Land nahe dem Fluss.',
    transliteration: 'Imtalaka al-ǧaddu ʾarḍan wāsiʿatan qurba an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1174,
    arabic: 'اِعْتَقَدَ الْجَمِيعُ أَنَّ الْأَرْضَ لِلْعَائِلَةِ.',
    german: 'Alle glaubten, dass das Land der Familie gehört.',
    transliteration: 'Iʿtaqada al-ǧamīʿu ʾanna al-ʾarḍa lil-ʿāʾilati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1175,
    arabic: 'اِنْظَمَّ الْحَفِيدُ إِلَى الْمُحَادَثَةِ بَعْدَ قَلِيلٍ.',
    german: 'Der Enkel schloss sich kurz darauf dem Gespräch an.',
    transliteration: 'Inẓamma al-ḥafīdu ʾilā al-muḥādaṯati baʿda qalīlin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1176,
    arabic: 'اِحْتَفَظَتِ الْجَدَّةُ بِرَسَائِلِ الْجَدِّ فِي صُنْدُوقٍ.',
    german: 'Die Großmutter bewahrte die Briefe des Großvaters in einer Kiste auf.',
    transliteration: 'Iḥtafaẓat al-ǧaddatu bi-rasāʾili al-ǧaddi fī ṣundūqin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1177,
    arabic: 'اِنْزَعَجَ الْعَمُّ مِنَ الْخِلَافِ حَوْلَ الْمِيرَاثِ.',
    german: 'Der Onkel ärgerte sich über den Streit ums Erbe.',
    transliteration: 'Inzaʿaǧa al-ʿammu mina al-ḫilāfi ḥawla al-mīrāṯi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1178,
    arabic: 'اِسْتَرْجَعَتِ الْعَائِلَةُ الْحَقَّ بَعْدَ سَنَوَاتٍ.',
    german: 'Die Familie erhielt das Recht nach Jahren zurück.',
    transliteration: 'Istarǧaʿat al-ʿāʾilatu al-ḥaqqa baʿda sanawātin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1179,
    arabic: 'اِعْتَزَلَ الْأَخُ فِي غُرْفَتِهِ وَلَمْ يَتَكَلَّمْ.',
    german: 'Der Bruder zog sich in sein Zimmer zurück und sprach nicht.',
    transliteration: 'Iʿtazala al-ʾaḫu fī ġurfatihī wa-lam yatakallam.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1180,
    arabic: 'لَا تَسْتَهِنْ بِكَلَامِ كِبَارِ السِّنِّ.',
    german: 'Schätze die Worte der Älteren nicht gering.',
    transliteration: 'Lā tastahin bi-kalāmi kibāri as-sinni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 119 (word_ids 1181–1190): „Das Lager im Wald".
/// Pfadfinder zelten am Waldrand, ein Feuer gerät außer Kontrolle.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNineteenStory = [
  Sentence(
    wordId: 1181,
    arabic: 'اِحْتَاطَ الْكَشَّافُ عِنْدَ إِشْعَالِ النَّارِ.',
    german: 'Der Pfadfinder übte beim Anzünden des Feuers Vorsicht.',
    transliteration: 'Iḥtāṭa al-kaššāfu ʿinda ʾišʿāli an-nāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1182,
    arabic: 'اِمْتَدَّ الْمُخَيَّمُ حَتَّى حَافَّةِ الْغَابَةِ.',
    german: 'Das Lager erstreckte sich bis zum Waldrand.',
    transliteration: 'Imtadda al-muḫayyamu ḥattā ḥāffati al-ġābati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1183,
    arabic: 'اِنْقَلَبَ الْقِدْرُ فَوْقَ الْأَرْضِ.',
    german: 'Der Topf kippte auf den Boden um.',
    transliteration: 'Inqalaba al-qidru fawqa al-ʾarḍi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1184,
    arabic: 'اِحْتَرَقَ الْخُبْزُ لِأَنَّ النَّارَ كَانَتْ شَدِيدَةً.',
    german: 'Das Brot verbrannte, weil das Feuer heftig war.',
    transliteration: 'Iḥtaraqa al-ḫubzu li-ʾanna an-nāra kānat šadīdatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1185,
    arabic: 'اِغْتَسَلَ الْوَلَدُ فِي النَّهْرِ الْبَارِدِ.',
    german: 'Der Junge wusch sich im kalten Fluss.',
    transliteration: 'Iġtasala al-waladu fī an-nahri al-bāridi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1186,
    arabic: 'تَعَاوَنَ الْكَشَّافَةُ عَلَى نَصْبِ الْخَيْمَةِ.',
    german: 'Die Pfadfinder arbeiteten beim Aufstellen des Zeltes zusammen.',
    transliteration: 'Taʿāwana al-kaššāfatu ʿalā naṣbi al-ḫaymati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1187,
    arabic: 'تَرَاجَعَتِ النَّارُ بَعْدَ سُقُوطِ الْمَطَرِ.',
    german: 'Das Feuer ging nach dem Regenfall zurück.',
    transliteration: 'Tarāǧaʿati an-nāru baʿda suqūṭi al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1188,
    arabic: 'تَصَرَّفَ الْقَائِدُ بِحِكْمَةٍ وَهُدُوءٍ.',
    german: 'Der Anführer handelte mit Weisheit und Ruhe.',
    transliteration: 'Taṣarrafa al-qāʾidu bi-ḥikmatin wa-hudūʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1189,
    arabic: 'اِنْطَبَعَتِ الْقِصَّةُ فِي ذَاكِرَتِهِمْ.',
    german: 'Die Geschichte prägte sich in ihr Gedächtnis ein.',
    transliteration: 'Inṭabaʿati al-qiṣṣatu fī ḏākiratihim.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1190,
    arabic: 'اِسْتَقْصَى الْقَائِدُ سَبَبَ الْحَرِيقِ.',
    german: 'Der Anführer untersuchte die Ursache des Brandes.',
    transliteration: 'Istaqṣā al-qāʾidu sababa al-ḥarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 120 (word_ids 1191–1200): „Der Richter und der Zeuge".
/// Vor Gericht tritt ein mutiger Zeuge auf, und das Urteil überzeugt alle.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyStory = [
  Sentence(
    wordId: 1191,
    arabic: 'اِحْتَكَمَ الْخَصْمَانِ إِلَى الْقَاضِي.',
    german: 'Die beiden Streitenden riefen den Richter an.',
    transliteration: 'Iḥtakama al-ḫaṣmāni ʾilā al-qāḍī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1192,
    arabic: 'اِنْضَمَّ شَاهِدٌ جَدِيدٌ إِلَى الْقَضِيَّةِ.',
    german: 'Ein neuer Zeuge schloss sich dem Fall an.',
    transliteration: 'Inḍamma šāhidun ǧadīdun ʾilā al-qaḍiyyati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1193,
    arabic: 'اِسْتَغَلَّ الرَّجُلُ ثِقَةَ النَّاسِ.',
    german: 'Der Mann nutzte das Vertrauen der Leute aus.',
    transliteration: 'Istaġalla ar-raǧulu ṯiqata an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1194,
    arabic: 'اِنْبَهَرَ الْحَاضِرُونَ بِشَجَاعَةِ الشَّاهِدِ.',
    german: 'Die Anwesenden staunten über den Mut des Zeugen.',
    transliteration: 'Inbahara al-ḥāḍirūna bi-šaǧāʿati aš-šāhidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1195,
    arabic: 'اِعْتَزَّ الشَّاهِدُ بِصِدْقِهِ أَمَامَ الْجَمِيعِ.',
    german: 'Der Zeuge war stolz auf seine Ehrlichkeit vor allen.',
    transliteration: 'Iʿtazza aš-šāhidu bi-ṣidqihī ʾamāma al-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1196,
    arabic: 'اِسْتَرْخَى الْقَاضِي فِي كُرْسِيِّهِ بَعْدَ الْجَلْسَةِ.',
    german: 'Der Richter entspannte sich nach der Sitzung in seinem Stuhl.',
    transliteration: 'Istarḫā al-qāḍī fī kursiyyihī baʿda al-ǧalsati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1197,
    arabic: 'اِنْفَرَدَ الْمُتَّهَمُ فِي زِنْزَانَتِهِ لَيْلَةً كَامِلَةً.',
    german: 'Der Angeklagte war eine ganze Nacht allein in seiner Zelle.',
    transliteration: 'Infarada al-muttahamu fī zinzānatihī laylatan kāmilatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1198,
    arabic: 'اِسْتَفَاقَ الشَّاهِدُ مِنْ ذُهُولِهِ وَتَكَلَّمَ.',
    german: 'Der Zeuge kam aus seiner Benommenheit zu sich und sprach.',
    transliteration: 'Istafāqa aš-šāhidu min ḏuhūlihī wa-takallama.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1199,
    arabic: 'اِعْتَزَمَ الْقَاضِي أَنْ يَحْكُمَ بِالْعَدْلِ.',
    german: 'Der Richter war fest entschlossen, gerecht zu urteilen.',
    transliteration: 'Iʿtazama al-qāḍī ʾan yaḥkuma bi-l-ʿadli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1200,
    arabic: 'اِسْتَحْسَنَ النَّاسُ حُكْمَ الْقَاضِي.',
    german: 'Die Leute hießen das Urteil des Richters gut.',
    transliteration: 'Istaḥsana an-nāsu ḥukma al-qāḍī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 121 (word_ids 1201–1210): „Die Nacht der Verhaftung".
/// In einer Nacht wird ein Fremder verhaftet, und das ganze Viertel wacht auf.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyOneStory = [
  Sentence(
    wordId: 1201,
    arabic: 'اِنْفَتَحَ الْبَابُ فِي مُنْتَصَفِ اللَّيْلِ.',
    german: 'Die Tür öffnete sich mitten in der Nacht.',
    transliteration: 'Inftaḥa al-bābu fī muntaṣafi al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1202,
    arabic: 'لَمْ يَعْتَدَّ الْمُعَلِّمُ بِرَأْيِ الطَّالِبِ.',
    german: 'Der Lehrer berücksichtigte die Meinung des Schülers nicht.',
    transliteration: 'Lam yaʿtadda al-muʿallimu bi-raʾyi aṭ-ṭālibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1203,
    arabic: 'اِسْتَغْرَبَ الْوَلَدُ مِنَ الصَّمْتِ الطَّوِيلِ.',
    german: 'Der Junge wunderte sich über die lange Stille.',
    transliteration: 'Istaġraba al-waladu mina aṣ-ṣamti aṭ-ṭawīli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1204,
    arabic: 'اِعْتَقَلَ الْحُرَّاسُ الرَّجُلَ الْغَرِيبَ.',
    german: 'Die Wachen verhafteten den fremden Mann.',
    transliteration: 'Iʿtaqala al-ḥurrāsu ar-raǧula al-ġarība.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1205,
    arabic: 'اِنْصَرَفَ الضُّيُوفُ بَعْدَ الْحَفْلِ.',
    german: 'Die Gäste gingen nach dem Fest weg.',
    transliteration: 'Inṣarafa aḍ-ḍuyūfu baʿda al-ḥafli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1206,
    arabic: 'اِعْتَرَضَ الْجُنْدِيُّ طَرِيقَ السَّيَّارَةِ.',
    german: 'Der Soldat trat dem Auto in den Weg.',
    transliteration: 'Iʿtaraḍa al-ǧundiyyu ṭarīqa as-sayyārati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1207,
    arabic: 'اِسْتَغْرَقَ الْعَمَلُ ثَلَاثَ سَاعَاتٍ.',
    german: 'Die Arbeit dauerte drei Stunden.',
    transliteration: 'Istaġraqa al-ʿamalu ṯalāṯa sāʿātin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1208,
    arabic: 'سُكَّانُ الْحَيِّ سَمِعُوا الصُّرَاخَ.',
    german: 'Die Bewohner des Viertels hörten das Geschrei.',
    transliteration: 'Sukkānu al-ḥayyi samiʿū aṣ-ṣurāḫa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1209,
    arabic: 'الْوَاقِعُ أَغْرَبُ مِنَ الْخَيَالِ.',
    german: 'Die Wirklichkeit ist seltsamer als die Phantasie.',
    transliteration: 'Al-wāqiʿu ʾaġrabu mina al-ḫayāli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1210,
    arabic: 'الْمَلِكَةُ أَمَرَتْ بِإِطْلَاقِ سَرَاحِ الرَّجُلِ.',
    german: 'Die Königin befahl, den Mann freizulassen.',
    transliteration: 'Al-malikatu ʾamarat bi-ʾiṭlāqi sarāḥi ar-raǧuli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 122 (word_ids 1211–1220): „Das Ende der Schlacht".
/// Nach einer verlorenen Schlacht kehrt der Alltag aus Handel und Miete zurück.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyTwoStory = [
  Sentence(
    wordId: 1211,
    arabic: 'الْأَمِيرُ قَادَ الْجَيْشَ إِلَى الْجَبَلِ.',
    german: 'Der Prinz führte das Heer zum Berg.',
    transliteration: 'Al-ʾamīru qāda al-ǧayša ʾilā al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1212,
    arabic: 'اِنْتَهَتِ الْمَعْرَكَةُ قَبْلَ غُرُوبِ الشَّمْسِ.',
    german: 'Die Schlacht endete vor Sonnenuntergang.',
    transliteration: 'Intahati al-maʿrakatu qabla ġurūbi aš-šamsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1213,
    arabic: 'هَزِيمَةُ الْجَيْشِ أَحْزَنَتِ الشَّعْبَ كُلَّهُ.',
    german: 'Die Niederlage des Heeres machte das ganze Volk traurig.',
    transliteration: 'Hazīmatu al-ǧayši ʾaḥzanat aš-šaʿba kullahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1214,
    arabic: 'الْخَطَرُ قَرِيبٌ فَاتْرُكُوا الْمَكَانَ.',
    german: 'Die Gefahr ist nah, verlasst den Ort.',
    transliteration: 'Al-ḫaṭaru qarībun fa-trukū al-makāna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1215,
    arabic: 'الشَّرِكَةُ فَتَحَتْ فَرْعًا جَدِيدًا فِي الْمَدِينَةِ.',
    german: 'Die Firma eröffnete eine neue Filiale in der Stadt.',
    transliteration: 'Aš-šarikatu fataḥat farʿan ǧadīdan fī al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1216,
    arabic: 'حَمَلَ الرَّجُلُ مَتَاعَهُ عَلَى الْجَمَلِ.',
    german: 'Der Mann lud sein Hab und Gut auf das Kamel.',
    transliteration: 'Ḥamala ar-raǧulu matāʿahū ʿalā al-ǧamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1217,
    arabic: 'وَصَلَتِ الْبَضَائِعُ مِنْ بَلَدٍ بَعِيدٍ.',
    german: 'Die Waren kamen aus einem fernen Land an.',
    transliteration: 'Waṣalati al-baḍāʾiʿu min baladin baʿīdin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1218,
    arabic: 'الْخَسَارَةُ كَانَتْ كَبِيرَةً هَذَا الْعَامَ.',
    german: 'Der Verlust war dieses Jahr groß.',
    transliteration: 'Al-ḫasāratu kānat kabīratan hāḏā al-ʿāma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1219,
    arabic: 'دَفَعَ الْمُسْتَأْجِرُ الْإِيجَارَ فِي بِدَايَةِ الشَّهْرِ.',
    german: 'Der Mieter zahlte die Miete zu Monatsbeginn.',
    transliteration: 'Dafaʿa al-mustaʾǧiru al-ʾīǧāra fī bidāyati aš-šahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1220,
    arabic: 'هَذِهِ الْبَضَاعَةُ رَخِيصَةٌ وَجَيِّدَةٌ.',
    german: 'Diese Ware ist billig und gut.',
    transliteration: 'Hāḏihi al-baḍāʿatu raḫīṣatun wa-ǧayyidatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 123 (word_ids 1221–1230): „Ein Tag im Amt".
/// Ein Tag in Behörden, Vereinen und Stiftungen einer großen Stadt.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyThreeStory = [
  Sentence(
    wordId: 1221,
    arabic: 'مِيزَانِيَّةُ الدَّوْلَةِ اِرْتَفَعَتْ هَذِهِ السَّنَةَ.',
    german: 'Der Staatshaushalt ist dieses Jahr gestiegen.',
    transliteration: 'Mīzāniyyatu ad-dawlati irtafaʿat hāḏihi as-sanata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1222,
    arabic: 'دَفَعَ كُلُّ عَامِلٍ الضَّرِيبَةَ.',
    german: 'Jeder Arbeiter zahlte die Steuer.',
    transliteration: 'Dafaʿa kullu ʿāmilin aḍ-ḍarībata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1223,
    arabic: 'ضَاعَتْ مَحْفَظَتِي فِي الْقِطَارِ.',
    german: 'Meine Brieftasche ging im Zug verloren.',
    transliteration: 'Ḍāʿat maḥfaẓatī fī al-qiṭāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1224,
    arabic: 'أَهْدَتْ لِي جَدَّتِي سُبْحَةً جَمِيلَةً.',
    german: 'Meine Großmutter schenkte mir eine schöne Perlenkette.',
    transliteration: 'ʾAhdat lī ǧaddatī subḥatan ǧamīlatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1225,
    arabic: 'يَعْمَلُ أَخِي فِي مَجَالِ الطِّبِّ.',
    german: 'Mein Bruder arbeitet im Bereich der Medizin.',
    transliteration: 'Yaʿmalu ʾaḫī fī maǧāli aṭ-ṭibbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1226,
    arabic: 'النِّظَامُ الْجَدِيدُ سَهْلٌ وَوَاضِحٌ.',
    german: 'Das neue System ist einfach und klar.',
    transliteration: 'An-niẓāmu al-ǧadīdu sahlun wa-wāḍiḥun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1227,
    arabic: 'مُؤَسَّسَةٌ خَيْرِيَّةٌ بَنَتْ مَدْرَسَةً فِي الْقَرْيَةِ.',
    german: 'Eine wohltätige Stiftung baute eine Schule im Dorf.',
    transliteration: 'Muʾassasatun ḫayriyyatun banat madrasatan fī al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1228,
    arabic: 'الْهَيْئَةُ الْعُلْيَا رَاجَعَتِ الْأَوْرَاقَ.',
    german: 'Die oberste Behörde prüfte die Unterlagen.',
    transliteration: 'Al-hayʾatu al-ʿulyā rāǧaʿat al-ʾawrāqa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1229,
    arabic: 'السُّفَارَةُ تَقَعُ قُرْبَ الْمَيْدَانِ الْكَبِيرِ.',
    german: 'Die Botschaft liegt nahe dem großen Platz.',
    transliteration: 'As-sufāratu taqaʿu qurba al-maydāni al-kabīri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1230,
    arabic: 'الْجَمْعِيَّةُ تُسَاعِدُ الْأَيْتَامَ كُلَّ شَهْرٍ.',
    german: 'Der Verein hilft jeden Monat den Waisen.',
    transliteration: 'Al-ǧamʿiyyatu tusāʿidu al-ʾaytāma kulla šahrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 124 (word_ids 1231–1240): „Die Wahlen".
/// Vor der Wahl diskutieren Parteien, Gewerkschaften und Bürger über Politik.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyFourStory = [
  Sentence(
    wordId: 1231,
    arabic: 'النِّقَابَةُ طَلَبَتْ زِيَادَةً فِي الْأُجُورِ.',
    german: 'Die Gewerkschaft forderte höhere Löhne.',
    transliteration: 'An-niqābatu ṭalabat ziyādatan fī al-ʾuǧūri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1232,
    arabic: 'الْحِزْبُ الْجَدِيدُ نَشَرَ بَرْنَامَجَهُ أَمْسِ.',
    german: 'Die neue Partei veröffentlichte gestern ihr Programm.',
    transliteration: 'Al-ḥizbu al-ǧadīdu našara barnāmaǧahū ʾamsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1233,
    arabic: 'اِنْتِخَابَاتُ هَذَا الْعَامِ جَرَتْ بِهُدُوءٍ.',
    german: 'Die Wahlen dieses Jahres verliefen ruhig.',
    transliteration: 'Intiḫābātu hāḏā al-ʿāmi ǧarat bi-hudūʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1234,
    arabic: 'التَّصْوِيتُ بَدَأَ فِي الصَّبَاحِ الْبَاكِرِ.',
    german: 'Die Abstimmung begann am frühen Morgen.',
    transliteration: 'At-taṣwītu badaʾa fī aṣ-ṣabāḥi al-bākiri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1235,
    arabic: 'الْمُرَشَّحُ تَكَلَّمَ أَمَامَ الْجُمْهُورِ.',
    german: 'Der Kandidat sprach vor dem Publikum.',
    transliteration: 'Al-muraššaḥu takallama ʾamāma al-ǧumhūri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1236,
    arabic: 'السِّيَاسَةُ تُهِمُّ الشَّبَابَ أَيْضًا.',
    german: 'Politik interessiert auch die Jugend.',
    transliteration: 'As-siyāsatu tuhimmu aš-šabāba ʾayḍan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1237,
    arabic: 'الْقَضِيَّةُ مَا زَالَتْ أَمَامَ الْمَحْكَمَةِ.',
    german: 'Der Fall liegt noch vor Gericht.',
    transliteration: 'Al-qaḍiyyatu mā zālat ʾamāma al-maḥkamati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1238,
    arabic: 'مُحَافَظَةُ الشَّمَالِ كَبِيرَةٌ وَجَمِيلَةٌ.',
    german: 'Die Provinz im Norden ist groß und schön.',
    transliteration: 'Muḥāfaẓatu aš-šamāli kabīratun wa-ǧamīlatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1239,
    arabic: 'نَحْنُ نَعِيشُ فِي جِوَارِ الْمَسْجِدِ.',
    german: 'Wir leben in der Nachbarschaft der Moschee.',
    transliteration: 'Naḥnu naʿīšu fī ǧiwāri al-masǧidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1240,
    arabic: 'الْحَارَةُ الْقَدِيمَةُ ضَيِّقَةٌ وَهَادِئَةٌ.',
    german: 'Das alte Viertel ist eng und ruhig.',
    transliteration: 'Al-ḥāratu al-qadīmatu ḍayyiqatun wa-hādiʾatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 125 (word_ids 1241–1250): „Die Verantwortung".
/// Über Verantwortung, Begabung und die Fähigkeit, etwas zu bewegen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyFiveStory = [
  Sentence(
    wordId: 1241,
    arabic: 'فِي هَذِهِ الْفَتْرَةِ نَعْمَلُ بِجِدٍّ.',
    german: 'In diesem Zeitraum arbeiten wir fleißig.',
    transliteration: 'Fī hāḏihi al-fatrati naʿmalu bi-ǧiddin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1242,
    arabic: 'طَالَتْ مُدَّةُ الاِنْتِظَارِ أَكْثَرَ مِنَ الْمُتَوَقَّعِ.',
    german: 'Die Wartezeit dauerte länger als erwartet.',
    transliteration: 'Ṭālat muddatu al-intiẓāri ʾakṯara mina al-mutawaqqaʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1243,
    arabic: 'جَاءَ مِصْدَاقُ الْخَبَرِ مِنَ الْإِذَاعَةِ.',
    german: 'Die Bestätigung der Nachricht kam vom Rundfunk.',
    transliteration: 'Ǧāʾa miṣdāqu al-ḫabari mina al-ʾiḏāʿati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1244,
    arabic: 'لِكُلِّ وَاحِدٍ دَوْرٌ فِي الْمَسْرَحِيَّةِ.',
    german: 'Jeder hat eine Rolle im Theaterstück.',
    transliteration: 'Li-kulli wāḥidin dawrun fī al-masraḥiyyati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1245,
    arabic: 'الْمَسْؤُولِيَّةُ كَبِيرَةٌ وَلَكِنَّنِي مُسْتَعِدٌّ.',
    german: 'Die Verantwortung ist groß, aber ich bin bereit.',
    transliteration: 'Al-masʾūliyyatu kabīratun wa-lākinnanī mustaʿiddun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1246,
    arabic: 'لَا أَرَى إِمْكَانًا لِلْحَلِّ الْآنَ.',
    german: 'Ich sehe jetzt keine Möglichkeit zur Lösung.',
    transliteration: 'Lā ʾarā ʾimkānan lil-ḥalli al-ʾāna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1247,
    arabic: 'لِلطِّفْلِ قُدْرَةٌ عَجِيبَةٌ عَلَى التَّعَلُّمِ.',
    german: 'Das Kind hat eine erstaunliche Lernfähigkeit.',
    transliteration: 'Liṭ-ṭifli qudratun ʿaǧībatun ʿalā at-taʿallumi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1248,
    arabic: 'مَقْدِرَةُ الرَّجُلِ عَلَى الْعَمَلِ مَعْرُوفَةٌ.',
    german: 'Die Leistungsfähigkeit des Mannes bei der Arbeit ist bekannt.',
    transliteration: 'Maqdiratu ar-raǧuli ʿalā al-ʿamali maʿrūfatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1249,
    arabic: 'تَظْهَرُ الْمَوَاهِبُ فِي الصِّغَرِ.',
    german: 'Begabungen zeigen sich in der Kindheit.',
    transliteration: 'Taẓharu al-mawāhibu fī aṣ-ṣiġari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1250,
    arabic: 'مَوْهِبَتُهَا فِي الرَّسْمِ مُدْهِشَةٌ.',
    german: 'Ihre Begabung im Zeichnen ist erstaunlich.',
    transliteration: 'Mawhibatuhā fī ar-rasmi mudhišatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 126 (word_ids 1251–1260): „Die Sitzung".
/// Eine Sitzung mit Diskussion, Vorschlag und Entscheidung.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentySixStory = [
  Sentence(
    wordId: 1251,
    arabic: 'الْمَهَارَةُ تَأْتِي بِالتَّدْرِيبِ الطَّوِيلِ.',
    german: 'Fertigkeit kommt durch langes Training.',
    transliteration: 'Al-mahāratu taʾtī bi-t-tadrībi aṭ-ṭawīli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1252,
    arabic: 'الْمَعْرِفَةُ نُورٌ لِلْعَقْلِ.',
    german: 'Wissen ist ein Licht für den Verstand.',
    transliteration: 'Al-maʿrifatu nūrun lil-ʿaqli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1253,
    arabic: 'اِنْتَهَتِ الْمُنَاقَشَةُ دُونَ نَتِيجَةٍ.',
    german: 'Die Diskussion endete ohne Ergebnis.',
    transliteration: 'Intahati al-munāqašatu dūna natīǧatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1254,
    arabic: 'الْحِوَارُ أَفْضَلُ مِنَ الْخِصَامِ.',
    german: 'Der Dialog ist besser als der Streit.',
    transliteration: 'Al-ḥiwāru ʾafḍalu mina al-ḫiṣāmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1255,
    arabic: 'اُتُّخِذَ الْقَرَارُ بَعْدَ سَاعَاتٍ طَوِيلَةٍ.',
    german: 'Die Entscheidung wurde nach langen Stunden getroffen.',
    transliteration: 'Uttuḫiḏa al-qarāru baʿda sāʿātin ṭawīlatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1256,
    arabic: 'قَدَّمَ الْمُهَنْدِسُ اقْتِرَاحًا ذَكِيًّا.',
    german: 'Der Ingenieur machte einen klugen Vorschlag.',
    transliteration: 'Qaddama al-muhandisu iqtirāḥan ḏakiyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1257,
    arabic: 'قَرَأَ الْأَعْضَاءُ الْمُقْتَرَحَ بِعِنَايَةٍ.',
    german: 'Die Mitglieder lasen die Vorlage sorgfältig.',
    transliteration: 'Qaraʾa al-ʾaʿḍāʾu al-muqtaraḥa bi-ʿināyatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1258,
    arabic: 'تَنْفِيذُ الْخُطَّةِ يَبْدَأُ غَدًا.',
    german: 'Die Durchführung des Plans beginnt morgen.',
    transliteration: 'Tanfīḏu al-ḫuṭṭati yabdaʾu ġadan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1259,
    arabic: 'التَّنْظِيمُ الْجَيِّدُ يُوَفِّرُ الْوَقْتَ.',
    german: 'Gute Organisation spart Zeit.',
    transliteration: 'At-tanẓīmu al-ǧayyidu yuwaffiru al-waqta.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1260,
    arabic: 'الْإِدَارَةُ تَطْلُبُ تَقْرِيرًا كَامِلًا.',
    german: 'Die Leitung verlangt einen vollständigen Bericht.',
    transliteration: 'Al-ʾidāratu taṭlubu taqrīran kāmilan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 127 (word_ids 1261–1270): „Der neue Posten".
/// Ein neuer Direktor übernimmt ein Amt und plant Verbesserungen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentySevenStory = [
  Sentence(
    wordId: 1261,
    arabic: 'الْمُدِيرُ الْجَدِيدُ وَصَلَ إِلَى الْمَكْتَبِ مُبَكِّرًا.',
    german: 'Der neue Direktor kam früh ins Büro.',
    transliteration: 'Al-mudīru al-ǧadīdu waṣala ʾilā al-maktabi mubakkiran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1262,
    arabic: 'تَوَلَّى الْأُسْتَاذُ رِئَاسَةَ الْجَلْسَةِ.',
    german: 'Der Professor übernahm den Vorsitz der Sitzung.',
    transliteration: 'Tawallā al-ʾustāḏu riʾāsata al-ǧalsati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1263,
    arabic: 'هَذَا الْمَنْصِبُ يَحْتَاجُ إِلَى خِبْرَةٍ.',
    german: 'Dieses Amt braucht Erfahrung.',
    transliteration: 'Hāḏā al-manṣibu yaḥtāǧu ʾilā ḫibratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1264,
    arabic: 'اُكْتُبْ هَذِهِ النُّقْطَةَ فِي الدَّفْتَرِ.',
    german: 'Schreib diesen Punkt ins Heft.',
    transliteration: 'Uktub hāḏihi an-nuqṭata fī ad-daftari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1265,
    arabic: 'الصِّدْقُ أَسَاسُ النَّجَاحِ.',
    german: 'Ehrlichkeit ist die Grundlage des Erfolgs.',
    transliteration: 'Aṣ-ṣidqu ʾasāsu an-naǧāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1266,
    arabic: 'نِسْبَةُ النَّجَاحِ عَالِيَةٌ هَذِهِ السَّنَةَ.',
    german: 'Der Prozentsatz der Erfolge ist dieses Jahr hoch.',
    transliteration: 'Nisbatu an-naǧāḥi ʿāliyatun hāḏihi as-sanata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1267,
    arabic: 'تَطْوِيرُ الْمَدِينَةِ يَحْتَاجُ إِلَى سَنَوَاتٍ.',
    german: 'Der Ausbau der Stadt braucht Jahre.',
    transliteration: 'Taṭwīru al-madīnati yaḥtāǧu ʾilā sanawātin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1268,
    arabic: 'نَرَى تَحْسِينًا وَاضِحًا فِي الْخِدْمَةِ.',
    german: 'Wir sehen eine deutliche Verbesserung im Service.',
    transliteration: 'Narā taḥsīnan wāḍiḥan fī al-ḫidmati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1269,
    arabic: 'الضَّرُورَةُ تَدْفَعُ النَّاسَ إِلَى الْعَمَلِ.',
    german: 'Die Notwendigkeit treibt die Menschen zur Arbeit.',
    transliteration: 'Aḍ-ḍarūratu tadfaʿu an-nāsa ʾilā al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1270,
    arabic: 'مَصْلَحَةُ الطُّلَّابِ أَهَمُّ مِنْ كُلِّ شَيْءٍ.',
    german: 'Das Interesse der Studenten ist wichtiger als alles.',
    transliteration: 'Maṣlaḥatu aṭ-ṭullābi ʾahammu min kulli šayʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 128 (word_ids 1271–1280): „Bedürfnisse und Bedingungen".
/// Was Menschen wollen und brauchen und welche Umstände dabei zählen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyEightStory = [
  Sentence(
    wordId: 1271,
    arabic: 'مَقْصِدُ الرِّحْلَةِ هُوَ زِيَارَةُ الْأَهْلِ.',
    german: 'Das Ziel der Reise ist der Besuch der Familie.',
    transliteration: 'Maqṣidu ar-riḥlati huwa ziyāratu al-ʾahli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1272,
    arabic: 'رَغْبَتُهُ فِي التَّعَلُّمِ لَا تَنْتَهِي.',
    german: 'Sein Wunsch zu lernen hört nie auf.',
    transliteration: 'Raġbatuhū fī at-taʿallumi lā tantahī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1273,
    arabic: 'كُلُّ إِنْسَانٍ لَهُ حَاجَةٌ إِلَى الْأَمَانِ.',
    german: 'Jeder Mensch hat ein Bedürfnis nach Sicherheit.',
    transliteration: 'Kullu ʾinsānin lahū ḥāǧatun ʾilā al-ʾamāni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1274,
    arabic: 'لِلْقِرَاءَةِ مَنْفَعَةٌ كَبِيرَةٌ لِلْعَقْلِ.',
    german: 'Lesen hat einen großen Nutzen für den Verstand.',
    transliteration: 'Lil-qirāʾati manfaʿatun kabīratun lil-ʿaqli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1275,
    arabic: 'فِي التَّدْخِينِ مَضَرَّةٌ عَلَى الصِّحَّةِ.',
    german: 'Rauchen bringt der Gesundheit Schaden.',
    transliteration: 'Fī at-tadḫīni maḍarratun ʿalā aṣ-ṣiḥḥati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1276,
    arabic: 'الظَّرْفُ الصَّعْبُ عَلَّمَنَا الصَّبْرَ.',
    german: 'Der schwierige Umstand lehrte uns Geduld.',
    transliteration: 'Aẓ-ẓarfu aṣ-ṣaʿbu ʿallamanā aṣ-ṣabra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1277,
    arabic: 'وَقَّعَ الطَّرَفَانِ الْمِيثَاقَ أَمَامَ الشُّهُودِ.',
    german: 'Die beiden Seiten unterzeichneten den Vertrag vor den Zeugen.',
    transliteration: 'Waqqaʿa aṭ-ṭarafāni al-mīṯāqa ʾamāma aš-šuhūdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1278,
    arabic: 'قَرِينُ الْفَارِسِ كَانَ وَفِيًّا لَهُ.',
    german: 'Der Genosse des Reiters war ihm treu.',
    transliteration: 'Qarīnu al-fārisi kāna wafiyyan lahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1279,
    arabic: 'نُخْبَةُ الْمُجْتَمَعِ حَضَرَتِ الِاحْتِفَالَ.',
    german: 'Die Elite der Gesellschaft nahm an der Feier teil.',
    transliteration: 'Nuḫbatu al-muǧtamaʿi ḥaḍarat al-iḥtifāla.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1280,
    arabic: 'الطَّبَقَةُ الْعَامِلَةُ تَعِبَتْ مِنَ الْغَلَاءِ.',
    german: 'Die Arbeiterklasse ist der Teuerung müde.',
    transliteration: 'Aṭ-ṭabaqatu al-ʿāmilatu taʿibat mina al-ġalāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 129 (word_ids 1281–1290): „Das Lager".
/// Vorräte im Lager, ein einzelner Gast und ein Blick auf die kommende Zeit.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredTwentyNineStory = [
  Sentence(
    wordId: 1281,
    arabic: 'الْمَخْزُونُ فِي الْبَيْتِ يَكْفِي لِشَهْرٍ.',
    german: 'Der Vorrat im Haus reicht für einen Monat.',
    transliteration: 'Al-maḫzūnu fī al-bayti yakfī li-šahrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1282,
    arabic: 'حَمَلَ الْعُمَّالُ الصَّنَادِيقَ إِلَى الْمُخَزَّنِ.',
    german: 'Die Arbeiter trugen die Kisten ins Lager.',
    transliteration: 'Ḥamala al-ʿummālu aṣ-ṣanādīqa ʾilā al-muḫazzani.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1283,
    arabic: 'الْبِنَاءُ الْقَائِمُ هُنَاكَ قَدِيمٌ جِدًّا.',
    german: 'Das dort stehende Gebäude ist sehr alt.',
    transliteration: 'Al-bināʾu al-qāʾimu hunāka qadīmun ǧiddan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1284,
    arabic: 'الْفَرِيقُ الْمُتَّحِدُ أَقْوَى مِنَ الْجَمِيعِ.',
    german: 'Das vereinte Team ist stärker als alle.',
    transliteration: 'Al-farīqu al-muttaḥidu ʾaqwā mina al-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1285,
    arabic: 'جَلَسَ ضَيْفٌ مُنْفَرِدٌ عَلَى الطَّاوِلَةِ الْبَعِيدَةِ.',
    german: 'Ein einzelner Gast saß am entfernten Tisch.',
    transliteration: 'Ǧalasa ḍayfun munfaridun ʿalā aṭ-ṭāwilati al-baʿīdati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1286,
    arabic: 'الْمُدِيرُ السَّابِقُ زَارَنَا الْيَوْمَ.',
    german: 'Der frühere Direktor besuchte uns heute.',
    transliteration: 'Al-mudīru as-sābiqu zāranā al-yawma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1287,
    arabic: 'فِي الدَّرْسِ التَّالِي سَنَقْرَأُ قِصَّةً.',
    german: 'In der folgenden Lektion lesen wir eine Geschichte.',
    transliteration: 'Fī ad-darsi at-tālī sanaqraʾu qiṣṣatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1288,
    arabic: 'الْأُسْبُوعُ الْمُقْبِلُ سَيَكُونُ مُزْدَحِمًا.',
    german: 'Die kommende Woche wird voll sein.',
    transliteration: 'Al-ʾusbūʿu al-muqbilu sayakūnu muzdaḥiman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1289,
    arabic: 'نَنْتَظِرُ الْعَامَ الْقَادِمَ بِأَمَلٍ.',
    german: 'Wir erwarten das kommende Jahr mit Hoffnung.',
    transliteration: 'Nantaẓiru al-ʿāma al-qādima bi-ʾamalin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1290,
    arabic: 'الطَّالِبُ الْغَائِبُ مَرِضَ أَمْسِ.',
    german: 'Der abwesende Student wurde gestern krank.',
    transliteration: 'Aṭ-ṭālibu al-ġāʾibu mariḍa ʾamsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 130 (word_ids 1291–1300): „Das Leben in der Stadt".
/// Ein gewöhnlicher Tag in einer Stadt mit Schulen, Märkten und einem Flughafen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyStory = [
  Sentence(
    wordId: 1291,
    arabic: 'الطَّرِيقُ الْمُعْتَادُ إِلَى الْعَمَلِ مُغْلَقٌ الْيَوْمَ.',
    german: 'Der gewohnte Weg zur Arbeit ist heute gesperrt.',
    transliteration: 'Aṭ-ṭarīqu al-muʿtādu ʾilā al-ʿamali muġlaqun al-yawma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1292,
    arabic: 'كَانَ يَوْمًا عَادِيًّا فِي الْمَدِينَةِ.',
    german: 'Es war ein gewöhnlicher Tag in der Stadt.',
    transliteration: 'Kāna yawman ʿādiyyan fī al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1293,
    arabic: 'هَذَا سَبَبٌ ثَانَوِيٌّ لَا أَكْثَرَ.',
    german: 'Das ist ein sekundärer Grund, nicht mehr.',
    transliteration: 'Hāḏā sababun ṯānawiyyun lā ʾakṯara.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1294,
    arabic: 'دَرَسَ أَخِي فِي مَكْتَبَةٍ جَامِعِيَّةٍ.',
    german: 'Mein Bruder lernte in einer Universitätsbibliothek.',
    transliteration: 'Darasa ʾaḫī fī maktabatin ǧāmiʿiyyatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1295,
    arabic: 'الْمَدْرَسَةُ حُكُومِيَّةٌ وَمَجَّانِيَّةٌ.',
    german: 'Die Schule ist staatlich und kostenlos.',
    transliteration: 'Al-madrasatu ḥukūmiyyatun wa-maǧǧāniyyatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1296,
    arabic: 'اِشْتَرَيْتُ خُضَارًا مَحَلِّيًّا مِنَ السُّوقِ.',
    german: 'Ich kaufte lokales Gemüse auf dem Markt.',
    transliteration: 'Ištaraytu ḫuḍāran maḥalliyyan mina as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1297,
    arabic: 'الْمَطَارُ الدَّوْلِيُّ بَعِيدٌ عَنِ الْمَدِينَةِ.',
    german: 'Der internationale Flughafen liegt weit von der Stadt.',
    transliteration: 'Al-maṭāru ad-dawliyyu baʿīdun ʿani al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1298,
    arabic: 'الْأَمْرُ دَاخِلِيٌّ وَلَا يَعْرِفُهُ أَحَدٌ.',
    german: 'Die Sache ist intern, und niemand kennt sie.',
    transliteration: 'Al-ʾamru dāḫiliyyun wa-lā yaʿrifuhū ʾaḥadun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1299,
    arabic: 'يُحِبُّ الشَّابُّ الْأَدَبَ الْعَصْرِيَّ.',
    german: 'Der junge Mann liebt zeitgenössische Literatur.',
    transliteration: 'Yuḥibbu aš-šābbu al-ʾadaba al-ʿaṣriyya.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1300,
    arabic: 'كَانَ الْمُعَلِّمُ بَارِزًا فِي عِلْمِهِ.',
    german: 'Der Lehrer war hervorragend in seinem Fach.',
    transliteration: 'Kāna al-muʿallimu bārizan fī ʿilmihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 131 (word_ids 1301–1310): „Licht für das Dorf".
/// Ein mobiles Gerät bringt Strom in ein Dorf, das lange auf Regen und Licht wartet.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyOneStory = [
  Sentence(
    wordId: 1301,
    arabic: 'جِهَازٌ مُتَحَرِّكٌ يَنْقُلُ الْكَهْرَبَاءَ إِلَى الْقَرْيَةِ.',
    german: 'Ein bewegliches Gerät bringt den Strom ins Dorf.',
    transliteration: 'Ǧihāzun mutaḥarrikun yanqulu al-kahrabāʾa ʾilā al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1302,
    arabic: 'يَبْقَى بَيْتُ رَئِيسِ الْقَرْيَةِ ثَابِتًا فِي الْمَوْقِعِ نَفْسِهِ.',
    german: 'Das Haus des Dorfoberhaupts bleibt fest am selben Ort.',
    transliteration: 'Yabqā baytu raʾīsi al-qaryati ṯābita fī al-mawqiʿi nafsihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1303,
    arabic: 'الْمُهَنْدِسُ يَحْفَظُ بَطَّارِيَّةً احْتِيَاطِيَّةً فِي الصُّنْدُوقِ.',
    german: 'Der Ingenieur hält eine Reservebatterie in der Kiste bereit.',
    transliteration: 'Al-muhandisu yaḥfaẓu baṭṭāriyyatan iḥtiyāṭiyyatan fī aṣ-ṣundūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1304,
    arabic: 'بَعْدَ الْمَطَرِ كَانَ الْمَاءُ وَفِيرًا فِي الْخِزَانِ.',
    german: 'Nach dem Regen war das Wasser im Behälter reichlich vorhanden.',
    transliteration: 'Baʿda al-maṭari kāna al-māʾu wafīra fī al-ḫizzāni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1305,
    arabic: 'لَكِنَّ الْمَطَرَ نَادِرٌ فِي هَذِهِ الْمِنْطَقَةِ.',
    german: 'Aber Regen ist in dieser Gegend selten.',
    transliteration: 'Lākinna al-maṭara nādirun fī hāḏihi al-mintaqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1306,
    arabic: 'لِذَلِكَ يَحْتَاجُ النَّاسُ إِلَى مَصْدَرٍ دَائِمٍ لِلْكَهْرَبَاءِ.',
    german: 'Deshalb brauchen die Menschen eine dauerhafte Stromquelle.',
    transliteration: 'Li-ḏālika yaḥtāǧu an-nāsu ʾilā maṣdarin dāʾimin lil-kahrabāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1307,
    arabic: 'غَالِبًا يَكُونُ الْجَوُّ مُشْمِسًا فِي الصَّيْفِ.',
    german: 'Meistens ist das Wetter im Sommer sonnig.',
    transliteration: 'Ġāliban yakūnu al-ǧawwu mušmisan fī aṣ-ṣayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1308,
    arabic: 'أَخِيرًا وَصَلَ الصُّنْدُوقُ الْكَبِيرُ إِلَى الْقَرْيَةِ.',
    german: 'Schließlich kam die große Kiste im Dorf an.',
    transliteration: 'ʾAḫīran waṣala aṣ-ṣundūqu al-kabīru ʾilā al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1309,
    arabic: 'يَعْمَلُ الْجِهَازُ تَقْرِيبًا عَشْرَ سَاعَاتٍ فِي الْيَوْمِ.',
    german: 'Das Gerät arbeitet ungefähr zehn Stunden am Tag.',
    transliteration: 'Yaʿmalu al-ǧihāzu taqrīban ʿašra sāʿātin fī al-yawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1310,
    arabic: 'فَوْرًا أَضَاءَتِ الْمَصَابِيحُ فِي كُلِّ الْبُيُوتِ.',
    german: 'Sofort leuchteten die Lampen in allen Häusern.',
    transliteration: 'Fawran ʾaḍāʾati al-maṣābīḥu fī kulli al-buyūti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 132 (word_ids 1311–1320): „Die Nachricht aus dem Büro".
/// Ein Leiter korrigiert eine falsche Nachricht und gibt ein neues Buch über das Projekt heraus.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyTwoStory = [
  Sentence(
    wordId: 1311,
    arabic: 'لَمْ يَكُنِ الْخَبَرُ صَحِيحًا مُطْلَقًا.',
    german: 'Die Nachricht war überhaupt nicht richtig.',
    transliteration: 'Lam yakuni al-ḫabaru ṣaḥīḥan muṭlaqan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1312,
    arabic: 'كَانَتِ الْمَشْكِلَةُ نِسْبِيًّا سَهْلَةً.',
    german: 'Das Problem war relativ einfach.',
    transliteration: 'Kānati al-maškilatu nisbiyyan sahlatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1313,
    arabic: 'لِذَلِكَ قَرَّرَ الْمُدِيرُ أَنْ يَشْرَحَ كُلَّ شَيْءٍ.',
    german: 'Deshalb beschloss der Leiter, alles zu erklären.',
    transliteration: 'Li-ḏālika qarrara al-mudīru ʾan yašraḥa kulla šayʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1314,
    arabic: 'عِنْدَمَا دَخَلَ الْمُوَظَّفُ الْمَكْتَبَ سَأَلَ عَنِ الْجَرِيدَةِ.',
    german: 'Als der Angestellte das Büro betrat, fragte er nach der Zeitung.',
    transliteration: 'ʿIndamā daḫala al-muwaẓẓafu al-maktaba saʾala ʿani al-ǧarīdati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1315,
    arabic: 'تَكَلَّمَ الْمُدِيرُ دُونَ خَوْفٍ مِنَ النَّاسِ.',
    german: 'Der Leiter sprach ohne Angst vor den Leuten.',
    transliteration: 'Takallama al-mudīru dūna ḫawfin mina an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1316,
    arabic: 'أَبْدَى جَمِيعُ الْحَاضِرِينَ رَأْيَهُمْ بِصَرَاحَةٍ.',
    german: 'Alle Anwesenden äußerten offen ihre Meinung.',
    transliteration: 'ʾAbdā ǧamīʿu al-ḥāḍirīna raʾyahum bi-ṣarāḥatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1317,
    arabic: 'أَبْطَلَ الْمُدِيرُ الْقَرَارَ الْقَدِيمَ.',
    german: 'Der Leiter hob die alte Entscheidung auf.',
    transliteration: 'ʾAbṭala al-mudīru al-qarāra al-qadīma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1318,
    arabic: 'لَمْ يُخْفِ الْمُوَظَّفُ الْحَقِيقَةَ عَنِ الْجَمِيعِ.',
    german: 'Der Angestellte verbarg die Wahrheit nicht vor allen.',
    transliteration: 'Lam yuḫfi al-muwaẓẓafu al-ḥaqīqata ʿani al-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1319,
    arabic: 'أَذَاعَتِ الْإِذَاعَةُ النَّبَأَ فِي كُلِّ الْمَدِينَةِ.',
    german: 'Der Rundfunk strahlte die Nachricht in der ganzen Stadt aus.',
    transliteration: 'ʾAḏāʿati al-ʾiḏāʿatu an-nabaʾa fī kulli al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1320,
    arabic: 'أَصْدَرَ الْمُدِيرُ كِتَابًا جَدِيدًا عَنِ الْمَشْرُوعِ.',
    german: 'Der Leiter gab ein neues Buch über das Projekt heraus.',
    transliteration: 'ʾAṣdara al-mudīru kitāban ǧadīdan ʿani al-mašrūʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 133 (word_ids 1321–1330): „Ein neues Kapitel in der Schule".
/// Die Schule feiert ein Fest, und ein Junge schenkt seinem Lehrer eine Blume.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyThreeStory = [
  Sentence(
    wordId: 1321,
    arabic: 'أَضَاءَتِ الْمَصَابِيحُ السَّاحَةَ فِي الْمَسَاءِ.',
    german: 'Die Lampen beleuchteten den Platz am Abend.',
    transliteration: 'ʾAḍāʾati al-maṣābīḥu as-sāḥata fī al-masāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1322,
    arabic: 'أَعَادَ الْمُعَلِّمُ الْكُتُبَ إِلَى الْمَكْتَبَةِ.',
    german: 'Der Lehrer gab die Bücher zur Bibliothek zurück.',
    transliteration: 'ʾAʿāda al-muʿallimu al-kutuba ʾilā al-maktabati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1323,
    arabic: 'أَقْبَلَ الطُّلَّابُ عَلَى الْمَدْرَسَةِ وَهُمْ فَرِحُونَ.',
    german: 'Die Schüler näherten sich fröhlich der Schule.',
    transliteration: 'ʾAqbala aṭ-ṭullābu ʿalā al-madrasati wa-hum fariḥūna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1324,
    arabic: 'أَكَّدَ الْمُدِيرُ أَنَّ الْحَفْلَ سَيُقَامُ الْيَوْمَ.',
    german: 'Der Leiter bestätigte, dass das Fest heute stattfinden werde.',
    transliteration: 'ʾAkkada al-mudīru ʾanna al-ḥafla sayuqāmu al-yawma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1325,
    arabic: 'لَكِنَّهُ أَلْغَى الِاجْتِمَاعَ الْمُهِمَّ.',
    german: 'Aber er sagte die wichtige Versammlung ab.',
    transliteration: 'Lākinnahū ʾalġā al-ʾiǧtimāʿa al-muhimma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1326,
    arabic: 'أَنْشَأَ النَّاسُ نَادِيًا جَدِيدًا قُرْبَ الْمَدْرَسَةِ.',
    german: 'Die Leute gründeten einen neuen Klub nahe der Schule.',
    transliteration: 'ʾAnšaʾa an-nāsu nādiyan ǧadīdan qurba al-madrasati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1327,
    arabic: 'أَهْدَى الْوَلَدُ زَهْرَةً إِلَى مُعَلِّمِهِ.',
    german: 'Der Junge schenkte seinem Lehrer eine Blume.',
    transliteration: 'ʾAhdā al-waladu zahratan ʾilā muʿallimihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1328,
    arabic: 'أَوْقَفَتِ الشُّرْطَةُ السَّيَّارَةَ أَمَامَ الْبَوَّابَةِ.',
    german: 'Die Polizei hielt das Auto vor dem Tor an.',
    transliteration: 'ʾAwqafati aš-šurṭatu as-sayyārata ʾamāma al-bawwābati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1329,
    arabic: 'اِتَّبَعَ النَّاسُ تَعْلِيمَاتِ الشُّرْطَةِ بِهُدُوءٍ.',
    german: 'Die Leute folgten ruhig den Anweisungen der Polizei.',
    transliteration: 'Ittabaʿa an-nāsu taʿlīmāti aš-šurṭati bi-hudūʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1330,
    arabic: 'لَمْ يَتَّهِمِ الْقَاضِي أَحَدًا بِالْخَطَأِ.',
    german: 'Der Richter beschuldigte niemanden des Fehlers.',
    transliteration: 'Lam yattahimi al-qāḍī ʾaḥadan bi-al-ḫaṭaʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 134 (word_ids 1331–1340): „Der Erfinder und seine Maschine".
/// Ein junger Erfinder entwickelt ein Küchengerät und bleibt bei Misserfolgen standhaft.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyFourStory = [
  Sentence(
    wordId: 1331,
    arabic: 'اِجْتَهَدَ الشَّابُّ فِي عَمَلِهِ طَوَالَ الْعَامِ.',
    german: 'Der junge Mann strengte sich das ganze Jahr in seiner Arbeit an.',
    transliteration: 'Iǧtahada aš-šābbu fī ʿamalihī ṭiwāla al-ʿāmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1332,
    arabic: 'اِخْتَرَعَ جِهَازًا صَغِيرًا لِلْمَطْبَخِ.',
    german: 'Er erfand ein kleines Gerät für die Küche.',
    transliteration: 'Iḫtaraʿa ǧihāzan ṣaġīran lil-maṭbaḫi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1333,
    arabic: 'اِخْتَصَرَ وَقْتَ الْعَمَلِ فِي الْمَطْبَخِ.',
    german: 'Er verkürzte die Arbeitszeit in der Küche.',
    transliteration: 'Iḫtaṣara waqta al-ʿamali fī al-maṭbaḫi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1334,
    arabic: 'اِخْتَلَطَ السُّكَّرُ بِالْمَاءِ فِي الْقِدْرِ.',
    german: 'Der Zucker vermischte sich im Topf mit dem Wasser.',
    transliteration: 'Iḫtalaṭa as-sukkāru bi-al-māʾi fī al-qidri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1335,
    arabic: 'اِدَّخَرَ الْمُهَنْدِسُ الْمَالَ لِشِرَاءِ الْآلَةِ.',
    german: 'Der Ingenieur sparte das Geld für den Kauf der Maschine.',
    transliteration: 'Iddaḫara al-muhandisu al-māla li-širāʾi al-ʾāləti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1336,
    arabic: 'اِرْتَبَطَ النَّجَاحُ بِاِجْتِهَادِ الشَّابِّ.',
    german: 'Der Erfolg hing mit dem Fleiß des jungen Mannes zusammen.',
    transliteration: 'Irtabaṭa an-naǧāḥu bi-ʾiǧtihādi aš-šābbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1337,
    arabic: 'لَمْ يَرْتَكِبِ الشَّابُّ أَيَّ خَطَإٍ فِي التَّجْرِبَةِ.',
    german: 'Der junge Mann machte bei dem Versuch keinen Fehler.',
    transliteration: 'Lam yartakibi aš-šābbu ʾayya ḫaṭaʾin fī at-taǧribati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1338,
    arabic: 'اِسْتَبْدَلَ الْقِطْعَةَ الْقَدِيمَةَ بِقِطْعَةٍ جَدِيدَةٍ.',
    german: 'Er ersetzte das alte Bauteil durch ein neues.',
    transliteration: 'Istabdala al-qiṭʿata al-qadīmata bi-qiṭʿatin ǧadīdatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1339,
    arabic: 'اِسْتَثْنَى الْمُدِيرُ يَوْمَ الْجُمُعَةِ مِنْ جَدْوَلِ الْعَمَلِ.',
    german: 'Der Leiter nahm den Freitag aus dem Arbeitsplan.',
    transliteration: 'Istaṯnā al-mudīru yawma al-ǧumʿati min ǧadwali al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1340,
    arabic: 'وَلَمْ يَسْتَسْلِمِ الشَّابُّ عِنْدَمَا فَشِلَ فِي الْبِدَايَةِ.',
    german: 'Der junge Mann gab nicht auf, als er am Anfang scheiterte.',
    transliteration: 'Wa-lam yastaslimi aš-šābbu ʿindamā fašila fī al-bidāyati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 135 (word_ids 1341–1350): „Die Reise in das nördliche Land".
/// Ein Reisender bereitet sich auf eine lange Fahrt vor; das Mondlicht spiegelt sich im Wasser.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyFiveStory = [
  Sentence(
    wordId: 1341,
    arabic: 'اِسْتَعَدَّ الْمُسَافِرُ لِلرِّحْلَةِ الطَّوِيلَةِ.',
    german: 'Der Reisende bereitete sich auf die lange Reise vor.',
    transliteration: 'Istaʿadda al-musāfiru lil-riḥlati aṭ-ṭawīlati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1342,
    arabic: 'اِسْتَوْرَدَتِ الْبِلَادُ الْبَضَائِعَ مِنَ الْخَارِجِ.',
    german: 'Das Land importierte die Waren aus dem Ausland.',
    transliteration: 'Istawradati al-bilādu al-baḍāʾiʿa mina al-ḫāriǧi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1343,
    arabic: 'اِقْتَرَضَ الْمُسَافِرُ الْمَالَ مِنْ صَدِيقِهِ.',
    german: 'Der Reisende borgte sich das Geld von seinem Freund.',
    transliteration: 'Iqṭaraḍa al-musāfiru al-māla min ṣadīqihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1344,
    arabic: 'اِلْتَفَتَ الْحَارِسُ إِلَى الصَّوْتِ فِي الْمَحَطَّةِ.',
    german: 'Der Wächter wandte sich dem Geräusch im Bahnhof zu.',
    transliteration: 'Iltafata al-ḥārisu ʾilā aṣ-ṣawti fī al-muḥaṭṭati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1345,
    arabic: 'اِمْتَدَحَ الرَّئِيسُ عَمَلَ الْحَارِسِ الْجَيِّدَ.',
    german: 'Der Chef lobte die gute Arbeit des Wächters.',
    transliteration: 'Imtadaḥa ar-raʾīsu ʿamala al-ḥārisi al-ǧayyida.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1346,
    arabic: 'اِنْسَحَبَ الْحَارِسُ مِنَ الْبَابِ بِهُدُوءٍ.',
    german: 'Der Wächter zog sich ruhig von der Tür zurück.',
    transliteration: 'Insaḥaba al-ḥārisu mina al-bābi bi-hudūʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1347,
    arabic: 'اِنْعَطَفَتِ السَّيَّارَةُ إِلَى الشِّمَالِ.',
    german: 'Das Auto bog nach Norden ab.',
    transliteration: 'Inʿaṭafati as-sayyāratu ʾilā aš-šimāli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1348,
    arabic: 'اِنْعَكَسَ ضَوْءُ الْقَمَرِ عَلَى الْمَاءِ.',
    german: 'Das Mondlicht spiegelte sich im Wasser.',
    transliteration: 'Inʿakasa ḍawʾu al-qamari ʿalā al-māʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1349,
    arabic: 'اِنْفَصَلَ الطَّرِيقَانِ بَعْدَ الْجَبَلِ.',
    german: 'Die beiden Straßen trennten sich hinter dem Berg.',
    transliteration: 'Infaṣala aṭ-ṭarīqāni baʿda al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1350,
    arabic: 'اِهْتَزَّتِ الْأَرْضُ عِنْدَمَا مَرَّ الْقِطَارُ.',
    german: 'Der Boden vibrierte, als der Zug vorbeifuhr.',
    transliteration: 'Ihtazzati al-ʾarḍu ʿindamā marra al-qiṭāru.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 136 (word_ids 1351–1360): „Die Rückkehr des Fahrers".
/// Ein Sportler feiert einen Sieg, erholt sich von der Verletzung und lernt, mit Druck umzugehen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtySixStory = [
  Sentence(
    wordId: 1351,
    arabic: 'بَارَكَ أَصْدِقَاءُ السَّائِقِ نَجَاحَهُ.',
    german: 'Die Freunde des Fahrers beglückwünschten ihn zu seinem Erfolg.',
    transliteration: 'Bāraka ʾaṣdiqāʾu as-sāʾiqi naǧāḥahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1352,
    arabic: 'تَأَلَّمَ السَّائِقُ فِي سَاقِهِ بَعْدَ السُّبَاقِ.',
    german: 'Der Fahrer litt nach dem Rennen Schmerzen im Bein.',
    transliteration: 'Taʾallama as-sāʾiqu fī sāqihī baʿda as-sibāqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1353,
    arabic: 'تَابَعَ الطَّبِيبُ حَالَتَهُ كُلَّ يَوْمٍ.',
    german: 'Der Arzt verfolgte seinen Zustand jeden Tag.',
    transliteration: 'Tābaʿa aṭ-ṭabību ḥālatahū kulla yawmin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1354,
    arabic: 'تَبَادَلَ الرِّيَاضِيُّ الْأَفْكَارَ مَعَ الْمُدَرِّبِ.',
    german: 'Der Sportler tauschte Ideen mit dem Trainer aus.',
    transliteration: 'Tabādala ar-riyāḍiyyu al-ʾafkāra maʿa al-mudarribi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1355,
    arabic: 'تَحَدَّى السَّائِقُ نَفْسَهُ فِي الْمُبَارَاةِ.',
    german: 'Der Fahrer forderte sich selbst im Wettkampf heraus.',
    transliteration: 'Taḥaddā as-sāʾiqu nafsahū fī al-mubārāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1356,
    arabic: 'تَحَكَّمَ فِي السَّيَّارَةِ بِمَهَارَةٍ كَبِيرَةٍ.',
    german: 'Er kontrollierte das Auto mit großem Geschick.',
    transliteration: 'Taḥakkama fī as-sayyārati bi-mahāratin kabīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1357,
    arabic: 'لَمْ يَتَخَلَّفِ السَّائِقُ عَنِ الرَّكْبِ.',
    german: 'Der Fahrer blieb hinter dem Feld nicht zurück.',
    transliteration: 'Lam yataḫallafi as-sāʾiqu ʿani ar-rakbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1358,
    arabic: 'تَذَوَّقَ الطَّعَامَ الْخَفِيفَ بَعْدَ الْمُبَارَاةِ.',
    german: 'Er kostete nach dem Wettkampf das leichte Essen.',
    transliteration: 'Taḏawwaqa aṭ-ṭaʿāma al-ḫafīfa baʿda al-mubārāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1359,
    arabic: 'تَعَافَى السَّائِقُ مِنَ الْإِصَابَةِ بِسُرْعَةٍ.',
    german: 'Der Fahrer genas schnell von der Verletzung.',
    transliteration: 'Taʿāfā as-sāʾiqu mina al-ʾiṣābati bi-surʿatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1360,
    arabic: 'تَعَامَلَ مَعَ الْعَصَبِيَّةِ بِصَبْرٍ كَبِيرٍ.',
    german: 'Er ging mit viel Geduld mit der Nervosität um.',
    transliteration: 'Taʿāmala maʿa al-ʿaṣabiyyati bi-ṣabrin kabīrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 137 (word_ids 1361–1370): „Der neue Leiter der Firma".
/// Ein Angestellter wird zum neuen Leiter befördert und übernimmt die Leitung des Unternehmens.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtySevenStory = [
  Sentence(
    wordId: 1361,
    arabic: 'تَعَوَّدَ الْمُوَظَّفُ عَلَى الْعَمَلِ الْمُبَكِّرِ.',
    german: 'Der Angestellte gewöhnte sich an die frühe Arbeit.',
    transliteration: 'Taʿawwada al-muwaẓẓafu ʿalā al-ʿamali al-mubakkiri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1362,
    arabic: 'تَمَنَّى أَنْ يَنَالَ تَرْقِيَةً سَرِيعًا.',
    german: 'Er wünschte sich, schnell eine Beförderung zu erhalten.',
    transliteration: 'Tamannā ʾan yanāla tarqiyatan sarīʿan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1363,
    arabic: 'تَنَافَسَ الْمُوَظَّفُونَ عَلَى الْمَرْكَزِ الْجَدِيدِ.',
    german: 'Die Angestellten wetteiferten um die neue Stelle.',
    transliteration: 'Tanāfasa al-muwaẓẓafūna ʿalā al-markazi al-ǧadīdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1364,
    arabic: 'تَنَاوَلَ الْمُدِيرُ الْجَدِيدُ الْحِوَارَ بِلُطْفٍ.',
    german: 'Der neue Leiter behandelte das Gespräch freundlich.',
    transliteration: 'Tanāwala al-mudīru al-ǧadīdu al-ḥiwāra bi-luṭfin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1365,
    arabic: 'تَهَيَّأَ الْفَرِيقُ لِلِاجْتِمَاعِ الْمُهِمِّ.',
    german: 'Das Team machte sich für die wichtige Sitzung fertig.',
    transliteration: 'Tahayyaʾa al-farīqu lil-ǧtimāʿi al-muhimmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1366,
    arabic: 'تَوَافَقَتْ أَلْوَانُ الْمَكْتَبِ مَعَ الْجُدْرَانِ.',
    german: 'Die Farben des Büros passten zu den Wänden.',
    transliteration: 'Tawāfaqat ʾalwānu al-maktabi maʿa al-ǧudrāni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1367,
    arabic: 'تَوَجَّهَ الْمُدِيرُ إِلَى الْمَكْتَبَةِ الْكَبِيرَةِ.',
    german: 'Der Leiter begab sich zur großen Bibliothek.',
    transliteration: 'Tawaǧǧaha al-mudīru ʾilā al-maktabati al-kabīrati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1368,
    arabic: 'تَوَلَّى مُهِمَّةَ إِدَارَةِ الْمُؤَسَّسَةِ.',
    german: 'Er übernahm die Aufgabe der Leitung der Einrichtung.',
    transliteration: 'Tawallā muhimmata ʾidārati al-muʾassasati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1369,
    arabic: 'حَدَّدَ وَقْتَ الِاجْتِمَاعِ فِي الصَّبَاحِ.',
    german: 'Er legte die Zeit der Sitzung auf den Morgen fest.',
    transliteration: 'Ḥaddada waqta al-ʾiǧtimāʿi fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1370,
    arabic: 'حَرَّرَ تَقْرِيرًا عَنْ أَعْمَالِ الْفِرِيقِ.',
    german: 'Er verfasste einen Bericht über die Arbeiten des Teams.',
    transliteration: 'Ḥarrara taqrīran ʿan ʾaʿmāli al-farīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 138 (word_ids 1371–1380): „Der Betrug im Geschäft".
/// Ein Verkäufer wird betrogen, prüft die Papiere und lässt sich von den Nachbarn zu neuem Mut ermutigen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyEightStory = [
  Sentence(
    wordId: 1371,
    arabic: 'حَقَّقَ الْبَائِعُ حُلْمَهُ فِي فَتْحِ مَتْجَرٍ.',
    german: 'Der Verkäufer verwirklichte seinen Traum, ein Geschäft zu eröffnen.',
    transliteration: 'Ḥaqqaqa al-bāʾiʿu ḥulmahū fī fatḥi matǧarin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1372,
    arabic: 'لَكِنَّ رَجُلًا خَدَعَهُ وَأَخَذَ مَالَهُ.',
    german: 'Aber ein Mann betrog ihn und nahm sein Geld.',
    transliteration: 'Lākinna raǧulan ḫadaʿahū wa-ʾaḫaḏa mālahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1373,
    arabic: 'دَارَ الْبَائِعُ فِي الْمَكَانِ وَهُوَ غَضْبَانُ.',
    german: 'Der Verkäufer drehte sich wütend im Raum um.',
    transliteration: 'Dāra al-bāʾiʿu fī al-makāni wa-huwa ġaḍbānu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1374,
    arabic: 'ذَابَ الثَّلْجُ فِي مَتْجَرِ الْبَائِعِ.',
    german: 'Das Eis schmolz im Laden des Verkäufers.',
    transliteration: 'Ḏāba aṯ-ṯalǧu fī matǧari al-bāʾiʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1375,
    arabic: 'ذَمَّ النَّاسُ الرَّجُلَ الْمُخَادِعَ.',
    german: 'Die Leute tadelten den betrügerischen Mann.',
    transliteration: 'Ḏamma an-nāsu ar-raǧula al-muḫādiʿa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1376,
    arabic: 'رَاجَعَ الْبَائِعُ الْأَوْرَاقَ بِعِنَايَةٍ.',
    german: 'Der Verkäufer überprüfte die Papiere sorgfältig.',
    transliteration: 'Rāǧaʿa al-bāʾiʿu al-ʾawrāqa bi-ʿināyatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1377,
    arabic: 'سَجَّلَ الشُّرْطِيُّ الْحَادِثَةَ فِي الْمَلَفِّ.',
    german: 'Der Polizist registrierte den Vorfall in der Akte.',
    transliteration: 'Saǧǧala aš-šurṭiyyu al-ḥādiṯata fī al-milaffi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1378,
    arabic: 'سَلَبَ اللِّصُّ الْمَالَ مِنَ الْمَتْجَرِ أَمْسِ.',
    german: 'Der Dieb raubte gestern das Geld aus dem Geschäft.',
    transliteration: 'Salaba al-liṣṣu al-māla mina al-matǧari ʾamsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1379,
    arabic: 'شَجَّعَ الْجِيرَانُ الْبَائِعَ عَلَى الِاسْتِمْرَارِ.',
    german: 'Die Nachbarn ermutigten den Verkäufer, weiterzumachen.',
    transliteration: 'Šaǧǧaʿa al-ǧīrānu al-bāʾiʿa ʿalā al-istimrāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1380,
    arabic: 'طَوَى الْبَائِعُ الْوَثِيقَةَ وَوَضَعَهَا فِي الْجَيْبِ.',
    german: 'Der Verkäufer faltete das Dokument und steckte es in die Tasche.',
    transliteration: 'Ṭawā al-bāʾiʿu al-waṯīqata wa-waḍaʿahā fī al-ǧaybi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 139 (word_ids 1381–1390): „Die Entscheidung des Leiters".
/// Ein Leiter bestraft einen Fehler, entschädigt den ehrlichen Mitarbeiter und belohnt das Team.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredThirtyNineStory = [
  Sentence(
    wordId: 1381,
    arabic: 'عَاقَبَ الْمُدِيرُ الْمُوَظَّفَ عَلَى التَّأْخِيرِ.',
    german: 'Der Leiter bestrafte den Angestellten für die Verspätung.',
    transliteration: 'ʿĀqaba al-mudīru al-muwaẓẓafa ʿalā at-taʾḫīri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1382,
    arabic: 'عَزَلَهُ مِنَ الْمَنْصِبِ بَعْدَ ذَلِكَ.',
    german: 'Er entließ ihn danach aus dem Amt.',
    transliteration: 'ʿAzalahū mina al-manṣibi baʿda ḏālika.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1383,
    arabic: 'عَوَّضَ الْمُدِيرُ الْمُوَظَّفَ عَنِ الْخَسَارَةِ.',
    german: 'Der Leiter entschädigte den Angestellten für den Verlust.',
    transliteration: 'ʿAwwaḍa al-mudīru al-muwaẓẓafa ʿani al-ḫasārati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1384,
    arabic: 'فَسَّرَ الْخَبِيرُ سَبَبَ الْمَشْكِلَةِ بِوُضُوحٍ.',
    german: 'Der Fachmann erklärte den Grund des Problems deutlich.',
    transliteration: 'Fassara al-ḫabīru sababa al-maškilati bi-wuḍūḥin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1385,
    arabic: 'فَكَّ الْمُهَنْدِسُ الْقِفْلَ بِالْمِفْتَاحِ.',
    german: 'Der Ingenieur öffnete das Schloss mit dem Schlüssel.',
    transliteration: 'Fakka al-muhandisu al-qufla bi-al-miftāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1386,
    arabic: 'قَارَنَ الْخَبِيرُ بَيْنَ الْمَشْرُوعَيْنِ.',
    german: 'Der Fachmann verglich zwischen den beiden Projekten.',
    transliteration: 'Qārana al-ḫabīru bayna al-mašrūʿayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1387,
    arabic: 'قَدَّرَ الْمُدِيرُ كُلْفَةَ الْبِنَاءِ بِدِقَّةٍ.',
    german: 'Der Leiter schätzte die Baukosten genau.',
    transliteration: 'Qaddara al-mudīru kulfata al-bināʾi bi-diqqatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1388,
    arabic: 'كَافَأَ الْمُدِيرُ الْفَرِيقَ بِجَائِزَةٍ كَبِيرَةٍ.',
    german: 'Der Leiter belohnte das Team mit einem großen Preis.',
    transliteration: 'Kāfaʾa al-mudīru al-farīqa bi-ǧāʾizatin kabīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1389,
    arabic: 'لَحِقَ الْمُوَظَّفُ بِزُمَلَائِهِ قَبْلَ الْمَسَاءِ.',
    german: 'Der Angestellte holte seine Kollegen vor dem Abend ein.',
    transliteration: 'Laḥiqa al-muwaẓẓafu bi-zumalāʾihī qabla al-masāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1390,
    arabic: 'لَفَّ النَّاسُ الْهَدِيَّةَ بِالْوَرَقِ الْجَمِيلِ.',
    german: 'Die Leute wickelten das Geschenk in das schöne Papier.',
    transliteration: 'Laffa an-nāsu al-hadiyyata bi-al-waraqi al-ǧamīli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 140 (word_ids 1391–1400): „Der Preis des Handwerkers".
/// Ein Handwerker gewinnt mit seinem Laden den Wettbewerb und spart für neue Werkzeuge.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyStory = [
  Sentence(
    wordId: 1391,
    arabic: 'لَمَعَتِ الْجَائِزَةُ الْفِضِّيَّةُ فِي عَرْضِ الْحِرْفَةِ.',
    german: 'Der silberne Preis glänzte in der Handwerksausstellung.',
    transliteration: 'Lamaʿati al-ǧāʾizatu al-fiḍḍiyyatu fī ʿarḍi al-ḥirfati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1392,
    arabic: 'نَالَ الْحِرَفِيُّ الْجَائِزَةَ عَنْ عَمَلٍ رَائِعٍ.',
    german: 'Der Handwerker erlangte den Preis für eine hervorragende Arbeit.',
    transliteration: 'Nāla al-ḥirfiyyu al-ǧāʾizata ʿan ʿamalin rāʾiʿin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1393,
    arabic: 'لَكِنَّهُ نَدِمَ أَنَّهُ لَمْ يُحْضِرِ الْأَدَوَاتِ.',
    german: 'Er aber bereute, dass er die Werkzeuge nicht mitgebracht hatte.',
    transliteration: 'Lākinnahū nadima ʾannahū lam yuḥḍiri al-ʾadawāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1394,
    arabic: 'هَزَمَ مَتْجَرُهُ الْمَتَاجِرَ الْأُخْرَى فِي الْمَسَابَقَةِ.',
    german: 'Sein Laden besiegte die anderen Läden im Wettbewerb.',
    transliteration: 'Hazama matǧaruhū al-matāǧira al-ʾuḫrā fī al-musābaqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1395,
    arabic: 'هَزَّ الْحِرَفِيُّ رَأْسَهُ بِفَخْرٍ.',
    german: 'Der Handwerker schüttelte stolz den Kopf.',
    transliteration: 'Hazza al-ḥirfiyyu raʾsahū bi-faḫrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1396,
    arabic: 'هَنَّأَ الْمُدِيرُ الْحِرَفِيَّ عَلَى الْفَوْزِ.',
    german: 'Der Leiter beglückwünschte den Handwerker zum Sieg.',
    transliteration: 'Hannaʾa al-mudīru al-ḥirfiyya ʿalā al-fawzi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1397,
    arabic: 'وَازَنَ الْحِرَفِيُّ بَيْنَ الْجَوْدَةِ وَالسِّعْرِ.',
    german: 'Der Handwerker wog zwischen Qualität und Preis ab.',
    transliteration: 'Wāzana al-ḥirfiyyu bayna al-ǧawdati wa-as-siʿri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1398,
    arabic: 'وَافَقَ الزُّبُونُ عَلَى الثَّمَنِ بِسُرُورٍ.',
    german: 'Der Kunde stimmte dem Preis mit Freude zu.',
    transliteration: 'Wāfaqa az-zubūnu ʿalā aṯ-ṯamani bi-surūrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1399,
    arabic: 'وَفَّرَ الْحِرَفِيُّ الْمَالَ لِلْأَدَوَاتِ الْجَدِيدَةِ.',
    german: 'Der Handwerker sparte das Geld für die neuen Werkzeuge.',
    transliteration: 'Waffara al-ḥirfiyyu al-māla lil-ʾadawāti al-ǧadīdati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1400,
    arabic: 'أَدَاةُ الْقَصِّ جَعَلَتِ الْعَمَلَ أَكْثَرَ سُهُولَةً.',
    german: 'Das Schneidewerkzeug machte die Arbeit leichter.',
    transliteration: 'ʾAdātu al-qaṣṣi ǧaʿalati al-ʿamala ʾakṯara suhūlatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 141 (word_ids 1401–1410): „Die Stellenanzeige".
/// Ein junger Mann liest eine Anzeige, bewirbt sich und zeigt im Gespräch Interesse.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyOneStory = [
  Sentence(
    wordId: 1401,
    arabic: 'أُجْرَةُ الْعَامِلِ فِي الْمَصْنَعِ مُنَاسِبَةٌ.',
    german: 'Der Lohn des Arbeiters in der Fabrik ist angemessen.',
    transliteration: 'Uǧratu al-ʿāmili fī al-maṣnaʿi munāsibatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1402,
    arabic: 'أُسْلُوبُ الْمُدِيرِ فِي الْكَلَامِ هَادِئٌ.',
    german: 'Der Stil des Leiters beim Sprechen ist ruhig.',
    transliteration: 'ʾUslūbu al-mudīri fī al-kalāmi hādiʾun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1403,
    arabic: 'شَعَرَتْ سَارَةُ بِإِحْسَاسٍ جَمِيلٍ عِنْدَ قِرَاءَةِ الْخَبَرِ.',
    german: 'Sara spürte beim Lesen der Nachricht eine schöne Empfindung.',
    transliteration: 'Šaʿarat Sāratu bi-ʾiḥsāsin ǧamīlin ʿinda qirāʾati al-ḫabari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1404,
    arabic: 'قَرَأَ يُوسُفُ إِعْلَانًا عَنْ وَظِيفَةٍ جَدِيدَةٍ فِي الْجَرِيدَةِ.',
    german: 'Yusuf las in der Zeitung eine Anzeige über eine neue Stelle.',
    transliteration: 'Qaraʾa Yūsufu ʾiʿlānan ʿan waẓīfatin ǧadīdatin fī al-ǧarīdati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1405,
    arabic: 'اللُّغَةُ الْإِنْجِلِيزِيَّةُ اِمْتِيَازٌ لِلْمُتَقَدِّمِ.',
    german: 'Englisch ist ein Vorzug für den Bewerber.',
    transliteration: 'Al-luġatu al-ʾinǧlīziyyatu imtiyāzun lil-mutaqaddimi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1406,
    arabic: 'اِنْتِبَاهُ الشَّابِّ فِي الْمُقَابَلَةِ كَانَ وَاضِحًا.',
    german: 'Die Aufmerksamkeit des jungen Mannes im Gespräch war deutlich.',
    transliteration: 'Intibāhu aš-šābbi fī al-muqābalati kāna wāḍiḥan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1407,
    arabic: 'أَظْهَرَ الشَّابُّ اِهْتِمَامًا كَبِيرًا بِالْعَمَلِ.',
    german: 'Der junge Mann zeigte großes Interesse an der Arbeit.',
    transliteration: 'ʾAẓhara aš-šābbu ihtimāman kabīran bi-al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1408,
    arabic: 'لِلْمُقَابَلَةِ تَأْثِيرٌ كَبِيرٌ عَلَى قَرَارِ الْمُدِيرِ.',
    german: 'Das Gespräch hat große Wirkung auf die Entscheidung des Leiters.',
    transliteration: 'Lil-muqābalati taʾṯīrun kabīrun ʿalā qarāri al-mudīri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1409,
    arabic: 'تَدْفَعُ الشَّرِكَةُ تَأْمِينًا صِحِّيًّا لِكُلِّ مُوَظَّفٍ.',
    german: 'Die Firma zahlt jedem Angestellten eine Krankenversicherung.',
    transliteration: 'Tadfaʿu aš-šarikatu taʾmīnan ṣiḥḥiyyan li-kulli muwaẓẓafin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1410,
    arabic: 'بَدَأَ التَّدْرِيبُ فِي الْأُسْبُوعِ الْأَوَّلِ مِنَ الشَّهْرِ.',
    german: 'Das Training begann in der ersten Woche des Monats.',
    transliteration: 'Badaʾa at-tadrību fī al-ʾusbūʿi al-ʾawwali mina aš-šahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 142 (word_ids 1411–1420): „Das Erbe der Vorfahren".
/// Ein Großvater erzählt von Kultur und Zivilisation, während zu Hause der Alltag weitergeht.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyTwoStory = [
  Sentence(
    wordId: 1411,
    arabic: 'هَذَا التَّعْبِيرُ جَمِيلٌ فِي الشِّعْرِ الْعَرَبِيِّ.',
    german: 'Dieser Ausdruck ist schön in der arabischen Dichtung.',
    transliteration: 'Hāḏā at-taʿbīru ǧamīlun fī aš-šiʿri al-ʿarabiyyi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1412,
    arabic: 'أَخِي الصَّغِيرُ تَوْأَمٌ لِأُخْتِي.',
    german: 'Mein kleiner Bruder ist der Zwilling meiner Schwester.',
    transliteration: 'ʾAḫī aṣ-ṣaġīru tawʾamun li-ʾuḫtī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1413,
    arabic: 'يَحْكِي الْجَدُّ عَنْ تُرَاثِ الْقَرْيَةِ.',
    german: 'Der Großvater erzählt vom Kulturerbe des Dorfes.',
    transliteration: 'Yaḥkī al-ǧaddu ʿan turāṯi al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1414,
    arabic: 'وَضَعَتِ الْأُمُّ الْحَلِيبَ فِي الثَّلَّاجَةِ.',
    german: 'Die Mutter stellte die Milch in den Kühlschrank.',
    transliteration: 'Waḍaʿati al-ʾummu al-ḥalība fī aṯ-ṯallāǧati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1415,
    arabic: 'جَزَاءُ الْكَذِبِ فِي الْمَدْرَسَةِ شَدِيدٌ.',
    german: 'Die Strafe fürs Lügen in der Schule ist hart.',
    transliteration: 'Ǧazāʾu al-kaḏibi fī al-madrasati šadīdun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1416,
    arabic: 'الْجَهْلُ بِالْقَانُونِ لَا يَحْمِي النَّاسَ.',
    german: 'Unwissenheit über das Gesetz schützt die Menschen nicht.',
    transliteration: 'Al-ǧahlu bi-al-qānūni lā yaḥmī an-nāsa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1417,
    arabic: 'زَرَعَتِ الْبِنْتُ الْوَرْدَ فِي جُنَيْنَةِ الْبَيْتِ.',
    german: 'Das Mädchen pflanzte Rosen im Gärtchen des Hauses.',
    transliteration: 'Zaraʿati al-bintu al-warda fī ǧunaynati al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1418,
    arabic: 'اِشْتَرَى أَبِي جِهَازًا جَدِيدًا لِلْمَطْبَخِ.',
    german: 'Mein Vater kaufte ein neues Gerät für die Küche.',
    transliteration: 'Ištarā ʾabī ǧihāzan ǧadīdan lil-maṭbaḫi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1419,
    arabic: 'مِنْ أَيِّ جِهَةٍ تَأْتِي الرِّيحُ؟',
    german: 'Aus welcher Richtung kommt der Wind?',
    transliteration: 'Min ʾayyi ǧihatin taʾtī ar-rīḥu?',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1420,
    arabic: 'دَرَسْنَا حَضَارَةَ مِصْرَ الْقَدِيمَةَ فِي الْجَامِعَةِ.',
    german: 'Wir studierten an der Universität die Zivilisation des alten Ägypten.',
    transliteration: 'Darasnā ḥaḍārata Miṣra al-qadīmata fī al-ǧāmiʿati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 143 (word_ids 1421–1430): „Der Hirte und der Bär".
/// Ein Hirte schützt sein kluges Lamm vor einem Bären und gewinnt Weisheit.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyThreeStory = [
  Sentence(
    wordId: 1421,
    arabic: 'مَلَأَ الرَّاعِي الْحَوْضَ بِالْمَاءِ الْبَارِدِ.',
    german: 'Der Hirte füllte das Becken mit kaltem Wasser.',
    transliteration: 'Malaʾa ar-rāʿī al-ḥawḍa bi-al-māʾi al-bāridi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1422,
    arabic: 'أَخَذَ كُلُّ وَلَدٍ حِصَّتَهُ مِنَ الْخُبْزِ.',
    german: 'Jedes Kind nahm seinen Anteil vom Brot.',
    transliteration: 'ʾAḫaḏa kullu waladin ḥiṣṣatahū mina al-ḫubzi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1423,
    arabic: 'فِي كَلَامِ الشَّيْخِ حِكْمَةٌ كَبِيرَةٌ.',
    german: 'In den Worten des Alten liegt große Weisheit.',
    transliteration: 'Fī kalāmi aš-šayḫi ḥikmatun kabīratun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1424,
    arabic: 'يَرْعَى الْخَرُوفُ الصَّغِيرُ الْعُشْبَ قُرْبَ النَّهْرِ.',
    german: 'Das kleine Lamm weidet Gras nahe dem Fluss.',
    transliteration: 'Yarʿā al-ḫarūfu aṣ-ṣaġīru al-ʿušba qurba an-nahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1425,
    arabic: 'كَتَبَ الْمُعَلِّمُ خُلَاصَةَ الْقِصَّةِ عَلَى السَّبُّورَةِ.',
    german: 'Der Lehrer schrieb die Zusammenfassung der Geschichte an die Tafel.',
    transliteration: 'Kataba al-muʿallimu ḫulāṣata al-qiṣṣati ʿalā as-sabbūrati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1426,
    arabic: 'عِنْدَ الرَّاعِي خِطَّةٌ لِحِمَايَةِ الْقَطِيعِ.',
    german: 'Der Hirte hat einen Plan, um die Herde zu schützen.',
    transliteration: 'ʿInda ar-rāʿī ḫiṭṭatun li-ḥimāyati al-qaṭīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1427,
    arabic: 'رَكِبَ الْوَلَدُ دَرَّاجَتَهُ إِلَى الْحَقْلِ.',
    german: 'Der Junge fuhr mit seinem Fahrrad zum Feld.',
    transliteration: 'Rakiba al-waladu darrāǧatahū ʾilā al-ḥaqli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1428,
    arabic: 'رَأَى الصَّيَّادُ دُبًّا كَبِيرًا فِي الْغَابَةِ.',
    german: 'Der Jäger sah einen großen Bären im Wald.',
    transliteration: 'Raʾā aṣ-ṣayyādu dubban kabīran fī al-ġābati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1429,
    arabic: 'نَجَا الْخَرُوفُ بِذَكَائِهِ.',
    german: 'Das Lamm entkam dank seiner Intelligenz.',
    transliteration: 'Naǧā al-ḫarūfu bi-ḏakāʾihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1430,
    arabic: 'يَأْخُذُ الرَّاعِي رَاتِبَهُ فِي نِهَايَةِ الشَّهْرِ.',
    german: 'Der Hirte bekommt sein Gehalt am Monatsende.',
    transliteration: 'Yaʾḫuḏu ar-rāʿī rātibahū fī nihāyati aš-šahri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 144 (word_ids 1431–1440): „Die enge Gasse".
/// Am Abend wird es in einer Gasse unruhig: ein Diebstahl, eine Kerze und ein Zeuge mit Gewissen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyFourStory = [
  Sentence(
    wordId: 1431,
    arabic: 'بَكَى الرَّضِيعُ فِي اللَّيْلِ وَنَهَضَتْ أُمُّهُ.',
    german: 'Der Säugling weinte in der Nacht und seine Mutter stand auf.',
    transliteration: 'Bakā ar-raḍīʿu fī al-layli wa-nahaḍat ʾummuhū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1432,
    arabic: 'وَضَعْتُ الْكُتُبَ عَلَى الرَّفِّ الْعَالِي.',
    german: 'Ich stellte die Bücher auf das hohe Regal.',
    transliteration: 'Waḍaʿtu al-kutuba ʿalā ar-raffi al-ʿālī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1433,
    arabic: 'يَطْلُبُ الرَّجُلُ الرِّزْقَ بِعَمَلِهِ كُلَّ يَوْمٍ.',
    german: 'Der Mann sucht seinen Lebensunterhalt jeden Tag durch seine Arbeit.',
    transliteration: 'Yaṭlubu ar-raǧulu ar-rizqa bi-ʿamalihī kulla yawmin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1434,
    arabic: 'مَشَيْنَا فِي زُقَاقٍ ضَيِّقٍ بَيْنَ الْبُيُوتِ.',
    german: 'Wir gingen durch eine enge Gasse zwischen den Häusern.',
    transliteration: 'Mašaynā fī zuqāqin ḍayyiqin bayna al-buyūti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1435,
    arabic: 'سَمِعَتِ الشُّرْطَةُ عَنِ السَّرِقَةِ فِي الزُّقَاقِ.',
    german: 'Die Polizei hörte vom Diebstahl in der Gasse.',
    transliteration: 'Samiʿat aš-šurṭatu ʿani as-sariqati fī az-zuqāqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1436,
    arabic: 'أَشْعَلَتِ الْجَدَّةُ شَمْعَةً عِنْدَ اِنْقِطَاعِ الْكَهْرَبَاءِ.',
    german: 'Die Großmutter zündete bei Stromausfall eine Kerze an.',
    transliteration: 'ʾAšʿalati al-ǧaddatu šamʿatan ʿinda inqiṭāʿi al-kahrabāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1437,
    arabic: 'جَلَسَ الْجَارُ فِي الشُّرْفَةِ وَشَرِبَ الشَّايَ.',
    german: 'Der Nachbar saß auf dem Balkon und trank Tee.',
    transliteration: 'Ǧalasa al-ǧāru fī aš-šurfati wa-šariba aš-šāya.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1438,
    arabic: 'يَعْمَلُ أَخِي فِي شُعْبَةِ الْحِسَابَاتِ.',
    german: 'Mein Bruder arbeitet in der Abteilung für Buchhaltung.',
    transliteration: 'Yaʿmalu ʾaḫī fī šuʿbati al-ḥisābāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1439,
    arabic: 'لِهَذِهِ السَّاعَةِ ضَمَانٌ لِمُدَّةِ سَنَتَيْنِ.',
    german: 'Diese Uhr hat zwei Jahre Garantie.',
    transliteration: 'Li-hāḏihi as-sāʿati ḍamānun li-muddati sanatayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1440,
    arabic: 'ضَمِيرُ الشَّاهِدِ لَمْ يَسْمَحْ لَهُ بِالْكَذِبِ.',
    german: 'Das Gewissen des Zeugen erlaubte ihm nicht zu lügen.',
    transliteration: 'Ḍamīru aš-šāhidi lam yasmaḥ lahū bi-al-kaḏibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 145 (word_ids 1441–1450): „Die Folgen einer Entscheidung".
/// Ein Mann denkt über die Konsequenzen seines Handelns nach und lernt, was Tugend bedeutet.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyFiveStory = [
  Sentence(
    wordId: 1441,
    arabic: 'وَقَفَ الْوَلَدُ عَلَى طَرَفِ الطَّرِيقِ.',
    german: 'Der Junge stand am Rand der Straße.',
    transliteration: 'Waqafa al-waladu ʿalā ṭarafi aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1442,
    arabic: 'كَتَبَ الشَّاعِرُ قَصِيدَةً مَلِيئَةً بِالْعَاطِفَةِ.',
    german: 'Der Dichter schrieb ein Gedicht voller Gefühl.',
    transliteration: 'Kataba aš-šāʿiru qaṣīdatan malīʾatan bi-al-ʿāṭifati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1443,
    arabic: 'فَكَّرَ الرَّجُلُ فِي عَاقِبَةِ قَرَارِهِ.',
    german: 'Der Mann dachte über die Konsequenz seiner Entscheidung nach.',
    transliteration: 'Fakkara ar-raǧulu fī ʿāqibati qarārihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1444,
    arabic: 'سَمِعْتُ عِبَارَةً جَدِيدَةً فِي الْفِيلْمِ.',
    german: 'Ich hörte im Film eine neue Redewendung.',
    transliteration: 'Samiʿtu ʿibāratan ǧadīdatan fī al-fīlmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1445,
    arabic: 'نَسْكُنُ فِي عِمَارَةٍ عَالِيَةٍ وَسَطَ الْمَدِينَةِ.',
    german: 'Wir wohnen in einem hohen Gebäude mitten in der Stadt.',
    transliteration: 'Naskunu fī ʿimāratin ʿāliyatin wasaṭa al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1446,
    arabic: 'لَمْ يَكُنْ تَرْكُ الْبَابِ مَفْتُوحًا إِلَّا غَبَاءً.',
    german: 'Die Tür offen zu lassen war nichts als Dummheit.',
    transliteration: 'Lam yakun tarku al-bābi maftūḥan ʾillā ġabāʾan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1447,
    arabic: 'دَفَعَ السَّائِقُ غَرَامَةً لِأَنَّهُ تَجَاوَزَ السُّرْعَةَ.',
    german: 'Der Fahrer zahlte ein Bußgeld, weil er zu schnell fuhr.',
    transliteration: 'Dafaʿa as-sāʾiqu ġarāmatan li-ʾannahū taǧāwaza as-surʿata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1448,
    arabic: 'تَعَطَّلَتِ الْغَسَّالَةُ وَاِمْتَلَأَ الْحَمَّامُ بِالْمَاءِ.',
    german: 'Die Waschmaschine ging kaputt und das Bad füllte sich mit Wasser.',
    transliteration: 'Taʿaṭṭalati al-ġassālatu wa-imtalaʾa al-ḥammāmu bi-al-māʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1449,
    arabic: 'فَتَحَ الْبَنْكُ فَرْعًا جَدِيدًا فِي حَيِّنَا.',
    german: 'Die Bank eröffnete eine neue Filiale in unserem Viertel.',
    transliteration: 'Fataḥa al-banku farʿan ǧadīdan fī ḥayyinā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1450,
    arabic: 'الصِّدْقُ فَضِيلَةٌ يُحِبُّهَا النَّاسُ.',
    german: 'Ehrlichkeit ist eine Tugend, die die Menschen lieben.',
    transliteration: 'Aṣ-ṣidqu faḍīlatun yuḥibbuhā an-nāsu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 146 (word_ids 1451–1460): „Der Dieb in der Bäckerei".
/// Ein hungriger Dieb dringt nachts in eine Bäckerei ein und steht später vor dem Richter.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortySixStory = [
  Sentence(
    wordId: 1451,
    arabic: 'نَظَّفَ الْعَامِلُ الْأَرْضَ بِفُرْشَاةٍ قَدِيمَةٍ.',
    german: 'Der Arbeiter reinigte den Boden mit einer alten Bürste.',
    transliteration: 'Naẓẓafa al-ʿāmilu al-ʾarḍa bi-furšātin qadīmatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1452,
    arabic: 'هَذَا الْفِيلْمُ لِفِئَةِ الْأَطْفَالِ.',
    german: 'Dieser Film ist für die Gruppe der Kinder.',
    transliteration: 'Hāḏā al-fīlmu li-fiʾati al-ʾaṭfāli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1453,
    arabic: 'سَأَلَ الْقَاضِي الشَّاهِدَ عَنِ اللَّيْلَةِ.',
    german: 'Der Richter fragte den Zeugen nach der Nacht.',
    transliteration: 'Saʾala al-qāḍī aš-šāhida ʿani al-laylati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1454,
    arabic: 'نَامَتِ الْقِطَّةُ عَلَى الْكُرْسِيِّ بَعْدَ الظُّهْرِ.',
    german: 'Die Katze schlief nach dem Mittag auf dem Stuhl.',
    transliteration: 'Nāmati al-qiṭṭatu ʿalā al-kursiyyi baʿda aẓ-ẓuhri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1455,
    arabic: 'أَعْطَانِي الْخَبَّازُ قِطْعَةً مِنَ الْكَعْكِ.',
    german: 'Der Bäcker gab mir ein Stück Kuchen.',
    transliteration: 'ʾAʿṭānī al-ḫabbāzu qiṭʿatan mina al-kaʿki.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1456,
    arabic: 'قَدَّمَ الْأَخُ كَفَالَةً لِيَخْرُجَ صَدِيقُهُ مِنَ السِّجْنِ.',
    german: 'Der Bruder stellte eine Bürgschaft, damit sein Freund aus dem Gefängnis kommt.',
    transliteration: 'Qaddama al-ʾaḫu kafālatan li-yaḫruǧa ṣadīquhū mina as-siǧni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1457,
    arabic: 'أَكَلَ الْجَائِعُ لُقْمَةً وَاحِدَةً وَشَكَرَ الْخَبَّازَ.',
    german: 'Der Hungrige aß einen einzigen Bissen und dankte dem Bäcker.',
    transliteration: 'ʾAkala al-ǧāʾiʿu luqmatan wāḥidatan wa-šakara al-ḫabbāza.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1458,
    arabic: 'دَخَلَ لِصٌّ إِلَى الْمَخْبَزِ فِي اللَّيْلِ.',
    german: 'Ein Dieb drang nachts in die Bäckerei ein.',
    transliteration: 'Daḫala liṣṣun ʾilā al-maḫbazi fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1459,
    arabic: 'زُرْنَا الْمَتْحَفَ الْوَطَنِيَّ يَوْمَ الْجُمُعَةِ.',
    german: 'Wir besuchten am Freitag das Nationalmuseum.',
    transliteration: 'Zurnā al-matḥafa al-waṭaniyya yawma al-ǧumʿati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1460,
    arabic: 'يُفْتَحُ الْمَخْبَزُ قَبْلَ الْفَجْرِ كُلَّ صَبَاحٍ.',
    german: 'Die Bäckerei öffnet jeden Morgen vor Morgengrauen.',
    transliteration: 'Yuftaḥu al-maḫbazu qabla al-faǧri kulla ṣabāḥin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 147 (word_ids 1461–1470): „Der Umzug".
/// Eine Familie zieht in eine neue Wohnung; Heizung, Handtuch und gute Laune gehören dazu.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortySevenStory = [
  Sentence(
    wordId: 1461,
    arabic: 'لِلشَّقَّةِ الْجَدِيدَةِ مَزِيَّةٌ وَاحِدَةٌ، وَهِيَ الْقُرْبُ مِنَ الْعَمَلِ.',
    german: 'Die neue Wohnung hat einen Vorteil: Sie liegt nahe an der Arbeit.',
    transliteration: 'Lil-šaqqati al-ǧadīdati maziyyatun wāḥidatun, wa-hiya al-qurbu mina al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1462,
    arabic: 'بَدَأَ الْمُهَنْدِسُ مَشْرُوعًا لِبِنَاءِ بَيْتٍ صَغِيرٍ.',
    german: 'Der Ingenieur begann ein Projekt zum Bau eines kleinen Hauses.',
    transliteration: 'Badaʾa al-muhandisu mašrūʿan li-bināʾi baytin ṣaġīrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1463,
    arabic: 'قَالَ الْمُتَّهَمُ إِنَّهُ لَمْ يَكُنْ فِي الْبَيْتِ.',
    german: 'Der Angeklagte sagte, er sei nicht im Haus gewesen.',
    transliteration: 'Qāla al-muttahamu ʾinnahū lam yakun fī al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1464,
    arabic: 'صَوْتُ الْمُحَرِّكِ عَالٍ جِدًّا فِي الصَّبَاحِ.',
    german: 'Das Geräusch des Motors ist am Morgen sehr laut.',
    transliteration: 'Ṣawtu al-muḥarriki ʿālin ǧiddan fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1465,
    arabic: 'يَحْتَاجُ الْمُوَظَّفُ إِلَى مُسْتَنَدٍ رَسْمِيٍّ لِلسَّفَرِ.',
    german: 'Der Angestellte braucht für die Reise eine offizielle Urkunde.',
    transliteration: 'Yaḥtāǧu al-muwaẓẓafu ʾilā mustanadin rasmiyyin lil-safari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1466,
    arabic: 'نَسِيَتِ الْبِنْتُ الْمُشْطَ فِي حَقِيبَةِ السَّفَرِ.',
    german: 'Das Mädchen vergaß den Kamm in der Reisetasche.',
    transliteration: 'Nasiyati al-bintu al-mušṭa fī ḥaqībati as-safari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1467,
    arabic: 'جَفَّفَ الْوَلَدُ وَجْهَهُ بِمُنَشْفَةٍ نَظِيفَةٍ.',
    german: 'Der Junge trocknete sein Gesicht mit einem sauberen Handtuch.',
    transliteration: 'Ǧaffafa al-waladu waǧhahū bi-munaššafatin naẓīfatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1468,
    arabic: 'شَغَّلْنَا الْمِدْفَأَةَ لِأَنَّ الْجَوَّ بَارِدٌ.',
    german: 'Wir schalteten die Heizung ein, weil das Wetter kalt ist.',
    transliteration: 'Šaġġalnā al-midfaʾata li-ʾanna al-ǧawwa bāridun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1469,
    arabic: 'مِزَاجُ أَبِي حَسَنٌ بَعْدَ الْعُطْلَةِ.',
    german: 'Die Laune meines Vaters ist nach dem Urlaub gut.',
    transliteration: 'Mizāǧu ʾabī ḥasanun baʿda al-ʿuṭlati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1470,
    arabic: 'اِسْتَعَارَ الطَّالِبُ مِسْطَرَةً مِنْ صَدِيقِهِ.',
    german: 'Der Schüler lieh sich von seinem Freund ein Lineal.',
    transliteration: 'Istaʿāra aṭ-ṭālibu misṭaratan min ṣadīqihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 148 (word_ids 1471–1480): „Das Testament des Großvaters".
/// Nach dem Tod des Großvaters kommt die Familie zusammen, um Erbe und Dokumente zu klären.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyEightStory = [
  Sentence(
    wordId: 1471,
    arabic: 'الْأَرْضُ فِي الْقَرْيَةِ مِلْكِيَّةٌ خَاصَّةٌ لِلْعَائِلَةِ.',
    german: 'Das Land im Dorf ist Privateigentum der Familie.',
    transliteration: 'Al-ʾarḍu fī al-qaryati milkiyyatun ḫāṣṣatun lil-ʿāʾilati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1472,
    arabic: 'تَرَكَ الْجَدُّ مِيرَاثًا كَبِيرًا لِأَوْلَادِهِ.',
    german: 'Der Großvater hinterließ seinen Kindern ein großes Erbe.',
    transliteration: 'Taraka al-ǧaddu mīrāṯan kabīran li-ʾawlādihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1473,
    arabic: 'يَنْتَظِرُ أَهْلُ الْبَيْتِ مِيلَادَ الطِّفْلِ فِي الرَّبِيعِ.',
    german: 'Die Familie wartet im Frühling auf die Geburt des Kindes.',
    transliteration: 'Yantaẓiru ʾahlu al-bayti mīlāda aṭ-ṭifli fī ar-rabīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1474,
    arabic: 'لَا يَسْكُنُ أَحَدٌ فِي هَذِهِ النَّاحِيَةِ مِنَ الْجَبَلِ.',
    german: 'Niemand wohnt in dieser Gegend des Berges.',
    transliteration: 'Lā yaskunu aḥadun fī hāḏihi an-nāḥiyati mina al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1475,
    arabic: 'أَخَذَتِ الْبِنْتُ نَصِيبَهَا مِنَ الْمَالِ.',
    german: 'Das Mädchen nahm ihren Anteil am Geld.',
    transliteration: 'ʾAḫaḏati al-bintu naṣībahā mina al-māli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1476,
    arabic: 'طَلَبَ الْقَاضِي نُسْخَةً مِنَ الْعَقْدِ.',
    german: 'Der Richter verlangte eine Kopie des Vertrags.',
    transliteration: 'Ṭalaba al-qāḍī nusḫatan mina al-ʿaqdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1477,
    arabic: 'كَتَبَ الْجَدُّ وَصِيَّتَهُ قَبْلَ وَفَاتِهِ.',
    german: 'Der Großvater schrieb sein Testament vor seinem Tod.',
    transliteration: 'Kataba al-ǧaddu wasiyyatahū qabla wafātihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1478,
    arabic: 'عِنْدَ النَّاسِ وَعْيٌ كَبِيرٌ بِحُقُوقِهِمْ.',
    german: 'Die Leute haben ein großes Bewusstsein für ihre Rechte.',
    transliteration: 'ʿInda an-nāsi waʿyun kabīrun bi-ḥuqūqihim.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1479,
    arabic: 'حَضَرَ وَكِيلُ الْعَائِلَةِ إِلَى الْمَحْكَمَةِ.',
    german: 'Der Vertreter der Familie erschien vor Gericht.',
    transliteration: 'Ḥaḍara wakīlu al-ʿāʾilati ʾilā al-maḥkamati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1480,
    arabic: 'حَفِظَ الْمُحَامِي الْوِثِيقَةَ فِي خِزَانَةٍ آمِنَةٍ.',
    german: 'Der Anwalt bewahrte das Dokument in einem sicheren Schrank auf.',
    transliteration: 'Ḥafiẓa al-muḥāmī al-wiṯīqata fī ḫizānatin ʾāminatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 149 (word_ids 1481–1490): „Der Markt am Morgen".
/// Auf dem Markt prüfen Käufer frisches Brot, warme Milch und ein scharfes Messer.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFortyNineStory = [
  Sentence(
    wordId: 1481,
    arabic: 'رَبَّى الْعَمُّ طِفْلًا يَتِيمًا بَعْدَ وَفَاةِ أَبَوَيْهِ.',
    german: 'Der Onkel zog nach dem Tod der Eltern ein Waisenkind groß.',
    transliteration: 'Rabbā al-ʿammu ṭiflan yatīman baʿda wafāti ʾabawayhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1482,
    arabic: 'ظَهَرَ أَنَّ الْمُتَّهَمَ بَرِيءٌ.',
    german: 'Es zeigte sich, dass der Angeklagte unschuldig ist.',
    transliteration: 'Ẓahara ʾanna al-muttahama barīʾun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1483,
    arabic: 'السَّيْرُ فِي الزُّقَاقِ بَطِيءٌ صَبَاحًا.',
    german: 'Der Verkehr in der Gasse ist morgens langsam.',
    transliteration: 'As-sayru fī az-zuqāqi baṭīʾun ṣabāḥan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1484,
    arabic: 'اِحْذَرْ، فَالسِّكِّينُ حَادٌّ جِدًّا.',
    german: 'Pass auf, das Messer ist sehr scharf.',
    transliteration: 'Iḥḏar, fa-as-sikkīnu ḥāddun ǧiddan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1485,
    arabic: 'شَرِبْنَا حَلِيبًا دَافِئًا فِي الصَّبَاحِ.',
    german: 'Wir tranken morgens warme Milch.',
    transliteration: 'Šaribnā ḥalīban dāfiʾan fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1486,
    arabic: 'لَبِسَ الرَّجُلُ مِعْطَفًا أَزْرَقَ دَاكِنًا.',
    german: 'Der Mann trug einen dunkelblauen Mantel.',
    transliteration: 'Labisa ar-raǧulu miʿṭafan ʾazraqa dākinan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1487,
    arabic: 'اِشْتَرَتْ أُمِّي بِسَاطًا سَمِيكًا لِلشِّتَاءِ.',
    german: 'Meine Mutter kaufte einen dicken Teppich für den Winter.',
    transliteration: 'Ištarat ʾummī bisāṭan samīkan lil-šitāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1488,
    arabic: 'الْإِفْرَاطُ فِي السُّكَّرِ ضَارٌّ بِالصِّحَّةِ.',
    german: 'Zu viel Zucker ist schädlich für die Gesundheit.',
    transliteration: 'Al-ʾifrāṭu fī as-sukkari ḍārrun bi-aṣ-ṣiḥḥati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1489,
    arabic: 'الْخُبْزُ الطَّرِيُّ أَطْيَبُ مِنَ الْقَدِيمِ.',
    german: 'Das frische Brot schmeckt besser als das alte.',
    transliteration: 'Al-ḫubzu aṭ-ṭariyyu ʾaṭyabu mina al-qadīmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1490,
    arabic: 'لَا تَكُنْ عَجُولًا، فَالْوَقْتُ كَافٍ.',
    german: 'Sei nicht hastig, die Zeit reicht.',
    transliteration: 'Lā takun ʿaǧūlan, fa-al-waqtu kāfin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 150 (word_ids 1491–1500): „Optimist und Pessimist".
/// Zwei Freunde erleben denselben schwierigen Tag und sehen ihn völlig verschieden.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyStory = [
  Sentence(
    wordId: 1491,
    arabic: 'كَانَ الِامْتِحَانُ عَسِيرًا عَلَى الطُّلَّابِ.',
    german: 'Die Prüfung war für die Studenten schwierig.',
    transliteration: 'Kāna al-imtiḥānu ʿasīran ʿalā aṭ-ṭullābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1492,
    arabic: 'الْحِمَارُ عَنِيدٌ وَلَا يَتْرُكُ مَكَانَهُ.',
    german: 'Der Esel ist stur und verlässt seinen Platz nicht.',
    transliteration: 'Al-ḥimāru ʿanīdun wa-lā yatruku makānahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1493,
    arabic: 'خَرَجَ الْأَبُ غَاضِبًا مِنَ الْغُرْفَةِ.',
    german: 'Der Vater verließ wütend das Zimmer.',
    transliteration: 'Ḫaraǧa al-ʾabu ġāḍiban mina al-ġurfati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1494,
    arabic: 'اِخْتَارَتِ الْبِنْتُ لَوْنًا فَاتِحًا لِلْحَائِطِ.',
    german: 'Das Mädchen wählte eine helle Farbe für die Wand.',
    transliteration: 'Iḫtārati al-bintu lawnan fātiḥan lil-ḥāʾiṭi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1495,
    arabic: 'رَمَيْنَا اللَّحْمَ الْفَاسِدَ فِي الْقُمَامَةِ.',
    german: 'Wir warfen das verdorbene Fleisch in den Müll.',
    transliteration: 'Ramaynā al-laḥma al-fāsida fī al-qumāmati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1496,
    arabic: 'كَانَ الْمَاءُ فِي الْبِرْكَةِ قَذِرًا.',
    german: 'Das Wasser im Teich war schmutzig.',
    transliteration: 'Kāna al-māʾu fī al-birkati qaḏiran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1497,
    arabic: 'مِنَ اللَّازِمِ أَنْ نَبْدَأَ الْعَمَلَ مُبَكِّرًا.',
    german: 'Es ist nötig, dass wir früh mit der Arbeit beginnen.',
    transliteration: 'Mina al-lāzimi ʾan nabdaʾa al-ʿamala mubakkiran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1498,
    arabic: 'الْحَسَاءُ مَالِحٌ فَأَضَفْنَا إِلَيْهِ مَاءً.',
    german: 'Die Suppe ist salzig, also gaben wir Wasser dazu.',
    transliteration: 'Al-ḥasāʾu māliḥun fa-ʾaḍafnā ʾilayhi māʾan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1499,
    arabic: 'الرَّجُلُ الْمُتَشَائِمُ يَرَى الْمَشَاكِلَ فَقَطْ.',
    german: 'Der pessimistische Mann sieht nur Probleme.',
    transliteration: 'Ar-raǧulu al-mutašāʾimu yarā al-mašākila faqaṭ.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1500,
    arabic: 'أَنَا مُتَفَائِلٌ بِالْمُسْتَقْبَلِ رَغْمَ الصُّعُوبَاتِ.',
    german: 'Ich bin trotz der Schwierigkeiten optimistisch für die Zukunft.',
    transliteration: 'ʾAnā mutafāʾilun bi-al-mustaqbali raġma aṣ-ṣuʿūbāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 151 (word_ids 1501–1510): „Der neue Marktplatz".
/// Eine Stadt baut einen Platz mit Formen, Bänken und viel Betrieb.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyOneStory = [
  Sentence(
    wordId: 1501,
    arabic: 'شَكْلُ السَّقْفِ مُثَلَّثٌ.',
    german: 'Die Form des Dachs ist dreieckig.',
    transliteration: 'Šaklu as-saqfi muṯallaṯun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1502,
    arabic: 'لَمْ يَكُنِ الْوَلَدُ مُذْنِبًا.',
    german: 'Der Junge war nicht schuldig.',
    transliteration: 'Lam yakuni al-waladu muḏniban.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1503,
    arabic: 'عَلَى الطَّاوِلَةِ صُنْدُوقٌ مُرَبَّعٌ.',
    german: 'Auf dem Tisch steht eine viereckige Kiste.',
    transliteration: 'ʿalā aṭ-ṭāwilati ṣundūqun murabbaʿun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1504,
    arabic: 'هَذَا الْكُرْسِيُّ مُرِيحٌ جِدًّا.',
    german: 'Dieser Stuhl ist sehr bequem.',
    transliteration: 'Hāḏā al-kursiyyu murīḥun ǧiddan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1505,
    arabic: 'الشَّارِعُ مُزْدَحِمٌ فِي الْمَسَاءِ.',
    german: 'Die Straße ist abends überfüllt.',
    transliteration: 'Aš-šāriʿu muzdaḥimun fī al-masāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1506,
    arabic: 'اِشْتَرَيْنَا طَبَقًا مُسْتَدِيرًا لِلْخُبْزِ.',
    german: 'Wir kauften einen runden Teller für das Brot.',
    transliteration: 'Ištaraynā ṭabaqan mustadīran lil-ḫubzi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1507,
    arabic: 'الطَّرِيقُ مُسْتَوٍ وَلَيْسَ فِيهِ حُفَرٌ.',
    german: 'Die Straße ist eben und hat keine Löcher.',
    transliteration: 'Aṭ-ṭarīqu mustawin wa-laysa fīhi ḥufarun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1508,
    arabic: 'الْمَوْضُوعُ مُعَقَّدٌ وَيَحْتَاجُ إِلَى وَقْتٍ.',
    german: 'Das Thema ist kompliziert und braucht Zeit.',
    transliteration: 'Al-mawḍūʿu muʿaqqadun wa-yaḥtāǧu ʾilā waqtin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1509,
    arabic: 'سَمِعْنَا خَبَرًا مُقْلِقًا عَنِ الطَّقْسِ.',
    german: 'Wir hörten eine beunruhigende Nachricht über das Wetter.',
    transliteration: 'Samiʿnā ḫabaran muqliqan ʿani aṭ-ṭaqsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1510,
    arabic: 'التُّفَّاحُ النَّاضِجُ حُلْوٌ.',
    german: 'Der reife Apfel ist süß.',
    transliteration: 'At-tuffāḥu an-nāḍiǧu ḥulwun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 152 (word_ids 1511–1520): „Ein guter Rat".
/// Kleine Alltagsszenen mit Ratschlägen, Gründen und Folgen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyTwoStory = [
  Sentence(
    wordId: 1511,
    arabic: 'الْعَسَلُ نَافِعٌ لِلْحَلْقِ.',
    german: 'Honig ist gut für den Hals.',
    transliteration: 'Al-ʿasalu nāfiʿun lil-ḥalqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1512,
    arabic: 'السُّؤَالُ يَسِيرٌ وَجَوَابُهُ قَصِيرٌ.',
    german: 'Die Frage ist einfach und ihre Antwort kurz.',
    transliteration: 'As-suʾālu yasīrun wa-ǧawābuhū qaṣīrun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1513,
    arabic: 'لَمْ أَكُنْ أَعْرِفُهُ أَصْلًا.',
    german: 'Ich kannte ihn überhaupt nicht.',
    transliteration: 'Lam ʾakun ʾaʿrifuhū ʾaṣlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1514,
    arabic: 'بَيْنَمَا كُنْتُ أَقْرَأُ، دَقَّ الْجَرَسُ.',
    german: 'Während ich las, klingelte es.',
    transliteration: 'Baynamā kuntu ʾaqraʾu, daqqa al-ǧarasu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1515,
    arabic: 'لَمْ تُمْطِرِ السَّمَاءُ، وَبِالتَّالِي قَلَّ الْمَاءُ.',
    german: 'Der Himmel regnete nicht, folglich wurde das Wasser knapp.',
    transliteration: 'Lam tumṭiri as-samāʾu, wa-bi-t-tālī qalla al-māʾu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1516,
    arabic: 'فَهِمْتُ الدَّرْسَ تَمَامًا.',
    german: 'Ich verstand die Lektion völlig.',
    transliteration: 'Fahimtu ad-darsa tamāman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1517,
    arabic: 'ذَهَبْنَا إِلَى الْمَدِينَةِ حَيْثُ يَعْمَلُ أَخِي.',
    german: 'Wir fuhren in die Stadt, wo mein Bruder arbeitet.',
    transliteration: 'Ḏahabnā ʾilā al-madīnati ḥayṯu yaʿmalu ʾaḫī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1518,
    arabic: 'أُحِبُّ الْفَوَاكِهَ، خَاصَّةً التِّينَ.',
    german: 'Ich mag Obst, besonders Feigen.',
    transliteration: 'ʾUḥibbu al-fawākiha, ḫāṣṣatan at-tīna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1519,
    arabic: 'كَانَ الْبَرْدُ شَدِيدًا فِي اللَّيْلِ.',
    german: 'Die Kälte war nachts heftig.',
    transliteration: 'Kāna al-bardu šadīdan fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1520,
    arabic: 'عَكْسًا لِأَخِيهِ، يُحِبُّ سَامِي الْقِرَاءَةَ.',
    german: 'Anders als sein Bruder liest Sami gern.',
    transliteration: 'ʿAksan li-ʾaḫīhi, yuḥibbu Sāmī al-qirāʾata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 153 (word_ids 1521–1530): „Zeit und Ort".
/// Kurze Sätze über Pläne, Mannschaften und Entscheidungen im Laufe des Jahres.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyThreeStory = [
  Sentence(
    wordId: 1521,
    arabic: 'الْفِكْرَةُ جَيِّدَةٌ، لَكِنَّهَا عَمَلِيًّا صَعْبَةٌ.',
    german: 'Die Idee ist gut, aber praktisch schwierig.',
    transliteration: 'Al-fikratu ǧayyidatun, lākinnahā ʿamaliyyan ṣaʿbatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1522,
    arabic: 'النَّاسُ عُمُومًا يُحِبُّونَ الصَّبَاحَ الْهَادِئَ.',
    german: 'Die Leute mögen im Allgemeinen den ruhigen Morgen.',
    transliteration: 'An-nāsu ʿumūman yuḥibbūna aṣ-ṣabāḥa al-hādiʾa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1523,
    arabic: 'أَغْلَقْنَا الْمَحَلَّ مُؤَقَّتًا.',
    german: 'Wir schlossen den Laden vorübergehend.',
    transliteration: 'ʾAġlaqnā al-maḥalla muʾaqqatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1524,
    arabic: 'اِتَّصَلَ الْمُدِيرُ بِالْعَامِلِ مُبَاشَرَةً.',
    german: 'Der Leiter rief den Arbeiter direkt an.',
    transliteration: 'Ittaṣala al-mudīru bi-al-ʿāmili mubāšaratan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1525,
    arabic: 'قَرَّرَ الْفَرِيقُ نِهَائِيًّا أَنْ يَسْتَمِرَّ.',
    german: 'Das Team entschied endgültig weiterzumachen.',
    transliteration: 'Qarrara al-farīqu nihāʾiyyan ʾan yastamirra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1526,
    arabic: 'وَقَفَ الْجَمِيعُ صَامِتِينَ إِزَاءَ الْخَبَرِ.',
    german: 'Alle standen angesichts der Nachricht schweigend da.',
    transliteration: 'Waqafa al-ǧamīʿu ṣāmitīna ʾizāʾa al-ḫabari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1527,
    arabic: 'وَصَلَ حَوَالَيْ عِشْرِينَ رَجُلًا.',
    german: 'Etwa zwanzig Männer kamen an.',
    transliteration: 'Waṣala ḥawālay ʿišrīna raǧulan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1528,
    arabic: 'خِلَالَ الصَّيْفِ سَافَرْنَا إِلَى الْجَبَلِ.',
    german: 'Im Laufe des Sommers reisten wir ins Gebirge.',
    transliteration: 'Ḫilāla aṣ-ṣayfi sāfarnā ʾilā al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1529,
    arabic: 'لَعِبَ فَرِيقُنَا ضِدَّ فَرِيقِ الْمَدِينَةِ.',
    german: 'Unser Team spielte gegen das Team der Stadt.',
    transliteration: 'Laʿiba farīqunā ḍidda farīqi al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1530,
    arabic: 'لَدَى الطَّبِيبِ مَرِيضٌ فِي الْغُرْفَةِ.',
    german: 'Beim Arzt ist ein Patient im Zimmer.',
    transliteration: 'Ladā aṭ-ṭabībi marīḍun fī al-ġurfati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 154 (word_ids 1531–1540): „Die Wächter der Burg".
/// Soldaten und ein Kommandant sichern eine Burg an der Grenze.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyFourStory = [
  Sentence(
    wordId: 1531,
    arabic: 'سَارَ الْجُنْدِيُّ نَحْوَ الْبَابِ.',
    german: 'Der Soldat ging auf das Tor zu.',
    transliteration: 'Sāra al-ǧundiyyu naḥwa al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1532,
    arabic: 'أَحَاطَ السُّورُ بِالْقَلْعَةِ.',
    german: 'Die Mauer umgab die Burg.',
    transliteration: 'ʾAḥāṭa as-sūru bi-al-qalʿati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1533,
    arabic: 'اِطَّلَعَ الْقَائِدُ عَلَى التَّقْرِيرِ.',
    german: 'Der Kommandant nahm Einblick in den Bericht.',
    transliteration: 'Iṭṭalaʿa al-qāʾidu ʿalā at-taqrīri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1534,
    arabic: 'حَارَبَ الْجُنُودُ الْعَدُوَّ عِنْدَ الْحُدُودِ.',
    german: 'Die Soldaten bekämpften den Feind an der Grenze.',
    transliteration: 'Ḥāraba al-ǧunūdu al-ʿaduwwa ʿinda al-ḥudūdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1535,
    arabic: 'أَدَارَ الْأَمِيرُ شُؤُونَ الْمَدِينَةِ بِحِكْمَةٍ.',
    german: 'Der Fürst leitete die Angelegenheiten der Stadt weise.',
    transliteration: 'ʾAdāra al-ʾamīru šuʾūna al-madīnati bi-ḥikmatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1536,
    arabic: 'فَتَّشَ الْحَارِسُ الْحَقَائِبَ عِنْدَ الْبَوَّابَةِ.',
    german: 'Der Wächter durchsuchte die Taschen am Tor.',
    transliteration: 'Fattaša al-ḥārisu al-ḥaqāʾiba ʿinda al-bawwābati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1537,
    arabic: 'تَفَقَّدَ الْقَائِدُ الْأَسْلِحَةَ كُلَّ صَبَاحٍ.',
    german: 'Der Kommandant überprüfte jeden Morgen die Waffen.',
    transliteration: 'Tafaqqada al-qāʾidu al-ʾaslihata kulla ṣabāḥin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1538,
    arabic: 'رَاقَبَ الْحَارِسُ الطَّرِيقَ مِنَ الْبُرْجِ.',
    german: 'Der Wächter beobachtete die Straße vom Turm.',
    transliteration: 'Rāqaba al-ḥārisu aṭ-ṭarīqa mina al-burǧi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1539,
    arabic: 'قَضَى الْجُنْدِيُّ لَيْلَةً طَوِيلَةً فِي الْبُرْجِ.',
    german: 'Der Soldat verbrachte eine lange Nacht im Turm.',
    transliteration: 'Qaḍā al-ǧundiyyu laylatan ṭawīlatan fī al-burǧi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1540,
    arabic: 'غَلَبَ الْجَيْشُ الْخَوْفَ وَدَخَلَ الْمَدِينَةَ.',
    german: 'Das Heer überwand die Angst und betrat die Stadt.',
    transliteration: 'Ġalaba al-ǧayšu al-ḫawfa wa-daḫala al-madīnata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 155 (word_ids 1541–1550): „Die Untersuchung".
/// Ein Fall wird beraten, geprüft und mit einem Experiment bewiesen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyFiveStory = [
  Sentence(
    wordId: 1541,
    arabic: 'جَازَ الْمُسَافِرُ الْحَدَّ مِنْ دُونِ مُشْكِلَةٍ.',
    german: 'Der Reisende überschritt die Grenze ohne Probleme.',
    transliteration: 'Ǧāza al-musāfiru al-ḥadda min dūni mušklatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1542,
    arabic: 'رَافَقَ الْمُحَامِي مُوَكِّلَهُ إِلَى الْمَحْكَمَةِ.',
    german: 'Der Anwalt begleitete seinen Mandanten zum Gericht.',
    transliteration: 'Rāfaqa al-muḥāmī muwakkilahū ʾilā al-maḥkamati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1543,
    arabic: 'تَشَاوَرَ أَهْلُ الْقَرْيَةِ قَبْلَ الْقَرَارِ.',
    german: 'Die Dorfbewohner berieten sich vor der Entscheidung.',
    transliteration: 'Tašāwara ʾahlu al-qaryati qabla al-qarāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1544,
    arabic: 'أَبْقَى الْأَبُ بَعْضَ الْمَالِ لِلْمُسْتَقْبَلِ.',
    german: 'Der Vater behielt etwas Geld für die Zukunft.',
    transliteration: 'ʾAbqā al-ʾabu baʿḍa al-māli lil-mustaqbali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1545,
    arabic: 'وَكَّلَ التَّاجِرُ مُحَامِيًا بِالْقَضِيَّةِ.',
    german: 'Der Händler beauftragte einen Anwalt mit dem Fall.',
    transliteration: 'Wakkala at-tāǧiru muḥāmiyan bi-al-qaḍiyyati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1546,
    arabic: 'تَمَكَّنَ الطَّالِبُ مِنْ حَلِّ الْمَسْأَلَةِ.',
    german: 'Der Schüler konnte die Aufgabe lösen.',
    transliteration: 'Tamakkana aṭ-ṭālibu min ḥalli al-masʾalati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1547,
    arabic: 'أَسْقَطَ الْوَلَدُ الْكُوبَ عَلَى الْأَرْضِ.',
    german: 'Der Junge ließ die Tasse auf den Boden fallen.',
    transliteration: 'ʾAsqaṭa al-waladu al-kūba ʿalā al-ʾarḍi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1548,
    arabic: 'أَثْبَتَ الشَّاهِدُ أَنَّ الرَّجُلَ بَرِيءٌ.',
    german: 'Der Zeuge bewies, dass der Mann unschuldig ist.',
    transliteration: 'ʾAṯbata aš-šāhidu ʾanna ar-raǧula barīʾun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1549,
    arabic: 'أَجْرَى الْعَالِمُ تَجْرِبَةً فِي الْمُخْتَبَرِ.',
    german: 'Der Forscher führte im Labor ein Experiment durch.',
    transliteration: 'ʾAǧrā al-ʿālimu taǧribatan fī al-muḫtabari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1550,
    arabic: 'اِسْتَقَامَ الْأَمْرُ بَعْدَ الْحِوَارِ.',
    german: 'Die Sache kam nach dem Gespräch in Ordnung.',
    transliteration: 'Istaqāma al-ʾamru baʿda al-ḥiwāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 156 (word_ids 1551–1560): „Der neue Mitarbeiter".
/// Ein Angestellter findet seinen Platz im Team und steigt auf.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftySixStory = [
  Sentence(
    wordId: 1551,
    arabic: 'تَهَرَّبَ الْعَامِلُ مِنَ الْمَسْؤُولِيَّةِ.',
    german: 'Der Arbeiter drückte sich vor der Verantwortung.',
    transliteration: 'Taharraba al-ʿāmilu mina al-masʾūliyyati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1552,
    arabic: 'اِنْسَجَمَ الْمُوَظَّفُ الْجَدِيدُ مَعَ الْفَرِيقِ.',
    german: 'Der neue Angestellte passte gut ins Team.',
    transliteration: 'Insaǧama al-muwaẓẓafu al-ǧadīdu maʿa al-farīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1553,
    arabic: 'اِعْتَمَلَ الْمُحَرِّكُ طَوَالَ اللَّيْلِ.',
    german: 'Der Motor arbeitete die ganze Nacht.',
    transliteration: 'Iʿtamala al-muḥarriku ṭawāla al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1554,
    arabic: 'خَشِيَ الْوَلَدُ الْكَلْبَ الْكَبِيرَ.',
    german: 'Der Junge fürchtete den großen Hund.',
    transliteration: 'Ḫašiya al-waladu al-kalba al-kabīra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1555,
    arabic: 'دَامَ الِاجْتِمَاعُ سَاعَتَيْنِ.',
    german: 'Die Besprechung dauerte zwei Stunden.',
    transliteration: 'Dāma al-iǧtimāʿu sāʿatayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1556,
    arabic: 'أَحْسَنَ الْمُوَظَّفُ عَمَلَهُ هَذَا الْأُسْبُوعَ.',
    german: 'Der Angestellte machte seine Arbeit diese Woche gut.',
    transliteration: 'ʾAḥsana al-muwaẓẓafu ʿamalahū hāḏā al-ʾusbūʿa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1557,
    arabic: 'اِنْتَهَجَ الْمُدِيرُ طَرِيقًا جَدِيدًا فِي الْإِدَارَةِ.',
    german: 'Der Leiter schlug einen neuen Weg in der Führung ein.',
    transliteration: 'Intahaǧa al-mudīru ṭarīqan ǧadīdan fī al-ʾidārati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1558,
    arabic: 'شَغَلَ الْعَمَلُ الْجَدِيدُ وَقْتَ سَعِيدٍ كُلَّهُ.',
    german: 'Die neue Arbeit beschäftigte Saids ganze Zeit.',
    transliteration: 'Šaġala al-ʿamalu al-ǧadīdu waqta Saʿīdin kullahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1559,
    arabic: 'قَرَّرَتِ الشَّرِكَةُ فَتْحَ فَرْعٍ جَدِيدٍ.',
    german: 'Die Firma entschied, eine neue Filiale zu eröffnen.',
    transliteration: 'Qarrarati aš-šarikatu fatḥa farʿin ǧadīdin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1560,
    arabic: 'اِرْتَقَى الْمُوَظَّفُ إِلَى مَنْصِبٍ أَعْلَى.',
    german: 'Der Angestellte stieg auf eine höhere Stelle auf.',
    transliteration: 'Irtaqā al-muwaẓẓafu ʾilā manṣibin ʾaʿlā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 157 (word_ids 1561–1570): „Wasser und Wissen".
/// Vom Fluss über den Kochtopf bis ins Labor: Wasser regt zum Fragen an.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftySevenStory = [
  Sentence(
    wordId: 1561,
    arabic: 'تَدَفَّقَ الْمَاءُ مِنَ السَّدِّ.',
    german: 'Das Wasser strömte aus dem Staudamm.',
    transliteration: 'Tadaffaqa al-māʾu mina as-saddi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1562,
    arabic: 'اِنْسَابَ النَّهْرُ بَيْنَ الْأَشْجَارِ.',
    german: 'Der Fluss floss zwischen den Bäumen.',
    transliteration: 'Insāba an-nahru bayna al-ʾašǧāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1563,
    arabic: 'أَقْلَعَتِ الطَّائِرَةُ فِي الصَّبَاحِ.',
    german: 'Das Flugzeug startete am Morgen.',
    transliteration: 'ʾAqlaʿati aṭ-ṭāʾiratu fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1564,
    arabic: 'رَدَّدَ الطِّفْلُ الْكَلِمَةَ بَعْدَ الْمُعَلِّمِ.',
    german: 'Das Kind wiederholte das Wort nach dem Lehrer.',
    transliteration: 'Raddada aṭ-ṭiflu al-kalimata baʿda al-muʿallimi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1565,
    arabic: 'كَرَّرَ الْعَالِمُ التَّجْرِبَةَ ثَلَاثَ مَرَّاتٍ.',
    german: 'Der Forscher wiederholte das Experiment dreimal.',
    transliteration: 'Karrara al-ʿālimu at-taǧribata ṯalāṯa marrātin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1566,
    arabic: 'غَلَى الْمَاءُ فِي الْقِدْرِ.',
    german: 'Das Wasser siedete im Topf.',
    transliteration: 'Ġalā al-māʾu fī al-qidri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1567,
    arabic: 'تَسَاءَلَتِ الْبِنْتُ لِمَاذَا يَطِيرُ الطَّيْرُ.',
    german: 'Das Mädchen fragte sich, warum der Vogel fliegt.',
    transliteration: 'Tasāʾalati al-bintu li-māḏā yaṭīru aṭ-ṭayru.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1568,
    arabic: 'اِسْتَدَلَّ الْمُحَقِّقُ مِنَ الْأَثَرِ عَلَى الطَّرِيقِ.',
    german: 'Der Ermittler schloss aus der Spur auf den Weg.',
    transliteration: 'Istadalla al-muḥaqqiqu mina al-ʾaṯari ʿalā aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1569,
    arabic: 'حَلَّلَ الطَّبِيبُ الدَّمَ فِي الْمُخْتَبَرِ.',
    german: 'Der Arzt analysierte das Blut im Labor.',
    transliteration: 'Ḥallala aṭ-ṭabību ad-dama fī al-muḫtabari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1570,
    arabic: 'حَسَمَ الْقَاضِي الْقَضِيَّةَ فِي يَوْمٍ وَاحِدٍ.',
    german: 'Der Richter entschied den Fall an einem einzigen Tag.',
    transliteration: 'Ḥasama al-qāḍī al-qaḍiyyata fī yawmin wāḥidin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 158 (word_ids 1571–1580): „Der Sturm auf dem Meer".
/// Ein Sturm zerstört, ängstigt und zieht schließlich vorüber.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyEightStory = [
  Sentence(
    wordId: 1571,
    arabic: 'دَمَّرَتِ الْعَاصِفَةُ الْمَزْرَعَةَ كُلَّهَا.',
    german: 'Der Sturm zerstörte die ganze Farm.',
    transliteration: 'Dammarati al-ʿāṣifatu al-mazraʿata kullahā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1572,
    arabic: 'اِسْتَوْحَى الرَّسَّامُ لَوْحَتَهُ مِنَ الْعَاصِفَةِ.',
    german: 'Der Maler holte sich die Inspiration für sein Bild vom Sturm.',
    transliteration: 'Istawḥā ar-rassāmu lawḥatahū mina al-ʿāṣifati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1573,
    arabic: 'أَخْفَقَ الصَّيَّادُ فِي الْعَوْدَةِ قَبْلَ اللَّيْلِ.',
    german: 'Der Fischer scheiterte daran, vor der Nacht zurückzukehren.',
    transliteration: 'ʾAḫfaqa aṣ-ṣayyādu fī al-ʿawdati qabla al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1574,
    arabic: 'تَعَثَّرَ الْمُسَافِرُ بِحَجَرٍ فِي الظَّلَامِ.',
    german: 'Der Reisende stolperte im Dunkeln über einen Stein.',
    transliteration: 'Taʿaṯṯara al-musāfiru bi-ḥaǧarin fī aẓ-ẓalāmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1575,
    arabic: 'اِنْهَارَ الْجِدَارُ الْقَدِيمُ بَعْدَ الْمَطَرِ.',
    german: 'Die alte Mauer stürzte nach dem Regen ein.',
    transliteration: 'Inhāra al-ǧidāru al-qadīmu baʿda al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1576,
    arabic: 'اِضْطَرَبَ الْبَحْرُ وَخَافَ الرُّكَّابُ.',
    german: 'Das Meer wurde unruhig und die Passagiere hatten Angst.',
    transliteration: 'Iḍṭaraba al-baḥru wa-ḫāfa ar-rukkābu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1577,
    arabic: 'أَوْصَى الْجَدُّ بِبَيْتِهِ لِحَفِيدِهِ.',
    german: 'Der Großvater vermachte sein Haus seinem Enkel.',
    transliteration: 'ʾAwṣā al-ǧaddu bi-baytihī li-ḥafīdihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1578,
    arabic: 'اِعْتَصَمَ النَّاسُ بِالْجَبَلِ مِنَ الْفَيَضَانِ.',
    german: 'Die Leute suchten am Berg Schutz vor der Flut.',
    transliteration: 'Iʿtaṣama an-nāsu bi-al-ǧabali mina al-fayaḍāni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1579,
    arabic: 'حَافَظَ الْقَبْطَانُ عَلَى هُدُوئِهِ.',
    german: 'Der Kapitän bewahrte seine Ruhe.',
    transliteration: 'Ḥāfaẓa al-qabṭānu ʿalā hudūʾihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1580,
    arabic: 'هَدَأَتِ الرِّيحُ عِنْدَ الْفَجْرِ.',
    german: 'Der Wind ließ im Morgengrauen nach.',
    transliteration: 'Hadaʾati ar-rīḥu ʿinda al-faǧri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 159 (word_ids 1581–1590): „Die Ausgrabung".
/// Arbeiter graben in einem eingestürzten Haus und kämpfen mit Staub.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredFiftyNineStory = [
  Sentence(
    wordId: 1581,
    arabic: 'اِنْهَدَمَ الْبَيْتُ الْقَدِيمُ فِي الزِّلْزَالِ.',
    german: 'Das alte Haus stürzte im Erdbeben ein.',
    transliteration: 'Inhadama al-baytu al-qadīmu fī az-zilzāli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1582,
    arabic: 'حَفَرَ الْعُمَّالُ حُفْرَةً عَمِيقَةً.',
    german: 'Die Arbeiter gruben ein tiefes Loch.',
    transliteration: 'Ḥafara al-ʿummālu ḥufratan ʿamīqatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1583,
    arabic: 'اِنْحَدَرَ الطَّرِيقُ نَحْوَ الْوَادِي.',
    german: 'Die Straße fiel zum Tal hin ab.',
    transliteration: 'Inḥadara aṭ-ṭarīqu naḥwa al-wādī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1584,
    arabic: 'تَنَاثَرَتِ الْأَوْرَاقُ فِي الْحَدِيقَةِ.',
    german: 'Die Blätter zerstreuten sich im Garten.',
    transliteration: 'Tanāṯarati al-ʾawrāqu fī al-ḥadīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1585,
    arabic: 'تَفَرَّقَ النَّاسُ بَعْدَ الْمَطَرِ.',
    german: 'Die Leute gingen nach dem Regen auseinander.',
    transliteration: 'Tafarraqa an-nāsu baʿda al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1586,
    arabic: 'قَبَضَ الْوَلَدُ عَلَى يَدِ أَبِيهِ.',
    german: 'Der Junge fasste die Hand seines Vaters.',
    transliteration: 'Qabaḍa al-waladu ʿalā yadi ʾabīhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1587,
    arabic: 'اِسْتَنْشَقَ الْعَامِلُ الْهَوَاءَ النَّقِيَّ.',
    german: 'Der Arbeiter atmete die reine Luft ein.',
    transliteration: 'Istanšaqa al-ʿāmilu al-hawāʾa an-naqiyya.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1588,
    arabic: 'عَطَسَ الْعَامِلُ مِنَ الْغُبَارِ.',
    german: 'Der Arbeiter musste wegen des Staubs niesen.',
    transliteration: 'ʿAṭasa al-ʿāmilu mina al-ġubāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1589,
    arabic: 'سَعَلَ الشَّيْخُ طَوِيلًا.',
    german: 'Der Alte hustete lange.',
    transliteration: 'Saʿala aš-šayḫu ṭawīlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1590,
    arabic: 'جَرَّ الْحِصَانُ الْعَرَبَةَ إِلَى السُّوقِ.',
    german: 'Das Pferd zog den Wagen zum Markt.',
    transliteration: 'Ǧarra al-ḥiṣānu al-ʿarabata ʾilā as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 160 (word_ids 1591–1600): „Der kalte Morgen".
/// Ein Bauer erlebt einen frostigen Tag auf dem Hof.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyStory = [
  Sentence(
    wordId: 1591,
    arabic: 'اِسْتَوْقَظَ الْفَلَّاحُ قَبْلَ الْفَجْرِ.',
    german: 'Der Bauer wachte vor dem Morgengrauen auf.',
    transliteration: 'Istawqaẓa al-fallāḥu qabla al-faǧri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1592,
    arabic: 'أَغْلَقَ الْبَابَ لِأَنَّ الْهَوَاءَ بَارِدٌ.',
    german: 'Er schloss die Tür, weil die Luft kalt ist.',
    transliteration: 'ʾAġlaqa al-bāba li-ʾanna al-hawāʾa bāridun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1593,
    arabic: 'تَجَمَّدَ الْمَاءُ فِي الْإِنَاءِ.',
    german: 'Das Wasser im Gefäß gefror.',
    transliteration: 'Taǧammada al-māʾu fī al-ʾināʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1594,
    arabic: 'اِنْجَمَدَ الطِّفْلُ مِنَ الْخَوْفِ عِنْدَ الْبَابِ.',
    german: 'Das Kind erstarrte vor Angst an der Tür.',
    transliteration: 'Inǧamada aṭ-ṭiflu mina al-ḫawfi ʿinda al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1595,
    arabic: 'تَبَخَّرَ الْمَاءُ مِنَ الْقِدْرِ.',
    german: 'Das Wasser verdampfte aus dem Topf.',
    transliteration: 'Tabaḫḫara al-māʾu mina al-qidri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1596,
    arabic: 'اِرْتَجَعَ الْفَلَّاحُ إِلَى الْبَيْتِ بَعْدَ الظُّهْرِ.',
    german: 'Der Bauer kehrte nach dem Mittag nach Hause zurück.',
    transliteration: 'Irtaǧaʿa al-fallāḥu ʾilā al-bayti baʿda aẓ-ẓuhri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1597,
    arabic: 'مَزَّقَ الْوَلَدُ الْوَرَقَةَ الْقَدِيمَةَ.',
    german: 'Der Junge zerriss das alte Blatt.',
    transliteration: 'Mazzaqa al-waladu al-waraqata al-qadīmata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1598,
    arabic: 'خَرَّبَ الْجَرَادُ الْحَقْلَ.',
    german: 'Die Heuschrecken verwüsteten das Feld.',
    transliteration: 'Ḫarraba al-ǧarādu al-ḥaqla.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1599,
    arabic: 'شَالَ الْعَامِلُ الْكِيسَ عَلَى كَتِفِهِ.',
    german: 'Der Arbeiter hob den Sack auf seine Schulter.',
    transliteration: 'Šāla al-ʿāmilu al-kīsa ʿalā katifihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1600,
    arabic: 'تَرَدَّى الْحَجَرُ مِنَ الْجَبَلِ إِلَى الْوَادِي.',
    german: 'Der Stein stürzte vom Berg ins Tal.',
    transliteration: 'Taraddā al-ḥaǧaru mina al-ǧabali ʾilā al-wādī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 161 (word_ids 1601–1610): „Der geschäftige Markt".
/// Ein Händler feilscht, erweitert seinen Laden und verfolgt ehrgeizige Ziele.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyOneStory = [
  Sentence(
    wordId: 1601,
    arabic: 'سَاوَمَ التَّاجِرُ عَلَى الثَّمَنِ.',
    german: 'Der Händler feilschte über den Preis.',
    transliteration: 'Sāwama at-tāǧiru ʿalā aṯ-ṯamani.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1602,
    arabic: 'تَتَابَعَتِ الْأَخْبَارُ فِي الصَّبَاحِ.',
    german: 'Die Nachrichten folgten am Morgen aufeinander.',
    transliteration: 'Tatābaʿati al-ʾaḫbāru fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1603,
    arabic: 'شَقَّ الْفَلَّاحُ الْأَرْضَ بِالْمِحْرَاثِ.',
    german: 'Der Bauer pflügte die Erde mit dem Pflug.',
    transliteration: 'Šaqqa al-fallāḥu al-ʾarḍa bi-al-miḥrāṯi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1604,
    arabic: 'عَزَّزَ الدَّرْسُ ثِقَةَ الطَّالِبِ.',
    german: 'Die Lektion stärkte das Selbstvertrauen des Schülers.',
    transliteration: 'ʿAzzaza ad-darsu ṯiqata aṭ-ṭālibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1605,
    arabic: 'وَسَّعَ التَّاجِرُ مَتْجَرَهُ الْقَدِيمَ.',
    german: 'Der Händler erweiterte sein altes Geschäft.',
    transliteration: 'Wassaʿa at-tāǧiru matǧarahū al-qadīma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1606,
    arabic: 'تَخَلَّى الْأَبُ عَنِ الْكُرْسِيِّ لِطِفْلِهِ.',
    german: 'Der Vater verzichtete für sein Kind auf den Stuhl.',
    transliteration: 'Taḫallā al-ʾabu ʿani al-kursiyyi li-ṭiflihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1607,
    arabic: 'اِسْتَهْدَفَ الْمُدِيرُ زِيَادَةَ الْإِنْتَاجِ.',
    german: 'Der Leiter strebte eine höhere Produktion an.',
    transliteration: 'Istahdafa al-mudīru ziyādata al-ʾintāǧi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1608,
    arabic: 'تَوَاصَلَ الصَّدِيقَانِ بِالرَّسَائِلِ.',
    german: 'Die beiden Freunde hielten per Nachrichten Kontakt.',
    transliteration: 'Tawāṣala aṣ-ṣadīqāni bi-ar-rasāʾili.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1609,
    arabic: 'وَاصَلَ الْعُمَّالُ الْعَمَلَ حَتَّى اللَّيْلِ.',
    german: 'Die Arbeiter setzten die Arbeit bis zur Nacht fort.',
    transliteration: 'Wāṣala al-ʿummālu al-ʿamala ḥattā al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1610,
    arabic: 'كَفَّ الْمَطَرُ عَنِ الْهُطُولِ.',
    german: 'Der Regen hörte auf zu fallen.',
    transliteration: 'Kaffa al-maṭaru ʿani al-huṭūli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 162 (word_ids 1611–1620): „Das neue Gebäude".
/// Eine Firma errichtet, stellt ein und bittet um die nötigen Genehmigungen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyTwoStory = [
  Sentence(
    wordId: 1611,
    arabic: 'اِسْتَغْنَى الرَّجُلُ عَنْ مُسَاعَدَةِ أَخِيهِ.',
    german: 'Der Mann konnte auf die Hilfe seines Bruders verzichten.',
    transliteration: 'Istaġnā ar-raǧulu ʿan musāʿadati ʾaḫīhi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1612,
    arabic: 'اِسْتَعْرَضَ الْجُنْدِيُّ مَهَارَاتِهِ أَمَامَ الْقَائِدِ.',
    german: 'Der Soldat führte seine Fähigkeiten vor dem Kommandanten vor.',
    transliteration: 'Istaʿraḍa al-ǧundiyyu mahārātihī ʾamāma al-qāʾidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1613,
    arabic: 'وَظَّفَتِ الشَّرِكَةُ عَشَرَةَ مُهَنْدِسِينَ.',
    german: 'Die Firma stellte zehn Ingenieure an.',
    transliteration: 'Waẓẓafati aš-šarikatu ʿašarata muhandisīna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1614,
    arabic: 'حَضَّ الْمُعَلِّمُ الطُّلَّابَ عَلَى الْقِرَاءَةِ.',
    german: 'Der Lehrer trieb die Schüler zum Lesen an.',
    transliteration: 'Ḥaḍḍa al-muʿallimu aṭ-ṭullāba ʿalā al-qirāʾati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1615,
    arabic: 'حَثَّ الْأَبُ ابْنَهُ عَلَى الِاجْتِهَادِ.',
    german: 'Der Vater trieb seinen Sohn zur Anstrengung an.',
    transliteration: 'Ḥaṯṯa al-ʾabu ibnahū ʿalā al-iǧtihādi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1616,
    arabic: 'شَيَّدَ الْعُمَّالُ بُرْجًا عَالِيًا.',
    german: 'Die Arbeiter errichteten einen hohen Turm.',
    transliteration: 'Šayyada al-ʿummālu burǧan ʿāliyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1617,
    arabic: 'اِلْتَمَسَ الْمُوَظَّفُ مُسَاعَدَةَ الْمُدِيرِ.',
    german: 'Der Angestellte ersuchte den Leiter um Hilfe.',
    transliteration: 'Iltamasa al-muwaẓẓafu musāʿadati al-mudīri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1618,
    arabic: 'اِسْتَأْذَنَ الطَّالِبُ مُعَلِّمَهُ قَبْلَ الْخُرُوجِ.',
    german: 'Der Schüler bat seinen Lehrer vor dem Hinausgehen um Erlaubnis.',
    transliteration: 'Istaʾḏana aṭ-ṭālibu muʿallimahū qabla al-ḫurūǧi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1619,
    arabic: 'أَجَازَتِ الْبَلَدِيَّةُ الْمَشْرُوعَ الْجَدِيدَ.',
    german: 'Die Gemeinde genehmigte das neue Projekt.',
    transliteration: 'ʾAǧāzati al-baladiyyatu al-mašrūʿa al-ǧadīda.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1620,
    arabic: 'رَخَّصَتِ الْحُكُومَةُ الْمَتْجَرَ الْجَدِيدَ.',
    german: 'Die Regierung lizenzierte das neue Geschäft.',
    transliteration: 'Raḫḫaṣati al-ḥukūmatu al-matǧara al-ǧadīda.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 163 (word_ids 1621–1630): „Vor Gericht".
/// Ein Fall erfordert klare Worte, und am Ende steht die Vergebung.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyThreeStory = [
  Sentence(
    wordId: 1621,
    arabic: 'أَبَاحَ الْقَانُونُ التِّجَارَةَ الْحُرَّةَ.',
    german: 'Das Gesetz gab den freien Handel frei.',
    transliteration: 'ʾAbāḥa al-qānūnu at-tiǧārata al-ḥurrata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1622,
    arabic: 'أَوْجَبَ الْقَانُونُ حِمَايَةَ الْأَطْفَالِ.',
    german: 'Das Gesetz machte den Schutz der Kinder erforderlich.',
    transliteration: 'ʾAwǧaba al-qānūnu ḥimāyata al-ʾaṭfāli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1623,
    arabic: 'لَزِمَ الطَّالِبَ الْحُضُورُ مُبَكِّرًا.',
    german: 'Der Schüler musste früh erscheinen.',
    transliteration: 'Lazima aṭ-ṭāliba al-ḥuḍūru mubakkiran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1624,
    arabic: 'اِسْتَوْجَبَ الْعَمَلُ جُهْدًا كَبِيرًا.',
    german: 'Die Arbeit erforderte eine große Anstrengung.',
    transliteration: 'Istawǧaba al-ʿamalu ǧuhdan kabīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1625,
    arabic: 'اِسْتَبْعَدَ الْقَاضِي رِوَايَةَ الشَّاهِدِ.',
    german: 'Der Richter hielt die Aussage des Zeugen für unwahrscheinlich.',
    transliteration: 'Istabʿada al-qāḍī riwāyata aš-šāhidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1626,
    arabic: 'أَنْكَرَ الرَّجُلُ الِاتِّهَامَ أَمَامَ الْقَاضِي.',
    german: 'Der Mann leugnete die Anschuldigung vor dem Richter.',
    transliteration: 'ʾAnkara ar-raǧulu al-ittihāma ʾamāma al-qāḍī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1627,
    arabic: 'جَحَدَ الْوَلَدُ بِالْحَقِيقَةِ.',
    german: 'Der Junge leugnete die Wahrheit ab.',
    transliteration: 'Ǧaḥada al-waladu bi-al-ḥaqīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1628,
    arabic: 'بَرَّرَ الْمُتَّهَمُ عَمَلَهُ بِالْجَهْلِ.',
    german: 'Der Angeklagte rechtfertigte seine Tat mit Unwissenheit.',
    transliteration: 'Barrara al-muttahamu ʿamalahū bi-al-ǧahli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1629,
    arabic: 'عَذَرَ الْأُسْتَاذُ الطَّالِبَ الْمُتَأَخِّرَ.',
    german: 'Der Lehrer entschuldigte den zu spät gekommenen Schüler.',
    transliteration: 'ʿAḏara al-ʾustāḏu aṭ-ṭāliba al-mutaʾaḫḫira.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1630,
    arabic: 'سَامَحَ الْأَخُ أَخَاهُ بَعْدَ الْخِلَافِ.',
    german: 'Der Bruder verzieh seinem Bruder nach dem Streit.',
    transliteration: 'Sāmaḥa al-ʾaḫu ʾaḫāhu baʿda al-ḫilāfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 164 (word_ids 1631–1640): „Die neue Firma".
/// Ein Gründer errichtet, dokumentiert und entwickelt sein Werk.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyFourStory = [
  Sentence(
    wordId: 1631,
    arabic: 'تَصَالَحَ الْفَرِيقَانِ بَعْدَ خِلَافٍ طَوِيلٍ.',
    german: 'Die beiden Teams versöhnten sich nach langem Streit.',
    transliteration: 'Taṣālaḥa al-farīqāni baʿda ḫilāfin ṭawīlin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1632,
    arabic: 'اِسْتَوْدَعَ الرَّجُلُ وَثَائِقَهُ عِنْدَ الْمُحَامِي.',
    german: 'Der Mann hinterlegte seine Dokumente beim Anwalt.',
    transliteration: 'Istawdaʿa ar-raǧulu waṯāʾiqahū ʿinda al-muḥāmī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1633,
    arabic: 'اِسْتَقَلَّ الِابْنُ عَنْ أَبِيهِ فِي عَمَلِهِ.',
    german: 'Der Sohn wurde in seiner Arbeit unabhängig von seinem Vater.',
    transliteration: 'Istaqalla al-ibnu ʿan ʾabīhi fī ʿamalihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1634,
    arabic: 'أَسَّسَ الرَّجُلُ شَرِكَةً صَغِيرَةً.',
    german: 'Der Mann gründete eine kleine Firma.',
    transliteration: 'ʾAssasa ar-raǧulu šarikatan ṣaġīratan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1635,
    arabic: 'ثَبَّتَ الْعَامِلُ اللَّوْحَةَ عَلَى الْجِدَارِ.',
    german: 'Der Arbeiter befestigte das Schild an der Wand.',
    transliteration: 'Ṯabbata al-ʿāmilu al-lawḥata ʿalā al-ǧidāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1636,
    arabic: 'أَقَرَّ الْمُدِيرُ الْخُطَّةَ الْجَدِيدَةَ.',
    german: 'Der Leiter bestätigte den neuen Plan.',
    transliteration: 'ʾAqarra al-mudīru al-ḫuṭṭata al-ǧadīdata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1637,
    arabic: 'وَثَّقَ الْمُوَظَّفُ الْعَقْدَ بِخَتْمٍ رَسْمِيٍّ.',
    german: 'Der Angestellte belegte den Vertrag mit einem amtlichen Siegel.',
    transliteration: 'Waṯṯaqa al-muwaẓẓafu al-ʿaqda bi-ḫatmin rasmiyyin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1638,
    arabic: 'صَنَّفَ الْعَالِمُ الْحَيَوَانَاتِ فِي مَجْمُوعَاتٍ.',
    german: 'Der Forscher teilte die Tiere in Gruppen ein.',
    transliteration: 'Ṣannafa al-ʿālimu al-ḥayawānāti fī maǧmūʿātin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1639,
    arabic: 'اِبْتَكَرَ الْمُهَنْدِسُ آلَةً مُفِيدَةً.',
    german: 'Der Ingenieur schuf eine nützliche Maschine.',
    transliteration: 'Ibtakara al-muhandisu ʾālatan mufīdatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1640,
    arabic: 'طَوَّرَ الْمُبَرْمِجُ تَطْبِيقًا جَدِيدًا.',
    german: 'Der Programmierer entwickelte eine neue App.',
    transliteration: 'Ṭawwara al-mubarmiǧu taṭbīqan ǧadīdan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 165 (word_ids 1641–1650): „Die Konferenz".
/// Delegationen treffen sich, sprechen, verhandeln und tauschen Ideen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyFiveStory = [
  Sentence(
    wordId: 1641,
    arabic: 'ضَبَطَ الْفَنِّيُّ جِهَازَ الْحَاسُوبِ.',
    german: 'Der Techniker kontrollierte das Computergerät.',
    transliteration: 'Ḍabaṭa al-fanniyyu ǧihāza al-ḥāsūbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1642,
    arabic: 'صَحَّحَ الْمُعَلِّمُ أَخْطَاءَ الطُّلَّابِ.',
    german: 'Der Lehrer korrigierte die Fehler der Schüler.',
    transliteration: 'Ṣaḥḥaḥa al-muʿallimu ʾaḫṭāʾa aṭ-ṭullābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1643,
    arabic: 'اِنْحَرَفَ السَّائِقُ عَنِ الطَّرِيقِ الرَّئِيسِيِّ.',
    german: 'Der Fahrer wich von der Hauptstraße ab.',
    transliteration: 'Inḥarafa as-sāʾiqu ʿani aṭ-ṭarīqi ar-raʾīsiyyi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1644,
    arabic: 'رَوَى الْجَدُّ حِكَايَةً قَدِيمَةً.',
    german: 'Der Großvater erzählte eine alte Geschichte.',
    transliteration: 'Rawā al-ǧaddu ḥikāyatan qadīmatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1645,
    arabic: 'حَاوَرَ الطَّالِبُ أُسْتَاذَهُ بِأَدَبٍ.',
    german: 'Der Student sprach höflich mit seinem Lehrer.',
    transliteration: 'Ḥāwara aṭ-ṭālibu ʾustāḏahū bi-ʾadabin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1646,
    arabic: 'فَاوَضَ الْوَفْدُ الْجَانِبَ الْآخَرَ بِهُدُوءٍ.',
    german: 'Die Delegation verhandelte ruhig mit der anderen Seite.',
    transliteration: 'Fāwaḍa al-wafdu al-ǧāniba al-ʾāḫara bi-hudūʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1647,
    arabic: 'بَادَلَ الصَّدِيقَانِ الْهَدَايَا.',
    german: 'Die beiden Freunde tauschten die Geschenke.',
    transliteration: 'Bādala aṣ-ṣadīqāni al-hadāyā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1648,
    arabic: 'اِلْتَقَى الْفَرِيقَانِ فِي قَاعَةِ الْمُؤْتَمَرِ.',
    german: 'Die beiden Teams trafen sich im Konferenzsaal.',
    transliteration: 'Iltaqā al-farīqāni fī qāʿati al-muʾtamari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1649,
    arabic: 'تَعَارَفَ الطُّلَّابُ فِي أَوَّلِ يَوْمٍ.',
    german: 'Die Schüler lernten sich am ersten Tag kennen.',
    transliteration: 'Taʿārafa aṭ-ṭullābu fī ʾawwali yawmin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1650,
    arabic: 'تَعَرَّفَ الزَّائِرُ عَلَى الْمَدِينَةِ.',
    german: 'Der Besucher lernte die Stadt kennen.',
    transliteration: 'Taʿarrafa az-zāʾiru ʿalā al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 166 (word_ids 1651–1660): „Prüfen und Verantwortung".
/// Ein Arbeiter prüft gründlich, führt Befehle aus und steht zu seiner Aussage.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtySixStory = [
  Sentence(
    wordId: 1651,
    arabic: 'دَقَّقَ الْمُحَاسِبُ فِي الْأَرْقَامِ.',
    german: 'Der Buchhalter prüfte die Zahlen genau nach.',
    transliteration: 'Daqqaqa al-muḥāsibu fī al-ʾarqāmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1652,
    arabic: 'فَحَصَ الطَّبِيبُ الْمَرِيضَ بِعِنَايَةٍ.',
    german: 'Der Arzt untersuchte den Patienten sorgfältig.',
    transliteration: 'Faḥaṣa aṭ-ṭabību al-marīḍa bi-ʿināyatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1653,
    arabic: 'اِدَّعَى الرَّجُلُ أَنَّهُ بَرِيءٌ.',
    german: 'Der Mann behauptete, dass er unschuldig sei.',
    transliteration: 'Iddaʿā ar-raǧulu ʾannahū barīʾun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1654,
    arabic: 'أَقْسَمَ الشَّاهِدُ أَنَّهُ قَالَ الْحَقَّ.',
    german: 'Der Zeuge schwor, dass er die Wahrheit gesagt habe.',
    transliteration: 'ʾAqsama aš-šāhidu ʾannahū qāla al-ḥaqqa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1655,
    arabic: 'حَلَفَ الرَّجُلُ بِاللَّهِ عَلَى صِدْقِهِ.',
    german: 'Der Mann schwor bei Gott auf seine Aufrichtigkeit.',
    transliteration: 'Ḥalafa ar-raǧulu bi-llāhi ʿalā ṣidqihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1656,
    arabic: 'نَفَّذَ الْعَامِلُ الْأَوَامِرَ بِدِقَّةٍ.',
    german: 'Der Arbeiter führte die Befehle genau aus.',
    transliteration: 'Naffaḏa al-ʿāmilu al-ʾawāmira bi-diqqatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1657,
    arabic: 'بَالَغَ الْوَلَدُ فِي وَصْفِ الْحَادِثَةِ.',
    german: 'Der Junge übertrieb bei der Beschreibung des Vorfalls.',
    transliteration: 'Bālaġa al-waladu fī waṣfi al-ḥādiṯati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1658,
    arabic: 'حَيَّا الْجُنْدِيُّ الْعَلَمَ صَبَاحًا.',
    german: 'Der Soldat grüßte am Morgen die Flagge.',
    transliteration: 'Ḥayyā al-ǧundiyyu al-ʿalama ṣabāḥan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1659,
    arabic: 'رَحَّبَ الْمُضِيفُ بِالضُّيُوفِ.',
    german: 'Der Gastgeber hieß die Gäste willkommen.',
    transliteration: 'Raḥḥaba al-muḍīfu bi-aḍ-ḍuyūfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1660,
    arabic: 'ضَغَطَ الْعَامِلُ عَلَى الزِّرِّ.',
    german: 'Der Arbeiter drückte auf den Knopf.',
    transliteration: 'Ḍaġaṭa al-ʿāmilu ʿalā az-zirri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 167 (word_ids 1661–1670): „Auf dem Bauernhof".
/// Kinder, Mütter und Bauern verstecken, gießen, zählen und rüsten sich.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtySevenStory = [
  Sentence(
    wordId: 1661,
    arabic: 'عَلِقَ الثَّوْبُ بِالْمِسْمَارِ.',
    german: 'Das Kleid blieb am Nagel hängen.',
    transliteration: 'ʿAliqa aṯ-ṯawbu bi-al-mismāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1662,
    arabic: 'خَبَأَ الطِّفْلُ لُعْبَتَهُ تَحْتَ السَّرِيرِ.',
    german: 'Das Kind versteckte sein Spielzeug unter dem Bett.',
    transliteration: 'Ḫabaʾa aṭ-ṭiflu luʿbatahū taḥta as-sarīri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1663,
    arabic: 'سَكَبَ الْوَلَدُ الْمَاءَ فِي الْكُوبِ.',
    german: 'Der Junge goss das Wasser in den Becher.',
    transliteration: 'Sakaba al-waladu al-māʾa fī al-kūbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1664,
    arabic: 'صَبَّتِ الْأُمُّ الشَّايَ فِي الْأَكْوَابِ.',
    german: 'Die Mutter goss den Tee in die Gläser.',
    transliteration: 'Ṣabbati al-ʾummu aš-šāya fī al-ʾakwābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1665,
    arabic: 'شَاوَرَ الْأَبُ ابْنَهُ فِي الْأَمْرِ.',
    german: 'Der Vater beriet sich mit seinem Sohn in der Sache.',
    transliteration: 'Šāwara al-ʾabu ibnahū fī al-ʾamri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1666,
    arabic: 'اِبْتَلَعَ الرَّجُلُ رِيقَهُ مِنَ الْخَوْفِ.',
    german: 'Der Mann schluckte vor Angst seinen Speichel.',
    transliteration: 'Ibtalaʿa ar-raǧulu rīqahū mina al-ḫawfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1667,
    arabic: 'أَحْصَى الْفَلَّاحُ الْأَغْنَامَ فِي الْحَقْلِ.',
    german: 'Der Bauer zählte die Schafe auf dem Feld.',
    transliteration: 'ʾAḥṣā al-fallāḥu al-ʾaġnāma fī al-ḥaqli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1668,
    arabic: 'جَهَّزَتِ الْأُمُّ الْحَقَائِبَ لِلسَّفَرِ.',
    german: 'Die Mutter rüstete die Taschen für die Reise aus.',
    transliteration: 'Ǧahhazati al-ʾummu al-ḥaqāʾiba lis-safari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1669,
    arabic: 'اِجْتَنَبَ السَّائِقُ الطَّرِيقَ الْخَطِرَ.',
    german: 'Der Fahrer vermied die gefährliche Straße.',
    transliteration: 'Iǧtanaba as-sāʾiqu aṭ-ṭarīqa al-ḫaṭira.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1670,
    arabic: 'تَوَقَّى الْفَلَّاحُ الْبَرْدَ بِمِعْطَفٍ ثَقِيلٍ.',
    german: 'Der Bauer hütete sich mit einem schweren Mantel vor der Kälte.',
    transliteration: 'Tawaqqā al-fallāḥu al-barda bi-miʿṭafin ṯaqīlin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 168 (word_ids 1671–1680): „Gefahr und Vertrauen".
/// Ein Seemann, ein Lehrer und ein Händler warnen, riskieren und halten Versprechen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyEightStory = [
  Sentence(
    wordId: 1671,
    arabic: 'اِتَّقَى السَّائِقُ الْخَطَرَ عَلَى الطَّرِيقِ.',
    german: 'Der Fahrer hütete sich vor der Gefahr auf der Straße.',
    transliteration: 'Ittaqā as-sāʾiqu al-ḫaṭara ʿalā aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1672,
    arabic: 'نَبَّهَ الْمُعَلِّمُ الطُّلَّابَ إِلَى الْخَطَأِ.',
    german: 'Der Lehrer warnte die Schüler vor dem Fehler.',
    transliteration: 'Nabbaha al-muʿallimu aṭ-ṭullāba ʾilā al-ḫaṭaʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1673,
    arabic: 'أَنْذَرَ الدَّلِيلُ الْمُسَافِرِينَ مِنَ الْعَاصِفَةِ.',
    german: 'Der Führer warnte die Reisenden vor dem Sturm.',
    transliteration: 'ʾAnḏara ad-dalīlu al-musāfirīna mina al-ʿāṣifati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1674,
    arabic: 'خَاطَرَ الْبَحَّارُ بِحَيَاتِهِ فِي الْبَحْرِ.',
    german: 'Der Seemann riskierte sein Leben auf dem Meer.',
    transliteration: 'Ḫāṭara al-baḥḥāru bi-ḥayātihī fī al-baḥri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1675,
    arabic: 'أَطْلَقَ الْجُنْدِيُّ رَصَاصَةً فِي الْهَوَاءِ.',
    german: 'Der Soldat feuerte eine Kugel in die Luft.',
    transliteration: 'ʾAṭlaqa al-ǧundiyyu raṣāṣatan fī al-hawāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1676,
    arabic: 'أَقْرَضَ التَّاجِرُ صَدِيقَهُ مَبْلَغًا صَغِيرًا.',
    german: 'Der Händler lieh seinem Freund einen kleinen Betrag.',
    transliteration: 'ʾAqraḍa at-tāǧiru ṣadīqahū mablaġan ṣaġīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1677,
    arabic: 'اِسْتَدَانَ الطَّالِبُ مَالًا لِدِرَاسَتِهِ.',
    german: 'Der Student lieh sich Geld für sein Studium.',
    transliteration: 'Istadāna aṭ-ṭālibu mālan li-dirāsatihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1678,
    arabic: 'وَفَّى الرَّجُلُ بِوَعْدِهِ لِلْجَمِيعِ.',
    german: 'Der Mann erfüllte allen sein Versprechen.',
    transliteration: 'Waffā ar-raǧulu bi-waʿdihī lil-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1679,
    arabic: 'أَوْفَى الْعَامِلُ بِالْعَقْدِ كَامِلًا.',
    german: 'Der Arbeiter hielt den Vertrag vollständig ein.',
    transliteration: 'ʾAwfā al-ʿāmilu bi-al-ʿaqdi kāmilan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1680,
    arabic: 'اِنْدَفَعَ الْأَطْفَالُ نَحْوَ الْحَدِيقَةِ.',
    german: 'Die Kinder stürzten in den Garten.',
    transliteration: 'Indafaʿa al-ʾaṭfālu naḥwa al-ḥadīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 169 (word_ids 1681–1690): „Die Nacht im Dorf".
/// Ein Wächter wacht, Türen schließen und Feuer brennt in der Dunkelheit.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSixtyNineStory = [
  Sentence(
    wordId: 1681,
    arabic: 'سَهِرَ الْحَارِسُ حَتَّى الصَّبَاحِ.',
    german: 'Der Wächter blieb bis zum Morgen wach.',
    transliteration: 'Sahira al-ḥārisu ḥattā aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1682,
    arabic: 'اِنْغَلَقَ الْبَابُ بِهُدُوءٍ.',
    german: 'Die Tür schloss sich leise.',
    transliteration: 'Inġalaqa al-bābu bi-hudūʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1683,
    arabic: 'أَقْفَلَ الْأَبُ الْبَيْتَ قَبْلَ النَّوْمِ.',
    german: 'Der Vater schloss das Haus vor dem Schlafen ab.',
    transliteration: 'ʾAqfala al-ʾabu al-bayta qabla an-nawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1684,
    arabic: 'أَوَى الْمُسَافِرُ إِلَى مَخْدَعٍ صَغِيرٍ.',
    german: 'Der Reisende fand in einem kleinen Zimmer Unterschlupf.',
    transliteration: 'ʾAwā al-musāfiru ʾilā maḫdaʿin ṣaġīrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1685,
    arabic: 'ضَاعَفَ التَّاجِرُ أَسْعَارَهُ فِي الصَّيْفِ.',
    german: 'Der Händler verdoppelte im Sommer seine Preise.',
    transliteration: 'Ḍāʿafa at-tāǧiru ʾasʿārahū fī aṣ-ṣayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1686,
    arabic: 'ضَعُفَ الْحِصَانُ بَعْدَ الطَّرِيقِ الطَّوِيلِ.',
    german: 'Das Pferd wurde nach dem langen Weg schwach.',
    transliteration: 'Ḍaʿufa al-ḥiṣānu baʿda aṭ-ṭarīqi aṭ-ṭawīli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1687,
    arabic: 'اِنْطَفَأَ الْمِصْبَاحُ فِي الْغُرْفَةِ.',
    german: 'Die Lampe erlosch im Zimmer.',
    transliteration: 'Inṭafaʾa al-miṣbāḥu fī al-ġurfati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1688,
    arabic: 'أَطْفَأَ الرَّجُلُ الشَّمْعَةَ قَبْلَ النَّوْمِ.',
    german: 'Der Mann löschte die Kerze vor dem Schlafen aus.',
    transliteration: 'ʾAṭfaʾa ar-raǧulu aš-šamʿata qabla an-nawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1689,
    arabic: 'أَشْعَلَ الْفَلَّاحُ النَّارَ فِي الْمَوْقِدِ.',
    german: 'Der Bauer entzündete das Feuer im Ofen.',
    transliteration: 'ʾAšʿala al-fallāḥu an-nāra fī al-mawqidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1690,
    arabic: 'اِشْتَعَلَتِ النَّارُ فِي الْحَقْلِ.',
    german: 'Das Feuer brannte auf dem Feld.',
    transliteration: 'Ištaʿalati an-nāru fī al-ḥaqli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 170 (word_ids 1691–1700): „Der weite Ausflug".
/// Auf der Reise wärmt sich die Gruppe, rutscht aus und sehnt sich nach Hause.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyStory = [
  Sentence(
    wordId: 1691,
    arabic: 'تَدَفَّأَ الْأَطْفَالُ حَوْلَ النَّارِ.',
    german: 'Die Kinder wärmten sich am Feuer.',
    transliteration: 'Tadaffaʾa al-ʾaṭfālu ḥawla an-nāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1692,
    arabic: 'اِسْتَظَلَّ الْمُسَافِرُ تَحْتَ الشَّجَرَةِ.',
    german: 'Der Reisende suchte Schatten unter dem Baum.',
    transliteration: 'Istaẓalla al-musāfiru taḥta aš-šaǧarati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1693,
    arabic: 'زَلَّ الرَّجُلُ عَلَى الْأَرْضِ الْمُبْتَلَّةِ.',
    german: 'Der Mann rutschte auf dem nassen Boden aus.',
    transliteration: 'Zalla ar-raǧulu ʿalā al-ʾarḍi al-mubtallati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1694,
    arabic: 'اِنْزَلَقَ الطِّفْلُ عَلَى الْجَلِيدِ.',
    german: 'Das Kind rutschte auf dem Eis aus.',
    transliteration: 'Inzalaqa aṭ-ṭiflu ʿalā al-ǧalīdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1695,
    arabic: 'عَثَرَ الْعَالِمُ عَلَى كِتَابٍ قَدِيمٍ.',
    german: 'Der Forscher stieß auf ein altes Buch.',
    transliteration: 'ʿAṯara al-ʿālimu ʿalā kitābin qadīmin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1696,
    arabic: 'اِتَّضَحَ الْأَمْرُ لِلْجَمِيعِ.',
    german: 'Die Sache wurde allen klar.',
    transliteration: 'Ittaḍaḥa al-ʾamru lil-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1697,
    arabic: 'صَوَّرَ الرَّسَّامُ الطَّبِيعَةَ.',
    german: 'Der Maler bildete die Natur ab.',
    transliteration: 'Ṣawwara ar-rassāmu aṭ-ṭabīʿata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1698,
    arabic: 'تَفَاءَلَ الطَّالِبُ بِنَتِيجَةٍ جَيِّدَةٍ.',
    german: 'Der Schüler war wegen eines guten Ergebnisses optimistisch.',
    transliteration: 'Tafāʾala aṭ-ṭālibu bi-natīǧatin ǧayyidatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1699,
    arabic: 'تَشَاءَمَ الْجَدُّ مِنْ تَأَخُّرِ الْمَطَرِ.',
    german: 'Der Großvater war wegen des ausbleibenden Regens pessimistisch.',
    transliteration: 'Tašāʾama al-ǧaddu min taʾaḫḫuri al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1700,
    arabic: 'اِشْتَاقَ الْمُسَافِرُ إِلَى بَيْتِهِ.',
    german: 'Der Reisende sehnte sich nach seinem Haus.',
    transliteration: 'Ištāqa al-musāfiru ʾilā baytihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 171 (word_ids 1701–1710): „Beobachtungen am Meer".
/// Ein Beobachter staunt, schreibt Berichte und verfolgt die Sonne über dem Wasser.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyOneStory = [
  Sentence(
    wordId: 1701,
    arabic: 'اِنْدَهَشَ الْوَلَدُ مِنَ الْبَحْرِ الْوَاسِعِ.',
    german: 'Der Junge war vom weiten Meer verblüfft.',
    transliteration: 'Indahaša al-waladu mina al-baḥri al-wāsiʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1702,
    arabic: 'تَعَجَّبَ الْمُسَافِرُ مِنْ جَمَالِ الْجَبَلِ.',
    german: 'Der Reisende wunderte sich über die Schönheit des Berges.',
    transliteration: 'Taʿaǧǧaba al-musāfiru min ǧamāli al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1703,
    arabic: 'كَتَبَ الْمُوَظَّفُ تَقْرِيرًا طَوِيلًا.',
    german: 'Der Angestellte schrieb einen langen Bericht.',
    transliteration: 'Kataba al-muwaẓẓafu taqrīran ṭawīlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1704,
    arabic: 'رَفَضَ الْقَاضِي ادِّعَاءَ الْمُتَّهَمِ.',
    german: 'Der Richter wies die Behauptung des Angeklagten zurück.',
    transliteration: 'Rafaḍa al-qāḍī iddiʿāʾa al-muttahami.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1705,
    arabic: 'لِلْمُعَلِّمِ فَضْلٌ كَبِيرٌ عَلَى طُلَّابِهِ.',
    german: 'Der Lehrer hat großen Verdienst an seinen Schülern.',
    transliteration: 'Lil-muʿallimi faḍlun kabīrun ʿalā ṭullābihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1706,
    arabic: 'غَابَتِ الشَّمْسُ فِي الْمَغْرِبِ.',
    german: 'Die Sonne ging im Westen unter.',
    transliteration: 'Ġābati aš-šamsu fī al-maġribi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1707,
    arabic: 'تُشْرِقُ الشَّمْسُ مِنَ الْمَشْرِقِ.',
    german: 'Die Sonne geht im Osten auf.',
    transliteration: 'Tušriqu aš-šamsu mina al-mašriqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1708,
    arabic: 'رَفَعَتِ الْعَاصِفَةُ مَوْجَةً عَالِيَةً.',
    german: 'Der Sturm hob eine hohe Welle.',
    transliteration: 'Rafaʿati al-ʿāṣifatu mawǧatan ʿāliyatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1709,
    arabic: 'تَجَمَّدَ الْجَلِيدُ عَلَى النَّافِذَةِ.',
    german: 'Das Eis gefror an der Fensterscheibe.',
    transliteration: 'Taǧammada al-ǧalīdu ʿalā an-nāfiḏati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1710,
    arabic: 'لَا حَرَكَةَ فِي الشَّارِعِ هَذَا الصَّبَاحَ.',
    german: 'Auf der Straße ist heute Morgen keine Bewegung.',
    transliteration: 'Lā ḥarakata fī aš-šāriʿi hāḏā aṣ-ṣabāḥa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 172 (word_ids 1711–1720): „Nachrichten im alten Viertel".
/// Im alten Viertel liest man Texte, schickt Telegramme und gründet Vereine.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyTwoStory = [
  Sentence(
    wordId: 1711,
    arabic: 'اِشْتَرَى الْأَبُ مَلَابِسَ جَدِيدَةً لِأَوْلَادِهِ.',
    german: 'Der Vater kaufte seinen Kindern neue Kleidung.',
    transliteration: 'Ištarā al-ʾabu malābisa ǧadīdatan li-ʾawlādihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1712,
    arabic: 'لَا يَقْرَأُ الْجَدُّ بِدُونِ نَظَّارَةٍ.',
    german: 'Der Großvater liest nicht ohne Brille.',
    transliteration: 'Lā yaqraʾu al-ǧaddu bi-dūni naẓẓāratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1713,
    arabic: 'غَسَلْتُ يَدَيَّ بِالصَّابُونِ.',
    german: 'Ich wusch meine Hände mit Seife.',
    transliteration: 'Ġasaltu yadayya bi-aṣ-ṣābūni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1714,
    arabic: 'أَلْقَى الرَّئِيسُ خِطَابًا قَصِيرًا.',
    german: 'Der Präsident hielt eine kurze Rede.',
    transliteration: 'ʾAlqā ar-raʾīsu ḫiṭāban qaṣīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1715,
    arabic: 'وَصَلَتْ بَرْقِيَّةٌ عَاجِلَةٌ إِلَى الْمَكْتَبِ.',
    german: 'Ein dringendes Telegramm kam ins Büro.',
    transliteration: 'Waṣalat barqiyyatun ʿāǧilatun ʾilā al-maktabi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1716,
    arabic: 'قَرَأَ الطَّالِبُ النَّصَّ بِدِقَّةٍ.',
    german: 'Der Schüler las den Text genau.',
    transliteration: 'Qaraʾa aṭ-ṭālibu an-naṣṣa bi-diqqatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1717,
    arabic: 'لِلْإِنْسَانِ حُرْمَةٌ لَا تُنْتَهَكُ.',
    german: 'Der Mensch hat eine Würde, die nicht verletzt wird.',
    transliteration: 'Lil-ʾinsāni ḥurmatun lā tuntahaku.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1718,
    arabic: 'نَشَأَ مُحَمَّدٌ فِي حَيٍّ قَدِيمٍ.',
    german: 'Muhammad wuchs in einem alten Viertel auf.',
    transliteration: 'Našaʾa Muḥammadun fī ḥayyin qadīmin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1719,
    arabic: 'أَسَّسَ الْعُمَّالُ اِتِّحَادًا قَوِيًّا.',
    german: 'Die Arbeiter gründeten eine starke Vereinigung.',
    transliteration: 'ʾAssasa al-ʿummālu ittiḥādan qawiyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1720,
    arabic: 'فَازَ فَرِيقُ الْمَدْرَسَةِ بِالْكَأْسِ.',
    german: 'Das Team der Schule gewann den Pokal.',
    transliteration: 'Fāza farīqu al-madrasati bi-al-kaʾsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 173 (word_ids 1721–1730): „Leben und Arbeit".
/// Vom Lebensunterhalt über Traditionen bis zur Qualität der Arbeit.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyThreeStory = [
  Sentence(
    wordId: 1721,
    arabic: 'أَصْبَحَ سَعِيدٌ عُضْوًا فِي الْجَمْعِيَّةِ.',
    german: 'Said wurde Mitglied im Verein.',
    transliteration: 'ʾAṣbaḥa Saʿīdun ʿuḍwan fī al-ǧamʿiyyati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1722,
    arabic: 'اِنْتَخَبَ النَّاسُ نَائِبًا جَدِيدًا.',
    german: 'Die Leute wählten einen neuen Stellvertreter.',
    transliteration: 'Intaḫaba an-nāsu nāʾiban ǧadīdan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1723,
    arabic: 'يَكْسِبُ الْفَلَّاحُ مَعِيشَةً طَيِّبَةً مِنَ الْأَرْضِ.',
    german: 'Der Bauer verdient einen guten Lebensunterhalt von der Erde.',
    transliteration: 'Yaksibu al-fallāḥu maʿīšatan ṭayyibatan mina al-ʾarḍi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1724,
    arabic: 'تُهِمُّ الْجَوْدَةُ كُلَّ زَبُونٍ.',
    german: 'Die Qualität ist jedem Kunden wichtig.',
    transliteration: 'Tuhimmu al-ǧawdatu kulla zabūnin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1725,
    arabic: 'دَوَّنَ الطَّالِبُ الدَّرْسَ فِي مُذَكِّرَةٍ صَغِيرَةٍ.',
    german: 'Der Schüler notierte die Lektion in einem kleinen Notizbuch.',
    transliteration: 'Dawwana aṭ-ṭālibu ad-darsa fī muḏakkaratin ṣaġīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1726,
    arabic: 'يُتَابِعُ الْمُدِيرُ مَسَارَ الْعَمَلِ.',
    german: 'Der Leiter verfolgt den Verlauf der Arbeit.',
    transliteration: 'Yutābiʿu al-mudīru masāra al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1727,
    arabic: 'يَحْفَظُ الْجَدُّ تَقْلِيدَ الْعَائِلَةِ.',
    german: 'Der Großvater bewahrt die Tradition der Familie.',
    transliteration: 'Yaḥfaẓu al-ǧaddu taqlīda al-ʿāʾilati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1728,
    arabic: 'يَسْكُنُ أَخِي بِالْقُرْبِ مِنَ الْمَسْجِدِ.',
    german: 'Mein Bruder wohnt in der Nähe der Moschee.',
    transliteration: 'Yaskunu ʾaḫī bi-al-qurbi mina al-masǧidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1729,
    arabic: 'الْبِئْرُ عَمِيقَةٌ وَلَا نَعْرِفُ عُمْقَهَا.',
    german: 'Der Brunnen ist tief und wir kennen seine Tiefe nicht.',
    transliteration: 'Al-biʾru ʿamīqatun wa-lā naʿrifu ʿumqahā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1730,
    arabic: 'يَبْلُغُ طُولُ النَّهْرِ أَلْفَ كِيلُومِتْرٍ.',
    german: 'Die Länge des Flusses beträgt tausend Kilometer.',
    transliteration: 'Yabluġu ṭūlu an-nahri ʾalfa kīlūmitrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 174 (word_ids 1731–1740): „Die große Reise".
/// Gewicht, Größe und Geschwindigkeit bestimmen den Weg der Reisenden.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyFourStory = [
  Sentence(
    wordId: 1731,
    arabic: 'حَسَبَ الْعَامِلُ وَزْنَ الصُّنْدُوقِ.',
    german: 'Der Arbeiter berechnete das Gewicht der Kiste.',
    transliteration: 'Ḥasaba al-ʿāmilu wazna aṣ-ṣundūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1732,
    arabic: 'قَاسَ الْمُهَنْدِسُ حَجْمَ الْغُرْفَةِ.',
    german: 'Der Ingenieur maß das Volumen des Zimmers.',
    transliteration: 'Qāsa al-muhandisu ḥaǧma al-ġurfati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1733,
    arabic: 'تَزِيدُ سُرْعَةُ السَّيَّارَةِ عَلَى الطَّرِيقِ.',
    german: 'Die Geschwindigkeit des Autos nimmt auf der Straße zu.',
    transliteration: 'Tazīdu surʿatu as-sayyārati ʿalā aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1734,
    arabic: 'مَوْقِعُ الْفُنْدُقِ قَرِيبٌ مِنَ الشَّاطِئِ.',
    german: 'Die Lage des Hotels ist nahe am Strand.',
    transliteration: 'Mawqiʿu al-funduqi qarībun mina aš-šāṭiʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1735,
    arabic: 'جَلَسَ الرَّجُلُ عَلَى جَانِبِ الطَّرِيقِ.',
    german: 'Der Mann setzte sich an die Seite der Straße.',
    transliteration: 'Ǧalasa ar-raǧulu ʿalā ǧānibi aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1736,
    arabic: 'يَلْعَبُ الْأَطْفَالُ دَاخِلَ الْبَيْتِ.',
    german: 'Die Kinder spielen im Inneren des Hauses.',
    transliteration: 'Yalʿabu al-ʾaṭfālu dāḫila al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1737,
    arabic: 'اِنْتَظَرَ الْأَبُ خَارِجَ الْبَابِ.',
    german: 'Der Vater wartete außerhalb der Tür.',
    transliteration: 'Intaẓara al-ʾabu ḫāriǧa al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1738,
    arabic: 'نَالَتِ الْبِلَادُ اِسْتِقْلَالَهَا بَعْدَ نِضَالٍ.',
    german: 'Das Land erlangte seine Unabhängigkeit nach einem Kampf.',
    transliteration: 'Nālati al-bilādu istiqlālahā baʿda niḍālin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1739,
    arabic: 'قَدَّمَ الْعُمَّالُ مُطَالَبَةً بِأُجُورٍ أَعْلَى.',
    german: 'Die Arbeiter stellten eine Forderung nach höheren Löhnen.',
    transliteration: 'Qaddama al-ʿummālu muṭālabatan bi-ʾuǧūrin ʾaʿlā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1740,
    arabic: 'كَانَتْ نِيَّةُ الرَّجُلِ صَادِقَةً.',
    german: 'Die Absicht des Mannes war aufrichtig.',
    transliteration: 'Kānat niyyatu ar-raǧuli ṣādiqatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 175 (word_ids 1741–1750): „Wissen und Technik".
/// Vom Computer über die Astronomie bis zur Festung der Alten.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyFiveStory = [
  Sentence(
    wordId: 1741,
    arabic: 'يَعْمَلُ الْمُهَنْدِسُ عَلَى الْحَاسُوبِ طَوَالَ الْيَوْمِ.',
    german: 'Der Ingenieur arbeitet den ganzen Tag am Computer.',
    transliteration: 'Yaʿmalu al-muhandisu ʿalā al-ḥāsūbi ṭawāla al-yawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1742,
    arabic: 'تَوَفَّرَتْ لَنَا مَعْلُومَاتٌ كَثِيرَةٌ.',
    german: 'Uns standen viele Informationen zur Verfügung.',
    transliteration: 'Tawaffarat lanā maʿlūmātun kaṯīratun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1743,
    arabic: 'دَرَسَ الْعَالِمُ عِلْمَ الْفَلَكِ.',
    german: 'Der Forscher studierte die Astronomie.',
    transliteration: 'Darasa al-ʿālimu ʿilma al-falaki.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1744,
    arabic: 'خِدْمَةُ الْفُنْدُقِ مُمْتَازَةٌ.',
    german: 'Der Dienst des Hotels ist ausgezeichnet.',
    transliteration: 'Ḫidmatu al-funduqi mumtāzatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1745,
    arabic: 'نَشَرَ الْكَاتِبُ مَقَالَةً جَدِيدَةً.',
    german: 'Der Autor veröffentlichte einen neuen Artikel.',
    transliteration: 'Našara al-kātibu maqālatan ǧadīdatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1746,
    arabic: 'هَذَا مِثَالٌ وَاضِحٌ لِلطُّلَّابِ.',
    german: 'Dies ist ein klares Beispiel für die Schüler.',
    transliteration: 'Hāḏā miṯālun wāḍiḥun liṭ-ṭullābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1747,
    arabic: 'اِشْتَرَى الْمُعَلِّمُ مَجْمُوعَةَ كُتُبٍ.',
    german: 'Der Lehrer kaufte eine Sammlung von Büchern.',
    transliteration: 'Ištarā al-muʿallimu maǧmūʿata kutubin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1748,
    arabic: 'يُمَارِسُ الشَّبَابُ نَشَاطًا رِيَاضِيًّا.',
    german: 'Die Jugendlichen üben eine sportliche Aktivität aus.',
    transliteration: 'Yumārisu aš-šabābu našāṭan riyāḍiyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1749,
    arabic: 'تَقَعُ الْقَرْيَةُ فِي إِقْلِيمٍ جَبَلِيٍّ.',
    german: 'Das Dorf liegt in einer bergigen Region.',
    transliteration: 'Taqaʿu al-qaryatu fī ʾiqlīmin ǧabaliyyin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1750,
    arabic: 'بَنَى الْقُدَمَاءُ حِصْنًا عَلَى الْجَبَلِ.',
    german: 'Die Alten bauten eine Festung auf dem Berg.',
    transliteration: 'Banā al-qudamāʾu ḥiṣnan ʿalā al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 176 (word_ids 1751–1760): „Der Ausflug aufs Land".
/// Früchte, Zweige und Lieder begleiten einen ruhigen Tag auf dem Land.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventySixStory = [
  Sentence(
    wordId: 1751,
    arabic: 'أَكَلَ الْوَلَدُ ثَمَرَةً حُلْوَةً.',
    german: 'Der Junge aß eine süße Frucht.',
    transliteration: 'ʾAkala al-waladu ṯamaratan ḥulwatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1752,
    arabic: 'يَمْتَدُّ غُصْنُ الشَّجَرَةِ عَلَى النَّافِذَةِ.',
    german: 'Der Zweig des Baumes erstreckt sich über das Fenster.',
    transliteration: 'Yamtaddu ġuṣnu aš-šaǧarati ʿalā an-nāfiḏati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1753,
    arabic: 'سَقَطَ وَرَقٌ كَثِيرٌ فِي الْخَرِيفِ.',
    german: 'Im Herbst fielen viele Blätter.',
    transliteration: 'Saqaṭa waraqun kaṯīrun fī al-ḫarīfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1754,
    arabic: 'وَقَفْنَا عَلَى تَلٍّ صَغِيرٍ.',
    german: 'Wir standen auf einem kleinen Hügel.',
    transliteration: 'Waqafnā ʿalā tallin ṣaġīrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1755,
    arabic: 'التُّرْبَةُ هُنَا خَصْبَةٌ وَغَنِيَّةٌ.',
    german: 'Die Erde hier ist fruchtbar und reich.',
    transliteration: 'At-turbatu hunā ḫaṣbatun wa-ġaniyyatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1756,
    arabic: 'نَظَرَ الْمُسَافِرُ إِلَى الْخَرِيطَةِ.',
    german: 'Der Reisende blickte auf die Landkarte.',
    transliteration: 'Naẓara al-musāfiru ʾilā al-ḫarīṭati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1757,
    arabic: 'غَنَّى الْفَلَّاحُ أُغْنِيَةً قَدِيمَةً.',
    german: 'Der Bauer sang ein altes Lied.',
    transliteration: 'Ġannā al-fallāḥu uġniyatan qadīmatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1758,
    arabic: 'سَمِعْنَا نَغْمَةً جَمِيلَةً مِنَ الْعُودِ.',
    german: 'Wir hörten eine schöne Melodie von der Laute.',
    transliteration: 'Samiʿnā naġmatan ǧamīlatan mina al-ʿūdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1759,
    arabic: 'أَزْعَجَنَا ضَجِيجُ السَّيَّارَاتِ.',
    german: 'Der Lärm der Autos störte uns.',
    transliteration: 'ʾAzʿaǧanā ḍaǧīǧu as-sayyārāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1760,
    arabic: 'أَحْبَبْتُ هُدُوءَ الرِّيفِ.',
    german: 'Ich mochte die Ruhe des Landlebens.',
    transliteration: 'ʾAḥbabtu hudūʾa ar-rīfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 177 (word_ids 1761–1770): „Vor der Reise".
/// Koffer, Faden und Bus: eine Familie bereitet die Ferien vor.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventySevenStory = [
  Sentence(
    wordId: 1761,
    arabic: 'سَمِعْنَا صَرْخَةً فِي اللَّيْلِ.',
    german: 'Wir hörten einen Schrei in der Nacht.',
    transliteration: 'Samiʿnā ṣarḫatan fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1762,
    arabic: 'فِي يَدِهِ جِرَاحَةٌ صَغِيرَةٌ.',
    german: 'An seiner Hand ist eine kleine Wunde.',
    transliteration: 'Fī yadihī ǧirāḥatun ṣaġīratun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1763,
    arabic: 'شَرِبَ الرَّجُلُ قَدَحًا مِنَ الْمَاءِ.',
    german: 'Der Mann trank einen Becher Wasser.',
    transliteration: 'Šariba ar-raǧulu qadaḥan mina al-māʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1764,
    arabic: 'اِنْفَكَّ زِرُّ الْقَمِيصِ.',
    german: 'Der Knopf des Hemdes ging auf.',
    transliteration: 'Infakka zirru al-qamīṣi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1765,
    arabic: 'أَخَذَتِ الْأُمُّ خَيْطًا وَإِبْرَةً.',
    german: 'Die Mutter nahm einen Faden und eine Nadel.',
    transliteration: 'ʾAḫaḏati al-ʾummu ḫayṭan wa-ʾibratan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1766,
    arabic: 'قَصَّتِ الْخَيَّاطَةُ الثَّوْبَ بِمِقَصٍّ.',
    german: 'Die Schneiderin schnitt den Stoff mit einer Schere.',
    transliteration: 'Qaṣṣati al-ḫayyāṭatu aṯ-ṯawba bi-miqaṣṣin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1767,
    arabic: 'تَأَخَّرَتِ الْحَافِلَةُ عَنِ الْمَوْعِدِ.',
    german: 'Der Bus verspätete sich gegenüber dem Termin.',
    transliteration: 'Taʾaḫḫarat al-ḥāfilatu ʿani al-mawʿidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1768,
    arabic: 'قَضَيْنَا الْعُطْلَةَ فِي الْجَبَلِ.',
    german: 'Wir verbrachten den Urlaub im Gebirge.',
    transliteration: 'Qaḍaynā al-ʿuṭlata fī al-ǧabali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1769,
    arabic: 'طَلَبَ الْمُوَظَّفُ إِجَازَةً لِأُسْبُوعَيْنِ.',
    german: 'Der Angestellte beantragte einen Urlaub für zwei Wochen.',
    transliteration: 'Ṭalaba al-muwaẓẓafu ʾiǧāzatan li-ʾusbūʿayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1770,
    arabic: 'يَبْدَأُ مَوْسِمُ الْحَصَادِ فِي الصَّيْفِ.',
    german: 'Die Erntesaison beginnt im Sommer.',
    transliteration: 'Yabdaʾu mawsimu al-ḥaṣādi fī aṣ-ṣayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 178 (word_ids 1771–1780): „Die Stadtbesichtigung".
/// Kirchen, Moscheen und alte Handwerke auf einer Tour durch die Stadt.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyEightStory = [
  Sentence(
    wordId: 1771,
    arabic: 'قَامَ السَّائِحُ بِجَوْلَةٍ فِي الْمَدِينَةِ.',
    german: 'Der Tourist machte eine Tour durch die Stadt.',
    transliteration: 'Qāma as-sāʾiḥu bi-ǧawlin fī al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1772,
    arabic: 'خَرَجَتِ الْعَائِلَةُ فِي نُزْهَةٍ إِلَى الرِّيفِ.',
    german: 'Die Familie machte einen Ausflug aufs Land.',
    transliteration: 'Ḫaraǧati al-ʿāʾilatu fī nuzhatin ʾilā ar-rīfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1773,
    arabic: 'صَلَّى النَّاسُ فِي الْجَامِعِ.',
    german: 'Die Leute beteten in der Moschee.',
    transliteration: 'Ṣallā an-nāsu fī al-ǧāmiʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1774,
    arabic: 'تَقَعُ الْكَنِيسَةُ قُرْبَ الْحَدِيقَةِ.',
    german: 'Die Kirche liegt nahe am Park.',
    transliteration: 'Taqaʿu al-kanīsatu qurba al-ḥadīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1775,
    arabic: 'زَارَ السُّيَّاحُ مَعْبَدًا قَدِيمًا.',
    german: 'Die Touristen besuchten einen alten Tempel.',
    transliteration: 'Zāra as-suyyāḥu maʿbadan qadīman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1776,
    arabic: 'الْخَزَفُ حِرْفَةٌ قَدِيمَةٌ.',
    german: 'Die Töpferei ist ein altes Handwerk.',
    transliteration: 'Al-ḫazafu ḥirfatun qadīmatun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1777,
    arabic: 'خَدَمَ الْبَائِعُ الزَّبُونَ بِأَدَبٍ.',
    german: 'Der Verkäufer bediente den Kunden höflich.',
    transliteration: 'Ḫadama al-bāʾiʿu az-zabūna bi-ʾadabin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1778,
    arabic: 'صَاحِبُ الْمَتْجَرِ رَجُلٌ لَطِيفٌ.',
    german: 'Der Besitzer des Ladens ist ein freundlicher Mann.',
    transliteration: 'Ṣāḥibu al-matǧari raǧulun laṭīfun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1779,
    arabic: 'كَانَ زَعِيمُ الْقَبِيلَةِ حَكِيمًا.',
    german: 'Der Führer des Stammes war weise.',
    transliteration: 'Kāna zaʿīmu al-qabīlati ḥakīman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1780,
    arabic: 'اِتَّسَعَتِ الْمَمْلَكَةُ فِي عَهْدِهِ.',
    german: 'Das Königreich dehnte sich in seiner Zeit aus.',
    transliteration: 'Ittasaʿati al-mamlakatu fī ʿahdihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 179 (word_ids 1781–1790): „Kultur und Gesetz".
/// Verfassung, Theater und Wissenschaft auf einer großen Tagung.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredSeventyNineStory = [
  Sentence(
    wordId: 1781,
    arabic: 'كَانَتِ الْخِلَافَةُ نِظَامَ حُكْمٍ قَدِيمًا.',
    german: 'Das Kalifat war einst ein Regierungssystem.',
    transliteration: 'Kānati al-ḫilāfatu niẓāma ḥukmin qadīman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1782,
    arabic: 'يَحْمِي الدُّسْتُورُ حُقُوقَ الْمُوَاطِنِينَ.',
    german: 'Die Verfassung schützt die Rechte der Bürger.',
    transliteration: 'Yaḥmī ad-dustūru ḥuqūqa al-muwāṭinīna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1783,
    arabic: 'صَدَرَ مَرْسُومٌ جَدِيدٌ مِنَ الْحُكُومَةِ.',
    german: 'Ein neues Dekret erging von der Regierung.',
    transliteration: 'Ṣadara marsūmun ǧadīdun mina al-ḥukūmati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1784,
    arabic: 'أُعْجِبْتُ بِنَثْرِ الْكَاتِبِ.',
    german: 'Ich war von der Prosa des Autors beeindruckt.',
    transliteration: 'ʾUʿǧibtu bi-naṯri al-kātibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1785,
    arabic: 'عُرِضَتْ مَسْرَحِيَّةٌ جَمِيلَةٌ فِي الْمَدِينَةِ.',
    german: 'Ein schönes Theaterstück wurde in der Stadt aufgeführt.',
    transliteration: 'ʿUriḍat masraḥiyyatun ǧamīlatun fī al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1786,
    arabic: 'شَاهَدْنَا فِلْمًا مُثِيرًا أَمْسِ.',
    german: 'Wir sahen gestern einen spannenden Film.',
    transliteration: 'Šāhadnā filman muṯīran ʾamsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1787,
    arabic: 'حَضَرَ الطُّلَّابُ مُحَاضَرَةً فِي الْجَامِعَةِ.',
    german: 'Die Studenten besuchten eine Vorlesung an der Universität.',
    transliteration: 'Ḥaḍara aṭ-ṭullābu muḥāḍaratan fī al-ǧāmiʿati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1788,
    arabic: 'نَظَّمَتِ الْجَمْعِيَّةُ نَدْوَةً عَنِ الصِّحَّةِ.',
    german: 'Der Verein organisierte ein Seminar über Gesundheit.',
    transliteration: 'Naẓẓamati al-ǧamʿiyyatu nadwatan ʿani aṣ-ṣiḥḥati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1789,
    arabic: 'اِفْتَتَحَ الْعُلَمَاءُ مُؤْتَمَرًا دَوْلِيًّا.',
    german: 'Die Gelehrten eröffneten eine internationale Konferenz.',
    transliteration: 'Iftataḥa al-ʿulamāʾu muʾtamaran dawliyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1790,
    arabic: 'كَانَ اللِّقَاءُ وَدِّيًّا وَقَصِيرًا.',
    german: 'Die Begegnung war freundlich und kurz.',
    transliteration: 'Kāna al-liqāʾu waddiyyan wa-qaṣīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 180 (word_ids 1791–1800): „Das Feuer".
/// Rauch, Flammen und Asche erzählen von einem großen Brand.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyStory = [
  Sentence(
    wordId: 1791,
    arabic: 'رَدَّدَ الْجُنُودُ النَّشِيدَ الْوَطَنِيَّ.',
    german: 'Die Soldaten sangen die Nationalhymne.',
    transliteration: 'Raddada al-ǧunūdu an-našīda al-waṭaniyya.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1792,
    arabic: 'اِرْتَفَعَ الدُّخَانُ فَوْقَ الْبَيْتِ.',
    german: 'Der Rauch stieg über das Haus.',
    transliteration: 'Irtafaʿa ad-duḫānu fawqa al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1793,
    arabic: 'كَانَ اللَّهَبُ عَالِيًا وَقَوِيًّا.',
    german: 'Die Flamme war hoch und stark.',
    transliteration: 'Kāna al-lahabu ʿāliyan wa-qawiyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1794,
    arabic: 'أَخْمَدَ الْإِطْفَائِيُّونَ الْحَرِيقَ بِسُرْعَةٍ.',
    german: 'Die Feuerwehrleute löschten den Brand schnell.',
    transliteration: 'ʾAḫmada al-ʾiṭfāʾiyyūna al-ḥarīqa bi-surʿatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1795,
    arabic: 'تَنَاثَرَ الرَّمَادُ فِي الْهَوَاءِ.',
    german: 'Die Asche verteilte sich in der Luft.',
    transliteration: 'Tanāṯara ar-ramādu fī al-hawāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1796,
    arabic: 'تَصَاعَدَ الْبُخَارُ مِنَ الْقِدْرِ.',
    german: 'Der Dampf stieg aus dem Topf auf.',
    transliteration: 'Taṣāʿada al-buḫāru mina al-qidri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1797,
    arabic: 'الْحَدِيدُ مَعْدِنٌ قَوِيٌّ.',
    german: 'Das Eisen ist ein starkes Metall.',
    transliteration: 'Al-ḥadīdu maʿdinun qawiyyun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1798,
    arabic: 'تُشْتَهَرُ هَذِهِ الْمِنْطَقَةُ بِالزَّرَاعَةِ.',
    german: 'Diese Region ist für den Ackerbau bekannt.',
    transliteration: 'Tuštaharu hāḏihi al-minṭaqatu bi-az-zarāʿati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1799,
    arabic: 'لِأَهَمِّيَّةِ الْمَوْضُوعِ دَوْرٌ فِي الْقَرَارِ.',
    german: 'Die Wichtigkeit des Themas spielt bei der Entscheidung eine Rolle.',
    transliteration: 'Li-ʾahammiyyati al-mawḍūʿi dawrun fī al-qarāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1800,
    arabic: 'الْمَتْحَفُ مَعْلَمٌ ثَقَافِيٌّ هَامٌّ.',
    german: 'Das Museum ist ein bedeutendes kulturelles Wahrzeichen.',
    transliteration: 'Al-matḥafu maʿlamun ṯaqāfiyyun hāmmun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 181 (word_ids 1801–1810): „Schlagzeilen".
/// Soziale, wirtschaftliche und politische Themen in der Zeitung.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyOneStory = [
  Sentence(
    wordId: 1801,
    arabic: 'لِلْأُسْرَةِ دَوْرٌ اِجْتِمَاعِيٌّ مُهِمٌّ.',
    german: 'Die Familie hat eine wichtige soziale Rolle.',
    transliteration: 'Lil-ʾusrati dawrun iǧtimāʿiyyun muhimmun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1802,
    arabic: 'نَمَا الْبَلَدُ نُمُوًّا اِقْتِصَادِيًّا كَبِيرًا.',
    german: 'Das Land wuchs mit großem wirtschaftlichem Wachstum.',
    transliteration: 'Namā al-baladu numuwwan iqtiṣādiyyan kabīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1803,
    arabic: 'نَاقَشَ الرَّجُلُ قَضَايَا سِيَاسِيَّةً كَثِيرَةً.',
    german: 'Der Mann erörterte viele politische Fragen.',
    transliteration: 'Nāqaša ar-raǧulu qaḍāyā siyāsiyyatan kaṯīratan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1804,
    arabic: 'كَانَ هَذَا الْيَوْمُ اِسْتِثْنَائِيًّا.',
    german: 'Dieser Tag war außergewöhnlich.',
    transliteration: 'Kāna hāḏā al-yawmu istiṯnāʾiyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1805,
    arabic: 'الْقَاضِي هُوَ الشَّخْصُ الرَّئِيسِيُّ فِي الْمَحْكَمَةِ.',
    german: 'Der Richter ist die Hauptperson im Gericht.',
    transliteration: 'Al-qāḍī huwa aš-šaḫṣu ar-raʾīsiyyu fī al-maḥkamati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1806,
    arabic: 'أَصْبَحَ الِاقْتِصَادُ عَالَمِيًّا فِي زَمَنِنَا.',
    german: 'Die Wirtschaft wurde in unserer Zeit global.',
    transliteration: 'ʾAṣbaḥa al-iqtiṣādu ʿālamiyyan fī zamaninā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1807,
    arabic: 'زَارَ النَّاسُ مَكَانًا أَثَرِيًّا قَدِيمًا.',
    german: 'Die Leute besuchten einen alten historischen Ort.',
    transliteration: 'Zāra an-nāsu makānan ʾaṯariyyan qadīman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1808,
    arabic: 'الْكَاذِبُ يَفْقِدُ ثِقَةَ النَّاسِ.',
    german: 'Der Lügner verliert das Vertrauen der Leute.',
    transliteration: 'Al-kāḏibu yafqidu ṯiqata an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1809,
    arabic: 'كَانَ الْقَمَرُ سَاطِعًا فِي اللَّيْلِ.',
    german: 'Der Mond war nachts strahlend hell.',
    transliteration: 'Kāna al-qamaru sāṭiʿan fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1810,
    arabic: 'الْحَجَرُ صُلْبٌ وَلَا يَتَحَرَّكُ.',
    german: 'Der Stein ist hart und bewegt sich nicht.',
    transliteration: 'Al-ḥaǧaru ṣulbun wa-lā yataḥarraku.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 182 (word_ids 1811–1820): „Das Ergebnis".
/// Ein Bericht über Gewinn, Wetter und die letzte Lektion des Monats.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyTwoStory = [
  Sentence(
    wordId: 1811,
    arabic: 'عَادَ الْمُسَافِرُ سَالِمًا إِلَى وَطَنِهِ.',
    german: 'Der Reisende kehrte unversehrt in seine Heimat zurück.',
    transliteration: 'ʿĀda al-musāfiru sāliman ʾilā waṭanihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1812,
    arabic: 'كَانَ هَذَا هُوَ الدَّرْسُ الْأَخِيرُ.',
    german: 'Dies war die letzte Lektion.',
    transliteration: 'Kāna hāḏā huwa ad-darsu al-ʾaḫīru.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1813,
    arabic: 'سَنَبْدَأُ الْعَمَلَ فِي الشَّهْرِ اللَّاحِقِ.',
    german: 'Wir beginnen die Arbeit im folgenden Monat.',
    transliteration: 'Sanabdaʾu al-ʿamala fī aš-šahri al-lāḥiqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1814,
    arabic: 'وَضَعَ الْعَامِلُ الْمَبْلَغَ الْبَاقِيَ فِي الصُّنْدُوقِ.',
    german: 'Der Arbeiter legte den restlichen Betrag in die Kiste.',
    transliteration: 'Waḍaʿa al-ʿāmilu al-mablaġa al-bāqiya fī aṣ-ṣundūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1815,
    arabic: 'الْعَمَلُ الْيَوْمَ تَامٌّ وَكَامِلٌ.',
    german: 'Die Arbeit ist heute vollständig und umfassend.',
    transliteration: 'Al-ʿamalu al-yawma tāmmun wa-kāmilun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1816,
    arabic: 'كَانَ الْخَبَرُ مُثِيرًا لِلْجَمِيعِ.',
    german: 'Die Nachricht war für alle aufregend.',
    transliteration: 'Kāna al-ḫabaru muṯīran lil-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1817,
    arabic: 'رَبِحَ التَّاجِرُ رِبْحًا مَادِّيًّا كَبِيرًا.',
    german: 'Der Händler erzielte einen großen materiellen Gewinn.',
    transliteration: 'Rabiḥa at-tāǧiru ribḥan māddiyyan kabīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1818,
    arabic: 'الْجَوُّ الْيَوْمَ مُعْتَدِلٌ وَلَطِيفٌ.',
    german: 'Das Wetter ist heute gemäßigt und angenehm.',
    transliteration: 'Al-ǧawwu al-yawma muʿtadilun wa-laṭīfun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1819,
    arabic: 'الْأَثَرُ الظَّاهِرُ يَدُلُّ عَلَى الطَّرِيقِ.',
    german: 'Die sichtbare Spur weist auf den Weg.',
    transliteration: 'Al-ʾaṯaru aẓ-ẓāhiru yadullu ʿalā aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1820,
    arabic: 'الْغُرْفَةُ مُتَّسِعَةٌ وَمُمْتَلِئَةٌ بِالضَّوْءِ.',
    german: 'Das Zimmer ist weit und voller Licht.',
    transliteration: 'Al-ġurfatu muttasiʿatun wa-mumtaliʾatun bi-aḍ-ḍawʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 183 (word_ids 1821–1830): „Das Studium".
/// Ähnliche Zwillinge, veränderliches Wetter und festes Wissen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyThreeStory = [
  Sentence(
    wordId: 1821,
    arabic: 'التَّوْأَمَانِ مُتَشَابِهَانِ فِي الشَّكْلِ.',
    german: 'Die Zwillinge sind in der Form ähnlich.',
    transliteration: 'At-tawʾamāni mutašābihāni fī aš-šakli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1822,
    arabic: 'الطَّقْسُ مُتَغَيِّرٌ فِي الرَّبِيعِ.',
    german: 'Das Wetter ist im Frühling veränderlich.',
    transliteration: 'Aṭ-ṭaqsu mutaġayyirun fī ar-rabīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1823,
    arabic: 'أَصْبَحَتِ الْمَرْأَةُ مُسْتَقِلَّةً فِي عَمَلِهَا.',
    german: 'Die Frau wurde in ihrer Arbeit unabhängig.',
    transliteration: 'ʾAṣbaḥati al-marʾatu mustaqillatan fī ʿamalihā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1824,
    arabic: 'كَانَ التَّقْرِيرُ شَامِلًا لِكُلِّ الْجَوَانِبِ.',
    german: 'Der Bericht war umfassend für alle Aspekte.',
    transliteration: 'Kāna at-taqrīru šāmilan likulli al-ǧawānibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1825,
    arabic: 'وَصَلَ مِنَ الْبَحْرِ مَاءٌ وَافِرٌ.',
    german: 'Aus dem Meer kam reichlich Wasser.',
    transliteration: 'Waṣala mina al-baḥri māʾun wāfirun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1826,
    arabic: 'سَقَطَ الْمَطَرُ الْغَزِيرُ عَلَى الْمَدِينَةِ.',
    german: 'Der ergiebige Regen fiel auf die Stadt.',
    transliteration: 'Saqaṭa al-maṭaru al-ġazīru ʿalā al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1827,
    arabic: 'بُنِيَ الْجِسْرُ بِحَجَرٍ مَتِينٍ.',
    german: 'Die Brücke wurde mit stabilem Stein gebaut.',
    transliteration: 'Buniya al-ǧisru bi-ḥaǧarin matīnin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1828,
    arabic: 'الْعِلْمُ الرَّاسِخُ لَا يُنْسَى.',
    german: 'Gefestigtes Wissen wird nicht vergessen.',
    transliteration: 'Al-ʿilmu ar-rāsiḫu lā yunsā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1829,
    arabic: 'الْعَاجِزُ يَحْتَاجُ إِلَى مُسَاعَدَةٍ.',
    german: 'Der Unfähige braucht Hilfe.',
    transliteration: 'Al-ʿāǧizu yaḥtāǧu ʾilā musāʿadatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1830,
    arabic: 'كَانَ الْجَدُّ أُمِّيًّا لَكِنَّهُ حَكِيمٌ.',
    german: 'Der Großvater war ungebildet, aber weise.',
    transliteration: 'Kāna al-ǧaddu ʾummiyyan lākinnahū ḥakīmun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 184 (word_ids 1831–1840): „Der Tagesablauf".
/// Zuerst, zweitens und täglich — eine einfache Lernroutine.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyFourStory = [
  Sentence(
    wordId: 1831,
    arabic: 'أَوَّلًا أَتَعَلَّمُ الْكَلِمَاتِ الْجَدِيدَةَ.',
    german: 'Zuerst lerne ich die neuen Wörter.',
    transliteration: 'ʾAwwalan ʾataʿallamu al-kalimāti al-ǧadīdata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1832,
    arabic: 'ثَانِيًا أَقْرَأُ النَّصَّ بِهُدُوءٍ.',
    german: 'Zweitens lese ich den Text ruhig.',
    transliteration: 'Ṯāniyan ʾaqraʾu an-naṣṣa bi-hudūʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1833,
    arabic: 'ثَالِثًا أَكْتُبُ التَّمَارِينَ فِي الدَّفْتَرِ.',
    german: 'Drittens schreibe ich die Übungen ins Heft.',
    transliteration: 'Ṯāliṯan ʾaktubu at-tamārīna fī ad-daftari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1834,
    arabic: 'رَابِعًا أُرَاجِعُ الدَّرْسَ مَعَ صَدِيقِي.',
    german: 'Viertens wiederhole ich die Lektion mit meinem Freund.',
    transliteration: 'Rābiʿan ʾurāǧiʿu ad-darsa maʿa ṣadīqī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1835,
    arabic: 'أَعْمَلُ حَالِيًّا فِي شَرِكَةٍ صَغِيرَةٍ.',
    german: 'Ich arbeite derzeit in einer kleinen Firma.',
    transliteration: 'ʾAʿmalu ḥāliyyan fī šarikatin ṣaġīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1836,
    arabic: 'زُرْتُ حَدِيثًا مَدِينَةً قَدِيمَةً.',
    german: 'Ich besuchte kürzlich eine alte Stadt.',
    transliteration: 'Zurtu ḥadīṯan madīnatan qadīmatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1837,
    arabic: 'الشَّاطِئُ جَمِيلٌ جِدًّا فِي الصَّيْفِ.',
    german: 'Der Strand ist im Sommer sehr schön.',
    transliteration: 'Aš-šāṭiʾu ǧamīlun ǧiddan fī aṣ-ṣayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1838,
    arabic: 'أُصَلِّي صَبَاحًا قَبْلَ الْعَمَلِ.',
    german: 'Ich bete morgens vor der Arbeit.',
    transliteration: 'ʾUṣallī ṣabāḥan qabla al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1839,
    arabic: 'أَتَدَرَّبُ عَلَى الْقِرَاءَةِ يَوْمِيًّا.',
    german: 'Ich übe das Lesen täglich.',
    transliteration: 'ʾAtadarrabbu ʿalā al-qirāʾati yawmiyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1840,
    arabic: 'أَشْرَبُ الْقَهْوَةَ قَلِيلًا فِي اللَّيْلِ.',
    german: 'Ich trinke nachts wenig Kaffee.',
    transliteration: 'ʾAšrabu al-qahwata qalīlan fī al-layli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 185 (word_ids 1841–1850): „Behörden und Alltag".
/// Teilweise, völlig und tatsächlich: ein Tag mit Entscheidungen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyFiveStory = [
  Sentence(
    wordId: 1841,
    arabic: 'نَجَحَ الطَّالِبُ جُزْئِيًّا فِي الِاخْتِبَارِ.',
    german: 'Der Schüler hatte im Test teilweise Erfolg.',
    transliteration: 'Naǧaḥa aṭ-ṭālibu ǧuzʾiyyan fī al-iḫtibāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1842,
    arabic: 'لَا أُوَافِقُهُ كُلِّيًّا عَلَى رَأْيِهِ.',
    german: 'Ich stimme ihm in seiner Meinung nicht völlig zu.',
    transliteration: 'Lā ʾuwāfiquhū kulliyyan ʿalā raʾyihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1843,
    arabic: 'أَنْجَزَ الْعَامِلُ الْعَمَلَ فِعْلِيًّا.',
    german: 'Der Arbeiter führte die Arbeit tatsächlich aus.',
    transliteration: 'ʾAnǧaza al-ʿāmilu al-ʿamala fiʿliyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1844,
    arabic: 'يَبْلُغُ عَدَدُ السُّكَّانِ إِجْمَالِيًّا مِلْيُونَ نَسَمَةٍ.',
    german: 'Die Einwohnerzahl beträgt insgesamt eine Million Personen.',
    transliteration: 'Yabluġu ʿadadu as-sukkāni iǧmāliyyan milyūna nasamatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1845,
    arabic: 'تَحَدَّثْتُ بِشَأْنِ الْمَشْرُوعِ الْجَدِيدِ.',
    german: 'Ich sprach bezüglich des neuen Projekts.',
    transliteration: 'Taḥaddaṯtu bišaʾni al-mašrūʿi al-ǧadīdi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1846,
    arabic: 'جَلَسَ الْوَلَدُ قُبَالَةَ الْبَابِ.',
    german: 'Der Junge saß gegenüber der Tür.',
    transliteration: 'Ǧalasa al-waladu qubālata al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1847,
    arabic: 'وَقَفَ النَّاسُ وَسَطَ السَّاحَةِ.',
    german: 'Die Leute standen mitten auf dem Platz.',
    transliteration: 'Waqafa an-nāsu wasaṭa as-sāḥati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1848,
    arabic: 'أَنْفَذَ الْمُدِيرُ الْقَرَارَ بِسُرْعَةٍ.',
    german: 'Der Leiter führte die Entscheidung schnell aus.',
    transliteration: 'ʾAnfaḏa al-mudīru al-qarāra bi-surʿatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1849,
    arabic: 'أَحَلَّ الْقَاضِي الْعَقْدَ بَعْدَ الْخِلَافِ.',
    german: 'Der Richter löste den Vertrag nach dem Streit auf.',
    transliteration: 'ʾAḥalla al-qāḍī al-ʿaqda baʿda al-ḫilāfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1850,
    arabic: 'أَخْرَجَ الرَّجُلُ الْكُرْسِيَّ إِلَى الْحَدِيقَةِ.',
    german: 'Der Mann brachte den Stuhl in den Garten hinaus.',
    transliteration: 'ʾAḫraǧa ar-raǧulu al-kursiyya ʾilā al-ḥadīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 186 (word_ids 1851–1860): „Die gute Tat".
/// Helfen, füttern und überzeugen in einer Reihe von Geschichten.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightySixStory = [
  Sentence(
    wordId: 1851,
    arabic: 'أَذَاقَتِ الْأُمُّ الطِّفْلَ الْعَسَلَ.',
    german: 'Die Mutter ließ das Kind den Honig kosten.',
    transliteration: 'ʾAḏāqati al-ʾummu aṭ-ṭifla al-ʿasala.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1852,
    arabic: 'أَرْضَى الْعَامِلُ مُدِيرَهُ بِعَمَلِهِ.',
    german: 'Der Arbeiter stellte seinen Leiter durch seine Arbeit zufrieden.',
    transliteration: 'ʾArḍā al-ʿāmilu mudīrahū bi-ʿamalihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1853,
    arabic: 'أَسْرَفَ الْوَلَدُ فِي الطَّعَامِ.',
    german: 'Der Junge verschwendete beim Essen.',
    transliteration: 'ʾAsrafa al-waladu fī aṭ-ṭaʿāmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1854,
    arabic: 'أَصَابَ الرَّامِي الْهَدَفَ.',
    german: 'Der Schütze traf das Ziel.',
    transliteration: 'ʾAṣāba ar-rāmī al-hadafa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1855,
    arabic: 'أَضَرَّ الدُّخَانُ بِصِحَّةِ الْجَدِّ.',
    german: 'Der Rauch schadete der Gesundheit des Großvaters.',
    transliteration: 'ʾAḍarra ad-duḫānu bi-ṣiḥḥati al-ǧaddi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1856,
    arabic: 'أَطْعَمَ الرَّجُلُ الْقِطَّ وَالْكَلْبَ.',
    german: 'Der Mann fütterte die Katze und den Hund.',
    transliteration: 'ʾAṭʿama ar-raǧulu al-qiṭṭa wa-al-kalba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1857,
    arabic: 'أَعَانَ الْأَخُ أَخَاهُ فِي الدِّرَاسَةِ.',
    german: 'Der Bruder half seinem Bruder im Studium.',
    transliteration: 'ʾAʿāna al-ʾaḫu ʾaḫāhu fī ad-dirāsati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1858,
    arabic: 'أَغْرَقَ الْبَحْرُ الْقَارِبَ الصَّغِيرَ.',
    german: 'Das Meer ertränkte das kleine Boot.',
    transliteration: 'ʾAġraqa al-baḥru al-qāriba aṣ-ṣaġīra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1859,
    arabic: 'أَقْنَعَ الْمُعَلِّمُ الطَّالِبَ بِالْحَقِيقَةِ.',
    german: 'Der Lehrer überzeugte den Schüler von der Wahrheit.',
    transliteration: 'ʾAqnaʿa al-muʿallimu aṭ-ṭāliba bi-al-ḥaqīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1860,
    arabic: 'أَلْزَمَ الْأَبُ ابْنَهُ بِالْعَمَلِ.',
    german: 'Der Vater verpflichtete seinen Sohn zur Arbeit.',
    transliteration: 'ʾAlzama al-ʾabu ibnahū bi-al-ʿamali.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 187 (word_ids 1861–1870): „Der schwierige Tag".
/// Streit, Rat und Zwang prägen einen langen Arbeitstag.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightySevenStory = [
  Sentence(
    wordId: 1861,
    arabic: 'أَمْكَنَ لِلطَّالِبِ حَلُّ الْمَسْأَلَةِ.',
    german: 'Dem Schüler war das Lösen der Aufgabe möglich.',
    transliteration: 'ʾAmkana liṭ-ṭālibi ḥallu al-masʾalati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1862,
    arabic: 'أَوْجَعَ الْحَدِيدُ يَدَ الْعَامِلِ.',
    german: 'Das Eisen schmerzte die Hand des Arbeiters.',
    transliteration: 'ʾAwǧaʿa al-ḥadīdu yada al-ʿāmili.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1863,
    arabic: 'أَوْسَعَ الْأَبُ الْبَيْتَ لِلْعَائِلَةِ.',
    german: 'Der Vater erweiterte das Haus für die Familie.',
    transliteration: 'ʾAwsaʿa al-ʾabu al-bayta lil-ʿāʾilati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1864,
    arabic: 'اِحْتَجَّ الْعُمَّالُ عَلَى الْأُجُورِ الْمُنْخَفِضَةِ.',
    german: 'Die Arbeiter protestierten gegen die niedrigen Löhne.',
    transliteration: 'Iḥtaǧǧa al-ʿummālu ʿalā al-ʾuǧūri al-munḫafiḍati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1865,
    arabic: 'اِرْتَدَّ الْجُنْدِيُّ إِلَى مُعَسْكَرِهِ.',
    german: 'Der Soldat kehrte in sein Lager zurück.',
    transliteration: 'Irtadda al-ǧundiyyu ʾilā muʿaskarihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1866,
    arabic: 'اِسْتَبَانَ الْحَقُّ بَعْدَ الْبَحْثِ.',
    german: 'Die Wahrheit wurde nach der Untersuchung klar.',
    transliteration: 'Istabāna al-ḥaqqu baʿda al-baḥṯi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1867,
    arabic: 'اِسْتَحَبَّ الْإِمَامُ الْقِرَاءَةَ الْهَادِئَةَ.',
    german: 'Der Imam zog das ruhige Lesen vor.',
    transliteration: 'Istaḥabba al-ʾimāmu al-qirāʾata al-hādiʾata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1868,
    arabic: 'اِسْتَرْشَدَ الطَّالِبُ أُسْتَاذَهُ فِي الْأَمْرِ.',
    german: 'Der Student bat seinen Lehrer in der Sache um Rat.',
    transliteration: 'Istaršada aṭ-ṭālibu ʾustāḏahū fī al-ʾamri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1869,
    arabic: 'اِضْطَرَّ الْمُسَافِرُ إِلَى النَّوْمِ فِي الطَّرِيقِ.',
    german: 'Der Reisende war gezwungen, unterwegs zu schlafen.',
    transliteration: 'Iḍṭurra al-musāfiru ʾilā an-nawmi fī aṭ-ṭarīqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1870,
    arabic: 'اِنْشَغَلَ الْمُدِيرُ بِالْمُكَالَمَاتِ طَوَالَ الْيَوْمِ.',
    german: 'Der Leiter war den ganzen Tag mit Telefonaten beschäftigt.',
    transliteration: 'Inšaġala al-mudīru bi-al-mukālamāti ṭawāla al-yawmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 188 (word_ids 1871–1880): „Die Schlacht und ihre Lehren".
/// Ein Heer verliert, ein Volk lernt und der Reisende findet den Weg.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyEightStory = [
  Sentence(
    wordId: 1871,
    arabic: 'اِنْجَرَّ الْخِلَافُ إِلَى مُشْكِلَةٍ كَبِيرَةٍ.',
    german: 'Der Streit zog sich zu einem großen Problem hin.',
    transliteration: 'Inǧarra al-ḫilāfu ʾilā muškilatin kabīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1872,
    arabic: 'اِنْحَصَرَ الْعَدَدُ فِي مَجْمُوعَةٍ صَغِيرَةٍ.',
    german: 'Die Zahl beschränkte sich auf eine kleine Gruppe.',
    transliteration: 'Inḥaṣara al-ʿadadu fī maǧmūʿatin ṣaġīratin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1873,
    arabic: 'اِنْخَفَضَ سِعْرُ الزَّيْتِ فِي الشَّهْرِ الْمَاضِي.',
    german: 'Der Ölpreis sank im vergangenen Monat.',
    transliteration: 'Inḫafaḍa siʿru az-zayti fī aš-šahri al-māḍī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1874,
    arabic: 'اِنْسَاقَ النَّاسُ وَرَاءَ الزَّعِيمِ.',
    german: 'Die Leute ließen sich hinter dem Führer leiten.',
    transliteration: 'Insāqa an-nāsu warāʾa az-zaʿīmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1875,
    arabic: 'اِنْقَادَ الْجُنُودُ لِأَوَامِرِ الْقَائِدِ.',
    german: 'Die Soldaten ließen sich von den Befehlen des Kommandanten führen.',
    transliteration: 'Inqāda al-ǧunūdu li-ʾawāmiri al-qāʾidi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1876,
    arabic: 'اِنْكَشَفَ السِّرُّ أَمَامَ النَّاسِ.',
    german: 'Das Geheimnis enthüllte sich vor den Leuten.',
    transliteration: 'Inkašafa as-sirru ʾamāma an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1877,
    arabic: 'اِنْهَزَمَ الْجَيْشُ فِي الْمَعْرَكَةِ.',
    german: 'Das Heer wurde in der Schlacht besiegt.',
    transliteration: 'Inhazama al-ǧayšu fī al-maʿrakati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1878,
    arabic: 'اِهْتَدَى الْمُسَافِرُ إِلَى الطَّرِيقِ الصَّحِيحِ.',
    german: 'Der Reisende fand den richtigen Weg.',
    transliteration: 'Ihtadā al-musāfiru ʾilā aṭ-ṭarīqi aṣ-ṣaḥīḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1879,
    arabic: 'تَأَسَّفَ الْمُدِيرُ عَلَى الْخَطَأِ.',
    german: 'Der Leiter bedauerte den Fehler.',
    transliteration: 'Taʾassafa al-mudīru ʿalā al-ḫaṭaʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1880,
    arabic: 'تَأَمَّلَ الْجَدُّ فِي الْمَاضِي طَوِيلًا.',
    german: 'Der Großvater dachte lange über die Vergangenheit nach.',
    transliteration: 'Taʾammala al-ǧaddu fī al-māḍī ṭawīlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 189 (word_ids 1881–1890): „Gutes tun".
/// Adoptieren, spenden und Verantwortung übernehmen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredEightyNineStory = [
  Sentence(
    wordId: 1881,
    arabic: 'تَبَنَّى الرَّجُلُ طِفْلًا صَغِيرًا.',
    german: 'Der Mann adoptierte ein kleines Kind.',
    transliteration: 'Tabannā ar-raǧulu ṭiflan ṣaġīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1882,
    arabic: 'تَبَاهَى الْوَلَدُ بِنَجَاحِهِ.',
    german: 'Der Junge war stolz auf seinen Erfolg.',
    transliteration: 'Tabāhā al-waladu bi-naǧāḥihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1883,
    arabic: 'تَبَرَّعَ الْأَغْنِيَاءُ بِمَالٍ كَثِيرٍ.',
    german: 'Die Reichen spendeten viel Geld.',
    transliteration: 'Tabarraʿa al-ʾaġniyāʾu bi-mālin kaṯīrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1884,
    arabic: 'تَجَاهَلَ الرَّجُلُ سُؤَالَ الْوَلَدِ.',
    german: 'Der Mann ignorierte die Frage des Jungen.',
    transliteration: 'Taǧāhala ar-raǧulu suʾāla al-waladi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1885,
    arabic: 'تَجَدَّدَ الْبَيْتُ بَعْدَ الْإِصْلَاحِ.',
    german: 'Das Haus erneuerte sich nach der Reparatur.',
    transliteration: 'Taǧaddada al-baytu baʿda al-ʾiṣlāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1886,
    arabic: 'تَحَقَّقَ حُلْمُ الطِّفْلِ.',
    german: 'Der Traum des Kindes erfüllte sich.',
    transliteration: 'Taḥaqqaqa ḥulmu aṭ-ṭifli.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1887,
    arabic: 'تَحَمَّلَ الْأَبُ الْمَسْؤُولِيَّةَ.',
    german: 'Der Vater trug die Verantwortung.',
    transliteration: 'Taḥammala al-ʾabu al-masʾūliyyata.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1888,
    arabic: 'تَخَطَّى الْجُنْدِيُّ الْحُدُودَ.',
    german: 'Der Soldat überschritt die Grenzen.',
    transliteration: 'Taḫaṭṭā al-ǧundiyyu al-ḥudūda.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1889,
    arabic: 'تَخَلَّصَ الرَّجُلُ مِنْ هَمِّهِ.',
    german: 'Der Mann wurde seine Sorge los.',
    transliteration: 'Taḫallaṣa ar-raǧulu min hammihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1890,
    arabic: 'تَدَاوَلَ الْوُزَرَاءُ الْأَمْرَ.',
    german: 'Die Minister berieten die Angelegenheit.',
    transliteration: 'Tadāwala al-wuzarāʾu al-ʾamra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 190 (word_ids 1891–1900): „Hochzeit und Glaube".
/// Zögern, heiraten und Almosen geben im religiösen Alltag.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyStory = [
  Sentence(
    wordId: 1891,
    arabic: 'تَرَدَّدَ الرَّجُلُ قَبْلَ الْقَرَارِ.',
    german: 'Der Mann zögerte vor der Entscheidung.',
    transliteration: 'Taraddada ar-raǧulu qabla al-qarāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1892,
    arabic: 'تَزَوَّجَ أَخِي بِفَتَاةٍ طَيِّبَةٍ.',
    german: 'Mein Bruder heiratete ein gutes Mädchen.',
    transliteration: 'Tazawwaǧa ʾaḫī bi-fatātin ṭayyibatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1893,
    arabic: 'تَشَارَكَ الْأَوْلَادُ فِي اللَّعِبِ.',
    german: 'Die Kinder beteiligten sich gemeinsam am Spiel.',
    transliteration: 'Tašāraka al-ʾawlādu fī al-laʿibi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1894,
    arabic: 'تَشَكَّرَ الطَّالِبُ مُعَلِّمَهُ.',
    german: 'Der Schüler bedankte sich bei seinem Lehrer.',
    transliteration: 'Tašakkara aṭ-ṭālibu muʿallimahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1895,
    arabic: 'تَصَدَّقَ الرَّجُلُ عَلَى الْفُقَرَاءِ.',
    german: 'Der Mann gab den Armen Almosen.',
    transliteration: 'Taṣaddaqa ar-raǧulu ʿalā al-fuqarāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1896,
    arabic: 'صَارَحَ الْمُدِيرُ الْعُمَّالَ بِالْحَقِيقَةِ.',
    german: 'Der Leiter sagte den Arbeitern offen die Wahrheit.',
    transliteration: 'Ṣāraḥa al-mudīru al-ʿummāla bi-al-ḥaqīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1897,
    arabic: 'تَعَبَّدَ الرَّاهِبُ فِي الْمَعْبَدِ.',
    german: 'Der Mönch betete im Tempel an.',
    transliteration: 'Taʿabbada ar-rāhibu fī al-maʿbadi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1898,
    arabic: 'تَعَذَّرَ الْحُضُورُ بِسَبَبِ الْمَطَرِ.',
    german: 'Das Erscheinen war wegen des Regens unmöglich.',
    transliteration: 'Taʿaḏḏara al-ḥuḍūru bi-sababi al-maṭari.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1899,
    arabic: 'تَعَمَّدَ الْوَلَدُ إِخْفَاءَ الْحَقِيقَةِ.',
    german: 'Der Junge beabsichtigte, die Wahrheit zu verbergen.',
    transliteration: 'Taʿammada al-waladu ʾiḫfāʾa al-ḥaqīqati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1900,
    arabic: 'تَعَمَّقَ الطَّالِبُ فِي الْعِلْمِ.',
    german: 'Der Schüler vertiefte sich in die Wissenschaft.',
    transliteration: 'Taʿammaqa aṭ-ṭālibu fī al-ʿilmi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 191 (word_ids 1901–1910): „Lernen und Reisen".
/// Ernährung, Preise und Reservierungen auf einer langen Reise.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyOneStory = [
  Sentence(
    wordId: 1901,
    arabic: 'تَغَذَّى الْأَطْفَالُ بِطَعَامٍ صِحِّيٍّ.',
    german: 'Die Kinder ernährten sich mit gesunder Nahrung.',
    transliteration: 'Taġaḏḏā al-ʾaṭfālu bi-ṭaʿāmin ṣiḥḥiyyin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1902,
    arabic: 'تَفَاخَرَ الرَّجُلُ بِمَالِهِ.',
    german: 'Der Mann prahlte mit seinem Geld.',
    transliteration: 'Tafāḫara ar-raǧulu bi-mālihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1903,
    arabic: 'تَفَاوَتَتِ الْأَسْعَارُ بَيْنَ الْمَدِينَتَيْنِ.',
    german: 'Die Preise unterschieden sich zwischen den beiden Städten.',
    transliteration: 'Tafāwata al-ʾasʿāru bayna al-madīnatayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1904,
    arabic: 'تَكَرَّرَ الْخَطَأُ مَرَّتَيْنِ.',
    german: 'Der Fehler wiederholte sich zweimal.',
    transliteration: 'Takarrara al-ḫaṭaʾu marratayni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1905,
    arabic: 'تَكَوَّنَتِ الْجَمَاعَةُ مِنْ عَشَرَةِ أَعْضَاءَ.',
    german: 'Die Gruppe bestand aus zehn Mitgliedern.',
    transliteration: 'Takawwanati al-ǧamāʿatu min ʿašarati ʾaʿḍāʾa.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1906,
    arabic: 'تَلَاشَى الضَّبَابُ فِي الصَّبَاحِ.',
    german: 'Der Nebel verschwand am Morgen.',
    transliteration: 'Talāšā aḍ-ḍabābu fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1907,
    arabic: 'تَهَاوَنَ الطَّالِبُ فِي دِرَاسَتِهِ.',
    german: 'Der Schüler vernachlässigte sein Studium.',
    transliteration: 'Tahāwana aṭ-ṭālibu fī dirāsatihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1908,
    arabic: 'جَاوَزَ السَّائِقُ الْحُدُودَ.',
    german: 'Der Fahrer überschritt die Grenzen.',
    transliteration: 'Ǧāwaza as-sāʾiqu al-ḥudūda.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1909,
    arabic: 'حَاسَبَ الْمُدِيرُ الْعَامِلَ عَلَى الْخَطَأِ.',
    german: 'Der Leiter rechnete mit dem Arbeiter wegen des Fehlers ab.',
    transliteration: 'Ḥāsaba al-mudīru al-ʿāmila ʿalā al-ḫaṭaʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1910,
    arabic: 'حَجَزَ الْمُسَافِرُ غُرْفَةً فِي الْفُنْدُقِ.',
    german: 'Der Reisende reservierte ein Zimmer im Hotel.',
    transliteration: 'Ḥaǧaza al-musāfiru ġurfatan fī al-funduqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 192 (word_ids 1911–1920): „Verantwortung tragen".
/// Retten, verwalten und ehren in einer Stadt voller Aufgaben.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyTwoStory = [
  Sentence(
    wordId: 1911,
    arabic: 'خَلَّصَ الْفَارِسُ الطِّفْلَ مِنَ الْمَاءِ.',
    german: 'Der Ritter rettete das Kind aus dem Wasser.',
    transliteration: 'Ḫallaṣa al-fārisu aṭ-ṭifla mina al-māʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1912,
    arabic: 'دَاوَمَ الطَّالِبُ عَلَى الْقِرَاءَةِ.',
    german: 'Der Schüler fuhr mit dem Lesen fort.',
    transliteration: 'Dāwama aṭ-ṭālibu ʿalā al-qirāʾati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1913,
    arabic: 'دَبَّرَ الْأَبُ شُؤُونَ الْبَيْتِ.',
    german: 'Der Vater verwaltete die Angelegenheiten des Hauses.',
    transliteration: 'Dabbara al-ʾabu šuʾūna al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1914,
    arabic: 'رَشَّحَ الْحِزْبُ رَجُلًا لِلِانْتِخَابَاتِ.',
    german: 'Die Partei nominierte einen Mann für die Wahlen.',
    transliteration: 'Raššaḥa al-ḥizbu raǧulan lil-intiḫābāti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1915,
    arabic: 'سَمَّى الْأَبُ ابْنَهُ سَعِيدًا.',
    german: 'Der Vater nannte seinen Sohn Said.',
    transliteration: 'Sammā al-ʾabu ibnahū Saʿīdan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1916,
    arabic: 'شَخَّصَ الطَّبِيبُ الْمَرَضَ بِسُرْعَةٍ.',
    german: 'Der Arzt diagnostizierte die Krankheit schnell.',
    transliteration: 'Šaḫḫaṣa aṭ-ṭabību al-maraḍa bi-surʿatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1917,
    arabic: 'شَرَّفَ الْمَلِكُ الْعُلَمَاءَ الْحَاضِرِينَ.',
    german: 'Der König ehrte die anwesenden Gelehrten.',
    transliteration: 'Šarrafa al-maliku al-ʿulamāʾa al-ḥāḍirīna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1918,
    arabic: 'صَرَّحَتِ الْوِزَارَةُ بِقَرَارٍ جَدِيدٍ.',
    german: 'Das Ministerium kündigte eine neue Entscheidung an.',
    transliteration: 'Ṣarraḥati al-wizāratu bi-qarārin ǧadīdin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1919,
    arabic: 'طَرَحَ الْبَاحِثُ سُؤَالًا صَعْبًا.',
    german: 'Der Forscher warf eine schwere Frage auf.',
    transliteration: 'Ṭaraḥa al-bāḥiṯu suʾālan saʿban.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1920,
    arabic: 'عَانَقَ الْأَبُ ابْنَهُ بَعْدَ سَفَرٍ طَوِيلٍ.',
    german: 'Der Vater umarmte seinen Sohn nach einer langen Reise.',
    transliteration: 'ʿĀnaqa al-ʾabu ibnahū baʿda safari ṭawīlin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 193 (word_ids 1921–1930): „Handwerk und Wissen".
/// Berufe, Erbschaften und das Warten am Flughafen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyThreeStory = [
  Sentence(
    wordId: 1921,
    arabic: 'عَاهَدَ الْأَصْدِقَاءُ عَلَى الْوَفَاءِ.',
    german: 'Die Freunde verpflichteten sich zur Treue.',
    transliteration: 'ʿĀhada al-ʾaṣdiqāʾu ʿalā al-wafāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1922,
    arabic: 'قَابَلَ الْجُنْدِيُّ الْقَائِدَ فِي الصَّبَاحِ.',
    german: 'Der Soldat traf den Kommandanten am Morgen.',
    transliteration: 'Qābala al-ǧundiyyu al-qāʾida fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1923,
    arabic: 'مَارَسَ الرَّجُلُ الْمِهْنَةَ بِإِتْقَانٍ.',
    german: 'Der Mann übte den Beruf mit Meisterschaft aus.',
    transliteration: 'Mārasa ar-raǧulu al-mihnata bi-ʾitqānin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1924,
    arabic: 'مَزَجَ الْخَبَّازُ الدَّقِيقَ بِالْمَاءِ.',
    german: 'Der Bäcker mischte das Mehl mit Wasser.',
    transliteration: 'Mazaǧa al-ḫabbāzu ad-daqīqa bi-al-māʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1925,
    arabic: 'نَتَجَ عَنِ الْعَمَلِ الطَّوِيلِ نَجَاحٌ كَبِيرٌ.',
    german: 'Aus der langen Arbeit ergab sich ein großer Erfolg.',
    transliteration: 'Nataǧa ʿani al-ʿamali aṭ-ṭawīli naǧāḥun kabīrun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1926,
    arabic: 'وَرَّثَ الْجَدُّ الْبَيْتَ لِحَفِيدِهِ.',
    german: 'Der Großvater vererbte das Haus seinem Enkel.',
    transliteration: 'Warraṯa al-ǧaddu al-bayta li-ḥafīdihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1927,
    arabic: 'يَئِسَ الرَّجُلُ مِنَ النَّجَاحِ.',
    german: 'Der Mann verzweifelte am Erfolg.',
    transliteration: 'Yaʾisa ar-raǧulu mina an-naǧāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1928,
    arabic: 'جَاءَ أَهْلُ الْقَرْيَةِ إِلَى السُّوقِ.',
    german: 'Die Leute des Dorfes kamen zum Markt.',
    transliteration: 'Ǧāʾa ʾahlu al-qaryati ʾilā as-sūqi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1929,
    arabic: 'تَقَدَّمَ الطَّبِيبُ فِي اِخْتِصَاصِهِ.',
    german: 'Der Arzt machte Fortschritte in seinem Fachgebiet.',
    transliteration: 'Taqaddama aṭ-ṭabību fī iḫtiṣāṣihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1930,
    arabic: 'طَالَ اِنْتِظَارُ الْمُسَافِرِينَ فِي الْمَطَارِ.',
    german: 'Das Warten der Reisenden im Flughafen dauerte lange.',
    transliteration: 'Ṭāla intiẓāru al-musāfirīna fī al-maṭāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 194 (word_ids 1931–1940): „Bildung und Alltag".
/// Schule, Preise und Glaube prägen das tägliche Leben.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyFourStory = [
  Sentence(
    wordId: 1931,
    arabic: 'التَّعْلِيمُ حَقٌّ لِكُلِّ طِفْلٍ.',
    german: 'Bildung ist ein Recht für jedes Kind.',
    transliteration: 'At-taʿlīmu ḥaqqun likulli ṭiflin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1932,
    arabic: 'يُسَهِّلُ التَّطْبِيقُ حَيَاةَ النَّاسِ.',
    german: 'Die Anwendung erleichtert das Leben der Menschen.',
    transliteration: 'Yusahhilu at-taṭbīqu ḥayāta an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1933,
    arabic: 'قَدَّمَ الْمُفَسِّرُ تَفْسِيرًا وَاضِحًا.',
    german: 'Der Ausleger legte eine klare Auslegung vor.',
    transliteration: 'Qaddama al-mufassiru tafsīran wāḍiḥan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1934,
    arabic: 'صَفَّقَ الْجُمْهُورُ بِحَمَاسٍ.',
    german: 'Das Publikum klatschte mit Begeisterung.',
    transliteration: 'Ṣaffaqa al-ǧumhūru bi-ḥamāsin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1935,
    arabic: 'أَكْمَلَ الطَّالِبُ دِرَاسَةً جَامِعِيَّةً.',
    german: 'Der Student schloss ein Universitätsstudium ab.',
    transliteration: 'ʾAkmala aṭ-ṭālibu dirāsatan ǧāmiʿiyyatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1936,
    arabic: 'يَحْتَاجُ الْمَرِيضُ إِلَى رِعَايَةٍ كَامِلَةٍ.',
    german: 'Der Patient braucht eine vollständige Pflege.',
    transliteration: 'Yaḥtāǧu al-marīḍu ʾilā riʿāyatin kāmilatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1937,
    arabic: 'اِرْتَفَعَ سِعْرُ الْخُبْزِ هَذَا الشَّهْرَ.',
    german: 'Der Preis des Brotes stieg diesen Monat.',
    transliteration: 'Irtafaʿa siʿru al-ḫubzi hāḏā aš-šahra.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1938,
    arabic: 'تُنَظِّمُ الشَّرِيعَةُ حَيَاةَ النَّاسِ.',
    german: 'Die Scharia regelt das Leben der Menschen.',
    transliteration: 'Tunaẓẓimu aš-šarīʿatu ḥayāta an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1939,
    arabic: 'الْعِبَادَةُ تُقَرِّبُ الْإِنْسَانَ إِلَى رَبِّهِ.',
    german: 'Der Gottesdienst bringt den Menschen seinem Herrn näher.',
    transliteration: 'Al-ʿibādatu tuqarribu al-ʾinsāna ʾilā rabbihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1940,
    arabic: 'اِشْتَكَى النَّاسُ مِنْ غَلَاءِ الْأَسْعَارِ.',
    german: 'Die Leute beklagten sich über die Teuerung der Preise.',
    transliteration: 'Ištakā an-nāsu min ġalāʾi al-ʾasʿāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 195 (word_ids 1941–1950): „Wohlstand und Erfolg".
/// Erfolg, Ehrgeiz und Geschmack im Laufe der Zeit.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyFiveStory = [
  Sentence(
    wordId: 1941,
    arabic: 'تَزِيدُ كَمِّيَّةُ الْمَاءِ فِي الصَّيْفِ.',
    german: 'Die Wassermenge steigt im Sommer.',
    transliteration: 'Tazīdu kammiyyatu al-māʾi fī aṣ-ṣayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1942,
    arabic: 'جَاءَ النَّجَاحُ بَعْدَ جُهْدٍ كَبِيرٍ.',
    german: 'Der Erfolg kam nach großer Anstrengung.',
    transliteration: 'Ǧāʾa an-naǧāḥu baʿda ǧuhdin kabīrin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1943,
    arabic: 'لِلطَّالِبِ هِمَّةٌ عَالِيَةٌ فِي الدِّرَاسَةِ.',
    german: 'Der Schüler hat hohen Ehrgeiz im Studium.',
    transliteration: 'Liṭ-ṭālibi himmatun ʿāliyatun fī ad-dirāsati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1944,
    arabic: 'مَرَّ دَهْرٌ طَوِيلٌ عَلَى هَذِهِ الْقَرْيَةِ.',
    german: 'Eine lange Zeit verging über diesem Dorf.',
    transliteration: 'Marra dahrun ṭawīlun ʿalā hāḏihi al-qaryati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1945,
    arabic: 'لِلْعَسَلِ ذُوقٌ حُلْوٌ مُمَيَّزٌ.',
    german: 'Der Honig hat einen süßen, besonderen Geschmack.',
    transliteration: 'Lil-ʿasali ḏawqun ḥulwun mumayyazun.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1946,
    arabic: 'عَبَّرَ الرَّجُلُ عَنْ شُعُورِهِ بِصِدْقٍ.',
    german: 'Der Mann drückte sein Gefühl aufrichtig aus.',
    transliteration: 'ʿAbbara ar-raǧulu ʿan šuʿūrihī bi-ṣidqin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1947,
    arabic: 'كَانَ الْجُنْدِيُّ ضَحِيَّةَ الْحَرْبِ.',
    german: 'Der Soldat war ein Opfer des Krieges.',
    transliteration: 'Kāna al-ǧundiyyu ḍaḥiyyata al-ḥarbi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1948,
    arabic: 'اِتَّعَظَ النَّاسُ مِنْ عِبْرَةِ الْمَاضِي.',
    german: 'Die Leute lernten aus der Lehre der Vergangenheit.',
    transliteration: 'Ittaʿaẓa an-nāsu min ʿibrati al-māḍī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1949,
    arabic: 'الْكَلَامُ الطَّيِّبُ يَفْتَحُ الْقُلُوبَ.',
    german: 'Das gute Wort öffnet die Herzen.',
    transliteration: 'Al-kalāmu aṭ-ṭayyibu yaftaḥu al-qulūba.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1950,
    arabic: 'اِرْتَفَعَ الْمَبْنَى الْجَدِيدُ فِي وَسَطِ الْمَدِينَةِ.',
    german: 'Das neue Gebäude erhob sich in der Mitte der Stadt.',
    transliteration: 'Irtafaʿa al-mabnā al-ǧadīdu fī wasaṭi al-madīnati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 196 (word_ids 1951–1960): „Staat und Gesellschaft".
/// Heimat, Wirtschaft und Wahlen im öffentlichen Leben.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetySixStory = [
  Sentence(
    wordId: 1951,
    arabic: 'الْوَطَنُ أَغْلَى مِنْ كُلِّ شَيْءٍ.',
    german: 'Die Heimat ist wertvoller als alles.',
    transliteration: 'Al-waṭanu ʾaġlā min kulli šayʾin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1952,
    arabic: 'صَدَرَ إِصْدَارٌ جَدِيدٌ لِهَذَا الْكِتَابِ.',
    german: 'Eine neue Ausgabe dieses Buches erschien.',
    transliteration: 'Ṣadara ʾiṣdārun ǧadīdun lihāḏā al-kitābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1953,
    arabic: 'الِاقْتِصَادُ أَسَاسُ حَيَاةِ النَّاسِ.',
    german: 'Die Wirtschaft ist die Grundlage des Lebens der Menschen.',
    transliteration: 'Al-iqtiṣādu ʾasāsu ḥayāti an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1954,
    arabic: 'قَدَّمَ النَّائِبُ اِعْتِرَاضًا عَلَى الْقَرَارِ.',
    german: 'Der Abgeordnete brachte einen Einwand gegen die Entscheidung vor.',
    transliteration: 'Qaddama an-nāʾibu iʿtirāḍan ʿalā al-qarāri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1955,
    arabic: 'يَزِيدُ اِسْتِعْمَالُ الْحَاسُوبِ كُلَّ يَوْمٍ.',
    german: 'Die Nutzung des Computers nimmt jeden Tag zu.',
    transliteration: 'Yazīdu istiʿmālu al-ḥāsūbi kulla yawmin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1956,
    arabic: 'بَدَأَ الِانْتِخَابُ فِي الصَّبَاحِ الْبَاكِرِ.',
    german: 'Die Wahl begann am frühen Morgen.',
    transliteration: 'Badaʾa al-intiḫābu fī aṣ-ṣabāḥi al-bākiri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1957,
    arabic: 'اِسْتَشَارَ الْمُدِيرُ مُسْتَشَارًا خَبِيرًا.',
    german: 'Der Leiter konsultierte einen erfahrenen Berater.',
    transliteration: 'Istašāra al-mudīru mustašāran ḫabīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1958,
    arabic: 'كَتَبَ الطَّالِبُ مُلَخَّصًا قَصِيرًا.',
    german: 'Der Schüler schrieb eine kurze Zusammenfassung.',
    transliteration: 'Kataba aṭ-ṭālibu mulaḫḫaṣan qaṣīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1959,
    arabic: 'الْعَقِيدَةُ الصَّحِيحَةُ تُقَوِّي الْإِنْسَانَ.',
    german: 'Die richtige Glaubenslehre stärkt den Menschen.',
    transliteration: 'Al-ʿaqīdatu aṣ-ṣaḥīḥatu tuqawwī al-ʾinsāna.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1960,
    arabic: 'بَنَى الرَّجُلُ ثِقَةً بَيْنَ النَّاسِ.',
    german: 'Der Mann baute Vertrauen zwischen den Leuten auf.',
    transliteration: 'Banā ar-raǧulu ṯiqatan bayna an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 197 (word_ids 1961–1970): „Geschichte eines Soldaten".
/// Begeisterung, Wunden und Gewissheit auf dem Weg des Lebens.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetySevenStory = [
  Sentence(
    wordId: 1961,
    arabic: 'اِرْتَفَعَتْ حَمَاسَةُ الْجُمْهُورِ.',
    german: 'Die Begeisterung des Publikums stieg.',
    transliteration: 'Irtafaʿat ḥamāsatu al-ǧumhūri.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1962,
    arabic: 'بَلَغَ اِمْتِدَادُ الطَّرِيقِ عَشَرَةَ كِيلُومِتْرَاتٍ.',
    german: 'Die Ausdehnung der Straße betrug zehn Kilometer.',
    transliteration: 'Balaġa imtidādu aṭ-ṭarīqi ʿašarata kīlūmitrātin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1963,
    arabic: 'كَانَ جَرْحُ الْجُنْدِيِّ عَمِيقًا.',
    german: 'Die Wunde des Soldaten war tief.',
    transliteration: 'Kāna ǧarḥu al-ǧundiyyi ʿamīqan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1964,
    arabic: 'بَلَغَ عُمْرُ الْجَدِّ تِسْعِينَ سَنَةً.',
    german: 'Der Großvater wurde neunzig Jahre alt.',
    transliteration: 'Balaġa ʿumru al-ǧaddi tisʿīna sanatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1965,
    arabic: 'عَامَلَ الْمُعَلِّمُ الطُّلَّابَ بِلُطْفٍ.',
    german: 'Der Lehrer behandelte die Schüler mit Milde.',
    transliteration: 'ʿĀmala al-muʿallimu aṭ-ṭullāba bi-luṭfin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1966,
    arabic: 'نَجَحَتِ الْمُحَاوَلَةُ الْأُولَى.',
    german: 'Der erste Versuch gelang.',
    transliteration: 'Naǧaḥati al-muḥāwalatu al-ʾūlā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1967,
    arabic: 'كَانَ الْيَقِينُ فِي قَلْبِهِ قَوِيًّا.',
    german: 'Die Gewissheit in seinem Herzen war stark.',
    transliteration: 'Kāna al-yaqīnu fī qalbihī qawiyyan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1968,
    arabic: 'لِلْعُلَمَاءِ جَاهٌ كَبِيرٌ بَيْنَ النَّاسِ.',
    german: 'Die Gelehrten haben großes Ansehen unter den Leuten.',
    transliteration: 'Lil-ʿulamāʾi ǧāhun kabīrun bayna an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1969,
    arabic: 'رَبَطَ الْبَحَّارُ الْحَبْلَ بِعُقْدَةٍ قَوِيَّةٍ.',
    german: 'Der Seemann band das Seil mit einem starken Knoten.',
    transliteration: 'Rabaṭa al-baḥḥāru al-ḥabla bi-ʿuqdatin qawiyyatin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1970,
    arabic: 'شَرَحَ الْمُعَلِّمُ التَّفْصِيلَ بِوُضُوحٍ.',
    german: 'Der Lehrer erklärte das Detail klar.',
    transliteration: 'Šaraḥa al-muʿallimu at-tafṣīla bi-wuḍūḥin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 198 (word_ids 1971–1980): „Charakter und Tugend".
/// Verhalten, Rang und Tugenden im Bild eines guten Menschen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyEightStory = [
  Sentence(
    wordId: 1971,
    arabic: 'كَانَ سُلُوكُ الْوَلَدِ مُؤَدَّبًا.',
    german: 'Das Verhalten des Jungen war höflich.',
    transliteration: 'Kāna sulūku al-waladi muʾaddaban.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1972,
    arabic: 'أَحْبَبْتُ قِرَاءَةَ الْقُرْآنِ.',
    german: 'Ich liebte die Rezitation des Korans.',
    transliteration: 'ʾAḥbabtu qirāʾata al-qurʾāni.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1973,
    arabic: 'نَالَ الْجُنْدِيُّ رُتْبَةً عَالِيَةً.',
    german: 'Der Soldat erlangte einen hohen Rang.',
    transliteration: 'Nāla al-ǧundiyyu rutbatan ʿāliyatan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1974,
    arabic: 'اِرْتَفَعَتْ حَرَارَةُ الْجَوِّ فِي الصَّيْفِ.',
    german: 'Die Hitze des Wetters stieg im Sommer.',
    transliteration: 'Irtafaʿat ḥarāratu al-ǧawwi fī aṣ-ṣayfi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1975,
    arabic: 'يَمْلَأُ التَّفَاؤُلُ قَلْبَ الشَّبَابِ.',
    german: 'Der Optimismus erfüllt das Herz der Jugend.',
    transliteration: 'Yamlaʾu at-tafāʾulu qalba aš-šabābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1976,
    arabic: 'كَانَ الْقَاضِي عَادِلًا فِي حُكْمِهِ.',
    german: 'Der Richter war in seinem Urteil gerecht.',
    transliteration: 'Kāna al-qāḍī ʿādilan fī ḥukmihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1977,
    arabic: 'الْجُنْدِيُّ الْجَرِيءُ لَا يَخَافُ.',
    german: 'Der kühne Soldat fürchtet sich nicht.',
    transliteration: 'Al-ǧundiyyu al-ǧarīʾu lā yaḫāfu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1978,
    arabic: 'كَانَتِ الْأُمُّ صَبُورَةً مَعَ أَوْلَادِهَا.',
    german: 'Die Mutter war geduldig mit ihren Kindern.',
    transliteration: 'Kānati al-ʾummu ṣabūratan maʿa ʾawlādihā.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1979,
    arabic: 'الْعَامِلُ الشَّكُورُ يُحِبُّ عَمَلَهُ.',
    german: 'Der dankbare Arbeiter liebt seine Arbeit.',
    transliteration: 'Al-ʿāmilu aš-šakūru yuḥibbu ʿamalahū.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1980,
    arabic: 'الْأَرْضُ الْخَصِبَةُ تُعْطِي كَثِيرًا.',
    german: 'Die fruchtbare Erde gibt viel.',
    transliteration: 'Al-ʾarḍu al-ḫaṣibatu tuʿṭī kaṯīran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 199 (word_ids 1981–1990): „Eigenschaften der Menschen".
/// Genügsam, geduldig und bescheiden: Charaktere in kleinen Szenen.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonHundredNinetyNineStory = [
  Sentence(
    wordId: 1981,
    arabic: 'كَانَ الْجَدُّ قَنُوعًا بِقَلِيلٍ.',
    german: 'Der Großvater war mit wenig genügsam.',
    transliteration: 'Kāna al-ǧaddu qanūʿan bi-qalīlin.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1982,
    arabic: 'كَانَ الطَّرِيقُ عَسِرًا فِي الشِّتَاءِ.',
    german: 'Der Weg war im Winter schwierig.',
    transliteration: 'Kāna aṭ-ṭarīqu ʿasiran fī aš-šitāʾi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1983,
    arabic: 'الطُّلَّابُ مُتَحَمِّسُونَ لِلرِّحْلَةِ.',
    german: 'Die Schüler sind für die Reise begeistert.',
    transliteration: 'Aṭ-ṭullābu mutaḥammisūna lir-riḥlati.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1984,
    arabic: 'كَانَ الْمُدِيرُ مُتَوَاضِعًا مَعَ الْجَمِيعِ.',
    german: 'Der Leiter war bescheiden mit allen.',
    transliteration: 'Kāna al-mudīru mutawāḍiʿan maʿa al-ǧamīʿi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1985,
    arabic: 'الرَّجُلُ الْحَسُودُ لَا يَسْعَدُ.',
    german: 'Der neidische Mann ist nicht glücklich.',
    transliteration: 'Ar-raǧulu al-ḥasūdu lā yasʿadu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1986,
    arabic: 'الطَّالِبُ الْكَسُولُ يَخْسَرُ الْعَامَ.',
    german: 'Der faule Schüler verliert das Jahr.',
    transliteration: 'Aṭ-ṭālibu al-kasūlu yaḫsaru al-ʿāma.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1987,
    arabic: 'كَانَ صَبَاحُ الْعِيدِ بَهِيجًا.',
    german: 'Der Morgen des Festes war fröhlich.',
    transliteration: 'Kāna ṣabāḥu al-ʿīdi bahīǧan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1988,
    arabic: 'كَانَ الطِّفْلُ ظَرِيفًا فِي كَلَامِهِ.',
    german: 'Das Kind war in seiner Rede witzig.',
    transliteration: 'Kāna aṭ-ṭiflu ẓarīfan fī kalāmihī.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1989,
    arabic: 'كَانَ الْبَيْتُ رَحِيبًا وَجَمِيلًا.',
    german: 'Das Haus war weit und schön.',
    transliteration: 'Kāna al-baytu raḥīban wa-ǧamīlan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1990,
    arabic: 'كَانَ الْأُسْتَاذُ بَصِيرًا بِأُمُورِ النَّاسِ.',
    german: 'Der Lehrer war einsichtig in den Angelegenheiten der Leute.',
    transliteration: 'Kāna al-ʾustāḏu baṣīran bi-ʾumūri an-nāsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];

/// Lektion 200 (word_ids 1991–2000): „Weisheit des Alltags".
/// Gastfreundschaft und viele kleine Wörter zum Abschluss.
/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.
final List<Sentence> _lessonTwoHundredStory = [
  Sentence(
    wordId: 1991,
    arabic: 'كَانَ الْمُضِيفُ مِضْيَافًا وَكَرِيمًا.',
    german: 'Der Gastgeber war gastfreundlich und großzügig.',
    transliteration: 'Kāna al-muḍīfu miḍyāfan wa-karīman.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1992,
    arabic: 'وَقَفَ الْحَارِسُ قُدَّامَ الْبَابِ.',
    german: 'Der Wächter stand vor der Tür.',
    transliteration: 'Waqafa al-ḥārisu quddāma al-bābi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1993,
    arabic: 'اِسْتَيْقَظَ الْفَلَّاحُ بَاكِرًا فِي الصَّبَاحِ.',
    german: 'Der Bauer wachte früh am Morgen auf.',
    transliteration: 'Istayqaẓa al-fallāḥu bākiran fī aṣ-ṣabāḥi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1994,
    arabic: 'أَعْلَنَ الْمُدِيرُ الْخَبَرَ عِلَانًا.',
    german: 'Der Leiter gab die Nachricht öffentlich bekannt.',
    transliteration: 'ʾAʿlana al-mudīru al-ḫabara ʿilānan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1995,
    arabic: 'تَحَدَّثَ الرَّجُلَانِ سِرًّا.',
    german: 'Die beiden Männer sprachen heimlich.',
    transliteration: 'Taḥaddaṯa ar-raǧulāni sirran.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1996,
    arabic: 'هُنَاكَ حَدِيقَةٌ جَمِيلَةٌ قُرْبَ الْبَيْتِ.',
    german: 'Dort ist ein schöner Garten nahe dem Haus.',
    transliteration: 'Hunāka ḥadīqatun ǧamīlatun qurba al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1997,
    arabic: 'رُبَّمَا يَأْتِي الْمَطَرُ غَدًا.',
    german: 'Vielleicht kommt morgen der Regen.',
    transliteration: 'Rubbamā yaʾtī al-maṭaru ġadan.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1998,
    arabic: 'سَأَعُودُ عَاجِلًا إِلَى الْبَيْتِ.',
    german: 'Ich kehre bald nach Hause zurück.',
    transliteration: 'Saʾaʿūdu ʿāǧilan ʾilā al-bayti.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 1999,
    arabic: 'نَامَ الْوَلَدُ أَثْنَاءَ الدَّرْسِ.',
    german: 'Das Kind schlief während der Lektion ein.',
    transliteration: 'Nāma al-waladu aṯnāʾa ad-darsi.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
  Sentence(
    wordId: 2000,
    arabic: 'رُغْمَ الْمَطَرِ خَرَجَ النَّاسُ.',
    german: 'Trotz des Regens gingen die Leute hinaus.',
    transliteration: 'Ruġma al-maṭari ḫaraǧa an-nāsu.',
    wordAnalysis: [],
    targetIndex: 0,
  ),
];
