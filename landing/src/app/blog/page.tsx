import Link from "next/link";
import type { Metadata } from "next";
import { articles, readingMinutes, routeOf } from "@/site/content";
import { href } from "@/site/urls";
import { pageMetadata } from "@/site/metadata";
import { JsonLd } from "@/components/JsonLd";
import { breadcrumbSchema, collectionSchema } from "@/site/schema";
import { formatDate } from "@/components/ArticleLayout";

const title = "Guides to working with .xlsx files";
const description =
  "Practical guides to opening, editing and checking .xlsx workbooks on macOS: what is inside the file format, which formulas recalculate, and what a save keeps.";

export const metadata: Metadata = pageMetadata({ title, description, route: "/blog/" });

export default function BlogIndexPage() {
  return (
    <div className="container section--tight">
      <JsonLd
        data={collectionSchema(
          title,
          "/blog/",
          articles.map((article) => ({ title: article.title, route: routeOf(article) })),
        )}
      />
      <JsonLd
        data={breadcrumbSchema([
          { name: "Home", route: "/" },
          { name: "Guides", route: "/blog/" },
        ])}
      />

      <header className="prose">
        <p className="eyebrow">Guides</p>
        <h1>{title}</h1>
        <p className="lede">{description}</p>
      </header>

      <ul className="grid">
        {articles.map((article) => (
          <li className="card" key={article.id}>
            <p className="card__meta">
              <span>{article.category}</span>
              {article.datePublished && <> · {formatDate(article.datePublished)}</>} ·{" "}
              {readingMinutes(article)} min read
            </p>
            <h2 style={{ fontSize: "1.125rem", margin: 0 }}>
              <Link href={href(routeOf(article))}>{article.title}</Link>
            </h2>
            <p>{article.description}</p>
          </li>
        ))}
      </ul>

      <p className="button-row">
        <Link className="button button--primary" href={href("/viewer/")}>
          Open a workbook in the browser
        </Link>
        <Link className="button button--secondary" href={href("/features/")}>
          How the app works
        </Link>
      </p>
    </div>
  );
}
