import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/alarm_settings_builder.dart';

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
}
