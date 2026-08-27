import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/oversleep_contact_rules.dart';
import 'contact_screen.dart';
import 'edit_sub_screens.dart';
import 'share_screen.dart';
import 'widgets/settings_island.dart';

/// 寝坊時連絡・共有, per spec 11.3 — the one row in 覚悟の設定 that everything
/// about telling somebody now hangs off.
///
/// Three rows, and the third is the reason this screen exists: 送信タイミング is
/// **one number for both halves**. A personal call and a Discord post about
/// the same overslept alarm going out at different times would be two events
/// about one morning, so the delay lives on the alarm and both read it.
///
/// Each row's value is committed on pop, and this screen commits its own on
/// pop, so an edit three screens deep lands on the draft in one hop when the
/// user walks back out.
class ContactShareSubScreen extends ConsumerStatefulWidget {
  const ContactShareSubScreen({
    super.key,
    required this.contact,
    required this.share,
    required this.triggerMinutes,
    required this.onCommit,
    this.alarmId,
  });

  final OversleepContact? contact;
  final OversleepShare? share;
  final int triggerMinutes;

  /// Handed the whole trio at once: they are edited together and there is no
  /// state in which two of the three are the new values and one is not.
  final void Function(
    OversleepContact? contact,
    OversleepShare? share,
    int triggerMinutes,
  )
  onCommit;

  /// Only used to name the recording file, so it is optional.
  final String? alarmId;

  @override
  ConsumerState<ContactShareSubScreen> createState() =>
      _ContactShareSubScreenState();
}

class _ContactShareSubScreenState
    extends ConsumerState<ContactShareSubScreen> {
  late OversleepContact? _contact = widget.contact;
  late OversleepShare? _share = widget.share;
  late int _trigger = normalizeContactTriggerMinutes(widget.triggerMinutes);

  String get _triggerLabel => _trigger == 0 ? '猶予後すぐ' : '猶予後 $_trigger分';

  @override
  Widget build(BuildContext context) {
    // Watched: renaming somebody in the 連絡帳, or registering a 共有先, both
    // happen on screens pushed over this one and have to land on the row the
    // moment they pop.
    final book = ref.watch(contactBookListProvider);
    final contactName =
        resolveOversleepContactOrNull(_contact, book)?.name ?? 'なし';
    // Ids with no row behind them are not counted — a deleted 共有先 is one
    // fewer place this alarm posts to, not a broken alarm.
    final shareCount = liveShareTargetCount(
      _share,
      ref.watch(discordWebhookListProvider),
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onCommit(_contact, _share, _trigger);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('寝坊時連絡・共有')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SettingsIsland(
              title: '寝坊時連絡・共有',
              children: [
                SettingRow(
                  key: const ValueKey('contactRow'),
                  label: '寝坊時連絡先',
                  value: contactName,
                  onTap: () => pushEditorSubScreen(
                    context,
                    ContactSubScreen(
                      alarmId: widget.alarmId,
                      initial: _contact,
                      onCommit: (v) => setState(() => _contact = v),
                    ),
                  ),
                ),
                SettingRow(
                  key: const ValueKey('shareRow'),
                  label: '寝坊の共有',
                  value: shareCount == 0 ? 'なし' : 'Discord $shareCount件',
                  onTap: () => pushEditorSubScreen(
                    context,
                    ShareSubScreen(
                      alarmId: widget.alarmId,
                      initial: _share,
                      onCommit: (v) => setState(() => _share = v),
                    ),
                  ),
                ),
                SettingRow(
                  key: const ValueKey('triggerRow'),
                  label: '送信タイミング',
                  value: _triggerLabel,
                  onTap: () => pushEditorSubScreen(
                    context,
                    NumberSubScreen(
                      title: '送信タイミング',
                      initial: _trigger,
                      min: minContactTriggerMinutes,
                      max: maxContactTriggerMinutes,
                      suffix: '分',
                      description:
                          '起床猶予が切れてから何分後に連絡・共有するかです。鳴り始めからではありません。'
                          '0分なら、猶予が切れたその瞬間です。連絡と共有は同じタイミングで出ます。',
                      onCommit: (v) => setState(() => _trigger = v),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '連絡は相手ひとりに、共有はグループに向けたものです。'
              'どちらも設定していなければ、寝坊しても誰にも知られません。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
