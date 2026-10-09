import { Controller, Get, Query } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";

import { MosquesService } from "./mosques.service";

@ApiTags("content")
@Controller("mosques")
export class MosquesController {
  constructor(private readonly mosques: MosquesService) {}

  @Get("near")
  @ApiOperation({
    summary:
      "Mosques within 5 km of a point — OpenStreetMap + the Foundation's verified list (public; the point is not stored)",
  })
  near(@Query("lat") lat: string, @Query("lng") lng: string) {
    return this.mosques.near(lat, lng);
  }
}
