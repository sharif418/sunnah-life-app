import { Module } from "@nestjs/common";
import { ConfigApiController } from "./config.controller";

@Module({ controllers: [ConfigApiController] })
export class ConfigApiModule {}
