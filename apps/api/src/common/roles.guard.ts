import { type CanActivate, type ExecutionContext, Injectable } from "@nestjs/common";
import type { Request } from "express";
import { Reflector } from "@nestjs/core";
import { ROLE_RANK } from "../shared/domain";
import type { Role, User } from "../shared/domain";
import { ROLES_KEY } from "./roles.decorator";
import { ApiError } from "./api-error";

interface MaybeAuthedRequest extends Request {
  user?: User | null;
}

/**
 * Route-guard companion of @Roles(). Reads the role floor set by the
 * decorator and rejects with 401 (anonymous) / 403 (insufficient rank).
 *
 * Runs AFTER the global JwtAuthGuard (controller/route guards execute after
 * global ones), so req.user is already resolved from the Bearer header or the
 * sl_access cookie. Routes without @Roles() pass through untouched.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    // method-level metadata wins over controller-level (both may exist)
    const required =
      this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? null;
    if (!required || required.length === 0) return true;

    const req = context.switchToHttp().getRequest<MaybeAuthedRequest>();
    const user = req.user ?? null;
    if (!user) throw new ApiError(401, "সাইন ইন প্রয়োজন");

    const floor = Math.min(...required.map((r) => ROLE_RANK[r] ?? -1));
    const rank = ROLE_RANK[user.role] ?? -1;
    if (rank < floor) {
      throw new ApiError(403, "এই কাজের অনুমতি নেই");
    }
    return true;
  }
}
