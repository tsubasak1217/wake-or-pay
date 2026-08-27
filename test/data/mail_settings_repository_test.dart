import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_or_pay/data/repositories/mail_settings_repository.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/secret_store.dart';

const secret = 'abcd efgh ijkl mnop';

Future<({MailSettingsRepository repo, SharedPreferences prefs,
    InMemorySecretStore secrets})> open([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues({...initial});
  final prefs = await SharedPreferences.getInstance();
  final secrets = InMemorySecretStore();
  return (
    repo: MailSettingsRepository(prefs, secrets),
    prefs: prefs,
    secrets: secrets,
  );
}

const filled = MailSettings(
  presetId: 'gmail',
  host: '  smtp.gmail.com  ',
  fromAddress: ' me@gmail.com ',
  username: ' me@gmail.com ',
);

void main() {
  test('an empty store reads as an unconfigured account', () async {
    final s = (await open()).repo.read();
    expect(s.isConfigured, isFalse);
    expect(s.presetId, MailPreset.customId);
    expect(s.port, defaultSmtpPort);
    expect(s.passwordSaved, isFalse);
  });

  test('a round trip keeps the fields and trims them', () async {
    final o = await open();
    final saved = await o.repo.write(filled, password: secret);

    expect(saved.host, 'smtp.gmail.com');
    expect(saved.fromAddress, 'me@gmail.com');
    expect(saved.username, 'me@gmail.com');
    expect(saved.presetId, 'gmail');
    expect(saved.passwordSaved, isTrue);
    expect(saved.isConfigured, isTrue);
    expect(await o.repo.password(), secret);
    expect(o.repo.read(), saved, reason: 'a fresh read agrees with the write');
  });

  test('the app password is never written to the ordinary settings store',
      () async {
    final o = await open();
    await o.repo.write(filled, password: secret);

    // Every value prefs holds, whatever its type, flattened to a string.
    final stored = [
      for (final key in o.prefs.getKeys()) '$key=${o.prefs.get(key)}',
    ].join('\n');

    expect(
      stored,
      isNot(contains(secret)),
      reason: 'prefs is a plain XML file that any backup carries off',
    );
    expect(
      stored,
      isNot(contains('abcd')),
      reason: 'not even a fragment of it',
    );
    expect(
      o.prefs.getKeys().where((k) => k.toLowerCase().contains('password')),
      ['mail.passwordSaved'],
      reason: 'the only password-shaped key in prefs is the bool flag',
    );
    expect(o.prefs.get('mail.passwordSaved'), isTrue);

    // And it really is in the secure store, under a key of its own.
    expect(
      o.secrets.values[MailSettingsRepository.passwordSecretKey],
      secret,
    );
  });

  test('an empty password on save leaves the stored one alone', () async {
    final o = await open();
    await o.repo.write(filled, password: secret);

    final again = await o.repo.write(
      filled.copyWith(username: 'someone.else'),
    );
    expect(again.username, 'someone.else');
    expect(again.passwordSaved, isTrue);
    expect(await o.repo.password(), secret);
  });

  test('clearing the password takes the flag down with it', () async {
    final o = await open();
    await o.repo.write(filled, password: secret);

    final cleared = await o.repo.write(filled, clearPassword: true);
    expect(cleared.passwordSaved, isFalse);
    expect(cleared.isConfigured, isFalse);
    expect(await o.repo.password(), isNull);
    expect(o.secrets.values, isEmpty);
  });

  test('a keystore that refuses the write does not claim a password', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = MailSettingsRepository(prefs, _RefusingStore());

    final saved = await repo.write(filled, password: secret);
    expect(
      saved.passwordSaved,
      isFalse,
      reason: 'better to be told the setting is incomplete now than at 7am',
    );
    expect(saved.isConfigured, isFalse);
  });

  test('passwordSaved on the way in is ignored; the store decides', () async {
    final o = await open();
    final saved = await o.repo.write(filled.copyWith(passwordSaved: true));
    expect(saved.passwordSaved, isFalse);
  });
}

/// What a keystore looks like when it is unavailable: the write is swallowed,
/// and nothing is there afterwards. See [FlutterSecureStore].
class _RefusingStore implements SecretStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}
