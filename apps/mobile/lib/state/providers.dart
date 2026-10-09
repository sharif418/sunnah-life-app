/// Core providers: DB, API client, profile/settings, auth session.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../services/session_store.dart';
import '../db/api_cache.dart';
import '../db/database.dart';
import '../models/domain.dart';
import '../core/cities.dart';
import '../core/referral.dart';
import 'referral_state.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final apiProvider = Provider<ApiClient>((ref) {
  // W4-fix4: the Da'wah GET reads cache their last-good envelope in the
  // local sqlite file — offline the tab renders it with a staleness banner
  // instead of an error wall.
  final client = ApiClient(cacheStore: DriftApiCacheStore(ref.watch(dbProvider)));
  // 401 anywhere → the token is dead: clear it and drop to guest mode
  // without a network round-trip (signOut() calls the server).
  client.onUnauthorized = () {
    ref.read(authProvider.notifier).forceSignOut();
  };
  // every renewal rotates the refresh token — keep the new pair
  client.onTokensRefreshed = (access, refresh) {
    ref.read(sessionStoreProvider).saveTokens(access, refresh);
  };
  ref.onDispose(client.dispose);
  return client;
});

/// The signed-in session on the phone (keystore-backed).
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// Injectable "now" for the always-visible chrome (global header date bar,
/// today-diary keys). Production reads the wall clock; goldens pin it so a
/// capture never flakes across days (day-of-week amals, Bangla/Hijri dates).
final headerNowProvider = Provider<DateTime>((ref) => DateTime.now());

// ── Profile / settings (backed by the GuestProfile row) ──────────────────────

class ProfileState {
  const ProfileState({
    required this.name,
    required this.gender,
    required this.language,
    required this.city,
    required this.lat,
    required this.lng,
    required this.tz,
    required this.method,
    required this.madhhab,
    required this.category,
    required this.themeMode,
    required this.hijriAdjust,
    required this.onboardingDone,
  });

  final String name;
  final Gender gender;
  final String language; // bn | en | ar
  final String city;
  final double lat;
  final double lng;
  final double tz;
  final CalcMethod method;
  final Madhhab madhhab;
  final UserCategory category;
  final String themeMode; // light | dark | system
  final int hijriAdjust;
  final bool onboardingDone;
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    _hydrate();
    return const ProfileState(
      name: '',
      gender: Gender.m,
      language: 'bn',
      city: 'ঢাকা',
      lat: kDhakaLat,
      lng: kDhakaLng,
      tz: kDhakaTz,
      method: CalcMethod.karachi,
      madhhab: Madhhab.hanafi,
      category: UserCategory.general,
      themeMode: 'system',
      hijriAdjust: 0,
      onboardingDone: false,
    );
  }

  /// Sync state injection from the bootstrap read (no duplicate DB hit).
  void hydrateFrom(GuestProfile row) {
    state = ProfileState(
      name: row.name,
      gender: row.gender == 'F' ? Gender.f : Gender.m,
      language: row.language,
      city: row.city,
      lat: row.lat,
      lng: row.lng,
      tz: row.tz,
      method: CalcMethodJson.fromJson(row.method),
      madhhab: MadhhabJson.fromJson(row.madhhab),
      category: UserCategoryJson.fromJson(row.category),
      themeMode: row.themeMode,
      hijriAdjust: row.hijriAdjust,
      onboardingDone: row.onboardingDone,
    );
  }

  Future<void> _hydrate() async {
    final row = await ref.read(dbProvider).guestProfile();
    hydrateFrom(row);
  }

  Future<void> update({
    String? name,
    Gender? gender,
    String? language,
    String? city,
    double? lat,
    double? lng,
    double? tz,
    CalcMethod? method,
    Madhhab? madhhab,
    UserCategory? category,
    String? themeMode,
    int? hijriAdjust,
    bool? onboardingDone,
  }) async {
    state = ProfileState(
      name: name ?? state.name,
      gender: gender ?? state.gender,
      language: language ?? state.language,
      city: city ?? state.city,
      lat: lat ?? state.lat,
      lng: lng ?? state.lng,
      tz: tz ?? state.tz,
      method: method ?? state.method,
      madhhab: madhhab ?? state.madhhab,
      category: category ?? state.category,
      themeMode: themeMode ?? state.themeMode,
      hijriAdjust: hijriAdjust ?? state.hijriAdjust,
      onboardingDone: onboardingDone ?? state.onboardingDone,
    );
    final cityEntry = findCity(state.city);
    await ref
        .read(dbProvider)
        .saveGuestProfile(
          GuestProfilesCompanion(
            name: Value(state.name),
            gender: Value(state.gender.json),
            language: Value(state.language),
            city: Value(state.city),
            lat: Value(cityEntry?.lat ?? state.lat),
            lng: Value(cityEntry?.lng ?? state.lng),
            tz: Value(cityEntry?.tz ?? state.tz),
            method: Value(state.method.json),
            madhhab: Value(state.madhhab.json),
            category: Value(state.category.json),
            themeMode: Value(state.themeMode),
            hijriAdjust: Value(state.hijriAdjust),
            onboardingDone: Value(state.onboardingDone),
          ),
        );
    // Keep the server-side profile in sync when signed in (best effort).
    final user = ref.read(authProvider).user;
    if (user != null) {
      try {
        await ref.read(apiProvider).updateMe({
          'name': ?name,
          'language': ?language,
          'city': ?city,
          if (cityEntry != null) ...{
            'lat': cityEntry.lat,
            'lng': cityEntry.lng,
          },
          'calcMethod': ?method?.json,
          'madhhab': ?madhhab?.json,
          'category': ?category?.json,
        });
      } on ApiException {
        // offline — profile stays local, syncs on next successful call
      }
    }
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);

