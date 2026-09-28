/// Settings provider (spec path) — canonical implementation in
/// `lib/state/providers.dart`:
///
///  · [profileProvider]  — AppProfile equivalent (`ProfileState`: name,
///    gender, language, city, lat/lng/tz, method, madhhab, category,
///    themeMode, hijriAdjust, onboardingDone) persisted via Drift
///    (GuestProfiles row) + best-effort server sync when signed in.
///  · [authProvider]     — token session (SharedPreferences) + User;
///    `authProvider.userOrNull?.canSeeDawah` is the `isDaeePlus` flag.
///  · [dbProvider]       — the Drift [AppDatabase].
///  · [apiProvider]      — typed [ApiClient] (401 → clears the token).
///
/// Locale + ThemeMode are derived in `SunnahLifeApp.build` from
/// `ProfileState.language` / `ProfileState.themeMode`.
library;

export '../state/providers.dart'
    show
        dbProvider,
        apiProvider,
        ProfileState,
        ProfileNotifier,
        profileProvider,
        AuthState,
        AuthStatus,
        AuthNotifier,
        authProvider,
        sharedPrefsProvider;
