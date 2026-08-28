import 'package:flutter/foundation.dart';

import 'oversleep_contact.dart';

/// The SMTP account the app sends the oversleep mail **from**, per spec 11.5.
///
/// The user's own account, not a service of ours: the mail arrives from them,
/// to the person they picked, with nothing in between. The price of that is
/// that they have to hand the app an app password, which is why it is the one
/// value in this app that never goes near shared_preferences — see
/// `MailSettingsRepository`.
///
/// The password is **not a field here**. This object is written to prefs, read
/// back on every frame that draws the メール toggle, and printed in a `toString`
/// that could end up in a log; a secret in it would leak by all three routes.
/// [passwordSaved] is the only trace of it: whether one has been stored.
@immutable
class MailSettings {
  const MailSettings({
    this.presetId = MailPreset.customId,
    this.host = '',
    this.port = defaultSmtpPort,
    this.useSsl = false,
    this.fromAddress = '',
    this.username = '',
    this.passwordSaved = false,
  });

  /// Which row of [MailPreset.all] the user picked. Kept so reopening the
  /// screen shows 「Gmail」 rather than re-deriving it from the host, which
  /// would guess wrong the moment two presets share one.
  final String presetId;

  final String host;
  final int port;

  /// True connects over TLS from the first byte (the 465 style). False opens a
  /// plain socket and upgrades it with `STARTTLS` (the 587 style) — which is
  /// still encrypted, and is what every preset here uses.
  ///
  /// It is never "no encryption": `SmtpServer.allowInsecure` stays false, so a
  /// server that offers neither is refused rather than sent a password in the
  /// clear.
  final bool useSsl;

  /// The address the mail is *from*. Also where 「テスト送信」 goes.
  final String fromAddress;

  /// The SMTP login. Usually the same as [fromAddress] — the screen prefills
  /// it — but not always: some providers want a bare account name.
  final String username;

  /// Whether an app password has been stored in the secure store.
  ///
  /// A flag rather than the secret, so [isConfigured] can be answered
  /// synchronously while a widget builds. It can in principle disagree with
  /// the secure store — an OS that wiped the keystore leaves this true — in
  /// which case sending fails with 「アプリパスワードが保存されていません」 rather than
  /// silently doing nothing.
  final bool passwordSaved;

  /// Whether the app has everything it needs to actually send.
  ///
  /// The gate behind every メール control in the app: the toggle on 寝坊時の連絡
  /// 設定, the row in the profile, and the dispatcher's decision to try.
  bool get isConfigured =>
      host.trim().isNotEmpty &&
      port > 0 &&
      isEmailAddress(fromAddress) &&
      username.trim().isNotEmpty &&
      passwordSaved;

  MailSettings copyWith({
    String? presetId,
    String? host,
    int? port,
    bool? useSsl,
    String? fromAddress,
    String? username,
    bool? passwordSaved,
  }) => MailSettings(
    presetId: presetId ?? this.presetId,
    host: host ?? this.host,
    port: port ?? this.port,
    useSsl: useSsl ?? this.useSsl,
    fromAddress: fromAddress ?? this.fromAddress,
    username: username ?? this.username,
    passwordSaved: passwordSaved ?? this.passwordSaved,
  );

  @override
  bool operator ==(Object other) =>
      other is MailSettings &&
      other.presetId == presetId &&
      other.host == host &&
      other.port == port &&
      other.useSsl == useSsl &&
      other.fromAddress == fromAddress &&
      other.username == username &&
      other.passwordSaved == passwordSaved;

  @override
  int get hashCode => Object.hash(
    presetId,
    host,
    port,
    useSsl,
    fromAddress,
    username,
    passwordSaved,
  );

  /// Deliberately says nothing about the password beyond whether one exists.
  @override
  String toString() =>
      'MailSettings($presetId, $host:$port, ssl $useSsl, from $fromAddress, '
      'user $username, password ${passwordSaved ? 'saved' : 'none'})';
}

/// The submission port. 465 is the implicit-TLS one; this is the STARTTLS one
/// every preset below uses.
const defaultSmtpPort = 587;

const sslSmtpPort = 465;

/// One row of the プリセット picker: a provider whose SMTP settings are fixed
/// and known, so the user only has to supply their address and app password.
@immutable
class MailPreset {
  const MailPreset({
    required this.id,
    required this.label,
    required this.host,
    this.port = defaultSmtpPort,
    this.useSsl = false,
    this.note,
  });

  final String id;
  final String label;
  final String host;
  final int port;
  final bool useSsl;

  /// A line under the row, when the provider needs something said about it.
  final String? note;

  /// The id of the 「カスタム」 row — the one where the fields are typed by hand.
  static const customId = 'custom';

  static const gmail = MailPreset(
    id: 'gmail',
    label: 'Gmail',
    host: 'smtp.gmail.com',
    note: '2段階認証を有効にして「アプリパスワード」を作ってください。',
  );

  static const outlook = MailPreset(
    id: 'outlook',
    label: 'Outlook',
    host: 'smtp-mail.outlook.com',
    note: 'Microsoft アカウントのアプリパスワードが必要です。',
  );

  static const icloud = MailPreset(
    id: 'icloud',
    label: 'iCloud',
    host: 'smtp.mail.me.com',
    note: 'Apple ID の「App用パスワード」が必要です。',
  );

  static const custom = MailPreset(
    id: customId,
    label: 'カスタム',
    host: '',
    note: 'ホスト・ポート・暗号化を自分で入力します。',
  );

  static const all = [gmail, outlook, icloud, custom];

  /// The preset with [id], or [custom] for anything unknown — including a row
  /// written by a future version of the app.
  static MailPreset byId(String? id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return custom;
  }
}

