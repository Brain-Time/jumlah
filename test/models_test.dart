import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/models/root.dart';
import 'package:jumlah/models/sentence.dart';
import 'package:jumlah/models/word.dart';

void main() {
  test('Word.fromJson parst assets/data/words.json vollständig', () {
    final raw = File('assets/data/words.json').readAsStringSync();
    final list = json.decode(raw) as List<dynamic>;
    final words = list
        .map((entry) => Word.fromJson(entry as Map<String, dynamic>))
        .toList();

    expect(words, hasLength(2000));
    expect(words.first.id, 1);
    expect(words.first.arabic, 'كَتَبَ');
    expect(words.first.group, 'A1');
    expect(words.first.transliteration, 'kataba');
    expect(words.first.masdar, 'كِتَابَة');
    expect(words.first.masdarTransliteration, 'kitāba');
    expect(words.first.masdarGerman, 'das Schreiben');
    expect(words, everyElement(predicate<Word>((w) => w.transliteration.isNotEmpty)));
    expect(
      words.where((w) => w.masdar.isNotEmpty),
      hasLength(739),
      reason: 'Masdar ist nur bei Verben gesetzt, nicht bei Nomen/Adjektiven/Partikeln',
    );

    final roundTrip = Word.fromMap(words.first.toMap());
    expect(roundTrip.arabic, words.first.arabic);
    expect(roundTrip.transliteration, words.first.transliteration);
    expect(roundTrip.masdar, words.first.masdar);
    expect(roundTrip.masdarTransliteration, words.first.masdarTransliteration);
    expect(roundTrip.masdarGerman, words.first.masdarGerman);
  });

  test('WordRoot.fromJson parst assets/data/roots.json vollständig', () {
    final raw = File('assets/data/roots.json').readAsStringSync();
    final list = json.decode(raw) as List<dynamic>;
    final roots = list
        .map((entry) => WordRoot.fromJson(entry as Map<String, dynamic>))
        .toList();

    expect(roots, hasLength(1065));

    final aminRoot = roots.firstWhere((r) => r.root == 'أ-م-ن');
    expect(aminRoot.relatedWordIds, containsAll([14, 39]));
  });

  test('Sentence.fromJson parst assets/data/sentences.json vollständig', () {
    final raw = File('assets/data/sentences.json').readAsStringSync();
    final list = json.decode(raw) as List<dynamic>;
    final sentences = list
        .map((entry) => Sentence.fromJson(entry as Map<String, dynamic>))
        .toList();

    expect(sentences, hasLength(6000));
    expect(sentences.first.wordId, 1);
    expect(sentences.first.wordAnalysis, isNotEmpty);
    expect(sentences.first.targetIndex, 0);
    expect(sentences.first.targetWord?.word, 'كَتَبَ');
    expect(sentences.first.transliteration, 'Kataba aṭ-ṭālibu ad-darsa.');
    expect(
      sentences,
      everyElement(predicate<Sentence>((s) => s.transliteration.isNotEmpty)),
    );

    final byWord = <int, int>{};
    for (final s in sentences) {
      byWord[s.wordId] = (byWord[s.wordId] ?? 0) + 1;
      expect(
        s.targetIndex,
        inInclusiveRange(0, s.wordAnalysis.length - 1),
        reason: 'targetIndex außerhalb von word_analysis für word_id ${s.wordId}',
      );
    }
    expect(byWord.keys, hasLength(2000));
    expect(byWord.values, everyElement(3));

    // Der einzige Satz mit vorangestelltem Negationspartikel ("مَا") hat
    // targetIndex 1 statt 0 (siehe scripts/generate_sentences.py).
    final negated = sentences.firstWhere(
      (s) => s.arabic == 'مَا اسْتَطَعْنَا الْوُصُولَ.',
    );
    expect(negated.targetIndex, 1);
    expect(negated.targetWord?.word, 'اسْتَطَعْنَا');
  });
}
