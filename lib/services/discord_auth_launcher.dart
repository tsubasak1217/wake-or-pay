import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the authorize page ended up being shown.
///
/// Reported rather than inferred, so the 連携ログ can say it out loud. There
/// used to be a third value here — `discordApp` — and removing it is the
/// finding of this round rather than a simplification; see
/// [UrlLauncherDiscordAuthLauncher].
enum DiscordAuthChannel {
  /// A browser took it. Custom Tab or full browser — from here they are the
  /// same thing, and it is the only thing that ever takes it.
  browser,

  /// Nothing on the device could open it. Not a cancel: there is nothing to
  /// try again until a browser is installed.
  none,
}

/// Opens the Discord authorize URL.
///
/// An interface for one reason: **no test in this app may open a browser.**
/// Everything above this line is exercised with a fake that just records the
/// URL and answers with a channel.
abstract class DiscordAuthLauncher {
  Future<DiscordAuthChannel> open(String url);
}

/// The real one, over `url_launcher`. **One attempt, the browser.**
///
/// This used to try [LaunchMode.externalNonBrowserApplication] first, on the
/// theory that the Discord app claims `discord.com` links and would show the
/// consent screen in the place the user is already signed in. On a real device
/// that fell straight through to Brave, and the reason is not a bug in
/// url_launcher — it is what the Discord app actually registers. Measured on
/// the user's Pixel, with `com.discord` installed and its app links verified:
///
/// * `pm query-activities -d https://discord.com/channels/@me` → **both**
///   `com.discord/.main.MainActivity` and the browser.
/// * `pm query-activities -d https://discord.com/oauth2/authorize` → the
///   **browser only**. Same for `https://discord.com/api/oauth2/authorize`.
///   The Discord app's intent filter enumerates paths (channels, invites, …)
///   and deliberately leaves `/oauth2/authorize` out.
/// * `discord://-/oauth2/authorize`, `discord://discord.com/oauth2/authorize`,
///   `discord://-/channels/@me`, `discord://app` → *No activities found*. The
///   installed Discord app registers no `discord:` scheme at all.
///
/// So there is no in-app authorization to prefer. `externalNonBrowserApplication`
/// asks Android for a non-browser handler, there is none, and the only thing
/// the extra attempt bought was a launch failure before the real one.
/// `FLAG_ACTIVITY_REQUIRE_NON_BROWSER` does not conjure a handler.
///
/// The effort therefore goes into the **return** trip instead: the redirect is
/// an https URL on the Worker that `MainActivity` claims with
/// `autoVerify="true"`, so a Chromium browser (Brave included) hands the
/// navigation to the app without ever painting a page.
class UrlLauncherDiscordAuthLauncher implements DiscordAuthLauncher {
  const UrlLauncherDiscordAuthLauncher();

  @override
  Future<DiscordAuthChannel> open(String url) async {
    final uri = Uri.parse(url);
    // externalApplication, not the in-app WebView: an OAuth consent screen in
    // a WebView is both a phishing shape and a place the user's existing
    // Discord session does not exist.
    if (await _tryLaunch(uri, LaunchMode.externalApplication)) {
      return DiscordAuthChannel.browser;
    }
    return DiscordAuthChannel.none;
  }

  Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      // url_launcher reports a missing handler **both** ways depending on the
      // platform implementation: a `false` return and a `PlatformException`
      // wrapping `ActivityNotFoundException`. Both mean the same thing here.
      return await launchUrl(uri, mode: mode);
    } on Object {
      return false;
    }
  }
}

final discordAuthLauncherProvider = Provider<DiscordAuthLauncher>(
  (ref) => const UrlLauncherDiscordAuthLauncher(),
);
