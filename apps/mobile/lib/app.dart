/// App root: ProviderScope bootstrap → MaterialApp.router with the token
/// themes, locale bn/en/ar (manual string table), RTL for Arabic, and a
/// go_router StatefulShellRoute with the 5 tabs (হোম / আমল / দাওয়াত / ইলম /
/// আরও).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/phosphor_icons.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'catalog/kit_gallery.dart';
import 'design/design_tokens.dart';
import 'core/bell_schedule.dart';
import 'core/referral.dart';
import 'features/amal/goals_screen.dart';
import 'features/amal/habit_screen.dart';
import 'features/amal/month_screen.dart';
import 'features/amal/self_test_screen.dart';
import 'features/amal/today_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/guest_nudge.dart' show syncGuestNudgeReminder;
import 'features/dawah/dawah_requirements_screen.dart';
import 'features/dawah/dawah_screen.dart';
import 'features/dawah/usrah_questions_screen.dart';
import 'features/home/home_screen.dart';
import 'features/ilm/adhkar_screen.dart';
import 'features/ilm/articles_screen.dart';
import 'features/ilm/courses_screen.dart';
import 'features/ilm/duas_screen.dart';
import 'features/ilm/iman_branches_screen.dart';
import 'features/ilm/islamic_names_screen.dart';
import 'features/ilm/ilm_search_screen.dart';
import 'features/ilm/ilm_screen.dart';
import 'features/ilm/live_quiz_screen.dart';
import 'features/ilm/names99_screen.dart';
import 'features/ilm/quran_reader_screen.dart';
import 'features/ilm/quizzes_screen.dart';
import 'features/ilm/sunnahs_screen.dart';
import 'features/more/about_screen.dart';
import 'features/more/auto_silent_screen.dart';
import 'features/more/detox_screen.dart';
import 'features/more/faq_screen.dart';
import 'features/more/live_screen.dart';
import 'features/more/masala_screen.dart';
import 'features/more/more_screen.dart';
import 'features/more/mosques_screen.dart';
import 'features/more/profile_screen.dart';
import 'features/more/qibla_screen.dart';
import 'features/more/support_screen.dart';
import 'features/more/zakat_screen.dart';
import 'features/onboarding/gender_completion_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shared/contact_fab.dart';
import 'features/shared/sl_bottom_bar.dart';
import 'features/shared/widgets.dart';
import 'l10n/app_strings.dart';
import 'l10n/generated/app_localizations.dart';
import 'models/domain.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/app_link_service.dart';
import 'models/content_models.dart' show ContentPack;
import 'state/amal_state.dart';
import 'state/prayer_state.dart';
import 'state/providers.dart';
import 'state/referral_state.dart';

/// Single-flight bootstrap: read the persisted guest profile before the
/// router mounts so the onboarding redirect never races hydration.
final bootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(dbProvider);
  final row = await db.guestProfile();
  ref.read(profileProvider.notifier).hydrateFrom(row);
  // Offline-first background sync: 60s outbox flush (see SyncNotifier).
  ref.read(syncProvider.notifier).startPeriodicFlush();
  // The admin-editable content packs (duas, articles, FAQ, mosques,
  // quizzes) load from the server first, so a CMS edit reaches the app.
  ContentPack.remote = (key) => ref.read(apiProvider).contentPackData(key);
  // Post-prayer জামাতে/একা/কাযা action taps that reach the FOREGROUND
  // callback go through the same Riverpod flow as the in-app prompt
  // (optimistic state + shared DB connection + debounced sync flush);
  // taps while the app is dead are handled on the plugin's background
  // isolate by handleAmalNotificationAction.
  NotificationService.instance.onAmalAction = (actionId, payload) async {
    final value = kAmalActionValues[actionId];
    if (value == null) return;
    await ref
        .read(amalProvider.notifier)
        .write(
          payload.amalKey,
          payload.dateKey,
          value,
          autoSourceFromAmalKey(payload.amalKey) ?? 'manual',
        );
  };
  // Push (B2): FCM handlers + deep-link navigation; registration follows the
  // auth session. Everything degrades to local-only when Firebase is
  // unavailable (placeholder options / no Play Services / widget tests).
  await PushService.instance.ensureInitialized(
    onNavigate: (route) => ref.read(routerProvider).go(route),
  );
  ref.watch(pushRegistrationProvider);
  ref.watch(guestNudgeReminderProvider);
  // C-W3h: /join deep links (cold start + warm stream) → the pending
  // referral store; the auth screen surfaces the chip and rides the code
  // along on sign-in. Idempotent writes; failures swallowed inside.
  await AppLinkService.instance.ensureInitialized(
    onReferralCode: (code) async {
      final prefs = await SharedPreferences.getInstance();
      await PendingReferralStore(prefs).write(code);
      ref.invalidate(pendingReferralProvider);
    },
  );
});

