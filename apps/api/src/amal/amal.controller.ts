import { Req, Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { IsDateString, IsOptional, IsString, Matches } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";
import { AmalService } from "./amal.service";
import { AmalEntriesSyncDto, UnlockDto } from "../auth/dto/auth.dto";
import { AuthedRequest, currentUser } from "../common/auth.guard";

export class EntriesQueryDto {
  @ApiProperty({ example: "2025-06-01" })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: "তারিখের পরিসর (from ও to) ঠিকভাবে দিন" })
  from!: string;

  @ApiProperty({ example: "2025-06-15" })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: "তারিখের পরিসর (from ও to) ঠিকভাবে দিন" })
  to!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  userId?: string;
}

export class SurahNumberParamDto {
  @Matches(/^[0-9]+$/, { message: "সূরা নম্বর সঠিক নয়" })
  number!: string;
}

export class MonthQueryDto {
  @IsDateString()
  month!: string;
}

@ApiTags("amal")
@Controller("amal")
export class AmalController {
  constructor(private readonly amal: AmalService) {}

  /** GET /api/amal/definitions — public (guests keep a local diary too). */
  @Get("definitions")
  @ApiOperation({ summary: "Active amal catalog (public)" })
  definitions() {
    return this.amal.definitions();
  }

  /** GET /api/amal/entries?from&to[&userId] — diary range (guard-scoped). */
  @Get("entries")
  @ApiOperation({ summary: "Amal diary entries for a date range" })
  entries(@Query() q: EntriesQueryDto, @Req() req: AuthedRequest) {
    return this.amal.entries(currentUser(req), q.from, q.to, q.userId);
  }

  /**
   * POST /api/amal/entries — batch sync (offline-first). Returns HTTP 200 with
   * per-entry {accepted, rejected} outcomes.
   */
  @Post("entries")
  @ApiOperation({ summary: "Batch sync amal entries (locking + conflict rules)" })
  upsert(@Body() dto: AmalEntriesSyncDto, @Req() req: AuthedRequest) {
    return this.amal.upsertEntries(currentUser(req), dto.entries as never);
  }

  /** POST /api/amal/unlock — usrah_head+ unlocks a locked day (audited). */
  @Post("unlock")
  @ApiOperation({ summary: "Unlock a locked diary day (usrah_head+)" })
  unlock(@Body() dto: UnlockDto, @Req() req: AuthedRequest) {
    return this.amal.unlock(currentUser(req), dto.userId, dto.date, dto.reason);
  }
}
