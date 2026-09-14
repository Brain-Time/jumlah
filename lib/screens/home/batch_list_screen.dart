import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/word_groups.dart'
    show groupTitleHeroTag, learnBatchSize;
import '../../models/sentence.dart';
import '../../models/word.dart';
import '../../providers/learn_provider.dart' show sentencesForWords;
import '../learn/learn_screen.dart';
import '../quiz/group_complete_screen.dart';
import '../quiz/quiz_screen.dart';

enum BatchListMode { learn, quiz }

/// Liste der 10er-Batches eines Sprachniveaus (sequenzielle Freischaltung):
/// Batch 0 ist immer offen, Batch N erst nach fehlerfreiem Bestehen von
/// Batch N-1 (siehe `DatabaseHelper.getPassedBatchIndexes`/`markBatchPassed`).
/// Alle Lektionen einer **freigeschalteten** Stufe sind frei spielbar; die
/// Stufe selbst wird seit 10. September 2026 nicht mehr gekauft, sondern
/// durch Abschluss der vorherigen freigeschaltet
/// (`DatabaseHelper.getUnlockedLevels` — Einstiegs-Stufe A1 ist immer frei).
/// Im Quiz-Modus gilt zusätzlich eine Sicherheitsregel: ein Batch ist erst
/// spielbar, wenn sein Lernpfad einmal vollständig durchlaufen wurde
/// (`getLearnedBatchIndexes`/`markBatchLearned`) — Quiz vor Lernen ist nicht
/// möglich. Sind alle Batches bestanden, erscheint zusätzlich ein Zugang zur
/// Gesamtprüfung (`GroupCompleteScreen`). Gemeinsam von Learn- und Quiz-Tab
/// genutzt (`mode` steuert das Ziel-Screen).
class BatchListScreen extends StatefulWidget {
  const BatchListScreen({
    super.key,
    required this.group,
    required this.mode,
  });

  final String group;
  final BatchListMode mode;

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  List<Word> _words = const [];
  Map<int, List<Sentence>> _sentences = const {};
  Set<int> _passedBatches = const {};
  Set<int> _learnedBatches = const {};
  Set<String> _unlockedLevels = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _batchCount => (_words.length / learnBatchSize).ceil();

  /// Erste sichtbare Lektions-Nummer (ganzes Sprachniveau).
  int get _firstBatch => 0;

  /// Letzte sichtbare Lektions-Nummer, gedeckelt auf die tatsächliche
  /// Lektionsanzahl des Sprachniveaus.
  int get _lastBatch => _batchCount - 1;

  Future<void> _load() async {
    setState(() => _loading = true);
    final words = await DatabaseHelper.instance.getWordsByGroup(widget.group);
    final sentences = widget.mode == BatchListMode.quiz
        ? await sentencesForWords(words)
        : const <int, List<Sentence>>{};
    final passed = await DatabaseHelper.instance.getPassedBatchIndexes(
      widget.group,
    );
    final learned = await DatabaseHelper.instance.getLearnedBatchIndexes(
      widget.group,
    );
    final unlockedLevels = await DatabaseHelper.instance.getUnlockedLevels();
    if (!mounted) {
      return;
    }
    setState(() {
      _words = words;
      _sentences = sentences;
      _passedBatches = passed;
      _learnedBatches = learned;
      _unlockedLevels = unlockedLevels;
      _loading = false;
    });
  }

  /// Ob das Sprachniveau als Ganzes freigeschaltet ist (Einstiegs-Stufe A1
  /// immer; weitere Stufen nach Abschluss der vorherigen — siehe
  /// `DatabaseHelper.getUnlockedLevels`).
  bool get _levelUnlocked => _unlockedLevels.contains(widget.group);

