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
