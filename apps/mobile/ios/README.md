# Sunnah Life — iOS notes (no macOS host in the sandbox)

The iOS runner is code-complete but **cannot be compiled here** (no macOS /
Xcode possible in this environment — see `docs/ENVIRONMENT.md`). What is in
place, and what the signing Mac must do:

> **Push notifications (Task B2):** the full iOS push runbook — APNs key
> upload, `GoogleService-Info.plist` placement, capabilities, swizzling —
> lives in `docs/IOS_BUILD.md`. `AppDelegate.swift`, `Runner.entitlements`
> (aps-environment) and `Info.plist` (UIBackgroundModes remote-notification,
> `sunnahlife://` URL scheme) already carry the code side.

## What already exists
- `ios/Runner` project from `flutter create` (AppDelegate, Info.plist,
  Assets, Base.lproj) with **Swift channel stubs** for the three platform
  channels (`sunnahlife/prayer`, `sunnahlife/widget`, `sunnahlife/system`).
- `AppDelegate.swift` implements:
  - `sunnahlife/system` → real `UIActivityViewController` share sheet.
  - `sunnahlife/prayer` → `canScheduleExactAlarms: true` (the concept maps
    to notification scheduling on iOS) and `setAutoSilent`/`isDndGranted:
    false` (iOS has no public DND API — the Dart layer surfaces this as
    "unsupported" instead of failing).
  - `sunnahlife/widget` → no-op (see below).

## What the Mac must add (documented extension points)
1. **Signing**: set the Team/Bundle ID (`bd.asunnah.sunnahLife`) in
   `Runner.xcodeproj` and export `TEAM_ID` for CI. The bundle id placeholder
   in `project.pbxproj` is the flutter default — change to match
   `applicationId` on Android.
2. **WidgetKit widget**: the Android widget (next prayer + countdown) has an
   iOS counterpart as a design/plan item. On the Mac: add a Widget Extension
   target ("SunnahWidget"), read the shared `nextPrayer`/`countdown` from an
   App Group (`group.bd.asunnah.sunnahlife`), and have the
   `sunnahlife/widget` channel write into that App Group
   (`UserDefaults(suiteName:)`) instead of returning nil.
3. **Notification permission**: `flutter_local_notifications` requests it at
   runtime; nothing to pre-configure.
4. **Prayer alarms**: on iOS, waqt notifications come from
   `flutter_local_notifications` (already scheduled by
   `PrayerNotifier`); no AlarmManager path is used.

## Run
```bash
flutter run -t lib/main.dart          # app
flutter run -t lib/catalog/catalog_app.dart  # component catalog
flutter build ipa                     # on the signing Mac
```
