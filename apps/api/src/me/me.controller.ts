import { Res, Req, Body, Controller, Get, Patch } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import type { Response } from "express";
import { IsIn, IsLatitude, IsLongitude, IsOptional, IsString, MaxLength } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { toDomainUser } from "../common/mappers";
import { ApiError } from "../common/api-error";

/** Gender is locked once set: a user whose account was created WITHOUT one
 *  (social sign-in — gender "unspecified") sets it exactly once here, as the
 *  completion of the onboarding step. Any later change is rejected. */
const GENDER_LOCKED_ERR = "লিঙ্গ পরিবর্তন করা যায় না";

export class MePatchDto {
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
  "name", "gender", "language", "madhhab", "calcMethod", "lat", "lng", "city",
  "district", "workplace", "department", "category",
] as const;

@ApiTags("me")
@Controller("me")
export class MeController {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
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
    if (Object.keys(data).length === 0) {
      throw new ApiError(400, "কিছু পরিবর্তন দেওয়া হয়নি");
    }
    const updated = await this.rls.run(user, (tx) =>
      tx.user.update({ where: { id: user.id }, data: data as never })
    );
    void res;
    return { user: toDomainUser(updated as never) };
  }
}
