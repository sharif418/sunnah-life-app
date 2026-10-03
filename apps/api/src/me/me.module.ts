import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { MeController } from "./me.controller";

// AuthModule: the OTP machinery the phone change reuses (requestOtp /
// consumeOtpCode — the same throttle + hashing as sign-in).
@Module({ imports: [AuthModule], controllers: [MeController] })
export class MeModule {}
