import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';
import '../../services/secret_store.dart';

/// メール送信設定, split across two stores on purpose.
///
/// The server fields sit in shared_preferences beside the profile, because the
/// メール toggle is drawn from them on a frame that cannot wait for a future.
/// The **app password never goes there**: prefs is a plain XML file that any
/// backup, any `adb backup`, and any log dump of the settings map would carry
/// off. It lives in [SecretStore] and is read only at the moment a mail is
/// actually sent.
///
/// The one thing prefs learns about the password is [MailSettings.passwordSaved]
/// — a bool, written after the secret store has taken it.
class MailSettingsRepository {
  MailSettingsRepository(this._prefs, this._secrets);

  static const _presetKey = 'mail.presetId';
  static const _hostKey = 'mail.host';
  static const _portKey = 'mail.port';
  static const _sslKey = 'mail.useSsl';
  static const _fromKey = 'mail.fromAddress';
  static const _usernameKey = 'mail.username';
  static const _passwordSavedKey = 'mail.passwordSaved';

  /// The key inside the **secure** store. Not a prefs key, and deliberately
  /// not near the ones above.
  static const passwordSecretKey = 'mail.appPassword';

  final SharedPreferences _prefs;
  final SecretStore _secrets;

  MailSettings read() => MailSettings(
    presetId: _prefs.getString(_presetKey) ?? MailPreset.customId,
    host: _prefs.getString(_hostKey) ?? '',
    port: _prefs.getInt(_portKey) ?? defaultSmtpPort,
    useSsl: _prefs.getBool(_sslKey) ?? false,
    fromAddress: _prefs.getString(_fromKey) ?? '',
    username: _prefs.getString(_usernameKey) ?? '',
    passwordSaved: _prefs.getBool(_passwordSavedKey) ?? false,
  );

  /// Stores [settings], and [password] when one was typed.
  ///
  /// A null [password] means 「触っていない」 — the field on the screen starts
  /// empty even when a password is stored, because it is masked and cannot be
  /// shown, so an empty field must mean "leave it" rather than "delete it".
  /// [clearPassword] is the explicit way to delete it.
  ///
  /// [MailSettings.passwordSaved] on the way in is ignored: what is actually in
  /// the secret store decides it, so the flag can never claim a password that
  /// was never written.
  Future<MailSettings> write(
    MailSettings settings, {
    String? password,
    bool clearPassword = false,
  }) async {
    if (clearPassword) {
      await _secrets.delete(passwordSecretKey);
    } else if (password != null && password.isNotEmpty) {
      await _secrets.write(passwordSecretKey, password);
    }
    // Read back rather than assumed: a keystore that refused the write leaves
    // this false, and the user is told the setting is incomplete instead of
    // finding out at 7am that it was.
    final saved = (await _secrets.read(passwordSecretKey)) != null;

    await _prefs.setString(_presetKey, settings.presetId);
    await _prefs.setString(_hostKey, settings.host.trim());
    await _prefs.setInt(_portKey, settings.port);
    await _prefs.setBool(_sslKey, settings.useSsl);
    await _prefs.setString(_fromKey, settings.fromAddress.trim());
    await _prefs.setString(_usernameKey, settings.username.trim());
    await _prefs.setBool(_passwordSavedKey, saved);

    return read();
  }

  /// The app password, or null when there is none. Read at send time and never
  /// held: nothing in this app keeps it in a field.
  Future<String?> password() async {
    final value = await _secrets.read(passwordSecretKey);
    return (value ?? '').isEmpty ? null : value;
  }
}
