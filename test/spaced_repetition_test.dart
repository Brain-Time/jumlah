import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/spaced_repetition.dart';

/// Reine SM-2-Mathematik (Task: Spaced Repetition) — ohne DB/UI getestet.
/// Referenzwerte folgen der SuperMemo-2-Spezifikation:
/// EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02)), Minimum 1.3.
void main() {
  group('Sm2.review', () {
    test(
      'erster Erfolg (q=4): repetitions 1, Intervall 1 Tag, EF unveraendert',
      () {
        final r = Sm2.review(
          repetitions: 0,
          easeFactor: Sm2.initialEaseFactor,
          intervalDays: 0,
          quality: 4,
        );
        expect(r.repetitions, 1);
        expect(r.intervalDays, Sm2.firstIntervalDays);
        // delta = 0.1 - (5-4)*(0.08+(5-4)*0.02) = 0.1 - 0.1 = 0.0
        expect(r.easeFactor, closeTo(2.5, 1e-9));
      },
    );

    test('zweiter Erfolg: Intervall 6 Tage', () {
      final r = Sm2.review(
        repetitions: 1,
        easeFactor: 2.5,
        intervalDays: 1,
        quality: 5,
      );
      expect(r.repetitions, 2);
      expect(r.intervalDays, Sm2.secondIntervalDays);
      // delta = 0.1 -> EF 2.6
      expect(r.easeFactor, closeTo(2.6, 1e-9));
    });

    test('dritter Erfolg: round(prevInterval * easeFactor)', () {
      // Der EF wird VOR der Intervall-Rechnung aktualisiert: 2.7 + 0.1 (q=5)
      // = 2.8 → round(6 Tage * 2.8) = round(16.8) = 17 Tage.
      final r = Sm2.review(
        repetitions: 2,
        easeFactor: 2.7,
        intervalDays: 6,
        quality: 5,
      );
      expect(r.repetitions, 3);
      expect(r.intervalDays, 17);
    });

    test('q=3 senkt den EF (delta < 0), bleibt aber ein Erfolg', () {
      final r = Sm2.review(
        repetitions: 0,
        easeFactor: 2.5,
        intervalDays: 0,
        quality: 3,
      );
      expect(r.repetitions, 1);
      expect(r.intervalDays, 1);
      // delta = 0.1 - 2*(0.08+2*0.02) = 0.1 - 0.24 = -0.14 -> EF 2.36.
      expect(r.easeFactor, closeTo(2.36, 1e-9));
    });

    test('Fehlversuch (q<3): repetitions zurueck auf 0, Intervall 1 Tag', () {
      final r = Sm2.review(
        repetitions: 5,
        easeFactor: 2.6,
        intervalDays: 30,
        quality: 2,
      );
      expect(r.repetitions, 0);
      expect(r.intervalDays, Sm2.firstIntervalDays);
      // delta = 0.1 - 3*(0.08+3*0.02) = 0.1 - 0.42 = -0.32 -> EF 2.28.
      expect(r.easeFactor, closeTo(2.28, 1e-9));
    });

    test('q=0 senkt den EF am staerksten', () {
      final r = Sm2.review(
        repetitions: 2,
        easeFactor: 2.5,
        intervalDays: 6,
        quality: 0,
      );
      // delta = 0.1 - 5*(0.08+5*0.02) = 0.1 - 0.9 = -0.8 -> EF 1.7.
      expect(r.easeFactor, closeTo(1.7, 1e-9));
      expect(r.repetitions, 0);
    });

    test('EF wird auf das Minimum 1.3 begrenzt', () {
      // 1.7 - 0.8 = 0.9 -> clamp auf 1.3.
      final r = Sm2.review(
        repetitions: 0,
        easeFactor: 1.7,
        intervalDays: 1,
        quality: 0,
      );
      expect(r.easeFactor, Sm2.minEaseFactor);
    });

    test('Qualitätswerte ausserhalb 0-5 werden geklemmt', () {
      final high = Sm2.review(
        repetitions: 0,
        easeFactor: 2.5,
        intervalDays: 0,
        quality: 7,
      );
      expect(high.easeFactor, closeTo(2.6, 1e-9)); // wie q=5

      final low = Sm2.review(
        repetitions: 3,
        easeFactor: 2.5,
        intervalDays: 30,
        quality: -1,
      );
      expect(low.repetitions, 0); // wie q=0 -> Fehlversuch
    });
  });
}