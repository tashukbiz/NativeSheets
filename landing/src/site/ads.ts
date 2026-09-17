import { integrations, type AdState } from "./config";
import { normalizeRoute } from "./urls";

export type AdPlacement = "article-body" | "tool-aside";

export const adPlacements: Record<AdPlacement, { slotKey: keyof typeof integrations.ads.slots }> = {
  "article-body": { slotKey: "articleBody" },
  "tool-aside": { slotKey: "toolAside" },
};

/**
 * Route eligibility. Policies, contact, errors and the site's own utility pages
 * carry no ad slots; substantial articles, feature pages and the tool page do.
 */
const eligibleChildrenOf = ["/blog/", "/features/"];
const eligibleExactRoutes = ["/viewer/"];
const excludedRoutes = ["/", "/about/", "/privacy/", "/terms/", "/404/"];

export function routeIsAdEligible(route: string): boolean {
  const normalized = normalizeRoute(route);
  if (excludedRoutes.includes(normalized)) return false;
  if (eligibleExactRoutes.includes(normalized)) return true;
  return eligibleChildrenOf.some(
    (prefix) => normalized.startsWith(prefix) && normalized.length > prefix.length,
  );
}

const placeholderPattern = /(your|placeholder|example|xxxx|000000)/i;

function publisherIdIsReal(id: string): boolean {
  return /^ca-pub-\d{16}$/.test(id) && !placeholderPattern.test(id);
}

function slotIdIsReal(id: string): boolean {
  return /^\d{6,}$/.test(id) && !placeholderPattern.test(id);
}

export interface AdSlotDecision {
  /** Render reserved, labelled space. */
  render: boolean;
  /** Actually request an ad from the provider. */
  request: boolean;
  /** Deterministic placeholder text, for preview only. */
  previewLabel: string | null;
  slotId: string;
  publisherId: string;
}

/**
 * Whether a slot may render and whether it may request. `live` requires a real
 * publisher ID and a real slot ID: a placeholder cannot turn ads on.
 */
export interface AdConfiguration {
  state: AdState;
  publisherId: string;
  slots: Record<string, string>;
}

export function adSlotDecision(
  placement: AdPlacement,
  route: string,
  configuration: AdConfiguration = integrations.ads,
): AdSlotDecision {
  const { state, publisherId, slots } = configuration;
  const slotId = slots[adPlacements[placement].slotKey] ?? "";
  const eligible = routeIsAdEligible(route);
  const configured = publisherIdIsReal(publisherId) && slotIdIsReal(slotId);

  if (!eligible || state === "disabled" || state === "pending-review") {
    return { render: false, request: false, previewLabel: null, slotId, publisherId };
  }
  if (state === "preview") {
    return {
      render: true,
      request: false,
      previewLabel: `Ad slot preview: ${placement}`,
      slotId,
      publisherId,
    };
  }
  return {
    render: configured,
    request: configured,
    previewLabel: null,
    slotId,
    publisherId,
  };
}

export const adsAreConfigurable = integrations.ads.state !== "disabled";
