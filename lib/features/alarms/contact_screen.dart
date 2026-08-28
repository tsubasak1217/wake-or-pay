import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_controller.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/oversleep_contact_rules.dart';
import '../../services/mail_settings.dart';
import '../../services/route_permissions.dart';
import '../profile/mail_settings_screen.dart';
import '../profile/profile_overlay.dart';
import 'contact_book_screen.dart';
import 'widgets/mode_tile.dart';
import 'widgets/settings_island.dart';

/// 寝坊時の連絡設定: who is told when the oversleeping runs long, on which
/// routes, and in whose words.
///
/// Two islands, per spec 11.4:
///
/// * 寝坊時の連絡設定 — the person and the routes (SMS / メール)
/// * メール・SMS設定 — only while メール or SMS is on
///
/// The phone-call route was removed: auto-dialling from the background / lock
/// screen is unreliable across OEMs, Play-restricted, and cannot be verified.
/// The stored number stays — SMS is sent to it — but there is no 電話 toggle.
/// 送信タイミング moved up to 寝坊時連絡・共有, where the 共有 shares it.
///
/// The person is picked from the 連絡帳 and **copied** into the alarm: name,
/// number and address. Deleting them from the book afterwards leaves this
/// alarm still able to reach them.
///
/// Like every other editor sub-screen the value is local while the screen is
/// open and handed back exactly once, when it closes — which covers the app
/// bar's back button and the system back gesture alike, because both go
/// through [PopScope].
class ContactSubScreen extends ConsumerStatefulWidget {
  const ContactSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
    this.alarmId,
  });

  final OversleepContact? initial;
  final ValueChanged<OversleepContact?> onCommit;

  /// Unused now that the recorder has moved to the 共有 screen. Kept so the
  /// caller does not have to know that.
  final String? alarmId;

  @override
  ConsumerState<ContactSubScreen> createState() => _ContactSubScreenState();
}

class _ContactSubScreenState extends ConsumerState<ContactSubScreen> {
  late String? _contactId = widget.initial?.contactId;
  late String _name = widget.initial?.name ?? '';
  late String? _phone = widget.initial?.phone;
  late String? _email = widget.initial?.email;

  late bool _emailEnabled = widget.initial?.emailEnabled ?? false;
  late bool _smsEnabled = widget.initial?.smsEnabled ?? false;

  late MessageMode _messageMode =
      widget.initial?.messageMode ?? MessageMode.standard;
  late final TextEditingController _message = TextEditingController(
    text: widget.initial?.message ?? '',
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _hasContact => _name.trim().isNotEmpty;

  /// What this screen would hand back, with the **live** 連絡帳 entry's name and
  /// addresses in it rather than the copy the alarm was carrying.
  ///
  /// The fields above are the snapshot the alarm arrived with; they are only
  /// what is shown when the entry behind them has been deleted. Resolving here
  /// means both that the screen shows the edited name straight away and that
  /// the alarm's stored copy is refreshed the moment this screen is left —
  /// the snapshot cannot drift while anyone is looking at it.
  OversleepContact? _contactFor(List<ContactEntry> book) {
    if (!_hasContact) return null;
    final message = _message.text.trim();
    final live = resolveOversleepContact(
      OversleepContact(
        contactId: _contactId,
        name: _name.trim(),
        phone: _phone,
        email: _email,
        emailEnabled: _emailEnabled,
        smsEnabled: _smsEnabled,
        messageMode: _messageMode,
        message: message.isEmpty ? null : message,
      ),
      book,
    );
    // A route can never be on without an address behind it, whatever the
    // stored value said: the toggle for it is not even reachable.
    return live.copyWith(
      emailEnabled: live.emailEnabled && live.hasEmail,
      smsEnabled: live.smsEnabled && live.hasPhone,
    );
  }

  OversleepContact? get _value =>
      _contactFor(ref.read(contactBookListProvider));

  Future<void> _pickContact() async {
    final picked = await Navigator.of(context).push<ContactEntry>(
      MaterialPageRoute(
        builder: (_) => ContactBookScreen(selectedId: _contactId),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _contactId = picked.id;
      _name = picked.name;
      _phone = picked.phone;
      _email = picked.email;
      // Gated on the same flag the toggle is: switching メール on for somebody
      // the app cannot mail would put a route in the stored contact — and in
      // the event log — that the user never enabled and cannot see, let alone
      // switch back off.
      _emailEnabled = picked.hasEmail && ref.read(mailSendingConfiguredProvider);
      // SMS does not start on: a text message is a decision the user makes,
      // not a default that goes out silent at 4am.
      _smsEnabled = false;
    });
  }

  void _clearContact() => setState(() {
    _contactId = null;
    _name = '';
    _phone = null;
    _email = null;
    _emailEnabled = false;
    _smsEnabled = false;
  });

  /// SMS needs `SEND_SMS`, and spec 11.5 asks for it here — at the moment the
  /// route is switched on, where the reason for the dialog is on screen — not
  /// at launch.
  ///
  /// A refusal leaves the toggle off and says so. Storing it on anyway would
  /// put a route in the alarm that silently fails at 7am, which is the one
  /// outcome this whole feature exists to avoid.
  Future<void> _setSms(bool on) => _setRoute(
    on: on,
    request: () => ref.read(routePermissionsProvider).requestSms(),
    apply: (value) => setState(() => _smsEnabled = value),
    refusal: 'SMS の送信が許可されていないので、SMS は使えません',
  );

  Future<void> _setRoute({
    required bool on,
    required Future<bool> Function() request,
    required void Function(bool) apply,
    required String refusal,
  }) async {
    if (!on) {
      apply(false);
      return;
    }
    final granted = await request();
    if (!mounted) return;
    if (granted) {
      apply(true);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(refusal)));
  }

