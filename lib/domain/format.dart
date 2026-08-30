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

/// The first line of the 起床猶予 sub-screen description, shown regardless of
/// 覚悟.
const graceDescriptionBase = 'この時間内に起きるとボーナスコインが獲得できます。';

/// The second line, appended only when 覚悟 is armed — the grace window is
/// also the penalty's fuse in that case, and the description says so.
const graceDescriptionKakugo = '猶予時間を経過してしまうと覚悟設定のペナルティが発生します。';

/// The 起床猶予 sub-screen description for a given 覚悟 state. Pure.
String graceDescription(bool kakugo) =>
    kakugo ? '$graceDescriptionBase\n$graceDescriptionKakugo' : graceDescriptionBase;

/// How a snooze rule reads on a row of the editor. Pure.
String snoozeLabel(Snooze? snooze) => snooze == null
    ? 'オフ'
    : '${snooze.intervalMinutes}分 ・ 最大${snooze.maxCount}回';

/// 1234567 → 「1,234,567」. Pure.
///
/// Only ever used for 円: a coin count is a game number and reads better bare,
/// while a yen figure is money and is written the way money is written.
String thousands(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// One kakugo amount in the unit its 人質 is measured in. Pure.
///
/// 「1000 コイン」 for a coin pledge, 「1,000 円」 for a card one — the same stored
/// integer, because 1 コイン = 1 円.
String hostageAmount(int amount, HostageType hostage) =>
    hostage == HostageType.card
    ? '${thousands(amount)} ${hostage.unit}'
    : '$amount ${hostage.unit}';

/// What a カード人質 loss actually means, in one line. Pure.
///
/// Nothing is charged when this is shown — Phase 1 charges nothing at all, and
/// even in Phase 3 the card is touched once, at the end of the month. 「請求」,
/// never 「課金」 or 「購入」: the app is collecting on a pledge, not selling.
String cardChargeNotice(int amount) =>
    '${thousands(amount)} 円をカードに請求予定（月末）';

/// The rate on its own, for the alarm list. Pure.
String kakugoRateLabel(int ratePerMinute, [
  HostageType hostage = HostageType.coin,
]) => '${hostageAmount(ratePerMinute, hostage)}/分';

/// The worst case, in the editor's own words. Pure.
///
/// The same sentence as the 覚悟 island's header, because it is the same
/// number: the list must not make the stake look smaller than the editor did.
String maxLossLabel(int cap) => '寝坊で失う最大金額 $cap コイン';

/// How many minutes of oversleeping it takes to burn the whole pledge. Pure.
///
/// The rate on its own says nothing: 100 コイン/分 against a 200 コイン cap is
/// over in two minutes, and against a 10000 コイン cap it is a hundred. What
/// hurts is the ratio, so that is what the badge and the gauge are read from.
///
/// A rate of 0 never reaches the cap by the minute — infinity, and every band
/// below is written to fall through to "no penalty".
double kakugoMinutesToCap(int ratePerMinute, int cap) =>
    ratePerMinute <= 0 ? double.infinity : cap / ratePerMinute;

/// -1 = no per-minute penalty at all, then 0 (mildest) … 4 (worst).
int _kakugoBand(int ratePerMinute, int cap) {
  final minutes = kakugoMinutesToCap(ratePerMinute, cap);
  if (minutes <= 2) return 4;
  if (minutes <= 5) return 3;
  if (minutes <= 10) return 2;
  if (minutes <= 30) return 1;
  return minutes.isFinite ? 0 : -1;
}

/// The badge beside the time on a 覚悟 row of the alarm list. Pure.
///
/// One glance down a list of alarms should say which of them can hurt, and how
/// fast, before any of the numbers are read. Empty when there is no per-minute
/// penalty — a 連絡だけ pledge wears no badge.
String kakugoBadge(int ratePerMinute, int cap) =>
    switch (_kakugoBand(ratePerMinute, cap)) {
      4 => '💀',
      3 => '🔥',
      2 => '⚠️',
      1 => '💦',
      0 => '💸',
      _ => '',
    };

/// The gauge wording from the concept doc, off the same bands as [kakugoBadge]
/// so the editor and the list can never disagree. Pure.
String kakugoMood(int ratePerMinute, int cap) =>
    switch (_kakugoBand(ratePerMinute, cap)) {
      4 => '💀 寝るな',
      3 => '😠 絶対に起きろ',
      2 => '😐 絶対起きる',
      1 => '🙂 起きなきゃ',
      0 => '😴 まあ起きたい',
      _ => '😌 ペナルティなし',
    };

/// How a logged contact reads in the history. Pure.
String contactChannelLabel(ContactChannel channel) => switch (channel) {
  ContactChannel.phone => '電話',
  ContactChannel.sms => 'SMS',
  ContactChannel.email => 'メール',
  ContactChannel.discord => 'Discord',
  ContactChannel.log => '記録のみ',
};

String sessionResultLabel(SessionStatus status) => switch (status) {
  SessionStatus.ringing => '鳴動中',
  SessionStatus.success => '起床成功',
  SessionStatus.failed => '起床失敗',
};
