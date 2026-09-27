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

  @ApiProperty({ required: false, enum: ["general", "hafez", "alim"] })
  @IsOptional()
  @IsIn(["general", "hafez", "alim"], { message: "ক্যাটাগরি ঠিক নয়" })
  category?: string;
}

const ALLOWED_FIELDS = [
  "name", "language", "madhhab", "calcMethod", "lat", "lng", "city",
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

  /** PATCH /api/me — allowlisted profile fields only. */
  @Patch()
  @ApiOperation({ summary: "Update own profile (allowlisted fields)" })
  async updateMe(@Body() dto: MePatchDto, @Req() req: AuthedRequest, @Res({ passthrough: true }) res: Response) {
    const user = this.guard.requireUser(currentUser(req));
    const body = dto as unknown as Record<string, unknown>;
    const data: Record<string, unknown> = {};
    for (const f of ALLOWED_FIELDS) {
      if (body[f] !== undefined) data[f] = body[f];
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
