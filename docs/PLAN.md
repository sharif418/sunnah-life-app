# Sunnah Life — সুন্নাহ লাইফ · Engineering Plan (PLAN.md)

**Client:** As-Sunnah Foundation — Dawatus Sunnah department
**Product:** Sunnah Life (public Islamic companion app) + Dawatus Sunnah Tarbiyah Engine
**Document status:** Living document. Update PROGRESS.md after every milestone.
**Stack policy:** The mandated stack (§2) is **not negotiable** — every item is installed/built.
What cannot run in this sandbox is still **code-complete** for the client's Coolify VPS.

---

## 1. The one-paragraph truth (restated in my own words)

We are building **two products in one codebase**:

1. **Sunnah Life** — the front door: a public Islamic companion app (prayer
   times, Qur'an, du'a & adhkar, amal checklist, courses, quizzes, live
   programs, zakat calculator, qibla, 99 names, donation). Guests use it with
   zero friction; their data stays on-device until they register.
2. **The Tarbiyah Engine** — the real core: registered da'ees get a member code
   (`DS-000001`) + referral link, are grouped into same-gender **Usrahs**, keep
   a **daily Muhasaba diary**, are reviewed by their Usrah head **every 7
   days**, are assessed with the structured 23-criterion **Farze Ain v1
   form**, and climb levels (Muhibbus Sunnah → Farze Ain Cat-1/Cat-2 → …).

**The design principle above all:** product 1 feeds product 2. Finishing the
morning-adhkar screen auto-ticks "সকালের মাসনূন আযকার". Twenty minutes after a
waqt begins, the app asks "জামাতে / একা / কাযা?" and writes a tristate diary
row. The Qur'an reader logs tilawat. Content apps entertain; **this platform
runs a tarbiyah program with accountability**.

Audience: Bangladesh-first (low-end Android, poor connectivity), plus diaspora.
Bengali primary; English and Arabic (full RTL) supported. Female members' data
is visible **only to female supervisors** — enforced in the database itself,
not just in code.

---

## 2. Mandated technology stack (no substitutions)

| Layer | Technology | Status |
|---|---|---|
| Mobile (Android+iOS) | **Flutter** stable + Dart 3; Riverpod, go_router, Drift (SQLite), `adhan_dart` on-device prayer calc, `hijri`, `flutter_local_notifications`, FCM (push delivery only), platform channels (Kotlin/Swift): exact alarms, DND, home widgets (Glance/WidgetKit), Apple Sign-In | `apps/mobile` — Flutter SDK 3.47.5 installed in sandbox; analyze/test/apk-debug verified here |
| Backend API | **NestJS** modular monolith; Prisma, class-validator, OpenAPI/Swagger auto-generated, JWT access + rotating refresh, BullMQ | `apps/api` |
| Database | **PostgreSQL 16** with **Row-Level Security** for gender + usrah scoping (mandatory, e2e-tested) | portable PG16 runs in sandbox; RLS e2e test in `apps/api/test` |
| Cache/queues | **Redis 7 + BullMQ** | Redis 7.0.15 (userland) runs in sandbox; `apps/worker` |
| Object storage | **MinIO** (S3) — media, PDFs, versioned content packs | binary runs in sandbox; wired via env |
| Search | **Meilisearch** — Bengali-typo-tolerant search | binary runs in sandbox; index sync in api |
| Web public + PWA | **Next.js 14+ App Router, TS, Tailwind, shadcn/ui** — public site, referral landings `/join/DS-XXXX` | this repo root (see §3 note) |
| Admin panel | **Next.js `apps/admin`** — shadcn/ui + TanStack Table/Query | `apps/admin` |
| Live | Phase 1–2 YouTube unlisted embed; Phase 3 self-hosted LiveKit. Female sessions never public on YouTube | Phase 1–2 implemented; LiveKit extension point documented |
| Auth | Phone OTP (SMS gateway abstraction: mock + SSL Wireless/Infobip adapters), Email OTP, Google, Apple; guest local data merges on sign-up | OTP mock verified; adapter seam in `apps/api/src/auth` |
| Deploy | **Docker + docker-compose → Coolify VPS**, Cloudflare in front | `infra/docker-compose.yml` + `docs/DEPLOY_COOLIFY.md`; every service has a Dockerfile |
| Tooling | pnpm workspaces + Turborepo; ESLint/Prettier; `flutter analyze` clean; GitHub Actions CI | `.github/workflows/ci.yml` |

**Sandbox execution matrix** — what physically runs here vs what is
code-complete for the VPS:

| Item | Sandbox | Notes |
|---|---|---|
| Flutter SDK 3.47.5 + Android SDK (cmdline-tools, platform 36, build-tools 36) | ✅ user-level install, no root needed | `/home/z/flutter`, `/home/z/android-sdk` |
| `flutter analyze` / `flutter test` / `flutter build apk --debug` | ✅ run + paste in PROGRESS | 2-core/4 GB box — Gradle memory capped |
| PostgreSQL 16 (portable EDB binaries) + RLS + e2e proof | ✅ `~/opt/pg16`, port 5433 | schema identical to production |
| Redis 7.0.15 (extracted bookworm deb) | ✅ port 6380 | |
| Meilisearch + MinIO binaries | ✅ started for verification | data dirs under `~/opt` |
| Docker / docker-compose up | ❌ no root in sandbox (container-in-container) | **code-complete**: compose file, Dockerfiles, healthchecks; user runs `docker compose up` on the Coolify VPS |
| Coolify/Cloudflare production deploy | ❌ | `docs/DEPLOY_COOLIFY.md` step-by-step |
| GitHub Actions CI | ❌ (no GitHub remote) | `ci.yml` ready |
| iOS build/signing | ❌ no macOS | Xcode project config documented; signing placeholders per spec §9 |
| Real SMS (SSL Wireless/Infobip) | ❌ no credentials | adapters implemented; mock returns devCode |

---

## 3. Monorepo layout (pnpm workspaces + Turborepo)

```
sunnahlife/  (repo root = /home/z/my-project)
├── apps/
│   ├── api/          NestJS modular monolith (Prisma PostgreSQL, RLS)
│   ├── worker/       BullMQ workers (same codebase as api, own entrypoint)
│   ├── web/          Next.js public site + PWA  → THE REPO ROOT ITSELF (see note)
│   ├── admin/        Next.js admin panel
│   └── mobile/       Flutter app (android/, ios/ config included)
├── packages/
│   ├── shared-types/ generated from the API's OpenAPI; consumed by web/admin
│   ├── content/      seed content packs (JSON) — symlinked to repo content/
│   └── design-tokens/ single source of truth → Tailwind + Flutter ThemeData
├── infra/            docker-compose.yml, service Dockerfiles, pgBackRest config
├── docs/             PLAN, PROGRESS, ENVIRONMENT, DATA_MODEL, API, DESIGN_SYSTEM,
│                     DEPLOY_COOLIFY, DEMO_ACCOUNTS, API_CONTRACTS
└── .github/workflows/ci.yml
```

**Note (sandbox, not a design deviation):** the platform preview proxies
`bun run dev` on port 3000 with cwd fixed at the repo root, so the Next.js
web workspace **is the repo root** (its package.json is simultaneously the
workspace root). `pnpm-workspace.yaml` includes `.`, `apps/*`, `packages/*`,
so the tree is a valid pnpm monorepo as-is; on the VPS you may either deploy
with the root as web or move the web app into `apps/web` — turbo/pnpm configs
support both. All domain logic consumed by the web app already lives in
framework-agnostic lib modules.

---

## 4. Domain model (exact; extend, don't shrink)

Implemented in `prisma/schema.prisma` (web/SQLite mirror) and
`apps/api/prisma/schema.prisma` (production PostgreSQL + RLS policies — same
shape):

