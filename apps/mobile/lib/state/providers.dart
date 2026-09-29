/// Core providers: DB, API client, profile/settings, auth session.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
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
  final client = ApiClient();
  // 401 anywhere → the token is dead: clear it and drop to guest mode
  // without a network round-trip (signOut() calls the server).
  client.onUnauthorized = () {
    ref.read(authProvider.notifier).forceSignOut();
  };
  ref.onDispose(client.dispose);
  return client;
});

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

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
  static const _tokenKey = 'sl_token';

  @override
  AuthState build() {
    _restore();
    return const AuthState(status: AuthStatus.loading);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) {
      state = const AuthState(status: AuthStatus.guest);
      return;
    }
    final api = ref.read(apiProvider);
    api.token = token;
    try {
      final user = await api.me();
      if (user != null) {
        state = AuthState(status: AuthStatus.signedIn, user: user);
        return;
      }
    } on ApiException {
      // fall through to guest
    }
    await prefs.remove(_tokenKey);
    api.token = null;
    state = const AuthState(status: AuthStatus.guest);
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
    if (res.token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, res.token!);
      api.token = res.token;
    }
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
    final token = res.token;
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      api.token = token;
    }
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
    ref.read(apiProvider).token = null;
    await _clearSession();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    state = const AuthState(status: AuthStatus.guest);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
