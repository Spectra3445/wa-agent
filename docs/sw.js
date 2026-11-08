const C = 'agent-v1';
self.addEventListener('install', e => { self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(self.clients.claim()); });
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.open(C).then(async c => {
      const hit = await c.match(e.request);
      if (hit) return hit;
      try {
        const r = await fetch(e.request);
        if (r.ok && new URL(e.request.url).origin === location.origin) c.put(e.request, r.clone());
        return r;
      } catch (err) {
        return hit || new Response('offline', { status: 503 });
      }
    })
  );
});
