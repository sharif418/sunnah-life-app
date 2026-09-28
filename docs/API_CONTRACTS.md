# Sunnah Life — API Contracts (source of truth for all workstreams)

All endpoints are Next.js route handlers under `src/app/api/**`. JSON bodies.
Auth = HttpOnly session cookie (`sl_session`). Errors: `{ "error": "messageBn" }`
with proper status codes. Bengali-first data.

**Domain rules enforced server-side (see `src/lib/server/guard.ts`):**
- `assertCanAccess(viewer, targetId)` — gender-scope chokepoint: full_admin ⇒
  always; others require same gender + (self | own-usrah member | own downline |
  invigilator-of-own-gender).
- **Locking rule:** an AmalEntry for date D is locked once **Ishraq of D+1 has
  passed** (computed with the target user's location, default Dhaka +6,
  Karachi/Hanafi, `computePrayerTimes` from `src/lib/prayer-times.ts`, Ishraq =
  sunrise+20). POSTs of locked days are rejected with 423 unless a `DayUnlock`
  row exists for (userId, date). Unlock = usrah_head+ & audit-logged.
- **Conflict rule:** latest `clientUpdatedAt` wins.
- Weekly reviews: a `pending` review exists per da'ee per ISO week (Saturday
  week start); if missing, GET queue lazily creates it. Overdue when > 7 days old.
- Levels: `none → muhibbus_sunnah` requires (config `content/level-rules.json`,
  default): ≥4 months in level, a passed assessment (any template), ≥5 downline
  users at `muhibbus_sunnah`. Promotion via admin only, audit-logged.

## Endpoints

### Auth / profile
| Method | Path | Body / Query | Response |
|---|---|---|---|
| POST | `/api/auth/otp/request` | `{phone}` | `{ok, devCode}` (mock SMS; 429 on >3/10min) |
| POST | `/api/auth/otp/verify` | `{phone, code, name?, gender?, referredByCode?, guestEntries?}` | `{user}` — creates user+referral closure, merges guest amal entries |
| POST | `/api/auth/logout` | — | `{ok}` |
| GET | `/api/me` | — | `{user\|null}` |
| PATCH | `/api/me` | partial of `{name,language,madhhab,calcMethod,lat,lng,city,district,workplace,department,category}` | `{user}` |
| GET | `/api/config` | — | AppConfig (see types) |
| GET | `/api/join?code=DS-000123` | — | `{inviterName, inviterLevel}` (public) |

### Amal (Muhasaba)
| Method | Path | Body / Query | Response |
|---|---|---|---|
| GET | `/api/amal/definitions` | — | `{definitions: AmalDefinition[]}` (DB-configurable, seeded from content pack) |
| GET | `/api/amal/entries` | `?from&to` (self) or `?from&to&userId` (supervisor/downline via guard) | `{entries: AmalEntry[]}` |
| POST | `/api/amal/entries` | `{entries: [{amalKey,date,value,clientUpdatedAt,source?}]}` (batch, guest-merge + offline sync) | `{accepted: AmalEntry[], rejected: [{date,amalKey,reason}]}` (423 locked) |
| POST | `/api/amal/unlock` | `{userId,date,reason?}` (usrah_head+ of that user, audit) | `{ok}` |

`AmalEntry.value` JSON encodes the input type: tristate → `"jamaat"|"alone"|"qaza"`;
boolean → `true/false`; count/quantity → number. `source` = `"manual"` or
`"auto:adhkar:morning" | "auto:quran:tilawat" | "auto:prayer:fajr"` etc.

### Dawah engine
| Method | Path | Notes |
|---|---|---|
| GET | `/api/dawah` | daee+: `{memberCode, referralLink, invitedCount, downline: DownlineNode[], level, levelStartedAt, monthsInLevel, requirements: LevelRequirement[], nextLevel, assessments: AssessmentSummary[]}`. referralLink = `https://sunnahlife.app/?join=DS-XXXXXX` |
| GET | `/api/usrah` | own usrah: `{usrah: Usrah & {members: UsrahMember[]}, announcements: Announcement[]}` |
| GET | `/api/reviews` | self: `{reviews: WeeklyReview[]}` |
| GET | `/api/reviews?scope=queue` | usrah_head+: `{queue: (WeeklyReview & {user: UsrahMember})[]}` — lazily creates this week's pending reviews for own-usrah da'ees |
| POST | `/api/reviews` | usrah_head+: `{userId, weekStart, comment, rating(1-5), nextGoals}` → computes auto-summary server-side, marks done, notifies member (Reminder row) |
| GET | `/api/assessments` | `?userId` (guard) — `{assessments: AssessmentDetail[]}` |
| GET | `/api/assessments/templates` | `{templates: AssessmentTemplate[]}` |
| POST | `/api/assessments` | assessor (usrah_head+ w/ guard): `{assesseeId, templateKey, participantCategory(1|2), scores: {criterionKey: {score:0|1|2, comment?}}, overallComment}` → result computed ("majority of criteria ≥1 per section" ⇒ passed) |

