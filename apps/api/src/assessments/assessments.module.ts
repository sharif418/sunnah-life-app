import { Module } from "@nestjs/common";
import { AssessmentsController, AssessmentsService } from "./assessments.controller";

@Module({ controllers: [AssessmentsController], providers: [AssessmentsService] })
export class AssessmentsModule {}
