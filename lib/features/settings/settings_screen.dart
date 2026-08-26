import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('テーマ'),
          ),
          for (final theme in AppThemes.all)
            ListTile(
              onTap: () =>
                  ref.read(settingsProvider.notifier).selectTheme(theme.id),
              leading: CircleAvatar(backgroundColor: theme.seed),
              title: Text(theme.name),
              subtitle: Text(theme.description),
              trailing: theme.id == selected ? const Icon(Icons.check) : null,
            ),
        ],
      ),
    );
  }
}
