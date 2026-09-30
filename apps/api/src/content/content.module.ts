import { Module } from "@nestjs/common";
import { ContentController, ContentService, MeiliIndexer } from "./content.controller";
import { SearchService } from "./search.service";

@Module({
  controllers: [ContentController],
  providers: [ContentService, MeiliIndexer, SearchService],
})
export class ContentModule {}
