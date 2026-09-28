import type { NextConfig } from "next";
import path from "path";

const nextConfig: NextConfig = {
  output: "standalone",
  // Content packs + shared types live OUTSIDE apps/web (monorepo root), so
  // standalone output tracing must start at the repo root or the JSON packs
  // would be missing from the production bundle.
  outputFileTracingRoot: path.join(__dirname, "../../"),
  typescript: {
    ignoreBuildErrors: true,
  },
  reactStrictMode: false,
  // Content packs live in packages/content (monorepo, outside apps/web) —
  // webpack must be allowed to import outside the project root.
  experimental: { externalDir: true },
  allowedDevOrigins: ["*.space-z.ai", "*.z.ai", "localhost", "127.0.0.1"],
};

export default nextConfig;
