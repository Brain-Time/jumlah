import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/audio_service.dart';
import '../../core/widgets/animated_progress_bar.dart';
import '../../core/widgets/flip_card.dart';
import '../../core/word_groups.dart' show showsTransliteration;
import '../../models/root.dart';
import '../../models/sentence.dart';
import '../../models/word.dart';
import '../../providers/learn_provider.dart';
import '../info/transliteration_info_screen.dart';
import '../quiz/quiz_screen.dart';
import 'analysis_widget.dart';

/// Lern-Ansicht für einen 10-Wörter-Batch (Task C1). Zeigt das arabische
/// Wort, die deutsche Übersetzung, den Kontext-Satz mit Wort-für-Wort-
/// Analyse sowie die klassische Wurzel-Definition (Hybrid-Ansatz, Task A3).
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key, required this.group, this.batchIndex = 0});

  final String group;
  final int batchIndex;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(learnProvider.notifier)
          .loadBatch(widget.group, widget.batchIndex),
    );
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Von vorne beginnen?'),
        content: const Text(
          'Der gespeicherte Zwischenstand dieser Lektion geht verloren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Neu starten'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(learnProvider.notifier).restartBatch();
  }

  void _openQuiz(LearnState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: state.words,
          sentencesByWordId: state.sentencesByWordId,
          group: widget.group,
          batchIndex: widget.batchIndex,
          isLastBatch: state.isLastBatch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learnProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Lernen · ${widget.group}'),
        actions: [
          if (showsTransliteration(widget.group))
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Transliteration erklärt',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TransliterationInfoScreen(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Von vorne beginnen',
            onPressed: _confirmRestart,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(state)),
    );
  }

  Widget _buildBody(LearnState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Fehler beim Laden: ${state.errorMessage}',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (state.words.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Keine Wörter in dieser Gruppe gefunden.\n'
            '(words.json muss zuerst importiert werden — Task D1)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final word = state.currentWord!;
    final sentences = state.currentSentences;
    final root = state.currentRoot;
    final notifier = ref.read(learnProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedProgressBar(value: state.progress),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Lektion ${widget.batchIndex + 1}',
                style: AppTheme.secondaryStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${state.currentIndex + 1} / ${state.words.length}',
                style: AppTheme.titleStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WordCard(word: word, showTransliteration: showsTransliteration(widget.group)),
                  const SizedBox(height: 20),
                  _SentenceSection(
                    sentences: sentences,
                    expanded: state.showAnalysis,
                    onTap: notifier.toggleAnalysis,
                    showTransliteration: showsTransliteration(widget.group),
                  ),
                  const SizedBox(height: 24),
                  _RootSection(root: root),
                  if (word.masdar.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MasdarSection(
                      word: word,
                      showTransliteration: showsTransliteration(widget.group),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.hasPrevious ? notifier.prevWord : null,
                  child: const Text('Zurück'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: state.hasNext
                    ? FilledButton(
                        onPressed: notifier.nextWord,
                        child: const Text('Weiter'),
                      )
                    : FilledButton(
                        onPressed: () => _openQuiz(state),
                        child: const Text('Zum Quiz'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentenceSection extends StatelessWidget {
  const _SentenceSection({
    required this.sentences,
    required this.expanded,
    required this.onTap,
    required this.showTransliteration,
  });

  final List<Sentence> sentences;
  final bool expanded;
  final VoidCallback onTap;
  final bool showTransliteration;

  @override
  Widget build(BuildContext context) {
    if (sentences.isEmpty) {
      return const Text(
        'Für dieses Wort ist noch kein Kontext-Satz verfügbar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < sentences.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _SingleSentence(
            index: i + 1,
            total: sentences.length,
            sentence: sentences[i],
            sentenceIndex: i,
            expanded: expanded,
            onTap: onTap,
            showTransliteration: showTransliteration,
          ),
        ],
      ],
    );
  }
}

class _SingleSentence extends StatelessWidget {
  const _SingleSentence({
    required this.index,
    required this.total,
    required this.sentence,
    required this.sentenceIndex,
    required this.expanded,
    required this.onTap,
    required this.showTransliteration,
  });

  final int index;
  final int total;
  final Sentence sentence;
  final int sentenceIndex;
  final bool expanded;
  final VoidCallback onTap;
  final bool showTransliteration;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (total > 1)
              Text(
                'Satz $index/$total',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            const SizedBox(width: 8),
            _SentenceAudioButton(
              sentence: sentence,
              sentenceIndex: sentenceIndex,
            ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              sentence.arabic,
              textAlign: TextAlign.center,
              style: AppTheme.arabicTextStyle(
                fontSize: 22,
                color: AppColors.gold,
              ),
            ),
          ),
        ),
        if (showTransliteration && sentence.transliteration.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sentence.transliteration,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          sentence.german,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
        AnalysisWidget(sentence: sentence, expanded: expanded),
      ],
    );
  }
}

/// Play-/Stop-Schalter für den Kontext-Satz eines Worts. Hört auf den
/// zentralen [AudioService] (ChangeNotifier): das Icon zeigt genau dann "Stop",
/// wenn dieser Satz aktuell abgespielt wird, und springt automatisch zurück auf
/// "Play", sobald die Wiedergabe (auch von selbst) endet.
class _SentenceAudioButton extends StatelessWidget {
  const _SentenceAudioButton({
    required this.sentence,
    required this.sentenceIndex,
  });

  final Sentence sentence;
  final int sentenceIndex;

  Future<void> _toggle() async {
    final service = AudioService.instance;
    if (service.isPlaying(sentence, sentenceIndex)) {
      await service.stop();
    } else {
      await service.playSentence(sentence, sentenceIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = AudioService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final isPlaying = service.isPlaying(sentence, sentenceIndex);
        return InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              isPlaying ? Icons.stop_circle : Icons.play_circle,
              color: AppColors.gold,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

class _RootSection extends StatelessWidget {
  const _RootSection({required this.root});

  final WordRoot? root;

  @override
  Widget build(BuildContext context) {
    final root = this.root;
    if (root == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  root.root,
                  style: AppTheme.arabicTextStyle(
                    fontSize: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Wurzel',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            root.classicalDefinition,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _MasdarSection extends StatelessWidget {
  const _MasdarSection({required this.word, required this.showTransliteration});

  final Word word;
  final bool showTransliteration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  word.masdar,
                  style: AppTheme.arabicTextStyle(
                    fontSize: 20,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Masdar (Verbalnomen)',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          if (showTransliteration && word.masdarTransliteration.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              word.masdarTransliteration,
              style: const TextStyle(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (word.masdarGerman.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              word.masdarGerman,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}
/// Die zentrale Vokabel-Karte der Lern-Ansicht (Task UI-1): eingebettet in
/// eine gestylte Oberfläche mit Border/Schatten und Akzent-Background —
/// deutlicher Fokus auf das arabische Wort statt eine flache, konturlose
/// Zeile. Die `FlipCard`-Drehung (Task E1) beim Wortwechsel bleibt erhalten.
class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.showTransliteration});

  final Word word;
  final bool showTransliteration;

  @override
  Widget build(BuildContext context) {
    return FlipCard(
      itemKey: word.id,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: AppTheme.cardDecoration(
          color: AppColors.surfaceElevated,
          borderColor: AppColors.border,
        ),
        child: Column(
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                word.arabic,
                style: AppTheme.arabicTextStyle(fontSize: 52),
                textAlign: TextAlign.center,
              ),
            ),
            if (showTransliteration && word.transliteration.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                word.transliteration,
                textAlign: TextAlign.center,
                style: AppTheme.secondaryStyle(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                word.german,
                textAlign: TextAlign.center,
                style: AppTheme.bodyStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
