import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:audioplayers_platform_interface/src/audioplayers_platform.dart';
import 'package:audioplayers_platform_interface/src/global_audioplayers_platform.dart';

/// Task F1 — Deterministische No-op-Plattform für audioplayers im Widget-Test.
///
/// ersetzt die echten `audioplayers`-Plattform-Interfaces, damit der
/// `AudioPlayer`-Konstruktor (in `AudioService`) gar keine Platform-Kanaele
/// (MethodChannel/EventChannel) beruehrt. Ohne diese Fake wirft der
/// `AudioPlayer` beim ersten Erzeugen eine MissingPluginException auf den
/// EventStreams `xyz.luan/audioplayers.global/events` und
/// `xyz.luan/audioplayers/events/<playerId>` (dynamischer Kanalname), die den
/// Widget-Test sonst abbrechen wuerde. Wiedergabe wird in den Tests nie
/// gestartet — daher genuegen No-op-Implementierungen.
class FakeAudioplayersPlatform extends AudioplayersPlatform {
  @override
  Future<void> create(String playerId) async {}

  @override
  Future<void> dispose(String playerId) async {}

  @override
  Future<void> stop(String playerId) async {}

  @override
  Future<void> pause(String playerId) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) => const Stream.empty();

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;
}

class FakeGlobalAudioplayersPlatform extends GlobalAudioplayersPlatform {
  @override
  Future<void> init() async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}