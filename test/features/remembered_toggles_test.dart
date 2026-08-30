import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/alarm_draft.dart';
import 'package:wake_or_pay/features/alarms/alarm_edit_screen.dart';

import 'alarms_test.dart' show pumpHome, toggleInEditor;

/// The alarm the tests start from: a snooze and a pledge that are both plainly
/// *not* the defaults, so "restored" cannot be confused with "re-seeded".
const _stored = Alarm(
  id: 'a1',
  hour: 7,
  minute: 30,
  snooze: Snooze(intervalMinutes: 9, maxCount: 4),
  kakugo: Kakugo(
    hostage: HostageType.card,
    ratePerMinute: 300,
    cap: 5000,
    snoozePenalty: 70,
    snoozeResetsClock: true,
  ),
);

Alarm seedOf(WidgetTester tester) =>
    tester.widget<TimeWheel>(find.byType(TimeWheel)).seed;

/// Opens the editor of the one stored alarm and hands back its draft key.
///
/// Read here and held, not looked up again later: toggling a row scrolls the
/// form, and the wheel [seedOf] reads the key off goes out of the tree with it.
Future<Alarm> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('07:30'));
  await tester.pumpAndSettle();
  expect(find.text('アラームを編集'), findsOneWidget);
  return seedOf(tester);
}

void main() {
  group('the pure helpers', () {
    test('スヌーズ off puts the settings away, on takes them back out', () {
      final off = alarmWithSnoozeEnabled(_stored, false);
      expect(off.snooze, isNull);
      expect(off.canSnooze, isFalse, reason: 'the live field alone decides');
      expect(
        off.rememberedSnooze,
        const Snooze(intervalMinutes: 9, maxCount: 4),
      );

      final on = alarmWithSnoozeEnabled(off, true);
      expect(on.snooze, const Snooze(intervalMinutes: 9, maxCount: 4));
      expect(on.rememberedSnooze, isNull, reason: 'the memory is spent');
      expect(on, _stored, reason: 'off then on is a round trip');
    });

    test('with nothing remembered スヌーズ comes on at the defaults', () {
      const bare = Alarm(id: 'a1', hour: 7, minute: 30);
      expect(alarmWithSnoozeEnabled(bare, true).snooze, const Snooze());
    });

    test('覚悟 off puts the whole pledge away, on takes it back out', () {
      final off = alarmWithKakugoEnabled(_stored, false);
      expect(off.kakugo, isNull);
      expect(off.isKakugo, isFalse);
      expect(off.rememberedKakugo, _stored.kakugo);

      final on = alarmWithKakugoEnabled(off, true);
      expect(on.kakugo, _stored.kakugo);
      expect(on.rememberedKakugo, isNull);
      expect(on, _stored);
    });

    test('with nothing remembered 覚悟 comes on at the seed', () {
      const bare = Alarm(id: 'a1', hour: 7, minute: 30);
      expect(alarmWithKakugoEnabled(bare, true).kakugo, defaultKakugo);
    });

    test('both survive a JSON round trip', () {
      final off = alarmWithKakugoEnabled(
        alarmWithSnoozeEnabled(_stored, false),
        false,
      );
      expect(Alarm.fromJson(off.toJson()), off);
      expect(Alarm.fromJson(off.toJson()).rememberedKakugo, _stored.kakugo);
    });
  });

  testWidgets('toggling スヌーズ off and on again restores 間隔 and 上限回数', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 50000);
    await container.read(alarmRepositoryProvider).save(_stored);
    await tester.pumpAndSettle();
    final seed = await _openEditor(tester);

    await toggleInEditor(tester, 'スヌーズ');
    expect(container.read(alarmDraftProvider(seed)).snooze, isNull);

    await toggleInEditor(tester, 'スヌーズ');
    expect(
      container.read(alarmDraftProvider(seed)).snooze,
      const Snooze(intervalMinutes: 9, maxCount: 4),
      reason: 'not the 5分 x 3回 defaults',
    );
  });

  testWidgets('toggling 覚悟 off and on again restores the whole pledge', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 50000);
    await container.read(alarmRepositoryProvider).save(_stored);
    await tester.pumpAndSettle();
    final seed = await _openEditor(tester);

    await toggleInEditor(tester, '覚悟');
    expect(container.read(alarmDraftProvider(seed)).kakugo, isNull);

    await toggleInEditor(tester, '覚悟');
    expect(container.read(alarmDraftProvider(seed)).kakugo, _stored.kakugo);
  });

  testWidgets('saving with both off and reopening still restores them', (
    tester,
  ) async {
    final container = await pumpHome(tester, coins: 50000);
    final repository = container.read(alarmRepositoryProvider);
    await repository.save(_stored);
    await tester.pumpAndSettle();
    await _openEditor(tester);

    await toggleInEditor(tester, 'スヌーズ');
    await toggleInEditor(tester, '覚悟');
    await tester.tap(find.byKey(const ValueKey('alarmSaveFab')));
    await tester.pumpAndSettle();

    // What was stored is an alarm that neither snoozes nor pledges…
    final saved = (await repository.getAll()).single;
    expect(saved.canSnooze, isFalse);
    expect(saved.isKakugo, isFalse);
    // …carrying, invisibly, what it used to be.
    expect(
      saved.rememberedSnooze,
      const Snooze(intervalMinutes: 9, maxCount: 4),
    );
    expect(saved.rememberedKakugo, _stored.kakugo);

    // Reopened days later, the toggles bring it all back.
    final seed = await _openEditor(tester);
    await toggleInEditor(tester, 'スヌーズ');
    await toggleInEditor(tester, '覚悟');
    final draft = container.read(alarmDraftProvider(seed));
    expect(draft.snooze, const Snooze(intervalMinutes: 9, maxCount: 4));
    expect(draft.kakugo, _stored.kakugo);
  });

  testWidgets('複製 copies what the original remembered', (tester) async {
    final container = await pumpHome(tester, coins: 50000);
    final off = alarmWithKakugoEnabled(
      alarmWithSnoozeEnabled(_stored, false),
      false,
    );
    await container.read(alarmRepositoryProvider).save(off);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('07:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alarmActionDuplicate')));
    await tester.pumpAndSettle();

    final copy = seedOf(tester);
    expect(copy.id, isNot(off.id));
    expect(copy.rememberedSnooze, off.rememberedSnooze);
    expect(copy.rememberedKakugo, off.rememberedKakugo);
  });
}
