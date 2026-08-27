import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';

/// 連絡帳: the app's own address book.
///
/// It never reads the device's contacts — everything here was typed into this
/// app. Opened from the 寝坊時の連絡設定 screen to pick somebody, and it pops
/// with the entry that was tapped.
///
/// Deleting an entry does not disturb an alarm pointing at it: the alarm keeps
/// a snapshot of the name and addresses, so it still knows who to call.
class ContactBookScreen extends ConsumerWidget {
  const ContactBookScreen({super.key, this.selectedId});

  /// The entry the alarm is currently using, ticked in the list.
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(contactBookProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('連絡帳')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => data.isEmpty
            ? const _EmptyBook()
            : ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) =>
                    _ContactTile(entry: data[i], selectedId: selectedId),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('contactBookAdd'),
        tooltip: '連絡先を追加',
        onPressed: () => _openForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyBook extends StatelessWidget {
  const _EmptyBook();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'まだ誰も登録されていません。\n右下の ＋ から追加してください。',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile({required this.entry, required this.selectedId});

  final ContactEntry entry;
  final String? selectedId;

  /// 「090-… ・ a@b.c」 — whichever of the two the entry actually has.
  String get _subtitle => [
    if (entry.hasPhone) entry.phone!.trim(),
    if (entry.hasEmail) entry.email!.trim(),
  ].join(' ・ ');

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: ValueKey('contactBookRow-${entry.id}'),
    title: Text(entry.name),
    subtitle: Text(_subtitle),
    leading: entry.id == selectedId
        ? const Icon(Icons.check_circle, key: ValueKey('contactBookSelected'))
        : const Icon(Icons.person_outline),
    // Tapping picks; the menu (or a long press) is how the entry itself is
    // changed. Two different jobs, two different gestures.
    onTap: () => Navigator.of(context).pop(entry),
    onLongPress: () => _showActions(context, ref, entry),
    trailing: IconButton(
      key: ValueKey('contactBookMenu-${entry.id}'),
      tooltip: 'この連絡先の操作',
      icon: const Icon(Icons.more_vert),
      onPressed: () => _showActions(context, ref, entry),
    ),
  );
}

void _showActions(BuildContext context, WidgetRef ref, ContactEntry entry) =>
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
                _openForm(context, ref, entry: entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('削除'),
              onTap: () {
                Navigator.of(sheet).pop();
                _confirmDelete(context, ref, entry);
              },
            ),
          ],
        ),
      ),
    );

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ContactEntry entry,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('${entry.name} を削除しますか'),
      content: const Text(
        '連絡帳からいなくなります。この連絡先を使っているアラームは、'
        'そのまま同じ相手に連絡します（アラーム側に控えが残っているため）。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: const ValueKey('contactBookDeleteConfirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  if (yes == true) {
    await ref.read(contactBookRepositoryProvider).delete(entry.id);
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  ContactEntry? entry,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => ContactEntryForm(initial: entry)),
);

/// The one form behind both ＋ and 編集.
///
/// A contact needs a name and at least one way of reaching them — an entry
/// with neither a number nor an address could never do anything, so it is
/// refused rather than saved and silently useless. よみがな is optional and is
/// only ever used to sort the list.
class ContactEntryForm extends ConsumerStatefulWidget {
  const ContactEntryForm({super.key, this.initial});

  final ContactEntry? initial;

  @override
  ConsumerState<ContactEntryForm> createState() => _ContactEntryFormState();
}

class _ContactEntryFormState extends ConsumerState<ContactEntryForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _reading = TextEditingController(
    text: widget.initial?.reading ?? '',
  );
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _email = TextEditingController(text: widget.initial?.email ?? '');

  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _reading.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _trimmedOrNull(_phone);
    final email = _trimmedOrNull(_email);

    if (name.isEmpty) {
      setState(() => _error = '名前を入力してください。');
      return;
    }
    if (phone == null && email == null) {
      setState(() => _error = '電話番号かメールアドレスのどちらかは必要です。');
      return;
    }

    final existing = widget.initial;
    final entry = ContactEntry(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      reading: _trimmedOrNull(_reading),
      phone: phone,
      email: email,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await ref.read(contactBookRepositoryProvider).save(entry);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? '連絡先を追加' : '連絡先を編集')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          TextField(
            key: const ValueKey('contactEntryName'),
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名前',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('contactEntryReading'),
            controller: _reading,
            decoration: const InputDecoration(
              labelText: 'よみがな（任意）',
              helperText: '並び順にだけ使います。相手に送られることはありません',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('contactEntryPhone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '電話番号',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('contactEntryEmail'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '電話番号とメールアドレスは、どちらか一方だけでもかまいません。',
            style: theme.textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              key: const ValueKey('contactEntryError'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('contactEntrySave'),
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('保存'),
      ),
    );
  }
}
