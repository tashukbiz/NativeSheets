import type { Block, ContentRecord, ContentType } from "./types";
import { authors } from "./authors";
import { openXlsxOnMacWithoutExcel } from "./articles/open-xlsx-on-mac-without-excel";
import { keepChartsWhenEditingXlsx } from "./articles/keep-charts-when-editing-xlsx";
import { formulaCoverage } from "./articles/formula-coverage";
import { roundTripFidelity } from "./features/round-trip-fidelity";
import { formulasFeature } from "./features/formulas";
import { viewerTool } from "./tools/viewer";

const records: ContentRecord[] = [
  openXlsxOnMacWithoutExcel,
  keepChartsWhenEditingXlsx,
  formulaCoverage,
  roundTripFidelity,
  formulasFeature,
  viewerTool,
];

/** Route family per content type. One owning route per record. */
const routePrefix: Record<ContentType, string> = {
  article: "/blog/",
  guide: "/blog/",
  feature: "/features/",
  tool: "/",
  page: "/",
};

export function routeOf(record: ContentRecord): string {
  return `${routePrefix[record.type]}${record.slug}/`;
}

function wordCount(body: Block[]): number {
  let text = "";
  for (const block of body) {
    switch (block.kind) {
      case "heading":
        text += ` ${block.text}`;
        break;
      case "paragraph":
        text += ` ${inlineText(block.content)}`;
        break;
      case "list":
        text += block.items.map(inlineText).join(" ");
        break;
      case "table":
        text += ` ${block.head.join(" ")} ${block.rows.flat().join(" ")}`;
        break;
      case "code":
        text += ` ${block.code}`;
        break;
      case "note":
        text += ` ${block.title} ${inlineText(block.content)}`;
        break;
      case "faq":
        text += block.items.map((item) => `${item.question} ${inlineText(item.answer)}`).join(" ");
        break;
    }
  }
  return text.trim().split(/\s+/).filter(Boolean).length;
}

function inlineText(content: import("./types").Inline[]): string {
  return content
    .map((part) => {
      if (typeof part === "string") return part;
      if ("text" in part) return part.text;
      if ("code" in part) return part.code;
      return part.strong;
    })
    .join(" ");
}

/** Reading time in whole minutes, computed from the final body at 220 wpm. */
export function readingMinutes(record: ContentRecord): number {
  return Math.max(1, Math.round(wordCount(record.body) / 220));
}

/** Anchor targets for the in-page contents list. Long articles only. */
export function headings(record: ContentRecord): { id: string; text: string }[] {
  return record.body.filter((block) => block.kind === "heading").map(({ id, text }) => ({ id, text }));
}

export interface ValidationIssue {
  recordId: string;
  problem: string;
}

/**
 * Registry validation. A missing body, duplicate slug, invalid date, unknown
 * author, unknown related id or self-reference is an error, not a fallback.
 */
export function validateContent(all: ContentRecord[] = records): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const ids = new Set<string>();
  const routes = new Set<string>();
  const knownAuthors = new Set(authors.map((author) => author.id));
  const isoDate = /^\d{4}-\d{2}-\d{2}$/;

  for (const record of all) {
    const fail = (problem: string) => issues.push({ recordId: record.id, problem });

    if (ids.has(record.id)) fail(`duplicate id`);
    ids.add(record.id);

    const route = routeOf(record);
    if (routes.has(route)) fail(`duplicate route ${route}`);
    routes.add(route);

    if (!/^[a-z0-9-]+$/.test(record.slug)) fail(`slug is not url-safe: ${record.slug}`);
    if (!record.title.trim()) fail("missing title");
    if (!record.description.trim()) fail("missing description");
    if (record.body.length === 0) fail("missing body");
    if (wordCount(record.body) < 150) fail("body is too short to publish");
    if (!knownAuthors.has(record.authorId)) fail(`unknown author ${record.authorId}`);

    if (record.status === "published" && !record.datePublished) fail("published without a date");
    for (const [label, value] of [
      ["datePublished", record.datePublished],
      ["dateModified", record.dateModified],
    ] as const) {
      if (value === undefined) continue;
      if (!isoDate.test(value) || Number.isNaN(Date.parse(value))) fail(`invalid ${label}: ${value}`);
    }
    if (record.datePublished && record.dateModified && record.dateModified < record.datePublished) {
      fail("dateModified precedes datePublished");
    }

    const headingIds = new Set<string>();
    for (const block of record.body) {
      if (block.kind !== "heading") continue;
      if (headingIds.has(block.id)) fail(`duplicate heading anchor ${block.id}`);
      headingIds.add(block.id);
    }

    for (const relatedId of record.relatedIds) {
      if (relatedId === record.id) fail("related to itself");
      const target = all.find((candidate) => candidate.id === relatedId);
      if (!target) fail(`unknown related id ${relatedId}`);
      else if (target.status !== "published") fail(`related to a draft: ${relatedId}`);
    }
  }

  return issues;
}

const issues = validateContent(records);
if (issues.length > 0) {
  throw new Error(
    `Content registry is invalid:\n${issues.map((issue) => `  ${issue.recordId}: ${issue.problem}`).join("\n")}`,
  );
}

export const allContent = records;

export const publishedContent = records.filter((record) => record.status === "published");

export const articles = publishedContent
  .filter((record) => record.type === "article" || record.type === "guide")
  .sort((a, b) => (b.datePublished ?? "").localeCompare(a.datePublished ?? ""));

export const features = publishedContent.filter((record) => record.type === "feature");

export const toolPages = publishedContent.filter((record) => record.type === "tool");

export function contentById(id: string): ContentRecord {
  const found = allContent.find((record) => record.id === id);
  if (!found) throw new Error(`Unknown content id: ${id}`);
  return found;
}

export function relatedTo(record: ContentRecord): ContentRecord[] {
  return record.relatedIds.map(contentById).filter((related) => related.status === "published");
}

/** Every indexable route the build is expected to produce, content plus statics. */
export const staticRoutes = [
  "/",
  "/blog/",
  "/features/",
  "/about/",
  "/privacy/",
  "/terms/",
] as const;

export function expectedIndexableRoutes(): string[] {
  const contentRoutes = publishedContent
    .filter((record) => record.indexable)
    .map(routeOf);
  return [...staticRoutes, ...contentRoutes].sort();
}

export type { ContentRecord, Block } from "./types";
