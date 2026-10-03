import { Res, Req, Body, Controller, Get, HttpCode, HttpStatus, Patch, Post } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import type { Response } from "express";
import { IsEmail, IsIn, IsLatitude, IsLongitude, IsNotEmpty, IsOptional, IsString, MaxLength, ValidateIf } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { toDomainUser } from "../common/mappers";
import { ApiError } from "../common/api-error";
import { AuthService } from "../auth/auth.service";

/** Gender is locked once set: a user whose account was created WITHOUT one
 *  (social sign-in — gender "unspecified") sets it exactly once here, as the
 *  completion of the onboarding step. Any later change is rejected. */
const GENDER_LOCKED_ERR = "লিঙ্গ পরিবর্তন করা যায় না";

/** PROF-04: a phone number to add or change (an OTP goes to it first). */
export class MePhoneRequestDto {
  @ApiProperty({ example: "01712345678" })
  @IsString({ message: "সঠিক মোবাইল নম্বর দিন" })
  @IsNotEmpty({ message: "সঠিক মোবাইল নম্বর দিন" })
  @MaxLength(20)
  phone!: string;
}

export class MePhoneVerifyDto extends MePhoneRequestDto {
  @ApiProperty({ example: "123456" })
  @IsString({ message: "কোড দিন" })
  @IsNotEmpty({ message: "কোড দিন" })
  @MaxLength(10)
  code!: string;
}

export class MePatchDto {
  /** PROF-04: contact e-mail (null/"" clears it). */
  @ApiProperty({ required: false, example: "name@example.com" })
  @IsOptional()
  @ValidateIf((_, v) => v !== null && v !== "")
  @IsEmail({}, { message: "সঠিক ইমেইল দিন" })
  @MaxLength(200)
  email?: string | null;

  @ApiProperty({ required: false, example: "রাফিউল ইসলাম" })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiProperty({ required: false, enum: ["bn", "en", "ar"] })
  @IsOptional()
  @IsIn(["bn", "en", "ar"], { message: "ভাষা ঠিক নয়" })
  language?: string;

  @ApiProperty({ required: false, enum: ["hanafi", "shafii"] })
  @IsOptional()
  @IsIn(["hanafi", "shafii"], { message: "মাযহাব ঠিক নয়" })
  madhhab?: string;

  @ApiProperty({ required: false, enum: ["karachi", "mwl", "isna", "egypt", "makkah", "dubai"] })
  @IsOptional()
  @IsIn(["karachi", "mwl", "isna", "egypt", "makkah", "dubai"], { message: "হিসাব পদ্ধতি ঠিক নয়" })
  calcMethod?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsLatitude({ message: "অক্ষাংশ ঠিক নয়" })
  lat?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsLongitude({ message: "দ্রাঘিমাংশ ঠিক নয়" })
  lng?: number;

  @ApiProperty({ required: false, example: "ঢাকা" })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @ApiProperty({ required: false, example: "dhaka" })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  district?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(160)
  workplace?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(160)
  department?: string;

  @ApiProperty({
    required: false,
    enum: ["M", "F"],
    description:
      "One-time ONLY: completes gender onboarding for accounts created without it (social sign-in). Rejected once a gender is set.",
  })
  @IsOptional()
  @IsIn(["M", "F"], { message: "লিঙ্গ ঠিক নয়" })
  gender?: "M" | "F";

  @ApiProperty({ required: false, enum: ["general", "hafez", "alim"] })
  @IsOptional()
  @IsIn(["general", "hafez", "alim"], { message: "ক্যাটাগরি ঠিক নয়" })
  category?: string;
}

const ALLOWED_FIELDS = [
  "name", "email", "gender", "language", "madhhab", "calcMethod", "lat", "lng", "city",
  "district", "workplace", "department", "category", "tz",
] as const;

