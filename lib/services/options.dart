import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/models.dart';

/// オプション, held in memory so the editor's 上限金額 bound can be read
/// synchronously while a row is being built.
final optionsProvider = NotifierProvider<OptionsController, Options>(
  OptionsController.new,
);

class OptionsController extends Notifier<Options> {
  @override
  Options build() => ref.watch(optionsRepositoryProvider).read();

  /// Raises or lowers 上限金額の最大値. The confirmation for raising it lives in
  /// the UI, not here: this is the write, not the decision.
  Future<void> setCapCeiling(int ceiling) async {
    final next = state.copyWith(capCeiling: ceiling);
    await ref.read(optionsRepositoryProvider).write(next);
    state = next;
  }
}

/// The one field anything outside オプション reads. Selected, so the editor's
/// 上限金額 row does not rebuild when some future option changes.
final capCeilingProvider = Provider<int>(
  (ref) => ref.watch(optionsProvider.select((o) => o.capCeiling)),
);
