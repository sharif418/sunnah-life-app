# Sunnah Life — Release guide (RELEASE.md)

Everything a human must do to ship a release of the mobile app + backend.
Deployment of the server stack itself is `docs/DEPLOY_COOLIFY.md` (VPS +
Coolify/compose); this file covers **releasing versions**, with the Firebase
setup that powers push notifications (Task B2) as the centerpiece.

---

## 1. Version bump

| Where | What |
|---|---|
| `apps/mobile/pubspec.yaml` | `version: MAJOR.MINOR.PATCH+BUILD` (Flutter feeds `versionName`/`versionCode` on Android, `CFBundleShortVersionString`/`CFBundleVersion` on iOS) |
| `apps/web/package.json` / `apps/admin/package.json` / `apps/api/package.json` | npm versions (informational) |
| `docs/PROGRESS.md` | append a release note line |

---

## 2. Firebase (push notifications — one-time project setup)

The app uses **FCM HTTP v1 only, no firebase-admin SDK**: the API signs
service-account JWTs with WebCrypto and talks to
`https://fcm.googleapis.com/v1/projects/{project}/messages:send` directly
(`apps/api/src/push/fcm.transport.ts`). That means no server-side npm
dependency — but the two credentials below must exist.

### 2.1 Create the project

1. [console.firebase.google.com](https://console.firebase.google.com) →
   **Add project** → name it (e.g. `sunnah-life`) → Google Analytics optional
   (the app sends nothing to GA — leave it off).
2. The **project id** (Console → ⚙️ Project settings → General) is used
   everywhere below.

### 2.2 Register the apps

For each platform, Console → ⚙️ **Project settings → Your apps**:

| Platform | Package / bundle id | Download |
|---|---|---|
| Android | `bd.asunnah.sunnah_life` | `google-services.json` |
| iOS | `bd.asunnah.sunnahLife` | `GoogleService-Info.plist` |

**Android placement** — `apps/mobile/android/app/google-services.json`
(the committed `google-services.example.json` documents the shape; **the real
file is gitignored**). The Gradle build applies the google-services plugin
ONLY when this file exists
(`apps/mobile/android/app/build.gradle.kts` — file-existence guard), so **CI
and fresh clones build without it**: the Firebase config that matters at
runtime comes from `lib/firebase_options.dart` (§2.3), the JSON only wires
the default `google_app_id` resource.

**iOS placement** — `apps/mobile/ios/Runner/GoogleService-Info.plist`
(also gitignored; see `docs/IOS_BUILD.md`).

### 2.3 Dart-side options (REQUIRED — `flutterfire configure`)

`lib/firebase_options.dart` ships a **placeholder** (fake ids, commented as
such). Replace it with the real one:

```bash
# one-time: dart pub global activate flutterfire_cli
flutterfire configure \
  --project <project-id> \
  --android-package-name bd.asunnah.sunnah_life \
  --ios-bundle-id bd.asunnah.sunnahLife
```

This rewrites `lib/firebase_options.dart` in place. The placeholder values
make `Firebase.initializeApp` succeed structurally but `getToken` fail
gracefully — with the real options the app obtains FCM tokens on devices with
Play Services / APNs.

### 2.4 Server credential → `FCM_SERVICE_ACCOUNT_JSON` secret

The API/worker need a **service account with the Cloud Messaging API
enabled** to send pushes:

1. Console → ⚙️ **Project settings → Service accounts** →
   **Generate new private key** → save the `.json`
   (contains `project_id`, `client_email`, `private_key`).
2. Google Cloud console (same project) → APIs & Services → enable
   **Firebase Cloud Messaging API** (v1). The OAuth scope used is
   `https://www.googleapis.com/auth/firebase.messaging`.
3. Give the secret to **both** the `api` and the `worker` (the worker is the
   main fan-out process — prayer/review pushes). Compose already forwards it:

   ```dotenv
   # .env (compose passes it to api + worker)
   FCM_SERVICE_ACCOUNT_JSON={"project_id":"sunnah-life","client_email":"push@sunnah-life.iam.gserviceaccount.com","private_key":"-----BEGIN PRIVATE KEY-----\n…\n-----END PRIVATE KEY-----\n", …}
   ```

   The value is either the **full JSON object as a one-line string** or **a
   path to the JSON file** readable by the process
   (`apps/api/src/push/push.service.ts` → `createPushTransport`). Invalid or
   missing → the **no-op transport** with a warning log — flows keep working,
   pushes are logged only (this is exactly what the sandbox does).

4. Rotate: generate a new key, swap the env value, restart api + worker. Old
   access tokens die within an hour (the service account itself remains
   valid until deleted in the console).

### 2.5 APNs (iOS devices — see docs/IOS_BUILD.md)

Firebase can only deliver to iPhones once an APNs auth key (.p8) is uploaded:
Console → ⚙️ **Project settings → Cloud Messaging → Apple apps → APNs
Authentication Key**. Full steps in `docs/IOS_BUILD.md`.

### 2.6 Verify the wiring (no device needed)

```bash
# 1. api log on boot selects the real transport:
docker compose logs api | grep PushService
# → LOG [PushService] FCM transport ready (project <project-id>)
# (the no-op line means FCM_SERVICE_ACCOUNT_JSON is missing/invalid)

# 2. register a device token (any signed-in app install does this on its own;
#    manual check of the endpoint):
curl -X POST https://api.sunnahlife.app/api/push/token \
  -H "Authorization: Bearer <access-token>" \
  -H "Content-Type: application/json" \
  -d '{"token":"<FCM registration token>","platform":"android"}'

# 3. send a broadcast from an usrah head/admin account (apps/web Da'wah tab
#    or the admin console) — the phone should show "নতুন ঘোষণা".
```

---

## 3. Mobile release builds

### Android

```bash
cd apps/mobile
flutter build apk --release --split-per-abi      # or appbundle for Play
```

- Requires the real `google-services.json` **only if you want the default
  resource wiring** — the guard in `app/build.gradle.kts` applies the plugin
  when present; without it the build still succeeds and `firebase_options.dart`
  drives Firebase (§2.3 is the mandatory part).
- CI (`.github/workflows/ci.yml`) builds a **debug APK artifact** on every
  push — deliberately WITHOUT the real file.

### iOS

On the signing Mac — see `docs/IOS_BUILD.md` (APNs key, capabilities,
`flutter build ipa`).

---

## 4. Backend release

`docs/DEPLOY_COOLIFY.md` §8 (update procedure) — `git pull` → `docker compose
build` → `up -d`; `prisma migrate deploy` runs in the api entrypoint before
serving. For this repo's push schema: the `*_device_tokens` migration is
additive (new table + RLS policy) — safe to deploy freely.

Rollback: `docs/DEPLOY_COOLIFY.md` §10.

---

## 6. Social login — Google + Apple (Task B5)

"Google দিয়ে সাইন ইন" / "Apple দিয়ে সাইন ইন" on the mobile login screen. The
client sends the **provider id_token** to `POST /api/auth/social`; the API
verifies it **locally against the provider's JWKS** (RS256 for Google,
ES256 for Apple — plain `fetch` + WebCrypto `crypto.subtle`, **zero new npm
dependencies**) and links/creates the account **by verified email**
(provider `sub` is stored as the stable fallback — Apple only includes the
email claim on the FIRST authorization).

