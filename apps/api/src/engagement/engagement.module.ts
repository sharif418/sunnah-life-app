import { Module } from "@nestjs/common";
import {
  EnrollController,
  FeedbackController,
  MasalaController,
  QuizAttemptController,
  RemindersController,
  EngagementService,
} from "./engagement.controllers";
import {
  CoursesController,
  CoursesService,
  EnrollmentsController,
  EngagementHistoryService,
  QuizAttemptsController,
  QuizLiveController,
  QuizLiveService,
  UsrahQuestionsController,
  UsrahQuestionsService,
} from "./ilm.controllers";

@Module({
  controllers: [
    MasalaController,
    FeedbackController,
    EnrollController,
    QuizAttemptController,
    RemindersController,
    // Task B4 — ilm content + quiz engine
    CoursesController,
    EnrollmentsController,
    QuizAttemptsController,
    UsrahQuestionsController,
    QuizLiveController,
  ],
  providers: [
    EngagementService,
    CoursesService,
    EngagementHistoryService,
    UsrahQuestionsService,
    QuizLiveService,
  ],
})
export class EngagementModule {}
