import { Injectable, Logger } from "@nestjs/common";
import { promises as fs } from "fs";
import { dirname, join, normalize, resolve, sep } from "path";
import { Client } from "minio";

/**
 * Object storage with two interchangeable adapters behind one tiny surface:
 *
 *   put(key, buffer, contentType)  → writes the object (S3 putObject / local
 *                                    mkdir -p + writeFile, mirroring the key
 *                                    structure under STORAGE_DIR)
 *   get(key)                       → Buffer (S3 getObject / local readFile)
 *   signedUrl(key)                 → presigned GET URL on S3; null on local —
 *                                    local downloads stream through the
 *                                    authenticated API endpoint instead.
 *
 * The S3 adapter activates only when ALL of S3_ENDPOINT / S3_BUCKET /
 * S3_ACCESS_KEY / S3_SECRET_KEY are present (the same probe the health
 * check uses); otherwise the local-dir fallback keeps the sandbox and
 * single-box deployments fully functional. Prod wiring (MinIO or any
 * S3-compatible store) is documented in .env.example.
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  private readonly s3: Client | null = null;
  private readonly bucket = process.env.S3_BUCKET || "";
  private readonly dir = resolve(process.env.STORAGE_DIR || "./storage");

  constructor() {
    const endpoint = process.env.S3_ENDPOINT;
    const accessKey = process.env.S3_ACCESS_KEY;
    const secretKey = process.env.S3_SECRET_KEY;
    if (endpoint && this.bucket && accessKey && secretKey) {
      let url: URL;
      try {
        url = new URL(endpoint);
      } catch {
        this.logger.warn(`S3_ENDPOINT is not a URL — falling back to local storage: ${endpoint}`);
        return;
      }
      this.s3 = new Client({
        endPoint: url.hostname,
        port: url.port ? Number(url.port) : url.protocol === "https:" ? 443 : 80,
        useSSL: url.protocol === "https:",
        accessKey,
        secretKey,
      });
      this.logger.log(`Storage: S3 adapter → ${endpoint}/${this.bucket}`);
    } else {
      this.logger.log(`Storage: local adapter → ${this.dir}`);
    }
  }

  /** Write a binary object; local adapter mirrors the key under STORAGE_DIR. */
  async put(key: string, buffer: Buffer, contentType = "application/octet-stream"): Promise<void> {
    this.assertKey(key);
    if (this.s3) {
      await this.s3.putObject(this.bucket, key, buffer, buffer.length, { "Content-Type": contentType });
      return;
    }
    const file = this.localPath(key);
    await fs.mkdir(dirname(file), { recursive: true });
    await fs.writeFile(file, buffer);
  }

  /** Read a binary object back. Throws when the object does not exist. */
  async get(key: string): Promise<Buffer> {
    this.assertKey(key);
    if (this.s3) {
      const stream = await this.s3.getObject(this.bucket, key);
      const parts: Buffer[] = [];
      for await (const chunk of stream) {
        parts.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk as Uint8Array));
      }
      return Buffer.concat(parts);
    }
    return fs.readFile(this.localPath(key));
  }

  /** Delete an object (a missing one is not an error). */
  async remove(key: string): Promise<void> {
    this.assertKey(key);
    if (this.s3) {
      await this.s3.removeObject(this.bucket, key);
      return;
    }
    await fs.rm(this.localPath(key), { force: true });
  }

  /**
   * Presigned GET URL (S3/MinIO only, 1-hour TTL). Local adapter returns
   * null — callers stream local objects through their own authenticated
   * endpoint (e.g. GET /api/admin/reports/:id/download).
   */
  async signedUrl(key: string): Promise<string | null> {
    this.assertKey(key);
    if (!this.s3) return null;
    return this.s3.presignedGetObject(this.bucket, key, 3600);
  }

  // ── internals ───────────────────────────────────────────────────────────────

  /** Keys are app-generated; still refuse traversal-ish input. */
  private assertKey(key: string): void {
    if (!key || key.length > 512 || key.includes("..") || key.startsWith("/") || key.includes("\0")) {
      throw new Error("Invalid storage key");
    }
  }

  private localPath(key: string): string {
    const safe = normalize(key).split(sep).join("/").replace(/^\/+/, "");
    return join(this.dir, safe);
  }
}
