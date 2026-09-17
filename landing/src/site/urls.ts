import { siteConfig } from "./config";

/**
 * The single route normalisation policy for the site: every content route is
 * lower-case, starts with a slash and ends with one. It drives canonicals,
 * Open Graph URLs, sitemap entries and schema identifiers alike.
 */
export function normalizeRoute(route: string): string {
  const withLeading = route.startsWith("/") ? route : `/${route}`;
  const collapsed = withLeading.replace(/\/{2,}/g, "/");
  return collapsed.endsWith("/") ? collapsed : `${collapsed}/`;
}

/** Absolute URL of a content route, on the configured origin. */
export function absoluteUrl(route: string): string {
  return `${siteConfig.origin}${siteConfig.basePath}${normalizeRoute(route)}`;
}

/**
 * Href for an internal link. No base path: next/link prefixes it, and adding it
 * here would apply it twice.
 */
export function href(route: string): string {
  return normalizeRoute(route);
}

/**
 * Assets are files, not routes: no trailing slash is appended, because that
 * would break the request for the file itself.
 */
export function assetPath(path: string): string {
  const withLeading = path.startsWith("/") ? path : `/${path}`;
  return `${siteConfig.basePath}${withLeading}`;
}

export function absoluteAssetUrl(path: string): string {
  return `${siteConfig.origin}${assetPath(path)}`;
}
