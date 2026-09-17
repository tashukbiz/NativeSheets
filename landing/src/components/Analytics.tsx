"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import Script from "next/script";
import { integrations } from "@/site/config";
import { sanitizePath, trackPageView } from "@/site/analytics";
import { useConsent } from "./ConsentManager";

/** The page type a route belongs to, derived so no page can declare its own. */
export function pageTypeOf(pathname: string): string {
  if (pathname === "/") return "home";
  if (pathname === "/blog/") return "blog-index";
  if (pathname.startsWith("/blog/")) return "article";
  if (pathname === "/features/") return "features-index";
  if (pathname.startsWith("/features/")) return "feature";
  if (pathname === "/viewer/") return "tool";
  if (["/privacy/", "/terms/"].includes(pathname)) return "policy";
  if (pathname === "/about/") return "about";
  return "page";
}

/**
 * Mounted once, in the layout. It loads the measurement script only after
 * permission and sends exactly one page_view per navigation; automatic page
 * views are turned off so the manual call cannot be duplicated.
 */
export function Analytics() {
  const consent = useConsent();
  const pathname = usePathname();
  const pageType = pageTypeOf(pathname ?? "/");
  const lastSent = useRef<string | null>(null);
  const allowed = integrations.analytics.enabled && consent.analytics === "granted";

  useEffect(() => {
    if (!allowed) {
      lastSent.current = null;
      return;
    }
    const path = sanitizePath(pathname ?? "/");
    if (lastSent.current === path) return;
    lastSent.current = path;
    trackPageView(path, pageType);
  }, [allowed, pathname, pageType]);

  if (!allowed) return null;

  const id = integrations.analytics.measurementId;
  return (
    <>
      <Script
        id="ga-loader"
        strategy="afterInteractive"
        src={`https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(id)}`}
      />
      <Script id="ga-init" strategy="afterInteractive">
        {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}
window.gtag=window.gtag||gtag;
gtag('js', new Date());
gtag('config', ${JSON.stringify(id)}, { send_page_view: false, anonymize_ip: true });`}
      </Script>
    </>
  );
}
