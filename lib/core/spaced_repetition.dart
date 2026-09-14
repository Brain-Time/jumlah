import '../models/word.dart';

/// SM-2 (SuperMemo-2) — pure Wiederholungs-Logik ohne DB-/UI-Abhängigkeit
/// (Task: Spaced Repetition).
///
/// Kernidee: Jede Vokabel wird genau dann erneut abgefragt, wenn sie „fast
/// vergessen“ wäre. Nach jeder Selbstbewertung (Quality 0–5) wächst das
/// Intervall bei Erfolgen (Quality ≥ 3) und fällt bei Fehlversuchen auf den
/// Startwert zurück (Quality < 3).
///
/// SM-2-Regeln (Original):
///  * Quality < 3 → Vokabel gilt als vergessen: `repetitions` zurück auf 0,
///    Intervall 1 Tag.
///  * Erster Erfolg (`repetitions` 0 → 1) → Intervall 1 Tag.
///  * Zweiter Erfolg (`repetitions` 1 → 2) → Intervall 6 Tage.
///  * Weitere Erfolge → `round(previousInterval * easeFactor)`.
///  * Ease-Faktor (Start 2.5, Minimum 1.3): `EF' = EF + (0.1 - (5-q) *
///    (0.08 + (5-q) * 0.02))`.
class Sm2 {
  const Sm2._();

  static const double initialEaseFactor = 2.5;
  static const double minEaseFactor = 1.3;
  static const int firstIntervalDays = 1;
  static const int secondIntervalDays = 6;

  /// Wendet die SM-2-Übergangsregel auf einen Review der Qualität [quality]
  /// (0–5) an. Liefert den neuen Pool-Zustand ([Sm2Result]): nächste
  /// `repetitions`-Zahl, Ease-Faktor und Intervall (in Tagen).
  /// Das eigentliche Fälligkeitsdatum (heute + Intervall) berechnet die
  /// DB-Schicht — diese Klasse bleibt rein rechnerisch und dadurch ohne
  /// Uhrzeit-/Kalender-Abhängigkeit direkt testbar.
  static Sm2Result review({
    required int repetitions,
    required double easeFactor,
    required int intervalDays,
    required int quality,
  }) {
    final q = quality < 0 ? 0 : (quality > 5 ? 5 : quality);
    final nextEaseFactor = _nextEaseFactor(easeFactor, q);

    if (q < 3) {
      return Sm2Result(
        repetitions: 0,
        easeFactor: nextEaseFactor,
        intervalDays: firstIntervalDays,
      );
    }

    final nextRepetitions = repetitions + 1;
    final int nextIntervalDays;
    if (nextRepetitions == 1) {
      nextIntervalDays = firstIntervalDays;
    } else if (nextRepetitions == 2) {
      nextIntervalDays = secondIntervalDays;
    } else {
      nextIntervalDays = (intervalDays * nextEaseFactor).round();
    }
    return Sm2Result(
      repetitions: nextRepetitions,
      easeFactor: nextEaseFactor,
      intervalDays: nextIntervalDays,
    );
  }

  static double _nextEaseFactor(double easeFactor, int quality) {
    final ef = easeFactor < minEaseFactor ? minEaseFactor : easeFactor;
    final delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
    final next = ef + delta;
    return next < minEaseFactor ? minEaseFactor : next;
  }
}

/// Ergebnis eines SM-2-Übergangs ([Sm2.review]): der nächste Pool-Zustand.
class Sm2Result {
  const Sm2Result({
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
  });

  final int repetitions;
  final double easeFactor;

  /// Nächstes Intervall in Tagen (bis zur nächsten Fälligkeit).
  final int intervalDays;
}

/// Persistierter SM-2-Zustand eines Worts (eine Zeile der `sm2_state`-
/// Tabelle, ohne `word_id` — der gehört zum Primärschlüssel bzw. wird beim
/// Schreiben separat übergeben, siehe [Sm2State.toMap]).
class Sm2State {
  const Sm2State({
    this.repetitions = 0,
    this.easeFactor = Sm2.initialEaseFactor,
    this.intervalDays = 0,
    this.dueDate = '',
    this.lastQuality = 0,
  });

  /// Anzahl erfolgreicher Wiederholungen in Folge (SM-2 `repetitions`).
  final int repetitions;

  final double easeFactor;

  /// Aktuelles Intervall in Tagen.
  final int intervalDays;

  /// Nächstes Fälligkeitsdatum im `studyDateKey`-Format (`'YYYY-MM-DD'`,
  /// lokaler Tag — lexikographisch vergleichbar).
  final String dueDate;

  /// Letzte Selbstbewertung (0–5), nur für Debug-/Statistik-Zwecke.
  final int lastQuality;

  factory Sm2State.fromMap(Map<String, dynamic> map) {
    return Sm2State(
      repetitions: map['repetitions'] as int,
      easeFactor: (map['ease_factor'] as num).toDouble(),
      intervalDays: map['interval_days'] as int,
      dueDate: map['due_date'] as String,
      lastQuality: map['last_quality'] as int,
    );
  }

  Map<String, dynamic> toMap(int wordId) {
    return {
      'word_id': wordId,
      'repetitions': repetitions,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'due_date': dueDate,
      'last_quality': lastQuality,
    };
  }
}

/// Ein fälliges Wort inkl. seinem aktuellem SM-2-Zustand — ein Eintrag der
/// Wiederholungs-Session ([ReviewScreen]).
class Sm2ReviewItem {
  const Sm2ReviewItem({required this.word, required this.state});

  final Word word;
  final Sm2State state;
}