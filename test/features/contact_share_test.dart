import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/widgets/settings_island.dart';
import 'package:wake_or_pay/features/widgets/discord_icon.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/voice_recorder.dart';

import '../helpers.dart';

/// 寝坊時連絡・共有 — the one row in 覚悟の設定 that everything about telling
/// somebody now hangs off, and the screen behind it.
///
/// The screen exists because 送信タイミング is **one number for both halves**: a
/// personal call and a Discord post about the same overslept alarm going out
/// at different times would be two events about one morning. So the delay
/// lives on the alarm, and this is where it is set.

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

/// Picks a 人質 in the sub-screen behind the 人質 row. A new pledge starts at
/// 「なし」, which hides every money row of the island.
Future<void> chooseHostage(WidgetTester tester, String label) async {
  await scrollTo(tester, find.text('人質'));
  await tester.tap(find.text('人質'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// 覚悟の設定 → 寝坊時連絡・共有, and back out again.
Future<void> inContactShareScreen(
  WidgetTester tester,
  Future<void> Function() inside,
) async {
  await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
  await tester.tap(find.byKey(const ValueKey('contactShareRow')));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// One level deeper, through whichever row [key] names — 寝坊時連絡先, 寝坊の共有
/// or 送信タイミング.
Future<void> inRow(
  WidgetTester tester,
  String key,
  Future<void> Function() inside,
) => inContactShareScreen(tester, () async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
});

/// The labels of one island's rows, in the order they are drawn.
List<String> islandRows(WidgetTester tester, String title) => tester
    .widgetList<SettingRow>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SettingsIsland && w.title == title,
        ),
        matching: find.byType(SettingRow),
      ),
    )
    .map((row) => row.label)
    .toList();

/// The value shown on the right of a [SettingRow].
String rowValue(WidgetTester tester, String key) =>
    tester.widget<SettingRow>(find.byKey(ValueKey(key))).value;

late FakeVoiceRecorder recorder;
late FakeVoicePlayer player;

