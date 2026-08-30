import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme_controller.dart';
import 'app/usage_controller.dart';
import 'data/providers.dart';
import 'domain/loss_calculator.dart';
import 'domain/snooze_rules.dart';
import 'services/alarm_service.dart';
import 'services/app_update.dart';
import 'services/legacy_recording_cleanup.dart';
import 'services/app_notifier.dart';
import 'services/background_dispatch.dart';
import 'services/full_screen_intent.dart';
import 'services/route_permissions.dart';
import 'services/secret_store.dart';
import 'services/sms_sender.dart';
import 'services/snooze_service.dart';
import 'services/speaker.dart';
import 'services/stripe_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  late final ProviderContainer container;
  final overrides = <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Only the real app reaches the notification plugin; every test keeps
      // the recording default.
      localAppNotifierOverride(),
      // The スヌーズ中 foreground service, whose notification body is the live
      // loss computed here in Dart (spec 12.1). Returns null once the snooze is
      // over, which is the signal for the service to stop.
      platformSnoozeServiceOverride((sessionId) async {
        final session = await container
            .read(alarmSessionRepositoryProvider)
            .getById(sessionId);
        final now = DateTime.now();
        if (session == null || !isSnoozePending(session, now)) return null;
        return snoozeNotificationText(
          session.currentRingAt,
          loss: lossAt(now, session),
        ).body;
      }),
      // Only the real app can ask Android whether a full-screen intent is
      // still allowed to take over the screen (Android 14+).
      platformFullScreenIntentOverride(),
      ttsSpeakerOverride(),
      // The SMTP app password. Only the real app reaches the platform
      // keystore; every test keeps the in-memory store.
      flutterSecureStoreOverride(),
      // Only the real app is allowed to put a message on a radio; every test
      // keeps the recording sender.
      platformSmsSenderOverride(),
      // And only the real app puts a permission dialog on screen.
      pluginRoutePermissionsOverride(),
      // …or books a trigger with Android's own AlarmManager (spec 11.7).
      androidExactAlarmSchedulerOverride(),
  ];
  // The initial location is overridden from the start with the default, so
  // that the real answer can be swapped in below. `updateOverrides` can only
  // replace providers that were overridden when the container was built —
  // adding a new override there throws before `runApp`, and the app never
  // leaves the launch screen (build 112 did exactly that).
  container = ProviderContainer(
    overrides: [
      ...overrides,
      initialLocationProvider.overrideWithValue(initialLocationFor()),
    ],
  );

  // Must run before anything is booked. Cheap, and idempotent.
  await AndroidAlarmManager.initialize();

  // カード人質 (docs/BILLING_API.md). A publishable key — public by Stripe's own
  // design, and useless without the secret key that lives only in the Worker.
  //
  // **Here and not in [WakeOrPayApp].** Assigning this schedules a call over
  // the Stripe platform channel, and a widget test that pumps the app has no
  // plugin underneath it. The card sheet sets it again for itself.
  Stripe.publishableKey = kStripePublishableKey;

  // **Before the first frame, deliberately.** A full-screen intent launches
  // this process onto the lock screen while the alarm is already sounding; if
  // the ring screen is navigated to after `runApp`, the home tab paints first
  // and the user watches their alarms flash past on the way to the ring. So the
  // router is built already pointing at it. Bounded and swallowed inside
  // [AlarmService.launchRingingSessionId]: a probe that cannot answer must
  // never be the reason the app will not open.
  container.updateOverrides([
    ...overrides,
    initialLocationProvider.overrideWithValue(
      initialLocationFor(
        ringingSessionId: await container
            .read(alarmServiceProvider)
            .launchRingingSessionId(),
      ),
    ),
  ]);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );

  // Permission dialogs and the ring-screen jump both want a live UI, so this
  // starts after the first frame is on its way.
  unawaited(container.read(alarmServiceProvider).init());

  // Is there a newer APK on the release page? **Once per app start**, and no
  // more often than every 12 hours — not on every resume, which on a phone
  // that never gets closed would be a request every time the screen comes on.
  // Wrapped and unawaited for the same reason as the sweep below: the update
  // check is worth nothing to a user who is opening their alarms, and must
  // never be why the first frame is late.
  unawaited(
    container.read(appUpdateProvider.notifier).checkOnStart().catchError(
      (Object _) {},
    ),
  );

  // The one-off sweep for the recordings 改訂4 retired. Fire and forget, and
  // wrapped: it touches the filesystem, it is worth nothing to the user, and
  // it must never be the reason the first frame is late or the app will not
  // open.
  unawaited(
    container.read(legacyRecordingCleanupProvider).run().catchError(
      (Object _) => 0,
    ),
  );
}

class WakeOrPayApp extends ConsumerStatefulWidget {
  const WakeOrPayApp({super.key});

  @override
  ConsumerState<WakeOrPayApp> createState() => _WakeOrPayAppState();
}

class _WakeOrPayAppState extends ConsumerState<WakeOrPayApp> {
  @override
  void initState() {
    super.initState();
    // ログイン日数 (`PROFILE_TABS_SPEC` §1). **Once per app start**, and here
    // rather than on any one screen: an alarm that fires while the phone is
    // locked opens straight into the ringing screen, which wears no header and
    // no profile — and that morning is still a day the user opened the app.
    //
    // Not in `main()` above, because a widget test pumps this widget without
    // running it, and 「起動した」 has to mean the same thing in both.
    // Unawaited: it is one preference write, and the first frame must not wait
    // on it. Wrapped, because a statistic is never a reason not to open.
    unawaited(
      ref.read(usageProvider.notifier).recordOpen().catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return MaterialApp.router(
      title: '覚悟の目覚まし',
      theme: theme.themeData,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
