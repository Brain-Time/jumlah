import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/theme/app_theme.dart';
import '../../models/word.dart';

/// Ergebnis-Anzeige nach Abschluss aller 6 Quiz-Stufen („Schulprüfung",
/// Nutzer-Vorgabe 29. August 2026). Bestanden gilt bei
/// [wrongCount] ≤ [allowedErrors]; nur bei Bestehen wird die nächste
/// Lektion/Gruppe freigeschaltet.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.score,
    required this.totalWords,
    required this.wrongCount,
    required this.allowedErrors,
    required this.wrongWords,
    this.passed,
    this.isTrackedBatch = false,
    this.onRepeat,
    this.onContinue,
  });

  final int score;
  final int totalWords;
  final int wrongCount;
  final int allowedErrors;
  final List<Word> wrongWords;

  /// Ob der Lauf bestanden wurde (wrongCount ≤ allowedErrors) — null bei
  /// ungetrackten Läufen.
  final bool? passed;

  /// Ob dieser Lauf ein getrackter Batch war (Gruppe/Batch-Index gesetzt) —
  /// steuert, ob der Freischalt-Hinweis angezeigt wird.
  final bool isTrackedBatch;

  /// Wird aufgerufen, wenn der Nutzer das Quiz mit denselben Wörtern
  /// wiederholen möchte. Wenn null, wird kein "Wiederholen"-Button gezeigt.
  final VoidCallback? onRepeat;

  /// Ersetzt das Standard-Verhalten des "Weiter"-Buttons (zweimal pop) —
  /// z.B. um nach dem letzten Batch einer Gruppe zur Gesamtprüfung zu
  /// leiten (siehe `GroupCompleteScreen`).
  final VoidCallback? onContinue;

  /// Baut den Teil-Text für das Quiz-Ergebnis („Ergebnis teilen“-Button).
  /// Bewusst als reine Funktion gehalten, damit der Text ohne echte
  /// Clipboard-Interaktion testbar ist.
  static String buildShareText({
    required int score,
    required int totalWords,
    required int wrongCount,
    required int allowedErrors,
    required bool? passed,
  }) {
    final status = passed == true
        ? 'Bestanden ✅'
        : passed == false
        ? 'Nicht bestanden'
        : 'Abgeschlossen';
    return 'Jumlah — Arabisch lernen 📚\n'
        'Ergebnis: $status\n'
        'Richtige Antworten: $score von $totalWords\n'
        'Fehler: $wrongCount von $allowedErrors erlaubten';
  }

  /// Kopiert das Quiz-Ergebnis als Text in die Zwischenablage und bestätigt
  /// mit einer Snackbar. Fehler (z.B. keine Clipboard-Unterstützung auf dem
  /// Gerät) werden still geschluckt, damit der Bildschirm bedienbar bleibt.
  Future<void> _shareResult(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = buildShareText(
      score: score,
      totalWords: totalWords,
      wrongCount: wrongCount,
      allowedErrors: allowedErrors,
      passed: passed,
    );
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      // Absichtlich leer — siehe Doc-Kommentar oben.
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Ergebnis in die Zwischenablage kopiert.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passed = this.passed;
    final title = (passed == true)
        ? 'Bestanden!'
        : (passed == false)
        ? 'Nicht bestanden'
        : 'Ergebnis';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    final passed = this.passed;
    final isPassed = passed == true;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$score richtige Antworten',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '$wrongCount Fehler von $allowedErrors erlaubten',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          if (isTrackedBatch && passed != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isPassed ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPassed ? AppColors.success : AppColors.error,
                ),
              ),
              child: Text(
                isPassed
                    ? 'Lektion bestanden — nächste Lektion ist freigeschaltet!'
                    : 'Lektion nicht bestanden — bitte wiederholen, um die nächste Lektion freizuschalten.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPassed ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (wrongWords.isNotEmpty) ...[
            const Text(
              'Nochmal üben:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: wrongWords.length,
                itemBuilder: (context, index) {
                  final word = wrongWords[index];
                  return ListTile(
                    title: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        word.arabic,
                        style: AppTheme.arabicTextStyle(fontSize: 20),
                      ),
                    ),
                    subtitle: Text(
                      word.german,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 12),
          // „Ergebnis teilen“ (10. September 2026): kopiert den Ergebnis-Text
          // in die Zwischenablage.
          Expanded(
            child: OutlinedButton(
              onPressed: () => _shareResult(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share, size: 18),
                  const SizedBox(width: 6),
                  const Text('Ergebnis teilen'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onRepeat != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRepeat,
                    child: const Text('Wiederholen'),
                  ),
                ),
              if (onRepeat != null) const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed:
                      onContinue ??
                      () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                  child: const Text('Weiter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
