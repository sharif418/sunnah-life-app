import { Module } from "@nestjs/common";
import {
  EnrollController,
  FeedbackController,
  MasalaController,
  QuizAttemptController,
  RemindersController,
  EngagementService,
} from "./engagement.controllers";

@Module({
  controllers: [
    MasalaController,
    FeedbackController,
    EnrollController,
    QuizAttemptController,
    RemindersController,
  ],
  providers: [EngagementService],
})
export class EngagementModule {}
