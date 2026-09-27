import { Module } from "@nestjs/common";
import { UsrahController, UsrahService } from "./usrah.controller";

@Module({ controllers: [UsrahController], providers: [UsrahService] })
export class UsrahModule {}
