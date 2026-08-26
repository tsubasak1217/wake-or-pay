import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/wake_check.dart';

/// Type the sentence exactly. Selection and the paste menu are off, so it has
/// to be typed rather than copied.
class TypingCheck extends StatefulWidget {
  const TypingCheck({super.key, required this.onCleared, this.random});

  final VoidCallback onCleared;
  final Random? random;

  @override
  State<TypingCheck> createState() => _TypingCheckState();
}

class _TypingCheckState extends State<TypingCheck> {
  late final String _sentence = pickTypingSentence(widget.random ?? Random());
  final _controller = TextEditingController();
  bool _cleared = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_check);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_check)
      ..dispose();
    super.dispose();
  }

  void _check() {
    if (_cleared) return;
    if (_controller.text == _sentence) {
      _cleared = true;
      widget.onCleared();
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('この文を入力してください', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        SelectionContainer.disabled(
          child: Text(_sentence, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _controller,
            autofocus: true,
            enableInteractiveSelection: false,
            contextMenuBuilder: (context, editableTextState) =>
                const SizedBox.shrink(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }
}
