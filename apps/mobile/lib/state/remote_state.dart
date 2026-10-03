/// Remote-backed providers: app config (with offline fallback) and the
/// Da'wah-engine data (overview / usrah / reviews / live). All re-fetch when
/// the auth session changes; guests get null-safe idle states.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/calendars.dart' show effectiveHijriAdjust;
import '../models/content_models.dart' show ContentPack;
import '../models/domain.dart';
import 'providers.dart';

/// Offline fallback for the nisab prices + donation URL (only used when
/// /api/config is unreachable — the real values come from the server).
///
/// Keep in sync with packages/content/app-config.json (what the server
/// actually serves): mobile cannot import packages/content, so the parity
/// is pinned by a TEST that reads the committed JSON and asserts equality —
/// drift between these constants and the pack fails CI.
const double kFallbackGoldPerGramBdt = 16500;
const double kFallbackSilverPerGramBdt = 220;
const String kFallbackDonationUrl = 'https://as-sunnah.org/donation';

/// Effective Hijri day-adjustment (C-W3g): the user's local ±2 (profile
/// screen) PLUS the admin's ±2 from GET /api/config, clamped to ±4. Watch
/// this everywhere a Hijri date is rendered — home date bar, ayyam-beez
/// cadence — instead of `profile.hijriAdjust` alone, so the admin's
/// correction propagates consistently. Loading/offline config contributes 0.
final effectiveHijriAdjustProvider = Provider<int>((ref) {
  final user = ref.watch(profileProvider).hijriAdjust;
  final admin = ref.watch(configProvider).maybeWhen(
    data: (c) => c.hijriAdjust,
    orElse: () => 0,
  );
  return effectiveHijriAdjust(user, admin);
});

final configProvider = FutureProvider<AppConfig>((ref) async {
  try {
    return await ref.watch(apiProvider).config();
  } on ApiException {
    return const AppConfig(
      donationUrl: kFallbackDonationUrl,
      domain: 'sunnahlife.app',
      hijriAdjust: 0,
      goldPerGramBdt: kFallbackGoldPerGramBdt,
      silverPerGramBdt: kFallbackSilverPerGramBdt,
    );
  }
});

/// Da'wah overview (W4-fix4: cached offline). Null while a guest (the UI
/// shows the gate instead). Network failure + cached envelope → the stale
/// snapshot (the tab shows the offline banner + "সর্বশেষ হালনাগাদ");
/// never cached → null (the error state stays, as specced).
final dawahProvider = FutureProvider<ApiCached<DawahOverview>?>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.userOrNull;
  if (user == null || !user.canSeeDawah) return null;
  try {
    return await ref.watch(apiProvider).dawahOverview(scope: user.id);
  } on ApiException {
    return null;
  }
});

class UsrahBundle {
  const UsrahBundle({
    required this.usrah,
    required this.announcements,
    this.fetchedAt,
    this.stale = false,
  });
  final Usrah? usrah;
  final List<Announcement> announcements;

  /// W4-fix4: when the envelope last came over the network; `stale` marks
  /// a cache-served snapshot (offline banner stamp).
  final DateTime? fetchedAt;
  final bool stale;
}

final usrahProvider = FutureProvider<UsrahBundle?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    final c = await ref.watch(apiProvider).usrah(scope: auth.user!.id);
    return UsrahBundle(
      usrah: c.data.$1,
      announcements: c.data.$2,
      fetchedAt: c.fetchedAt,
      stale: c.stale,
    );
  } on ApiException {
    return null;
  }
});

final reviewsProvider = FutureProvider<ApiCached<List<WeeklyReview>>?>(
  (ref) async {
    final auth = ref.watch(authProvider);
    if (!auth.signedIn) return null;
    try {
      return await ref.watch(apiProvider).reviews(scope: auth.user!.id);
    } on ApiException {
      return null;
    }
  },
);

