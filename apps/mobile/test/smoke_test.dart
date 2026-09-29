// Smoke test — the app boots through the real bootstrap path (Drift DB +
// profile hydration + go_router shell) and the bottom nav renders the
// 5 tabs for a daee (Da'wah branch visible) and 4 tabs for a guest
// (Da'wah hidden for role < daee).
//
// C-W4a: the stock Material NavigationBar was replaced by the token-built
// SLBottomBar — the assertions were updated from NavigationBar/
// NavigationDestination to SLBottomBar/SLBottomBarItem (same localized
// label expectations, unchanged).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/features/shared/sl_bottom_bar.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';

/// Signed-in daee session without touching the network or SharedPreferences.
class _DaeeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    user: User(
      id: 'u-smoke-daee',
      name: 'রাফিউল ইসলাম',
      gender: Gender.m,
      role: Role.daee,
      category: UserCategory.general,
      memberCode: 'DS-000004',
      level: Level.muhibbusSunnah,
      createdAt: '2025-01-01T00:00:00.000Z',
      lastActiveAt: '2025-01-01T00:00:00.000Z',
    ),
  );
}

Future<AppDatabase> _seededDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.guestProfile(); // create the single row
  await db.saveGuestProfile(
    const GuestProfilesCompanion(onboardingDone: Value(true)),
  );
  return db;
}

Future<ProviderContainer> _boot(WidgetTester tester, AppDatabase db,
    {List<Override> extra = const []}) async {
  final container = ProviderContainer(
    overrides: [dbProvider.overrideWithValue(db), ...extra],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const BootstrapGate(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Dispose inside the test body so every provider timer (prayer ticker,
/// 60s sync flush) is cancelled before the binding checks pending timers.
Future<void> _shutdown(ProviderContainer container) async =>
    container.dispose();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Mirror production main(): never fetch fonts at runtime in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('app boots — daee sees all 5 bottom-nav tabs', (tester) async {
    final db = await _seededDb();
    addTearDown(db.close);

    final container = await _boot(
      tester,
      db,
      extra: [authProvider.overrideWith(_DaeeAuthNotifier.new)],
    );

    expect(find.byType(SLBottomBar), findsOneWidget);
    expect(find.byType(SLBottomDestination), findsNWidgets(5));
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('আমল'), findsOneWidget);
    expect(find.text('দাওয়াত'), findsOneWidget);
    expect(find.text('ইলম'), findsOneWidget);
    expect(find.text('আরও'), findsOneWidget);

    await _shutdown(container);
  });

  testWidgets('app boots — guest sees 4 tabs (Da\'wah hidden)', (tester) async {
    final db = await _seededDb();
    addTearDown(db.close);

    final container = await _boot(tester, db);

    expect(find.byType(SLBottomBar), findsOneWidget);
    expect(find.byType(SLBottomDestination), findsNWidgets(4));
    expect(find.text('দাওয়াত'), findsNothing);
    expect(find.text('আরও'), findsOneWidget);

    await _shutdown(container);
  });
}
