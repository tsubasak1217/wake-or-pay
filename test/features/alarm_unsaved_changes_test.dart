import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/alarm_draft.dart';
import 'package:wake_or_pay/features/alarms/alarm_edit_screen.dart';

import 'alarms_test.dart' show pumpHome;

/// The editor's draft key, read off the wheel — the same trick the duplicate
/// tests use, because the seed is not something the test can name for itself.
Alarm seedOf(WidgetTester tester) =>
    tester.widget<TimeWheel>(find.byType(TimeWheel)).seed;

Finder get _dialog => find.byKey(const ValueKey('unsavedDialog'));

/// Opens the editor of the one stored alarm.
Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('07:30'));
  await tester.pumpAndSettle();
  expect(find.text('アラームを編集'), findsOneWidget);
}

void main() {
  testWidgets('backing out of an untouched editor pops with no question', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    await container
        .read(alarmRepositoryProvider)
        .save(const Alarm(id: 'a1', hour: 7, minute: 30));
    await tester.pumpAndSettle();
    await _openEditor(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing, reason: 'nothing was changed');
    expect(find.text('アラームを編集'), findsNothing, reason: 'it popped');
  });

  testWidgets('a changed draft is guarded, and 保存 writes it and pops', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    final repository = container.read(alarmRepositoryProvider);
    await repository.save(const Alarm(id: 'a1', hour: 7, minute: 30));
    await tester.pumpAndSettle();
    await _openEditor(tester);

    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(9, 15);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
    expect(find.text('変更を保存していません'), findsOneWidget);
    expect(find.text('このまま戻ると変更は失われます。'), findsOneWidget);

    // 保存, not 編集を続ける: the way out of the dialog that keeps the change is
    // the one that stores it, and it leaves the editor exactly as the FAB does.
    await tester.tap(find.byKey(const ValueKey('unsavedSave')));
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(find.text('アラームを編集'), findsNothing, reason: 'it popped');
    final saved = (await repository.getAll()).single;
    expect((saved.hour, saved.minute), (9, 15));
    expect(find.text('09:15'), findsOneWidget, reason: 'the row moved');
  });

  testWidgets('保存 from the dialog refuses a time clash and stays open', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    final repository = container.read(alarmRepositoryProvider);
    await repository.save(const Alarm(id: 'a1', hour: 7, minute: 30));
    await repository.save(const Alarm(id: 'a2', hour: 9, minute: 15));
    await tester.pumpAndSettle();
    await _openEditor(tester);

    // Straight onto the other alarm's minute: the one rule the save refuses on.
    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(9, 15);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('unsavedSave')));
    await tester.pumpAndSettle();

    // The dialog is gone, the editor is not: the save answered by carrying the
    // user back to the wheel, with the warning under it.
    expect(_dialog, findsNothing);
    expect(find.text('アラームを編集'), findsOneWidget, reason: 'still editing');
    expect(find.byKey(const ValueKey('duplicateTimeWarning')), findsOneWidget);
    // And nothing was written: 07:30 is still 07:30.
    final stored = await repository.getById('a1');
    expect((stored!.hour, stored.minute), (7, 30));
  });

  testWidgets('破棄して戻る pops and leaves the stored alarm alone', (tester) async {
    final container = await pumpHome(tester, coins: 5000);
    final repository = container.read(alarmRepositoryProvider);
    await repository.save(const Alarm(id: 'a1', hour: 7, minute: 30));
    // Read back rather than compared against the literal: the write fills the
    // trigger-delay column in, so the row is not byte-for-byte the constant.
    final stored = (await repository.getAll()).single;
    await tester.pumpAndSettle();
    await _openEditor(tester);

    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(9, 15);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('unsavedDiscard')));
    await tester.pumpAndSettle();

    expect(find.text('アラームを編集'), findsNothing, reason: 'it popped');
    expect(find.text('07:30'), findsOneWidget, reason: 'the row never moved');
    expect((await repository.getAll()).single, stored);
  });

  testWidgets('saving pops without ever asking about unsaved changes', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 5000);
    final repository = container.read(alarmRepositoryProvider);
    await repository.save(const Alarm(id: 'a1', hour: 7, minute: 30));
    await tester.pumpAndSettle();
    await _openEditor(tester);

    container.read(alarmDraftProvider(seedOf(tester)).notifier).setTime(9, 15);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('alarmSaveFab')));
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing, reason: 'the save is not a discard');
    expect(find.text('アラームを編集'), findsNothing);
    final saved = (await repository.getAll()).single;
    expect((saved.hour, saved.minute), (9, 15));
  });
}
