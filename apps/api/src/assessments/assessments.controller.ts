import { Req, Body, Controller, Get, Post, Query, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { AssessmentSubmitDto } from "../auth/dto/auth.dto";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import type {
  AssessmentDetail,
  AssessmentSection,
  AssessmentTemplate,
  User,
} from "../shared/domain";

type TemplateRow = {
  id: string;
  key: string;
  version: number;
  titleBn: string;
  titleEn: string;
  sectionsJson: unknown;
};

export function mapTemplate(row: TemplateRow): AssessmentTemplate {
  let sections: AssessmentSection[] = [];
  const parsed = row.sectionsJson;
  if (Array.isArray(parsed)) {
    sections = parsed
      .filter((s) => s && typeof s === "object")
      .map((s) => ({
        key: String((s as { key?: unknown }).key ?? ""),
        titleBn: String((s as { titleBn?: unknown }).titleBn ?? ""),
        criteria: Array.isArray((s as { criteria?: unknown }).criteria)
          ? ((s as { criteria: unknown[] }).criteria)
              .filter((c: unknown) => c && typeof c === "object")
              .map((cRaw) => {
                const c = cRaw as { key?: unknown; titleBn?: unknown; hintBn?: unknown };
                return {
                  key: String(c.key ?? ""),
                  titleBn: String(c.titleBn ?? ""),
                  hintBn: c.hintBn != null ? String(c.hintBn) : undefined,
                };
              })
          : [],
      }));
  }
  return { key: row.key, version: row.version, titleBn: row.titleBn, titleEn: row.titleEn, sections };
}

function parseScores(raw: unknown): Record<string, { score: 0 | 1 | 2; comment?: string }> {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, { score: 0 | 1 | 2; comment?: string }>;
  }
  return {};
}

export function scorePctOf(scores: Record<string, { score?: number }>): number | null {
  const vals = Object.values(scores);
  if (!vals.length) return null;
  const sum = vals.reduce((s, v) => s + (v?.score ?? 0), 0);
  return Math.round((100 * sum) / (2 * vals.length));
}

type AssessmentRowLike = {
  id: string;
  templateKey: string;
  assesseeId: string;
  assessorId: string;
  participantCategory: number;
  scoresJson: unknown;
  overallComment: string | null;
  assessorSignedAt: Date | null;
  assesseeSignedAt: Date | null;
  result: string;
  createdAt: Date;
};

/** Map one DB assessment row (+ names + template) to AssessmentDetail. */
export function mapAssessment(
  row: AssessmentRowLike,
  template: AssessmentTemplate,
  assessorName?: string | null,
  assesseeName?: string | null
): AssessmentDetail {
  const scores = parseScores(row.scoresJson);
  return {
    id: row.id,
    templateKey: row.templateKey,
    result: row.result === "passed" ? "passed" : "not_yet",
    createdAt: row.createdAt.toISOString(),
    assessorSignedAt: row.assessorSignedAt?.toISOString() ?? null,
    assesseeSignedAt: row.assesseeSignedAt?.toISOString() ?? null,
    participantCategory: row.participantCategory,
    scorePct: scorePctOf(scores),
    template,
    assessorName: assessorName ?? undefined,
    assesseeName: assesseeName ?? undefined,
    scores,
    overallComment: row.overallComment,
  };
}

/**
 * Majority-per-section rule (unit-tested): passed iff EVERY section has a
 * strict majority (count×2 > total) of its criteria scored ≥ 1.
 */
export function assessmentPassed(
  template: AssessmentTemplate,
  scores: Record<string, { score?: number }>
): boolean {
  return (
    template.sections.length > 0 &&
    template.sections.every((section) => {
      const total = section.criteria.length;
      const good = section.criteria.filter((c) => (scores[c.key]?.score ?? 0) >= 1).length;
      return total === 0 ? true : good * 2 > total;
    })
  );
}

