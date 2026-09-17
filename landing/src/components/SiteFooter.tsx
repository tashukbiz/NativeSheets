import Link from "next/link";
import { contact, siteConfig } from "@/site/config";
import { articles, features, routeOf } from "@/site/content";
import { href } from "@/site/urls";
import { ConsentPreferencesLink } from "./ConsentManager";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="container">
        <div className="footer-grid">
          <section>
            <h2>Use it</h2>
            <ul>
              <li>
                <Link href={href("/viewer/")}>Open a workbook in the browser</Link>
              </li>
              {features.map((feature) => (
                <li key={feature.id}>
                  <Link href={href(routeOf(feature))}>{shortTitle(feature.title)}</Link>
                </li>
              ))}
            </ul>
          </section>
          <section>
            <h2>Guides</h2>
            <ul>
              {articles.map((article) => (
                <li key={article.id}>
                  <Link href={href(routeOf(article))}>{shortTitle(article.title)}</Link>
                </li>
              ))}
            </ul>
          </section>
          <section>
            <h2>Site</h2>
            <ul>
              <li>
                <Link href={href("/about/")}>About and contact</Link>
              </li>
              <li>
                <Link href={href("/privacy/")}>Privacy</Link>
              </li>
              <li>
                <Link href={href("/terms/")}>Terms</Link>
              </li>
              <li>
                <ConsentPreferencesLink />
              </li>
            </ul>
          </section>
          <section>
            <h2>Contact</h2>
            <ul>
              <li>
                <a href={contact.mailto}>{contact.email}</a>
              </li>
            </ul>
          </section>
        </div>
        <p className="footer-note">
          {siteConfig.name} is a free macOS app for .xlsx files, operated by {siteConfig.operator.name}.
          The browser viewer reads workbooks on your device and uploads nothing.
        </p>
      </div>
    </footer>
  );
}

/** Footer links use the part of a title before the first colon. */
function shortTitle(title: string): string {
  return title.split(":")[0] ?? title;
}
