import Link from "next/link";
import { authorById } from "@/site/content/authors";
import { headings, readingMinutes, relatedTo, routeOf, type ContentRecord } from "@/site/content";
import { href } from "@/site/urls";
import { Blocks } from "./Blocks";
import { AdSlot } from "./AdSlot";
import { JsonLd } from "./JsonLd";
import { articleSchema, breadcrumbSchema } from "@/site/schema";

const dateFormat = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "long",
  year: "numeric",
  timeZone: "UTC",
});

export function formatDate(iso: string): string {
  return dateFormat.format(new Date(`${iso}T00:00:00Z`));
}

interface ArticleLayoutProps {
  record: ContentRecord;
  breadcrumb: { name: string; route: string }[];
  eyebrow: string;
}

/** The shared layout for every article, guide, feature and tool explanation. */
export function ArticleLayout({ record, breadcrumb, eyebrow }: ArticleLayoutProps) {
  const author = authorById(record.authorId);
  const route = routeOf(record);
  const anchors = headings(record);
  const related = relatedTo(record);
  const showContents = anchors.length >= 4;
  const adBreakIndex = adBreakFor(record);

  return (
    <article className="container section--tight">
      <JsonLd data={articleSchema(record)} />
      <JsonLd data={breadcrumbSchema([...breadcrumb, { name: record.title, route }])} />

      <nav aria-label="Breadcrumb" style={{ marginBottom: "var(--step-2)" }}>
        <ol
          style={{
            listStyle: "none",
            display: "flex",
            flexWrap: "wrap",
            gap: "0.5rem",
            padding: 0,
            margin: 0,
            fontSize: "0.875rem",
            color: "var(--ink-faint)",
          }}
        >
          {breadcrumb.map((step) => (
            <li key={step.route}>
              <Link href={href(step.route)}>{step.name}</Link>
              <span aria-hidden="true"> /</span>
            </li>
          ))}
          <li aria-current="page">{shortCrumb(record.title)}</li>
        </ol>
      </nav>

      <header className="prose">
        <p className="eyebrow">{eyebrow}</p>
        <h1>{record.title}</h1>
        <p className="lede">{record.description}</p>
        <p className="article-meta">
          By {author.name}, {author.role}
          {record.datePublished && <> · Published {formatDate(record.datePublished)}</>}
          {record.dateModified && <> · Updated {formatDate(record.dateModified)}</>} ·{" "}
          {readingMinutes(record)} min read
        </p>
      </header>

      {showContents && (
        <nav className="contents prose" aria-label="On this page">
          <h2>On this page</h2>
          <ol>
            {anchors.map((anchor) => (
              <li key={anchor.id}>
                <a href={`#${anchor.id}`}>{anchor.text}</a>
              </li>
            ))}
          </ol>
        </nav>
      )}

      <div className="prose">
        <Blocks blocks={record.body.slice(0, adBreakIndex)} />
        {adBreakIndex < record.body.length && <AdSlot placement="article-body" route={route} />}
        <Blocks blocks={record.body.slice(adBreakIndex)} />
      </div>

      <section className="prose" aria-labelledby="related-heading">
        <h2 id="related-heading">Related</h2>
        <ul className="grid">
          {related.map((item) => (
            <li className="card" key={item.id}>
              <h3>
                <Link href={href(routeOf(item))}>{item.title}</Link>
              </h3>
              <p>{item.description}</p>
            </li>
          ))}
        </ul>
        <p>
          <Link className="button button--primary" href={href("/viewer/")}>
            Open a workbook in the browser
          </Link>
        </p>
      </section>
    </article>
  );
}

/**
 * The in-body ad goes after the first substantive section, never before the
 * article has answered anything.
 */
function adBreakFor(record: ContentRecord): number {
  const firstHeadingIndex = record.body.findIndex((block) => block.kind === "heading");
  if (firstHeadingIndex < 0) return record.body.length;
  const secondHeadingIndex = record.body.findIndex(
    (block, index) => index > firstHeadingIndex && block.kind === "heading",
  );
  return secondHeadingIndex < 0 ? record.body.length : secondHeadingIndex;
}

function shortCrumb(title: string): string {
  const head = title.split(":")[0] ?? title;
  return head.length > 48 ? `${head.slice(0, 45)}…` : head;
}
