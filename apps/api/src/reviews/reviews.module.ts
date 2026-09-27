import { Module } from "@nestjs/common";
import { ReviewsController, ReviewsService } from "./reviews.controller";

@Module({ controllers: [ReviewsController], providers: [ReviewsService] })
export class ReviewsModule {}
