import { ApiProperty } from "@nestjs/swagger";
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  Validate,
  ValidateNested,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from "class-validator";
import { Type } from "class-transformer";
import type { AmalValue } from "../../shared/domain";

const phoneMsg = "সঠিক মোবাইল নম্বর দিন";
const codeMsg = "নম্বর ও কোড দিন";

/**
 * Guest-entry value shape (Phase C/W2g): boolean | finite number | non-empty
 * string ≤ 100 chars. A custom constraint — the union type can't be expressed
 * with stock decorators, and WITHOUT any class-validator decorator the global
 * whitelist pipe STRIPS the field (the W2g strip-bug: guest merges silently
 * lost every entry in production). Type-tolerant on purpose: the amal value
 * semantics (tri-state / count / boolean) are re-validated per definition in
 * src/shared/conflict.ts decideEntry + the guest merge in AuthService.
 */
@ValidatorConstraint({ name: "isValidAmalValue", async: false })
export class IsValidAmalValue implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    if (typeof value === "boolean") return true;
    if (typeof value === "number") return Number.isFinite(value);
    if (typeof value === "string") return value.length > 0 && value.length <= 100;
    return false;
  }

  defaultMessage(): string {
    return "মান ঠিক নয়";
  }
}

export class OtpRequestDto {
  @ApiProperty({ example: "01000000004" })
  @IsString({ message: phoneMsg })
  phone!: string;
}

export class GuestEntryDto {
  @ApiProperty()
  @IsString({ message: "অসম্পূর্ণ এন্ট্রি" })
  amalKey!: string;

  @ApiProperty({ example: "2025-06-15" })
  @IsString({ message: "অসম্পূর্ণ এন্ট্রি" })
  date!: string;

  @ApiProperty({ example: "jamaat" })
  @Validate(IsValidAmalValue, { message: "মান ঠিক নয়" })
  value!: AmalValue;

  @ApiProperty({ example: "2025-06-15T10:00:00.000Z" })
  @IsString({ message: "সময় প্রয়োজন" })
  clientUpdatedAt!: string;

  @ApiProperty({ required: false, example: "manual" })
  @IsOptional()
  @IsString()
  source?: string;
}

export class OtpVerifyDto {
  @ApiProperty({ example: "01000000004" })
  @IsString({ message: phoneMsg })
  phone!: string;

  @ApiProperty({ example: "123456" })
  @IsString({ message: codeMsg })
  @MinLength(4, { message: codeMsg })
  code!: string;

  @ApiProperty({ required: false, example: "রাফিউল ইসলাম" })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiProperty({ required: false, enum: ["M", "F"] })
  @IsOptional()
  @IsIn(["M", "F"], { message: "লিঙ্গ ঠিক নয়" })
  gender?: "M" | "F";

  @ApiProperty({ required: false, example: "DS-000004" })
  @IsOptional()
  @IsString()
  referredByCode?: string;

  @ApiProperty({ required: false, type: [GuestEntryDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500, { message: "একবারে সর্বোচ্চ ৫০০টি এন্ট্রি পাঠানো যায়" })
  @ValidateNested({ each: true })
  @Type(() => GuestEntryDto)
  guestEntries?: GuestEntryDto[];
}

export class RefreshDto {
  // Optional: cookie-based clients (web PWA) rely on the HttpOnly sl_refresh
  // cookie instead of echoing the token back in the body.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString({ message: "রিফ্রেশ টোকেন দিন" })
  refreshToken?: string;
}

/** POST /api/auth/social (Task B5) — Google/Apple id_token sign-in. */
export class SocialSignInDto {
  @ApiProperty({ example: "google", enum: ["google", "apple"] })
  @IsIn(["google", "apple"], { message: "সঠিক সাইন-ইন পদ্ধতি দিন" })
  provider!: "google" | "apple";

  @ApiProperty({ description: "Provider id_token (JWT)" })
  @IsString({ message: "সাইন-ইন টোকেন দিন" })
  @MinLength(10, { message: "সাইন-ইন টোকেন দিন" })
  idToken!: string;

  @ApiProperty({ required: false, example: "রাফিউল ইসলাম" })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiProperty({
    required: false,
    enum: ["M", "F"],
    description:
      "Only applied at ACCOUNT CREATION (onboarding gender). Ignored for existing accounts — gender is locked afterwards.",
  })
  @IsOptional()
  @IsIn(["M", "F"], { message: "লিঙ্গ ঠিক নয়" })
  gender?: "M" | "F";

  @ApiProperty({ required: false, example: "DS-000004" })
  @IsOptional()
  @IsString()
  referredByCode?: string;

  @ApiProperty({ required: false, type: [GuestEntryDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500, { message: "একবারে সর্বোচ্চ ৫০০টি এন্ট্রি পাঠানো যায়" })
  @ValidateNested({ each: true })
  @Type(() => GuestEntryDto)
  guestEntries?: GuestEntryDto[];
}

export class LogoutDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  refreshToken?: string;
}

export class AmalEntriesSyncDto {
  @ApiProperty({ type: [Object], isArray: true })
  @IsArray()
  @ArrayMinSize(1, { message: "কোনো এন্ট্রি পাওয়া যায়নি" })
  @ArrayMaxSize(500, { message: "একবারে সর্বোচ্চ ৫০০টি এন্ট্রি পাঠানো যায়" })
  entries!: Record<string, unknown>[];
}

export class UnlockDto {
  @ApiProperty()
  @IsString({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  userId!: string;

  @ApiProperty({ example: "2025-06-10" })
  @IsString({ message: "তারিখ ঠিকভাবে দিন (YYYY-MM-DD)" })
  date!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class ReviewSubmitDto {
  @ApiProperty()
  @IsString({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  userId!: string;

  @ApiProperty({ example: "2025-06-14" })
  @IsString({ message: "সপ্তাহের তারিখ ঠিকভাবে দিন (YYYY-MM-DD)" })
  weekStart!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  comment?: string;

  @ApiProperty({ minimum: 1, maximum: 5 })
  @IsInt({ message: "রেটিং ১ থেকে ৫ এর মধ্যে হতে হবে" })
  rating!: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  nextGoals?: string;
}

export class ScoreItemDto {
  @ApiProperty({ minimum: 0, maximum: 2 })
  @IsInt()
  score!: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  comment?: string;
}

export class AssessmentSubmitDto {
  @ApiProperty()
  @IsString({ message: "মূল্যায়নার্থী নির্বাচন করা হয়নি" })
  assesseeId!: string;

  @ApiProperty({ example: "farze_ain_v1" })
  @IsString({ message: "টেমপ্লেট নির্বাচন করা হয়নি" })
  templateKey!: string;

  @ApiProperty({ required: false, enum: [1, 2] })
  @IsOptional()
  @IsInt()
  participantCategory?: number;

  @ApiProperty({ type: Object })
  @IsObject({ message: "স্কোর দেওয়া হয়নি" })
  scores!: Record<string, ScoreItemDto>;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  overallComment?: string;
}
