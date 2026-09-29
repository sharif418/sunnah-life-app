import { Req, Body, Controller, Get, Param, Post, Query, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { IsOptional, IsString, MaxLength } from "class-validator";
import type { Prisma } from "../common/prisma-client";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { toDomainUser } from "../common/mappers";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { AuthService } from "../auth/auth.service";
import { AssessmentSubmitDto } from "../auth/dto/auth.dto";
import { fajrOfNextDay, type LockUser } from "../shared/amal";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import type {
  AssessmentDetail,
  AssessmentSection,
  AssessmentStatus,
  AssessmentTemplate,
  User,
} from "../shared/domain";

export class AssessmentConfirmDto {
  @ApiProperty({ example: "123456" })
  @IsString({ message: "কোড দিন" })
  code!: string;
}

export class AssessmentDeclineDto {
  @ApiProperty({ required: false, example: "স্কোরে ভুল আছে — আবার মূল্যায়ন হোক" })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

type TemplateRow = {
  id: string;
  key: string;
  version: number;
  titleBn: string;
  titleEn: string;
  sectionsJson: unknown;
  metaJson?: unknown;
  active?: boolean;
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
  let meta: AssessmentTemplate["meta"];
  const m = row.metaJson;
  if (m && typeof m === "object" && !Array.isArray(m)) {
    const raw = m as Record<string, unknown>;
    meta = {
      instructionsBn: typeof raw.instructionsBn === "string" ? raw.instructionsBn : null,
      categories: Array.isArray(raw.categories)
        ? (raw.categories as NonNullable<AssessmentTemplate["meta"]>["categories"])
        : null,
      categoriesFooterBn: typeof raw.categoriesFooterBn === "string" ? raw.categoriesFooterBn : null,
      scale: Array.isArray(raw.scale) ? (raw.scale as NonNullable<AssessmentTemplate["meta"]>["scale"]) : null,
      scaleNoteBn: typeof raw.scaleNoteBn === "string" ? raw.scaleNoteBn : null,
      summarySpec:
        raw.summarySpec && typeof raw.summarySpec === "object"
          ? (raw.summarySpec as NonNullable<AssessmentTemplate["meta"]>["summarySpec"])
          : null,
      overallCommentLabelBn:
        typeof raw.overallCommentLabelBn === "string" ? raw.overallCommentLabelBn : null,
      signatures: Array.isArray(raw.signatures)
        ? (raw.signatures as NonNullable<AssessmentTemplate["meta"]>["signatures"])
        : null,
      headerFields: Array.isArray(raw.headerFields)
        ? (raw.headerFields as NonNullable<AssessmentTemplate["meta"]>["headerFields"])
        : null,
    };
  }
  return { key: row.key, version: row.version, titleBn: row.titleBn, titleEn: row.titleEn, sections, ...(meta ? { meta } : {}) };
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
  status: string;
  confirmedAt: Date | null;
  declinedAt: Date | null;
  decisionNote: string | null;
  createdAt: Date;
};

/** The three known statuses — anything else (legacy/unknown) reads as
 * pending_confirmation, the safe non-final default. */
export function normalizeStatus(raw: string): AssessmentStatus {
  return raw === "confirmed" || raw === "declined" ? raw : "pending_confirmation";
}

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
    status: normalizeStatus(row.status),
    confirmedAt: row.confirmedAt?.toISOString() ?? null,
    declinedAt: row.declinedAt?.toISOString() ?? null,
    decisionNote: row.decisionNote ?? null,
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
    private readonly guard: GuardService,
    private readonly auth: AuthService
  ) {}

  /** GET /api/assessments/templates — the ACTIVE version of each template family. */
  async templates() {
    const rows = (await this.rls.system((tx) =>
      tx.assessmentTemplate.findMany({ where: { active: true }, orderBy: { key: "asc" } })
    )) as unknown as TemplateRow[];
    return { templates: rows.map(mapTemplate) };
  }

  /**
   * Shared row→detail mapper for the member-facing reads: joins the ACTIVE
   * template of each family (falling back to any remaining row of the key)
   * and the assessee/assessor names. Runs inside the caller's RLS context.
   */
  private async mapRows(
    tx: Prisma.TransactionClient,
    rows: AssessmentRowLike[]
  ): Promise<AssessmentDetail[]> {
    if (!rows.length) return [];

    const templateKeys = [...new Set(rows.map((r) => r.templateKey))];
    // prefer the ACTIVE version of each family; historical assessments of
    // since-deactivated versions fall back to any remaining row of that key
    const templateRows = (await tx.assessmentTemplate.findMany({
      where: { key: { in: templateKeys } },
      orderBy: [{ key: "asc" }, { active: "desc" }, { version: "desc" }],
    })) as unknown as TemplateRow[];
    const activeOrLast = new Map<string, TemplateRow>();
    for (const t of templateRows) {
      if (!activeOrLast.has(t.key)) activeOrLast.set(t.key, t);
    }
    const templates = new Map([...activeOrLast].map(([key, t]) => [key, mapTemplate(t)]));
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

    return rows.map((r) =>
      mapAssessment(
        r,
        templates.get(r.templateKey) ?? fallback(r.templateKey),
        names.get(r.assessorId),
        names.get(r.assesseeId)
      )
    );
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
      return { assessments: await this.mapRows(tx, rows) };
    });
  }

  /**
   * GET /api/assessments/me (W4i) — the signed-in member's OWN assessments
   * (where they are the ASSESSEE), every status, with scores: the
   * acknowledgment flow's read. Any signed-in member; RLS the net.
   */
  async me(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    return this.rls.run(user, async (tx) => {
      const rows = (await tx.assessment.findMany({
        where: { assesseeId: user.id },
        orderBy: { createdAt: "desc" },
      })) as unknown as AssessmentRowLike[];
      return { assessments: await this.mapRows(tx, rows) };
    });
  }

  /**
   * POST /api/assessments — usrah_head+ records a signed assessment.
   * Result rule: passed iff EVERY section has a strict majority of its criteria
   * scored ≥ 1. W4i: the row starts status pending_confirmation — the result
   * only becomes FINAL when the ASSESSEE confirms it with their own OTP.
   * The assessee gets a Fajr-scheduled reminder (their own tz) to review +
   * acknowledge; the submission itself is audit-logged.
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
      const templateRow = (await tx.assessmentTemplate.findFirst({
        where: { key: templateKey, active: true },
        orderBy: { version: "desc" },
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
          status: "pending_confirmation",
        },
      })) as unknown as AssessmentRowLike;

      // W4i — the "notify" step: the ASSESSEE's reminder, scheduled Fajr of
      // their tomorrow in their own tz (the goal-approval pattern) with the
      // link hint "assessment", so the existing reminder panel + push infra
      // surface it. Reminder's WITH CHECK (sl_visible_user) passes in this
      // context exactly like the review-submit reminder.
      const member = await tx.user.findUnique({
        where: { id: target.id },
        select: { tz: true, lat: true, lng: true, calcMethod: true, madhhab: true },
      });
      await tx.reminder.create({
        data: {
          userId: target.id,
          kind: "assessment",
          title: "মূল্যায়নের ফলাফল প্রস্তুত",
          body: `${template.titleBn} — ফলাফল: ${passed ? "উত্তীর্ণ" : "আরও উন্নতি প্রয়োজন"}। দাওয়াত ট্যাবে দেখে OTP দিয়ে নিশ্চিত করুন।`,
          link: "assessment",
          scheduledAt: member
            ? fajrOfNextDay(member as unknown as LockUser)
            : new Date(Date.now() + 24 * 3_600_000),
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

  // ── W4i — the assessee's own acknowledgment flow ─────────────────────────

  /**
   * Load one assessment metadata-only (system context) for the assessee's
   * own decision endpoints: 404 when missing, 403 when the caller is anyone
   * other than the assessee — the assessor may VIEW the row (RLS lets them)
   * but the acknowledgment decision is the assessee's alone, never the
   * invigilator's or the admin's.
   */
  private async loadForSelfDecision(viewer: User, id: string): Promise<AssessmentRowLike> {
    const row = (await this.rls.system((tx) =>
      tx.assessment.findUnique({ where: { id } })
    )) as unknown as AssessmentRowLike | null;
    if (!row) throw new ApiError(404, "মূল্যায়নটি পাওয়া যায়নি");
    if (row.assesseeId !== viewer.id) {
      throw new ApiError(403, "নিশ্চিতকরণ শুধু মূল্যায়নার্থীর নিজের কাজ");
    }
    return row;
  }

  /**
   * POST /api/assessments/:id/confirm-request — the ASSESSEE asks for the
   * OTP. Reuses the auth OTP service verbatim (requestOtp: same DB-backed
   * 3-per-10-min window per phone, sha256 storage, provider send) against
   * the assessee's OWN phone — never a caller-supplied number.
   */
  async confirmRequest(viewer: User | null, id: string) {
    const user = this.guard.requireUser(viewer);
    const row = await this.loadForSelfDecision(user, id);
    if (row.status !== "pending_confirmation") {
      throw new ApiError(400, "মূল্যায়নটি অপেক্ষমাণ নয় — আর কোড লাগবে না");
    }
    const phoneRow = await this.rls.system((tx) =>
      tx.user.findUnique({ where: { id: user.id }, select: { phone: true } })
    );
    if (!phoneRow?.phone) {
      // social-created accounts without a phone cannot OTP-acknowledge —
      // honest refusal (linking a phone is a future account-settings task)
      throw new ApiError(400, "আপনার অ্যাকাউন্টে মোবাইল নম্বর যুক্ত নেই — ফাউন্ডেশনে যোগাযোগ করুন");
    }
    const res = await this.auth.requestOtp(phoneRow.phone);
    return { ok: true as const, ...(res.devCode ? { devCode: res.devCode } : {}) };
  }

  /**
   * POST /api/assessments/:id/confirm {code} — verify the OTP against the
   * assessee's own phone (consumeOtpCode: atomic attempt counter + single
   * use), then status → confirmed + assesseeSignedAt/confirmedAt. Race-safe
   * via the conditional updateMany; audited as assessment_confirm.
   */
  async confirm(viewer: User | null, id: string, dto: AssessmentConfirmDto) {
    const user = this.guard.requireUser(viewer);
    const row = await this.loadForSelfDecision(user, id);
    if (row.status !== "pending_confirmation") {
      throw new ApiError(400, "মূল্যায়নটি অপেক্ষমাণ নয়");
    }
    const code = (dto?.code ?? "").toString().trim();
    if (!code) throw new ApiError(400, "কোড দিন");

    const phoneRow = await this.rls.system((tx) =>
      tx.user.findUnique({ where: { id: user.id }, select: { phone: true } })
    );
    if (!phoneRow?.phone) {
      throw new ApiError(400, "আপনার অ্যাকাউন্টে মোবাইল নম্বর যুক্ত নেই — ফাউন্ডেশনে যোগাযোগ করুন");
    }
    // the shared atomic verify+consume — a wrong code 400s, the 5th wrong
    // attempt 429s, a correct code burns so it can never replay.
    await this.auth.consumeOtpCode(phoneRow.phone, code);

    const now = new Date();
    return this.rls.run(user, async (tx) => {
      // status guard: another confirm may have landed between the read above
      // and this write — updateMany only fires on a still-pending row.
      const res = await tx.assessment.updateMany({
        where: { id, status: "pending_confirmation" },
        data: { status: "confirmed", confirmedAt: now, assesseeSignedAt: now },
      });
      if (res.count === 0) {
        throw new ApiError(400, "মূল্যায়নটি অপেক্ষমাণ নয়");
      }
      const updated = (await tx.assessment.findUnique({ where: { id } })) as unknown as AssessmentRowLike;
      return { assessment: (await this.mapRows(tx, [updated]))[0] };
    }).then(async (payload) => {
      await this.guard.audit(user.id, "assessment_confirm", "assessment", id, {
        assesseeId: user.id,
        templateKey: row.templateKey,
        result: row.result,
      });
      return payload;
    });
  }

  /**
   * POST /api/assessments/:id/decline {reason?} — the ASSESSEE refuses the
   * result. Decision (documented in code): declining is final for the row —
   * the assessor gets a Fajr-scheduled reminder (their own tz) carrying the
   * member's name + reason so a re-assessment can be arranged; the row keeps
   * result/scores for history but never counts as passed. Audited as
   * assessment_decline.
   */
  async decline(viewer: User | null, id: string, dto: AssessmentDeclineDto) {
    const user = this.guard.requireUser(viewer);
    const row = await this.loadForSelfDecision(user, id);
    if (row.status !== "pending_confirmation") {
      throw new ApiError(400, "মূল্যায়নটি অপেক্ষমাণ নয়");
    }
    const reason = (dto?.reason ?? "").toString().trim().slice(0, 500) || null;

    const now = new Date();
    // The status update runs in the ASSESSEE's own context (they are the row's
    // assessee — RLS allows the self-write).
    const payload = await this.rls.run(user, async (tx) => {
      const res = await tx.assessment.updateMany({
        where: { id, status: "pending_confirmation" },
        data: { status: "declined", declinedAt: now, decisionNote: reason },
      });
      if (res.count === 0) {
        throw new ApiError(400, "মূল্যায়নটি অপেক্ষমাণ নয়");
      }
      const updated = (await tx.assessment.findUnique({ where: { id } })) as unknown as AssessmentRowLike;
      return { assessment: (await this.mapRows(tx, [updated]))[0] };
    });

    // The assessor (the invigilator who submitted the scores) is notified —
    // the goal-approval reminder pattern, their own tz, Fajr tomorrow. The
    // member's own RLS context CANNOT write the invigilator's reminder row
    // (sl_visible_user — a member does not see a supervising invigilator, by
    // design), so the notification is inserted with the RECIPIENT's context:
    // a self-write on their own reminder, exactly the row any notification
    // pipeline would land. Non-transactional by the same rule as audit rows —
    // a failed notification never rolls back the member's decision.
    const assessorRow = await this.rls.system((tx) =>
      tx.user.findUnique({ where: { id: row.assessorId } })
    );
    if (assessorRow) {
      const assessor = toDomainUser(assessorRow as never);
      await this.rls.run(assessor, (tx) =>
        tx.reminder.create({
          data: {
            userId: row.assessorId,
            kind: "assessment",
            title: "মূল্যায়ন বাতিল করা হয়েছে",
            body: `${user.name} আপনার নেওয়া মূল্যায়ন বাতিল করেছেন${reason ? ` — কারণ: ${reason}` : ""}। অনুগ্রহ করে পুনরায় মূল্যায়নের ব্যবস্থা করুন।`,
            link: "assessment",
            scheduledAt: fajrOfNextDay(assessorRow as unknown as LockUser),
          },
        })
      );
    }

    await this.guard.audit(user.id, "assessment_decline", "assessment", id, {
      assesseeId: user.id,
      assessorId: row.assessorId,
      templateKey: row.templateKey,
      reason,
    });
    return payload;
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

  @Get("me")
  @ApiOperation({ summary: "Own assessments incl. status + scores (any signed-in member)" })
  me(@Req() req: AuthedRequest) {
    return this.service.me(currentUser(req));
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

  @Post(":id/confirm-request")
  @ApiOperation({ summary: "ASSESSEE ONLY — issue the OTP to their own phone (W4i)" })
  confirmRequest(@Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.confirmRequest(currentUser(req), id);
  }

  @Post(":id/confirm")
  @ApiOperation({ summary: "ASSESSEE ONLY — verify the OTP → result becomes final (W4i)" })
  confirm(@Param("id") id: string, @Body() dto: AssessmentConfirmDto, @Req() req: AuthedRequest) {
    return this.service.confirm(currentUser(req), id, dto);
  }

  @Post(":id/decline")
  @ApiOperation({ summary: "ASSESSEE ONLY — refuse the result with an optional reason (W4i)" })
  decline(@Param("id") id: string, @Body() dto: AssessmentDeclineDto, @Req() req: AuthedRequest) {
    return this.service.decline(currentUser(req), id, dto);
  }
}
