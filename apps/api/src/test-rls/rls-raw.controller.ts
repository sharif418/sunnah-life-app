import { Req, Controller, Get, Query } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { ApiError } from "../common/api-error";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";

/**
 * TEST-ONLY RLS probe. Enabled only when the request carries the
 * `x-rls-raw-test: 1` header AND NODE_ENV is not production.
 *
 * It runs a query WITHOUT any application-level gender filter —
 * `prisma.amalEntry.count({ where: { userId: targetId } })` — inside the
 * acting user's RLS context. The database itself must return 0 when the
 * target belongs to the opposite gender; that refusal is what the e2e test
 * (test/rls.e2e-spec.ts) asserts.
 */
@ApiTags("test")
@Controller("test")
export class RlsRawTestController {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  @Get("rls-raw")
  @ApiOperation({ summary: "TEST-ONLY: raw unfiltered query under RLS context" })
  async raw(@Query("userId") userId: string | undefined, @Req() req: AuthedRequest) {
    if (req.headers["x-rls-raw-test"] !== "1" || process.env.NODE_ENV === "production") {
      throw new ApiError(404, "পাওয়া যায়নি");
    }
    const user = this.guard.requireUser(currentUser(req));
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");

    // Deliberately NO gender filter — the DB policy must hide opposite-gender
    // rows (and rows outside self/usrah/downline scope). findMany + count both
    // run raw under the requesting user's RLS context.
    const [rows, count] = await this.rls.run(user, (tx) =>
      Promise.all([
        tx.amalEntry.findMany({ where: { userId } }),
        tx.amalEntry.count({ where: { userId } }),
      ])
    );
    return {
      count,
      rows: rows.length,
      note: "raw unfiltered findMany/count under requesting user's RLS context",
    };
  }

  /**
   * TEST-ONLY DeviceToken twin of the probe above (Task B2): runs
   * `prisma.deviceToken.findMany({ where: { userId } })` inside the acting
   * user's RLS context with NO application-level filter. The DeviceToken
   * policy is stricter than the generic visibility pattern — same-gender
   * AND (self | same usrah | usrah I head) — so the database itself must
   * return 0 rows for an opposite-gender member's device tokens even if
   * membership data drifted (defense in depth for the push fan-out).
   */
  @Get("rls-raw-device-tokens")
  @ApiOperation({ summary: "TEST-ONLY: raw DeviceToken query under RLS context" })
  async rawDeviceTokens(
    @Query("userId") userId: string | undefined,
    @Req() req: AuthedRequest
  ) {
    if (req.headers["x-rls-raw-test"] !== "1" || process.env.NODE_ENV === "production") {
      throw new ApiError(404, "পাওয়া যায়নি");
    }
    const user = this.guard.requireUser(currentUser(req));
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");

    const rows = await this.rls.run(user, (tx) =>
      tx.deviceToken.findMany({ where: { userId }, select: { token: true } })
    );
    return {
      rows: rows.length,
      note: "raw unfiltered DeviceToken findMany under requesting user's RLS context",
    };
  }
}
