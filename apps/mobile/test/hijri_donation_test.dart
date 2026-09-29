// C-W3g — Hijri adjustment + donation link (pure logic; no plugins):
//   1. effectiveHijriAdjust — the user ±2 (profile) + admin ±2 (/api/config)
//      sum, clamped to ±4;
//   2. offline nisab fallback parity — the constants in remote_state.dart
//      must equal the committed packages/content/app-config.json (what the
//      server actually serves via GET /api/config) — drift fails this test;
//   3. isLaunchableHttpUrl — the donation CTA / More-tile gating decision.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/calendars.dart';
import 'package:sunnah_life/core/external_urls.dart';
import 'package:sunnah_life/state/remote_state.dart';

void main() {
  group('effectiveHijriAdjust — user ±2 + admin ±2, clamped ±4', () {
    const matrix = <(int, int, int)>[
      // (user, admin, expected)
      (0, 0, 0),
      (1, 0, 1),
      (0, 1, 1),
      (-1, -1, -2),
      (2, 2, 4),
      (-2, -2, -4),
      (2, -2, 0), // opposite corrections cancel
      (-2, 2, 0),
      (1, -2, -1),
      // clamping: the ±2 sources can hold values outside their nominal range
      // (a stale server or restored profile) — the sum never exceeds ±4.
      (2, 3, 4),
      (-2, -4, -4),
      (5, 5, 4),
      (-5, 5, 0),
      (-9, 9, 0),
      (3, -8, -4),
    ];
    for (final (user, admin, expected) in matrix) {
      test('user $user + admin $admin → $expected', () {
        expect(effectiveHijriAdjust(user, admin), expected);
      });
    }

    test('every in-range pair stays within ±4 without change', () {
      for (var u = -2; u <= 2; u++) {
        for (var a = -2; a <= 2; a++) {
          final e = effectiveHijriAdjust(u, a);
          expect(e, u + a); // in-range sums never hit the clamp
          expect(e.abs(), lessThanOrEqualTo(4));
        }
      }
    });
  });

  group('offline nisab fallback parity with packages/content/app-config.json',
      () {
    test('fallback constants equal the committed pack values', () {
      // `flutter test` runs with CWD = apps/mobile.
      final file = File('../../packages/content/app-config.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'pack file missing — has it moved? (mobile reads it only in '
            'this test; the app itself gets the values from GET /api/config)',
      );
      final j =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final nisab = j['nisab'] as Map<String, dynamic>;

      // num vs double: compare numerically so 16500 (int in JSON) matches
      // the double constant.
      expect(
        (nisab['goldPerGramBdt'] as num).toDouble(),
        kFallbackGoldPerGramBdt,
        reason: 'offline gold fallback drifted from the committed pack — '
            'update kFallbackGoldPerGramBdt in remote_state.dart',
      );
      expect(
        (nisab['silverPerGramBdt'] as num).toDouble(),
        kFallbackSilverPerGramBdt,
        reason: 'offline silver fallback drifted from the committed pack — '
            'update kFallbackSilverPerGramBdt in remote_state.dart',
      );
      expect(
        j['donationUrl'] as String?,
        kFallbackDonationUrl,
        reason: 'offline donation URL drifted from the committed pack — '
            'update kFallbackDonationUrl in remote_state.dart',
      );
    });
  });

  group('isLaunchableHttpUrl — donation URL gating', () {
    const cases = <String, bool>{
      '': false, // empty config → affordance hidden
      '   ': false, // whitespace-only
      'as-sunnah.org/donation': false, // scheme-less
      'https://as-sunnah.org/donation': true,
      'http://as-sunnah.org/donation': true,
      'HTTPS://as-sunnah.org/donation': true, // scheme is case-insensitive
      '  https://as-sunnah.org/donation  ': true, // trimmed
      'javascript:alert(1)': false,
      'intent://as-sunnah.org/#Intent': false,
      'ftp://as-sunnah.org/donation': false,
      'mailto:info@as-sunnah.org': false,
      'sunnahlife://home': false, // our own scheme — never a browser target
      'content://provider/secret': false,
    };
    for (final entry in cases.entries) {
      test('${entry.key.isEmpty ? '(empty)' : entry.key} → ${entry.value}',
          () {
        expect(isLaunchableHttpUrl(entry.key), entry.value);
      });
    }
  });
}
