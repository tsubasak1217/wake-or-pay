import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../services/discord_sender.dart';

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
  Widget build(BuildContext context) {
    final webhooks = ref.watch(discordWebhooksProvider);

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
              : ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final webhook = data[i];
                    // Tapping the row toggles; the long press is how the 共有先
                    // itself is changed. Two jobs, two gestures — the same
                    // split the 連絡帳 uses. The long press lives on a wrapper
                    // because SwitchListTile has no slot for one, and the tap
                    // still reaches the tile underneath.
                    return GestureDetector(
                      key: ValueKey('webhook-${webhook.id}'),
                      onLongPress: () => _showActions(context, ref, webhook),
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
        floatingActionButton: FloatingActionButton(
          key: const ValueKey('webhookAdd'),
          tooltip: '共有先を追加',
          onPressed: () => _openForm(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'まだ共有先がありません。\n右下の ＋ から Webhook を追加してください。',
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('編集'),
              onTap: () {
                Navigator.of(sheet).pop();
                _openForm(context, ref, initial: webhook);
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

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  DiscordWebhook? initial,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => DiscordWebhookForm(initial: initial)),
);

/// The one form behind both ＋ and 編集.
///
/// The URL is checked before anything is saved: a URL that is not a Discord
/// webhook could only ever fail silently at 6am, which is the one time this
/// app must not fail silently.
///
/// The display name is prefilled by GET-ing the webhook — the API answers with
/// the *webhook's* own name — and **every failure is silent**. Offline, a
/// revoked webhook, a captive portal serving HTML: none of them is a reason to
/// refuse a registration that works perfectly well typed by hand.
class DiscordWebhookForm extends ConsumerStatefulWidget {
  const DiscordWebhookForm({super.key, this.initial});

  final DiscordWebhook? initial;

  @override
  ConsumerState<DiscordWebhookForm> createState() => _DiscordWebhookFormState();
}

class _DiscordWebhookFormState extends ConsumerState<DiscordWebhookForm> {
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _name = TextEditingController(
    text: widget.initial?.displayName ?? '',
  );

  String? _urlError;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    _url.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  /// The last URL a lookup was started for, so the same paste does not fire a
  /// second request every time the field rebuilds.
  String _lookedUp = '';

  void _onUrlChanged() {
    final url = normalizeDiscordWebhookUrl(_url.text);
    if (url == _lookedUp || !isDiscordWebhookUrl(url)) return;
    _lookedUp = url;
    unawaited(_lookUpName(url));
  }

  /// Fills 表示名 in, but **only while it is blank**: whatever the user has
  /// typed is theirs, and a lookup arriving a second later must never take it
  /// away from under the cursor.
  Future<void> _lookUpName(String url) async {
    setState(() => _looking = true);
    final name = await ref.read(discordSenderProvider).fetchWebhookName(url);
    if (!mounted) return;
    setState(() {
      _looking = false;
      if (name != null && _name.text.trim().isEmpty) _name.text = name;
    });
  }

  Future<void> _save() async {
    final url = normalizeDiscordWebhookUrl(_url.text);
    if (!isDiscordWebhookUrl(url)) {
      setState(
        () => _urlError =
            'Discord の Webhook URL を入力してください。'
            '（https://discord.com/api/webhooks/… の形式です）',
      );
      return;
    }
    final typed = _name.text.trim();
    final existing = widget.initial;
    final webhook = DiscordWebhook(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      // A blank name would leave an unpickable row in the list, so it falls
      // back to something the user can at least recognise as theirs.
      displayName: typed.isEmpty ? 'Discord 共有先' : typed,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await ref.read(discordWebhookRepositoryProvider).save(webhook);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? '共有先を追加' : '共有先を編集')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          TextField(
            key: const ValueKey('webhookUrlField'),
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Webhook URL',
              helperText: 'Discord のチャンネル設定 →「連携サービス」→「ウェブフック」で作れます',
              errorText: _urlError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('webhookNameField'),
            controller: _name,
            decoration: InputDecoration(
              labelText: '表示名',
              helperText: '一覧に出る名前です。例：みんなのサーバー/#一般',
              suffixIcon: _looking
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Discord は Webhook からサーバー名やチャンネル名を教えてくれません'
            '（返ってくるのは Webhook 自身の名前と ID だけです）。'
            'そのため表示名は手入力です。URL を入れると Webhook 名を初期値として入れますが、'
            '取得できなくても登録はできます。',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('webhookSave'),
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('保存'),
      ),
    );
  }
}
