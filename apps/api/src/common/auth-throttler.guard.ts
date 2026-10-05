import { Injectable } from "@nestjs/common";
import { ThrottlerGuard } from "@nestjs/throttler";

/**
 * The app-wide throttler guard. Each named throttler carries its own
 * tracker and route scope (src/common/throttlers.ts); this fallback tracker
 * (per IP) only applies to a throttler that names none.
 */
@Injectable()
export class AuthThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, unknown>): Promise<string> {
    return `ip:${(req as { ip?: string }).ip ?? "unknown"}`;
  }
}
