import { db } from "@/lib/db";
import { requireUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";
import type { AssessmentSection, AssessmentTemplate } from "@/types/domain";

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
  return {
    key: row.key,
    version: row.version,
    titleBn: row.titleBn,
    titleEn: row.titleEn,
    sections,
  };
}

/** GET /api/assessments/templates — all assessment templates (sections parsed). */
export async function GET() {
  try {
    await requireUser();
    const rows = await db.assessmentTemplate.findMany({ orderBy: { key: "asc" } });
    return json({ templates: rows.map(mapTemplate) });
  } catch (e) {
    return errorResponse(e);
  }
}
