import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/router.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/lock_screen.dart';

import '../helpers.dart';

/// Snoozeable, and cleared with one tap, so a test can take either exit.
const alarm = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  wakeCheck: WakeCheckType.normal,
  snooze: Snooze(intervalMinutes: 5, maxCount: 2),
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
);

/// The ring screen ticks every second, so pumpAndSettle would never settle.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Starts the app with the recorder in place. [ringing] opens a session and
/// navigates to it, exactly as a ring arriving while the app is alive does.
Future<
  ({
    ProviderContainer container,
    RecordingLockScreenVisibility lock,
    AlarmSession? session,
  })
>
pumpApp(WidgetTester tester, {bool ringing = false}) async {
  final lock = RecordingLockScreenVisibility();
  final container = await testContainer(
    extra: [
      fakeAlarmServiceOverride(),
      lockScreenVisibilityProvider.overrideWithValue(lock),
    ],
  );
  await container.read(alarmRepositoryProvider).save(alarm);
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 5000));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await settle(tester);

  if (!ringing) return (container: container, lock: lock, session: null);

  final session = await container
      .read(sessionServiceProvider)
      .start(alarm: alarm, firedAt: DateTime.now());
  container.read(appRouterProvider).go(AppRoute.ringing(session.id));
  await settle(tester);
  return (container: container, lock: lock, session: session);
}

void main() {
  testWidgets('an ordinary launch lowers the flag once and leaves it', (
    tester,
  ) async {
    final r = await pumpApp(tester);

    // MainActivity.onCreate raised it before the first frame; nothing is
    // ringing, so the first thing the app does is put it back down.
    expect(r.lock.calls, [false]);
  });

  testWidgets('the ringing screen raises it', (tester) async {
    final r = await pumpApp(tester, ringing: true);
    expect(r.lock.calls, [false, true]);
  });

  testWidgets('clearing the wake check lowers it again', (tester) async {
    final r = await pumpApp(tester, ringing: true);

    await tester.tap(find.byKey(const ValueKey('normalCheckButton')));
    await settle(tester);

    expect(r.lock.calls, [false, true, false]);
    expect(
      (await r.container
              .read(alarmSessionRepositoryProvider)
              .getById(r.session!.id))!
          .isRinging,
      isFalse,
      reason: 'the morning really is over',
    );
  });

  testWidgets('スヌーズ lowers it too — the ring screen is going away', (
    tester,
  ) async {
    final r = await pumpApp(tester, ringing: true);

    await tester.tap(find.byKey(const ValueKey('snoozeButton')));
    await settle(tester);

    expect(r.lock.calls, [false, true, false]);
  });

  test('a channel that fails is not a crash', () async {
    const channel = MethodChannel('wake_or_pay/lock_screen');
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'nope'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    // The whole contract: it never throws, whatever the platform says.
    await expectLater(
      const PlatformLockScreenVisibility().setShowWhenLocked(true),
      completes,
    );
  });
}
