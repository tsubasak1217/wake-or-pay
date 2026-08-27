import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// The runtime permissions the personal routes need, asked for at the moment
/// the user switches that route on — per spec 11.5, not at launch.
///
/// Asking up front for the right to text people and place calls, before the
/// user has said they want either, is how an alarm clock gets uninstalled.
/// Asking when the toggle is flipped puts the dialog next to the reason for
/// it.
///
/// An interface because a widget test has no platform under it: the real
/// implementation would throw a `MissingPluginException` at every toggle.
abstract class RoutePermissions {
  /// `SEND_SMS`. False means the user said no, or the platform has no
  /// telephony to say yes with.
  Future<bool> requestSms();

  /// `CALL_PHONE`.
  Future<bool> requestPhone();
}

/// `permission_handler`. Every throw is a `false`: a permission the app cannot
/// ask for is a permission it does not have, and the toggle stays off with a
/// line saying so rather than the screen coming down.
class PluginRoutePermissions implements RoutePermissions {
  const PluginRoutePermissions();

  @override
  Future<bool> requestSms() => _request(Permission.sms);

  @override
  Future<bool> requestPhone() => _request(Permission.phone);

  static Future<bool> _request(Permission permission) async {
    try {
      if (await permission.isGranted) return true;
      return (await permission.request()).isGranted;
    } on Object catch (e) {
      debugPrint('permission request failed: $e');
      return false;
    }
  }
}

/// Says yes without asking anyone. The default, so widget tests can drive the
/// toggles; `main()` swaps in the real one.
class AlwaysGrantRoutePermissions implements RoutePermissions {
  AlwaysGrantRoutePermissions({this.granted = true});

  final bool granted;
  final asked = <String>[];

  @override
  Future<bool> requestSms() async {
    asked.add('sms');
    return granted;
  }

  @override
  Future<bool> requestPhone() async {
    asked.add('phone');
    return granted;
  }
}

final routePermissionsProvider = Provider<RoutePermissions>(
  (ref) => AlwaysGrantRoutePermissions(),
);

Override pluginRoutePermissionsOverride() =>
    routePermissionsProvider.overrideWithValue(const PluginRoutePermissions());
