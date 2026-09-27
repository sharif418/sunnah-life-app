# সুন্নাহ লাইফ — Sunnah Life (Flutter mobile app)

Islamic companion app + Dawatus Sunnah Tarbiyah engine for As-Sunnah
Foundation. Bengali-first (default), English + Arabic with full RTL.

## Run
```bash
flutter pub get
flutter run                                   # app (Android)
flutter run -t lib/catalog/catalog_app.dart    # component catalog
flutter test                                  # unit + widget tests
flutter build apk --debug                     # debug APK
```

## API base
Default `https://sunnahlife.app`. Override for local backend:
```bash
flutter run --dart-define=SUNNAH_API_BASE=http://10.0.2.2:3000
```
Guest mode is local-only (Drift + outbox); sign-in merges the guest diary
(latest `clientUpdatedAt` wins, same rule as the server).

## Architecture
```
lib/
  main.dart                 entrypoint (GoogleFonts offline-first)
  app.dart                  router (go_router StatefulShellRoute, 5 tabs),
                            theme (design tokens), locale bn/en/ar + RTL
  design/design_tokens.dart COPY of packages/design-tokens/dist/flutter —
                            SLColors/SLSpacing/SLRadius/SLMotion/SLElevation/
                            SLType + buildSunnahLight/DarkTheme()
  l10n/app_strings.dart     manual bn/en/ar string table (S.tr / context.t)
  models/                   typed domain + content + quran models (no Map sprawl)
  api/api_client.dart       typed REST client (mirrors src/lib/api.ts)
  db/                       Drift: AmalEntries, Outbox, GuestProfile,
                            Settings, LastRead, AyahBookmarks
  core/                     prayer engine (adhan_dart), calendars (Bangla +
                            Hijri + toBn), cities, qibla, amal engine
                            (points/streaks/lock), sync merge
  state/                    riverpod providers (profile, auth, amal + outbox
                            sync, prayer ticker, remote data)
  services/                 notifications (FCM seam: PushAdapter behind
                            kFcmEnabled=false), platform channels
  features/                 onboarding, auth, home(prayer), amal, dawah,
                            ilm, more
  catalog/catalog_app.dart  component gallery — the Widgetbook substitute
```

### Platform channels (Kotlin)
- `sunnahlife/prayer` — exact alarms (`AlarmManager.setExactAndAllowWhileIdle`
  + `canScheduleExactAlarms` + `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`),
  DND auto-silent (`NotificationManager.setInterruptionFilter` +
  `ACCESS_NOTIFICATION_POLICY`).
- `sunnahlife/widget` — home widget (AppWidgetProvider + RemoteViews): next
  prayer + countdown; updates pushed on every prayer-tick.
- `sunnahlife/system` — native share sheet.

iOS stubs: `ios/README.md`. The widget is re-scheduled whenever the app
opens (no boot receiver by design — alarms are recomputed daily).

## Catalog (Widgetbook substitute)
`lib/catalog/catalog_app.dart` — decision: a hand-rolled gallery listing
every custom component in light + dark + RTL keeps the pubspec lean
(Widgetbook would add ~40 deps and version pins that clash in this
sandbox). Same review capability, zero dependency cost.

## Fonts
Bundled under `assets/google_fonts/` (Hind Siliguri, Amiri, Amiri Quran) with
`GoogleFonts.config.allowRuntimeFetching = false` — fully offline typography.
