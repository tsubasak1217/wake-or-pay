import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import 'alarm_controller.dart';

class AlarmEditScreen extends ConsumerWidget {
  const AlarmEditScreen({super.key, this.alarmId});

  /// null when creating a new alarm.
  final String? alarmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = alarmId;
    if (id == null) return const _AlarmEditForm();

    return ref
        .watch(alarmByIdProvider(id))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (data) => data == null
              ? const Scaffold(body: Center(child: Text('アラームが見つかりません')))
              : _AlarmEditForm(existing: data),
        );
  }
}

class _AlarmEditForm extends ConsumerStatefulWidget {
  const _AlarmEditForm({this.existing});

  final Alarm? existing;

  @override
  ConsumerState<_AlarmEditForm> createState() => _AlarmEditFormState();
}

class _AlarmEditFormState extends ConsumerState<_AlarmEditForm> {
  late TimeOfDay _time;
  late Set<int> _days;
  late WakeCheckType _wakeCheck;
  late int _grace;
  late bool _kakugoOn;
  late int _rate;
  late final TextEditingController _capController;
  late final TextEditingController _customRateController;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _time = TimeOfDay(hour: a?.hour ?? 7, minute: a?.minute ?? 0);
    _days = {...?a?.repeatDays};
    _wakeCheck = a?.wakeCheck ?? WakeCheckType.longPress;
    _grace = normalizeGraceMinutes(a?.graceMinutes ?? minGraceMinutes);
    _kakugoOn = a?.isKakugo ?? false;
    _rate = a?.kakugo?.ratePerMinute ?? 100;
    _capController = TextEditingController(
      text: (a?.kakugo?.cap ?? 1000).toString(),
    );
    _customRateController = TextEditingController(
      text: Kakugo.ratePresets.contains(_rate) ? '' : _rate.toString(),
    );
  }

  @override
  void dispose() {
    _capController.dispose();
    _customRateController.dispose();
    super.dispose();
  }

  int get _cap => int.tryParse(_capController.text.trim()) ?? 0;

  Alarm _build() => Alarm(
    id: widget.existing?.id ?? AlarmController.newId(),
    hour: _time.hour,
    minute: _time.minute,
    repeatDays: _days,
    enabled: widget.existing?.enabled ?? true,
    wakeCheck: _wakeCheck,
    graceMinutes: _grace,
    kakugo: _kakugoOn ? Kakugo(ratePerMinute: _rate, cap: _cap) : null,
  );

  Future<void> _save() async {
    final coins = (await ref.read(walletRepositoryProvider).read()).coins;
    if (!mounted) return;

    // A warning, never a block: pledging more than you hold is allowed, it
    // simply cannot all burn.
    if (_kakugoOn && _cap > coins) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('残高より上限が大きい'),
          content: Text(
            '上限 $_cap コインに対して残高は $coins コインです。'
            '燃えるのは残高までですが、このまま保存できます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('このまま保存'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    await ref.read(alarmControllerProvider).save(_build());
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await ref.read(alarmControllerProvider).delete(existing);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'アラームを追加' : 'アラームを編集'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: '削除',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _TimeWheel(time: _time, onChanged: (t) => setState(() => _time = t)),
          const SizedBox(height: 16),
          Text('繰り返し', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
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
          const SizedBox(height: 4),
          Text(repeatDaysLabel(_days), style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          Text('起床確認', style: theme.textTheme.titleMedium),
          for (final type in WakeCheckType.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => setState(() => _wakeCheck = type),
              title: Text(type.label),
              trailing: _wakeCheck == type ? const Icon(Icons.check) : null,
            ),
          const SizedBox(height: 24),
          Text('起床猶予', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in graceMinutesOptions)
                ChoiceChip(
                  label: Text('$minutes 分'),
                  selected: _grace == minutes,
                  onSelected: (_) => setState(() => _grace = minutes),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '鳴り始めから $_grace 分以内に解除できれば起床成功。'
            '過ぎるとその瞬間から燃え始めます。',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _kakugoOn,
            onChanged: (v) => setState(() => _kakugoOn = v),
            title: const Text('覚悟モード'),
            subtitle: const Text('寝坊した1分ごとにコインが燃えます'),
          ),
          if (_kakugoOn) ...[
            const SizedBox(height: 8),
            Text('1分あたり', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in Kakugo.ratePresets)
                  ChoiceChip(
                    label: Text('$preset'),
                    selected: _rate == preset,
                    onSelected: (_) => setState(() {
                      _rate = preset;
                      _customRateController.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customRateController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'カスタム（コイン/分）',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v.trim());
                if (parsed != null) setState(() => _rate = parsed);
              },
            ),
            const SizedBox(height: 8),
            Text(kakugoMood(_rate), style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            TextField(
              controller: _capController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '1回の最大損失（コイン）',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(kakugoLabel(Kakugo(ratePerMinute: _rate, cap: _cap))),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('保存'),
      ),
    );
  }
}

/// The iOS style hour/minute wheels, 24 hour, inline in the form.
///
/// Cupertino widgets carry their own theme, so the picker is wrapped in a
/// [CupertinoTheme] built from the Material one — otherwise it would ignore the
/// app's colours and read as black text on the dark themes.
class _TimeWheel extends StatelessWidget {
  const _TimeWheel({required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  static const height = 190.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: theme.brightness,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle:
                theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ) ??
                const TextStyle(),
          ),
        ),
        child: CupertinoDatePicker(
          key: const ValueKey('timeWheel'),
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          // A fixed date: only the hour and minute of this value are read.
          initialDateTime: DateTime(2026, 1, 1, time.hour, time.minute),
          onDateTimeChanged: (t) =>
              onChanged(TimeOfDay(hour: t.hour, minute: t.minute)),
        ),
      ),
    );
  }
}
