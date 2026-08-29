import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'billing_api.dart';
import 'stripe_config.dart';

/// How a card sheet ended.
enum CardSheetStatus {
  /// The user entered a card and Stripe accepted it. [CardSheetResult
  /// .setupIntentId] is set.
  completed,

  /// The user backed out. Not an error, and nothing is shown for it: they did
  /// what they meant to do.
  cancelled,

  /// Stripe refused — a declined card, a 3-D Secure that failed, no network.
  failed,
}

/// The outcome of one [CardSheet.present].
@immutable
class CardSheetResult {
  const CardSheetResult._(this.status, {this.setupIntentId, this.message});

  const CardSheetResult.completed(String setupIntentId)
    : this._(CardSheetStatus.completed, setupIntentId: setupIntentId);

  const CardSheetResult.cancelled() : this._(CardSheetStatus.cancelled);

  const CardSheetResult.failed(String message)
    : this._(CardSheetStatus.failed, message: message);

  final CardSheetStatus status;

  /// Set only when [status] is [CardSheetStatus.completed].
  final String? setupIntentId;

  /// Set only when [status] is [CardSheetStatus.failed].
  final String? message;
}

/// Stripe's PaymentSheet, behind an interface.
///
/// An interface because the real one needs an Activity, a platform channel and
/// a human with a card — none of which exist under `flutter test`.
abstract class CardSheet {
  Future<CardSheetResult> present(SetupIntentSession session);
}

/// The SetupIntent id hiding in a client secret. Pure.
///
/// A client secret is `seti_1ABC…_secret_XYZ…` — the id, then the marker, then
/// the part that must never be logged. `/v1/billing/card/confirm` wants the id
/// alone, and the Worker re-reads the SetupIntent from Stripe to check it, so
/// there is nothing to be gained by sending the whole secret along.
///
/// Null when [clientSecret] has no `_secret_` in it at all, which is the shape
/// a caller must not turn into a request.
String? setupIntentIdFromClientSecret(String clientSecret) {
  const marker = '_secret_';
  final at = clientSecret.indexOf(marker);
  if (at <= 0) return null;
  return clientSecret.substring(0, at);
}

/// The real sheet, on `flutter_stripe`.
class StripeCardSheet implements CardSheet {
  const StripeCardSheet({this.publishableKey = kStripePublishableKey});

  final String publishableKey;

  @override
  Future<CardSheetResult> present(SetupIntentSession session) async {
    final setupIntentId = setupIntentIdFromClientSecret(
      session.setupIntentClientSecret,
    );
    if (setupIntentId == null) {
      return const CardSheetResult.failed('カードの登録を開始できませんでした');
    }

    // Set here and not in `WakeOrPayApp`: assigning this schedules a call over
    // a platform channel, and a widget test that builds the app must not need
    // a Stripe plugin underneath it. By the time anybody reaches this method
    // there is a real Activity on screen.
    Stripe.publishableKey = publishableKey;

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: session.setupIntentClientSecret,
          customerId: session.customerId,
          customerEphemeralKeySecret: session.ephemeralKeySecret,
          merchantDisplayName: 'Wake or Pay',
          style: ThemeMode.system,
          // Google Pay is offered on top of manual entry, not instead of it:
          // the saved PaymentMethod is a normal card either way, reusable
          // off-session the same as one typed by hand. `testEnv` follows the
          // publishable key so switching to `pk_live_` flips it automatically.
          // Production also needs Google Pay & Wallet Console approval for
          // this app once it's published on Play.
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'JP',
            currencyCode: 'JPY',
            testEnv: isStripeTestKey(publishableKey),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return const CardSheetResult.cancelled();
      }
      return CardSheetResult.failed(
        e.error.localizedMessage ?? e.error.message ?? 'カードを登録できませんでした',
      );
    } on Object {
      return const CardSheetResult.failed('カードを登録できませんでした');
    }

    return CardSheetResult.completed(setupIntentId);
  }
}

/// Overridable in tests with a fake; the real sheet everywhere else.
final cardSheetProvider = Provider<CardSheet>(
  (ref) => const StripeCardSheet(),
);
