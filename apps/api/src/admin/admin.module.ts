import { Module } from "@nestjs/common";
import { PushModule } from "../push/push.module";
import { LevelsModule } from "../levels/levels.module";
import { AdminController, AdminService } from "./admin.controller";

@Module({
  imports: [PushModule, LevelsModule], // PushModule: broadcast/promote fan-out (B2); LevelsModule: promote + transitions (B6)
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
