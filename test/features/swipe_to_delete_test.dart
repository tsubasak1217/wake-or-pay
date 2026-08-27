import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
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
}
