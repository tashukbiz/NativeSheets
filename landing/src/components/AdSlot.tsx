"use client";

import { useEffect, useRef } from "react";
import Script from "next/script";
import { adSlotDecision, type AdPlacement } from "@/site/ads";
import { integrations } from "@/site/config";
import { useConsent } from "./ConsentManager";

declare global {
  interface Window {
    adsbygoogle?: unknown[];
  }
}

/**
 * One abstraction for every ad position. Space is reserved before any request,
 * each mounted slot is initialised at most once, and a slot that cannot request
 * simply renders nothing rather than collapsing the layout around it.
 */
export function AdSlot({ placement, route }: { placement: AdPlacement; route: string }) {
  const consent = useConsent();
  const decision = adSlotDecision(placement, route);
  const initialised = useRef(false);
  const mayRequest = decision.request && consent.ads === "granted";

  useEffect(() => {
    if (!mayRequest || initialised.current) return;
    initialised.current = true;
    try {
      window.adsbygoogle = window.adsbygoogle || [];
      window.adsbygoogle.push({});
    } catch {
      // A blocked or failed provider must leave the page working.
    }
  }, [mayRequest]);

  if (!decision.render) return null;

  return (
    <aside className="ad-slot" aria-label="Advertisement">
      <span className="ad-slot__label">Advertisement</span>
      <div className="ad-slot__frame">
        {mayRequest ? (
          <>
            <Script
              id="adsense-loader"
              strategy="afterInteractive"
              crossOrigin="anonymous"
              src={`https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${encodeURIComponent(
                decision.publisherId,
              )}`}
            />
            <ins
              className="adsbygoogle"
              style={{ display: "block", width: "100%" }}
              data-ad-client={decision.publisherId}
              data-ad-slot={decision.slotId}
              data-ad-format="auto"
              data-full-width-responsive="true"
            />
          </>
        ) : (
          <span>
            {decision.previewLabel ??
              `Reserved space. Ads are ${integrations.ads.state} and make no requests.`}
          </span>
        )}
      </div>
    </aside>
  );
}
