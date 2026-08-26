import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/wake_check.dart';

/// Three two-digit additions in a row. A wrong answer swaps the problem and
/// resets the streak, but never locks the user out.
class MathCheck extends StatefulWidget {
  const MathCheck({super.key, required this.onCleared, this.random});

  final VoidCallback onCleared;
  final Random? random;

  @override
  State<MathCheck> createState() => _MathCheckState();
}

class _MathCheckState extends State<MathCheck> {
  late final Random _random = widget.random ?? Random();
  final _controller = TextEditingController();
  late MathProblem _problem = generateMathProblem(_random);
  int _solved = 0;
  bool _wasWrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final answer = int.tryParse(_controller.text.trim());
    _controller.clear();

    if (answer == _problem.answer) {
      final solved = _solved + 1;
      if (solved >= mathProblemCount) {
        widget.onCleared();
        return;
      }
      setState(() {
        _solved = solved;
        _wasWrong = false;
        _problem = generateMathProblem(_random);
      });
    } else {
      setState(() {
        _solved = 0;
        _wasWrong = true;
        _problem = generateMathProblem(_random);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_solved / $mathProblemCount 問正解',
          style: theme.textTheme.titleMedium,
        ),
        if (_wasWrong)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'まちがい。問題を変えます',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('$_problem = ?', style: theme.textTheme.displaySmall),
        const SizedBox(height: 16),
        SizedBox(
          width: 200,
          child: TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: const Text('答える')),
      ],
    );
  }
}
