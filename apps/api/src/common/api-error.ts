// ApiError — the Bengali-first error envelope used across the web mirror:
// { "error": "messageBn" } with a proper HTTP status.
import { HttpException } from "@nestjs/common";

export class ApiError extends HttpException {
  constructor(
    status: number,
    message: string
  ) {
    super({ error: message }, status);
  }
}
