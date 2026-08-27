import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';

/// The alarm currently being edited, keyed by the alarm it started from.
///
/// It lives in a provider rather than in the editor's [State] so that a change
/// to one field only rebuilds the rows that watch that field: spinning the time
/// wheel writes hour and minute on every frame, and every other row of the
/// editor subscribes with `select`, so none of them are touched by it.
///
/// The seed is the family key rather than something written in `initState`,
/// because Riverpod forbids writing to a provider from a widget life-cycle —
/// and a draft seeded one frame late would show 07:00 for that frame and, worse,
/// hand the time wheel the wrong `initialDateTime`, which it only reads once.
///
/// `autoDispose`, so closing the editor throws the draft away: the rows keep it
/// alive while the editor is on screen, including while a sub-screen sits on
/// top of it.
final alarmDraftProvider = NotifierProvider.autoDispose
    .family<AlarmDraft, Alarm, Alarm>(AlarmDraft.new);

class AlarmDraft extends AutoDisposeFamilyNotifier<Alarm, Alarm> {
  @override
  Alarm build(Alarm seed) => seed;

  /// [Alarm] is a value type, so writing an identical alarm is not a change and
  /// Riverpod drops it — the wheel settling back onto the same minute costs
  /// nothing.
  void setTime(int hour, int minute) =>
      state = state.copyWith(hour: hour, minute: minute);

  void update(Alarm Function(Alarm draft) change) => state = change(state);
}

/// How many times the editor's body has been rebuilt. Test-only: the spec
/// requires that spinning the time wheel does not rebuild the editor around it,
/// and a counter is the only way to see a rebuild that produces identical
/// pixels. Not `@visibleForTesting` because the editor itself increments it.
int debugAlarmEditBuildCount = 0;

/// Build counts per settings row label, for the same reason.
final debugRowBuildCounts = <String, int>{};
