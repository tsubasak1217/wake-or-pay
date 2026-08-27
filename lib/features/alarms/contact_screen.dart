import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_controller.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/oversleep_contact_rules.dart';
import '../../services/voice_recorder.dart';
import '../settings/user_name_screen.dart';
import 'contact_book_screen.dart';
import 'edit_sub_screens.dart';
import 'widgets/settings_island.dart';

/// 寝坊時の連絡設定: who is told when the oversleeping runs long, on which
/// routes, and in whose words.
///
/// Three islands, per 改訂2:
///
/// * 寝坊時の連絡設定 — the person, when, and the two routes
/// * メール設定 — only while メール is on
/// * 電話設定 — only while 電話 is on
///
/// The person is picked from the 連絡帳 and **copied** into the alarm: name,
/// number and address. Deleting them from the book afterwards leaves this
/// alarm still able to reach them.
///
/// Like every other editor sub-screen the value is local while the screen is
/// open and handed back exactly once, when it closes — which covers the app
/// bar's back button and the system back gesture alike, because both go through
/// [PopScope].
class ContactSubScreen extends ConsumerStatefulWidget {
  const ContactSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
    this.alarmId,
  });

  final OversleepContact? initial;
  final ValueChanged<OversleepContact?> onCommit;

  /// Only used to name the recording file, so it is optional.
  final String? alarmId;

  @override
  ConsumerState<ContactSubScreen> createState() => _ContactSubScreenState();
}

class _ContactSubScreenState extends ConsumerState<ContactSubScreen> {
  late String? _contactId = widget.initial?.contactId;
  late String _name = widget.initial?.name ?? '';
  late String? _phone = widget.initial?.phone;
  late String? _email = widget.initial?.email;

  late bool _phoneEnabled = widget.initial?.phoneEnabled ?? false;
  late bool _emailEnabled = widget.initial?.emailEnabled ?? false;

  late MailMode _mailMode = widget.initial?.mailMode ?? MailMode.standard;
  late final TextEditingController _mailMessage = TextEditingController(
    text: widget.initial?.mailMessage ?? '',
  );

  late PhoneMode _phoneMode = widget.initial?.phoneMode ?? PhoneMode.auto;
  late String? _recordingPath = widget.initial?.recordingPath;

  late int _trigger = normalizeContactTriggerMinutes(
    widget.initial?.triggerMinutesAfterGrace ?? defaultContactTriggerMinutes,
  );

  bool _recording = false;
  bool _playing = false;
  StreamSubscription<bool>? _playbackSubscription;

  /// Shown in place of the buttons' result when the microphone was refused.
  String? _error;

