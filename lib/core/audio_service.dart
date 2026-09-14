import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/sentence.dart';
import '../screens/learn/learn_audio_constants.dart';

/// Ein einziger, zentral verwalteter Audio-Player für die vorab generierten
/// MP3-Sätze. Erhält dabei genau eine Audio-Instanz, trackt aber, welcher Satz
/// aktuell abgespielt wird, und meldet sich über [ChangeNotifier] — so können
/// die Play-/Stop-Buttons automatisch das Ende der Wiedergabe erkennen und
/// wieder auf "Play" springen (statt dauerhaft "Stop" zu zeigen).
class AudioService extends ChangeNotifier {
  AudioService._() {
    _player.onPlayerComplete.listen((_) => _onPlaybackFinished());
  }

  static final AudioService instance = AudioService._();
  final AudioPlayer _player = AudioPlayer();

  /// Schlüssel des aktuell abgespielten Satzes (word_id:satzIndex),
  /// oder `null`, wenn gerade nichts läuft.
  String? _activeKey;

  String _key(Sentence sentence, int sentenceIndex) =>
      '${sentence.wordId}:$sentenceIndex';

  /// Ob genau dieser Satz gerade abgespielt wird.
  bool isPlaying(Sentence sentence, int sentenceIndex) =>
      _activeKey == _key(sentence, sentenceIndex);

  String _assetPath(Sentence sentence, int sentenceIndex) {
    final lesson = (sentence.wordId - 1) ~/ sentencesPerLesson + 1;
    final firstWordOfLesson = (lesson - 1) * sentencesPerLesson + 1;
    final positionInLesson = (sentence.wordId - firstWordOfLesson)
            * sentencesPerWord
        + sentenceIndex;
    final fileNumber = positionInLesson + 1;
    return 'audio/lektion_$lesson/$fileNumber.mp3';
  }

  /// Spielt die Audio-Datei zum Kontext-Satz ab und markiert ihn als aktiv.
  /// [sentenceIndex] ist der 0-basierte Index des Satzes innerhalb der Sätze
  /// desselben Worts (0, 1 oder 2).
  Future<void> playSentence(Sentence sentence, int sentenceIndex) async {
    _activeKey = _key(sentence, sentenceIndex);
    notifyListeners();
    await _player.play(AssetSource(_assetPath(sentence, sentenceIndex)));
  }

  Future<void> stop() async {
    _activeKey = null;
    notifyListeners();
    await _player.stop();
  }

  /// Wird bei natürlichem Ende der Wiedergabe aufgerufen (nicht bei manuellem
  /// Stopp — dort wird [stop] verwendet und das Icon direkt umgeschaltet).
  void _onPlaybackFinished() {
    _activeKey = null;
    notifyListeners();
  }
}