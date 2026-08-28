import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/discord_oauth.dart';
import 'discord_auth_launcher.dart';
import 'discord_callback_router.dart';
import 'discord_exchange.dart';
import 'discord_link_log.dart';

/// The sentence shown while the app is asking something to open Discord.
const kDiscordOpeningMessage = 'Discord を開いています…';

/// The 連携ログ line naming where the authorize page went.
///
/// It is worth a line of its own because it is the answer to a question that
/// cost this app a release: 「なぜ Discord アプリが開かないのか」. It is not a
/// misconfiguration — the Discord Android app does not register
/// `/oauth2/authorize` at all (see [UrlLauncherDiscordAuthLauncher]), so the
/// browser is the only route there has ever been.
const kDiscordOpenedInBrowserMessage =
    'ブラウザで Discord を開きました（Discord アプリは承認画面に対応していません）';

/// 承認待ち. One message, because there is one channel.
const kDiscordWaitingInBrowserMessage = '承認を待っています…（ブラウザで許可してください）';

/// What a five-minute silence means, said as the thing to go and check.
///
/// The redirect URI is the one setting that fails **before the consent screen**
/// and therefore produces exactly this symptom: Discord shows
/// 「Redirect URI … is not supported by client」, never redirects, and the app
/// waits forever. Naming the exact string here is the difference between a
/// user who can fix their own Portal and one who files 「連携できない」.
const kDiscordTimedOutMessage =
    '承認が返ってきませんでした。Discord の画面に「Redirect URI … is not supported by client」'
    'と出ていた場合は、Developer Portal の OAuth2 → Redirects に '
    '$kDiscordRedirectUri を 1 文字違わず登録してください。';

/// Why 「Discord で連携」 ended the way it did.
enum DiscordLinkStatus {
  ok,

  /// This build has no 連携サーバー baked in. 「Discord で連携」 needs one now:
  /// the implicit grant is gone, so the code has to be exchanged somewhere
  /// that holds the client secret.
  noEndpoint,

  /// No browser could open the authorize URL. Distinct from a cancel: there is
  /// nothing to retry until something is installed.
  noApp,

  /// The user pressed 「やめる」 on the waiting row.
  cancelled,

  /// Five minutes with no callback. Most often the redirect URI.
  timedOut,

  /// The `state` did not come back intact. Loud on purpose — this is the one
  /// failure that means something was wrong rather than merely unlucky.
  stateMismatch,

  /// Discord answered the authorize step with `error=…` — 「キャンセル」 on the
  /// consent screen, most often.
  denied,

  /// A code came back but the 連携サーバー did not answer with a user — it is
  /// down, the code was already spent, or the secret was never put on it.
  identityFailed,
}

/// The outcome of a link attempt, as a value.
@immutable
class DiscordLinkResult {
  const DiscordLinkResult(this.status, [this.identity]);

  final DiscordLinkStatus status;
  final DiscordIdentity? identity;

  bool get ok => status == DiscordLinkStatus.ok && identity != null;

  /// What the status area says. Japanese, and specific enough to act on.
  String get label => switch (status) {
    DiscordLinkStatus.ok => '連携しました',
    DiscordLinkStatus.noEndpoint =>
      '連携サーバーが設定されていないビルドです（worker/README.md の手順でデプロイし、'
          'kDiscordExchangeEndpoint に URL を入れてビルドし直してください）',
    DiscordLinkStatus.noApp => 'ブラウザが見つかりませんでした',
    DiscordLinkStatus.cancelled => '連携をやめました',
    DiscordLinkStatus.timedOut => kDiscordTimedOutMessage,
    DiscordLinkStatus.stateMismatch => '確認に失敗しました。アプリからもう一度お試しください',
    DiscordLinkStatus.denied => 'Discord で許可されませんでした',
    DiscordLinkStatus.identityFailed => 'ユーザー情報を取得できませんでした（連携サーバーの応答なし）',
  };
}

