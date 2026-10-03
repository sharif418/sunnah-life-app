// The madu avatar letter skips honorific prefixes ("মোঃ সাইফুল" → সা).
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/features/dawah/madu_tree.dart' show maduInitial;

void main() {
  test('honorific prefixes are skipped', () {
    expect(maduInitial('মোঃ সাইফুল ইসলাম'), 'সা');
    expect(maduInitial('মুহাম্মদ আব্দুল্লাহ'), 'আ');
    expect(maduInitial('Md. Rafiul Islam'), 'R');
  });

  test('plain names use their first letter (whole grapheme)', () {
    expect(maduInitial('আব্দুল্লাহ আল মামুন'), 'আ');
    expect(maduInitial('ফাতিমা আক্তার'), 'ফা');
    expect(maduInitial('  '), '?');
    expect(maduInitial('মোঃ'), 'মোঃ');
  });
}
