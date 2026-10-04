// The privacy policy link opens the website that belongs to the API the app
// talks to: production shares one origin; staging's API is api-<site>.
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/external_urls.dart';

void main() {
  test('production: the API origin is the site', () {
    expect(webBaseFor('https://sunnahlife.app'), 'https://sunnahlife.app');
  });
  test('staging: api-staging.<domain> → staging.<domain>', () {
    expect(
      webBaseFor('https://api-staging.sunnahlife.ailearnersbd.com'),
      'https://staging.sunnahlife.ailearnersbd.com',
    );
  });
  test('api.<domain> → <domain>', () {
    expect(webBaseFor('https://api.example.org'), 'https://example.org');
  });
}
