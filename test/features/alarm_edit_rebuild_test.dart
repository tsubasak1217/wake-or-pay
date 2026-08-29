import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/features/alarms/alarm_draft.dart';

import 'alarms_test.dart' show pumpHome;

/// The spec's performance rule: spinning the time wheel must not rebuild the
/// editor around it. Counters are the only way to see a rebuild that produces
/// identical pixels, so the editor keeps two — see [debugAlarmEditBuildCount].
///
/// Reasoning behind the fix, for the record: with the time in `setState`, one
/// drag of the wheel calls `onDateTimeChanged` on every frame and each call
/// marked the whole form dirty. `debugPrintRebuildDirtyWidgets` showed the
/// entire ListView subtree — chips, tiles, text fields — in the dirty list on
/// each of those frames. The time now lives in [alarmDraftProvider] and the
/// wheel only writes to it, so nothing above it is marked dirty at all.
void main() {
  testWidgets('spinning the time wheel does not rebuild the editor', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final before = debugAlarmEditBuildCount;
    expect(before, greaterThan(0), reason: 'the editor built at least once');

    final wheel = tester.getRect(find.byKey(const ValueKey('timeWheel')));
    await tester.dragFrom(
      Offset(wheel.center.dx - 60, wheel.center.dy),
      const Offset(0, -64),
    );
    await tester.pumpAndSettle();

    expect(
      debugAlarmEditBuildCount,
      before,
      reason: 'the wheel writes the draft; nothing else watches the time',
    );

    // …and the spin still landed, so isolation did not cost correctness.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      (await container.read(alarmRepositoryProvider).getAll()).single.hour,
      15,
    );
  });
}
