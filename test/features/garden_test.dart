import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/garden.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/ojisan.dart';
import 'package:wake_or_pay/features/garden/garden_board.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

/// Boots the app and lands on the garden tab.
Future<ProviderContainer> pumpGarden(
  WidgetTester tester, {
  List<AlarmSession> sessions = const [],
  int oversleeps = 0,
  int tokens = 0,
}) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  for (final session in sessions) {
    await container.read(alarmSessionRepositoryProvider).save(session);
  }
  if (oversleeps > 0) {
    await container
        .read(ojisanRepositoryProvider)
        .write(OjisanState(totalOversleeps: oversleeps));
  }
  if (tokens > 0) {
    await container
        .read(walletRepositoryProvider)
        .write(Wallet(tokens: tokens));
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('お庭'));
  await tester.pumpAndSettle();
  return container;
}

AlarmSession _ok(DateTime at) => AlarmSession(
  id: 'ok-${at.toIso8601String()}',
  alarmId: 'a1',
  firedAt: at,
  status: SessionStatus.success,
);

void main() {
  testWidgets('the garden shows the terrarium, the hut and the resident', (
    tester,
  ) async {
    await pumpGarden(tester);

    expect(find.byType(GardenBoard), findsOneWidget);
    expect(find.byKey(const ValueKey('hut')), findsOneWidget);
    expect(find.byKey(const ValueKey('ojisan')), findsOneWidget);
  });

  testWidgets('the free plant from the first grant is already on the floor', (
    tester,
  ) async {
    final container = await pumpGarden(tester);

    final state = await container.read(gardenRepositoryProvider).read();
    expect(state.placements.single.itemId, 'plant_small');
    expect(find.textContaining('小さな植物'), findsOneWidget);
    expect(
      find.byKey(ValueKey('placement-${state.placements.single.id}')),
      findsOneWidget,
    );
  });

  testWidgets('the banner counts the streak and the oversleeps', (
    tester,
  ) async {
    final today = DateTime.now();
    await pumpGarden(
      tester,
      sessions: [
        _ok(today.subtract(const Duration(days: 2))),
        _ok(today.subtract(const Duration(days: 1))),
        _ok(today),
      ],
      oversleeps: 4,
    );

    expect(find.text('🔥 連続起床 3日（最高 3日）'), findsOneWidget);
    expect(find.text('👨 寝坊 4回'), findsOneWidget);
  });

  testWidgets('the hut matches the oversleep count', (tester) async {
    await pumpGarden(tester, oversleeps: 12);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hut'))).data,
      hutStageEmoji[2],
      reason: '10-19 oversleeps buys him a house',
    );
  });

  testWidgets('tapping the ojisan shows his current line', (tester) async {
    await pumpGarden(tester, oversleeps: 25);

    expect(find.byKey(const ValueKey('ojisanSpeech')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ojisan')));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('ojisanSpeech'))).data,
      ojisanLine(25),
    );

    // The bubble goes away on its own.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ojisanSpeech')), findsNothing);
  });

  testWidgets('a plant that grew has its stage written back', (tester) async {
    final today = DateTime.now();
    final container = await pumpGarden(
      tester,
      sessions: [
        for (var d = 6; d >= 0; d -= 1) _ok(today.subtract(Duration(days: d))),
      ],
    );
    await tester.pumpAndSettle();

    final state = await container.read(gardenRepositoryProvider).read();
    // Placed today, so only today counts: still a sprout despite the streak.
    expect(state.placements.single.growthStage, 0);
    expect(
      computeStreak(
        await container.read(alarmSessionRepositoryProvider).getRecent(),
        today,
      ).currentStreakDays,
      7,
    );
    expect(find.textContaining('小さな植物・芽'), findsOneWidget);
  });

  testWidgets('an older plant blooms and the stage reaches the database', (
    tester,
  ) async {
    final today = DateTime.now();
    final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
    for (var d = 15; d >= 1; d -= 1) {
      await container
          .read(alarmSessionRepositoryProvider)
          .save(_ok(today.subtract(Duration(days: d))));
    }
    // A plant that has been in the ground through all of it.
    await container
        .read(gardenRepositoryProvider)
        .write(
          GardenState(
            placements: [
              GardenPlacement(
                id: 'old',
                itemId: 'plant_moss',
                x: 0,
                y: 0,
                placedAt: today.subtract(const Duration(days: 20)),
              ),
            ],
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WakeOrPayApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('お庭'));
    await tester.pumpAndSettle();

    expect(find.textContaining('苔・開花'), findsOneWidget);
    final stored = await container.read(gardenRepositoryProvider).read();
    expect(
      stored.placements.firstWhere((p) => p.id == 'old').growthStage,
      3,
      reason: 'the cached column follows what is on screen',
    );
  });

  testWidgets('the garden sells nothing it should not', (tester) async {
    await pumpGarden(tester);
    for (final banned in ['広告', 'スタミナ', 'ルーレット', '課金', 'コインで購入']) {
      expect(find.textContaining(banned), findsNothing, reason: banned);
    }
  });
}
