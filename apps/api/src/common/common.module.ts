import { Global, Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { PrismaService } from "./prisma.service";
import { RlsService } from "./rls.service";
import { GuardService } from "./guard.service";

/**
 * Global infrastructure module — Prisma (RLS-constrained `sunnah_app`
 * connection), the RLS execution-context wrapper, the application-layer
 * gender/scope guard and the JWT module every feature module shares.
 */
@Global()
@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET ?? "dev-only-secret-change-me-in-production",
      signOptions: { expiresIn: `${Number(process.env.ACCESS_TOKEN_TTL_MIN || 15)}m` },
    }),
  ],
  providers: [PrismaService, RlsService, GuardService],
  exports: [PrismaService, RlsService, GuardService, JwtModule],
})
export class CommonModule {}
