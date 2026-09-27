import { json, errorResponse } from "@/lib/server/guard";
import { loadActiveDefinitions, mapDefinition } from "@/lib/server/amal";

export const dynamic = "force-dynamic";

/** GET /api/amal/definitions — active amal catalog (public: guests keep a local diary too). */
export async function GET() {
  try {
    const rows = await loadActiveDefinitions();
    return json({ definitions: rows.map(mapDefinition) });
  } catch (e) {
    return errorResponse(e);
  }
}
