import { Req, Body, Controller, Get, Param, Post, Query, Res, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Matches, Max, Min } from "class-validator";
import type { Response } from "express";
import { ReportsService } from "./reports.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import { monthLabelBn } from "./report-data";

export class GenerateReportDto {
  @ApiProperty({ example: "ckv4…", description: "target member id" })
  @IsString({ message: "ব্যবহারকারী আইডি দিন" })
  @IsNotEmpty({ message: "ব্যবহারকারী আইডি দিন" })
  userId!: string;

  @ApiProperty({ example: "2026-09" })
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/, { message: "মাস ঠিকভাবে দিন (YYYY-MM)" })
  month!: string;
}

export class ListReportsQueryDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  userId?: string;

  @ApiProperty({ required: false, example: "2026-09" })
  @IsOptional()
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/, { message: "মাস ঠিকভাবে দিন (YYYY-MM)" })
  month?: string;

  @ApiProperty({ required: false, example: 100 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(500)
  take?: number;
}

export class ReportIdParamDto {
  @IsString({ message: "রিপোর্ট আইডি দিন" })
  @IsNotEmpty({ message: "রিপোর্ট আইডি দিন" })
  id!: string;
}

export class ReportStatusDto {
  @ApiProperty({ example: "ready" })
  @IsIn(["ready", "failed"], { message: "অবস্থা ঠিক নয়" })
  status!: string;
}

/**
 * Monthly Muhasaba PDF reports — admin surface.
 *
 *   POST /api/admin/reports/generate   full_admin — synchronous render+store
 *   GET  /api/admin/reports            usrah_head+ — RLS-scoped list
 *   GET  /api/admin/reports/:id/download  usrah_head+ — PDF stream
 *
 * The worker's monthly-report queue job renders the same ReportsService
 * pipeline on the 1st of each month for every active member.
 */
@ApiTags("admin")
@Controller("admin/reports")
@UseGuards(RolesGuard)
@Roles("usrah_head") // supervisor floor for the class; generate is full_admin only
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  /** POST /api/admin/reports/generate — synchronous render + store + row. */
  @Post("generate")
  @Roles("full_admin")
  @ApiOperation({ summary: "full_admin: render a member's monthly Muhasaba PDF now" })
  generate(@Body() dto: GenerateReportDto, @Req() req: AuthedRequest) {
    return this.reports.generate(currentUser(req), dto.userId, dto.month);
  }

  /** GET /api/admin/reports?userId&month&take — RLS-scoped report list. */
  @Get()
  @ApiOperation({ summary: "Monthly report list (scoped by RLS)" })
  list(@Query() q: ListReportsQueryDto, @Req() req: AuthedRequest) {
    return this.reports.list(currentUser(req), {
      userId: q.userId,
      month: q.month,
      take: q.take,
    });
  }

  /** GET /api/admin/reports/:id/download — streams the stored PDF. */
  @Get(":id/download")
  @ApiOperation({ summary: "Download a monthly report PDF" })
  async download(@Param() p: ReportIdParamDto, @Req() req: AuthedRequest, @Res() res: Response) {
    const { row, pdf } = await this.reports.download(currentUser(req), p.id);
    const code = row.memberCode ?? row.userId.slice(0, 8);
    const asciiName = `muhasaba-${code}-${row.month}.pdf`;
    const bnName = `মুহাসাবা-${row.userName ?? ""}-${monthLabelBn(row.month)}.pdf`;
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Length", String(pdf.length));
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="${asciiName}"; filename*=UTF-8''${encodeURIComponent(bnName)}`
    );
    res.end(pdf);
  }
}
