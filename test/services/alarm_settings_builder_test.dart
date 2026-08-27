import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/sound_library.dart';
import 'package:wake_or_pay/services/alarm_settings_builder.dart';
import 'package:wake_or_pay/services/sound_preview_player.dart';

void main() {
  group('platformAlarmId', () {
    test('numeric ids are used as-is when they fit', () {
      expect(platformAlarmId('42'), 42);
    });

    test('big numeric ids are folded into the positive int32 range', () {
      final id = platformAlarmId('1756252800000');
      expect(id, greaterThan(0));
      expect(id, lessThan(0x7fffffff));
    });

    test('non numeric ids are stable and non negative', () {
      expect(platformAlarmId('morning'), platformAlarmId('morning'));
      expect(platformAlarmId('morning'), greaterThanOrEqualTo(0));
      expect(platformAlarmId('morning'), isNot(platformAlarmId('evening')));
    });

    test('an empty id does not blow up', () {
      expect(platformAlarmId(''), greaterThanOrEqualTo(0));
    });
  });

  group('scheduleActionFor', () {
    test('an enabled alarm is scheduled, a disabled one cancelled', () {
      expect(
        scheduleActionFor(enabled: true, isRinging: false),
        ScheduleAction.schedule,
      );
      expect(
        scheduleActionFor(enabled: false, isRinging: false),
        ScheduleAction.cancel,
      );
    });

    test('a ringing alarm is never touched, enabled or not', () {
      expect(
        scheduleActionFor(enabled: true, isRinging: true),
        ScheduleAction.skipRinging,
      );
      expect(
        scheduleActionFor(enabled: false, isRinging: true),
        ScheduleAction.skipRinging,
      );
    });
  });

  group('buildAlarmSettings', () {
    const alarm = Alarm(
      id: '17',
      hour: 7,
      minute: 0,
      kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
    );
    final fireAt = DateTime(2026, 8, 28, 7);

    test('carries the fire time, the id and our alarm id as payload', () {
      final s = buildAlarmSettings(alarm, fireAt);
      expect(s.id, 17);
      expect(s.dateTime, fireAt);
      expect(s.payload, '17');
      expect(s.assetAudioPath, alarmAssetPath);
    });

    test('never offers a snooze', () {
      final s = buildAlarmSettings(alarm, fireAt);
      expect(s.androidSnoozeDuration, isNull);
      expect(s.notificationSettings.androidSnoozeButton, isNull);
    });

    test('cannot be silenced from the notification', () {
      final s = buildAlarmSettings(alarm, fireAt);
      expect(s.notificationSettings.stopButton, isNull);
      expect(s.notificationSettings.androidStopAlarmOnDismiss, isFalse);
    });

    test('keeps ringing when the app is killed', () {
      final s = buildAlarmSettings(alarm, fireAt);
      expect(s.androidStopAlarmOnTermination, isFalse);
      expect(s.loopAudio, isTrue);
      expect(s.androidFullScreenIntent, isTrue);
    });

    test('the notification names the rate only for a kakugo alarm', () {
      expect(
        buildAlarmSettings(alarm, fireAt).notificationSettings.body,
        contains('100'),
      );
      expect(
        buildAlarmSettings(
          alarm.copyWith(clearKakugo: true),
          fireAt,
        ).notificationSettings.body,
        isNot(contains('100')),
      );
    });
  });

  group('the sound', () {
    test('a library alarm rings with that library sound', () {
      final s = buildAlarmSettings(
        const Alarm(id: '1', hour: 7, minute: 0, soundId: 'siren'),
        DateTime(2026, 8, 27, 7),
      );
      expect(s.assetAudioPath, 'assets/audio/siren.wav');
    });

    test('an imported sound is handed over as a path on disk', () {
      const path = '/data/user/0/app/files/sounds/1700_morning.mp3';
      final s = buildAlarmSettings(
        Alarm(id: '1', hour: 7, minute: 0, soundId: deviceSoundIdFor(path)),
        DateTime(2026, 8, 27, 7),
      );
      expect(s.assetAudioPath, path, reason: 'no assets/ prefix, no file:');
    });

    test(
      'an id that matches nothing falls back to the bell, never silence',
      () {
        final s = buildAlarmSettings(
          const Alarm(id: '1', hour: 7, minute: 0, soundId: 'no-such-sound'),
          DateTime(2026, 8, 27, 7),
        );
        expect(s.assetAudioPath, alarmAssetPath);
      },
    );

    test('the preview strips the prefix audioplayers adds back', () {
      expect(previewAssetPath('assets/audio/alarm.wav'), 'audio/alarm.wav');
      expect(previewAssetPath('/tmp/x.wav'), '/tmp/x.wav');
    });
  });
}