  /// The example the preview is drawn against: a fixed 07:00, so the text does
  /// not move under the user while they read it.
  static final _previewAt = DateTime(2026, 1, 1, 7);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The subject of the default sentence. Watched, so coming back from the
    // editor redraws the row and the preview.
    final userName = ref.watch(profileProvider).userName;

    // The one flag behind every メール control on this screen, per spec 11.5.
    // False for the whole of stage C: there is no SMTP account yet, so there
    // is nothing to send with.
    //
    // It greys the toggle; it does **not** switch the stored value off. An
    // alarm written under an earlier version with メール on has said what its
    // owner wants, and unsetting that because the sending half is not built
    // yet would quietly lose a choice they made — and would take an extra tap
    // to get back the day stage D lands.
    final mailConfigured = ref.watch(mailSendingConfiguredProvider);

    // Watched, not read: editing this person inside the 連絡帳 — which is a
    // route pushed on top of this screen — has to land on the 連絡先 row and
    // on every route toggle the moment it pops.
    final live = _contactFor(ref.watch(contactBookListProvider));
    final hasContact = live != null;
    final hasPhone = live?.hasPhone ?? false;
    final hasEmail = live?.hasEmail ?? false;
    final emailOn = live?.emailEnabled ?? false;
    final smsOn = live?.smsEnabled ?? false;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onCommit(_value);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('寝坊時の連絡設定')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SettingsIsland(
              title: '寝坊時の連絡設定',
              children: [
                // Above 連絡先 on purpose: the message is about this person and
                // is sent to that one, and reading the rows in order says so.
                // A pointer, not an editor: the name is one value and it is
                // owned by the profile now, so this row shows what it is and
                // opens the place it is set.
                SettingRow(
                  key: const ValueKey('contactUserNameRow'),
                  label: 'あなたの名前',
                  value: userName.isEmpty ? '未設定' : userName,
                  subtitle: '名前はプロフィールで設定します',
                  onTap: () => showProfileOverlay(context),
                ),
                SettingRow(
                  key: const ValueKey('contactPickRow'),
                  label: '連絡先',
                  value: live?.name ?? 'なし',
                  onTap: _pickContact,
                ),
                SettingSwitchRow(
                  label: 'メール',
                  value: emailOn && mailConfigured,
                  enabled: hasEmail && mailConfigured,
                  subtitle: !hasEmail
                      ? 'この連絡先にはメールアドレスがありません'
                      : (mailConfigured ? null : mailSendingUnconfiguredNote),
                  onChanged: (v) => setState(() => _emailEnabled = v),
                ),
                // Only when the toggle is grey for the one reason the user can
                // do something about. A row rather than a sentence: the fix is
                // two screens away, and telling somebody where to go is worse
                // than taking them.
                if (hasEmail && !mailConfigured)
                  ListTile(
                    key: const ValueKey('contactMailSetupRow'),
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('メール送信設定を開く'),
                    subtitle: const Text('あなたのアドレスとアプリパスワードを登録します'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => pushMailSettingsScreen(context),
                  ),
                SettingSwitchRow(
                  label: 'SMS',
                  value: smsOn,
                  enabled: hasPhone,
                  subtitle: hasPhone
                      ? 'あなたの番号から相手にメッセージを送ります'
                      : 'この連絡先には電話番号がありません',
                  onChanged: _setSms,
                ),
                // Modelled nowhere and offered nowhere: the row exists so the
                // list of routes is the whole list, and the note says why it
                // cannot be pressed rather than leaving the user to guess.
                const SettingSwitchRow(
                  key: ValueKey('contactLineRow'),
                  label: 'LINE',
                  value: false,
                  enabled: false,
                  subtitle: 'まだ実装しない',
                  onChanged: _ignoreToggle,
                ),
              ],
            ),
            if (userName.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                child: Text(
                  'あなたの名前が未設定です。デフォルト文面では'
                  '「$oversleepUserNameFallback」と表示されます。',
                  key: const ValueKey('contactUserNameWarning'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            // One island for both written routes, because they carry one body.
            if ((emailOn && mailConfigured) || smsOn)
              _messageIsland(
                theme,
                userName,
                mailOn: emailOn && mailConfigured,
              ),
            if (hasContact)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('contactClear'),
                  onPressed: _clearContact,
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('連絡先を外す'),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'ここの経路（SMS・メール）と寝坊の共有（Discord）は、'
              '発火したときに実際に送信します。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// [mailOn] is メール as it stands *right now* — enabled and sendable — not
  /// the stored flag: it picks which default sentence the preview shows.
  Widget _messageIsland(
    ThemeData theme,
    String userName, {
    required bool mailOn,
  }) => SettingsIsland(
    key: const ValueKey('messageIsland'),
    title: 'メール・SMS設定',
    children: [
      ModeTile(
        key: const ValueKey('messageModeStandard'),
        label: 'デフォルト',
        description: 'アプリが用意した文面を送ります。',
        selected: _messageMode == MessageMode.standard,
        onTap: () => setState(() => _messageMode = MessageMode.standard),
      ),
      ModeTile(
        key: const ValueKey('messageModeCustom'),
        label: 'カスタムメッセージ',
        description: '自分の言葉で書いた文面を送ります。メールと SMS で同じ文面です。',
        selected: _messageMode == MessageMode.custom,
        onTap: () => setState(() => _messageMode = MessageMode.custom),
      ),
      if (_messageMode == MessageMode.custom)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            key: const ValueKey('contactMessage'),
            controller: _message,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'メッセージ',
              border: OutlineInputBorder(),
            ),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            // The route that is actually on decides which default is shown.
            // The two differ by the 【Wake or Pay】 subject tag — mail has an
            // inbox to be recognised in and SMS does not — so previewing the
            // mail body beside an SMS-only island would show a sentence that
            // could never be sent. In stage C that is the *only* way this
            // island appears, because メール cannot be switched on at all.
            '例：${mailOn ? defaultOversleepMailMessage(userName: userName, at: _previewAt) : defaultOversleepSmsMessage(userName: userName, at: _previewAt)}',
            key: const ValueKey('contactMessagePreview'),
            style: theme.textTheme.bodySmall,
          ),
        ),
    ],
  );
}

/// A disabled switch still needs a callback to name. It is never reached —
/// [SettingSwitchRow] hands `null` to the switch when the row is disabled,
/// which is what draws it grey and makes it untappable.
void _ignoreToggle(bool _) {}
