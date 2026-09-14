/// Entspricht der SQLite-Tabelle `progress` (siehe README.md
/// Abschnitt Datenstruktur).
class Progress {
  const Progress({
    required this.wordId,
    this.level = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastSeen,
  });

  final int wordId;
  final int level;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastSeen;

  factory Progress.fromMap(Map<String, dynamic> map) {
    final lastSeenRaw = map['last_seen'] as String?;
    return Progress(
      wordId: map['word_id'] as int,
      level: map['level'] as int? ?? 0,
      correctCount: map['correct_count'] as int? ?? 0,
      wrongCount: map['wrong_count'] as int? ?? 0,
      lastSeen: lastSeenRaw == null ? null : DateTime.tryParse(lastSeenRaw),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'level': level,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  Progress copyWith({
    int? level,
    int? correctCount,
    int? wrongCount,
    DateTime? lastSeen,
  }) {
    return Progress(
      wordId: wordId,
      level: level ?? this.level,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
