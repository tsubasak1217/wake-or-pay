import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/widgets/swipe_to_delete.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';
import 'alarms_test.dart' show pumpHome;

void main() {
  testWidgets('swiping a row left reveals 削除, which deletes on a tap', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    await container
        .read(alarmRepositoryProvider)
        .save(const Alarm(id: 'a1', hour: 6, minute: 30));
    await tester.pumpAndSettle();

    expect(find.text('削除'), findsNothing, reason: 'hidden behind the row');

    await tester.drag(find.text('06:30'), const Offset(-120, 0));
    await tester.pumpAndSettle();

    // The row has moved aside; the action underneath is now reachable.
    expect(find.text('削除'), findsOneWidget);
    expect(
      await container.read(alarmRepositoryProvider).getAll(),
      hasLength(1),
      reason: 'revealing is not deleting',
    );

    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(await container.read(alarmRepositoryProvider).getAll(), isEmpty);
    expect(find.text('アラームはまだありません'), findsOneWidget);

    // The platform alarm went with it.
    final fake = container.read(alarmServiceProvider) as FakeAlarmService;
    expect(fake.cancelled, contains('a1'));
  });

  testWidgets('a half swipe springs back and deletes nothing', (tester) async {
    final container = await pumpHome(tester);
    await container
        .read(alarmRepositoryProvider)
        .save(const Alarm(id: 'a1', hour: 6, minute: 30));
    await tester.pumpAndSettle();

    await tester.drag(find.text('06:30'), const Offset(-20, 0));
    await tester.pumpAndSettle();

    expect(
      await container.read(alarmRepositoryProvider).getAll(),
      hasLength(1),
    );
    expect(find.text('削除'), findsNothing, reason: 'it sprang back shut');
  });

  testWidgets('tapping an open row closes it instead of opening the editor', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    await container
        .read(alarmRepositoryProvider)
        .save(const Alarm(id: 'a1', hour: 6, minute: 30));
    await tester.pumpAndSettle();

    await tester.drag(find.text('06:30'), const Offset(-120, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('06:30'));
    await tester.pumpAndSettle();

    expect(
      find.text('アラームを編集'),
      findsNothing,
      reason: 'the tap only closed it',
    );
    expect(find.text('削除'), findsNothing);
    expect(
      await container.read(alarmRepositoryProvider).getAll(),
      hasLength(1),
    );
  });

  testWidgets('the row that moves up is not left swiped open', (tester) async {
    final container = await pumpHome(tester);
    final repo = container.read(alarmRepositoryProvider);
    await repo.save(const Alarm(id: 'a1', hour: 6, minute: 30));
    await repo.save(const Alarm(id: 'a2', hour: 8, minute: 15));
    await tester.pumpAndSettle();

    await tester.drag(find.text('06:30'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('削除'), findsOneWidget);

    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    // The swipe state belongs to the alarm, not to the slot it sat in: 08:15
    // inherits nothing by moving up into the deleted row's place.
    expect(await repo.getAll(), hasLength(1));
    expect(find.text('08:15'), findsOneWidget);
    expect(find.byType(SwipeToDelete), findsOneWidget);
    expect(
      tester.state<SwipeToDeleteState>(find.byType(SwipeToDelete)).isRevealed,
      isFalse,
    );
    expect(find.text('削除'), findsNothing);
  });

  testWidgets('the deleted row collapses instead of the list jumping', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    final repo = container.read(alarmRepositoryProvider);
    await repo.save(const Alarm(id: 'a1', hour: 6, minute: 30));
    await repo.save(const Alarm(id: 'a2', hour: 8, minute: 15));
    await tester.pumpAndSettle();

    await tester.drag(find.text('06:30'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));

    // Mid-flight: the gone row is still on screen, shrinking.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SizeTransition), findsAtLeastNWidgets(1));

    await tester.pumpAndSettle();
    expect(find.byType(SwipeToDelete), findsOneWidget);
    expect(find.text('06:30'), findsNothing);
  });
}
