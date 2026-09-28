# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life — admin panel (apps/admin, Next.js + shadcn/ui + TanStack).
#
# Build (from repo root):  docker compose --env-file .env -f infra/docker-compose.yml build admin
# Build context:            apps/admin
# Port:                     3000 inside the container — compose maps host 3002.
#
# NEXT_PUBLIC_API_BASE is baked into the client bundle at BUILD time (Next.js
# inlines NEXT_PUBLIC_* at build), so it is an ARG here, wired from the
# environment by the compose service. Rebuild to change it.
# ─────────────────────────────────────────────────────────────────────────────

FROM oven/bun:1 AS build
WORKDIR /app

ARG NEXT_PUBLIC_API_BASE=""
ARG NEXT_PUBLIC_APP_URL=""
# "true" only on demo/staging builds: shows the demo quick-login grid.
ARG NEXT_PUBLIC_DEMO=""
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE} \
    NEXT_PUBLIC_APP_URL=${NEXT_PUBLIC_APP_URL} \
    NEXT_PUBLIC_DEMO=${NEXT_PUBLIC_DEMO}

COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

COPY . .
RUN bun run build

# ─────────────────────────────────────────────────────────────────────────────
# Runtime
# ─────────────────────────────────────────────────────────────────────────────
FROM oven/bun:1 AS runtime

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl dumb-init ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV NODE_ENV=production \
    TZ=Asia/Dhaka \
    PORT=3000 \
    HOSTNAME=0.0.0.0

COPY --from=build /app ./

COPY <<'EOF' /usr/local/bin/admin-entrypoint.sh
#!/bin/sh
# Sunnah Life admin entrypoint — serve Next.js (standalone if available).
set -e
log() { printf '[admin] %s\n' "$1"; }

if [ -d .next/standalone ] && [ -f .next/standalone/server.js ]; then
  # Assemble the standalone layout if the build did not copy static assets.
  [ -d .next/standalone/.next/static ] || cp -r .next/static .next/standalone/.next/static 2>/dev/null || true
  [ -d .next/standalone/public ] || cp -r public .next/standalone/ 2>/dev/null || true
  log "starting Next.js standalone on :${PORT:-3000}"
  cd .next/standalone && exec bun server.js
fi

if grep -q '"start":' package.json; then
  log "starting via package.json start script on :${PORT:-3000}"
  exec bun run start
fi

log "FATAL: no .next/standalone/server.js and no start script"
exit 1
EOF
RUN chmod +x /usr/local/bin/admin-entrypoint.sh && chown -R bun:bun /app

USER bun
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT:-3000}/" || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/local/bin/admin-entrypoint.sh"]
