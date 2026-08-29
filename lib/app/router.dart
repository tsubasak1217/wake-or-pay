import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/alarms/alarm_edit_screen.dart';
import '../features/alarms/home_screen.dart';
import '../features/garden/garden_edit_screen.dart';
import '../features/garden/garden_screen.dart';
import '../features/garden/seed_shop_screen.dart';
import '../features/result/result_screen.dart';
import '../features/ringing/ringing_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shop/shop_screen.dart';
import 'shell_scaffold.dart';

class AppRoute {
  const AppRoute._();

  static const home = '/';
  static const alarmNew = '/alarm/new';
  static const activity = '/activity';
  static const garden = '/garden';
  static const gardenEdit = '/garden/edit';
  static const seedShop = '/garden/shop';
  static const shop = '/shop';
  static const settings = '/settings';

  /// The tab the ＋ beside the coins goes to. Kept as its own name because
  /// 「where the balance is topped up」 and 「the shop tab」 are the same place
  /// only for as long as the shop sells nothing else.
  static const wallet = shop;

  static String alarmEdit(String id) => '/alarm/$id';

  /// The editor opened on a *copy* of [id] — same settings, new alarm.
  static String alarmDuplicate(String id) => '/alarm/$id/duplicate';

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
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ShellScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoute.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoute.activity,
              builder: (context, state) => const ActivityScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoute.garden,
              builder: (context, state) => const GardenScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoute.shop,
              builder: (context, state) => const ShopScreen(),
            ),
          ],
        ),
      ],
    ),
    // Outside the shell: full screen, no tab bar.
    GoRoute(
      path: AppRoute.gardenEdit,
      builder: (context, state) => const GardenEditScreen(),
    ),
    GoRoute(
      path: AppRoute.seedShop,
      builder: (context, state) => const SeedShopScreen(),
    ),
    GoRoute(
      path: '/alarm/new',
      builder: (context, state) => const AlarmEditScreen(),
    ),
    // Before '/alarm/:id' so the longer path is the one that matches it.
    GoRoute(
      path: '/alarm/:id/duplicate',
      builder: (context, state) => AlarmEditScreen(
        alarmId: state.pathParameters['id'],
        duplicate: true,
      ),
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
      path: AppRoute.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
