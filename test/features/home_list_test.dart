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
    phoneEnabled: true,
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

  testWidgets('a 覚悟 row wears the badge and a plain one does not', (
    tester,
  ) async {
    await pumpHome(tester, alarms: const [kakugoAlarm]);
    expect(find.byKey(const ValueKey('kakugoBadge')), findsOneWidget);
    expect(
      find.text('⚠️'),
      findsOneWidget,
      reason: '500/分 against a 3000 cap is 6 minutes',
    );

    await pumpHome(tester, alarms: const [plainAlarm]);
    expect(find.byKey(const ValueKey('kakugoBadge')), findsNothing);
    expect(textOf(tester, 'alarmSummary'), '覚悟なし');
  });

  testWidgets('the badge follows the gauge — minutes to the cap', (
    tester,
  ) async {
    // cap 3000: how many minutes of oversleeping burn the lot.
    for (final (rate, badge) in const [
      (3000, '💀'),
      (1500, '💀'),
      (600, '🔥'),
      (300, '⚠️'),
      (100, '💦'),
      (50, '💸'),
    ]) {
      await pumpHome(
        tester,
        alarms: [
          kakugoAlarm.copyWith(kakugo: Kakugo(ratePerMinute: rate, cap: 3000)),
        ],
      );
      expect(find.text(badge), findsOneWidget, reason: '$rate コイン/分');
    }
    expect(kakugoBadge(1500, 3000), '💀', reason: 'the pure function agrees');
  });

  testWidgets('a 覚悟 row and a plain row are laid out identically', (
    tester,
  ) async {
    // The 覚悟 row differs in colour, frame and glow — and in nothing that
    // moves a pixel. Same time position, same switch, same row height.
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

  testWidgets('three lines: the time, the repeat, and what is at stake', (
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
    expect(find.text('覚悟あり ・ 500 コイン/分 ・ 📞 ✉ 田中太郎'), findsOneWidget);

    expect(find.text('08:15'), findsOneWidget);
    expect(find.text('一回限り'), findsOneWidget);
    expect(find.text('覚悟なし'), findsOneWidget);

    // The wake check and the worst case live in the editor now: the list says
    // when it rings, whether it can hurt, and who hears about it.
    expect(find.textContaining('寝坊で失う最大金額'), findsNothing);
    expect(find.textContaining('ノーマル'), findsNothing);
    expect(find.textContaining('計算'), findsNothing);
  });

  testWidgets('a 0 コイン/分 pledge is a badge-less, price-less 覚悟あり row', (
    tester,
  ) async {
    await pumpHome(
      tester,
      alarms: [
        kakugoAlarm.copyWith(
          kakugo: const Kakugo(ratePerMinute: 0, cap: 3000),
        ),
      ],
    );

    expect(find.byKey(const ValueKey('kakugoBadge')), findsNothing);
    expect(find.textContaining('コイン/分'), findsNothing);
    expect(
      textOf(tester, 'alarmSummary'),
      '覚悟あり ・ 📞 ✉ 田中太郎',
      reason: 'the pledge is the phone call',
    );
  });

  testWidgets('the contact name is the one the 連絡帳 has now', (tester) async {
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
    // Renamed, and the address was dropped, so the mail route goes with it.
    expect(textOf(tester, 'alarmSummary'), endsWith('・ 📞 田中太郎（部長）'));
    expect(find.textContaining('✉'), findsNothing);
  });

  testWidgets('no contact, no name on the row', (tester) async {
    await pumpHome(tester, alarms: [kakugoAlarm.copyWith(clearContact: true)]);
    expect(textOf(tester, 'alarmSummary'), '覚悟あり ・ 500 コイン/分');
    expect(find.byKey(const ValueKey('kakugoBadge')), findsOneWidget);
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
    // Still a 覚悟 row, still saying what it would cost — just not armed.
    expect(find.byKey(const ValueKey('kakugoBadge')), findsOneWidget);
    expect(textOf(tester, 'alarmSummary'), startsWith('覚悟あり ・ 500 コイン/分'));
  });
}
