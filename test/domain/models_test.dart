import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

/// Round-trips through real JSON text, so encodability is checked too.
T reencode<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) from,
) => from(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

void main() {
  const kakugo = Kakugo(ratePerMinute: 100, cap: 2000);

  group('Alarm', () {
    final alarm = Alarm(
      id: 'a1',
      hour: 7,
      minute: 5,
      repeatDays: const {1, 3, 5},
      wakeCheck: WakeCheckType.typing,
      kakugo: kakugo,
    );

    test('json round trip', () {
      expect(reencode(alarm.toJson(), Alarm.fromJson), alarm);
    });

    test('json round trip without kakugo', () {
      final plain = alarm.copyWith(clearKakugo: true, repeatDays: const {});
      final back = reencode(plain.toJson(), Alarm.fromJson);
      expect(back, plain);
      expect(back.kakugo, isNull);
      expect(back.isKakugo, isFalse);
    });

    test('copyWith replaces only what it is given', () {
      expect(alarm.copyWith(hour: 6).hour, 6);
      expect(alarm.copyWith(hour: 6).minute, 5);
      expect(alarm.copyWith().kakugo, kakugo);
      expect(alarm.copyWith(clearKakugo: true).kakugo, isNull);
    });

    test('equality ignores repeat day ordering', () {
      expect(alarm.copyWith(repeatDays: const {5, 3, 1}), alarm);
      expect(
        alarm.copyWith(repeatDays: const {5, 3, 1}).hashCode,
        alarm.hashCode,
      );
    });
  });

  group('AlarmSession', () {
    final s = AlarmSession(
      id: 's1',
      alarmId: 'a1',
      firedAt: DateTime(2026, 8, 27, 7),
      dismissedAt: DateTime(2026, 8, 27, 7, 13),
      status: SessionStatus.failed,
      loss: 1300,
      kakugoSnapshot: kakugo,
      coinsAtFire: 5000,
    );

    test('json round trip', () {
      expect(reencode(s.toJson(), AlarmSession.fromJson), s);
    });

    test('json round trip while still ringing', () {
      final ringing = AlarmSession(
        id: 's2',
        alarmId: 'a1',
        firedAt: DateTime(2026, 8, 27, 7),
      );
      final back = reencode(ringing.toJson(), AlarmSession.fromJson);
      expect(back, ringing);
      expect(back.isRinging, isTrue);
      expect(back.dismissedAt, isNull);
      expect(back.kakugoSnapshot, isNull);
    });
  });

  group('OversleepShare', () {
    const share = OversleepShare(
      webhookIds: {'w2', 'w1'},
      messageMode: MessageMode.custom,
      message: '起きろ',
      recordingPath: '/tmp/a.m4a',
      recordingWaveform: [0.5, 1],
      xEnabled: true,
    );

    test('json round trip', () {
      expect(reencode(share.toJson(), OversleepShare.fromJson), share);
    });

    test('json round trip with nothing on it', () {
      const empty = OversleepShare();
      final back = reencode(empty.toJson(), OversleepShare.fromJson);
      expect(back, empty);
      expect(back.webhookIds, isEmpty);
      expect(back.recordingPath, isNull);
      expect(back.hasRecording, isFalse);
    });

    test('the waveform is stored at two decimals and clamped', () {
      // A bar is a few pixels tall and nobody can see the third decimal; a
      // hand edited row must not be able to paint outside the widget.
      final back = reencode(
        const OversleepShare(
          webhookIds: {'w1'},
          recordingWaveform: [0.123456, -1, 5],
        ).toJson(),
        OversleepShare.fromJson,
      );
      expect(back.recordingWaveform, [0.12, 0.0, 1.0]);
    });

    test('the ids are sorted, so a save that changed nothing looks like it', () {
      expect(share.toJson()['webhookIds'], ['w1', 'w2']);
      expect(
        const OversleepShare(webhookIds: {'w1', 'w2'}),
        const OversleepShare(webhookIds: {'w2', 'w1'}),
        reason: 'equality does not read the ordering either',
      );
    });

    test('a share with nowhere to post is not a share', () {
      expect(const OversleepShare().isUsable, isFalse);
      expect(
        const OversleepShare(message: '起きろ').isUsable,
        isFalse,
        reason: 'a message with no destination never goes out',
      );
      expect(const OversleepShare(webhookIds: {'w1'}).isUsable, isTrue);
    });

    test('a cleared recording takes its waveform with it', () {
      final cleared = share.copyWith(clearRecordingPath: true);
      expect(cleared.recordingPath, isNull);
      expect(cleared.recordingWaveform, isEmpty);
      expect(cleared.webhookIds, share.webhookIds, reason: 'kept');
    });

    test('the default line names the time and nobody else', () {
      final at = DateTime(2026, 8, 27, 7, 5);
      expect(defaultOversleepShareMessage(at: at), '07:05 のアラームを解除できていません。');
      expect(
        oversleepShareBodyFor(const OversleepShare(webhookIds: {'w1'}), at),
        '07:05 のアラームを解除できていません。',
      );
    });

    test('the custom line wins only when there is one', () {
      final at = DateTime(2026, 8, 27, 7, 5);
      expect(oversleepShareBodyFor(share, at), '起きろ');
      expect(
        oversleepShareBodyFor(
          share.copyWith(messageMode: MessageMode.standard),
          at,
        ),
        defaultOversleepShareMessage(at: at),
        reason: 'デフォルト mode ignores the stored custom text',
      );
      expect(
        oversleepShareBodyFor(share.copyWith(message: '   '), at),
        defaultOversleepShareMessage(at: at),
        reason: 'an empty post says nothing',
      );
    });
  });

  test('Wallet json round trip', () {
    const w = Wallet(coins: 1200, tokens: 30);
    expect(reencode(w.toJson(), Wallet.fromJson), w);
    expect(w.copyWith(coins: 0), const Wallet(coins: 0, tokens: 30));
  });

  test('OjisanState json round trip', () {
    const o = OjisanState(totalOversleeps: 4, totalEarned: 5200);
    expect(reencode(o.toJson(), OjisanState.fromJson), o);
  });

  test('Settings json round trip', () {
    const s = Settings(
      themeId: 'sunrise',
      unlockedThemeIds: {'midnight', 'sunrise'},
    );
    expect(reencode(s.toJson(), Settings.fromJson), s);
    expect(const Settings().unlockedThemeIds, contains('midnight'));
  });

  test('Kakugo json round trip', () {
    expect(reencode(kakugo.toJson(), Kakugo.fromJson), kakugo);
    expect(kakugo.hostage, HostageType.coin);
  });
}
