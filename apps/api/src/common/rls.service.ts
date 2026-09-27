import { Injectable } from "@nestjs/common";
import type { Prisma } from "@prisma/client";
import { PrismaService } from "./prisma.service";
import type { User } from "../shared/domain";

/**
 * Row-Level-Security execution context.
 *
 * Every request-scoped DB access MUST run through run()/system(): the helper
 * wraps the callback in a Prisma interactive transaction that begins with
 * `SELECT set_config('app.user_id' | 'app.gender' | 'app.usrah_id' |
 * 'app.role', …, true)` — transaction-local (is_local = true) so the GUCs
 * reset at commit and the pooled connection stays clean.
 *
 * PostgreSQL then enforces the gender/usrah/downline policies by itself:
 * even a query that forgets the app-level filter returns 0 rows when the
 * target user's gender differs (proven in test/rls.e2e-spec.ts).
 */
@Injectable()
export class RlsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Run `fn` with the acting user's RLS context (their fresh DB row). */
  async run<T>(user: User | null | undefined, fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    const ctx = user
      ? {
          userId: user.id,
          gender: user.gender,
          usrahId: user.usrahId ?? "",
          role: user.role,
        }
      : { userId: "", gender: "", usrahId: "", role: "" };
    return this.apply(ctx, fn);
  }

  /**
   * Run `fn` with the system bootstrap context (role = 'system').
   * STRICTLY reserved for the auth module (OTP verify / user creation /
   * refresh-token bookkeeping) and the BullMQ workers. The context is created
   * server-side only; no request can set it.
   */
  async system<T>(fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    return this.apply({ userId: "", gender: "", usrahId: "", role: "system" }, fn);
  }

  private apply<T>(
    ctx: { userId: string; gender: string; usrahId: string; role: string },
    fn: (tx: Prisma.TransactionClient) => Promise<T>
  ): Promise<T> {
    // timeout raised: the amal batch sync (up to 500 per-entry upserts) runs
    // inside one of these transactions; Prisma's default 5s is too tight.
    return this.prisma.$transaction(
      async (tx) => {
        await tx.$executeRawUnsafe(
          `SELECT set_config('app.user_id', $1, true),
                  set_config('app.gender', $2, true),
                  set_config('app.usrah_id', $3, true),
                  set_config('app.role', $4, true)`,
          ctx.userId,
          ctx.gender,
          ctx.usrahId,
          ctx.role
        );
        return fn(tx);
      },
      { timeout: 30_000, maxWait: 10_000 }
    );
  }
}
