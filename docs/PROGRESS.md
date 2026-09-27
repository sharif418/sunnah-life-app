# Sunnah Life — PROGRESS.md

Verification artifacts get pasted here after each milestone. Newest first.

## Milestone 1 — Foundation (Task ID 1) ✅

**Built:** monorepo-adapted workspace (see PLAN.md §2.1), design tokens (light+dark),
Bengali/Arabic/Latin font stack, Prisma schema (22 models) + push, on-device
prayer engine, Bangla + Hijri calendars, qibla, 64-district city DB, i18n
(bn/en/ar), fuzzy search, offline-first amal store with batched outbox sync,
app shell (5 tabs, onboarding, OTP auth + demo quick-login), foundation APIs
(auth/me/config/join/reminders/quran), PWA manifest.

**Verified (curl + lint):**
- `bun run lint` → 0 issues
- `GET /` → 200 (renders)
- `GET /api/config` → 200, `GET /api/me` → `{user:null}`
- `POST /api/auth/otp/request` → `{ok:true,devCode:"319476"}`
- `GET /api/quran/surahs` → 114 surahs; `GET /api/quran/surah/112` → Bismillah correctly stripped; `/1` → Bismillah kept as ayah 1; Bengali translation merged ✓

**Prayer engine snapshot tests (Karachi 18/18, Hanafi Asr, on-device):**
```
2025-06-15 Dhaka: Fajr 03:43 Sunrise 05:11 Dhuhr 11:59 Asr 16:39 Maghrib 18:50 Isha 20:14 Tahajjud 01:43 Ishraq 05:31 Duha 06:53
2025-12-21 Dhaka: Fajr 05:15 Sunrise 06:36 Dhuhr 11:56 Asr 15:40 Maghrib 17:19 Isha 18:37
2025-02-10 Dhaka: Fajr 05:18 Sunrise 06:35 Dhuhr 12:13 Asr 16:14 Maghrib 17:53 Isha 19:07
2025-06-21 London: Fajr 01:02 (night-middle clamp at 49°N summer) Sunrise 04:43 Maghrib 21:24
2025-06-15 Riyadh: Fajr 03:32 Sunrise 05:04 Dhuhr 11:54 Asr 16:36 Maghrib 18:47 Isha 20:14
```
Cross-checked against an independent NOAA-formula calculator:
```
NOAA Dhaka 2025-06-15: sunrise 05:11 sunset 18:46   (engine: 05:11 / 18:47 ✓)
NOAA Riyadh 2025-06-15: sunrise 05:04 sunset 18:43   (engine: 05:04 / 18:44 ✓)
NOAA London 2025-06-21: sunrise 04:43 sunset 21:21   (engine: 04:43 / 21:21 ✓)
NOAA Dhaka 2025-12-21: sunrise 06:37 sunset 17:17   (engine: 06:36 / 17:16 ✓)
```
(≈1 min = MAGHRIB_SAFETY_MIN + rounding; documented.)

**Not done in sandbox (with reasons):** Flutter/Android toolchain builds,
Docker compose, Postgres RLS (SQLite here — replaced by the
`assertCanAccess` chokepoint), CI pipeline. See PLAN.md §2.1 and §10.

## Milestone — Task 3-b COMPLETE: NestJS API + Worker verified green (Task ID 5)

**Built/fixed this round:**
- `AuthedRequest` Bun-ESM runtime bug: `emitDecoratorMetadata` retained the type-only
  interface as a runtime import → bun's strict ESM linking failed ("Export named
  'AuthedRequest' not found"). Fixed in all 11 controllers via `import type`.
- `apps/api/src/worker.ts` — canonical compiled worker entrypoint (`dist/worker.js`,
  wired as `start:worker` script; compose `worker` service fallback chain now satisfied).
- `apps/worker/package.json` — dropped unresolvable `workspace:*` dep (imports are
  relative into ../api/src; documented NODE_PATH for bun --hot dev).
