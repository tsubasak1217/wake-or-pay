import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../services/discord_link_log.dart';
import '../../services/discord_oauth.dart';
import '../../services/discord_sender.dart';
import '../profile/discord_flow_status_view.dart';

/// Discord 共有先設定, per spec 11.6.
///
/// The list is **app-wide** — one server is worth registering once — and the
/// switches are **per alarm**: each row asks whether *this* alarm posts there.
/// So ＋, 編集 and 削除 write the shared table, and the switches write the
/// draft's [OversleepShare.webhookIds], and the two never touch each other.
///
/// Deleting a 共有先 an alarm was posting to leaves a **dangling id** on that
/// alarm. Nothing goes hunting for them: an id with no row behind it is
/// skipped wherever the list is read — the count on the 共有 row, the switches
/// here, the sender in C3 — which is the same rule the 連絡帳 follows for the
/// same reason. Sweeping every alarm on a delete would be a write to every row
/// in the table to fix something that already reads correctly.
class DiscordWebhooksSubScreen extends ConsumerStatefulWidget {
  const DiscordWebhooksSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
  });

  final Set<String> initial;
  final ValueChanged<Set<String>> onCommit;

  @override
  ConsumerState<DiscordWebhooksSubScreen> createState() =>
      _DiscordWebhooksSubScreenState();
}

