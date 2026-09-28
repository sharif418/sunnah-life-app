# ENVIRONMENT.md — Sandbox Environment & Toolchain Log

Everything installed for the Sunnah Life build, with exact methods and
workarounds. **No root available** (`sudo` requires a password) — every install
below is user-level. Documented so the client's desktop agent can reproduce or
parallelize on the Coolify VPS.

## Base machine (verified)

| | |
|---|---|
| OS | Debian GNU/Linux 13 (trixie), kernel 5.10 |
| User | `z` (no sudo) |
| CPU / RAM | 2 cores / 4.1 GB (≈1.4 GB used by the Next.js dev server) |
| Disk | 9.9 GB rootfs (shared with everything) |
| Preinstalled | Node 24.21, Bun 1.3.14, OpenJDK 21, git 2.47 |

## Installed toolchain (user-level)

### Flutter 3.47.5 stable (Dart 3.13.4) — `/home/z/flutter`
- Source tarball `flutter_linux_3.47.5-stable.tar.xz` (1.47 GB) from
  storage.googleapis.com.
- **Workaround:** the sandbox proxy stalls large single-stream GETs on
  storage.googleapis.com, so the tarball was fetched with a 16-way parallel
  ranged downloader (`/home/z/opt/parallel-dl.sh`, HTTP Range chunks +
  reassembly). 1.47 GB in 58 s.
- Extraction prints benign `Directory renamed before its status could be
  extracted` warnings for a few `engine/src/flutter/lib/web_ui` metadata
  entries (tarball quirk on overlayfs). Content verified: `flutter --version`,
  `flutter doctor`, and the toolchain below all work.
- `flutter config --no-analytics --no-cli-animations`; `flutter precache
  --android` (1 GB artifacts); `git config --global --add safe.directory
  /home/z/flutter`.
- `flutter doctor -v`: ✅ Flutter, ✅ Android toolchain (SDK 36.0.0, licenses
  accepted, Java 21). ✗ Chrome / ✗ Linux-desktop toolchain (clang/cmake/gtk)
  are not needed for the Android target and are not installed.

### Android SDK — `/home/z/android-sdk` (472 MB)
- cmdline-tools 13114758 from dl.google.com (fast host, 25 MB/s).
- `yes | sdkmanager --licenses` (all accepted) + `platform-tools`,
  `platforms;android-36`, `build-tools;36.0.0`.
- Gradle will resolve from google()/mavenCentral on first `flutter build`.

### PostgreSQL 16.10 — port **5433**, running ✅
- Portable static build from `github.com/theseus-rs/postgresql-binaries`
  (11 MB tarball; EDB's get.enterprisedb.com serves 403 without auth).
- Binaries: `/home/z/opt/pg16/postgresql-16.10.0-x86_64-unknown-linux-gnu/bin`
- Data: `/home/z/opt/pgdata`, socket dir `/home/z/opt/pgrun`, log
  `/home/z/opt/logs/pg.log`, superuser `postgres` (trust auth, local only).
- Daemon survives across shell sessions (verified). Restart via
  `/home/z/opt/start-services.sh`.

### Redis 7.0.15 — port **6380**, running ✅
- `redis-server` + `redis-tools` debs (bookworm-security 7.0.15-1~deb12u10)
  extracted with `dpkg-deb -x` into `/home/z/opt/redis` (no root needed).
- Needed `liblzf1` (3.6-4+b4, same extraction) + `LD_LIBRARY_PATH` pointing at
  the extracted libs (the packaged redis-check-rdb links liblzf.so.1).
- No persistence (cache/queue only), daemonized, survives sessions.

### Meilisearch 1.54.0 — port **7700**, running ✅
- Static binary from GitHub releases (fast host) → `/home/z/opt/bin/meilisearch`.
- `--no-analytics`, data at `/home/z/opt/meili-data`, log
  `/home/z/opt/logs/meili.log`. Health verified `{"status":"available"}`.

### pnpm / Turborepo
- pnpm available via `bun add -g pnpm` (installs to `~/.bun/bin`).
- `pnpm-workspace.yaml` + `turbo.json` committed at repo root; workspace =
  `.` (web, repo root is the web app — platform preview constraint, PLAN §3),
  `apps/*`, `packages/*`.

## Could NOT run in this sandbox (code-complete instead)

| Item | Exact reason | Where the code lives |
|---|---|---|
| Docker / `docker compose up` | container-in-container needs root; no docker socket | `infra/docker-compose.yml`, `infra/*/Dockerfile` — ready for the client's VPS |
| MinIO server | `dl.min.io` serves HTTP 410 from this network (all paths probed) | storage module behind S3 env config in `apps/api`; minio service in compose |
| iOS build | no macOS/Xcode possible | `apps/mobile/ios` config + signing placeholders documented |
| GitHub Actions | no GitHub remote/credentials | `.github/workflows/ci.yml` ready |
| Production SMS (SSL Wireless/Infobip) | no credentials | adapter interface in `apps/api` (mock returns devCode) |
| LiveKit | phase-3 item by design | extension point documented |

## Sandbox gotchas (important for agents)

1. **Background processes are reaped between tool calls** unless they
   daemonize properly (double-fork). PostgreSQL/Redis/Meili survive; ad-hoc
   `nohup … &` does not. Start/verify services within a single shell call.
2. **storage.googleapis.com stalls on large single-stream GETs** — use the
   ranged parallel downloader (`/home/z/opt/parallel-dl.sh URL OUT [N]`) or
   resume with `curl -C -`. dl.google.com and github.com are fast.
3. **RAM is 4 GB with ~1.5–2 GB free** — Gradle must run with
   `org.gradle.jvmargs=-Xmx1536m` and `--no-daemon` where possible.
4. **Disk is tight (~2 GB free after toolchain)** — clean build caches when
   possible; debug APK target < 40 MB per spec.
5. One HTTP surface only: the Next.js dev server on port 3000 behind Caddy
   (`?XTransformPort=` for internal ports).

## Environment variables (sandbox)

```bash
export PATH="/home/z/flutter/bin:/home/z/android-sdk/cmdline-tools/latest/bin:/home/z/android-sdk/platform-tools:/home/z/opt/pg16/postgresql-16.10.0-x86_64-unknown-linux-gnu/bin:/home/z/opt/redis/usr/bin:/home/z/.bun/bin:$PATH"
export ANDROID_HOME=/home/z/android-sdk ANDROID_SDK_ROOT=/home/z/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export LD_LIBRARY_PATH=/home/z/opt/redis/usr/lib/x86_64-linux-gnu
export PUB_CACHE=/home/z/.pub-cache
# services
DATABASE_URL="postgresql://postgres@127.0.0.1:5433/sunnahlife"
REDIS_URL="redis://127.0.0.1:6380"
MEILI_HOST="http://127.0.0.1:7700"
```
