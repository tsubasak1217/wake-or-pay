import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/activity_stats.dart';
import '../../domain/format.dart';
import '../../domain/journey_stats.dart';
import '../../domain/models.dart';
import '../../services/recording_library.dart';
import '../../services/voice_recorder.dart';
import '../alarms/widgets/settings_island.dart';
import '../profile/app_header.dart';
import 'contact_event_tile.dart';
import 'contact_log_archive_screen.dart';
import 'penalty_history_screen.dart';
import 'wake_time_history_screen.dart';
import 'wake_time_painter.dart';

/// アクティビティ — everything the app has recorded about the user's mornings:
/// what this month cost, when they got up, who was told, and what was said out
/// loud. See `docs/design/activity_spec_2026-08-30.png`.
///
/// Read-only by design, apart from deleting a recording: nothing here changes
/// how an alarm behaves, so a tap can never make tomorrow more expensive.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: const AppHeaderBar(),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        _MonthPenaltySection(),
        _WakeChartSection(),
        _ContactEventSection(),
        _RecordingsSection(),
      ],
    ),
  );
}

/// 「まだ記録はありません」 and friends, in the one place the padding is decided.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    child: Center(
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}

/// The 「もっと見る >」 in the bottom-right corner of a card. The chevron is the
/// promise that tapping goes somewhere.
class _MoreLink extends StatelessWidget {
  const _MoreLink({
    required this.linkKey,
    required this.label,
    required this.onTap,
  });

  /// Sits on the **InkWell**, not on the widget: the row is stretched across
  /// the card, so a key on the outside would point a test's tap at the empty
  /// half of it.
  final Key linkKey;

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        key: linkKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 今月の寝坊ペナルティ
// ---------------------------------------------------------------------------

/// What this calendar month has already cost, in both units at once.
///
/// Two headline figures rather than one total, because they are not the same
/// money: コイン is already gone, 円 is a promise the card has not been asked
/// about yet.
class _MonthPenaltySection extends ConsumerWidget {
  const _MonthPenaltySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions =
        ref.watch(allSessionsProvider).valueOrNull ?? const <AlarmSession>[];
    final charges =
        ref.watch(pendingChargesProvider).valueOrNull ?? const <PendingCharge>[];
    final month = monthlyPenalty(sessions, charges, ref.watch(clockProvider)());

    return SettingsIsland(
      key: const ValueKey('activityMonthCard'),
      title: '今月の寝坊ペナルティ',
      footer: Text(
        '※総額$minimumChargeableYen円未満の場合は請求されません',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '寝坊回数 ${month.oversleepCount}回'
                '　総寝坊時間 ${journeyDurationLabel(month.oversleep)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${thousands(month.yen)}円',
                style: theme.textTheme.displaySmall,
              ),
              Text(
                '${month.coins}コイン',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              _MoreLink(
                linkKey: const ValueKey('activityPenaltyHistoryLink'),
                label: 'ペナルティ履歴',
                onTap: () => pushPenaltyHistoryScreen(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 起床時間の遷移
// ---------------------------------------------------------------------------

class _WakeChartSection extends ConsumerWidget {
  const _WakeChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(allSessionsProvider).valueOrNull ?? const <AlarmSession>[];
    final today = dayOf(ref.watch(clockProvider)());
    final points = wakeTimes(sessions, today);

    return SettingsIsland(
      key: const ValueKey('activityWakeChart'),
      title: '起床時間の遷移(30日間)',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (points.isEmpty)
                const _EmptyNote('まだ記録はありません')
              else
                WakeTimeChart(
                  points: points,
                  firstDay: today.subtract(const Duration(days: 29)),
                  lastDay: today,
                ),
              const SizedBox(height: 4),
              _MoreLink(
                linkKey: const ValueKey('activityWakeMoreLink'),
                label: 'もっと見る',
                onTap: () => pushWakeTimeHistoryScreen(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 寝坊連絡・共有履歴
// ---------------------------------------------------------------------------

/// The five most recent contacts, with the whole archive a tap behind them.
class _ContactEventSection extends ConsumerWidget {
  const _ContactEventSection();

  /// How many rows the card carries. Any more and the tab becomes the archive.
  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(contactEventsProvider).valueOrNull ?? const <ContactEvent>[];

    return SettingsIsland(
      key: const ValueKey('activityContactLog'),
      title: '寝坊連絡・共有履歴',
      children: [
        if (events.isEmpty)
          const _EmptyNote('まだ記録はありません')
        else
          for (final event in events.take(_shown))
            ContactEventTile(event: event),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: _MoreLink(
            linkKey: const ValueKey('activityContactMoreLink'),
            label: 'もっと見る',
            onTap: () => pushContactLogArchiveScreen(context),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 寝言の録音
// ---------------------------------------------------------------------------

/// The recordings shelf, with playback and a delete that asks first.
///
/// Stateful because 「which one is playing」 lives nowhere else: the player
/// reports *that* something is playing, not what, so the path is held here and
/// cleared when the player says it stopped.
class _RecordingsSection extends ConsumerStatefulWidget {
  const _RecordingsSection();

  @override
  ConsumerState<_RecordingsSection> createState() => _RecordingsSectionState();
}

class _RecordingsSectionState extends ConsumerState<_RecordingsSection> {
  StreamSubscription<bool>? _playbackSubscription;
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _playbackSubscription = ref
        .read(voicePlayerProvider)
        .playing
        .listen((playing) {
          if (!playing && mounted) setState(() => _playingPath = null);
        });
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggle(Recording recording) async {
    final player = ref.read(voicePlayerProvider);
    if (_playingPath == recording.path) {
      await player.stop();
      if (mounted) setState(() => _playingPath = null);
      return;
    }
    await player.play(recording.path);
    if (mounted) setState(() => _playingPath = recording.path);
  }

  Future<void> _delete(Recording recording) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('recordingDeleteConfirm'),
            title: const Text('録音を削除しますか？'),
            content: const Text('この録音は端末から消えます。元には戻せません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('やめる'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('削除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    if (_playingPath == recording.path) {
      await ref.read(voicePlayerProvider).stop();
      if (mounted) setState(() => _playingPath = null);
    }
    await ref.read(recordingLibraryProvider).delete(recording.path);
    ref.invalidate(recordingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final recordings =
        ref.watch(recordingsProvider).valueOrNull ?? const <Recording>[];

    return SettingsIsland(
      key: const ValueKey('activityRecordings'),
      title: '寝言の録音',
      children: [
        if (recordings.isEmpty)
          const _EmptyNote('まだ録音はありません')
        else
          for (final recording in recordings)
            ListTile(
              key: ValueKey('recording-${recording.path}'),
              leading: IconButton(
                tooltip: _playingPath == recording.path ? '停止' : '再生',
                icon: Icon(
                  _playingPath == recording.path
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                ),
                onPressed: () => _toggle(recording),
              ),
              title: Text(
                recording.recordedAt == null
                    ? '日時不明'
                    : formatDateTime(recording.recordedAt!),
              ),
              trailing: IconButton(
                tooltip: '削除',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(recording),
              ),
            ),
      ],
    );
  }
}
