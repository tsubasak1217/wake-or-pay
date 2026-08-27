import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/router.dart';
import '../../data/providers.dart';
import '../../domain/loss_calculator.dart';
import '../../domain/models.dart';
import '../../domain/ojisan.dart';
import 'ringing_controller.dart';
import 'wake_checks/long_press_check.dart';
import 'wake_checks/math_check.dart';
import 'wake_checks/typing_check.dart';

/// Full screen, no way back, no snooze. The only control is the wake check.
class RingingScreen extends ConsumerStatefulWidget {
  const RingingScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends ConsumerState<RingingScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setWakelock(true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _setWakelock(false);
    super.dispose();
  }

  /// Keeping the screen awake is a nicety; failing to is never a reason to
  /// take the ring screen down.
  void _setWakelock(bool enable) => unawaited(
    (enable ? WakelockPlus.enable() : WakelockPlus.disable()).catchError(
      (Object _) {},
    ),
  );

  void _dismiss() =>
      unawaited(ref.read(ringingControllerProvider).dismiss(widget.sessionId));

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionByIdProvider(widget.sessionId));

    return PopScope(
      // Back and home do not stop the sound, and they do not leave this screen.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: session.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) => data == null
                ? const _MissingSession()
                : _RingingBody(session: data, now: _now, onCleared: _dismiss),
          ),
        ),
      ),
    );
  }
}

class _MissingSession extends ConsumerWidget {
  const _MissingSession();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('鳴動中のアラームはありません'),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => ref.read(appRouterProvider).go(AppRoute.home),
          child: const Text('ホームへ'),
        ),
      ],
    ),
  );
}

class _RingingBody extends ConsumerWidget {
  const _RingingBody({
    required this.session,
    required this.now,
    required this.onCleared,
  });

  final AlarmSession session;
  final DateTime now;
  final VoidCallback onCleared;

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loss = lossAt(now, session);
    final alarm = ref.watch(alarmByIdProvider(session.alarmId));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Text(_hhmm(now), style: theme.textTheme.displayLarge),
          Text('起きろ！！', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          if (session.kakugoSnapshot != null)
            _OjisanPanel(loss: loss)
          else
            Text('覚悟モードはオフです', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 32),
          // Never guess the wake check: showing long press while the alarm
          // loads would let the user clear a check they did not choose. An
          // alarm that has since been deleted still needs a way out, so that
          // — and only that — falls back to long press.
          alarm.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => _wakeCheckFor(WakeCheckType.longPress, onCleared),
            data: (data) => _wakeCheckFor(
              data?.wakeCheck ?? WakeCheckType.longPress,
              onCleared,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _wakeCheckFor(WakeCheckType type, VoidCallback onCleared) =>
    switch (type) {
      WakeCheckType.longPress => LongPressCheck(onCleared: onCleared),
      WakeCheckType.math => MathCheck(onCleared: onCleared),
      WakeCheckType.typing => TypingCheck(onCleared: onCleared),
    };

class _OjisanPanel extends StatelessWidget {
  const _OjisanPanel({required this.loss});

  final int loss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '💸 あなた：−$loss',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 4),
        Text('👨 おじさん：+$loss', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('「$ojisanRingingLine」', style: theme.textTheme.titleMedium),
      ],
    );
  }
}
