import 'package:flutter/foundation.dart';

/// カード人質 — the card the user hands over as the hostage behind 覚悟.
///
/// Phase 1 only registers it. Nothing here charges anything: see
/// `docs/BILLING_API.md`, which is the contract this app and the Worker both
/// follow. The card number itself never reaches this device — Stripe's
/// PaymentSheet takes it, and only these four public fields come back.

/// The mandate the user ticks before a card can be registered.
///
/// The exact sentence matters: it is what is stored, versioned and shown back,
/// and it is the whole of what the user agreed to. Changing the wording means
/// bumping [cardHostageConsentVersion] and asking again.
const cardHostageMandateText =
    'Wake or Pay が、寝坊で確定した金額を毎月末にこのカードへ請求することに同意します。'
    '金額は各アラームの上限金額を超えません。いつでも解除できます。';

/// The version of [cardHostageMandateText] currently in force.
const cardHostageConsentVersion = 1;

/// What the app knows about the registered card. Four public fields, and no
/// way back to a card number from any of them.
@immutable
class HostageCard {
  const HostageCard({
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  /// Stripe's own spelling — `visa`, `mastercard`, `amex`. Lower case on the
  /// wire; [label] is what a person reads.
  final String brand;

  final String last4;
  final int expMonth;
  final int expYear;

  /// 「VISA •••• 4242」. What the profile row and the screen both show.
  String get label => '${brand.toUpperCase()} •••• $last4';

  /// 「12/30」. The two-digit year Stripe prints on the card itself.
  String get expiry =>
      '${expMonth.toString().padLeft(2, '0')}/'
      '${(expYear % 100).toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'brand': brand,
    'last4': last4,
    'expMonth': expMonth,
    'expYear': expYear,
  };

  /// Null for anything that is not a card — a truncated prefs value, a Worker
  /// answering `{"card": null}`, a shape from a future version. A profile row
  /// that cannot be drawn is 「なし」, never a crash.
  static HostageCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final brand = json['brand'];
    final last4 = json['last4'];
    final expMonth = json['expMonth'];
    final expYear = json['expYear'];
    if (brand is! String || last4 is! String) return null;
    if (expMonth is! int || expYear is! int) return null;
    if (brand.isEmpty || last4.isEmpty) return null;
    return HostageCard(
      brand: brand,
      last4: last4,
      expMonth: expMonth,
      expYear: expYear,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HostageCard &&
      other.brand == brand &&
      other.last4 == last4 &&
      other.expMonth == expMonth &&
      other.expYear == expYear;

  @override
  int get hashCode => Object.hash(brand, last4, expMonth, expYear);

  @override
  String toString() => 'HostageCard($label $expiry)';
}

/// The mandate the user accepted, and when.
@immutable
class CardHostageConsent {
  const CardHostageConsent({required this.version, required this.acceptedAt});

  final int version;
  final DateTime acceptedAt;

  /// Whether this consent is for the mandate text the app shows today.
  bool get isCurrent => version == cardHostageConsentVersion;

  Map<String, Object?> toJson() => {
    'version': version,
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
  };

  static CardHostageConsent? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final acceptedAt = json['acceptedAt'];
    if (version is! int || acceptedAt is! String) return null;
    final at = DateTime.tryParse(acceptedAt);
    if (at == null) return null;
    return CardHostageConsent(version: version, acceptedAt: at);
  }

  @override
  bool operator ==(Object other) =>
      other is CardHostageConsent &&
      other.version == version &&
      other.acceptedAt.isAtSameMomentAs(acceptedAt);

  @override
  int get hashCode => Object.hash(version, acceptedAt.toUtc());

  @override
  String toString() => 'CardHostageConsent(v$version, $acceptedAt)';
}
