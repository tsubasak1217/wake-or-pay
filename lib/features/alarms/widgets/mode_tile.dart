import 'package:flutter/material.dart';

/// One of the two message modes an island offers — デフォルト or カスタムメッセージ.
///
/// A radio in everything but the widget: [Radio] would need a group above it,
/// and the row is already the group. Shared by the 連絡設定 and the 共有設定
/// screens, which offer the same pair for the same reason.
class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? Theme.of(context).colorScheme.primary : null,
    ),
    title: Text(label),
    subtitle: Text(description),
  );
}