- `packages/shared-types/scripts/generate.ts` — two path bugs fixed (createRequire
  needs a FILE anchor; openapi-typescript cwd was `packages/api`, nonexistent).

**Verified (pasted from this session):**
- `bun install` apps/api: 311 packages (after freeing 3.4 GB: .gradle/caches 2.9G + mobile build/ 593M — disk was 100% full)
- `nest build` → exit 0 (twice)
- `bun run test` → **4 suites, 34/34 passed** (incl. rls.e2e gender-isolation proof + sync-conflict)
- `bun run lint` → **0 errors, 0 warnings** (7 unused-import warnings removed)
- `openapi:export` → 35 paths
- `shared-types generate` → dist/openapi.json + dist/schema.d.ts (openapi-typescript 7.13.0)
- API booted (`node dist/main.js` :3001): `/health` → postgres ✓ redis ✓ meilisearch ✓ storage ✓; queues registered; `POST /api/auth/otp/request` → devCode; `GET /api/config` → live JSON
- Worker booted (`node dist/worker.js`): 4 repeatable schedulers registered (prayer-push-nightly, weekly-reviews-saturday, monthly-report-first, streaks-daily), delayed jobs visible, "Waiting for jobs…"

**Sandbox services:** PG16 :5433 (15 users, 31 amal defs, 15 RLS policies seeded), Redis :6380, Meili :7700.

## Milestone — Task 3-c COMPLETE: Tarbiyah Admin Panel (apps/admin)

**Scope (from crashed session, recovered + verified this round):**
- Complete Next.js 16 admin app (desktop-first, Bengali UI, TanStack Query/Table):
  `/login` (demo accounts), dashboard overview, `users`, `members/[id]` (full profile +
  month-grid heatmap + locked-day unlock dialog with audit reason), `usrah` (health),
  `referrals` (closure tree), `reviews` (pending/complete weekly Muhasaba), `assessments`
  (Farze Ain grading), `catalog` (amal definitions CRUD), `levels` (transitions),
  `live` (broadcasts), `broadcast` (compose), `exports` (CSV hub: users, usrah health,
  month grids, audit), `audit` (log viewer).
- Shared libs: `lib/api.ts` (typed client, 40+ endpoints), `lib/session.tsx` (token
  bootstrap + role gate), `lib/bn.ts` (Bengali dates/numbers/labels), `lib/csv.ts`
  (Excel-safe CSV with BOM), `lib/demo-accounts.ts`, `lib/labels.ts`.
- Components: app-shell (sidebar nav, role-aware), badges, month-grid heatmap
  (print/PDF-ready), rating, review-dialog, providers (QueryClient + Theme +
  Session + Toast).

**Recovered this round (the crashed session committed with a UUID message and 9 TS errors):**
- Fixed `members/[id]`: missing `useMutation`/`useToast`/`useQueryClient` imports in UnlockDialog.
- Fixed `exports`: monthGrid response is `{ grid }` (was destructuring `res.user` — dropped
  field; now resolves the selected user's name from the users list).
- Fixed `month-grid`: `const { toast } = useToast()` (was calling the context value).
- Widened `roleRank`/`isSupervisor`/`isFullAdmin` in `lib/labels.ts` to `string`
  (RoleGate's `allow` callback passes plain strings; unknown roles now rank -1).

**Verified (this round):**
- `bun run lint` → 0 errors · `bun run typecheck` → 0 errors · `bun run build` → 15 routes compiled ✓
- Runtime smoke: api :3001 `/health` all-green; admin :3002 `/login` → 200, `<title>সুন্নাহ লাইফ অ্যাডমিন</title>`, `/` → 200.
- Hygiene: `tool-results/` untracked from index (was already on GitHub without any secrets — PAT grep clean).

**Next:** Flutter chunks F2/F3 (platform channels: exact alarms, notifications, home-screen
widget; then polish), then delivery steps 4–9 of the Master Prompt (Da'wah engine,
content, Learn & Live, More, launch).