Future<void> seedBook(ProviderContainer container) => container
    .read(contactBookRepositoryProvider)
    .save(
      ContactEntry(
        id: 'c1',
        name: '田中太郎',
        reading: 'たなかたろう',
        phone: '090-1234-5678',
        email: 'taro@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );

Future<void> seedWebhook(ProviderContainer container) => container
    .read(discordWebhookRepositoryProvider)
    .save(
      DiscordWebhook(
        id: 'w1',
        url: 'https://discord.com/api/webhooks/1/abc',
        displayName: 'みんなのサーバー/#一般',
        createdAt: DateTime(2026, 1, 1),
      ),
    );

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
  await seedBook(container);
  await seedWebhook(container);
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

/// Picks 田中太郎 through 寝坊時連絡先, from the editor.
Future<void> pickContact(WidgetTester tester) =>
    inRow(tester, 'contactRow', () async {
      await tester.tap(find.byKey(const ValueKey('contactPickRow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('田中太郎'));
      await tester.pumpAndSettle();
    });

/// Ticks the one seeded 共有先, from the editor.
Future<void> pickWebhook(WidgetTester tester) =>
    inRow(tester, 'shareRow', () async {
      await tester.tap(find.byKey(const ValueKey('shareDiscordRow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webhook-w1')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

String statusText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('contactRecordingStatus')))
    .data!;

void main() {
  setUp(() {
    // Tall enough that every row of every sub-screen is built and hit testable
    // at once; these lists are long.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('覚悟の設定 lists its six rows, 人質 first', (tester) async {
    await openNewAlarm(tester);
    // スヌーズ is on by default now, so the スヌーズペナルティ row is there already.
    // The 人質 has to be named too: a new pledge starts at 「なし」, which hides
    // every money row below it.
    await toggle(tester, '覚悟');
    await chooseHostage(tester, 'コイン');
    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));

    expect(islandRows(tester, '覚悟の設定'), [
      '人質',
      '寝坊時連絡・共有',
      '起床猶予',
      '寝坊ペナルティ',
      'スヌーズペナルティ',
      '上限金額',
    ]);
    expect(
      find.text('寝坊で失う最大金額'),
      findsOneWidget,
      reason: 'the header above the rows is unchanged',
    );
  });

  testWidgets('スヌーズペナルティ is not listed when the alarm cannot be snoozed', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await chooseHostage(tester, 'コイン');
    // Off: new alarms are snoozeable now, and this test is the other case.
    await toggle(tester, 'スヌーズ');
    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));

    expect(islandRows(tester, '覚悟の設定'), [
      '人質',
      '寝坊時連絡・共有',
      '起床猶予',
      '寝坊ペナルティ',
      '上限金額',
    ]);
  });

  testWidgets('the row reads なし until somebody is actually reachable', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
    expect(rowValue(tester, 'contactShareRow'), 'なし');

    // Opening the screen and walking straight back out changes nothing: it is
    // a person or a 共有先 that makes it 設定済み, not a visit.
    await inContactShareScreen(tester, () async {
      expect(rowValue(tester, 'contactRow'), 'なし');
      expect(rowValue(tester, 'shareRow'), 'なし');
      expect(rowValue(tester, 'triggerRow'), '猶予後 3分');
    });
    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
    expect(rowValue(tester, 'contactShareRow'), 'なし');

    await pickContact(tester);
    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
    expect(
      rowValue(tester, 'contactShareRow'),
      '設定済み',
      reason: 'a name would leave a share-only alarm reading なし',
    );

    expect((await save(tester, container)).contact!.name, '田中太郎');
  });

  testWidgets('a 共有先 alone is enough to make the row 設定済み', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await pickWebhook(tester);
    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
    expect(rowValue(tester, 'contactShareRow'), '設定済み');

    await inContactShareScreen(tester, () async {
      expect(
        rowValue(tester, 'shareRow'),
        'Discord 1件',
        reason: 'the count, because the row stands for a room and not a person',
      );
      expect(rowValue(tester, 'contactRow'), 'なし', reason: 'nobody is called');
    });

    final alarm = await save(tester, container);
    expect(alarm.share!.webhookIds, {'w1'});
    expect(alarm.contact, isNull);
    expect(alarm.willShare, isTrue);
  });

  testWidgets('the timing runs 0-60 and 0 is the moment the grace ends', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await pickContact(tester);

    await inRow(tester, 'triggerRow', () async {
      expect(find.text('0〜60分'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '0',
      );
      await tester.pumpAndSettle();
    });
    await inContactShareScreen(tester, () async {
      expect(rowValue(tester, 'triggerRow'), '猶予後すぐ');
    });

    expect(
      (await save(tester, container)).triggerMinutes,
      0,
      reason: '0 is a real choice, and it lives on the alarm now',
    );
  });

  testWidgets('a timing above 60 is clamped down, not rejected', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inRow(tester, 'triggerRow', () async {
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '999',
      );
      await tester.pumpAndSettle();
    });

    expect((await save(tester, container)).triggerMinutes, 60);
  });

  testWidgets('the 共有 screen offers Discord and an X row nobody can press', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inRow(tester, 'shareRow', () async {
      expect(find.widgetWithText(AppBar, '寝坊共有設定'), findsOneWidget);
      expect(rowValue(tester, 'shareDiscordRow'), 'なし');
      // The Discord mark sits on the row, so the destination is recognisable
      // before the word is read.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shareDiscordRow')),
          matching: find.byType(DiscordIcon),
        ),
        findsOneWidget,
      );

      final x = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'X に投稿'),
      );
      expect(x.onChanged, isNull, reason: 'modelled, never offered in stage C');
      expect(x.value, isFalse);
      expect(find.text('まだ実装しない'), findsOneWidget);
    });
  });

  testWidgets('共有メッセージ設定 keeps the words the user wrote', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await pickWebhook(tester);

    await inRow(tester, 'shareRow', () async {
      expect(
        find.byKey(const ValueKey('shareMessage')),
        findsNothing,
        reason: 'デフォルト has nothing to write',
      );
      expect(
        previewOf(tester),
        contains('07:00'),
        reason: 'the example is drawn against a fixed hour',
      );

      await tester.tap(find.byKey(const ValueKey('shareModeCustom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('shareMessage')),
        '寝坊しました。起こしてください。',
      );
      await tester.pumpAndSettle();
    });

    final share = (await save(tester, container)).share!;
    expect(share.messageMode, MessageMode.custom);
    expect(share.message, '寝坊しました。起こしてください。');
  });

  // The recorder itself is unchanged — see recording_bar_test.dart — but it
  // hangs off 共有 now rather than off the contact, because the recording is
  // attached to the post and a call plays nothing.
  testWidgets('the recorder records onto the share, not onto the contact', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await pickWebhook(tester);

    await inRow(tester, 'shareRow', () async {
      expect(statusText(tester), '録音なし');
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();
      expect(statusText(tester), startsWith('録音中'));
      expect(recorder.started, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
      expect(statusText(tester), startsWith('録音あり'));
    });

    final alarm = await save(tester, container);
    expect(alarm.share!.recordingPath, recorder.started.single);
    expect(alarm.contact, isNull, reason: 'the contact never held a recording');
  });

  testWidgets('削除 plays back then throws the recording away', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');
    await pickWebhook(tester);

    await inRow(tester, 'shareRow', () async {
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
    });

    await inRow(tester, 'shareRow', () async {
      expect(
        statusText(tester),
        startsWith('録音あり'),
        reason: 'read back off the draft',
      );
      await tester.tap(find.byKey(const ValueKey('contactRecordPlay')));
      await tester.pumpAndSettle();
      expect(player.played, [recorder.started.single]);

      // 削除 asks first: it is the one button here that cannot be undone.
      await tester.tap(find.byKey(const ValueKey('contactRecordDelete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('contactRecordDeleteConfirm')),
      );
      await tester.pumpAndSettle();
      expect(statusText(tester), '録音なし');
    });

    final share = (await save(tester, container)).share!;
    expect(share.recordingPath, isNull);
    expect(
      share.webhookIds,
      {'w1'},
      reason: 'only the recording was deleted',
    );
  });

  testWidgets('a refused microphone says so in Japanese and records nothing', (
    tester,
  ) async {
    final container = await openNewAlarm(tester, micPermitted: false);
    await toggle(tester, '覚悟');
    await pickWebhook(tester);

    await inRow(tester, 'shareRow', () async {
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();

      expect(recorder.permissionAsked, 1);
      expect(recorder.started, isEmpty);
      expect(statusText(tester), '録音なし');
      expect(find.textContaining('マイクの使用が許可されていない'), findsWidgets);
    });

    expect((await save(tester, container)).share!.recordingPath, isNull);
  });
}

/// The 共有 preview, which only exists while デフォルト is chosen.
String previewOf(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('shareMessagePreview')))
    .data!;
