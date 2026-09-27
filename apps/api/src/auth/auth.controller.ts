import { Body, Controller, HttpCode, HttpStatus, Post, Res } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import type { Response } from "express";
import { AuthService } from "./auth.service";
import { LogoutDto, OtpRequestDto, OtpVerifyDto, RefreshDto } from "./dto/auth.dto";
import { ApiError } from "../common/api-error";

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
   */
  @Post("refresh")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Rotate the refresh token (family revoke on reuse)" })
  async refresh(@Body() dto: RefreshDto, @Res({ passthrough: true }) res: Response) {
    if (!dto?.refreshToken) throw new ApiError(400, "রিফ্রেশ টোকেন দিন");
    const result = await this.auth.refresh(dto.refreshToken);
    setTokenCookies(res, result.tokens.accessToken, result.tokens.refreshToken);
    return { user: result.user, ...result.tokens };
  }

  /** POST /api/auth/logout — revokes the refresh family; clears cookies. */
  @Post("logout")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Sign out (revoke refresh family)" })
  async logout(@Body() dto: LogoutDto, @Res({ passthrough: true }) res: Response) {
    const result = await this.auth.logout(dto?.refreshToken);
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
