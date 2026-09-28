import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Standalone output for the Docker image (infra/admin.Dockerfile).
  output: "standalone",
  typescript: {
    // Strict: type errors must fail the build (CI runs `tsc --noEmit` too).
    ignoreBuildErrors: false,
  },
  reactStrictMode: false,
  allowedDevOrigins: ["localhost", "127.0.0.1"],
};

export default nextConfig;