  /// Lektion [index] ist im Lern-Modus offen, sobald der vorherige Batch
  /// bestanden ist und das Sprachniveau freigeschaltet ist. Im Quiz-Modus
  /// zusätzlich nur, wenn der Lernpfad dieser Lektion selbst schon einmal
  /// vollständig durchlaufen wurde (Sicherheitsregel: kein Quiz vor
  /// abgeschlossenem Lernen).
  bool _prevPassed(int index) =>
      index == _firstBatch || _passedBatches.contains(index - 1);

  /// Lektion [index] ist (vollständig) spielbar: freigeschaltetes
  /// Sprachniveau, plus die üblichen Batch-Vorgänger-/Lernpfad-Regeln.
  bool _isUnlocked(int index) {
    final prevPassed = _prevPassed(index);
    if (widget.mode == BatchListMode.learn) {
      return _levelUnlocked && prevPassed;
    }
    return _levelUnlocked && prevPassed && _learnedBatches.contains(index);
  }

  Future<void> _openBatch(int batchIndex) async {
    final start = batchIndex * learnBatchSize;
    final end = (start + learnBatchSize).clamp(0, _words.length);
    final batchWords = _words.sublist(start, end);
    final isLastBatch = batchIndex == _batchCount - 1;

    if (widget.mode == BatchListMode.learn) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              LearnScreen(group: widget.group, batchIndex: batchIndex),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            words: batchWords,
            sentencesByWordId: _sentences,
            group: widget.group,
            batchIndex: batchIndex,
            isLastBatch: isLastBatch,
          ),
        ),
      );
    }
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _openGroupComplete() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupCompleteScreen(group: widget.group),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  void _showLockedHint(int index) {
    late final String message;
    if (!_levelUnlocked) {
      message = 'Schließe zuerst das vorherige Sprachniveau ab, um dieses '
          'freizuschalten.';
    } else if (!_prevPassed(index)) {
      message =
          'Erst die vorherige Lektion fehlerfrei bestehen, um diese '
          'freizuschalten.';
    } else {
      message = 'Zuerst diese Lektion lernen, bevor du das Quiz machst.';
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isQuiz = widget.mode == BatchListMode.quiz;
    final title = isQuiz ? 'Quiz' : 'Lernen';
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: groupTitleHeroTag(widget.group, isQuiz: isQuiz),
          child: Material(
            type: MaterialType.transparency,
            child: Text('$title · ${_appBarSubtitle()}'),
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  String _appBarSubtitle() => widget.group;

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Keine Wörter in dieser Gruppe gefunden.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Gesamtprüfung über das ganze Sprachniveau anbieten, wenn alle Lektionen
    // bestanden sind.
    final groupComplete = _passedBatches.length >= _batchCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (groupComplete)
          Card(
            color: AppColors.gold.withValues(alpha: 0.12),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: _openGroupComplete,
              leading: const Icon(Icons.emoji_events, color: AppColors.gold),
              title: const Text(
                'Gesamtprüfung',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
          ),
        for (var index = _firstBatch; index <= _lastBatch; index++)
          _BatchTile(
            index: index,
            start: index * learnBatchSize + 1,
            end: ((index + 1) * learnBatchSize).clamp(0, _words.length),
            unlocked: _isUnlocked(index),
            passed: _passedBatches.contains(index),
            onTap: () => _openBatch(index),
            onLockedTap: () => _showLockedHint(index),
          ),
      ],
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({
    required this.index,
    required this.start,
    required this.end,
    required this.unlocked,
    required this.passed,
    required this.onTap,
    required this.onLockedTap,
  });

  final int index;
  final int start;
  final int end;
  final bool unlocked;
  final bool passed;
  final VoidCallback onTap;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: unlocked ? onTap : onLockedTap,
        title: Text(
          'Lektion ${index + 1} · Wörter $start–$end',
          style: const TextStyle(color: Colors.white),
        ),
        trailing: Icon(
          passed
              ? Icons.check_circle
              : unlocked
              ? Icons.chevron_right
              : Icons.lock,
          color: passed ? AppColors.success : Colors.white38,
        ),
      ),
    );
  }
}
