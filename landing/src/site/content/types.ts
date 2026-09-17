/** The content model. Cards, articles, metadata, related links and the sitemap
 * are all generated from these records. */

export type ContentStatus = "draft" | "published";
export type ContentType = "article" | "guide" | "feature" | "tool" | "page";

/** An inline run of text. Links carry an internal route or an absolute URL. */
export type Inline =
  | string
  | { text: string; href: string; external?: boolean }
  | { code: string }
  | { strong: string };

export type Block =
  | { kind: "heading"; id: string; text: string }
  | { kind: "paragraph"; content: Inline[] }
  | { kind: "list"; ordered?: boolean; items: Inline[][] }
  | { kind: "table"; caption?: string; head: string[]; rows: string[][] }
  | { kind: "code"; language?: string; code: string }
  | { kind: "note"; title: string; content: Inline[] }
  | { kind: "faq"; items: { question: string; answer: Inline[] }[] };

export interface Author {
  id: string;
  name: string;
  /** Only verifiable responsibility, never an invented biography. */
  role: string;
  bio: string;
}

export interface ContentRecord {
  id: string;
  slug: string;
  type: ContentType;
  status: ContentStatus;
  title: string;
  /** Meta description and card summary. */
  description: string;
  language: string;
  intentCluster: string;
  authorId: string;
  /** ISO date. Required when published. */
  datePublished?: string;
  dateModified?: string;
  category?: string;
  relatedIds: string[];
  productOrToolId?: string;
  indexable: boolean;
  body: Block[];
}
