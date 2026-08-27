import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../domain/models.dart';

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

  /// How loud the microphone is, 0 (silence) to 1 (as loud as it goes), one
  /// reading every [contactWaveformInterval] while recording.
  ///
  /// **Never required.** Plenty of devices and emulators report nothing at all,
  /// and a recording that will not draw a waveform is still a recording — the
  /// bar is simply flat. An implementation that cannot do this returns a stream
  /// that emits nothing, and nothing waits on it.
  Stream<double> get amplitude;

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

  /// How far into the recording playback has got, so the knob on the bar can
  /// follow it. Emits nothing when the platform will not say.
  Stream<Duration> get position;

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

  /// The plugin reports dBFS: 0 is as loud as the format goes and it falls away
  /// without a floor, so a silent room reads as -120 or worse. [_quietDbfs] is
  /// where the scale is cut off — quieter than that is drawn as silence — and
  /// everything above it is spread over 0..1.
  ///
  /// The plugin's own stream only emits while it believes it is recording, and
  /// a platform that cannot answer `getAmplitude` simply never emits. Errors
  /// are swallowed for the same reason: a waveform is decoration, and nothing
  /// about it may take the recording down with it.
  static const _quietDbfs = -45.0;

  @override
  Stream<double> get amplitude => _recorder
      .onAmplitudeChanged(contactWaveformInterval)
      .map((a) {
        final db = a.current;
        if (!db.isFinite) return 0.0;
        return ((db - _quietDbfs) / -_quietDbfs).clamp(0.0, 1.0).toDouble();
      })
      .handleError((Object _) {});

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
  Stream<Duration> get position => _player.onPositionChanged;

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
