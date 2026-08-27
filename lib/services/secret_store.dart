import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where secrets go. Today that is exactly one value: the SMTP app password.
///
/// An interface for two reasons. Tests must never touch the platform keystore
/// — there is no plugin under a `flutter test` — and, more to the point, the
/// test that matters here is the one that proves the password did **not** end
/// up in shared_preferences, which needs a store it can look inside.
abstract class SecretStore {
  /// null when nothing is stored under [key], and also when the platform
  /// refused to answer — see [FlutterSecureStore].
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The real one, on the Android keystore via `flutter_secure_storage`.
///
/// Every failure is swallowed into null / a no-op rather than thrown. The
/// keystore is not always available — a device mid-upgrade, a backup restored
/// onto different hardware — and the consequence of a failed read here is that
/// mail cannot be sent, which the caller already reports. It is never a reason
/// for the profile screen to crash.
class FlutterSecureStore implements SecretStore {
  const FlutterSecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  /// The package's own defaults, which since 11.0 are already the strong ones
  /// on Android: values are AES-GCM encrypted under a key wrapped by the
  /// platform keystore, in a file of the plugin's own — not the app's
  /// shared_preferences XML. There is no weaker mode left to opt out of.
  static const _android = AndroidOptions();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key, aOptions: _android);
    } on Object catch (e) {
      debugPrint('secure read failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value, aOptions: _android);
    } on Object catch (e) {
      debugPrint('secure write failed: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key, aOptions: _android);
    } on Object catch (e) {
      debugPrint('secure delete failed: $e');
    }
  }
}

/// Holds secrets in memory for the length of one process. The default, so a
/// test that forgets to override still cannot reach a keystore.
class InMemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Overridden in `main()` with [FlutterSecureStore]; everywhere else it is the
/// in-memory one.
final secretStoreProvider = Provider<SecretStore>(
  (ref) => InMemorySecretStore(),
);

Override flutterSecureStoreOverride() =>
    secretStoreProvider.overrideWithValue(const FlutterSecureStore());
