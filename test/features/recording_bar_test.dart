import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/widgets/recording_bar.dart';
import 'package:wake_or_pay/services/voice_recorder.dart';

import '../helpers.dart';

late FakeVoiceRecorder recorder;
late FakeVoicePlayer player;

/// The panel on its own, with the screen above it replaced by two variables:
/// this is exactly the split the real screen makes, so driving it this way
/// tests the panel and not a screenful of unrelated islands.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? path;
  List<double> waveform = const [];

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ContactRecorderPanel(
          alarmId: 'a1',
          recordingPath: path,
          waveform: waveform,
          onRecorded: (p, w) => setState(() {
            path = p;
            waveform = w;
          }),
          onDeleted: () => setState(() {
            path = null;
            waveform = const [];
          }),
        ),
      ),
    ),
  );
}

Future<ProviderContainer> pumpPanel(
  WidgetTester tester, {
  FakeVoiceRecorder? withRecorder,
}) async {
  recorder = withRecorder ?? FakeVoiceRecorder();
  player = FakeVoicePlayer();
  final container = await testContainer(
    extra: [
      voiceRecorderProvider.overrideWithValue(recorder),
      voicePlayerProvider.overrideWithValue(player),
      contactRecordingPathProvider.overrideWithValue(
        (alarmId) async => '/tmp/wake_or_pay_test/$alarmId-recording.m4a',
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const _Host()),
  );
  await tester.pumpAndSettle();
  return container;
}

String status(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('contactRecordingStatus')))
    .data!;

bool hasBar(WidgetTester tester) =>
    find.byKey(const ValueKey('recordingBarPainter')).evaluate().isNotEmpty;

RecordingBarPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('recordingBarPainter')),
            )
            .painter!
        as RecordingBarPainter;

