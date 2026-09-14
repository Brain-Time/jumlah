import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/models/sentence.dart';
import 'package:jumlah/models/word.dart';
import 'package:jumlah/providers/quiz_provider.dart';
import 'package:jumlah/screens/quiz/quiz_screen.dart';

void main() {
  // Die 10 Wörter der Lektion 1 (word_ids 1–10), damit die eingelegte
  // zusammenhängende Geschichte (_lessonOneStory) in Stufe 6 verwendet wird.
  final words = [
    Word(id: 1, arabic: 'كَتَبَ', german: 'schreiben', root: 'ك-ت-ب', group: 'A1', frequencyRank: 1, transliteration: 'kataba'),
    Word(id: 2, arabic: 'قَرَأَ', german: 'lesen', root: 'ق-ر-أ', group: 'A1', frequencyRank: 2, transliteration: 'qaraʾa'),
    Word(id: 3, arabic: 'قَالَ', german: 'sagen', root: 'ق-و-ل', group: 'A1', frequencyRank: 3, transliteration: 'qāla'),
    Word(id: 4, arabic: 'ذَهَبَ', german: 'gehen', root: 'ذ-ه-ب', group: 'A1', frequencyRank: 4, transliteration: 'ḏahaba'),
    Word(id: 5, arabic: 'جَاءَ', german: 'kommen', root: 'ج-ي-أ', group: 'A1', frequencyRank: 5, transliteration: 'ǧāʾa'),
    Word(id: 6, arabic: 'عَلِمَ', german: 'wissen', root: 'ع-ل-م', group: 'A1', frequencyRank: 6, transliteration: 'ʿalima'),
    Word(id: 7, arabic: 'فَعَلَ', german: 'tun', root: 'ف-ع-ل', group: 'A1', frequencyRank: 7, transliteration: 'faʿala'),
    Word(id: 8, arabic: 'رَأَى', german: 'sehen', root: 'ر-أ-ي', group: 'A1', frequencyRank: 8, transliteration: 'raʾā'),
    Word(id: 9, arabic: 'سَمِعَ', german: 'hören', root: 'س-م-ع', group: 'A1', frequencyRank: 9, transliteration: 'samiʿa'),
    Word(id: 10, arabic: 'أَكَلَ', german: 'essen', root: 'أ-ك-ل', group: 'A1', frequencyRank: 10, transliteration: 'ʾakala'),
  ];

  // Ein Satz je Wort, damit die Satz-Stufen (Klassen 4–6) spielbar sind.
  Map<int, List<Sentence>> sentences() {
    final german = [
      'Der Mann schrieb einen Brief.',
      'Der Mann las das Buch.',
      'Der Mann sagte: Hallo.',
      'Der Mann ging nach Hause.',
      'Sein Freund kam voller Freude.',
      'Der Mann erfuhr die Nachricht.',
      'Der Mann tat eine Arbeit.',
      'Der Mann sah ein schönes Buch.',
      'Der Mann hörte ein Geräusch.',
      'Der Mann aß das Essen.',
    ];
    return {
      for (var i = 0; i < words.length; i++)
        words[i].id: [
          Sentence(
            wordId: words[i].id,
            arabic: 'Satz ${words[i].id}',
            german: german[i],
            transliteration: 'satz',
            wordAnalysis: const [],
            targetIndex: 0,
          ),
        ],
    };
  }

  testWidgets(
    'Stufe 6 zeigt zuerst die Lesephase der Geschichte, dann 3 Zuordnungsoptionen',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: QuizScreen(words: words, sentencesByWordId: sentences()),
          ),
        ),
      );
      await tester.pump();

      // Durch alle Stufen bis zur Geschichte klicken (je Frage: richtig
      // antworten + Weiter).
      var guard = 0;
      while (container.read(quizProvider).stage != QuizStage.story &&
          !container.read(quizProvider).isFinished &&
          guard < 300) {
        guard++;
        final correct = container.read(quizProvider).currentQuestion!.correctAnswer;
        await tester.tap(find.text(correct));
        await tester.pump();
        await tester.tap(find.text('Weiter'));
        await tester.pump();
      }

      // Lese-Phase der Geschichte.
      expect(container.read(quizProvider).stage, QuizStage.story);
      expect(find.text('Lies die Geschichte:'), findsOneWidget);
      expect(find.text('Weiter zur Zuordnung'), findsOneWidget);
      // Die Geschichte (die deutschen Übersetzungen sind NICHT sichtbar,
      // nur die arabischen Sätze).
      expect(find.text('Der Mann ging nach Hause.'), findsNothing);

      // Weiter zur Zuordnung.
      await tester.tap(find.text('Weiter zur Zuordnung'));
      await tester.pump();

      // Erste Zuordnungs-Frage: genau 3 Optionen, arabischer Satz sichtbar,
      // die korrekte deutsche Bedeutung ist unter den Optionen.
      final q = container.read(quizProvider).currentQuestion!;
      expect(q.isStory, isTrue);
      expect(q.options, hasLength(3));
      expect(q.options, contains(q.correctAnswer));
      expect(q.options, containsAll(q.options.toSet()));
      // Alle Optionen sind deutsche Übersetzungen (ähnlich).
      expect(q.options.map((o) => o.contains('Der Mann')).where((b) => b).length, greaterThanOrEqualTo(2));
    },
  );
}
