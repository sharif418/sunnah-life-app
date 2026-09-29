# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life — NestJS API (apps/api). The BullMQ worker (apps/worker concept)
# shares this image and overrides the command (see the `worker` service in
# infra/docker-compose.yml).
#
# Build (from repo root):   docker compose --env-file .env -f infra/docker-compose.yml build api
# Build context:             the REPOSITORY ROOT ("..") — NOT apps/api alone!
#                            The image needs apps/api AND the content packs
#                            (packages/content — the single content source)
#                            the entrypoint seed reads amal-catalog.json +
#                            assessment-farze-ain-v1.json, and the content
#                            routes serve the Qur'an + packs from CONTENT_DIR
#                            (set below to /app/packages/content).
# BuildKit note:             the sibling file infra/api.Dockerfile.dockerignore
#                            (same directory as this Dockerfile) is picked up
#                            automatically by BuildKit and keeps node_modules /
#                            dist / apps/mobile / .env / .git out of the context.
#
# Runtime: oven/bun:1 (Debian). `node` is NOT in this image — the entrypoint
# runs the compiled NestJS output with `bun dist/main.js` (bun is a drop-in
# runner for compiled CommonJS, and it is also what runs the TypeScript seed).
# ─────────────────────────────────────────────────────────────────────────────

FROM oven/bun:1 AS build
WORKDIR /app

# Manifests + prisma schema first (bun's @prisma/client postinstall generates
# the client, which needs the schema) → cached dependency layer.
COPY apps/api/package.json apps/api/bun.lock* ./
COPY apps/api/prisma ./prisma
RUN bun install --frozen-lockfile || bun install

# Sources, config and content packs.
COPY apps/api/ .

# Prisma client (no-op if bun's postinstall already generated it) + build.
# NOTE: the client is plain JS under src/generated/prisma — tsc/nest build
# compiles only .ts and does NOT emit it into dist/, yet the compiled
# dist/common/prisma-client.js requires "../generated/prisma". The build
# script therefore copies src/generated → dist/generated after nest build
# (the CI compose smoke crashed on "Cannot find module '../generated/prisma'"
# before this copy existed).
RUN bunx prisma generate
RUN bun run build

# ─────────────────────────────────────────────────────────────────────────────
# Runtime
# ─────────────────────────────────────────────────────────────────────────────
FROM oven/bun:1 AS runtime

# curl → container healthchecks; dumb-init → PID 1 signal reaping; ca-certificates
# → outbound TLS (S3/Meili/SMS gateways); tzdata → explicit UTC.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl dumb-init ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV NODE_ENV=production \
    TZ=UTC \
    PORT=4000 \
    CONTENT_DIR=/app/packages/content

# Built app + prod node_modules + prisma (migrations, seed).
COPY --from=build /app ./

# Content packs — packages/content is the ONLY content source since B1
# (commit 16370d8 removed the old root content/ dir + packages/content
# symlink); copy the real directory to /app/packages/content = CONTENT_DIR.
# The seed reads amal-catalog.json + assessment-farze-ain-v1.json from here
# and the content routes serve the Qur'an + packs from CONTENT_DIR.
COPY packages/content ./packages/content

# Entrypoint: migrate (owner via DIRECT_URL) → seed (idempotent) → serve.
# Written inline (COPY heredoc) so the image is self-contained even when the
# build context does not include infra/.
COPY <<'EOF' /usr/local/bin/api-entrypoint.sh
#!/bin/sh
# Sunnah Life API entrypoint — migrations, then idempotent seed, then serve.
set -e
log() { printf '[api] %s\n' "$1"; }
has() { grep -q "\"$1\":" package.json; }

log "applying Prisma migrations (owner role via DIRECT_URL)"
migrate() {
  if has migrate:deploy; then bun run migrate:deploy
  elif has db:migrate:prod; then bun run db:migrate:prod
  elif [ -d prisma/migrations ]; then bunx prisma migrate deploy
  fi
}
# stack bring-up can race the DB healthcheck under load (P1001 is transient):
# retry a few times before giving up — defense in depth behind -h 127.0.0.1
n=0
until migrate; do
  n=$((n+1))
  if [ "$n" -ge 5 ]; then log "FATAL: migrations failed after $n attempts"; exit 1; fi
  log "migrations failed (attempt $n) — retrying in 5s"
  sleep 5
done

# Phase C/W2a: boot seeds REFERENCE data only (amal catalog by key, the
# farze_ain_v1.1 template, app config) — IDEMPOTENT upserts, never deletes.
# Demo data (users/usrahs) requires SEED_DEMO=true AND NODE_ENV != production
# and is never part of a production boot; a non-zero exit is logged but does
# not block startup (two replicas may race the seed).
if has seed:reference; then
  log "seeding reference data (idempotent, non-destructive)"
  bun run seed:reference || log "WARN: seed:reference exited non-zero — continuing"
elif has seed; then
  log "seeding (idempotent)"
  bun run seed || log "WARN: seed exited non-zero — continuing"
fi

log "starting NestJS on :${PORT:-4000}"
# `node` is not in this image; run the compiled output with bun.
if [ -f dist/main.js ]; then
  exec bun dist/main.js
elif [ -f dist/src/main.js ]; then
  exec bun dist/src/main.js
elif has start:prod; then
  exec bun run start:prod
else
  log "FATAL: no dist/main.js and no start:prod script"; exit 1
fi
EOF
RUN chmod +x /usr/local/bin/api-entrypoint.sh \
 && mkdir -p storage/reports \
 && chown -R bun:bun /app

USER bun
EXPOSE 4000

# [C-W5-ops] Liveness ONLY — the process can serve HTTP; no dependency calls.
# The readiness checks (/health, /health/ready) are for monitoring: a slow
# Postgres/Redis/Meili must NEVER flip the container unhealthy (that made
# Coolify's Traefik drop the serving api on the live staging deployment).
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT:-4000}/health/live" || curl -fsS "http://localhost:3001/health/live" || curl -fsS "http://localhost:3000/health/live" || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/local/bin/api-entrypoint.sh"]
