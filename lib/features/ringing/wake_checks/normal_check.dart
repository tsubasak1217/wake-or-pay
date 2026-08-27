import 'package:flutter/material.dart';

/// One tap and the morning is over. The plainest wake check there is: what an
/// ordinary alarm clock does.
///
/// It is a wake check like any other, so it looks like one — the same circle
/// the long press uses, without the ring, so nothing about the screen has to
/// move when the user switches between them.
class NormalCheck extends StatelessWidget {
  const NormalCheck({super.key, required this.onCleared});

  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('タップして解除', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        GestureDetector(
          key: const ValueKey('normalCheckButton'),
          onTap: onCleared,
          child: Container(
            width: 180,
            height: 180,
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
        ),
      ],
    );
  }
}
