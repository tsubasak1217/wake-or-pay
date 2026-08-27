import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/voice_recorder.dart';

import '../helpers.dart';

/// A recorder that never touches a microphone: it remembers the path it was
/// asked to write and hands the same one back from [stop].
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.permitted = true});

  final bool permitted;
  final started = <String>[];
  int permissionAsked = 0;

  String? _current;

  @override
  Future<bool> hasPermission() async {
    permissionAsked++;
    return permitted;
  }

  @override
  Future<void> start(String path) async {
    started.add(path);
    _current = path;
  }

  @override
  Future<String?> stop() async {
    final path = _current;
    _current = null;
    return path;
  }

  @override
  Future<void> dispose() async {}
}

class FakeVoicePlayer implements VoicePlayer {
  final played = <String>[];
  final _playing = StreamController<bool>.broadcast();

  @override
  Future<void> play(String path) async {
    played.add(path);
    _playing.add(true);
  }

  @override
  Future<void> stop() async => _playing.add(false);

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Future<void> dispose() async => _playing.close();
}

/// The editor's own scroll view; the time wheel brings scrollables of its own.
Finder get editorScrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// scrollUntilVisible only ever scrolls one way, so anything already above the
/// viewport would be scrolled further away. Start from the top every time.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  tester.state<ScrollableState>(editorScrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: editorScrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> toggle(WidgetTester tester, String label) async {
  await scrollTo(tester, find.text(label));
  await tester.tap(find.widgetWithText(SwitchListTile, label));
  await tester.pumpAndSettle();
}

Future<void> inContactScreen(
  WidgetTester tester,
  Future<void> Function() inside,
) async {
  await scrollTo(tester, find.text('寝坊時連絡先'));
  await tester.tap(find.text('寝坊時連絡先'));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

late FakeVoiceRecorder recorder;
late FakeVoicePlayer player;

Future<ProviderContainer> openNewAlarm(
  WidgetTester tester, {
  bool micPermitted = true,
}) async {
  recorder = FakeVoiceRecorder(permitted: micPermitted);
  player = FakeVoicePlayer();
  final container = await testContainer(
    extra: [
      fakeAlarmServiceOverride(),
      voiceRecorderProvider.overrideWithValue(recorder),
      voicePlayerProvider.overrideWithValue(player),
      // A fixed name instead of the real one, so the test never reaches
      // path_provider — and never writes anything to the machine.
      contactRecordingPathProvider.overrideWithValue(
        (alarmId) async => '/tmp/wake_or_pay_test/$alarmId-recording.m4a',
      ),
    ],
  );
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 100000));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  return container;
}

Future<Alarm> save(WidgetTester tester, ProviderContainer container) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  return (await container.read(alarmRepositoryProvider).getAll()).single;
}

String statusText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('contactRecordingStatus')))
    .data!;

void main() {
  setUp(() {
    // Tall enough that every field of the contact screen is built and hit
    // testable at once; the sub-screen's list is long.
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('the row lives in 覚悟の設定 and starts at なし', (tester) async {
    await openNewAlarm(tester);
    expect(find.text('寝坊時連絡先'), findsNothing, reason: '覚悟 is off');

    await toggle(tester, '覚悟');
    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('寝坊時連絡先'), findsOneWidget);
    expect(find.text('なし'), findsOneWidget);

    await toggle(tester, '覚悟');
    expect(find.text('寝坊時連絡先'), findsNothing);
  });

  testWidgets('name, phone, message and timing are saved onto the alarm', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      expect(find.text('寝坊時連絡先'), findsOneWidget, reason: 'the app bar');
      await tester.enterText(find.byKey(const ValueKey('contactName')), '田中太郎');
      await tester.enterText(
        find.byKey(const ValueKey('contactPhone')),
        '090-1234-5678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('contactEmail')),
        'taro@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('contactMessage')),
        '起きられませんでした。起こしてください。',
      );
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '15',
      );
      await tester.pumpAndSettle();
    });

    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('田中太郎'), findsOneWidget, reason: 'the row shows the name');

    final contact = (await save(tester, container)).contact!;
    expect(contact.name, '田中太郎');
    expect(contact.phone, '090-1234-5678');
    expect(contact.email, 'taro@example.com');
    expect(contact.message, '起きられませんでした。起こしてください。');
    expect(contact.triggerMinutesAfterGrace, 15);
  });

  testWidgets('a timing above 60 is clamped down, not rejected', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await tester.enterText(find.byKey(const ValueKey('contactName')), '母');
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '999',
      );
      await tester.pumpAndSettle();
    });
    expect(
      (await save(tester, container)).contact!.triggerMinutesAfterGrace,
      60,
    );
  });

  testWidgets('a timing of 0 is clamped up to 1', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await tester.enterText(find.byKey(const ValueKey('contactName')), '母');
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '0',
      );
      await tester.pumpAndSettle();
    });
    expect(
      (await save(tester, container)).contact!.triggerMinutesAfterGrace,
      1,
      reason: 'nobody is contacted the instant the grace runs out',
    );
  });

  testWidgets('clearing the name removes the contact entirely', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await tester.enterText(find.byKey(const ValueKey('contactName')), '母');
      await tester.pumpAndSettle();
    });
    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('母'), findsOneWidget);

    await inContactScreen(tester, () async {
      await tester.enterText(find.byKey(const ValueKey('contactName')), '   ');
      await tester.pumpAndSettle();
    });

    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('なし'), findsOneWidget);
    expect((await save(tester, container)).contact, isNull);
  });

  testWidgets('record then stop stores the recorded file', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await tester.enterText(find.byKey(const ValueKey('contactName')), '母');
      expect(statusText(tester), '録音なし');

      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();
      expect(statusText(tester), '録音中');
      expect(recorder.started, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
      expect(statusText(tester), '録音あり');
    });

    expect(
      (await save(tester, container)).contact!.recordingPath,
      recorder.started.single,
    );
  });

  testWidgets('削除 plays back then throws the recording away', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await tester.enterText(find.byKey(const ValueKey('contactName')), '母');
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
    });

    await inContactScreen(tester, () async {
      expect(statusText(tester), '録音あり', reason: 'read back off the draft');
      await tester.tap(find.byKey(const ValueKey('contactRecordPlay')));
      await tester.pumpAndSettle();
      expect(player.played, [recorder.started.single]);

      await tester.tap(find.byKey(const ValueKey('contactRecordDelete')));
      await tester.pumpAndSettle();
      expect(statusText(tester), '録音なし');
    });

    final after = (await save(tester, container)).contact!;
    expect(after.recordingPath, isNull);
    expect(after.name, '母', reason: 'only the recording was deleted');
  });

  testWidgets('a refused microphone says so in Japanese and records nothing', (
    tester,
  ) async {
    final container = await openNewAlarm(tester, micPermitted: false);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await tester.enterText(find.byKey(const ValueKey('contactName')), '母');
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();

      expect(recorder.permissionAsked, 1);
      expect(recorder.started, isEmpty);
      expect(statusText(tester), '録音なし');
      expect(find.textContaining('マイクの使用が許可されていない'), findsWidgets);
    });

    expect((await save(tester, container)).contact!.recordingPath, isNull);
  });
}
