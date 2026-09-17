import { integrations, siteConfig } from "./config";
import { getConsent } from "./consent";

/** The event vocabulary. Nothing outside this map is sent. */
export interface AnalyticsEvents {
  page_view: { page_path: string; page_type: string; profile: string };
  tool_start: { tool_id: string; placement: string };
  tool_complete: { tool_id: string; outcome: string };
  related_content_click: { from_id: string; to_id: string; placement: string };
}

type Gtag = (...args: unknown[]) => void;

declare global {
  interface Window {
    gtag?: Gtag;
    dataLayer?: unknown[];
  }
}

/**
 * Strips query strings and fragments before a path is transmitted. Tool inputs,
 * file names and tokens must never reach the provider.
 */
export function sanitizePath(path: string): string {
  const withoutQuery = path.split(/[?#]/)[0] ?? "/";
  return withoutQuery.startsWith("/") ? withoutQuery : `/${withoutQuery}`;
}

export function analyticsAllowed(): boolean {
  return integrations.analytics.enabled && getConsent().analytics === "granted";
}

export function track<K extends keyof AnalyticsEvents>(
  event: K,
  params: AnalyticsEvents[K],
): void {
  if (typeof window === "undefined" || !analyticsAllowed()) return;
  const gtag = window.gtag;
  if (!gtag) return;
  gtag("event", event, { ...params, profile: siteConfig.profile });
}

export function trackPageView(path: string, pageType: string): void {
  track("page_view", {
    page_path: sanitizePath(path),
    page_type: pageType,
    profile: siteConfig.profile,
  });
}
