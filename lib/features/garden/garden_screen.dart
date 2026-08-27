import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../domain/ojisan.dart';
import 'garden_board.dart';
import 'garden_controller.dart';

class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  @override
  void initState() {
    super.initState();
    // `ref.listen` only fires on change, so the first garden to arrive gets
    // its stages written back from here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(gardenGrowthWriterProvider).sync(ref.read(gardenViewProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(gardenViewProvider);
    final hutStage = ref.watch(hutStageProvider);
    final oversleeps = ref.watch(oversleepCountProvider);

    // Keep the cached growth column in step with what is on screen.
    ref.listen(gardenViewProvider, (previous, next) {
      ref.read(gardenGrowthWriterProvider).sync(next);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('お庭')),
      body: Column(
        children: [
          const _StreakBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GardenBoard(
                placements: view.state.placements,
                stages: view.stages,
                hutStage: hutStage,
                ojisanSpeech: ojisanLine(oversleeps),
              ),
            ),
          ),
          const _GardenActions(),
        ],
      ),
    );
  }
}

class _GardenActions extends StatelessWidget {
  const _GardenActions();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoute.seedShop),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('種屋'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.push(AppRoute.gardenEdit),
          icon: const Icon(Icons.grid_view_outlined),
          label: const Text('模様替え'),
        ),
      ],
    ),
  );
}

class _StreakBanner extends ConsumerWidget {
  const _StreakBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final oversleeps = ref.watch(oversleepCountProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '🔥 連続起床 ${streak.currentStreakDays}日'
              '（最高 ${streak.bestStreakDays}日）',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text('👨 寝坊 $oversleeps回', style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
