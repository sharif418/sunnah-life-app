// Push module (Task B2): FCM HTTP v1 transport (or the no-op dev adapter),
// the PushService fan-out door, and the /api/push/token registration route.
//
// Imported by AppModule (controller + registration) AND by the worker
// processors (weekly-reviews / prayer-push deliver through PushService).
import { Module } from "@nestjs/common";
import { PushController } from "./push.controller";
import { PushService } from "./push.service";
import { DeviceTokensService } from "./device-tokens.service";

@Module({
  controllers: [PushController],
  providers: [PushService, DeviceTokensService],
  exports: [PushService, DeviceTokensService],
})
export class PushModule {}
