/// Personal-goal lifecycle state (W4c): the member's own goals + the
/// supervisor approval queue. Both are server-backed — guests get null and
/// the screens show their sign-in gates; every ApiException degrades to a
/// retryable null (offline never blocks the rest of the diary).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/domain.dart';
import 'providers.dart';

/// Own goals, every lifecycle status (newest first). Null while a guest or
/// offline — the goals screen gates on it.
final goalsProvider = FutureProvider<List<PersonalGoal>?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.signedIn) return null;
  try {
    return await ref.watch(apiProvider).fetchGoals();
  } on ApiException {
    return null;
  }
});

/// The approval queue for usrah_head+ (GET /api/usrah/goals — RLS scopes the
/// rows to the caller's own members server-side). Null for non-supervisors,
/// guests and offline (the section hides entirely).
final goalQueueProvider = FutureProvider<List<GoalQueueItem>?>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.userOrNull;
  if (user == null || !user.role.isSupervisor) return null;
  try {
    return await ref.watch(apiProvider).usrahGoals();
  } on ApiException {
    return null;
  }
});
