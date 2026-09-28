import { SetMetadata } from "@nestjs/common";
import type { Role } from "../shared/domain";

/**
 * Explicit role-rank authorization at the route level.
 *
 * Semantics: the listed names are role RANK floors — a caller passes when
 * ROLE_RANK[req.user.role] >= min(ROLE_RANK of the listed roles). This mirrors
 * GuardService.isSupervisor / assertFullAdmin, e.g.
 *
 *   @Roles("full_admin")                      → rank 3 (full admin only)
 *   @Roles("usrah_head")                      → rank 2+ (heads + invigilators + admin)
 *   @Roles("invigilator")                     → rank 2+ (same set — invigilator and
 *                                              usrah_head share rank 2)
 *
 * The guard (roles.guard.ts) runs after the global JwtAuthGuard and is a no-op
 * on routes without the decorator. RLS remains the last line of defence — this
 * makes authorization explicit, testable and visible in Swagger metadata.
 */
export const ROLES_KEY = "sl:roles";

export const Roles = (...roles: Role[]): MethodDecorator & ClassDecorator =>
  SetMetadata(ROLES_KEY, roles) as MethodDecorator & ClassDecorator;
