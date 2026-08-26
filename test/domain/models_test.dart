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
