import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/models.dart';

/// 開始日 and ログイン日数, kept in memory so the profile paints them without
/// waiting on a future.
///
/// **Reading this does not record anything.** [recordOpen] is called once, from
/// the root widget's `initState` (`WakeOrPayApp`) — the only place that sees
/// every launch, including the one that opens straight into a ringing alarm.
/// Recording from `build` instead would tie the count to whoever happened to
/// look at the statistics first.
final usageProvider = NotifierProvider<UsageTracker, UsageStats>(
  UsageTracker.new,
);

class UsageTracker extends Notifier<UsageStats> {
  @override
  UsageStats build() => ref.watch(usageRepositoryProvider).read();

  /// One app start. [at] defaults to the injected clock, so a test can put the
  /// two opens it needs on either side of midnight.
  Future<void> recordOpen([DateTime? at]) async {
    final now = at ?? ref.read(clockProvider)();
    state = await ref.read(usageRepositoryProvider).recordOpen(now);
  }
}
