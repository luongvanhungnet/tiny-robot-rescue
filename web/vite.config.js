import { defineConfig } from "vite";
export default defineConfig({
  plugins: [
    {
      name: "offline-cache",
      generateBundle(_, bundle) {
        const files = [
          "/",
          "/index.html",
          "/icon.svg",
          ...Object.keys(bundle).map((f) => "/" + f),
        ];
        const version = "trr-" + Date.now();
        this.emitFile({
          type: "asset",
          fileName: "sw.js",
          source: `const CACHE=${JSON.stringify(version)},FILES=${JSON.stringify(files)};
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('trr-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET'||new URL(e.request.url).origin!==self.location.origin)return;e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request)));});`,
        });
      },
    },
  ],
  build: { chunkSizeWarningLimit: 1800 },
});
