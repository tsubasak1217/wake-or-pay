import 'package:flutter/foundation.dart';

/// How often a snoozed alarm comes back, in minutes.
const minSnoozeIntervalMinutes = 1;
const maxSnoozeIntervalMinutes = 30;

/// How many times it may be snoozed. 0 is not "unlimited" — it means the
/// snooze button never appears. There is deliberately no unlimited option.
const minSnoozeMaxCount = 0;
const maxSnoozeMaxCount = 10;

int normalizeSnoozeInterval(int minutes) =>
    minutes.clamp(minSnoozeIntervalMinutes, maxSnoozeIntervalMinutes);

int normalizeSnoozeMaxCount(int count) =>
    count.clamp(minSnoozeMaxCount, maxSnoozeMaxCount);

/// One alarm's snooze rule.
///
/// Snooze is a free, standard feature: nothing here is ever sold, and no
/// setting is gated. In kakugo mode it becomes something that *costs* — see
/// `Kakugo.snoozePenalty` — but that is a punishment, not a purchase.
@immutable
class Snooze {
  const Snooze({
    this.intervalMinutes = defaultIntervalMinutes,
    this.maxCount = defaultMaxCount,
  });

  static const defaultIntervalMinutes = 5;
  static const defaultMaxCount = 3;

  final int intervalMinutes;
  final int maxCount;

  Snooze copyWith({int? intervalMinutes, int? maxCount}) => Snooze(
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    maxCount: maxCount ?? this.maxCount,
  );

  Map<String, dynamic> toJson() => {
    'intervalMinutes': intervalMinutes,
    'maxCount': maxCount,
  };

  /// Like the grace window, the bounds are re-applied on every read: a hand
  /// edited database cannot widen them.
  factory Snooze.fromJson(Map<String, dynamic> json) => Snooze(
    intervalMinutes: normalizeSnoozeInterval(
      json['intervalMinutes'] as int? ?? defaultIntervalMinutes,
    ),
    maxCount: normalizeSnoozeMaxCount(
      json['maxCount'] as int? ?? defaultMaxCount,
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is Snooze &&
      other.intervalMinutes == intervalMinutes &&
      other.maxCount == maxCount;

  @override
  int get hashCode => Object.hash(intervalMinutes, maxCount);

  @override
  String toString() => 'Snooze(${intervalMinutes}m x $maxCount)';
}