// ── Auth session ─────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({required this.status, this.user});
  final AuthStatus status;
  final User? user;

  bool get signedIn => status == AuthStatus.signedIn;
  User? get userOrNull => signedIn ? user : null;
}

enum AuthStatus { loading, guest, signedIn }

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState(status: AuthStatus.loading);
  }

  /// Opening the app: the stored session comes back as it was.
  ///
  /// Until 2026-10-09 this asked the server first and signed the member out
  /// on ANY failure — and the stored access token lives 15 minutes, so
  /// nearly every reopen meant a new code (offline or on a slow network
  /// too). Now: the last known user shows at once (offline-first), the
  /// server is asked in the background, an expired access token is renewed
  /// with the refresh token, and only a refused refresh signs out.
  Future<void> _restore() async {
    final store = ref.read(sessionStoreProvider);
    final saved = await store.read();
    if (saved == null) {
      state = const AuthState(status: AuthStatus.guest);
      return;
    }
    final api = ref.read(apiProvider);
    api.token = saved.access;
    api.refreshToken = saved.refresh;
    final cached = saved.user;
    if (cached != null) {
      state = AuthState(status: AuthStatus.signedIn, user: cached);
    }
    try {
      final user = await api.me();
      if (user != null) {
        state = AuthState(status: AuthStatus.signedIn, user: user);
        await store.saveUser(user);
        return;
      }
    } on ApiException catch (e) {
      // 401 that a refresh could not cure: the client already fired
      // onUnauthorized → forceSignOut. Anything else (offline, timeout,
      // 5xx) keeps the session — the next request tries again.
      if (e.status == 401) return;
      if (cached != null) return;
      // an install from before the user cache, offline: the session stays
      // stored; the member shows as guest until the next open reaches the
      // server
      state = const AuthState(status: AuthStatus.guest);
      return;
    }
    await forceSignOut();
  }

  Future<void> _saveSession(VerifyResponse res) async {
    final token = res.token;
    if (token == null) return;
    final api = ref.read(apiProvider);
    api.token = token;
    api.refreshToken = res.refreshToken;
    final store = ref.read(sessionStoreProvider);
    await store.saveTokens(token, res.refreshToken);
    await store.saveUser(res.user);
  }

  /// OTP verify. Guest amal entries ride along (server merges by
  /// latest clientUpdatedAt) — the same conflict rule as the outbox.
  Future<void> signIn({
    required String phone,
    required String code,
    String? name,
    Gender? gender,
    String? referredByCode,
  }) async {
    final db = ref.read(dbProvider);
    final guestEntries = await db.entriesBetween('2000-01-01', '2999-12-31');
    final api = ref.read(apiProvider);
    final res = await api.verifyOtp(
      phone: phone,
      code: code,
      name: name,
      gender: gender,
      referredByCode: referredByCode,
      guestEntries: guestEntries.take(500).toList(),
    );
    await _saveSession(res);
    state = AuthState(status: AuthStatus.signedIn, user: res.user);
    await _consumePendingReferral(referredByCode);
    // Adopt the account's prayer profile locally.
    await ref
        .read(profileProvider.notifier)
        .update(
          name: res.user.name,
          gender: res.user.gender,
          language: res.user.language,
          city: res.user.city ?? 'ঢাকা',
          lat: res.user.lat,
          lng: res.user.lng,
          method: res.user.calcMethod,
          madhhab: res.user.madhhab,
          category: res.user.category,
        );
  }

  /// Social sign-in (Google/Apple — Task B5): the id_token is verified
  /// server-side (JWKS + WebCrypto); the account is linked by provider sub
  /// or verified email. Same session + guest-entries migration path as OTP.
  /// When the returned user still has no gender (account created via social
  /// elsewhere without one), the router routes to the one-time completion
  /// screen (/complete-profile) instead of '/'.
  Future<void> signInWithSocial({
    required String provider,
    required String idToken,
    String? name,
    Gender? gender,
    String? referredByCode,
  }) async {
    final db = ref.read(dbProvider);
    final guestEntries = await db.entriesBetween('2000-01-01', '2999-12-31');
    final api = ref.read(apiProvider);
    final res = await api.socialSignIn(
      provider: provider,
      idToken: idToken,
      name: name,
      gender: gender,
      referredByCode: referredByCode,
      guestEntries: guestEntries.take(500).toList(),
    );
    await _saveSession(res);
    state = AuthState(status: AuthStatus.signedIn, user: res.user);
    await _consumePendingReferral(referredByCode);
    // Adopt the account's profile — EXCEPT gender while it is still
    // "unspecified" (the local onboarding choice stays until completion).
    await ref
        .read(profileProvider.notifier)
        .update(
          name: res.user.name,
          gender: res.user.gender.needsCompletion ? null : res.user.gender,
          language: res.user.language,
          city: res.user.city ?? 'ঢাকা',
          lat: res.user.lat,
          lng: res.user.lng,
          method: res.user.calcMethod,
          madhhab: res.user.madhhab,
          category: res.user.category,
        );
  }

  /// Replace the in-session user after a profile PATCH (gender completion).
  void updateUser(User user) {
    state = AuthState(status: AuthStatus.signedIn, user: user);
    // the offline start shows the latest profile
    ref.read(sessionStoreProvider).saveUser(user);
  }

  /// C-W3h: a successful sign-in that CARRIED a referral consumes the
  /// pending-referral storage — a later sign-in can never re-attach the
  /// same inviter. Called only after the session state is already signed in
  /// (a failed verify leaves the code in place for the retry).
  Future<void> _consumePendingReferral(String? referredByCode) async {
    if (referredByCode == null || referredByCode.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await PendingReferralStore(prefs).clear();
    ref.invalidate(pendingReferralProvider);
  }

  /// True while the signed-in account still lacks gender — the router sends
  /// these users to /complete-profile (one-time; the API locks gender after).
  bool get needsGenderCompletion =>
      state.userOrNull?.gender.needsCompletion ?? false;

  Future<void> signOut() async {
    try {
      await ref.read(apiProvider).logout();
    } on ApiException {
      // offline sign-out is fine
    }
    await _clearSession();
  }

  /// Local-only sign-out (used by the API client's 401 hook).
  Future<void> forceSignOut() async {
    final api = ref.read(apiProvider);
    api.token = null;
    api.refreshToken = null;
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AuthState(status: AuthStatus.guest);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
