# Sunnah Life — Human steps (HUMAN_STEPS.md)

The exact steps only a human can do — credentials, accounts, keys and
clicks that no repo commit can provide. Each item: **what to create → where
to paste it (the exact variable/secret name the repo reads) → how to verify**.
Every variable name here was extracted from the code — none are invented.
Where the repo has no hook at all, the item says so honestly (marked
**TODO**).

Companion docs: deployment = docs/DEPLOY_COOLIFY.md; mobile release flow +
Firebase background = docs/RELEASE.md; the Mac runbook = docs/IOS_BUILD.md;
demo accounts = docs/DEMO_ACCOUNTS.md.

| # | Step | Where it lands | § in DEPLOY_COOLIFY |
|---|---|---|---|
| 1 | Firebase project + FCM service account | `FCM_SERVICE_ACCOUNT_JSON` env | §4 api/worker |
| 2 | SMS gateway (SSL Wireless) | `SMS_PROVIDER` + `SMS_SSLWIRELESS_*` env | §8.2 |
| 3 | Google / Apple OAuth client IDs | `GOOGLE_*` / `APPLE_*` env + app build flag | §8 |
| 4 | Android upload keystore | 4 GitHub secrets + 1 repo variable | §8 |
| 5 | iOS build on a Mac (APNs key + capabilities) | Xcode + Apple/Firebase consoles | §8 |
| 6 | Domain + Cloudflare | Cloudflare dashboard | §3, §8.3 |
| 7 | Backups | VPS crontab + off-site bucket | §8.4 |

---

## 1. Firebase — push notifications (FCM)

**What to create** (full walkthrough with screenshots-in-words:
docs/RELEASE.md §2):

