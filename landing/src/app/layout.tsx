import type { Metadata } from "next";
import "./globals.css";
import { siteConfig } from "@/site/config";
import { SiteHeader } from "@/components/SiteHeader";
import { SiteFooter } from "@/components/SiteFooter";
import { ConsentManager } from "@/components/ConsentManager";
import { Analytics } from "@/components/Analytics";
import { JsonLd } from "@/components/JsonLd";
import { websiteSchema } from "@/site/schema";
import { absoluteUrl, assetPath } from "@/site/urls";

export const metadata: Metadata = {
  metadataBase: new URL(absoluteUrl("/")),
  title: {
    default: `${siteConfig.name} — ${siteConfig.tagline}`,
    template: `%s — ${siteConfig.name}`,
  },
  description: siteConfig.description,
  applicationName: siteConfig.name,
  authors: [{ name: siteConfig.operator.name }],
  creator: siteConfig.operator.name,
  formatDetection: { telephone: false },
  // assetPath, not a bare string: Next does not apply the base path to icon
  // metadata, and a project site is served from a sub-path.
  icons: {
    icon: { url: assetPath("/icon.png"), type: "image/png", sizes: "256x256" },
    apple: { url: assetPath("/apple-touch-icon.png"), sizes: "180x180" },
  },
  // A preview build is never indexable; the production origin overrides this.
  robots: siteConfig.isProductionOrigin ? undefined : { index: false, follow: false },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang={siteConfig.language}>
      <body>
        <a className="skip-link" href="#main">
          Skip to content
        </a>
        <JsonLd data={websiteSchema()} />
        <SiteHeader />
        <main id="main">{children}</main>
        <SiteFooter />
        <ConsentManager />
        <Analytics />
      </body>
    </html>
  );
}
