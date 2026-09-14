import 'dart:convert';

/// Wort-für-Wort-Übersetzung innerhalb eines Kontext-Satzes.
class WordAnalysis {
  const WordAnalysis({required this.word, required this.translation});

  final String word;
  final String translation;

  factory WordAnalysis.fromJson(Map<String, dynamic> json) {
    return WordAnalysis(
      word: json['word'] as String,
      translation: json['translation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'word': word, 'translation': translation};
  }
}

/// Entspricht einem Eintrag in assets/data/sentences.json (Task A2).
class Sentence {
  const Sentence({
    required this.wordId,
    required this.arabic,
    required this.german,
    required this.transliteration,
    required this.wordAnalysis,
    required this.targetIndex,
  });

  final int wordId;
  final String arabic;
  final String german;

  /// Wissenschaftliche Umschrift des ganzen Satzes nach DIN 31635 (nur bei
  /// A1/A2 angezeigt, siehe `core/word_groups.dart#showsTransliteration`).
  final String transliteration;

  final List<WordAnalysis> wordAnalysis;

  /// Index in [wordAnalysis], der das gelehrte Zielwort markiert (die
  /// arabische Form dort kann von `Word.arabic` abweichen, z.B. durch
  /// Konjugation — siehe scripts/generate_sentences.py). Grundlage für den
  /// Lückentext im Satz-Quiz.
  final int targetIndex;

  /// Die arabische Oberflächenform des Zielworts, wie sie im Satz steht
  /// (für den Lückentext-Blank und dessen richtige Antwort).
  WordAnalysis? get targetWord =>
      targetIndex >= 0 && targetIndex < wordAnalysis.length
      ? wordAnalysis[targetIndex]
      : null;

  factory Sentence.fromJson(Map<String, dynamic> json) {
    final rawAnalysis = json['word_analysis'] as List<dynamic>? ?? const [];
    return Sentence(
      wordId: json['word_id'] as int,
      arabic: json['arabic'] as String,
      german: json['german'] as String,
      transliteration: json['transliteration'] as String? ?? '',
      wordAnalysis: rawAnalysis
          .map((entry) => WordAnalysis.fromJson(entry as Map<String, dynamic>))
          .toList(),
      targetIndex: json['target_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word_id': wordId,
      'arabic': arabic,
      'german': german,
      'transliteration': transliteration,
      'word_analysis': wordAnalysis.map((entry) => entry.toJson()).toList(),
      'target_index': targetIndex,
    };
  }

  /// Für die SQLite-Tabelle `sentences` (Task D1) — `word_analysis` wird
  /// als JSON-Text gespeichert, da SQLite keine verschachtelten Strukturen
  /// kennt. Die Tabelle hat eine eigene, hier ungenutzte `id`-Spalte
  /// (AUTOINCREMENT), da mehrere Sätze denselben `word_id` teilen.
  factory Sentence.fromMap(Map<String, dynamic> map) {
    final rawAnalysis = jsonDecode(map['word_analysis'] as String) as List<dynamic>;
    return Sentence(
      wordId: map['word_id'] as int,
      arabic: map['arabic'] as String,
      german: map['german'] as String,
      transliteration: map['transliteration'] as String? ?? '',
      wordAnalysis: rawAnalysis
          .map((entry) => WordAnalysis.fromJson(entry as Map<String, dynamic>))
          .toList(),
      targetIndex: map['target_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'arabic': arabic,
      'german': german,
      'transliteration': transliteration,
      'word_analysis': jsonEncode(
        wordAnalysis.map((entry) => entry.toJson()).toList(),
      ),
      'target_index': targetIndex,
    };
  }
}
