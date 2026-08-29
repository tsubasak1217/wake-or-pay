import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/ojisan.dart';
import '../../domain/reward.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: session.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) =>
                data == null ? const _Missing() : _ResultBody(session: data),
          ),
        ),
      ),
    );
  }
}

class _Missing extends ConsumerWidget {
  const _Missing();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: TextButton(
      onPressed: () => ref.read(appRouterProvider).go(AppRoute.home),
      child: const Text('ホームへ'),
    ),
  );
}

class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.session});

  final AlarmSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final success = session.status == SessionStatus.success;
    final oversleeps =
        ref.watch(ojisanProvider).valueOrNull?.totalOversleeps ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              success ? '起床成功' : '起床失敗',
              style: theme.textTheme.displaySmall?.copyWith(
                color: success
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            // A card pledge takes nothing out of the wallet, so 「消費」 would
            // be a lie about a balance that never moved: the ring says what
            // will happen to the card instead.
            if (session.kakugoSnapshot?.hostage == HostageType.card &&
                session.loss > 0)
              Text(
                cardChargeNotice(session.loss),
                key: const ValueKey('cardChargeNotice'),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              )
            else
              Text('消費：${session.loss}', style: theme.textTheme.headlineSmall),
            if (success && session.kakugoSnapshot != null)
              Text(
                '守った金額：${session.kakugoSnapshot!.cap}',
                style: theme.textTheme.titleMedium,
              ),
            if (success)
              Text(
                '獲得トークン：+${rewardTokens(session.kakugoSnapshot)}',
                style: theme.textTheme.titleMedium,
              ),
            const SizedBox(height: 32),
            const Text('👨', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              '「${success ? ojisanSuccessLine : ojisanLine(oversleeps)}」',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: () => ref.read(appRouterProvider).go(AppRoute.home),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
