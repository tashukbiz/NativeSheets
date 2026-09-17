import type { MetadataRoute } from "next";
import { publishedContent, routeOf, staticRoutes } from "@/site/content";
import { absoluteUrl } from "@/site/urls";

export const dynamic = "force-static";

/**
 * Every published, canonical, indexable route, and nothing else. `lastmod` is
 * only emitted where a real content date exists.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const contentEntries = publishedContent
    .filter((record) => record.indexable)
    .map((record) => ({
      url: absoluteUrl(routeOf(record)),
      lastModified: record.dateModified ?? record.datePublished,
    }));

  const newestContentDate = contentEntries
    .map((entry) => entry.lastModified)
    .filter((date): date is string => Boolean(date))
    .sort()
    .at(-1);

  const staticEntries = staticRoutes.map((route) => ({
    url: absoluteUrl(route),
    // Listing pages change when their content does; policy pages have no date.
    lastModified:
      route === "/" || route === "/blog/" || route === "/features/" ? newestContentDate : undefined,
  }));

  return [...staticEntries, ...contentEntries];
}
