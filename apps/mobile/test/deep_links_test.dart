// Deep-link route table tests (Task B2).
//
// deepLinkToRoute maps `sunnahlife://…` push payloads (the server embeds
// DEEP_LINKS from apps/api/src/push/deep-links.ts into FCM data.deepLink) to
// in-app go_router paths. These tests pin BOTH halves of the contract:
//   1. the canonical URI strings themselves (mirror of the API table — if
//      either side renames a link, this file fails), and
//   2. the mapping/whitelisting behavior (unknown links never navigate).
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/deep_links.dart';

void main() {
  group('DeepLinks constants (mirror of apps/api DEEP_LINKS)', () {
    test('canonical URIs use the sunnahlife scheme and stable paths', () {
      expect(DeepLinks.home, 'sunnahlife://home');
      expect(DeepLinks.amal, 'sunnahlife://amal');
      expect(DeepLinks.amalMonth, 'sunnahlife://amal/month');
      expect(DeepLinks.dawah, 'sunnahlife://dawah');
      expect(DeepLinks.reviews, 'sunnahlife://reviews');
      expect(DeepLinks.usrah, 'sunnahlife://usrah');
      expect(DeepLinks.live, 'sunnahlife://live');
      expect(DeepLinks.quran, 'sunnahlife://quran');
      expect(DeepLinks.more, 'sunnahlife://more');
      expect(DeepLinks.report, 'sunnahlife://report');
      expect(DeepLinks.liveProgram('abc123'), 'sunnahlife://live/abc123');
      expect(kSunnahDeepLinkScheme, 'sunnahlife');
    });
  });

  group('deepLinkToRoute — canonical links', () {
    const cases = <String, String?>{
      'sunnahlife://home': '/',
      'sunnahlife://amal': '/amal',
      'sunnahlife://amal/month': '/amal/month',
      'sunnahlife://dawah': '/dawah',
      // Reviews + usrah announcements both live in the Dawah tab.
      'sunnahlife://reviews': '/dawah',
      'sunnahlife://usrah': '/dawah',
      'sunnahlife://live': '/more/live',
      'sunnahlife://live/abc123': '/more/live',
      'sunnahlife://quran': '/ilm/quran',
      'sunnahlife://more': '/more',
      'sunnahlife://report': '/more',
    };
    for (final entry in cases.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(deepLinkToRoute(entry.key), entry.value);
      });
    }
  });

  group('deepLinkToRoute — guards', () {
    test('null / empty → null (never navigates)', () {
      expect(deepLinkToRoute(null), isNull);
      expect(deepLinkToRoute(''), isNull);
    });

    test('foreign schemes are rejected', () {
      expect(deepLinkToRoute('https://evil.example.com/amal'), isNull);
      expect(deepLinkToRoute('intent://amal'), isNull);
      expect(deepLinkToRoute('sunnahlifeevil://amal'), isNull);
    });

    test('unknown sunnahlife hosts fall through to the path whitelist', () {
      expect(deepLinkToRoute('sunnahlife://anything'), isNull);
      expect(deepLinkToRoute('sunnahlife://settings/deep/stuff'), isNull);
    });

    test('plain in-app paths pass only when whitelisted', () {
      // In-app notification payloads use plain router paths.
      expect(deepLinkToRoute('/amal'), '/amal');
      expect(deepLinkToRoute('/more/live'), '/more/live');
      expect(deepLinkToRoute('/ilm/quran'), '/ilm/quran');
      // Non-whitelisted bases never navigate.
      expect(deepLinkToRoute('/settings'), isNull);
      expect(deepLinkToRoute('/onboarding'), isNull);
      expect(deepLinkToRoute('amal'), isNull); // no leading slash
      expect(deepLinkToRoute('//amal'), isNull);
    });
  });
}
