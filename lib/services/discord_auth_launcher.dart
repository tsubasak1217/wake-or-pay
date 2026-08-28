import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the authorize page ended up being shown.
///
/// Reported rather than inferred, because it is the difference between two
/// very different waits: the Discord app comes back in two taps, a browser
/// asks for an email and a password first. The status line says which one the
/// user is looking at.
enum DiscordAuthChannel {
  /// The Discord app took the link. The user is already signed in there, so
  /// all that is left is 「認証」.
  discordApp,

  /// A browser took it. Custom Tab or full browser — from here they are the
  /// same thing.
  browser,

  /// Nothing on the device could open it. Not a cancel: there is nothing to
  /// try again until something is installed.
  none,
}

/// Opens the Discord authorize URL, preferring the Discord app.
///
/// An interface for one reason: **no test in this app may open a browser.**
/// Everything above this line is exercised with a fake that just records the
/// URL and answers with a channel.
abstract class DiscordAuthLauncher {
  Future<DiscordAuthChannel> open(String url);
}

/// The real one, over `url_launcher`.
///
/// Two attempts, in this order:
///
/// 1. [LaunchMode.externalNonBrowserApplication] — Android's
///    `FLAG_ACTIVITY_REQUIRE_NON_BROWSER`. Every browser is excluded from the
///    resolution, so this either lands in the Discord app (which claims
///    `discord.com` links) or fails outright. That is exactly the question we
///    want asked: *is the Discord app here?* — and asking it this way needs no
///    package name, no version check and no `canLaunchUrl` guess.
/// 2. [LaunchMode.externalApplication] — the browser. Reached only when 1 said
///    no.
///
/// url_launcher reports "no non-browser handler" **both** ways depending on
/// the platform implementation: a `false` return and a `PlatformException`
/// wrapping `ActivityNotFoundException`. Both are caught, and both mean the
/// same thing here.
class UrlLauncherDiscordAuthLauncher implements DiscordAuthLauncher {
  const UrlLauncherDiscordAuthLauncher();

  @override
  Future<DiscordAuthChannel> open(String url) async {
    final uri = Uri.parse(url);

    if (await _tryLaunch(uri, LaunchMode.externalNonBrowserApplication)) {
      return DiscordAuthChannel.discordApp;
    }
    if (await _tryLaunch(uri, LaunchMode.externalApplication)) {
      return DiscordAuthChannel.browser;
    }
    return DiscordAuthChannel.none;
  }

  Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } on Object {
      return false;
    }
  }
}

final discordAuthLauncherProvider = Provider<DiscordAuthLauncher>(
  (ref) => const UrlLauncherDiscordAuthLauncher(),
);
