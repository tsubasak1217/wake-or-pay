import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/activity_stats.dart';
import '../../domain/models.dart';
import 'contact_event_tile.dart';

/// 寝坊連絡・共有履歴 のアーカイブ — a year at a time, a month at a tap.
///
/// Only years that hold something are drawn, and only months up to this one: a
/// grid of twelve grey tiles under a year nothing happened in is a page that
/// says nothing, and a tile for next March is a promise the calendar has not
/// made yet.
class ContactLogArchiveScreen extends ConsumerStatefulWidget {
  const ContactLogArchiveScreen({super.key});

  @override
  ConsumerState<ContactLogArchiveScreen> createState() =>
      _ContactLogArchiveScreenState();
}

Future<void> pushContactLogArchiveScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ContactLogArchiveScreen()),
    );

class _ContactLogArchiveScreenState
    extends ConsumerState<ContactLogArchiveScreen> {
  /// Which tile is lit, and whose events are listed under the grid. Null until
  /// the user picks one — the archive opens on the index, not on a month.
  ({int year, int month})? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events =
        ref.watch(allContactEventsProvider).valueOrNull ??
        const <ContactEvent>[];
    final years = monthsWithEvents(events, ref.watch(clockProvider)());
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: const Text('寝坊連絡・共有履歴')),
      body: years.isEmpty
          ? const Center(
              key: ValueKey('archiveEmpty'),
              child: Text('まだ記録はありません'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (final year in years) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${year.year}',
                      key: ValueKey('archiveYear-${year.year}'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    children: [
                      for (final month in year.months)
                        _MonthTile(
                          year: year.year,
                          month: month,
                          enabled: year.active.contains(month),
                          selected:
                              selected != null &&
                              selected.year == year.year &&
                              selected.month == month,
                          onTap: () => setState(
                            () => _selected = (year: year.year, month: month),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                if (selected != null) ...[
                  Text(
                    '${selected.year}年${selected.month}月',
                    key: const ValueKey('archiveMonthHeading'),
                    style: theme.textTheme.titleMedium,
                  ),
                  for (final event in eventsInMonth(
                    events,
                    selected.year,
                    selected.month,
                  ))
                    ContactEventTile(event: event),
                ],
              ],
            ),
    );
  }
}

/// One 「8月」 island. A month with nothing behind it is grey and does not
/// answer a tap — the same rule the unowned cosmetics follow.
class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.year,
    required this.month,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final int year;
  final int month;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = ValueKey(
      'archiveMonth-$year-${month.toString().padLeft(2, '0')}',
    );

    return Material(
      key: key,
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        // A null callback is what makes the tile inert; the grey below says the
        // same thing in colour, so the two can never disagree.
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            '$month月',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}
