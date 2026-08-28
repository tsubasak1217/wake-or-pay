import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models.dart';
import '../../domain/send_result.dart';
import '../../services/mail_settings.dart';
import '../alarms/widgets/settings_island.dart';

/// Opens a URL in whatever the OS uses for it. Injected so no test opens a
/// browser: overridden in widget tests to record the URL instead.
typedef MailUrlOpener = Future<bool> Function(Uri url);

Future<bool> _launchExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

final mailUrlOpenerProvider = Provider<MailUrlOpener>(
  (ref) => _launchExternal,
);

/// メール送信設定 — the SMTP account the oversleep mail goes out from, per
/// spec 11.5.
///
/// Simplified to the common case: メールアドレス and アプリパスワード. The server is
/// derived from the address's domain via [smtpForEmail]; only a domain the app
/// does not know reveals 詳細設定 for a hand-entered server.
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

  late final _from = TextEditingController(text: _settings.fromAddress);

  /// The 詳細設定 fields — used only when the address's domain is unknown.
  /// Prefilled from the stored account when one was hand-entered (so a custom
  /// config round-trips), and empty otherwise.
  late final _host = TextEditingController(
    text: _hasCustomServer ? _settings.host : '',
  );
  late final _port = TextEditingController(
    text: _hasCustomServer ? '${_settings.port}' : '',
  );
  late bool _useSsl = _hasCustomServer ? _settings.useSsl : false;

  /// Always starts empty, even when a password is stored: it cannot be read
  /// back out of the secure store into a text field without putting it back in
  /// the widget tree, and there is no reason to. Empty on save means 「変更なし」.
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  /// The last 「テスト送信」 outcome, kept on screen rather than in a SnackBar
  /// that vanishes while the user is still reading it.
  SendResult? _testResult;

  /// Whether the stored account is a hand-entered server (a real host on a
  /// domain no preset covers) rather than a derived one.
  bool get _hasCustomServer =>
      _settings.host.trim().isNotEmpty &&
      smtpForEmail(_settings.fromAddress) == null;

  @override
  void dispose() {
    _from.dispose();
    _host.dispose();
    _port.dispose();
    _password.dispose();
    super.dispose();
  }

  /// The provider derived from the address, or null when the domain is unknown.
  SmtpProvider? get _provider => smtpForEmail(_from.text);

  /// Whether the 詳細設定 block is showing: a plausible address whose domain is
  /// not one of the presets.
  bool get _showAdvanced =>
      isEmailAddress(_from.text) && _provider == null;

  /// The form as it stands. The password is handled separately — it is never a
  /// field of [MailSettings].
  MailSettings get _formValue {
    final provider = _provider;
    if (provider != null) {
      return provider.toSettings().copyWith(
        passwordSaved: _settings.passwordSaved,
      );
    }
    // Unknown domain: the 詳細設定 fields carry the server, and the address is
    // both the login and the from.
    final address = _from.text.trim();
    return _settings.copyWith(
      presetId: MailPreset.customId,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? defaultSmtpPort,
      useSsl: _useSsl,
      fromAddress: address,
      username: address,
    );
  }

  /// What is missing, or null when nothing is. Drives the hint under 保存 and
  /// whether テスト送信 can be pressed.
  String? get _missing {
    if (!isEmailAddress(_from.text)) return 'メールアドレスを入力してください';
    if (_provider == null) {
      if (_host.text.trim().isEmpty) return 'SMTP サーバーを入力してください（詳細設定）';
      if ((int.tryParse(_port.text.trim()) ?? 0) <= 0) {
        return 'ポート番号を入力してください（詳細設定）';
      }
    }
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

  Future<void> _openAppPasswordPage(String url) async {
    final opened = await ref.read(mailUrlOpenerProvider)(Uri.parse(url));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ブラウザを開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = _missing;
    final provider = _provider;

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
            title: 'アカウント',
            children: [
              _field(
                keyName: 'mailFromField',
                controller: _from,
                label: 'メールアドレス',
                hint: '例：you@gmail.com、you@yahoo.co.jp',
                keyboardType: TextInputType.emailAddress,
              ),
              // What the domain was recognised as, or a nudge to 詳細設定.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: provider != null
                    ? Text(
                        '${provider.label} として送信します',
                        key: const ValueKey('mailProviderHint'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : isEmailAddress(_from.text)
                    ? Text(
                        'このドメインは自動設定に対応していません。'
                        '下の「詳細設定」でサーバーを入力してください。',
                        key: const ValueKey('mailUnknownDomainHint'),
                        style: theme.textTheme.bodySmall,
                      )
                    : const SizedBox.shrink(),
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
              if (provider?.appPasswordUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('mailAppPasswordButton'),
                      onPressed: () =>
                          _openAppPasswordPage(provider!.appPasswordUrl!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('アプリパスワードを取得'),
                    ),
                  ),
                ),
              if (provider?.note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    provider!.note!,
                    key: const ValueKey('mailProviderNote'),
                    style: theme.textTheme.bodySmall,
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
          if (_showAdvanced)
            SettingsIsland(
              title: '詳細設定',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'このドメインのSMTPサーバーを手動で入力します。'
                    'メール提供者の案内にある送信（SMTP）サーバー名とポートを入れてください。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                _field(
                  keyName: 'mailHostField',
                  controller: _host,
                  label: 'SMTP サーバー',
                  hint: '例：smtp.example.com',
                  keyboardType: TextInputType.url,
                ),
                _field(
                  keyName: 'mailPortField',
                  controller: _port,
                  label: 'ポート',
                  hint: '$defaultSmtpPort',
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                SettingSwitchRow(
                  key: const ValueKey('mailSslRow'),
                  label: 'SSL で接続する',
                  value: _useSsl,
                  subtitle: _useSsl
                      ? '最初から TLS で接続します（ポート $sslSmtpPort など）'
                      : 'STARTTLS で暗号化します（ポート $defaultSmtpPort など）。'
                            '暗号化できないサーバーには送りません',
                  onChanged: (v) => setState(() => _useSsl = v),
                ),
              ],
            ),
          if (missing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(
                missing,
                key: const ValueKey('mailMissingNote'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
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
          const _StorageNote(),
        ],
      ),
    );
  }

  Widget _field({
    required String keyName,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: TextField(
      key: ValueKey(keyName),
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      autocorrect: false,
      // The provider hint, the 詳細設定 block, the 保存 hint and the テスト送信
      // button all read the form, so every keystroke has to redraw them.
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

/// Where the app password lives, said plainly. Not a how-to any more — the
/// per-provider 「アプリパスワードを取得」 button links the page that walks the user
/// through it — just the one promise that matters.
class _StorageNote extends StatelessWidget {
  const _StorageNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsIsland(
      title: 'アプリパスワードの保管について',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'アプリパスワードは、この端末の暗号化された保管領域に保存されます。'
            'アプリの通常の設定ファイルには書き込まれず、ログにも出しません。'
            'ふだんお使いのログインパスワードではなく、'
            'メール提供者が発行する「アプリパスワード」を入力してください。',
            key: const ValueKey('mailStorageNote'),
            style: theme.textTheme.bodyMedium,
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
