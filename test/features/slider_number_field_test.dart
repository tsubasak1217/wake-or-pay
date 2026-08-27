import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/features/alarms/edit_sub_screens.dart';
import 'package:wake_or_pay/features/alarms/widgets/slider_number_field.dart';

const _fieldKey = ValueKey('sliderNumberInput');

/// Hosts the widget the way a sub-screen does: the value is state above it.
Future<int Function()> _pumpField(
  WidgetTester tester, {
  int initial = 5,
  int min = 1,
  int max = 30,
}) async {
  var value = initial;
  late void Function(void Function()) rebuild;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                SliderNumberField(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: (v) => rebuild(() => value = v),
                ),
                // Somewhere else for the focus to go.
                const TextField(key: ValueKey('elsewhere')),
              ],
            );
          },
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return () => value;
}

void main() {
  testWidgets('typing a number moves the slider with it', (tester) async {
    final read = await _pumpField(tester);

    await tester.enterText(find.byKey(_fieldKey), '17');
    await tester.pumpAndSettle();

    expect(read(), 17);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 17.0);
  });

  testWidgets('text that is not a number is ignored, keeping the last value', (
    tester,
  ) async {
    final read = await _pumpField(tester, initial: 8);

    // Clearing the field is the everyday case: it must not read as zero and
    // snap the slider to the minimum while the user is mid-edit.
    await tester.enterText(find.byKey(_fieldKey), '');
    await tester.pumpAndSettle();
    expect(read(), 8);

    // The formatter strips letters, so this arrives as an empty string too.
    await tester.enterText(find.byKey(_fieldKey), 'abc');
    await tester.pumpAndSettle();
    expect(read(), 8);
  });

  testWidgets('a number outside the range is clamped, not rejected', (
    tester,
  ) async {
    final read = await _pumpField(tester, initial: 5, min: 1, max: 30);

    await tester.enterText(find.byKey(_fieldKey), '9999');
    await tester.pumpAndSettle();
    expect(read(), 30);

    await tester.enterText(find.byKey(_fieldKey), '0');
    await tester.pumpAndSettle();
    expect(read(), 1);
  });

  testWidgets('leaving the field tidies the text back to the clamped value', (
    tester,
  ) async {
    await _pumpField(tester, initial: 5, min: 1, max: 30);

    await tester.enterText(find.byKey(_fieldKey), '9999');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(_fieldKey)).controller!.text,
      '9999',
      reason: 'not rewritten under the caret',
    );

    // Moving the focus somewhere else tidies it to what was accepted.
    await tester.tap(find.byKey(const ValueKey('elsewhere')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(_fieldKey)).controller!.text,
      '30',
    );
  });

  testWidgets('a number sub-screen commits once, when it closes', (
    tester,
  ) async {
    final commits = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => pushEditorSubScreen(
                  context,
                  NumberSubScreen(
                    title: 'テスト',
                    initial: 5,
                    min: 1,
                    max: 30,
                    suffix: '分',
                    onCommit: commits.add,
                  ),
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_fieldKey), '11');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_fieldKey), '12');
    await tester.pumpAndSettle();
    expect(commits, isEmpty, reason: 'nothing is decided while it is open');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(commits, [12]);
  });
}
