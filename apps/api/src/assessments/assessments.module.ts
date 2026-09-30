import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { AssessmentsController, AssessmentsService } from "./assessments.controller";

// AuthModule supplies the OTP machinery the W4i acknowledgment reuses
// (requestOtp / consumeOtpCode — the same throttle + hashing as sign-in).
@Module({
  imports: [AuthModule],
  controllers: [AssessmentsController],
  providers: [AssessmentsService],
})
export class AssessmentsModule {}
