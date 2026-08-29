import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/providers.dart';
import '../domain/app_update.dart';
import 'discord_sender.dart' show httpClientProvider;
import 'distribution.dart';

/// The prefs key holding when the app last asked GitHub. ISO-8601, UTC.
const kUpdateLastCheckedKey = 'update.lastCheckedAt';

/// How long an answer from GitHub is good for. The automatic check is once per
/// app start *and* no more often than this, so an app opened twenty times a
/// day makes two requests. 「アプリの更新」 in the profile ignores it — a user who
/// taps the row is asking now.
const kUpdateThrottle = Duration(hours: 12);

/// How long the manifest fetch is given. Short on purpose: this runs while the
/// user is looking at their alarms, and a slow answer is worth nothing.
const kUpdateManifestTimeout = Duration(seconds: 8);

/// How long the APK download is given. The user is watching a progress bar,
/// but the file is tens of megabytes over whatever connection they have.
const kUpdateDownloadTimeout = Duration(minutes: 5);

// ---------------------------------------------------------------------------
// The three things that touch the outside world. All injectable, so no test
// reaches the network, the filesystem or the package installer.
// ---------------------------------------------------------------------------

/// Where the app learns that a newer build exists.
abstract class UpdateSource {
  /// The decoded manifest, or **null for every failure** — offline, a 404, a
  /// timeout, a body that is not JSON. Never throws: a failed update check is
  /// not something the user asked for and must not surface as an error.
  Future<Map<String, dynamic>?> fetchManifest();
}

/// The sideloaded build's source: `version.json` beside the APK on GitHub
/// Releases, at the fixed 「latest」 URL.
class GitHubUpdateSource implements UpdateSource {
  const GitHubUpdateSource(this._client, {this.url = kUpdateManifestUrl});

  final http.Client _client;
  final String url;

  @override
  Future<Map<String, dynamic>?> fetchManifest() async {
    try {
      // `http` follows redirects by default, which this URL always is:
      // /releases/latest/download/ is a 302 to the asset's real object URL.
      final response = await _client
          .get(Uri.parse(url))
          .timeout(kUpdateManifestTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }
}

/// The Play build's source, which does not exist yet.
///
/// A Play build must never download and install an APK of its own — it is a
/// policy violation, and pointless besides, because Play updates the app. When
/// there is a Play build it will use Play's own in-app updates
/// (`in_app_update`); until then this answers 「nothing to install」 and the
/// banner never appears.
class PlayUpdateSource implements UpdateSource {
  const PlayUpdateSource();

  @override
  Future<Map<String, dynamic>?> fetchManifest() async => null;
}

/// Fetches the APK to a local file.
abstract class ApkDownloader {
  /// Downloads [url] into the app's private updates folder and answers the
  /// path, or **null for every failure**. [onProgress] is called with 0..1 as
  /// bytes arrive, and once with 1 when the file is complete.
  Future<String?> download(
    String url,
    int build,
    void Function(double progress) onProgress,
  );
}

/// Streams the APK to `<application support>/updates/WakeOrPay-<build>.apk`.
///
/// Application support, not the cache or external storage: the cache can be
/// swept out from under a download, and external storage would need a
/// permission this app has no other use for. The folder holds exactly one
/// file — the previous build's APK is deleted before the new one starts, so an
/// abandoned update cannot leave 60 MB behind forever.
class HttpApkDownloader implements ApkDownloader {
  const HttpApkDownloader(this._client);

  final http.Client _client;

  @override
  Future<String?> download(
    String url,
    int build,
    void Function(double progress) onProgress,
  ) async {
    IOSink? sink;
    try {
      final root = await getApplicationSupportDirectory();
      final dir = Directory(p.join(root.path, 'updates'));
      await dir.create(recursive: true);

      final target = p.join(dir.path, 'WakeOrPay-$build.apk');
      // Everything that is not the file about to be written, including a
      // half-finished copy of this same build from a cancelled attempt.
      await for (final entity in dir.list()) {
        try {
          await entity.delete(recursive: true);
        } on Object {
          // A file the OS still holds open is not a reason to refuse the
          // update; it just stays on disk one build longer.
        }
      }

      final response = await _client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(kUpdateDownloadTimeout);
      if (response.statusCode != 200) return null;

      final total = response.contentLength ?? 0;
      final file = File(target);
      sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        // No content-length (a chunked answer) means no percentage; the bar
        // stays indeterminate rather than lying about how far along it is.
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      }
      await sink.flush();
      await sink.close();
      sink = null;
      onProgress(1);
      return target;
    } on Object {
      try {
        await sink?.close();
      } on Object {
        // Nothing left to do about it.
      }
      return null;
    }
  }
}

/// Hands the downloaded APK to Android's package installer.
abstract class ApkInstaller {
  /// True when the installer actually opened. False means the user has to
  /// grant 「不明なアプリのインストール」 first — the one failure worth a message.
  Future<bool> open(String path);
}

/// The real one. `open_filex` deliberately does **not** declare
/// `REQUEST_INSTALL_PACKAGES` (it was forked from `open_file` to drop it, for
/// Play policy), so this app declares it in its own manifest.
class OpenFilexApkInstaller implements ApkInstaller {
  const OpenFilexApkInstaller();

