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
import 'day_bars_painter.dart';

/// アクティビティ — everything the app has recorded about the user's mornings:
/// how they went, what they cost, who was told, and what was said out loud.
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
        _WakeChartSection(),
        _PenaltySection(),
        _ContactEventSection(),
        _RecordingsSection(),
      ],
    ),
  );
}

/// How tall every strip in this screen is drawn.
const _stripHeight = 64.0;

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

// ---------------------------------------------------------------------------
// 起床・寝坊の記録
// ---------------------------------------------------------------------------

class _WakeChartSection extends ConsumerWidget {
  const _WakeChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions =
        ref.watch(allSessionsProvider).valueOrNull ?? const <AlarmSession>[];
    final outcomes = dailyOutcomes(sessions, ref.watch(clockProvider)());
    final success = successDays(outcomes);
    final overslept = oversleptDays(outcomes);

    return SettingsIsland(
      key: const ValueKey('activityWakeChart'),
      title: '起床・寝坊の記録',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _stripHeight,
                child: CustomPaint(
                  painter: DayBarsPainter(
                    bars: [
                      for (final outcome in outcomes)
                        DayBar(
                          color: switch (outcome.result) {
                            DayResult.success => theme.colorScheme.primary,
                            DayResult.failed => theme.colorScheme.error,
                            DayResult.none => theme.colorScheme.outlineVariant,
                          },
                          // A day with no ring is a floor tick, not a column:
                          // an empty month must not look like a good one.
                          fill: outcome.result == DayResult.none ? 0 : 1,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                success == 0 && overslept == 0
                    ? 'まだ記録はありません'
                    : '成功 $success ／ 寝坊 $overslept（直近30日）',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ペナルティ履歴
// ---------------------------------------------------------------------------

class _PenaltySection extends ConsumerWidget {
  const _PenaltySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions =
        ref.watch(allSessionsProvider).valueOrNull ?? const <AlarmSession>[];
    final charges =
        ref.watch(pendingChargesProvider).valueOrNull ?? const <PendingCharge>[];

    final rows = penaltySessions(sessions);
    final outcomes = dailyOutcomes(sessions, ref.watch(clockProvider)());
    final worst = outcomes.fold(0, (max, o) => o.penalty > max ? o.penalty : max);
    final pending = charges
        .where((c) => c.status == PendingChargeStatus.pending)
        .fold(0, (sum, c) => sum + c.amount);

    return SettingsIsland(
      key: const ValueKey('activityPenaltyList'),
      title: 'ペナルティ履歴',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '総支払額 ${journeyPenaltyLabel(totalPenalty(sessions))}',
              style: theme.textTheme.titleMedium,
            ),
            if (pending > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '請求予定 ${thousands(pending)} 円',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: _stripHeight,
              child: CustomPaint(
                painter: DayBarsPainter(
                  bars: [
                    for (final outcome in outcomes)
                      DayBar(
                        color: outcome.penalty > 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.outlineVariant,
                        // Against the worst day of the window, so the tallest
                        // column is always the day that hurt most.
                        fill: worst == 0 ? 0 : outcome.penalty / worst,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        if (rows.isEmpty)
          const _EmptyNote('まだペナルティはありません')
        else
          for (final session in rows)
            ListTile(
              key: ValueKey('penalty-${session.id}'),
              title: Text(formatDateTime(session.firedAt)),
              trailing: Text(
                isCardHostage(session)
                    ? '${thousands(session.loss)} 円をカードに請求予定'
                    : '−${session.loss} コイン',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 連絡・共有の記録
// ---------------------------------------------------------------------------

/// The oversleep contact log. Absent entirely until something has fired, so
/// nobody is shown an empty section about a feature they never set up.
class _ContactEventSection extends ConsumerWidget {
  const _ContactEventSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = ref.watch(contactEventsProvider).valueOrNull;
    if (events == null || events.isEmpty) return const SizedBox.shrink();

    return SettingsIsland(
      key: const ValueKey('activityContactLog'),
      title: '連絡・共有の記録',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          'Discord への共有・SMS・メールは、発火したときに実際に送信されます。',
          style: theme.textTheme.bodySmall,
        ),
      ),
      children: [
        for (final event in events)
          ListTile(
            key: ValueKey('contactEvent-${event.id}'),
            leading: Icon(
              contactChannelIcon(event.channel),
              color: theme.colorScheme.error,
            ),
            // The name already carries its honorific — or is 「Discord 2件」,
            // which takes none — because it is the same phrase the countdown
            // said out loud.
            title: Text('${event.contactName}へ'),
            subtitle: Text(
              [
                formatDateTime(event.firedAt),
                contactChannelLabel(event.channel),
                ?event.detail,
              ].join(' ・ '),
            ),
          ),
      ],
    );
  }
}

IconData contactChannelIcon(ContactChannel channel) => switch (channel) {
  ContactChannel.phone => Icons.phone_outlined,
  ContactChannel.sms => Icons.sms_outlined,
  ContactChannel.email => Icons.mail_outline,
  ContactChannel.discord => Icons.forum_outlined,
  ContactChannel.log => Icons.receipt_long_outlined,
};

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
