import { Module } from "@nestjs/common";
import { LevelsService } from "./levels.service";

/**
 * Levels engine (B6). LevelsService itself is provider-scoped (no controller
 * here): the dawah controller serves the member checklist, the admin
 * controller serves promote + transitions history, and the worker's
 * levels.processor drives the nightly auto-promotion.
 */
@Module({ providers: [LevelsService], exports: [LevelsService] })
export class LevelsModule {}
