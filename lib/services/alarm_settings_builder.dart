import 'package:alarm/alarm.dart' as pkg;
import 'package:flutter/material.dart';

import '../domain/models.dart' as domain;
import '../domain/sound_library.dart';

/// The sound every alarm rang with before the library existed, kept as the
/// fallback for an id that matches nothing.
const alarmAssetPath = 'assets/audio/alarm.wav';

/// The plugin keys alarms by int. Our ids are strings generated from
/// [DateTime.millisecondsSinceEpoch], so parse when we can and fall back to a
/// stable hash otherwise. Pure.
int platformAlarmId(String alarmId) {
  final parsed = int.tryParse(alarmId);
  if (parsed != null && parsed > 0) return parsed % 0x7fffffff;
  return alarmId.hashCode & 0x7fffffff;
}

enum ScheduleAction { schedule, cancel, skipRinging }

/// What to do with one alarm during a (re)schedule pass. Pure.
///
/// Ringing wins over everything: the platform alarm must not be touched while
/// it is ringing — not even to cancel a disabled one — because `Alarm.set`
/// replaces an alarm with the same id and `Alarm.stop` silences it.
ScheduleAction scheduleActionFor({
  required bool enabled,
  required bool isRinging,
}) {
  if (isRinging) return ScheduleAction.skipRinging;
  return enabled ? ScheduleAction.schedule : ScheduleAction.cancel;
}

/// Builds the plugin's settings for one ring of [alarm] at [fireAt]. Pure, so
/// the scheduling decisions can be tested without the platform.
///
/// `assetAudioPath` takes either an asset path or a path on disk, which is
/// exactly the two shapes [soundPathFor] produces — so a sound the user
/// imported and one that ships with the app are handed over the same way.
///
/// No platform snooze is configured, ever. Snooze is a free feature of this
/// app, but it has to run through the app so the session can record it; the
/// plugin's own snooze would silence the alarm behind our back.
pkg.AlarmSettings buildAlarmSettings(domain.Alarm alarm, DateTime fireAt) {
  return pkg.AlarmSettings(
    id: platformAlarmId(alarm.id),
    dateTime: fireAt,
    assetAudioPath: soundPathFor(alarm.soundId),
    loopAudio: true,
    vibrate: true,
    androidFullScreenIntent: true,
    // Keep ringing when the app is swiped away — the foreground service is the
    // whole point.
    androidStopAlarmOnTermination: false,
    warningNotificationOnKill: false,
    payload: alarm.id,
    volumeSettings: pkg.VolumeSettings.fade(
      volume: 1,
      fadeDuration: const Duration(seconds: 5),
      volumeEnforced: true,
    ),
    notificationSettings: pkg.NotificationSettings(
      title: '起きろ！！',
      // Same rule as the ringing screen: a pledge with no per-minute penalty
      // must not claim coins are burning by the minute, because none are.
      body: (alarm.kakugo?.ratePerMinute ?? 0) > 0
          ? '1分ごとに ${alarm.kakugo!.ratePerMinute} コインが燃えています'
          : 'アプリを開いて解除してください',
      // No stop button and no swipe-to-stop: dismissing has to go through the
      // wake check on the ringing screen.
      androidStopAlarmOnDismiss: false,
      iconColor: const Color(0xFF6C4BFF),
    ),
  );
}
