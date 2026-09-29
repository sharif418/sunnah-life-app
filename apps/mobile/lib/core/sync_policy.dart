/// Pure sync-pull/retry policy — C-W3d client side.
///
/// Everything here is a pure function (unit-tested in
/// test/sync_pull_test.dart): the pull watermark math, the outbox
/// reject/dead policy, and the convergence entry built from a
/// `newerVersion` rejection that carries the server's winning value
/// (the W2g contract — `rejected[].serverValue`).
///
/// The impure halves live elsewhere: `SyncNotifier.pull()` (state +
/// SharedPreferences watermark) and `AppDatabase` (row writes).
library;

import '../core/bn_digits.dart';
import '../core/date_keys.dart';
import '../core/sync_merge.dart';
import '../models/domain.dart';

/// Outbox rows are retried at most this many times before being marked dead
/// (validation/lock/unknown-amal rejections — a `newerVersion` rejection
/// with a serverValue converges in ONE round, see [outboxRejectDecision]).
const int kMaxOutboxAttempts = 5;

/// Days of overlap re-pulled on every incremental pull — covers clock skew
/// between the device and the server, plus entries written by another
/// device just after our watermark was taken.
const int kPullOverlapDays = 3;

/// Bounded first pull: when no watermark exists yet (fresh install or
/// pre-C-W3d upgrade) we fetch the same 3-month window the app itself
/// hydrates in memory (`AmalNotifier._loadWindow`), not "everything".
const int kFirstPullWindowDays = 95;

/// Strict YYYY-MM-DD that is also a real calendar day (rejects 2025-13-01,
/// 2025-02-30, …). Date keys are timezone-free local keys (see date_keys),
/// so this check is timezone-safe by construction.
bool isValidDateKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return false;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return false;
  final parsed = DateTime(y, mo, d);
  return parsed.year == y && parsed.month == mo && parsed.day == d;
}

/// Start of the pull window for the persisted [watermark] (a dateKey, or
/// null when never pulled). Incremental pulls go back
/// [kPullOverlapDays] from the watermark; a corrupt watermark falls back to
/// the bounded first-pull window; a watermark in the future (device clock
/// set back) degrades to the recent-overlap window so the pull stays small.
String pullWindowFrom(String? watermark, String today) {
  if (watermark == null || !isValidDateKey(watermark)) {
    return addDays(today, -kFirstPullWindowDays);
  }
  if (watermark.compareTo(today) > 0) {
    return addDays(today, -kPullOverlapDays);
  }
  return addDays(watermark, -kPullOverlapDays);
}

/// What flush() should do with one rejected outbox row.
class OutboxRejectDecision {
  const OutboxRejectDecision({
    required this.attempts,
    required this.reason,
    required this.converge,
    required this.dead,
  });

  /// New attempts counter (previous + 1 — every rejection is an attempt).
  final int attempts;

  /// The server's reason, captured for the UI (and for the dead-row list).
  final String reason;

  /// LWW loss with a known server value: converge locally via
  /// [convergedEntryFor] instead of retrying.
  final bool converge;

  /// Stop re-POSTing this row. Always true when [converge]; otherwise true
  /// once [attempts] reaches [kMaxOutboxAttempts].
  final bool dead;
}

/// Policy for one rejected row. Pure.
OutboxRejectDecision outboxRejectDecision({
  required AmalRejectInfo info,
  required int previousAttempts,
}) {
  final attempts = previousAttempts + 1;
  final converge = info.serverValue != null;
  return OutboxRejectDecision(
    attempts: attempts,
    reason: info.reason,
    converge: converge,
    dead: converge || attempts >= kMaxOutboxAttempts,
  );
}

/// Entry to merge locally when the server rejected our push because its own
/// copy is newer (`newerVersion` + serverValue, the W2g contract).
///
/// The stamp is bumped 1 ms past the pushed one — the minimum that still
/// wins the local merge against the very row we pushed (mergeEntry: strictly
/// newer wins, ties go to the remote), while staying ≤ any future server
/// row we might pull (the true server stamp is ≥ the pushed one; ties and
/// older stamps both resolve to the same VALUE, so the row converges in
/// every ordering — proven in test/sync_pull_test.dart).
AmalEntry convergedEntryFor(AmalEntry pushed, AmalRejectInfo info) {
  final base = DateTime.tryParse(pushed.clientUpdatedAt) ?? DateTime.now();
  return pushed.copyWith(
    value: info.serverValue,
    clientUpdatedAt: base
        .add(const Duration(milliseconds: 1))
        .toIso8601String(),
  );
}

/// The merge outcome used for convergence: the [converged] entry must win
/// against the pushed local row, and any later server row must not change
/// the VALUE back. Exposed for tests that pin the invariant.
bool convergenceWinsMerge(AmalEntry pushed, AmalEntry converged) =>
    identical(mergeEntry(pushed, converged), converged);

/// Compact relative time for the sync sheet ("এইমাত্র", "৫ মিনিট আগে", …).
/// Pure arithmetic on the difference — deterministic under a fixed clock,
/// which is how the golden test injects it.
String formatAgoBn(Duration ago, {bool bengali = true}) {
  String two(int v) => bengali ? toBn(v) : v.toString();
  if (ago.isNegative || ago.inMinutes < 1) {
    return bengali ? 'এইমাত্র' : 'just now';
  }
  if (ago.inHours < 1) {
    return '${two(ago.inMinutes)}${bengali ? ' মিনিট আগে' : 'm ago'}';
  }
  if (ago.inDays < 1) {
    return '${two(ago.inHours)}${bengali ? ' ঘণ্টা আগে' : 'h ago'}';
  }
  return '${two(ago.inDays)}${bengali ? ' দিন আগে' : 'd ago'}';
}
