/// Pending-referral UI state (C-W3h): the auth screen watches this to show
/// the "রেফার করেছেন: DS-XXXXXX" chip and to pass referredByCode into
/// sign-in. Invalidate after any store write/clear (the deep-link service
/// and AuthNotifier do).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/referral.dart';

class PendingReferralNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() {
    _load();
    return const AsyncValue<String?>.loading();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Re-read on every invalidate — cheap (one in-memory map lookup after
    // the platform's first load).
    state = AsyncValue<String?>.data(
      prefs.getString(kPendingReferralPref),
    );
  }
}

/// The pending referral code (DS-XXXXXX) or null — loading while the
/// SharedPreferences read is in flight (callers render nothing then).
final pendingReferralProvider =
    NotifierProvider<PendingReferralNotifier, AsyncValue<String?>>(
  PendingReferralNotifier.new,
);
