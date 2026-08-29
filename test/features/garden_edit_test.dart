import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/features/garden/garden_edit_screen.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpEditor(WidgetTester tester) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('庭'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('模様替え'));
  await tester.pumpAndSettle();
  return container;
}

/// Drags [from] onto [to] the way a finger would: press, move in steps so the
/// drag is recognised, then release.
Future<void> dragOnto(WidgetTester tester, Finder from, Finder to) async {
  final start = tester.getCenter(from);
  final end = tester.getCenter(to);
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 100));
  for (var i = 1; i <= 8; i += 1) {
    await gesture.moveTo(Offset.lerp(start, end, i / 8)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the editor opens with the shelf and the current garden', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.byType(GardenEditScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('shelf')), findsOneWidget);
    // The starter set: moss and two pebbles are still in hand.
    expect(find.byKey(const ValueKey('shelf-plant_moss')), findsOneWidget);
    expect(find.byKey(const ValueKey('shelf-deco_pebble')), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('dragging from the shelf onto the floor places the item', (
    tester,
  ) async {
    final container = await pumpEditor(tester);

    await dragOnto(
      tester,
      find.byKey(const ValueKey('shelf-plant_moss')),
      find.byKey(const ValueKey('cell-0-5')),
    );

    // Committed only by 完了, so the store is untouched until then.
    expect(
      (await container.read(gardenRepositoryProvider).read()).placements,
      hasLength(1),
    );

    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    final state = await container.read(gardenRepositoryProvider).read();
    expect(state.placements, hasLength(2));
    final moss = state.placements.firstWhere((p) => p.itemId == 'plant_moss');
    expect(moss.x, 0);
    expect(moss.y, 5);
    expect(state.inventory.countOf('plant_moss'), 0, reason: 'left the shelf');
  });

  testWidgets('a placed item can be dragged to another cell', (tester) async {
    final container = await pumpEditor(tester);

    final before = (await container.read(gardenRepositoryProvider).read())
        .placements
        .single;
    expect((before.x, before.y), (3, 2), reason: 'the granted plant');

    await dragOnto(
      tester,
      find.byKey(ValueKey('placement-${before.id}')),
      find.byKey(const ValueKey('cell-6-0')),
    );
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    final after = (await container.read(gardenRepositoryProvider).read())
        .placements
        .single;
    expect(after.id, before.id, reason: 'moved, not replaced');
    expect((after.x, after.y), (6, 0));
  });

  testWidgets('dragging a placed item onto the shelf stores it again', (
    tester,
  ) async {
    final container = await pumpEditor(tester);
    final placed = (await container.read(gardenRepositoryProvider).read())
        .placements
        .single;

    await dragOnto(
      tester,
      find.byKey(ValueKey('placement-${placed.id}')),
      find.byKey(const ValueKey('shelf')),
    );
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    final state = await container.read(gardenRepositoryProvider).read();
    expect(state.placements, isEmpty);
    expect(state.inventory.countOf('plant_small'), 1);
  });

  testWidgets('an occupied cell refuses the drop', (tester) async {
    final container = await pumpEditor(tester);

    // The granted plant sits at (3,2); drop the moss right on top of it.
    await dragOnto(
      tester,
      find.byKey(const ValueKey('shelf-plant_moss')),
      find.byKey(const ValueKey('cell-3-2')),
    );
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    final state = await container.read(gardenRepositoryProvider).read();
    expect(state.placements, hasLength(1), reason: 'nothing was placed');
    expect(state.inventory.countOf('plant_moss'), 1, reason: 'still in hand');
  });

  testWidgets('backing out without 完了 changes nothing', (tester) async {
    final container = await pumpEditor(tester);

    await dragOnto(
      tester,
      find.byKey(const ValueKey('shelf-plant_moss')),
      find.byKey(const ValueKey('cell-0-0')),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    final state = await container.read(gardenRepositoryProvider).read();
    expect(state.placements, hasLength(1));
    expect(state.inventory.countOf('plant_moss'), 1);
  });

  testWidgets('the placement survives a relaunch', (tester) async {
    final container = await pumpEditor(tester);
    await dragOnto(
      tester,
      find.byKey(const ValueKey('shelf-deco_pebble')),
      find.byKey(const ValueKey('cell-7-0')),
    );
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    // A fresh widget tree over the same database is what a relaunch sees.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WakeOrPayApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The router kept the garden tab, so there is nothing to tap.
    final state = await container.read(gardenRepositoryProvider).read();
    final pebble = state.placements.firstWhere(
      (p) => p.itemId == 'deco_pebble',
    );
    expect((pebble.x, pebble.y), (7, 0));
    expect(
      find.byKey(ValueKey('placement-${pebble.id}')),
      findsOneWidget,
      reason: 'drawn again after the relaunch',
    );
  });

  testWidgets('the editor sells nothing it should not', (tester) async {
    await pumpEditor(tester);
    for (final banned in ['広告', 'スタミナ', 'ルーレット', '課金', 'コインで購入']) {
      expect(find.textContaining(banned), findsNothing, reason: banned);
    }
  });
}
