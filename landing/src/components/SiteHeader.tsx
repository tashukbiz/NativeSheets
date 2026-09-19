import Link from "next/link";
import { siteConfig } from "@/site/config";
import { download } from "@/site/product";
import { assetPath, href } from "@/site/urls";

const navigation = [
  { label: "Viewer", route: "/viewer/" },
  { label: "Features", route: "/features/" },
  { label: "Guides", route: "/blog/" },
  { label: "About", route: "/about/" },
];

export function SiteHeader() {
  return (
    <header className="site-header">
      <div className="container site-header__inner">
        <Link className="site-header__brand" href={href("/")}>
          <SheetMark />
          {siteConfig.name}
        </Link>
        <nav className="site-nav" aria-label="Primary">
          {navigation.map((item) => (
            <Link key={item.route} href={href(item.route)}>
              {item.label}
            </Link>
          ))}
          <a className="button button--primary" href={download.url}>
            Download
          </a>
        </nav>
      </div>
    </header>
  );
}

/**
 * The app icon. It is the same file the browser already fetched for the tab, so
 * showing it here costs no extra request. Plain img rather than next/image:
 * the export runs with images unoptimized, which makes the two equivalent.
 */
function SheetMark() {
  return (
    <img
      className="site-header__mark"
      src={assetPath("/icon.png")}
      width={22}
      height={22}
      alt=""
      aria-hidden="true"
    />
  );
}