  @override
  Future<bool> open(String path) async {
    try {
      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } on Object {
      return false;
    }
  }
}

/// The running build, as the OS reports it.
abstract class AppVersionInfo {
  Future<({int build, String versionName})> read();
}

/// `package_info_plus`, which reads the installed APK's own `versionCode` and
/// `versionName` — the values `flutter build apk --build-number/--build-name`
/// wrote, which is exactly what `tools/release.ps1` publishes into
/// `version.json`.
class PackageInfoVersion implements AppVersionInfo {
  const PackageInfoVersion();

  @override
  Future<({int build, String versionName})> read() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return (
        build: parseBuildNumber(info.buildNumber),
        versionName: info.version,
      );
    } on Object {
      // No platform underneath (a widget test that did not override this).
      // Build 0 makes every published build look newer, which is the harmless
      // direction — and nothing auto-installs.
      return (build: 0, versionName: '');
    }
  }
}

final updateSourceProvider = Provider<UpdateSource>(
  (ref) => kDistributedViaGitHub
      ? GitHubUpdateSource(ref.watch(httpClientProvider))
      : const PlayUpdateSource(),
);

final apkDownloaderProvider = Provider<ApkDownloader>(
  (ref) => HttpApkDownloader(ref.watch(httpClientProvider)),
);

final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => const OpenFilexApkInstaller(),
);

final appVersionInfoProvider = Provider<AppVersionInfo>(
  (ref) => const PackageInfoVersion(),
);

// ---------------------------------------------------------------------------

/// What the banner and the profile row draw.
@immutable
class AppUpdateState {
  const AppUpdateState({
    this.available,
    this.checking = false,
    this.downloading = false,
    this.progress = 0,
    this.error,
    this.lastCheckedAt,
    this.dismissed = false,
    this.currentBuild = 0,
    this.currentVersionName = '',
  });

  /// The newer build, or null when there is none — or none is known yet.
  final AvailableUpdate? available;

  final bool checking;
  final bool downloading;

  /// 0..1 while [downloading]. Meaningless otherwise.
  final double progress;

  /// A message for the user, in Japanese. Only ever set by something the user
  /// started: a failed *automatic* check says nothing.
  final String? error;

  /// When the source was last asked, successfully or not. Null until the first
  /// check of this install.
  final DateTime? lastCheckedAt;

  /// 「あとで」. Hides the banner for the rest of this app start — not persisted,
  /// because the next start is the next chance to offer it.
  final bool dismissed;

  final int currentBuild;
  final String currentVersionName;

  /// Whether the home screen should show the banner.
  bool get showBanner => available != null && !dismissed;

  /// 「1.0.0 (build 42)」, or 「不明」 before the version has been read.
  String get currentLabel => currentVersionName.isEmpty
      ? '不明'
      : '$currentVersionName (build $currentBuild)';

  AppUpdateState copyWith({
    AvailableUpdate? available,
    bool clearAvailable = false,
    bool? checking,
    bool? downloading,
    double? progress,
    String? error,
    bool clearError = false,
    DateTime? lastCheckedAt,
    bool? dismissed,
    int? currentBuild,
    String? currentVersionName,
  }) => AppUpdateState(
    available: clearAvailable ? null : (available ?? this.available),
    checking: checking ?? this.checking,
    downloading: downloading ?? this.downloading,
    progress: progress ?? this.progress,
    error: clearError ? null : (error ?? this.error),
    lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    dismissed: dismissed ?? this.dismissed,
    currentBuild: currentBuild ?? this.currentBuild,
    currentVersionName: currentVersionName ?? this.currentVersionName,
  );
}

/// 「ダウンロードに失敗しました」 — the network gave out partway through.
const kUpdateDownloadFailed = 'ダウンロードに失敗しました。通信状況を確かめて、もう一度お試しください。';