@ApiTags("me")
@Controller("me")
export class MeController {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService,
    private readonly auth: AuthService
  ) {}

  /** GET /api/me — {user|null}; refreshes lastActiveAt when signed in. */
  @Get()
  @ApiOperation({ summary: "Current user profile (null when anonymous)" })
  async me(@Req() req: AuthedRequest) {
    const user = currentUser(req);
    if (user) {
      await this.rls
        .run(user, (tx) => tx.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } }))
        .catch(() => null);
    }
    return { user };
  }

  /** PATCH /api/me — allowlisted profile fields only. Gender is a ONE-TIME
   *  set (social-sign-in accounts complete it here); changing an already-set
   *  gender is rejected — it is onboarding data, locked afterwards (full_admin
   *  may still change it through the admin console). */
  @Patch()
  @ApiOperation({ summary: "Update own profile (allowlisted fields; gender one-time)" })
  async updateMe(@Body() dto: MePatchDto, @Req() req: AuthedRequest, @Res({ passthrough: true }) res: Response) {
    const user = this.guard.requireUser(currentUser(req));
    const body = dto as unknown as Record<string, unknown>;
    const data: Record<string, unknown> = {};
    for (const f of ALLOWED_FIELDS) {
      if (body[f] !== undefined) data[f] = body[f];
    }
    // GENDER RULE: set-once. "unspecified" = pre-onboarding (social-created
    // account) — that user may set it here exactly once; anything else is a
    // change attempt → rejected (same value re-sent is a harmless no-op).
    if (body.gender !== undefined) {
      const current = user.gender;
      if (current !== "unspecified" && current !== body.gender) {
        throw new ApiError(400, GENDER_LOCKED_ERR);
      }
      if (current !== "unspecified" && current === body.gender) {
        delete data.gender; // no-op, not an error
      }
    }
    if (data.email !== undefined) {
      const e = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
      data.email = e || null;
    }
    if (Object.keys(data).length === 0) {
      throw new ApiError(400, "কিছু পরিবর্তন দেওয়া হয়নি");
    }
    const updated = await this.rls.run(user, (tx) =>
      tx.user.update({ where: { id: user.id }, data: data as never })
    );
    void res;
    return { user: toDomainUser(updated as never) };
  }

  /**
   * POST /api/me/phone/request — PROF-04: send an OTP to a NEW phone (the
   * phone is the sign-in identity, so it changes only once the member proves
   * they hold it). Refused when another account already uses the number.
   */
  @Post("phone/request")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Send an OTP to a new phone number (signed in)" })
  async requestPhone(@Body() dto: MePhoneRequestDto, @Req() req: AuthedRequest) {
    const user = this.guard.requireUser(currentUser(req));
    const phone = normalizePhone(dto.phone);
    await this.assertPhoneFree(phone, user.id);
    return this.auth.requestOtp(phone);
  }

  /** POST /api/me/phone/verify — consume the OTP, then switch the phone (audited). */
  @Post("phone/verify")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Verify the OTP and change the phone number (signed in)" })
  async verifyPhone(@Body() dto: MePhoneVerifyDto, @Req() req: AuthedRequest) {
    const user = this.guard.requireUser(currentUser(req));
    const phone = normalizePhone(dto.phone);
    await this.assertPhoneFree(phone, user.id);
    await this.auth.consumeOtpCode(phone, dto.code);
    const updated = await this.rls.run(user, (tx) =>
      tx.user.update({ where: { id: user.id }, data: { phone } })
    );
    await this.guard.audit(user.id, "change_phone", "user", user.id, {
      from: user.phone ? `…${user.phone.slice(-3)}` : null,
      to: `…${phone.slice(-3)}`,
    });
    return { user: toDomainUser(updated as never) };
  }

  private async assertPhoneFree(phone: string, selfId: string) {
    const taken = await this.rls.system((tx) =>
      tx.user.findFirst({ where: { phone, NOT: { id: selfId } }, select: { id: true } })
    );
    if (taken) throw new ApiError(409, "এই নম্বরটি অন্য একটি অ্যাকাউন্টে যুক্ত");
  }
}

/** Same normalisation as sign-in (digits and a leading +). */
function normalizePhone(raw: string): string {
  const p = (raw ?? "").replace(/[^\d+]/g, "");
  if (!/^\+?\d{10,15}$/.test(p)) throw new ApiError(400, "সঠিক মোবাইল নম্বর দিন");
  return p;
}
