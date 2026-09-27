# Sunnah Life — iOS build guide (IOS_BUILD.md)

The iOS runner is **code-complete** (including push notifications, Task B2,
and Sign in with Apple, Task B5 — §9) but cannot be compiled in this
environment — no macOS/Xcode host exists in the sandbox
(`docs/ENVIRONMENT.md`). This file is the exact runbook for the
signing Mac. (General project notes: `apps/mobile/ios/README.md`.)

---

## 1. What already exists in-repo (no Mac needed to have written it)

| File | Push-relevant content |
|---|---|
| `ios/Runner/AppDelegate.swift` | `UIApplication.shared.registerForRemoteNotifications()` on launch + `didRegisterForRemoteNotificationsWithDeviceToken` → `Messaging.messaging().apnsToken = deviceToken` (the documented no-swizzle bridge; harmless when swizzling stays on). `FirebaseApp.configure()` happens on the Dart side (`lib/services/push_service.dart`). |
| `ios/Runner/Runner.entitlements` | `aps-environment` = `development` (Xcode flips it to `production` at archive/upload via the provisioning profile). |
| `ios/Runner/Info.plist` | `UIBackgroundModes` → `remote-notification`; `CFBundleURLTypes` registers the `sunnahlife://` scheme. |
| `ios/Runner.xcodeproj` | standard Flutter runner; `firebase_messaging`/`firebase_core` Pods arrive via `pod install` (the Dart deps are already in `pubspec.yaml`). |
| `lib/firebase_options.dart` | **placeholder** — §3 replaces it. |

## 2. Prerequisites on the Mac

1. Xcode 16+ (from the Mac App Store) + command-line tools
   (`xcode-select --install`).
2. Flutter SDK (same major as CI: `flutter --version` ≥ 3.47).
3. Apple Developer Program membership (needed for push — the free personal
   team **cannot** create push certificates/profiles).
4. CocoaPods: `sudo gem install cocoapods` (or brew).

## 3. Firebase (once per machine) — full detail in docs/RELEASE.md §2

1. `flutterfire configure --project <project-id> --ios-bundle-id bd.asunnah.sunnahLife`
   → rewrites `lib/firebase_options.dart` with the real values.
2. Download `GoogleService-Info.plist` (Firebase console → Project settings →
   Your apps → iOS app) → place at
   `apps/mobile/ios/Runner/GoogleService-Info.plist` (**gitignored** — never
   commit it; the repo carries no example for it, the shape is a standard
   Firebase plist).
3. **APNs key upload** (the step people forget): Apple Developer portal →
   Keys → generate an **APNs Auth Key (.p8)** with the *Apple Push
   Notifications service (APNs)* checkbox → download once → Firebase console
   → ⚙️ Project settings → **Cloud Messaging** → Apple apps → **APNs
   Authentication Key** → upload the .p8 + team id + key id.
   - .p8 is the recommended path (works for both sandbox and production, no
     yearly renewal like .p12 certificates).
   - Without this, FCM accepts your server sends but iOS devices never
     receive them.

## 4. Xcode capabilities (once per checkout)

Open `apps/mobile/ios/Runner.xcworkspace`:

1. **Runner target → Signing & Capabilities**: set your Team; bundle id must
   be exactly `bd.asunnah.sunnahLife`.
2. **+ Capability → Push Notifications** — this is what writes
   `aps-environment` into the provisioning profile (the
   `Runner.entitlements` file in-repo already declares it; Xcode shows the
   capability as configured).
3. **+ Capability → Background Modes** → check **Remote notifications** —
   matches the `UIBackgroundModes` entry already in `Info.plist`.
4. If Xcode complains the entitlement exists twice, trust the repo's
   `Runner.entitlements` (it is wired in `project.pbxproj`).

## 5. Build & run

```bash
cd apps/mobile
flutter pub get
cd ios && pod install && cd ..        # firebase_core/messaging pods
flutter run                           # on a connected iPhone
```

First launch asks for notification permission **after sign-in**
(`PushService.syncRegistration` → `requestPermission(alert/badge/sound)`);
answering "Allow" registers the FCM token via `POST /api/push/token`.

## 6. Archive for distribution

```bash
flutter build ipa                     # then Xcode → Organizer → Distribute
# or: flutter build ios --release --no-codesign  + manual xcarchive
```

- TestFlight/App Store: the `aps-environment` entitlement automatically
  resolves to `production` at upload — no edit needed.
- Verify push in TestFlight with a **distribution** build and a device with a
  real SIM (some push routing differs on Wi-Fi-only iPads).

## 7. Swizzling note (why AppDelegate registers explicitly)

`firebase_messaging` swizzles the app delegate by DEFAULT
(`FirebaseAppDelegateProxyEnabled` defaults to YES) and would handle APNs
registration + token forwarding by itself. `AppDelegate.swift` still calls
`registerForRemoteNotifications()` and bridges the APNs token — the
documented belt-and-suspenders pattern so the build keeps working if
swizzling is ever disabled (add
`FirebaseAppDelegateProxyEnabled = NO` to Info.plist). Both paths coexist
safely; do not remove either.

## 8. Remaining iOS gaps that are NOT push (pre-existing, see ios/README.md)

- WidgetKit home-screen widget (Android has one; iOS widget target is a
  documented extension point for the Mac).
- DND auto-silent is not possible on iOS (no public API) — the Dart layer
  already surfaces it as unsupported.

## 9. Sign in with Apple (Task B5)

The Apple sign-in button (`lib/features/auth/auth_screen.dart` →
`SocialSignInService.appleIdToken`, plugin `sign_in_with_apple` 8.x) is
**iOS-only** — on Android the button stays hidden (the web-flow alternative
needs a `https://…/auth/callback` redirect on our own domain, deliberately
out of scope).

One-time setup on the Mac + Apple Developer portal:

1. **Apple Developer portal** — Identifiers → the app id
   (`bd.asunnah.sunnahLife`) → check **Sign In with Apple** → save (re-download
   the provisioning profiles afterwards). Optionally create a **Services ID**
   + **Sign in with Apple key (.p8)** — only needed for the web-style flow
   (the api's `APPLE_SERVICES_ID` audience); the native flow needs neither.
2. **Xcode** — Runner target → **Signing & Capabilities** →
   **+ Capability → Sign in with Apple**. The repo's
   `ios/Runner/Runner.entitlements` already declares
   `com.apple.developer.applesignin = ["Default"]`; the capability toggle is
   what bakes it into the provisioning profile (same pattern as the Push
   Notifications capability in §4).
3. **API env** — the native flow's id_token carries the bundle id as `aud`,
   so the api needs `APPLE_IOS_BUNDLE_ID=bd.asunnah.sunnahLife` (see
   docs/RELEASE.md §social-login for the full env list). Without any Apple
   audience env set, `GET /api/auth/providers` reports `apple: false` and
   the app hides the button — CI builds stay green without any of this.
4. Flutter/dart side needs **no flags** — `pod install` after the first
   `flutter pub get` that added the plugin.

Behavior notes: Apple returns the **email + name only on the very first
authorization**; later sign-ins are linked by the provider subject id stored
on the account (`User.socialSub`). If the account was created without a
gender, the app shows the one-time gender+name completion screen before
anything else (`/complete-profile` → `PATCH /api/me`).
