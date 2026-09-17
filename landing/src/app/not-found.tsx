import Link from "next/link";
import type { Metadata } from "next";
import { articles, features, routeOf } from "@/site/content";
import { href } from "@/site/urls";

export const metadata: Metadata = {
  title: "Page not found",
  description: "That page does not exist on this site.",
  robots: { index: false, follow: true },
};

export default function NotFound() {
  return (
    <div className="container section--tight prose">
      <p className="eyebrow">404</p>
      <h1>That page does not exist</h1>
      <p className="lede">
        The address you followed is not a page on this site. Nothing is broken on your end.
      </p>

      <h2>The things people come here for</h2>
      <ul>
        <li>
          <Link href={href("/viewer/")}>Open an .xlsx workbook in the browser</Link>
        </li>
        <li>
          <Link href={href("/")}>What the macOS editor does</Link>
        </li>
        {features.map((feature) => (
          <li key={feature.id}>
            <Link href={href(routeOf(feature))}>{feature.title}</Link>
          </li>
        ))}
        {articles.map((article) => (
          <li key={article.id}>
            <Link href={href(routeOf(article))}>{article.title}</Link>
          </li>
        ))}
        <li>
          <Link href={href("/about/")}>About and contact</Link>
        </li>
      </ul>

      <p>
        If you arrived here from a link on this site, please say so by email so it can be fixed:
        the address is on the <Link href={href("/about/")}>about page</Link>.
      </p>
    </div>
  );
}
