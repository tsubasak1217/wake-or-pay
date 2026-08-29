import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/models.dart';
import 'billing_api.dart';
import 'card_sheet.dart';
import 'secret_store.dart';

/// Where the two device secrets live. The secure store and nowhere else — a
/// device token is a bearer credential for this device's Stripe customer.
const kInstallIdSecretKey = 'billing.installId';
const kDeviceTokenSecretKey = 'billing.deviceToken';

/// Where the *public* half is cached, so the profile row can be drawn on the
/// first frame without a round trip. Brand, last4 and expiry only — the same
/// four fields the Worker holds.
const kCardPrefsKey = 'billing.card';
const kConsentPrefsKey = 'billing.consent';

/// What `/v1/devices/register` is told this build is. Mirrors `pubspec.yaml`;
/// the Worker only logs it.
const kBillingAppVersion = '1.0.0+1';

/// The registered card as this app knows it.
@immutable
class CardHostageState {
  const CardHostageState({
    this.card,
    this.consent,
    this.loading = false,
    this.error,
  });

  static const empty = CardHostageState();

  final HostageCard? card;
  final CardHostageConsent? consent;

  /// A call is in the air — the button is disabled and a spinner is up.
  final bool loading;

  /// The last failure, in Japanese, or null. Cleared at the start of every
  /// attempt: an error from ten minutes ago must not sit under a fresh one.
  final String? error;

  bool get enrolled => card != null;

  /// [error] is **not** carried over: omitting it clears the last failure,
  /// which is what every caller wants — a new attempt starts clean, and the
  /// only way to show an error is to pass one.
  CardHostageState copyWith({bool? loading, String? error}) =>
      CardHostageState(
        card: card,
        consent: consent,
        loading: loading ?? this.loading,
        error: error,
      );

  @override
  bool operator ==(Object other) =>
      other is CardHostageState &&
      other.card == card &&
      other.consent == consent &&
      other.loading == loading &&
      other.error == error;

  @override
  int get hashCode => Object.hash(card, consent, loading, error);
}

/// カード人質 — register a card, look at it, take it back.
///
/// Phase 1 charges nothing. See `docs/BILLING_API.md`: this drives
/// `/v1/devices/register`, `/v1/billing/setup-intent`,
/// `/v1/billing/card/confirm` and `DELETE /v1/billing/card`, with Stripe's
/// PaymentSheet in the middle so the card number never reaches this process.
class CardHostageService extends Notifier<CardHostageState> {
  @override
  CardHostageState build() {
    // Synchronous, off prefs, so the profile row has an answer on the first
    // frame. The network copy arrives later through [refresh] if anybody asks.
    final prefs = ref.watch(sharedPreferencesProvider);
    return CardHostageState(
      card: HostageCard.fromJson(_decode(prefs.getString(kCardPrefsKey))),
      consent: CardHostageConsent.fromJson(
        _decode(prefs.getString(kConsentPrefsKey)),
      ),
    );
  }

  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  BillingApi get _api => ref.read(billingApiProvider);
  SecretStore get _secrets => ref.read(secretStoreProvider);

  /// The installId, generated once and kept for the life of the install.
  ///
  /// The Worker keys the Stripe Customer off this, so losing it means losing
  /// the card — which is why it is written before the first register call and
  /// never rewritten.
  Future<String> installId() async {
    final existing = (await _secrets.read(kInstallIdSecretKey))?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = newUuidV4();
    await _secrets.write(kInstallIdSecretKey, fresh);
    return fresh;
  }

  /// The device token, registering for one when there is none.
  Future<String> ensureRegistered({bool force = false}) async {
    if (!force) {
      final existing = (await _secrets.read(kDeviceTokenSecretKey))?.trim();
      if (existing != null && existing.isNotEmpty) return existing;
    }
    final token = await _api.register(
      await installId(),
      platform: defaultTargetPlatform.name,
      appVersion: kBillingAppVersion,
    );
    await _secrets.write(kDeviceTokenSecretKey, token);
    return token;
  }

