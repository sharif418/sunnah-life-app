import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/core/mosque_format.dart';

void main() {
  test('metres under a kilometre, one decimal under ten', () {
    expect(distanceLabel(243), '২৪০ মিটার');
    expect(distanceLabel(4), '১০ মিটার');
    expect(distanceLabel(996), '৯৯০ মিটার');
    expect(distanceLabel(1430), '১.৪ কিমি');
    expect(distanceLabel(12400), '১২ কিমি');
    expect(distanceLabel(1430, bengali: false), '1.4 km');
  });

  test('walking time only where walking is the answer', () {
    expect(walkLabel(240), 'হেঁটে ~৩ মিনিট');
    expect(walkLabel(2950), 'হেঁটে ~৩৭ মিনিট');
    expect(walkLabel(3200), isNull);
  });

  test('eight directions, in the locative', () {
    expect(directionWord(0), 'উত্তরে');
    expect(directionWord(44), 'উত্তর-পূর্বে');
    expect(directionWord(181), 'দক্ষিণে');
    expect(directionWord(-90), 'পশ্চিমে');
    expect(directionWord(350), 'উত্তরে');
  });
}