/// [settings] with [preset]'s server fields written in. Pure.
///
/// The address and the login are the user's and survive a preset change: the
/// picker changes *where* the mail goes out through, never *who* it is from.
/// Picking カスタム leaves the current host and port alone too — it unlocks the
/// fields rather than blanking what is in them.
MailSettings applyMailPreset(MailSettings settings, MailPreset preset) =>
    preset.id == MailPreset.customId
    ? settings.copyWith(presetId: preset.id)
    : settings.copyWith(
        presetId: preset.id,
        host: preset.host,
        port: preset.port,
        useSsl: preset.useSsl,
      );

/// Whether [value] looks like an address this app can send to or from. Pure.
///
/// Deliberately loose. The authority on whether an address exists is the SMTP
/// server that refuses it, and a regex strict enough to be interesting rejects
/// valid addresses; all this stops is an empty field and an obvious typo.
bool isEmailAddress(String value) {
  final trimmed = value.trim();
  final at = trimmed.indexOf('@');
  if (at <= 0 || at != trimmed.lastIndexOf('@')) return false;
  final domain = trimmed.substring(at + 1);
  return domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.') &&
      !trimmed.contains(' ');
}

/// The SMTP account a known provider fixes, derived from an address's domain.
///
/// The common case of メール送信設定: the user types their address and their
/// app password, and everything else — the server, the port, the encryption,
/// the login — is known from the domain. [smtpForEmail] returns one of these,
/// or null for a domain the app does not recognise, which is where 詳細設定
/// takes over.
@immutable
class SmtpProvider {
  const SmtpProvider({
    required this.label,
    required this.host,
    required this.username,
    required this.fromAddress,
    this.port = defaultSmtpPort,
    this.useSsl = false,
    this.appPasswordUrl,
  });

  /// The name shown to the user (「Gmail」「Outlook」…). Also stored as the
  /// [MailSettings.presetId] so a reopened screen has a label to show.
  final String label;

  final String host;
  final int port;
  final bool useSsl;

  /// The SMTP login — the full address for every provider here.
  final String username;

  /// Where the mail is sent from — the full address, the same string the user
  /// typed.
  final String fromAddress;

  /// The page where this provider hands out app passwords, when it has one.
  /// Null for providers that bury it somewhere unlinkable.
  final String? appPasswordUrl;

  /// The [MailSettings] this provider and the typed [password] state describe.
  MailSettings toSettings() => MailSettings(
    presetId: label,
    host: host,
    port: port,
    useSsl: useSsl,
    fromAddress: fromAddress,
    username: username,
  );
}

/// The SMTP configuration for [email]'s domain, or null when the domain is one
/// the app does not know. Pure.
///
/// Case-insensitive on the domain and tolerant of surrounding whitespace; a
/// string with no single '@' is not an address and returns null. [username]
/// and [fromAddress] are the whole (trimmed) address, because every provider
/// here logs in as the address it sends from.
SmtpProvider? smtpForEmail(String email) {
  final trimmed = email.trim();
  final at = trimmed.indexOf('@');
  if (at <= 0 || at != trimmed.lastIndexOf('@')) return null;
  final address = trimmed;
  final domain = trimmed.substring(at + 1).toLowerCase();

  SmtpProvider make(
    String label,
    String host, {
    String? appPasswordUrl,
  }) => SmtpProvider(
    label: label,
    host: host,
    username: address,
    fromAddress: address,
    appPasswordUrl: appPasswordUrl,
  );

  switch (domain) {
    case 'gmail.com':
    case 'googlemail.com':
      return make(
        'Gmail',
        'smtp.gmail.com',
        appPasswordUrl: 'https://myaccount.google.com/apppasswords',
      );
    case 'outlook.com':
    case 'hotmail.com':
    case 'live.com':
    case 'live.jp':
    case 'msn.com':
      return make('Outlook', 'smtp-mail.outlook.com');
    case 'icloud.com':
    case 'me.com':
    case 'mac.com':
      return make(
        'iCloud',
        'smtp.mail.me.com',
        appPasswordUrl: 'https://account.apple.com',
      );
    case 'yahoo.com':
    case 'ymail.com':
      return make('Yahoo', 'smtp.mail.yahoo.com');
    case 'yahoo.co.jp':
      return make('Yahoo! JP', 'smtp.mail.yahoo.co.jp');
    default:
      return null;
  }
}

/// The subject line of every oversleep mail, per spec 11.5.
const oversleepMailSubject = '【Wake or Pay】寝坊のお知らせ';

/// The subject of the 「テスト送信」 mail, which goes to the user themselves.
const mailTestSubject = '【Wake or Pay】テスト送信';

/// The body of the test mail. Says what it is, so an inbox six months later
/// still explains itself.
String mailTestBody(MailSettings settings) =>
    'Wake or Pay のメール送信設定のテストです。\n'
    'このメールが届いていれば、寝坊したときに '
    '${settings.fromAddress} から連絡先へお知らせが送られます。\n'
    '\n'
    'サーバー：${settings.host}:${settings.port}'
    '（${settings.useSsl ? 'SSL' : 'STARTTLS'}）';

/// The whole mail sent to one contact about one overslept alarm. Pure.
///
/// [at] is the alarm's own time, filled in at trigger time; [userName] is the
/// app's user, who is the *subject* of the sentence and not its recipient. The
/// body is the same one the SMS carries when the user wrote their own — see
/// [oversleepMailBodyFor].
({String to, String subject, String body}) buildOversleepMail(
  OversleepContact contact,
  DateTime at, {
  required String userName,
}) => (
  to: (contact.email ?? '').trim(),
  subject: oversleepMailSubject,
  body: oversleepMailBodyFor(contact, at, userName: userName),
);
