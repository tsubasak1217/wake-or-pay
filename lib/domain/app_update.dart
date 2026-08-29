import 'package:flutter/foundation.dart';

/// A build published to GitHub Releases that is newer than the one running.
///
/// Pure data, read out of `version.json` — the manifest `tools/release.ps1`
/// uploads beside the APK. Nothing here touches the network or the disk.
@immutable
class AvailableUpdate {
  const AvailableUpdate({
    required this.build,
    required this.versionName,
    required this.apkUrl,
    this.notes = '',
  });

  /// The published build number — the commit count at the time of the build,
  /// which is what `--build-number` was given and therefore what
  /// `package_info_plus` reads back out of the installed APK.
  final int build;

  /// The `x.y.z` shown to the user. Cosmetic: the comparison is on [build].
  final String versionName;

  /// Where the APK is. Always the fixed 「latest」 URL in practice, but read
  /// from the manifest so a future release can move it without shipping a new
  /// app first.
  final String apkUrl;

  /// Release notes, usually empty. Shown under the banner when present.
  final String notes;

  @override
  bool operator ==(Object other) =>
      other is AvailableUpdate &&
      other.build == build &&
      other.versionName == versionName &&
      other.apkUrl == apkUrl &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(build, versionName, apkUrl, notes);

  @override
  String toString() => 'AvailableUpdate($versionName build $build)';
}

/// The published build as an update, or null when there is nothing to install.
///
/// Pure, and deliberately unforgiving in one direction only: **anything it
/// cannot read is 「no update」**, never an error. A malformed manifest — a
/// truncated upload, a 404 page that happened to parse, a build number written
/// as a string — must not put a banner on the home screen offering to install
/// something the app knows nothing about.
///
/// Equal builds are not an update either. The build number is a commit count,
/// so it is monotonic, and 「same commit」 means 「already installed」.
AvailableUpdate? newerThan(int currentBuild, Map<String, dynamic> json) {
  final build = json['build'];
  if (build is! int) return null;
  if (build <= currentBuild) return null;

  final apkUrl = _string(json['apkUrl']);
  // A row with nowhere to download from could only ever fail at the last
  // step, after the user tapped 更新.
  if (apkUrl.isEmpty) return null;
  final uri = Uri.tryParse(apkUrl);
  // https only: an APK is executable code, and one fetched over http is one
  // anybody on the same wifi can replace.
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;

  return AvailableUpdate(
    build: build,
    versionName: _string(json['versionName']),
    apkUrl: apkUrl,
    notes: _string(json['notes']),
  );
}

String _string(Object? value) => value is String ? value.trim() : '';

/// The build number `package_info_plus` reports, as an int. Pure.
///
/// Android hands back the `versionCode` as a decimal string, which is the
/// ordinary case and parses directly. The fallbacks exist because the field is
/// a `String` by contract and not every platform fills it the same way: an
/// empty one (a debug build with no build number) and a dotted one (iOS's
/// `CFBundleVersion`, e.g. `1.0.3`) both have to answer something rather than
/// throw.
///
/// 0 for anything unreadable — the safe direction, because a current build of
/// 0 makes every published build look newer, and the user is *offered* an
/// update rather than silently denied one.
int parseBuildNumber(String raw) {
  final trimmed = raw.trim();
  final direct = int.tryParse(trimmed);
  if (direct != null) return direct < 0 ? 0 : direct;

  // `1.0.3` → 3: the last dotted segment is the build on the platforms that
  // write one that way.
  final segments = trimmed.split('.');
  if (segments.length > 1) {
    final last = int.tryParse(segments.last.trim());
    if (last != null && last >= 0) return last;
  }
  return 0;
}