/// 「Discord で連携」, end to end.
///
/// The **authorization-code** grant, like 「チャンネルを連携」 — the implicit
/// grant this used to use is gone. Two reasons, and the first is fatal on its
/// own: Discord refuses the `wakeorpay://` redirect the implicit flow relied
/// on, and the https redirect that replaces it lands on the Worker, where a
/// fragment would never arrive (a fragment is not sent to a server, which was
/// the whole point of it). The second is that it is simply better: the access
/// token is now spent **inside the Worker** and never touches the device at
/// all. What comes back over the wire is the id, the two names and the avatar
/// hash. Nothing token-shaped is ever persisted, logged, or held in a field.
///
/// The two halves of the flow are separate collaborators on purpose. The
/// [DiscordAuthLauncher] only opens a URL — it never learns the answer — and
/// the [DiscordCallbackRouter] only delivers a URI — it never opens anything.
/// That split is the fix for the bug this class used to have: the old
/// authorizer owned both, and its callback arrived in a browser-owned task
/// that left the app behind the Custom Tab.
class DiscordOAuthService {
  DiscordOAuthService(
    this._launcher,
    this._router,
    this._exchange, {
    this.reporter = DiscordFlowReporter.silent,
  });

  final DiscordAuthLauncher _launcher;
  final DiscordCallbackRouter _router;
  final DiscordExchangeClient _exchange;
  final DiscordFlowReporter reporter;

  /// The state of the flow currently in the air, for the emulator check —
  /// it is what an `adb am start` has to echo back.
  String? get pendingState => _router.pendingState;

  /// Set by [cancel] so the null coming back from the router can be told apart
  /// from the one the timer produces. Both look identical at the await.
  bool _cancelRequested = false;

  /// Abandons the flow in the air. The awaiting [link] returns
  /// [DiscordLinkStatus.cancelled].
  void cancel() {
    _cancelRequested = true;
    _router.cancelPending();
  }

  Future<DiscordLinkResult> link({
    String endpoint = kDiscordExchangeEndpoint,
    Duration timeout = discordFlowTimeout,
  }) async {
    _cancelRequested = false;
    if (!isDiscordExchangeEndpoint(endpoint)) {
      return _fail(DiscordLinkStatus.noEndpoint);
    }

    final state = randomOAuthState();
    final url = buildDiscordAuthorizeUrl(
      responseType: 'code',
      scopes: kDiscordIdentifyScopes,
      state: state,
      // Always show the consent screen: without it a user who already
      // authorised once is bounced straight back, which looks like nothing
      // happened when they pressed the button to *change* accounts.
      prompt: 'consent',
    );

    reporter.phase(DiscordFlowPhase.opening, kDiscordOpeningMessage);
    // Registered **before** the launch: the Discord app can answer faster than
    // `launchUrl` returns, and a listener attached afterwards would miss it.
    final pending = _router.awaitCallback(state, timeout: timeout);

    final channel = await _launcher.open(url);
    if (channel == DiscordAuthChannel.none) {
      _router.cancelPending();
      return _fail(DiscordLinkStatus.noApp);
    }
    reporter.log(kDiscordOpenedInBrowserMessage);
    reporter.phase(DiscordFlowPhase.waiting, kDiscordWaitingInBrowserMessage);

    final callback = await pending;
    if (callback == null) {
      // Null covers three things that look identical at this await: the timer
      // fired, 「やめる」 was pressed, or a newer flow displaced this one. Only
      // the first deserves the redirect-URI explanation, so the cancel is
      // flagged rather than guessed at.
      return _fail(
        _cancelRequested
            ? DiscordLinkStatus.cancelled
            : DiscordLinkStatus.timedOut,
      );
    }

    reporter.phase(DiscordFlowPhase.working, '連携サーバーに問い合わせています…');
    final parsed = parseDiscordCallback(callback, expectedState: state);
    if (!parsed.ok) {
      return _fail(switch (parsed.error) {
        DiscordCallbackError.stateMismatch => DiscordLinkStatus.stateMismatch,
        DiscordCallbackError.denied => DiscordLinkStatus.denied,
        _ => DiscordLinkStatus.identityFailed,
      });
    }
    final code = parsed.code;
    if (code == null || code.isEmpty) {
      return _fail(DiscordLinkStatus.identityFailed);
    }

    final identity = await _exchange.exchangeIdentity(
      endpoint: endpoint,
      code: code,
      // The same redirect that went out with the authorize request. Discord
      // checks the two match, and a mismatch here is a 400 on a code that is
      // then spent and unusable.
      redirectUri: kDiscordRedirectUri,
    );
    if (identity == null) return _fail(DiscordLinkStatus.identityFailed);

    final result = DiscordLinkResult(DiscordLinkStatus.ok, identity);
    reporter.phase(
      DiscordFlowPhase.done,
      '連携済み：@${identity.displayName}',
    );
    return result;
  }

