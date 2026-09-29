# AUDIT — master-prompt §4–9 requirement-by-requirement status

Honesty rules: **Done** = the implementing files exist AND the listed command
reproduces the proof on a fresh clone. **Partial** = shipped with a stated
limitation. **Not done** = stated plainly. Last verified at commit below.

| Area | Status | Implementing files | Proof (command / test) |
|---|---|---|---|
| **§4 Domain model — 22 models, closure table, day-lock** | | `apps/api/prisma/schema.prisma`, `apps/api/prisma/migrations/` | |
| User/ReferralClosure/Usrah/Amal/WeeklyReview/Assessment/… exact shape | Done | schema + 6 migrations | `cd apps/api && bunx prisma migrate status` → up to date; `psql` count: 22 tables |
| AmalEntry day-lock after next-day Ishraq (server-enforced) | Done | `apps/api/src/amal/amal.service.ts` | `cd apps/api && bun run test` → amal.spec (day-lock cases) |
| DS-code referral closure tree | Done | `apps/api/src/dawah/` | `curl :3001/api/dawah` (daee) → downline + requirements |
| **§5 Roles & gender rule — in the DATABASE** | | | |
| Postgres RLS: 15 policies via SET LOCAL (app.user_id/gender/usrah_id/role) | Done | `apps/api/prisma/migrations/*_rls`, `src/common/rls.service.ts` | `cd apps/api && bun run test` → rls.e2e.spec (cross-gender SELECT = 0 rows) |
| Gender set at onboarding, locked; only Full Admin changes (audited) | Done | `src/me/me.controller.ts` (rejects change), `src/admin/` | `curl -X PATCH /api/me {gender}` → 400 "লিঙ্গ পরিবর্তন করা যায় না"; admin PATCH writes AuditLog |
| RolesGuard + @Roles() explicit at API layer | Done | `src/common/roles.guard.ts`, `roles.decorator.ts` | gateway matrix in worklog B1: user→403, head→200, admin→200 |
| **§6 Features** | | | |
| Prayer times (adhan_dart on-device, 64 BD districts, hijri/bengali calendars) | Done | `apps/mobile/lib/core/prayer*`, `apps/web/src/lib/prayer-times.ts` | `flutter test` (prayer_snapshots_test); browser: home countdown + triple calendar |
| Post-prayer জামাত/একা/কাযা prompt (20 min after waqt) | Done | `apps/mobile/lib/features/amal/` (post-prayer dialog) | `flutter test` (amal_logic_test) |
| Muhasaba diary — 31-item catalog faithful to paper forms | Done | `packages/content/amal-catalog.json`, `apps/api/src/amal/` | `curl :3001/api/amal/definitions` → 31 |
| Auto-logging from adhkar + Qur'an screens | Done | `apps/mobile/lib/features/ilm/*` (autoSource writes) | `flutter test` (smoke + amal tests) |
| Weekly review: auto-pending every 7 days, head reviews | Done | `apps/api/src/reviews/`, worker weekly-reviews | `curl :3001/api/reviews?scope=queue` (head) |
| 23-criterion assessment, majority-per-section rule | Done | `apps/api/src/assessments/`, `packages/content/assessment-farze-ain-v1.json` | `bun run test` → assessment.spec (majority rule cases) |
| Offline-first sync (Drift + outbox + conflict rules) | Done | `apps/mobile/lib/db/database.dart` (in git since B0), `core/sync_merge.dart` | fresh clone: `flutter test` → sync_conflict_test |
| **§6 (Phase B additions)** | | | |
| Push notifications (FCM HTTP v1, no SDK) + device tokens (RLS) + deep links | Done | `apps/api/src/push/`, `apps/mobile/lib/services/push_service.dart` | `bun run test` → push.spec + rls.e2e device-token cases; api.log "(no-op) would send" |
| Gender-aware usrah broadcast fan-out | Done | `src/push/` sendToUsrah + RLS on DeviceToken | rls.e2e: cross-gender token SELECT = 0 |
| Monthly Muhasaba PDF (paper-form layout, Bengali shaping) | Done | `apps/api/src/reports/`, `src/storage/`, processor | `pdftotext -l 1` output in this report; `curl POST /api/admin/reports/generate` → 200 |
| PDF in MinIO/S3 + admin list + download + manual trigger | Partial | same + `apps/admin exports page` | download → 200 (local adapter; S3 adapter active when S3_* env set — MinIO not runnable in sandbox) |
| Courses (2×5 Bengali lessons), enrollments, progress | Done | `packages/content/courses.json`, `src/engagement/`, **mobile `apps/mobile/lib/features/ilm/courses_screen.dart`** (list → detail → lesson player, enroll + progress sync) | `curl :3001/api/courses` → 2; detail → 5 lessons each; `flutter analyze` 0 · `flutter test` 65/65 (fresh clone, this report) |
| Quizzes (3×10 MCQs + explanations), attempts with scoring | Done | `packages/content/quizzes.json`, `src/engagement/`, **mobile `apps/mobile/lib/features/ilm/quizzes_screen.dart`** (player + attempt submit) | `curl :3001/api/content/quizzes` → 3×10; quiz-attempt 201; browser E2E: quiz played, answer locked + explanation shown (this report) |
| Usrah questions (head assigns/answers, RLS) | Done | `src/engagement/ilm.controllers.ts`, **mobile `apps/mobile/lib/features/dawah/usrah_questions_screen.dart`** (ask + head answers in the Dawah tab) | POST/GET usrah-questions → 201/list; browser E2E: question asked + head answer published → both render (this report) |
| Live quiz over WebSocket + per-gender leaderboard | Done | `apps/api/src/engagement/quiz.gateway.ts` — **folded INTO the NestJS process** (B9; the :3030 bun mini-service is deleted): one backend, one auth (HMAC room token minted by `GET /api/quiz/live-token` after JWT+RLS), same wire protocol; `usrah.controller.ts` also got `@Roles` | `cd apps/api && bun run smoke:quiz` → 21/21 PASS; socket through Caddy `/?XTransformPort=3001` path `/socket.io` (polling + websocket both); browser E2E: full host round (start → প্রথম প্রশ্ন → reveal → next → end) via the gateway (this report); **mobile `live_quiz_screen.dart`** on socket_io_client |
| Google + Apple Sign-In (link by verified email) | Partial | `src/auth/social/`, mobile `social_signin_service.dart` | jest social-auth.spec green; LIVE needs GOOGLE_CLIENT_ID/APPLE_SERVICES_ID env (documented RELEASE.md) — not settable in sandbox |
| Gender asked at onboarding, locked after (incl. social path) | Done | `me.controller` lock + `gender_completion_screen.dart` | social-auth.spec + flutter test |
| Level automation (nightly rules → transition + audit + reminder) | Done | `src/levels/`, `src/queues/processors/levels.processor.ts` | worker log: levels-nightly registered; GET /api/dawah/requirements live checklist |
| Dawah tab live requirements checklist ("৩/৫ জন…") | Done (web **and mobile**) | `apps/web/src/components/dawah/dawah-view.tsx` + `apps/mobile/lib/features/dawah/dawah_requirements_screen.dart` (B9; entry from the Dawah overview section) | browser: স্তরের প্রয়োজনীয়তা renders live data; `flutter analyze` 0 (fresh clone) |
| Amal catalog CRUD (create/update/reorder/disable) | Done | `src/admin/admin.controller.ts` + admin catalog page | PATCH /api/admin/amal-catalog/:key → 200; reorder → 200; audit rows written |
| Versioned assessment templates | Done | `AssessmentTemplate` model + admin endpoints | prisma schema + admin templates UI |
| Usrah management (create, assign head/invigilator, move members) | Done | same controller + admin usrah page | POST /api/admin/usrah → 201 (উসরা আল-ইখলাস) |
| Audited role/gender changes (Full Admin, reason) | Done | `src/admin/` (AuditLog on every mutation) | audit list shows update/reorder/create/move entries |
| Live program CRUD (admin) | Done | `src/admin/` + admin live page | build + admin code path (not curl-proven in this run) |
| Mosques (≥20 Dhaka w/ coords) | Done | `packages/content/mosques.json` | `curl :3001/api/content/mosques` → 24 |
| FAQ (≥15 Bengali) | Done | `packages/content/faq.json` | `curl :3001/api/content/faq` → 16 |
| Full Qur'an + Bengali translation | Done | `packages/content/quran-*.json`, `src/content/` | `curl :3001/api/quran/surahs` → 114; surah/1 with অনুবাদ |
| 15-page admin panel | Done | `apps/admin/app/(dash)/*` (15 pages) | static code review + prior round-4 build |
| **§7 Design system** | | `packages/design-tokens/`, DESIGN_SYSTEM.md | |
| Tokens (colors/type/spacing) as single source, parity-checked | Done | `packages/design-tokens/build.mjs` | `node build.mjs --check` → "70 color values verified" |
| Skeletons/empty/error states, haptics, no default Material look | Done | mobile + web views | browser E2E (guest/empty/loading states observed) |
| **§8 Engineering quality bar** | | | |
| i18n bn/en/ar + RTL (mobile ARB + gen-l10n) | Partial | `apps/mobile/lib/l10n/*.arb` + generated | `flutter test` (ARB consistency tests); Arabic onboarding → dir="rtl". Gap: a few onboarding strings fall back to Bengali in ar; admin stays bn-only (RTL-ready classes) |
| Web i18n bn/en/ar + logical CSS + RTL | Done | `apps/web/src/lib/i18n.ts` (77 keys × 3), shell dir switch | browser: Arabic UI (الرئيسية/الأعمال/العلم/المزيد) with RTL |
| Accessibility: Semantics, 44×44 targets, 1.3× text scale | Partial | mobile sweep + web tap-target/aria | `docs/A11Y_CONTRAST.md` (all PASS). Gap: Semantics coverage is broad-but-not-exhaustive on mobile; noted honestly |
| WCAG AA contrast both themes | Done | tokens.json fixes (gold-text, alert) | `docs/A11Y_CONTRAST.md` — 14 pairs PASS |
| API lint/tests/typecheck | Done | apps/api | `bun run lint` 0 · `bunx tsc --noEmit` 0 · `bun run test` 133/133 (9 suites) |
| Mobile analyze/tests | Done | apps/mobile | `flutter analyze` → No issues · `flutter test` → 65/65 |
| Web typecheck | Done | apps/web | `bunx tsc --noEmit` → exit 0 (verified on a FRESH CLONE — the generated `packages/shared-types/dist/schema.d.ts` is committed; found un-committed by B9 fresh-clone verification) |
| Swagger/OpenAPI | Done | `src/main.ts` DocumentBuilder | `GET :3001/openapi.json` |
| CI green (lint/test/build on GitHub runners) | Done — run #25 all-green (2026-09-28) | `.github/workflows/ci.yml` (8 jobs: workspace probe → 5 gated jobs + release-bundle + report) | Actions API evidence: run #25 (id 36389041267, sha 3d632c0) conclusion=success — tokens/api/web/admin/mobile/release-bundle/report ALL success. Three stacked bugs fixed to get there: (1) job-level `if: hashFiles()` invalid → workspace probe job (2bbb55b); (2) after the billing lock was lifted (runs #23–#24): zod `.min(8).default("")` rejected every boot without .env (JWT_REFRESH_SECRET refine fix) + flutter 3.47.5 gradle script errors (java.util shadowing import; newDsl=false flags are load-bearing for the flutter plugin's legacy AbstractAppExtension cast; ndkVersion pinned) (7056ca3); (3) jest 3 parallel workers on 4-vCPU runners raced shared demo phones (OTP newest-code-wins + concurrent consume) → --runInBand + verifyOtp updateMany hardening (3d632c0). Local proofs: jest 133/133 with the exact CI invocation; gradle scripts compile + flutter plugin applies (sandbox stopped only at disk for the NDK) |
| Debug APK artifact on CI | Done — verified end-to-end | mobile job → `actions/upload-artifact@v4` (`if-no-files-found: error`) | run #25 artifact `mobile-debug-apk` (id 10955835922): 386.3 MB zip, downloaded via the Actions API, zip CRCs pass, inner `app-debug.apk` is a valid Android package (1128 MB uncompressed) with AndroidManifest, classes.dex, flutter engine .so (arm64-v8a + armeabi-v7a + x86_64), libsqlite3.so, flutter_assets. Known nuance: Flutter's debug packaging ships all 3 engine ABIs (the defaultConfig abiFilters arm64 only restricts packaging, and the flutter gradle plugin controls debug ABIs) — a universal debug APK, hence the size; split-ABIs can be revisited if artifact size matters
| Release appbundle behind secrets | Done (gated) | release-bundle job | skips cleanly without ANDROID_KEYSTORE_BASE64; builds+uploads `mobile-release-aab` with it |
| **§9 / delivery** | | | |
| Single backend (web + mobile + admin → NestJS; no SQLite mirror) | Done | B1 restructure | NestJS access log lines for browser traffic (this report); root prisma/db/api deleted |
| DEPLOY_COOLIFY runbook | Done | `docs/DEPLOY_COOLIFY.md` (11 §) | services/env/volumes/pgBackRest/Cloudflare/health/rollback |
| IOS_BUILD / RELEASE human steps | Done | `docs/IOS_BUILD.md`, `docs/RELEASE.md` | written (B2/B5) — the console steps themselves need a human |
| Demo accounts doc | Done | `docs/DEMO_ACCOUNTS.md` | seeded phones work (this report uses them) |

