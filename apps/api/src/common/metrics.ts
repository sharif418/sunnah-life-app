import { type CallHandler, type ExecutionContext, Injectable, type NestInterceptor } from "@nestjs/common";
import { type Observable, tap } from "rxjs";
import { Registry, Histogram } from "prom-client";

export const metricsRegistry = new Registry();

export const httpRequestDuration = new Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status"] as const,
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [metricsRegistry],
});

@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const start = process.hrtime.bigint();
    return next.handle().pipe(
      tap({
        next: () => this.observe(_context, start),
        error: () => this.observe(_context, start),
      })
    );
  }

  private observe(context: ExecutionContext, start: bigint) {
    try {
      const http = context.switchToHttp();
      const req = http.getRequest<{ method?: string; route?: { path?: string } }>();
      const res = http.getResponse<{ statusCode?: number }>();
      const route = req.route?.path ?? "unknown";
      const labels = { method: req.method ?? "?", route, status: String(res.statusCode ?? 0) };
      const seconds = Number(process.hrtime.bigint() - start) / 1e9;
      httpRequestDuration.observe(labels, seconds);
    } catch {
      // metrics must never break a request
    }
  }
}
