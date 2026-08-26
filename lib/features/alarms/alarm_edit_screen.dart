import 'package:flutter/material.dart';

class AlarmEditScreen extends StatelessWidget {
  const AlarmEditScreen({super.key, this.alarmId});

  /// null when creating a new alarm.
  final String? alarmId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(alarmId == null ? 'アラームを追加' : 'アラームを編集')),
      body: const Center(child: Text('準備中')),
    );
  }
}