## Explicitly Not done / out of sandbox

1. **Real push delivery** — no Firebase project exists in the sandbox; the
   FCM adapter is code-complete (HTTP v1 via fetch) but untested against a real
   device. No-op transport logs in `apps/api/api.log`.
2. **Google/Apple live login** — needs client IDs (env) + store apps; JWKS
   verification is unit-tested.
3. **iOS build** — code + entitlements + docs only (no macOS in sandbox);
   `docs/IOS_BUILD.md` lists the remaining Xcode steps.
4. **S3/MinIO upload of reports in the sandbox** — MinIO binary not
   available/downloadable within disk limits; the storage service uses the
   local-dir adapter here and the `minio` client adapter when `S3_*` env is
   present (compose wires MinIO in prod).

## B9 close-out (surface parity + one-backend live quiz)

The post-Phase-B audit found three gaps; all closed in this round:

| Gap | Status now | Proof |
|---|---|---|
| Courses/quizzes/live-quiz/usrah-questions had NO Flutter UI | Done — mobile screens shipped (`apps/mobile/lib/features/ilm/courses_screen.dart`, `quizzes_screen.dart`, `live_quiz_screen.dart`, `dawah/usrah_questions_screen.dart`, `dawah/dawah_requirements_screen.dart`) | `flutter analyze` → No issues · `flutter test` → 65/65 · ARB parity 408/408/408 |
| Live quiz was a separate bun mini-service (:3030) outside NestJS | Done — folded into the API (`quiz.gateway.ts`, `IoAdapter`); mini-service deleted | `bun run smoke:quiz` → 21/21; Caddy polling+ws both PASS; browser E2E full host round |
| `usrah.controller.ts` lacked `@Roles` | Done — `@UseGuards(RolesGuard)` + `@Roles("user")` | `bun run test` → 133/133 (incl. usrah coverage) |
| (found during B9 E2E) web আরও tab was unreachable; `QuizzesSection` was dead code; host panel could not advance past the lobby | Done — fixed (`ilm-view.tsx` routeIlm cases, extras wiring, API_PORT export, প্রথম প্রশ্ন button) | browser E2E in worklog B9-e: grid reachable, quiz played, live round completed |


