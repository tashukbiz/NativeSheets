import type { MetadataRoute } from "next";
import { siteConfig } from "@/site/config";

export const dynamic = "force-static";

/**
 * A preview build is kept out of search entirely; the production origin is open
 * to crawlers, with no blanket rule for AI crawlers because search discovery and
 * training crawlers are separate decisions that have not been made here.
 */
export default function robots(): MetadataRoute.Robots {
  if (!siteConfig.isProductionOrigin) {
    return { rules: [{ userAgent: "*", disallow: "/" }] };
  }
  return {
    rules: [{ userAgent: "*", allow: "/" }],
    sitemap: `${siteConfig.origin}${siteConfig.basePath}/sitemap.xml`,
    host: siteConfig.origin,
  };
}
