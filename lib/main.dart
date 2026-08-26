import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme_controller.dart';

void main() {
  runApp(const ProviderScope(child: WakeOrPayApp()));
}

class WakeOrPayApp extends ConsumerWidget {
  const WakeOrPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return MaterialApp.router(
      title: '覚悟の目覚まし',
      theme: theme.themeData,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
