#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life web container entrypoint (infra/web.Dockerfile).
#
# 1. First boot (marker /data/.seeded missing): create the SQLite mirror
#    schema (prisma db push) and run the demo seed (prisma/seed.ts — the same
#    accounts as the sandbox preview, docs/DEMO_ACCOUNTS.md).
# 2. Every boot: serve the Next.js standalone server.
#
# The seed is deliberately marker-gated: prisma/seed.ts wipes + reseeds, so it
# must only run once per volume — user data in the mirror survives restarts.
# Set SEED_WEB_MIRROR=false to start a clean, unseeded web mirror (the public
# content still works; demo accounts then live only on the api service).
# ─────────────────────────────────────────────────────────────────────────────
set -e
log() { printf '[web] %s\n' "$1"; }

mkdir -p /data

case "${SEED_WEB_MIRROR:-true}" in
  true|1|yes)
    if [ ! -f /data/.seeded ]; then
      log "first boot: creating SQLite mirror schema (prisma db push)"
      bun run db:push
      log "first boot: seeding demo data (docs/DEMO_ACCOUNTS.md)"
      bun run db:seed
      touch /data/.seeded
      log "seed complete — marker written to /data/.seeded"
    else
      log "SQLite mirror already initialised — skipping seed"
    fi
    ;;
  *)
    log "SEED_WEB_MIRROR=${SEED_WEB_MIRROR} — starting without local database bootstrap"
    ;;
esac

log "starting Next.js standalone on :${PORT:-3000}"

if [ -f .next/standalone/server.js ]; then
  # Belt & braces: assemble the standalone layout if the build script's copy
  # steps did not run (Next writes static/ + public/ beside server.js).
  [ -d .next/standalone/.next/static ] || cp -r .next/static .next/standalone/.next/static 2>/dev/null || true
  [ -d .next/standalone/public ] || cp -r public .next/standalone/ 2>/dev/null || true
  exec bun .next/standalone/server.js
fi

log "FATAL: .next/standalone/server.js missing — build with output:'standalone'"
exit 1
