// NAV-03: the Foundation's notices show in the bell panel — for guests too.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/shared/notifications_sheet.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart' show foundationAnnouncementsProvider;

import 'golden_fixtures.dart';

class _Guest extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.guest);
}

void main() {
  testWidgets('a guest sees the Foundation notice under the prayer alert', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(_Guest.new),
        prayerProvider.overrideWith(GoldenPinnedPrayer.new),
        foundationAnnouncementsProvider.overrideWith((ref) async => [
          Announcement.fromJson({
            'id': 'a1',
            'authorId': 'x',
            'kind': 'announcement',
            'body': 'আগামী শুক্রবার জাতীয় দাওয়াহ সম্মেলন',
            'pinned': true,
            'createdAt': '2026-10-04T05:00:00Z',
          }),
        ]),
      ],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(onPressed: () => showNotificationsSheet(c), child: const Text('open')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notif_prayer_alert')), findsOneWidget);
    expect(find.text('ফাউন্ডেশনের ঘোষণা'), findsOneWidget);
    expect(find.text('আগামী শুক্রবার জাতীয় দাওয়াহ সম্মেলন'), findsOneWidget);
  });
}
