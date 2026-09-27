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

## 5. Pre-flight checklist

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
