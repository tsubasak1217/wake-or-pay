import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import 'widgets/slider_number_field.dart';

/// Pushes [screen] over the editor and returns when it is closed.
Future<void> pushEditorSubScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));

/// A sub-screen holding one number.
///
/// The value is local while the screen is open and handed back exactly once,
/// when it closes — the spec's "決定はサブ画面を閉じた時点で反映". That covers the
/// app bar's back button and the system back gesture alike, because both go
/// through [PopScope].
class NumberSubScreen extends StatefulWidget {
  const NumberSubScreen({
    super.key,
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.onCommit,
    this.suffix,
    this.description,
    this.footer,
  });

  final String title;
  final int initial;
  final int min;
  final int max;
  final ValueChanged<int> onCommit;
  final String? suffix;
  final String? description;

  /// Rebuilt on every change: the kakugo gauge, the balance warning.
  final Widget Function(BuildContext context, int value)? footer;

  @override
  State<NumberSubScreen> createState() => _NumberSubScreenState();
}

class _NumberSubScreenState extends State<NumberSubScreen> {
  late int _value = widget.initial.clamp(widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onCommit(_value);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              '$_value${widget.suffix ?? ''}',
              key: const ValueKey('numberSubScreenValue'),
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SliderNumberField(
              value: _value,
              min: widget.min,
              max: widget.max,
              suffix: widget.suffix,
              semanticLabel: widget.title,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.min}〜${widget.max}${widget.suffix ?? ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (widget.description != null) ...[
              const SizedBox(height: 16),
              Text(widget.description!, style: theme.textTheme.bodyMedium),
            ],
            if (widget.footer != null) ...[
              const SizedBox(height: 24),
              widget.footer!(context, _value),
            ],
          ],
        ),
      ),
    );
  }
}

/// 曜日: the repeat rule, as chips.
class RepeatDaysSubScreen extends StatefulWidget {
  const RepeatDaysSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
  });

  final Set<int> initial;
  final ValueChanged<Set<int>> onCommit;

  @override
  State<RepeatDaysSubScreen> createState() => _RepeatDaysSubScreenState();
}

class _RepeatDaysSubScreenState extends State<RepeatDaysSubScreen> {
  late final Set<int> _days = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onCommit(_days);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('曜日')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(repeatDaysLabel(_days), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayLabel(d)),
                    selected: _days.contains(d),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '曜日を選ばなければ一回限りのアラームになり、鳴り終わると自動的にオフになります。',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// 起床確認: which check has to be cleared to stop the alarm.
class WakeCheckSubScreen extends StatefulWidget {
  const WakeCheckSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
  });

  final WakeCheckType initial;
  final ValueChanged<WakeCheckType> onCommit;

  @override
  State<WakeCheckSubScreen> createState() => _WakeCheckSubScreenState();
}

class _WakeCheckSubScreenState extends State<WakeCheckSubScreen> {
  late WakeCheckType _selected = widget.initial;

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) widget.onCommit(_selected);
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('起床確認')),
      body: ListView(
        children: [
          for (final type in WakeCheckType.values)
            ListTile(
              onTap: () => setState(() => _selected = type),
              title: Text(type.label),
              subtitle: Text(type.description),
              trailing: _selected == type ? const Icon(Icons.check) : null,
            ),
        ],
      ),
    ),
  );
}
