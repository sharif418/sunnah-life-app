import { join } from "path";
import { config as loadDotenv } from "dotenv";
import { Module } from "@nestjs/common";
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from "@nestjs/core";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { validateEnv } from "./config/env.validation";
import { CommonModule } from "./common/common.module";
import { JwtAuthGuard } from "./common/auth.guard";
import { AllExceptionsFilter } from "./common/all-exceptions.filter";
import { MetricsInterceptor } from "./common/metrics";
import { QueueModule } from "./queues/queue.module";

// ─────────────────────────────────────────────────────────────────────────────
// The API's own .env is AUTHORITATIVE for this process. dotenv's default is to
// keep pre-existing shell vars, which breaks the sandbox (the web-app shell
// exports DATABASE_URL=file:… — Prisma then rejects it at $connect). Loading
// with override BEFORE any Prisma client is instantiated fixes both the dev
// server and the jest suite (both import AppModule). In CI/Docker the file is
// absent → this is a no-op and the real environment wins.
// ─────────────────────────────────────────────────────────────────────────────
loadDotenv({ path: join(__dirname, "../.env"), override: true, quiet: true });

import { AuthModule } from "./auth/auth.module";
import { HealthModule } from "./health/health.module";
import { ConfigApiModule } from "./config/config.module";
import { ContentModule } from "./content/content.module";
import { AmalModule } from "./amal/amal.module";
import { DawahModule } from "./dawah/dawah.module";
import { UsrahModule } from "./usrah/usrah.module";
import { ReviewsModule } from "./reviews/reviews.module";
import { AssessmentsModule } from "./assessments/assessments.module";
import { AdminModule } from "./admin/admin.module";
import { EngagementModule } from "./engagement/engagement.module";
import { JoinModule } from "./join/join.module";
import { LiveModule } from "./live/live.module";
import { MeModule } from "./me/me.module";
import { TestRlsModule } from "./test-rls/test-rls.module";

/**
 * Sunnah Life API — NestJS modular monolith.
 *
 * Request pipeline:
 *   JwtAuthGuard (optional auth: Bearer header / sl_access cookie → req.user)
 *   → controller → service (GuardService.assertCanAccess + RlsService.run)
 *   → PostgreSQL Row-Level Security as the final safety net.
 *
 * The BullMQ queue module only REGISTERS queues + repeatable job schedulers;
 * the processors run in the separate apps/worker process.
 */
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnv,
      // .env is loaded by Nest; prisma seed reads DIRECT_URL itself.
    }),
    CommonModule, // @Global: Prisma + RLS + Guard + Jwt
    QueueModule, // BullMQ queues + schedulers (Redis)
    AuthModule,
    HealthModule,
    ConfigApiModule,
    ContentModule,
    AmalModule,
    DawahModule,
    UsrahModule,
    ReviewsModule,
    AssessmentsModule,
    AdminModule,
    EngagementModule,
    JoinModule,
    LiveModule,
    MeModule,
    TestRlsModule, // test-only RLS probe (header-gated, non-production)
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_INTERCEPTOR, useClass: MetricsInterceptor },
    ConfigService,
  ],
})
export class AppModule {}
