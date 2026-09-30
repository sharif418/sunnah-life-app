/* সুন্নাহ লাইফ — web service worker (W4g).
 *
 * Strategy (per docs/PLAN.md C-W4g + the W4j search close-out):
 *  - PRECACHE the app shell ("/" HTML, offline fallback, manifest, icons).
 *    Prayer times are computed CLIENT-SIDE (src/lib/prayer-times.ts) and
 *    cities are bundled into the JS chunks — the shell is all the offline
 *    experience needs for the core surfaces.
 *  - RUNTIME cache-first for immutable /_next/static/* (build chunks +
 *    self-hosted next/font files).
 *  - STALE-WHILE-REVALIDATE for GET /api/config (donation URL, hijri
 *    adjust, nisab, contacts) — any origin, so the cross-origin API base
 *    used in production is covered too.
 *  - STALE-WHILE-REVALIDATE for GET /api/content/:pack (duas, adhkar,
 *    names99, articles, …) — versioned content; W4j: the offline search
 *    fallback (and the offline ilm tabs) read these through getPack(), so
 *    after the first visit the packs survive a network loss. Any origin
 *    (same cross-origin-API reason as /api/config).
 *  - NAVIGATIONS: network-first with the cached shell as fallback, then
 *    /offline.html as the last resort.
 *
 * Bump VERSION to invalidate every cache on deploy.
 */
const VERSION = "w4j-1";
const SHELL_CACHE = `sl-shell-${VERSION}`;
const STATIC_CACHE = `sl-static-${VERSION}`;
const RUNTIME_CACHE = `sl-runtime-${VERSION}`;
const CONFIG_CACHE = `sl-config-${VERSION}`;
const CACHES = [SHELL_CACHE, STATIC_CACHE, RUNTIME_CACHE, CONFIG_CACHE];

const SHELL_ASSETS = [
  "/",
  "/offline.html",
  "/manifest.webmanifest",
  "/icon.svg",
  "/icon-192.png",
  "/icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      .then((cache) => cache.addAll(SHELL_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => !CACHES.includes(k)).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);

  // GET /api/config — stale-while-revalidate, any origin (the API base is
  // cross-origin in production; those requests still pass through this SW).
  if (url.pathname === "/api/config" || url.pathname.endsWith("/api/config")) {
    event.respondWith(staleWhileRevalidate(req, CONFIG_CACHE));
    return;
  }

  // GET /api/content/:pack — stale-while-revalidate, any origin. W4j: the
  // offline search fallback reads these packs through getPack(); serving
  // them from the cache (and refreshing in the background) makes the ilm
  // content + the search fallback work offline after the first visit.
  if (url.pathname.startsWith("/api/content/")) {
    event.respondWith(staleWhileRevalidate(req, CONFIG_CACHE));
    return;
  }

  if (url.origin !== self.location.origin) return; // other cross-origin: pass through

  // Navigations — network-first, cached shell, then the offline page.
  if (req.mode === "navigate") {
    event.respondWith(networkFirstNavigation(req));
    return;
  }

  // Immutable build output (chunks + self-hosted fonts) — cache-first.
  if (url.pathname.startsWith("/_next/static/")) {
    event.respondWith(cacheFirst(req, STATIC_CACHE));
    return;
  }

  // Everything else same-origin (icons, manifest, misc) — SWR.
  event.respondWith(staleWhileRevalidate(req, RUNTIME_CACHE));
});

async function networkFirstNavigation(req) {
  try {
    const fresh = await fetch(req);
    const cache = await caches.open(SHELL_CACHE);
    cache.put(req, fresh.clone());
    return fresh;
  } catch {
    const cached = (await caches.match(req)) || (await caches.match("/")) || (await caches.match("/offline.html"));
    return cached || offlineResponse();
  }
}

async function cacheFirst(req, cacheName) {
  const cached = await caches.match(req);
  if (cached) return cached;
  try {
    const fresh = await fetch(req);
    if (fresh && fresh.ok) {
      const cache = await caches.open(cacheName);
      cache.put(req, fresh.clone());
    }
    return fresh;
  } catch {
    return offlineResponse();
  }
}

async function staleWhileRevalidate(req, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  const refresh = fetch(req)
    .then((fresh) => {
      if (fresh && fresh.ok) cache.put(req, fresh.clone());
      return fresh;
    })
    .catch(() => null);
  if (cached) return cached;
  const fresh = await refresh;
  return fresh || offlineResponse();
}

function offlineResponse() {
  return new Response("অফলাইন — ইন্টারনেট সংযোগ নেই", {
    status: 503,
    statusText: "Offline",
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
