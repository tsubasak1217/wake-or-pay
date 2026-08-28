import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/discord_link_log.dart';

/// The status area shared by 「Discord で連携」 and the 共有先 screen.
///
/// It exists because the old flow had **nothing to look at**. The button
/// spun, a browser opened over the app, and every outcome after that — the
/// success, the state mismatch, the five minutes of silence — was a SnackBar
/// fired while the app was in the background, where nobody ever saw it. That
/// is precisely the bug the user reported as 「承認したのに連携済みにならない」.
///
/// So the state lives in a provider rather than in a widget's `setState`, and
/// it survives the app being backgrounded and brought forward again by the
/// callback intent. Whatever happened while the user was in Discord is still
/// on screen when they get back.
class DiscordFlowStatusView extends ConsumerWidget {
  const DiscordFlowStatusView({super.key, this.onCancel});

  /// 「やめる」. Shown only while something is actually pending — without it a
  /// user who closed the Discord page has no way out but the five-minute
  /// timeout.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(discordFlowStatusProvider);
    if (status.phase == DiscordFlowPhase.idle) return const SizedBox.shrink();

    final (icon, color) = switch (status.phase) {
      DiscordFlowPhase.done => (
        Icons.check_circle_outline,
        theme.colorScheme.primary,
      ),
      DiscordFlowPhase.failed => (
        Icons.error_outline,
        theme.colorScheme.error,
      ),
      _ => (Icons.hourglass_empty, theme.colorScheme.onSurfaceVariant),
    };

    return Container(
      key: const ValueKey('discordFlowStatus'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: status.busy
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          if (status.busy && onCancel != null)
            TextButton(
              key: const ValueKey('discordFlowCancel'),
              onPressed: onCancel,
              child: const Text('やめる'),
            ),
        ],
      ),
    );
  }
}
