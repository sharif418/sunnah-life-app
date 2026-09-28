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
import { QuizGateway } from "./quiz.gateway";

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
    // Task B9 — live quiz socket.io gateway (folded into the API process)
    QuizGateway,
  ],
})
export class EngagementModule {}
