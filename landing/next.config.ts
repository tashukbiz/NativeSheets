import type { NextConfig } from "next";

/**
 * GitHub Pages serves a project site from a sub-path, so the base path has to be
 * baked in at build time. Leave NEXT_PUBLIC_BASE_PATH empty for a custom domain
 * or a user/organisation site.
 */
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  basePath,
  images: { unoptimized: true },
  // GitHub Pages does not serve _next-prefixed directories from Jekyll builds;
  // the .nojekyll file in public/ is what keeps them reachable.
  reactStrictMode: true,
};

export default nextConfig;