void main() {
  group('the painter', () {
    test('a flat bar is drawn when nothing was sampled', () {
      const p = RecordingBarPainter(
        progress: 0.5,
        span: 0.5,
        waveform: [],
        accent: Colors.red,
        muted: Colors.grey,
        track: Colors.black12,
      );
      // Nothing to draw and nothing to crash on: the track and the knob are
      // still painted, which is what "flat" means here.
      final recorderCanvas = _CountingCanvas();
      p.paint(recorderCanvas.canvas, const Size(300, 64));
      expect(recorderCanvas.lines, 2, reason: 'the track and the filled part');
      expect(recorderCanvas.circles, 2, reason: 'the knob');
    });

    test('one line per sample, on top of the track', () {
      final p = RecordingBarPainter(
        progress: 1,
        span: 1,
        waveform: List<double>.filled(contactWaveformSamples, 0.5),
        accent: Colors.red,
        muted: Colors.grey,
        track: Colors.black12,
      );
      final canvas = _CountingCanvas();
      p.paint(canvas.canvas, const Size(300, 64));
      expect(canvas.lines, contactWaveformSamples + 2);
      expect(canvas.circles, 2);
    });

    test('a sample outside 0..1 cannot paint outside the widget', () {
      final p = RecordingBarPainter(
        progress: 3,
        span: -1,
        waveform: normalizeWaveform([5.0, -2.0, double.nan]),
        accent: Colors.red,
        muted: Colors.grey,
        track: Colors.black12,
      );
      final canvas = _BoundsCanvas();
      p.paint(canvas.canvas, const Size(300, 64));
      expect(canvas.maxX, lessThanOrEqualTo(300));
      expect(canvas.minY, greaterThanOrEqualTo(0));
      expect(canvas.maxY, lessThanOrEqualTo(64));
    });

    test('normalizeWaveform clamps, drops the excess and kills NaN', () {
      expect(normalizeWaveform([1.5, -0.2, 0.4]), [1.0, 0.0, 0.4]);
      expect(normalizeWaveform([double.nan]), [0.0]);
      expect(
        normalizeWaveform(List<double>.filled(contactWaveformSamples + 40, 1)),
        hasLength(contactWaveformSamples),
      );
    });
  });

  group('the panel', () {
    testWidgets('starts with no recording and no bar at all', (tester) async {
      await pumpPanel(tester);
      expect(status(tester), '録音なし');
      expect(find.byKey(const ValueKey('contactRecordStart')), findsOneWidget);
      expect(find.byKey(const ValueKey('contactRecordStop')), findsNothing);
      expect(find.byKey(const ValueKey('contactRecordPlay')), findsNothing);
      expect(find.byKey(const ValueKey('contactRecordDelete')), findsNothing);
      expect(hasBar(tester), isFalse, reason: 'nothing to seek through yet');
    });

    testWidgets('the bar appears with the first recording and then stays', (
      tester,
    ) async {
      await pumpPanel(tester);
      expect(hasBar(tester), isFalse);

      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();
      expect(hasBar(tester), isTrue, reason: 'it is running towards the limit');

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
      expect(hasBar(tester), isTrue, reason: 'there is a recording to play');
    });

    testWidgets('while recording the bar is the 30 second limit', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));

      expect(painter(tester).progress, closeTo(0.5, 0.01), reason: '15 of 30');
      expect(painter(tester).span, closeTo(0.5, 0.01));
    });

    testWidgets('after the stop the bar is the recording, not the limit', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();

      // 6 of 30 seconds while it ran; the whole bar once it is a recording.
      expect(painter(tester).span, 1.0, reason: 'the waveform spans the width');
      expect(painter(tester).progress, 1.0, reason: 'the knob is at the end');

      await tester.tap(find.byKey(const ValueKey('contactRecordPlay')));
      await tester.pumpAndSettle();
      player.emitPosition(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        painter(tester).progress,
        closeTo(0.5, 0.02),
        reason: 'halfway through a 6 second recording is halfway along',
      );

      player.emitPosition(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(painter(tester).progress, 1.0, reason: 'the end is the right edge');
    });

    testWidgets('録音開始 becomes 停止, and the knob moves while it runs', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();

      expect(recorder.started, hasLength(1));
      expect(find.byKey(const ValueKey('contactRecordStart')), findsNothing);
      expect(find.byKey(const ValueKey('contactRecordStop')), findsOneWidget);
      expect(find.text('停止'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      final moved = painter(tester).progress;
      expect(moved, greaterThan(0.15));
      expect(moved, lessThan(0.25), reason: '6 of 30 seconds');
      expect(status(tester), contains('録音中'));

      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
      expect(recorder.stopped, 1);
      expect(status(tester), contains('録音あり'));
      expect(find.byKey(const ValueKey('contactRecordPlay')), findsOneWidget);
      expect(find.byKey(const ValueKey('contactRecordDelete')), findsOneWidget);
    });

    testWidgets('it stops itself at the limit', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();

      await tester.pump(maxContactRecordingDuration);
      await tester.pumpAndSettle();

      expect(recorder.stopped, 1, reason: 'nobody pressed 停止');
      expect(find.byKey(const ValueKey('contactRecordStop')), findsNothing);
      expect(painter(tester).progress, 1.0);
      expect(status(tester), contains('30.0秒'));
    });

    testWidgets('the amplitudes it is fed become the waveform', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();

      for (final level in [0.1, 0.9, 0.4, 0.7]) {
        recorder.emitAmplitude(level);
        await tester.pump(contactWaveformInterval);
      }
      expect(painter(tester).waveform, [0.1, 0.9, 0.4, 0.7]);

      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
      expect(painter(tester).waveform, [
        0.1,
        0.9,
        0.4,
        0.7,
      ], reason: 'kept once the recording is finished');
    });

    testWidgets('a platform that reports no levels still records', (
      tester,
    ) async {
      await pumpPanel(tester, withRecorder: SilentAmplitudeRecorder());
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();

      expect(recorder.started, hasLength(1));
      expect(status(tester), contains('録音あり'));
      expect(
        painter(tester).waveform,
        isEmpty,
        reason: 'a flat bar, not a bug',
      );
    });

    testWidgets('▶ becomes ■ and the knob follows the position', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('contactRecordPlay')));
      await tester.pumpAndSettle();
      expect(player.played, ['/tmp/wake_or_pay_test/a1-recording.m4a']);
      expect(find.byKey(const ValueKey('contactRecordPause')), findsOneWidget);
      expect(find.byKey(const ValueKey('contactRecordPlay')), findsNothing);

      player.emitPosition(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      // Half of the 10 second recording, on the recording's own scale.
      expect(painter(tester).progress, closeTo(0.5, 0.02));
      expect(status(tester), contains('再生中'));

      player.finish();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('contactRecordPlay')), findsOneWidget);
    });

    testWidgets('the bin asks first, and only then throws it away', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      recorder.emitAmplitude(0.6);
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('contactRecordDelete')));
      await tester.pumpAndSettle();
      expect(find.text('録音を削除しますか'), findsOneWidget);

      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();
      expect(status(tester), contains('録音あり'), reason: 'nothing was deleted');

      await tester.tap(find.byKey(const ValueKey('contactRecordDelete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('contactRecordDeleteConfirm')),
      );
      await tester.pumpAndSettle();

      expect(status(tester), '録音なし');
      expect(find.byKey(const ValueKey('contactRecordStart')), findsOneWidget);
      expect(find.byKey(const ValueKey('contactRecordDelete')), findsNothing);
      expect(hasBar(tester), isFalse, reason: 'back to the idle panel');
    });

    testWidgets('a refused microphone says so and records nothing', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        withRecorder: FakeVoiceRecorder(permitted: false),
      );
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();

      expect(recorder.permissionAsked, 1);
      expect(recorder.started, isEmpty);
      expect(status(tester), '録音なし');
      expect(find.textContaining('マイクの使用が許可されていない'), findsWidgets);
      expect(find.byKey(const ValueKey('contactRecordStop')), findsNothing);
    });
  });
}

