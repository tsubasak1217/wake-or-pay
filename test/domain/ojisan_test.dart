import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/ojisan.dart';

void main() {
  const lunch = 'ありがとうございます。あなたのおかげで今日も昼飯が食えます。';
  const shoes = 'おかげさまで新しい靴買えました。';
  const moved = 'おかげさまで引っ越しました。';
  const quit = 'おかげさまで会社を辞めました。';

  group('ojisanLine', () {
    test('1-2 oversleeps: lunch', () {
      expect(ojisanLine(1), lunch);
      expect(ojisanLine(2), lunch);
    });

    test('3-9 oversleeps: shoes', () {
      expect(ojisanLine(3), shoes);
      expect(ojisanLine(9), shoes);
    });

    test('10-19 oversleeps: moved house', () {
      expect(ojisanLine(10), moved);
      expect(ojisanLine(19), moved);
    });

    test('20+ oversleeps: quit his job', () {
      expect(ojisanLine(20), quit);
      expect(ojisanLine(1000), quit);
    });

    test('degenerate counts fall back to the first line', () {
      expect(ojisanLine(0), lunch);
      expect(ojisanLine(-1), lunch);
    });
  });
}
