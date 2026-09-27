// Social sign-in (Task B5) — pure-Dart unit tests for the mobile side:
// Gender "unspecified" handling (pre-onboarding social accounts), the
// providers response parsing, and the FLUTTER_TEST guard that keeps the
// plugin-channel calls (google_sign_in / sign_in_with_apple) inert under the
// test binding (same rule as push_service.dart — the channels hang there).
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/services/social_signin_service.dart';

void main() {
  test('Gender.unspecified parses from the API wire format', () {
    final user = User.fromJson({
      'id': 'u1',
      'name': 'সাইফুল',
      'gender': 'unspecified',
      'role': 'user',
      'category': 'general',
      'createdAt': '2025-01-01T00:00:00.000Z',
      'lastActiveAt': '2025-01-01T00:00:00.000Z',
      'email': 'saif@icloud.com',
    });
    expect(user.gender, Gender.unspecified);
    expect(user.gender.needsCompletion, isTrue);
    expect(user.gender.json, 'unspecified');
    expect(user.email, 'saif@icloud.com');
    expect(user.phone, isNull);

    // M/F still round-trip for normal accounts.
    expect(GenderJson.fromJson('M'), Gender.m);
    expect(GenderJson.fromJson('F'), Gender.f);
    expect(Gender.m.needsCompletion, isFalse);
    expect(Gender.f.needsCompletion, isFalse);
  });

  test('AuthProviders.fromJson — all-off defaults for a legacy/offline server', () {
    final p = AuthProviders.fromJson({});
    expect(p.google, isFalse);
    expect(p.apple, isFalse);

    final on = AuthProviders.fromJson({'google': true, 'apple': true});
    expect(on.google, isTrue);
    expect(on.apple, isTrue);
  });

  test('FLUTTER_TEST guard: the social adapters are inert under the test binding', () {
    // Plugin channels never resolve under `flutter test` — the service must
    // report itself unavailable instead of hanging the sign-in flow.
    expect(SocialSignInService.instance.googleAvailable, isFalse);
    expect(SocialSignInService.instance.appleAvailable, isFalse);
  });

  test('SocialSignInCanceled is a distinct, non-error outcome type', () {
    // The auth screen treats it as "user closed the sheet" (silent), not an
    // ApiException to display.
    expect(SocialSignInCanceled() is ApiException, isFalse);
  });
}
