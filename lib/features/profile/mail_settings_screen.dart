import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/send_result.dart';
import '../../services/mail_settings.dart';
import '../alarms/widgets/settings_island.dart';

/// メール送信設定 — the SMTP account the oversleep mail goes out from, per
/// spec 11.5.
///
/// Not a PopScope-commit screen like the rest of the editor. Two things make
/// it different: there is a password, which must be written deliberately and
/// never on the way past; and there is a 「テスト送信」 that has to send with
/// *exactly* what is on screen, which means what is on screen has to be stored
/// first. So it has a 保存 button, and テスト送信 saves before it sends.
class MailSettingsScreen extends ConsumerStatefulWidget {
  const MailSettingsScreen({super.key});

  @override
  ConsumerState<MailSettingsScreen> createState() => _MailSettingsScreenState();
}

class _MailSettingsScreenState extends ConsumerState<MailSettingsScreen> {
  late MailSettings _settings = ref.read(mailSettingsProvider);

  late final _host = TextEditingController(text: _settings.host);
  late final _port = TextEditingController(text: '${_settings.port}');
  late final _from = TextEditingController(text: _settings.fromAddress);
  late final _username = TextEditingController(text: _settings.username);

  /// Always starts empty, even when a password is stored: it cannot be read
  /// back out of the secure store into a text field without putting it back in
  /// the widget tree, and there is no reason to. Empty on save means 「変更なし」.
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  /// The last 「テスト送信」 outcome, kept on screen rather than in a SnackBar
  /// that vanishes while the user is still reading it.
  SendResult? _testResult;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _from.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  MailPreset get _preset => MailPreset.byId(_settings.presetId);

  bool get _isCustom => _preset.id == MailPreset.customId;

  void _selectPreset(MailPreset preset) {
    setState(() {
      _settings = applyMailPreset(_settings, preset);
      _host.text = _settings.host;
      _port.text = '${_settings.port}';
      // The login is the address for every preset here, and typing the same
      // string twice is the commonest way to get one of them wrong.
      if (_username.text.trim().isEmpty) _username.text = _from.text.trim();
    });
  }

  /// The form as it stands. The password is handled separately — it is never a
  /// field of [MailSettings].
  MailSettings get _formValue => _settings.copyWith(
    host: _host.text.trim(),
    port: int.tryParse(_port.text.trim()) ?? _settings.port,
    fromAddress: _from.text.trim(),
    username: _username.text.trim(),
  );

  /// What is missing, or null when nothing is. Drives the hint under 保存 and
  /// whether テスト送信 can be pressed.
  String? get _missing {
    final value = _formValue;
    if (value.host.isEmpty) return 'SMTP ホストを入力してください';
    if (value.port <= 0) return 'ポート番号が正しくありません';
    if (!isEmailAddress(value.fromAddress)) return '送信元アドレスを入力してください';
    if (value.username.isEmpty) return 'ユーザー名を入力してください';
    if (_password.text.isEmpty && !_settings.passwordSaved) {
      return 'アプリパスワードを入力してください';
    }
    return null;
  }

