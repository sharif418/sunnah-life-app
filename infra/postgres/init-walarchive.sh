#!/bin/bash
# Prepare the WAL archive directory (Phase C/W2h).
# Runs ONCE on first boot (docker-entrypoint-initdb.d) as the postgres user —
# the dir must live INSIDE PGDATA (/var/lib/postgresql/data), because the
# entrypoint chowns PGDATA before dropping privileges; a separate named volume
# would be root-owned and unwritable for the archiver.
set -e
mkdir -p /var/lib/postgresql/data/walarchive