  DiscordLinkResult _fail(DiscordLinkStatus status) {
    final result = DiscordLinkResult(status);
    reporter.phase(DiscordFlowPhase.failed, result.label);
    return result;
  }

}

final discordOAuthServiceProvider = Provider(
  (ref) => DiscordOAuthService(
    ref.watch(discordAuthLauncherProvider),
    ref.watch(discordCallbackRouterProvider),
    ref.watch(discordExchangeClientProvider),
    reporter: ref.watch(discordFlowReporterProvider),
  ),
);

/// Why 「チャンネルを連携」 ended the way it did.
enum DiscordChannelLinkStatus {
  ok,

  /// This build has no 連携サーバー baked in. Not a failure so much as a step
  /// not taken, and the fix is a rebuild rather than anything on screen.
  noEndpoint,

  noApp,
  cancelled,
  timedOut,
  stateMismatch,
  denied,

  /// The Worker did not hand back a webhook — it is down, the code was
  /// already spent, or the secret was never put on it.
  exchangeFailed,
}

/// The outcome of 「チャンネルを連携」, as a value.
@immutable
class DiscordChannelLinkResult {
  const DiscordChannelLinkResult(this.status, [this.grant]);

  final DiscordChannelLinkStatus status;
  final DiscordWebhookGrant? grant;

  bool get ok => status == DiscordChannelLinkStatus.ok && grant != null;

  String get label => switch (status) {
    DiscordChannelLinkStatus.ok => '共有先を追加しました',
    DiscordChannelLinkStatus.noEndpoint =>
      '連携サーバーが設定されていないビルドです（worker/README.md の手順でデプロイし、'
          'kDiscordExchangeEndpoint に URL を入れてビルドし直してください）',
    DiscordChannelLinkStatus.noApp => 'ブラウザが見つかりませんでした',
    DiscordChannelLinkStatus.cancelled => '連携をやめました',
    DiscordChannelLinkStatus.timedOut => kDiscordTimedOutMessage,
    DiscordChannelLinkStatus.stateMismatch =>
      '確認に失敗しました。アプリからもう一度お試しください',
    DiscordChannelLinkStatus.denied => 'Discord で許可されませんでした',
    DiscordChannelLinkStatus.exchangeFailed => 'チャンネルを連携できませんでした（連携サーバーの応答なし）',
  };
}

/// 「チャンネルを連携（Discord で選ぶ）」, end to end.
///
/// The **code** grant, not the implicit one, because `webhook.incoming` only
/// hands the webhook over with the token — and that exchange needs the client
/// secret, which is why [kDiscordExchangeEndpoint] (the Worker) has to exist
/// at all. The app never sees a token: what comes back over the Worker is a
/// webhook URL and a couple of names.
///
/// Opening goes through the same [DiscordAuthLauncher], so the server and
/// channel picker shows up **inside the Discord app** when it is installed —
/// which is the only place the picker is pleasant to use, and the only place
/// the user is already signed in.
class DiscordChannelLinker {
  DiscordChannelLinker(
    this._launcher,
    this._router,
    this._exchange, {
    this.reporter = DiscordFlowReporter.silent,
  });

