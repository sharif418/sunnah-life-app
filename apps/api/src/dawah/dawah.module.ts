import { Module } from "@nestjs/common";
import { DawahController, DawahService } from "./dawah.controller";
import { LevelsModule } from "../levels/levels.module";

@Module({
  controllers: [DawahController],
  providers: [DawahService],
  imports: [LevelsModule], // B6: live requirements checklist shares the evaluation engine
})
export class DawahModule {}
