import 'dart:convert';

/// Entspricht einem Eintrag in assets/data/roots.json (Hybrid-Wörterbuch-
/// Ansatz: Wurzel-Cluster mit klassischer Definition, inspiriert von
/// arabiclexicon.hawramani.com / Lane's Lexicon).
class WordRoot {
  const WordRoot({
    required this.root,
    required this.classicalDefinition,
    required this.source,
    required this.relatedWordIds,
    this.exampleNounArabic = '',
  });

  final String root;
  final String classicalDefinition;
  final String source;
  final List<int> relatedWordIds;

  /// Ein zur Wurzel gehörendes Nomen in arabischer Schrift (z.B. „كِتَابٌ“
  /// bei der Wurzel ك-ت-ب), sofern eines der `relatedWordIds` bereits ein
  /// solches Wort ist (siehe `scripts/build_roots.py#example_noun_arabic`).
  /// Leer, wenn die Wurzel (noch) kein passendes Nomen als Vokabel enthält —
  /// siehe TODO zur Vervollständigung der restlichen Wurzeln.
  final String exampleNounArabic;

  factory WordRoot.fromJson(Map<String, dynamic> json) {
    final rawIds = json['related_word_ids'] as List<dynamic>? ?? const [];
    return WordRoot(
      root: json['root'] as String,
      classicalDefinition: json['classical_definition'] as String,
      source: json['source'] as String,
      relatedWordIds: rawIds.map((id) => id as int).toList(),
      exampleNounArabic: json['example_noun_arabic'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'root': root,
      'classical_definition': classicalDefinition,
      'source': source,
      'related_word_ids': relatedWordIds,
      'example_noun_arabic': exampleNounArabic,
    };
  }

  /// Für die SQLite-Tabelle `roots` (Task D1) — `related_word_ids` wird als
  /// JSON-Text gespeichert, da SQLite keine Listen-Spalten kennt.
  factory WordRoot.fromMap(Map<String, dynamic> map) {
    final rawIds = jsonDecode(map['related_word_ids'] as String) as List<dynamic>;
    return WordRoot(
      root: map['root'] as String,
      classicalDefinition: map['classical_definition'] as String,
      source: map['source'] as String,
      relatedWordIds: rawIds.map((id) => id as int).toList(),
      exampleNounArabic: map['example_noun_arabic'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'root': root,
      'classical_definition': classicalDefinition,
      'source': source,
      'related_word_ids': jsonEncode(relatedWordIds),
      'example_noun_arabic': exampleNounArabic,
    };
  }
}