## Phase C close-out — Wave 1 (shared plumbing) & Wave 2 (production blockers)

Baseline tag: `v0.9-pre-phase-c`. Full narrative in `worklog.md` (entries C-W1..C-W2d); evidence trail in the linked CI runs.

| Item | Status | Proven by |
|---|---|---|
| User.tz + tz-correct scheduling (push epochs, weekStart, lock deadline) | Done | `test/tz.spec.ts` (Dhaka/Riyadh/London) — part of the 248/248 suite |
| Consolidated /api/config (contacts, hijri adjust, donation, flags) | Done | `test/config.spec.ts` + admin PATCH route audited |
| Content pipeline (packages/content → mobile assets; CI parity gate; 114-surah pack) | Done | CI `Content parity gate` step (run 36448583413 lineage green since 1b2b593) + `test/content-packs.spec.ts` (30 tests) + mobile quran-meta canary (flutter test) |
| Monorepo hygiene (bun workspaces, one lockfile, generated client committed, no sandbox leftovers, CI writes no commits) | Done | fresh-clone gates in B11 lineage + CI green since |
| Part D verbatim content (farze_ain_v1.1 23 criteria, Muhibbus outline, ladder fix, diary rules) | Done | `test/levels.spec.ts` + `test/content-packs.spec.ts` asserts; template row via admin API |
| Seed split (reference idempotent on boot; demo gated SEED_DEMO + non-production) | Done | `test/seed-split.spec.ts` (4 tests incl. boot-twice row stability + production refusal) |
| Real SMS (SSL Wireless + Infobip) + OTP hardening | Done (code); live delivery needs real creds | `test/auth-otp.spec.ts` + `test/token-security.spec.ts`; **real SMS delivery: Ready for device/creds test** — providers are env-wired, mock refused in production |
| Token & secret handling (typ claims, separate refresh secret, atomic rotation, production env gate, CORS on gateway) | Done | `test/token-security.spec.ts`; CI production-validation refuses bad env (proven by the compose smoke booting with full env) |
| RLS tightening (DayUnlock policies, OtpCode/AuditLog/MasalaQuestion/Feedback RLS, self-role/gender trigger, worker role restricted, same-gender review fallback) | Done | `test/rls.e2e.spec.ts` 23/23 — twice in a row (re-runnability proof after the supertest listener + DayUnlock-cleanup fixes) |
| Push delivery (RFC 7523 jwt-bearer, token cache, device-token takeover) | Done (code); real FCM delivery needs a Firebase project | `test/push.spec.ts` 22/22 incl. mocked-endpoint grant/cache/refresh + takeover; **real device push: Ready for device test** |
| Sync & guest merge hardening (strip bug, clamped LWW, conditional writes, inputType validation, source guard, serverValue, capped ordered merge) | Done | `test/conflict.spec.ts` + `test/social-auth.spec.ts` through the REAL APP_PIPE (248/248) |
| Operations (/health 503, internal-only /metrics + /docs, structured logger + PII redaction, socket.io redis adapter, durable compose) | Done (code) | `test/health-ops.spec.ts` + `test/docs-gating.spec.ts`; quiz smoke 21/21 ×3 through the adapter; compose itself proven by the docker job |
| Docker images + compose smoke | Done — GREEN (run 36454553711, confirmed clean on 36455455278) | CI `docker` job: builds the images, `up --wait`, api /health status:ok (migrations + seed:reference completed), web :3000 + admin :3002 HTTP 200, AmalDefinition count ≥ 30. The job caught SIX real bugs on its way green: MinIO unpullable anonymously anywhere (CI override → local-storage adapter); postgres archive_command missing its GUC name; root-owned walarchive volume (moved inside pgdata); non-idempotent test-!-f archive idiom; pg_isready unix-socket race (api P1001 crash loop); the api image NEVER shipped the generated Prisma client (tsc does not compile generated JS — masked locally by a gitignored dist symlink); worker missing SMS creds in production mode |

