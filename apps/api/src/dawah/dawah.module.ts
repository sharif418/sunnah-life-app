import { Module } from "@nestjs/common";
import { DawahController, DawahService } from "./dawah.controller";

@Module({ controllers: [DawahController], providers: [DawahService] })
export class DawahModule {}
