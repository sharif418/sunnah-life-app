"use client";

// Single place that decides where API requests go — ONE variable:
//
//   NEXT_PUBLIC_API_BASE  e.g. https://api.sunnahlife.app
//
// - Empty (default in fresh dev checkouts): same-origin requests ("/api/…").
//   Use this only when a reverse proxy in front of the web app forwards /api
//   to the NestJS API.
// - Set (all real deployments): absolute requests to the API origin.
//
// Baked at BUILD time (Next.js inlines NEXT_PUBLIC_* into the bundle):
// pass it as a Docker build arg (infra/web.Dockerfile, infra/admin.Dockerfile)
// or `NEXT_PUBLIC_API_BASE=http://localhost:4000 bun run dev` in local dev.

export const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "";

export function apiUrl(path: string): string {
  const p = path.startsWith("/") ? path : `/${path}`;
  return API_BASE ? `${API_BASE}${p}` : p;
}
