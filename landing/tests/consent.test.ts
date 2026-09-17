import { strict as assert } from "node:assert";
import test from "node:test";
import { adSlotDecision, routeIsAdEligible } from "../src/site/ads";
import { sanitizePath } from "../src/site/analytics";
import { consentIsRequired, defaultConsent, requestedPurposes } from "../src/site/consent";

/**
 * These run against the default configuration: no measurement ID, ads disabled.
 * They are the state the site ships in, so this is the state worth pinning.
 */

test("nothing is granted before a choice", () => {
  assert.equal(defaultConsent.analytics, "denied");
  assert.equal(defaultConsent.ads, "denied");
  assert.equal(defaultConsent.decidedAt, null);
});

test("no configured purpose means no consent interface at all", () => {
  assert.equal(requestedPurposes.analytics, false);
  assert.equal(requestedPurposes.ads, false);
  assert.equal(consentIsRequired, false);
});

test("transmitted paths carry no query string, fragment or input", () => {
  assert.equal(sanitizePath("/viewer/?file=salaries.xlsx"), "/viewer/");
  assert.equal(sanitizePath("/blog/post/#section"), "/blog/post/");
  assert.equal(sanitizePath("/viewer/?token=abc123#cell=B7"), "/viewer/");
  assert.equal(sanitizePath("blog/"), "/blog/");
});

test("page type is derived from the route, so no page can send a second one", async () => {
  const { pageTypeOf } = await import("../src/components/Analytics");
  assert.equal(pageTypeOf("/"), "home");
  assert.equal(pageTypeOf("/blog/"), "blog-index");
  assert.equal(pageTypeOf("/blog/will-my-formulas-work/"), "article");
  assert.equal(pageTypeOf("/features/"), "features-index");
  assert.equal(pageTypeOf("/features/formulas/"), "feature");
  assert.equal(pageTypeOf("/viewer/"), "tool");
  assert.equal(pageTypeOf("/privacy/"), "policy");
  assert.equal(pageTypeOf("/unknown/"), "page");
});

test("policy, contact and home routes are never ad-eligible", () => {
  for (const route of ["/", "/about/", "/privacy/", "/terms/", "/404/"]) {
    assert.equal(routeIsAdEligible(route), false, route);
  }
});

test("articles, features and the tool page are ad-eligible templates", () => {
  for (const route of ["/blog/anything/", "/features/formulas/", "/viewer/"]) {
    assert.equal(routeIsAdEligible(route), true, route);
  }
});

test("index routes themselves are not ad-eligible", () => {
  assert.equal(routeIsAdEligible("/blog/"), false);
  assert.equal(routeIsAdEligible("/features/"), false);
});

test("a disabled state neither renders nor requests", () => {
  const decision = adSlotDecision("article-body", "/blog/anything/");
  assert.equal(decision.render, false);
  assert.equal(decision.request, false);
});

const realIds = {
  publisherId: "ca-pub-1234567890123456",
  slots: { articleBody: "1234567890", toolAside: "9876543210" },
};

test("preview renders a deterministic placeholder and never requests", () => {
  const decision = adSlotDecision("article-body", "/blog/anything/", {
    state: "preview",
    ...realIds,
  });
  assert.equal(decision.render, true);
  assert.equal(decision.request, false);
  assert.equal(decision.previewLabel, "Ad slot preview: article-body");
});

test("pending-review makes no request even with real identifiers", () => {
  const decision = adSlotDecision("article-body", "/blog/anything/", {
    state: "pending-review",
    ...realIds,
  });
  assert.equal(decision.render, false);
  assert.equal(decision.request, false);
});

test("live requests only with real publisher and slot identifiers", () => {
  const live = adSlotDecision("article-body", "/blog/anything/", { state: "live", ...realIds });
  assert.equal(live.request, true);

  for (const broken of [
    { state: "live" as const, publisherId: "", slots: realIds.slots },
    { state: "live" as const, publisherId: "ca-pub-YOUR-ID-HERE", slots: realIds.slots },
    { state: "live" as const, publisherId: realIds.publisherId, slots: { articleBody: "" } },
    {
      state: "live" as const,
      publisherId: realIds.publisherId,
      slots: { articleBody: "your-slot" },
    },
  ]) {
    const decision = adSlotDecision("article-body", "/blog/anything/", broken);
    assert.equal(decision.request, false, JSON.stringify(broken));
    assert.equal(decision.render, false, JSON.stringify(broken));
  }
});

test("live never requests on an excluded route", () => {
  const decision = adSlotDecision("article-body", "/privacy/", { state: "live", ...realIds });
  assert.equal(decision.request, false);
});
