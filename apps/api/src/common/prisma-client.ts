// ─────────────────────────────────────────────────────────────────────────────
// Prisma client re-export (bun workspaces).
//
// The client is generated into src/generated/prisma (see prisma/schema.prisma
// generator.output) because @prisma/client resolves through node_modules/.bun
// in this workspace layout — the default node_modules/.prisma location would
// be unreachable from there. EVERY file in the API imports Prisma types and
// the PrismaClient from HERE, never from "@prisma/client" directly.
// ─────────────────────────────────────────────────────────────────────────────
export * from "../generated/prisma";
