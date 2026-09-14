import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sentence.dart';
import '../../models/word.dart';
import '../../providers/learn_provider.dart' show sentencesForWords;
import '../../providers/quiz_provider.dart';
import 'quiz_screen.dart';

/// Erscheint, nachdem der letzte Batch einer Gruppe fehlerfrei bestanden
/// wurde: bietet zunächst eine Gesamtprüfung über alle Wörter der Gruppe an,
/// nach deren Bestehen einen Hinweis, dass die nächste Stufe freigeschaltet
/// ist (Abschluss-Freischaltung, keine Käufe mehr — 10. September 2026).
class GroupCompleteScreen extends ConsumerStatefulWidget {
  const GroupCompleteScreen({super.key, required this.group});

  final String group;

  @override
  ConsumerState<GroupCompleteScreen> createState() =>
      _GroupCompleteScreenState();
}

class _GroupCompleteScreenState extends ConsumerState<GroupCompleteScreen> {
  List<Word> _words = const [];
  Map<int, List<Sentence>> _sentences = const {};
  bool _loading = true;
  bool? _finalExamPassed;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final words = await DatabaseHelper.instance.getWordsByGroup(widget.group);
    final sentences = await sentencesForWords(words);
    if (!mounted) {
      return;
    }
    setState(() {
      _words = words;
      _sentences = sentences;
      _loading = false;
    });
  }

  Future<void> _startFinalExam() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: _words,
          sentencesByWordId: _sentences,
          group: widget.group,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _finalExamPassed = ref.read(quizProvider).passed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.group} abgeschlossen')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _finalExamPassed == true
              ? const _UnlockNextGroupPrompt()
              : _FinalExamPrompt(
                  attemptFailed: _finalExamPassed == false,
                  onStart: _startFinalExam,
                ),
        ),
      ),
    );
  }
}

class _FinalExamPrompt extends StatelessWidget {
  const _FinalExamPrompt({required this.attemptFailed, required this.onStart});

  final bool attemptFailed;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emoji_events, color: AppColors.gold, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Alle Lektionen geschafft!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          attemptFailed
              ? 'Die Gesamtprüfung war noch nicht fehlerfrei — versuch es nochmal.'
              : 'Zum Abschluss folgt eine Gesamtprüfung über alle Wörter dieser Gruppe.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onStart,
          child: const Text('Gesamtprüfung starten'),
        ),
      ],
    );
  }
}

class _UnlockNextGroupPrompt extends StatelessWidget {
  const _UnlockNextGroupPrompt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.workspace_premium,
          color: AppColors.success,
          size: 64,
        ),
        const SizedBox(height: 16),
        const Text(
          'Gesamtprüfung bestanden!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Das Sprachniveau ist abgeschlossen — die nächste Stufe ist '
          'freigeschaltet. Weitere Stufen folgen, sobald ihre Inhalte '
          'verfügbar sind.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Zur Lektionsübersicht'),
        ),
      ],
    );
  }
}
