import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/wake_check.dart';

void main() {
  group('longPressProgress', () {
    test('runs from 0 to 1 over five seconds', () {
      expect(longPressProgress(Duration.zero), 0);
      expect(longPressProgress(const Duration(milliseconds: 2500)), 0.5);
      expect(longPressProgress(const Duration(seconds: 5)), 1);
    });

    test('clamps at both ends', () {
      expect(longPressProgress(const Duration(seconds: -1)), 0);
      expect(longPressProgress(const Duration(minutes: 1)), 1);
    });
  });

  group('longPressSecondsLeft', () {
    test('counts down and stops at zero', () {
      expect(longPressSecondsLeft(Duration.zero), 5);
      expect(longPressSecondsLeft(const Duration(milliseconds: 1)), 5);
      expect(longPressSecondsLeft(const Duration(seconds: 4)), 1);
      expect(longPressSecondsLeft(const Duration(seconds: 5)), 0);
      expect(longPressSecondsLeft(const Duration(seconds: 9)), 0);
    });
  });

  group('generateMathProblem', () {
    test('both operands are always two digits', () {
      final random = Random(7);
      for (var i = 0; i < 500; i++) {
        final p = generateMathProblem(random);
        expect(p.left, inInclusiveRange(10, 99));
        expect(p.right, inInclusiveRange(10, 99));
        expect(p.answer, p.left + p.right);
      }
    });

    test('is deterministic for a given seed', () {
      expect(
        generateMathProblem(Random(1)).toString(),
        generateMathProblem(Random(1)).toString(),
      );
    });
  });

  group('pickTypingSentence', () {
    test('always returns one of the sentences', () {
      final random = Random(3);
      for (var i = 0; i < 100; i++) {
        expect(typingSentences, contains(pickTypingSentence(random)));
      }
    });

    test('the sentences are around 12 characters', () {
      for (final s in typingSentences) {
        expect(s.length, inInclusiveRange(8, 16), reason: s);
      }
    });
  });

  group('resolveWakeCheck', () {
    test('leaves a check the user actually chose alone', () {
      final random = Random(1);
      for (final type in [
        WakeCheckType.longPress,
        WakeCheckType.math,
        WakeCheckType.typing,
        WakeCheckType.shake,
      ]) {
        expect(resolveWakeCheck(type, random), type);
      }
    });

    test('draws only from checks that can be performed', () {
      final random = Random(3);
      for (var i = 0; i < 500; i++) {
        final drawn = resolveWakeCheck(WakeCheckType.random, random);
        expect(randomWakeCheckPool, contains(drawn));
        expect(drawn, isNot(WakeCheckType.random));
      }
    });

    test('reaches all four over enough draws', () {
      final random = Random(11);
      final seen = <WakeCheckType>{};
      for (var i = 0; i < 500; i++) {
        seen.add(resolveWakeCheck(WakeCheckType.random, random));
      }
      expect(seen, randomWakeCheckPool.toSet());
    });

    test('is pure given the seed', () {
      List<WakeCheckType> draw() {
        final random = Random(42);
        return [
          for (var i = 0; i < 20; i++)
            resolveWakeCheck(WakeCheckType.random, random),
        ];
      }

      expect(draw(), draw());
    });
  });
}
