import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/router.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/shake_detector.dart';
import 'package:wake_or_pay/features/ringing/wake_checks/shake_check.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';
import 'alarms_test.dart' show inSubScreen, pumpHome;

const _alarm = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  wakeCheck: WakeCheckType.shake,
);

void main() {
  testWidgets('the shake check clears once the phone has been shaken', (
    tester,
  ) async {
    // The emulator cannot be shaken, so the samples are injected. The maths
    // behind them is covered by test/domain/shake_detector_test.dart.
    final samples = StreamController<ShakeSample>.broadcast();
    addTearDown(samples.close);
    // The detector reads time off the samples, so the test controls both.
    var at = Duration.zero;
    void shake() {
      at += const Duration(milliseconds: 100);
      samples.add(ShakeSample(at, 30));
    }

    final container = await testContainer(
      extra: [
        fakeAlarmServiceOverride(),
        shakeSampleProvider.overrideWith((ref) => samples.stream),
      ],
    );
    await container.read(alarmRepositoryProvider).save(_alarm);
    await container.read(walletRepositoryProvider).write(const Wallet());
    final session = await container
        .read(sessionServiceProvider)
        .start(alarm: _alarm, firedAt: DateTime.now());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WakeOrPayApp(),
      ),
    );
    await tester.pump();
    container.read(appRouterProvider).go(AppRoute.ringing(session.id));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('5秒間振り続ける'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const ValueKey('shakeProgress')),
          )
          .value,
      0,
    );

    // Half a second of shaking: progress, but nowhere near cleared.
    for (var i = 0; i < 6; i++) {
      shake();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const ValueKey('shakeProgress')),
          )
          .value,
      inExclusiveRange(0, 1),
    );
    expect(find.text('5秒間振り続ける'), findsNothing, reason: 'counting down now');
    expect(find.text('起きろ！！'), findsOneWidget, reason: 'still ringing');

    // Keep going past five seconds.
    for (var i = 0; i < 60; i++) {
      shake();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.text('起きろ！！'), findsNothing, reason: 'the ring is over');
    expect(
      (await container
              .read(alarmSessionRepositoryProvider)
              .getById(session.id))!
          .isRinging,
      isFalse,
    );
  });

  testWidgets('the wake check sub-screen offers all five', (tester) async {
    await pumpHome(tester, coins: 5000);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await inSubScreen(tester, '起床確認', () async {
      for (final type in WakeCheckType.values) {
        expect(find.text(type.label), findsOneWidget, reason: type.name);
      }
      await tester.tap(find.text('ランダム'));
      await tester.pumpAndSettle();
    });

    expect(find.text('ランダム'), findsOneWidget, reason: 'shown on the row');
  });
}
