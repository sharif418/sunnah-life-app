import { Module } from "@nestjs/common";
import { PushModule } from "../push/push.module";
import { AdminController, AdminService } from "./admin.controller";

@Module({
  imports: [PushModule], // broadcast fans out through PushService (B2)
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
