import 'package:flutter/material.dart';

import '../alarm_draft.dart';

/// One grouped block of the editor, in the shape iOS uses for its settings:
/// a title above a rounded card whose rows are separated by hairlines.
class SettingsIsland extends StatelessWidget {
  const SettingsIsland({
    super.key,
    required this.title,
    required this.children,
    this.header,
    this.background,
    this.borderColor,
    this.titleColor,
  });

  final String title;
  final List<Widget> children;

  /// Sits inside the card, above the rows. The kakugo island puts its running
  /// total here.
  final Widget? header;

  final Color? background;
  final Color? borderColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = borderColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: titleColor),
            ),
          ),
          // Material, not a decorated box: ListTile paints its splashes onto
          // the nearest Material, and a coloured box over it would hide them.
          Material(
            color: background ?? theme.colorScheme.surfaceContainerHighest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: border == null
                  ? BorderSide.none
                  : BorderSide(color: border, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that shows a value and opens a sub-screen. The chevron is the promise
/// that tapping goes somewhere.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.valueColor,
    this.subtitle,
    this.leading,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;
  final String? subtitle;

  /// Sits before the label. Used for the rows that name an outside service —
  /// the Discord mark says which one faster than the word does.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    debugRowBuildCounts.update(label, (n) => n + 1, ifAbsent: () => 1);
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: leading,
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible, not a bare Text: a long value — 「1.0.0 (build 123)」 on
          // the 更新 row — otherwise makes the trailing widget wider than the
          // whole tile, which ListTile does not shrink but *asserts* on. The
          // value gives way; the chevron never does, because a row without one
          // stops looking tappable.
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// A row that is just a switch.
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.labelColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  /// Colours the label only. 覚悟 uses it to carry the same red its island
  /// title does, so the row reads as the same dangerous thing.
  final Color? labelColor;

  /// false greys the row out and makes it untappable — for a switch that has
  /// nothing to switch, like 電話 on a contact with no number.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    debugRowBuildCounts.update(label, (n) => n + 1, ifAbsent: () => 1);
    return SwitchListTile(
      value: value,
      // A null callback is what makes SwitchListTile draw itself disabled, so
      // the grey and the untappable are the same fact rather than two.
      onChanged: enabled ? onChanged : null,
      title: Text(
        label,
        style: labelColor == null ? null : TextStyle(color: labelColor),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
  }
}
