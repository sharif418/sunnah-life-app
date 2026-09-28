# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life — web (Next.js public site + PWA), now in apps/web.
#
# Build context is the repository root ("..") because the app imports types
# from packages/shared-types (the content packs it renders come from the
# NestJS API, which serves packages/content). outputFileTracingRoot is the
# repo root (apps/web/next.config.ts), so the standalone output mirrors
# repo-relative paths — server.js lands at .next/standalone/apps/web/server.js.
# The web app has NO local database — it talks ONLY to the NestJS API
# (NEXT_PUBLIC_API_BASE), where PostgreSQL Row-Level Security enforces
# gender/usrah scoping.
#
# Build (from repo root):  docker compose --env-file .env -f infra/docker-compose.yml build web
# ─────────────────────────────────────────────────────────────────────────────

FROM oven/bun:1 AS build
WORKDIR /repo

ARG NEXT_PUBLIC_API_BASE=""
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE}

# Web manifest first → cached dependency layer.
COPY apps/web/package.json apps/web/bun.lock* ./apps/web/
RUN cd apps/web && (bun install --frozen-lockfile || bun install)

# Full sources (apps/web, content packs, shared types).
COPY . .
RUN cd apps/web && bun run build

# Standalone layout (outputFileTracingRoot = repo root):
#   .next/standalone/apps/web/server.js
#   .next/standalone/node_modules (traced runtime deps only — the
#   packages/shared-types imports are type-only and erased at build)
# Static assets + public live NEXT TO the server's .next dir:
#   .next/standalone/apps/web/.next/static
#   .next/standalone/apps/web/public
# (apps/web/package.json's build script also repacks for the OLD flat layout —
# .next/standalone/.next + .next/standalone/public — its stray output is
# removed here so the runtime layer below gets exactly the documented layout.)
RUN cd apps/web \
 && cp -r .next/static .next/standalone/apps/web/.next/static \
 && cp -r public .next/standalone/apps/web/public \
 && rm -rf .next/standalone/.next .next/standalone/public

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

COPY --from=build /repo/apps/web/.next/standalone ./
RUN chown -R bun:bun /app

USER bun
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost:3000/ || exit 1

ENTRYPOINT ["dumb-init", "--"]
WORKDIR /app/apps/web
CMD ["bun", "server.js"]