final liveProvider = FutureProvider<List<LiveProgramItem>>((ref) async {
  return ref.watch(apiProvider).live();
});

// ── Ilm engagement (B9): packs with the bundled-asset offline fallback ────────

/// Quiz pack — GET /api/content/quizzes, falling back to the bundled asset
/// (assets/content/quizzes.json) so the reading/playing still works offline.
/// Refetch when the session changes (nothing auth-dependent in the pack
/// itself, but a fresh sign-in may follow a long offline period).
final quizPackProvider = FutureProvider<List<Quiz>>((ref) async {
  final auth = ref.watch(authProvider);
  auth.signedIn; // re-resolve when the session flips
  try {
    return await ref.watch(apiProvider).quizPack();
  } on ApiException {
    return ContentPack.quizzes();
  }
});

/// Course pack — GET /api/courses with the bundled bodies as the offline
/// fallback (progress/enrollment stats only exist signed-in, so the list
/// falls back to the reading-only pack when offline).
final coursePackProvider = FutureProvider<List<CourseSummary>>((ref) async {
  final auth = ref.watch(authProvider);
  auth.signedIn;
  try {
    return await ref.watch(apiProvider).courses();
  } on ApiException {
    final bundled = await loadBundledCourses();
    return bundled
        .map(
          (c) => CourseSummary(
            id: c.id,
            titleBn: c.titleBn,
            descBn: c.descBn,
            level: c.level,
            lessonCount: c.lessons.length,
            totalMinutes: c.totalMinutes,
            enrolledCount: 0,
          ),
        )
        .toList();
  }
});

/// My enrollment progress rows (signed-in only; null while a guest).
final enrollmentsProvider = FutureProvider<List<EnrollmentItem>?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    return await ref.watch(apiProvider).enrollments();
  } on ApiException {
    return null;
  }
});

/// My self-paced quiz attempt history (signed-in only; null while a guest).
final quizAttemptsProvider = FutureProvider<List<QuizAttemptItem>?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    return await ref.watch(apiProvider).quizAttempts();
  } on ApiException {
    return null;
  }
});

/// The members' quiz results for a usrah head / invigilator. Null for
/// everyone else and offline (the section hides).
final usrahQuizResultsProvider = FutureProvider<UsrahQuizResults?>((ref) async {
  final user = ref.watch(authProvider).userOrNull;
  if (user == null || !user.role.isSupervisor) return null;
  try {
    return await ref.watch(apiProvider).usrahQuizResults();
  } on ApiException {
    return null;
  }
});

/// Usrah question board (RLS — own usrah only; empty while a guest).
final usrahQuestionsProvider = FutureProvider<List<UsrahQuestion>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return const [];
  try {
    return await ref.watch(apiProvider).usrahQuestions();
  } on ApiException {
    return const [];
  }
});

/// Live level-requirements checklist (daee+; null while a guest/never
/// cached offline — W4-fix4 serves the stale envelope with its banner).
final dawahRequirementsProvider =
    FutureProvider<ApiCached<DawahRequirements>?>((ref) async {
      final auth = ref.watch(authProvider);
      final user = auth.userOrNull;
      if (user == null || !user.canSeeDawah) return null;
      try {
        return await ref.watch(apiProvider).dawahRequirements(
          scope: user.id,
        );
      } on ApiException {
        return null;
      }
    });

/// Own gender-scoped leaderboard band (W4c) — the scholars' config gate:
/// hidden entirely (null) while the flag is off (including while the
/// config is still loading), for guests, on the server's 404 (flag off
/// server-side too) and on any network failure. Never an error wall.
final leaderboardMeProvider = FutureProvider<LeaderboardMe?>((ref) async {
  final enabled = ref.watch(configProvider).maybeWhen(
    data: (c) => c.leaderboardEnabled,
    orElse: () => false,
  );
  if (!enabled) return null;
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    return await ref.watch(apiProvider).leaderboardMe();
  } on ApiException {
    return null;
  }
});
