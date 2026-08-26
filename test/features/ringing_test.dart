import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/router.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';

const alarm = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
);

/// The ring screen ticks every second, so pumpAndSettle would never settle.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<({ProviderContainer container, AlarmSession session})> openRinging(
  WidgetTester tester, {
  Alarm withAlarm = alarm,
  Duration ringingFor = Duration.zero,
}) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await container.read(alarmRepositoryProvider).save(withAlarm);
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 5000));
  final session = await container
      .read(sessionServiceProvider)
      .start(alarm: withAlarm, firedAt: DateTime.now().subtract(ringingFor));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await settle(tester);

  container.read(appRouterProvider).go(AppRoute.ringing(session.id));
  await settle(tester);

  return (container: container, session: session);
}

void main() {
  testWidgets('the ringing screen shows the burn and offers no escape', (
    tester,
  ) async {
    await openRinging(tester, ringingFor: const Duration(minutes: 3));

    expect(find.text('起きろ！！'), findsOneWidget);
    expect(find.text('💸 あなた：−300'), findsOneWidget);
    expect(find.text('👨 おじさん：+300'), findsOneWidget);

    // No snooze, no stop, no way back.
    expect(find.text('スヌーズ'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is PopScope && !w.canPop),
      findsOneWidget,
    );
  });

  testWidgets('letting go of the long press resets it', (tester) async {
    await openRinging(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('解除')),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('あと 2 秒'), findsOneWidget);

    await gesture.up();
    await settle(tester);
    expect(find.text('5秒間押し続ける'), findsOneWidget);
    expect(find.text('起きろ！！'), findsOneWidget, reason: 'still ringing');
  });

  testWidgets('holding for five seconds clears and routes to the result', (
    tester,
  ) async {
    final opened = await openRinging(
      tester,
      ringingFor: const Duration(minutes: 3),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('解除')),
    );
    await tester.pump(const Duration(seconds: 6));
    await gesture.up();
    await settle(tester, frames: 30);

    expect(find.text('起床失敗'), findsOneWidget);
    expect(find.text('消費：300'), findsOneWidget);

    final settled = await opened.container
        .read(alarmSessionRepositoryProvider)
        .getById(opened.session.id);
    expect(settled!.status, SessionStatus.failed);
    expect(settled.loss, 300);

    // The coins moved and the platform alarm was told to stop.
    expect(
      (await opened.container.read(walletRepositoryProvider).read()).coins,
      4700,
    );
    final fake =
        opened.container.read(alarmServiceProvider) as FakeAlarmService;
    expect(fake.cancelled, contains(alarm.id));
  });

  testWidgets('clearing inside the first minute is a success with tokens', (
    tester,
  ) async {
    final opened = await openRinging(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('解除')),
    );
    await tester.pump(const Duration(seconds: 6));
    await gesture.up();
    await settle(tester, frames: 30);

    expect(find.text('起床成功'), findsOneWidget);
    expect(find.text('消費：0'), findsOneWidget);
    expect(find.text('守った金額：2000'), findsOneWidget);
    expect(find.text('獲得トークン：+20'), findsOneWidget);
    expect(find.text('「チッ……」'), findsOneWidget);

    expect(
      (await opened.container.read(walletRepositoryProvider).read()).tokens,
      20,
    );
  });

  testWidgets('the math check needs three right answers in a row', (
    tester,
  ) async {
    await openRinging(
      tester,
      withAlarm: alarm.copyWith(wakeCheck: WakeCheckType.math),
    );

    expect(find.text('0 / 3 問正解'), findsOneWidget);
    expect(find.textContaining('= ?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('答える'));
    await settle(tester);

    expect(find.text('まちがい。問題を変えます'), findsOneWidget);
    expect(find.text('0 / 3 問正解'), findsOneWidget);
    expect(find.text('起きろ！！'), findsOneWidget, reason: 'still ringing');
  });

  testWidgets('the typing check demands an exact match and blocks selection', (
    tester,
  ) async {
    await openRinging(
      tester,
      withAlarm: alarm.copyWith(wakeCheck: WakeCheckType.typing),
    );

    expect(find.text('この文を入力してください'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enableInteractiveSelection, isFalse);

    await tester.enterText(find.byType(TextField), 'ちがう文');
    await settle(tester);
    expect(find.text('起きろ！！'), findsOneWidget, reason: 'still ringing');
  });
}
