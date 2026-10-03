// Taka amounts are grouped the South-Asian way (lakh / crore), then shown in
// Bengali digits — the zakat screen used to print ৳১৪০২৫০০.
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/core/bn_digits.dart';

void main() {
  test('groupLakh groups last three digits, then pairs', () {
    expect(groupLakh(0), '0');
    expect(groupLakh(999), '999');
    expect(groupLakh(1000), '1,000');
    expect(groupLakh(35062), '35,062');
    expect(groupLakh(1402500), '14,02,500');
    expect(groupLakh(123456789), '12,34,56,789');
    expect(groupLakh(-1402500), '-14,02,500');
  });

  test('grouped amounts convert to Bengali digits', () {
    expect(toBn(groupLakh(1402500)), '১৪,০২,৫০০');
  });
}
