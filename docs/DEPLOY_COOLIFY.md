# Sunnah Life — Deployment on the client's VPS with Coolify (DEPLOY_COOLIFY.md)

Target: the client's own virtual server, managed with
[Coolify](https://coolify.io) (Docker + docker compose under the hood), with
**Cloudflare** in front. Everything below maps 1:1 to `infra/docker-compose.yml`
— if a value here and a value there disagree, the compose file wins; fix the
docs when you change it.

---

## 1. Prerequisites

| Item | Requirement |
|---|---|
| VPS | **2 vCPU / 4 GB RAM / 40 GB SSD minimum** (the full stack idles ≈ 2.2 GB). 4 vCPU / 8 GB recommended for production headroom. Debian 12/13 or Ubuntu 22.04+. |
| Docker | installed by Coolify itself (Coolify requires a fresh server with SSH root access — it installs Docker Engine, configures the firewall, and runs as a set of containers). |
| Compose | docker compose **v2** (plugin) — required for per-Dockerfile `.dockerignore` support and healthcheck conditions. Ships with any Docker installed by Coolify. |
| DNS | a domain at Cloudflare (free tier is fine) — see §5. |
| Git | the repo (GitHub/GitLab/Forgejo) reachable from the VPS; Coolify deploys from it. |
| Off-site S3 | a bucket + keypair for pgBackRest (any S3-compatible provider, e.g. AWS S3, Backblaze B2, Wasabi). Required for §6 backups. |

> **No root beyond Coolify's own install** is needed afterwards — every
> operational command below runs through `docker compose` (the `docker` group)
> or the Coolify UI.

---

## 2. What gets deployed (the 10 services)

| Service | Image | Host port | Notes |
|---|---|---|---|
| `postgres` | postgres:16 | — (internal) | `sunnahlife` DB; RLS bootstrap on first init; volume `pgdata` |
| `redis` | redis:7 | — (internal) | BullMQ queues + cache; no persistence by design |
| `minio` | minio/minio | — (internal) | S3 API :9000 + console :9001, internal only; volume `miniodata` |
| `minio-init` | minio/mc | — | one-shot: creates the `sunnahlife` bucket |
| `meilisearch` | getmeili/meilisearch:v1.54.0 | — (internal) | Bengali typo-tolerant search; volume `meili` |
| `api` | built from the repo root (`apps/api` + `packages/content`) via `infra/api.Dockerfile` | **4000** | NestJS; runs migrations + idempotent seed then serves |
| `worker` | same image as `api` | — | BullMQ workers, different command; no HTTP — health = liveness probe (PID 1 + Redis ping) |
| `web` | built from repo root via `infra/web.Dockerfile` | **3000** | Next.js PWA (standalone) + seeded SQLite mirror on volume `webdata` |
| `admin` | built from `apps/admin` via `infra/admin.Dockerfile` | **3002** → 3000 | Next.js admin panel |
| `proxy` (optional profile) | caddy:2-alpine | 80/443 | reverse proxy; Cloudflare sits in front anyway |

Everything runs on the internal `sunnah` bridge network with `restart:
unless-stopped` and a healthcheck each — `docker compose ps` must show every
service `(healthy)` (minio-init shows `exited (0)` — that is success).

**Minimal start** (if you only want the data layer while apps/* are still
landing): `docker compose --env-file .env -f infra/docker-compose.yml up -d
postgres redis minio minio-init meilisearch`.

---

## 3. Bring-up — three supported paths

### Path A — plain docker compose from a git clone (fastest, recommended)

```bash
ssh user@your-vps
git clone https://github.com/<org>/sunnahlife.git && cd sunnahlife
cp .env.example .env && nano .env      # fill the secrets (§4)
docker compose --env-file .env -f infra/docker-compose.yml up -d --build
```

`--env-file .env` matters: compose looks for `.env` **next to the compose file**
(`infra/`), but the repo keeps it at the root. The convenience wrapper
`./infra/up.sh` runs exactly this.

First boot order is orchestrated by healthchecks: postgres/redis/meili/minio
become healthy → `minio-init` creates the bucket → `api` runs
`prisma migrate deploy` + the idempotent seed → `worker` starts after the api
is healthy → `web` builds its SQLite mirror + demo seed on its volume →
`admin` comes up.

Verify:

```bash
docker compose --env-file .env -f infra/docker-compose.yml ps
curl -s http://localhost:4000/health   # api
curl -s http://localhost:3000/api/config | head -c 200   # web
```

### Path B — Coolify "Docker Compose" stack

1. Coolify → **Resources → New → Docker Compose** (Empty/Custom).
2. Paste/upload `infra/docker-compose.yml` (or point Coolify at the repo and
   the compose file path).
3. Add the environment variables from §4 in the resource's **Environment
   Variables** section (Coolify injects them into the stack).
4. **Caveats:**
   - Coolify rewrites/rewrites bind-mount paths for some templates — the only
     bind mount in the stack is `./postgres/init-rls.sql` (and `./Caddyfile`
     for the proxy profile). If Coolify clones the repo for you, keep the
     working copy path stable, or switch the two mounts to absolute paths
     (`/data/coolify/applications/<uuid>/infra/postgres/init-rls.sql`).
   - Alternatively use Path C for the `postgres` service only and keep the
     rest as a stack — the RLS init only needs to exist at first database init.
5. **Deploy**. Coolify streams the build logs; the stack comes up exactly like
   Path A.

### Path C — one Coolify application per service (maximum Coolify-ness)

Create each service with a **Build pack: Dockerfile** (⚠ the api + worker
build contexts are the **repo root**, not apps/api — the image bundles
`packages/content` for the seed + content routes):

| Coolify app | Dockerfile location | Build context |
|---|---|---|
| `api` | `/infra/api.Dockerfile` | `/` (repo root — needs `apps/api` + `packages/content`) |
| `worker` | `/infra/api.Dockerfile` (same image; override the command with the worker line from the compose file) | `/` (repo root) |
| `web` | `/infra/web.Dockerfile` | `/` (repo root) |
| `admin` | `/infra/admin.Dockerfile` | `/apps/admin` |
| `postgres` / `redis` / `minio` / `meilisearch` | — (public images, create as Coolify "Docker Image" resources) | — |

Attach a Coolify network named `sunnah` to all of them (equivalent of the
compose network) and copy each service's environment block from the compose
file. More clicking, but every app gets its own deploy button, healthcheck UI
and log stream.

---

## 4. Environment variables (complete reference)

Copy `.env.example` → `.env` at the repo root (or into the Coolify stack's
environment editor). `openssl rand -base64 48` generates good secrets.

### PostgreSQL (postgres service)

| Variable | Example | Req | Notes |
|---|---|---|---|
| `POSTGRES_USER` | `postgres` | ✔ | owner/migration role (used in `DIRECT_URL`) |
| `POSTGRES_PASSWORD` | `xK7…` | **✔** | strong secret |
| `POSTGRES_DB` | `sunnahlife` | ✔ | keep the default — the API's RLS migration grants on this exact database name |
| `SUNNAH_APP_PASSWORD` | `aN3…` | **✔** | password of the NOBYPASSRLS runtime role `sunnah_app` — created by `infra/postgres/init-rls.sql` on first init; compose interpolates it into `DATABASE_URL` |
| `PG_SHARED_BUFFERS` | `256MB` | opt | postgres tuning (default 256MB) |
| `PG_MAX_CONNECTIONS` | `100` | opt | default 100 |

### Object storage (minio + api)

| Variable | Example | Req | Notes |
|---|---|---|---|
| `MINIO_ROOT_USER` | `sunnahlife` | **✔** | **= `S3_ACCESS_KEY`** (compose maps them) |
| `MINIO_ROOT_PASSWORD` | `qM9…` | **✔** | **= `S3_SECRET_KEY`** |
| `S3_BUCKET` | `sunnahlife` | ✔ | created by `minio-init` |
| `S3_PUBLIC_BASE` | *(empty)* | opt | CDN base for public object URLs; empty = served via the api |

(`S3_ENDPOINT` is hard-wired by compose to `http://minio:9000`; the api reads
`S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PUBLIC_BASE`
per `apps/api/src/config/env.validation.ts`.)

### Search (meilisearch + api)

| Variable | Example | Req | Notes |
|---|---|---|---|
| `MEILI_MASTER_KEY` | `b2F…` (≥16 bytes) | **✔** | meili container env; the api receives the same value as `MEILI_KEY` |

### Redis / connections (api + worker)

| Variable | Example | Req | Notes |
|---|---|---|---|
| `REDIS_URL` | `redis://redis:6379` | ✔ | hard-wired inside compose; set it yourself only when running apps outside compose |
| `DATABASE_URL` | `postgresql://sunnah_app:…@postgres:5432/sunnahlife` | ✔ | composed automatically from `SUNNAH_APP_PASSWORD`; this is the **RLS-bound runtime** connection |
| `DIRECT_URL` | `postgresql://postgres:…@postgres:5432/sunnahlife` | ✔ | owner connection for `prisma migrate deploy` + seed |
| `MEILI_HOST` | `http://meilisearch:7700` | ✔ | hard-wired in compose |

### API / worker (apps/api)

| Variable | Example | Req | Notes |
|---|---|---|---|
| `API_PORT` | `4000` | ✔ | **host** port for the api (the container always listens on 4000) |
| `JWT_SECRET` | `J4v…` (min 8) | **✔** | signs access tokens (and refresh tokens when `JWT_REFRESH_SECRET` is unset); rotation + family revocation via the `RefreshToken` table |
| `JWT_REFRESH_SECRET` | *(empty)* | opt | separate secret for refresh tokens; empty ⇒ `JWT_SECRET` is used |
| `ACCESS_TOKEN_TTL_MIN` | `15` | opt | |
| `REFRESH_TOKEN_TTL_DAYS` | `7` | opt | |
| `APP_DOMAIN` | `sunnahlife.app` | opt | canonical domain used in referral links (`https://<APP_DOMAIN>/?join=DS-XXXXXX`) |
| `CORS_ORIGINS` | `https://sunnahlife.app,https://admin.sunnahlife.app` | opt | comma list of browser origins |
| `SMS_PROVIDER` | `mock` | opt | `mock` (dev — OTP returned as `devCode`) · `sslwireless` · `infobip` |
| `SMS_SSLWIRELESS_URL` / `_USER` / `_PASS` | | opt | SSL Wireless credentials |
| `SMS_INFOBIP_URL` / `_KEY` | | opt | Infobip credentials |

### Web (repo-root Next.js)

| Variable | Example | Req | Notes |
|---|---|---|---|
| `WEB_PORT` | `3000` | ✔ | host port |
| `SEED_WEB_MIRROR` | `true` | opt | first-boot SQLite mirror + demo seed (docs/DEMO_ACCOUNTS.md); `false` = clean web |
| `NEXT_PUBLIC_API_BASE` | *(empty)* | opt | reserved: when the web client is switched to call the NestJS API directly it is baked at build time; empty = the web app uses its own routes (mirror mode) |

### Admin (apps/admin)

| Variable | Example | Req | Notes |
|---|---|---|---|
| `ADMIN_PORT` | `3002` | ✔ | host port |
| `PUBLIC_API_BASE` | `https://api.sunnahlife.app` | ✔ for prod | **build arg** (`NEXT_PUBLIC_API_BASE` inside apps/admin) — baked into the client bundle, rebuild to change |

### Reverse proxy profile (optional)

| Variable | Example | Notes |
|---|---|---|
| `WEB_DOMAIN` / `ADMIN_DOMAIN` / `API_DOMAIN` | `sunnahlife.app` / `admin.sunnahlife.app` / `api.sunnahlife.app` | Caddy site addresses (infra/Caddyfile) |
| `ACME_EMAIL` | `admin@sunnahlife.app` | origin cert email |

### Housekeeping

| Variable | Example | Notes |
|---|---|---|
| `STACK_TAG` | `latest` | image tag; set to a git SHA for rollback-able releases (§10) |

---

## 5. Domains & Cloudflare

1. **DNS:** in the Cloudflare dashboard create proxied (orange-cloud) records:
   - `A  sunnahlife.app        → <VPS IP>` (web)
   - `A  admin.sunnahlife.app  → <VPS IP>` (admin)
   - `A  api.sunnahlife.app    → <VPS IP>` (api)
2. **SSL mode: "Full (strict)"** — the origin (Caddy from the `proxy` profile,
   or Coolify's own Traefik if you prefer) must serve a valid cert. With the
   compose `proxy` profile, Caddy obtains Let's Encrypt certs automatically
   (`infra/Caddyfile`); Cloudflare validates whatever it serves.
   - If you keep Cloudflare's free Universal SSL + "Flexible" mode instead,
     TLS stops at the edge — acceptable for demos, **not** for sisters' data;
     use Full (strict).
3. **WebSockets:** enabled by default on Cloudflare — no page rule needed.
   Live sessions (and any future LiveKit SFU) work over the proxied ports
   443/2053/2083/2087/2096/8443. Caddy's `reverse_proxy` upgrades them
   automatically.
4. Recommended **cache rules**: cache `/_next/static/*` and `/icons/*`
   (immutable, 1 year), bypass cache for `/api/*` and `/admin/*`.
5. Point the apps at their public URLs (set in `.env`):
   `PUBLIC_API_BASE=https://api.sunnahlife.app`,
   `CORS_ORIGINS=https://sunnahlife.app,https://admin.sunnahlife.app`,
   `APP_DOMAIN=sunnahlife.app`, and the `*_DOMAIN` values for the proxy.
6. **Meilisearch and MinIO are never published** — compose gives them no host
   ports. Access them only via `docker compose exec` / SSH tunnels.

---

## 6. Volumes & backup strategy

Docker named volumes: `pgdata` (critical), `webdata` (web mirror DB),
`miniodata` (media), `meili` (rebuildable indexes).

### 6.1 PostgreSQL — pgBackRest to off-site S3 (the critical backup)

Configure `infra/postgres/pgbackrest.conf` (placeholders marked `<…>`): a
REMOTE S3 repo, AES-256 repo encryption, retention 2 full + 6 diff backups,
30-day archive (PITR-capable WAL). The backup containers reach postgres over
the shared `pgsocket` volume (unix socket — the official image trusts local
connections, so no passwords travel between containers).

The volume triple every pgBackRest command needs (repo root on the VPS):

```bash
PGBR="-v sunnahlife_pgdata:/var/lib/postgresql/data:ro \
      -v sunnahlife_pgsocket:/var/run/postgresql \
      -v $PWD/infra/postgres/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro"
```

One-shot containers (from the repo root on the VPS):

```bash
# first use: create the stanza (also self-heals after major upgrades)
docker run --rm $PGBR pgbackrest/pgbackrest:latest \
  --stanza=sunnahlife stanza-create

# nightly full backup (cron 03:15 Asia/Dhaka) — add to the VPS crontab
docker run --rm $PGBR pgbackrest/pgbackrest:latest \
  --stanza=sunnahlife --type=full backup

# a differential backup mid-day
docker run --rm $PGBR pgbackrest/pgbackrest:latest \
  --stanza=sunnahlife --type=diff backup

# verify + list backups (repo-side, does not touch the database)
docker run --rm $PGBR pgbackrest/pgbackrest:latest \
  --stanza=sunnahlife info
```

**Restore drill (do it once before you need it):**

```bash
docker compose --env-file .env -f infra/docker-compose.yml stop api worker postgres
docker run --rm \
  -v sunnahlife_pgdata:/var/lib/postgresql/data \
  -v sunnahlife_pgsocket:/var/run/postgresql \
  -v "$PWD/infra/postgres/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro" \
  pgbackrest/pgbackrest:latest \
  --stanza=sunnahlife --delta restore
docker compose --env-file .env -f infra/docker-compose.yml start postgres api worker
```

### 6.2 MinIO bucket → off-site copy

The local MinIO holds media + generated PDFs. Mirror it to the same off-site
S3 with `mc`:

```bash
docker run --rm --network sunnah \
  -e MC_HOST_src="http://$MINIO_ROOT_USER:$MINIO_ROOT_PASSWORD@minio:9000" \
  -e MC_HOST_dst="https://<offsite-key>:<offsite-secret>@s3.<region>.amazonaws.com" \
  minio/mc:latest \
  mc mirror --overwrite --remove src/sunnahlife dst/sunnahlife-minio
```

### 6.3 Schedule it

Crontab on the VPS (`crontab -e` — assumes the repo at `/opt/sunnahlife`):

```cron
# m h  dom mon dow   command
15 3 * * *  cd /opt/sunnahlife && PGBR="-v sunnahlife_pgdata:/var/lib/postgresql/data:ro -v sunnahlife_pgsocket:/var/run/postgresql -v $PWD/infra/postgres/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro" && docker run --rm $PGBR pgbackrest/pgbackrest:latest --stanza=sunnahlife --type=full backup
0  5 * * 1  cd /opt/sunnahlife && PGBR="-v sunnahlife_pgdata:/var/lib/postgresql/data:ro -v sunnahlife_pgsocket:/var/run/postgresql -v $PWD/infra/postgres/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro" && docker run --rm $PGBR pgbackrest/pgbackrest:latest --stanza=sunnahlife --type=diff backup
30 4 * * *  cd /opt/sunnahlife && docker run --rm --network sunnah -e MC_HOST_src="http://$MINIO_ROOT_USER:$MINIO_ROOT_PASSWORD@minio:9000" -e MC_HOST_dst="https://<offsite-key>:<offsite-secret>@s3.<region>.amazonaws.com" minio/mc:latest mc mirror --overwrite --remove src/sunnahlife dst/sunnahlife-minio
```

Test restores quarterly; a backup that has never been restored is a hope, not
a backup.

---

## 7. Scaling notes

- **The wall is the database, not the containers.** At 2 vCPU/4 GB keep one
  `api` replica; PostgreSQL's `max_connections=100` is plenty (Prisma pools
  ~10 per process).
- `docker compose … up -d --scale api=2` works (stateless behind the proxy);
  only the FIRST replica should run the seed race — the entrypoint tolerates
  seed races (logs a warning, continues).
- The `worker` scales horizontally too (`--scale worker=2`) — BullMQ queues
  distribute jobs; keep at 1 on a 2 vCPU box.
- Meilisearch: give it RAM (`meili` volume grows with the corpus); rebuild
  indexes from the API after major content changes.
- Redis has **no persistence by design** (queues/cache only) — losing a
  pending job queue is acceptable; the diary sync protocol is idempotent and
  client-side retries cover it.
- For >10 k users move Postgres to a dedicated box (same pgBackRest config,
  `pg1-host` set accordingly) and put Cloudflare in front of a horizontally
  scaled api.

---

## 8. Update procedure

```bash
ssh user@your-vps && cd sunnahlife
git pull
cp .env.example /tmp/env.new && diff .env /tmp/env.new   # pick up NEW variables!
docker compose --env-file .env -f infra/docker-compose.yml build          # rebuild
docker compose --env-file .env -f infra/docker-compose.yml up -d          # recreate
```

**Migration policy:** `prisma migrate deploy` (non-interactive, ordered,
idempotent — only unapplied migrations run) executes automatically in the
`api` container's entrypoint **before** the new server process starts; the
worker waits for the api's healthcheck. For schema changes:

1. additive columns/tables → safe, deploy freely;
2. destructive changes → take a full pgBackRest backup **first** (§6.1), then
   deploy during a low-traffic window (the locking rule is Dhaka-time
   anchored — pick mid-morning BD time when yesterday's diary is already
   locked);
3. never edit an applied migration — always add a new one.

Coolify Path B/C: the same flow is "pull latest → redeploy" per resource.

---

## 9. Observability

- **`GET /health`** on the api (port 4000) — liveness for compose/Coolify/
  Cloudflare health checks (also used by the Dockerfile HEALTHCHECK).
- **`GET /metrics`** on the api — Prometheus text format (prom-client):
  request latency histograms, error rates, queue depths. Scrape example:
  `curl -s http://localhost:4000/metrics | head`. Point a Prometheus/Grafana
  agent (or UptimeRobot on `/health`) at it.
- **Container health:** `docker compose ps` — every service must read
  `(healthy)`; `minio-init` exits 0.
- **Logs:** `docker compose logs -f api worker` (JSON-file driver, 10 MB × 3
  rotation per container, configured via the compose `x-logging` anchor).
  Structured logs on the api (`src/common/structured-logger.ts`); no PII in
  logs.
- **Web mirror sanity:** `GET /api/config` (200) is the web healthcheck.
- Coolify shows per-service CPU/RAM graphs on Path C.

---

## 10. Rollback

Images are tagged `sunnahlife/{api,web,admin}:${STACK_TAG:-latest}`. Two ways:

1. **Image tag rollback (preferred, instant):** deploy with a tag you kept:
   ```bash
   STACK_TAG=<previous-git-sha> docker compose --env-file .env \
     -f infra/docker-compose.yml up -d
   ```
   (requires the earlier `build` to have run with the same `STACK_TAG` — see
   `.env` §Housekeeping).
2. **Git rollback:** `git checkout <previous-tag/sha>` → rebuild (§8).

Database rollbacks are **forward-only** by policy: if a migration must be
reverted, write a new compensating migration. If data was lost, restore from
pgBackRest (§6.1 restore drill) into a fresh volume and restart the stack.

Verify after any rollback: `/health` green, `docker compose ps` all healthy,
demo login works (docs/DEMO_ACCOUNTS.md §5).

---

## 11. Troubleshooting quick hits

| Symptom | Check |
|---|---|
| `postgres` unhealthy | `docker compose logs postgres`; if it loops on init, the `pgdata` volume was initialised with different `POSTGRES_*` values — either set them back or `docker volume rm sunnahlife_pgdata` (destroys data!) and re-up |
| api unhealthy, log shows RLS/permission errors | role `sunnah_app` missing grants → `docker compose exec postgres psql -U postgres -d sunnahlife -f -` and replay `infra/postgres/init-rls.sql` (it is idempotent) |
| api log: `JWT_SECRET must be set` | a `:?` variable is missing from `.env` — compose prints which one |
| web shows demo accounts missing | `SEED_WEB_MIRROR` was false, or `/data/.seeded` exists without a seed — `docker compose exec web rm /data/.seeded` and restart (re-seeds) |
| admin blank / CORS errors | `PUBLIC_API_BASE` baked wrong (rebuild the admin image) or `CORS_ORIGINS` missing the admin origin |
| minio-init fails | `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` mismatch — they must satisfy MinIO's ≥8-char rule |
| builds fail on the api | context must contain `apps/api` with its `bun.lock`; `docker compose build api` shows the failing layer |
| everything healthy but 502 | Cloudflare origin rules or the `proxy` profile isn't running (`docker compose --profile proxy up -d`) |
