import Link from "next/link";
import { siteConfig } from "@/site/config";
import { href } from "@/site/urls";

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
          <Link className="button button--primary" href={href("/viewer/")}>
            Open a workbook
          </Link>
        </nav>
      </div>
    </header>
  );
}

function SheetMark() {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true" focusable="false">
      <rect x="1" y="1" width="20" height="20" rx="4" fill="var(--accent-wash)" stroke="var(--accent)" />
      <path d="M1 8h20M8 8v13M1 14.5h20" stroke="var(--accent)" strokeWidth="1.2" fill="none" />
    </svg>
  );
}
