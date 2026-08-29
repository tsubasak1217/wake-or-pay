import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../services/card_hostage.dart';
import '../alarms/widgets/settings_island.dart';

/// クレジットカードを人質にする — the screen behind the profile row.
///
/// Phase 1 registers a card and nothing else: see `docs/BILLING_API.md`. The
/// card number never reaches this process; Stripe's own sheet takes it and
/// hands back four public fields.
///
/// What this screen is **not**: it sells nothing. Nothing here unlocks a
/// feature, and there is no version of this app that works better for having
/// pressed it. It is the 罰 half of Wake *or* Pay — the user putting something
/// real behind their own 覚悟 — which is why the wording is 請求 and 人質
/// throughout.
class CardHostageScreen extends ConsumerStatefulWidget {
  const CardHostageScreen({super.key});

  @override
  ConsumerState<CardHostageScreen> createState() => _CardHostageScreenState();
}

class _CardHostageScreenState extends ConsumerState<CardHostageScreen> {
  bool _consented = false;

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('cardHostageRemoveDialog'),
        title: const Text('カード人質を解除しますか？'),
        content: const Text('登録したカードの情報を消します。寝坊しても、このカードには何も起きなくなります。'),
        actions: [
          TextButton(
            key: const ValueKey('cardHostageRemoveCancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            key: const ValueKey('cardHostageRemoveConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cardHostageProvider.notifier).remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(cardHostageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('クレジットカードを人質にする')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (state.card == null)
            ..._notEnrolled(theme, state)
          else
            ..._enrolled(theme, state.card!),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Text(
                state.error!,
                key: const ValueKey('cardHostageError'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _notEnrolled(ThemeData theme, CardHostageState state) => [
    Text(
      'カードを人質にすると、寝坊で確定した金額があなたのカードに請求されます。'
      '覚悟の重さを、本物にするための仕組みです。',
      style: theme.textTheme.bodyMedium,
    ),
    const SizedBox(height: 16),
    SettingsIsland(
      title: '何が起きるか',
      children: const [
        _Point(icon: Icons.event, text: 'いつ：毎月末に、その月ぶんを合算して1回だけ請求します。'),
        _Point(
          icon: Icons.trending_up,
          text: 'いくら：寝坊で燃えた金額です。1回のアラームにつき、そのアラームに設定した上限金額を超えることはありません。',
        ),
        _Point(icon: Icons.link_off, text: 'やめ方：この画面の「解除」でいつでも外せます。'),
        _Point(
          icon: Icons.lock_outline,
          text: 'カード番号：この端末にもアプリの提供者にも残りません。カード会社の画面が直接受け取ります。',
        ),
      ],
    ),
    CheckboxListTile(
      key: const ValueKey('cardHostageConsent'),
      value: _consented,
      onChanged: state.loading
          ? null
          : (v) => setState(() => _consented = v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(cardHostageMandateText, style: theme.textTheme.bodyMedium),
    ),
    const SizedBox(height: 8),
    FilledButton(
      key: const ValueKey('cardHostageEnroll'),
      onPressed: _consented && !state.loading
          ? () => ref.read(cardHostageProvider.notifier).enroll()
          : null,
      child: Text(state.loading ? '登録中…' : 'カードを登録'),
    ),
    if (state.loading)
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: CircularProgressIndicator(
            key: ValueKey('cardHostageProgress'),
          ),
        ),
      ),
  ];

  List<Widget> _enrolled(ThemeData theme, HostageCard card) => [
    SettingsIsland(
      title: '人質にしているカード',
      children: [
        ListTile(
          key: const ValueKey('cardHostageCard'),
          leading: const Icon(Icons.credit_card),
          title: Text(card.label),
          subtitle: Text('有効期限 ${card.expiry}'),
        ),
      ],
    ),
    Text(
      // Phase 1 の正直な言い方。登録はできるが、まだ何も引き落とされない。
      '請求の仕組みは準備中です。いまはカードの登録だけができます。',
      key: const ValueKey('cardHostagePhaseNote'),
      style: theme.textTheme.bodyMedium,
    ),
    const SizedBox(height: 16),
    Text(
      'この先、寝坊で確定した金額を毎月末に合算して1回だけ請求します。'
      '金額は各アラームの上限金額を超えません。',
      style: theme.textTheme.bodySmall,
    ),
    const SizedBox(height: 24),
    OutlinedButton(
      key: const ValueKey('cardHostageRemove'),
      onPressed: ref.watch(cardHostageProvider).loading ? null : _remove,
      child: const Text('解除'),
    ),
  ];
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// Opens the screen over whatever asked for it — the profile row today.
Future<void> pushCardHostageScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const CardHostageScreen()));