  final DiscordAuthLauncher _launcher;
  final DiscordCallbackRouter _router;
  final DiscordExchangeClient _exchange;
  final DiscordFlowReporter reporter;

  bool _cancelRequested = false;

  String? get pendingState => _router.pendingState;

  void cancel() {
    _cancelRequested = true;
    _router.cancelPending();
  }

  Future<DiscordChannelLinkResult> link({
    String endpoint = kDiscordExchangeEndpoint,
    Duration timeout = discordFlowTimeout,
  }) async {
    _cancelRequested = false;
    if (!isDiscordExchangeEndpoint(endpoint)) {
      return _fail(DiscordChannelLinkStatus.noEndpoint);
    }

    final state = randomOAuthState();
    final url = buildDiscordAuthorizeUrl(
      responseType: 'code',
      // `webhook.incoming` is what makes Discord show the channel picker;
      // `identify` is only so the Worker can name the server it landed in.
      scopes: kDiscordWebhookScopes,
      state: state,
      // No prompt=consent here: picking a channel *is* the consent screen,
      // and Discord shows it every time regardless.
    );

    reporter.phase(DiscordFlowPhase.opening, kDiscordOpeningMessage);
    final pending = _router.awaitCallback(state, timeout: timeout);

    final channel = await _launcher.open(url);
    if (channel == DiscordAuthChannel.none) {
      _router.cancelPending();
      return _fail(DiscordChannelLinkStatus.noApp);
    }
    reporter.log(kDiscordOpenedInBrowserMessage);
    reporter.phase(
      DiscordFlowPhase.waiting,
      '承認を待っています…（ブラウザでサーバーとチャンネルを選んでください）',
    );

    final callback = await pending;
    if (callback == null) {
      return _fail(
        _cancelRequested
            ? DiscordChannelLinkStatus.cancelled
            : DiscordChannelLinkStatus.timedOut,
      );
    }

    reporter.phase(DiscordFlowPhase.working, '連携サーバーに問い合わせています…');
    final parsed = parseDiscordCallback(callback, expectedState: state);
    if (!parsed.ok) {
      return _fail(switch (parsed.error) {
        DiscordCallbackError.stateMismatch =>
          DiscordChannelLinkStatus.stateMismatch,
        DiscordCallbackError.denied => DiscordChannelLinkStatus.denied,
        _ => DiscordChannelLinkStatus.exchangeFailed,
      });
    }
    final code = parsed.code;
    if (code == null || code.isEmpty) {
      return _fail(DiscordChannelLinkStatus.exchangeFailed);
    }

    final grant = await _exchange.exchange(
      endpoint: endpoint,
      code: code,
      // The same redirect that went out with the authorize request. Discord
      // checks the two match, and a mismatch here is a 400 on a code that is
      // then spent and unusable.
      redirectUri: kDiscordRedirectUri,
    );
    if (grant == null) return _fail(DiscordChannelLinkStatus.exchangeFailed);

    reporter.phase(DiscordFlowPhase.done, '共有先を追加しました：${grant.displayName}');
    return DiscordChannelLinkResult(DiscordChannelLinkStatus.ok, grant);
  }

  DiscordChannelLinkResult _fail(DiscordChannelLinkStatus status) {
    final result = DiscordChannelLinkResult(status);
    reporter.phase(DiscordFlowPhase.failed, result.label);
    return result;
  }
}

final discordChannelLinkerProvider = Provider(
  (ref) => DiscordChannelLinker(
    ref.watch(discordAuthLauncherProvider),
    ref.watch(discordCallbackRouterProvider),
    ref.watch(discordExchangeClientProvider),
    reporter: ref.watch(discordFlowReporterProvider),
  ),
);
