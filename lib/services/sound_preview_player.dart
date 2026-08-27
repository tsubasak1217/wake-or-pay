import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sound_library.dart';

/// Plays a sound so the user can hear it before choosing it.
///
/// An interface, not the plugin, so widget tests can drive the sound screen
/// without an audio device underneath.
abstract class SoundPreviewPlayer {
  /// Starts [soundId], replacing whatever was playing.
  Future<void> play(String soundId);

  Future<void> stop();

  Future<void> dispose();
}

/// audioplayers takes asset paths relative to its own `assets/` prefix, so the
/// prefix has to come off the paths the library stores. Pure.
String previewAssetPath(String assetPath) =>
    assetPath.startsWith('assets/') ? assetPath.substring(7) : assetPath;

class AudioPlayersSoundPreviewPlayer implements SoundPreviewPlayer {
  AudioPlayersSoundPreviewPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String soundId) async {
    await _player.stop();
    // A preview is a preview: it plays once, at media volume, and stops. The
    // alarm itself is the only thing that loops and shouts.
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.play(
      isDeviceSound(soundId)
          ? DeviceFileSource(deviceSoundPathOf(soundId))
          : AssetSource(previewAssetPath(soundPathFor(soundId))),
    );
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final soundPreviewPlayerProvider = Provider<SoundPreviewPlayer>((ref) {
  final player = AudioPlayersSoundPreviewPlayer();
  ref.onDispose(player.dispose);
  return player;
});
