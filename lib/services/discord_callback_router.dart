import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/discord_oauth.dart';

/// How long a flow is allowed to stay in the air.
///
/// Five minutes is not a network timeout — it is "the user opened Discord,
/// got distracted, and is not coming back". Long enough to log in on a phone
/// with a password manager; short enough that the next 「Discord で連携」 is not
/// refused because of one abandoned an hour ago.
const discordFlowTimeout = Duration(minutes: 5);

/// Delivers `wakeorpay://` callbacks to whichever flow asked for them.
///
/// **One flow at a time.** Two flows in the air would share one callback URI
/// and the second would be answered by the first one's redirect — and neither
/// could tell. Starting a second while one is pending cancels the first, which
/// is what the user meant by pressing the button again.
///
/// Matching is by `state`, always, and by nothing else: a callback carrying
/// somebody else's state is not this flow's, and is left for
/// [parseDiscordCallback] to reject as a state mismatch rather than being
/// quietly dropped — a silently ignored callback is exactly the failure this
/// whole rework exists to remove.
class DiscordCallbackRouter {
  DiscordCallbackRouter(this._links);

  /// Every `wakeorpay://` URI the OS hands the app, from a cold start as well
  /// as while it is running.
  final Stream<Uri> _links;

  StreamSubscription<Uri>? _subscription;
  _PendingFlow? _pending;

  /// Starts listening. Idempotent, so wiring it from a provider that may be
  /// rebuilt cannot end up with two subscriptions racing for one callback.
  void start() {
    _subscription ??= _links.listen(_onUri);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _pending?.completeWith(null);
    _pending = null;
  }

  /// True while a flow is waiting for its redirect. The UI uses it to refuse a
  /// second tap rather than to show anything.
  bool get hasPendingFlow => _pending != null;

  /// The `state` the flow in the air is expecting, or null when none is.
  ///
  /// Exposed because it is what an emulator check has to echo back:
  /// `adb shell am start -d "wakeorpay://discord/callback#…&state=<this>"`.
  String? get pendingState => _pending?.state;

  /// Waits for the callback belonging to [state].
  ///
  /// **Call this before opening the authorize URL**, never after. The Discord
  /// app can be quick enough on a warm cache that the redirect arrives before
  /// an `await launchUrl(...)` has returned, and a listener registered after
  /// that would miss it entirely.
  ///
  /// Answers `null` on the timeout and on being displaced by a newer flow.
  Future<String?> awaitCallback(
    String state, {
    Duration timeout = discordFlowTimeout,
  }) {
    start();
    // A flow already in the air is abandoned rather than left to answer this
    // one's redirect. Its own await gets null and reports 「連携をやめました」.
    _pending?.completeWith(null);

    final flow = _PendingFlow(state);
    _pending = flow;
    flow.timer = Timer(timeout, () {
      if (identical(_pending, flow)) _pending = null;
      flow.completeWith(null);
    });
    return flow.completer.future;
  }

  /// Drops the pending flow without answering it. Used when the authorize URL
  /// could not be opened at all — there is nothing coming back.
  void cancelPending() {
    _pending?.completeWith(null);
    _pending = null;
  }

  void _onUri(Uri uri) {
    if (uri.scheme != kDiscordCallbackScheme) return;
    final flow = _pending;
    if (flow == null) return;
    _pending = null;
    flow.completeWith(uri.toString());
  }
}

class _PendingFlow {
  _PendingFlow(this.state);

  final String state;
  final completer = Completer<String?>();
  Timer? timer;

  void completeWith(String? url) {
    timer?.cancel();
    timer = null;
    if (!completer.isCompleted) completer.complete(url);
  }
}

/// The stream of incoming deep links. Overridden in tests with a controller,
/// which is the only reason it is a provider of its own.
final discordDeepLinkStreamProvider = Provider<Stream<Uri>>((ref) {
  final links = AppLinks();
  // `uriLinkStream` already replays the launch URI, so a callback that starts
  // the process from cold is not lost.
  return links.uriLinkStream;
});

final discordCallbackRouterProvider = Provider<DiscordCallbackRouter>((ref) {
  final router = DiscordCallbackRouter(ref.watch(discordDeepLinkStreamProvider))
    ..start();
  ref.onDispose(router.dispose);
  return router;
});
