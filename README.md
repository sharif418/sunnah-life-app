# Sunnah Life — সুন্নাহ লাইফ

**As-Sunnah Foundation — Dawatus Sunnah department.**
One platform, two products: a public Islamic companion app (prayer times,
Qur'an, du'as & adhkar, courses, live programs) **and** the Tarbiyah engine
that runs the Dawatus Sunnah program — usrahs, the daily Muhasaba diary,
weekly reviews, Farze Ain assessments and level progression.

- Bengali-first (English + Arabic RTL supported), built for low-end Android
  and poor connectivity, offline-first.
- Sisters' data is visible only to female supervisors — enforced **in the
  database** (PostgreSQL Row-Level Security), not just in code.

---

## Quick start

### In this workspace / local development (Next.js web app, SQLite)

```bash
bun install
bun run db:push     # create the SQLite mirror schema
bun run db:seed     # demo data (docs/DEMO_ACCOUNTS.md)
bun run dev         # http://localhost:3000
```

Optional local services for the other workstreams (PostgreSQL 16, Redis 7,
Meilisearch, the Flutter SDK) — install/run instructions are in
`docs/ENVIRONMENT.md`.

### On the VPS — the full production stack (Docker)

```bash
cp .env.example .env      # then fill in the secrets
docker compose --env-file .env -f infra/docker-compose.yml up -d --build
```

or simply `./infra/up.sh`. One command brings up PostgreSQL 16 (+RLS
bootstrap), Redis, MinIO (+bucket init), Meilisearch, the NestJS API, the
BullMQ worker, the web PWA and the admin panel — all with healthchecks.
Full guide: **docs/DEPLOY_COOLIFY.md**.

Demo logins (OTP mock — the code is returned in the response and shown in the
auth modal): **docs/DEMO_ACCOUNTS.md**.

---

## Repository map

```
sunnahlife/                     ← repo root IS the web workspace (Next.js PWA)
├── src/                        web app: components, app router, API routes, libs
│   ├── app/                    pages + /api/** route handlers (SQLite mirror)
│   ├── components/             home · amal · dawah · ilm · more · admin · app shell
│   └── lib/                    prayer engine, calendars, i18n, store, api client…
├── apps/
│   ├── api/                    NestJS modular monolith — Prisma PostgreSQL + RLS,
│   │                           JWT auth, BullMQ, OpenAPI, /health + /metrics
│   ├── worker/                 BullMQ workers (same image as the api)
│   ├── admin/                  Next.js admin panel (three role dashboards)
│   └── mobile/                 Flutter app (Android + iOS), Riverpod + Drift
├── packages/
│   ├── design-tokens/          tokens.json → Tailwind CSS + Flutter ThemeData
│   ├── content/                versioned JSON content packs (symlink → content/)
│   └── shared-types/            generated from the API's OpenAPI (/openapi.json)
│                               — consumed by web/admin
├── content/                    Qur'an, adhkar, du'as, names99, courses, quizzes…
├── prisma/                     SQLite schema + demo seed (the web mirror)
├── infra/                      docker-compose.yml, service Dockerfiles,
│                               postgres init-rls.sql, pgbackrest.conf, Caddyfile
├── docs/                       everything below ↓
└── .github/workflows/ci.yml    lint · test · build for api/web/admin/mobile
```

---

## The stack

| Layer | Technology | Where |
|---|---|---|
| Mobile | Flutter stable, Riverpod, go_router, Drift (offline-first) | `apps/mobile` |
| API | NestJS, Prisma, JWT + rotating refresh, BullMQ, OpenAPI | `apps/api` |
| Database | PostgreSQL 16 + **Row-Level Security** (gender/usrah scoping) | `apps/api/prisma` |
| Cache/queues | Redis 7 + BullMQ | `apps/worker` |
| Object storage | MinIO (S3) | `infra/docker-compose.yml` |
| Search | Meilisearch (Bengali typo-tolerant) | `infra/docker-compose.yml` |
| Web + PWA | Next.js 16 App Router, TypeScript, Tailwind v4, shadcn/ui | repo root |
| Admin | Next.js, shadcn/ui, TanStack Table/Query | `apps/admin` |
| Design system | tokens.json → Tailwind + Flutter ThemeData | `packages/design-tokens` |
| Deploy | Docker compose → Coolify VPS, Cloudflare in front | `infra/`, `docs/DEPLOY_COOLIFY.md` |
| CI | GitHub Actions (bun + flutter, Postgres/Redis services) | `.github/workflows/ci.yml` |

---

## Documentation index

| Doc | What's inside |
|---|---|
| [docs/PLAN.md](docs/PLAN.md) | architecture, mandated stack, build order, assumptions |
| [docs/API_CONTRACTS.md](docs/API_CONTRACTS.md) | every endpoint, domain rules (locking rule, conflict rule) |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | full ERD (22 models), RLS policy matrix, natural keys, locking-rule diagram |
| [docs/DEMO_ACCOUNTS.md](docs/DEMO_ACCOUNTS.md) | seeded phones, OTP mock flow, referral links, guest→merge |
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | palette, typography, motion, RTL, component inventory (web + Flutter) |
| [docs/DEPLOY_COOLIFY.md](docs/DEPLOY_COOLIFY.md) | VPS bring-up, env vars, Cloudflare, backups (pgBackRest), updates, rollback |
| [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md) | sandbox toolchain log (what runs where, and why) |
| [docs/PROGRESS.md](docs/PROGRESS.md) | verification artifacts per milestone |

Design tokens build: `cd packages/design-tokens && node build.mjs [--check]`.

---

## Development commands (web workspace)

```bash
bun run dev        # dev server on :3000
bun run lint       # eslint — must stay 0 issues
bun run build      # production build (standalone output)
bun run db:push    # sync the SQLite mirror schema
bun run db:seed    # (re)seed demo data
```

Flutter: `cd apps/mobile && flutter pub get && flutter run`
(catalog: `flutter run -t lib/catalog/catalog_app.dart`).
NestJS: `cd apps/api && bun install && bun run start:dev`.

---

## License & ownership

© As-Sunnah Foundation — Dawatus Sunnah department. All rights reserved.
This is a client-commissioned, private codebase: it is **not** open-source and
may not be redistributed without the Foundation's written consent. Demo
content (Qur'an text, translations, du'a compilations) follows the respective
sources' licenses; verify before republishing beyond the app.
