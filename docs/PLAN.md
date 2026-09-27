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
