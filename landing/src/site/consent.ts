import { integrations } from "./config";

export type ConsentDecision = "granted" | "denied";

export interface ConsentState {
  analytics: ConsentDecision;
  ads: ConsentDecision;
  /** ISO timestamp of the choice, or null while no choice has been made. */
  decidedAt: string | null;
}

export const defaultConsent: ConsentState = {
  analytics: "denied",
  ads: "denied",
  decidedAt: null,
};

const STORAGE_KEY = "native-sheets.consent.v1";

/**
 * Which purposes are worth asking about. A purpose with no configuration is not
 * offered, so an unconfigured site shows no banner at all.
 */
export const requestedPurposes = {
  analytics: integrations.analytics.enabled,
  ads: integrations.ads.state === "live",
} as const;

export const consentIsRequired = requestedPurposes.analytics || requestedPurposes.ads;

let current: ConsentState = defaultConsent;
let hydrated = false;
const listeners = new Set<() => void>();

function readStorage(): ConsentState {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaultConsent;
    const parsed = JSON.parse(raw) as Partial<ConsentState>;
    return {
      analytics: parsed.analytics === "granted" ? "granted" : "denied",
      ads: parsed.ads === "granted" ? "granted" : "denied",
      decidedAt: typeof parsed.decidedAt === "string" ? parsed.decidedAt : null,
    };
  } catch {
    // Storage can be unavailable or blocked. That is not permission.
    return defaultConsent;
  }
}

function emit() {
  for (const listener of listeners) listener();
}

/** Global Privacy Control, when the browser sends it, is a refusal. */
function globalPrivacyControl(): boolean {
  const signal = (navigator as Navigator & { globalPrivacyControl?: boolean })
    .globalPrivacyControl;
  return signal === true;
}

export function hydrateConsent(): void {
  if (hydrated || typeof window === "undefined") return;
  hydrated = true;
  current = globalPrivacyControl()
    ? { analytics: "denied", ads: "denied", decidedAt: new Date().toISOString() }
    : readStorage();
  emit();
}

export function getConsent(): ConsentState {
  return current;
}

/** Server snapshot: nothing is granted before the client has read a choice. */
export function getServerConsent(): ConsentState {
  return defaultConsent;
}

export function subscribeConsent(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function setConsent(next: Omit<ConsentState, "decidedAt">): void {
  current = { ...next, decidedAt: new Date().toISOString() };
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(current));
  } catch {
    // A failed write must not break the site; the choice holds for this page.
  }
  emit();
}

/** Withdraws everything and clears the identifiers this site can reach. */
export function withdrawConsent(): void {
  setConsent({ analytics: "denied", ads: "denied" });
  clearMeasurementIdentifiers();
}

function clearMeasurementIdentifiers(): void {
  if (typeof document === "undefined") return;
  const measurementCookies = document.cookie
    .split(";")
    .map((entry) => entry.split("=")[0]?.trim() ?? "")
    .filter((name) => name === "_ga" || name.startsWith("_ga_") || name === "_gid");
  for (const name of measurementCookies) {
    document.cookie = `${name}=; Max-Age=0; path=/`;
    document.cookie = `${name}=; Max-Age=0; path=/; domain=.${window.location.hostname}`;
  }
}

export const hasDecided = (state: ConsentState): boolean => state.decidedAt !== null;
