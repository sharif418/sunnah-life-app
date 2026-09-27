import { Module } from "@nestjs/common";
import { RlsRawTestController } from "./rls-raw.controller";

@Module({ controllers: [RlsRawTestController] })
export class TestRlsModule {}
