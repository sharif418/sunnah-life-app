# Sunnah Life — Deployment on the client's VPS with Coolify (DEPLOY_COOLIFY.md)

Target: the client's own virtual server, managed with
[Coolify](https://coolify.io) (Docker + docker compose under the hood), with
**Cloudflare** in front. **This is the actual working flow** — everything here
is grounded in `infra/coolify.compose.yml`, the file the Coolify resource
runs (mirrored on the `staging` branch; see §7). If this doc and that compose
file ever disagree, the compose file wins — fix the doc.

> **Two compose files, two jobs.** `infra/coolify.compose.yml` is the Coolify
> stack (this doc). `infra/docker-compose.yml` is the local / CI dev stack
> (adds MinIO + a Caddy proxy profile, host ports, fixed network name).
> Never deploy the dev stack in Coolify — the Coolify file is the one kept in
> sync with what is really running.

---

## 1. Prerequisites

| Item | Requirement |
|---|---|
| VPS | 2 vCPU / 4 GB RAM minimum (the compose file caps the seven services at ≈ 4.5 GB of `mem_limit` — caps, not reservations; real usage idles well below). 4 vCPU / 8 GB recommended for production headroom. Debian 12/13 or Ubuntu 22.04+. |
| Coolify | installed per coolify.io docs (it installs Docker Engine itself). The stack below is deployed as ONE Coolify resource of the **Docker Compose** build pack. |
| Docker | compose **v2** (plugin) — ships with any Docker Coolify installs; required for per-Dockerfile `.dockerignore` support and `depends_on: condition: service_healthy`. |
| DNS | the client's domain at Cloudflare — proxied records per §3 and docs/HUMAN_STEPS.md §6. |
| Git | the repo reachable from the VPS. Today Coolify clones the **public** repo and deploys the `staging` branch (§7); going private is a production step (§8). |
| Secrets | everything marked **✔** in §4 set in the Coolify resource's environment before the first deploy. |

---

## 2. The Coolify resource — "Docker Compose" build pack, repo-root contexts

One resource, one deploy button, seven services. In Coolify:

**Resources → New → Docker Compose (Empty/Custom)**, then point it at the repo
and the compose file path `infra/coolify.compose.yml`, and fill the §4
environment variables in the resource's **Environment Variables** editor.

The critical, easy-to-miss part: **build contexts are relative to the
REPOSITORY ROOT**. Coolify runs compose with `--project-directory` set to the
checkout root, and the compose file says so verbatim:

```yaml
# Build contexts are relative to the REPOSITORY ROOT: Coolify runs compose
# with --project-directory set to the checkout root.
```

The actual context/dockerfile lines from `infra/coolify.compose.yml`:

```yaml
  postgres:
    build:
      context: ./infra/postgres
      dockerfile: Dockerfile
```
```yaml
  api:
    build:
      context: .                    # ← the repo ROOT
      dockerfile: infra/api.Dockerfile
```
```yaml
  worker:
    build:
      context: .                    # ← the repo ROOT
      dockerfile: infra/api.Dockerfile
```
```yaml
  web:
    build:
      context: .                    # ← the repo ROOT
      dockerfile: infra/web.Dockerfile
      args:
        NEXT_PUBLIC_API_BASE: ${NEXT_PUBLIC_API_BASE:?set NEXT_PUBLIC_API_BASE}
```
```yaml
  admin:
    build:
      context: ./apps/admin
      dockerfile: ../../infra/admin.Dockerfile
      args:
        NEXT_PUBLIC_API_BASE: ${NEXT_PUBLIC_API_BASE:?set NEXT_PUBLIC_API_BASE}
        NEXT_PUBLIC_DEMO: ${NEXT_PUBLIC_DEMO:-}
```

Why the root matters:

- **api + worker** need `apps/api` AND `packages/content` (the entrypoint seed
  reads the amal catalog + assessment packs; the content routes serve the
  Qur'an + packs from `CONTENT_DIR=/app/packages/content`) — see the header of
  `infra/api.Dockerfile`.
- **web** imports types from `packages/shared-types` and sets
  `outputFileTracingRoot` to the repo root (`apps/web/next.config.ts`), so its
  standalone output mirrors repo-relative paths.
- **admin** is the one exception — its context is `apps/admin` only.
- **postgres** is not the stock image here: it is **built from
  `infra/postgres/Dockerfile`**, which bakes `init-rls.sql` (the
  `sunnah_app` NOBYPASSRLS role bootstrap) and `init-walarchive.sh` into the
  image — Coolify does not provide repo files to runtime bind mounts, which
  is exactly why the dev compose's bind mount could not be reused.

### What runs (7 services)

| Service | Built from | Container port | Volume | `mem_limit` |
|---|---|---|---|---|
| `postgres` | `infra/postgres/Dockerfile` (postgres:16 + RLS init) | 5432 internal | `pgdata` | 1g |
| `redis` | image `redis:7` (AOF on) | 6379 internal | `redisdata` | 256m |
| `meilisearch` | image `getmeili/meilisearch:v1.54.0` | 7700 internal | `meili` | 512m |
| `api` | `infra/api.Dockerfile` (NestJS; migrates + seeds then serves) | **4000** | `apistorage` | 1g |
| `worker` | same image as api, worker command (BullMQ) | none | `apistorage` | 768m |
| `web` | `infra/web.Dockerfile` (Next.js PWA) | **3000** | — | 512m |
| `admin` | `infra/admin.Dockerfile` (Next.js admin) | **3000** | — | 512m |

No host ports are published and there is no proxy service in this file —
**Coolify's own Traefik owns 80/443** and routes the domains you assign per
service (§3).

---

## 3. Domains — set per service in Coolify, pointing at the CONTAINER port

In the Coolify resource, each service that must be reachable gets a domain
(`Networking` / domains field, or the per-service `FQDN` env). The compose
header documents the mapping (container port after the colon):

```yaml
# Domains (set in Coolify per service, container port after the colon):
#   web   → https://<web-domain>:3000
#   admin → https://<admin-domain>:3000
#   api   → https://<api-domain>:4000
```

- **api** → `https://api.<domain>:4000` — e.g. the current staging deployment
  answers at `https://api-staging.sunnahlife.ailearnersbd.com` (the
  `:4000` is the container port; Coolify's Traefik terminates TLS, the public
  URL never shows it).
- **web** → `https://<domain>:3000` — the public PWA.
- **admin** → `https://admin.<domain>:3000` — the admin console.
- postgres / redis / meilisearch / worker get **no domain** — internal only;
  reach them through the Coolify terminal (`docker exec`) or SSH.

Point the clients at the public API origin (§4): `NEXT_PUBLIC_API_BASE` for
web/admin builds, `CORS_ORIGINS` + `APP_DOMAIN` for the api. DNS records +
Cloudflare proxying: docs/HUMAN_STEPS.md §6.

---

## 4. Environment variables (complete reference for the Coolify resource)

Every `${VAR}` below is set in the Coolify resource's environment editor.
`openssl rand -base64 48` generates good secrets. The compose file
**hard-fails the deploy** (`:?` interpolation) on any variable marked **✔**
that is empty — Coolify shows which one in the deploy log.

### PostgreSQL

| Variable | Req | Notes |
|---|---|---|
| `POSTGRES_PASSWORD` | **✔** | owner/migration role password (`DIRECT_URL`) |
| `SUNNAH_APP_PASSWORD` | **✔** | password of the NOBYPASSRLS runtime role `sunnah_app`, created on first init by the baked-in `init-rls.sql`; interpolated into `DATABASE_URL` |
| `POSTGRES_USER` | opt | default `postgres` |
| `POSTGRES_DB` | opt | default `sunnahlife` — **keep it**: the RLS grants target this exact database |
| `PG_SHARED_BUFFERS` / `PG_MAX_CONNECTIONS` | opt | defaults `256MB` / `100` |

### Search / Redis (hard-wired, listed for completeness)

`MEILI_HOST` (`http://meilisearch:7700`), `MEILI_KEY` (=
`MEILI_MASTER_KEY`), `REDIS_URL` (`redis://redis:6379`), `DATABASE_URL`
(`postgresql://sunnah_app:…@postgres:5432/sunnahlife`), `DIRECT_URL`
(`postgresql://<POSTGRES_USER>:…@postgres:5432/sunnahlife`) — all composed
inside the file from the two Postgres passwords + `MEILI_MASTER_KEY`; you set
none of them yourself.

| Variable | Req | Notes |
|---|---|---|
| `MEILI_MASTER_KEY` | **✔** | meili container env; the api receives the same value as `MEILI_KEY` |

### api + worker (shared `&api-env` anchor — both get the whole block)

| Variable | Req | Notes |
|---|---|---|
| `JWT_SECRET` | **✔** | signs access tokens (min 8 chars; production boot refuses the dev default) |
| `JWT_REFRESH_SECRET` | **✔** | refresh tokens (production requires it, different from `JWT_SECRET`) |
| `QUIZ_SECRET` | **✔** | HMAC secret for live-quiz room tokens |
| `APP_DOMAIN` | **✔** | canonical domain for referral links |
| `CORS_ORIGINS` | **✔** | comma list of browser origins (production refuses empty) |
| `NODE_ENV` | opt | default `production` in the compose file. Set `staging` on the staging stack (§6 demo seed, §8 production) |
| `SMS_PROVIDER` | opt | default `mock`; `sslwireless` or `infobip` in production (§8) |
| `SMS_SSLWIRELESS_URL` / `_USER` / `_PASS` | opt | SSL Wireless v3 API credentials (see docs/HUMAN_STEPS.md §2) |
| `SMS_INFOBIP_URL` / `_KEY` | opt | Infobip alternative |
| `FCM_SERVICE_ACCOUNT_JSON` | opt | Firebase service-account JSON (object string or file path) for push — docs/HUMAN_STEPS.md §1 |
| `GOOGLE_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` | opt | social-login audiences — docs/HUMAN_STEPS.md §3 |
| `APPLE_SERVICES_ID` / `APPLE_IOS_BUNDLE_ID` / `APPLE_TEAM_ID` | opt | social-login audiences — docs/HUMAN_STEPS.md §3 |
| `METRICS_TOKEN` | opt | unlocks `GET /metrics`; unset ⇒ /metrics 403s in production |
| `DOCS_ENABLED` | opt | `false` disables Swagger UI + `/openapi.json`; unset ⇒ enabled outside production only |
| `ACCESS_TOKEN_TTL_MIN` / `REFRESH_TOKEN_TTL_DAYS` | opt | defaults `15` / `7` |
| `S3_ENDPOINT` / `S3_BUCKET` / `S3_ACCESS_KEY` / `S3_SECRET_KEY` / `S3_PUBLIC_BASE` | opt | all four ⇒ S3 storage adapter activates; otherwise local volume (§5) |

### web + admin builds

| Variable | Req | Notes |
|---|---|---|
| `NEXT_PUBLIC_API_BASE` | **✔** | **build arg**, not runtime env — see below |
| `NEXT_PUBLIC_DEMO` | opt | admin build arg; `"true"` shows the demo quick-login grid (staging/demo builds only) |

### NEXT_PUBLIC_API_BASE is a BUILD ARG (rebuild to change)

Next.js inlines `NEXT_PUBLIC_*` into the client bundle at **build** time, so
the compose file passes it as a build argument and the Dockerfiles bake it:

```yaml
# infra/coolify.compose.yml — the web service
    build:
      args:
        NEXT_PUBLIC_API_BASE: ${NEXT_PUBLIC_API_BASE:?set NEXT_PUBLIC_API_BASE}
```

```dockerfile
# infra/web.Dockerfile
ARG NEXT_PUBLIC_API_BASE=""
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE}
```

(`infra/admin.Dockerfile` does exactly the same, plus `NEXT_PUBLIC_DEMO`.)
Consequences:

- the value must be the **public, browser-reachable** API origin —
  `https://api-staging.sunnahlife.ailearnersbd.com` on the current staging
  stack (NOT `http://api:4000`, which only exists inside the Docker network —
  browsers cannot resolve it);
- changing it means **redeploying so the images rebuild** — editing the env
  alone is not enough. The `:?` in the compose line means an unset value
  blocks the deploy outright.

---

## 5. Health checks — `/health/live` gates the orchestrator, `/health/ready` is for monitors

The api exposes a **liveness/readiness split** (C-W5-ops), and everything the
orchestrator touches points at liveness only:

- **`GET /health/live`** — liveness: the process is up, the event loop
  turns, **zero dependency calls**. Always 200 while the app can answer at
  all. This is what the Docker `HEALTHCHECK`, the compose healthcheck and
  therefore **Coolify's Traefik** gate routing on.
- **`GET /health/ready`** (and the legacy alias **`GET /health`**) —
  readiness: probes postgres · redis · meili · storage with a 1.5 s
  per-check budget, returns **503 when degraded**. Point uptime monitors
  (UptimeRobot, Better Stack, …) HERE, never at `/health/live`.

The compose healthcheck for the api, verbatim:

```yaml
    healthcheck:
      # [C-W5-ops] liveness only — readiness (/health, /health/ready) is for
      # monitoring; slow deps must not flip the container unhealthy
      # (Traefik drops unhealthy containers).
      test: ["CMD-SHELL", "curl -fsS http://localhost:4000/health/live"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 90s
```

The endpoint lives in `apps/api/src/health/health.controller.ts`
(`@Get("health/live")`, excluded from the `/api` global prefix in
`src/main.ts`), and the same `curl …/health/live` also gates the image's own
Dockerfile `HEALTHCHECK`. Why the split matters: on the live staging
deployment a slow Postgres used to flip the *serving* api container
"unhealthy" and Traefik dropped it ("no available server") — a liveness-only
probe must never do that again.

The other services' healthchecks (all in the compose file): postgres
`pg_isready`, redis `redis-cli ping`, meili `curl -fsS
http://localhost:7700/health`, worker = `kill -0 1` + a bun/ioredis `PING`,
web/admin `curl -fsS http://localhost:3000/`.

### First deploy, service by service

Boot order is orchestrated by `depends_on: condition: service_healthy`:
postgres/redis/meili become healthy → **api** runs `prisma migrate deploy`
(owner role via `DIRECT_URL`) + the idempotent **reference seed** (amal
catalog, farze-ain template, app config — never deletes), then serves →
**worker** starts after the api is healthy → **web** + **admin** come up.
`start_period: 90s` on the api covers the first-boot migration.

**Verify after each service** (Coolify terminal or SSH on the VPS; the public
commands work from anywhere):

```bash
# postgres / redis / meili — Coolify's service list shows (healthy); on the
# host (Coolify names the compose project itself — plain docker ps):
docker ps --format "table {{.Names}}\t{{.Status}}"   # every service (healthy)

# api — liveness (what routing gates on):
curl -s https://api-staging.sunnahlife.ailearnersbd.com/health/live
#  → {"status":"ok","uptimeSeconds":…,"pid":…,"version":"…"}

# api — readiness (what monitors watch; also proves postgres+redis+meili+storage):
curl -s https://api-staging.sunnahlife.ailearnersbd.com/health/ready
#  → {"status":"ok","checks":{"postgres":true,"redis":true,"meilisearch":"ok","storage":"local"},…}

# worker — no HTTP; check it holds healthy + logs show BullMQ queues:
docker logs <worker-container> 2>&1 | tail   # or Coolify's log stream

# web — open https://<web-domain> in a browser (page shell loads; sign-in modal
#       appears; API errors would surface as /api/* failures in the console):
curl -s -o /dev/null -w "%{http_code}\n" https://<web-domain>/   # 200

# admin — open https://admin.<domain>; the login page renders:
curl -s -o /dev/null -w "%{http_code}\n" https://admin.<domain>/   # 200
```

First boot also indexes the content packs into Meilisearch (v1.x API) — the
duas/adhkar/names indexes appear in the meili logs. Then demo-login to the
web app with any phone from docs/DEMO_ACCOUNTS.md §1 (staging only, §6).

---

## 6. No MinIO — local storage volume, S3 via env when one exists

The Coolify stack deliberately runs **without MinIO**: anonymous pulls of
MinIO images stopped being available (see the `infra/docker-compose.yml`
header comment), so the api falls back to its **local storage adapter**:

```yaml
# infra/coolify.compose.yml — api + worker both mount it:
    environment:
      STORAGE_DIR: /app/storage
    volumes:
      - apistorage:/app/storage
```

- Generated objects (monthly PDF reports, etc.) land under the `apistorage`
  named volume — persistent across restarts/redeploys, shared by api +
  worker.
- The storage probe in `apps/api/src/storage/storage.module.ts` activates the
  **S3 adapter only when `S3_ENDPOINT` + `S3_BUCKET` + `S3_ACCESS_KEY` +
  `S3_SECRET_KEY` are ALL set** — the same probe the `/health/ready` storage
  check uses (it reports `"local"` vs `"s3"`). When the client provisions a
  real bucket, set the four `S3_*` variables in Coolify and redeploy — no
  code change. `S3_PUBLIC_BASE` optionally fronts object URLs with a CDN.
- The demo login grid on the admin console is build-gated by
  `NEXT_PUBLIC_DEMO` — leave it unset for anything client-facing.

### The demo seed — NON-PRODUCTION only

The api's boot seed is **reference data only** (idempotent, never deletes).
The demo dataset (15 users, usrahs, 30 days of amal history — the accounts in
docs/DEMO_ACCOUNTS.md) is seeded manually, and the seed **refuses to run when
`NODE_ENV=production`** (`apps/api/prisma/seed-demo.ts` exits 1: "SEED_DEMO=true
is REFUSED in production — demo data would wipe real users"):

```bash
# inside the running api container (Coolify terminal → api service, or):
docker exec -it <api-container> bun run seed:demo
# = SEED_DEMO=true bun prisma/seed.ts   (apps/api package.json)
```

Requires the staging stack to run with `NODE_ENV=staging` (or anything ≠
`production`) — the api's env.validation accepts `staging` as a value. The
demo seed wipes **user-domain tables only** (users, usrahs, amal entries) and
never touches reference data. Verify afterwards by OTP-logging in as
`01000000001` (mock SMS returns `devCode` — docs/DEMO_ACCOUNTS.md §3).

---

## 7. The git flow — main → staging → Coolify redeploy

What is actually happening today (and this doc's contract with it):

1. **All work lands on `main`** — commits, CI (`ci.yml` runs on pushes to
   main: api jest, flutter analyze/test/debug APK, release-APK jobs, docker
   smoke), review.
2. **`infra/coolify.compose.yml` is mirrored on the `staging` branch** — the
   file carries the reminder verbatim:
   ```yaml
   # [C-W5-ops] This file is mirrored on the `staging` branch — that is what
   # Coolify actually deploys. Keep the two copies in sync: the api healthcheck
   # targets /health/live here AND on staging (same change on both branches).
   ```
3. **To deploy, the owner merges `main` into `staging`** (nothing deploys
   straight from main):
   ```bash
   git checkout staging && git merge main && git push origin staging
   ```
4. **Then hits Redeploy on the Coolify resource.** Coolify pulls the staging
   branch, rebuilds changed images and recreates the services — migrations
   run in the api entrypoint before serving (`prisma migrate deploy`,
   non-interactive, ordered, idempotent), the worker waits for the api's
   healthcheck.
5. Verify the redeploy: `curl https://<api-domain>/health/live` → 200, then
   `/health/ready` → all checks true; open the web domain; check the Coolify
   service list is all `(healthy)`.

This is exactly how the live fixes went out (worklog C-OPS/W5-ops): the api
code + `/health/live` healthchecks were mirrored to staging (HEAD `2c2d28f`
at the time) and one redeploy delivered both the Traefik-outage fix and the
Meilisearch v1.x create-index route.

### Update / rollback

- **Update** = the flow above (merge → redeploy). Pick up NEW env variables
  by diffing `.env.example` against the Coolify resource's env list before
  redeploying.
- **Rollback** = redeploy an older staging commit: `git checkout <sha>` on
   staging (or revert the merge) → push → Redeploy. Database migrations are
   **forward-only** by policy — if a migration must be reverted, write a new
   compensating migration; if data was lost, restore from backups (§8).
- Destructive schema changes: take a full backup FIRST (§8), deploy in a
  low-traffic window (the amal locking rule is Dhaka-time anchored —
  mid-morning BD time, after yesterday's diary is locked).

---

## 8. Production differences (staging today → the client's production)

Exactly these five items change between the current staging stack and a
production deployment:

1. **`NODE_ENV=production`.** The compose file defaults it already
   (`NODE_ENV: ${NODE_ENV:-production}`) — the point is what it switches on:
   the api's env.validation **refuses to boot** on the dev-default
   `JWT_SECRET`, a missing/duplicate `JWT_REFRESH_SECRET`, the dev
   `QUIZ_SECRET`, empty `CORS_ORIGINS`, and `SMS_PROVIDER=mock` (the
   production-boot rules in `apps/api/src/config/env.validation.ts`); `/docs`
   + `/metrics` clamp shut without opt-ins. It also (correctly) makes
   `bun run seed:demo` impossible (§6).
2. **A real SMS provider — not the mock.** The repo's Bangladesh provider is
   **SSL Wireless** (v3 HTTP API): `SMS_PROVIDER=sslwireless` plus
   `SMS_SSLWIRELESS_URL` / `SMS_SSLWIRELESS_USER` / `SMS_SSLWIRELESS_PASS`
   (the sender id is hard-coded `SUNNAHLIFE` in
   `apps/api/src/auth/sms/sms-providers.ts`). Production refuses mock AND
   refuses `sslwireless` with missing credentials — get the three values from
   the client's SSL Wireless account (docs/HUMAN_STEPS.md §2). `infobip`
   (`SMS_INFOBIP_URL`/`_KEY`) is the wired alternative.
3. **The client's domain behind Cloudflare, websockets enabled for
   `/socket.io`.** The live usrah quiz rides socket.io **on the api's own
   HTTP server at the `/socket.io` path** (`apps/api/src/main.ts` — one
   backend, one auth, Redis adapter across replicas). Cloudflare proxies
   websockets by default; keep them ON (Network → WebSockets) and make sure
   any page rule/zone setting that disables them excludes the api hostname.
   DNS: proxied `A` records for the web/admin/api hostnames → VPS IP; SSL
   mode **Full (strict)** (Coolify's Traefik serves the origin cert). Full
   DNS walkthrough: docs/HUMAN_STEPS.md §6.
4. **Off-site backups.** The stack already archives WAL into the `pgdata`
   volume (`archive_mode=on`, `archive_command` copies segments to
   `walarchive/` inside the volume — see the postgres `command:` in the
   compose file), and `infra/postgres/pgbackrest.conf` is a ready pgBackRest
   template (remote S3 repo, AES-256, retention). The **scheduled backup cron
   + off-site bucket are owner-side** — nothing in the repo schedules them
   (honest TODO; see docs/HUMAN_STEPS.md §7 for the exact arrangement: a
   nightly `pgbackrest` one-shot container over the `pgdata` volume + a copy
   of the `apistorage` volume). Test a restore once before you need it.
5. **Repo private + connected through the GitHub App.** Make the GitHub repo
   private, then in Coolify install/authorize the **Coolify GitHub App**
   (Coolify → Sources → GitHub) and point the resource at the private repo —
   the App token is how Coolify clones private repositories over HTTPS
   without a personal access token. Redeploys continue unchanged (§7).
   (On GitHub's side: Settings → General → Danger Zone → Change visibility.)

Staging extras that must NOT ship to production: `NODE_ENV=staging`, the
demo seed (§6), `NEXT_PUBLIC_DEMO=true` on the admin build, and
`SMS_PROVIDER=mock` (devCodes in API responses).

---

## 9. Observability

- **`/health/live`** (api, port 4000) — liveness; what Traefik + Docker gate
  on. Monitor NOT here.
- **`/health/ready`** (alias `/health`) — readiness with per-check detail;
  503 when degraded. **Point UptimeRobot here.**
- **`GET /metrics`** — Prometheus exposition (request latency, error rates,
  queue depths). Needs `METRICS_TOKEN` in production:
  `curl -s -H "Authorization: Bearer <token>" https://<api-domain>/metrics`.
- **Container health:** the Coolify resource view must show every service
  `(healthy)` — same info on the host via `docker ps` (Coolify names the
  compose project itself).
- **Logs:** Coolify's per-service log stream (json-file driver, 10 MB × 3
  rotation per container — the `x-logging` anchor). No PII in api logs
  (phones are masked even in the mock SMS path).
- **Web sanity:** `GET /` 200 is the web healthcheck — the shell loads; data
  errors surface as `/api/*` failures in the browser console.

---

## 10. Troubleshooting quick hits

| Symptom | Check |
|---|---|
| deploy fails with `set POSTGRES_PASSWORD` (or another `set …` line) | a `:?` variable is missing in the Coolify resource env — the log names it (§4) |
| build fails on api/web | build context must be the **repo root** (§2) — if the context was pasted from the dev compose or started as a plain-Dockerfile resource, rebuild the resource from `infra/coolify.compose.yml` |
| api restart-loops with `Invalid environment configuration` | env.validation refused the boot — read the message (production rules, §8.1): dev-default JWT_SECRET, mock SMS in production, empty CORS_ORIGINS, … |
| web loads but every action errors | `NEXT_PUBLIC_API_BASE` baked wrong (must be the public api origin) — set it correctly and REDEPLOY so the image rebuilds (§4) |
| admin login blank / CORS errors in console | `CORS_ORIGINS` missing the admin origin, or `NEXT_PUBLIC_API_BASE` wrong |
| quiz connects then dies at load | Cloudflare websockets disabled for the api hostname (§8.3) |
| api `(healthy)` but `/health/ready` says degraded | read `checks` in the response — the named dependency is down; the api keeps serving (that is the split working) |
| demo login 400/404 | demo dataset not seeded (§6) or the stack runs `NODE_ENV=production` |
| meili indexes empty after first boot | check the meili + api logs; the api boot indexer populates them (needs meili healthy, which `depends_on` guarantees) — indexes broken by an older deploy can be wiped; the `meili` volume is rebuildable from the database |
| `postgres` unhealthy loop | the `pgdata` volume was initialised with different `POSTGRES_*` values — either restore them or wipe the volume (destroys data!) |

---

*Cross-references: human-only setup steps (Firebase/push, SSL Wireless,
OAuth ids, signing keys, DNS, backups) → docs/HUMAN_STEPS.md; mobile release
artifacts + the device-test checklist → docs/RELEASE.md,
docs/PHONE_TEST_CHECKLIST.md; demo accounts → docs/DEMO_ACCOUNTS.md; local
dev stack → docs/ENVIRONMENT.md + `infra/docker-compose.yml`.*