- **User** — phone/email, name, `gender` (M/F — set once at onboarding, only
  Full Admin changes), `role` (`user | daee | usrah_head | invigilator |
  full_admin`), `category` (`general | hafez | alim`), `memberCode`
  (`DS-000001` on becoming da'ee), `referredById`, `usrahId`, `level`
  (`none | muhibbus_sunnah | farze_ain_1 | farze_ain_2`), `levelStartedAt`,
  district/workplace/department, language, madhhab, calc method, lat/lng/city.
- **ReferralClosure** — closure table (ancestor, descendant, depth) powering
  "আমার মাদউ" downline and the "5 referrals reaching level" requirement.
- **Usrah** — name, gender (= head's = all members'), head, invigilator,
  district.
- **AmalDefinition** (DB-configurable, seeded from `packages/content`) — key,
  titles bn/en, category, `inputType` (`tristate`=জামাত/একা/কাযা, `boolean`,
  `count`, `quantity`, `text`), `cadence` (`daily | weekly:fri |
  weekly:mon_thu | monthly:ayyam_beez(13–15 Hijri)`), targets by category
  (tilawat: hafez 1 পারা / alim 10 পৃষ্ঠা / general 1 পৃষ্ঠা), `minLevel`,
  `sortOrder`, `autoSource` (which product-1 feature can auto-complete it).
- **AmalEntry** — natural key `(userId, amalKey, date)`, value JSON, `source`
  (`manual | auto:<feature>`), `clientUpdatedAt` (conflict winner),
  `serverUpdatedAt`, `locked` (computed) — **paper-diary rule:** a day locks
  after the next day's Ishraq; only Usrah head+ can unlock; unlocks are
  audit-logged (`DayUnlock`).
- **PersonalGoal** — up to 14 target amals with start date + reviewer notes.
- **WeeklyReview** — auto-created pending every 7 days per da'ee; auto-summary
  (per-category completion, streaks, missed days), comment, rating 1–5,
  next goals, status pending/done/overdue; both parties reminded.
- **AssessmentTemplate / Assessment** — versioned templates; Farze Ain v1 =
  23 criteria (Iman 5, Ilm 5, Ibadat 6, Akhlaq 7) seeded verbatim; scores
  0 (হয়নি) / 1 (আংশিক) / 2 (সম্পূর্ণ) + comments; participant category 1
  (beginner 45–60 min/day) / 2 (advanced 60–90); dual digital signature
  (assessor on submit, assessee OTP-confirmed); "majority complete per
  category" ⇒ passed (rule configurable).
- **LevelTransition** — from/to/at + evidence (assessment id, months in
  level, referral count at required level).
- Content & engagement: Dua, Dhikr sets (per-item repetition), Name (99),
  IslamicName, ImanBranch (70), Sunnah, Article, Course/Lesson, Quiz/Question,
  LiveProgram, Reminder, Announcement, MasalaQuestion, Feedback, AuditLog,
  Enrollment, QuizAttempt, Session, OtpCode.

ERD (Mermaid): `docs/DATA_MODEL.md`.

---

## 5. Roles & the gender rule — enforced in the DATABASE

| Role | Sees | Does |
|---|---|---|
| Full Admin | everything, both genders | users, usrahs, roles, amal catalog editor, assessment templates, level rules, CMS, live, broadcasts, audit log |
| Invigilator (পরিদর্শক) | all usrahs **of own gender** | usrah health dashboards, flags, overdue reviews, cross-usrah reports |
| Usrah Head (উসরা প্রধান) | own usrah members only (same gender) | member 31-day grids, weekly reviews, comments, goals, assessments, usrah questions, reminders, day-unlocks |
| Da'ee | own data + own downline (same gender) | everything a user does + referral link + madu tree |
| User | own data | app usage, amal tracking |
| Guest | public content, local-only amal data | prayer times, content, self-tests |

**PostgreSQL RLS (production) + `assertCanAccess` chokepoint (web mirror):**
queries executed with a female Usrah head's session **cannot** return male
rows even if application code forgets a filter — enforced by RLS policies
per table with session GUCs (`app.user_id`, `app.gender`, `app.usrah_id`,
`app.role`) set per request inside the transaction. The RLS e2e test
(`apps/api/test/rls.e2e-spec.ts`) proves it. Female users see the trust
message on day one (onboarding + profile).

---

## 6. Feature build order (delivery order per mandate)

1. **Foundation** — monorepo, tokens, docker-compose (all services healthy),
   Prisma schema + migrations + RLS + seeds, auth (guest/OTP/Google/Apple),
   OpenAPI, CI green, Flutter app shell with 5-tab navigation, theme, i18n
   scaffolding (bn/en/ar), Widgetbook.
2. **Prayer system** (mobile + web) — on-device calculation, countdown,
   schedule, forbidden times, alarms, home widget, post-prayer prompt.
3. **Muhasaba diary** — catalog, Today view, Month grid, personal goals,
   locking rule, offline sync, streaks.
4. **Da'wah engine** — member codes, referral links + `/join/DS-XXXX` landing,
   closure tree, usrahs, weekly reviews, assessments, levels.
5. **Admin panel** — three role dashboards, catalog/template editors, monthly
   PDF report worker.
6. **Content** — Qur'an, adhkar with auto-logging, du'as, names, branches,
   sunnahs, articles, Meilisearch.
7. **Learn & Live** — courses, quizzes (incl. live quiz), usrah questions,
   YouTube live embed, notifications & reminders.
8. **More** — zakat, qibla, mosque map, masala form, support, donation
   redirect, detox (Guard-module seed), profile completeness.
9. **Polish & release** — low-end performance pass, accessibility, RTL pass,
   store assets, release builds, Coolify guide verified against compose.

---

## 7. Design system (summary — full doc `docs/DESIGN_SYSTEM.md`)

- **Tokens first** (`packages/design-tokens/tokens.json` → Tailwind + Flutter):
  primary deep green `#1F4D3D`, cream `#F7F4EC`, card white, gold `#C99A3B`,
  alert `#FCE4E4`/`#C0392B`, text `#222222`/`#666666` + full dark palette;
  semantic roles (surface/on-surface/outline/success/warning); 8-pt spacing
  grid; type scale (Bengali body 16/24, captions 12, headings 20–28,
  line-height ≥1.6); radii 8/12/16; elevation; motion 120/200/320 ms.
- **Typography:** Hind Siliguri/Noto Sans Bengali (bn), Inter (latin), Amiri
  Quran/KFGQPC Uthmanic (Qur'an), Noto Naskh (du'as).
- **Layout:** card-based, 2-column feature grid, "সব দেখুন →" headers,
  safe-area aware, tablet-adaptive, full RTL mirroring for Arabic.
- **Interaction:** skeleton loaders, designed empty/error/offline states,
  optimistic amal toggles, haptics on dhikr counters + salat chips,
  pull-to-refresh, 60 fps on 2 GB Android, cold start <2 s, debug APK <40 MB.
- **Accessibility:** WCAG AA both themes, 44×44 pt targets, dynamic type,
  semantic labels.
- **Trust UX:** female privacy note day one; lock/sync/review states legible.
- **Admin UX:** dense TanStack tables, sticky headers, saved filters,
  CSV/PDF export; 31-day heatmap readable at a glance.
- Storybook (web/admin) + Widgetbook (Flutter) in place.

## 8. Engineering quality bar (definition of done)

- No TODOs, no mock data on production paths, no fake-success stubs; every
  screen wired to the real API and real local DB.
- OpenAPI generated by the API; typed clients for web/admin
  (`packages/shared-types`) and Flutter (typed client).
- Prisma migrations + seeds: full amal catalog, assessment template, level
  rules, sample usrahs (one M + one F), demo users for every role
  (`docs/DEMO_ACCOUNTS.md`).
- Tests: RLS gender-isolation e2e; sync-conflict unit tests; prayer-time
  snapshots (Dhaka/Riyadh/London); assessment scoring; Flutter widget tests
  (Today diary + month grid). CI runs lint + test + build for api/web/admin +
  `flutter analyze` + `flutter test` + `flutter build apk --debug`.
- Security: OTP rate limiting, refresh rotation + reuse detection, audit log
  on unlock/role/gender changes, no PII in logs, secrets via env.
- Observability: structured logs, `/health`, Prometheus metrics endpoint.
- Docs: PLAN, PROGRESS, ENVIRONMENT, DATA_MODEL (ERD), API, DESIGN_SYSTEM,
  DEPLOY_COOLIFY, DEMO_ACCOUNTS + one-command local start in README.

## 9. Assumptions (as permitted)

1. Referral tree (informational + level evidence) and Usrah membership
   (accountability) are **separate structures**; admins assign usrahs.
2. Diary unlock: Usrah head and above (invigilator, full admin).
3. Full Admin sees both genders; every other role strictly gender-scoped.
4. Domain placeholder `sunnahlife.app` (config-driven).
5. Where the PDFs are silent → prefer **admin-configurable** over hard-coded
   (level thresholds live in `content/level-rules.json`, served via config).
6. Ayyam-e-Beez = Hijri 13–15 of every lunar month.
7. Ishraq = sunrise + 20 min; Duha = sunrise + ¼(sunrise→dhuhr); Tahajjud =
   last third of night (constants configurable in the prayer lib).
8. Maghrib = sunset + 3 min safety (BD convention).

## 10. Worklog & coordination

Every agent reads and appends to `/home/z/my-project/worklog.md` (template at
the bottom of that file). API contracts: `docs/API_CONTRACTS.md`. The NestJS
API (`apps/api`) implements the same REST contract the web mirror exposes,
so the Flutter app, web PWA and admin panel can all target one backend in
production while the sandbox preview keeps running from the Next.js mirror.

---

*বিসমিল্লাহির রাহমানির রাহীম। Begin.*

---

# Phase B — completion (post-audit)

**Trigger:** independent audit of the delivered Phase A (≈60–70% of master
prompt). This section plans the remaining work end to end. Order matters:
repo integrity first (B0), single-backend consolidation second (B1) —
everything else builds on those two. Agents work in waves; the lead commits
and pushes after every wave.

## B0 — Repository completeness (blocking everything)

- `.gitignore` bug: bare `test` and `db/` rules silently excluded
  `apps/mobile/lib/db/` (the Drift database `providers.dart` imports!),
  `apps/mobile/test/` (38 tests) and `apps/api/test/` (34 Jest tests, incl.
  RLS e2e). Fix: anchor the rules (`/db/` for the runtime SQLite dir only),
  un-ignore the Flutter gradle wrapper (`gradlew`, `gradlew.bat`,
  `gradle-wrapper.jar`) so CI can build the APK, then
  `git ls-files --others --exclude-standard` → commit everything.
- Proof: fresh `git clone` from origin into /tmp → `flutter pub get &&
  flutter analyze && flutter test` (mobile) and `bun install && bun run test`
  (api). Raw output pasted in the final report. Disk freed for this:
  `~/.gradle` (CI builds remotely), `~/.bun` install cache, stale `apps/mobile/build`.

## B1 — One backend (NestJS), web moved into `apps/web`

- Move the root Next.js app → `apps/web` (own package.json; root keeps a thin
  orchestrator whose `dev` script runs the web app on port 3000 and tees to
  the root `dev.log`). Delete root `src/app/api/**`, root `prisma/`, `db/`,
  and the `webdata` volume from `infra/docker-compose.yml`.
- Web talks ONLY to NestJS: `NEXT_PUBLIC_API_BASE` (empty in sandbox →
  same-origin `/api` + `XTransformPort=3001` query on every request, per
  gateway rules), types from `packages/shared-types` (regenerated).
- Whatever the web needed from the deleted mirror routes gets added to
  NestJS under RLS (amal definitions for guests, config, masala, feedback,
  live programs, quran packs…).
- `RolesGuard` + `@Roles()` decorator on every admin/usrah/review/assessment
  controller — RLS stays the last line of defence; authorization explicit at
  the API layer too.
- Proof: browser E2E against the live NestJS port with server log lines
  showing the `/api/*` hits.

## B2 — Push notifications (FCM HTTP v1)

- `DeviceToken` model (already in schema) + registration endpoint; mobile
  `firebase_messaging` integration, token upload, deep links
  (`sunnahlife://` + `/.well-known/assetlinks` style web fallback).
- NestJS `PushService`: FCM HTTP v1 adapter (service account via
  `FCM_SERVICE_ACCOUNT_JSON`) + no-op dev adapter; gender-aware fan-out for
  usrah broadcasts; prayer-push worker + weekly-review reminders route
  through it.
- `apps/mobile/android/app/google-services.example.json`, Firebase console
  steps in `docs/RELEASE.md`; iOS APNs registration + capabilities in
  AppDelegate/Runner entitlemments + `docs/IOS_BUILD.md`.

## B3 — Monthly Muhasaba PDF report (the paper form, digital)

- BullMQ processor for the existing report queue: header (name, DS code,
  district, Bengali month), 31-column grid in amal-catalog order (✔/□ for
  salat tristates, counts for count items), weekly + monthly tally rows,
  that month's reviewer comments, signature lines — Bengali font bundled,
  `pdfkit`-style rendering in `apps/api` (`ReportsModule`), upload to MinIO
  (S3 service), listed in admin exports with download, manual trigger
  endpoint (Full Admin).
- Proof: generate for one seeded male + one seeded female da'ee;
  `pdftotext` first page of each pasted in the report.

## B4 — Ilm content & quizzes (real data, not shells)

- `content/courses.json`: 2 courses × 5 Bengali lessons.
- `content/quizzes.json`: 3 quizzes × 10 MCQs with explanations.
- `content/mosques.json`: ≥20 Dhaka mosques with coordinates;
  `content/faq.json`: ≥15 Bengali FAQs.
- API: enrollment progress, quiz attempts with scoring, upcoming/recorded
  lists, usrah questions (head assigns, members answer, RLS-scoped).
- Live quiz over WebSocket (socket.io gateway INSIDE the NestJS API —
  folded in from the retired :3030 mini-service in B9) with per-gender
  leaderboard.

## B5 — Social auth

- Google Sign-In (Android + Web) and Apple Sign-In (mandatory for App
  Store) → backend links to the same User by verified email; gender asked
  at onboarding, locked afterwards (never taken from the IdP).

## B6 — Level automation + full admin CRUD

- Nightly worker evaluates `content/level-rules.json` → LevelTransition +
  audit log + reminder, automatic; admin promote stays as a reason-required
  override. Dawah tab shows live requirements checklist.
- Admin API + UI: amal catalog CRUD (create/update/reorder/disable),
  versioned assessment templates, usrah management (create, assign head +
  invigilator, move members), audited role/gender changes (Full Admin only),
  live program CRUD.

## B7 — i18n (bn/en/ar + RTL) & accessibility

- Mobile: ARB files + gen-l10n, hot-swap language switch, Arabic locale
  under `Directionality(rtl:)`, audit for hard-coded L/R.
- Web + admin: message catalogs, logical CSS properties, RTL when ar.
- A11y: Semantics on interactive widgets, ≥44×44 targets, 1.3× text scale
  without overflow, WCAG AA contrast table for both themes (documented in
  `docs/AUDIT.md`).

## B8 — CI proof, docs, audit

- GitHub Actions: mobile job builds debug APK (+ release appbundle behind
  secrets) and uploads artifacts — no local Gradle. Fix until green; run URL
  + per-job results pasted.
- `docs/IOS_BUILD.md` (remaining Xcode/APNs steps), `docs/RELEASE.md`
  (Firebase + store release), `docs/DEPLOY_COOLIFY.md` rewritten as a
  blind-followable DevOps runbook (services, env, volumes, pgBackRest,
  Cloudflare, health checks, seed, rollback).
- `docs/AUDIT.md`: master-prompt §4–9 requirement table —
  Done/Partial/Not done + implementing files + proving command. Honest only.

## B9 — Surface parity: mobile Ilm/Dawah screens + one-backend live quiz

**Trigger:** post-Phase-B audit found three gaps: the courses/quizzes/live
quiz/usrah-questions/dawah-checklist features existed only on the web; the
live quiz ran as a separate bun mini-service (:3030) outside NestJS; and
`usrah.controller.ts` lacked `@Roles` for consistency.

- Fold the live quiz INTO the API: `apps/api/src/engagement/quiz.gateway.ts`
  (socket.io gateway on the API's own HTTP server, path `/socket.io`), same
  HMAC room-token auth minted by `GET /api/quiz/live-token`, same wire
  protocol. `WsAdapter` in main.ts; `JwtAuthGuard` + `AllExceptionsFilter`
  made ws-context safe (global guards/filters also run on gateways).
  `mini-services/quiz-service` deleted. Web connects via the same base as
  REST (sandbox `/?XTransformPort=3001` → Caddy → API :3001; prod
  `NEXT_PUBLIC_API_BASE`). Smoke: `bun run smoke:quiz` (apps/api).
- `@Roles("user")` + `@UseGuards(RolesGuard)` on `usrah.controller.ts`.
- Mobile Flutter UI for everything the web already had:
  - Ilm tab: course list → detail → lesson player with per-lesson progress
    (POST /api/enroll, PATCH /api/enroll progress), self-paced quiz player
    (10 MCQs, explanations, POST /api/quiz-attempt, attempt history),
    live quiz screen on socket_io_client (same protocol).
  - Dawah tab: usrah question board (ask + head answers, RLS) and the live
    level-requirements checklist (GET /api/dawah/requirements).
  - ARB strings bn/en/ar for every new screen (gen-l10n).

*Commit + push after every wave. Git is the safety net.*

---

# Phase C — make it real (post-device audit)

**Trigger:** the owner installed the debug APK on a real phone. It runs, but a
line-by-line audit found that most remaining failures only show up on a real
phone or a real server (empty Qur'an list, receivers missing from the
manifest, seed wiping the DB on boot, mock-only SMS, 6-hour-late pushes…).
Phase C is not "add more code" — it is "make what exists real, safe and
complete". Baseline tag: `v0.9-pre-phase-c`.

## C.0 Ordering & reasoning (why this order)

Five observations drive the ordering:

1. **Shared plumbing first.** tz handling (User.tz), the config endpoint
   (contacts / hijri adjust / donation URL / flags), and the content pipeline
   (packages/content → mobile assets copy + CI parity) are depended on by
   items in Parts A, B and C. Doing them first means every later item is born
   correct instead of being retrofitted.
2. **Client-form content rides the same pipe.** Part D (verbatim assessment
   criteria, ~30-goal Muhibbus outline, ladder fix) is pure content + rules.
   `seed:reference` (A1) seeds exactly those files — so D must land *with or
   before* the seed split, or the split would seed the drifted text a second
   time.
3. **Security before features, deployability before polish.** Part A
   (SMS, tokens, RLS, Docker, URLs) is what makes the thing *safe to run*;
   Part B is what makes it *run at all* on a device; Part C is what makes it
   *feel premium*. A customer cannot feel premium UI served by a mock SMS
   layer that logs everyone in as anyone.
4. **Proof discipline is constant.** Anything not runnable in the sandbox
   (Gradle, Docker, real FCM) gets a CI job as its proof ("Done without a CI
   job or test that proves it is not [acceptable]"). Every device-only bug
   gets a regression test that would have caught it (114-surah assert,
   manifest-receiver parse, non-empty content-pack check, tz tests for
   Dhaka/Riyadh/London, DTO-through-the-real-pipeline merge test).
5. **Sandbox resource budget.** 1.8 GB disk free, no Docker daemon, no
   Gradle/NDK. Plan accordingly: prove Docker via a GitHub Actions compose
   job; prove release APK via a split-per-abi release job with a size report;
   never run heavy toolchains in parallel; `jest --runInBand`.

## Wave 1 — Shared plumbing (unblocks everything)

- **C-W1a · User.tz + tz-correct scheduling.** Add `tz` (default
  `Asia/Dhaka`) to User; prayer-push processor computes the delay from the
  *user's* wall clock (not UTC-shifted Dhaka); `weekStartOf` takes tz;
  day-lock computed in user tz (not hard-coded +6). Tests: Dhaka, Riyadh,
  London. (Part A8 — done early because B2's scheduler and C2's date bar
  consume it.)
- **C-W1b · Config endpoint consolidation.** One `/api/config` source of
  truth: Hijri ±adjust, donation URL, five institution contacts, app-user
  group links, leaderboard flag, detox flag. Admin CMS writes it; mobile,
  web and admin read it. (Feeds A1 seed, C1 chrome, C4 More, C8 admin.)
- **C-W1c · Content pipeline + Part D content.** `packages/content` is the
  only source; a build script copies packs into `apps/mobile/assets/content`
  (and web consumes directly); CI check fails if a copy differs or any pack
  is empty/`{}`. Fill: 114-surah `quran-meta-bn.json` (from Uthmani data),
  real `faq.json`, real `mosques.json`; copy `amal-catalog.json`,
  `assessment-farze-ain-v1.json`, `level-rules.json` into mobile. **Part D
  verbatim:** 23 criteria + instructions + two category descriptions
  (`farze_ain_v1.1`), the ~30-goal Muhibbus outline, the corrected ladder
  (Muhibbus = 4 months + outline review + 5 people; Farze Ain = the
  assessment), diary instructions 1–6 surfaced in-app. Tests: 114-surah
  assert, pack non-empty assert, manifest-receiver parse assert.
- **C-W1d · Monorepo hygiene (Part E subset).** One package manager (bun
  workspaces, root `bun.lock`, `packageManager` field), remove
  `pnpm-workspace.yaml`/`turbo.json`, delete sandbox leftovers
  (`.zscripts/`, `mini-services/`, `examples/`, `download/`, root
  `tests/*.sh`, root `Caddyfile`), `ignoreBuildErrors: false` + typecheck
  jobs in CI, CI `report` job stops pushing commits (job summary only),
  top-level `permissions: block`, remove sandbox URL vars (XTransformPort)
  → `NEXT_PUBLIC_API_BASE` build-arg everywhere. (Done now — later waves
  must not reintroduce any of it.)

## Wave 2 — Part A · Production blockers (security & deploy)

- **C-W2a · Seed split.** `seed:reference` = idempotent upserts only (amal
  catalog, templates, level rules, content, config) — runs on boot, never
  deletes; `seed:demo` = demo users/usrahs, only when `SEED_DEMO=true` AND
  `NODE_ENV !== "production"`. FCM `google-services` guarded. Tests: boot
  twice → row counts stable; demo seed refuses in production.
- **C-W2b · Real SMS + OTP hardening.** SSL Wireless + Infobip HTTP
  adapters (env creds); production boot fails on `SMS_PROVIDER=mock` or
  missing creds; `devCode` never returned outside non-production;
  `crypto.randomInt` OTPs stored hashed; atomic attempt counter;
  `@nestjs/throttler` per IP + per phone; mobile release build must not
  auto-fill devCode; admin quick-login grid only with
  `NEXT_PUBLIC_DEMO=true`.
- **C-W2c · Token & secret handling.** JWT `typ` claim checked in
  `auth.guard.ts`; separate refresh secret (no fallback to access secret);
  atomic rotation (`updateMany … usedAt IS NULL` in a transaction);
  production env validation fails boot for default/missing
  `JWT_SECRET`/`JWT_REFRESH_SECRET`/`QUIZ_SECRET` and empty
  `CORS_ORIGINS`; remove `override: true`; CORS list also applied to the
  socket.io gateway.
- **C-W2d · Docker images + compose smoke CI.** Fix all four Dockerfiles
  (standalone output, `outputFileTracingRoot` server.js path, dockerignores,
  admin port 3000-in-container, no non-existent copies). CI job: build
  api/worker/web/admin images → `docker compose up -d` → wait healthy →
  migrate + seed:reference → curl `/health` 200, web `/` 200, admin
  `/login` 200. That job is the proof.
- **C-W2e · RLS tightening.** (a) User `usrahId` clause restricted to
  usrah_head/invigilator; (b) DayUnlock insert = usrah_head+ at DB level;
  (c) RLS on OtpCode/AuditLog/MasalaQuestion/Feedback; (d) users cannot
  change own role/gender/usrahId at DB level (column privileges); (e)
  migration fallback password removed; (f) worker runs as restricted role
  (no superuser DIRECT_URL); (g) `rls.e2e.spec.ts` extended: positive
  control, same-gender-other-usrah member, reports/reviews coverage,
  `current_user`/`rolbypassrls` asserts. PATCH /admin/users gender-mismatch
  rejected; weekly-review fallback = same-gender invigilator, never
  cross-gender admin.
- **C-W2f · Push delivery.** FCM `urn:ietf:params:oauth:grant-type:jwt-bearer`
  grant; OAuth token cached until expiry; device-token registration removes
  the token from every other user. Tests: transport unit test with mocked
  token endpoint (grant type + cache), dedup test.
- **C-W2g · Sync & guest merge (server).** `GuestEntryDto` validators (the
  whitelist pipe was stripping `value`/`clientUpdatedAt`!); test app uses
  the *real* `main.ts` pipeline; LWW: clamp `clientUpdatedAt` ≤ now+5min,
  conditional/atomic upsert, validate values against inputType, `auto:*`
  source not trusted blindly, server's winning value returned on rejection;
  guest merge ordered + capped chunks.
- **C-W2h · Operations.** `/health` 503 when degraded; `/metrics` + `/docs`
  internal-only; structured logger wired (no PII — names/phones/query
  strings redacted); compose: API not bound to host port (2-replica
  scalable), socket.io Redis adapter, Redis AOF, pinned minio/mc,
  pgBackRest/WAL — honest `Partial` if unprovable.

## Wave 3 — Part B · What breaks on a real phone

- **C-W3a · Qur'an reader.** 114-surah metadata (W1c); ~5 MB JSON parsed in
  a background isolate (`compute`); FutureBuilder bugs fixed (search closes
  keyboard; bookmark/translation toggle jumps scroll to top — memoized
  futures); recitation audio (`just_audio`, per-ayah streaming + cache +
  reciter choice); go-to-ayah; resume-from-last-read. Golden tests bn
  light/dark + ar RTL.
- **C-W3b · Prayer bell scheduler.** Manifest: `ScheduledNotificationReceiver`,
  `ScheduledNotificationBootReceiver`, `ActionBroadcastReceiver`,
  `RECEIVE_BOOT_COMPLETED`; Android 14 exact-alarm permission screen with
  inexact fallback (no unhandled throw); rolling 2–3-day schedule;
  reschedule on boot / city / madhhab / method change + daily WorkManager;
  post-prayer notification with জামাতে/একা/কাযা action buttons writing the
  diary; monochrome `ic_notification`; per-row "N minutes before/after"
  (not only fixed 10-min).
- **C-W3c · Location, qibla, mosques.** `geolocator` permission flow +
  manual city fallback; snap to nearest district; city in header;
  magnetometer compass + calibration hint; `flutter_map` (OSM tiles) +
  nearby mosques from API.
- **C-W3d · Sync pull.** Cursor-based pull on login + app start; rejected
  entries stop retrying forever (bounded retries + surface state); non-API
  error no longer leaves `syncing=true`; sync state visible in UI.
  (Server side in W2g; this is the client side + golden test.)
- **C-W3e · Auto-silent.** Settings screen (explain → request DND access →
  silence N min at each jama'at → restore). Kotlin DND handlers already
  exist; wire Dart calls.
- **C-W3f · Home widget.** Persist next-prayer times for the widget;
  background refresh so it survives app death (no "--:--" reset).
- **C-W3g · Hijri adjust + donation.** Admin `/api/config` hijri ±1 applied
  to mobile date bar; donation link opens in-app browser (Custom Tabs).
- **C-W3h · Referral links.** Web `/join/DS-000123` route + landing;
  `assetlinks.json` + `apple-app-site-association`; `autoVerify` intent
  filter + iOS associated-domains; app handles incoming link → onboarding
  pre-fills `referred_by`. (Store upload of the site files documented for
  the owner.)
- **C-W3i · APK size + release CI.** Remove `keepDebugSymbols`; release
  ships arm64-v8a + armeabi-v7a; CI job `flutter build apk --release
  --split-per-abi` (upload key when secret exists, else
  `internal-test-<abi>`), artifacts + sizes in job summary. Target: arm64
  release < 40 MB.

## Wave 4 — Part C · Make it feel complete and premium

- **C-W4a · Global chrome (§3).** Top header on every main screen (logo,
  location, Gregorian/Bangla/Hijri bar, notification + reminder + profile
  icons); floating headset button → Contact panel (five institutions from
  config); Notification panel + Reminder panel as real screens.
- **C-W4b · Home per spec order.** Countdown ring hero (HH:MM:SS) with
  hero-transition to the schedule; schedule incl. tahajjud/ishraq/duha with
  alarm popup; three forbidden-time cards; সর্বাধিক ব্যবহৃত (real usage
  counts); দ্রুত প্রবেশ grid; Ilm section; today's amal preview (progress
  ring); Live preview; "সব দেখুন →" headers.
- **C-W4c · Amal completeness (§4.2).** 14 personal-goal amals
  (set → mentor approve → remind → review), custom checklist, single-amal
  tracker, exercise tracker, fard/sunnah/nafl/akhlaq groupings,
  daily/forgotten/salah sunnahs, tilawat minutes for beginners,
  gender-scoped leaderboard as percentile bands behind a config flag.
- **C-W4d · More (§4.3) complete.** Donate + Foundation services (top),
  zakat, live support thread (admin replies), usrah join request, masala,
  99 names, Islamic names, 70 branches, app user groups, my mosque, qibla,
  auto-silent, Social Media Detox (UsageStats — seed of the Guard module),
  about, FAQ, feedback, share (`share_plus`).
- **C-W4e · Dawah craft.** Referral share card rendered to a branded PNG;
  real madu tree view.
- **C-W4f · Design system craft.** Custom bottom bar + app bar from
  design-tokens (no stock Material chrome); one icon set (Phosphor) mapped
  to the spec's element codes; bento grid on 8-pt rhythm; Bengali
  line-height ≥ 1.6; subtle Islamic geometric texture in hero/header;
  motion tokens (shared-axis/fade-through, hero transitions, haptics +
  micro-interactions); shimmer skeletons; illustrated empty/error/offline
  states; tuned dark mode; 360×640 + 1.3× text-scale verified; lazy heavy
  packs for < 2 s cold start; golden tests (Home, Today diary, Month grid,
  Qur'an reader × bn light/dark/ar RTL); Widgetbook entries.
- **C-W4g · Web (§3.3).** Top nav (Home, আমাদের সম্পর্কে, আর্টিকেল/রুলস,
  সেবা, highlighted Donate, Notification, Reminder, Login/Profile); real
  service worker (PWA installs, offline prayer times + content);
  `<html lang dir>` per locale; finish web i18n (remove hard-coded bn).
- **C-W4h · Admin maturity.** Role-specific nav + dashboards; level-rules
  editor; CMS for courses/quizzes/duas/articles/FAQ/mosques/contacts/config;
  referral tree visualisation with server-side pagination; meaningful
  invigilator health score (review completion, mean amal completion,
  inactive members, overdue flags).
- **C-W4i · Assessment signature.** Assessee notified → reviews scores in
  app → confirms with OTP → only then final (schema + flow + admin view).
- **C-W4j · Search.** Meilisearch query endpoint (duas/adhkar/names/
  articles/Islamic names, Bengali typo-tolerant) + mobile & web usage with
  offline fallback.

## Wave 5 — Part E · Clean-up + reporting

- Unused web deps removed; DEPLOY_COOLIFY.md rewritten to reality (Traefik
  owns 80/443, FQDN per service, build args, seed split, SMS provider,
  backups, cdn. MinIO, Cloudflare websockets for /socket.io, rollback).
- `docs/AUDIT.md` rewritten with a **Proven by** column (unit/widget test ·
  CI job `<name>` · needs real device / credentials). Last group ⇒ "Ready
  for device test", never "Done".
- `docs/PHONE_TEST_CHECKLIST.md` — owner's step-by-step device script.
- Sandbox-impossible items (real Firebase project, SMS creds, Google/Apple
  client IDs, iOS build, Coolify deploy, on-device test) documented as
  exact human steps.

## Invariants for every wave

- Small descriptive commits; push after each meaningful unit.
- Fresh-clone gates: `bun run lint`, `tsc --noEmit`, `jest --runInBand`,
  `next build` (webpack), `flutter analyze`, `flutter test` — where
  runnable.
- Raw terminal output pasted into the report; Actions run URL + per-job
  table for CI-proven items; APK sizes in the summary.
- The worklog gets one section per wave; AUDIT.md is never allowed to say
  "Done" for anything not proven here.
