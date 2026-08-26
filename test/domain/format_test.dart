import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/format.dart';
import 'package:wake_or_pay/domain/models.dart';

void main() {
  test('weekdayLabel covers Monday to Sunday and rejects the rest', () {
    expect(
      [for (var d = 1; d <= 7; d++) weekdayLabel(d)],
      ['月', '火', '水', '木', '金', '土', '日'],
    );
    expect(() => weekdayLabel(0), throwsArgumentError);
    expect(() => weekdayLabel(8), throwsArgumentError);
  });

  test('repeatDaysLabel names the common patterns', () {
    expect(repeatDaysLabel(const {}), '一回限り');
    expect(repeatDaysLabel(const {1, 2, 3, 4, 5, 6, 7}), '毎日');
    expect(repeatDaysLabel(const {1, 2, 3, 4, 5}), '平日');
    expect(repeatDaysLabel(const {6, 7}), '週末');
    expect(repeatDaysLabel(const {5, 1}), '月・金');
    expect(repeatDaysLabel(const {3}), '水');
  });

  test('hhmm pads both halves', () {
    expect(hhmm(7, 0), '07:00');
    expect(hhmm(23, 59), '23:59');
    expect(hhmm(0, 5), '00:05');
  });

  test('kakugoLabel distinguishes a plain alarm', () {
    expect(kakugoLabel(null), '覚悟なし');
    expect(
      kakugoLabel(const Kakugo(ratePerMinute: 100, cap: 2000)),
      '100 コイン/分 ・ 最大 2000',
    );
  });

  test('kakugoMood steps at the preset boundaries', () {
    expect(kakugoMood(1), '😴 まあ起きたい');
    expect(kakugoMood(9), '😴 まあ起きたい');
    expect(kakugoMood(10), '🙂 起きなきゃ');
    expect(kakugoMood(49), '🙂 起きなきゃ');
    expect(kakugoMood(50), '😐 絶対起きる');
    expect(kakugoMood(100), '😠 絶対に起きろ');
    expect(kakugoMood(499), '😠 絶対に起きろ');
    expect(kakugoMood(500), '💀 寝るな');
    expect(kakugoMood(10000), '💀 寝るな');
  });

  test('sessionResultLabel covers every status', () {
    for (final status in SessionStatus.values) {
      expect(sessionResultLabel(status), isNotEmpty);
    }
    expect(sessionResultLabel(SessionStatus.success), '起床成功');
  });

  test('formatDateTime is short and unambiguous within a year', () {
    expect(formatDateTime(DateTime(2026, 8, 27, 7, 5)), '8/27 07:05');
  });
}
