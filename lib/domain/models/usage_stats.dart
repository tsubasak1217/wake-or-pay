import 'package:flutter/foundation.dart';

/// What the app knows about being opened at all: when it was first opened, and
/// on how many separate days since.
///
/// Nothing here comes from an alarm — 「これまでの歩み」 needs 開始日 and
/// ログイン日数, and neither can be derived from a history of rings: an install
/// that has never rung an alarm still has both.
@immutable
class UsageStats {
  const UsageStats({
    this.firstOpenedAt,
    this.loginDays = 0,
    this.lastLoginDay = '',
  });

  /// The first launch on record. Written once and never again.
  final DateTime? firstOpenedAt;

  /// How many distinct local calendar days the app has been opened on.
  final int loginDays;

  /// The last day counted, `yyyy-MM-dd` in local time. Stored rather than
  /// derived, because the count is of *distinct* days and a set of every day
  /// ever would grow without a ceiling.
  final String lastLoginDay;

  @override
  bool operator ==(Object other) =>
      other is UsageStats &&
      other.firstOpenedAt == firstOpenedAt &&
      other.loginDays == loginDays &&
      other.lastLoginDay == lastLoginDay;

  @override
  int get hashCode => Object.hash(firstOpenedAt, loginDays, lastLoginDay);

  @override
  String toString() =>
      'UsageStats(first $firstOpenedAt, $loginDays days, last $lastLoginDay)';
}

/// `yyyy-MM-dd` in **local** time. Pure.
///
/// Local on purpose: 「ログイン日数」 is a count of the user's own days, and a UTC
/// key would roll over mid-evening in Japan and count one evening as two.
String usageDayKey(DateTime at) =>
    '${at.year.toString().padLeft(4, '0')}-'
    '${at.month.toString().padLeft(2, '0')}-'
    '${at.day.toString().padLeft(2, '0')}';
