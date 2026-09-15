import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/spaced_repetition.dart' show Sm2ReviewItem;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_progress_bar.dart';
import '../../core/word_groups.dart' show showsTransliteration;
import '../../l10n/l10n.dart';
import '../../models/word.dart';

/// Wiederholungs-Screen der Spaced-Repetition (Task: SM-2). Zeigt alle
/// aktuell fälligen Wörter als Karte: erst Arabisch (Antwort verdeckt),
/// nach „Antwort zeigen“ die deutsche Übersetzung (plus Transliteration bei
/// A1/A2) und eine SM-2-Selbstbewertung (0–5). Jede Bewertung verschiebt das
/// Wort über den SM-2-Algorithmus (siehe `lib/core/spaced_repetition.dart`)
/// in sein nächstes Intervall bzw. macht es bei Quality < 3 wieder fällig.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Sm2ReviewItem> _due = const [];
  String? _errorMessage;
  bool _loading = true;
  int _index = 0;
  bool _revealed = false;
  bool _finished = false;
  int _totalAnswered = 0;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  /// Lädt alle fälligen Wörter frisch aus dem SM-2-Pool. Der Screen lädt bei
  /// jedem Aufbau neu — wer direkt nach dem Bestehen einer Lektion hierher
  /// wechselt, sieht sofort die neuen fälligen Wörter.
  Future<void> _load() async {
    try {
      final due =
          await DatabaseHelper.instance.getDueSm2Words(DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _due = due;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  /// Deckt die Übersetzung auf. Zählt zugleich als Lernaktivität für den
  /// heutigen Tag (fire-and-forget, analog zum Lern-Modus).
  void _reveal() {
    if (_revealed) {
      return;
    }
    setState(() => _revealed = true);
    DatabaseHelper.instance.trackStudyActivity(wordsViewed: 1);
  }

  /// Wertet die SM-2-Selbstbewertung [quality] (0–5) für das aktuelle Wort
  /// aus, persistiert den neuen Pool-Zustand und rückt zum nächsten Wort —
  /// bzw. zeigt nach dem letzten Wort die Zusammenfassung.
  Future<void> _rate(int quality) async {
    final current = _due[_index];
    await DatabaseHelper.instance.recordSm2Review(
      current.word.id,
      quality,
      DateTime.now(),
    );
    // Richtig erinnerte Wörter (Quality ≥ 3) stärken auch den allgemeinen
    // Wort-Fortschritt (fire-and-forget, wie im Quiz).
    DatabaseHelper.instance.updateProgress(current.word.id, quality >= 3);

    final answered = _totalAnswered + 1;
    final correct = _correctCount + (quality >= 3 ? 1 : 0);
    if (_index + 1 >= _due.length) {
      setState(() {
        _finished = true;
        _totalAnswered = answered;
        _correctCount = correct;
      });
    } else {
      setState(() {
        _index += 1;
        _revealed = false;
        _totalAnswered = answered;
        _correctCount = correct;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reviewAppBarTitle)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.loadError(_errorMessage!),
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_due.isEmpty) {
      return const _EmptyState();
    }
    if (_finished) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _Summary(
          totalAnswered: _due.length,
          correctCount: _correctCount,
        ),
      );
    }

    final word = _due[_index].word;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedProgressBar(value: (_index + 1) / _due.length),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                context.l10n.reviewAppBarTitle,
                style: AppTheme.secondaryStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${_index + 1} / ${_due.length}',
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
                  _WordCard(word: word, revealed: _revealed),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildFooter()),
        ],
      ),
    );
}
/// Unterer Bereich: vor dem Aufdecken der „Antwort zeigen“-Button, danach
  /// die sechsstufige SM-2-Selbstbewertung (0 = vergessen … 5 = perfekt).
  Widget _buildFooter() {
    if (!_revealed) {
      return FilledButton(
        onPressed: _reveal,
        child: Text(context.l10n.revealAnswer),
      );
    }
    final ratings = [
      (0, context.l10n.quality0, AppColors.error),
      (1, context.l10n.quality1, AppColors.error),
      (2, context.l10n.quality2, AppColors.textSecondary),
      (3, context.l10n.quality3, AppColors.success),
      (4, context.l10n.quality4, AppColors.success),
      (5, context.l10n.quality5, AppColors.gold),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.howWellQuestion,
          style: AppTheme.secondaryStyle(fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        for (var rowStart = 0; rowStart < ratings.length; rowStart += 3) ...[
          Row(
            children: [
              for (final (quality, label, _) in ratings.sublist(
                    rowStart,
                    (rowStart + 3).clamp(0, ratings.length),
                  ))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rate(quality),
                    child: Text(label),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
/// Wort-Karte des Wiederholungs-Screens: großes Arabisch (RTL, Amiri);
/// nach dem Aufdecken zusätzlich Transliteration (A1/A2) und Deutsch.
class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.revealed});

  final Word word;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceElevated,
        borderColor: AppColors.primary.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              word.arabic,
              textAlign: TextAlign.center,
              style: AppTheme.arabicTextStyle(
                fontSize: 42,
                color: AppColors.gold,
              ),
            ),
          ),
          if (revealed) ...[
            if (showsTransliteration(word.group) &&
                word.transliteration.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                word.transliteration,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              word.german,
              textAlign: TextAlign.center,
              style: AppTheme.titleStyle(fontSize: 22),
            ),
          ],
        ],
      ),
    );
  }
}
/// Leer-Zustand: keine fälligen Wörter im SM-2-Pool.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: AppTheme.cardPaddingAll,
          decoration: AppTheme.cardDecoration(
            color: AppColors.surfaceElevated,
            borderColor: AppColors.gold.withValues(alpha: 0.45),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.done_all, size: 26, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.reviewAllDone,
                      style: AppTheme.titleStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.reviewNoDue,
                style: AppTheme.secondaryStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zusammenfassung am Ende einer Wiederholungs-Session („Fertig“ kehrt zur
/// Startseite zurück).
class _Summary extends StatelessWidget {
  const _Summary({required this.totalAnswered, required this.correctCount});

  final int totalAnswered;
  final int correctCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: AppTheme.cardPaddingAll,
            decoration: AppTheme.cardDecoration(
              color: AppColors.surfaceElevated,
              borderColor: AppColors.success.withValues(alpha: 0.45),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.celebration,
                      size: 28,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.sessionComplete,
                        style: AppTheme.headingStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.rememberedSummary(correctCount, totalAnswered),
                  style: AppTheme.bodyStyle(),
                ),
                if (correctCount == 0)
                  Text(
                    context.l10n.forgottenHint,
                    style: AppTheme.secondaryStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.done),
          ),
        ],
      ),
    );
  }
}