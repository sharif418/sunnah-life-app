# AUDIT — requirement-by-requirement status

Honesty rules: **Done** = the implementing files exist AND the listed proof
reproduces (on a fresh clone or in the cited CI run). **Partial** = shipped
with a stated limitation. **Not done** = stated plainly.
**Proven by** = concrete evidence only: the test suite/file with its counts,
the CI run id + URL, an artifact name, a commit hash — or the explicit marker
*needs a real device / credentials* (documented in `docs/PHONE_TEST_CHECKLIST.md`
and `docs/HUMAN_STEPS.md`). That last group is **"Ready for device test"**,
never "Done". No status in this file was upgraded by the W5 rewrite; stale
per-session notes are kept verbatim with forward pointers where later waves
completed the work.

---

## Master-prompt §4–9

| Area | Status | Implementing files | Proven by |
|---|---|---|---|
| **§4 Domain model — 22 models, closure table, day-lock** | | `apps/api/prisma/schema.prisma`, `apps/api/prisma/migrations/` | |
| User/ReferralClosure/Usrah/Amal/WeeklyReview/Assessment/… exact shape | Done | schema + 6 migrations | `cd apps/api && bunx prisma migrate status` → up to date (14 migrations at the W5 head); `psql` count: 22 tables |
| AmalEntry day-lock after next-day Ishraq (server-enforced) | Done | `apps/api/src/amal/amal.service.ts` | `cd apps/api && bun run test` → amal.spec (day-lock cases), part of the 383/383 suite |
| DS-code referral closure tree | Done | `apps/api/src/dawah/` | `curl :3001/api/dawah` (daee) → downline + requirements |
| **§5 Roles & gender rule — in the DATABASE** | | | |
| Postgres RLS: 15 policies via SET LOCAL (app.user_id/gender/usrah_id/role) | Done | `apps/api/prisma/migrations/*_rls`, `src/common/rls.service.ts` | `cd apps/api && bun run test` → rls.e2e.spec (cross-gender SELECT = 0 rows); CI api job runs it against real PG16 |
| Gender set at onboarding, locked; only Full Admin changes (audited) | Done | `src/me/me.controller.ts` (rejects change), `src/admin/` | `curl -X PATCH /api/me {gender}` → 400 "লিঙ্গ পরিবর্তন করা যায় না"; admin PATCH writes AuditLog |
| RolesGuard + @Roles() explicit at API layer | Done | `src/common/roles.guard.ts`, `roles.decorator.ts` | gateway matrix in worklog B1: user→403, head→200, admin→200 |
| **§6 Features** | | | |
| Prayer times (adhan_dart on-device, 64 BD districts, hijri/bengali calendars) | Done | `apps/mobile/lib/core/prayer*`, `apps/web/src/lib/prayer-times.ts` | `flutter test` (prayer_snapshots_test); browser: home countdown + triple calendar; NOAA cross-check table in PROGRESS.md |
| Post-prayer জামাত/একা/কাযা prompt (20 min after waqt) | Done | `apps/mobile/lib/features/amal/` (post-prayer dialog) | `flutter test` (amal_logic_test) |
| Muhasaba diary — catalog faithful to paper forms (35 amals at the W4c/W5 head) | Done | `packages/content/amal-catalog.json`, `apps/api/src/amal/` | `curl :3001/api/amal/definitions` → 35 (31 → 35 at W4c: tilawat_minutes, exercise_minutes, akhlaq ×2) |
| Auto-logging from adhkar + Qur'an screens | Done | `apps/mobile/lib/features/ilm/*` (autoSource writes) | `flutter test` (smoke + amal tests) |
| Weekly review: auto-pending every 7 days, head reviews | Done | `apps/api/src/reviews/`, worker weekly-reviews | `curl :3001/api/reviews?scope=queue` (head) |
| 23-criterion assessment, majority-per-section rule | Done | `apps/api/src/assessments/`, `packages/content/assessment-farze-ain-v1.1.json` | `bun run test` → assessment.spec (majority rule cases) |
| Offline-first sync (Drift + outbox + conflict rules) | Done | `apps/mobile/lib/db/database.dart`, `core/sync_merge.dart` | fresh clone: `flutter test` → sync_conflict_test + sync_pull_test |
| **§6 (Phase B additions)** | | | |
| Push notifications (FCM HTTP v1, no SDK) + device tokens (RLS) + deep links | Done | `apps/api/src/push/`, `apps/mobile/lib/services/push_service.dart` | `bun run test` → push.spec + rls.e2e device-token cases; api.log "(no-op) would send"; real delivery = HUMAN_STEPS.md §1 |
| Gender-aware usrah broadcast fan-out | Done | `src/push/` sendToUsrah + RLS on DeviceToken | rls.e2e: cross-gender token SELECT = 0 |
| Monthly Muhasaba PDF (paper-form layout, Bengali shaping) | Done | `apps/api/src/reports/`, `src/storage/`, processor | `pdftotext -l 1` output in the B6 report; `curl POST /api/admin/reports/generate` → 200 |
| PDF in MinIO/S3 + admin list + download + manual trigger | Partial | same + `apps/admin exports page` | download → 200 (local adapter; S3 adapter active when S3_* env set — MinIO not runnable in sandbox; the Coolify stack ships the apistorage local volume by design, see DEPLOY_COOLIFY.md) |
| Courses (2×5 Bengali lessons), enrollments, progress | Done | `packages/content/courses.json`, `src/engagement/`, mobile `apps/mobile/lib/features/ilm/courses_screen.dart` | `curl :3001/api/courses` → 2; detail → 5 lessons each; `flutter analyze` 0 · `flutter test` (fresh-clone lineage in the B9 report) |
| Quizzes (3×10 MCQs + explanations), attempts with scoring | Done | `packages/content/quizzes.json`, `src/engagement/`, mobile `apps/mobile/lib/features/ilm/quizzes_screen.dart` | `curl :3001/api/content/quizzes` → 3×10; quiz-attempt 201; browser E2E: quiz played, answer locked + explanation shown |
| Usrah questions (head assigns/answers, RLS) | Done | `src/engagement/ilm.controllers.ts`, mobile `apps/mobile/lib/features/dawah/usrah_questions_screen.dart` | POST/GET usrah-questions → 201/list; browser E2E: question asked + head answer published → both render |
| Live quiz over WebSocket + per-gender leaderboard | Done | `apps/api/src/engagement/quiz.gateway.ts` (folded INTO the NestJS process at B9; the :3030 mini-service deleted) + mobile `live_quiz_screen.dart` | `cd apps/api && bun run smoke:quiz` → 21/21; socket through Caddy (polling + websocket); browser E2E: full host round via the gateway |
| Google + Apple Sign-In (link by verified email) | Partial | `src/auth/social/`, mobile `social_signin_service.dart` | jest social-auth.spec green; LIVE needs GOOGLE_CLIENT_ID/APPLE_SERVICES_ID env (HUMAN_STEPS.md §3) — not settable in sandbox |
| Gender asked at onboarding, locked after (incl. social path) | Done | `me.controller` lock + `gender_completion_screen.dart` | social-auth.spec + flutter test |
| Level automation (nightly rules → transition + audit + reminder) | Done | `src/levels/`, `src/queues/processors/levels.processor.ts` | worker log: levels-nightly registered; GET /api/dawah/requirements live checklist |
| Dawah tab live requirements checklist ("৩/৫ জন…") | Done (web **and mobile**) | `apps/web/src/components/dawah/dawah-view.tsx` + `apps/mobile/lib/features/dawah/dawah_requirements_screen.dart` | browser: স্তরের প্রয়োজনীয়তা renders live data; `flutter analyze` 0 |
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
| Tokens (colors/type/spacing) as single source, parity-checked | Done | `packages/design-tokens/build.mjs` | `node build.mjs --check` → "70 color values verified"; the CI `tokens` job runs it on every push |
| Skeletons/empty/error states, haptics, no default Material look | Done | mobile + web views | browser E2E (guest/empty/loading states observed); illustrated states at W4f-b |
| **§8 Engineering quality bar** | | | |
| i18n bn/en/ar + RTL (mobile ARB + gen-l10n) | Partial | `apps/mobile/lib/l10n/*.arb` + generated | `flutter test` (ARB consistency tests); Arabic onboarding → dir="rtl". Gap: a few onboarding strings fall back to Bengali in ar; admin stays bn-only (RTL-ready classes) |
| Web i18n bn/en/ar + logical CSS + RTL | Done | `apps/web/src/lib/i18n.ts`, shell dir switch | browser: Arabic UI (الرئيسية/الأعمال/العلم/المزيد) with RTL |
| Accessibility: Semantics, 44×44 targets, 1.3× text scale | Partial | mobile sweep + web tap-target/aria | `docs/A11Y_CONTRAST.md` (all PASS); W4f-b 360×640 @1.3× overflow sweep (10 tests). Gap: Semantics coverage broad-but-not-exhaustive on mobile |
| WCAG AA contrast both themes | Done | tokens.json fixes (gold-text, alert) + W5 `test/theme_contrast_test.dart` | `docs/A11Y_CONTRAST.md` — 14 pairs PASS; theme_contrast_test pins ≥4.5:1 on the EFFECTIVE rendered ListTile/chip colors, both brightnesses (commit 25ed835) |
| API lint/tests/typecheck | Done | apps/api | latest verified at the W5 head: `bun run lint` 0 errors · `bunx tsc --noEmit` 0 · `bun run test` 27/27 suites, 383/383 tests, both parallel and `--runInBand` (worklog W5-a, local CI-replica PG16+Redis) |
| Mobile analyze/tests | Done | apps/mobile | latest verified at the W5 head (this commit's tree): `flutter analyze` → "No issues found! (ran in 1.5s)" · `flutter test` → "+337: All tests passed!" (337/337; 330 at W4j + 7 new-executed: theme_contrast ×2 [one per brightness], tofu_guard ×2, day_part ×3) |
| Web typecheck | Done | apps/web | `bunx tsc --noEmit` → exit 0 (verified on a FRESH CLONE — the generated `packages/shared-types/dist/schema.d.ts` is committed); W5 dependency removal re-verified tsc clean after −38 packages (2d54df3) |
| Swagger/OpenAPI | Done | `src/main.ts` DocumentBuilder | `GET :3001/openapi.json` |
| CI green (lint/test/build on GitHub runners) | Done | `.github/workflows/ci.yml` (10 jobs incl. docker compose smoke + both release jobs) | run 36616631396 (65658fc) all-10-jobs green; the W5 head's run is recorded in worklog W5-c; three stacked bugs fixed on the way (B11): job-level hashFiles → workspace probe; zod `.min(8).default("")` boot failure; jest worker OTP race → --runInBand |
| Debug APK artifact on CI | Done — verified end-to-end | mobile job → `actions/upload-artifact@v4` (`if-no-files-found: error`) | run #25 artifact `mobile-debug-apk` (id 10955835922): zip CRCs + valid Android package verified via the Actions API; shrank 386 MB → ~88 MB after the keepDebugSymbols removal (W3i) |
| Release appbundle behind secrets | Done (gated) | release-bundle job | skips cleanly without ANDROID_KEYSTORE_BASE64; builds+uploads `mobile-release-aab` with it; the fail-closed SUNNAH_API_BASE guard passed on the real repo variable (run 36519971155) |
| **§9 / delivery** | | | |
| Single backend (web + mobile + admin → NestJS; no SQLite mirror) | Done | B1 restructure | NestJS access log lines for browser traffic; root prisma/db/api deleted |
| DEPLOY_COOLIFY runbook | Done | `docs/DEPLOY_COOLIFY.md` | rewritten to the real coolify.compose.yml flow at W5 (commit 8df9c8c): build pack + repo-root contexts, per-service domains/ports, NEXT_PUBLIC_API_BASE build arg, /health/live vs /health/ready, no-MinIO apistorage, staging-only demo seed, main→staging→redeploy |
| IOS_BUILD / RELEASE / HUMAN_STEPS | Done | `docs/IOS_BUILD.md`, `docs/RELEASE.md`, `docs/HUMAN_STEPS.md` (new at W5) | written; the console steps themselves need a human — each with exact env/secret names + verify steps |
| Demo accounts doc | Done | `docs/DEMO_ACCOUNTS.md` | seeded phones work (CI's api job seeds them every run for the RLS e2e) |

## Explicitly Not done / out of sandbox (owner-side human steps)

1. **Real push delivery** — no Firebase project exists in the sandbox; the
   FCM adapter is code-complete (HTTP v1 via fetch) but untested against a
   real device. No-op transport logs in `apps/api/api.log`.
   → `docs/HUMAN_STEPS.md` §1 (Firebase end-to-end).
2. **Google/Apple live login** — needs client IDs (env) + store apps; JWKS
   verification is unit-tested. → `docs/HUMAN_STEPS.md` §3.
3. **iOS build** — code + entitlements + docs only (no macOS in sandbox);
   `docs/IOS_BUILD.md` lists the remaining Xcode steps; the iOS side of the
   human steps is `docs/HUMAN_STEPS.md` §5.
4. **S3/MinIO upload of reports in the sandbox** — the storage service uses
   the local-dir adapter here and the `minio` client adapter when `S3_*` env
   is present (the Coolify stack ships the apistorage local volume by design).

Every on-device verification item has a step-by-step script in
**`docs/PHONE_TEST_CHECKLIST.md`** (created at W5-b; the earlier
"PHONE_TEST_CHECKLIST item" references in this file now resolve to its §1–§9).

## B9 close-out (surface parity + one-backend live quiz)

The post-Phase-B audit found three gaps; all closed in that round:

| Gap | Status | Proven by |
|---|---|---|
| Courses/quizzes/live-quiz/usrah-questions had NO Flutter UI | Done — mobile screens shipped (`apps/mobile/lib/features/ilm/courses_screen.dart`, `quizzes_screen.dart`, `live_quiz_screen.dart`, `dawah/usrah_questions_screen.dart`, `dawah/dawah_requirements_screen.dart`) | `flutter analyze` → No issues · `flutter test` green · ARB parity 408/408/408 |
| Live quiz was a separate bun mini-service (:3030) outside NestJS | Done — folded into the API (`quiz.gateway.ts`, `IoAdapter`); mini-service deleted | `bun run smoke:quiz` → 21/21; Caddy polling+ws both PASS; browser E2E full host round |
| `usrah.controller.ts` lacked `@Roles` | Done — `@UseGuards(RolesGuard)` + `@Roles("user")` | `bun run test` → full suite green (incl. usrah coverage) |
| (found during B9 E2E) web আরও tab was unreachable; `QuizzesSection` was dead code; host panel could not advance past the lobby | Done — fixed (`ilm-view.tsx` routeIlm cases, extras wiring, API_PORT export, প্রথম প্রশ্ন button) | browser E2E in worklog B9-e: grid reachable, quiz played, live round completed |

## Phase C — Wave 1 (shared plumbing) & Wave 2 (production blockers)

Baseline tag: `v0.9-pre-phase-c`. Full narrative in `worklog.md` (entries C-W1..C-W2d); evidence trail in the linked CI runs.

| Item | Status | Proven by |
|---|---|---|
| User.tz + tz-correct scheduling (push epochs, weekStart, lock deadline) | Done | `test/tz.spec.ts` (Dhaka/Riyadh/London) — in the suite (now 383/383) |
| Consolidated /api/config (contacts, hijri adjust, donation, flags) | Done | `test/config.spec.ts` + admin PATCH route audited |
| Content pipeline (packages/content → mobile assets; CI parity gate; 114-surah pack) | Done | CI `Content parity gate` step (green since 1b2b593) + `test/content-packs.spec.ts` (30 tests) + mobile quran-meta canary (flutter test) |
| Monorepo hygiene (bun workspaces, one lockfile, generated client committed, no sandbox leftovers, CI writes no commits) | Done | fresh-clone gates in B11 lineage + CI green since |
| Part D verbatim content (farze_ain_v1.1 23 criteria, Muhibbus outline, ladder fix, diary rules) | Done | `test/levels.spec.ts` + `test/content-packs.spec.ts` asserts; template row via admin API |
| Seed split (reference idempotent on boot; demo gated SEED_DEMO + non-production) | Done | `test/seed-split.spec.ts` (4 tests incl. boot-twice row stability + production refusal) |
| Real SMS (SSL Wireless + Infobip) + OTP hardening | Done (code); live delivery needs real creds — HUMAN_STEPS.md §2 | `test/auth-otp.spec.ts` + `test/token-security.spec.ts`; providers env-wired, mock refused in production |
| Token & secret handling (typ claims, separate refresh secret, atomic rotation, production env gate, CORS on gateway) | Done | `test/token-security.spec.ts` (de-flaked at W5 — commit 26cc105: the racing-refresh family revoke driven sequentially, 383/383 both modes on the local CI-replica PG16+Redis); CI production-validation refuses bad env (compose smoke boots with full env) |
| RLS tightening (DayUnlock policies, OtpCode/AuditLog/MasalaQuestion/Feedback RLS, self-role/gender trigger, worker role restricted, same-gender review fallback) | Done | `test/rls.e2e.spec.ts` 23/23 — twice in a row (re-runnability proof after the supertest listener + DayUnlock-cleanup fixes) |
| Push delivery (RFC 7523 jwt-bearer, token cache, device-token takeover) | Done (code); real FCM delivery needs a Firebase project — HUMAN_STEPS.md §1 | `test/push.spec.ts` 22/22 incl. mocked-endpoint grant/cache/refresh + takeover |
| Sync & guest merge hardening (strip bug, clamped LWW, conditional writes, inputType validation, source guard, serverValue, capped ordered merge) | Done | `test/conflict.spec.ts` + `test/social-auth.spec.ts` through the REAL APP_PIPE |
| Operations (/health 503→ liveness/readiness split, internal-only /metrics + /docs, structured logger + PII redaction, socket.io redis adapter, durable compose) | Done (code) | `test/health-ops.spec.ts` (13/13) + `test/docs-gating.spec.ts`; quiz smoke 21/21 ×3 through the adapter; compose proven by the docker job |
| Docker images + compose smoke | Done — GREEN (run 36454553711) | CI `docker` job: builds the images, `up --wait`, api /health status:ok (migrations + seed:reference completed), web :3000 + admin :3002 HTTP 200, AmalDefinition count ≥ 30. The job caught SIX real bugs on its way green (MinIO unpullable → local-storage adapter; archive_command GUC name; root-owned walarchive volume; non-idempotent archive idiom; pg_isready unix-socket race; api image never shipped the generated Prisma client; worker missing SMS creds) |

**Known deferred:** real FCM/device push, real SMS credentials, social-login client IDs, iOS build — all documented as owner-side human steps (`docs/HUMAN_STEPS.md`); quiz rooms remain single-instance by design until state is externalized (compose comment).

## Phase C — Wave 3 (Part B · "what breaks on a real phone")

Full narrative in `worklog.md` (entries C-W3a..C-W3i-CI). Local analyze 0 / 226/226 raw tails in each section + CI runs cited. The golden test files carry their own determinism contracts in-file.

| Item | Status | Proven by |
|---|---|---|
| Notification receivers were NEVER declared — every scheduled bell/post-prayer prompt silently never fired on a real phone (W3b) | Done | manifest statics committed; `flutter analyze` 0 + bell-schedule unit tests; CI mobile job green (run 36474538959 lineage) — the actual on-device fire is a device test → PHONE_TEST_CHECKLIST §3/§8 |
| tz.local never set — zonedSchedule broken on-device; exact-alarm denied → throw; monochrome icon only on FCM (W3b) | Done | flutter_timezone wiring + inexact fallback path; unit tests for the fallback decision; device confirmation pending → PHONE_TEST_CHECKLIST §3 (honest) |
| Rolling 3-day bell window + reschedule on city/madhhab/method change + daily WorkManager re-arm (W3b) | Done | `test/bell_schedule_test.dart` (id scheme, triggers) + `workmanager` periodic task registered; CI green |
| Post-prayer জামাত/একা/কাযা notification action buttons write the diary from a dead app (W3b) | Done (code) | background-isolate Drift write mirroring the in-app prompt exactly (value jamaat/alone/qaza, source auto:prayer:*); unit tests for payload/action mapping; **needs the owner's phone to tap for real** → PHONE_TEST_CHECKLIST §3 |
| Per-waqt "N minutes before/after" bell timing (W3b) | Done | long-press bell → timing sheet; clamp unit tests; l10n ×3 |
| Qur'an reader: 5MB main-isolate parse, first-open race, keyboard-closing search, scroll-jumping toggles (W3a) | Done | compute() isolate decode; single-flight + per-surah memoization; reader suite 30 tests; goldens bn light/dark + ar RTL (VLM-verified) |
| **Dart 3.13.4 hazard**: `map[k] ??= fut.whenComplete(() => map.remove(k))` NEVER completes — would have deadlocked the reader in production | Found + worked around | minimal repro pinned by `test/quran_reader_test.dart` hazard regression group (toxic shape times out; restructured shape resolves) |
| Recitation audio (per-ayah, cached, 4 reciters, auto-advance) (W3a) | Done (code) | everyayah.com URLs live-verified during the build (404 vs 200 evidence in quran_audio.dart doc); playback needs a real device/network → PHONE_TEST_CHECKLIST §4 |
| Go-to-ayah + resume-from-last-read (W3a) | Done | bn+ASCII digit parsing, two-step jump; unit tests |
| Sync pull on login/app-start + bounded rejected retries + unstuck syncing + visible sync state (W3d) | Done | 21 new tests (policy matrix, watermark, flush-finally, v1→v2 migration on a raw sqlite file); sync sheet golden (VLM-verified) |
| Location + snap-to-district + qibla live compass + mosques near me (W3c) | Done | geolocator + flutter_compass; 26 pure tests (snap matrix, bearing, permission gate); compass heading magnetic-vs-true documented; **GPS on-device: Ready for device test** → PHONE_TEST_CHECKLIST §5 |
| Auto-silent (DND) settings screen + jama'at windows via Kotlin AlarmManager (W3e) | Done (code) | 19 unit tests (windows, clamps, prefs codec, arms); Kotlin receiver static-verified + compiled by CI's APK jobs; **ringer flips need the owner's phone** → PHONE_TEST_CHECKLIST §5 |
| Home widget persists + survives process death + boot restore (W3f) | Done (code) | shared Kotlin render path (live + persisted); boot receiver + 15-min inexact re-render; contract test pins the snapshot shape; **widget on a home screen: device test** → PHONE_TEST_CHECKLIST §6 |
| Admin hijri ±adjust applied everywhere + donation Custom Tabs + More tile (W3g) | Done | effective adjust (user+admin, clamp ±4) matrix tests; nisab fallback parity test reads the committed pack; URL gating tests |
| Referral links: web /join/<code> landing + assetlinks + autoVerify + app_links prefill (W3h) | Done | dev-server smoke: /join/DS-000123 → 200 with og meta, /join → 307, .well-known both → 200; 12 mobile tests (parsing, storage, end-to-end wire through MockClient); app-Links VERIFICATION needs the owner's upload-key SHA-256 (placeholder committed, RELEASE.md §8) → PHONE_TEST_CHECKLIST §7 |
| Release split-per-ABI APK job + < 40 MB gate (W3i) | **Done — CI-proven on first run** | run 36474538959 job `Flutter — release APKs · split-per-ABI`: arm64 26,665,649 B (25.4 MB), armv7 24,435,193 B (23.3 MB), gate passed; artifacts `internal-test-arm64-v8a` + `internal-test-armeabi-v7a` — **the owner's device-test release build (debug-signed until the keystore secrets from HUMAN_STEPS.md §4 are set)** |
| keepDebugSymbols + misleading abiFilters removed (W3i) | Done | debug APK artifact 386 MB → 87.76 MB zipped across the same job lineage; release split drives ABI selection |

**Wave 3 honest edges (owner/device-pending):** every notification fire, ringer flip, GPS fix, compass turn, widget tile, audio playback and cold-start link is code-proven + CI-compiled but device-unproven until the owner runs the internal-test APK (docs/PHONE_TEST_CHECKLIST.md); app-links verification requires the real upload-key SHA-256; referral codes do not cross the install boundary (browser localStorage ≠ app storage, RELEASE.md §8.3); R8/minify deliberately deferred until after the device smoke.

## Phase C — Wave 4 (Part C) — first units

| Item | Status | Proven by |
|---|---|---|
| Global header on the five tabs (logo, location, triple calendar, notification/reminder/profile actions) (W4a) | Done | flutter analyze 0 + 236/236; rtl/smoke tests still assert localized tab labels through the new chrome |
| Notification + Reminder panels (W4a) | Done (code) | consumes the existing /api/reminders (finally wired on mobile); panel behavior needs a real session on the device → PHONE_TEST_CHECKLIST §8 |
| Floating contact button — five institutions (W4a) | Done (code) | configProvider.contacts rendered; tel/in-app-browser actions reuse W3g helpers; on-device tap-through pending → PHONE_TEST_CHECKLIST §5 (W5 gave it scroll clearance — see Wave 5) |
| Token-built bottom bar + Phosphor set (W4a/W4f subset) | Done | SLBottomBar replaces stock NavigationBar (localized labels kept, tests green); fonts vendored (pub package didn't compile in the build env — commit d4e3a7f); icon migration completed wholesale at W4f-a |
| Home per spec — countdown ring, সর্বাধিক ব্যবহৃত, দ্রুত প্রবেশ, Ilm/amal/Live sections, সব দেখুন headers (W4b) | Done (code) — UI fully rewired: ring hero (CustomPainter on waqtInterval().remainingFraction + 1s tick; the schedule "hero flight" is an animated in-page ensureVisible scroll — the schedule lives on the same screen, not a route Hero), most-used আজ লিখুন, quick-access 2×2 grid, Ilm/amal/Live previews, সব দেখুন headers | flutter analyze 0 + 243/243 tests (7 new widget tests in test/w4_home_widget_test.dart) + CI run 36525487866 (https://github.com/sharif418/sunnah-life-app/actions/runs/36525487866) — all 10 jobs green incl. both release jobs |
| W4d..W4j | Not started **at the time of this first-units table** — since completed in the later Wave-4 units (see the W4d–W4j sections below, each with its own proof) | the W4d/W4e, W4f, C-OPS/W4h/W4i, W4-FIX, W4g and W4j tables below |
| W4c backend — goal lifecycle (propose → head queue → approve/reject + reminder + audit), review-summary goal progress, gender-scoped percentile-band leaderboard behind the config flag, tilawat-minutes + exercise + akhlaq catalog amals | **Done (backend)** | jest 282/282 local (20 suites; +13 goals.spec +10 leaderboard.spec, live-DB e2e incl. reminder/audit/queue-scoping/gender-isolation proofs, re-run-verified); migration 20260929054442_goal_lifecycle applied (`prisma migrate status` up to date); catalog 31 → 35 via seed:reference (count verified); lint 0 errors / tsc clean; CI run 36529174552 (https://github.com/sharif418/sunnah-life-app/actions/runs/36529174552) — all 10 jobs green incl. api lint·test(PG16+Redis)·build + docker compose smoke which ran the migration under `prisma migrate deploy` clean |
| W4c mobile UI — goals lifecycle screen (propose sheet, status chips incl. rejected reason, head approval queue in the dawah tabs), local per-day custom checklist, tilawat beginner ramp card + exercise amal + fard/salah-sunnah/nafl group headers, config-gated leaderboard percentile band card | **Done (code + tests)** — incl. a REAL defect the new tests caught and fixed: the propose sheet's dropdown overflowed 195px horizontally on small widths (b4afb61: isExpanded + one-line ellipsized items) | flutter analyze 0 + 261/261 tests (18 new in test/w4c_amal_widget_test.dart: goals lifecycle, head queue incl. daee boundary, checklist persistence, tilawat ramp day counts over the committed catalog, leaderboard bands + null-hidden); backend CI run 36529174552 (https://github.com/sharif418/sunnah-life-app/actions/runs/36529174552) all 10 jobs green — but that run's head c80d5af predates the six UI commits, so it proves the API only; the UI chain is proven by its own push run: CI run 36539079890 (https://github.com/sharif418/sunnah-life-app/actions/runs/36539079890, head 137ab45) all 10 jobs green incl. Flutter — analyze · test · debug APK; mobile commits 5736040 · 19b7feb · e5076ab · c1ca0f9 · b4afb61 · c60fe7c |

## Wave 4 — W4d + W4e + W4f

| Item | Status | Proven by |
|---|---|---|
| W4d — More §4.3 full assembly (backend + admin + mobile; see the W4-FIX Fix 5 row below for the inventory) | Done | W4d-API: jest 314/314 (+15 support +17 join, live-DB RLS/isolation/audit proofs) + migrate status up-to-date + admin lint/build green; W4d-UI: flutter analyze 0 + 293/293 (+13 in test/w4d_more_widget_test.dart); More golden regenerated; Kotlin compiled by CI's debug-APK job (no local Android SDK — honest; and see the W4j CI-fix record below for the two hallucinated Android APIs MainActivity.kt carried) |
| W4e — referral share card as a branded PNG | **Done** — 1080×1350 fixed design surface (token branding, bundled fonts), live preview sheet (bounded height — a real 359px overflow defect caught by tests + fixed pre-commit), Android native image share (FileProvider exposing only <cache>/share), honest text fallback on iOS/render failure | flutter analyze 0 + 303/303 tests: the card pinned as a PNG golden; the REAL capture proven runAsync-style (magic header + exact dimensions); wiring + fallback via the visibleForTesting seam |
| W4e — real madu tree view | **Done** — 24px/level indent rails (CustomPainter), gender-tinted avatars, level chips, relative last-active (pinned clock), ellipsized names at 360w @1.3×; read-only (API carries depth, not parentage — documented); renders from the offline cache | same suite: depth/indent/rails/gender/text-scale/empty/offline tests |
| W4f — design-system craft (a + b) | **Done** — full Phosphor migration (goldens render the REAL glyphs via the vendored-family prewarm); token app bar + one shared fade-through transition for all 32 pushed routes; SLMotion tokens in real use; khatam-lattice hero texture (5% painter, no assets); illustrated empty/error states with CTA + calm alert idiom; dark-mode token sweep (no raw colors in features/); 360×640 @1.3× overflow-proofed with FOUR real spills fixed; debug-only /__gallery kit catalog (release-gated); Bengali body line-height 1.6 verified | flutter analyze 0 + 313/313 (10 new overflow tests pumping the key screens at the small surface × 1.3 text; all 12 goldens byte-stable through the state/widget work except the two regenerated for the icon migration + home texture) |

## Wave 4 — admin maturity + assessment signature (W4h, W4i)

| Item | Status | Proven by |
|---|---|---|
| W4h — admin maturity | **Done** — role-filtered nav + URL gates (redirect, not 403; usrah_head/invigilator/full_admin see their real surfaces); role dashboards incl. the invigilator health score (formula in code: reviews 35% + amal completion 35% + active members 20% + overdue 10% over 30 days); level-rules editor (DB override over the pack seed, per-level field editing, reset-to-pack); CMS pages for faq/articles/mosques/duas packs + app-config contacts/groups/nisab/toggles (courses/quizzes read-only — endpoint ready, form pass pending, honest); referral tree with cursor-paginated children-on-expand | apps/api: lint 0 errors + tsc clean + jest 365/365 (+51: roles/validation/audit/pagination boundaries for every new endpoint); apps/admin: lint 0 + build ✓ 19 routes — after every commit |
| W4i — assessment signature | **Done** — status pending_confirmation → the assessee is reminded (Fajr, their tz) → sees the score in the dawah tab → OTP-confirms through the same OTP machinery as sign-in (atomic consume + audit) or declines with a reason (invigilator reminded); level facts read confirmed-only; admin sees the lifecycle read-only | api: jest 372/372 (the full e2e incl. the level gate + wrong-code paths); mobile: analyze 0 + 319/319 (chips, the OTP happy path, wrong-code recovery, decline, the wire contract ×4); admin lint/build ✓ |

## Wave 4 — operations fixes (C-OPS)

Found on the LIVE staging deployment (Coolify) + real phones: a slow dependency flipped the serving api container unhealthy and Traefik dropped it ("no available server"); release APKs targeted the placeholder API default so sign-in failed on real phones; Meilisearch boot indexing 405'd on v1.x and the duas pack was never indexed. Narrative in `worklog.md` (entries C-OPS-a..c).

| Item | Status | Implementing files | Proven by |
|---|---|---|---|
| Release builds target the real API | Done | `.github/workflows/ci.yml` (both release jobs), `docs/RELEASE.md` | CI run 36519971155 (https://github.com/sharif418/sunnah-life-app/actions/runs/36519971155) — all 10 jobs green incl. both release jobs, which built `--dart-define=SUNNAH_API_BASE` from the repo variable (guard passed: variable is set); real-phone sign-in verification still pending a device test → PHONE_TEST_CHECKLIST §2 |
| Liveness/readiness split (`/health/live` vs `/health/ready`+alias, shared Redis client, 1.5 s per-check budgets) | Done (code) | `apps/api/src/health/health.controller.ts`, `apps/api/src/main.ts`, `test/health-ops.spec.ts`, `infra/api.Dockerfile`, `infra/docker-compose.yml`, `infra/coolify.compose.yml` | CI run 36519971155 all-10-jobs green (api job: lint · 259-test jest · build, incl. the health-ops suite) + jest 13/13 local; live effect on the Coolify staging stack PENDING the owner's redeploy of the staging branch (honest: not yet deployed) |
| Meilisearch create-index 405 on boot (v1.x route) + duas pack never indexed (packDocuments first-array bug) | Done (code) | `apps/api/src/content/content.controller.ts`, `apps/api/src/shared/quran.ts`, `test/meili-indexer.spec.ts` | CI run 36519971155 api job green (jest incl. meili-indexer 6/6, route shape pinned against v1.54); real meili re-indexing happens on the owner's redeploy — after which the create-index log line no longer 405s (honest: not yet run live) |

## Wave 4 — visual-review fixes (W4-FIX, from the owner's 412×2400 DPR2 pass)

Five "not premium enough" findings on the merged W4a–W4c work, fixed BEFORE continuing W4d → W4j. The owner renders the screens after each wave and deployed staging themselves (main → staging merges are the owner's from now on).

| Item | Status | Implementing files | Proven by |
|---|---|---|---|
| Fix 1 — font consistency: every component theme in the token-built ThemeData carries Hind Siliguri | Done | `apps/mobile/pubspec.yaml` (engine families), `apps/mobile/lib/design/design_tokens.dart` (regenerated), `packages/design-tokens/build.mjs` | flutter analyze 0 + 266/266; tofu guard `test/font_golden_test.dart` (family walk). NB: the golden PIXEL layer of this guard was later proven tofu-blind at W5 and superseded by `test/tofu_guard_test.dart` — see Wave 5 |
| Fix 2 — Amal Today density: compact grouped rows + rebuilt tilawat quantity input | Done | `apps/mobile/lib/features/amal/today_screen.dart`, `amal_widgets.dart` | flutter analyze 0 + 266/266 (w4c widget tests re-fitted); golden regenerated |
| Fix 3 — forbidden-times card per spec §2.1 (#FCE4E4 + #C0392B, calm not alarm) | Done | `apps/mobile/lib/features/home/home_screen.dart` | flutter analyze 0 + 280/280 |
| Fix 4 — Dawah tab offline cache (Drift RemoteCacheTable + stale-on-network-fail envelope + OfflineBanner) | Done (code + tests) | `apps/mobile/lib/db/database.dart`, `lib/db/api_cache.dart`, `lib/api/api_client.dart`, `lib/state/{providers,remote_state}.dart`, `dawah_screen.dart`, `dawah_requirements_screen.dart`, `widgets.dart` (OfflineBanner) | flutter analyze 0 + 280/280; `test/dawah_cache_test.dart` (14 tests): store round-trip on real in-memory Drift, stale-serve + 4xx-rethrow semantics, u1/u2 scope isolation, full-tab offline integration with NO error wall |
| Fix 5 / W4d — More tab §4.3 full list | **Done** — support threads + usrah join requests (backend + admin + mobile), sectioned More, SupportScreen/SupportThreadScreen, join sheet, DetoxScreen (config-gated), FAQ screen, share tile; share_plus NOT added (the repo's zero-plugin SystemChannel.shareText does the same — spec deviation, documented); detox Android-only by design; no push on admin reply yet | `apps/api/src/support/`, `src/usrah/join-request.controller.ts`, `apps/admin/app/(dash)/support/page.tsx` + usrah page section, `apps/mobile/lib/features/more/*` | W4d gates in the W4d row above (jest 314/314 + flutter 293/293). Two REAL defects found and fixed by the tests: FaqRepository memoized the future (never resolves fake-zone listeners — now the QuranRepository data-cache design) and _shareApp's clipboard-before-share order |

## Wave 4 — W4g (web §3.3: top nav, PWA, i18n)

| Item | Status | Implementing files | Proven by |
|---|---|---|---|
| Top nav per spec §3.3 — green header, all spec items, gold Donate permanently the only gold-filled element | Done | `apps/web/src/components/app/shell.tsx`, `logo.tsx`, `hooks/use-donation-url.ts` | lint 0 + tsc clean + production build; built HTML carries the manifest link; donation wiring = the same api.config() idiom as about.tsx (now shared) |
| Real service worker — app-shell precache, cache-first static, SWR /api/config, network-first navigations with /offline.html fallback | Done | `apps/web/public/sw.js`, `offline.html`, `sw-register.tsx`, `layout.tsx` | `bun run start` smoke: / 200, manifest + sw + offline + icons all 200 with correct content types; SW unit tests: none exist (no web test infra — honest) |
| Installable PWA — hardened manifest + generated icons + beforeinstallprompt banner with persisted dismissal | Done | `manifest.webmanifest`, `scripts/gen-icons.mjs`, `install-prompt.tsx`, `layout.tsx` | manifest served with correct content-type + full icon set (smoke above); the actual install prompt is browser-engagement-gated — verified by code + built HTML, not a headless install |
| `<html lang dir>` per locale — static bn/ltr + reactive LocaleSync | Done | `layout.tsx`, `locale-sync.tsx` | built HTML: `<html lang="bn" dir="ltr">`; LocaleSync + ServiceWorkerRegister both present in the rendered tree |
| Web i18n finish (top surfaces, ~78 new keys) | Done (top surfaces; deeper views stay bn-first by design) | `apps/web/src/lib/i18n.ts`, swept components | grep: no hard-coded bn left in the swept surfaces beyond calendar-era words, prayer-time names and the bn-by-design label maps |
| PRE-EXISTING DEFECT fixed: standalone build copied static+public to the wrong root — ALL /_next/static chunks 404 (unstyled, uninstallable) | Done | `apps/web/package.json` (build + start scripts) | before/after smoke: chunks+css+manifest+sw+offline+icons 404 → 200 with correct content types (curl matrix in worklog W4g) |

## Wave 4 — W4j (search)

| Item | Status | Implementing files | Proven by |
|---|---|---|---|
| Meilisearch indexer — 5 packs, per-pack typo tolerance, title-first searchableAttributes | Done (code) | `apps/api/src/content/content.controller.ts`, `src/shared/quran.ts`, `test/meili-indexer.spec.ts` | jest meili-indexer 6/6 (route shape pinned against v1.54); real re-index fires on the next staging boot with MEILI_HOST (owner's redeploy) |
| GET /api/search — unified pack search, one /multi-search round trip, grouped, short-q empty, 503 with Bengali message when meili is absent | Done | `search.service.ts`, `content.controller.ts`, `test/search.spec.ts` | jest search suite green inside the api job's 383/383; wire contract pinned |
| Mobile — Ilm search screen + offline fallback (bundled-pack matcher, NO typo tolerance — the banner says which corpus answered) | Done | `ilm_search_screen.dart`, `search_offline.dart`, models + api client + l10n | flutter analyze 0 + 330/330 incl. test/w4j_search_test.dart (11 tests); ilm golden regenerated |
| Web — Ilm unified search + deep links + offline fallback (the plan's "mobile & web usage") | Done | `search-section.tsx`, `lib/search-offline.ts`, `ilm-view.tsx` | lint 0 / tsc clean / build ✓; BROWSER E2E (dev server + the real API with meili absent → the 503 path): grouped results + offline strip, name99/dua/article deep links (article dialog auto-opens), clear/restore, 390px no overflow, zero page errors |
| Web offline persistence — SW serves /api/content/:pack SWR | Done (code) | `apps/web/public/sw.js` | served-asset smoke at deploy; SW behavior verified by code review — no web SW test infra (honest); the fallback browser-verified via the 503 path |
| Local-monorepo API boot shim (dev tool, not a product change) | Done | `apps/api/scripts/dev-run.cjs` | the real API booted locally through it — the same instance the browser E2E ran against; CI/Docker unaffected |

## Wave 4 — W4j CI fix (a W4e regression found at close-out — the honest record)

| Item | Status | Implementing files | Proven by |
|---|---|---|---|
| APK CI jobs RED since W4e — MainActivity.kt "Unclosed comment" at EOF: the W4e shareFile KDoc said "as image/* + EXTRA_STREAM" INSIDE a block comment; Kotlin NESTS block comments, so the `image/*` opened a second level, the block's `*/` closed the nested one, and the outer comment swallowed the whole file. Every pushed head from 1cae221 (W4d docs) through 160254f (W4i) failed both APK jobs on exactly this (runs 36567327689, 36577878577, 36583178635, 36587229096, 36590645367, 36597585832, 36602057408). The W4e..W4i worklogs' "gates green" lines were true only for the LOCAL gates run in those sessions — the APK jobs rode red, undiscovered until the W4j close-out read the runs list | Done (11ff487) — the KDoc reworded ("with an any-image MIME type"); no other .kt file carries a nested open | `apps/mobile/android/app/src/main/kotlin/bd/asunnah/sunnah_life/MainActivity.kt` | nesting-aware comment scan of every .kt (depth 0, no nested opens) + the APK jobs on the fix head; local Kotlin compilation impossible in the sandbox (no Android SDK) |
| …continued (the errors the un-swallowed file surfaced) — the W4d usage channel's Kotlin had TWO hallucinated Android APIs that the W4e comment bug had been masking: `OPSTR_USAGE_ACCESS` (real: `OPSTR_GET_USAGE_STATS`; pre-Q String-op checkOpNoThrow is not public — pre-Q probes via the events query) and `nextEvent()` (real: `getNextEvent(Event)` filling a mutable out-event, returns Boolean). Every API now used is verified against the AOSP framework source (UsageEvents.java + AppOpsManager.java from the aosp-mirror) | Done (ee0a84f + 65658fc) | same MainActivity.kt | **Run 36616631396 on 65658fc — ALL 10 JOBS GREEN including both APK builds** (first fully-green run since 36558890112 on dcab440); interim reds 36614184485 + 36615386357 pinned the exact resolver errors. LESSON: Kotlin written without the Android SDK is UNVERIFIED until an APK job compiles it; close-outs read both APK jobs per push |

## Wave 5 — Part E (clean-up + reporting)

The wave the PLAN promised: visual debt found on the merged W4 state, web bloat removed, the flaky CI test made deterministic, and the docs set (this file's Proven-by rewrite included). On-device confirmation of the five mobile fixes = **PHONE_TEST_CHECKLIST §1**.

| Item | Status | Proven by |
|---|---|---|
| Component theme text colors — the invisible ListTile/chip text (component themes REPLACE their M3 defaults wholesale; color-less styles left titles/subtitles/chip labels near-white on the cream surface, visible only after the W5 golden font fix made pixels legible) | Done | commit 25ed835; `test/theme_contrast_test.dart`: the EFFECTIVE rendered color of a ListTile title/subtitle + a chip label must contrast ≥ 4.5:1 (WCAG AA relative luminance) in BOTH themes — proven red on the pre-fix theme, green after |
| Real-font goldens — flutter test does NOT load pubspec-declared families; all eleven committed goldens were tofu (boxes) with the guard green, so the pixel layer compared tofu against tofu | Done | commit ee7c5fb; `test/tofu_guard_test.dart` — the genuine advance-width guard (an unregistered family falls back to Ahem where every glyph advances exactly fontSize; real proportional faces never do) + a negative control proving the detector; `golden_fonts.dart` warmAppFonts (FontLoader for Hind Siliguri ×3 weights, Amiri, Amiri Quran, 3 Phosphor families); 11 goldens regenerated with real glyphs and visually inspected (VLM) |
| Minute-precision day parts — Zuhr at 11:59 read 'সকাল ১১:৫৯' because the labeller cut at whole hours; সন্ধ্যা now starts 17:00 (Maghrib itself sets 17:12–18:47 in BD — the old cut labelled a 17:51 Maghrib 'বিকাল') | Done | commit c906d9b; `test/day_part_test.dart` — every boundary at minute edges for all six Bengali day parts (11:29 সকাল / 11:30 দুপুর / 14:59 দুপুর / 15:00 বিকাল / 16:59 বিকাল / 17:00 সন্ধ্যা …); the wider দুপুর label also exposed a real 360dp @1.3× ListTile trailing overflow — fixed with the ConstrainedBox-capped Row, W4f overflow sweep green |
| Contact-FAB clearance — the floating headset button (52dp, 16dp above the nav bar) covered the last list rows' chevrons | Done | commit 8a4a657; `kContactFabClearance = 52 + 16 + 12 = 80dp` bottom padding on the five root-tab ListViews (home, amal today, dawah, ilm, more — the import sites are in the commit's stat); the golden suite passes at the current head (337/337 — the padding changes scroll extent, not the captured initial viewport). Honest note: at the TOP scroll position the FAB still floats over content — standard Material behaviour; the guarantee is clearance at the end of the scroll extent |
| Dawah stat-cell label wrap — 'মোট দাওয়াত দি…' clipped to one line at 412dp | Done | commit 8a9e1bf; the label wraps to two lines (value keeps its 2-line cap); dawah golden regenerated — VLM-verified the full label renders |
| Web dependency removal — 38 unused packages dropped (dnd-kit trio, mdxeditor, react-table, date-fns, next-auth, next-intl, react-markdown, react-syntax-highlighter, uuid, z-ai-web-dev-sdk, zod, recharts, cmdk, vaul, embla, day-picker, resizable-panels, react-hook-form + resolvers, tailwindcss-animate + the 15 radix packages behind 28 dead shadcn components) + dead tailwind.config.ts deleted (Tailwind v4 CSS-first never reads it) | Done | commit 2d54df3 (+ lockfile landed as a4b76e1); gates: importer scan (rg across src/ + configs — the 28 deleted ui components have zero importers outside ui/), eslint clean, `tsc --noEmit` clean, `next build` green (/, /join, /join/[code], apple-app-site-association), dev-server smoke 200 with the Bengali `<title>` |
| token-security de-flake — the W4j-CI-FIX-pt3 flake (run 36617854673, docs-only push: "two RACING refreshes … exactly one wins" resolved where it should reject — the invariant conflated "exactly one wins" with "the family is revoked") | Done | commit 26cc105 — the family revoke driven sequentially; `bun run test` 27/27 suites, 383/383 tests on the local CI-replica (PG 16.10 + Redis 7.0.15), BOTH the task-command parallel mode (19.2 s) and CI's exact `--runInBand` (16.5 s); lint 0 errors / tsc clean |
| Docs — DEPLOY_COOLIFY rewritten to the real coolify.compose.yml flow; HUMAN_STEPS (7 owner-side setups with exact env/secret names + verify steps); PHONE_TEST_CHECKLIST (§0 artifact path → §9 resilience, incl. §1 the five Wave-5 checks) | Done | commit 8df9c8c; the three files exist in docs/ (PHONE_TEST_CHECKLIST was created NEW — the previous AUDIT's reference to it was dangling); grounding reads + structure documented in worklog W5-b |
| AUDIT rewritten with the **Proven by** column + PROGRESS W5 section | Done | this commit — every row above carries its evidence; no status upgraded, the W4 regression records (red-APK-since-W4e + the hallucinated-API fixes) preserved verbatim above |

**Wave 5 honest edges:** the five mobile fixes are code+test+golden-proven, but their on-device confirmation is PHONE_TEST_CHECKLIST §1 (the owner runs the internal-test-arm64-v8a artifact); the Home header date + sync-sheet message sit at 12px onSurfaceVariant (≈8:1 — AA-passing) and were flagged "faint-looking" by the VLM inspection — recorded as an observation, not a bug (PROGRESS W5); goldens are Linux-rendered and pinned to Flutter 3.47.5 == CI's pin.

---

**Standing rule (kept from W4j):** a close-out reads the CI runs list for every push, both APK jobs included — a green local gate says nothing about Kotlin compiled only on GitHub runners.