**Known deferred:** real FCM/device push, real SMS credentials, social-login client IDs, iOS build — all documented as owner-side human steps (docs/RELEASE.md, docs/IOS_BUILD.md); quiz rooms remain single-instance by design until state is externalized (compose comment).

## Phase C — Wave 3 (Part B · "what breaks on a real phone")

Full narrative in `worklog.md` (entries C-W3a..C-W3i-CI). Evidence: local analyze 0 / 226/226 raw tails in each section + CI runs cited. The golden test files carry their own determinism contracts in-file.

| Item | Status | Proven by |
|---|---|---|
| Notification receivers were NEVER declared — every scheduled bell/post-prayer prompt silently never fired on a real phone (W3b) | Done | manifest statics committed; `flutter analyze` 0 + bell-schedule unit tests; **CI mobile job green on run 36474538959 lineage — but the actual on-device fire is a device test** (PHONE_TEST_CHECKLIST item) |
| tz.local never set — zonedSchedule broken on-device; exact-alarm denied → throw; monochrome icon only on FCM (W3b) | Done | flutter_timezone wiring + inexact fallback path; unit tests for the fallback decision; device confirmation pending (honest) |
| Rolling 3-day bell window + reschedule on city/madhhab/method change + daily WorkManager re-arm (W3b) | Done | `test/bell_schedule_test.dart` (id scheme, triggers) + `workmanager` periodic task registered; CI green |
| Post-prayer জামাতে/একা/কাযা notification action buttons write the diary from a dead app (W3b) | Done (code) | background-isolate Drift write mirroring the in-app prompt exactly (value jamaat/alone/qaza, source auto:prayer:*); unit tests for payload/action mapping; **needs the owner's phone to tap for real** |
| Per-waqt "N minutes before/after" bell timing (W3b) | Done | long-press bell → timing sheet; clamp unit tests; l10n ×3 |
| Qur'an reader: 5MB main-isolate parse, first-open race, keyboard-closing search, scroll-jumping toggles (W3a) | Done | compute() isolate decode; single-flight + per-surah memoization; reader suite 30 tests; goldens bn light/dark + ar RTL (VLM-verified in-file contract) |
| **Dart 3.13.4 hazard**: `map[k] ??= fut.whenComplete(() => map.remove(k))` NEVER completes — would have deadlocked the reader in production | Found + worked around | minimal repro pinned by `test/quran_reader_test.dart` hazard regression group (toxic shape times out; restructured shape resolves) |
| Recitation audio (per-ayah, cached, 4 reciters, auto-advance) (W3a) | Done (code) | everyayah.com URLs live-verified during the build (404 vs 200 evidence in quran_audio.dart doc); playback needs a real device/network |
| Go-to-ayah + resume-from-last-read (W3a) | Done | bn+ASCII digit parsing, two-step jump; unit tests |
| Sync pull on login/app-start + bounded rejected retries + unstuck syncing + visible sync state (W3d) | Done | 21 new tests (policy matrix, watermark, flush-finally, v1→v2 migration on a raw sqlite file); sync sheet golden (VLM-verified) |
| Location + snap-to-district + qibla live compass + mosques near me (W3c) | Done | geolocator + flutter_compass; 26 pure tests (snap matrix, bearing, permission gate); compass heading magnetic-vs-true documented; **GPS on-device: Ready for device test** |
| Auto-silent (DND) settings screen + jama'at windows via Kotlin AlarmManager (W3e) | Done (code) | 19 unit tests (windows, clamps, prefs codec, arms); Kotlin receiver static-verified; **ringer flips need the owner's phone** |
| Home widget persists + survives process death + boot restore (W3f) | Done (code) | shared Kotlin render path (live + persisted); boot receiver + 15-min inexact re-render; contract test pins the snapshot shape; **widget on a home screen: device test** |
| Admin hijri ±adjust applied everywhere + donation Custom Tabs + More tile (W3g) | Done | effective adjust (user+admin, clamp ±4) matrix tests; nisab fallback parity test reads the committed pack; URL gating tests |
| Referral links: web /join/<code> landing + assetlinks + autoVerify + app_links prefill (W3h) | Done | dev-server smoke: /join/DS-000123 → 200 with og meta, /join → 307, .well-known both → 200; 12 mobile tests (parsing, storage, end-to-end wire through MockClient); app-Links VERIFICATION needs the owner's upload-key SHA-256 (placeholder committed, RELEASE.md §8) |
| Release split-per-ABI APK job + < 40 MB gate (W3i) | **Done — CI-proven on first run** | run 36474538959 job `Flutter — release APKs · split-per-ABI`: arm64 26,665,649 B (25.4 MB), armv7 24,435,193 B (23.3 MB), gate passed; artifacts `internal-test-arm64-v8a` (13.28 MB zipped) + `internal-test-armeabi-v7a` — **the owner's device-test release build, downloadable NOW (debug-signed until keystore secrets are set)** |
| keepDebugSymbols + misleading abiFilters removed (W3i) | Done | debug APK artifact 386 MB → 87.76 MB zipped across the same job lineage; release split drives ABI selection |