/// Counts what a painter drew. `Canvas` is final, so this records through a
/// recorder rather than subclassing it.
class _CountingCanvas {
  _CountingCanvas() {
    _recorder = ui.PictureRecorder();
    canvas = _TallyCanvas(_recorder, this);
  }

  late final ui.PictureRecorder _recorder;
  late final Canvas canvas;
  int lines = 0;
  int circles = 0;
}

class _TallyCanvas implements Canvas {
  _TallyCanvas(ui.PictureRecorder recorder, this._tally)
    : _inner = Canvas(recorder);

  final Canvas _inner;
  final _CountingCanvas _tally;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _tally.lines++;
    _inner.drawLine(p1, p2, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _tally.circles++;
    _inner.drawCircle(c, radius, paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not drawn here');
}

/// Remembers the extremes of everything drawn, so a bad sample that painted
/// outside the widget would show up as a coordinate off the edge.
class _BoundsCanvas {
  _BoundsCanvas() {
    canvas = _ExtentCanvas(ui.PictureRecorder(), this);
  }

  late final Canvas canvas;
  double maxX = 0;
  double minY = double.infinity;
  double maxY = 0;

  void see(Offset p) {
    maxX = p.dx > maxX ? p.dx : maxX;
    minY = p.dy < minY ? p.dy : minY;
    maxY = p.dy > maxY ? p.dy : maxY;
  }
}

class _ExtentCanvas implements Canvas {
  _ExtentCanvas(ui.PictureRecorder recorder, this._bounds)
    : _inner = Canvas(recorder);

  final Canvas _inner;
  final _BoundsCanvas _bounds;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _bounds
      ..see(p1)
      ..see(p2);
    _inner.drawLine(p1, p2, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _bounds
      ..see(c.translate(radius, radius))
      ..see(c.translate(-radius, -radius));
    _inner.drawCircle(c, radius, paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not drawn here');
}
