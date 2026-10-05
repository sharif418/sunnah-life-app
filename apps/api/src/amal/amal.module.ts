import { Module } from "@nestjs/common";
import { PushModule } from "../push/push.module";
import { AmalController } from "./amal.controller";
import { AmalService } from "./amal.service";
import { GoalsController, GoalsService, UsrahGoalsController } from "./goals.controller";

@Module({
  imports: [PushModule], // unlock requests reach the head as a push
  controllers: [AmalController, GoalsController, UsrahGoalsController],
  providers: [AmalService, GoalsService],
  exports: [AmalService],
})
export class AmalModule {}
