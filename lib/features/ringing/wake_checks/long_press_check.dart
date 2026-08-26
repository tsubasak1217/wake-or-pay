import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/wake_check.dart';

const _tick = Duration(milliseconds: 50);

/// Hold for five seconds. Letting go resets it to zero — no partial credit.
class LongPressCheck extends StatefulWidget {
  const LongPressCheck({super.key, required this.onCleared});

  final VoidCallback onCleared;

  @override
  State<LongPressCheck> createState() => _LongPressCheckState();
}

class _LongPressCheckState extends State<LongPressCheck> {
  Duration _held = Duration.zero;
  bool _holding = false;
  bool _cleared = false;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    if (_cleared) return;
    _ticker?.cancel();
    setState(() {
      _holding = true;
      _held = Duration.zero;
    });
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      final held = _held + _tick;
      if (longPressProgress(held) >= 1) {
        _ticker?.cancel();
        _cleared = true;
        widget.onCleared();
        return;
      }
      setState(() => _held = held);
    });
  }

  void _cancel() {
    _ticker?.cancel();
    if (!mounted || _cleared) return;
    setState(() {
      _holding = false;
      _held = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = longPressProgress(_held);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _holding ? 'あと ${longPressSecondsLeft(_held)} 秒' : '5秒間押し続ける',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTapDown: (_) => _start(),
          onTapUp: (_) => _cancel(),
          onTapCancel: _cancel,
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                  ),
                ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '解除',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
