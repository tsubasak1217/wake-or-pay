import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../../../services/voice_recorder.dart';

/// The bar the recorder draws itself on: a fixed
/// [maxContactRecordingDuration] wide, whatever is in it.
///
/// Everything on it is measured against that limit rather than against the
/// recording, so the knob is in the same place for the same number of seconds
/// whether it is being recorded or played back, and a 5 second recording
/// visibly is a fifth of a 25 second one.
///
/// [progress] is where the knob sits, 0..1 of the limit. [span] is how much of
/// the bar the recording occupies — the same thing while recording, and the
/// finished length once it has stopped.
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    super.key,
    required this.progress,
    required this.span,
    required this.waveform,
    this.active = false,
  });

  final double progress;
  final double span;

  /// Loudness 0..1, one per [contactWaveformInterval]. Empty draws a flat bar
  /// — a device that will not report the microphone level is not an error.
  final List<double> waveform;

  /// True while recording, which is the one state that gets the danger colour:
  /// the microphone is open and the user needs to be in no doubt about it.
  final bool active;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        key: const ValueKey('recordingBarPainter'),
        painter: RecordingBarPainter(
          progress: progress,
          span: span,
          waveform: waveform,
          accent: active ? scheme.error : scheme.primary,
          muted: scheme.onSurfaceVariant.withValues(alpha: 0.35),
          track: scheme.onSurfaceVariant.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

/// Draws the waveform, the track, the filled part of it, and the knob.
///
/// Written as one painter rather than a stack of widgets because all four are
/// the same measurement read four ways, and a knob that disagrees with its own
/// progress bar by a pixel is exactly the sort of thing a layout of nested
/// boxes produces.
class RecordingBarPainter extends CustomPainter {
  const RecordingBarPainter({
    required this.progress,
    required this.span,
    required this.waveform,
    required this.accent,
    required this.muted,
    required this.track,
  });

  final double progress;
  final double span;
  final List<double> waveform;
  final Color accent;
  final Color muted;
  final Color track;

  static const _trackHeight = 4.0;
  static const _knobRadius = 9.0;
  static const _barWidth = 3.0;

  /// Kept off zero so a silent moment is still a mark on the bar rather than a
  /// gap in it — the waveform is there to show that recording happened.
  static const _minBarHeight = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final clampedSpan = span.clamp(0.0, 1.0);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final mid = size.height / 2;
    // Inset by the knob so it cannot be drawn half outside the widget at
    // either end.
    final left = _knobRadius;
    final usable = (size.width - _knobRadius * 2).clamp(0.0, size.width);
    final playhead = left + usable * clampedProgress;

    _paintWaveform(canvas, size, left, usable, mid, clampedSpan, playhead);

    final trackPaint = Paint()
      ..color = track
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _trackHeight;
    canvas.drawLine(Offset(left, mid), Offset(left + usable, mid), trackPaint);
    if (clampedProgress > 0) {
      canvas.drawLine(
        Offset(left, mid),
        Offset(playhead, mid),
        trackPaint..color = accent,
      );
    }

    canvas
      ..drawCircle(Offset(playhead, mid), _knobRadius, Paint()..color = accent)
      ..drawCircle(
        Offset(playhead, mid),
        _knobRadius - 3,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
  }

  /// Vertical bars, centred on the track, spread over the part of the bar the
  /// recording occupies. Everything left of the knob is the accent colour.
  void _paintWaveform(
    Canvas canvas,
    Size size,
    double left,
    double usable,
    double mid,
    double span,
    double playhead,
  ) {
    if (waveform.isEmpty || span <= 0) return;
    final width = usable * span;
    final step = width / waveform.length;
    final maxHeight = size.height / 2 - 4;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;

    for (var i = 0; i < waveform.length; i++) {
      final x = left + step * (i + 0.5);
      final half = (_minBarHeight + waveform[i] * (maxHeight - _minBarHeight))
          .clamp(_minBarHeight, maxHeight);
      paint.color = x <= playhead ? accent.withValues(alpha: 0.55) : muted;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(RecordingBarPainter old) =>
      old.progress != progress ||
      old.span != span ||
      old.accent != accent ||
      old.muted != muted ||
      old.track != track ||
      !identical(old.waveform, waveform);
}

/// 電話設定 のカスタム録音: the bar, one wide button, and — once there is
/// something to play — a bin beside it.
///
/// The recorder and the player are reached through their interfaces and never
/// through the plugins, so a widget test drives the whole of this with fakes:
/// fed amplitudes, fed playback positions, no microphone anywhere.
///
/// The panel owns *transport* state (recording, playing, how long for) and
/// nothing else. The recording itself belongs to the screen above, which is
/// what hands it back to the alarm — so this reports a finished recording
/// upwards rather than keeping it.
class ContactRecorderPanel extends ConsumerStatefulWidget {
  const ContactRecorderPanel({
    super.key,
    required this.recordingPath,
    required this.waveform,
    required this.onRecorded,
    required this.onDeleted,
    this.alarmId,
  });

  final String? recordingPath;
  final List<double> waveform;

  /// A finished recording and the shape of it.
  final void Function(String path, List<double> waveform) onRecorded;

  final VoidCallback onDeleted;

  /// Only used to name the file.
  final String? alarmId;

  @override
  ConsumerState<ContactRecorderPanel> createState() =>
      _ContactRecorderPanelState();
}

class _ContactRecorderPanelState extends ConsumerState<ContactRecorderPanel> {
  /// How often the knob moves while recording. Four times the rate the
  /// waveform is sampled at, so the knob glides rather than stepping.
  static const _tick = Duration(milliseconds: 60);

  bool _recording = false;
  bool _playing = false;

  Duration _elapsed = Duration.zero;
  Duration _played = Duration.zero;

  /// The length of the finished recording, so the bar can show it after the
  /// stop. Zero when there is nothing recorded in this sitting — a recording
  /// read back off the alarm has its length taken from the waveform instead.
  Duration _recordedLength = Duration.zero;

  final _samples = <double>[];

  Timer? _ticker;
  StreamSubscription<double>? _amplitudes;
  StreamSubscription<bool>? _playbackState;
  StreamSubscription<Duration>? _playbackPosition;

  /// Shown under the buttons when the microphone was refused or would not open.
  String? _error;

  @override
  void initState() {
    super.initState();
    final player = ref.read(voicePlayerProvider);
    _playbackState = player.playing.listen((on) {
      if (!mounted) return;
      setState(() {
        _playing = on;
        // A finished playback puts the knob back at the start, so pressing 再生
        // again reads as starting over rather than resuming from the end.
        if (!on) _played = Duration.zero;
      });
    });
    _playbackPosition = player.position.listen((at) {
      if (mounted) setState(() => _played = at);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudes?.cancel();
    _playbackState?.cancel();
    _playbackPosition?.cancel();
    super.dispose();
  }

  bool get _hasRecording => widget.recordingPath != null;

  /// How long the recording runs. Measured while recording; afterwards taken
  /// from the number of samples, which is the only record of it that survives
  /// the screen being closed and reopened.
  Duration get _length {
    if (_recordedLength > Duration.zero) return _recordedLength;
    final samples = widget.waveform.length;
    if (samples == 0) return Duration.zero;
    return contactWaveformInterval * samples;
  }

  double get _fraction {
    if (_recording) return _ratio(_elapsed);
    if (_playing) return _ratio(_played);
    return _ratio(_length);
  }

  double get _span => _recording ? _ratio(_elapsed) : _ratio(_length);

  static double _ratio(Duration d) =>
      (d.inMilliseconds / maxContactRecordingDuration.inMilliseconds).clamp(
        0.0,
        1.0,
      );

  List<double> get _shownWaveform => _recording ? _samples : widget.waveform;

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _start() async {
    final recorder = ref.read(voiceRecorderProvider);
    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      _showError('マイクの使用が許可されていないため録音できません。端末の設定から許可してください。');
      return;
    }
    // Allocating the file and opening the microphone are the two places this
    // can fail on a real device — no storage, or the mic already held by a
    // call. Either way the screen says so instead of throwing under the tap.
    try {
      final path = await ref.read(contactRecordingPathProvider)(widget.alarmId);
      await recorder.start(path);
      _pending = path;
    } catch (_) {
      if (!mounted) return;
      _showError('録音を開始できませんでした。ほかのアプリがマイクを使っていないか確認してください。');
      return;
    }
    if (!mounted) return;

    // The waveform is decoration and the recording is not: it is subscribed to
    // after the recorder is already running, it is never awaited, and an
    // implementation that emits nothing simply leaves the bar flat.
    _amplitudes?.cancel();
    _amplitudes = recorder.amplitude.listen((level) {
      if (_samples.length < contactWaveformSamples) _samples.add(level);
    }, onError: (Object _) {});

    setState(() {
      _recording = true;
      _error = null;
      _elapsed = Duration.zero;
      _recordedLength = Duration.zero;
      _samples.clear();
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      final next = _elapsed + _tick;
      // The limit is the limit: it stops itself rather than trusting the user
      // to, which is the whole point of having one.
      if (next >= maxContactRecordingDuration) {
        setState(() => _elapsed = maxContactRecordingDuration);
        unawaited(_stop());
        return;
      }
      setState(() => _elapsed = next);
    });
  }

  /// The path handed to the recorder, kept so a stop that reports nothing back
  /// still has a file to name. Some platforms return null from `stop`.
  String? _pending;

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    _ticker = null;
    final length = _elapsed;
    final samples = List<double>.unmodifiable(_samples);
    final path = await ref.read(voiceRecorderProvider).stop() ?? _pending;
    // Not awaited: closing a broadcast subscription is housekeeping, and the
    // screen must never wait a frame on it before it says 停止 happened.
    _amplitudes?.cancel().ignore();
    _amplitudes = null;
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordedLength = length;
    });
    // A stop that produced nothing leaves the previous recording alone: the
    // user has not asked for it to be thrown away, 削除 is how that is said.
    if (path != null) widget.onRecorded(path, samples);
  }

  Future<void> _play() async {
    final path = widget.recordingPath;
    if (path == null) return;
    setState(() => _played = Duration.zero);
    await ref.read(voicePlayerProvider).play(path);
  }

  Future<void> _stopPlayback() async {
    await ref.read(voicePlayerProvider).stop();
    if (mounted) setState(() => _played = Duration.zero);
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('録音を削除しますか'),
        content: const Text(
          'この録音は端末から消えます。取り消せません。'
          '削除すると、電話は自動音声の文面を読み上げます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            key: const ValueKey('contactRecordDeleteConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(voicePlayerProvider).stop();
    if (!mounted) return;
    setState(() {
      _recordedLength = Duration.zero;
      _played = Duration.zero;
      _samples.clear();
    });
    widget.onDeleted();
  }

  String get _status {
    if (_recording) {
      final limit = _seconds(maxContactRecordingDuration);
      return '録音中 ${_seconds(_elapsed)} / $limit';
    }
    if (!_hasRecording) return '録音なし';
    if (_playing) return '再生中 ${_seconds(_played)} / ${_seconds(_length)}';
    return '録音あり ${_seconds(_length)}';
  }

  static String _seconds(Duration d) {
    final total = d.inMilliseconds / 1000;
    return '${total.toStringAsFixed(1)}秒';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecordingBar(
          progress: _fraction,
          span: _span,
          waveform: _shownWaveform,
          active: _recording,
        ),
        const SizedBox(height: 4),
        Text(
          _status,
          key: const ValueKey('contactRecordingStatus'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _recording ? theme.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: 12),
        if (!_hasRecording || _recording) _recordButton(theme) else _playRow(),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// One button doing both jobs: pressing it starts, and while it is running
  /// the same button under the same finger is the stop.
  Widget _recordButton(ThemeData theme) => SizedBox(
    width: double.infinity,
    child: _recording
        ? FilledButton.icon(
            key: const ValueKey('contactRecordStop'),
            onPressed: _stop,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
          )
        : FilledButton.icon(
            key: const ValueKey('contactRecordStart'),
            onPressed: _start,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.mic),
            label: const Text('録音開始'),
          ),
  );

  Widget _playRow() => Row(
    children: [
      Expanded(
        child: _playing
            ? FilledButton.icon(
                key: const ValueKey('contactRecordPause'),
                onPressed: _stopPlayback,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('停止'),
              )
            : FilledButton.icon(
                key: const ValueKey('contactRecordPlay'),
                onPressed: _play,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('再生'),
              ),
      ),
      const SizedBox(width: 8),
      IconButton.outlined(
        key: const ValueKey('contactRecordDelete'),
        tooltip: '録音を削除',
        onPressed: _confirmDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  );
}
