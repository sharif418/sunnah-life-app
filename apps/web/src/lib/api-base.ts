"use client";

// Single place that decides where API requests go.
//
// Production: NEXT_PUBLIC_API_BASE points at the NestJS API origin
//   (e.g. https://api.sunnahlife.app) — requests become absolute.
// Sandbox:   empty base = same-origin through the gateway; the NestJS API
//   runs on port 3001 behind the sandbox gateway, so every request gets the
//   XTransformPort query (gateway rule: relative paths only, port in query).

export const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "";

/** The API port behind the sandbox gateway (exported: the socket.io client
 *  needs it to build its URL — it does not go through fetch/apiUrl). */
export const API_PORT = process.env.NEXT_PUBLIC_API_PORT ?? "3001";

export function apiUrl(path: string): string {
  const p = path.startsWith("/") ? path : `/${path}`;
  if (API_BASE) return `${API_BASE}${p}`;
  const sep = p.includes("?") ? "&" : "?";
  return `${p}${sep}XTransformPort=${API_PORT}`;
}
