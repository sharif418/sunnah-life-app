#!/bin/bash
# Prepare the WAL archive directory (Phase C/W2h).
# Runs ONCE on first boot (docker-entrypoint-initdb.d) as the postgres user,
# before the server starts: archive_command refuses to cp into a missing dir,
# and postgres can't mkdir into a fresh empty volume mount at archive time.
set -e
mkdir -p /var/lib/postgresql/walarchive