> **The audience rule (read twice):** the `aud` claim of a Google id_token is
> the OAuth client the token was minted for. The Android app passes the
> **web client id** as `serverClientId`, so Android tokens carry the web
> client id — that single value (`GOOGLE_CLIENT_ID`) is the main audience on
> the server. iOS native Sign in with Apple tokens carry the **app bundle
> id** (`bd.asunnah.sunnahLife`); the web-style Apple flow (Services ID) is
> the alternative. Set the one(s) you use.

### 6.1 Google Cloud console

1. [console.cloud.google.com](https://console.cloud.google.com) → pick the
   SAME project as Firebase (§2 — one project for everything).
2. **APIs & Services → OAuth consent screen**: External, app name
   "Sunnah Life", support email; add the scopes `openid`, `email`,
   `profile` (that is what `google_sign_in` requests); test users while in
   testing mode.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**:
   - **Web application** — no redirect needed for this flow, but its client
     id is the one everyone shares as the token audience. Copy it →
     `GOOGLE_CLIENT_ID` (api env) **and** `--dart-define=GOOGLE_SERVER_CLIENT_ID`
     for the app build (same value, both sides).
   - **Android** — package name `bd.asunnah.sunnah_life` + your SHA-1
     (`keytool -exportcert -alias androiddebugkey -keystore … | sha1sum`).
     Android needs no secret for this flow and **no google-services.json**
     (the plugin takes the server client id in code; no manifest meta-data
     is required by google_sign_in 7.x).
   - **iOS** (optional) — bundle id `bd.asunnah.sunnahLife`; its client id
     goes to `GOOGLE_IOS_CLIENT_ID` on the api (extra accepted audience) and
     optionally `--dart-define=GOOGLE_IOS_CLIENT_ID` in the app.

### 6.2 Apple Developer

1. [developer.apple.com](https://developer.apple.com) → Certificates,
   Identifiers & Profiles.
2. **Identifiers → Services ID** (e.g. `bd.asunnah.sunnahlife.login`) →
   enable **Sign In with Apple** → this id is the web-flow audience →
   `APPLE_SERVICES_ID` on the api.
3. **Keys → Sign in with Apple key (.p8)** — only needed for the web flow /
   server-side token revocation checks; the mobile **native** flow does not
   need a key. Skip it unless you add Apple sign-in to the web PWA later.
4. **App ID** (`bd.asunnah.sunnahLife`): enable the **Sign in with Apple**
   capability (and re-generate the provisioning profiles after).
5. Native iOS id_tokens carry the **bundle id** as `aud` → set
   `APPLE_IOS_BUNDLE_ID=bd.asunnah.sunnahLife` on the api.
   `APPLE_TEAM_ID` is reserved for a future Android/web Apple flow (needs a
   `https://…/auth/callback` redirect on our domain) — leave empty.

### 6.3 Wire the env (api only — the worker never verifies id_tokens)

```dotenv
# .env (compose forwards these to the api container)
GOOGLE_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
#GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
#APPLE_SERVICES_ID=bd.asunnah.sunnahlife.login
APPLE_IOS_BUNDLE_ID=bd.asunnah.sunnahLife
#APPLE_TEAM_ID=
```

Empty values ⇒ provider **disabled**: `POST /api/auth/social` answers 400
("এই সাইন-ইন পদ্ধতি এখন চালু নেই") and `GET /api/auth/providers` returns
false for it, so the mobile buttons stay hidden. This is the sandbox state
by design.

### 6.4 Mobile build flags

```bash
cd apps/mobile
flutter build apk --release --split-per-abi \
  --dart-define=SUNNAH_API_BASE=https://api.sunnahlife.app \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
# iOS additionally (optional; falls back to GoogleService-Info.plist):
#   --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
```

Apple: iOS only (native ASAuthorization — see `docs/IOS_BUILD.md` §9 for
the Xcode capability); the button is hidden on Android.

### 6.5 Account rules (what a release reviewer should know)

- **Linking:** provider `sub` first, then **verified email**
  (case-insensitive; a partial unique index on `lower(email)` guards races).
  Google requires `email_verified: true`; Apple emails are trusted as-is.
- **Gender:** only set at account creation (onboarding) — an existing
  account ignores a gender in the payload. Social accounts created without
  one are stored as `"unspecified"` and the app routes them to the one-time
  gender+name completion screen (`PATCH /api/me`), after which the API
  rejects any change: "লিঙ্গ পরিবর্তন করা যায় না".
- Guest amal entries, referral codes and the session envelope are exactly
  the OTP flow's (shared helpers in `apps/api/src/auth/auth.service.ts`).

---

## 7. Pre-flight checklist

- [ ] `flutter analyze` clean, `flutter test` green (apps/mobile)
- [ ] `bun run lint` + `bun run test` green (apps/api)
- [ ] CI green (mobile debug APK artifact attached)
- [ ] `lib/firebase_options.dart` = real project (no PLACEHOLDER strings)
- [ ] `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) in
      place locally, **not** committed (gitignored)
- [ ] `FCM_SERVICE_ACCOUNT_JSON` set in `.env` → api log shows
      `FCM transport ready (project …)`
- [ ] APNs key uploaded (iOS delivery)
- [ ] one real device end-to-end: sign in → POST /api/push/token 200 →
      broadcast arrives → tap opens the deep-linked screen
- [ ] social login (if enabled): `GOOGLE_CLIENT_ID` (+`APPLE_IOS_BUNDLE_ID`)
      set in `.env` → `GET /api/auth/providers` reports them true → Google
      sign-in on an Android device returns a session; the app build carries
      `--dart-define=GOOGLE_SERVER_CLIENT_ID=<same value>`

---

## 8. App Links — referral deep links (C-W3h)

`https://sunnahlife.app/join/DS-000123` (shared from the Dawah tab) opens the
app with the inviter's code stored as the *pending referral* — the auth screen
shows a "রেফার করেছেন: DS-000123" chip and the code rides along on the next
OTP/social sign-in as `referredByCode` (the server creates the
ReferralClosure rows). The `sunnahlife://join/DS-000123` custom scheme works
too (QR codes, older shares). The web fallback for browsers/never-installed
devices is the branded landing at the same https URL
(`apps/web/src/app/join/[code]`).

Three one-time owner steps make the https variant open *directly* (no
disambiguation sheet) — until then Android shows the chooser, and the landing
page still works everywhere:

### 8.1 Android — the SHA-256 fingerprint (assetlinks.json)

The statement file is committed at
`apps/web/public/.well-known/assetlinks.json` with the placeholder
`REPLACE_WITH_UPLOAD_CERT_SHA256`. Replace it with the **upload key's** cert
fingerprint (Play App Signing signs releases with the upload key):

```bash
keytool -list -v -keystore upload-keystore.jks -alias upload
# copy "SHA256: " line's hex (drop the "SHA256:" prefix), lowercase A-F is fine
```

Deploy the web app after editing. Verify (must return the JSON with a 200 and
`content-type: application/json`):

```bash
curl -s https://sunnahlife.app/.well-known/assetlinks.json | head
adb shell pm verify-app-links --re-verify bd.asunnah.sunnah_life
adb shell pm get-app-links bd.asunnah.sunnah_life   # state: verified
```

Notes: the manifest intent-filter (`apps/mobile/android/app/src/main/
AndroidManifest.xml`) scopes verification to `pathPrefix="/join"` — the rest
of sunnahlife.app stays a normal website. Debug builds are signed with the
debug key, so App Links only verify for release-signed installs
(`internal-test-*` CI artifacts are debug-signed → they get the chooser,
not direct open — expected).

### 8.2 iOS — associated domains (apple-app-site-association)

`apps/mobile/ios/Runner/Runner.entitlements` already declares
`applinks:sunnahlife.app`. On the signing Mac (once per Apple developer
account):

1. [developer.apple.com](https://developer.apple.com) → Certificates,
   Identifiers & Profiles → Identifiers → the app id
   (`bd.asunnah.sunnahLife`) → **Associated Domains** capability on.
2. Copy the 10-character **Team ID** (Membership page) into
   `apps/web/src/app/.well-known/apple-app-site-association/route.ts` →
   `appIDs: ["TEAMID.bd.asunnah.sunnahLife"]` (placeholder
   `REPLACE_WITH_TEAM_ID`) and deploy the web app.
3. Verify: `curl -s https://sunnahlife.app/.well-known/apple-app-site-association`
   — must be the JSON **with `content-type: application/json`**. (It is a
   Next route handler, NOT a static file, precisely so the extensionless
   file can never be served as octet-stream — Apple requires the JSON
   content type.)
4. Rebuild + reinstall the app (the entitlement must be in the provisioning
   profile — a rebuild picks up the refreshed profile automatically).
   Test in Notes/WhatsApp: long-press the join link → "Open in Sunnah Life".

### 8.3 The honest edges

- **Install-boundary gap:** a guest who taps the link in a browser where the
  app is NOT installed sees the landing; the code is persisted in the
  browser's `localStorage` (`sl_join_key`) for a future *web* sign-up — the
  Android/iOS app cannot read the browser's storage. The code only reaches
  the app when a tap actually opens the app (scheme link or verified App
  Link). On the landing, "অ্যাপে খুলুন" (the `sunnahlife://` button) is that
  bridge after an install.
- The pending referral survives app restarts (SharedPreferences) and is
  consumed only on a successful sign-in; a failed verify keeps it.
