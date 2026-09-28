import { Module } from "@nestjs/common";
import { AmalController } from "./amal.controller";
import { AmalService } from "./amal.service";
import { GoalsController } from "./goals.controller";

@Module({
  controllers: [AmalController, GoalsController],
  providers: [AmalService],
  exports: [AmalService],
})
export class AmalModule {}
