// ─────────────────────────────────────────────────────────────────────────────
// Request body limits beyond Express's 100kb default — only where needed.
//
// The content CMS sends whole packs (a draft of 500 names or many articles
// outgrows 100kb), so /api/admin/cms gets a 2mb JSON parser of its own. It
// runs before Nest's global parser, which then skips the already-parsed body.
//
// Two traps, both covered by test/body-limits.spec.ts:
//  • Nest registers its global parsers only if no middleware NAMED
//    "jsonParser" is mounted yet (ExpressAdapter.isMiddlewareApplied) — a bare
//    express.json() here would switch JSON parsing off for every other route.
//    Hence the named wrapper.
//  • express is not a direct dependency (bun keeps it inside
//    @nestjs/platform-express): json() comes from the copy Nest's HTTP adapter
//    runs on.
// ─────────────────────────────────────────────────────────────────────────────
import type { INestApplication } from "@nestjs/common";
import type { NextFunction, Request, Response } from "express";
import { createRequire } from "module";

const express = createRequire(require.resolve("@nestjs/platform-express"))("express") as typeof import("express");

export const CMS_BODY_LIMIT = "2mb";

/** Call before app.init()/listen() (i.e. before Nest mounts its own parsers). */
export function applyBodyLimits(app: INestApplication): void {
  const cmsJson = express.json({ limit: CMS_BODY_LIMIT });
  app.use("/api/admin/cms", function cmsBodyParser(req: Request, res: Response, next: NextFunction) {
    cmsJson(req, res, next);
  });
}
