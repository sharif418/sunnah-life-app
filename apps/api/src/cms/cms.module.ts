import { Module } from "@nestjs/common";
import { CmsController, CmsService } from "./cms.controller";

/** Content workflow: drafts → scholar review → publish, versions, rollback. */
@Module({ controllers: [CmsController], providers: [CmsService], exports: [CmsService] })
export class CmsModule {}
