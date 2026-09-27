# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life — web (Next.js public site + PWA).
#
# IMPORTANT: the Next.js web app IS THE REPO ROOT (docs/PLAN.md §3 — sandbox
# preview constraint). Build context is the repository root (".."), NOT
# apps/web. The root .dockerignore (and infra/web.Dockerfile.dockerignore,
# which BuildKit prefers) keep node_modules / .next / .git / apps/mobile out
# of the context.
#
# Build (from repo root):  docker compose --env-file .env -f infra/docker-compose.yml build web
#
# Runtime mode: "mirror" — the web app ships its own Next.js API routes backed
# by a SQLite database (volume /data), seeded once with the same demo data as
# the sandbox (docs/DEMO_ACCOUNTS.md). The NestJS API (service `api`) is the
# production backend for the Flutter app + admin panel; the web PWA keeps
# working standalone. Point the web client at the API by rebuilding with
# NEXT_PUBLIC_API_BASE once the frontend consumes it (see docs/DEPLOY_COOLIFY.md).
# ─────────────────────────────────────────────────────────────────────────────

FROM oven/bun:1 AS build
WORKDIR /app

ARG NEXT_PUBLIC_API_BASE=""
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE}

# Manifests + prisma schema first (bun's @prisma/client postinstall generates
# the client, which needs prisma/schema.prisma) → cached dependency layer.
COPY package.json bun.lock* ./
COPY prisma ./prisma
RUN bun install --frozen-lockfile || bun install

# Web app sources (src/, content/, public/, configs at repo root).
COPY . .

# next build + standalone assembly (package.json "build" also copies
# .next/static and public into .next/standalone).
RUN DATABASE_URL=file:/tmp/build.db bun run build

# Prune dev-only deps for the runtime layer (prisma + @prisma/client are
# *dependencies* → kept: needed for db:push / db:seed at first boot).
RUN bun install --production

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
    HOSTNAME=0.0.0.0 \
    DATABASE_URL=file:/data/sunnahlife.db \
    SEED_WEB_MIRROR=true

# node_modules (prod), .next (incl. standalone), public, prisma, src, content.
COPY --from=build /app ./

# Entrypoint: first boot → SQLite mirror schema + demo seed, then serve.
COPY infra/web/entrypoint.sh /usr/local/bin/web-entrypoint.sh
RUN chmod +x /usr/local/bin/web-entrypoint.sh \
 && mkdir -p /data \
 && chown -R bun:bun /app /data

USER bun
EXPOSE 3000
VOLUME /data

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:3000/api/config || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/local/bin/web-entrypoint.sh"]
