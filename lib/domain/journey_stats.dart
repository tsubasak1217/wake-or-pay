import 'package:flutter/foundation.dart';

import 'format.dart';
import 'models.dart';
import 'profile_catalog.dart';
import 'title_catalog.dart';

/// 「これまでの歩み」 — everything the profile says about the user, computed from
/// the session history, the usage record and the profile itself.
///
/// Pure and immutable: this is derived, never stored, so there is nothing to
/// migrate and no way for it to disagree with the rows it was computed from.
@immutable
class JourneyStats {
  const JourneyStats({
    this.startedAt,
    this.loginDays = 0,
    this.totalPenalty = 0,
    this.maxPenalty = 0,
    this.successCount = 0,
    this.oversleepCount = 0,
    this.totalOversleep = Duration.zero,
    this.maxOversleep = Duration.zero,
    this.ownedCollections = 0,
    this.totalCollections = 0,
  });

  /// 開始日. The first launch on record, or — for an install that predates the
  /// usage record — the oldest ring it still has. Null when there is neither.
  final DateTime? startedAt;

  final int loginDays;

  /// Coins lost across every settled session, and the worst single one.
  final int totalPenalty;
  final int maxPenalty;

  /// Settled sessions by outcome. [oversleepCount] is 累計寝坊回数.
  final int successCount;
  final int oversleepCount;

  /// How long the user stayed asleep past the alarm, summed and at its worst.
  /// Only failed sessions that were actually dismissed can contribute: one
  /// still ringing has no end yet.
  final Duration totalOversleep;
  final Duration maxOversleep;

  final int ownedCollections;
  final int totalCollections;

  /// How many rings have an outcome. Zero means every rate below is 「—」.
  int get settledCount => successCount + oversleepCount;

  /// 起床成功率, 0..1 — null when nothing has settled, because a rate over no
  /// rings is not 0%, it is nothing at all.
  double? get successRate =>
      settledCount == 0 ? null : successCount / settledCount;
}

/// Pure. [sessions] may be in any order and may include ringing ones.
JourneyStats computeJourneyStats({
  required List<AlarmSession> sessions,
  required UsageStats usage,
  required Profile profile,
}) {
  DateTime? earliestFired;
  var totalPenalty = 0;
  var maxPenalty = 0;
  var successCount = 0;
  var oversleepCount = 0;
  var totalOversleep = Duration.zero;
  var maxOversleep = Duration.zero;

  for (final session in sessions) {
    if (earliestFired == null || session.firedAt.isBefore(earliestFired)) {
      earliestFired = session.firedAt;
    }
    if (session.status == SessionStatus.ringing) continue;

    totalPenalty += session.loss;
    if (session.loss > maxPenalty) maxPenalty = session.loss;

    if (session.status == SessionStatus.success) {
      successCount++;
      continue;
    }

    oversleepCount++;
    final dismissedAt = session.dismissedAt;
    if (dismissedAt == null) continue;
    final slept = dismissedAt.difference(session.firedAt);
    // A row whose dismissal predates its ring is a clock that went backwards,
    // not a negative sleep. It contributes nothing rather than subtracting.
    if (slept.isNegative) continue;
    totalOversleep += slept;
    if (slept > maxOversleep) maxOversleep = slept;
  }

  return JourneyStats(
    startedAt: usage.firstOpenedAt ?? earliestFired,
    loginDays: usage.loginDays,
    totalPenalty: totalPenalty,
    maxPenalty: maxPenalty,
    successCount: successCount,
    oversleepCount: oversleepCount,
    totalOversleep: totalOversleep,
    maxOversleep: maxOversleep,
    ownedCollections: ownedCollectionCount(profile),
    totalCollections: totalCollectionCount,
  );
}

/// Every cosmetic there is: icons, plates, frames, 背景 and 称号の語. Pure.
int get totalCollectionCount =>
    ProfileCatalog.icons.length +
    ProfileCatalog.plateBackgrounds.length +
    ProfileCatalog.frames.length +
    ProfileCatalog.backgrounds.length +
    TitleCatalog.wordCount;

/// How many of them [profile] holds. Pure.
///
/// Counted against the catalogue rather than by set size, so an id left behind
/// by a retired cosmetic cannot push the count past the total.
int ownedCollectionCount(Profile profile) =>
    ProfileCatalog.icons.where((e) => profile.ownedIconIds.contains(e.id)).length +
    ProfileCatalog.plateBackgrounds
        .where((e) => profile.ownedPlateBackgroundIds.contains(e.id))
        .length +
    ProfileCatalog.frames
        .where((e) => profile.ownedFrameIds.contains(e.id))
        .length +
    ProfileCatalog.backgrounds
        .where((e) => profile.ownedBackgroundIds.contains(e.id))
        .length +
    [
      ...TitleCatalog.prefixes,
      ...TitleCatalog.connectors,
      ...TitleCatalog.suffixes,
    ].where((w) => profile.ownedTitleWordIds.contains(w.id)).length;

// ---------------------------------------------------------------------------
// How each of them reads on the row. All pure, all tested.
// ---------------------------------------------------------------------------

/// 開始日. 「—」 for an install with no record and no history at all.
String journeyDateLabel(DateTime? at) =>
    at == null ? '—' : '${at.year}/${at.month}/${at.day}';

/// 「2h 30分」 / 「30分」 / 「0分」. Pure.
///
/// Minutes, not seconds: this is how long somebody stayed in bed, and a figure
/// to the second would be precision the number does not have.
String journeyDurationLabel(Duration d) {
  final minutes = d.inMinutes < 0 ? 0 : d.inMinutes;
  final hours = minutes ~/ 60;
  return hours == 0 ? '$minutes分' : '${hours}h ${minutes % 60}分';
}

/// 起床成功率, rounded to a whole percent. 「—」 when nothing has settled.
String journeyRateLabel(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';

/// A penalty figure in the unit 覚悟 is measured in.
String journeyPenaltyLabel(int coins) => '${thousands(coins)} コイン';
