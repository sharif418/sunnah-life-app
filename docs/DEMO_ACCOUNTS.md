# Sunnah Life — Demo Accounts (DEMO_ACCOUNTS.md)

Seeded demo data for reviewers, testers and the client's team. **The same
phones work on both surfaces**, because both are seeded from the same reserved
account list (worklog task 1):

| Surface | Database | Seeded by |
|---|---|---|
| **Web PWA** (`/`, repo root) | SQLite mirror | `bun run db:seed` — or, on the Docker stack, automatically on the `web` container's first boot (`/data/.seeded` marker) |
| **NestJS API** (`apps/api`) | PostgreSQL 16 + RLS | the `api` container's entrypoint (`bun run seed`, idempotent) — the seed script lives at `apps/api/prisma/seed.ts` |
| **Flutter app** (`apps/mobile`) | talks to the NestJS API | logs in with the same phones over OTP |

Every account has 30 days of deterministic amal history, referral closure rows,
weekly reviews, reminders and announcements where the role calls for it.

---

## 1. The phones

All numbers are Bangladeshi-format 11-digit demo phones (`01xxxxxxxxx`). No real
SMS is sent — see §3 (OTP mock).

### Program leadership

| Phone | Name | Gender | Role | Member code | Level | Usrah |
|---|---|---|---|---|---|---|
| `01000000001` | আব্দুল্লাহ আল মামুন | M | **full_admin** | — | none | — |
| `01000000002` | হাফেজ যাকারিয়া | M | **invigilator** (হাফেজ) | — | none | — |
| `01000000003` | মাওলানা ইউসুফ | M | **usrah_head** | DS-000003 | farze_ain_1 | উসরা আল-ফুরকান (M) — head |
| `01000000005` | উম্মে হাবিবা | F | **usrah_head** | DS-000005 | farze_ain_1 | উসরা আয়েশা সিদ্দিকা (F) — head |
| `01000000015` | উস্তায়া সালেহা আক্তার | F | **invigilator** | — | none | — |

### Da'ees (dawah engine)

| Phone | Name | Gender | Role | Member code | Level | Referred by | Usrah |
|---|---|---|---|---|---|---|---|
| `01000000004` | রাফিউল ইসলাম | M | **daee** | **DS-000004** | muhibbus_sunnah | 01000000003 | আল-ফুরকান |
| `01000000006` | মারিয়াম হাসান | F | **daee** | **DS-000006** | muhibbus_sunnah | 01000000005 | আয়েশা সিদ্দিকা |
| `01000000009` | মেহেদী হাসান | M | daee (হাফেজ) | DS-000009 | muhibbus_sunnah | 01000000004 | আল-ফুরকান |
| `01000000013` | সাদিয়া রহমান | F | daee | DS-000013 | muhibbus_sunnah | 01000000006 | আয়েশা সিদ্দিকা |

### Regular users (madu — downline)

| Phone | Name | Gender | Role | Referred by | Usrah |
|---|---|---|---|---|---|
| `01000000007` | তানভীর হোসেন | M | user | 01000000004 | আল-ফুরকান |
| `01000000008` | সাইফুল ইসলাম | M | user | 01000000004 | আল-ফুরকান |
| `01000000010` | আব্দুর রহিম | M | user | 01000000009 | আল-ফুরকান |
| `01000000011` | ফাতিমা আক্তার | F | user | 01000000006 | আয়েশা সিদ্দিকা |
| `01000000012` | নুসরাত জাহান | F | user | 01000000006 | আয়েশা সিদ্দিকা |
| `01000000014` | রাইসা খাতুন | F | user | 01000000013 | আয়েশা সিদ্দিকা |

### Usrah membership map

```
উসরা আল-ফুরকান (M) — head 01000000003, invigilator 01000000002
└── 03 · 04 · 07 · 08 · 09 · 10

উসরা আয়েশা সিদ্দিকা (F) — head 01000000005, invigilator 01000000015
└── 05 · 06 · 11 · 12 · 13 · 14
```

Referral tree (dawah downline, separate from usrah membership):

```
03 ── 04 ── 07
│      ├── 08
│      └── 09 ── 10
05 ── 06 ── 11
       ├── 12
       └── 13 ── 14
```

### Extra seeded context worth knowing

- `01000000004` and `01000000006` have **passed assessments** (score 88 %);
  `01000000009` has a **not_yet** assessment (failed akhlaq section) — useful
  to demo the assessment flow and the promotion requirement gate.
- `01000000008` has a **demo day-unlock**: day D−3 was unlocked by his usrah
  head (reason: "অসুস্থ ছিলেন") with the matching `AuditLog` entry — use it to
  demo the locking-rule flow (§4).
- 4 **live programs**: one live right now, one upcoming F-only session
  ("বোনদের তারবিয়াহ সেশন") — log in as an F account to see it appear.
- Level transitions + promotion audit entries exist for 03/04/05/06/09/13.

---