  @override
  void initState() {
    super.initState();
    _playbackSubscription = ref.read(voicePlayerProvider).playing.listen((on) {
      if (mounted) setState(() => _playing = on);
    });
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _mailMessage.dispose();
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
    final message = _mailMessage.text.trim();
    final live = resolveOversleepContact(
      OversleepContact(
        contactId: _contactId,
        name: _name.trim(),
        phone: _phone,
        email: _email,
        phoneEnabled: _phoneEnabled,
        emailEnabled: _emailEnabled,
        mailMode: _mailMode,
        mailMessage: message.isEmpty ? null : message,
        phoneMode: _phoneMode,
        recordingPath: _recordingPath,
        triggerMinutesAfterGrace: normalizeContactTriggerMinutes(_trigger),
      ),
      book,
    );
    // A route can never be on without an address behind it, whatever the
    // stored value said: the toggle for it is not even reachable.
    return live.copyWith(
      phoneEnabled: live.phoneEnabled && live.hasPhone,
      emailEnabled: live.emailEnabled && live.hasEmail,
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
      // Picking somebody means wanting to reach them: every route they have an
      // address for starts on, and one they do not have stays off.
      _phoneEnabled = picked.hasPhone;
      _emailEnabled = picked.hasEmail;
    });
  }

  void _clearContact() => setState(() {
    _contactId = null;
    _name = '';
    _phone = null;
    _email = null;
    _phoneEnabled = false;
    _emailEnabled = false;
  });

  void _showError(String message) {
    setState(() => _error = message);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startRecording() async {
    final recorder = ref.read(voiceRecorderProvider);
    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      _showError('マイクの使用が許可されていないため録音できません。端末の設定から許可してください。');
      return;
    }
    // Allocating the file and opening the microphone are the two places this
    // can fail on a real device — no storage, or the mic already held by a
    // call. Either way the screen says so instead of throwing under the tap.
    try {
      final path = await ref.read(contactRecordingPathProvider)(widget.alarmId);
      await recorder.start(path);
    } catch (_) {
      if (!mounted) return;
      _showError('録音を開始できませんでした。ほかのアプリがマイクを使っていないか確認してください。');
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _error = null;
    });
  }

  Future<void> _stopRecording() async {
    final path = await ref.read(voiceRecorderProvider).stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      // A stop that produced nothing leaves the previous recording alone: the
      // user has not asked for it to be thrown away, 削除 is how that is said.
      if (path != null) _recordingPath = path;
    });
  }

  Future<void> _play() async {
    final path = _recordingPath;
    if (path == null) return;
    await ref.read(voicePlayerProvider).play(path);
  }

  Future<void> _deleteRecording() async {
    final path = _recordingPath;
    setState(() => _recordingPath = null);
    if (path == null) return;
    await ref.read(voicePlayerProvider).stop();
    // The file is the app's own, inside app storage, so deleting it here is
    // the whole deletion. A file that is already gone is not an error.
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  String get _recordingStatus {
    if (_recording) return '録音中';
    if (_recordingPath != null) return _playing ? '再生中' : '録音あり';
    return '録音なし';
  }

  String get _triggerLabel => _trigger == 0 ? '猶予後すぐ' : '猶予後 $_trigger分';

  /// The example both previews are drawn against: a fixed 07:00, so the text
  /// does not move under the user while they read it.
  static final _previewAt = DateTime(2026, 1, 1, 7);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The subject of the default sentence. Watched, so coming back from the
    // editor redraws the row and both previews.
    final userName = ref.watch(settingsProvider).userName;

    // Watched, not read: editing this person inside the 連絡帳 — which is a
    // route pushed on top of this screen — has to land on the 連絡先 row and
    // on both route toggles the moment it pops.
    final live = _contactFor(ref.watch(contactBookListProvider));
    final hasContact = live != null;
    final hasPhone = live?.hasPhone ?? false;
    final hasEmail = live?.hasEmail ?? false;
    final phoneOn = live?.phoneEnabled ?? false;
    final emailOn = live?.emailEnabled ?? false;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Leaving mid-recording discards it: the file is still being written
        // and there is nothing to await it on the way out, so committing a
        // path that may never be finished would be worse than dropping it.
        if (_recording) unawaited(ref.read(voiceRecorderProvider).stop());
        unawaited(ref.read(voicePlayerProvider).stop());
        widget.onCommit(_value);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('寝坊時連絡先')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SettingsIsland(
              title: '寝坊時の連絡設定',
              children: [
                // Above 連絡先 on purpose: the message is about this person and
                // is sent to that one, and reading the rows in order says so.
                SettingRow(
                  key: const ValueKey('contactUserNameRow'),
                  label: 'あなたの名前',
                  value: userName.isEmpty ? '未設定' : userName,
                  onTap: () => pushUserNameSubScreen(context),
                ),
                SettingRow(
                  key: const ValueKey('contactPickRow'),
                  label: '連絡先',
                  value: live?.name ?? 'なし',
                  onTap: _pickContact,
                ),
                SettingRow(
                  key: const ValueKey('contactTriggerRow'),
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
                          '起床猶予が切れてから何分後に連絡するかです。鳴り始めからではありません。'
                          '0分なら、猶予が切れたその瞬間に連絡します。',
                      onCommit: (v) => setState(() => _trigger = v),
                    ),
                  ),
                ),
                SettingSwitchRow(
                  label: '電話',
                  value: phoneOn,
                  enabled: hasPhone,
                  subtitle: hasPhone ? null : 'この連絡先には電話番号がありません',
                  onChanged: (v) => setState(() => _phoneEnabled = v),
                ),
                SettingSwitchRow(
                  label: 'メール',
                  value: emailOn,
                  enabled: hasEmail,
                  subtitle: hasEmail ? null : 'この連絡先にはメールアドレスがありません',
                  onChanged: (v) => setState(() => _emailEnabled = v),
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
            if (emailOn) _mailIsland(theme, userName),
            if (phoneOn) _phoneIsland(theme, userName),
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
              '現在は実際の送信は行いません。発火した記録がアプリ内に残るだけです'
              '（次のフェーズでサーバー送信に対応予定）。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mailIsland(ThemeData theme, String userName) => SettingsIsland(
    title: 'メール設定',
    children: [
      _ModeTile(
        key: const ValueKey('mailModeStandard'),
        label: 'デフォルト',
        description: 'アプリが用意した文面を送ります。',
        selected: _mailMode == MailMode.standard,
        onTap: () => setState(() => _mailMode = MailMode.standard),
      ),
      _ModeTile(
        key: const ValueKey('mailModeCustom'),
        label: 'カスタムメッセージ',
        description: '自分の言葉で書いた文面を送ります。',
        selected: _mailMode == MailMode.custom,
        onTap: () => setState(() => _mailMode = MailMode.custom),
      ),
      if (_mailMode == MailMode.custom)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            key: const ValueKey('contactMailMessage'),
            controller: _mailMessage,
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
            '例：${defaultOversleepMailMessage(userName: userName, at: _previewAt)}',
            key: const ValueKey('contactMailPreview'),
            style: theme.textTheme.bodySmall,
          ),
        ),
    ],
  );

  Widget _phoneIsland(ThemeData theme, String userName) {
    final hasRecording = _recordingPath != null;
    return SettingsIsland(
      title: '電話設定',
      children: [
        _ModeTile(
          key: const ValueKey('phoneModeAuto'),
          label: '自動音声',
          description: 'アプリが用意した文面を合成音声で読み上げます。',
          selected: _phoneMode == PhoneMode.auto,
          onTap: () => setState(() => _phoneMode = PhoneMode.auto),
        ),
        _ModeTile(
          key: const ValueKey('phoneModeCustom'),
          label: 'カスタム録音',
          description: '自分の声で録音したものを流します。',
          selected: _phoneMode == PhoneMode.custom,
          onTap: () => setState(() => _phoneMode = PhoneMode.custom),
        ),
        if (_phoneMode == PhoneMode.custom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _recording ? Icons.fiber_manual_record : Icons.mic_none,
                      color: _recording ? theme.colorScheme.error : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _recordingStatus,
                      key: const ValueKey('contactRecordingStatus'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _recording ? theme.colorScheme.error : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('contactRecordStart'),
                      onPressed: _recording ? null : _startRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('録音開始'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('contactRecordStop'),
                      onPressed: _recording ? _stopRecording : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('停止'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('contactRecordPlay'),
                      onPressed: hasRecording && !_recording ? _play : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('再生'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('contactRecordDelete'),
                      onPressed: hasRecording && !_recording
                          ? _deleteRecording
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('削除'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              '読み上げる文：${defaultOversleepVoiceScript(userName: userName, at: _previewAt)}',
              key: const ValueKey('contactVoicePreview'),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// One of the two modes an island offers. A radio in everything but the
/// widget: [Radio] would need a group above it, and the row is already the
/// group.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
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
