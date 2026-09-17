"use client";

import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";
import {
  consentIsRequired,
  getConsent,
  getServerConsent,
  hasDecided,
  hydrateConsent,
  requestedPurposes,
  setConsent,
  subscribeConsent,
  withdrawConsent,
} from "@/site/consent";

export function useConsent() {
  useEffect(() => {
    hydrateConsent();
  }, []);
  return useSyncExternalStore(subscribeConsent, getConsent, getServerConsent);
}

/**
 * One interface for both purposes. Accepting and rejecting are the same kind of
 * button, in the same place, with no preselected permission.
 */
export function ConsentManager() {
  const consent = useConsent();
  const [panelOpen, setPanelOpen] = useState(false);
  const [analytics, setAnalytics] = useState(false);
  const [ads, setAds] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const open = () => {
      setAnalytics(getConsent().analytics === "granted");
      setAds(getConsent().ads === "granted");
      setPanelOpen(true);
    };
    window.addEventListener("native-sheets:open-consent", open);
    return () => window.removeEventListener("native-sheets:open-consent", open);
  }, []);

  useEffect(() => {
    if (panelOpen) panelRef.current?.focus();
  }, [panelOpen]);

  const acceptAll = useCallback(() => {
    setConsent({
      analytics: requestedPurposes.analytics ? "granted" : "denied",
      ads: requestedPurposes.ads ? "granted" : "denied",
    });
    setPanelOpen(false);
  }, []);

  const rejectAll = useCallback(() => {
    withdrawConsent();
    setPanelOpen(false);
  }, []);

  const saveChoices = useCallback(() => {
    setConsent({
      analytics: analytics && requestedPurposes.analytics ? "granted" : "denied",
      ads: ads && requestedPurposes.ads ? "granted" : "denied",
    });
    setPanelOpen(false);
  }, [analytics, ads]);

  if (!consentIsRequired) return null;

  const showBanner = !hasDecided(consent) && !panelOpen;
  if (!showBanner && !panelOpen) return null;

  if (panelOpen) {
    return (
      <div
        className="consent-banner"
        role="dialog"
        aria-modal="false"
        aria-label="Privacy preferences"
        tabIndex={-1}
        ref={panelRef}
      >
        <div className="container consent-banner__inner">
          <div>
            <h2 style={{ fontSize: "1rem", margin: "0 0 0.5rem" }}>Privacy preferences</h2>
            {requestedPurposes.analytics && (
              <p>
                <label>
                  <input
                    type="checkbox"
                    checked={analytics}
                    onChange={(event) => setAnalytics(event.target.checked)}
                  />{" "}
                  Measurement: anonymous page and feature statistics.
                </label>
              </p>
            )}
            {requestedPurposes.ads && (
              <p>
                <label>
                  <input
                    type="checkbox"
                    checked={ads}
                    onChange={(event) => setAds(event.target.checked)}
                  />{" "}
                  Advertising: ads served by our advertising partner.
                </label>
              </p>
            )}
            <p>The viewer works either way. Neither choice affects it.</p>
          </div>
          <div className="button-row">
            <button type="button" className="button button--secondary" onClick={rejectAll}>
              Reject all
            </button>
            <button type="button" className="button button--primary" onClick={saveChoices}>
              Save choices
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="consent-banner" role="region" aria-label="Privacy choices">
      <div className="container consent-banner__inner">
        <p>
          We ask permission before loading anything optional. Nothing optional runs until you
          choose, and the workbook viewer works without either choice.
        </p>
        <div className="button-row">
          <button type="button" className="button button--secondary" onClick={rejectAll}>
            Reject
          </button>
          <button
            type="button"
            className="button button--secondary"
            onClick={() => {
              setAnalytics(false);
              setAds(false);
              setPanelOpen(true);
            }}
          >
            Choose
          </button>
          <button type="button" className="button button--primary" onClick={acceptAll}>
            Accept
          </button>
        </div>
      </div>
    </div>
  );
}

/** Footer control that reopens the preference panel. */
export function ConsentPreferencesLink() {
  if (!consentIsRequired) {
    return <span style={{ color: "var(--ink-faint)" }}>No optional tracking</span>;
  }
  return (
    <button
      type="button"
      className="link-button"
      style={{
        background: "none",
        border: 0,
        padding: 0,
        font: "inherit",
        color: "var(--accent)",
        textDecoration: "underline",
        cursor: "pointer",
      }}
      onClick={() => window.dispatchEvent(new Event("native-sheets:open-consent"))}
    >
      Privacy preferences
    </button>
  );
}
