import { Module } from "@nestjs/common";
import { ContentController, ContentService, MeiliIndexer } from "./content.controller";

@Module({
  controllers: [ContentController],
  providers: [ContentService, MeiliIndexer],
})
export class ContentModule {}