### Admin (usrah_head / invigilator / full_admin, guard-scoped)
| Method | Path | Notes |
|---|---|---|
| GET | `/api/admin/overview` | role-scoped: `{role, totals, usrahs: UsrahHealth[], recentAudit}` (usrah_head: own usrah only; invigilator: own-gender usrahs; admin: all) |
| GET | `/api/admin/users?q=` | gender-scoped user search (admin: both) `{users: (User & {usrahName})[]}` |
| GET | `/api/admin/month-grid?userId&month=YYYY-MM` | guard-checked: `{grid: MonthGrid}` — definitions + days + rows (31-col heatmap data) |
| PATCH | `/api/admin/users` | full_admin only: `{userId, role?, gender?, usrahId?, category?}` — gender/role changes audited |
| POST | `/api/admin/promote` | full_admin: `{userId, toLevel}` — validates requirements, writes LevelTransition, audit |
| POST | `/api/admin/broadcast` | usrah_head+ : `{usrahId?, gender?, body}` → Announcement + Reminder fan-out |
| POST | `/api/admin/amal-catalog` | full_admin: upsert `{key, titleBn, titleEn, category, inputType, cadence, target?, unit?, minLevel?, sortOrder?, autoSource?}` |
| GET | `/api/admin/audit` | full_admin: `{entries: AuditEntry[]}` |

### Engagement
| Method | Path | Notes |
|---|---|---|
| GET/PATCH | `/api/reminders` | own reminders; PATCH marks read |
| GET/POST | `/api/live` | list programs (gender-scoped for female sessions — only F users see F programs); POST `{id}` = "Notify me" |
| POST | `/api/masala` | `{name, phone?, question}` (guest ok) |
| POST | `/api/feedback` | `{message}` (guest ok) |
| POST/PATCH | `/api/enroll` | enroll in course; save progress JSON (login) |
| POST | `/api/quiz-attempt` | `{quizId, score, total}` (login, or guest-ignored) |
| GET | `/api/quran/surahs` | `{surahs: [{number,name,nameBn,englishName,englishNameTranslation,ayahCount,revelationType}]}` |
| GET | `/api/quran/surah/[number]` | `{surah: {…, bismillahPre, ayahs: [{numberInSurah, text, translationBn?, page, juz}]}}` |

## Live usrah quiz — socket.io gateway (inside the API, B9)

The live quiz is a socket.io gateway **in the NestJS process**
(`apps/api/src/engagement/quiz.gateway.ts`, path `/socket.io` on the same
HTTP server — one backend, one auth, one deployment). The retired :3030 bun
mini-service is deleted.

- **Join:** `GET /api/quiz/live-token?quizId=…` (login; own usrah + real
  gender required) → `{token, room, role, quizId, exp}` — a 15-min HMAC
  token minted with `QUIZ_SECRET`. Connect with
  `io(API_BASE || "/?XTransformPort=3001", { path: "/socket.io", auth: { token } })`
  (sandbox: same-origin through the edge gateway; prod: the API origin).
- **Wire protocol** (identical to the retired mini-service):
  `room:state {room, role, phase, quizId, quizTitle, questionCount,
  currentIndex, players, scoreboard}` on every join/leave/phase change;
  `quiz:started {quizId, titleBn, questionCount}`;
  `quiz:question {index, questionBn, options, seconds, endsAt}`;
  `quiz:reveal {index, answerIndex, explanationBn, tally, scoreboard}`;
  `quiz:ended {scoreboard}`; `quiz:error {messageBn}`.
  Client → server: `host:start {quizId}`, `host:next` (during question =
  early reveal), `host:end`, `player:answer {index, choice}`.
- **Gender isolation:** the room id IS the usrah id (single-gender by
  design); tokens are only minted for a user's OWN usrah. Leaderboard
  carries first names + member codes only.
- **Scoring:** correct = 100 + up to 40 speed bonus; one answer per
  question; reconnecting players keep their score; rooms GC when empty.
