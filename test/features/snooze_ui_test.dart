import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/router.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';

const snooze = Snooze(intervalMinutes: 5, maxCount: 2);

const plain = Alarm(id: 'a1', hour: 7, minute: 0, snooze: snooze);

const pledged = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  snooze: snooze,
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000, snoozePenalty: 50),
);

/// The ring screen ticks every second, so pumpAndSettle would never settle.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<({ProviderContainer container, AlarmSession session})> openRinging(
  WidgetTester tester,
  Alarm alarm, {
  List<DateTime> alreadySnoozed = const [],
}) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await container.read(alarmRepositoryProvider).save(alarm);
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 5000));

  final sessions = container.read(alarmSessionRepositoryProvider);
  var session = await container
      .read(sessionServiceProvider)
      .start(alarm: alarm, firedAt: DateTime.now());
  if (alreadySnoozed.isNotEmpty) {
    session = session.copyWith(snoozes: alreadySnoozed);
    await sessions.save(session);
  }

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
  testWidgets('a plain snoozable alarm offers a bare スヌーズ', (tester) async {
    await openRinging(tester, plain);

    expect(find.text('スヌーズ'), findsOneWidget);
    // Secondary to 解除: a text button, not the filled one the wake check uses.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('snoozeButton')),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('snoozeButton'))),
      isNotNull,
    );
  });

  testWidgets('under a pledge the button states the price', (tester) async {
    await openRinging(tester, pledged);

    expect(find.text('スヌーズ（−50 コイン）'), findsOneWidget);
    expect(find.text('スヌーズ'), findsNothing);
  });

  testWidgets('an alarm with snooze off never shows the button', (
    tester,
  ) async {
    await openRinging(tester, const Alarm(id: 'a1', hour: 7, minute: 0));

    expect(find.byKey(const ValueKey('snoozeButton')), findsNothing);
  });

  testWidgets('the button disappears once maxCount is used up', (tester) async {
    final now = DateTime.now();
    await openRinging(
      tester,
      plain,
      alreadySnoozed: [now, now.add(const Duration(minutes: 5))],
    );

    expect(find.byKey(const ValueKey('snoozeButton')), findsNothing);
  });

  testWidgets(
    'pressing it goes Home, posts the notice and marks the alarm row',
    (tester) async {
      final r = await openRinging(tester, pledged);

      await tester.tap(find.byKey(const ValueKey('snoozeButton')));
      await settle(tester);

      expect(find.text('起きろ！！'), findsNothing, reason: 'off the ring screen');
      // Home has no title bar of its own any more, only the shared header.
      expect(
        find.byKey(const ValueKey('appHeader')),
        findsOneWidget,
        reason: 'Home',
      );

      final posted = notifierOf(r.container).posted.single;
      expect(posted.title, 'スヌーズ中');
      expect(posted.body, contains('に再鳴動'));

      final service =
          r.container.read(alarmServiceProvider) as FakeAlarmService;
      expect(service.rearmed.single.alarmId, 'a1');

      // And the alarm list says so.
      await settle(tester);
      expect(find.byKey(const ValueKey('snoozedUntil')), findsOneWidget);
      expect(find.textContaining('スヌーズ中 '), findsOneWidget);

      // The session is still open and now costs the penalty.
      final stored = await r.container
          .read(alarmSessionRepositoryProvider)
          .getById(r.session.id);
      expect(stored!.isRinging, isTrue);
      expect(stored.snoozes, hasLength(1));
    },
  );
}
