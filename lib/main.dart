import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme_controller.dart';
import 'data/providers.dart';
import 'domain/loss_calculator.dart';
import 'domain/snooze_rules.dart';
import 'services/alarm_service.dart';
import 'services/legacy_recording_cleanup.dart';
import 'services/app_notifier.dart';
import 'services/background_dispatch.dart';
import 'services/route_permissions.dart';
import 'services/secret_store.dart';
import 'services/sms_sender.dart';
import 'services/snooze_service.dart';
import 'services/speaker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  late final ProviderContainer container;
  container = ProviderContainer(
    overrides: [
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
    ],
  );

  // Must run before anything is booked. Cheap, and idempotent.
  await AndroidAlarmManager.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );

  // Permission dialogs and the ring-screen jump both want a live UI, so this
  // starts after the first frame is on its way.
  unawaited(container.read(alarmServiceProvider).init());

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

class WakeOrPayApp extends ConsumerWidget {
  const WakeOrPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return MaterialApp.router(
      title: '覚悟の目覚まし',
      theme: theme.themeData,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
