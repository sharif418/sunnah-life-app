import { Global, Module } from "@nestjs/common";
import { StorageService } from "./storage.service";

/**
 * Object storage for generated artifacts (monthly Muhasaba PDFs today).
 * Global so any module can inject StorageService without re-importing.
 *
 * Adapter selection (mirrors the health check's storage probe):
 *   S3  when S3_ENDPOINT + S3_BUCKET + S3_ACCESS_KEY + S3_SECRET_KEY are all
 *       set — MinIO (or any S3-compatible store) via the `minio` client;
 *       `signedUrl()` returns a presigned GET URL.
 *   local  otherwise — files under STORAGE_DIR (default ./storage), mirroring
 *       the object-key structure; `signedUrl()` returns null (downloads are
 *       streamed through the authenticated API instead — see the admin
 *       reports download endpoint).
 */
@Global()
@Module({
  providers: [StorageService],
  exports: [StorageService],
})
export class StorageModule {}
