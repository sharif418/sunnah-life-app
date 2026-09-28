import { type ArgumentsHost, Catch, type ExceptionFilter, HttpException, HttpStatus, Logger } from "@nestjs/common";
import type { Response } from "express";

/**
 * Error envelope identical to the web mirror: `{ "error": "messageBn" }`
 * with the proper status code. Unexpected errors log server-side and return
 * the generic Bengali 500 (no internals leaked).
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    // Socket.io gateway errors: there is no HTTP response object to write —
    // log (the gateway already emitted a Bengali quiz:error to the socket).
    if (host.getType() === "ws") {
      this.logger.warn(
        `ws error: ${exception instanceof Error ? exception.message : String(exception)}`,
      );
      return;
    }
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();
      let message = "সার্ভারে সমস্যা হয়েছে";
      if (typeof body === "string") {
        message = body;
      } else if (body && typeof body === "object" && "error" in (body as Record<string, unknown>)) {
        message = String((body as Record<string, unknown>).error);
      } else if (body && typeof body === "object" && "message" in (body as Record<string, unknown>)) {
        const m = (body as Record<string, unknown>).message;
        message = Array.isArray(m) ? String(m[0]) : String(m);
      }
      res.status(status).json({ error: message });
      return;
    }

    this.logger.error(
      exception instanceof Error ? exception.message : String(exception),
      exception instanceof Error ? exception.stack : undefined
    );
    res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({ error: "সার্ভারে সমস্যা হয়েছে" });
  }
}
