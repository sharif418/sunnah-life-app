// POST/DELETE /api/push/token — device registration (auth required).
// The controller is a thin shell over DeviceTokensService (RLS-enforced).
import { Body, Controller, Delete, Post, Req } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { DeviceTokensService } from "./device-tokens.service";
import { RegisterPushTokenDto, UnregisterPushTokenDto } from "./dto/push.dto";

@ApiTags("push")
@Controller("push")
export class PushController {
  constructor(private readonly tokens: DeviceTokensService) {}

  /** POST /api/push/token — register/refresh the FCM token (auth required). */
  @Post("token")
  @ApiOperation({ summary: "Register device push token (auth)" })
  register(@Body() dto: RegisterPushTokenDto, @Req() req: AuthedRequest) {
    return this.tokens.register(currentUser(req), dto);
  }

  /** DELETE /api/push/token — unregister one device token. */
  @Delete("token")
  @ApiOperation({ summary: "Unregister device push token (auth)" })
  unregister(@Body() dto: UnregisterPushTokenDto, @Req() req: AuthedRequest) {
    return this.tokens.unregister(currentUser(req), dto.token);
  }
}
