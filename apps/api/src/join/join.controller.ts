import { Controller, Get, Query } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { IsNotEmpty, IsString } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";
import { RlsService } from "../common/rls.service";
import { ApiError } from "../common/api-error";
import type { Level } from "../shared/domain";

export class JoinQueryDto {
  @ApiProperty({ example: "DS-000123" })
  @IsString({ message: "কোড দেওয়া হয়নি" })
  @IsNotEmpty({ message: "কোড দেওয়া হয়নি" })
  code!: string;
}

/** Referral landing: /?join=DS-000123 → public minimal info about the inviter. */
@ApiTags("join")
@Controller("join")
export class JoinController {
  constructor(private readonly rls: RlsService) {}

  @Get()
  @ApiOperation({ summary: "Referral landing info (?code=DS-XXXXXX)" })
  async join(@Query() query: JoinQueryDto) {
    const code = query.code;
    // memberCode lookup is public (name + level only) — system bootstrap context.
    const inviter = await this.rls.system((tx) =>
      tx.user.findUnique({ where: { memberCode: code.toUpperCase() }, select: { name: true, level: true } })
    );
    if (!inviter) throw new ApiError(404, "কোডটি সঠিক নয়");
    return { inviterName: inviter.name, inviterLevel: inviter.level as Level };
  }
}
