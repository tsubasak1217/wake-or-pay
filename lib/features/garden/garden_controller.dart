import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/garden.dart';
import '../../domain/garden_catalog.dart';
import '../../domain/models.dart';

/// How each past day went, derived from session history.
final gardenDayResultsProvider = Provider<Map<DateTime, DayResult>>(
  (ref) =>
      classifyDays(ref.watch(sessionHistoryProvider).valueOrNull ?? const []),
);

/// The wake-up streak. Derived on every read; nothing about it is stored.
final streakProvider = Provider<Streak>(
  (ref) => computeStreak(
    ref.watch(sessionHistoryProvider).valueOrNull ?? const [],
    DateTime.now(),
  ),
);

/// The ojisan's hut, by lifetime oversleeps.
final hutStageProvider = Provider<int>(
  (ref) =>
      hutStageFor(ref.watch(ojisanProvider).valueOrNull?.totalOversleeps ?? 0),
);

/// Total oversleeps, for the banner and his line.
final oversleepCountProvider = Provider<int>(
  (ref) => ref.watch(ojisanProvider).valueOrNull?.totalOversleeps ?? 0,
);

/// Everything the garden screen draws, with each plant's growth stage already
/// folded out of history.
class GardenView {
  const GardenView({required this.state, required this.stages});

  final GardenState state;

  /// Placement id → growth stage, 0..3. Non-plants are absent.
  final Map<String, int> stages;

  int stageOf(GardenPlacement placement) => stages[placement.id] ?? 0;
}

final gardenViewProvider = Provider<GardenView>((ref) {
  final state = ref.watch(gardenProvider).valueOrNull ?? const GardenState();
  final days = ref.watch(gardenDayResultsProvider);
  final today = DateTime.now();

  return GardenView(
    state: state,
    stages: {
      for (final placement in state.placements)
        if (GardenCatalog.byId(placement.itemId)?.growable ?? false)
          placement.id: growthStageFor(placement, days, today),
    },
  );
});

/// Writes the derived growth stages back onto the stored placements, so the
/// cached column stays honest. Only rows whose stage actually moved are
/// touched, which is what keeps this from looping against its own stream.
class GardenGrowthWriter {
  GardenGrowthWriter(this._ref);

  final Ref _ref;

  Future<void> sync(GardenView view) async {
    final repository = _ref.read(gardenRepositoryProvider);
    for (final placement in view.state.placements) {
      final stage = view.stages[placement.id];
      if (stage == null || stage == placement.growthStage) continue;
      await repository.savePlacement(placement.copyWith(growthStage: stage));
    }
  }
}

final gardenGrowthWriterProvider = Provider(GardenGrowthWriter.new);
