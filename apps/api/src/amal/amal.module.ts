import { Module } from "@nestjs/common";
import { AmalController } from "./amal.controller";
import { AmalService } from "./amal.service";
import { GoalsController, GoalsService, UsrahGoalsController } from "./goals.controller";

@Module({
  controllers: [AmalController, GoalsController, UsrahGoalsController],
  providers: [AmalService, GoalsService],
  exports: [AmalService],
})
export class AmalModule {}
