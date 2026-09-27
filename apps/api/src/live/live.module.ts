import { Module } from "@nestjs/common";
import { LiveController, LiveService } from "./live.controller";

@Module({ controllers: [LiveController], providers: [LiveService] })
export class LiveModule {}
