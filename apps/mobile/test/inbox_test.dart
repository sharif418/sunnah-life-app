// The header bell's personal inbox: message kinds only (not self-set live /
// detox reminders, not future-scheduled ones), unread first-class, a dot on
// the bell while anything is unread, tap = mark read.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/shared/notifications_sheet.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart'
    show inboxProvider, inboxUnreadProvider, liveProvider, usrahProvider;

import 'golden_fixtures.dart';

ReminderItem _r(String id, String kind, {bool read = false, String? at}) => ReminderItem.fromJson({
  'id': id,
  'kind': kind,
  'title': 'শিরোনাম $id',
  'body': 'বিস্তারিত $id',
  'read': read,
  'scheduledAt': ?at,
  'createdAt': '2026-10-0${id.length}T08:00:00.000Z',
});

class _Api extends ApiClient {
  _Api(this.items);
  final List<ReminderItem> items;
  final read = <String>[];

  @override
  Future<List<ReminderItem>> reminders() async => items;

  @override
  Future<void> readReminder(String id) async => read.add(id);
}

void main() {
  final rows = [
    _r('a', 'review'),
    _r('bb', 'goal', read: true),
    _r('ccc', 'live'), // self-set reminder — not a message
    _r('dddd', 'assessment', at: DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String()),
    _r('eeeee', 'detox'),
  ];

  test('message kinds whose time has come; unread counted', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      authProvider.overrideWith(GoldenSignedInDaee.new),
      apiProvider.overrideWithValue(_Api(rows)),
    ]);
    addTearDown(c.dispose);
    c.listen(inboxProvider, (_, _) {});
    final inbox = await c.read(inboxProvider.future);
    expect(inbox!.map((r) => r.id), ['bb', 'a']); // newest first
    expect(c.read(inboxUnreadProvider), 1);
  });

  testWidgets('the sheet shows আপনার জন্য; tapping marks read', (tester) async {
    final api = _Api(rows);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showNotificationsSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(path: '/dawah', builder: (_, _) => const Scaffold(body: Text('dawah-screen'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(GoldenSignedInDaee.new),
        apiProvider.overrideWithValue(api),
        usrahProvider.overrideWith((ref) async => null),
        liveProvider.overrideWith((ref) async => const []),
        prayerProvider.overrideWith(GoldenPinnedPrayer.new),
      ],
      child: MaterialApp.router(theme: buildSunnahLightTheme(), routerConfig: router),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // NAV-03: the prayer alert leads the panel
    expect(find.byKey(const ValueKey('notif_prayer_alert')), findsOneWidget);
    expect(find.textContaining('পরবর্তী:'), findsOneWidget);
    expect(find.text('আপনার জন্য'), findsOneWidget);
    expect(find.text('শিরোনাম a'), findsOneWidget);
    expect(find.text('শিরোনাম bb'), findsOneWidget);
    expect(find.text('শিরোনাম ccc'), findsNothing);
    expect(find.text('শিরোনাম dddd'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('inbox_a')));
    await tester.pumpAndSettle();
    expect(api.read, ['a']);
    expect(find.text('dawah-screen'), findsOneWidget);
  });
}
