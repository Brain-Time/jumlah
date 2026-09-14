/// Entspricht einem Eintrag in assets/data/words.json bzw. der SQLite-Tabelle
/// `words` (siehe scripts/prepare_words.py, Task A1).
class Word {
  const Word({
    required this.id,
    required this.arabic,
    required this.german,
    required this.root,
    required this.group,
    required this.frequencyRank,
    required this.transliteration,
    this.masdar = '',
    this.masdarTransliteration = '',
    this.masdarGerman = '',
  });

  final int id;
  final String arabic;
  final String german;
  final String root;
  final String group;
  final int frequencyRank;

  /// Wissenschaftliche Umschrift nach DIN 31635 (nur bei A1/A2 angezeigt,
  /// siehe `core/word_groups.dart#showsTransliteration`).
  final String transliteration;

  /// Masdar (Verbalnomen) des Verbs in arabischer Schrift, z.B. „الكِتَابَة“
  /// bei „كَتَبَ“ (Nutzer-Vorgabe, 27. August 2026 — der zuvor gezeigte
  /// „example_noun_arabic“ der Wurzel war oft kein echter Masdar, sondern
  /// irgendein zufälliges Nomen derselben Wurzel, teils sogar ein
  /// Homograph mit unverwandter Bedeutung). Leer bei Nomen/Adjektiven/
  /// Partikeln, da nur Verben einen Masdar haben.
  final String masdar;

  /// Wissenschaftliche Umschrift des Masdars nach DIN 31635.
  final String masdarTransliteration;

  /// Deutsche Bedeutung des Masdars als Substantiv (z.B. „das Schreiben“).
  final String masdarGerman;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int,
      arabic: json['arabic'] as String,
      german: json['german'] as String,
      root: json['root'] as String,
      group: json['group'] as String,
      frequencyRank: json['frequency_rank'] as int,
      transliteration: json['transliteration'] as String? ?? '',
      masdar: json['masdar'] as String? ?? '',
      masdarTransliteration: json['masdar_transliteration'] as String? ?? '',
      masdarGerman: json['masdar_german'] as String? ?? '',
    );
  }

  /// Alias für fromJson: SQLite-Zeilen (sqflite) verwenden dieselben
  /// Spaltennamen wie die JSON-Keys, siehe [toMap].
  factory Word.fromMap(Map<String, dynamic> map) => Word.fromJson(map);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'arabic': arabic,
      'german': german,
      'root': root,
      'group': group,
      'frequency_rank': frequencyRank,
      'transliteration': transliteration,
      'masdar': masdar,
      'masdar_transliteration': masdarTransliteration,
      'masdar_german': masdarGerman,
    };
  }
}
