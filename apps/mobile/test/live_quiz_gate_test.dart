// The live quiz room is per usrah (the API refuses a member without one):
// such a member is shown the way in, not an "Enter" that ends in a 400.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/live_quiz_screen.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a member without an usrah sees "join an usrah"', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(GoldenSignedInDaee.new)],
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const LiveQuizScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.tr(Lang.bn, 'live_quiz_no_usrah_hint')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'more_usrah_join')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'live_quiz_enter')), findsNothing);
  });
}
