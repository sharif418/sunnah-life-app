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
  ValidateNested,
} from "class-validator";
import { Type } from "class-transformer";
import type { AmalValue } from "../../shared/domain";

const phoneMsg = "সঠিক মোবাইল নম্বর দিন";
const codeMsg = "নম্বর ও কোড দিন";

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
  value!: AmalValue;

  @ApiProperty({ example: "2025-06-15T10:00:00.000Z" })
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
