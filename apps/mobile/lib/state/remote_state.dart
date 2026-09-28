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

/// Da'wah overview — null while a guest (the UI shows the gate instead).
final dawahProvider = FutureProvider<DawahOverview?>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.userOrNull;
  if (user == null || !user.canSeeDawah) return null;
  try {
    return await ref.watch(apiProvider).dawahOverview();
  } on ApiException {
    return null;
  }
});

class UsrahBundle {
  const UsrahBundle({required this.usrah, required this.announcements});
  final Usrah? usrah;
  final List<Announcement> announcements;
}

final usrahProvider = FutureProvider<UsrahBundle?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    final (usrah, announcements) = await ref.watch(apiProvider).usrah();
    return UsrahBundle(usrah: usrah, announcements: announcements);
  } on ApiException {
    return null;
  }
});

final reviewsProvider = FutureProvider<List<WeeklyReview>?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    return await ref.watch(apiProvider).reviews();
  } on ApiException {
    return null;
  }
});

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

/// Live level-requirements checklist (daee+; null while a guest/offline).
final dawahRequirementsProvider = FutureProvider<DawahRequirements?>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.userOrNull;
  if (user == null || !user.canSeeDawah) return null;
  return ref.watch(apiProvider).dawahRequirements();
});
