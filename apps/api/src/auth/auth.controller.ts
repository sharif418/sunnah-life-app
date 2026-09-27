import { Body, Controller, HttpCode, HttpStatus, Post, Req, Res } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import type { Request, Response } from "express";
import { AuthService } from "./auth.service";
import { LogoutDto, OtpRequestDto, OtpVerifyDto, RefreshDto } from "./dto/auth.dto";
import { ApiError } from "../common/api-error";
import { readCookie } from "../common/auth.guard";

@ApiTags("auth")
@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** POST /api/auth/otp/request — {phone} → {ok, devCode} (mock SMS). */
  @Post("otp/request")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Send a phone OTP (mock provider returns devCode)" })
  requestOtp(@Body() dto: OtpRequestDto) {
    return this.auth.requestOtp(dto.phone);
  }

  /**
   * POST /api/auth/otp/verify — {phone, code, name?, gender?, referredByCode?,
   * guestEntries?} → {user, accessToken, refreshToken, tokenType, expiresIn}.
   * Creates the user + referral closure, merges guest amal entries
   * (clientUpdatedAt latest-wins) and issues the JWT pair. Tokens are also set
   * as HttpOnly cookies for cookie-based clients (web PWA parity).
   */
  @Post("otp/verify")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Verify OTP → sign in / register + guest data merge" })
  async verifyOtp(@Body() dto: OtpVerifyDto, @Res({ passthrough: true }) res: Response) {
    const result = await this.auth.verifyOtp(
      dto.phone,
      dto.code,
      dto.name,
      dto.gender,
      dto.referredByCode,
      dto.guestEntries
    );
    setTokenCookies(res, result.tokens.accessToken, result.tokens.refreshToken);
    return { user: result.user, ...result.tokens };
  }

  /**
   * POST /api/auth/refresh — rotating refresh. A replayed (already used)
   * token revokes the whole family (reuse detection) and returns 401.
   * The token may come from the body (mobile/Bearer clients) or the HttpOnly
   * sl_refresh cookie (web PWA clients cannot read it to echo it back).
   */
  @Post("refresh")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Rotate the refresh token (body token or sl_refresh cookie)" })
  async refresh(@Body() dto: RefreshDto, @Req() req: Request, @Res({ passthrough: true }) res: Response) {
    const token = dto?.refreshToken || readCookie(req, "sl_refresh");
    if (!token) throw new ApiError(400, "রিফ্রেশ টোকেন দিন");
    const result = await this.auth.refresh(token);
    setTokenCookies(res, result.tokens.accessToken, result.tokens.refreshToken);
    return { user: result.user, ...result.tokens };
  }

  /** POST /api/auth/logout — revokes the refresh family; clears cookies. */
  @Post("logout")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Sign out (revoke refresh family)" })
  async logout(@Body() dto: LogoutDto, @Req() req: Request, @Res({ passthrough: true }) res: Response) {
    const token = dto?.refreshToken || readCookie(req, "sl_refresh");
    const result = await this.auth.logout(token || undefined);
    res.clearCookie("sl_access");
    res.clearCookie("sl_refresh");
    return result;
  }
}

export function setTokenCookies(res: Response, accessToken: string, refreshToken: string) {
  const secure = process.env.NODE_ENV === "production";
  res.cookie("sl_access", accessToken, {
    httpOnly: true,
    sameSite: "lax",
    secure,
    path: "/",
    maxAge: 15 * 60 * 1000,
  });
  res.cookie("sl_refresh", refreshToken, {
    httpOnly: true,
    sameSite: "lax",
    secure,
    path: "/",
    maxAge: 7 * 86400 * 1000,
  });
}
