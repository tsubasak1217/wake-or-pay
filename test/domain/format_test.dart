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

  test('kakugoMinutesToCap is the ratio, and 0/分 never gets there', () {
    expect(kakugoMinutesToCap(100, 1000), 10);
    expect(kakugoMinutesToCap(500, 1000), 2);
    expect(kakugoMinutesToCap(3, 1000), closeTo(333.3, 0.1));
    expect(kakugoMinutesToCap(0, 1000), double.infinity);
    expect(kakugoMinutesToCap(-5, 1000), double.infinity);
  });

  test('kakugoBadge steps on minutes to the cap, not on the rate', () {
    // 2 / 5 / 10 / 30 分 to burn the whole pledge.
    expect(kakugoBadge(500, 1000), '💀', reason: '2分');
    expect(kakugoBadge(1000, 1000), '💀', reason: '1分');
    expect(kakugoBadge(501, 1000), '💀', reason: '2分弱');
    expect(kakugoBadge(499, 1000), '🔥', reason: '2分をわずかに超える');
    expect(kakugoBadge(200, 1000), '🔥', reason: '5分');
    expect(kakugoBadge(100, 1000), '⚠️', reason: '10分');
    expect(kakugoBadge(34, 1000), '💦', reason: '30分弱');
    expect(kakugoBadge(33, 1000), '💸', reason: '30分より長い');
    expect(kakugoBadge(1, 1000), '💸');

    // The same rate against a different cap is a different badge — that is the
    // whole point of reading the ratio.
    expect(kakugoBadge(100, 200), '💀');
    expect(kakugoBadge(100, 10000), '💸');

    expect(kakugoBadge(0, 1000), '', reason: '連絡だけの覚悟にバッジは付かない');
  });

  test('kakugoMood is the same bands as the badge', () {
    expect(kakugoMood(1, 1000), '😴 まあ起きたい');
    expect(kakugoMood(34, 1000), '🙂 起きなきゃ');
    expect(kakugoMood(100, 1000), '😐 絶対起きる');
    expect(kakugoMood(200, 1000), '😠 絶対に起きろ');
    expect(kakugoMood(500, 1000), '💀 寝るな');
    expect(kakugoMood(0, 1000), '😌 ペナルティなし');

    // Same band, same boundary: the gauge steps exactly where the badge does.
    expect(kakugoMood(34, 1000), isNot(kakugoMood(33, 1000)));
    expect(kakugoBadge(34, 1000), isNot(kakugoBadge(33, 1000)));
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
