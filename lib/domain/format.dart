import 'models.dart';

const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// 1 = Monday … 7 = Sunday, matching [DateTime.weekday]. Pure.
String weekdayLabel(int weekday) {
  if (weekday < 1 || weekday > 7) {
    throw ArgumentError.value(weekday, 'weekday', 'must be 1-7');
  }
  return _weekdayLabels[weekday - 1];
}

/// How a repeat rule reads on the alarm list. Pure.
String repeatDaysLabel(Set<int> days) {
  if (days.isEmpty) return '一回限り';
  if (days.length == 7) return '毎日';
  if (days.length == 5 && days.containsAll(const {1, 2, 3, 4, 5})) return '平日';
  if (days.length == 2 && days.containsAll(const {6, 7})) return '週末';
  return (days.toList()..sort()).map(weekdayLabel).join('・');
}

String hhmm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// A countdown, `m:ss`. Pure.
String mmss(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime t) =>
    '${t.month}/${t.day} ${hhmm(t.hour, t.minute)}';

/// The kakugo summary shown under an alarm. Pure.
String kakugoLabel(Kakugo? kakugo) => kakugo == null
    ? '覚悟なし'
    : '${kakugo.ratePerMinute} コイン/分 ・ 最大 ${kakugo.cap}';

/// How a snooze rule reads on a row of the editor. Pure.
String snoozeLabel(Snooze? snooze) => snooze == null
    ? 'オフ'
    : '${snooze.intervalMinutes}分 ・ 最大${snooze.maxCount}回';

/// The rate on its own, for the alarm list. Pure.
String kakugoRateLabel(int ratePerMinute) => '$ratePerMinute コイン/分';

/// The worst case, in the editor's own words. Pure.
///
/// The same sentence as the 覚悟 island's header, because it is the same
/// number: the list must not make the stake look smaller than the editor did.
String maxLossLabel(int cap) => '寝坊で失う最大金額 $cap コイン';

/// The badge on a 覚悟 row of the alarm list, by the same thresholds as
/// [kakugoMood]. Pure.
///
/// One glance down a list of alarms should say which of them can hurt, and how
/// much, before any of the numbers are read.
String kakugoBadge(int ratePerMinute) {
  if (ratePerMinute >= 500) return '💀';
  if (ratePerMinute >= 100) return '🔥';
  if (ratePerMinute >= 50) return '⚠️';
  if (ratePerMinute >= 10) return '💦';
  return '💸';
}

/// The gauge wording from the concept doc, by rate. Pure.
String kakugoMood(int ratePerMinute) {
  if (ratePerMinute >= 500) return '💀 寝るな';
  if (ratePerMinute >= 100) return '😠 絶対に起きろ';
  if (ratePerMinute >= 50) return '😐 絶対起きる';
  if (ratePerMinute >= 10) return '🙂 起きなきゃ';
  return '😴 まあ起きたい';
}

/// How a logged contact reads in the history. Pure.
String contactChannelLabel(ContactChannel channel) => switch (channel) {
  ContactChannel.phone => '電話',
  ContactChannel.email => 'メール',
  ContactChannel.log => '記録のみ',
};

String sessionResultLabel(SessionStatus status) => switch (status) {
  SessionStatus.ringing => '鳴動中',
  SessionStatus.success => '起床成功',
  SessionStatus.failed => '起床失敗',
};