- **Smoke:** `cd apps/api && bun run smoke:quiz` (21 checks).


## Client utilities already provided
- `src/lib/api.ts` — typed client for ALL endpoints above.
- `src/lib/store.ts` — zustand store: `nav(tab, view, params)`, `back()`,
  `user`, `profile` (persisted), `amalCache`/`outbox` + `writeEntry(entry)` =
  offline-first optimistic write with debounced batched sync.
  **Views MUST write amals via `useApp().writeEntry`** and read from
  `amalCache` (hydrate with `api.amalEntries(range)` + `hydrateFromServer`).
- `src/lib/prayer-times.ts` — `computePrayerTimes({y,m,d}, cfg)`,
  `nextPrayer(now, cfg)`, `forbiddenWindows(t)`, `CALC_METHODS`.
- `src/lib/calendars.ts` — `toBn`, `dateKey`, `addDays`, `banglaDate(d)`,
  `hijriDate(d, adjust)`, `formatTimeBn(minutes)`, `gregorianBn`, `weekdayBn`,
  `isAyyamBeez`.
- `src/lib/qibla.ts`, `src/lib/cities.ts`, `src/lib/search.ts`
  (`searchList(query, items, fields)`), `src/lib/content.ts` (`getPack(key)`).
- `src/types/domain.ts` — ALL shared types + labels (ROLE_LABELS_BN,
  AMAL_CATEGORY_LABELS_BN, PRAYER_LABELS_BN…).

## View/subview registry (store navigation)
`nav("home")` · `nav("amal", "today"|"month"|"goals"|"habits")` ·
`nav("dawah", "overview"|"madu"|"usrah"|"reviews"|"level")` ·
`nav("ilm", "home"|"quran"|"quran-surah" (params:{number})|"adhkar"|"adhkar-set" (params:{id})|"post-salat"|"duas"|"dua" (params:{id})|"names99"|"islamic-names"|"iman70"|"sunnahs"|"articles"|"article" (params:{id})|"courses"|"course" (params:{id})|"lesson" (params:{courseId,lessonId})|"quizzes"|"quiz" (params:{id})|"live"|"usrah-questions")` ·
`nav("more", "home"|"zakat"|"qibla"|"mosques"|"masala"|"support"|"contact"|"detox"|"profile"|"settings"|"about"|"faq"|"feedback"|"donation"|"groups")`.
Admin console overlay: `setAdminOpen(true)` — separate from tab nav.

## Design conventions (MANDATORY for every view)
- Colors ONLY via tokens: `bg-background`, `bg-card`, `text-primary`,
  `bg-primary-soft`, `text-gold`, `bg-gold-soft`, `text-alert`, `bg-alert-soft`,
  `text-success`, `text-muted-foreground`, `border-border`. Never raw hex.
- Radius: `rounded-lg`(16) / `rounded-xl`(20) for cards; `rounded-full` pills.
- Cards: `bg-card border border-border rounded-xl shadow-card p-4 sm:p-5`.
- Section headers: `<h2 className="text-lg font-bold flex items-center justify-between">` + "সব দেখুন →" link buttons in `text-primary text-sm font-medium`.
- Skeletons while loading (shadcn Skeleton), designed empty states, error
  states with retry. Never blank spinners, never "Lorem ipsum".
- All numerals in Bengali via `toBn()` when language is bn.
- Touch targets ≥ 44px (`tap-target` class where needed).
- Arabic text: `className="font-arabic"` (duas), `font-quran` (Qur'an ayahs),
  `dir="rtl"` and `text-right`/`text-end` on the Arabic block.
- Lists longer than ~8 items: `max-h-96 overflow-y-auto scroll-thin`.
- Buttons/links: `transition-colors motion-base` for hover feedback.
- framer-motion: subtle only (fade/slide ≤ 320ms). Use `motion.div` for card
  entrance, not for everything.
- lucide-react icons everywhere (size-4/5).
- DO NOT create new global files (store/types/tokens) — extend via existing
  patterns. If something's missing, note it in the worklog for the integrator.

## File ownership map (workstreams)
- `src/components/home/**`, `src/components/amal/**`, `src/components/dawah/**`,
  `src/components/ilm/**`, `src/components/more/**`, `src/components/admin/**`
  — owned by their agents (start by REPLACING the stub view files).
- `src/app/api/**` — owned by backend agent (except auth/config/join/quran/
  reminders which are done).
- `content/**` + `prisma/seed.ts` — owned by content agent.
- Shared libs — integration agent (me). Report needed changes in worklog.
