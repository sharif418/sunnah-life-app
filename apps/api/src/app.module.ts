import { join } from "path";
import { config as loadDotenv } from "dotenv";
import { Module } from "@nestjs/common";
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from "@nestjs/core";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { ThrottlerModule } from "@nestjs/throttler";
import { validateEnv } from "./config/env.validation";
import { CommonModule } from "./common/common.module";
import { StorageModule } from "./storage/storage.module";
import { JwtAuthGuard } from "./common/auth.guard";
import { AllExceptionsFilter } from "./common/all-exceptions.filter";
import { MetricsInterceptor } from "./common/metrics";
import { QueueModule } from "./queues/queue.module";
import { AuthThrottlerGuard } from "./common/auth-throttler.guard";

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
import { ReportsModule } from "./reports/reports.module";
import { EngagementModule } from "./engagement/engagement.module";
import { PushModule } from "./push/push.module";
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
    ThrottlerModule.forRoot([
      // per-IP general limit — generous for a phone app user, hard for a flood
      { name: "ip", ttl: 60_000, limit: Number(process.env.THROTTLE_IP_PER_MIN || 600) },
      // per-phone OTP request limit (attempts, not just stored codes).
      // Test/CI raise this via env: the jest suites share one Redis across
      // 13 spec files, each signing in the same demo phones.
      { name: "otp-phone", ttl: 600_000, limit: Number(process.env.THROTTLE_OTP_PER_10MIN || 5) },
    ]),
    CommonModule, // @Global: Prisma + RLS + Guard + Jwt
    StorageModule, // @Global: S3/local object storage (monthly report PDFs)
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
    ReportsModule,
    EngagementModule,
    PushModule, // FCM push: token registration + PushService fan-out (B2)
    JoinModule,
    LiveModule,
    MeModule,
    TestRlsModule, // test-only RLS probe (header-gated, non-production)
  ],
  providers: [
    // AuthThrottlerGuard runs BEFORE JwtAuthGuard (guard order): unauthenticated
    // floods get 429 without touching auth at all. Per-phone on the OTP route,
    // per-IP everywhere else (Phase C/W2b).
    { provide: APP_GUARD, useClass: AuthThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_INTERCEPTOR, useClass: MetricsInterceptor },
    ConfigService,
  ],
})
export class AppModule {}
