/// How this build was handed to the user — the one switch the update feature
/// reads.
///
/// **true** is the sideloaded APK: there is no store to check, so the app
/// checks GitHub Releases itself and installs the APK it downloads. That is
/// the only build that exists today, because `SEND_SMS` keeps this app off
/// Google Play (README の「既知の制約」).
///
/// **false** would be a Play build, where an app that downloads and installs
/// its own APK is a policy violation as well as pointless — Play's own in-app
/// update flow does it properly. Nothing implements that yet; flipping this
/// selects [PlayUpdateSource], which answers 「no update」 and shows nothing.
const bool kDistributedViaGitHub = true;

/// The manifest `tools/release.ps1` uploads beside the APK, at the same fixed
/// 「latest」 URL the APK itself lives at. Never changes: that is the point of
/// it — an app that is three builds old still knows where to look.
const String kUpdateManifestUrl =
    'https://github.com/tsubasak1217/wake-or-pay/releases/latest/download/version.json';
