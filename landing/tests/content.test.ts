import { strict as assert } from "node:assert";
import test from "node:test";
import {
  allContent,
  articles,
  expectedIndexableRoutes,
  publishedContent,
  readingMinutes,
  relatedTo,
  routeOf,
  validateContent,
} from "../src/site/content/index";
import type { ContentRecord } from "../src/site/content/types";

const sample = (): ContentRecord => ({
  id: "sample",
  slug: "sample",
  type: "article",
  status: "published",
  title: "Sample",
  description: "A sample record.",
  language: "en-US",
  intentCluster: "sample",
  authorId: "tashuk",
  datePublished: "2026-01-01",
  relatedIds: [],
  indexable: true,
  body: [{ kind: "paragraph", content: [Array(200).fill("word").join(" ")] }],
});

test("the shipped registry is valid", () => {
  assert.deepEqual(validateContent(), []);
});

test("every published record has a unique route and a reading time", () => {
  const routes = publishedContent.map(routeOf);
  assert.equal(new Set(routes).size, routes.length);
  for (const record of publishedContent) {
    assert.ok(readingMinutes(record) >= 1);
    assert.match(routeOf(record), /^\/[a-z0-9/-]*\/$/);
  }
});

test("related links resolve and never point at the record itself", () => {
  for (const record of allContent) {
    const related = relatedTo(record);
    assert.equal(related.length, record.relatedIds.length);
    assert.ok(!related.some((item) => item.id === record.id));
  }
});

test("expected routes include every published indexable record", () => {
  const routes = expectedIndexableRoutes();
  for (const record of publishedContent.filter((item) => item.indexable)) {
    assert.ok(routes.includes(routeOf(record)), `${record.id} is missing from expected routes`);
  }
});

test("validation rejects a missing body", () => {
  const record = { ...sample(), body: [] };
  const issues = validateContent([record]);
  assert.ok(issues.some((issue) => issue.problem === "missing body"));
});

test("validation rejects a duplicate slug", () => {
  const issues = validateContent([sample(), { ...sample(), id: "other" }]);
  assert.ok(issues.some((issue) => issue.problem.startsWith("duplicate route")));
});

test("validation rejects an invalid date", () => {
  const issues = validateContent([{ ...sample(), datePublished: "2026-13-45" }]);
  assert.ok(issues.some((issue) => issue.problem.startsWith("invalid datePublished")));
});

test("validation rejects publication without a date", () => {
  const record = sample();
  delete record.datePublished;
  const issues = validateContent([record]);
  assert.ok(issues.some((issue) => issue.problem === "published without a date"));
});

test("validation rejects an unknown related id", () => {
  const issues = validateContent([{ ...sample(), relatedIds: ["nowhere"] }]);
  assert.ok(issues.some((issue) => issue.problem === "unknown related id nowhere"));
});

test("validation rejects a link to a draft", () => {
  const draft: ContentRecord = { ...sample(), id: "draft", slug: "draft", status: "draft" };
  const issues = validateContent([{ ...sample(), relatedIds: ["draft"] }, draft]);
  assert.ok(issues.some((issue) => issue.problem === "related to a draft: draft"));
});

test("drafts are absent from listings and expected routes", () => {
  assert.ok(articles.every((article) => article.status === "published"));
  assert.ok(!expectedIndexableRoutes().some((route) => route.includes("draft")));
});
