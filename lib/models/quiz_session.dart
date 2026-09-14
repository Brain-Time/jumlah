import 'dart:convert';

/// Entspricht der SQLite-Tabelle `quiz_session` (Task G3, Anti-Cheat):
/// Zwischenstand eines noch laufenden, getrackten Batch-Quiz. Wird nach
/// jeder beantworteten Frage überschrieben und erst gelöscht, wenn das Quiz
/// regulär zu Ende gespielt wird (bestanden oder nicht). Verhindert, dass
/// ein App-Neustart mitten im Quiz bereits verbrauchte Fehlversuche
/// zurücksetzt — beim nächsten Öffnen desselben Batches wird stattdessen
/// genau an dieser Stelle fortgesetzt.
class QuizSession {
  const QuizSession({
    required this.group,
    required this.batchIndex,
    required this.stage,
    required this.attempts,
    required this.stageResolvedWordIds,
    required this.finalWrongWordIds,
    required this.correctCount,
    required this.wrongCount,
  });

  final String group;
  final int batchIndex;

  /// Name des `QuizStage`-Enum-Werts (`QuizStage.name`) — als String
  /// persistiert, damit dieses Model nicht von `quiz_provider.dart`
  /// abhängen muss.
  final String stage;

  final Map<int, int> attempts;
  final Set<int> stageResolvedWordIds;
  final Set<int> finalWrongWordIds;
  final int correctCount;
  final int wrongCount;

  factory QuizSession.fromMap(Map<String, dynamic> map) {
    Map<int, int> decodeAttempts(String raw) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(int.parse(key), value as int));
    }

    Set<int> decodeIds(String raw) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e as int).toSet();
    }

    return QuizSession(
      group: map['group_name'] as String,
      batchIndex: map['batch_index'] as int,
      stage: map['stage'] as String,
      attempts: decodeAttempts(map['attempts'] as String),
      stageResolvedWordIds: decodeIds(map['stage_resolved'] as String),
      finalWrongWordIds: decodeIds(map['final_wrong'] as String),
      correctCount: map['correct_count'] as int,
      wrongCount: map['wrong_count'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_name': group,
      'batch_index': batchIndex,
      'stage': stage,
      'attempts': jsonEncode(
        attempts.map((key, value) => MapEntry(key.toString(), value)),
      ),
      'stage_resolved': jsonEncode(stageResolvedWordIds.toList()),
      'final_wrong': jsonEncode(finalWrongWordIds.toList()),
      'correct_count': correctCount,
      'wrong_count': wrongCount,
    };
  }
}
