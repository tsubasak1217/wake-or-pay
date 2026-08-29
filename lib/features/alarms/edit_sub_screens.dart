import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../services/card_hostage.dart';
import '../profile/card_hostage_screen.dart';
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
            // No separate value display: the field below *is* the number.
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

/// One of two named choices, each with a line of explanation. The value is
/// local while the screen is open and handed back when it closes, exactly like
/// [NumberSubScreen].
class ChoiceSubScreen<T> extends StatefulWidget {
  const ChoiceSubScreen({
    super.key,
    required this.title,
    required this.initial,
    required this.options,
    required this.onCommit,
    this.description,
  });

  final String title;
  final T initial;
  final List<({T value, String label, String description})> options;
  final ValueChanged<T> onCommit;
  final String? description;

  @override
  State<ChoiceSubScreen<T>> createState() => _ChoiceSubScreenState<T>();
}

class _ChoiceSubScreenState<T> extends State<ChoiceSubScreen<T>> {
  late T _selected = widget.initial;

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) widget.onCommit(_selected);
    },
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        children: [
          for (final option in widget.options)
            ListTile(
              onTap: () => setState(() => _selected = option.value),
              title: Text(option.label),
              subtitle: Text(option.description),
              trailing: _selected == option.value
                  ? const Icon(Icons.check)
                  : null,
            ),
          if (widget.description != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    ),
  );
}

/// 人質: what the user actually loses by oversleeping.
///
/// The card option is only selectable once a card is registered — a pledge
/// against a card that does not exist would be a stake the app cannot take —
/// so with no card the option is drawn disabled and 「カードを登録する」 sits under
/// it, opening the same プロフィール screen. Coming back with a card registered
/// enables the option in place, because the card state is watched.
///
/// Committed on pop, like every other sub-screen.
class HostageSubScreen extends ConsumerStatefulWidget {
  const HostageSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
  });

  final HostageType initial;
  final ValueChanged<HostageType> onCommit;

  static const noneDescription = '寝坊してもコインもカードも失いません。連絡・共有だけの覚悟です。';
  static const coinDescription = '寝坊すると、アプリ内のコインが燃えます。';
  static const cardDescription = '寝坊で確定した金額を、毎月末にまとめてカードに請求します。';

  static const _options =
      <({HostageType value, String description, Key key})>[
        (
          value: HostageType.none,
          description: noneDescription,
          key: ValueKey('hostageOptionNone'),
        ),
        (
          value: HostageType.coin,
          description: coinDescription,
          key: ValueKey('hostageOptionCoin'),
        ),
        (
          value: HostageType.card,
          description: cardDescription,
          key: ValueKey('hostageOptionCard'),
        ),
      ];

  @override
  ConsumerState<HostageSubScreen> createState() => _HostageSubScreenState();
}

class _HostageSubScreenState extends ConsumerState<HostageSubScreen> {
  late HostageType _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enrolled = ref.watch(cardHostageProvider).card != null;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onCommit(_selected);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('人質')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            RadioGroup<HostageType>(
              groupValue: _selected,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selected = value);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in HostageSubScreen._options)
                    RadioListTile<HostageType>(
                      key: option.key,
                      value: option.value,
                      // The card cannot be put up before it is handed over.
                      enabled:
                          option.value != HostageType.card || enrolled,
                      selected: _selected == option.value,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option.value.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        option.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!enrolled)
              ListTile(
                key: const ValueKey('hostageRegisterCard'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card),
                title: const Text('カードを登録する'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => pushCardHostageScreen(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// 起床確認方法: which check has to be cleared to stop the alarm.
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
      appBar: AppBar(title: const Text('起床確認方法')),
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
