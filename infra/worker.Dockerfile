# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life — BullMQ worker.
#
# DEFAULT WIRING (mandated): the `worker` service in infra/docker-compose.yml
# reuses the api image (image: sunnahlife/api) with a different command, so
# the whole stack is built from infra/api.Dockerfile.
#
# THIS FILE is the drop-in alternative for the case where the worker grows
# into a standalone package with its own package.json at apps/worker:
#   1. in infra/docker-compose.yml replace the worker service's `image:` with
#      build: { context: .., dockerfile: infra/worker.Dockerfile }
#   2. keep depends_on: api: healthy (migrations are done by the api first).
#   3. NOTE: if the standalone worker also reads packages/content (level rules,
#      report data), switch its COPY paths to repo-root-relative like
#      infra/api.Dockerfile does (context "..", COPY apps/worker/… and
#      packages/content, ENV CONTENT_DIR=/app/packages/content).
#
# Build context: apps/worker
# ─────────────────────────────────────────────────────────────────────────────

FROM oven/bun:1 AS build
WORKDIR /app

COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

COPY . .
# Same schema as the api (Prisma client + RLS-aware queries).
RUN if [ -d prisma ] && [ -f prisma/schema.prisma ]; then bunx prisma generate; fi
RUN if grep -q '"build":' package.json; then bun run build; fi

FROM oven/bun:1 AS runtime
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl dumb-init ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV NODE_ENV=production TZ=UTC

COPY --from=build /app ./

COPY <<'EOF' /usr/local/bin/worker-entrypoint.sh
#!/bin/sh
# Sunnah Life worker entrypoint — BullMQ workers only (no HTTP server).
set -e
log() { printf '[worker] %s\n' "$1"; }
has() { grep -q "\"$1\":" package.json; }

log "starting BullMQ worker"
if [ -f dist/worker.js ]; then
  exec bun dist/worker.js
elif [ -f dist/src/worker.js ]; then
  exec bun dist/src/worker.js
elif has start:worker; then
  exec bun run start:worker
elif has start:prod; then
  exec bun run start:prod
else
  log "FATAL: no worker entrypoint (dist/worker.js / start:worker)"; exit 1
fi
EOF
RUN chmod +x /usr/local/bin/worker-entrypoint.sh && chown -R bun:bun /app

USER bun

# The worker serves no HTTP port, so an HTTP probe would mark it permanently
# unhealthy. Liveness = PID 1 (dumb-init) still alive — a crashed worker exits
# the container, and the restart policy reaps it.
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD kill -0 1 || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/local/bin/worker-entrypoint.sh"]
