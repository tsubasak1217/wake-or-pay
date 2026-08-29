import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/journey_stats.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/profile_catalog.dart';
import 'package:wake_or_pay/domain/title_catalog.dart';

AlarmSession session({
  required String id,
  required DateTime firedAt,
  DateTime? dismissedAt,
  SessionStatus status = SessionStatus.success,
  int loss = 0,
}) => AlarmSession(
  id: id,
  alarmId: 'a1',
  firedAt: firedAt,
  dismissedAt: dismissedAt,
  status: status,
  loss: loss,
);

void main() {
  group('computeJourneyStats', () {
    test('an install with nothing in it', () {
      final stats = computeJourneyStats(
        sessions: const [],
        usage: const UsageStats(),
        profile: const Profile(),
      );

      expect(stats.startedAt, isNull);
      expect(journeyDateLabel(stats.startedAt), '—');
      expect(stats.loginDays, 0);
      expect(stats.totalPenalty, 0);
      expect(stats.maxPenalty, 0);
      expect(stats.settledCount, 0);
      expect(stats.successRate, isNull);
      expect(journeyRateLabel(stats.successRate), '—');
      expect(stats.oversleepCount, 0);
      expect(stats.totalOversleep, Duration.zero);
      expect(stats.maxOversleep, Duration.zero);
    });

    test('開始日 is the first launch, and the oldest ring without one', () {
      final sessions = [
        session(id: 's2', firedAt: DateTime(2026, 5, 4, 7)),
        session(id: 's1', firedAt: DateTime(2026, 3, 2, 7)),
      ];

      // An install from before the usage record existed: the history is all
      // there is, so the oldest ring stands in for the first launch.
      final derived = computeJourneyStats(
        sessions: sessions,
        usage: const UsageStats(),
        profile: const Profile(),
      );
      expect(derived.startedAt, DateTime(2026, 3, 2, 7));
      expect(journeyDateLabel(derived.startedAt), '2026/3/2');

      // With a record, the record wins — it is older than any ring can be.
      final recorded = computeJourneyStats(
        sessions: sessions,
        usage: UsageStats(firstOpenedAt: DateTime(2026, 1, 9, 21, 30)),
        profile: const Profile(),
      );
      expect(recorded.startedAt, DateTime(2026, 1, 9, 21, 30));
      expect(journeyDateLabel(recorded.startedAt), '2026/1/9');
    });

    test('a mixed history: penalties, rate, counts and durations', () {
      final stats = computeJourneyStats(
        sessions: [
          // 起床成功, no loss.
          session(
            id: 's1',
            firedAt: DateTime(2026, 8, 1, 7),
            dismissedAt: DateTime(2026, 8, 1, 7, 1),
            loss: 0,
          ),
          session(
            id: 's2',
            firedAt: DateTime(2026, 8, 2, 7),
            dismissedAt: DateTime(2026, 8, 2, 7, 2),
          ),
          session(
            id: 's3',
            firedAt: DateTime(2026, 8, 3, 7),
            dismissedAt: DateTime(2026, 8, 3, 7),
          ),
          // 寝坊 90 min, 1200 コイン.
          session(
            id: 's4',
            firedAt: DateTime(2026, 8, 4, 7),
            dismissedAt: DateTime(2026, 8, 4, 8, 30),
            status: SessionStatus.failed,
            loss: 1200,
          ),
          // 寝坊 20 min, 300 コイン.
          session(
            id: 's5',
            firedAt: DateTime(2026, 8, 5, 7),
            dismissedAt: DateTime(2026, 8, 5, 7, 20),
            status: SessionStatus.failed,
            loss: 300,
          ),
          // Still ringing: it has no outcome, so it counts towards nothing —
          // not the rate, not the total, not the duration.
          session(
            id: 's6',
            firedAt: DateTime(2026, 8, 6, 7),
            status: SessionStatus.ringing,
            loss: 9999,
          ),
        ],
        usage: UsageStats(
          firstOpenedAt: DateTime(2026, 7, 31),
          loginDays: 12,
        ),
        profile: const Profile(),
      );

      expect(stats.loginDays, 12);
      expect(stats.totalPenalty, 1500);
      expect(stats.maxPenalty, 1200);
      expect(stats.successCount, 3);
      expect(stats.oversleepCount, 2);
      expect(stats.settledCount, 5);
      expect(stats.successRate, closeTo(0.6, 1e-9));
      expect(journeyRateLabel(stats.successRate), '60%');
      expect(stats.totalOversleep, const Duration(minutes: 110));
      expect(stats.maxOversleep, const Duration(minutes: 90));
      expect(journeyDurationLabel(stats.totalOversleep), '1h 50分');
      expect(journeyDurationLabel(stats.maxOversleep), '1h 30分');
      expect(journeyPenaltyLabel(stats.totalPenalty), '1,500 コイン');
    });

    test('a 寝坊 that was never dismissed adds to the count, not the clock', () {
      final stats = computeJourneyStats(
        sessions: [
          session(
            id: 's1',
            firedAt: DateTime(2026, 8, 4, 7),
            status: SessionStatus.failed,
            loss: 500,
          ),
          // A clock that went backwards. Not a negative sleep.
          session(
            id: 's2',
            firedAt: DateTime(2026, 8, 5, 7),
            dismissedAt: DateTime(2026, 8, 5, 6),
            status: SessionStatus.failed,
            loss: 100,
          ),
        ],
        usage: const UsageStats(),
        profile: const Profile(),
      );

      expect(stats.oversleepCount, 2);
      expect(stats.totalPenalty, 600);
      expect(stats.totalOversleep, Duration.zero);
      expect(stats.maxOversleep, Duration.zero);
      expect(journeyRateLabel(stats.successRate), '0%');
    });

    test('所持コレクション数 counts every kind against the catalogue', () {
      final total =
          ProfileCatalog.icons.length +
          ProfileCatalog.plateBackgrounds.length +
          ProfileCatalog.frames.length +
          ProfileCatalog.backgrounds.length +
          TitleCatalog.wordCount;

      final all = computeJourneyStats(
        sessions: const [],
        usage: const UsageStats(),
        profile: const Profile(),
      );
      expect(all.totalCollections, total);
      expect(all.ownedCollections, total);

      final sparse = computeJourneyStats(
        sessions: const [],
        usage: const UsageStats(),
        profile: const Profile(
          ownedIconIds: {ProfileCatalog.defaultIconId},
          ownedPlateBackgroundIds: {},
          ownedFrameIds: {},
          ownedBackgroundIds: {ProfileCatalog.defaultBackgroundId},
          // One real word plus an id no catalogue has: the count is of the
          // catalogue, so the stranger cannot push it past the total.
          ownedTitleWordIds: {TitleCatalog.defaultPrefixId, 'retired'},
        ),
      );
      expect(sparse.ownedCollections, 3);
      expect(sparse.totalCollections, total);
    });
  });

  group('labels', () {
    test('durations read in hours and minutes', () {
      expect(journeyDurationLabel(Duration.zero), '0分');
      expect(journeyDurationLabel(const Duration(minutes: 7)), '7分');
      expect(journeyDurationLabel(const Duration(minutes: 59)), '59分');
      expect(journeyDurationLabel(const Duration(minutes: 60)), '1h 0分');
      expect(journeyDurationLabel(const Duration(minutes: 125)), '2h 5分');
      // Seconds are precision the number does not have.
      expect(journeyDurationLabel(const Duration(seconds: 90)), '1分');
      expect(journeyDurationLabel(const Duration(minutes: -5)), '0分');
    });

    test('the rate rounds to a whole percent', () {
      expect(journeyRateLabel(null), '—');
      expect(journeyRateLabel(0), '0%');
      expect(journeyRateLabel(1), '100%');
      expect(journeyRateLabel(2 / 3), '67%');
    });

    test('penalties are written the way money is', () {
      expect(journeyPenaltyLabel(0), '0 コイン');
      expect(journeyPenaltyLabel(1234567), '1,234,567 コイン');
    });
  });
}
