import { type CanActivate, type ExecutionContext, Injectable } from "@nestjs/common";
import type { Request } from "express";
import { JwtService } from "@nestjs/jwt";
import { RlsService } from "./rls.service";
import { toDomainUser } from "./mappers";
import type { User } from "../shared/domain";

export interface AuthedRequest extends Request {
  user: User | null;
}

export function readCookie(req: Request, name: string): string | null {
  const header = req.headers.cookie;
  if (!header) return null;
  for (const part of header.split(";")) {
    const [k, ...rest] = part.trim().split("=");
    if (k === name) return decodeURIComponent(rest.join("="));
  }
  return null;
}

/**
 * Optional JWT guard: verifies the access token from the Authorization
 * header (Bearer) or the sl_access cookie, loads the fresh user row (system
 * context — auth bootstrap) and attaches it to req.user. Missing/expired
 * tokens leave req.user = null; individual endpoints decide whether that is
 * a 401 (requireUser) or a public response — mirroring the web getSessionUser.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly rls: RlsService
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // WS gateways (socket.io) authenticate with their own HMAC room token in
    // handleConnection — the JWT layer is HTTP-only. Guards/interceptors also
    // run in the "ws" context, so bail before touching an express Request.
    if (context.getType() !== "http") return true;
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    req.user = null;
    const header = req.headers.authorization;
    const token =
      (header?.startsWith("Bearer ") ? header.slice(7).trim() : null) ?? readCookie(req, "sl_access");
    if (!token) return true;
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; typ?: string }>(token, {
        secret: process.env.JWT_SECRET,
      });
      // A refresh token must never authenticate API calls. When the refresh
      // secret equals the access secret (documented dev fallback), the
      // signature alone would verify — the typ claim is the real gate.
      // [Phase C/W2c]
      if (payload.typ === "refresh") {
        return true; // → anonymous; endpoints answer 401 where required
      }
      const row = await this.rls.system((tx) =>
        tx.user.findUnique({ where: { id: payload.sub } })
      );
      if (row) req.user = toDomainUser(row as never);
    } catch {
      // invalid/expired token → anonymous
    }
    return true;
  }
}

/** Extract the current user or null from the request. */
export function currentUser(req: AuthedRequest): User | null {
  return req.user ?? null;
}