  /// Runs [call] with a device token, and exactly once more with a fresh one
  /// if the Worker says the token is no good.
  ///
  /// The recovery path the contract asks for: registering the same installId
  /// again issues a new token and keeps the Customer. Once, not in a loop — a
  /// Worker answering 401 to everything must fail rather than spin.
  Future<T> _authorized<T>(Future<T> Function(String token) call) async {
    final token = await ensureRegistered();
    try {
      return await call(token);
    } on BillingApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      return call(await ensureRegistered(force: true));
    }
  }

  /// Re-reads the card from the Worker. Quiet about failure: this runs when a
  /// screen opens, and a network blip must not paint an error over a card the
  /// user registered last week.
  Future<void> refresh() async {
    try {
      final answer = await _authorized(_api.card);
      await _store(card: answer.card, consent: answer.consent);
    } on BillingApiException {
      // Keep whatever prefs had.
    }
  }

  /// The whole registration: register → setup-intent → sheet → confirm.
  ///
  /// [consentedAt] is when the user ticked the mandate; the Worker keeps it as
  /// the record of what was agreed to.
  Future<void> enroll({DateTime? consentedAt}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true);

    final consent = CardHostageConsent(
      version: cardHostageConsentVersion,
      acceptedAt: consentedAt ?? ref.read(clockProvider)(),
    );

    try {
      final session = await _authorized(
        (token) => _api.createSetupIntent(token, consent),
      );
      final result = await ref.read(cardSheetProvider).present(session);

      switch (result.status) {
        case CardSheetStatus.cancelled:
          // Backing out is not a failure. No error, no card, no confirm call.
          state = state.copyWith(loading: false);
        case CardSheetStatus.failed:
          state = state.copyWith(
            loading: false,
            error: result.message ?? 'カードを登録できませんでした',
          );
        case CardSheetStatus.completed:
          final card = await _authorized(
            (token) => _api.confirmCard(token, result.setupIntentId!),
          );
          await _store(card: card, consent: consent);
      }
    } on BillingApiException catch (e) {
      state = state.copyWith(loading: false, error: _messageFor(e));
    }
  }

  /// カード人質の解除. The consent stays on the Worker as history; the card does
  /// not.
  Future<void> remove() async {
    if (state.loading) return;
    state = state.copyWith(loading: true);
    try {
      await _authorized((token) => _api.removeCard(token));
      await _store(card: null, consent: null);
    } on BillingApiException catch (e) {
      state = state.copyWith(loading: false, error: _messageFor(e));
    }
  }

  /// Writes both halves of the answer — prefs and state — so the row a user
  /// comes back to is the row they left.
  Future<void> _store({
    required HostageCard? card,
    required CardHostageConsent? consent,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (card == null) {
      await prefs.remove(kCardPrefsKey);
    } else {
      await prefs.setString(kCardPrefsKey, jsonEncode(card.toJson()));
    }
    if (consent == null) {
      await prefs.remove(kConsentPrefsKey);
    } else {
      await prefs.setString(kConsentPrefsKey, jsonEncode(consent.toJson()));
    }
    state = CardHostageState(card: card, consent: consent);
  }

  static String _messageFor(BillingApiException e) => switch (e.code) {
    'network' => 'ネットワークにつながりませんでした。通信できるところでもう一度お試しください。',
    'unauthorized' => 'この端末の登録が切れていました。もう一度お試しください。',
    'setup_not_succeeded' => 'カードの確認が完了しませんでした。もう一度お試しください。',
    'wrong_customer' => 'カードの確認に失敗しました。もう一度お試しください。',
    'bad_install_id' => 'この端末を登録できませんでした。',
    _ => 'カードを登録できませんでした（${e.code}）',
  };
}

/// A UUID v4 out of `Random.secure`. No package for sixteen bytes.
///
/// Version and variant bits set as RFC 4122 requires — the Worker rejects an
/// installId that is not a UUID, and it checks the shape.
String newUuidV4([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  String hex(int from, int to) => [
    for (var i = from; i < to; i++) bytes[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// The one カード人質 state the app reads. Defaults to the real Worker and the
/// real card sheet; both are overridden in tests through
/// [billingApiProvider] / [cardSheetProvider].
final cardHostageProvider =
    NotifierProvider<CardHostageService, CardHostageState>(
      CardHostageService.new,
    );
