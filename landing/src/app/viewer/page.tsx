import Link from "next/link";
import type { Metadata } from "next";
import { contentById, readingMinutes, relatedTo, routeOf } from "@/site/content";
import { authorById } from "@/site/content/authors";
import { href } from "@/site/urls";
import { pageMetadata } from "@/site/metadata";
import { Blocks } from "@/components/Blocks";
import { JsonLd } from "@/components/JsonLd";
import { AdSlot } from "@/components/AdSlot";
import { WorkbookViewer } from "@/components/WorkbookViewer";
import { articleSchema, breadcrumbSchema } from "@/site/schema";
import { formatDate } from "@/components/ArticleLayout";

const record = contentById("viewer");

export const metadata: Metadata = pageMetadata({
  title: record.title,
  description: record.description,
  route: routeOf(record),
});

export default function ViewerPage() {
  const author = authorById(record.authorId);
  const related = relatedTo(record);
  const route = routeOf(record);

  return (
    <div className="container section--tight">
      <JsonLd data={articleSchema(record)} />
      <JsonLd
        data={breadcrumbSchema([
          { name: "Home", route: "/" },
          { name: "XLSX viewer", route },
        ])}
      />

      <header className="prose">
        <p className="eyebrow">Free browser tool</p>
        <h1>XLSX viewer: open a spreadsheet in your browser</h1>
        <p className="lede">
          Read any .xlsx workbook without installing anything. The file is parsed on your device,
          so nothing is uploaded, and there is no account or payment involved.
        </p>
      </header>

      <noscript>
        <div className="note">
          <h3>The viewer needs JavaScript</h3>
          <p>
            The workbook is decompressed and parsed in your browser, which requires JavaScript.
            Everything else on this page, including the instructions and limits below, is readable
            without it. Editing workbooks happens in the macOS app, described on the{" "}
            <Link href={href("/")}>home page</Link>.
          </p>
        </div>
      </noscript>

      <WorkbookViewer />

      <AdSlot placement="tool-aside" route={route} />

      <div className="prose">
        <Blocks blocks={record.body} />
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
        <p className="article-meta">
          Written by {author.name}, {author.role}
          {record.datePublished && <> · Published {formatDate(record.datePublished)}</>} ·{" "}
          {readingMinutes(record)} min read
        </p>
      </section>
    </div>
  );
}
