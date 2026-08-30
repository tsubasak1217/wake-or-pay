import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/format.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/widgets/swipe_to_delete.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

/// An alarm with money on it and somebody to call.
const kakugoAlarm = Alarm(
  id: 'a-kakugo',
  hour: 6,
  minute: 30,
  kakugo: Kakugo(ratePerMinute: 500, cap: 3000),
  contact: OversleepContact(
    contactId: 'c1',
    name: '田中太郎',
    phone: '090-1234-5678',
    email: 'taro@example.com',
    smsEnabled: true,
    emailEnabled: true,
  ),
);

const plainAlarm = Alarm(id: 'a-plain', hour: 8, minute: 15);

Future<ProviderContainer> pumpHome(
  WidgetTester tester, {
  List<Alarm> alarms = const [kakugoAlarm, plainAlarm],
  List<ContactEntry> book = const [],
}) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  for (final entry in book) {
    await container.read(contactBookRepositoryProvider).save(entry);
  }
  for (final alarm in alarms) {
    await container.read(alarmRepositoryProvider).save(alarm);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  setUp(() {
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

  testWidgets('a 覚悟 row wears the icon row and a plain one does not', (
    tester,
  ) async {
    await pumpHome(tester, alarms: const [kakugoAlarm]);
    expect(find.byKey(const ValueKey('alarmKakugoIcons')), findsOneWidget);

    await pumpHome(tester, alarms: const [plainAlarm]);
    expect(find.byKey(const ValueKey('alarmKakugoIcons')), findsNothing);
  });

  testWidgets('the 覚悟あり／なし label names the state, never the amount', (
    tester,
  ) async {
    await pumpHome(tester, alarms: const [kakugoAlarm, plainAlarm]);
    final labels = tester
        .widgetList<Text>(find.byKey(const ValueKey('alarmKakugoLabel')))
        .map((t) => t.data)
        .toList();
    expect(labels, containsAll(['覚悟あり', '覚悟なし']));
  });

  testWidgets('no number reaches the row — not the rate, not the cap', (
    tester,
  ) async {
    // The gauge, the price and the badge all lived here once. The row now
    // says *which* consequences are armed and nothing about how much.
    for (final rate in const [3000, 1500, 600, 300, 100, 50]) {
      await pumpHome(
        tester,
        alarms: [
          kakugoAlarm.copyWith(kakugo: Kakugo(ratePerMinute: rate, cap: 3000)),
        ],
      );
      expect(find.textContaining('コイン/分'), findsNothing, reason: '$rate');
      expect(find.textContaining('$rate'), findsNothing);
      expect(find.text(kakugoBadge(rate, 3000)), findsNothing);
    }
  });

  testWidgets('a 覚悟 row and a plain row are laid out identically', (
    tester,
  ) async {
    // The 覚悟 row differs in colour, frame and glow — and in nothing that
    // moves a pixel. The icon line only exists on a 覚悟 row, but the label
    // shares that line there and gets a line of its own on a plain row, so
    // both rows end up the same height. Same time position, same switch,
    // same row height.
    await pumpHome(tester, alarms: const [plainAlarm]);
    final plainTime = tester.getTopLeft(find.byKey(const ValueKey('alarmTime')));
    final plainSwitch = tester.getRect(find.byType(Switch));
    final plainRow = tester.getRect(find.byType(SwipeToDelete));

    await pumpHome(tester, alarms: const [kakugoAlarm]);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('alarmTime'))),
      plainTime,
      reason: 'the time does not move for a pledge',
    );
    expect(tester.getRect(find.byType(Switch)), plainSwitch);
    expect(tester.getRect(find.byType(SwipeToDelete)), plainRow);
  });

  testWidgets('the row is the time, the repeat, and a line of icons', (
    tester,
  ) async {
    await pumpHome(
      tester,
      alarms: [
        kakugoAlarm.copyWith(repeatDays: const {1, 2, 3, 4, 5}),
        plainAlarm,
      ],
    );

    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('平日'), findsOneWidget);
    // SMS, メール — and コイン, because the default 人質 is the coins.
    expect(find.byTooltip('SMS'), findsOneWidget);
    expect(find.byTooltip('メール'), findsOneWidget);
    expect(find.byTooltip('コイン'), findsOneWidget);
    expect(find.byTooltip('カード'), findsNothing);
    expect(find.byTooltip('Discord'), findsNothing);
    expect(find.byKey(const ValueKey('alarmIconX')), findsNothing);

    expect(find.text('08:15'), findsOneWidget);
    expect(find.text('一回限り'), findsOneWidget);

    // The あり/なし word is back, but never a number and never a name.
    expect(find.text('覚悟あり'), findsOneWidget);
    expect(find.text('覚悟なし'), findsOneWidget);
    expect(find.text('田中太郎'), findsNothing);
    expect(find.textContaining('寝坊で失う最大金額'), findsNothing);
    expect(find.textContaining('ノーマル'), findsNothing);
    expect(find.textContaining('計算'), findsNothing);
  });

  testWidgets('人質なし drops the money icon and keeps the 連絡 ones', (
    tester,
  ) async {
    await pumpHome(
      tester,
      alarms: [
        kakugoAlarm.copyWith(
          kakugo: const Kakugo(
            hostage: HostageType.none,
            ratePerMinute: 0,
            cap: 3000,
          ),
        ),
      ],
    );

    expect(find.byKey(const ValueKey('alarmKakugoIcons')), findsOneWidget);
    expect(find.byTooltip('SMS'), findsOneWidget);
    expect(find.byTooltip('メール'), findsOneWidget);
    expect(find.byTooltip('コイン'), findsNothing);
    expect(find.byTooltip('カード'), findsNothing);
  });

  testWidgets('カード人質 wears the card icon instead of the coin', (tester) async {
    await pumpHome(
      tester,
      alarms: [
        kakugoAlarm.copyWith(
          kakugo: const Kakugo(
            hostage: HostageType.card,
            ratePerMinute: 500,
            cap: 3000,
          ),
        ),
      ],
    );
    expect(find.byTooltip('カード'), findsOneWidget);
    expect(find.byTooltip('コイン'), findsNothing);
  });

  testWidgets('a live Discord 共有先 puts the Discord mark on the row', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      alarms: [
        kakugoAlarm.copyWith(
          clearContact: true,
          share: const OversleepShare(webhookIds: {'w1'}),
        ),
      ],
    );
    await container
        .read(discordWebhookRepositoryProvider)
        .save(
          DiscordWebhook(
            id: 'w1',
            displayName: 'てすと',
            url: 'https://discord.com/api/webhooks/1/abc',
            createdAt: DateTime(2026),
          ),
        );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Discord'), findsOneWidget);
    expect(find.byTooltip('SMS'), findsNothing);
    // Still the coins, because the pledge still burns them.
    expect(find.byTooltip('コイン'), findsOneWidget);
  });

  testWidgets('the icons follow the 連絡帳 as it stands now', (tester) async {
    await pumpHome(
      tester,
      alarms: const [kakugoAlarm],
      book: [
        ContactEntry(
          id: 'c1',
          name: '田中太郎（部長）',
          phone: '090-1234-5678',
          createdAt: DateTime(2026),
        ),
      ],
    );
    // The address was dropped from the entry, so the mail route goes with it.
    expect(find.byTooltip('SMS'), findsOneWidget);
    expect(find.byTooltip('メール'), findsNothing);
  });

  testWidgets('no contact, no 連絡 icons — only what is still armed', (
    tester,
  ) async {
    await pumpHome(tester, alarms: [kakugoAlarm.copyWith(clearContact: true)]);
    expect(find.byKey(const ValueKey('alarmKakugoIcons')), findsOneWidget);
    expect(find.byTooltip('SMS'), findsNothing);
    expect(find.byTooltip('メール'), findsNothing);
    expect(find.byTooltip('コイン'), findsOneWidget);
  });

  testWidgets('スヌーズ中 still shows on a 覚悟 row', (tester) async {
    final container = await pumpHome(tester, alarms: const [kakugoAlarm]);
    final ringAt = DateTime.now().add(const Duration(minutes: 7));
    await container
        .read(alarmSessionRepositoryProvider)
        .save(
          AlarmSession(
            id: 's1',
            alarmId: kakugoAlarm.id,
            firedAt: DateTime.now().subtract(const Duration(minutes: 3)),
            graceMinutes: 1,
            kakugoSnapshot: kakugoAlarm.kakugo,
            snoozes: [DateTime.now()],
            currentRingAt: ringAt,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('snoozedUntil')), findsOneWidget);
  });

  testWidgets('the snoozed row offers 起きた（解除）; other rows do not', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      alarms: const [kakugoAlarm, plainAlarm],
    );
    await container
        .read(alarmSessionRepositoryProvider)
        .save(
          AlarmSession(
            id: 's1',
            alarmId: kakugoAlarm.id,
            firedAt: DateTime.now().subtract(const Duration(minutes: 3)),
            graceMinutes: 1,
            kakugoSnapshot: kakugoAlarm.kakugo,
            snoozes: [DateTime.now()],
            currentRingAt: DateTime.now().add(const Duration(minutes: 7)),
          ),
        );
    await tester.pumpAndSettle();

    // Exactly one button: on the snoozed row, never on the plain one.
    expect(find.byKey(const ValueKey('wakeNowButton')), findsOneWidget);
    expect(find.text('起きた（解除）'), findsOneWidget);
  });

  testWidgets('起きた（解除） settles the session and routes to the result', (
    tester,
  ) async {
    final container = await pumpHome(tester, alarms: const [kakugoAlarm]);
    await container
        .read(walletRepositoryProvider)
        .write(const Wallet(coins: 5000));
    await container
        .read(alarmSessionRepositoryProvider)
        .save(
          AlarmSession(
            id: 's1',
            alarmId: kakugoAlarm.id,
            firedAt: DateTime.now().subtract(const Duration(minutes: 3)),
            graceMinutes: 1,
            kakugoSnapshot: kakugoAlarm.kakugo,
            coinsAtFire: 5000,
            snoozes: [DateTime.now()],
            currentRingAt: DateTime.now().add(const Duration(minutes: 7)),
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('wakeNowButton')));
    await tester.pumpAndSettle();

    // Settled exactly like a cleared wake check: failed, no longer ringing.
    final settled = await container
        .read(alarmSessionRepositoryProvider)
        .getById('s1');
    expect(settled!.status, SessionStatus.failed);
    expect(settled.isRinging, isFalse);
    // And the result screen is up, reading the settled outcome.
    expect(find.text('起床失敗'), findsOneWidget);
    expect(find.textContaining('消費'), findsOneWidget);
  });

  testWidgets('swipe to delete still works on a 覚悟 row', (tester) async {
    final container = await pumpHome(tester, alarms: const [kakugoAlarm]);
    await tester.drag(find.byType(SwipeToDelete), const Offset(-120, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(await container.read(alarmRepositoryProvider).getAll(), isEmpty);
    expect(find.text('アラームはまだありません'), findsOneWidget);
  });

  testWidgets('the switch on a 覚悟 row still arms and disarms it', (
    tester,
  ) async {
    final container = await pumpHome(tester, alarms: const [kakugoAlarm]);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final saved =
        (await container.read(alarmRepositoryProvider).getAll()).single;
    expect(saved.enabled, isFalse);
    // Still a 覚悟 row, still saying what it has armed — just not armed tonight.
    expect(find.byKey(const ValueKey('alarmKakugoIcons')), findsOneWidget);
    expect(find.byTooltip('コイン'), findsOneWidget);
  });
}
