import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/services/discord_callback_router.dart';

/// [DiscordCallbackRouter] on its own, over a bare [StreamController] —
/// nothing here goes through a [ProviderContainer], because the class itself
/// takes only a `Stream<Uri>` and needs nothing else to be exercised.
void main() {
  late StreamController<Uri> links;
  late DiscordCallbackRouter router;

  setUp(() {
    links = StreamController<Uri>.broadcast();
    router = DiscordCallbackRouter(links.stream);
  });

  tearDown(() async {
    router.dispose();
    await links.close();
  });

  test('delivers the callback to the pending flow, fragment intact', () async {
    final future = router.awaitCallback('abc');
    links.add(
      Uri.parse('wakeorpay://discord/callback#access_token=TOK&state=abc'),
    );
    expect(
      await future,
      'wakeorpay://discord/callback#access_token=TOK&state=abc',
    );
  });

  test('ignores a URI whose scheme is not wakeorpay, leaving the flow '
      'pending', () async {
    final future = router.awaitCallback(
      'abc',
      timeout: const Duration(seconds: 5),
    );
    // A page unrelated to this app's callback — a redirect chain in a
    // browser tab can produce plenty of these before the real one arrives.
    links.add(Uri.parse('https://discord.com/whatever?state=abc'));
    await Future<void>.delayed(Duration.zero);
    expect(router.hasPendingFlow, isTrue);

    links.add(Uri.parse('wakeorpay://discord/callback?state=abc'));
    expect(await future, 'wakeorpay://discord/callback?state=abc');
  });

  test('times out and answers null when nothing ever arrives', () async {
    final result = await router.awaitCallback(
      'abc',
      timeout: const Duration(milliseconds: 10),
    );
    expect(result, isNull);
    expect(router.hasPendingFlow, isFalse);
  });

  test('cancelPending answers the waiting flow with null right away, well '
      'before its timeout', () async {
    final future = router.awaitCallback(
      'abc',
      timeout: const Duration(seconds: 30),
    );
    router.cancelPending();
    expect(await future, isNull);
    expect(router.hasPendingFlow, isFalse);
  });

  test('a second awaitCallback displaces the first, which resolves to null',
      () async {
    final first = router.awaitCallback(
      'first',
      timeout: const Duration(seconds: 30),
    );
    expect(router.pendingState, 'first');

    final second = router.awaitCallback(
      'second',
      timeout: const Duration(seconds: 30),
    );
    expect(router.pendingState, 'second');

    // The abandoned flow is told, not left hanging until its own timeout.
    expect(await first, isNull);

    links.add(Uri.parse('wakeorpay://discord/callback?state=second'));
    expect(await second, 'wakeorpay://discord/callback?state=second');
  });

  test('pendingState reflects only the flow currently in the air', () async {
    expect(router.pendingState, isNull);
    final future = router.awaitCallback('xyz', timeout: const Duration(seconds: 5));
    expect(router.pendingState, 'xyz');

    router.cancelPending();
    await future;
    expect(router.pendingState, isNull);
  });

  test('dispose answers the pending flow with null and stops listening',
      () async {
    final future = router.awaitCallback(
      'abc',
      timeout: const Duration(seconds: 30),
    );
    router.dispose();
    expect(await future, isNull);
  });
}
