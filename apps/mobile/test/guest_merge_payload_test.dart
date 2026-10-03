// Sign-in carries the guest diary along — only rows the server can merge.
// A cleared row ('' / null) used to fail the WHOLE sign-in ("Bad Request").
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/models/domain.dart';

AmalEntry _e(Object? value, {String date = '2026-10-03'}) => AmalEntry(
  amalKey: 'k',
  date: date,
  clientUpdatedAt: '2026-10-03T08:00:00Z',
  value: value,
  source: 'manual',
);

void main() {
  test('cleared, odd and malformed rows stay home', () {
    final sent = sendableGuestEntries([
      _e('jamaat'),
      _e(true),
      _e(3),
      _e(''), // a cleared tristate
      _e(null),
      _e(double.nan),
      _e(['a']),
      _e('jamaat', date: '3-10-2026'),
    ]);
    expect(sent.map((m) => m['value']), ['jamaat', true, 3]);
  });
}
