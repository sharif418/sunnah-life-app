import { Req, Controller, Get } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { computeRequirements, monthsInLevelOf, nextLevelOf } from "../shared/levels";
import { LevelsService } from "../levels/levels.service";
import type { AssessmentSummary, DownlineNode, Gender, Level, User } from "../shared/domain";

@Injectable()
export class DawahService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService,
    private readonly levels: LevelsService
  ) {}

  /** GET /api/dawah — the da'ee's own dawah dashboard (daee and above). */
  async overview(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    if (!["daee", "usrah_head", "invigilator", "full_admin"].includes(user.role)) {
      throw new ApiError(403, "এই অংশটি দায়ী ও তত্ত্বাবধায়কদের জন্য");
    }

    return this.rls.run(user, async (tx) => {
      const memberCode = user.memberCode ?? "";
      const invitedCount = await tx.user.count({ where: { referredById: user.id } });

      // downline (depth 1..3) via referral closure — ReferralClosure has no FK
      // relation to User, so we join manually. RLS on the closure keeps this to
      // rows where I am the ancestor.
      const closures = await tx.referralClosure.findMany({
        where: { ancestorId: user.id, depth: { gte: 1, lte: 3 } },
      });
      const descendantIds = [...new Set(closures.map((c) => c.descendantId))];
      const downlineUsers = descendantIds.length
        ? await tx.user.findMany({ where: { id: { in: descendantIds } } })
        : [];
      const byId = new Map(downlineUsers.map((u) => [u.id, u]));
      const downline: DownlineNode[] = [];
      for (const c of closures) {
        const u = byId.get(c.descendantId);
        if (!u) continue;
        downline.push({
          id: u.id,
          name: u.name,
          gender: u.gender as Gender,
          level: u.level as Level,
          memberCode: u.memberCode,
          depth: c.depth,
          lastActiveAt: u.lastActiveAt.toISOString(),
          joinedAt: u.createdAt.toISOString(),
        });
      }
      downline.sort((a, b) => a.depth - b.depth || a.name.localeCompare(b.name, "bn"));

      const requirements = await computeRequirements(tx, user);

      // assessment summaries with score % + the W4i acknowledgment status
      // (the dawah tab's assessment cards render the status chips)
      const assessmentRows = await tx.assessment.findMany({
        where: { assesseeId: user.id },
        orderBy: { createdAt: "desc" },
      });
      const assessments: AssessmentSummary[] = assessmentRows.map((a) => {
        const scores = (a.scoresJson ?? {}) as Record<string, { score?: number }>;
        const vals = Object.values(scores);
        const sum = vals.reduce((s, v) => s + (v?.score ?? 0), 0);
        const scorePct = vals.length ? Math.round((100 * sum) / (2 * vals.length)) : null;
        return {
          id: a.id,
          templateKey: a.templateKey,
          result: a.result as AssessmentSummary["result"],
          createdAt: a.createdAt.toISOString(),
          assessorSignedAt: a.assessorSignedAt?.toISOString() ?? null,
          assesseeSignedAt: a.assesseeSignedAt?.toISOString() ?? null,
          participantCategory: a.participantCategory,
          scorePct,
          status: (a.status === "confirmed" || a.status === "declined"
            ? a.status
            : "pending_confirmation") as AssessmentSummary["status"],
          confirmedAt: a.confirmedAt?.toISOString() ?? null,
          declinedAt: a.declinedAt?.toISOString() ?? null,
          decisionNote: a.decisionNote ?? null,
        };
      });

      return {
        memberCode,
        referralLink: memberCode
          ? `https://${process.env.APP_DOMAIN || "sunnahlife.app"}/?join=${memberCode}`
          : "",
        invitedCount,
        downline,
        level: user.level,
        levelStartedAt: user.levelStartedAt,
        monthsInLevel: monthsInLevelOf(user),
        requirements,
        nextLevel: nextLevelOf(user.level),
        assessments,
      };
    });
  }

  /**
   * GET /api/dawah/requirements (B6) — the signed-in member's LIVE checklist
   * for their next level: one row per rule with {current, target, met} progress
   * chips plus the auto-promotion hint. Same evaluation engine (LevelsService)
   * as the nightly job and the admin promote.
   */
  async requirements(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    if (!["daee", "usrah_head", "invigilator", "full_admin"].includes(user.role)) {
      throw new ApiError(403, "এই অংশটি দায়ী ও তত্ত্বাবধায়কদের জন্য");
    }
    return this.levels.requirementsFor(user);
  }
}

@ApiTags("dawah")
@Controller("dawah")
export class DawahController {
  constructor(private readonly service: DawahService) {}

  @Get()
  @ApiOperation({ summary: "Dawah dashboard: member code, downline, level requirements" })
  overview(@Req() req: AuthedRequest) {
    return this.service.overview(currentUser(req));
  }

  @Get("requirements")
  @ApiOperation({ summary: "Live next-level checklist (progress chips + auto hint)" })
  requirements(@Req() req: AuthedRequest) {
    return this.service.requirements(currentUser(req));
  }
}
