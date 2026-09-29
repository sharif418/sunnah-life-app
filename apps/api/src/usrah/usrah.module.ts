import { Module } from "@nestjs/common";
import { UsrahController, UsrahService } from "./usrah.controller";
import {
  JoinRequestAdminController,
  JoinRequestController,
  JoinRequestService,
} from "./join-request.controller";

@Module({
  controllers: [UsrahController, JoinRequestController, JoinRequestAdminController],
  providers: [UsrahService, JoinRequestService],
})
export class UsrahModule {}
