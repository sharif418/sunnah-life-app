/// Pending-referral storage (C-W3h).
///
/// A /join deep link (https://sunnahlife.app/join/DS-000123 or
/// sunnahlife://join/DS-000123) stores the inviter's member code here
/// BEFORE the user has an account. The code rides along on the NEXT
/// sign-in (OTP verify or social — both accept referredByCode server-side)
/// and is cleared only after a SUCCESSFUL sign-in. Survives app restarts
/// (SharedPreferences) so a user who taps the link, closes the app and
/// signs up tomorrow still credits their inviter.
///
/// Honest edge: a guest who taps the link on the WEB landing page
/// (sunnahlife.app/join/…) has the code persisted in the browser's
/// localStorage ('sl_join_code') — the mobile app CANNOT read that. Only a
/// tap that reaches the installed app (custom scheme or verified App Link)
/// lands in this store.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the pending referral member code (DS-XXXXXX).
const String kPendingReferralPref = 'pending_referral';

/// Thin typed wrapper over the persisted pending referral. Construct with
/// [SharedPreferences] directly (tests: SharedPreferences.setMockInitialValues
/// before the first getInstance).
class PendingReferralStore {
  PendingReferralStore(this._prefs);

  final SharedPreferences _prefs;

  /// The stored code, or null when no pending referral exists.
  String? read() => _prefs.getString(kPendingReferralPref);

  /// Persist [code] (already validated by referralCodeFromLink). Idempotent
  /// — re-tapping the same link writes the same value.
  Future<void> write(String code) => _prefs.setString(kPendingReferralPref, code);

  /// Consume: the referral was used by a successful sign-in — drop it so a
  /// LATER sign-in can never accidentally re-attach the same inviter.
  Future<void> clear() => _prefs.remove(kPendingReferralPref);
}
