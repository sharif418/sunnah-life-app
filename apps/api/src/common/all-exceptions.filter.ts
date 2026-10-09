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
      const b = body && typeof body === "object" ? (body as Record<string, unknown>) : null;
      if (typeof body === "string") {
        message = body;
      } else if (b && "statusCode" in b && "message" in b) {
        // Nest's own errors (ValidationPipe…): {statusCode, message, error:
        // "Bad Request"} — the MESSAGE is the useful (Bengali) part; "error"
        // is only the HTTP reason phrase members used to see
        const m = b.message;
        message = Array.isArray(m) ? String(m[0]) : String(m);
      } else if (b && "error" in b) {
        message = String(b.error); // ApiError: {error: "<Bengali message>"}
      } else if (b && "message" in b) {
        const m = b.message;
        message = Array.isArray(m) ? String(m[0]) : String(m);
      }
      // a validation report rides along (the content CMS lists every issue
      // next to its item)
      const issues = b && Array.isArray(b.issues) ? b.issues : undefined;
      res.status(status).json(issues ? { error: message, issues } : { error: message });
      return;
    }

    // the body parser's own refusals (too large, malformed JSON) carry their
    // 4xx — say so instead of a server error
    const parserErr = exception as { status?: unknown; type?: unknown; expose?: unknown } | null;
    if (
      parserErr &&
      parserErr.expose === true &&
      typeof parserErr.status === "number" &&
      parserErr.status >= 400 &&
      parserErr.status < 500
    ) {
      const message = parserErr.type === "entity.too.large" ? "পাঠানো তথ্য খুব বড়" : "পাঠানো তথ্য পড়া যায়নি";
      res.status(parserErr.status).json({ error: message });
      return;
    }

    this.logger.error(
      exception instanceof Error ? exception.message : String(exception),
      exception instanceof Error ? exception.stack : undefined
    );
    res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({ error: "সার্ভারে সমস্যা হয়েছে" });
  }
}
