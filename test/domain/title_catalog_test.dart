import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/title_catalog.dart';

void main() {
  group('composeTitle', () {
    test('joins the three words in order', () {
      expect(
        composeTitle(
          TitleCatalog.defaultPrefixId,
          TitleCatalog.defaultConnectorId,
          TitleCatalog.defaultSuffixId,
        ),
        '寝坊の常習犯',
      );
      expect(composeTitle('p_asahi', 'c_taru', 's_ou'), '朝日たる王');
      expect(composeTitle('p_futon', 'c_naru', 's_bannin'), '布団なる番人');
    });

    test('an unknown id falls back to the first word of its list', () {
      // A title written by a future build, opened by this one: it must paint
      // something rather than come out half-written.
      expect(composeTitle('from_the_future', 'c_no', 's_ou'), '寝坊の王');
      expect(composeTitle('p_asahi', 'nope', 'nope'), '朝日の常習犯');
    });

    test('the catalogue is big enough for the spec, and its ids are unique', () {
      expect(TitleCatalog.prefixes.length, greaterThanOrEqualTo(8));
      expect(TitleCatalog.connectors.length, greaterThanOrEqualTo(3));
      expect(TitleCatalog.suffixes.length, greaterThanOrEqualTo(8));

      final ids = [
        ...TitleCatalog.prefixes,
        ...TitleCatalog.connectors,
        ...TitleCatalog.suffixes,
      ].map((w) => w.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'one owned set covers all three slots');
      expect(TitleCatalog.allTitleWordIds, ids.toSet());
      expect(TitleCatalog.wordCount, ids.length);
    });
  });

  test('a fresh profile wears 寝坊の常習犯 and owns every word', () {
    const profile = Profile();
    expect(profile.title, '寝坊の常習犯');
    expect(profile.ownedTitleWordIds, TitleCatalog.allTitleWordIds);
  });
}
