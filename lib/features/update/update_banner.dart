import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_update.dart';

/// 「新しいバージョン（build N）があります」 — the sideloaded build's only way of
/// telling anyone that a newer APK exists.
///
/// Sits above the alarm list rather than in a dialog: an update is news, not a
/// question, and a dialog on top of the first screen after every launch is the
/// thing people learn to dismiss without reading. 「あとで」 puts it away until
/// the app is started again.
///
/// Draws nothing at all when there is nothing to say, so the home screen can
/// place it unconditionally.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final update = state.available;
    // A download in flight, or a message about one that failed, outranks
    // 「あとで」: the user asked for this, and it has to finish saying what
    // happened.
    final busy = state.downloading || state.error != null;
    if (update == null || (!state.showBanner && !busy)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final service = ref.read(appUpdateProvider.notifier);

    return Material(
      key: const ValueKey('updateBanner'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.system_update,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '新しいバージョン（build ${update.build}）があります',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (update.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 36),
                child: Text(update.notes, style: theme.textTheme.bodySmall),
              ),
            if (state.downloading)
              UpdateProgressBar(
                progress: state.progress,
                barKey: const ValueKey('updateProgress'),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 36),
                child: Text(
                  state.error!,
                  key: const ValueKey('updateError'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('updateLater'),
                  onPressed: state.downloading ? null : service.dismiss,
                  child: const Text('あとで'),
                ),
                TextButton(
                  key: const ValueKey('updateInstall'),
                  onPressed: state.downloading
                      ? null
                      : service.downloadAndInstall,
                  child: const Text('更新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar and its percentage. Indeterminate at exactly 0, because a
/// content-length-less answer never moves off it and a bar frozen at 0% looks
/// like a hung download.
class UpdateProgressBar extends StatelessWidget {
  const UpdateProgressBar({
    super.key,
    required this.progress,
    required this.barKey,
  });

  final double progress;
  final Key barKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, left: 36, right: 8),
    child: Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            key: barKey,
            value: progress <= 0 ? null : progress,
          ),
        ),
        const SizedBox(width: 12),
        Text('${(progress * 100).round()}%'),
      ],
    ),
  );
}

/// The same 更新 flow, in a dialog — what 「アプリの更新」 in the profile opens
/// once a check has found something.
///
/// Its own keys, not the banner's: both can be on screen at once, and two
/// widgets sharing a key would be ambiguous to find and illegal to nest.
Future<void> showUpdateDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialogContext) => const _UpdateDialog(),
);

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final update = state.available;
    final service = ref.read(appUpdateProvider.notifier);

    return AlertDialog(
      key: const ValueKey('updateDialog'),
      title: const Text('アプリの更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            update == null
                ? '最新です'
                : '新しいバージョン（build ${update.build}）があります',
          ),
          if (update != null && update.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(update.notes),
            ),
          if (state.downloading)
            UpdateProgressBar(
              progress: state.progress,
              barKey: const ValueKey('updateDialogProgress'),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.error!,
                key: const ValueKey('updateDialogError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('updateDialogClose'),
          onPressed: state.downloading
              ? null
              : () => Navigator.of(context).maybePop(),
          child: const Text('閉じる'),
        ),
        if (update != null)
          FilledButton(
            key: const ValueKey('updateDialogInstall'),
            onPressed: state.downloading ? null : service.downloadAndInstall,
            child: const Text('更新'),
          ),
      ],
    );
  }
}
