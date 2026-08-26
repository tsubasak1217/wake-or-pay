import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alarms/alarm_edit_screen.dart';
import '../features/alarms/home_screen.dart';
import '../features/result/result_screen.dart';
import '../features/ringing/ringing_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/wallet/wallet_screen.dart';

class AppRoute {
  const AppRoute._();

  static const home = '/';
  static const alarmNew = '/alarm/new';
  static const wallet = '/wallet';
  static const settings = '/settings';

  static String alarmEdit(String id) => '/alarm/$id';
  static String ringing(String sessionId) => '/ringing/$sessionId';
  static String result(String sessionId) => '/result/$sessionId';
}

/// Used by [AlarmService] to navigate from outside the widget tree when an
/// alarm starts ringing.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter());

GoRouter createAppRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoute.home,
  routes: [
    GoRoute(
      path: AppRoute.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/alarm/new',
      builder: (context, state) => const AlarmEditScreen(),
    ),
    GoRoute(
      path: '/alarm/:id',
      builder: (context, state) =>
          AlarmEditScreen(alarmId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/ringing/:sessionId',
      builder: (context, state) =>
          RingingScreen(sessionId: state.pathParameters['sessionId']!),
    ),
    GoRoute(
      path: '/result/:sessionId',
      builder: (context, state) =>
          ResultScreen(sessionId: state.pathParameters['sessionId']!),
    ),
    GoRoute(
      path: AppRoute.wallet,
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: AppRoute.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
