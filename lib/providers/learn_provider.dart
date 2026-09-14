import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_helper.dart';
import '../core/word_groups.dart' show learnBatchSize;
import '../models/root.dart';
import '../models/sentence.dart';
import '../models/word.dart';

export '../core/word_groups.dart' show learnBatchSize;

/// Zustand eines Lern-Batches: 10 Wörter einer Gruppe, mit optionalem
/// Kontext-Satz (sentences.json, Task A2) und optionaler klassischer
/// Wurzel-Definition (roots.json, Task A3 — Hybrid-Ansatz).
class LearnState {
  const LearnState({
    this.group,
    this.batchIndex = 0,
    this.words = const [],
    this.currentIndex = 0,
    this.showAnalysis = false,
    this.sentencesByWordId = const {},
    this.rootsByRoot = const {},
    this.isLastBatch = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final String? group;
  final int batchIndex;
  final List<Word> words;
  final int currentIndex;
  final bool showAnalysis;
  final Map<int, List<Sentence>> sentencesByWordId;
  final Map<String, WordRoot> rootsByRoot;

  /// Ob dies der letzte Batch der Gruppe ist — steuert, ob nach dem Quiz
  /// dieses Batches die Gesamtprüfung statt der nächsten Lektion angeboten
  /// wird (siehe `QuizScreen`/`GroupCompleteScreen`).
  final bool isLastBatch;
  final bool isLoading;
  final String? errorMessage;

  Word? get currentWord => words.isEmpty ? null : words[currentIndex];

  /// Alle Kontext-Sätze für das aktuelle Wort (Task A2: bis zu 3 je Wort).
  List<Sentence> get currentSentences {
    final word = currentWord;
    return word == null ? const [] : sentencesByWordId[word.id] ?? const [];
  }

  /// Erster Kontext-Satz für das aktuelle Wort, für die Einzel-Satz-Ansicht.
  Sentence? get currentSentence =>
      currentSentences.isEmpty ? null : currentSentences.first;

  WordRoot? get currentRoot {
    final word = currentWord;
    return word == null ? null : rootsByRoot[word.root];
  }

  bool get hasNext => currentIndex < words.length - 1;
  bool get hasPrevious => currentIndex > 0;

  /// Fortschritt innerhalb des Batches, 0.0–1.0.
  double get progress => words.isEmpty ? 0 : (currentIndex + 1) / words.length;

  LearnState copyWith({
    String? group,
    int? batchIndex,
    List<Word>? words,
    int? currentIndex,
    bool? showAnalysis,
    Map<int, List<Sentence>>? sentencesByWordId,
    Map<String, WordRoot>? rootsByRoot,
    bool? isLastBatch,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LearnState(
      group: group ?? this.group,
      batchIndex: batchIndex ?? this.batchIndex,
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      showAnalysis: showAnalysis ?? this.showAnalysis,
      sentencesByWordId: sentencesByWordId ?? this.sentencesByWordId,
      rootsByRoot: rootsByRoot ?? this.rootsByRoot,
      isLastBatch: isLastBatch ?? this.isLastBatch,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class LearnNotifier extends Notifier<LearnState> {
  @override
  LearnState build() => const LearnState();

  /// Lädt Batch [batchIndex] (0-basiert, je [learnBatchSize] Wörter) der
  /// Gruppe [group] aus der SQLite-DB (Task B2) sowie die passenden
  /// Kontext-Sätze und Wurzel-Definitionen aus den JSON-Assets. Setzt
  /// fort beim zuletzt angesehenen Wort dieses Batches, sofern vorhanden
  /// (`DatabaseHelper.getLearnPosition`) — siehe [restartBatch] für die
  /// Option, stattdessen von vorne zu beginnen.
  Future<void> loadBatch(String group, int batchIndex) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final allWords = await DatabaseHelper.instance.getWordsByGroup(group);
      final start = (batchIndex * learnBatchSize).clamp(0, allWords.length);
      final end = (start + learnBatchSize).clamp(0, allWords.length);
      final batchWords = allWords.sublist(start, end);
      final isLastBatch = end >= allWords.length;

      final sentences = await sentencesForWords(batchWords);
      final roots = await _rootsFor(batchWords);
      final savedIndex = await DatabaseHelper.instance.getLearnPosition(
        group,
        batchIndex,
      );
      final currentIndex = (savedIndex != null && batchWords.isNotEmpty)
          ? savedIndex.clamp(0, batchWords.length - 1)
          : 0;

      state = LearnState(
        group: group,
        batchIndex: batchIndex,
        words: batchWords,
        currentIndex: currentIndex,
        sentencesByWordId: sentences,
        rootsByRoot: roots,
        isLastBatch: isLastBatch,
      );
      await _markLearnedIfLastWordReached();
      // Lernstatistik (Task: Heatmap/Streak): das Öffnen/Verlassen einer
      // Lektion zählt bereits als Aktivität für den heutigen Tag.
      await DatabaseHelper.instance.trackStudyActivity(wordsViewed: 1);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  /// Setzt den Batch auf das erste Wort zurück und löscht den gespeicherten
  /// Zwischenstand — für Nutzer, die bewusst von vorne beginnen möchten,
  /// statt automatisch beim zuletzt angesehenen Wort fortzusetzen.
  Future<void> restartBatch() async {
    final group = state.group;
    state = state.copyWith(currentIndex: 0, showAnalysis: false);
    if (group != null) {
      await DatabaseHelper.instance.clearLearnPosition(
        group,
        state.batchIndex,
      );
    }
  }

  void nextWord() {
    if (!state.hasNext) {
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      showAnalysis: false,
    );
    _persistPosition();
    _markLearnedIfLastWordReached();
  }

  /// Schreibt den aktuellen Wort-Index fire-and-forget nach SQLite, damit
  /// ein Wiedereinstieg (App-Neustart, Zurück-Navigation) genau hier
  /// fortsetzt statt wieder bei Wort 1 zu beginnen.
  void _persistPosition() {
    final group = state.group;
    if (group == null) {
      return;
    }
    DatabaseHelper.instance.saveLearnPosition(
      group,
      state.batchIndex,
      state.currentIndex,
    );
    // Lernstatistik (Task: Heatmap/Streak): jeder Wortwechsel zählt als
    // Aktivität für den heutigen Tag (fire-and-forget, wie saveLearnPosition).
    DatabaseHelper.instance.trackStudyActivity(wordsViewed: 1);
  }

  /// Markiert den aktuellen Batch als gelernt (Sicherheits-Voraussetzung
  /// fürs Quiz, siehe `DatabaseHelper.markBatchLearned`), sobald das letzte
  /// Wort des Batches erreicht ist — sowohl beim Laden eines Ein-Wort-Batches
  /// als auch beim Weiterblättern zum letzten Wort.
  Future<void> _markLearnedIfLastWordReached() async {
    final group = state.group;
    if (group == null || state.words.isEmpty) {
      return;
    }
    if (state.currentIndex == state.words.length - 1) {
      await DatabaseHelper.instance.markBatchLearned(group, state.batchIndex);
    }
  }

  void prevWord() {
    if (!state.hasPrevious) {
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      showAnalysis: false,
    );
    _persistPosition();
  }

  void toggleAnalysis() {
    state = state.copyWith(showAnalysis: !state.showAnalysis);
  }

  Future<Map<String, WordRoot>> _rootsFor(List<Word> words) async {
    if (words.isEmpty) {
      return const {};
    }
    final rootKeys = words.map((w) => w.root).toSet();
    return DatabaseHelper.instance.getRootsByKeys(rootKeys);
  }
}

/// Alle Kontext-Sätze für [words], gruppiert nach word_id. Wiederverwendet
/// von `LearnNotifier`, `BatchListScreen` und `GroupCompleteScreen` — überall
/// dort, wo Sätze für eine Wortliste fürs Quiz (Satz-Lückentext-Stufe) oder
/// die Lern-Ansicht gebraucht werden. Liest aus der `sentences`-Tabelle
/// (Task D1) statt direkt aus den JSON-Assets.
Future<Map<int, List<Sentence>>> sentencesForWords(List<Word> words) async {
  if (words.isEmpty) {
    return const {};
  }
  final ids = words.map((w) => w.id).toSet();
  return DatabaseHelper.instance.getSentencesByWordIds(ids);
}

final learnProvider = NotifierProvider<LearnNotifier, LearnState>(
  LearnNotifier.new,
);
