import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../domain/shake_detector.dart';

/// Accelerometer readings with gravity already removed, stamped as they arrive.
///
/// A provider rather than a direct subscription so tests — and an emulator,
/// which cannot be shaken — can feed the check by hand. The stamp is taken here
/// rather than in the widget so an injected stream controls time as well as
/// magnitude; a widget test cannot make a real [Stopwatch] run.
final shakeSampleProvider = StreamProvider.autoDispose<ShakeSample>((ref) {
  final clock = Stopwatch()..start();
  return userAccelerometerEventStream().map(
    (e) => ShakeSample(clock.elapsed, shakeMagnitude(e.x, e.y, e.z)),
  );
});

/// Shake the phone for five seconds. Stopping for more than half a second
/// throws the progress away — the turning points of a real shake are shorter
/// than that, so an honest shake never resets.
class ShakeCheck extends ConsumerStatefulWidget {
  const ShakeCheck({super.key, required this.onCleared});

  final VoidCallback onCleared;

  @override
  ConsumerState<ShakeCheck> createState() => _ShakeCheckState();
}

class _ShakeCheckState extends ConsumerState<ShakeCheck> {
  final _detector = ShakeDetector();

  double _progress = 0;
  bool _cleared = false;

  void _onSample(ShakeSample sample) {
    if (_cleared) return;
    final progress = _detector.addSample(sample);
    if (_detector.isComplete) {
      _cleared = true;
      widget.onCleared();
      return;
    }
    if (progress != _progress && mounted) {
      setState(() => _progress = progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shakeSampleProvider, (_, next) {
      final sample = next.valueOrNull;
      if (sample != null) _onSample(sample);
    });

    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _progress > 0 ? 'あと ${_detector.secondsLeft} 秒' : '5秒間振り続ける',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  key: const ValueKey('shakeProgress'),
                  value: _progress,
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
                child: Text('📳', style: theme.textTheme.displayMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