**Wave 3 honest edges (owner/device-pending):** every notification fire, ringer flip, GPS fix, compass turn, widget tile, audio playback and cold-start link is code-proven + CI-compiled but device-unproven until the owner runs the internal-test APK; app-links verification requires the real upload-key SHA-256; referral codes do not cross the install boundary (browser localStorage ≠ app storage, RELEASE.md §8.3); R8/minify deliberately deferred until after the device smoke.

## Phase C — Wave 4 (Part C) — first units

| Item | Status | Proven by |
|---|---|---|
| Global header on the five tabs (logo, location, triple calendar, notification/reminder/profile actions) (W4a) | Done | flutter analyze 0 + 236/236; rtl/smoke tests still assert localized tab labels through the new chrome |
| Notification + Reminder panels (W4a) | Done (code) | consumes the existing /api/reminders (finally wired on mobile); panel behavior needs a real session on the device |
| Floating contact button — five institutions (W4a) | Done (code) | configProvider.contacts rendered; tel/in-app-browser actions reuse W3g helpers; on-device tap-through pending |
| Token-built bottom bar + Phosphor set (W4a/W4f subset) | Done | SLBottomBar replaces stock NavigationBar (localized labels kept, tests green); fonts vendored (pub package didn't compile in the build env — commit d4e3a7f); icon migration is incremental by design |
| Home per spec — countdown ring, সর্বাধিক ব্যবহৃত, দ্রুত প্রবেশ, Ilm/amal/Live sections, সব দেখুন headers (W4b) | Done (code) — UI fully rewired: ring hero (CustomPainter on waqtInterval().remainingFraction + 1s tick; the schedule "hero flight" is an animated in-page ensureVisible scroll — the schedule lives on the same screen, not a route Hero), most-used আজ লিখুন, quick-access 2×2 grid, Ilm/amal/Live previews, সব দেখুন headers | flutter analyze 0 + 243/243 tests (7 new widget tests in test/w4_home_widget_test.dart) + CI run 36525487866 (https://github.com/sharif418/sunnah-life-app/actions/runs/36525487866) — all 10 jobs green incl. both release jobs |
| W4d..W4j | Not started this session | — |
| W4c backend — goal lifecycle (propose → head queue → approve/reject + reminder + audit), review-summary goal progress, gender-scoped percentile-band leaderboard behind the config flag, tilawat-minutes + exercise + akhlaq catalog amals | **Done (backend)** | jest 282/282 local (20 suites; +13 goals.spec +10 leaderboard.spec, live-DB e2e incl. reminder/audit/queue-scoping/gender-isolation proofs, re-run-verified); migration 20260929054442_goal_lifecycle applied (`prisma migrate status` up to date); catalog 31 → 35 via seed:reference (count verified); lint 0 errors / tsc clean; CI run 36529174552 (https://github.com/sharif418/sunnah-life-app/actions/runs/36529174552) — all 10 jobs green incl. api lint·test(PG16+Redis)·build + docker compose smoke (migrate·seed·health) which ran migration 20260929054442 under `prisma migrate deploy` clean |
| W4c mobile UI — goals lifecycle screen (propose sheet, status chips incl. rejected reason, head approval queue in the dawah tabs), local per-day custom checklist, tilawat beginner ramp card + exercise amal + fard/salah-sunnah/nafl group headers, config-gated leaderboard percentile band card | **Done (code + tests)** — incl. a REAL defect the new tests caught and fixed: the propose sheet's dropdown overflowed 195px horizontally on small widths (b4afb61: isExpanded + one-line ellipsized items) | flutter analyze 0 + 261/261 tests (18 new in test/w4c_amal_widget_test.dart: goals lifecycle, head queue incl. daee boundary, checklist persistence, tilawat ramp day counts over the committed catalog, leaderboard bands + null-hidden); backend CI run 36529174552 (https://github.com/sharif418/sunnah-life-app/actions/runs/36529174552) all 10 jobs green — but that run's head c80d5af predates the six UI commits, so it proves the API only; the UI chain is proven by its own push run: CI run 36539079890 (https://github.com/sharif418/sunnah-life-app/actions/runs/36539079890, head 137ab45) all 10 jobs green incl. Flutter — analyze · test · debug APK; mobile commits 5736040 · 19b7feb · e5076ab · c1ca0f9 · b4afb61 · c60fe7c |

## Wave 4 — operations fixes (C-OPS)

Found on the LIVE staging deployment (Coolify) + real phones: a slow dependency flipped the serving api container unhealthy and Traefik dropped it ("no available server"); release APKs targeted the placeholder API default so sign-in failed on real phones; Meilisearch boot indexing 405'd on v1.x and the duas pack was never indexed. Narrative in `worklog.md` (entries C-OPS-a..c).

| Item | Status | Implementing files | Proven by |
|---|---|---|---|
| Release builds target the real API | Done | `.github/workflows/ci.yml` (both release jobs), `docs/RELEASE.md` | CI run 36519971155 (https://github.com/sharif418/sunnah-life-app/actions/runs/36519971155) — all 10 jobs green incl. both release jobs, which built `--dart-define=SUNNAH_API_BASE` from the repo variable (guard passed: variable is set); real-phone sign-in verification still pending a device test |
| Liveness/readiness split (`/health/live` vs `/health/ready`+alias, shared Redis client, 1.5 s per-check budgets) | Done (code) | `apps/api/src/health/health.controller.ts`, `apps/api/src/main.ts`, `test/health-ops.spec.ts`, `infra/api.Dockerfile`, `infra/docker-compose.yml`, `infra/coolify.compose.yml` | CI run 36519971155 all-10-jobs green (api job: lint · 259-test jest · build, incl. the health-ops suite) + jest 13/13 local; live effect on the Coolify staging stack PENDING the owner's redeploy of the staging branch (honest: not yet deployed) |
| Meilisearch create-index 405 on boot (v1.x route) + duas pack never indexed (packDocuments first-array bug) | Done (code) | `apps/api/src/content/content.controller.ts`, `apps/api/src/shared/quran.ts`, `test/meili-indexer.spec.ts` | CI run 36519971155 api job green (jest incl. meili-indexer 6/6, route shape pinned against v1.54); real meili re-indexing happens on the owner's redeploy — after which the create-index log line no longer 405s (honest: not yet run live) |

## Wave 4 — visual-review fixes (W4-FIX, from the owner's 412×2400 DPR2 pass)

Five "not premium enough" findings on the merged W4a–W4c work, fixed BEFORE continuing W4d → W4j. The owner renders the screens after each wave and deployed staging themselves (main → staging merges are the owner's from now on).

| Item | Status | Implementing files | Proven by |
|---|---|---|---|
| Fix 1 — font consistency: every component theme in the token-built ThemeData carries Hind Siliguri (text/primaryText/tabBar/chip/actionChip/all button variants/segmented/snackBar/dialog/bottomSheet/input/tooltip/popup/dropdown/listTile/fab/navBar); families engine-registered so nothing falls back before the first frame | Done | `apps/mobile/pubspec.yaml` (engine families = the same bundled TTFs), `apps/mobile/lib/design/design_tokens.dart` (regenerated via build.mjs), `packages/design-tokens/build.mjs` | flutter analyze 0 + 266/266; NEW tofu guard `test/font_golden_test.dart`: Home/Amal Today/Dawah/Ilm/More in bn light rendered with ONLY the bundled fonts — pixel goldens + a RenderParagraph family walk that fails naming the exact widget on any fallback |
| Fix 2 — Amal Today density: boolean amals are compact single rows (60 dp min, title+hint leading, switch trailing, dividers, whole row tappable) grouped one-card-per-category; tilawat quantity input rebuilt (normal height, value + unit inline, beginner unit switch); salat tristate rows unchanged | Done | `apps/mobile/lib/features/amal/today_screen.dart`, `apps/mobile/lib/features/amal/amal_widgets.dart` | flutter analyze 0 + 266/266 (w4c widget tests re-fitted); golden `fonts_amal_today_bn_light.png` regenerated (59073 → 51893 bytes) |
| Fix 3 — forbidden-times card per spec §2.1: #FCE4E4 tinted surface + #C0392B text/icons + hairline border (dark: #3A211D + #E06A5A) — calm, not an alarm | Done | `apps/mobile/lib/features/home/home_screen.dart` | flutter analyze 0 + 280/280 (the home golden viewport sits above the strip — capture unchanged, verified passing) |
| Fix 4 — Dawah tab offline: Drift v4 RemoteCacheTable + ApiClient ApiCacheStore pipeline (fresh GET overwrites; network failure serves the envelope stale with its stamp; server 4xx/5xx always rethrows; keys user-scoped) + OfflineBanner with 'সর্বশেষ হালনাগাদ' on all three tabs + requirements screen; never-cached keeps the error state | Done (code + tests) | `apps/mobile/lib/db/database.dart` (+generated), `apps/mobile/lib/db/api_cache.dart` (new), `apps/mobile/lib/api/api_client.dart`, `apps/mobile/lib/state/providers.dart`, `apps/mobile/lib/state/remote_state.dart`, `apps/mobile/lib/features/dawah/dawah_screen.dart`, `dawah_requirements_screen.dart`, `apps/mobile/lib/features/shared/widgets.dart` (OfflineBanner), l10n ×3 + gen | flutter analyze 0 + 280/280; NEW `test/dawah_cache_test.dart` (14 tests): store round-trip on real in-memory Drift, fresh-fetch writes the row, offline+hit serves stale with the row stamp, offline+miss rethrows, 403 with warm cache rethrows, u1/u2 scope isolation, all four envelopes parse back, null store = legacy behavior, banner renders the stamp, full Dawah tab renders cached overview + banner with NO error wall offline |
| Fix 5 / W4d — More tab §4.3 full list | **Done** — backend + admin + mobile: support threads (user ↔ full_admin inbox with reply/close + audit), usrah join requests (ask → full_admin approve-with-usrah / reject + audit), admin support inbox page + join-request queue on the usrah page; mobile More rebuilt SECTIONED (Foundation: Donate + 5 contacts · ইবাদত ও টুলস: zakat/qibla/mosque/masala/live/autosilent/detox · জ্ঞান: 99 names/Islamic names/70 branches · সহায়তা: support/usrah join/feedback/FAQ · অ্যাপ: about/share/groups) + SupportScreen/SupportThreadScreen + join sheet + DetoxScreen (UsageStats channel, config-gated) + FAQ screen + share tile. share_plus NOT added — the repo's zero-plugin SystemChannel.shareText does the same (spec deviation, documented); detox is Android-only by design (honest state elsewhere); no push on admin reply yet | W4d-API: `apps/api` lint 0 errors + tsc clean + jest 314/314 (+15 support +17 join, live-DB RLS/isolation/audit proofs) + migrate status up-to-date + admin lint/build green; W4d-UI: flutter analyze 0 + 293/293 (+13 in test/w4d_more_widget_test.dart incl. the §4.3 inventory over an enriched config, detox gate, share channel fire, FAQ expansion, thread list/view, join sheet states, detox Android-only state, UsageChannel codec) — More golden regenerated (41818 → 44215 bytes), other five goldens byte-identical; Kotlin compiles in CI's debug-APK job (no local Android SDK — honest). Two REAL defects found and fixed by the tests: FaqRepository memoized the future (never resolves fake-zone listeners after runAsync — now the QuranRepository data-cache design) and _shareApp's clipboard-before-share order (a clipboard-less platform killed the native share — now share-first, clipboard best-effort) |
