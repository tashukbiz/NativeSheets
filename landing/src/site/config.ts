/** Identity, origin, operator and integration switches for the whole site. */
export type SiteProfile = "app-discovery" | "ad-supported-web";

/** Monetization state. Live ads require every activation gate in README.md. */
export type AdState = "disabled" | "preview" | "pending-review" | "live";

const rawOrigin = process.env.NEXT_PUBLIC_SITE_ORIGIN?.trim();

/**
 * The production origin is not registered yet, so builds fall back to a local
 * preview origin and `isProductionOrigin` stays false. A release build refuses
 * to continue in that state (see scripts/verify-build.mjs).
 */
export const siteConfig = {
  name: "Native Sheets",
  tagline: "A native macOS editor for .xlsx files",
  description:
    "Native Sheets is a free, standalone macOS app for opening and editing .xlsx workbooks, with a browser-based viewer that reads a workbook without uploading it anywhere.",
  profile: "ad-supported-web" as SiteProfile,
  locale: "en",
  language: "en-US",
  origin: rawOrigin || "http://localhost:4173",
  isProductionOrigin: Boolean(rawOrigin && rawOrigin.startsWith("https://")),
  basePath: process.env.NEXT_PUBLIC_BASE_PATH ?? "",
  operator: {
    /** No company entity has been verified; the site is operated by an individual. */
    type: "Person" as const,
    /** The only verified identity is the repository account name. */
    name: "tashuk",
    role: "Developer and operator of Native Sheets",
    email: "tashukwork@gmail.com",
    /** Postal address and jurisdiction are not confirmed, so neither is published. */
  },
  /** Whether the site targets children. Recorded because it gates ad activation. */
  audience: {
    directedAtChildren: false,
    description:
      "Adults who work with spreadsheet files on macOS: analysts, accountants, developers and general office users.",
  },
  social: {
    /** No verified social accounts; no fabricated profile links are published. */
    repository: "",
  },
} as const;

/**
 * Integrations are disabled whenever their configuration is absent. An unset ID
 * means no script, no request and no consent category for that purpose.
 */
export const integrations = {
  analytics: {
    provider: "google-analytics-4" as const,
    measurementId: process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID?.trim() || "",
    get enabled() {
      return this.measurementId.length > 0;
    },
  },
  ads: {
    state: (process.env.NEXT_PUBLIC_AD_STATE?.trim() || "disabled") as AdState,
    publisherId: process.env.NEXT_PUBLIC_ADSENSE_CLIENT?.trim() || "",
    slots: {
      articleBody: process.env.NEXT_PUBLIC_ADSENSE_SLOT_ARTICLE?.trim() || "",
      toolAside: process.env.NEXT_PUBLIC_ADSENSE_SLOT_TOOL?.trim() || "",
    },
  },
} as const;

export const contact = {
  email: siteConfig.operator.email,
  mailto: `mailto:${siteConfig.operator.email}`,
  /** Email is the only support channel that exists; no form is published. */
  responseExpectation:
    "Email is the only support channel. It is answered by one person, so replies are not immediate and no response time is promised.",
} as const;
