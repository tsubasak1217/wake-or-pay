import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The three bottom tabs. Ringing and Result live outside this shell so a
/// firing alarm always covers the whole screen.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      // `initialLocation: true` on a re-tap pops the branch back to its root,
      // which is the usual expectation for a tab you are already on.
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.alarm_outlined),
          selectedIcon: Icon(Icons.alarm),
          label: 'アラーム',
        ),
        NavigationDestination(
          icon: Icon(Icons.yard_outlined),
          selectedIcon: Icon(Icons.yard),
          label: 'お庭',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'ウォレット',
        ),
      ],
    ),
  );
}
