import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('覚悟の目覚まし'),
        actions: [
          IconButton(
            tooltip: 'ウォレット',
            onPressed: () => context.push(AppRoute.wallet),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          IconButton(
            tooltip: '設定',
            onPressed: () => context.push(AppRoute.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: const Center(child: Text('アラームはまだありません')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoute.alarmNew),
        child: const Icon(Icons.add),
      ),
    );
  }
}
