import { type LoggerService as NestLoggerService, Injectable, LogLevel } from "@nestjs/common";

/**
 * Structured JSON logger — one line per event, no PII (phones/codes/tokens are
 * never logged; caller-visible ids are masked to a short prefix).
 *
 * Registered as an app provider (AppModule) and wired with
 * `app.useLogger(app.get(StructuredLogger))` in main.ts / worker.ts, so every
 * Nest log line ships as `{"ts","level","ctx","msg",…}` JSON. [Phase C/W2h]
 */
@Injectable()
export class StructuredLogger implements NestLoggerService {
  constructor(private readonly levels: LogLevel[] = ["log", "error", "warn", "debug", "verbose"]) {}

  private static write(level: string, context: string, message: string, meta?: Record<string, unknown>) {
    const line = {
      ts: new Date().toISOString(),
      level,
      ctx: context,
      msg: message,
      ...(meta ?? {}),
    };
    process.stdout.write(JSON.stringify(line) + "\n");
  }

  log(message: string, context?: string, meta?: Record<string, unknown>) {
    StructuredLogger.write("info", context ?? "app", message, meta);
  }
  error(message: string, context?: string, meta?: Record<string, unknown>) {
    StructuredLogger.write("error", context ?? "app", message, meta);
  }
  warn(message: string, context?: string, meta?: Record<string, unknown>) {
    StructuredLogger.write("warn", context ?? "app", message, meta);
  }
  debug(message: string, context?: string, meta?: Record<string, unknown>) {
    if (this.levels.includes("debug")) StructuredLogger.write("debug", context ?? "app", message, meta);
  }
  verbose(message: string, context?: string, meta?: Record<string, unknown>) {
    if (this.levels.includes("verbose")) StructuredLogger.write("verbose", context ?? "app", message, meta);
  }
  fatal(message: string, context?: string, meta?: Record<string, unknown>) {
    StructuredLogger.write("fatal", context ?? "app", message, meta);
  }

  /** Mask an id for logs (no full cuid — still correlatable). */
  static mask(id: string | null | undefined): string {
    if (!id) return "-";
    return id.slice(0, 6);
  }
}
