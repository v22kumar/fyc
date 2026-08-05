/**
 * Service worker — deliberately conservative.
 *
 * A chess game cannot be played offline, so there is no value in serving stale
 * pages, and a lot of harm: the classic PWA failure is a member stuck on a
 * cached build for days with no way to force an update. This worker therefore
 * does the least that still makes the site installable and fast on repeat
 * visits:
 *
 *   - HTML is always network-first. The cache is only a fallback for when the
 *     network genuinely fails, so a deploy is picked up on the next load.
 *   - Build assets (/_astro/*) are content-hashed by Astro, so a filename can
 *     never refer to different bytes. Those are safe to serve cache-first.
 *   - API and WebSocket traffic is never touched.
 *   - skipWaiting + clients.claim so a new worker takes over immediately
 *     instead of waiting for every tab to close.
 */
const VERSION = 'fyc-v1';
const HTML_CACHE = `${VERSION}-html`;
const ASSET_CACHE = `${VERSION}-assets`;

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Drop caches from older versions so a bad build cannot outlive itself.
      const names = await caches.keys();
      await Promise.all(
        names.filter((n) => !n.startsWith(VERSION)).map((n) => caches.delete(n)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  // Same-origin only. The backend lives on another host and must never be
  // cached — a stale game state would be far worse than a slow one.
  if (url.origin !== self.location.origin) return;

  // Hashed build output: immutable by construction.
  if (url.pathname.startsWith('/_astro/')) {
    event.respondWith(
      caches.open(ASSET_CACHE).then(async (cache) => {
        const hit = await cache.match(req);
        if (hit) return hit;
        const res = await fetch(req);
        if (res.ok) cache.put(req, res.clone());
        return res;
      }),
    );
    return;
  }

  // Pages: network first, cache only as a fallback.
  if (req.mode === 'navigate' || req.headers.get('accept')?.includes('text/html')) {
    event.respondWith(
      (async () => {
        try {
          const res = await fetch(req);
          if (res.ok) {
            const cache = await caches.open(HTML_CACHE);
            cache.put(req, res.clone());
          }
          return res;
        } catch {
          const hit = await caches.match(req);
          if (hit) return hit;
          throw new Error('offline and not cached');
        }
      })(),
    );
  }
});
