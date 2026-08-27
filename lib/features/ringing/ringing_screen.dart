import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/router.dart';
import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/loss_calculator.dart';
import '../../domain/models.dart';
import '../../domain/ojisan.dart';
import '../../domain/snooze_rules.dart';
import 'ringing_controller.dart';
import 'wake_checks/long_press_check.dart';
import 'wake_checks/math_check.dart';
import 'wake_checks/shake_check.dart';
import 'wake_checks/typing_check.dart';

/// Full screen, no way back. The wake check is the only way to finish the
/// morning; スヌーズ, when the alarm allows it, is the way to postpone it.
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

  void _snooze() =>
      unawaited(ref.read(ringingControllerProvider).snooze(widget.sessionId));

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
                : _RingingBody(
                    session: data,
                    now: _now,
                    onCleared: _dismiss,
                    onSnooze: _snooze,
                  ),
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

const _padding = EdgeInsets.symmetric(vertical: 24, horizontal: 16);

class _RingingBody extends ConsumerWidget {
  const _RingingBody({
    required this.session,
    required this.now,
    required this.onCleared,
    required this.onSnooze,
  });

  final AlarmSession session;
  final DateTime now;
  final VoidCallback onCleared;
  final VoidCallback onSnooze;

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loss = lossAt(now, session);
    final grace = graceRemaining(now, session);
    final alarm = ref.watch(alarmByIdProvider(session.alarmId));

    // A bare Column inside a scroll view shrinks to its widest child and lands
    // in the top left corner. Forcing it to the full width of the viewport
    // centres it horizontally; the minHeight plus mainAxisAlignment.center
    // centres it vertically whenever it fits, and lets it scroll when it does
    // not (small screens, large font scale, the keyboard on the typing check).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: _padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: (constraints.maxWidth - _padding.horizontal).clamp(
              0.0,
              double.infinity,
            ),
            minHeight: (constraints.maxHeight - _padding.vertical).clamp(
              0.0,
              double.infinity,
            ),
          ),
          child: Column(
            key: const ValueKey('ringingContent'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_hhmm(now), style: theme.textTheme.displayLarge),
              Text('起きろ！！', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 24),
              // The grace window first, so the user can see exactly how long
              // they have; the burn takes over the moment it runs out.
              if (grace > Duration.zero)
                _GracePanel(remaining: grace, kakugo: session.kakugoSnapshot)
              else if (session.kakugoSnapshot != null)
                _OjisanPanel(loss: loss)
              else
                Text('覚悟モードはオフです', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 32),
              // Never guess the wake check: showing long press while the alarm
              // loads would let the user clear a check they did not choose. An
              // alarm that has since been deleted still needs a way out, so that
              // — and only that — falls back to long press.
              //
              // A check drawn at fire time wins over the alarm's own, which for
              // a random alarm is the word "random" and not something anyone
              // can perform.
              alarm.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) =>
                    _wakeCheckFor(WakeCheckType.longPress, onCleared),
                data: (data) => _wakeCheckFor(
                  session.wakeCheckResolved ??
                      data?.wakeCheck ??
                      WakeCheckType.longPress,
                  onCleared,
                ),
              ),
              // Deliberately last, and deliberately a plain text button: the
              // wake check above is the way out of this screen, and snoozing
              // is the thing you do instead of getting up.
              alarm.maybeWhen(
                data: (data) =>
                    data != null && canSnoozeNow(data, session)
                    ? _SnoozeButton(session: session, onSnooze: onSnooze)
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _wakeCheckFor(WakeCheckType type, VoidCallback onCleared) =>
    switch (type) {
      WakeCheckType.longPress => LongPressCheck(onCleared: onCleared),
      WakeCheckType.math => MathCheck(onCleared: onCleared),
      WakeCheckType.typing => TypingCheck(onCleared: onCleared),
      WakeCheckType.shake => ShakeCheck(onCleared: onCleared),
      // Unreachable in practice: the draw happens when the session opens. A
      // session written before that existed still needs a way out, so it gets
      // the simplest check rather than a crash.
      WakeCheckType.random => LongPressCheck(onCleared: onCleared),
    };

/// The secondary way off this screen. Under a pledge it has to state the
/// price — the whole point of kakugo mode is that nothing costs money quietly.
class _SnoozeButton extends StatelessWidget {
  const _SnoozeButton({required this.session, required this.onSnooze});

  final AlarmSession session;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: TextButton(
      key: const ValueKey('snoozeButton'),
      onPressed: onSnooze,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: Text(snoozeButtonLabel(session.kakugoSnapshot)),
    ),
  );
}

/// The countdown shown while the alarm is still free to clear.
class _GracePanel extends StatelessWidget {
  const _GracePanel({required this.remaining, required this.kakugo});

  final Duration remaining;
  final Kakugo? kakugo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pledge = kakugo;
    return Column(
      children: [
        Text(
          '猶予 あと ${mmss(remaining)}',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          pledge == null
              ? '今のうちに解除すれば起床成功'
              : '過ぎると 1分ごとに ${pledge.ratePerMinute} コイン',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

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
