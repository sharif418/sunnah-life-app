# PostgreSQL 16 with the Sunnah Life init scripts baked in.
# Used by infra/coolify.compose.yml: Coolify does not ship repo files to
# runtime bind mounts, so the RLS role bootstrap must live inside the image.
FROM postgres:16
COPY init-rls.sql /docker-entrypoint-initdb.d/10-rls.sql
COPY init-walarchive.sh /docker-entrypoint-initdb.d/20-walarchive.sh
RUN chmod 0644 /docker-entrypoint-initdb.d/10-rls.sql \
 && chmod 0755 /docker-entrypoint-initdb.d/20-walarchive.sh