@Injectable()
export class AssessmentsService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/assessments/templates — public template catalog. */
  async templates() {
    const rows = (await this.rls.system((tx) =>
      tx.assessmentTemplate.findMany({ orderBy: { key: "asc" } })
    )) as unknown as TemplateRow[];
    return { templates: rows.map(mapTemplate) };
  }

  /** GET /api/assessments[?userId] — history (default own), guard-scoped. */
  async list(viewer: User | null, targetParam?: string) {
    const user = this.guard.requireUser(viewer);
    const target = targetParam ? await this.guard.assertCanAccess(user, targetParam) : user;

    return this.rls.run(user, async (tx) => {
      const rows = (await tx.assessment.findMany({
        where: { OR: [{ assesseeId: target.id }, { assessorId: target.id }] },
        orderBy: { createdAt: "desc" },
      })) as unknown as AssessmentRowLike[];
      if (!rows.length) return { assessments: [] };

      const templateKeys = [...new Set(rows.map((r) => r.templateKey))];
      const templateRows = (await tx.assessmentTemplate.findMany({
        where: { key: { in: templateKeys } },
      })) as unknown as TemplateRow[];
      const templates = new Map(templateRows.map((t) => [t.key, mapTemplate(t)]));
      const fallback = (key: string): AssessmentTemplate => ({
        key,
        version: 1,
        titleBn: key,
        titleEn: key,
        sections: [],
      });

      const userKeys = [...new Set(rows.flatMap((r) => [r.assesseeId, r.assessorId]))];
      const users = await tx.user.findMany({ where: { id: { in: userKeys } }, select: { id: true, name: true } });
      const names = new Map(users.map((u) => [u.id, u.name]));

      return {
        assessments: rows.map((r) =>
          mapAssessment(
            r,
            templates.get(r.templateKey) ?? fallback(r.templateKey),
            names.get(r.assessorId),
            names.get(r.assesseeId)
          )
        ),
      };
    });
  }

  /**
   * POST /api/assessments — usrah_head+ records a signed assessment.
   * Result rule: passed iff EVERY section has a strict majority of its criteria
   * scored ≥ 1. Assessee gets a reminder; action is audit-logged.
   */
  async submit(viewer: User | null, dto: AssessmentSubmitDto) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "মূল্যায়ন জমা দেওয়ার অনুমতি নেই");

    const assesseeId = dto.assesseeId;
    const templateKey = (dto.templateKey ?? "").trim();
    if (!assesseeId) throw new ApiError(400, "মূল্যায়নার্থী নির্বাচন করা হয়নি");
    if (!templateKey) throw new ApiError(400, "টেমপ্লেট নির্বাচন করা হয়নি");
    const participantCategory = Number(dto.participantCategory) === 2 ? 2 : 1;
    if (!dto.scores || typeof dto.scores !== "object" || Array.isArray(dto.scores)) {
      throw new ApiError(400, "স্কোর দেওয়া হয়নি");
    }

    const target = await this.guard.assertCanAccess(user, assesseeId);

    return this.rls.run(user, async (tx) => {
      const templateRow = (await tx.assessmentTemplate.findUnique({
        where: { key: templateKey },
      })) as unknown as TemplateRow | null;
      if (!templateRow) throw new ApiError(400, "টেমপ্লেট পাওয়া যায়নি");
      const template = mapTemplate(templateRow);

      // sanitize scores
      const scores: Record<string, { score: 0 | 1 | 2; comment?: string }> = {};
      for (const [k, v] of Object.entries(dto.scores)) {
        const s = Number(v?.score);
        scores[k] = {
          score: (s === 1 || s === 2 ? s : 0) as 0 | 1 | 2,
          ...(v?.comment != null && String(v.comment).trim()
            ? { comment: String(v.comment).trim().slice(0, 500) }
            : {}),
        };
      }

      const passed = assessmentPassed(template, scores);
      const result = passed ? "passed" : "not_yet";

      const row = (await tx.assessment.create({
        data: {
          templateKey,
          assesseeId: target.id,
          assessorId: user.id,
          participantCategory,
          scoresJson: scores as never,
          overallComment: (dto.overallComment ?? "").toString().trim().slice(0, 4000) || null,
          assessorSignedAt: new Date(),
          result,
        },
      })) as unknown as AssessmentRowLike;

      await tx.reminder.create({
        data: {
          userId: target.id,
          kind: "assessment",
          title: "নতুন মূল্যায়ন সম্পন্ন হয়েছে",
          body: `${template.titleBn} — ফলাফল: ${passed ? "উত্তীর্ণ" : "আরও উন্নতি প্রয়োজন"}`,
        },
      });

      await this.guard.audit(user.id, "create_assessment", "user", target.id, {
        assesseeId: target.id,
        templateKey,
        result,
        participantCategory,
      });

      return { assessment: mapAssessment(row, template, user.name, target.name) };
    });
  }
}

@ApiTags("assessments")
@Controller("assessments")
@UseGuards(RolesGuard)
export class AssessmentsController {
  constructor(private readonly service: AssessmentsService) {}

  @Get("templates")
  @ApiOperation({ summary: "Assessment template catalog (public)" })
  templates() {
    return this.service.templates();
  }

  @Get()
  @ApiOperation({ summary: "Assessment history (own or guard-scoped ?userId)" })
  list(@Query("userId") userId: string | undefined, @Req() req: AuthedRequest) {
    return this.service.list(currentUser(req), userId);
  }

  @Post()
  @ApiOperation({ summary: "Record a signed assessment (majority-per-section rule)" })
  @Roles("invigilator") // invigilator and above (invigilator / usrah_head / full_admin)
  submit(@Body() dto: AssessmentSubmitDto, @Req() req: AuthedRequest) {
    return this.service.submit(currentUser(req), dto);
  }
}