/// Push registration lifecycle: register the FCM token when signed in,
/// unregister on sign-out. Watches the session; fireImmediately covers the
/// restored-session boot case.
final pushRegistrationProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authProvider, (prev, next) {
    final wasIn = prev?.status == AuthStatus.signedIn;
    final signedIn = next.status == AuthStatus.signedIn;
    if (wasIn == signedIn && prev != null) return; // no-op flip
    unawaited(
      PushService.instance.syncRegistration(
        api: ref.read(apiProvider),
        signedIn: signedIn,
      ),
    );
  }, fireImmediately: true);
});

/// The weekly guest sign-up reminder follows the session: scheduled while a
/// guest, cancelled on sign-in.
final guestNudgeReminderProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.status == AuthStatus.loading) return;
    if (prev != null && prev.status == next.status) return;
    unawaited(syncGuestNudgeReminder(guest: next.status == AuthStatus.guest));
  }, fireImmediately: true);
});

/// Bridges riverpod changes into GoRouter's refreshListenable.
class _RiverpodListenable extends ChangeNotifier {
  _RiverpodListenable(Ref ref) {
    ref.listen(profileProvider, (_, _) => notifyListeners());
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}

/// W4f: the shared pushed-route transition — fade-through on the motion
/// tokens (one helper, no per-route ad-hoc). The shell branches (the five
/// tabs) stay instant by design.
CustomTransitionPage<T> slFadePage<T>({
  required Widget child,
  Object? arguments,
  String? name,
}) {
  return CustomTransitionPage<T>(
    arguments: arguments,
    name: name,
    transitionDuration: SLMotion.base,
    reverseTransitionDuration: SLMotion.fast,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: SLMotion.decelerate,
        reverseCurve: SLMotion.accelerate,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    child: child,
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _RiverpodListenable(ref);
  ref.onDispose(listenable.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final profile = ref.read(profileProvider);
      final loc = state.matchedLocation;
      final onOnboarding = loc == '/onboarding';
      if (!profile.onboardingDone) return onOnboarding ? null : '/onboarding';
      if (onOnboarding) return '/';
      // Social-sign-in accounts created without gender (Task B5): complete
      // the one-time gender+name step before anything else. The refresh
      // listener re-fires on the auth change, so finishing it lands on '/'.
      final auth = ref.read(authProvider);
      if (auth.userOrNull != null && auth.userOrNull!.gender.needsCompletion) {
        return loc == '/complete-profile' ? null : '/complete-profile';
      }
      // Da'wah engine is daee+ territory — hide the branch for everyone
      // else (the tab disappears too; the screen itself also gates).
      if (loc.startsWith('/dawah') &&
          !(auth.userOrNull?.canSeeDawah ?? false)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const GenderCompletionScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (c, s) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/amal',
                builder: (c, s) => const AmalHubScreen(),
                routes: [
                  GoRoute(
                    path: 'month',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const MonthGridScreen()),
                  ),
                  GoRoute(
                    path: 'habit',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const HabitBuilderScreen()),
                  ),
                  GoRoute(
                    path: 'self-test',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const SelfTestScreen()),
                  ),
                  // W4c: আমার লক্ষ্য — personal-goal lifecycle (propose →
                  // head approval → status chips).
                  GoRoute(
                    path: 'goals',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const GoalsScreen()),
                  ),
                  // AMOL-15: the usrah question board belongs to the আমল
                  // page's কুইজ ও পরীক্ষা — every usrah MEMBER reaches it here
                  // (under /dawah it was da'ee-only, so plain members never
                  // could). The API already scopes it to the user's usrah.
                  GoRoute(
                    path: 'questions',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const UsrahQuestionsScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dawah',
                builder: (c, s) => const DawahScreen(),
                routes: [
                  // B9: usrah question board + live level checklist (mobile
                  // parity with the web views).
                  GoRoute(
                    path: 'questions',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const UsrahQuestionsScreen()),
                  ),
                  GoRoute(
                    path: 'requirements',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const DawahRequirementsScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ilm',
                builder: (c, s) => const IlmScreen(),
                routes: [
                  // B9: courses + self-paced quizzes + live usrah quiz.
                  GoRoute(
                    path: 'courses',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const CoursesScreen()),
                    routes: [
                      GoRoute(
                        path: ':courseId',
                        pageBuilder: (c, s) => slFadePage(
                          child: CourseDetailScreen(
                            courseId: s.pathParameters['courseId'] ?? '',
                            openLessonId: s.uri.queryParameters['lesson'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'quizzes',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const QuizzesScreen()),
                    routes: [
                      GoRoute(
                        path: ':quizId',
                        pageBuilder: (c, s) => slFadePage(
                          child: QuizPlayerScreen(
                            quizId: s.pathParameters['quizId'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'live-quiz',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const LiveQuizScreen()),
                  ),
                  GoRoute(
                    path: 'quran',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const QuranReaderScreen()),
                  ),
                  GoRoute(
                    path: 'adhkar',
                    pageBuilder: (c, s) => slFadePage(
                      child: AdhkarScreen(focus: s.uri.queryParameters['set']),
                    ),
                  ),
                  // W4j: the unified content search — the Ilm tab's entry
                  // (public + its own offline fallback over the bundled packs).
                  GoRoute(
                    path: 'search',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const IlmSearchScreen()),
                  ),
                  GoRoute(path: 'duas', builder: (c, s) => const DuasScreen()),
                  GoRoute(
                    path: 'names99',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const Names99Screen()),
                  ),
                  GoRoute(
                    path: 'islamic-names',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const IslamicNamesScreen()),
                  ),
                  GoRoute(
                    path: 'iman-branches',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const ImanBranchesScreen()),
                  ),
                  GoRoute(
                    path: 'sunnahs',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const SunnahsScreen()),
                  ),
                  GoRoute(
                    path: 'articles',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const ArticlesScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (c, s) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'zakat',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const ZakatScreen()),
                  ),
                  GoRoute(
                    path: 'qibla',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const QiblaScreen()),
                  ),
                  GoRoute(
                    path: 'autosilent',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const AutoSilentScreen()),
                  ),
                  // W4d: সোশ্যাল মিডিয়া ডিটক্স — Guard-module seed (the
                  // More tile itself is config-gated; the screen also gates).
                  GoRoute(
                    path: 'detox',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const DetoxScreen()),
                  ),
                  // W4d: জিজ্ঞাসা (FAQ) — bundled faq.json, expandable.
                  GoRoute(path: 'faq', builder: (c, s) => const FaqScreen()),
                  GoRoute(
                    path: 'mosques',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const MosquesScreen()),
                  ),
                  GoRoute(
                    path: 'masala',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const MasalaScreen()),
                  ),
                  GoRoute(path: 'live', builder: (c, s) => const LiveScreen()),
                  // W4d: লাইভ সাপোর্ট — own threads + the conversation view
                  // (guest → sign-in gate inside the screen).
                  GoRoute(
                    path: 'support',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const SupportScreen()),
                    routes: [
                      GoRoute(
                        path: ':threadId',
                        pageBuilder: (c, s) => slFadePage(
                          child: SupportThreadScreen(
                            id: s.pathParameters['threadId'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'about',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const AboutScreen()),
                  ),
                  GoRoute(
                    path: 'profile',
                    pageBuilder: (c, s) =>
                        slFadePage(child: const ProfileScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // W4f — the designer's kit gallery. Debug/profile builds only: the
      // route never exists in release (tree-shaken — nothing inside the
      // gallery can ship), and nothing in the UI links to it. Open by
      // pushing '/__gallery' in a debug run (see lib/catalog/kit_gallery.dart).
      if (!kReleaseMode)
        GoRoute(
          path: '/__gallery',
          pageBuilder: (c, s) => slFadePage(child: const KitGalleryScreen()),
        ),
    ],
  );
});

class SunnahLifeApp extends ConsumerStatefulWidget {
  const SunnahLifeApp({super.key});

  @override
  ConsumerState<SunnahLifeApp> createState() => _SunnahLifeAppState();
}

class _SunnahLifeAppState extends ConsumerState<SunnahLifeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background (possibly after days): the rolling bell
    // window may have gone stale — re-arm it (idempotent per day).
    if (state == AppLifecycleState.resumed) {
      ref.read(prayerProvider.notifier).refreshBells();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final lang = LangX.fromCode(profile.language);
    final themeMode = switch (profile.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp.router(
      title: 'সুন্নাহ লাইফ',
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.app_title ?? 'সুন্নাহ লাইফ',
      debugShowCheckedModeBanner: false,
      theme: buildSunnahLightTheme(),
      darkTheme: buildSunnahDarkTheme(),
      themeMode: themeMode,
      // bn/en/ar with the generated AppLocalizations as the single source
      // (ARB files in lib/l10n, Bengali template). RTL comes from the locale
      // itself — Arabic flips the whole tree, and the language switcher in
      // profile rebuilds this immediately (no restart).
      locale: lang.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Splash while the local DB read completes (sub-frame on real devices).
class BootstrapGate extends ConsumerWidget {
  const BootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);
    return boot.when(
      loading: () => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: SLColors.primary,
          alignment: Alignment.center,
          child: const _SplashLogo(),
        ),
      ),
      error: (e, _) {
        debugPrint('bootstrap failed: $e');
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: SLColors.primary,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(SLSpacing.s24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SplashLogo(),
                      const SizedBox(height: SLSpacing.s24),
                      Text(
                        S.tr(Lang.bn, 'boot_failed'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: kAppFontFamily,
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: SLSpacing.s16),
                      FilledButton(
                        onPressed: () => ref.invalidate(bootstrapProvider),
                        child: const Text(
                          'আবার চেষ্টা করুন',
                          style: TextStyle(fontFamily: kAppFontFamily),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      data: (_) => const SunnahLifeApp(),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: SLColors.gold,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              PhosphorIconsFill.star,
              color: SLColors.primaryDeep,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: SLSpacing.s16),
        Text(
          S.tr(Lang.bn, 'app_title'),
          style: const TextStyle(
            fontFamily: kAppFontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: SLColors.lightPrimaryForeground,
          ),
        ),
      ],
    );
  }
}

/// Bottom-nav shell: 5 destinations for daee+ (হোম / আমল / দাওয়াত / ইলম /
/// আরও), 4 for everyone else (the Da'wah branch is hidden, not merely
/// gated). Token-built SLBottomBar (C-W4a) + the floating contact button on
/// the five root tab paths only.
class AppShellScaffold extends ConsumerWidget {
  const AppShellScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  /// The five root tab paths — where the floating contact button (C-W4a)
  /// may appear. Sub-screens keep their own chrome, no overlapping FAB.
  static const _rootTabPaths = {'/', '/amal', '/dawah', '/ilm', '/more'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final canSeeDawah = ref.watch(
      authProvider.select((s) => s.userOrNull?.canSeeDawah ?? false),
    );

    // Branch index ↔ visible tab index (branch 2 = Da'wah is skipped when
    // the role doesn't qualify).
    final current = navigationShell.currentIndex;
    final selectedTab = !canSeeDawah && current > 2 ? current - 1 : current;
    final onRootTab = _rootTabPaths.contains(
      GoRouterState.of(context).uri.path,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            navigationShell,
            // C-W4a: floating contact (five institutions) — bottom-END above
            // the nav bar, never over the SyncBadge (header trailing) or a
            // CTA. Hidden when the config carries no contacts.
            if (onRootTab)
              PositionedDirectional(
                bottom: SLSpacing.s16,
                end: SLSpacing.s16,
                child: const ContactFab(),
              ),
          ],
        ),
        bottomNavigationBar: SLBottomBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (tab) {
            final branch = !canSeeDawah && tab >= 2 ? tab + 1 : tab;
            navigationShell.goBranch(
              branch,
              initialLocation: branch == navigationShell.currentIndex,
            );
          },
          destinations: [
            SLBottomBarItem(
              icon: PhosphorIconsRegular.starAndCrescent,
              selectedIcon: PhosphorIconsFill.starAndCrescent,
              label: S.tr(lang, 'tab_home'),
            ),
            SLBottomBarItem(
              icon: PhosphorIconsRegular.bookOpen,
              selectedIcon: PhosphorIconsFill.bookOpen,
              label: S.tr(lang, 'tab_amal'),
            ),
            if (canSeeDawah)
              SLBottomBarItem(
                icon: PhosphorIconsRegular.megaphone,
                selectedIcon: PhosphorIconsFill.megaphone,
                label: S.tr(lang, 'tab_dawah'),
              ),
            SLBottomBarItem(
              icon: PhosphorIconsRegular.graduationCap,
              selectedIcon: PhosphorIconsFill.graduationCap,
              label: S.tr(lang, 'tab_ilm'),
            ),
            SLBottomBarItem(
              icon: PhosphorIconsRegular.squaresFour,
              selectedIcon: PhosphorIconsFill.squaresFour,
              label: S.tr(lang, 'tab_more'),
            ),
          ],
        ),
      ),
    );
  }
}