/// The one failure that needs an instruction rather than an apology: Android
/// refuses to hand an APK to the installer until this app is allowed to be an
/// installer, and that switch lives in the OS settings, not in here.
const kUpdateInstallBlocked =
    'インストール画面を開けませんでした。Android の設定 →「アプリ」→「特別なアプリアクセス」→'
    '「不明なアプリのインストール」で Wake or Pay を許可してから、もう一度お試しください。';

/// The in-app update check for the sideloaded build.
///
/// Sideloading has no store behind it, so the app is the only thing that can
/// tell the user a newer build exists. It asks GitHub for the manifest
/// `tools/release.ps1` publishes, compares build numbers, and — when the user
/// taps 更新 — downloads the APK and hands it to Android's installer. It never
/// installs anything on its own.
final appUpdateProvider = NotifierProvider<AppUpdateService, AppUpdateState>(
  AppUpdateService.new,
);

class AppUpdateService extends Notifier<AppUpdateState> {
  bool _disposed = false;

  @override
  AppUpdateState build() {
    ref.onDispose(() => _disposed = true);
    // The running version, for the profile row. Local, cheap, and never a
    // reason to keep the first frame waiting.
    unawaited(_loadVersion());
    return AppUpdateState(lastCheckedAt: _storedLastCheckedAt());
  }

  Future<void> _loadVersion() async {
    final info = await ref.read(appVersionInfoProvider).read();
    if (_disposed) return;
    state = state.copyWith(
      currentBuild: info.build,
      currentVersionName: info.versionName,
    );
  }

  DateTime? _storedLastCheckedAt() {
    final raw = ref.read(sharedPreferencesProvider).getString(
      kUpdateLastCheckedKey,
    );
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// The automatic check, once per app start. Silent about every failure.
  Future<void> checkOnStart() => check();

  /// Asks the source whether a newer build exists.
  ///
  /// [force] skips the 12 h throttle and is what the profile row passes: a
  /// user who taps 「アプリの更新」 is asking about *now*, and an answer cached
  /// this morning is not an answer.
  ///
  /// A source that answers nothing is not an error here in either case. The
  /// user did not ask to be told about GitHub being down, and the profile row
  /// already says 「未確認」 when nothing has ever come back.
  Future<void> check({bool force = false}) async {
    if (!kDistributedViaGitHub) return;
    if (state.checking) return;

    final now = ref.read(clockProvider)();
    final last = state.lastCheckedAt;
    if (!force && last != null && now.difference(last) < kUpdateThrottle) {
      return;
    }

    state = state.copyWith(checking: true, clearError: true);
    // The version may still be loading; the comparison needs it.
    final info = await ref.read(appVersionInfoProvider).read();
    final json = await ref.read(updateSourceProvider).fetchManifest();
    if (_disposed) return;

    await ref
        .read(sharedPreferencesProvider)
        .setString(kUpdateLastCheckedKey, now.toIso8601String());
    if (_disposed) return;

    final update = json == null ? null : newerThan(info.build, json);
    state = state.copyWith(
      checking: false,
      lastCheckedAt: now,
      clearAvailable: update == null,
      available: update,
      currentBuild: info.build,
      currentVersionName: info.versionName,
      // 「あとで」 was said about one particular build. A *different* build —
      // or none — is a new question, so the banner comes back.
      dismissed: update?.build == state.available?.build && update != null
          ? state.dismissed
          : false,
    );
  }

  /// 「あとで」. The banner stays away until the app is started again.
  void dismiss() => state = state.copyWith(dismissed: true, clearError: true);

  /// 「更新」: fetch the APK, then let Android install it.
  ///
  /// This app never installs anything itself — the last step is the OS's own
  /// installer screen, which the user confirms. If it will not open, the only
  /// possible cause is the 「不明なアプリのインストール」 permission, so that is
  /// what the message says.
  Future<void> downloadAndInstall() async {
    final update = state.available;
    if (update == null || state.downloading) return;

    state = state.copyWith(downloading: true, progress: 0, clearError: true);

    final path = await ref
        .read(apkDownloaderProvider)
        .download(update.apkUrl, update.build, (progress) {
          if (_disposed) return;
          state = state.copyWith(progress: progress);
        });
    if (_disposed) return;

    if (path == null) {
      state = state.copyWith(downloading: false, error: kUpdateDownloadFailed);
      return;
    }

    state = state.copyWith(progress: 1);
    final opened = await ref.read(apkInstallerProvider).open(path);
    if (_disposed) return;

    state = state.copyWith(
      downloading: false,
      progress: 1,
      error: opened ? null : kUpdateInstallBlocked,
      clearError: opened,
    );
  }
}
