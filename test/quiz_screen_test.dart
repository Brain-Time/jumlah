import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/providers/quiz_provider.dart';
import 'package:jumlah/screens/quiz/quiz_screen.dart';

void main() {
  const wordA = Word(
    id: 1,
    arabic: 'كَتَبَ',
    german: 'schreiben',
    root: 'ك-ت-ب',
    group: 'A1',
    frequencyRank: 1,
    transliteration: 'kataba',
  );
  const wordB = Word(
    id: 2,
    arabic: 'قَرَأَ',
    german: 'lesen',
    root: 'ق-ر-أ',
    group: 'A1',
    frequencyRank: 2,
    transliteration: 'qaraʾa',
  );

  /// Beantwortet die aktuell angezeigte Frage korrekt und blättert weiter
  /// (kein Sofort-Feedback mehr -> direkt Weiter tippen).
  Future<void> answerCorrectly(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final correctAnswer = container
        .read(quizProvider)
        .currentQuestion!
        .correctAnswer;
    await tester.tap(find.text(correctAnswer));
    await tester.pump();
    await tester.tap(find.text('Weiter'));
    await tester.pump();
  }

  testWidgets(
    'QuizScreen zeigt kein Sofort-Feedback und navigiert nach den Stufen zum Ergebnis',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: QuizScreen(words: [wordA, wordB])),
        ),
      );
      await tester.pump();

      expect(find.text('Stufe 1/6 · Arabisch → Deutsch'), findsOneWidget);

      final firstQuestion = container.read(quizProvider).currentQuestion!;
      await tester.tap(find.text(firstQuestion.correctAnswer));
      await tester.pump();

      // Kein Sofort-Feedback: kein grüner/roter Buttontext, "Weiter" ist da
      // (neutral). Richtige Antwort -> Fehlerstand bleibt 0, Wort wird als
      // gelöst markiert (kein Requeue).
      expect(find.text('Weiter'), findsOneWidget);
      expect(container.read(quizProvider).lastAnswerCorrect, isTrue);
      expect(container.read(quizProvider).wrongCount, 0);
      expect(
        container.read(quizProvider).finalWrongWordIds,
        isEmpty,
      );

      await tester.tap(find.text('Weiter'));
      await tester.pump();

      // 2 Woerter x 3 Wort-Stufen = 6 Fragen; eine bereits beantwortet -> 5 weitere.
      for (var i = 0; i < 5; i++) {
        await answerCorrectly(tester, container);
      }
      await tester.pumpAndSettle();

      // Nach der letzten Wort-Stufe navigiert der Screen zum Ergebnis-Screen.
      // (0 Fehler -> Titel "Bestanden!")
      expect(find.text('Bestanden!'), findsOneWidget);
      expect(find.text('6 richtige Antworten'), findsOneWidget);
      expect(find.text('0 Fehler von 3 erlaubten'), findsOneWidget);
    },
  );

  testWidgets(
    'Falsche Antwort loest keinen Requeue aus und zeigt kein Gruen/Rot',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: QuizScreen(words: [wordA, wordB])),
        ),
      );
      await tester.pump();

      final question = container.read(quizProvider).currentQuestion!;
      final wrongOption = question.options.firstWhere(
        (o) => o != question.correctAnswer,
      );

      await tester.tap(find.text(wrongOption));
      await tester.pump();

      expect(container.read(quizProvider).lastAnswerCorrect, isFalse);
      // Kein Requeue (Prüfung): die Wort-Warteschlange für Stufe 1 hat
      // nicht zugenommen (currentQuestion + queue = 2 Woerter), Fehlerstand +1.
      expect(container.read(quizProvider).wrongCount, 1);
      expect(container.read(quizProvider).finalWrongWordIds, hasLength(1));
    },
  );
}
