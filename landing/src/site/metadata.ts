import type { Metadata } from "next";
import { siteConfig } from "./config";
import { absoluteAssetUrl, absoluteUrl } from "./urls";

export const shareImage = {
  path: "/share-card.png",
  width: 1200,
  height: 630,
  alt: "Native Sheets, a native macOS editor for .xlsx files",
} as const;

interface PageMetaInput {
  title: string;
  description: string;
  route: string;
  type?: "website" | "article";
  publishedTime?: string;
  modifiedTime?: string;
  indexable?: boolean;
}

/** One helper behind every page's title, description, canonical and social card. */
export function pageMetadata({
  title,
  description,
  route,
  type = "website",
  publishedTime,
  modifiedTime,
  indexable = true,
}: PageMetaInput): Metadata {
  const url = absoluteUrl(route);
  const image = {
    url: absoluteAssetUrl(shareImage.path),
    width: shareImage.width,
    height: shareImage.height,
    alt: shareImage.alt,
  };

  return {
    title,
    description,
    alternates: { canonical: url },
    robots: indexable ? undefined : { index: false, follow: true },
    openGraph: {
      type,
      url,
      siteName: siteConfig.name,
      title,
      description,
      locale: siteConfig.language.replace("-", "_"),
      images: [image],
      ...(publishedTime ? { publishedTime } : {}),
      ...(modifiedTime ? { modifiedTime } : {}),
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [image.url],
    },
  };
}
