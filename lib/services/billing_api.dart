import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'discord_exchange.dart';
import 'discord_sender.dart';

/// The Worker's `/v1/**` half — 端末登録 and カード人質.
///
/// The **same** Worker the Discord exchange already talks to, so there is one
/// deployment and one URL: see `kDiscordExchangeEndpoint`, and
/// `docs/BILLING_API.md` for the contract both sides follow.
const kBillingEndpoint = kDiscordExchangeEndpoint;

const kDevicesRegisterPath = '/v1/devices/register';
const kSetupIntentPath = '/v1/billing/setup-intent';
const kCardConfirmPath = '/v1/billing/card/confirm';
const kCardPath = '/v1/billing/card';

/// How long the Worker is given. It makes Stripe calls of its own behind each
/// of these, and a user is watching a spinner the whole time.
const billingTimeout = Duration(seconds: 25);

/// Everything this layer can fail with, carrying the Worker's own snake_case
/// code so the caller can act on `unauthorized` specifically.
///
/// [status] is the HTTP status, or 0 when the request never got an answer at
/// all — offline, DNS, a timeout — under the code `network`.
@immutable
class BillingApiException implements Exception {
  const BillingApiException(this.code, this.status);

  final String code;
  final int status;

  /// The one code with a recovery: the device token is gone or was replaced,
  /// and re-registering the same installId gets a new one.
  bool get isUnauthorized => code == 'unauthorized';

  @override
  String toString() => 'BillingApiException($code, $status)';
}

/// What `/v1/billing/setup-intent` hands back — everything PaymentSheet needs
/// and nothing that could charge anybody.
@immutable
class SetupIntentSession {
  const SetupIntentSession({
    required this.customerId,
    required this.ephemeralKeySecret,
    required this.setupIntentClientSecret,
    required this.publishableKey,
  });

  final String customerId;
  final String ephemeralKeySecret;
  final String setupIntentClientSecret;

  /// The Worker's own `pk_…`, for checking it against the app's constant. The
  /// app uses its own — see `lib/services/stripe_config.dart`.
  final String publishableKey;

  static SetupIntentSession? fromJson(Object? json) {
    if (json is! Map) return null;
    String field(String key) => (json[key] as String?)?.trim() ?? '';
    final secret = field('setupIntentClientSecret');
    if (secret.isEmpty) return null;
    return SetupIntentSession(
      customerId: field('customerId'),
      ephemeralKeySecret: field('ephemeralKeySecret'),
      setupIntentClientSecret: secret,
      publishableKey: field('publishableKey'),
    );
  }
}

/// The five calls, behind an interface so a test never reaches the Worker.
abstract class BillingApi {
  /// Trades an installId for a device token. Called again with the same
  /// installId when the token is lost — the Worker issues a new one and keeps
  /// the Stripe Customer.
  Future<String> register(
    String installId, {
    required String platform,
    required String appVersion,
  });

  Future<SetupIntentSession> createSetupIntent(
    String token,
    CardHostageConsent consent,
  );

  Future<HostageCard> confirmCard(String token, String setupIntentId);

  Future<({HostageCard? card, CardHostageConsent? consent})> card(String token);

  Future<void> removeCard(String token);
}

/// The real one, over `package:http`.
class HttpBillingApi implements BillingApi {
  const HttpBillingApi(this._client, {this.baseUrl = kBillingEndpoint});

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers(String? token) => {
    'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  };

  /// One request, with every failure already collapsed into a
  /// [BillingApiException] and every success already decoded.
  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    final http.Response response;
    try {
      final uri = _uri(path);
      final headers = _headers(token);
      final encoded = body == null ? null : jsonEncode(body);
      final pending = switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      };
      response = await pending.timeout(billingTimeout);
    } on Object {
      // Offline, DNS, a timeout, a TLS refusal — all the same to the caller,
      // and none of them a reason to throw a raw platform error at the UI.
      throw const BillingApiException('network', 0);
    }

    // bodyBytes, not body: `http` falls back to latin-1 without a charset, and
    // a Worker error message in Japanese would come back as mojibake.
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded is Map ? decoded['error'] : null;
      throw BillingApiException(
        code is String && code.isNotEmpty
            ? code
            // A 401 with no body is still an unauthorized, and the retry path
            // hangs off exactly that.
            : response.statusCode == 401
            ? 'unauthorized'
            : 'server_error',
        response.statusCode,
      );
    }

    return decoded is Map ? Map<String, Object?>.from(decoded) : {};
  }

  @override
  Future<String> register(
    String installId, {
    required String platform,
    required String appVersion,
  }) async {
    final json = await _send(
      'POST',
      kDevicesRegisterPath,
      body: {
        'installId': installId,
        'platform': platform,
        'appVersion': appVersion,
      },
    );
    final token = (json['deviceToken'] as String?)?.trim() ?? '';
    if (token.isEmpty) throw const BillingApiException('bad_response', 200);
    return token;
  }

  @override
  Future<SetupIntentSession> createSetupIntent(
    String token,
    CardHostageConsent consent,
  ) async {
    final json = await _send(
      'POST',
      kSetupIntentPath,
      token: token,
      body: {'consent': consent.toJson()},
    );
    final session = SetupIntentSession.fromJson(json);
    if (session == null) throw const BillingApiException('bad_response', 200);
    return session;
  }

  @override
  Future<HostageCard> confirmCard(String token, String setupIntentId) async {
    final json = await _send(
      'POST',
      kCardConfirmPath,
      token: token,
      body: {'setupIntentId': setupIntentId},
    );
    final card = HostageCard.fromJson(json['card']);
    if (card == null) throw const BillingApiException('bad_response', 200);
    return card;
  }

  @override
  Future<({HostageCard? card, CardHostageConsent? consent})> card(
    String token,
  ) async {
    final json = await _send('GET', kCardPath, token: token);
    return (
      card: HostageCard.fromJson(json['card']),
      consent: CardHostageConsent.fromJson(json['consent']),
    );
  }

  @override
  Future<void> removeCard(String token) async {
    await _send('DELETE', kCardPath, token: token);
  }
}

/// Overridable in tests with a fake; the real one everywhere else.
final billingApiProvider = Provider<BillingApi>(
  (ref) => HttpBillingApi(ref.watch(httpClientProvider)),
);
