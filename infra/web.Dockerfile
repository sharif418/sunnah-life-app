# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life — web (Next.js public site + PWA), now in apps/web.
#
# Build context is the repository root ("..") because the app imports content
# packs from content/ and types from packages/shared-types. The web app has NO
# local database — it talks ONLY to the NestJS API (NEXT_PUBLIC_API_BASE),
# where PostgreSQL Row-Level Security enforces gender/usrah scoping.
#
# Build (from repo root):  docker compose --env-file .env -f infra/docker-compose.yml build web
# ─────────────────────────────────────────────────────────────────────────────

FROM oven/bun:1 AS build
WORKDIR /repo
WORKDIR /app

ARG NEXT_PUBLIC_API_BASE=""
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE}

# Web app manifest first → cached dependency layer.
COPY apps/web/package.json apps/web/bun.lock* ./apps/web/
RUN cd apps/web && (bun install --frozen-lockfile || bun install)

# Full sources (apps/web, content packs, shared types for editor tooling).
COPY . .
RUN cd apps/web && bun run build \
 # Repack the standalone output into a runtime-shaped /app.
 && cp -r apps/web/.next/standalone ./ \
 && cp -r apps/web/.next/static ./.next/static \
 && cp -r apps/web/public ./public

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
RUN chown -R bun:bun /app

USER bun
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost:3000/ || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["bun", "server.js"]
