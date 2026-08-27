import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_controller.dart';
import '../../domain/models.dart';

/// あなたの名前: the one name the app has for its own user.
///
/// Reached from two places — the 設定 screen and the 寝坊時の連絡設定 island —
/// and it is deliberately the same screen from both, because it is the same
/// single value. Written on the way out, like every other editor sub-screen.
class UserNameSubScreen extends ConsumerStatefulWidget {
  const UserNameSubScreen({super.key});

  @override
  ConsumerState<UserNameSubScreen> createState() => _UserNameSubScreenState();
}

class _UserNameSubScreenState extends ConsumerState<UserNameSubScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(settingsProvider).userName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final name = _controller.text.trim();
    if (name == ref.read(settingsProvider).userName) return;
    ref.read(settingsProvider.notifier).setUserName(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('あなたの名前')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextField(
              key: const ValueKey('userNameField'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(context).maybePop(),
              decoration: const InputDecoration(
                labelText: '名前',
                hintText: '例：田中太郎',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '寝坊したことを連絡先に伝える文面の主語になります。'
              '連絡を受け取るのは相手なので、ここに入るのは「あなた」の名前です。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '未設定のままでも連絡はできます。その場合の文面は'
              '「$oversleepUserNameFallback さんは…」になります。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the editor over whatever screen asked for it.
Future<void> pushUserNameSubScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const UserNameSubScreen()),
    );
