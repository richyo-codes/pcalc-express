const cacheName = 'pcalc-express-v1';
const appShell = ['./', 'index.html', 'manifest.json', 'flutter_bootstrap.js'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(cacheName).then((cache) => cache.addAll(appShell)),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((key) => key.startsWith('pcalc-express-') && key !== cacheName)
        .map((key) => caches.delete(key)),
    )),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const requestUrl = new URL(event.request.url);
  if (requestUrl.origin !== self.location.origin) return;

  event.respondWith(
    fetch(event.request)
      .then(async (response) => {
        if (response.ok) {
          try {
            const cache = await caches.open(cacheName);
            await cache.put(event.request, response.clone());
          } catch (_) {
            // A full or unavailable cache must not prevent online use.
          }
        }
        return response;
      })
      .catch(async () => {
        const cached = await caches.match(event.request);
        if (cached) return cached;
        if (event.request.mode === 'navigate') return caches.match('index.html');
        throw new Error('Resource unavailable offline');
      }),
  );
});