  Future<void> _save() async {
    final saved = await _store();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved.isConfigured ? 'メール送信設定を保存しました' : '保存しましたが、まだ未完了です'),
      ),
    );
  }

  /// Writes the form, clears the password field, and hands back what was
  /// actually stored.
  Future<MailSettings> _store() async {
    final password = _password.text;
    await ref
        .read(mailSettingsProvider.notifier)
        .save(_formValue, password: password.isEmpty ? null : password);
    final stored = ref.read(mailSettingsProvider);
    if (mounted) {
      setState(() {
        _settings = stored;
        _password.clear();
      });
    }
    return stored;
  }

  Future<void> _clearPassword() async {
    await ref
        .read(mailSettingsProvider.notifier)
        .save(_formValue, clearPassword: true);
    if (!mounted) return;
    setState(() {
      _settings = ref.read(mailSettingsProvider);
      _password.clear();
      _testResult = null;
    });
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _testResult = null;
    });
    // Saved first: the test has to prove the settings that were stored, not a
    // form the user might still change before the alarm ever fires.
    await _store();
    final result = await ref.read(mailSettingsProvider.notifier).sendTest();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = _missing;

    return Scaffold(
      appBar: AppBar(title: const Text('メール送信設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'あなた自身のメールアカウントから、寝坊したことを連絡先に知らせます。'
            '入力した内容はこの端末の中だけに保存され、どこにも送信されません。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SettingsIsland(
            title: 'サーバー',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('プリセット', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final preset in MailPreset.all)
                          ChoiceChip(
                            key: ValueKey('mailPreset-${preset.id}'),
                            label: Text(preset.label),
                            selected: preset.id == _settings.presetId,
                            onSelected: (_) => _selectPreset(preset),
                          ),
                      ],
                    ),
                    if (_preset.note != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _preset.note!,
                        key: const ValueKey('mailPresetNote'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              _field(
                keyName: 'mailHostField',
                controller: _host,
                label: 'SMTP ホスト',
                hint: '例：smtp.gmail.com',
                enabled: _isCustom,
                keyboardType: TextInputType.url,
              ),
              _field(
                keyName: 'mailPortField',
                controller: _port,
                label: 'ポート',
                hint: '$defaultSmtpPort',
                enabled: _isCustom,
                keyboardType: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SettingSwitchRow(
                key: const ValueKey('mailSslRow'),
                label: 'SSL で接続する',
                value: _settings.useSsl,
                enabled: _isCustom,
                subtitle: _settings.useSsl
                    ? '最初から TLS で接続します（ポート $sslSmtpPort など）'
                    : 'STARTTLS で暗号化します（ポート $defaultSmtpPort など）。'
                          '暗号化できないサーバーには送りません',
                onChanged: (v) =>
                    setState(() => _settings = _settings.copyWith(useSsl: v)),
              ),
            ],
          ),
          SettingsIsland(
            title: 'アカウント',
            children: [
              _field(
                keyName: 'mailFromField',
                controller: _from,
                label: '送信元アドレス',
                hint: '例：you@gmail.com',
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  // The two are the same string for every preset here, so the
                  // login follows the address until the user says otherwise.
                  if (_username.text.trim().isEmpty) setState(() {});
                },
              ),
              _field(
                keyName: 'mailUsernameField',
                controller: _username,
                label: 'ユーザー名',
                hint: 'ふつうは送信元アドレスと同じです',
                keyboardType: TextInputType.emailAddress,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  key: const ValueKey('mailPasswordField'),
                  controller: _password,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  // The 保存 hint and the テスト送信 button both count this field
                  // as one of the things that must be filled in, so typing in
                  // it has to redraw them.
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'アプリパスワード',
                    hintText: _settings.passwordSaved ? '保存済み（変更するときだけ入力）' : '',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      key: const ValueKey('mailPasswordReveal'),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscure ? '表示する' : '隠す',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              if (_settings.passwordSaved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'アプリパスワードは保存済みです。'
                          'この端末の暗号化された保管領域にだけあります。',
                          key: const ValueKey('mailPasswordSavedNote'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('mailPasswordClear'),
                        onPressed: _busy ? null : _clearPassword,
                        child: const Text('削除'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (missing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                missing,
                key: const ValueKey('mailMissingNote'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          FilledButton(
            key: const ValueKey('mailSaveButton'),
            onPressed: _busy ? null : _save,
            child: const Text('保存'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('mailTestButton'),
            // Sends to the user's own address, so there is nobody to bother by
            // pressing it — but it does need a complete account first.
            onPressed: _busy || missing != null ? null : _test,
            child: Text(_busy ? '送信中…' : 'テスト送信（自分あて）'),
          ),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                _testResult!.ok
                    ? '${_from.text.trim()} に送信しました。受信を確認してください。'
                    : '送信できませんでした：${_testResult!.reason}',
                key: const ValueKey('mailTestResult'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _testResult!.ok
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 24),
          const _GmailHelp(),
        ],
      ),
    );
  }

  Widget _field({
    required String keyName,
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: TextField(
      key: ValueKey(keyName),
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      autocorrect: false,
      onChanged: (value) {
        onChanged?.call(value);
        // The 保存 hint and the テスト送信 button both read the form, so every
        // keystroke has to redraw them.
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        helperText: enabled ? null : 'プリセットが決めています',
      ),
    ),
  );
}

/// How to get a Gmail app password, per spec 11.5.
///
/// Written out rather than linked: the user is standing in a settings screen
/// at some point in the evening, and 「2段階認証を先に有効にする」 is the step
/// everybody misses — the アプリパスワード page simply does not exist until it
/// is on.
class _GmailHelp extends StatelessWidget {
  const _GmailHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsIsland(
      title: 'Gmail のアプリパスワードの作り方',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: const ValueKey('mailGmailHelp'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in const [
                '1. Google アカウントの「セキュリティ」を開きます。',
                '2. 「2段階認証プロセス」を有効にします。（先に有効にしないと次の項目が出てきません）',
                '3. 同じページの「アプリパスワード」を開きます。',
                '4. 名前を決めて作成すると、16文字のパスワードが表示されます。',
                '5. その16文字をここの「アプリパスワード」に貼り付けます。'
                    '（ふだんの Google のパスワードではありません）',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
              Text(
                'アプリパスワードは、この端末の暗号化された保管領域に保存されます。'
                'アプリの通常の設定ファイルには書き込まれず、ログにも出しません。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the editor over whatever screen asked for it — the profile overlay
/// today, and the メール toggle's hint tomorrow.
Future<void> pushMailSettingsScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const MailSettingsScreen()));
