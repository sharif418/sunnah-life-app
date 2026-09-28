// ─────────────────────────────────────────────────────────────────────────────
// Live-quiz HMAC token (Task B4; folded in-process in B9).
//
// The NestJS API MINTS a short-lived token (GET /api/quiz/live-token) and the
// QuizGateway in this same process VERIFIES it with the same QUIZ_SECRET —
// one backend, one auth path, one deployment. This file stays dependency-free
// (node:crypto only) so the smoke script (src/scripts/quiz-smoke.ts) can mint
// tokens with the exact same module the API uses.
//
//   payload = { u: userId, s: usrahId (room), r: "host"|"player", g: gender,
//               n: first name, m: memberCode, q: quizId, e: exp epoch-ms }
//   token   = base64url(payload) + "." + base64url(HMAC-SHA256(payload))
// ─────────────────────────────────────────────────────────────────────────────
import { createHmac } from "crypto";

export const QUIZ_TOKEN_TTL_MS = 15 * 60 * 1000; // 15 minutes

function quizSecret(): string {
  return process.env.QUIZ_SECRET || "dev-secret";
}

export interface QuizTokenPayload {
  /** user id */
  u: string;
  /** usrah id — the socket room (usrahs are single-gender) */
  s: string;
  /** room role */
  r: "host" | "player";
  /** gender ("M" | "F") — carried for the per-gender leaderboard guarantee */
  g: "M" | "F";
  /** display: FIRST name only (privacy) */
  n: string;
  /** member code (DS-XXXXXX) or null */
  m: string | null;
  /** quiz id the token was minted for */
  q: string;
  /** expiry (epoch ms) */
  e: number;
}

export function mintQuizToken(p: QuizTokenPayload): string {
  const body = Buffer.from(JSON.stringify(p), "utf8").toString("base64url");
  const sig = createHmac("sha256", quizSecret()).update(body).digest("base64url");
  return `${body}.${sig}`;
}

/** Returns the payload when the signature matches and the token is unexpired. */
export function verifyQuizToken(token: string): QuizTokenPayload | null {
  const dot = token.indexOf(".");
  if (dot <= 0 || dot === token.length - 1) return null;
  const body = token.slice(0, dot);
  const sig = token.slice(dot + 1);

  const expect = createHmac("sha256", quizSecret()).update(body).digest("base64url");
  const a = Buffer.from(sig, "utf8");
  const b = Buffer.from(expect, "utf8");
  if (a.length !== b.length) return null;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i]; // timing-safe compare
  if (diff !== 0) return null;

  try {
    const p = JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as QuizTokenPayload;
    if (
      typeof p.u !== "string" || !p.u ||
      typeof p.s !== "string" || !p.s ||
      (p.r !== "host" && p.r !== "player") ||
      (p.g !== "M" && p.g !== "F") ||
      typeof p.n !== "string" || !p.n ||
      typeof p.q !== "string" ||
      typeof p.e !== "number" || !Number.isFinite(p.e) ||
      p.e < Date.now()
    ) {
      return null;
    }
    return p;
  } catch {
    return null;
  }
}
