"use client";

// PWA — service-worker registration. Mounted once from the root layout.
// Production only: `next dev` churns build output and a SW caching it is a
// foot-gun; the standalone production build (what CI ships) registers here.

import * as React from "react";

export function ServiceWorkerRegister() {
  React.useEffect(() => {
    if (process.env.NODE_ENV !== "production") return;
    if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return;
    // scope defaults to "/" — sw.js lives at the origin root.
    navigator.serviceWorker.register("/sw.js", { scope: "/" }).catch(() => {
      /* registration failure must never break the app */
    });
  }, []);
  return null;
}
