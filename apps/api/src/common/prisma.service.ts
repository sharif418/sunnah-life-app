import { Injectable, type OnModuleDestroy, type OnModuleInit } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";

/**
 * Plain Prisma client. It connects as the RLS-constrained `sunnah_app` role
 * (DATABASE_URL). NEVER query user data through it directly in request
 * handlers — use RlsService.run(user, …) so the session GUCs are set.
 * Direct use is fine for RLS-exempt tables (AmalDefinition, OtpCode, …).
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
