import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Records the user's own voice for the oversleep contact.
///
/// An interface, not the plugin, so the contact sub-screen can be driven in a
/// widget test without a microphone underneath — the same shape
/// [SoundPreviewPlayer] already uses for playback.
abstract class VoiceRecorder {
  /// True when recording may start. Implementations are allowed to prompt.
  Future<bool> hasPermission();

  /// Starts writing to [path], which the caller has already chosen.
  Future<void> start(String path);

  /// Stops and returns the file that was written, or null if nothing was.
  Future<String?> stop();

  Future<void> dispose();
}

/// Plays back a recorded file. Separate from [SoundPreviewPlayer] because that
/// one speaks in sound ids from the library, and a recording is a bare path.
abstract class VoicePlayer {
  Future<void> play(String path);

  Future<void> stop();

  /// True while a recording is audible, so the screen can show 再生中 and offer
  /// a stop instead of a second play.
  Stream<bool> get playing;

  Future<void> dispose();
}

/// Where a new recording is written.
///
/// Under the application *support* directory rather than a cache: this file is
/// the original — nothing else on the device holds a copy — and a cache the OS
/// decides to reclaim would silently empty an alarm's contact recording. The
/// timestamp keeps two recordings of the same alarm apart.
typedef ContactRecordingPathBuilder = Future<String> Function(String? alarmId);

Future<String> newContactRecordingPath(String? alarmId) async {
  final directory = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'contact_recordings'),
  );
  await directory.create(recursive: true);
  return p.join(
    directory.path,
    '${alarmId ?? 'contact'}-${DateTime.now().millisecondsSinceEpoch}.m4a',
  );
}

class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() async {
    // permission_handler first: it is what the rest of the app uses, so a
    // denial here is the same denial the user can undo from the app's settings
    // page. The plugin's own check then confirms the recorder agrees.
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
    return _recorder.hasPermission();
  }

  @override
  Future<void> start(String path) => _recorder.start(
    // AAC in an m4a container: the default of the plugin, and the encoder that
    // is present on every Android version the app supports.
    const RecordConfig(encoder: AudioEncoder.aacLc),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}

class AudioPlayersVoicePlayer implements VoicePlayer {
  AudioPlayersVoicePlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String path) async {
    await _player.stop();
    // Once, like the sound preview: only the alarm itself loops.
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<bool> get playing =>
      _player.onPlayerStateChanged.map((state) => state == PlayerState.playing);

  @override
  Future<void> dispose() => _player.dispose();
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = RecordVoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

final voicePlayerProvider = Provider<VoicePlayer>((ref) {
  final player = AudioPlayersVoicePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Injected rather than called directly so a widget test can name a
/// destination without a path_provider platform channel behind it.
final contactRecordingPathProvider = Provider<ContactRecordingPathBuilder>(
  (ref) => newContactRecordingPath,
);