## 2. What each account can see (the gender rule)

The gender rule is enforced **in the database itself** (PostgreSQL RLS on the
production API) and mirrored by `assertCanAccess` on the web — see
docs/DATA_MODEL.md §4. Quick matrix with these accounts:

| Logged in as | Sees |
|---|---|
| `01000000001` (full_admin M) | everything, both genders: all usrahs, all members' 31-day grids, audit log, user admin (role/gender/usrah/category), amal catalog, promotions |
| `01000000002` (invigilator M) | all **male** usrahs + members (health dashboards, overdue reviews); no F rows at all |
| `01000000015` (invigilator F) | all **female** usrahs + members; no M rows at all |
| `01000000003` (usrah_head M) | own usrah আল-ফুরকান only: members' month grids, weekly review queue, day unlocks, assessments, usrah announcements |
| `01000000005` (usrah_head F) | own usrah আয়েশা সিদ্দিকা only — **cannot** see or unlock any male member (try the month grid of `01000000008` → 403) |
| `01000000004` (daee M) | own diary + own downline (07, 08, 09, 10) + referral link + level progress |
| `01000000006` (daee F) | own diary + own downline (11, 12, 13, 14) + referral link + level progress |
| `01000000007…14` (user) | own diary, own reminders, own enrollments/quiz attempts, usrah announcements, live programs for own gender |
| guest (not signed in) | public content, prayer times, Qur'an, local-only amal diary; no usrah/engagement features |

---

## 3. OTP mock flow (no real SMS in dev)

`SMS_PROVIDER=mock` (the default in `.env.example`) — production providers
(SSL Wireless / Infobip) are adapters behind the same interface.

1. On the web auth modal, enter any of the phones above (or the quick-login
   buttons in the modal — they prefill the five headline accounts).
2. `POST /api/auth/otp/request {phone}` → `{ ok: true, devCode: "319476" }`
   — the **devCode comes back in the API response**.
3. The web auth modal **auto-fills the code** and shows a toast:
   `ডেমো SMS গেটওয়ে — কোড: 319476`.
4. `POST /api/auth/otp/verify {phone, code}` → `{user}`; the session cookie is
   set (`sl_session` on the web mirror, JWT access + rotating refresh on the
   NestJS API).
5. Rate limit: 3 codes per 10 minutes per phone (429 beyond that).

OTP codes for the **NestJS API** are issued by the same mock provider when
`SMS_PROVIDER=mock` — the response includes the same `devCode` field for the
Flutter app's debug builds.

---

## 4. Referral links & the guest → member merge flow

### Referral link format

A da'ee's link (shown on their দাওয়াত tab, `/api/dawah`):

```
https://sunnahlife.app/?join=DS-000004
```

- The current web app captures the `?join=DS-XXXXXX` query param (see
  `src/app/page.tsx`) and keeps it pending until the guest registers.
- The canonical path form `/join/DS-000004` is the planned SEO-friendly
  landing route (the same handler); both resolve to the same join flow.
- `GET /api/join?code=DS-000004` (public) returns `{inviterName,
  inviterLevel}` so the landing can greet the invitee personally.

### Guest → member merge (offline-first)

1. A **guest** uses the app anonymously: onboarding profile (name/gender/
   city/prayer config) + amal diary entries are stored **on-device**
   (zustand persist on web; Drift/SQLite on Flutter).
2. The guest opens a referral link `?join=DS-000004` — the code is captured.
3. On OTP verification the client sends
   `POST /api/auth/otp/verify {phone, code, name?, gender?, referredByCode?,
   guestEntries: [...]}`:
   - the user is created (or found), `memberCode` minted later at da'ee
     promotion;
   - the **referral closure rows** are inserted (depth 1..3 along the inviter's
     ancestor chain);
   - the **guest diary entries merge into the account** with the
     latest-`clientUpdatedAt`-wins conflict rule (per-entry upserts — no
     `createMany skipDuplicates` on SQLite);
   - from then on the outbox syncs through the signed-in API.

---

## 5. Quick smoke script (reviewer checklist)

```bash
# 1. request an OTP for the full admin
curl -s -X POST http://localhost:3000/api/auth/otp/request \
  -H 'content-type: application/json' -d '{"phone":"01000000001"}'
# → {"ok":true,"devCode":"319476"}

# 2. verify (web sets the sl_session cookie)
curl -s -c /tmp/sl.txt -X POST http://localhost:3000/api/auth/otp/verify \
  -H 'content-type: application/json' \
  -d '{"phone":"01000000001","code":"<devCode>"}'
# → {"user":{ "role":"full_admin", ... }}

# 3. admin overview (role-scoped)
curl -s -b /tmp/sl.txt http://localhost:3000/api/admin/overview

# 4. referral landing preview
curl -s 'http://localhost:3000/api/join?code=DS-000004'
```

On the Docker stack the same endpoints exist on the **api** service at
`http://localhost:4000` (the Flutter app + admin panel talk to that one).
