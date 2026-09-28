# Sunnah Life — Shared Worklog

All agents MUST read this file before starting, and MUST append their section
(using the template at the bottom) after finishing. Never overwrite others'
sections. The coordination bible is `docs/API_CONTRACTS.md` — read it too.

---

Task ID: 1
Agent: lead-architect (main session)
Task: Foundation — PLAN.md, Prisma schema, design tokens, fonts, core libs (prayer engine, calendars, qibla, cities, i18n, store, API client), app shell (5-tab nav, onboarding, auth modal), auth/config/join/quran/reminders API routes, Qur'an data download, API contracts doc.

Work Log:
- Verified sandbox: Next.js 16 dev server on :3000, Bun 1.3.14, Tailwind v4 (CSS-first), full shadcn/ui set, Prisma+SQLite, no Docker/Flutter/pnpm. Network OK (Google Fonts, alquran.cloud reachable).
- Wrote docs/PLAN.md (architecture, sandbox adaptation matrix, assumptions).
- Downloaded content/quran-uthmani.json (2.1MB, 114 surahs) + content/quran-bn.json (2.9MB Bengali translation, Muhiuddin Khan) from api.alquran.cloud.
- prisma/schema.prisma: User (roles/gender/memberCode/usrahId/level/…), Session, OtpCode, ReferralClosure, Usrah, AmalDefinition, AmalEntry (unique userId+amalKey+date), DayUnlock, PersonalGoal, WeeklyReview, AssessmentTemplate, Assessment, LevelTransition, Announcement, Reminder, AuditLog, MasalaQuestion, Feedback, LiveProgram, Enrollment, QuizAttempt. Pushed with `bun run db:push`.
- globals.css: full token system — light (cream #F7F4EC bg, card white, primary #1F4D3D, gold #C99A3B, alert #C0392B) + dark (green-black #0E1613). Radii 8/12/16, shadow-card/lifted, font-arabic/font-quran utilities, Islamic lattice patterns, scroll-thin/no-scrollbar, safe-bottom, tap-target, RTL flip helper.
- layout.tsx: Hind Siliguri (bn+latin) + Inter + Amiri + Amiri Quran via next/font. Metadata bn-first + manifest + themeColor.
- src/types/domain.ts: ALL shared types + label maps (ROLE_LABELS_BN, LEVEL_LABELS_BN, ROLE_RANK, AMAL_CATEGORY_LABELS_BN, PRAYER_LABELS_BN, FARZ_PRAYERS).
- src/lib/prayer-times.ts: PrayTimes.org solar algorithm, CALC_METHODS (karachi default 18/18, Hanafi asr factor 2), night-middle high-lat clamp with NaN guards, Ishraq=+20min, Duha=sunrise+¼ to dhuhr, Tahajjud=last third, Maghrib=sunset+3min (MAGHRIB_SAFETY_MIN), forbiddenWindows (sunrise −15/+20, zawal −10/+5, sunset −15/+5). VERIFIED against independent NOAA calc (Dhaka/London/Riyadh within 1 min) — output in docs/PROGRESS.md.
- src/lib/calendars.ts: toBn (Bengali digits), dateKey/addDays/parseKey, Bangla calendar (2019 reform, Boishakh 1 = Apr 14, Falgun 30 iff leap), Hijri via Intl islamic-umalqura + Kuwaiti arithmetic fallback + ±adjust, isAyyamBeez (13–15), formatTimeBn (ভোর/সকাল/দুপুর/বিকাল/সন্ধ্যা/রাত periods).
- src/lib/qibla.ts (bearing+distance+compass label bn), src/lib/cities.ts (64 BD districts + 18 intl), src/lib/i18n.ts (bn/en/ar strings + translate), src/lib/search.ts (Bengali fuzzy bigram+word scoring = Meilisearch stand-in), src/lib/content.ts (typed pack loader via dynamic import — packs: duas, adhkar, names99, islamicNames, imanBranches, sunnahs, articles, courses, quizzes, mosques, faq; placeholders exist in content/).
- src/lib/store.ts: zustand+persist — nav(tab,view,params)/back()/navHistory, adminOpen overlay flag, user+authChecked+authModal, persisted guest profile (name/gender/lang/city/lat/lng/method/madhhab/onboardingDone), amalCache+outbox (offline-first), writeEntry → debounced batched POST /api/amal/entries, hydrateFromServer, online/offline listeners, currentPrayerConfig(). referralCode capture.
- src/lib/api.ts: typed client for every endpoint (auth, me, config, amal, dawah, usrah, reviews, assessments, admin, join, reminders, live, masala, feedback, enroll, quiz-attempt, quran).
- src/lib/server/auth.ts: sessions (HttpOnly cookie sl_session, 30d), toDomainUser, requireUser/requireRole, audit(); src/lib/server/guard.ts: assertCanAccess (RLS chokepoint: full_admin always; else same gender AND self/own-usrah/downline/invigilator), isSupervisor, assertFullAdmin, json/errorResponse helpers; src/lib/server/quran.ts: cached Qur'an loader.
- API routes done: auth/otp/request (mock SMS, rate-limited 3/10min), auth/otp/verify (creates user + referral closure + guest amal merge with clientUpdatedAt conflict resolution), auth/logout, me (GET/PATCH allowlist), config (AppConfig), join (?code → inviter name), reminders (GET/PATCH), quran/surahs, quran/surah/[number] (Bismillah word-strip for surahs ≠1,9 — VERIFIED). All tested via curl — see PROGRESS.md.
- App shell: src/app/page.tsx (hydration splash → onboarding gate → AppShell, ?join= capture), components/app/{providers,logo,onboarding,auth-modal,shell}. Onboarding: 3 steps (language / name+gender with female-privacy trust note / city picker sheet+GPS+madhhab+method). AuthModal: OTP flow (auto-filled devCode) + 5 demo quick-login buttons. Shell: sticky header (logo, desktop tabs, sync badge, bell sheet, theme toggle, profile dropdown with admin entry), mobile fixed bottom nav (5 tabs, spring pill), offline banner, AdminConsole overlay stub.
- Public assets: manifest.webmanifest, icon.svg (8-point star + dome), PWA metadata.
- bun run lint: 0 issues. GET / → 200. All foundation APIs curl-tested.

Stage Summary:
- Foundation COMPLETE. App skeleton runs at / with onboarding + shell + auth.
- Demo phones reserved (content agent must seed exactly these):
  01000000001 full_admin M "আব্দুল্লাহ আল মামুন"
  01000000002 invigilator M "হাফেজ যাকারিয়া"
  01000000003 usrah_head M "মাওলানা ইউসুফ" (head of উসরা আল-ফুরকান, M)
  01000000004 daee M "রাফিউল ইসলাম" DS-000004, level muhibbus_sunnah
  01000000005 usrah_head F "উম্মে হাবিবা" (head of উসরা আয়েশা সিদ্দিকা, F)
  01000000006 daee F "মারিয়াম হাসান" DS-000006, level muhibbus_sunnah
  01000000007 user M "তানভীর হোসেন"
  Plus ~8 usrah members (01000000008–01000000015, mixed M/F across the two usrahs) with 30 days of seeded amal history.
- Content pack placeholder files exist in content/ (agents overwrite them).
- View stubs at src/components/{home,amal,dawah,ilm,more}/… and admin/console.tsx are REPLACED by their owning agents.

Template for new sections:
---
Task ID: <id>
Agent: <agent name>
Task: <task>
Work Log:
- <steps>
Stage Summary:
- <results / decisions / artifacts>

---
Task ID: 2-b
Agent: backend-api (main session)
Task: All remaining API routes — amal diary engine (locking rule), goals, dawah engine, usrah, weekly reviews + assessments, full admin console backend, engagement (live/masala/feedback/enroll/quiz) + shared server helpers (amal/reviews/levels).

Work Log:
- Read worklog + API_CONTRACTS + domain types + auth/guard + schema + api.ts. Implemented 22 route files + 3 helper files; all responses type-matched to src/types/domain.ts (ISO dates, parsed JSON fields, cast enums).
- Helpers created:
  - src/lib/server/amal.ts: mapDefinition/mapEntry mappers; 30s TTL cache for active AmalDefinitions (invalidateDefinitionCache used by amal-catalog); Dhaka wall-clock helpers (bdToday/bdNowShifted — server TZ independent, server runs UTC); computeLockDeadline/isDateLocked implementing the Ishraq-of-D+1 rule via computePrayerTimes (user lat/lng or Dhaka 23.8103/90.4125, tz +6, user calcMethod/madhhab); amalPoints (tristate jamaat/alone=1, qaza=0; boolean; count/quantity >=target else 0.5 partial; target lookup by user category w/ "general" fallback); completionPctFromEntries + completion7dForUsers (batch, 1 query) + completion7d; ownUsrahIds.
  - src/lib/server/reviews.ts: weekStartOf (Saturday), weekDays, computeWeekSummary (overallPct/byCategory/streak≥50%/missedDays/counts over weekStart..+6; only elapsed days ≤ Dhaka-today count toward expectations so a running week isn't punished), mapReview.
  - src/lib/server/levels.ts: loadLevelRules (fs + 60s cache, accepts flat / {muhibbus_sunnah} / {levels.muhibbus_sunnah} shapes; checklist items accepted as strings OR {key,label} objects — matches the real content/level-rules.json the content agent landed mid-task; defaults minMonths 4 / assessment true / referrals 5); monthsInLevelOf (30.44-day months); computeRequirements (min_months / assessment_passed / min_referrals + informational checklist items, done=false); nextLevelOf ladder.
- Routes implemented (all with Bengali ApiError messages, json()/errorResponse() from guard):
  - amal/definitions GET (public — guests keep a local diary): active defs, sortOrder, targetJson→target parsed.
  - amal/entries GET (from/to + optional userId via assertCanAccess) & POST batch sync (≤500): future dates → "ভবিষ্যতের তারিখ"; locked days → "লক হয়ে গেছে — উসরা প্রধানের অনুমতি দরকার" (DayUnlock override honored); unknown key → "অজানা আমল"; conflict rule existing.clientUpdatedAt >= incoming → "নতুন সংস্করণ আছে"; returns HTTP 200 {accepted, rejected} per-entry (store.ts flush contract — 423 was NOT used, deliberate deviation from older contracts doc text); touches lastActiveAt.
  - amal/unlock POST: usrah_head+ + assertCanAccess; DayUnlock upsert + audit "unlock_day".
  - goals GET/POST/DELETE: own PersonalGoals, max 14 active → "সর্বোচ্চ ১৪টি লক্ষ্য". NOTE: no domain type exists for PersonalGoal — response shape is the DB row mapped (id, amalKey, title, note, target, startDate, active, createdAt ISO); api.ts has no goals methods (frontend fetches directly) — flagged for integrator.
  - dawah GET: daee+ only (403 otherwise); memberCode, referralLink https://sunnahlife.app/?join=…, invitedCount, downline depth 1..3 (manual join via ReferralClosure — no FK relation in schema), level/monthsInLevel, requirements, nextLevel (ladder: none→muhibbus→farze_ain_1→farze_ain_2), assessment summaries w/ scorePct.
  - usrah GET: own usrah + members w/ completion7d + headName + usrah-scoped announcements (pinned first) w/ authorName; {usrah:null, announcements:[]} when none.
  - reviews GET (self w/ reviewerName) / ?scope=queue (head: own-usrah users; invigilator: own gender; full_admin: role daee+usrah_head): lazily creates this Saturday-week's pending reviews (pre-check + createMany, race tolerated — SQLite Prisma has NO skipDuplicates), marks >7d-old pending overdue, returns queue w/ joined user (name/memberCode/level/completion7d); POST (supervisor + guard): computes summary server-side, upserts → done + completedAt, creates member Reminder (kind review, title "সাপ্তাহিক রিভিউ সম্পন্ন হয়েছে", body=first 100 chars), rating validated 1..5.
  - assessments/templates GET; assessments GET ?userId (guard; default self; includes both given+received) w/ template joined + names + scorePct; POST (supervisor + guard): sanitizes scores to 0|1|2, result = "passed" iff EVERY section has strict majority (count×2 > total) of criteria ≥1, assessorSignedAt=now, member Reminder, audit "create_assessment".
  - admin/overview GET (role-scoped): head → headed/member usrahs; invigilator → own-gender usrahs; full_admin → all. Per-usrah UsrahHealth (members, reviewPct = done/(members×4) last 4 weeks capped 100, avgCompletion via completion7d batch, inactiveCount >3d); totals; recentAudit last 15 (full_admin: all, others: own actions only) w/ actorName.
  - admin/users GET ?q= (name/phone/memberCode contains; full_admin all, invigilator own gender, head own-usrah members; usrahName joined) + PATCH (full_admin): role/gender/usrahId/category; audits "change_role"/"change_gender" w/ old→new; role→daee auto-assigns next memberCode (max DS-NNNNNN + 1).
  - admin/month-grid GET ?userId&month: guard-checked; days 1..EOM, all active definitions, rows keyed by amalKey w/ cells (value parsed, source "none" when absent).
  - admin/promote POST (full_admin): validates computeRequirements for muhibbus_sunnah target → 422 "চাহিদা পূরণ হয়নি: <labels>" if unmet (farze levels promote directly — no rules defined); updates level+levelStartedAt, LevelTransition w/ evidence snapshot, audit "promote_level", user Reminder "আপনি নতুন স্তরে উন্নীত হয়েছেন".
  - admin/broadcast POST (usrah_head+): Announcement + Reminder fan-out; scoping enforced (head → own usrahs only; invigilator → own-gender usrah/users; global fan-out full_admin only) + audit "broadcast".
  - admin/amal-catalog POST (full_admin): upsert by key (accepts `target` object or raw `targetJson`), full field validation, invalidates cache, returns all active definitions.
  - admin/audit GET (full_admin): last 100, actorName joined, metaJson parsed.
  - live GET (public): F programs visible ONLY to signed-in F users (guests/M see only general M programs); order live→upcoming→past (past newest-first); status = seeded "live" honored else computed from startsAt/endsAt (+2h fallback). POST {id}: requireUser, gender-checked, dedup Reminder w/ scheduledAt=program.startsAt.
  - masala POST (guest ok, links userId when signed in); feedback POST (guest ok); enroll POST/PATCH (upsert + progressJson string); quiz-attempt POST (requireUser — 401 for guests, client stores locally).
- CURL VERIFICATION (dev server, full OTP sign-in flow; used throwaway 017xxx users because the content agent's seed had NOT landed yet — the 0100xxxxxxx demo phones weren't in the DB; role/gender/usrah structure mirrored the reserved demo set; ALL test data was torn down afterwards, DB back to 0 rows):
  - definitions (guest) → 5 defs, target parsed; entries POST: today accepted, future → "ভবিষ্যতের তারিখ", 5-days-ago → lock reason, re-POST older clientUpdatedAt → "নতুন সংস্করণ আছে", unknown key → "অজানা আমল"; GET range returns parsed entries.
  - unlock: head3 unlocks own member ✓; head5 (F) → 403 "বিপরীত লিঙ্গের তথ্য দেখার অনুমতি নেই"; member re-posts unlocked day → accepted.
  - dawah (daee): memberCode DS-000004, link, invitedCount 2, downline 3 (depth 1,1,2), monthsInLevel 5, requirements [months ✓, assessment ✓, referrals 2/5 ✗], nextLevel farze_ain_1, assessment scorePct 88; plain user → 403. Verified again after content agent landed level-rules.json: 6 checklist items render with keys checklist_iman/ibadat/ilm/akhlaq/sifat/tyag.
  - usrah: member sees usrah+members (completion7d 57% — hand-verified against seeded entries) ; no-usrah user → {usrah:null}.
  - reviews: queue lazy-creates pending (Sat weekStart 2026-09-26); head POST → done + auto-summary (overallPct 25 = 2pts/(4defs×2 elapsed days) — hand-verified, streak/missedDays/byCategory correct); member sees done review w/ reviewerName; queue doesn't re-create done weeks; >7d-old pending → overdue; plain user queue → 403.
  - assessments: templates parsed; POST all-2s → passed (scorePct 88); one failed section → not_yet (50); cross-gender assessor → 403; GET ?userId joins template+names.
  - admin/overview: head → own usrah (reviewPct 13, avgCompletion 29, own audit only); head5 → F usrah only; plain user → 403.
  - admin/users: head search scoped to own usrah; full_admin sees 9; PATCH role→daee auto-assigns DS-900010, category/usrahId/gender updates + audits (change_role, change_gender visible in /admin/audit); head PATCH → 403.
  - month-grid: 30 days × 5 rows w/ values; GENDER ISOLATION head3 (M) → F member = 403 (exact scenario requested); head5 (F) → own F member 200.
  - promote: unmet requirements → 422 with Bengali missing list; daee→farze_ain_1 → 200 + LevelTransition + reminder; head → 403.
  - broadcast: head→own usrah ✓, foreign usrah → 403, global non-admin → 403, global admin ✓; announcement visible in member's /api/usrah; reminders fan-out confirmed via /api/reminders.
  - amal-catalog: upsert new + update target object (returned catalog reflects both); head → 403. audit: last entries w/ actorName + parsed meta; non-admin → 403.
  - live: guest → 3 programs (no F), F user → 4 (F session visible), M user → 3; live-first ordering; notify: guest 401, M ok, dedup ok, M on F program → 403 "এই সেশনটি শুধু বোনদের জন্য".
  - masala/feedback guests ok + validation 400s; enroll POST/PATCH ok, guest 401; quiz-attempt ok / guest 401; goals CRUD + 14-limit ("সর্বোচ্চ ১৪টি লক্ষ্য") + invalid date 400.
  - bun run lint: 0 issues (run twice, before and after final edits). dev.log: no compile errors, no 500s from my routes.

Stage Summary:
- ALL contracted endpoints from src/lib/api.ts are implemented and curl-verified end-to-end; business logic 100% server-side; frontend stays dumb.
- Deviations/decisions (integrator please note):
  1) amal/entries POST returns HTTP 200 with per-entry rejected[] (NOT 423) — matches store.ts flush handling + task spec; older API_CONTRACTS wording superseded.
  2) nextLevel ladder extends spec: farze_ain_1→farze_ain_2, farze_ain_2 terminal (spec only defined none→muhibbus→farze_ain_1).
  3) /api/goals has no domain type & no api.ts client method — response shapes: GET {goals:GoalItem[]}, POST {goal}, DELETE ?id → {ok}. GoalItem = {id,amalKey,title,note,target,startDate,active,createdAt}.
  4) reviews queue target sets: head → all own-usrah members (excl. self); invigilator → all own-gender users; full_admin → role ∈ {daee, usrah_head} (excl. self).
  5) Requirements validation on promote only applies to toLevel=muhibbus_sunnah (level-rules.json defines no farze thresholds).
  6) BUG FOUND in lead's route (not mine to fix): src/app/api/auth/otp/verify/route.ts uses createMany({skipDuplicates:true}) — Prisma+SQLite rejects `skipDuplicates` at runtime (verified), so guest amal merge would 500 whenever guestEntries are sent. Suggest replacing with per-entry upserts or try/catch. My own routes never use skipDuplicates.
  7) completion7d/review summaries use daily-cadence definitions only; a running week's summary counts only elapsed days (≤ Dhaka today).
  8) Demo phones 0100xxxxxxx were not seeded yet at test time → verification used role/gender-matched 017xxx throwaways (full OTP flow), 100% removed afterwards (DB counts: 0 users/usrahs/defs/entries/…). Integrator should re-smoke-test against the real seed once 2-a lands it (same code paths: lock dates are relative to "today", so they'll behave identically).
---
Task ID: 3
Agent: lead-architect (main session, round 2)
Task: Mandated-stack environment bring-up + seed repair + monorepo scaffolding + design-tokens package (user rejected the earlier web-only adaptation; full stack now enforced).

Work Log:
- Rewrote docs/PLAN.md for the MANDATED architecture (Flutter/NestJS/PG16+RLS/Redis+BullMQ/MinIO/Meili/admin/monorepo) with a sandbox-execution matrix.
- Installed (user-level, no root): Flutter 3.47.5 (ranged-parallel download workaround for stalled storage.googleapis.com — script /home/z/opt/parallel-dl.sh), Android SDK 36 (cmdline-tools 13114758 + platform-tools + build-tools; licenses accepted; flutter doctor Android ✓), PostgreSQL 16.10 portable (:5433, RUNNING, data /home/z/opt/pgdata), Redis 7.0.15 via dpkg-deb extraction + liblzf1 (:6380, RUNNING), Meilisearch 1.54 (:7700, RUNNING). All documented in docs/ENVIRONMENT.md. MinIO: dl.min.io serves 410 here → code-only (compose + S3 module). Docker impossible without root → compose/Dockerfiles code-only.
- DB WAS EMPTY (content agent's seed never landed) → wrote prisma/seed.ts (idempotent): 15 users (the reserved 0100xxxxxxx demo phones, all roles, M+F), 2 usrahs (আল-ফুরকান M / আয়েশা সিদ্দিকা F), 20 referral-closure rows, 6901 deterministic amal entries over 30 days (tristate/boolean/count/quantity; cadence-aware incl. ayyam_beez via Hijri; auto: sources ~45%), 10 done weekly reviews with real computed summaries, 3 assessments (2 passed incl. signed, 1 not_yet with failed akhlaq), level transitions + audit log, 4 live programs (1 live now, 1 F-only), announcements, reminders, personal goals, demo DayUnlock. `bun run db:seed`.
- Fixed agent 2-b's flagged bug: auth/otp/verify used createMany skipDuplicates (SQLite runtime error) → per-entry upsert with clientUpdatedAt latest-wins conflict rule.
- Monorepo scaffolding: pnpm-workspace.yaml (root=web + apps/* + packages/*), turbo.json, content/package.json (@sunnahlife/content) + packages/content symlink, .gitignore, eslint ignores scoped to web app only.
- packages/design-tokens: tokens.json (single source: brand/light/dark palettes exact from globals.css, radii 8/12/16, 8-pt spacing, bn type scale, motion 120/200/320, tap target 44) + build.mjs → dist/tailwind.css + dist/flutter/design_tokens.dart (complete ThemeData builders light/dark, GoogleFonts, SLElevation, SLType.quran/dua) + --check parity guard (verified in sync with globals.css). PACKAGE READY FOR FLUTTER AGENT.
- packages/shared-types: left for the API agent to generate from OpenAPI.

Stage Summary:
- Toolchain RUNNING: PG16 :5433 (postgres/trust), Redis :6380, Meili :7700. Start script: /home/z/opt/start-services.sh. All survive across sessions (daemonized).
- Web app verified alive after scaffolding: GET / 200, quran 114 surahs, defs 200.
- Subagent briefs issued next: 3-a Flutter app (apps/mobile), 3-b NestJS API+worker (apps/api, apps/worker), 3-d infra+docs; 3-c admin panel queued after 3-b.
- Disk ~2.2GB free — gradle -Xmx1536m, clean caches when possible.
---
Task ID: 3-a-1
Agent: flutter-scaffold (subagent F1, chunk 1 of 3)
Task: Flutter app skeleton + core (apps/mobile): project, deps, design tokens, content packs, core engines (calendars/prayer/cities/digits), models, Drift DB, API client, providers, 5-tab shell, tests.

Work Log:
- Found a partially-built apps/mobile from an interrupted prior run (no worklog entry): real feature screens, state, services, l10n, core engines, gradle config and 6 test files existed and analyzed clean, but with gaps vs the chunk-1 spec. COMPLETED rather than recreated (everything below verified green).
- Project: org bd.asunnah.sunnah_life, platforms android+ios. pubspec has the full mandated stack (flutter_riverpod 2.6, go_router 14, drift 2.24 + sqlite3_flutter_libs, adhan_dart 1.0.11, hijri 3.0, flutter_local_notifications 18, google_fonts 6.2, shared_preferences, http, intl, path_provider, path; dev: flutter_test, flutter_lints 6, build_runner, drift_dev). `flutter pub get` clean. android/gradle.properties: -Xmx1536m/MaxMetaspace 512m, daemon=false, + android.enableR8=true.
- design tokens: lib/design/design_tokens.dart = formatted copy of packages/design-tokens/dist/flutter/design_tokens.dart (SLColors/SLSpacing/SLRadius/SLMotion/SLElevation/SLType, buildSunnahLightTheme/DarkTheme; bundled TTFs in assets/google_fonts, allowRuntimeFetching=false in main).
- Content: assets/content/ refreshed from repo content/ (12 packs incl. quran-uthmani 2.1MB + quran-bn 2.9MB; faq/mosques/quizzes/quran-meta still placeholder `{}` in the repo — app has in-code fallbacks).
- NEW lib/api/fallback_catalog.dart: 15 const Dart records (key/titleBn/titleEn/category/inputType/cadence/sortOrder/target/unit/autoSource) mirroring amal-catalog.json salat_fajr…dua_private_10min EXACTLY + fallbackDefinitions() → AmalDefinition list. Replaced the looser 12-entry kFallbackAmalCatalog in content_models.dart (call sites + month-grid test updated).
- lib/core (pure Dart, no Flutter): bn_digits (toBn ০-৯), calendars (Bangla 2019-reform, hijri pkg + Kuwaiti fallback, hijriDate(adjustDays), isAyyamBeez 13–15, formatTimeBn, dateKey/parseKey/addDays in date_keys.dart), prayer_engine (adhan_dart wrapper: fajr…isha minutes-from-midnight + tahajjud/ishraq+20/duha ¼, maghrib+3 BD safety, forbiddenWindows sunrise −15/+20 · zawal −10/+5 · sunset −15/+5), cities (64 BD + 18 intl const), qibla, amal_engine (locking rule, points, cadence), sync_merge (mergeEntry/mergeLists — latest clientUpdatedAt wins, tie → remote).
- lib/l10n/app_strings.dart: S.tr + full bn/en/ar table (completeness enforced by test/widget_test.dart); Lang/LangX + context extension.
- lib/models: SPLIT per spec into user.dart (User, Role/Gender/Level/UserCategory/Madhhab/CalcMethod + Json extensions + labelBn + rank), amal.dart, dawah.dart, review.dart (WeeklyReview + WeekSummary), assessment.dart (+ NEW AssessmentCriterion/Section/Template/Score/Detail — weren't in the prior code), usrah.dart, live.dart; models/domain.dart is now a barrel so ALL existing imports keep working. Typed fromJson everywhere, no Map sprawl.
- lib/db: Drift AppDatabase (implementation database.dart + generated database.g.dart; spec-path alias app_db.dart). Tables: AmalEntries (natural key amalKey+date, valueJson, source, clientUpdatedAt, synced), Outbox (one pending op per amalKey+date), GuestProfiles (single row: name/gender/language/city/lat/lng/tz/method/madhhab/category/themeMode/hijriAdjust/onboardingDone), SettingsTable KV, LastRead, AyahBookmarks. DAOs: writeEntry/upsert (tx: entry+outbox), entry, entriesForDates, entriesBetween, pendingEntries(≤500), markSynced, pendingSyncCount, mergeServerEntries (uses sync_merge), guestProfile/saveGuestProfile, setting/setSetting, lastReadEntry/saveLastRead, bookmarks/toggleBookmark. build_runner output already generated (schema untouched this round).
- lib/api/api_client.dart: baseUrl from --dart-define=SUNNAH_API_BASE (default https://sunnahlife.app), Bearer token; typed methods per src/lib/api.ts: requestOtp→devCode, verifyOtp(phone,code,name,gender,referredByCode,guestEntries)→{user,token}, me, updateMe, config, amalDefinitions/amalEntries/amalUpsert→{accepted,rejected}, amalUnlock, dawahOverview, usrah, reviews, reminders, live, masala, feedback, quranSurahs. NEW: any 401 → token cleared + onUnauthorized hook → AuthNotifier.forceSignOut() (wired in providers; no network round-trip).
- State: lib/state/providers.dart (dbProvider, apiProvider, ProfileState/ProfileNotifier persisted via Drift guest row + best-effort PATCH /me; AuthNotifier session in SharedPreferences), amal_state.dart (definitions API-else-fallback, optimistic AmalNotifier with lock rule + debounced flush; SyncNotifier outbox flush) + remote_state.dart (config/dawah/usrah/reviews/live). Spec-path aliases: lib/providers/settings_provider.dart + lib/providers/sync_provider.dart (documented re-exports).
- NEW sync scheduling: SyncNotifier.startPeriodicFlush() — 60s Timer.periodic started once from bootstrapProvider (kept OUT of build so widget tests stay timer-clean; ref.onDispose cancels). Attempt = connectivity probe (ApiException → lastMessage, retries next tick). Manual flush exists via SyncBadge.
- lib/app.dart: ProviderScope → BootstrapGate (splash) → MaterialApp.router (token themes, locale bn/en/ar + RTL for ar, themeMode from profile). go_router StatefulShellRoute.indexedStack, 5 branches (/, /amal +month|habit|self-test, /dawah, /ilm +8 subroutes, /more +7 subroutes), onboarding/auth routes with redirect. NEW: Da'wah branch HIDDEN for role < daee — bottom nav renders 4 destinations with tab↔branch index mapping + router redirect /dawah → / for non-qualified (screen + provider also gate). Spec-path aliases: lib/screens/{home,amal,dawah,ilm,more}_screen.dart re-export the real feature screens (which are full implementations, not placeholders — home/amal/dawah/ilm/more all built with content packs, quran reader, month heatmap, habit builder, self-test, zakat, qibla, mosques, live, masala, profile).
- test/: NEW smoke_test.dart (boots the REAL app through BootstrapGate with in-memory Drift: daee override → 5 tabs হোম/আমল/দাওয়াত/ইলম/আরও; guest → 4 tabs, দাওয়াত hidden; containers disposed in-body so no pending timers). Pre-existing tests fixed for the new fallback catalog (15 defs): amal_logic, month_grid (31×15 cells), prayer_snapshots, sync_conflict, today_diary, l10n completeness.
- `flutter analyze`: No issues found. `flutter test`: All 38 tests passed.

Stage Summary:
- DONE: chunk-1 skeleton complete and green (analyze 0, tests 38/38) on top of the interrupted prior run — verify-first policy: what existed was audited against the spec, gaps closed, nothing thrown away.
- Layout map for F2/F3: screens/features (NOT bare placeholders): lib/features/{home,amal,dawah,ilm,more,auth,onboarding,shared}/*; spec-path aliases in lib/screens/. State: lib/state/{providers,amal_state,remote_state,prayer_state}.dart (+ aliases in lib/providers/). Models: lib/models/{user,amal,dawah,review,assessment,usrah,live,content_models,quran_models}.dart, barrel domain.dart. DB: lib/db/database.dart (alias app_db.dart). API: lib/api/{api_client,fallback_catalog}.dart. Core: lib/core/*. l10n: lib/l10n/app_strings.dart (S.tr / context.t — ADD NEW KEYS THERE, table completeness is test-enforced).
- Notes: 60s sync flush starts in bootstrapProvider (startPeriodicFlush); guests are local-only (flush no-ops); auth token in SharedPreferences 'sl_token', cleared on 401; Dart define SUNNAH_API_BASE for the API. Demo phones for sign-in flow tests: see Task ID 3 section of this worklog.
- Not done (intentionally): no gradle build attempted (disk-rationed sandbox; analyze+tests green), FCM/push remains a seam (PushAdapter), quran-meta-bn.json still a placeholder upstream.
---
Task ID: 3-d
Agent: infra-docs-ci (subagent D2)
Task: Audit the interrupted infra/ deliverable (compose, 4 Dockerfiles + .dockerignores, postgres/ RLS bootstrap, up.sh), write/verify the docs set (README, DATA_MODEL, DEPLOY_COOLIFY, DEMO_ACCOUNTS, DESIGN_SYSTEM, .env.example) and the CI pipeline (.github/workflows/ci.yml).

Work Log:
- AUDIT (read every infra file + the sources of truth: apps/api/src/config/env.validation.ts, main.ts, health/queues/content controllers, prisma seed + both RLS/init SQL files, root + api package.json, tokens.json, both prisma schemas, root .dockerignore):
  * env-var names cross-checked against what apps/api ACTUALLY reads (DATABASE_URL, DIRECT_URL, REDIS_URL, MEILI_HOST, MEILI_KEY, S3_ENDPOINT/BUCKET/ACCESS_KEY/SECRET_KEY/PUBLIC_BASE, JWT_SECRET, JWT_REFRESH_SECRET [read by auth.service as optional refresh-secret fallback to JWT_SECRET], ACCESS_TOKEN_TTL_MIN, REFRESH_TOKEN_TTL_DAYS, PORT, CORS_ORIGINS, APP_DOMAIN, SMS_PROVIDER + SMS_SSLWIRELESS_* + SMS_INFOBIP_*, CONTENT_DIR, STORAGE_DIR). Compose now matches 1:1 (JWT_REFRESH_SECRET added to api+worker; no phantom vars).
- INFRA FIXES (all in infra/ + root dotfiles — src/apps/prisma/content untouched):
  1. docker-compose.yml — api PORT was `${API_PORT:-4000}` while the port mapping pinned the container side to 4000: overriding API_PORT made the app listen on a port nothing mapped/probed. PORT is now pinned to 4000 inside the container (API_PORT = host side only); compose healthcheck simplified to `curl :4000/health`.
  2. docker-compose.yml — worker had NO healthcheck → inherited the api image's HTTP probe and would read permanently (unhealthy) (the worker serves no HTTP). Added an override: PID-1 alive + live Redis PING via `bun -e "import('ioredis')…"` (the exact one-liner was live-tested against the sandbox Redis: PONG, exit 0).
  3. docker-compose.yml + api.Dockerfile — CRITICAL: the api image was built from context `apps/api` only, but the entrypoint seed reads `packages/content/amal-catalog.json` + `assessment-farze-ain-v1.json` and the content routes serve the Qur'an/packs from `contentDir()`; in the image both resolve to `/packages/content` (absent) → empty DB, dead /api/content routes. Build context is now the REPO ROOT for api + worker; Dockerfile COPYs `apps/api/…` and `content → /app/packages/content` (real dir, not the packages/content symlink — a copied symlink would dangle) with `ENV CONTENT_DIR=/app/packages/content`. api.Dockerfile.dockerignore rewritten for the root context (keeps apps/api + content; excludes node_modules/.next/apps-mobile/admin/.git/.env/db/dumps/…).
  4. .dockerignore (root) + infra/web.Dockerfile.dockerignore — SECRET LEAK: neither excluded `.env`, so `COPY . .` baked the repo-root .env (POSTGRES/JWT/MinIO secrets) into the web image. Both now exclude `.env`/`.env.*` (re-include `.env.example`); NEXT_PUBLIC_* still arrive via build ARGs.
  5. postgres/init-rls.sql — `GRANT CONNECT ON DATABASE sunnahlife` + `ALTER DEFAULT PRIVILEGES FOR ROLE postgres` hardcoded names; now `GRANT … ON DATABASE current_database() \gexec` + bare `ALTER DEFAULT PRIVILEGES IN SCHEMA public` (applies to POSTGRES_USER whoever it is). Still fully idempotent (\gexec + DO $$ blocks). DRY-RUN VERIFIED against the sandbox PG16: ran twice on a scratch DB with ON_ERROR_STOP (pass 1 + replay both exit 0; role NOBYPASSRLS confirmed via pg_roles). NOTE: the api's own RLS migration hardcodes `GRANT … ON DATABASE sunnahlife` → documented everywhere: keep POSTGRES_DB=sunnahlife.
  6. worker.Dockerfile — added the missing HEALTHCHECK (`kill -0 1` liveness — no HTTP in a worker) + updated the drop-in instructions for the repo-root-context pattern.
  7. .env.example — added optional `JWT_REFRESH_SECRET` (empty ⇒ JWT_SECRET), POSTGRES_DB keep-`sunnahlife` warning.
- CI (.github/workflows/ci.yml — existed from the interrupted run, audited + fixed):
  * env bug: `JWT_ACCESS_SECRET`/`JWT_REFRESH_SECRET` were set but apps/api reads `JWT_SECRET` (refresh falls back) → now `JWT_SECRET` + `SMS_PROVIDER=mock`.
  * DB name bug: service used `sunnahlife_test` but the RLS migration hardcodes `GRANT … ON DATABASE sunnahlife` → migrate:deploy would fail → POSTGRES_DB/healthcheck/URLs all `sunnahlife`.
  * MISSING SEED: the RLS e2e (test/rls.e2e-spec.ts — landed by 3-b mid-task) signs in as the demo phones → added `bun run seed` (idempotent, DIRECT_URL) after migrate:deploy.
  * removed misleading env (MEILI_HOST pointing at nothing → health would report "down"; S3_* + unread S3_FORCE_PATH_STYLE).
  * mobile job: added actions/setup-java temurin 17 (AGP 8 needs JDK 17; runner default not guaranteed).
  * jobs: tokens (build.mjs --check parity) · api (bun install, psql role bootstrap + migrate + seed, eslint, jest with postgres:16 + redis:7 services, nest build) · web (root: bun install, lint, `bun run build` — CI-only, never in the sandbox) · admin (`if: hashFiles('apps/admin/package.json') != ''`) · mobile (flutter-action@v2 stable, pub get, analyze, test, apk --debug + artifact, setup-java + gradle caches). concurrency: cancel-in-progress ✓.
- DOCS (all six existed from the interrupted run — VERIFIED against the sources and patched, not rewritten):
  * README.md — one-command starts (sandbox: bun install && db:push && db:seed && dev; VPS: cp .env.example .env && ./infra/up.sh) ✓, fixed a garbled phrase, added packages/shared-types to the repo map (now exists — 3-b generated it), stack table, demo pointer, docs index all verified.
  * docs/DATA_MODEL.md — ERD verified against apps/api/prisma/schema.prisma (22 models incl. RefreshToken; SQLite mirror 21); RLS table cross-checked line-by-line with migrations/*_rls/migration.sql → fixed the Reminder row (policy is `sl_visible_user(userId)`, not owner-only); GUCs (app.user_id/gender/usrah_id/role incl. system) ✓; Ishraq-of-D+1 locking-rule flowchart ✓; both mermaid blocks fenced ```mermaid.
  * docs/DEMO_ACCOUNTS.md — every phone/name/role/memberCode/usrah/level verified against apps/api/prisma/seed.ts (all 15 accounts, both usrahs, referral tree, 88% passed / akhlaq-failed assessments, D−3 day-unlock for 01000000008, 4 live programs incl. F-only session); OTP mock (devCode in response, auto-filled + toast in the auth modal, 5 quick-login buttons), referral link forms (?join= emitted by the api today, /join/DS-XXXX canonical), gender-visibility matrix, guest→merge, web-SQLite + api-PG duality ✓.
  * docs/DESIGN_SYSTEM.md — verified value-by-value against packages/design-tokens/tokens.json (brand/light/dark palettes, 8-pt spacing, radii 8/12/16+20/pill, type scale 16/1.6 body…quran 26/2.2, motion 120/200/320 + 3 curves, tinted elevation, tap target 44, RTL + Bengali-numeral rules, web + Flutter component inventory incl. catalog_app run command, WCAG AA).
  * docs/DEPLOY_COOLIFY.md — updated for the fixes: api/worker build contexts (repo root), JWT_REFRESH_SECRET row, POSTGRES_DB pin, worker liveness note; everything else re-checked against compose + env.validation (prereqs 2vCPU/4GB, paths A/B/C, full env var reference, Cloudflare Full-strict + websocket notes, pgBackRest off-site + MinIO mirror + cron, update procedure with `prisma migrate deploy` in the api entrypoint + idempotent seeds, /health + /metrics, STACK_TAG rollback).
  * .env.example — see fix 7.
- VERIFICATION: `python3 yaml.safe_load` OK on infra/docker-compose.yml + .github/workflows/ci.yml (services: postgres redis minio minio-init meilisearch api worker web admin proxy; jobs: tokens api web admin mobile) · `node build.mjs --check` → "✓ globals.css in sync with tokens.json (68 color values verified)" · worker healthcheck one-liner → PONG/exit 0 against sandbox redis · init-rls.sql double-run on scratch PG → clean · `cd /home/z/my-project && bun run lint` → **0 issues (exit 0)** · all docs code fences balanced, mermaid blocks fenced.
- Sandbox side-effect repaired: my init-rls.sql dry-run ALTER ROLE reset the shared sandbox `sunnah_app` password; restored from apps/api/.env and re-verified the runtime role reconnects (super=false, bypassrls=false, login ok). Scratch DB dropped.

Stage Summary:
- infra/ + CI + docs are consistent with the real code (env names, DB name, content-pack path, health endpoints). Known pending workstreams (documented, not blockers): apps/admin (3-c) — compose `admin` service + CI admin job activate on arrival (`hashFiles` guard); apps/worker (3-b in flight, dir exists) — compose worker reuses the api image and needs dist/worker.js or a start:worker script in it; if apps/worker lands as its own package, switch the compose worker to infra/worker.Dockerfile (repo-root context pattern per its header) or extend api.Dockerfile to COPY apps/worker too.
- CI turns green on GitHub as soon as the workstreams land; the api job requires the seeded demo DB (seed step included) because the RLS e2e signs in with the 0100xxxxxxx phones.
- Rollback-able ops documented end-to-end (STACK_TAG image rollback, forward-only migrations, pgBackRest restore drill).

---
Task ID: 4
Agent: lead-architect (main session, round 3)
Task: GitHub safety snapshot (user-provided repo sharif418/sunnah-life-app + PAT) — push everything BEFORE continuing, so any sandbox loss is recoverable via git pull.

Work Log:
- Sandbox shell layer crashed mid-audit (100+ failed tool calls, 403 broken session); recovered on new turn. Codebase was never lost — verified git tree clean, all work intact on disk.
- Pre-push hygiene (nothing had been pushed yet, so history amended safely):
  - Untracked `.env` (sandbox-local credentials) from the initial commit — kept locally, ignored by .gitignore. Secret never reached GitHub.
  - Dropped sandbox junk: tool-results/ persisted-output dumps (auto-committed by the crashed session), added to .gitignore.
  - Untracked apps/mobile/artifacts/app-debug.apk (79 MB build artifact; CI rebuilds APKs) — repo shrank 93 MB → 14 MB.
- Single clean commit `ef44577` "Sunnah Life — monorepo snapshot (web app, Flutter mobile, NestJS api, worker, content packs, design tokens, infra, docs)" — 445 files.
- Remote `origin` = github.com/sharif418/sunnah-life-app (PAT embedded in URL for session-long pushes). `git ls-remote` verified main = ef44577. Remote was empty pre-push (no conflicts, no force needed).
- STANDING RULE from user: push after every meaningful milestone; if the sandbox breaks again, re-clone from GitHub and continue (worklog.md + docs/PROGRESS.md are the resume points).

Stage Summary:
- SAFETY SNAPSHOT COMPLETE: entire codebase (Tasks 1, 2-b, 3, 3-a-1, 3-d) is on GitHub.
- Pending workstreams (next up): Task 3-b audit/finish (NestJS apps/api + apps/worker — partially done, RLS e2e landed mid-task), Task 3-c admin panel (compose/CI guards already waiting), Flutter chunks F2/F3 (platform channels, polish), then delivery steps 4–9.
- Remote is private (404 to anonymous HTTP) — expected.

---
Task ID: 5
Agent: lead-architect (main session, round 3)
Task: Finish + verify Task 3-b (NestJS api + worker) — unblock bun-runtime, compiled worker entrypoint, shared-types generation.

Work Log:
- Disk was 100% full (api install NoSpaceLeft) → freed 3.4 GB: .gradle/caches (2.9G), .gradle/daemon, apps/mobile/build (593M). Keep: .pub-cache, .gradle/wrapper, artifacts/app-debug.apk (build evidence).
- bun install apps/api (311 pkgs) → build exit 0 → tests 4 suites 34/34 GREEN (incl. rls.e2e.spec.ts gender-isolation proof).
- FIXED Bun-ESM runtime bug: `import { AuthedRequest, currentUser }` + emitDecoratorMetadata retained the erased interface as runtime import → strict ESM link error. All 11 controllers now `import type { AuthedRequest }`. openapi:export works again (35 paths).
- FIXED shared-types generate.ts: createRequire directory anchor (needs FILE anchor: apps/api/package.json) + wrong relative requires → "./dist/app.module.js"; openapi-typescript cwd pointed at nonexistent packages/api → now `bun x openapi-typescript` from packages/shared-types (devDep installed). Generates dist/openapi.json + dist/schema.d.ts ✓.
- CREATED apps/api/src/worker.ts (canonical compiled entrypoint; nest build → dist/worker.js; package.json start:worker script added) — satisfies infra compose worker service fallback chain (dist/worker.js found first). apps/worker stays as the bun --hot dev twin; its package.json no longer declares the unresolvable workspace:* dep.
- Lint 0 errors/0 warnings (removed 7 unused imports: seed BN_DIGITS, admin IsUUID/Matches, amal Param, content Query, rls-raw UseGuards, prayer-times Madhhab).
- BOOT VERIFIED (both processes, sandbox services): api :3001 /health → postgres+redis+meilisearch+storage all true; POST /api/auth/otp/request → devCode; GET /api/config → live JSON. Worker → 4 repeatable schedulers registered, delayed jobs enqueued, waiting for jobs.
- Boot artifacts left RUNNING in background: api (node dist/main.js, log /tmp/api.log), worker (node dist/worker.js, log /tmp/worker.log).

Stage Summary:
- TASK 3-b COMPLETE AND VERIFIED. Pushed as d7c77e3 with PROGRESS.md update.
- Next: Task 3-c admin panel (apps/admin) — compose/CI hashFiles guards already await it; then Flutter F2/F3 (platform channels, polish) and delivery-order steps 4–9.
- Disk discipline: keep an eye on df; gradle caches will rebuild on next android build (~3G) — clean again after.

---
Task ID: 6
Agent: lead-architect (main session, round 4)
Task: Recover + verify Task 3-c (Tarbiyah admin panel, apps/admin) which the crashed session auto-committed with a UUID message and 9 TypeScript errors; then push milestone to GitHub per user's standing rule.

Work Log:
- Tools recovered this round. Found main ahead 1: commit e3befda (UUID message) containing the FULL admin panel (49 files, 8726 insertions) — Task 3-c work from the crashed session.
- Verified no PAT leak in tool-results/ (grep clean). `.env` still untracked — good.
- Ran verification: lint 0, but `tsc --noEmit` failed with 9 errors.
- FIXED all 9: (1) members/[id] UnlockDialog missing useMutation/useToast/useQueryClient imports; (2) exports monthGrid destructuring `res.user.name` — response is `{ grid }`, now resolves selected user name from users list; (3) month-grid `const toast = useToast()` → destructure `{ toast }`; (4) roleRank/isSupervisor/isFullAdmin widened to `string` (RoleGate `allow` passes plain strings; unknown role → rank -1).
- Re-verified: lint 0 · typecheck 0 · `next build` 15 routes ✓ · runtime smoke: admin :3002 /login → 200 with Bengali title, / → 200; api :3001 /health all green.
- INCIDENT + FIX: my pkill for the leftover admin server also killed the main dev server's next-server worker (port 3000 dead). Restarted `bun run dev` in background — / → 200 again. Lesson: never pkill "next-server" blindly; root app's dev worker matches it too.
- Hygiene: `git rm -r --cached tool-results/` (gitignore line 83 already covers; files remain on disk, untracked now).
- Amended e3befda with proper message + fixes + PROGRESS.md Task 3-c section, then pushed to origin.

Stage Summary:
- TASK 3-c COMPLETE AND VERIFIED. Admin panel on GitHub as "admin: Tarbiyah admin panel — 15 pages (Task 3-c)".
- Milestone-push rule honored: 3-b snapshot pushed earlier (f047738); 3-c pushed now.
- Next: Flutter chunks F2/F3 (platform channels — exact alarms, local notifications, home widget; then amal/polish), then Master Prompt delivery steps 4–9. Disk at 79% (2.0G free) — watch for gradle cache rebuilds.

---
Task ID: 7
Agent: lead-architect (main session, round 4)
Task: Recover the wiped Flutter SDK (sandbox lost /home/z/opt/flutter between sessions) and verify the mobile app (analyze + tests) — Task F2 closeout.

Work Log:
- DISCOVERED: sandbox cleanup deleted /home/z/opt/flutter (SDK) but KEPT: ~/.pub-cache, ~/.gradle/wrapper, /home/z/android-sdk (SDK 36), and apps/mobile/artifacts. Same class of loss the user feared — this time only toolchain, no source (git is the safety net now).
- Reinstall attempts: streaming tar.xz extraction hit sandbox limits twice (detached processes reaped; FS slow at small files; disk filled to 100% with tarball+partial). Freed: admin .next (469M), ms-playwright cache (659M), .bun cache (215M), admin node_modules (641M), mobile artifacts/APK (80M).
- FINAL SOLUTION (works, ~free): shallow git clone of framework source — `git clone --depth 1 --branch 3.47.5 flutter/flutter` (237M) + grafted the official bin/cache (2.0G, incl. dart-sdk) from the partial tarball extraction + let the tool self-bootstrap. `flutter --version` → 3.47.5 / Dart 3.13.4 ✓ (exact match to original).
- Fixed apps/mobile/android/local.properties stale flutter.sdk → /home/z/opt/flutter (file is gitignored).
- VERIFIED: `flutter pub get` ✓ (warm pub-cache), `flutter analyze` → **No issues found** (14.8s), `flutter test` → **38/38 passed** (13s).
- APK build SKIPPED locally: .gradle caches were freed earlier (2.9G re-download won't fit in 1.2G free). CI's mobile job builds the debug APK on GitHub runners and uploads it as an artifact (7-day retention).
- CI status not readable via PAT (fine-grained token lacks actions:read) — user can check the Actions tab on GitHub.

Stage Summary:
- MOBILE (F2 platform channels) VERIFIED GREEN at Dart level. Kotlin side: MainActivity.kt (225 lines: exact alarms, DND/auto-silent, share), PrayerAlarmReceiver, PrayerWidgetProvider + widget layouts + manifest receivers all present; compiled by CI's APK build.
- Flutter SDK recovery recipe documented above (shallow clone + graft) — survives future wipes.
- Next: F3 mobile polish if needed, then Master Prompt delivery steps 4–9 (Da'wah engine, content, Learn & Live, More, launch).

---
Task ID: 8-a
Agent: general-purpose (HomeView + MoreView builder)
Task: Build the two remaining SPA tab views — HomeView (নামাজ dashboard) and MoreView (আরও hub with 8 sub-views) — replacing the placeholders, Bengali-first, guest-friendly, design-token compliant.

Work Log:
- Read worklog (Tasks 1–7) + all shared libs (store, api, domain, calendars, prayer-times, qibla, cities, content, i18n), shell.tsx, onboarding, auth-modal, and the Flutter references (home_screen.dart, more/*.dart, app_strings.dart) for behavior/wording parity.
- src/components/home/prayer-hooks.ts — the ONE sanctioned shared file: useNow (ticking clock, interval cleanup), usePrayerConfig (profile → PrayerConfig with city tz), usePrayerDay (day-keyed memo of computePrayerTimes + nextPrayer), formatCountdownBn (HH:MM:SS Bengali), SCHEDULE_ROWS (৫ ওয়াক্ত + সূর্যোদয়).
- HomeView: prayer-hero.tsx (city chip + live clock + গ্রেগরিয়ান/বঙ্গাব্দ/হিজরি date line — hijriAdjust from /api/config; gold "চলছে" pill; ৫xl gold countdown to next waqt; 6-row timeline with current/next highlight; ইশরাক/দুহা/তাহাজ্জুদ footnote), qibla-card.tsx (bearing + compassLabelBn + Kaaba distance, mini SVG dial, → nav("more","qibla")), amal-summary-card.tsx (public /api/amal/definitions + entries: server for signed-in with outbox-overrides, local amalCache for guests; client copy of amalPoints incl. 0.5 partial + cadence filter incl. weekly:fri/mon_thu + ayyam_beez via isAyyamBeez; SVG progress ring + per-category chips with AMAL_CATEGORY_LABELS_BN), quick-links.tsx (কুরআন/দুআ/আমল/লাইভ), city-sheet.tsx (GPS + searchable 64-district list), home-view.tsx (composition + "শহর নির্বাচন করুন" prompt when lat/lng missing).
- MoreView: more-view.tsx switches on store `view` (profile|settings|qibla|zakat|mosques|masala|contacts|about) — menu.tsx (profile card + 2-col grid, zakat gold-highlighted); bits.tsx (SubShell back-header w/ 150ms fade, SectionLabel, ErrorRetry, EmptyState); profile.tsx (signed-in: identity card role/memberCode-copy/level + editable name/district/workplace/department via api.updateMe + language + embedded prayer settings + sign-out; guest: sign-in CTA + local name/language/madhhab via updateProfile); prayer-settings.tsx (CityPicker + CALC_METHODS select + হানাফি/শাফেয়ি segments + live "আজকের সময়সূচি" preview; debounced /api/me PATCH for signed-in, also embedded in profile); qibla.tsx (SVG compass dial, DeviceOrientationEvent w/ iOS requestPermission + deviceorientationabsolute, webkitCompassHeading/alpha handling, aligned-gold-ring state, manual slider fallback + instructions); zakat.tsx (gold/silver/cash/business/debts — Bengali-digit input parsing, nisab from /api/config w/ offline fallback, 2.5% above 85g-gold nisab, hero result + breakdown + nisab progress bar + donate CTA); mosques.tsx (content pack sorted by distance + maps deep-link; defensive against empty pack); masala.tsx (form → api.masala + FAQ accordion from content pack); contacts.tsx (config contacts w/ tel/mailto/website + groups as new-tab links); about.tsx (logo, version from package.json, donation, privacy note, feedback → api.feedback).
- Fixed 2 react-hooks/use-memo errors (day-key memo), 2 no-unused-expressions warnings, 4 TS unknown errors from content.ts's broken getPack generic (cast via `as unknown as MosquesPack/FaqPack` — lib file not mine to fix).
- VERIFICATION: `bunx eslint src/components/home src/components/more` → 0 errors 0 warnings. `bunx tsc --noEmit` → 0 errors in my files (pre-existing errors elsewhere: apps/admin/** own-tsc mismatches, prisma/seed Bun types, 3 api routes, and in-flight src/components/ilm/* + dawah/* work by sibling agents). Full-project `bun run lint` fails ONLY on sibling agents' files (dawah/parts.tsx + ilm/parts.tsx "Cannot access refs during render"). Headless SSR render test (bun + react-dom/server): all 15 of my components render clean, content assertions pass (পরবর্তী ওয়াক্ত/হিজরি/নিসাব/labels), temp script removed.
- Dev server was found DEAD mid-verification (port 3000 unbound; last dev.log entry a 500 from sibling ilm agent's bad lucide import). Restarted one instance detached (`bun run dev`, now serving). GET / still 500s ONLY from sibling agents' invalid lucide-react imports — MenuBook (ilm/quran-section.tsx), FrontHand (ilm/duas-section.tsx), FactCheck (dawah/dawah-view.tsx) — none from my files (zero traces in logs).

Stage Summary:
- Files: home/{home-view,prayer-hero,qibla-card,amal-summary-card,quick-links,city-sheet,prayer-hooks}.tsx + more/{more-view,menu,bits,city-picker,prayer-settings,profile,qibla,zakat,mosques,masala,contacts,about}.tsx — 19 files, export names HomeView/MoreView preserved, shell.tsx untouched.
- Verification: eslint my folders = clean; tsc my files = clean; SSR smoke = all pass; dev server restored & running.
- Integrator to check: (1) fix sibling icons (MenuBook→BookOpen, FrontHand→HeartHandshake, FactCheck→BadgeCheck or similar) so GET / compiles; (2) content/mosques.json + content/faq.json are EMPTY packs `{}` — my views degrade to empty states, but packs need real data; (3) lib/content.ts getPack return-type is broken (TS2536/TS2322 pre-existing) — I worked around via casts, but it should be fixed at source; (4) GET /api/amal/entries requires auth (guests 401) — by design, my Home summary reads the local cache for guests; (5) lucide-react pinned at 0.525 has no Mosque icon — used Landmark; a `mosque` icon exists in newer lucide if the integrator wants to upgrade.

---
Task ID: 8-b
Agent: general-purpose (AmalView builder) — died to infra timeout after writing files; verified + integrated by lead-architect
Task: Build the Amal (Muhasaba daily diary) view — tri-state prayers, counters, auto-source badges, day locking, week strip, month heatmap, guest offline cache.

Work Log:
- Files written before agent death: amal-view.tsx (622), amal-controls.tsx (317), amal-logic.tsx (231), amal-month.tsx (256).
- Lead verification: lint 0, tsc 0 (src/), browser E2E passed — week strip (today highlighted), completion ring ০→১/২৭ after clicking জামাত, guest banner, tri-state selectors with অটো badges, localStorage amalCache natural key `2026-09-27#salat_fajr` persisted.

Stage Summary:
- AmalView functional for guests (offline-first). Signed-in sync path exercised via store outbox (batched upsert).

---
Task ID: 8-c
Agent: general-purpose (DawahView + IlmView builder) — died to infra timeout after writing files; verified + integrated by lead-architect
Task: Build DawahView (member identity, referral link, usrah, reviews, assessments) and IlmView (live, Quran reader, duas/adhkar, courses, extras).

Work Log:
- Files written before agent death: dawah-view.tsx (810), assessment-dialog.tsx (215), review-dialog.tsx (140), parts.tsx (200); ilm-view.tsx (119), quran-section.tsx (390), duas-section.tsx (282), live-section.tsx (165), courses-section.tsx (218), extras-section.tsx (348), parts.tsx (229).
- Agent left two bad lucide imports (FrontHand, FactCheck — not in lucide-react 0.525); already self-fixed by the agents late in their runs; final icon audit vs real module exports: ALL OK (5469 icons checked).
- Lead browser E2E: Ilm tabs render live programs (seeded তাফসীর মজলিস "এখন লাইভ", upcoming ঈমানের শাখা-প্রশাখা), Quran surah list + reader verified end-to-end (Uthmani + Bengali translation per ayah). Dawah view not browser-verified (guest-gated) — code review only this round.

Stage Summary:
- IlmView fully working with seeded data. DawahView compiled + linted; needs a daee-role login for full E2E (follow-up).

---
Task ID: 8
Agent: lead-architect (main session, round 4)
Task: Web app view buildout milestone — replace all 5 placeholder views with real implementations (delivery steps 4–8 for the web product), verified end-to-end in a real browser.

Work Log:
- Delegated 8-a (Home+More — completed: 19 files), 8-b (Amal), 8-c (Dawah+Ilm) — 8-b/8-c agents hit infra timeouts AFTER writing all files; integrated and verified their output myself.
- CRITICAL BUG FOUND + FIXED (the app had NEVER passed the splash in a real browser): zustand v5 persist with sync localStorage fires onRehydrateStorage's post-callback DURING create() — `useApp.setState` hit the temporal dead zone → ReferenceError swallowed by persist → hydrated stayed false forever. Fix: queueMicrotask(() => useApp.setState({ hydrated: true })). All previous "GET / 200" checks were SSR-only — browser-verified interactivity is now the standard.
- next.config.ts: allowedDevOrigins += localhost, 127.0.0.1 (Next 16 blocked _next/* cross-origin dev resources → client JS never loaded when browsing via 127.0.0.1).
- shell.tsx: Dawah tab gated to ROLE_RANK >= daee (guests/users see 4 tabs; dynamic bottom-nav columns; snap-to-home if role drops).
- src/lib/content.ts: getPack typing rewritten (PackMap interface, double-cast loaders) — fixes TS2536/TS2322 that forced `as unknown as` casts in views.
- auth/otp/verify route: capture `const created` before the createMany closure (TS closure narrowing limitation).
- domain.ts: AuditEntry.actorName → `string | null` (routes produce null).
- BROWSER E2E (agent-browser): onboarding 3 steps ✓ → Home dashboard (triple calendar গ্রেগরিয়ান·বঙ্গাব্দ·হিজরি, live countdown to আসর, 6-waqt timeline, ইশরাক/দুহা/তাহাজ্জুদ, qibla ২৭৭.৬° + ৫,১৭২ কিমি, amal summary ০/২৬ with category chips, quick links) ✓ → Amal (জামাত click → ১/২৭, localStorage persist `2026-09-27#salat_fajr`) ✓ → Ilm (live programs seeded, Quran reader: Al-Faatiha Uthmani + বাংলা অনুবাদ per ayah) ✓ → More (8 menu items) ✓ → mobile 390px: bottom nav fixed, 4 tabs, no horizontal overflow ✓. dev.log: zero errors, all APIs 200.
- Verification: bun run lint → 0/0 · bunx tsc --noEmit → 0 errors in src/ · GET / 200.

Stage Summary:
- WEB APP FULLY ALIVE END-TO-END (first true browser verification in project history). All 5 views shipped: Home (prayer dashboard), Amal (Muhasaba diary), Dawah (Tarbiyah, daee-gated), Ilm (Quran/duas/live/courses), More (profile/qibla/zakat/mosques/masala/contacts/about).
- 41 changed/new files this milestone. Follow-ups: (1) Dawah E2E needs a daee login, (2) mosques.json + faq.json packs are empty (views degrade gracefully), (3) worker scheduler not wired for web (NestJS worker covers it in prod).

---
Task ID: B1
Agent: B1 (general-purpose subagent)
Task: web→NestJS rewiring (api.ts through apiUrl + shared-types), fill engagement gaps under RLS, RolesGuard + @Roles() explicit authorization, rebuild/restart, full verification.

Work Log:
- Rewired apps/web/src/lib/api.ts (the ONLY sanctioned fetch layer): every request now goes through apiUrl() from "@/lib/api-base" (same-origin "/api/…?XTransformPort=3001" in the sandbox, absolute NEXT_PUBLIC_API_BASE in prod); credentials = "include" when API_BASE non-empty else "same-origin". Response/error envelopes verified identical to the NestJS controllers ({error: messageBn} via AllExceptionsFilter) — no view changes needed.
- NEW transparent session refresh: old mirror had a 30d cookie; NestJS uses sl_access 15 min + sl_refresh 7d HttpOnly cookies. api.ts now retries ONCE on 401 after POST /api/auth/refresh (deduped single-flight promise, 30s failure memory so guests never spam; /api/auth/* never retried).
- Typed route surface: regenerated packages/shared-types (`bun run generate` — boots the Nest app itself, no port needed; 35 paths) and api.ts imports `paths` via a type-only relative import (`…/packages/shared-types/dist/schema`) — `route()` builder compile-checks every literal against the OpenAPI surface (a renamed API route = web build error, not a runtime 404). Type-only → erased, no bundling/build step. Workspace dep deliberately NOT invented.
- apps/web/src/lib/store.ts outbox flush (the only other raw fetch) now goes through apiUrl() too. content.ts was already correct.
- CRITICAL LATENT BUG FOUND + FIXED in apps/api: ALL 5 engagement controllers (masala, feedback, enroll POST/PATCH, quiz-attempt, reminders GET/PATCH — 7 methods) declared `req: AuthedRequest` WITHOUT the `@Req()` decorator → req was undefined at runtime → every one of those routes 500'd ("Cannot read properties of undefined (reading 'user')"). They were never curl-verified as NestJS routes (2-b verified the old Next.js mirror). Added @Req() everywhere. Gateway proofs now 200/201 for all seven (guest masala/feedback included).
- Auth gaps for the cookie-only web PWA fixed in apps/api: POST /api/auth/refresh and POST /api/auth/logout now fall back to the HttpOnly sl_refresh COOKIE when the body has no refreshToken (web can't read HttpOnly cookies to echo them). RefreshDto.refreshToken made @IsOptional. readCookie() exported from auth.guard.ts. Verified: refresh with EMPTY body + cookie → 200 new tokens; logout → family revoked + me → null afterwards.
- RolesGuard + @Roles() (explicit, testable authorization; RLS stays the last line):
  - NEW apps/api/src/common/roles.decorator.ts — @Roles(...roles) via SetMetadata; semantics = ROLE RANK floor (min rank of the listed roles; reuses ROLE_RANK from src/shared/domain).
  - NEW apps/api/src/common/roles.guard.ts — Reflector-based CanActivate, runs after the global JwtAuthGuard (global guards execute before controller-scoped ones), no-op without metadata, 401 anonymous / 403 insufficient rank, Bengali messages.
  - Applied @UseGuards(RolesGuard) + @Roles:
    · admin controller (ALL routes): class-level @Roles("usrah_head") for overview/users GET/month-grid/broadcast; method-level @Roles("full_admin") for users PATCH, promote, amal-catalog, audit.
    · reviews POST → @Roles("usrah_head") (head+); amal unlock POST → @Roles("usrah_head").
    · assessments POST → @Roles("invigilator") (invigilator+; same rank-2 set as head+ per ROLE_RANK).
    · usrah management routes (create/assign) do NOT exist as endpoints — usrah assignment is admin/users PATCH (usrahId), covered by @Roles("full_admin"); no admin CRUD breadth added (B6).
  - GET /api/reviews (self), GET /api/assessments, amal definitions/entries, all member/public routes untouched.
- Rebuilt + restarted: `bun run build` → killed ONLY the dist/main.js + dist/worker.js pids → relaunched both via nohup from apps/api (worker shares the module graph; restarted for the dist refresh). /health green (postgres+redis+meilisearch+storage). Caddy/Next/postgres/redis/meili never touched.
- VERIFICATION:
  · apps/api: `bun run lint` 0/0 · `bun run test` 34/34 GREEN (4 suites).
  · apps/web: `bunx tsc --noEmit` → exit 0 for the WHOLE project (zero new errors; zero old ones remain) · eslint on the 4 touched lib files 0/0.
  · Gateway curls (:81 with XTransformPort=3001) — guests: config 200, amal/definitions 31 defs, live 3 programs (F-session hidden), quran/surahs 114, quran/surah/1 + বাংলা অনুবাদ, content/duas, join?code=DS-000004 200, masala 201, feedback 201, me → user:null. Signed-in daee (01000000004): dawah (DS-000004, downline 4, reqs 9), usrah (আল-ফুরকান, 6 members, 2 announcements), reviews 3, assessments 1, templates [farze_ain_v1], reminders GET+PATCH 200, amal entries GET 154 + POST accepted, enroll POST/PATCH 201/200, quiz-attempt 201. Auth: otp request→verify→cookie refresh (EMPTY body) 200→logout 200→me null.
  · RolesGuard matrix: admin/overview user→403 / head 200(1 usrah) / invigilator 200(1 F usrah) / admin 200(2 usrahs); admin/audit head→403 admin→200(9); reviews POST user→403, head→200 (queue lazily created 5 pending, submitted one with auto-summary); assessments POST user→403, invigilator→200 (scorePct 92); amal unlock user→403, head own member→201; admin users GET head 200 (6 own-usrah users; Bengali search works encoded) user→403; users PATCH/promote/amal-catalog head→403; broadcast head scoped→201, global→403 (service scope, by design).
  · Browser E2E (agent-browser, via gateway :81 — first browser run of the rewired client): onboarding → Home dashboard with live API data (amal categories, qibla) → network log shows /api/me, /api/config, /api/amal/definitions all 200 with XTransformPort; quick-login usrah_head → otp request+verify 200 → দাওয়াত tab appears (role gating) → Dawah view full (DS-000003, ১৩ মাস, usrah, reviews queue, assessments, templates all 200) → Ilm লাইভ (তাফসীর মজলিস embed). Zero page errors; console clean (one pre-existing benign webpack warning in about.tsx).
  · Web :3000 200, gateway :81 200, api /health ok, dev.log tail clean (the old /api/* 404s predate the rewiring — browsing :3000 directly was never the sanctioned URL; via :81 everything forwards).
- Note: masala/feedback/enroll/quiz-attempt now return HTTP 201 (NestJS POST default) instead of the mirror's 200 — res.ok covers both, no client change needed.

Stage Summary:
- Web app now talks ONLY to the NestJS API (api.ts + store.ts flush through apiUrl; compile-checked routes from @sunnahlife/shared-types dist; cookie session with transparent refresh). The deleted SQLite-mirror surface is fully served by NestJS — including the 5 engagement routes that had been silently broken (missing @Req()).
- Explicit authorization in place: @Roles() + RolesGuard on every admin route + reviews/assessments submit + amal unlock (rank floors via ROLE_RANK); RLS unchanged as the safety net; 34/34 tests green.
- Demo DB side-effects from smoke tests (intended, realistic): one done weekly review (তানভীর, week 2026-09-26), one DayUnlock (2026-09-20), one invigilator assessment (not_yet, 92%), one masala + feedback row, daee enrollments/progress/quiz-attempt, one scoped broadcast + reminders. All valid seed-consistent data for B6's admin panel testing.
- Not done / notes for next agents: (1) admin month-grid for a PLAIN member's own grid now 403s (admin routes are supervisor-floor per task spec — only the admin console ever called it; mobile computes the heatmap locally); (2) B6 will own admin CRUD breadth — only the mirror's surface exists today; (3) shared-types response bodies are still `unknown` in the generated schema (controllers lack typed ApiResponse decorators) — request DTOs + paths are typed; response typing intentionally stayed in apps/web/src/types/domain.ts (verified 1:1 with API mappers).

---
Task ID: B2
Agent: B2 (general-purpose subagent)
Task: FCM push notifications, end to end — NestJS PushService (FCM HTTP v1 via plain fetch, no firebase-admin), DeviceToken table + RLS, token registration route, gender-isolated usrah fan-out, wiring (broadcast / weekly-reviews / prayer-push), Flutter firebase_messaging integration with deep-link navigation, Android/iOS platform setup, docs + CI-safe google-services guard.

Work Log:
- AUDIT FIRST: a previous B2 run had already written the bulk of this feature (it died before finishing — same class as 8-b/8-c). Found in place: apps/api/src/push/* (module, PushService, transports, device-tokens service, controller, DTOs, deep-links.ts), DeviceToken model + migration + RLS, processor/admin wiring, test/push.spec.ts, mobile push_service.dart / deep_links.dart / firebase_options.dart placeholder, Android manifest + gradle guard + example google-services.json, iOS AppDelegate/entitlements/Info.plist. Verified every piece against the task spec, fixed what was broken, filled the gaps.
- DEVICE-TOKEN SCHEMA (verified, was already applied): model DeviceToken (userId, token unique per user, platform, lastSeenAt) in prisma/schema.prisma + migration 20260928120000_device_tokens with RLS — policy app_self: SELECT = full_admin/system | own rows | (usrah_head/invigilator AND same-gender AND (invigilator | same usrah | usrah I head)); INSERT/UPDATE/DELETE = own rows only (WITH CHECK). FORCE ROW LEVEL SECURITY + GRANT to sunnah_app. LIVE DB CHECK (read-only pg): table exists, relrowsecurity+relforcerowsecurity true, policy applied, 0 rows. `bunx prisma migrate status` → "Database schema is up to date!" (4 migrations) — nothing left for the lead to run.
- NEW DB-LEVEL RLS TESTS (my addition): test-only probe GET /api/test/rls-raw-device-tokens (same header-gate + NODE_ENV guard as the amalEntry probe) in test-rls/rls-raw.controller.ts, and 5 new e2e cases in test/rls.e2e.spec.ts — M+F members register tokens through the REAL POST /api/push/token (upsert idempotency verified), F head → M member's tokens = 0 rows, M head → F member = 0 rows (DB-level cross-gender refusal for push fan-out), positive control F head → own member = 1 row, DELETE unregister → gone. Seeded tokens cleaned up in afterAll (system context).
- MOBILE CRITICAL FIX (found by running the suite): the smoke test "daee sees 5 tabs" FAILED — bootstrap hung on the splash. Root cause: firebase_core's platform-channel calls NEVER RESOLVE under the flutter test binding (neither value nor MissingPluginException — the future hangs forever; probe test confirmed a 5-min timeout). The guest test only passed because the singleton's `_initialized` flag had already been set by the hung daee test. Fix in push_service.dart: `_runningInFlutterTest` guard (FLUTTER_TEST env, !kIsWeb) skips Firebase entirely in `flutter test`; production path unchanged.
- NEW test/deep_links_test.dart (16 tests): pins the canonical sunnahlife:// URI literals (mirror of apps/api DEEP_LINKS) AND the deepLinkToRoute mapping/guards — foreign schemes rejected, unknown hosts → null, plain in-app paths only when whitelisted (/amal /dawah /ilm /more prefixes), live/{id} → /more/live, reviews+usrah → /dawah.
- DEPLOYMENT WIRING (was missing): infra/docker-compose.yml now passes FCM_SERVICE_ACCOUNT_JSON to BOTH api and worker (the worker is the main fan-out process — prayer/review pushes); .env.example documents it (object string OR file path, empty ⇒ no-op transport); docs/DEPLOY_COOLIFY.md §4 API/worker table got the FCM row.
- SECRET HYGIENE: .gitignore now excludes apps/mobile/android/app/google-services.json + apps/mobile/ios/Runner/GoogleService-Info.plist (real Firebase creds never committed; the example json stays as documentation).
- DOCS: NEW docs/RELEASE.md — §2 Firebase end-to-end: project creation, app registration (Android google-services.json placement + why CI doesn't need it, iOS plist), `flutterfire configure` → lib/firebase_options.dart (placeholder committed), service account key → FCM_SERVICE_ACCOUNT_JSON for api+worker, rotation, no-device verification (api log "FCM transport ready", curl /api/push/token, broadcast E2E), pre-flight checklist. NEW docs/IOS_BUILD.md — the signing-Mac runbook: APNs .p8 key upload to Firebase console, GoogleService-Info.plist placement, Xcode capabilities (Push Notifications + Background Modes remote-notification), pod install, TestFlight (aps-environment → production at upload), AppDelegate swizzling note. ios/README.md got a cross-link.
- ADAPTER SELECTION (verified by tests, runs at boot in PushService.onModuleInit): FCM_SERVICE_ACCOUNT_JSON absent/empty → NoopPushTransport (logs "[PushService] (no-op) would send: …", reports all sent so queues don't retry); invalid JSON/missing fields → warn + no-op fallback (never crashes boot); JSON object string → parsed; anything else → file path. Valid → FcmTransport: RS256 client-credentials JWT grant via WebCrypto against oauth2.googleapis.com/token (cached, 60s margin, one 401 retry), POST fcm.googleapis.com/v1/projects/{project}/messages:send, Promise.all batches of 25, android channel sunnah_life_push + icon ic_notification, apns sound default + badge 1; 404/410 UNREGISTERED → PushService prunes the token (system context).
- WIRING (all verified in code + jest): admin broadcast → push after the RLS transaction commits under the acting user (Announcement + Reminders remain the always-on fallback, push failure never fails the broadcast); weekly-reviews processor → pushes BOTH parties (member + head aggregate, gender-isolated bookkeeping); prayer-push processor → nightly job (18:05 UTC) computes next-day waqt times per user (shared prayer engine), stores 5 Reminder rows AND enqueues delayed "prayer-waqt" jobs with deterministic jobIds (prayer-waqt:{userId}:{date}:{waqt}) that fire at the waqt instant through PushService. WorkerProcessorsModule imports PushModule; AppModule imports PushModule (HTTP side: token registration + broadcast).
- GENDER DEFENSE IN DEPTH: sendToUsrah(usrahId) resolves members under the ACTING user's RLS, throws 403 "বিপরীত লিঙ্গের উসরায় নোটিফিকেশন পাঠানো যাবে না" for cross-gender non-admin, and stamps an application-level gender filter (user.gender = usrah.gender) onto token resolution as the second net; full_admin may cross but tokens stay gender-filtered (respectGenderIsolation=false escape hatch for admin tooling).
- MOBILE INTEGRATION (verified + fixed): pubspec firebase_core ^4.15.0 + firebase_messaging ^16.7.0 (locked: 4.15.0/16.7.0, dart >=3.13.4 — no new heavy deps); PushService.ensureInitialized (foreground → NotificationService.showNow on the sunnah_life_push channel, background tap + getInitialMessage → deepLinkToRoute → go_router.go, local-notification taps share the same callback); syncRegistration on every auth flip (pushRegistrationProvider watches authProvider, fireImmediately covers restored sessions) → requestPermission(alert/badge/sound) → getToken → POST /api/push/token, onTokenRefresh re-registers, sign-out DELETEs the token; api_client.dart register/unregisterPushToken. Android: manifest has WAKE_LOCK + default channel/icon meta + sunnahlife:// intent-filter; settings.gradle.kts declares the google-services 4.4.2 classpath, app/build.gradle.kts applies the plugin ONLY when google-services.json exists (CI builds without it — ci.yml mobile job untouched and compatible; firebase_options.dart is what matters at runtime).
- VERIFICATION: apps/api — `bun run lint` 0/0 · `bun run test` **76/76 GREEN** (6 suites: +13 push unit, +5 DeviceToken RLS e2e over the previous 71; the pre-B2 34 are all still green) · `bunx tsc --noEmit` — ZERO errors in any push/rls file; 18 PRE-EXISTING errors remain in src/reports/report-renderer.ts (17× TS2749 PDFDocument-as-type) + test/monthly-report.spec.ts (fontkit types) — the monthly-reports agent's domain, NOT touched by me (diff against the pre-B2 snapshot is identical). apps/mobile — `flutter analyze` No issues found · `flutter test` **54/54** (38 pre-B2 + 16 deep-link; smoke test repaired by the FLUTTER_TEST guard). NOT done by design: no rebuild/restart of api/worker (dist/ predates the push module — running processes serve no /api/push/* until the lead rebuilds), no git commands.

Stage Summary:
- Push notifications are code-complete end to end: DeviceToken (RLS, migration ALREADY applied to the live DB — verified, nothing to run), FCM HTTP v1 adapter (plain fetch + WebCrypto JWT, no SDK, ~zero deps) with no-op dev fallback, POST/DELETE /api/push/token (auth, upsert, cap 5/user via lastSeenAt eviction), gender-isolated sendToUsrah, wired flows (broadcast / weekly-reviews / prayer-push delayed per-waqt jobs), mobile firebase_messaging + deep-link routing (table in apps/api/src/push/deep-links.ts ⇄ apps/mobile/lib/core/deep_links.dart, pinned by tests), Android+iOS platform files, google-services.example.json + gradle file-existence guard (CI green without the real file — it's also gitignored now), docs/RELEASE.md + docs/IOS_BUILD.md + FCM env wired through compose to BOTH api and worker.
- Verification: api lint 0/0 · jest 76/76 · tsc clean in all push files · flutter analyze 0 · flutter test 54/54.
- FOR THE LEAD: (1) `cd apps/api && bun run build` then restart dist/main.js + dist/worker.js — BUT the build currently FAILS on src/reports/report-renderer.ts (17× TS2749 — monthly-reports agent's file landed after the last build; their jest passed because ts-jest isolatedModules does no full typecheck); coordinate with that agent or apply the mechanical fix (type-only PDFDocument import) before restarting. (2) After restart: verify POST /api/push/token (201) — the no-op transport logs "(no-op) would send: …" in api.log/worker output with no FCM_SERVICE_ACCOUNT_JSON set (sandbox has no Firebase project — by design). (3) Migration: NOTHING to run — 20260928120000_device_tokens is already applied (prisma migrate status = up to date; DeviceToken table + policy live, 0 rows). (4) Optional: regenerate packages/shared-types so /api/push/* lands in the OpenAPI path surface (web doesn't reference push routes, so nothing breaks without it). (5) Real delivery needs the human Firebase steps in docs/RELEASE.md §2 (service account JSON → FCM_SERVICE_ACCOUNT_JSON, flutterfire configure, google-services.json) — everything degrades to the no-op transport until then.

---
Task ID: B4
Agent: B4 (general-purpose subagent — died to infra timeout after writing all files; verified + integrated by lead-architect)
Task: Ilm content + quiz engine — real courses/quizzes/mosques/faq packs, enrollments/attempts/usrah-questions API (RLS), live quiz over WebSocket with per-gender leaderboard.

Work Log:
- Packs filled: courses.json 2 courses × 5 Bengali lessons (আকীদার মূলনীতি, সালাতের ফিকহ); quizzes.json 3 × 10 MCQs with explanations; mosques.json 24 Dhaka mosques with coords; faq.json 16 Bengali FAQs.
- API: GET /api/courses + /api/courses/:id (public, lessons), GET /api/enrollments + /api/quiz-attempts (auth), GET/POST /api/usrah-questions + answers (RLS-scoped to own usrah) — new Prisma model UsrahQuestion + migration 20260928140000 (APPLIED, verified by lead).
- GET /api/quiz/live-token (auth, HMAC {u,s,r,g,n,m,q,e} with QUIZ_SECRET) for the socket service.
- mini-services/quiz-service (port 3030, bun --hot, socket.io): host starts quiz room per usrah, questions with countdown, per-question reveal, speed-bonus scoring, leaderboard with FIRST NAMES + member codes only (rooms are single-gender by usrah design; token carries gender).
- Web: courses-section (cards → lesson reader + শেষ করেছি progress), quizzes-section (play flow + explanations + history), live-quiz-section (io("/?XTransformPort=3030")), extras usrah-questions UI (daee-gated).
- LEAD FIX: live-quiz-section useEffect cleanup type (TS2322); ilm.spec unused-var rename.
- Lead live verification: /api/courses 2 courses ✓ detail shows 5 lessons ✓ quizzes 3×10 ✓ mosques 24 ✓ faq 16 ✓ usrah-questions POST 201 + list ✓ live-token 401 unauth ✓ smoke.ts 13/13 PASS (leaderboard privacy, Bengali error on bad token, role guard) ✓ browser: কোর্স tab renders আকীদার মূলনীতি/সালাতের ফিকহ with পাঠ ✓ dev.log zero errors.

Stage Summary:
- Ilm is no longer a shell: real content packs flow through the single API, enrollment/quiz-attempt history works, usrah Q&A is RLS-scoped, live quiz runs on socket.io :3030 with gender-safe leaderboards. Quiz-service left RUNNING.

---
Task ID: B5
Agent: B5 (general-purpose subagent — died to infra timeout after writing all files; verified + integrated by lead-architect)
Task: Google + Apple Sign-In — JWKS-verified id_tokens (no SDK), link by verified email, gender asked at onboarding and locked after.

Work Log:
- API: POST /api/auth/social {provider, idToken, …} — Google JWKS (RS256, crypto.subtle) + Apple JWKS (ES256), aud/iss/exp checks, verified-email requirement; links to existing User by email (case-insensitive) or creates one (memberCode + referral + guestEntries import shared with OTP path); gender payload ignored for existing accounts. GET /api/auth/providers {google,apple} from env presence (GOOGLE_CLIENT_ID / APPLE_SERVICES_ID in env.validation + .env.example + DEPLOY_COOLIFY env tables).
- me controller: gender locked after set (Bengali rejection "লিঙ্গ পরিবর্তন করা যায় না"), name editable.
- Migrations: 20260928150000_social_auth (email field additions) — APPLIED, verified.
- Mobile: google_sign_in + sign_in_with_apple deps; social buttons gated on /api/auth/providers; session/guest-entry migration reuses the OTP path; gender_completion_screen.dart (one-time gender+name completion for social-created accounts → PATCH /api/me); social_signin_service.dart with FLUTTER_TEST guards; Runner.entitlements + docs/IOS_BUILD.md capability notes.
- Tests: apps/api/test/social-auth.spec.ts (JWKS reject paths: wrong aud, unverified email, expired; happy-path email linking) + apps/mobile/test/social_signin_test.dart.
- Lead verification: providers → {"google":false,"apple":false} (disabled without env — correct); api lint 0 errors (1 warning fixed), tsc 0, jest 116/116 (8 suites); flutter analyze No issues, flutter test 58/58.

Stage Summary:
- Social auth is code-complete and statically verified; enabling live requires GOOGLE_CLIENT_ID/APPLE_SERVICES_ID env + restart (documented in RELEASE.md §social-login).

---
Task ID: B6
Agent: B6 (general-purpose subagent — died to infra timeout after writing all files; verified + integrated by lead-architect)
Task: Level automation (nightly rules worker → LevelTransition + audit + reminder), Dawah live requirements checklist, full admin CRUD (catalog, versioned templates, usrah mgmt, audited role/gender, live programs) + admin UI wiring.

Work Log:
- LevelsService (src/levels/) — rule evaluation shared by the nightly processor + GET /api/dawah/requirements; levels.processor.ts + "levels-nightly" repeatable job (00:30 BD) auto-promotes, writes LevelTransition (method:auto) + AuditLog + Reminder + push; idempotent. Migration 20260928160000_level_transitions APPLIED (prisma migrate status clean).
- Admin promote now REQUIRES a reason; records method:"admin" + actor.
- Admin CRUD: amal catalog PATCH /api/admin/amal-catalog/:key (titleBn/points/active) + PATCH reorder (keys array) — catalog now DB-backed (AmalDefinition table, 31 rows seeded); versioned AssessmentTemplate (create new version, activate); POST /api/admin/usrah + PATCH (head/invigilator assignment, gender-validated) + member move endpoints; PATCH /api/admin/users audited with reason (gender Full-Admin-only); live program CRUD.
- Web Dawah view: স্তরের প্রয়োজনীয়তা live checklist section (progress chips).
- Admin UI: catalog (update/disable/reorder), templates, usrah mgmt, levels (history + promote-with-reason), live CRUD pages wired.
- LEAD FIXES: levels.spec getResponse() typing; ilm.spec unused var.
- Lead live verification: dawah/requirements returns live checklist (min_months 4/4 met, assessment_passed met, …); usrah create 201 (উসরা আল-ইখলাস); catalog update 200 + reorder 200 + audit entries recorded (update_amal_definition, reorder_amal_catalog, create_usrah, usrah move); audited usrahId move + restore 200; worker log shows levels queue + levels-nightly registered. jest 133/133 (9 suites), lint 0, tsc 0.

Stage Summary:
- Level progression is automated nightly (rules from level-rules.json) with admin override requiring a reason; the admin API now covers catalog CRUD/reorder, versioned templates, usrah management, audited role/gender changes, live program CRUD — all wired into the admin UI.

---
Task ID: B7
Agent: B7 (general-purpose subagent — died to infra timeout after writing most files; completed + verified by lead-architect)
Task: bn/en/ar with real RTL (ARB + gen-l10n on mobile, catalogs + logical CSS on web/admin) + accessibility pass with WCAG AA contrast table.

Work Log:
- Mobile: full ARB migration (lib/l10n/app_bn.arb TEMPLATE + app_en.arb + app_ar.arb; committed generated/ output via l10n.yaml, nullable getter w/ Bengali fallback); app swept to AppLocalizations (~25 screens); Arabic locale → RTL Directionality; hard-coded L/R audited; hot-swap via persisted store; flutter analyze 0 issues, flutter test 65/65.
- Web: full trilingual catalog in i18n.ts (77 keys × bn/en/ar); shell sets dir="rtl" for ar; globals.css [dir=rtl] rules; logical-CSS sweep (ms/me/ps/pe/start/end); language switch hot-swaps.
- A11Y (lead-completed): contrast script over tokens.json → docs/A11Y_CONTRAST.md — 14 pairs, both themes, ALL PASS after fixes: gold TEXT now uses --gold-text (#B7791F light = 3.31:1 ≥3:1 large, #D9B25F dark = 9.23:1) with 23 text-gold usages swept; alert light #C0392B→#B93527 (4.49→4.82:1); tokens.json + globals.css + build.mjs --check path fixed (root→apps/web) → "70 color values verified". tap-target (44px) on bottom nav; focus-visible ring; aria-labels on icon buttons; Flutter Semantics + scale-safe layouts.
- Browser verification: Arabic onboarding → dir="rtl" on shell; bottom nav renders الرئيسية/الأعمال/العلم/المزيد (Arabic labels live).

Stage Summary:
- bn/en/ar shipped on mobile (ARB+gen-l10n, RTL) and web (catalog + RTL + logical CSS); WCAG AA contrast table documented with the two failures FIXED (gold-text, alert) and parity-check green. Honest gaps: admin keeps bn-only (RTL-ready logical classes), a few onboarding step-2 strings fall back to Bengali in the Arabic locale.

---
Task ID: B8
Agent: lead-architect (main session, Phase B closeout)
Task: CI for the new layout (debug APK + secrets-gated aab + ci-status self-report), docs (AUDIT.md, DEPLOY_COOLIFY de-mirrored), final fresh-clone verification, push.

Work Log:
- CI (7 jobs): branches trigger fixed ([main, master] — the corrupted line was a display artifact: od showed "[m"+"ain" being eaten as an escape in tool output); web job moved to apps/web (no DATABASE_URL — no local DB); release-bundle job (secrets-gated: ANDROID_KEYSTORE_BASE64 family → app/build.gradle.kts reads key.properties, falls back to debug signing locally); report job writes .github/ci-status.md back to main ([skip ci]) because the fine-grained PAT lacks actions:read (all Actions endpoints 403).
- SECOND gitignore-class bug found BY the fresh-clone test: apps/api/.gitignore bare `storage/` hid src/storage/ (the whole storage module) from git — anchored to /storage/, committed (fb2a92c).
- Fresh-clone final verification: flutter pub get ✓ · analyze No issues (5.5s) · flutter test 65/65 (an earlier 8-failure run was a disk-full artifact; freed and re-run → clean) · API bun install 369 pkgs · jest 9 suites 133/133.
- Web production build verified locally (3/3 static pages, ~7 min) — the CI web job's exact commands all reproduce.
- docs/AUDIT.md: §4–9 table (Done/Partial/Not done + files + proof commands + explicit "Not done in sandbox" list). DEPLOY_COOLIFY.md: mirror-mode references removed (web = API-only, no webdata volume), troubleshooting updated.
- gradle signing: app/build.gradle.kts release signing from key.properties (fallback debug); docs/RELEASE.md §3 documents the secret injection.
- CI status: NOT observable from the sandbox after 60+ min (no ci-status.md; every Actions API endpoint 403 on the PAT). Honest note in AUDIT.md — user must check the Actions tab; likely queued on private-repo minutes or Actions disabled.
- Final state: all services running (web :3000, api :3001, worker, quiz-service :3030), dev.log clean.

Stage Summary:
- Phase B code-complete and pushed. CI is configured to prove everything the audit demanded but its RESULTS could not be observed from the sandbox (PAT limitation) — flagged honestly instead of claimed.

---
Task ID: B9-a
Agent: lead-architect (main session)
Task: Fold the live-quiz mini-service into the NestJS API as a socket.io gateway (one backend / one auth / one deployment) + @Roles on usrah.controller.

Work Log:
- Restored the reset sandbox toolchain: portable Postgres 16.10 (github.com theseus-rs binaries → /home/z/opt/pg16, initdb, :5433), Redis 7.0.15 debs → /home/z/opt/redis (:6380, liblzf from pool), `bun install` in apps/api + apps/web. Meilisearch NOT restored (API skips indexing without MEILI_HOST — health shows "absent", tests unaffected).
- prisma migrate deploy + seed against the fresh DB (15 users, 2 usrahs, 6796 amal entries…).
- apps/api: added @nestjs/websockets, @nestjs/platform-socket.io, socket.io (runtime) + socket.io-client (dev, for the smoke script).
- NEW apps/api/src/engagement/quiz.gateway.ts — the retired mini-service logic as a NestJS @WebSocketGateway on the API's own HTTP server (path /socket.io): same HMAC token auth (verifyQuizToken, same QUIZ_SECRET, minted by GET /api/quiz/live-token AFTER JwtAuthGuard+RLS checks), same wire protocol (room:state / quiz:started / quiz:question / quiz:reveal / quiz:ended / quiz:error; player:accepted), same scoring (100 + ≤40 speed bonus, reconnect-safe scores, one-answer rule, empty-room GC). Room state stays in-memory (ephemeral game state; durable writes stay behind RLS).
- main.ts: IoAdapter (NOT WsAdapter — that's the raw-ws package; first boot caught it). Global JwtAuthGuard + AllExceptionsFilter made ws-context safe (guards/filters also run on gateway message handlers; without the fix they'd crash on a Socket).
- usrah.controller.ts: @UseGuards(RolesGuard) + @Roles("user") on GET /api/usrah (consistency with reviews/dawah/admin).
- Web live-quiz-section.tsx now connects to the API's own gateway: `io(API_BASE || "/?XTransformPort=3001", { path: "/socket.io" })` — no more :3030.
- Deleted mini-services/quiz-service entirely (repo has zero bun mini-services now).
- Smoke ported to apps/api/src/scripts/quiz-smoke.ts (`bun run smoke:quiz`), package.json script added.
- PLAN.md: B9 section added (audit gaps + fixes).

Stage Summary:
- VERIFIED RAW: `bun run smoke:quiz` → 21/21 PASS against the in-process gateway (websocket direct :3001). Socket through Caddy `/?XTransformPort=3001` path `/socket.io`: polling PASS + websocket-upgrade PASS (room:state received on both). `bun run test` (apps/api) → 9 suites, 133/133 PASS. eslint clean (api files + web app).
- One backend stands again: web+mobile both reach NestJS :3001 for REST and WS.
- API dev boot: `DATABASE_URL=postgresql://sunnah_app:sunnah_app_dev@127.0.0.1:5433/sunnahlife DIRECT_URL=postgresql://postgres@127.0.0.1:5433/sunnahlife QUIZ_SECRET=dev-quiz-secret JWT_SECRET=… JWT_REFRESH_SECRET=… REDIS_URL=redis://127.0.0.1:6380 SMS_PROVIDER=mock PORT=3001 bun src/main.ts`

---
Task ID: B9-b
Agent: lead-architect (main session)
Task: Flutter foundation for the B9 surface parity — models, API client, providers, l10n, router, entry points (screens themselves land in B9-c/B9-d).

Work Log:
- Restored Flutter 3.47.5 stable (Dart 3.13.4, exact repo pin) to /home/z/flutter — storage.googleapis.com now streams at ~17 MB/s, no ranged downloader needed.
- pubspec: + socket_io_client ^3.1.6 (socket.io v4 protocol — matches the API gateway). flutter pub get green.
- NEW lib/models/ilm_engagement.dart: CourseSummary/CourseDetail/CourseLesson/CourseDetailResponse/EnrollmentItem, QuizAttemptItem, UsrahQuestion (+6 category ARB keys), LevelCheckRow/DawahRequirements, QuizLiveTokenResponse, loadBundledCourses() (offline pack). Quiz/QuizQuestion NOT duplicated — content_models.dart owns them (now with a `live` flag). Exported via the domain.dart barrel.
- api_client.dart: courses/courseDetail/enrollments/enroll/saveCourseProgress/quizPack/submitQuizAttempt/quizAttempts/usrahQuestions/askUsrahQuestion/answerUsrahQuestion/dawahRequirements/quizLiveToken.
- remote_state.dart: quizPackProvider (API→bundled fallback), coursePackProvider (API→bundled), enrollmentsProvider, quizAttemptsProvider, usrahQuestionsProvider, dawahRequirementsProvider — all session-aware.
- ARB: +87 keys ×3 (bn/en/ar, parity 411/411/411), flutter gen-l10n regenerated (411 getters), app_strings.dart identity map updated by script.
- app.dart router: /ilm/courses(+/:courseId), /ilm/quizzes(+/:quizId), /ilm/live-quiz, /dawah/questions, /dawah/requirements.
- Ilm grid: +কোর্স +কুইজ +লাইভ কুইজ tiles (11 total). Dawah tab: requirements section got a "লাইভ চেকলিস্ট" action → /dawah/requirements; Usrah tab got the উসরার প্রশ্নোত্তর entry card → /dawah/questions.
- Bundled the real packs (assets/content/quizzes.json + courses.json — copies of packages/content) for the offline fallbacks.
- 7 STUB screens committed so the tree compiles while agents replace them (courses_screen.dart: CoursesScreen+CourseDetailScreen(courseId, openLessonId); quizzes_screen.dart: QuizzesScreen+QuizPlayerScreen(quizId); live_quiz_screen.dart; usrah_questions_screen.dart; dawah_requirements_screen.dart).

Stage Summary:
- flutter analyze: No issues found. flutter test: 65/65 pass (with stubs).
- The screen writers (B9-c, B9-d) now have a frozen contract: models in lib/models/ilm_engagement.dart + content_models.dart, providers in lib/state/remote_state.dart, api methods on ApiClient, l10n keys 411 in ARB (t('key') / context.t), routes fixed.

---
Task ID: B9-c
Agent: B9-c (courses + quizzes screens)
Task: Replace the two B9 stub screens in apps/mobile with production UI — lib/features/ilm/courses_screen.dart (CoursesScreen + CourseDetailScreen with lesson-player bottom sheet) and lib/features/ilm/quizzes_screen.dart (QuizzesScreen + QuizPlayerScreen with result view).

Work Log:
- Read B9-a/B9-b sections + style contract references (articles_screen, live_screen, shared/widgets, design_tokens, bn_digits) and the frozen B9-b contracts (ilm_engagement models, remote_state providers, ApiClient methods, 411 ARB keys, go_router routes /ilm/courses/:courseId?lesson=… and /ilm/quizzes/:quizId).
- courses_screen.dart (586 lines):
  - NEW in-file FutureProvider.autoDispose.family `courseDetailProvider(courseId)` → api.courseDetail(); on ApiException falls back to loadBundledCourses() find-by-id (enrolledCount 0, myEnrollment null) so offline reads still work; rethrow when not in the pack either.
  - CoursesScreen (ConsumerWidget): watches coursePackProvider + enrollmentsProvider; Skeleton 132×4 / ErrorState (courses_load_failed + ApiException message) with retry-invalidate / EmptyState (courses_empty_title + courses_empty_hint combined). Card: level chip (secondary pill, c.level), titleBn w700, descBn 2-line ellipsis, meta row `'X পাঠ · Y মিনিট'` + `' · N জন ভর্তি'` (course_enrolled_unit, only when enrolledCount>0), progress bar (4dp, ClipRRect pill) + 'x/y পাঠ সম্পন্ন' (course_progress_of) when done>0, full-width FilledButton course_continue/course_start → push /ilm/courses/:id.
  - CourseDetailScreen (ConsumerStatefulWidget): AppBar title = course titleBn (fallback ilm_courses). ref.listen syncs `List<String> _done` from myEnrollment.done on EVERY load (server wins); auto-opens openLessonId's sheet once via post-frame callback. Enroll button tri-state: signed-out → course_signin_to_enroll → push /auth; signed-in & !enrolled → course_enroll (course_enrolling text + disabled while awaiting, SnackBar on ApiException); enrolled (myEnrollment != null || local flag) → disabled FilledButton.tonalIcon course_enrolled. Header card: title/desc/progress+label/lessons.
  - Lesson rows (playlist): AppCard, leading 34px circle (primary+onPrimary ✓ when done, else secondary+onSecondary Bengali number), title + 'X মিনিট', DirectionalIcon chevron. Lessons sorted by `order`.
  - Lesson player sheet (_LessonSheet, showModalBottomSheet isScrollControlled, showDragHandle, theme-rounded top, ConstrainedBox maxHeight 85%, Flexible+SingleChildScrollView body, PINNED button area): paragraphs split on `\n{2,}`; toggle button lesson_complete (FilledButton.icon)/lesson_unmark (tonal) → parent _toggleLesson (setState + persist). Persist = saveCourseProgress ONLY when authProvider.signedIn, try/catch (offline keeps local state); on success invalidates enrollmentsProvider so the catalog beneath refreshes. Interpretation (noted deviation): marking complete KEEPS the sheet open when a next lesson exists — the button area then ALSO offers lesson_next (advance = pop + open next sheet); unmarking or completing the FINAL lesson closes the sheet.
- quizzes_screen.dart (658 lines):
  - QuizzesScreen (ConsumerWidget): watches quizPackProvider + quizAttemptsProvider (+bare authProvider watch for session flips); Skeleton 148×4 / ErrorState (quizzes_load_failed) / EmptyState (quizzes_empty_title + hint). Card: titleBn w700 + gold live chip (quiz_live_eligible) when q.live, descBn, meta 'X প্রশ্ন · Y মিনিট' (quiz_questions/quiz_minutes), when attempts exist: gold _GoldChip 'সেরা s/t' (quiz_best, max by score/total ratio) + 'সর্বশেষ: s/t' (quiz_last, max createdAt), full-width CTA quiz_play → push /ilm/quizzes/:id.
  - QuizPlayerScreen (ConsumerStatefulWidget): quiz from quizPackProvider (Skeleton while loading, error + not-found → ErrorState retry, empty questions guarded). One question at a time: top 'প্রশ্ন x/n' primary chip (quiz_question_of) + 4dp position LinearProgressIndicator, headlineMedium question. Option rows: 56px Material+InkWell+border, leading 32px circle with Bengali number, tap locks all; correct → primary tint/border + ✓ trailing + filled primary circle; wrong pick → error tint + ✗ + filled error circle; others dim 55%. Feedback: 'সঠিক উত্তর ছিল: <option>' (error color) when wrong + 'ব্যাখ্যা: …' callout (secondary bg) when explanationBn exists (shown for both right/wrong picks). Pinned bottom primary button quiz_next_question / quiz_finish.
  - Result view: 168px score ring (CircularProgressIndicator stroke 10, round caps, primary when ≥80% else gold tertiary) + big 'x/n' (displaySmall) + Semantics label, headline quiz_great/quiz_needs_more (≥80% rule), save-note row (cloud_done/cloud_off + quiz_result_saved / quiz_result_local), buttons quiz_play_again (full state reset) + quiz_back_to_list (canPop ? pop : go /ilm/quizzes — deep-link safe). submitQuizAttempt called ONCE per finished run when signedIn (guard flag reset by play-again), try/catch → offline = guest note; success also invalidates quizAttemptsProvider.
- All user-visible strings via context.t (35 keys verified pre-existing in ARB — no new keys, l10n untouched); numbers via `_n` = context.isBn ? toBn : toString; colors exclusively theme.colorScheme.*/SLColors (dark-safe); dart format applied to exactly the two files.

Stage Summary:
- VERIFIED RAW:
  - `flutter analyze` → "No issues found! (ran in 2.8s)"
  - `flutter test` → "00:24 +65: All tests passed!" (65/65)
- Both B9-c stubs replaced 1:1 on their frozen contracts (constructors, routes, providers, keys unchanged) — router/app.dart needed zero edits.
- Deviations (integrator please note): (1) lesson-complete keeps the sheet open when a next lesson exists (per the "button area ALSO offers lesson_next to advance" clause) — unmark/final-lesson close it; (2) course/quiz list cards are ALSO tappable (same route as their CTA) for larger touch areas; (3) enrollmentsProvider is invalidated after each successful progress save / enroll / attempt submit so the catalog chips refresh on return (ref is unusable in dispose — riverpod throws post-defunct).

---
Task ID: B9-d
Agent: B9-d (general-purpose subagent)
Task: Replace the three B9-b stub screens — LiveQuizScreen (socket.io live usrah quiz), UsrahQuestionsScreen (usrah Q&A board), DawahRequirementsScreen (live level checklist).

Work Log:
- READ FIRST (per contract): quiz.gateway.ts wire protocol (source of truth), live-quiz-section.tsx + usrah-questions.tsx + dawah-view.tsx (LevelRequirementsCard) on the web, dawah_screen.dart + live_screen.dart + shared/widgets.dart + design_tokens.dart for the mobile style, models (ilm_engagement/dawah/user/content_models), api_client.dart, remote_state.dart providers, ARB keys (all live_quiz_*/usrah_q_*/dawah_req_* verified present ×3 locales, no l10n edits).
- lib/features/ilm/live_quiz_screen.dart (~1340 lines): ConsumerStatefulWidget. Join = quizLiveToken('') → socket_io.io(base, OptionBuilder().setPath('/socket.io').setAuth({'token'}).setTransports(['websocket','polling']).disableAutoConnect().disableReconnection().build()) + connect(); wired room:state / quiz:started / quiz:question / quiz:reveal / quiz:ended / quiz:error / connect_error / player:accepted, emits player:answer {index, choice} + host:start {quizId} / host:next / host:end; 250ms Timer.periodic countdown (error colour ≤5s, "N সে" via toBn + live_quiz_secs) cancelled on reveal/ended/leave/dispose; socket.dispose() in dispose(); signing out mid-room drops the socket (ref.listen on authProvider). Phases mirror the web: lobby players card (live_quiz_players chips, online dimming), question card (locked options + check badge, host hint / answered / choose-option footnote), gold reveal card (quiz_correct_was + explanation + tally chips "i: N জন"), ended crown card (workspace_premium) + live_quiz_leave reset-to-intro. Host card (gold border): live-quiz picker from quizPackProvider q.live (radio rows, title + "N প্রশ্ন") + live_quiz_start; question → live_quiz_reveal_now; reveal → live_quiz_next; both + live_quiz_end outline. Leaderboard whenever scoreboard non-empty && phase != ended (rank 1 gold-tinted tertiary, name bold + memberCode small + score toBn, "+N" when lastPoints>0). AppBar status pill সংযুক্ত/বিচ্ছিন্ন.
- lib/features/dawah/usrah_questions_screen.dart (~570 lines): ConsumerStatefulWidget. Sign-out gate (usrah_q_title/usrah_q_hint → /auth); RefreshIndicator (invalidate + await future) AND a refresh IconButton; ask form (multiline TextField usrah_q_ask_hint, 6 category chips via UsrahQuestion.categoryLabelKey, min-8-chars client check, usrah_q_send/sending) → askUsrahQuestion → usrah_q_sent SnackBar + clear + invalidate; question cards (category chip + author + yyyy-mm-dd header, answer block on primaryContainer with usrah_q_answered_by + answeredAt, else italic gold usrah_q_awaiting chip); HEAD answering (role.rank >= 2): "উত্তর লিখুন…" toggle (usrah_q_answer_hint key) opens a TextField + submit (usrah_q_answer_submit, ValueListenableBuilder enables it as the head types) + cancel → answerUsrahQuestion → usrah_q_answered SnackBar + invalidate.
- lib/features/dawah/dawah_requirements_screen.dart (~470 lines): ConsumerWidget watching dawahRequirementsProvider + dawahProvider fallback. loading → Skeleton; live error/null → overview rows (ListTile form) + muted dawah_req_load_failed note; neither → ErrorState + retry (invalidates both). Live body: level row (আমার স্তর/পরবর্তী স্তর via labelKey stat cells), rulesApply machine-dot progress row (one dot per autoChecked row, filled primary when met, labelBn tooltips) + "x/y পূরণ" (dawah_req_progress_unit), checklist rows (check_circle primary / radio_button_unchecked outline, bold labelBn when met, gold dawah_req_invigilator_check chip when !autoChecked, detailBn + current/target chip when target>1 — met ? primaryContainer : surfaceContainerHighest), allMet → success card (dawah_req_all_met, primaryContainer), else autoEligible/rulesApply → hint card (dawah_req_auto_hint).
- Style contract kept: AppCard/SectionHeader/EmptyState/ErrorState/Skeleton/DirectionalIcon, colors exclusively theme.colorScheme (dark-mode safe), SLSpacing/SLRadius/SLMotion tokens, 44px+ tap targets (56px option/picker rows), every string via context.t, numbers isBn ? toBn : '$n'. dart format applied to exactly the three files.
- DEVIATIONS: (1) socket_io_client import prefix is `socket_io`, not `IO` — repo analysis_options lints library_prefixes (lower_case_with_underscores); `as IO` leaves an analyzer info and would break the mandatory "No issues found!". Connection options are otherwise verbatim. (2) The head's answer-toggle button label reuses usrah_q_answer_hint ("উত্তর লিখুন…") — no dedicated key exists and keys must not be added; same key doubles as the min-8-chars validation SnackBar. (3) Rank-1 leaderboard highlight uses tertiary (gold) withValues(alpha) tints rather than unset container roles. (4) /agent-ctx at the filesystem root is unwritable in this sandbox (permission denied) — the agent work record lives at /home/z/my-project/agent-ctx/B9-d-mobile-engagement-screens.md.

Stage Summary:
- VERIFIED RAW: `flutter analyze` → "Analyzing mobile... No issues found! (ran in 2.1s)"; `flutter test` → "00:23 +65: All tests passed!" (65/65). One mid-run analyze showed a transient unused_local_variable warning in B9-c's in-flight courses_screen.dart; it cleared on the ~35s re-run with no action from me — final tree clean with both agents' files.
- B9 mobile parity complete end-to-end: the live quiz speaks the API gateway's exact wire protocol (one backend, /socket.io, HMAC room token), the usrah board rides the RLS-scoped REST endpoints, and the level checklist renders the live rules engine with the overview snapshot as offline fallback.

---
Task ID: B9-e
Agent: lead-architect (main session)
Task: B9 verification + audit/docs close-out — browser E2E, fresh-clone gates, AUDIT corrections, push.

Work Log:
- Browser E2E (agent-browser, through Caddy :81 like the preview): signed in as the male usrah head → Ilm → আরও → লাইভ কুইজ → room joined via the NESTJS gateway (api.log: "[QuizGateway] host মাওলানা (DS-000003) joined room …"), full host round played (start → প্রথম প্রশ্ন → reveal with correct answer + tally → next → end → leave). Self-paced কুইজ played (answer locked, explanation, next). উসরার প্রশ্নোত্তর: question asked + head answer published → both render (API log POST 201 /answers 201).
- FOUR latent web bugs found & fixed by that E2E (commit 3ba9fa6): routeIlm had no "more" case (আরও tab unreachable → showed live programs); QuizzesSection was dead code (never imported — now wired with a কুইজ card + quiz deep link); API_PORT was not exported from api-base.ts (socket URL became /?XTransformPort=undefined); the host panel had no transition out of the lobby after quiz:started (host could never reach the first question) — added the প্রথম প্রশ্ন button.
- 3 dead ARB keys removed (408/408/408 parity), gen-l10n regenerated, key-usage audit script confirmed every context.t() key in the new screens resolves.
- AUDIT.md: live-quiz row → in-process gateway (mini-service deleted) with smoke 21/21 + Caddy + browser proofs; mobile-surface rows (courses/quizzes/usrah-questions/checklist) now Done with the mobile files listed; known-gap #5 (mobile checklist web-only) REMOVED; B9 close-out table added (the 3 audit gaps + the 4 E2E-found bugs).
- API_CONTRACTS.md: "Live usrah quiz — socket.io gateway (inside the API, B9)" section (protocol, auth, isolation, scoring, smoke).
- FRESH-CLONE verification (/tmp/sl-clone, raw outputs in the session report): flutter pub get / analyze "No issues found!" / test 65/65; apps/api bun install + jest 9 suites 133/133; apps/web bun install + eslint clean + `bunx tsc --noEmit` exit 0 + `bun run build` exit 0.
- Found by that fresh-clone run: packages/shared-types/dist was gitignored → the web tsc gate could NOT pass on a fresh clone (the main checkout had a local dist; CI was saved only by typescript.ignoreBuildErrors). Fixed by committing dist/schema.d.ts (75KB, 60 paths, regenerated via nest build + bun run generate — deterministic) with precise .gitignore negation. Fresh-clone tsc now passes. (commit 6d311a3)

Stage Summary:
- All three audit gaps closed and machine-verified; two EXTRA repo-integrity bugs (dead web code, un-committed generated types) found and fixed along the way.
- Every gate re-verified on a fresh clone at the final commit.

---
Task ID: B10
Agent: lead-architect (main session)
Task: Diagnose GitHub Actions run #20 failure via the Actions API (PAT now has actions:read) and fix CI so the debug APK artifact is generated.

Work Log:
- Queried the Actions API with the embedded remote token: runs #15–#20 ALL conclusion=failure with ZERO jobs, same-second completion, no check runs — workflow-level rejection, not a job failure.
- Verified the workflow blob is byte-identical local↔GitHub (git blob sha e80bc7976c… matches the contents API) and strict-YAML-valid — so the rejection had to be GitHub's workflow compiler. Fetched the public run page HTML and extracted the real annotation: "Invalid workflow file: .github/workflows/ci.yml#L1 … (Line: 37/50/137/164/190/249, Col: 9): Unrecognized function: 'hashFiles'".
- Root cause: job-level `if: hashFiles('…') != ''` gates on 6 jobs. hashFiles() is not available in job-level if (no workspace exists before checkout), so GitHub rejected the whole file on EVERY push since the first — the "mobile debug APK artifact: Done" audit row was never observable (honest correction made).
- Pre-validated the mobile job before fixing: gradle-wrapper.jar committed, firebase_options.dart committed, google-services plugin guarded (builds without the real json), migrate:deploy + seed scripts exist, bun.lock committed for api/web/admin, api env needs only DATABASE_URL (all CI envs set).
- Fix (commit 2bbb55b): new `workspace` probe job (one checkout, exports true/false per workspace to GITHUB_OUTPUT); every downstream job gates on `needs.workspace.outputs.* == 'true'` — same "activate only when the workspace exists" intent, valid syntax. Flutter pinned to 3.47.5 (the SDK the repo is verified with: analyze 0, tests 65/65) in both mobile and release-bundle. Header/report comments refreshed (PAT now has actions:read).
- Hardening (commit 7bccddd): debug APK upload `if-no-files-found: warn → error` — a green run with no artifact is a silent failure; now it fails red.
- Dropped the unpushed auto-snapshot commit b93532a (mode-only, 0 content changes — it would have re-broken 49d0b68's mode normalization) via reset to 49d0b68 before committing.
- Verified via API: run #21 (2bbb55b) and #22 (7bccddd) — the workflow now COMPILES and creates 8 jobs (workspace → tokens/api/web/admin/mobile/release-bundle gated; report with always()). Local strict YAML parse + structure dump OK.
- NEW BLOCKER surfaced (was masked by the compile error): every job start is refused with "The job was not started because your account is locked due to a billing issue." — account-level GitHub billing lock on sharif418. Not fixable via API (billing API → 403 with this PAT); repo is public so ubuntu-latest minutes are free once the lock is cleared.
- AUDIT.md honesty updates: "CI green" row → Blocked (workflow FIXED, account billing-locked) with the full API evidence; "Debug APK artifact" row Done → Not done (blocked) with the correction note.

Stage Summary:
- Workflow compile bug FIXED and proven live: 0 jobs → 8 jobs (runs #21/#22). Remaining blocker is the user's GitHub billing lock; once cleared, a re-run of #22 (or any push) will execute the full pipeline and upload `mobile-debug-apk`.
- Commits pushed: 2bbb55b (workspace probe + pin), 7bccddd (strict artifact upload) + AUDIT/worklog in this commit.

---
Task ID: B11
Agent: lead-architect (main session)
Task: Billing resolved by the user — re-run #23 via the Actions API, then drive CI to all-green with the debug APK artifact actually produced and verified.

Work Log:
- Re-ran #23 via POST /actions/runs/36378225119/rerun (HTTP 201). Jobs executed for the first time ever: workspace/tokens/web/admin/release-bundle/report green; API failed at jest; mobile failed at "Build debug APK".
- API log: "Invalid environment configuration → JWT_REFRESH_SECRET: String must contain at least 8 character(s)" — 3 suites (ilm/social-auth/rls.e2e) 51 tests dead at app-module import. Root cause: zod validates .default("") through the inner schema, so .min(8).optional().default("") rejects EVERY boot without the var (no .env on CI — or anywhere). REPRODUCED LOCALLY (ilm.spec 18/18 fail with no env) → fixed with a refine (empty allowed: auth.service falls back to JWT_SECRET; explicit short still rejected) → full suite 133/133 in a CI-equivalent env (JWT_REFRESH_SECRET deliberately unset, local PG 5433 + Redis 6380).
- Mobile log: "Script compilation errors … 2 errors" in app/build.gradle.kts. (1) Unresolved reference 'util' — java.util.Properties() inside android{} resolves 'java' to the Gradle extension → import java.util.Properties. (2) The android{} accessor deprecation is only a WARNING (w:) listed in the failure section — and android.newDsl=false/builtInKotlin=false are LOAD-BEARING: flutter 3.47.5's own plugin casts to legacy AbstractAppExtension (FlutterPlugin.kt:353-354), newDsl=true (AGP-9 default) ClassCasts at plugin apply. Verified empirically both ways locally with the repo's exact Gradle 9.3.1/AGP 9.1.0/Kotlin 2.4.0/JDK 21.
- Deep local verification of the mobile build path: installed Android cmdline-tools + platform-36/build-tools-36 in the sandbox, stub NDK 28.2.13676358 (source.properties only — AGP demands the NDK at configure for the strip machinery; debug keeps native symbols via keepDebugSymbols so no NDK binaries run), Adoptium JDK 21 (sandbox had JRE only). Proven locally: scripts compile → flutter plugin applies → :app configuration proceeds into plugin subprojects — the sandbox then hit ENOSPC (fs full), so task execution was left to CI (runners have 20 GB+). Also pinned ndkVersion = flutter.ndkVersion and scoped keepDebugSymbols to the debug variant; CI JDK 17 → 21 to match the verified toolchain.
- Pushed 7056ca3 → run #24: mobile job GREEN — debug APK built; API 126/133 with only rls.e2e failing (7 tests, all 500 at otp/verify). Log analysis: CI's 4 vCPU → 3 jest workers; ilm.spec and rls.e2e.spec sign in as the SAME seeded demo phones; OTP verify honors only the newest code per phone → interleaved sign-ins → mismatch path → failure-counter update() on a row the other worker's deleteMany consumed → Prisma P2025 → 500. Never seen locally (2 vCPU → 1 worker). Fixed: ci.yml jest --runInBand (shared-DB integration suites are serial by design) + auth.service.ts update → updateMany (concurrent consume must not 500). Local: 133/133 with the exact CI invocation.
- Pushed 3d632c0 → RUN #25 (id 36389041267): conclusion=SUCCESS — all 8 jobs green (tokens/api/web/admin/mobile/release-bundle/report).
- Artifact verified end-to-end via the Actions API: mobile-debug-apk (id 10955835922) 386.3 MB, downloaded, zip CRCs pass, inner app-debug.apk is a valid Android package (1128 MB uncompressed): AndroidManifest.xml, classes.dex, libflutter.so (arm64-v8a + armeabi-v7a + x86_64 debug engines), libsqlite3.so, flutter_assets all present, APK CRCs pass. Note: flutter's debug packaging ships all 3 engine ABIs (universal debug APK) — abiFilters do not restrict flutter-controlled debug ABIs; documented in AUDIT.
- AUDIT.md: CI row → Done (run #25 evidence, the three stacked bugs listed); Debug APK row → Done (artifact id, size, integrity checks). Worklog B11 (this entry).

Stage Summary:
- CI fully green end-to-end with a verified downloadable debug APK artifact. Commits: 7056ca3 (zod schema + gradle script fixes + JDK 21), 3d632c0 (--runInBand + updateMany race fix), plus AUDIT/worklog docs.
- The whole chain of latent bugs (workflow compiler → billing → schema default → gradle DSL/cast → jest worker race) is fixed at the ROOT of each; every fix carries a local reproduction + verification except task-execution (proven by CI itself).

---
Task ID: C-W1 (a,b,c,d)
Agent: lead-architect (main session, Phase C round 1)
Task: Phase C Wave 1 — shared plumbing: monorepo hygiene (W1d), content pipeline + Part D verbatim client forms (W1c), per-user time zones (W1a), consolidated editable app config (W1b).

Work Log:
- Tagged v0.9-pre-phase-c (pushed) before any change; Phase C plan written into docs/PLAN.md.
- W1d: bun workspaces (root bun.lock only, per-app locks deleted); prisma client generated into apps/api/src/generated/prisma with src/common/prisma-client.ts re-export (the .bun store made node_modules/.prisma unreachable — 12 import sites rewritten; CI runs prisma:generate explicitly); phantom deps declared (dotenv, fontkit, @eslint/js); sandbox leftovers deleted (.zscripts, mini-services, examples, download, root tests/*.sh, root Caddyfile, apps/worker dev twin, pnpm-workspace.yaml, turbo.json); XTransformPort removed from web/admin (NEXT_PUBLIC_API_BASE is the one variable); CI permissions: contents read at top level and the report job no longer pushes ci-status.md commits to main (writes the job summary instead — it had twice collided with my pushes); ignoreBuildErrors:false both Next apps (tsc clean); react-hooks pinned 7.0.1 (7.1.1's new set-state-in-effect rule fires on ~22 pre-existing sites — TODO W4f); 5 real no-useless-assignment lint findings fixed.
- W1c: quran-meta-bn.json was {"surahs":[]} in BOTH copies (phone showed an EMPTY Qur'an list) — generated complete 114-surah metadata (Bengali+Arabic+English names, মাক্কী/মাদানী, 6236 ayahs) via packages/content/scripts/gen-quran-meta.mjs; farze_ain_v1.1 with ALL 23 criteria + instructions + both category descriptions + scale + signatures VERBATIM (stored in new AssessmentTemplate.metaJson, migration 20260928170000); level-rules.json = client's ~34-goal Muhibbus outline verbatim + LADDER FIX (Muhibbus = 4 months + head outline review (outlineReviewed attestation on POST /admin/promote) + 5 people, NO assessment; farze_ain_1/2 = the 23-criterion assessment) — loadLevelRules is per-level now; diary-instructions.json (rules 1–6 + cover quote verbatim); sync-mobile.mjs copy gate + CI 'Content parity gate' (byte-identical + non-empty packs); mobile faq/mosques {} fixed, amal-catalog/level-rules/diary-instructions copies added; seed UsrahQuestion FK crash fixed (missing table in wipe order).
- W1a: User.tz (IANA, default Asia/Dhaka; migration 20260928180000; PATCH /api/me allowlist); src/shared/tz.ts (Intl-only, DST-correct: tzOffsetMs/wallTime/wallTimeToEpoch/todayInTz/weekStartInTz/tzOffsetHoursFor); prayer-push stores REAL epochs (was Dhaka wall-as-UTC → ~6 h late pushes), per-user 'tomorrow', prayer engine fed per-user offsets; weekStartOf(tz) (was server-LOCAL); computeLockDeadline real-epoch per-user zone; streaks/entries POST/week summaries per-member today.
- W1b: AppConfigRow (migration 20260928190000) — GET /api/config serves DB row → content pack defaults → fallback; mergeConfig validates both read+write paths; GET/PATCH /api/admin/config (full_admin, audited, cache-invalidating); AppConfig gains leaderboardEnabled (scholars' gate) + detoxEnabled; mobile AppConfig model extended (ConfigContact/ConfigGroup/flags).

Stage Summary:
- Wave 1 complete + W2a (seed split) landed. Commits eb84286..0ff3079 + build fix e9d69b7.
- jest grew 133→191 (content-packs 30, tz 14, config 6, seed-split 4, corrected ladder/muhibbus tests); flutter test 69/69 (quran_meta canary 4); flutter analyze 0.
- Known deferred: set-state-in-effect refactor → W4f (rule off, TODO noted in eslint config).
- CI note: three mid-wave red web-build runs (36417635477/36418459317/36419173409) were all the same single root cause (orphaned sessionMinutes after the refs fix) — fixed in e9d69b7; both web+admin next builds verified locally after.



---
Task ID: C-W2b
Agent: lead-architect (main session, prior round)
Task: Real SMS providers + hardened OTP (Wave 2 — the "no one logs in as anyone" fix).

Work Log:
- SSL Wireless + Infobip HTTP adapters behind SMS_PROVIDER (env creds; mock only for dev/CI).
- Production boot fails fast on SMS_PROVIDER=mock or missing provider creds.
- devCode never returned outside non-production; OTPs generated with crypto.randomInt and stored hashed.
- Atomic attempt counter (updateMany — concurrent consume cannot 500, B11 lesson carried forward); @nestjs/throttler per-IP + per-phone.
- Mobile release build no longer auto-fills devCode; admin quick-login grid gated on NEXT_PUBLIC_DEMO=true.

Stage Summary:
- Commit d2285ba. CI run 36420807545 superseded mid-wave; the wave closed green on e35e8ee (run 36421191654, all jobs success).

---
Task ID: C-W2c
Agent: lead-architect (main session, prior round)
Task: Token & secret handling hardening.

Work Log:
- JWT typ claim enforced in auth.guard.ts (access vs refresh tokens cannot be swapped).
- Separate refresh secret — no fallback to the access secret; atomic rotation via updateMany ... usedAt IS NULL inside a transaction.
- Production env validation fails boot for default/missing JWT_SECRET/JWT_REFRESH_SECRET/QUIZ_SECRET and empty CORS_ORIGINS.
- CORS list applied to the socket.io gateway as well; override removed.

Stage Summary:
- Commit e35e8ee; CI run 36421191654 — all 8 jobs success (first fully green Wave-2 run).

---
Task ID: C-W2e
Agent: lead-architect (main session, prior round + this round)
Task: RLS tightening (Part A: database-level enforcement).

Work Log:
- Migration 20260928210000_rls_tightening: sl_visible_user gated to usrah_head/invigilator (roster via sl_usrah_roster() projection); DayUnlock per-command policies (read for member/supervisors, insert/update for heads+, NO delete — owner-connection-only by design); RLS on OtpCode/AuditLog/MasalaQuestion/Feedback; BEFORE UPDATE trigger blocks users changing own role/gender/usrahId; migration fallback password removed; worker no longer gets superuser DIRECT_URL in compose.
- rls.e2e.spec.ts extended to 23 tests: (meta) current_user/rolbypassrls asserts, (a) regression + positive control + other-usrah member, (b) DayUnlock member-denied/head-allowed, (c) OtpCode/AuditLog invisibility, (d) self-role/gender/usrahId trigger, (g) cross-gender admin assignment rejected + head-only reviews surface.
- admin.controller.ts gender-mismatch rejection (এক-লিঙ্গ); weekly-review fallback = same-gender invigilator, never cross-gender admin.

Stage Summary:
- Commit 0f678a5 (message was a stray UUID — content verified by this worklog entry). CI run 36423438154: 215/216, one flake in rls.e2e (g).

---
Task ID: C-W2e-flake
Agent: lead-architect (main session, this round)
Task: Fix the W2e CI flake + make rls.e2e deterministic on re-runs.

Work Log:
- Root cause 1 (CI ECONNREFUSED 127.0.0.1:45861): the spec never called app.listen(); supertest lazily binds an ephemeral port per Test and races its own close across ~75 sequential round-trips. Fix: await app.listen(0) in root beforeAll — one stable listener for the whole file; afterAll app.close() symmetric.
- Root cause 2 (local unique-constraint failure): the test cleaned up DayUnlock via rls.run/rls.system deleteMany, but RLS has NO delete policy on DayUnlock (owner-only by design) — leftover rows from earlier runs silently survived and tripped the unique (userId, date) index. CI never saw it (fresh DB per run). Fix: superuser maintenance connection (DIRECT_URL, the seed-split.spec.ts pattern) for pre/post cleanup.
- Note: an earlier cleanup attempt deleted the WRONG const head line (test (b) would have hit ReferenceError) — caught by re-running the suite before pushing; restored, and the genuinely-unused vars removed instead.
- Environment note: the sandbox tool transport was down most of this round (broken session 403); work continued via small single-command subagent dispatches.

Stage Summary:
- Commits 4f25465 + 1e7eb76. VERIFIED RAW: rls.e2e 23/23 TWICE in a row (re-runnability proof); full suite 216/216 in 7.85s; eslint 0/0 on the spec. CI runs 36436114518 (4f25465) + 36436665733 (1e7eb76) started — verdicts to be confirmed.


---
Task ID: C-W2f
Agent: lead-architect (main session)
Task: Push delivery — RFC 7523 jwt-bearer grant + device-token takeover dedup.

Work Log:
- fcm.transport.ts: grant_type switched from client_credentials to urn:ietf:params:oauth:grant-type:jwt-bearer (Google's canonical service-account form; token caching with 60s pre-expiry margin and 401-forced refresh already stood from B2 — now proven by test).
- device-tokens.service.ts: register() now takes the token over from every OTHER user first (system-context deleteMany { token, userId not self }) — FCM delivers to the device, so a leftover previous-owner row would leak the old account's notifications to the new account. Cross-user deletes are impossible under the user's own RLS context by design; the takeover is a maintenance write in the same pattern as PushService.pruneTokens.
- push.spec.ts: two new describes — (1) OAuth token exchange against a mocked endpoint: asserts the jwt-bearer grant_type, a 3-part assertion JWT with iss/scope/aud claims, caching (2nd call does NOT re-hit the endpoint), and forced refresh (2nd exchange); (2) register() takeover: the scripted RlsService records the system-context deleteMany where-clause { token, userId: { not } } before the upsert.

Stage Summary:
- VERIFIED RAW: push spec 22/22; eslint 0/0 on src/push + test/push.spec.ts; full suite 218/218 (was 216).


---
Task ID: C-W2g
Agent: lead-architect (main session) + implementation subagent
Task: Sync & guest merge hardening (server side).

Work Log:
- THE STRIP BUG (production data loss): GuestEntryDto.value and .clientUpdatedAt carried no class-validator decorators, and production's whitelist ValidationPipe strips undecorated fields — every guest diary entry was silently dropped on sign-in in production. Tests never saw it: the pipe was registered only in main.ts useGlobalPipes, so e2e test apps ran with NO validation at all. Fix: pipe moved to AppModule via APP_PIPE (one pipeline for prod AND tests) + validators added (value: custom IsValidAmalValue union constraint; clientUpdatedAt: IsString). The existing guest-merge e2e test now runs through the real pipe — it is the strip-bug proof.
- decideEntry: clientUpdatedAt clamped to now+5min (CLIENT_TS_MAX_SKEW_MS — a year-3000 stamp can no longer win forever); value validated against the amal definition's inputType (tristate/boolean/count matrix); guardSource (auto: allowlist regex, everything else → manual); newerVersion rejection now carries serverValue (the server's winning value so clients can converge).
- upsertEntries: conditional/atomic write — updateMany WHERE clientUpdatedAt < incoming (strictly-newer-wins at write time, immune to the findUnique→upsert race), absent-row create wrapped in SAVEPOINT w2g_amal_create + ROLLBACK TO on P2002 (a caught P2002 otherwise poisons the whole interactive transaction — Prisma adds no per-statement savepoints; proven empirically by the implementing agent).
- importGuestEntries: cap MAX_BATCH, unparseable-ts filtered, oldest-first ordering (newest lands last — deterministic final state), clamp, catalog-key + normalizeValue guards (guest payloads are client-controlled), guardSource, bounded 50-entry chunk transactions.
- Test fix with a story: rls.e2e (b)-1's dayUnlock.create was missing byUserId — it would have been rejected by the NOT NULL constraint even WITHOUT the RLS policy (a test passing for the wrong reason). byUserId: maleMember.id added; now only the policy can reject it.
- openapi.json + packages/shared-types/dist regenerated (previously-stale artifacts refreshed; GuestEntryDto now correctly lists clientUpdatedAt required). Known nit: POST /api/amal/entries response shape is untyped in swagger — serverValue reaches TS clients via AmalUpsertResult only (noted for W4/wave-5 hygiene).

Stage Summary:
- VERIFIED RAW: full suite 233/233 (was 218; +15 tests: clamp, inputType matrix, guardSource, serverValue, strip-bug-through-real-pipe, merge-clamp, unknown-key-dropped, merge-LWW); bunx tsc --noEmit clean; eslint 0 errors (4 pre-existing warnings in untouched files).


---
Task ID: C-W2h
Agent: lead-architect (main session) + implementation subagent (200-turn cap hit mid-verification; lead completed verification)
Task: Operations hardening — health 503, internal-only metrics/docs, structured logging, redis adapter, compose persistence.

Work Log:
- /health now returns 503 (not 200) when degraded — readiness semantics for the compose healthcheck + any LB probe.
- /metrics gated: METRICS_TOKEN set → bearer/?token required else 403; unset → non-production only. prom-client collectDefaultMetrics() added (CPU/mem/GC). Route labels stay PII-free (route templates only).
- /docs + /openapi.json gated via docsEnabled (DOCS_ENABLED env override; default off in production) — full admin-route/DTO disclosure is no longer public in prod. Setup extracted to src/common/swagger-setup.ts with a pure docsEnabled(env) unit-tested + integration-tested.
- StructuredLogger (previously dead code) wired via app.useLogger in main.ts AND worker.ts; access-log middleware logs the PATH ONLY (query strings stripped — /api/admin/users?q=<phone|name> PII was leaking into docker json-file logs, contradicting its own no-PII comment).
- socket.io Redis adapter wired (new src/common/redis-socket.adapter.ts + @socket.io/redis-adapter) — broadcasts cross-replica now. socket.io pinned 4.8.3 (apps/api + root override) to collapse a 4.8.3/4.8.4 duplicate-copy type clash. Quiz-smoke race FIXED: the pub/sub hop can deliver the first question event after host:next fired — the smoke now awaits the SPECIFIC index-1 payload (3x stable).
- compose: api host-port binding REMOVED (caddy is the only ingress; REST scales with --scale api=N — quiz rooms documented as single-instance until state is externalized); redis AOF on (appendonly yes, appendfsync everysec — queued jobs survive restarts); postgres WAL archiving ON (archive_mode + cp-to-pgwal-volume command, init-walarchive.sh creates the dir on first boot, honest Partial: scheduled pgBackRest stays owner-run per DEPLOY_COOLIFY.md); minio/mc pinned to quay.io RELEASE tags with the full story documented (MinIO withdrew from Docker Hub; last image RELEASE.2025-09-07; quay needs docker login since 2026-09-24).
- .env.example + DEPLOY_COOLIFY.md updated (METRICS_TOKEN, DOCS_ENABLED, no API_PORT, AOF, WAL).

Stage Summary:
- VERIFIED RAW: full suite 248/248 (17 suites; +15 ops tests: health 503/200, metrics gating matrix, docs gating incl. pure fn); quiz smoke OK x3 consecutive; eslint 0 errors; tsc --noEmit clean; nest build OK. Compose itself is not runnable in the sandbox — the W2d CI job is its proof (next).


---
Task ID: C-W2d
Agent: lead-architect (main session) + implementation subagent
Task: Docker images + compose smoke CI job (the Wave-2 proof-by-CI item).

Work Log:
- infra/worker.Dockerfile DELETED (its apps/worker context was removed in W1d; compose's worker reuses the api image — the story lives in the compose comments; zero remaining references in infra//docs//README).
- infra/web.Dockerfile REWRITTEN: single WORKDIR /repo; correct monorepo standalone layout (outputFileTracingRoot = repo root — server at .next/standalone/apps/web/server.js, static+public repacked beside it, stray pre-monorepo repack output stripped); runtime WORKDIR /app/apps/web + bun server.js.
- web.Dockerfile.dockerignore: blanket apps exclusion → specific siblings (apps/api, apps/admin, apps/mobile) — the old exclusion broke the Dockerfile's own COPY apps/web paths.
- api.Dockerfile: COPY content fixed to COPY packages/content — the root content/ dir was deleted in B1, so the old COPY pointed at a nonexistent path and the compose build (the W2d proof itself) could never succeed. Discovered by the implementing agent verifying against git ls-tree.
- compose: QUIZ_SECRET hard-fail wiring added to api + worker (env.validation demands it in production but compose never passed it — a real deploy would have refused to boot); METRICS_TOKEN + DOCS_ENABLED passthroughs on api.
- NEW CI docker job: compose config sanity — quay.io MinIO pre-pull with docker.io fallback + retag — build the four images — up -d --wait (health-gated) — smoke: api /health status:ok (proves migrations + seed:reference completed), web :3000 and admin :3002 HTTP 200, seeded AmalDefinition count >= 30 — always: ps + logs + down -v. 40-min timeout; gated on api+web+admin workspace probes; report job needs it.
- docs/DEPLOY_COOLIFY.md: QUIZ_SECRET documented (compose hard-fails without it).

Stage Summary:
- Local verification: CI YAML + compose YAML parse clean; API suite 248/248; eslint 0 errors; AmalDefinition catalog = 31 rows (the >=30 smoke assert holds). Docker itself cannot run in the sandbox — the CI docker job on this push IS the proof (run result to be appended below when green).

CI RUN HISTORY (the proof, appended as it happened):
- Run 5 (36453750873, ed25921) — W2d api-image fix: `nest build && cp -R src/generated dist/` in apps/api/package.json (tsc never compiled the generated JS; dist/common/prisma-client.js crashed on 'Cannot find module ../generated/prisma'). RESULT: api image FIXED — api-1 Healthy, "Nest application successfully started", listening :4000, migrations+seed ran. But the smoke failed one container later: sunnahlife-worker-1 unhealthy.
- Root cause #2 (fixed same day, 9f6617d): the compose worker service passed only SMS_PROVIDER through — not SMS_SSLWIRELESS_URL/USER/PASS — so with CI's SMS_PROVIDER=sslwireless the worker crash-looped on 'Invalid environment configuration → SMS_SSLWIRELESS_URL: … incomplete' (worker boots the same validated env with NODE_ENV=production). Hidden until run 5 because the worker depends_on a healthy api, which the pre-W2d image could never become. Worker env now mirrors the api's SMS block incl. the infobip pair.
- Run 6 (36454553711, 9f6617d): Docker — image build + compose smoke (migrate·seed·health) GREEN — full stack healthy, smoke asserts passed. The API test job flaked ONCE on test/token-security.spec.ts 'two RACING refreshes … exactly one wins' (247/248; winner's new token resolved instead of rejecting — timing-dependent, unrelated to the W2d diff which touched no API source). Re-run of failed jobs: attempt 2 fully GREEN, 248/248.
- NOTE for a later hardening pass: the racing-refresh test is flake-prone on loaded CI runners (one observed failure in two identical-code runs) — worth a retry wrapper or a deterministic interleave.


---
Task ID: C-W3b
Agent: implementation subagent (general-purpose, this round)
Task: Prayer bell scheduler — Wave 3 Part B, "what breaks on a real phone" (docs/PLAN.md ~line 543).

Work Log:
- THE KILLER FIX first: AndroidManifest.xml now declares the flutter_local_notifications receivers (ScheduledNotificationReceiver, ScheduledNotificationBootReceiver with BOOT_COMPLETED/MY_PACKAGE_REPLACED/QUICKBOOT_POWERON intent filters, ActionBroadcastReceiver — all exported=false, matching the plugin example for v18) + the RECEIVE_BOOT_COMPLETED permission. The plugin's own manifest ships only VIBRATE+POST_NOTIFICATIONS, so every zonedSchedule() bell/post-prayer notification silently never fired on a real phone; the boot receiver re-arms pending schedules after reboot/upgrade.
- tz.local real-phone bug: zonedSchedule resolves triggers through tz.local which was never set (package default = UTC — every bell shifted by the city offset). NotificationService.init() now installs the device zone via flutter_timezone 5.1.0 (getLocalTimezone → setLocalLocation; Asia/Dhaka fallback when the plugin is unavailable — tests/stubs). Note for v18: the probe API is canScheduleExactNotifications() (canScheduleExactAlarms was removed); local is set via tz.setLocalLocation (tz.local has no setter).
- Android 14 exact-alarm flow: zoned() resolves AndroidScheduleMode via canScheduleExactNotifications() — exactAllowWhileIdle when granted, inexactAllowWhileIdle otherwise; NEVER an unhandled throw (probe wrapped in try/catch). The Home _ExactAlarmCard + Kotlin PrayerChannel path are untouched and keep working.
- Monochrome icon: AndroidInitializationSettings('@drawable/ic_notification') for ALL plugin notifications + Kotlin PrayerAlarmReceiver setSmallIcon(R.drawable.ic_notification) (was applicationInfo.icon → white square).
- Rolling 3-day window: _scheduleDayAlarms (1 day, fixed 10-before/20-after, single PrayerChannel exact alarm) replaced by PrayerBellScheduler (services/prayer_bell_scheduler.dart) — today + 2 days armed idempotently per dateKey (Set<String> _armedDays + Set<int> _armedIds bookkeeping; stale days pruned at each refresh). Deterministic id scheme documented in core/bell_schedule.dart: bell=1000+dayOffset*16+waqtIndex, post=2000+dayOffset*16+waqtIndex (stride 16 > max PrayerKey.index 9 → collision-free 30 slots; day-0 reuses the historical 1000+idx/2000+idx so upgrades replace in place; disjoint from the 900+idx Kotlin exact alarms and 3000+idx confirmations).
- Reschedule triggers: city/method/madhhab change (PrayerNotifier ref.listen on profileProvider comparing PrayerBellConfig.scheduleKey — name/theme/language ignored → no alarm thrash), day rollover (ticker), app resume (SunnahLifeApp became a ConsumerStatefulWidget + WidgetsBindingObserver), bell enable, per-waqt minute change, and the daily WorkManager task. On a settings change the scheduler cancels every armed id + Kotlin alarms, then re-arms fresh.
- Post-prayer diary action buttons: the prompt notification carries three AndroidNotificationActions (amal_jamaat/amal_ekai/amal_qaza, Bengali labels জামাতে/একা/কাযা) with a JSON payload {dateKey, amalKey}. Taps while the app is dead go to the top-level @pragma('vm:entry-point') amalActionBackgroundResponse (registered via onDidReceiveBackgroundNotificationResponse in initialize()), which opens a FRESH AppDatabase() on the background isolate, writes the AmalEntry + Outbox row with writeEntry (exactly the in-app prompt's write — see value encoding below), closes, and posts a 'আমলনামায় দাখিল হয়েছে' confirmation on sunnah_life_general (Nid.amalConfirm = 3000+idx). Action taps that reach the FOREGROUND callback route through onAmalAction (wired in bootstrapProvider → AmalNotifier.write — optimistic state + shared DB + debounced sync flush). Everything try/catch — a broken button can never crash a headless app.
- VALUE ENCODING (found + mirrored exactly, per fallback_catalog.dart + home_screen's in-app prompt + server AUTO_SOURCE_RE): amalKey 'salat_<waqt>' (salat_fajr…salat_isha), value is the plain string 'jamaat' | 'alone' | 'qaza' (Drift stores it as JSON text "jamaat"; amal_engine counts jamaat/alone as 1), source 'auto:prayer:<waqt>' — NOT 'manual': the spec sketch said "source manual" but the catalog's autoSource for the five farz salahs IS auto:prayer:<waqt> and the server's guardSource AUTO_SOURCE_RE (^auto:[a-z]+(:[a-z0-9_]+)?$) trusts it, so the notification write is indistinguishable from the in-app prompt write (identical rows merge cleanly in sync). Deviation noted, intentional.
- Per-row "N minutes": bellmin_<waqt> (0–60, default 10) + postmin_<waqt> (5–120, default 20) SharedPreferences ints, clamped through pure helpers. UI: long-press a schedule-row bell → bottom sheet with two sliders (Bengali digits via toBn in bn) + reset + done, saving via PrayerNotifier.updateBellMinutes (re-arms the window). New ARB keys bell_minutes_title/before/after/reset/done added to ALL THREE arb files (413 keys each), gen-l10n + tool/make_arbs.py --keymap regenerated; the ARB consistency + keymap tests stay green.
- Daily WorkManager: workmanager 0.10.10 initialized in main() with top-level prayerBellCallbackDispatcher; unique periodic task 'prayer-bell-refresh' (24h, ExistingPeriodicWorkPolicy.keep) runs refreshPrayerBellsFromDb() — profile read from the local Drift GuestProfile row, adhan_dart is pure Dart so the background compute is isolate-safe; task failure returns false (backoff retry) and never blocks boot (init wrapped in try/catch; tests never run main()).
- Widget snapshot (C-W3f foundation): new services/widget_snapshot.dart writes {city, dateKey, times: HH:mm for ALL 10 waqts, nextKey, nextAt (epoch millis, crosses midnight into tomorrow's fajr), nextLabelBn} to SharedPreferences 'widget_snapshot' after every prayer tick; failure-swallowed, fire-and-forget.
- Known edges (honest): (a) an action tap while the app is ALIVE but the diary screen open writes via the background isolate, so the in-memory AmalNotifier state catches up on next load/hydrate — the in-app prompt card remains the visible surface in that scenario; (b) the background isolate's fresh Drift connection + the main connection can contend on the sqlite file only if both write in the same instant (try/catch'd, tap lost but never a crash); (c) when the profile change listener fires, the GuestProfile row write may still be in flight — which is why the foreground path passes the RIVERPOD profile (fresh) and only the WorkManager background path reads the DB row.
- Commits (b78841d → 52c8b03, all on main, pushed):
  · b78841d fix(C-W3b): declare the flutter_local_notifications receivers — zoned bells silently never fired on real phones
  · 4c356f9 fix(C-W3b): tz.local via flutter_timezone + inexact-alarm fallback + monochrome notification icon
  · fdbbfec feat(C-W3b): rolling 3-day bell window + reschedule on city/madhhab/method change
  · a89e131 feat(C-W3b): post-prayer জামাতে/একা/কাযা action buttons write the diary
  · a2d46de feat(C-W3b): per-row 'N minutes before/after' — long-press a bell for the timing sheet
  · a903d78 feat(C-W3b): daily WorkManager re-arm + widget snapshot writer
  · 52c8b03 test(C-W3b): bell-schedule pure logic — ids, clamps, payloads, triggers, snapshot
- Scope kept: apps/mobile only (manifest, Kotlin receiver icon, Dart); workflow/api/web/admin/packages untouched; DND + widget Kotlin handlers in MainActivity.kt untouched.

Stage Summary:
- flutter analyze: 0 issues. flutter test: 87/87 (was 69; +18 in test/bell_schedule_test.dart: id scheme determinism/collision-freedom/historical-id reuse, minute defaults + clamps, payload round-trip + malformed nulls, action-id→value mapping, salat key/source mirroring, reschedule-trigger detection incl. no-op profile fields, widget snapshot JSON shape + midnight wrap).
- VERIFIED RAW (tails, re-run after the final commit):
  flutter analyze:
    Analyzing mobile...
    No issues found! (ran in 1.3s)
  flutter test (tail):
    00:15 +85: /home/z/my-project/apps/mobile/test/deep_links_test.dart: deepLinkToRoute — guards plain in-app paths pass only when whitelisted
    00:16 +85: loading /home/z/my-project/apps/mobile/test/text_scale_test.dart
    00:16 +85: /home/z/my-project/apps/mobile/test/text_scale_test.dart: Amal hub lays out cleanly at 1.0x text scale
    00:17 +86: /home/z/my-project/apps/mobile/test/text_scale_test.dart: Amal hub lays out cleanly at 1.3x text scale
    00:17 +87: All tests passed!
- Manifest/gradle proof for CI: manifest is XML-parse-clean; the receivers + RECEIVE_BOOT_COMPLETED are committed statics (repo CI runs analyze+test on this push); no gradle change was needed (workmanager 0.10.x auto-initializes via androidx.startup, plain periodic task — no FGS type involved).

---
Task ID: C-W3a
Agent: lead-architect (main session) + implementation subagent (context cap hit mid-verification; lead completed verification + goldens)
Task: Qur'an reader — Part B real-phone items (isolate parse, first-open race, FutureBuilder bugs, recitation audio, go-to-ayah, resume, goldens).

Work Log:
- Subagent landed 458f9a8 + 4cb5909: compute() decode of the three packs (meta 38KB, Uthmani 2.1MB, bn 2.9MB) off the UI isolate; single-flight _ensureLoaded + per-surah _pendingSurah memoization (the first-open race — AppBar title + body FutureBuilders shared one load); search TextField hoisted out of the list FutureBuilder (typing no longer unmounts the field → keyboard stays open); reader futures memoized in initState (translation toggle + bookmark writes never change future identity → no scroll jump); resume-from-last-read honors lastReadAyah; go-to-ayah dialog parses Bengali AND ASCII digits with two-step jump (estimateJumpOffset coarse + Scrollable.ensureVisible exact, GlobalKeys per ayah); per-ayah recitation via just_audio 0.10.6 — LockCachingAudioSource disk cache, auto-advance, AppBar stop, gold-highlight playing ayah, 4-reciter bottom sheet persisted as quran_reciter, audio errors → SnackBar; audioBase honesty: download.quranicaudio.com serves PER-SURAH files only (live-verified 001001.mp3 → 404 vs 001.mp3 → 200) so per-ayah playback uses everyayah.com layout, audioBase stays the admin on/off gate. ARB keys + gen-l10n + keymap regenerated (420 keys × 3).
- LEAD DEBUG (the session's big catch): the subagent's memoization returned `_pendingSurah[n] ??= _buildSurah(n).whenComplete(() => _pendingSurah.remove(n))` — and that future NEVER completes on Dart 3.13.4. Bisected empirically through 17 minimal probes: the body runs to completion (caches filled), but the whenComplete-wrapper that ??= assigns+returns stays pending forever; hangs with OR without .timeout(), with OR without compute — i.e. a PRODUCTION deadlock on every first reader open, not a test artifact. The toxic shape needs both ??=-into-map AND the callback removing from that same map. Fixed by storing the inner future first and wrapping a local; regression group added that pins the toxic shape (asserts TimeoutException) and the safe shape (asserts resolution + map cleanup). _ensureLoaded restructured identically (defensive).
- compute() bypass under FLUTTER_TEST env (flutter#98362-style runner hang: tests decode inline; production always isolates).
- parseBnDigits ('1৭' → 17 bug): now enforces its own doc contract — mixed scripts → null.
- Goldens (shipped by lead): test/quran_golden_test.dart + 4 committed PNGs — list bn light, reader bn light / bn dark / ar RTL, reached via real navigation with the real 5MB packs. Determinism: configProvider overridden (audio OFF regardless of runner network), GoogleFonts runtime fetching off, families pre-warmed through google_fonts' OWN loadFontIfNecessary (manual FontLoader registration does NOT feed its cache — first capture rendered tofu until the warm went through the style builders), packs pre-warmed under tester.runAsync with the injectable File loader (rootBundle never completes inside fake-async), fixed 800×1600 @ DPR 1.0. All four VLM-verified: proper UI, Arabic script legible everywhere.

Stage Summary:
- Commits 458f9a8, 4cb5909 (subagent) + 6827ee1, efcc2a7 (lead), all pushed.
- VERIFIED RAW (after final commit): flutter analyze → "No issues found! (ran in 1.7s)"; flutter test → "+117: All tests passed!" (was 87 after W3b; +30: reader unit suite incl. the Dart-hazard regression group, +3 goldens... final count 117).
- The Dart 3.13.4 hazard is the headline: caught before shipping because the subagent's own test suite hung and the lead bisected instead of dismissing it as test flakiness.
- Known honest edges: audio quality/latency on a real phone NOT device-verified (CI builds prove compile; audio play needs the owner's phone); goldens are Linux-rendered and pinned to Flutter 3.47.5 == CI's pin — if CI flakes on font rasterization the fallback is regenerating on a runner and committing those.

---
Task ID: C-W3d
Agent: lead-architect (main session) + implementation subagent (context cap hit during final verification; lead finished the last polish + verified)
Task: Sync pull client side — cursor pull on login/app-start, bounded outbox retries, unstuck syncing, visible sync state.

Work Log:
- 4c3f52e (subagent): cursor-based pull on login + app-start-after-hydration (guest→signedIn auth listener) + manual sync-now; watermark in SharedPreferences 'sync_pull_cursor' (from = watermark − 3d overlap, bounded 95d first pull); merges through the existing client-side LWW mergeServerEntries; kept OUT of the 60s loop. Rejected entries stop retrying: attempts incremented (the column finally used), reason captured (AmalRejectInfo parses the W2g serverValue); serverValue present ⇒ converge locally through the merge path + dead in one round, else kMaxOutboxAttempts=5 then dead. Outbox schema v1→v2 (last_error, dead_at — additive ALTERs via MigrationStrategy). flush() try/finally resets syncing on EVERY error path (was only ApiException — a TypeError stuck the spinner and blocked all future flushes until restart). SyncBadge: idle/syncing/pending-N/dead-M(error) + tap opens the new sync sheet (counts, last-sync, dead list w/ retry+discard, sync now); 8 new ARB keys ×3 locales.
- a139a24 (lead): golden of the sync sheet (bn light, pending=2 + dead=1, pinned clock so the relative-time label never drifts; determinism mirrors the quran golden — fonts warmed through google_fonts' own loadFontIfNecessary); raw v1→v2 outbox migration test through the REAL MigrationStrategy on a raw sqlite file (sqlite3 dev-dep, drift generates only the latest schema); sheet label styles pinned to the overridden body styles (titleSmall/labelLarge are not in the app text theme → tofu in golden env); pull() success no longer clears push error messages; dispose()→close() drift deprecation; removed the tmp_probe scratch dir.
- Known honest edges: pull window is date-based (watermark = dateKey, overlap 3d) rather than a server-issued cursor token — the server's /api/amal/entries is range-based (from/to), so the watermark IS the cursor; entries older than the first-pull bound (95d) never backfill — documented in sync_policy.dart.

Stage Summary:
- Commits 4c3f52e + a139a24, pushed.
- VERIFIED RAW (after final polish): flutter analyze → "No issues found! (ran in 1.4s)"; flutter test → "+138: All tests passed!" (was 117; +21: retry/dead policy matrix, watermark math, flush-finally semantics, pull idempotence, v1→v2 migration, sheet golden ×1).
- Golden VLM-verified (Bengali readable, sync-now + failed-entries visible).

---
Task ID: C-W3i
Agent: lead-architect (main session)
Task: APK size + release CI — split-per-ABI release APK job so the owner can test a release build on the phone.

Work Log:
- apps/mobile/android/app/build.gradle.kts: the debug-only keepDebugSymbols escape hatch REMOVED (PLAN item) — CI runners provide the NDK so debug APKs strip normally now (artifact shrinks from the 1.1 GB universal); the defaultConfig ndk.abiFilters arm64-v8a line removed too — it was a misleading NO-OP (run #25's debug artifact shipped all 3 engine ABIs despite it; the flutter tool owns ABI selection, and a stray filter can only confuse the release split). R8/minify deliberately NOT enabled this round: the split alone meets the < 40 MB arm64 target, and shrinking needs a device smoke before trusting plugin reflection (workmanager, notification receivers) — decision documented in the gradle comment.
- .github/workflows/ci.yml NEW JOB release-apk (NOT secrets-gated — the whole point is the owner tests a release build TODAY): JDK 21 + Flutter 3.47.5 (same pins as mobile) + gradle cache → decode keystore IF secrets exist (absence = ::notice::, not a skip) → flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 → sizes table into $GITHUB_STEP_SUMMARY → HARD gate: arm64-v8a ≥ 40 MB fails the job (PLAN W3i target) → two artifacts with signing-aware names: mobile-release-<abi> (store-signed) or internal-test-<abi> (debug-signed via the build.gradle fallback — installable on a phone, not uploadable to Play).
- report job needs + summary table extended with the release-apk row.

Stage Summary:
- Commit ee50630, pushed. YAML parse-clean (python yaml.safe_load). Gradle is static-verified only in the sandbox (no NDK/disk) — the CI run IS the proof (docker-job precedent): run for ee50630 started; verdict to be appended when complete. NOTE: concurrency cancel-in-progress cancels superseded runs — only the FINAL push's run carries the full proof (W3a + W3d + W3i together).

---
Task ID: C-W3c
Agent: implementation subagent (general-purpose, this round)
Task: Location, qibla, mosques (docs/PLAN.md ~line 551).

Work Log:
- Packages: geolocator ^14.0.2 (location + permission flow) + flutter_compass ^0.8.1 (magnetometer heading). NOT added: flutter_map (deviation, see below).
- core/location_service.dart (NEW): pure snapToNearestCity(lat,lng,cities) — great-circle over all 85 CityEntry rows, returns CitySnap {city, raw lat/lng fix, accuracyM, distanceKm} + approximate flag (>50km ⇒ UI must label অনুমান); pure locationGate({serviceEnabled, permission}) state machine (denied→requestPermission, deniedForever→openSettings, serviceOff→openLocationSettings, whileInUse/always→fetchPosition, unableToDetermine→blocked — every enum value covered); thin LocationService wrapper is the ONLY geolocator touchpoint (never invoked in tests) mapping every platform failure to typed LocationFailureException{serviceOff, permissionDenied, permissionDeniedForever, timeout, unavailable} — geolocator exceptions never reach widgets. currentSnapIfGranted() = silent no-prompt probe (mosques screen opens without a permission dialog). Balanced-power accuracy + 20s timeLimit (city-level snap doesn't need GPS-grade power draw).
- core/qibla.dart: + bearingDeg(fromLat,fromLng,toLat,toLng) — the general initial great-circle bearing (qiblaBearing is its Kaaba-fixed special case); mosque arrows use mosque-from-user.
- core/compass_quality.dart (NEW): compassSignalQuality({accuracy, recentHeadings}) — jitter-first heuristic (Android's flutter_compass accuracy values are hard-coded in the plugin, so ≥2 consecutive swings >20° or a >25° circular spread over the last 8 events ⇒ poor); iOS-reliable accuracy >15° alone ⇒ poor; null accuracy + short window ⇒ good (no nag without evidence).
- City picker (features/shared/city_picker.dart): the stale "GPS option (manual coordinates fallback)" comment is now real UI. "GPS দিয়ে খুঁজুন" row above the search → locating spinner → confirm row "আপনার অবস্থান: <city> (±N মি) [· অনুমান + far-note]" → tap pops the snapped CityEntry through the SAME path as a manual pick (onboarding + profile screen both already route into profileProvider.update → prayer times, home header, bells all follow; nothing re-wired). Failures: denied → friendly message, list stays browsable; deniedForever → "সেটিংস খুলুন" button (Geolocator.openAppSettings); serviceOff → "লোকেশন চালু করুন" (openLocationSettings); the error row itself is the retry. No dead ends.
- Qibla screen: flutter_compass stream → dial rotation = −heading (north tick tracks real north; the fixed-up indicator + qibla arrow then point the Kaaba relative to the phone). HEADING SEMANTICS (verified against the plugin's native sources, documented in-code as compassHeadingIsTrueNorth): iOS = CLLocationManager.trueHeading ⇒ TRUE north; Android = SensorManager.getOrientation() on ROTATION_VECTOR ⇒ MAGNETIC north, and the plugin applies NO GeomagneticField declination — neither do we (honest note: declination ≈1° in Bangladesh, small against the uncalibrated-magnetometer error the calibration hint exists for; the manual dial is the exact fallback; a per-fix declination method-channel was judged not worth the surface). Figure-8 calibration card (l10n) shows while quality is poor. Probe hardening: null heading, NEGATIVE heading (iOS trueHeading-unavailable sentinel), stream error (MissingPluginException on desktop), stream done, or total silence for 2s all degrade to the manual dial — never crashes, never dead-ends. GEOMETRY FIX: the qibla arrow now rides the dial (arrowAngle includes rotation — the old fixed-on-card arrow was only correct at rotation 0, so the manual slider was geometrically wrong; qibla_dial_hint reworded in all 3 locales to "turn the dial until N points north"). Distance + bearing numbers unchanged (they were good).
- Mosques screen: "আমার কাছাকাছি" — silent probe on open (no prompt), prompted flow via the button; mode label states the active origin ("আপনার অবস্থান থেকে (±N মি)" vs "এই শহর থেকে: <city>") + one-tap switch back to city mode. Distance/bearing computed from the RAW fix (not the snapped city center); each row gains a bearing arrow rotated by mosque-from-user bearingDeg (NOT kaaba) with a Semantics label; distances in Bengali digits via toBn. Denials → SnackBar; the city-sorted list always stays usable. Bundled mosques.json untouched — no API change.
- City-in-header (PLAN item): VERIFIED, no code needed — home_screen.dart already renders a location row from profileProvider (findCity(profile.city)); the GPS confirm flows through profileProvider.update so the header follows automatically. W4a owns global chrome; nothing new built here.
- AndroidManifest: ACCESS_COARSE_LOCATION + ACCESS_FINE_LOCATION added (coarse covers Android 12+ "approximate" grants). iOS Info.plist: NSLocationWhenInUseUsageDescription added (Bengali, matches the app's primary locale). iOS config exists in-repo, so it was updated.
- l10n: 23 new keys × bn/en/ar (451 total, consistency test green): gps_* family, unit_m, qibla_compass_heading/calibration_title/calibration_hint/compass_unavailable, mosques_near_me/from_city/from_location/use_city, mosque_direction; qibla_dial_hint value corrected in all three. flutter gen-l10n + tool/make_arbs.py --keymap regenerated.
- DEVIATION from PLAN (documented per task): flutter_map + OSM tiles + "nearby mosques from API" SKIPPED — the server has no mosques endpoint and the bundled pack is 24 Dhaka mosques; a 20-row distance/bearing list beats shipping a tile engine (APK size + a WebView-class dependency surface) for that dataset. Revisit in W4 if the server grows a mosques endpoint (a real map needs real data).
- Scope kept: apps/mobile only. Untouched: CI workflow (W3i), prayer bells (W3b), quran reader (W3a), sync (W3d), apps/api/web/admin/packages, MainActivity.kt (no Kotlin needed — geolocator/flutter_compass are pure plugin declarations). The Dart 3.13.4 never-completing-future hazard (W3a) is not present anywhere: no map[k] ??= fut.whenComplete(remove) pattern was written (the compass stream has no memoization; verified by reading the new code before commit).
- Commits (443f9b0 → e5ade9e, all on main):
  · 443f9b0 feat(C-W3c): location service — snap-to-nearest-city + permission gate + bearing math
  · f81f7d4 feat(C-W3c): l10n — 23 GPS/qibla/mosque keys × bn/en/ar + geometry-correct dial hint
  · 17fe0ba feat(C-W3c): GPS দিয়ে খুঁজুন in the city picker — locate, snap, confirm
  · f7db100 feat(C-W3c): qibla live compass + figure-8 calibration card, manual dial fallback
  · 665a25b feat(C-W3c): আমার কাছাকাছি — mosques from the real GPS fix, list-first
  · e5ade9e test(C-W3c): pure location/qibla logic — 26 tests, no platform channels

Stage Summary:
- VERIFIED RAW (after the final commit e5ade9e):
  flutter analyze:
    Analyzing mobile...
    No issues found! (ran in 2.2s)
  flutter test (tail):
    00:25 +162: /home/z/my-project/apps/mobile/test/text_scale_test.dart: Amal hub lays out cleanly at 1.0x text scale
    00:26 +163: /home/z/my-project/apps/mobile/test/text_scale_test.dart: Amal hub lays out cleanly at 1.3x text scale
    00:26 +164: All tests passed!
- flutter test: 164/164 (was 138; +26 in test/location_qibla_test.dart: snap matrix incl. mid-Atlantic→New York approximate + the 44.5/55.6km threshold either side of 50km, known-pair distances ±1% (Dhaka–Kaaba 5172, Dhaka–Kolkata 250.6, Chattogram–Dhaka 214), bearingDeg cardinals + Dhaka qibla 277.6° + forward/reverse ±180°, full locationGate matrix, compassSignalQuality (accuracy-only / jitter / spread / settled / angDist wraparound), mosque sorting city-vs-GPS + immutability + raw-fix origin + mosque-bearing ≠ qibla). No platform channel touched in tests — only the LocationPermission enum is imported.
- Known honest edges: (a) real-device GPS/compass behavior is static-verified only in the sandbox (no sensor) — the CI release-apk job (W3i) is the on-phone proof, and the manual fallbacks mean a bad sensor can never dead-end the screens; (b) Android magnetic-north declination uncorrected (≈1° in BD, documented); (c) geolocator_android uses flutter.compileSdkVersion — same as the app's gradle, no compileSdk conflict with CI's Flutter 3.47.5; (d) mosque bearing arrows assume the user holds the phone flat/screen-up like a map — the label states the mosque direction, matching the qibla dial's mental model.

---
Task ID: C-W3i-CI
Agent: lead-architect (main session)
Task: CI proof collection for the W3i release job (appendix to C-W3i).

Work Log:
- Run 36474538959 (f562208, covers the full W3a+W3d+W3i state): ALL TEN jobs success — including the NEW 'Flutter — release APKs · split-per-ABI (device test)' job on its first execution.
- RAW from the job log (job 109104918178): `-rw-r--r-- 26665649 app-arm64-v8a-release.apk` (25.4 MB) and `24435193 app-armeabi-v7a-release.apk` (23.3 MB) — the < 40 MB PLAN target passes with 14.6 MB headroom on arm64.
- Artifacts (no keystore secret configured → debug-signed device-test names, exactly per design): internal-test-arm64-v8a (13.28 MB zipped), internal-test-armeabi-v7a (12.74 MB zipped). THE OWNER'S PATH: Actions → run → artifacts → download internal-test-arm64-v8a → unzip → install on the phone (enable install-unknown-apps for the browser/files app first). NOT uploadable to Play (debug-signed) until the owner adds the ANDROID_KEYSTORE_BASE64 secret family — then the same job produces store-signed mobile-release-<abi>.
- Bonus proof: mobile-debug-apk artifact shrank from 386 MB to 87.76 MB zipped after the keepDebugSymbols removal (run #25 vs this run) — the debug strip now runs on CI as intended.

Stage Summary:
- C-W3i is CI-PROVEN GREEN on first execution: split-per-ABI release APKs + sizes + the 40 MB gate + signing-aware artifact names. No follow-ups needed.

---
Task ID: C-W3e
Agent: implementation subagent (general-purpose, this round)
Task: Auto-silent — settings screen + jama'at window scheduling (docs/PLAN.md ~line 559; Kotlin DND handlers existed with zero call sites).

Work Log:
- DND SCHEDULING APPROACH (the design decision): DND is a ringer change, NOT a notification — flutter_local_notifications cannot run background actions. Implemented the Kotlin AlarmManager path: new channel methods scheduleAutoSilent(id, epochMillis, on) + cancelAutoSilent(ids) in MainActivity.kt arm PendingIntent alarms (requestCode = the Dart-owned Nid id) to a new AutoSilentReceiver (BroadcastReceiver, exported=false, manifest-declared). The receiver runs WITHOUT the Flutter engine — the ringer flips even when the app was never opened that day. Exact alarm guarded like W3b: setExactAndAllowWhileIdle when SCHEDULE_EXACT_ALARM is granted, setAndAllowWhileIdle (inexact, no permission needed) otherwise — a slightly-late ringer change beats nothing (documented in-code). Deviation from the task sketch: scheduleAutoSilent carries an id (multiple windows are pending simultaneously — distinct request codes are required) and cancelAutoSilent takes the id list rather than being no-arg, keeping the Kotlin side 100% scheme-agnostic (the Dart Nid owns the id space).
- Kotlin AutoSilent object (shared by the MainActivity channel handler AND the receiver — they can never diverge): isGranted + apply(context, enabled). apply writes an `autosilent_engaged` marker (app default SharedPreferences, non-flutter-prefixed key — no collision with the plugin cache) when WE silence; the restore branch only clears that marker's silence, so a window end never switches off a DND mode the USER turned on. SecurityException-safe, permission-checked at fire time (a revoked grant degrades to a no-op).
- NO BOOT RECEIVER for auto-silent (per task): Android clears alarms on reboot; the Dart refresh (app open / resume / day rollover / settings change) re-arms. Honest edge #1: after a reboot the silent windows resume on the next app open — a boot receiver would need the DND grant + settings state behind the Dart scheduler to be honest.
- Scheduling hook (add, don't rewrite): PrayerBellScheduler._scheduleAutoSilentWindows runs at the END of refresh() — the SAME rolling 3-day window + the same triggers as the W3b bells (app start, day rollover, profile change via reset(), resume, the daily WorkManager task). Own idempotency set _armedSilentDays so bell toggles never thrash ringer arms and vice-versa; per-day arms are future-edges-only (mid-window re-arm keeps the restore edge: a start already past is skipped, an end still future arms alone). reset() (profile change) cancels + restores. Skips arming entirely when autosilent_enabled is off or isDndGranted() is false (saves useless pending alarms; the receiver re-checks at fire time anyway).
- Ids: Nid gains autoSilentOnBase 4000 / autoSilentOffBase 5000 (+ dayOffset*16 + PrayerKey.index — same stride-16 scheme as 1000/2000/3000/900, collision-free by construction, tested) + autoSilentAllIds() = the deterministic 96-id cancel set (one channel call; no bookkeeping can go stale across process death).
- Settings screen (features/more/auto_silent_screen.dart, More-grid entry + /more/autosilent route): explain card (why DND access), status row + grant button → PrayerChannel.requestDndAccess() → ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS, re-check via WidgetsBindingObserver on resume + a refresh AppBar action + one poll after the launch (the system screen delivers no result). Master switch, "N মিনিট সাইলেন্ট" slider (10–90, default 30, Bengali digits), five-farz SwitchListTile matrix, prefs autosilent_enabled / autosilent_<waqt> (default ON) / autosilent_min.
- MID-WINDOW SAFETY (the subtle part): any settings change cancels the whole deterministic id space BEFORE re-arming — re-arm only REPLACES the ids it still schedules, so a waqt switched off would otherwise leave its old edges pending. _restoreIfOrphaned(wasActive) then restores the ringer NOW if the active window lost its future restore edge (master off, waqt off, or minutes shortened past now — the slider mutates live, so the OLD persisted minutes are recovered to judge the pre-change window). A no-op when this app isn't the one silencing (engaged-flag). reset() (city/method/madhhab change) also restores for the same reason.
- l10n: 14 new keys × bn/en/ar (465 total): more_autosilent, autosilent_explain_title/body, dnd_status, granted/not_granted, grant, recheck, return_hint, master, minutes_label, minutes_suffix, waqts_title, reboot_note. flutter gen-l10n + tool/make_arbs.py --keymap regenerated; ARB consistency + keymap tests stay green.
- The Dart 3.13.4 hazard (W3a): no map[k] ??= fut.whenComplete(remove) pattern anywhere in the new code (verified by reading before commit).
- Commits (all on main, pushed):
  · 1dbab5c feat(C-W3e): pure jama'at silent-window logic — clamps, prefs codec, arms, Nid ids
  · 7f18060 feat(C-W3e): Kotlin AutoSilentReceiver + PrayerChannel arms + rolling-scheduler hook
  · 2ceac13 feat(C-W3e): অটো-সাইলেন্ট settings screen — DND grant flow, per-waqt matrix, minutes
- Scope kept: apps/mobile only; workflow/api/web/admin/packages untouched; W3b bell logic untouched beyond the parallel hook + reset additions.

Stage Summary:
- flutter analyze: 0 issues. flutter test: 184/184 (was 164; +20: 19 in test/auto_silent_test.dart — minute clamp, prefs-key stability + round-trip incl. clamp-on-read, window = waqt-start→+N, per-waqt enable matrix, empty-set honesty, arm ids/mid-window/fully-past cases, state machine off/not-granted/3-day-rolling/no-waqt, Nid disjointness + stride collision-freedom + autoSilentAllIds coverage; +1 widget-snapshot Kotlin contract test that belongs to C-W3f).
- VERIFIED RAW (after the final commit, re-run):
  flutter analyze:
    Analyzing mobile...
    No issues found! (ran in 1.4s)
  flutter test (tail):
    00:27 +182: /home/z/my-project/apps/mobile/test/text_scale_test.dart: Amal hub lays out cleanly at 1.0x text scale
    00:28 +183: /home/z/my-project/apps/mobile/test/text_scale_test.dart: Amal hub lays out cleanly at 1.3x text scale
    00:28 +184: All tests passed!
  auto_silent_test.dart alone: 00:00 +19: All tests passed!
- Known honest edges (device checklist — no PHONE_TEST_CHECKLIST.md exists yet, it is the Wave-5 deliverable; these belong on it): (a) real DND flip behavior + the Android 14 exact/inexact ringer timing is static-verified only in the sandbox — the CI release-apk job's internal-test artifact is the on-phone proof; (b) after a reboot, silent windows resume on the next app open (no boot receiver by design); (c) the daily WorkManager background engine cannot re-arm the Kotlin ringer alarms (the background Flutter engine has no MainActivity channel handlers — every PrayerChannel call is MissingPluginException-swallowed there): the auto-silent windows re-arm when the app is next opened, unlike the plugin bells which DO re-arm from background; (d) if the user sets their OWN DND during one of our windows, the window-end restore clears it (Android exposes no "who set this filter" API — the engaged-flag only protects the reverse direction); (e) isDndGranted is probed per refresh while the feature is on (a handful of calls/day at most — refresh is not the per-minute ticker).

---
Task ID: C-W3f
Agent: implementation subagent (general-purpose, this round)
Task: Home widget — persist + background refresh, no "--:--" reset after process death or reboot.

Work Log:
- WIDGET BOOT/RENDER DESIGN: PrayerWidgetProvider.kt is rewritten around a WidgetRender object that owns ONE view-binding — renderInto(views, content) — used by BOTH the live engine push (MainActivity's sunnahlife/widget channel → pushLive) and the persisted read (renderFromSnapshot). The two paths can never diverge again. The old companion pushUpdate is gone (its one call site swapped).
- Persisted path: onUpdate + a custom ACTION_RENDER (manifest intent-filter + onReceive) render from the W3b snapshot in Flutter's DEFAULT SharedPreferences — key "flutter.widget_snapshot" (flutter. prefix on the plain key, verified against the plugin's storage layout; the read lives in WidgetRender.readSnapshotContent). Rendering rules: nextAt in the future → nextLabelBn + "H ঘ M মি" countdown in Bengali digits (identical format to the live path, Kotlin-side toBn mirror). nextAt past → the next farz slot from the times map, extended +24h/day up to 2 extra days (the SAME ±1–2 min/day midnight approximation the Dart writer itself makes), label from a Kotlin mirror of prayerLabelsBn. Beyond that → honest "ওয়াক্ত পার হয়েছে" stale marker + city (falls back to the app name — never a silently blank tile). Malformed/missing JSON never crashes a widget broadcast (returns null → keeps previous views).
- Boot restore: WidgetBootReceiver (BOOT_COMPLETED + MY_PACKAGE_REPLACED, exported=false, RECEIVE_BOOT_COMPLETED already in the manifest from W3b) → render from the snapshot + re-arm the periodic re-render. Periodic re-render: AlarmManager.setInexactRepeating, ~15 min, non-wakeup RTC — a clock-ish tile tolerates drift and misses while asleep coalesce on wake (exactly when the widget becomes visible); an exact chain would burn the SCHEDULE_EXACT_ALARM budget. Tradeoff documented in-code. updatePeriodMillis stays 1800000 (30 min) as the cheap system backstop — comment added to widget_prayer_info.xml.
- DART SNAPSHOT SHAPE: UNCHANGED from W3b ({city, dateKey, times: HH:mm × all 10 waqts, nextKey, nextAt epoch-millis int, nextLabelBn}) — verified against the Kotlin parser field-by-field; the W3b snapshot tests needed no expectation changes. Added one contract test (bell_schedule_test.dart "Kotlin reader contract") pinning the exact key set, types (nextAt stays an int, never a double), the 10 HH:mm slots and non-empty strings — a Dart-side shape change that keeps the old tests green but breaks the headless Kotlin parser now fails.
- Background freshness (beyond the task's minimum): PrayerBellScheduler.refresh takes an optional city and rewrites the snapshot from the SAME nextKey/nextAt computation the live ticker uses — so the daily WorkManager task (which runs a background Flutter engine with shared_preferences available) keeps the widget fresh INDEFINITELY, not just ~1 day. Callers: PrayerNotifier.refreshBells passes profile.city; refreshPrayerBellsFromDb passes the Drift GuestProfile row's city. Failure is swallowed inside the writer (unchanged).
- Honest edges: (a) the +24h extension drifts up to ~2–3 min by day 2 — acceptable for a countdown tile, and the first app open re-syncs exactly; (b) if the widget is added BEFORE the app ever ticks, the initial layout placeholder shows until the first app open (no snapshot exists to render); (c) the alarm re-render + boot restore + snapshot read are Kotlin-static-verified only in the sandbox — the device checklist (Wave-5 PHONE_TEST_CHECKLIST.md) must cover: add widget → kill app → countdown keeps ticking; reboot phone → widget renders (not placeholder); airplane-mode weekend → stale marker + city appear ~2 days after the last app open; tap → opens the app.
- Commit: 1ed752a feat(C-W3f): widget renders from the persisted snapshot — no reset after process death or reboot (includes the scheduler city-threading + contract test).

Stage Summary:
- flutter analyze: 0 issues. flutter test: 184/184 (+1 over C-W3e's count: the Kotlin reader contract test).
- VERIFIED RAW (after the final commit):
  bell_schedule_test.dart (tail):
    00:00 +16: widget snapshot writes the full JSON shape + midnight wrap
    00:00 +17: widget snapshot HH:mm formatting is zero-padded + wraps defensively
    00:00 +18: widget snapshot Kotlin reader contract — field set, types, HH:mm slots
    00:00 +19: All tests passed!
  Manifest + widget XMLs: python xml.dom.minidom parse-clean; manifest receiver comments checked for XML-illegal double hyphens (one was caught + fixed pre-commit).
- Kotlin is static-reviewed (no gradle in the sandbox — no NDK/disk): the CI release-apk job on this push is the compile proof; on-phone behavior belongs to the device checklist above.

---
Task ID: C-W3g
Agent: implementation subagent (general-purpose, this round)
Task: Hijri adjust + donation — admin /api/config hijri ±1 applied to the mobile date bar; donation link opens in-app browser (Custom Tabs) (docs/PLAN.md ~line 564).

Work Log:
- VERIFIED the stated current state first: home date bar used ONLY profile.hijriAdjust (local ±2 from the profile screen); configProvider parses GET /api/config's hijriAdjust but it was consumed NOWHERE; the zakat CTA copied donationUrl to the clipboard (no url_launcher); no Donate entry on More; offline fallback hardcoded nisab 11500/135 while packages/content/app-config.json says 16500/220.
- effectiveHijriAdjust(user, admin) in core/calendars.dart — pure SUM of the two ±day corrections (user ±2 profile + admin ±2 config, both are corrections from different actors) clamped to −4..4. effectiveHijriAdjustProvider (remote_state.dart) combines profileProvider + configProvider (loading/offline config contributes 0). Wired into EVERY hijriDate consumer: home date bar (home_screen.dart) AND the ayyam-beez cadence (today_screen's isAmalDay — searched all call sites; month grid renders no Hijri dates). The admin's moon-sighting correction now propagates consistently.
- Fallback alignment: kFallbackGoldPerGramBdt 11500→16500, kFallbackSilverPerGramBdt 135→220, kFallbackDonationUrl 'https://sunnahlife.app/donate'→'https://as-sunnah.org/donation' (remote_state.dart, keep-in-sync comment). Mobile cannot import packages/content — the parity is pinned by a TEST that READS ../../packages/content/app-config.json (flutter test CWD = apps/mobile) and asserts equality, so drift fails CI. quran_golden_test's offline config now references the shared constants (can never drift again).
- Donation in-app browser: url_launcher 6.3.2. core/external_urls.dart — isLaunchableHttpUrl (pure gate: http/https only; empty/whitespace/scheme-less and javascript:/intent:/ftp:/sunnahlife:/content: rejected) + openInAppBrowser (LaunchMode.inAppBrowserView = Chrome Custom Tabs on Android / SFSafariViewController on iOS; falls back to LaunchMode.externalApplication when the in-app view throws; never throws itself). Zakat CTA now OPENS the link (was clipboard copy); the copy affordance is KEPT as an icon button on the small link row (judged genuinely useful — sharing the link on; noted). New 'দান করুন' tile on the More grid beside zakat (entries restructured to (icon, title, onTap) records). Both affordances HIDDEN when the config carries no launchable http(s) URL; a failed launch shows a 'লিংক খোলা যায়নি' snackbar.
- l10n: more_donate + donation_open_failed × bn/en/ar (468 keys × 3); flutter gen-l10n + tool/make_arbs.py --keymap regenerated; ARB consistency + keymap tests stay green (part of the suite).
- The Dart 3.13.4 hazard (W3a): no map[k] ??= fut.whenComplete(remove) pattern anywhere in the new code (verified by scan before commit; the only matches in the repo are W3a's own regression test + its doc comment).
- Commits (f53f897 → 29f01c7, all on main, pushed):
  · f53f897 feat(C-W3g): admin hijri adjust applies everywhere — user ±2 + config ±2, clamped ±4
  · c07a61c feat(C-W3g): donation opens in the in-app browser — zakat CTA + More tile
  · 29f01c7 test(C-W3g): hijri-adjust matrix, pack parity, donation URL gating
- Scope kept: apps/mobile only; workflow/api/web/admin/packages sources untouched (app-config.json only READ by a test).

Stage Summary:
- VERIFIED RAW (after the final commit, re-run):
  flutter analyze:
    Analyzing mobile...
    No issues found! (ran in 4.2s)
  flutter test (tail):
    00:30 +225: ...text_scale_test.dart: Amal hub lays out cleanly at 1.3x text scale
    00:30 +226: All tests passed!
- 226/226 (was 184; +30 in test/hijri_donation_test.dart: the (user,admin)→clamped-sum matrix incl. out-of-range inputs (5+5→4, −9+9→0) + the full −2..2 × −2..2 sweep asserting sum-within-±4; the pack-parity test reading the committed JSON; the isLaunchableHttpUrl gating matrix ×13).
- Honest edges: (a) the admin ±1 ask in PLAN became "sum the admin value with the user value, clamp ±4" per the task instructions — the profile screen still shows/edits only the USER's ±2 (its own ±N label unchanged); (b) openInAppBrowser's real-device Custom Tabs behavior is static-verified only in the sandbox — the CI release-apk job is the on-phone proof; (c) when the config is LOADING the donate tile/CTA is hidden for a frame (orElse '' → not launchable) — the fallback config surfaces immediately after the ApiException path, so offline users get the pack-aligned fallback URL.

---
Task ID: C-W3h
Agent: implementation subagent (general-purpose, this round)
Task: Referral links — web /join route + landing, assetlinks.json + apple-app-site-association, autoVerify intent filter + iOS associated-domains, app handles incoming link → onboarding pre-fills referred_by (docs/PLAN.md ~line 566).

Work Log:
- VERIFIED the stated current state first: dawah_screen shares https://sunnahlife.app/join/<memberCode>; api_client + AuthNotifier accept referredByCode on verifyOtp/socialSignIn but auth_screen passes NOTHING; sunnahlife:// scheme filter in the manifest, NO https autoVerify, no assetlinks.json, no app_links, no cold-start handling, no web /join route.
- Web route (apps/web/src/app/join/[code]/page.tsx + join-landing.tsx): SERVER page (generateMetadata with bn og:title/description embedding the code — link-preview friendly; title template picks up "সুন্নাহ লাইফ-এ যোগ দিন · সুন্নাহ লাইফ") rendering a CLIENT landing: logo, title, the code prominent (card, tracking-wide), 'অ্যাপে খুলুন' (href sunnahlife://join/<code>), 'অ্যাপ ডাউনলোড করুন' (NEXT_PUBLIC_APP_DOWNLOAD_URL env with '#download' + TODO-comment fallback — no npm packages added), copy-code affordance (clipboard API + execCommand fallback), and localStorage persistence under 'sl_join_code' (web-only consumption path; no auth changes). Garbage codes AND bare /join redirect to '/' (page.tsx) — never 404. LIVE-VERIFIED on the dev server: /join/DS-000123 → 200 (title + og tags + sunnahlife:// href all present), /join → 307, /join/garbage → 307.
- App-links site files: apps/web/public/.well-known/assetlinks.json (correct statement shape for bd.asunnah.sunnah_life, sha256_cert_fingerprints ["REPLACE_WITH_UPLOAD_CERT_SHA256"] — RELEASE.md §8.1 documents the owner's `keytool -list -v -keystore upload-keystore.jks` step + the adb verify-app-links commands). Apple: apple-app-site-association is a Next ROUTE HANDLER (apps/web/src/app/.well-known/apple-app-site-association/route.ts) with EXPLICIT content-type application/json — an extensionless static file serves as octet-stream (verified live on the dev server before the rewrite: Content-Type application/octet-stream), which Apple rejects. Route handler serves 200 + application/json (verified). RELEASE.md §8 App Links added: fingerprint step, TEAMID step, verify commands, debug-signed CI artifacts only get the chooser (expected), the install-boundary honesty.
- Android manifest: NEW intent-filter android:autoVerify="true" on https host sunnahlife.app with pathPrefix /join (the existing sunnahlife:// scheme filter untouched — both work). XML parse-clean.
- iOS entitlements edit WAS MADE: Runner.entitlements gains com.apple.developer.associated-domains = [applinks:sunnahlife.app] (the file structure was straightforward — a plain plist dict; plistlib parse-verified; the doc notes the capability must also be toggled on the App ID on the signing Mac).
- Mobile deep-link handling: app_links 7.2.1. core/deep_links.dart extended with referralCodeFromLink — parses BOTH shapes (https://sunnahlife.app/join/CODE, www host tolerated, sunnahlife://join/CODE), validates the member-code regex ^ds-\d{6,}$ case-insensitive (mirrors apps/api nextMemberCode's 6-zero-padded DS codes; 6+ digits accepts a grown code space, rejects garbage) and normalizes to UPPERCASE; a single trailing slash is tolerated. deepLinkToRoute deliberately UNCHANGED for join links (they store, not navigate — pinned by test). services/app_link_service.dart follows PushService's lifecycle rules exactly (FLUTTER_TEST guard so the bootstrap never hangs in tests, single-shot, every failure swallowed + debugPrint). Cold start (getInitialLink) + warm stream (uriLinkStream; Android's double-delivery is harmless — idempotent write). bootstrapProvider wiring persists via PendingReferralStore (SharedPreferences 'pending_referral') and invalidates pendingReferralProvider.
- Sign-in prefill: auth_screen watches pendingReferralProvider → subtle 'রেফার করেছেন: DS-XXXXXX' chip (primary-tinted bordered container, l10n referral_by × bn/en/ar) shown during onboarding's sign-in flow (onb_signin → /auth); _verify AND _signInSocial pass the stored code as referredByCode. AuthNotifier._consumePendingReferral clears the storage ONLY after a successful sign-in (both paths) and invalidates the provider — a failed verify keeps the code for the retry.
- Tests: deep_links_test extended (4 new tests: both shapes + normalization + trailing slash; garbage codes; foreign hosts/paths/schemes incl. http vs https; join links never map to a navigation route). test/referral_test.dart (NEW, 10 tests): store round-trip / idempotent rewrite / restart-survival (fresh store over the same mock prefs) / clear; ApiClient.verifyOtp wire proof via http's MockClient (referredByCode present when passed, ABSENT from the body when null); AuthNotifier.signIn END-TO-END through a ProviderContainer over the mock client + in-memory Drift DB — the stored code reaches the /api/auth/otp/verify request body AND the storage is consumed on success, KEPT on a 400. (Bengali bodies need the charset=utf-8 content-type header in MockClient — http defaults to latin1 and throws; documented in the test helper.)
- Commits (59715b0 → e9973eb, all on main, pushed):
  · 59715b0 feat(C-W3h): /join deep links — pending referral from app links, consumed on sign-in
  · 09badf2 feat(C-W3h): web /join/<code> referral landing + app-links site files
  · e9973eb test(C-W3h): referral plumbing — link parsing, storage survival, wire plumbing
- Scope kept: apps/mobile + apps/web only; workflow/api/admin untouched.

Stage Summary:
- VERIFIED RAW (after the final commit):
  flutter analyze:
    Analyzing mobile...
    No issues found! (ran in 4.2s)
  flutter test (tail):
    00:30 +225: ...text_scale_test.dart: Amal hub lays out cleanly at 1.3x text scale
    00:30 +226: All tests passed!
  apps/web: bun run typecheck → clean; bun run lint → clean (no output = 0 issues). NOTE: the ROOT `bun run typecheck` script (tsc -p apps/web + apps/admin) cannot run in this sandbox — tsc is not on PATH at the repo root (no root node_modules/tsc); the equivalent proof ran from each workspace: apps/web `bun run typecheck` ✓ AND apps/admin `./node_modules/.bin/tsc --noEmit` ✓ — exactly the two projects the root script covers.
  Dev-server smoke (live): /join/DS-000123 → 200; og:title 'সুন্নাহ লাইফ-এ যোগ দিন'; og:description embeds DS-000123; /join → 307; /join/garbage → 307; /.well-known/assetlinks.json → 200 application/json; /.well-known/apple-app-site-association → 200 application/json (route handler).
- 226/226 mobile (was 184 at the C-W3f baseline; +30 from C-W3g's hijri_donation_test, +12 from C-W3h: +4 in deep_links_test.dart [join-link parsing group], +8 in the new referral_test.dart [4 store, 2 ApiClient wire, 2 AuthNotifier end-to-end]).
- Web: no test infra exists for the new page (no test script in apps/web/package.json) — typecheck + lint + the live dev-server smoke above are the proof.
- Honest edges: (a) THE INSTALL-BOUNDARY GAP (documented in RELEASE.md §8.3 + code comments): a guest who taps the link in a browser where the app is NOT installed gets the web landing; the code persists in the BROWSER's localStorage ('sl_join_code') which the MOBILE app cannot read — the code only reaches the app when a tap actually OPENS the app (custom scheme or verified App Link). The landing's 'অ্যাপে খুলুন' button is that bridge after install. (b) App-Links verification itself needs the owner's real upload-key SHA-256 (placeholder committed; RELEASE.md §8.1) and the iOS TEAMID (placeholder; §8.2) — until then Android shows the disambiguation chooser (the deep link still works through it) and iOS Universal Links don't auto-open (the sunnahlife:// scheme + the landing still work). (c) Debug-signed CI artifacts (internal-test-*) are debug-key-signed → App Links only verify for release-signed installs (expected, documented). (d) Real-device cold-start link behavior (app_links platform channels) is static-verified only — the CI release-apk job + the owner's phone checklist are the on-device proof.
