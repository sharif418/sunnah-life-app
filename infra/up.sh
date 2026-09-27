#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Sunnah Life — one-command stack bring-up (wrapper around docker compose).
#
#   ./infra/up.sh            # build + start everything (detached)
#   ./infra/up.sh logs -f    # any extra args pass through to docker compose
#   ./infra/up.sh down       # stop the stack
#
# Requires: .env at the repo root (cp .env.example .env, then edit secrets).
# ─────────────────────────────────────────────────────────────────────────────
set -e
cd "$(dirname "$0")/.." # repo root

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run:  cp .env.example .env   and fill in the secrets."
  exit 1
fi

exec docker compose --env-file .env -f infra/docker-compose.yml up -d --build "$@"
