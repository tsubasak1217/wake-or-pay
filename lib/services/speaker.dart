import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Says a line of Japanese out loud, over whatever else is playing.
///
/// An interface so the ringing screen's speech schedule can be tested without
/// a platform, and so a broken engine is a silent ring rather than no ring.
abstract class Speaker {
  Future<void> speak(String text);
  Future<void> stop();
}

/// Records what would have been said. Tests, and any platform without TTS.
class RecordingSpeaker implements Speaker {
  final spoken = <String>[];
  var stopped = 0;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopped++;
}

/// `flutter_tts`, in Japanese, layered on top of the alarm.
///
/// The one thing that matters here is `focus: false`. With it the plugin never
/// requests audio focus at all; with `focus: true` it asks for
/// AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK, which is Android's way of saying "quiet
/// everything else down" — and the thing it would quiet down is the alarm we
/// are trying to shout over. So: no focus request, and the queue set to add
/// rather than flush, so a line already in progress is finished instead of
/// being cut off by the next cue.
class TtsSpeaker implements Speaker {
  TtsSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  static const _queueAdd = 1;

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setLanguage('ja-JP');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    await _tts.setQueueMode(_queueAdd);
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    await _configure();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

/// Wraps [inner] so nothing it throws can reach the ring.
///
/// A ring that fails because the speech engine is missing, muted or busy would
/// be the worst bug this app could have. Every failure is swallowed, and the
/// speaker simply goes quiet.
class SafeSpeaker implements Speaker {
  const SafeSpeaker(this.inner);

  final Speaker inner;

  @override
  Future<void> speak(String text) async {
    try {
      await inner.speak(text);
    } on Object catch (e) {
      debugPrint('tts speak failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await inner.stop();
    } on Object catch (e) {
      debugPrint('tts stop failed: $e');
    }
  }
}

/// Recording by default so no test ever reaches the plugin; `main()` installs
/// the real one.
final speakerProvider = Provider<Speaker>((ref) => RecordingSpeaker());

Override ttsSpeakerOverride() =>
    speakerProvider.overrideWithValue(SafeSpeaker(TtsSpeaker()));
