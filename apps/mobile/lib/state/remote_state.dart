/// Remote-backed providers: app config (with offline fallback) and the
/// Da'wah-engine data (overview / usrah / reviews / live). All re-fetch when
/// the auth session changes; guests get null-safe idle states.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/domain.dart';
import 'providers.dart';

/// Offline fallback for the nisab prices (only used when /api/config is
/// unreachable — the real values come from the server).
const double kFallbackGoldPerGramBdt = 11500;
const double kFallbackSilverPerGramBdt = 135;

final configProvider = FutureProvider<AppConfig>((ref) async {
  try {
    return await ref.watch(apiProvider).config();
  } on ApiException {
    return const AppConfig(
      donationUrl: 'https://sunnahlife.app/donate',
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
