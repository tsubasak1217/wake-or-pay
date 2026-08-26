import 'package:flutter/material.dart';

class RingingScreen extends StatelessWidget {
  const RingingScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    // No back button, no snooze: the only way out is the wake check.
    return const PopScope(
      canPop: false,
      child: Scaffold(body: Center(child: Text('起きろ！！'))),
    );
  }
}
