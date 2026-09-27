import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, audit, requireUser } from "@/lib/server/auth";
import { assertCanAccess, errorResponse, isSupervisor, json } from "@/lib/server/guard";
import type {
  AssessmentDetail,
  AssessmentSection,
  AssessmentTemplate,
} from "@/types/domain";

type TemplateRow = {
  id: string;
  key: string;
  version: number;
  titleBn: string;
  titleEn: string;
  sectionsJson: string;
};

function mapTemplate(row: TemplateRow): AssessmentTemplate {
  let sections: AssessmentSection[] = [];
  try {
    const parsed = JSON.parse(row.sectionsJson);
    if (Array.isArray(parsed)) {
      sections = parsed
        .filter((s) => s && typeof s === "object")
        .map((s) => ({
          key: String(s.key ?? ""),
          titleBn: String(s.titleBn ?? ""),
          criteria: Array.isArray(s.criteria)
            ? s.criteria
                .filter((c: unknown) => c && typeof c === "object")
                .map((c: { key?: unknown; titleBn?: unknown; hintBn?: unknown }) => ({
                  key: String(c.key ?? ""),
                  titleBn: String(c.titleBn ?? ""),
                  hintBn: c.hintBn != null ? String(c.hintBn) : undefined,
                }))
            : [],
        }));
    }
  } catch {
    sections = [];
  }
  return { key: row.key, version: row.version, titleBn: row.titleBn, titleEn: row.titleEn, sections };
}

function parseScores(raw: string): Record<string, { score: 0 | 1 | 2; comment?: string }> {
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed as Record<string, { score: 0 | 1 | 2; comment?: string }>;
    }
  } catch {
    // fall through
  }
  return {};
}

function scorePctOf(scores: Record<string, { score?: number }>): number | null {
  const vals = Object.values(scores);
  if (!vals.length) return null;
  const sum = vals.reduce((s, v) => s + (v?.score ?? 0), 0);
  return Math.round((100 * sum) / (2 * vals.length));
}

/** Map one DB assessment row (+ names + template) to AssessmentDetail. */
function mapAssessment(
  row: {
    id: string;
    templateKey: string;
    assesseeId: string;
    assessorId: string;
    participantCategory: number;
    scoresJson: string;
    overallComment: string | null;
    assessorSignedAt: Date | null;
    assesseeSignedAt: Date | null;
    result: string;
    createdAt: Date;
  },
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
 * GET /api/assessments[?userId] — assessment history (default: own), each with
 * template + assessor/assessee names. Gender/scope guard applied for others.
 */
export async function GET(req: NextRequest) {
  try {
    const viewer = await requireUser();
    const targetParam = req.nextUrl.searchParams.get("userId");
    const target = targetParam ? await assertCanAccess(viewer, targetParam) : viewer;

    const rows = await db.assessment.findMany({
      where: { OR: [{ assesseeId: target.id }, { assessorId: target.id }] },
      orderBy: { createdAt: "desc" },
    });
    if (!rows.length) return json({ assessments: [] });

    const templateKeys = [...new Set(rows.map((r) => r.templateKey))];
    const templateRows = await db.assessmentTemplate.findMany({ where: { key: { in: templateKeys } } });
    const templates = new Map(templateRows.map((t) => [t.key, mapTemplate(t)]));
    const fallback = (key: string): AssessmentTemplate => ({
      key,
      version: 1,
      titleBn: key,
      titleEn: key,
      sections: [],
    });

    const userKeys = [...new Set(rows.flatMap((r) => [r.assesseeId, r.assessorId]))];
    const users = await db.user.findMany({ where: { id: { in: userKeys } }, select: { id: true, name: true } });
    const names = new Map(users.map((u) => [u.id, u.name]));

    return json({
      assessments: rows.map((r) =>
        mapAssessment(r, templates.get(r.templateKey) ?? fallback(r.templateKey), names.get(r.assessorId), names.get(r.assesseeId))
      ),
    });
  } catch (e) {
    return errorResponse(e);
  }
}

/**
 * POST /api/assessments — usrah_head+ records a signed assessment.
 * Result rule: passed iff EVERY section has a strict majority of its criteria
 * scored ≥ 1. Assessee gets a reminder; action is audit-logged.
 */
export async function POST(req: NextRequest) {
  try {
    const viewer = await requireUser();
    if (!isSupervisor(viewer)) throw new ApiError(403, "মূল্যায়ন জমা দেওয়ার অনুমতি নেই");

    const body = (await req.json().catch(() => null)) as {
      assesseeId?: string;
      templateKey?: string;
      participantCategory?: number;
      scores?: Record<string, { score?: number; comment?: string }>;
      overallComment?: string;
    } | null;

    const assesseeId = body?.assesseeId;
    const templateKey = (body?.templateKey ?? "").trim();
    if (!assesseeId) throw new ApiError(400, "মূল্যায়নার্থী নির্বাচন করা হয়নি");
    if (!templateKey) throw new ApiError(400, "টেমপ্লেট নির্বাচন করা হয়নি");
    const participantCategory = Number(body?.participantCategory) === 2 ? 2 : 1;
    if (!body?.scores || typeof body.scores !== "object" || Array.isArray(body.scores)) {
      throw new ApiError(400, "স্কোর দেওয়া হয়নি");
    }

    const target = await assertCanAccess(viewer, assesseeId);
    const templateRow = await db.assessmentTemplate.findUnique({ where: { key: templateKey } });
    if (!templateRow) throw new ApiError(400, "টেমপ্লেট পাওয়া যায়নি");
    const template = mapTemplate(templateRow);

    // sanitize scores
    const scores: Record<string, { score: 0 | 1 | 2; comment?: string }> = {};
    for (const [k, v] of Object.entries(body.scores)) {
      const s = Number(v?.score);
      scores[k] = {
        score: (s === 1 || s === 2 ? s : 0) as 0 | 1 | 2,
        ...(v?.comment != null && String(v.comment).trim() ? { comment: String(v.comment).trim().slice(0, 500) } : {}),
      };
    }

    // passed iff every section has a strict majority of criteria with score ≥ 1
    const passed =
      template.sections.length > 0 &&
      template.sections.every((section) => {
        const total = section.criteria.length;
        const good = section.criteria.filter((c) => (scores[c.key]?.score ?? 0) >= 1).length;
        return total === 0 ? true : good * 2 > total;
      });
    const result = passed ? "passed" : "not_yet";

    const row = await db.assessment.create({
      data: {
        templateKey,
        assesseeId: target.id,
        assessorId: viewer.id,
        participantCategory,
        scoresJson: JSON.stringify(scores),
        overallComment: (body?.overallComment ?? "").toString().trim().slice(0, 4000) || null,
        assessorSignedAt: new Date(),
        result,
      },
    });

    await db.reminder.create({
      data: {
        userId: target.id,
        kind: "assessment",
        title: "নতুন মূল্যায়ন সম্পন্ন হয়েছে",
        body: `${template.titleBn} — ফলাফল: ${passed ? "উত্তীর্ণ" : "আরও উন্নতি প্রয়োজন"}`,
      },
    });

    await audit(viewer.id, "create_assessment", "user", target.id, {
      assesseeId: target.id,
      templateKey,
      result,
      participantCategory,
    });

    return json({ assessment: mapAssessment(row, template, viewer.name, target.name) });
  } catch (e) {
    return errorResponse(e);
  }
}
