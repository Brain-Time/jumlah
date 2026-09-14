import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_progress_bar.dart';
import '../../core/word_groups.dart' show showsTransliteration;
import '../../models/sentence.dart';
import '../../models/word.dart';
import '../../providers/quiz_provider.dart';
import '../learn/learn_screen.dart';
import 'group_complete_screen.dart';
import 'result_screen.dart';

/// Quiz-Ansicht für einen Wort-Batch — „Schulprüfung“ (Nutzer-Vorgabe,
/// 29. August 2026): 6 Stufen (AR→DE, DE→AR, abwechselnd, Sätze abwechselnd,
/// Audio→Deutsch, Geschichte). Es gibt **kein** Sofort-Feedback — der Nutzer
/// klickt sich still durch, erst am Ende erscheint das Gesamtergebnis.
/// Bestanden bei ≤ [maxAllowedErrors] Fehlern. [group]/[batchIndex] aktivieren
/// das Freischalt-Tracking; ohne sie (z.B. Gesamtprüfung) bleibt der Lauf
/// ungetrackt.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    super.key,
    required this.words,
    this.sentencesByWordId = const {},
    this.group,
    this.batchIndex,
    this.isLastBatch = false,
  });

  final List<Word> words;
  final Map<int, List<Sentence>> sentencesByWordId;
  final String? group;
  final int? batchIndex;
  final bool isLastBatch;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  String? _selectedOption;

  /// Stufe 6 (Geschichte) läuft in zwei Phasen: zuerst wird die ganze
  /// Geschichte gelesen (Lese-Phase, `_storyIntroShown == false`), danach
  /// folgen die Zuordnungs-Fragen pro Satz.
  bool _storyIntroShown = false;

  @override
  void initState() {
    super.initState();
    // Deferred, damit der Provider-State nicht waehrend der ersten
    // Widget-Baumerstellung veraendert wird (Riverpod verbietet das).
    Future.microtask(_startQuiz);
  }

  void _startQuiz() {
    final group = widget.group;
    final batchIndex = widget.batchIndex;
    final notifier = ref.read(quizProvider.notifier);
    if (group != null && batchIndex != null) {
      // Getrackter Batch -> evtl. unterbrochene Sitzung fortsetzen statt
      // Fehlversuche durch einen App-Neustart verlieren zu lassen (G3).
      notifier.startOrResumeQuiz(
        widget.words,
        sentencesByWordId: widget.sentencesByWordId,
        group: group,
        batchIndex: batchIndex,
        isLastBatch: widget.isLastBatch,
      );
    } else {
      notifier.startQuiz(
        widget.words,
        sentencesByWordId: widget.sentencesByWordId,
        group: group,
        batchIndex: batchIndex,
        isLastBatch: widget.isLastBatch,
      );
    }
  }

  void _selectOption(String option) {
    setState(() => _selectedOption = option);
    ref.read(quizProvider.notifier).submitAnswer(option);
  }

  void _next() {
    setState(() => _selectedOption = null);
    ref.read(quizProvider.notifier).nextQuestion();
  }

  void _repeat() {
    setState(() => _selectedOption = null);
    _startQuiz();
    Navigator.of(context).pop();
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Von vorne beginnen?'),
        content: const Text(
          'Der bisherige Fortschritt in diesem Quiz geht verloren.',
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
    setState(() => _selectedOption = null);
    ref
        .read(quizProvider.notifier)
        .restartQuiz(
          widget.words,
          sentencesByWordId: widget.sentencesByWordId,
          group: widget.group,
          batchIndex: widget.batchIndex,
          isLastBatch: widget.isLastBatch,
        );
  }

  String _stageLabel(QuizStage stage) {
    switch (stage) {
      case QuizStage.arabicToGerman:
        return 'Stufe 1/6 · Arabisch → Deutsch';
      case QuizStage.germanToArabic:
        return 'Stufe 2/6 · Deutsch → Arabisch';
      case QuizStage.mixed:
        return 'Stufe 3/6 · Abwechselnd';
      case QuizStage.wholeSentence:
        return 'Stufe 4/6 · Sätze';
      case QuizStage.audio:
        return 'Stufe 5/6 · Audio';
      case QuizStage.story:
        return 'Stufe 6/6 · Geschichte';
    }
  }

  void _onContinueAfterGroupComplete() {
    final navigator = Navigator.of(context);
    navigator.pop(); // ResultScreen
    navigator.pop(); // QuizScreen
    final group = widget.group;
    if (group != null) {
      navigator.push(
        MaterialPageRoute(builder: (_) => GroupCompleteScreen(group: group)),
      );
    }
  }

  /// Nutzer-Vorgabe: nach fehlerfrei bestandener, getrackter Lektion (aber
  /// noch nicht der letzten der Gruppe) geht es direkt in die nächste
  /// Lektion weiter, statt zurück zur Lektions-Übersicht — durchgängiger
  /// Lektion→Quiz→Lektion-Fluss.
  void _onContinueToNextLesson() {
    final navigator = Navigator.of(context);
    navigator.pop(); // ResultScreen
    navigator.pop(); // QuizScreen
    final group = widget.group;
    final batchIndex = widget.batchIndex;
    if (group != null && batchIndex != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              LearnScreen(group: group, batchIndex: batchIndex + 1),
        ),
      );
    }
  }

  /// Seit der Umstellung auf die „Schulprüfung“ gibt es keinen
  /// Leseverständnis-Zwischenschritt mehr zwischen den Stufen — der Nutzer
  /// klickt alle 6 Stufen durch. Am Ende (isFinished) wird nur noch das
  /// Gesamtergebnis angezeigt. Beim Eintritt in die Geschichten-Stufe wird
  /// die Lese-Phase (gesamte Geschichte) zurückgesetzt/aktiviert.
  void _handleStateChange(QuizState? previous, QuizState next) {
    final enteredStory =
        next.stage == QuizStage.story && previous?.stage != QuizStage.story;
    if (enteredStory) {
      if (_storyIntroShown) {
        setState(() => _storyIntroShown = false);
      }
      return;
    }
    final justFinished = next.isFinished && previous?.isFinished != true;
    if (!justFinished) {
      return;
    }
    _pushResult(next);
  }

  void _pushResult(QuizState next) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: next.score,
          totalWords: next.words.length,
          wrongCount: next.wrongCount,
          allowedErrors: maxAllowedErrors,
          wrongWords: next.wrongWords,
          passed: next.passed,
          isTrackedBatch: next.group != null && next.batchIndex != null,
          onRepeat: _repeat,
          onContinue: next.groupNowComplete
              ? _onContinueAfterGroupComplete
              : (next.passed == true &&
                    next.group != null &&
                    next.batchIndex != null)
              ? _onContinueToNextLesson
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizProvider);

    ref.listen(quizProvider, _handleStateChange);

    return Scaffold(
      appBar: AppBar(
        title: Text(_stageLabel(state.stage)),
        actions: [
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

  Widget _buildBody(QuizState state) {
    // Geschichten-Stufe, Lese-Phase: erst die ganze Geschichte lesen, dann
    // erst zur Zuordnung (Nutzer-Vorgabe).
    if (state.stage == QuizStage.story &&
        !_storyIntroShown &&
        state.storySentences.isNotEmpty) {
      return _buildStoryReadPhase(state);
    }

    final question = state.currentQuestion;
    if (question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final answered = _selectedOption != null;
    final showTransliteration =
        state.group != null && showsTransliteration(state.group!);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedProgressBar(value: state.stageProgress),
          const SizedBox(height: 32),
          Center(
            child: question.isAudio
                ? _AudioPrompt(question: question)
                : question.isStory
                ? _StoryPrompt(
                    question: question,
                    showTransliteration: showTransliteration,
                  )
                : question.isWholeSentence
                ? _WholeSentencePrompt(
                    question: question,
                    showTransliteration: showTransliteration,
                  )
                : question.direction == QuizDirection.arabicToGerman
                ? Column(
                    children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          question.prompt,
                          style: AppTheme.arabicTextStyle(fontSize: 40),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (showTransliteration &&
                          question.word.transliteration.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            question.word.transliteration,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  )
                : Text(
                    question.prompt,
                    style: const TextStyle(fontSize: 26, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final option in question.options)
                    _OptionButton(
                      text: option,
                      isArabic: question.isStory || question.isAudio
                          ? false
                          : question.direction ==
                                    QuizDirection.germanToArabic ||
                                (question.isWholeSentence &&
                                    question.direction ==
                                        QuizDirection.germanToArabic),
                      isSelected: option == _selectedOption,
                      onTap: answered ? null : () => _selectOption(option),
                    ),
                ],
              ),
            ),
          ),
          if (answered) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: _next, child: const Text('Weiter')),
          ],
        ],
      ),
    );
  }

  /// Lese-Phase der Geschichten-Stufe: die gesamte Geschichte als
  /// zusammenhängender, scrollbarer Text. Erst nach „Weiter zur Zuordnung"
  /// folgen die 3-Optionen-Fragen pro Satz.
  Widget _buildStoryReadPhase(QuizState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedProgressBar(value: state.stageProgress),
            const SizedBox(height: 12),
            const Text(
              'Lies die Geschichte:',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final sentence in state.storySentences)
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              sentence.arabic,
                              style: AppTheme.arabicTextStyle(fontSize: 24),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() => _storyIntroShown = true),
              child: const Text('Weiter zur Zuordnung'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Audio-Stufe ([QuizStage.audio]): arabischer Satz wird als Audio
/// abgespielt (Play-Button), die deutsche Bedeutung steht in den Optionen.
/// Kein arabischer Text sichtbar — nur die Hörverständnis-Frage.
class _AudioPrompt extends StatelessWidget {
  const _AudioPrompt({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final sentence = question.sentence!;
    return Column(
      children: [
        const Text(
          'Höre zu und wähle die deutsche Bedeutung:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        IconButton(
          iconSize: 64,
          tooltip: 'Satz anhören',
          onPressed: () =>
              AudioService.instance.playSentence(sentence, _sentenceIndex),
          icon: const Icon(Icons.play_circle_fill, color: AppColors.gold),
        ),
      ],
    );
  }

  int get _sentenceIndex => question.sentenceIndex;
}

/// Geschichten-Stufe ([QuizStage.story]) — Zuordnungs-Phase: zeigt den
/// aktuellen Satz aus der bereits gelesenen Geschichte; der Nutzer wählt
/// aus den ähnlichen Übersetzungsoptionen die passende deutsche Bedeutung.
/// Die Lese-Phase (ganze Geschichte) wird separat zu Beginn der Stufe
/// angezeigt (`_buildStoryReadPhase`).
class _StoryPrompt extends StatelessWidget {
  const _StoryPrompt({
    required this.question,
    required this.showTransliteration,
  });

  final QuizQuestion question;
  final bool showTransliteration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welche Bedeutung passt zu diesem Satz?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            question.sentence!.arabic,
            style: AppTheme.arabicTextStyle(fontSize: 28, color: AppColors.gold),
            textAlign: TextAlign.center,
          ),
        ),
        if (showTransliteration &&
            question.sentence!.transliteration.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              question.sentence!.transliteration,
              style: const TextStyle(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// Ganzer Satz (Arabisch oder Deutsch, je nach Richtung) für die
/// Ganze-Sätze-Stufe ([QuizStage.wholeSentence]) — kein ausgeblendetes
/// Wort, hier wird der komplette Satz übersetzt statt nur ein Zielwort.
class _WholeSentencePrompt extends StatelessWidget {
  const _WholeSentencePrompt({
    required this.question,
    required this.showTransliteration,
  });

  final QuizQuestion question;
  final bool showTransliteration;

  @override
  Widget build(BuildContext context) {
    final sentence = question.sentence!;
    if (question.direction == QuizDirection.arabicToGerman) {
      return Column(
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              sentence.arabic,
              style: AppTheme.arabicTextStyle(fontSize: 28),
              textAlign: TextAlign.center,
            ),
          ),
          if (showTransliteration && sentence.transliteration.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                sentence.transliteration,
                style: const TextStyle(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }
    return Text(
      sentence.german,
      style: const TextStyle(fontSize: 22, color: Colors.white),
      textAlign: TextAlign.center,
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.text,
    required this.isArabic,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isArabic;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Kein Sofort-Feedback (Schulprüfung): ausgewählte Option wird nur
    // dezent hervorgehoben, Richtig/Falsch sehen Nutzer erst am Ende.
    final backgroundColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.4)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: isArabic
              ? Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    text,
                    style: AppTheme.arabicTextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(text, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