class _DiscordWebhooksSubScreenState
    extends ConsumerState<DiscordWebhooksSubScreen> {
  late final Set<String> _selected = {...widget.initial};

  @override
  void initState() {
    super.initState();
    // The status area is shared with the profile row, so a finished flow from
    // over there must not greet this screen as if it were its own. A flow
    // still in the air is left alone — that one really is still happening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(discordFlowStatusProvider).busy) {
        ref.read(discordFlowStatusProvider.notifier).reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final webhooks = ref.watch(discordWebhooksProvider);
    final status = ref.watch(discordFlowStatusProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onCommit({..._selected});
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Discord 共有先設定')),
        body: webhooks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (data) => data.isEmpty
              ? const _EmptyList()
              : Column(
                  children: [
                    // The long press hides three things a user would otherwise
                    // never find, and テスト送信 is the one that matters most:
                    // a wrong URL is only ever discovered at 6am otherwise.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        'タップでこのアラームの共有先を選びます。'
                        '長押しすると テスト送信 / 名前を変更 / 削除 ができます。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: data.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final webhook = data[i];
                          // Tapping the row toggles; the long press is how the
                          // 共有先 itself is changed. Two jobs, two gestures —
                          // the same split the 連絡帳 uses. The long press
                          // lives on a wrapper because SwitchListTile has no
                          // slot for one, and the tap still reaches the tile
                          // underneath.
                          return GestureDetector(
                            key: ValueKey('webhook-${webhook.id}'),
                            onLongPress: () =>
                                _showActions(context, ref, webhook),
                            child: SwitchListTile(
                              value: _selected.contains(webhook.id),
                              onChanged: (on) => setState(
                                () => on
                                    ? _selected.add(webhook.id)
                                    : _selected.remove(webhook.id),
                              ),
                              title: Text(webhook.displayName),
                              subtitle: const Text('Discord Webhook'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        // 「Webhook URL を手動で登録」 is gone (段階F). It asked the user to open
        // Discord's channel settings, make a webhook, copy a URL that is a
        // bearer credential in its own right, and paste it back — five steps
        // in another app, and the step most people never finished. There is
        // now one way in, and Discord does the work.
        bottomNavigationBar: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Above the button, not below: this is what the user watches
              // after they press it, and after Discord hands them back.
              DiscordFlowStatusView(
                onCancel: () =>
                    ref.read(discordChannelLinkerProvider).cancel(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey('webhookLinkChannel'),
                  onPressed: status.busy
                      ? null
                      : () => unawaited(_linkChannel(ref)),
                  icon: const Icon(Icons.add_link),
                  label: const Text('チャンネルを連携（Discord で選ぶ）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「チャンネルを連携」: Discord shows the server and channel picker — inside
  /// the Discord app when it is installed — and the 連携サーバー turns the code
  /// it hands back into a webhook.
  ///
  /// Registers the 共有先 **and ticks it on for this alarm**. Somebody who just
  /// picked a channel meant to post there; making them tap the row afterwards
  /// would be asking the same question twice.
  ///
  /// Nothing is reported by SnackBar any more: this flow spends minutes in
  /// another app, and a SnackBar fired on the way back is a message shown to
  /// an empty room. [DiscordFlowStatusView] holds the outcome instead.
  Future<void> _linkChannel(WidgetRef ref) async {
    final result = await ref.read(discordChannelLinkerProvider).link();
    final grant = result.grant;
    if (result.ok && grant != null) {
      final webhook = DiscordWebhook(
        id: grant.id,
        url: grant.url,
        // Defaults to the server name; 「Wake or Pay」 (the webhook's own name)
        // is only the fallback. The user renames from the long-press menu to
        // tell two channels in the same server apart.
        displayName: webhookDefaultName(
          grant.guildName,
          grant.channelName,
          grant.webhookName,
        ),
        createdAt: DateTime.now(),
      );
      await ref.read(discordWebhookRepositoryProvider).save(webhook);
      if (mounted) setState(() => _selected.add(webhook.id));
    }
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'まだ共有先がありません。\n'
        '下の「チャンネルを連携」を押すと、Discord が投稿先のチャンネルを選ばせてくれます。',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}

void _showActions(BuildContext context, WidgetRef ref, DiscordWebhook webhook) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('webhookTestSend'),
              leading: const Icon(Icons.send_outlined),
              title: const Text('テスト送信'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_testSend(context, ref, webhook));
              },
            ),
            // 名前を変更 is the one field the old 編集 form had that still makes
            // sense: the URL comes from Discord and must not be hand-typed, but
            // the label defaults to the server name, and two channels in the
            // same server land on the same label — a rename is how they are
            // told apart (「みんなのサーバー/#報告」).
            ListTile(
              key: const ValueKey('webhookRename'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('名前を変更'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(_renameDialog(context, ref, webhook));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('削除'),
              onTap: () {
                Navigator.of(sheet).pop();
                _confirmDelete(context, ref, webhook);
              },
            ),
          ],
        ),
      ),
    );

/// The whole body of a テスト送信. No attachment, nothing about oversleeping:
/// this is the user checking their URL, not the alarm firing.
const discordTestSendMessage = 'Wake or Pay のテスト送信です';

/// Posts one line to one 共有先, right now, and says what happened.
///
/// The point of the feature is that a wrong URL is otherwise discovered at
/// 6am, by nothing arriving in a channel nobody is looking at. So the failure
/// is reported as specifically as the sender knows it — 「失敗（HTTP 404）」 tells
/// the user their webhook was deleted, which 「失敗」 alone never would.
Future<void> _testSend(
  BuildContext context,
  WidgetRef ref,
  DiscordWebhook webhook,
) async {
  // Taken before the await: the sheet is gone by the time the post answers,
  // and this context may be too.
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref
      .read(discordWebhookSenderProvider)
      .post(url: webhook.url, content: discordTestSendMessage);
  messenger.showSnackBar(
    SnackBar(content: Text(result.ok ? 'テスト送信しました' : result.label)),
  );
}

/// Renames one 共有先 in the app-wide list.
///
/// The label defaults to the server name, and two channels in the same server
/// both land on it, so this is the only way to tell them apart. Only the label
/// is touched — the URL is a live Discord credential and is never editable by
/// hand. An empty name is rejected: a nameless row cannot be picked out of the
/// list ([DiscordWebhook.isUsable] would read false), so the 保存 button simply
/// stays disabled until there is something to save.
Future<void> _renameDialog(
  BuildContext context,
  WidgetRef ref,
  DiscordWebhook webhook,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: webhook.displayName),
  );
  if (name == null || name.isEmpty) return;
  await ref
      .read(discordWebhookRepositoryProvider)
      .save(webhook.copyWith(displayName: name));
}

/// The rename dialog owns its own [TextEditingController] so the controller is
/// disposed with the dialog, not before it — disposing it the moment
/// [showDialog] returns leaves the closing transition rebuilding a listener on
/// a dead notifier.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('共有先の名前を変更'),
    content: TextField(
      key: const ValueKey('webhookRenameField'),
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: '表示名',
        hintText: 'みんなのサーバー/#報告',
      ),
      // 完了 on the keyboard commits, on the same non-empty rule as 保存.
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('やめる'),
      ),
      // Rebuilt on every keystroke so 保存 lights up the moment there is a name
      // and greys out again if it is cleared.
      ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => FilledButton(
          key: const ValueKey('webhookRenameSave'),
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: const Text('保存'),
        ),
      ),
    ],
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  DiscordWebhook webhook,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('${webhook.displayName} を削除しますか'),
      content: const Text(
        '共有先の一覧からいなくなります。この共有先を選んでいるアラームは、'
        'そのぶんだけ投稿先が減ります（他の共有先や連絡先はそのままです）。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: const ValueKey('webhookDeleteConfirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  if (yes == true) {
    await ref.read(discordWebhookRepositoryProvider).delete(webhook.id);
  }
}