1. A Firebase project ([console.firebase.google.com](https://console.firebase.google.com)
   → Add project; Analytics optional — the app sends nothing to GA).
2. Two "apps" inside it: Android `bd.asunnah.sunnah_life` and iOS
   `bd.asunnah.sunnahLife`.
3. A **service account key** for the API: Project settings → Service
   accounts → **Generate new private key** → download the `.json`
   (contains `project_id`, `client_email`, `private_key`).
   Same Google Cloud project → APIs & Services → enable **Firebase Cloud
   Messaging API (v1)**.

**Where to paste:**

| Artifact | Destination |
|---|---|
| service-account `.json` | the `FCM_SERVICE_ACCOUNT_JSON` env var in the Coolify resource (DEPLOY_COOLIFY.md §4) — the FULL object as a one-line JSON string, **or** a path to the file readable by the processes. Coolify passes it to **both `api` and `worker`** (the worker is the main fan-out process — prayer/review pushes). Empty/absent ⇒ the **no-op transport**: pushes are logged, never delivered (exactly today's staging state). |
| `google-services.json` (Android) | `apps/mobile/android/app/google-services.json` — **gitignored**; the committed `google-services.example.json` documents the shape. Optional at runtime: the Gradle plugin applies only when the file exists (CI builds without it), because the config that matters comes from `lib/firebase_options.dart`. |
| `GoogleService-Info.plist` (iOS) | `apps/mobile/ios/Runner/GoogleService-Info.plist` — gitignored (see docs/IOS_BUILD.md §3). |
| real Dart options | run ONCE on a dev machine: `flutterfire configure --project <project-id> --android-package-name bd.asunnah.sunnah_life --ios-bundle-id bd.asunnah.sunnahLife` — this rewrites `lib/firebase_options.dart` in place (the committed file is an explicit PLACEHOLDER). **Commit the rewritten file** — it is not gitignored. |

**How to verify (end-to-end):**

```bash
# 1. transport selected at boot (NOT the no-op line):
docker logs <api-container> 2>&1 | grep PushService
#    → LOG [PushService] FCM transport ready (project <project-id>)

# 2. a signed-in app registers its token (happens by itself after sign-in +
#    notification permission; the endpoint it hits):
#    POST /api/push/token {"token":"<FCM token>","platform":"android"}

# 3. the phone actually rings: send a broadcast from an usrah-head/admin
#    account (web Da'wah tab or admin console) → the phone shows
#    "নতুন ঘোষণা" and tapping it opens the deep-linked screen.
```

(Also the pre-flight list in docs/RELEASE.md §7.)

---

## 2. SMS gateway — SSL Wireless (the provider the repo supports)

**What to create:** an SSL Wireless (Bangladesh) bulk-SMS account — the
client contracts for it; you receive a **user / password** for the v3 HTTP
API (`https://smsplus.sslwireless.com/api/v3/send-sms`) and the **sender id
must be `SUNNAHLIFE`** — it is hard-coded in
`apps/api/src/auth/sms/sms-providers.ts` (the request body sends
`{user, pass, sid: "SUNNAHLIFE", msisdn, sms, csms_id}`), so request exactly
that mask from SSL Wireless.

**Where to paste** (Coolify resource env; DEPLOY_COOLIFY.md §4):

```dotenv
SMS_PROVIDER=sslwireless
SMS_SSLWIRELESS_URL=https://smsplus.sslwireless.com/api/v3/send-sms
SMS_SSLWIRELESS_USER=<ssl-wireless-user>
SMS_SSLWIRELESS_PASS=<ssl-wireless-password>
```

The alternative provider the repo wires is Infobip (`SMS_PROVIDER=infobip` +
`SMS_INFOBIP_URL` / `SMS_INFOBIP_KEY`) — one or the other, never both.

**Why it cannot be skipped:** in production the API **refuses to boot** with
`SMS_PROVIDER=mock` ("OTP would be returned in the response"), and refuses
`sslwireless` with any of the three credentials missing
(`apps/api/src/config/env.validation.ts`). Staging may stay on `mock` — the
OTP comes back as `devCode` in the API response (docs/DEMO_ACCOUNTS.md §3).

**How to verify:** with the env set, redeploy (DEPLOY_COOLIFY.md §7), then
request an OTP from a REAL phone (the app's sign-in screen) → the SMS
arrives on that phone within seconds and `docker logs <api-container>` shows
no `sslwireless rejected sms` warning. A wrong sender id surfaces as a
`sms_status ≠ SUCCESS` warning line in the same log.

---

## 3. Google / Apple OAuth client IDs

**What to create:**

- **Google** (docs/RELEASE.md §6.1): in the SAME Google Cloud project as
  Firebase (item 1), create OAuth client IDs:
  - a **Web application** client id — this single value is the token
    audience everyone shares;
  - an **Android** client (package `bd.asunnah.sunnah_life` + your signing
    SHA-1: `keytool -exportcert -alias androiddebugkey -keystore … |
    sha1sum` for debug, the upload key's SHA-1 for release);
  - optionally an **iOS** client (`bd.asunnah.sunnahLife`).
- **Apple** (docs/RELEASE.md §6.2): enable **Sign In with Apple** on the App
  ID `bd.asunnah.sunnahLife`; optionally create a Services ID + .p8 key
  (only needed for a future web-flow; the native iOS flow needs neither).

**Where to paste:**

| Value | Destination |
|---|---|
| web client id | `GOOGLE_CLIENT_ID` env (Coolify resource; api only — the worker never verifies id_tokens) **and** the app build flag `--dart-define=GOOGLE_SERVER_CLIENT_ID=<same value>` (`apps/mobile/lib/services/social_signin_service.dart` reads it) |
| iOS client id (optional) | `GOOGLE_IOS_CLIENT_ID` env (extra accepted audience) + optional `--dart-define=GOOGLE_IOS_CLIENT_ID=…` |
| Apple Services ID (optional) | `APPLE_SERVICES_ID` env |
| iOS bundle id | `APPLE_IOS_BUNDLE_ID=bd.asunnah.sunnahLife` env (native ASAuthorization tokens carry the bundle id as `aud`) |
| Apple team id | `APPLE_TEAM_ID` — **leave empty**: reserved for a future Android/web Apple flow that does not exist yet |

Empty values ⇒ provider disabled (by design): `POST /api/auth/social`
answers 400 (Bengali) and the mobile buttons stay hidden — that is today's
staging state and it is safe.

**How to verify:**

```bash
curl -s https://<api-domain>/api/auth/providers
#  → {"google":true,"apple":false}   (once each env var is set + redeployed)
```

then on a real device: Google sign-in returns a session (the app build must
carry the matching `GOOGLE_SERVER_CLIENT_ID` dart-define — a mismatch shows
up as the api rejecting the id_token audience); Apple sign-in on an iPhone.

---

## 4. Android upload keystore → GitHub secrets

Play requires release builds signed with your own key. Until this is done,
the CI release jobs produce **debug-signed** artifacts named
`internal-test-*` — installable on the owner's phone, NOT uploadable to
Play (that is today's state, by design).

**What to create** (once, keep the file + passwords safe FOREVER — Play
tracks this key):

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Where to paste — the four EXACT secret names the release jobs read**
(`.github/workflows/ci.yml`, jobs `Flutter — release APKs · split-per-ABI
(device test)` and `Flutter — release App Bundle (secrets-gated)`):

GitHub → **Settings → Secrets and variables → Actions → Secrets**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the keystore, base64: `base64 -w0 upload-keystore.jks` (Linux) or `base64 -i upload-keystore.jks` (macOS) — CI undoes it with `echo "$ANDROID_KEYSTORE_BASE64" \| base64 --decode > app/upload-keystore.jks` |
| `ANDROID_KEY_ALIAS` | `upload` (the `-alias` from the keytool command) |
| `ANDROID_KEY_PASSWORD` | the key password you typed |
| `ANDROID_STORE_PASSWORD` | the keystore (store) password |

CI writes `android/key.properties` itself from those secrets
(`storeFile=upload-keystore.jks`, `keyAlias`, `keyPassword`,
`storePassword` — the exact keys `android/app/build.gradle.kts` reads);
you never commit key.properties or the .jks.

**Also set the repository VARIABLE (not a secret) the same release jobs
fail-closed on:** Settings → Secrets and variables → Actions →
**Variables** → `SUNNAH_API_BASE` = the public API origin the builds should
target (current value: `https://api-staging.sunnahlife.ailearnersbd.com`;
production: the client's api domain). Both release jobs refuse to build
without it — a build silently targeting the placeholder default cannot
sign in.

**How to verify:** push any commit to main → the **release-apk** job's
summary shows "Signing: upload keystore (store-signed)" (instead of "DEBUG
key (device-test only)") and the artifacts are named `mobile-release-arm64-v8a`
/ `mobile-release-armeabi-v7a` (instead of `internal-test-*`); the
`mobile-release-aab` bundle artifact appears once the same secrets exist.
Then replace the `REPLACE_WITH_UPLOAD_CERT_SHA256` placeholder in
`apps/web/public/.well-known/assetlinks.json` with this key's SHA-256
(`keytool -list -v -keystore upload-keystore.jks -alias upload`) so App
Links verify on release installs (docs/RELEASE.md §8.1).

---

## 5. iOS build on a Mac

The iOS runner is **code-complete in-repo but has never been compiled** (no
macOS host anywhere in this project's pipeline). The full runbook is
docs/IOS_BUILD.md; the honest split:

**Already automated / in the repo (nothing to do but build):**

- the Xcode runner project, `Runner.entitlements` (APNs `aps-environment`,
  Sign in with Apple, associated domains for `applinks:sunnahlife.app`),
  `Info.plist` background modes, the `AppDelegate.swift` APNs-token bridge
  (docs/IOS_BUILD.md §1, §7);
- the Dart side of push (`lib/services/push_service.dart` — permission +
  `POST /api/push/token` after sign-in) and Apple sign-in
  (`lib/services/social_signin_service.dart`).

**Manual, on the Mac (once per machine + Apple account):**

1. Xcode 16+, Flutter ≥ 3.47, CocoaPods, a paid Apple Developer Program
   membership (the free team cannot create push profiles).
2. `flutterfire configure --project <project-id>` (item 1) +
   `GoogleService-Info.plist` in place.
3. **APNs auth key** — Apple Developer → Keys → generate a `.p8` with the
   *APNs* checkbox → upload it in the Firebase console (Project settings →
   Cloud Messaging → Apple apps → APNs Authentication Key) + team id + key
   id. Without it, FCM accepts server sends but **iPhones never receive**.
4. Xcode → Runner target → Signing & Capabilities: your Team; toggle
   **Push Notifications**, **Background Modes → Remote notifications**,
   **Sign in with Apple** (and Associated Domains for the join links) so
   the provisioning profile carries the entitlements the repo declares.
5. `cd apps/mobile && flutter pub get && cd ios && pod install && cd ..`
   → `flutter run` on an iPhone → sign in → allow notifications.
6. Distribute: `flutter build ipa` → Organizer → TestFlight. Verify push on
   a TestFlight build with a real SIM.

**FamilyControls — the honest state.** The task list mentions a
FamilyControls entitlement request; **the repo today uses no Family
Controls / Screen Time API**. The social-media detox feature
(`DetoxScreen`, the `sunnahlife/usage` MethodChannel) is **Android-only by
design** — it reads UsageStats, which iOS has no equivalent for, and the
iOS path surfaces "unsupported" instead (worklog W4d: "detox is
Android-only by design (iOS has no UsageStats equivalent — honest screen
state on other beds)"). `Runner.entitlements` declares no
`com.apple.developer.family-controls`. **TODO (product decision, not a
bug):** if the client wants iOS parity for detox/screen-time shielding,
Apple requires requesting the Family Controls entitlement through the
developer-account request form (Identifiers → the App ID → Capabilities →
Family Controls → request), plus a DeviceActivity/Shield extension that
does not exist in this repo yet. Nothing to configure today.

---

## 6. Domain + Cloudflare

**What to create:** proxied DNS records for the three public hostnames,
pointing at the VPS IP (staging used `api-staging.sunnahlife.ailearnersbd.com`;
production = the client's own domain):

| Type | Name | Content | Proxy |
|---|---|---|---|
| `A` | `app.<domain>` (web) | VPS IP | **on** (orange cloud) |
| `A` | `admin.<domain>` | VPS IP | **on** |
| `A` | `api.<domain>` | VPS IP | **on** |

Then in the Coolify resource set the domains per service with the right
container ports (web → 3000, admin → 3000, api → 4000 — DEPLOY_COOLIFY.md §3)
and align the env: `NEXT_PUBLIC_API_BASE=https://api.<domain>` (rebuild!),
`CORS_ORIGINS=https://app.<domain>,https://admin.<domain>`,
`APP_DOMAIN=<domain>`.

**Cloudflare settings that matter:**

- **SSL/TLS mode: Full (strict)** — Coolify's Traefik serves the origin
  cert; "Flexible" would terminate TLS at the edge and is not acceptable
  for sisters' data.
- **WebSockets: ON** (default, but verify per-zone) — the live usrah quiz
  rides socket.io **on the api's own HTTP server at the `/socket.io` path**
  (`apps/api/src/main.ts`); any rule disabling websockets must exclude the
  api hostname.
- Recommended cache rules: cache `/_next/static/*` and `/icons/*`
  (immutable, 1 year); bypass cache for the api hostname.
- Web + admin get additional records only if served on subdomains — one
  zone, three hostnames, all proxied.

**How to verify:**

```bash
curl -s https://api.<domain>/health/live        # {"status":"ok",...}
curl -s -o /dev/null -w "%{http_code}\n" https://app.<domain>/   # 200
# websocket path end-to-end: open the web app on two devices in the same
# usrah, start a live quiz — both screens join the same room (the
# /socket.io upgrade in the browser devtools' Network tab shows 101).
```

---

## 7. The backup bucket

**The honest state first:** the repo has **no backup env vars** — nothing
like `BACKUP_*` or `PGBACKREST_*` exists in `.env.example`, the compose
files, or `apps/api/src` (the `S3_*` family is the API's own
storage-for-uploads config, not a backup hook). Backups are a human
arrangement around the running stack; nothing in the repo schedules them.

**What already exists (built into the Coolify stack):**

- Postgres runs with `archive_mode=on` and an `archive_command` that copies
  every WAL segment into `pgdata/walarchive/` **inside the `pgdata`
  volume** (DEPLOY_COOLIFY.md §8.4) — point-in-time-recovery raw material.
- `infra/postgres/pgbackrest.conf` — a ready pgBackRest template (remote S3
  repo, AES-256 repo encryption, retention 2 full + 6 diff, 30-day archive)
  with placeholders marked `<…>` for the bucket/keypair.

**What the owner must arrange (the manual part):**

1. An off-site S3 bucket + keypair (AWS S3 / Backblaze B2 / Wasabi — any
   S3-compatible provider) and fill the `<…>` placeholders
   (`repo1-s3-*`, `repo1-cipher-pass`) in a copy of
   `infra/postgres/pgbackrest.conf` on the VPS.
2. A nightly cron on the VPS running the pgBackRest one-shot container
   over the stack's `pgdata` volume (find the volume with
   `docker volume ls | grep pgdata` — Coolify prefixes its own project
   name), roughly:
   ```bash
   docker run --rm \
     -v <pgdata-volume>:/var/lib/postgresql/data:ro \
     -v /path/to/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro \
     pgbackrest/pgbackrest:latest --stanza=sunnahlife --type=full backup
   ```
   One honest caveat: the committed conf's `[sunnahlife]` stanza connects
   over the **unix socket** (`pg1-socket-path`), matching the dev stack's
   shared `pgsocket` volume — the Coolify stack has no such volume, so for
   it either point `pg1-host`/`pg1-port` at the postgres container with
   `POSTGRES_PASSWORD`, or add a matching socket-volume mount to the
   one-shot container.
3. A copy of the `apistorage` volume (generated PDFs/reports — small):
   `docker run --rm -v <apistorage-volume>:/data -v <backup-dir>:/backup
   alpine tar czf /backup/apistorage-$(date +%F).tgz -C /data .`
4. **A restore drill, once, before it is needed** (a backup that has never
   been restored is a hope, not a backup).

**How to verify:** `docker run --rm … pgbackrest/pgbackrest:latest info`
lists the stanza with today's full backup; restore into a scratch volume and
boot a throwaway postgres against it.

---

*Each of these steps changes only Coolify env / external accounts / local
gitignored files — no code change, no commit. The repo never needs a
credential committed.*
