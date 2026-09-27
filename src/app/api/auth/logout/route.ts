import { destroySession } from "@/lib/server/auth";
import { json, errorResponse } from "@/lib/server/guard";

export async function POST() {
  try {
    await destroySession();
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
