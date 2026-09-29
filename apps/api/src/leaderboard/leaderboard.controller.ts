import { Controller, Get, Injectable, Module, Req, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { PrismaService } from "../common/prisma.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { readAppConfig } from "../config/config.controller";
import { RolesGuard } from "../common/roles.guard";
import { amalPoints, lastNDayKeys, loadActiveDefinitions, mapDefinition } from "../shared/amal";
import type { User } from "../shared/domain";

// ─────────────────────────────────────────────────────────────────────────────
// Gender-scoped percentile-band leaderboard (Phase C/W4c), behind the scholars'
// config gate (AppConfig.leaderboardEnabled — the same source GET /api/config
// serves). Privacy by design:
//   • NO lists, NO names, NO other users' data ever leaves the server — the
//     member only learns which BAND their last-30-day amal points fall into.
//   • The distribution is computed against the user's OWN gender cohort only
//     (User.gender = the requester's exact value; "unspecified" pre-onboarding
//     accounts form their own cohort by construction).
//   • The aggregate runs in the system context (a read-only rollup of points
//     totals by user id + category — never fetched into any app-level role),
//     mirroring the nightly workers' aggregate pattern.
// ─────────────────────────────────────────────────────────────────────────────

export const LEADERBOARD_WINDOW_DAYS = 30;
export type LeaderboardBand = "top10" | "top25" | "top50" | "top75" | "bottom";
export const LEADERBOARD_BANDS: LeaderboardBand[] = ["top10", "top25", "top50", "top75", "bottom"];

/**
 * Percentile of `mine` among the cohort `mine + others` (0–100): the share of
 * the cohort the member is at or above, with ties split evenly (a full tie is
 * the median). A solo cohort returns 50 — the member IS their cohort's middle.
 */
export function percentileOf(mine: number, others: number[]): number {
  if (!others.length) return 50;
  const below = others.filter((v) => v < mine).length;
  const tied = others.filter((v) => v === mine).length;
  return (100 * (below + 0.5 * tied)) / others.length;
}

/** Percentile → the five bands (≥90 top10 · ≥75 top25 · ≥50 top50 · ≥25 top75). */
export function bandOfPercentile(p: number): LeaderboardBand {
  if (p >= 90) return "top10";
  if (p >= 75) return "top25";
  if (p >= 50) return "top50";
  if (p >= 25) return "top75";
  return "bottom";
}

@Injectable()
export class LeaderboardService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService,
    private readonly prisma: PrismaService
  ) {}

  /**
   * Same-gender 30-day amal-points totals (userId → points) — the percentile
   * denominator. Points come from the server's shared amalPoints rule over
   * every ACTIVE catalog definition (1 = done, 0.5 = partial count/quantity,
   * 0 = missed), summed over the last `windowDays` diary days.
   */
  async genderTotals(gender: string, windowDays = LEADERBOARD_WINDOW_DAYS): Promise<Map<string, number>> {
    return this.rls.system(async (tx) => {
      const users = (await tx.user.findMany({
        where: { gender },
        select: { id: true, category: true },
      })) as unknown as { id: string; category: string }[];
      if (!users.length) return new Map<string, number>();

      const defs = (await loadActiveDefinitions(tx)).map(mapDefinition);
      const defMap = new Map(defs.map((d) => [d.key, d]));
      const categoryById = new Map(users.map((u) => [u.id, u.category]));

      const days = lastNDayKeys(windowDays);
      const entries = (await tx.amalEntry.findMany({
        where: { date: { gte: days[0], lte: days[days.length - 1] } },
        select: { userId: true, amalKey: true, valueJson: true },
      })) as unknown as { userId: string; amalKey: string; valueJson: unknown }[];

      const totals = new Map<string, number>();
      for (const u of users) totals.set(u.id, 0);
      for (const e of entries) {
        const def = defMap.get(e.amalKey);
        if (!def || !totals.has(e.userId)) continue;
        totals.set(
          e.userId,
          (totals.get(e.userId) ?? 0) + amalPoints(e.valueJson, def, categoryById.get(e.userId) ?? "general")
        );
      }
      return totals;
    });
  }

  /** GET /api/leaderboard/me — the member's own band (config-gated). */
  async me(viewer: User | null) {
    const user = this.guard.requireUser(viewer);

    // The scholars' gate — the SAME config source GET /api/config serves.
    const cfg = await readAppConfig(this.prisma);
    if (!cfg.leaderboardEnabled) {
      throw new ApiError(404, "লিডারবোর্ড সাময়িকভাবে বন্ধ");
    }

    const totals = await this.genderTotals(user.gender);
    const myPoints = totals.get(user.id) ?? 0;
    const others = [...totals.entries()]
      .filter(([id]) => id !== user.id)
      .map(([, v]) => v);
    const band = bandOfPercentile(percentileOf(myPoints, others));

    return { band, myPoints, windowDays: LEADERBOARD_WINDOW_DAYS };
  }
}

@ApiTags("leaderboard")
@Controller("leaderboard")
@UseGuards(RolesGuard)
export class LeaderboardController {
  constructor(private readonly service: LeaderboardService) {}

  /** GET /api/leaderboard/me — own percentile band (never a list). */
  @Get("me")
  @ApiOperation({ summary: "Own gender-scoped percentile band (config-gated)" })
  me(@Req() req: AuthedRequest) {
    return this.service.me(currentUser(req));
  }
}

@Module({
  controllers: [LeaderboardController],
  providers: [LeaderboardService],
})
export class LeaderboardModule {}
