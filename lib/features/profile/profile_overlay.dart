import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../domain/journey_stats.dart';
import '../../services/card_hostage.dart';
import '../../services/mail_settings.dart';
import '../alarms/widgets/settings_island.dart';
import '../widgets/discord_icon.dart';
import '../widgets/top_sheet.dart';
import 'card_hostage_screen.dart';
import 'discord_link_screen.dart';
import 'mail_settings_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_head.dart';

/// Drops the profile over whatever is on screen, from the top.
///
/// The route, the grab bar and the 閉じる button are [TopSheetOverlay]'s, shared
/// with オプション so the two sheets cannot behave differently.
Future<void> showProfileOverlay(BuildContext context) => showTopSheet(
  context,
  barrierLabel: 'プロフィールを閉じる',
  builder: (_) => const ProfileOverlay(),
);

/// 誰であるか (the head), 何をしてきたか (これまでの歩み), 何と繋がっているか
/// (連携情報) — in that order, and nothing else.
///
/// The cosmetics pickers used to live here, under 「コレクション」. They moved to
/// [ProfileEditScreen]: choosing an icon is something you do while looking at
/// the result, and the result was two islands above the picker.
class ProfileOverlay extends ConsumerWidget {
  const ProfileOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return TopSheetOverlay(
      scaffoldKey: const ValueKey('profileOverlay'),
      handleKey: const ValueKey('profileOverlayHandle'),
      closeKey: const ValueKey('profileOverlayClose'),
      // 誰であるか stays put: the head is who you are, and scrolling 歩み must
      // not take your own face off the screen.
      header: ProfileHead(
        profile: profile,
        keyPrefix: 'profile',
        onEdit: () => pushProfileEditScreen(context),
      ),
      // No spacer row at the top: the air under the head is the header slot's
      // own bottom padding now, so it survives scrolling instead of sliding
      // under the head with the rest of the list.
      children: const [
        _JourneyIsland(),
        _LinksIsland(),
      ],
    );
  }
}

/// これまでの歩み. Every row is derived — see [journeyStatsProvider] — so there
/// is nothing here to keep in sync with anything.
class _JourneyIsland extends ConsumerWidget {
  const _JourneyIsland();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(journeyStatsProvider);

    return SettingsIsland(
      key: const ValueKey('profileJourneyIsland'),
      title: 'これまでの歩み',
      children: [
        _JourneyRow(
          rowKey: 'journeyStartedAt',
          label: '開始日',
          value: journeyDateLabel(stats.startedAt),
        ),
        _JourneyRow(
          rowKey: 'journeyLoginDays',
          label: 'ログイン日数',
          value: '${stats.loginDays}日',
        ),
        _JourneyRow(
          rowKey: 'journeyTotalPenalty',
          label: '累計ペナルティ額',
          value: journeyPenaltyLabel(stats.totalPenalty),
        ),
        _JourneyRow(
          rowKey: 'journeyMaxPenalty',
          label: '最大ペナルティ額',
          value: journeyPenaltyLabel(stats.maxPenalty),
        ),
        _JourneyRow(
          rowKey: 'journeySuccessRate',
          label: '起床成功率',
          value: journeyRateLabel(stats.successRate),
        ),
        _JourneyRow(
          rowKey: 'journeyOversleepCount',
          label: '累計寝坊回数',
          value: '${stats.oversleepCount}回',
        ),
        _JourneyRow(
          rowKey: 'journeyTotalOversleep',
          label: '累計寝坊時間',
          value: journeyDurationLabel(stats.totalOversleep),
        ),
        _JourneyRow(
          rowKey: 'journeyMaxOversleep',
          label: '最大寝坊時間',
          value: journeyDurationLabel(stats.maxOversleep),
        ),
        _JourneyRow(
          rowKey: 'journeyCollections',
          label: '所持コレクション数',
          value: '${stats.ownedCollections} / ${stats.totalCollections}',
        ),
      ],
    );
  }
}

/// A label on the left and a number on the right. **No chevron**: these rows go
/// nowhere, and a chevron is the promise that tapping does something.
class _JourneyRow extends StatelessWidget {
  const _JourneyRow({
    required this.rowKey,
    required this.label,
    required this.value,
  });

  final String rowKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey(rowKey),
      title: Text(label),
      trailing: Text(
        value,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 未連携 / 連携済み — the only two things a 連携情報 row ever says. Pure.
String _linkLabel({required bool linked}) => linked ? '連携済み' : '未連携';

/// 連携情報 — everything that reaches outside this phone, in one place.
///
/// **Three rows, one word each.** Not a screen: an index of screens. Every row
/// is an icon, a name, 未連携 or 連携済み, and a chevron — no subtitle explaining
/// the service, no 「連携を解除」 button, and no card number or mail address. The
/// island's job is to answer 「何と繋がっているか」 at a glance; what each link
/// means, how it is made and how it is broken all live behind the tap, where
/// there is room for them. `****1234` and 「山田 から送ります」 are details of a
/// link, not the state of one, so neither is here.
///
/// 「あなたの名前」 used to be the first row of this island back when it was
/// 「プロフィール設定」. It is not a link to anything, and the name is now edited
/// where it is previewed: in [ProfileEditScreen].
class _LinksIsland extends ConsumerWidget {
  const _LinksIsland();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discordLinked = ref.watch(profileProvider).discordLinked;
    final mail = ref.watch(mailSettingsProvider);
    final card = ref.watch(cardHostageProvider).card;

    return SettingsIsland(
      key: const ValueKey('profileLinksIsland'),
      title: '連携情報',
      children: [
        SettingRow(
          key: const ValueKey('profileDiscordRow'),
          leading: const DiscordIcon(),
          label: 'Discord',
          value: _linkLabel(linked: discordLinked),
          onTap: () => pushDiscordLinkScreen(context),
        ),
        // 罰としての請求（`docs/BILLING_API.md`）。機能を売る行ではない：
        // 押しても何も解放されず、押さなくても全機能が使える。
        SettingRow(
          key: const ValueKey('profileCardHostageRow'),
          leading: const Icon(Icons.credit_card),
          label: 'クレジットカード',
          value: _linkLabel(linked: card != null),
          onTap: () => pushCardHostageScreen(context),
        ),
        // 連携済み only when the app could actually send: a half-filled account
        // is 未連携 as far as every other screen is concerned, so this row must
        // not be the one place that calls it done.
        SettingRow(
          key: const ValueKey('profileMailRow'),
          leading: const Icon(Icons.mail_outline),
          label: 'メール',
          value: _linkLabel(linked: mail.isConfigured),
          onTap: () => pushMailSettingsScreen(context),
        ),
        // 「アプリの更新」 used to sit here. It is not プロフィール — it is about
        // the app, not about who you are — so it moved to オプション › アプリ
        // (`optionsUpdateRow`).
      ],
    );
  }
}
