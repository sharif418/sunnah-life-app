#!/usr/bin/env node
/* Bun-workspaces quirk (LOCAL full-monorepo runs only):
 *
 * @nestjs/websockets takes @nestjs/core as an UNDECLARED peer. From its
 * .bun install dir, node resolves its OWN symlinked copy — which in this
 * monorepo is a DIFFERENT install instance (@nestjs+core@…aab5…) than the
 * one apps/api resolves (@nestjs+core@…93416…; identical deps, different
 * bun peer-hash). Two class objects → `app instanceof NestApplication`
 * inside AbstractWsAdapter fails → the whole NestApplication gets passed to
 * socket.io as the HTTP server → "TypeError: server.listeners is not a
 * function" on boot.
 *
 * CI and the Docker container install apps/api STANDALONE (one copy) and
 * never hit this. This dev-only runner aliases the websockets-resolved
 * copy's module-cache entry to the api's copy so the class identity
 * matches, then boots dist/. Local dev tool — never imported by app code.
 *
 * Usage: bun run build && node scripts/dev-run.cjs
 */
const path = require("path");

const apiDir = path.join(__dirname, "..");
const apiCore = require.resolve("@nestjs/core", { paths: [apiDir] });

// The copy @nestjs/websockets would resolve at RUNTIME (the mismatch).
const wsMain = require.resolve("@nestjs/websockets", { paths: [apiDir] });
const wsCore = require.resolve("@nestjs/core", { paths: [path.dirname(wsMain)] });

if (apiCore !== wsCore) {
  require(apiCore); // populate the cache entry first
  require.cache[wsCore] = require.cache[apiCore];
  const tag = (p) => p.match(/@nestjs\+core@([^/]+)\+/)?.[1] ?? p;
  console.log(`[dev-run] @nestjs/core class identity: ${tag(wsCore)} → ${tag(apiCore)} (aliased)`);
}

require(path.join(apiDir, "dist", "main.js"));
