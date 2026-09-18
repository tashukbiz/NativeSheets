import { siteConfig } from "./config";
import { download, product } from "./product";
import { authorById } from "./content/authors";
import { readingMinutes, routeOf, type ContentRecord } from "./content";
import { absoluteAssetUrl, absoluteUrl } from "./urls";
import { shareImage } from "./metadata";

type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };

/**
 * JSON-LD is embedded in a script element, where the only sequence that can end
 * the element early is `</`. Escaping it keeps an unexpected string in a title
 * or description from terminating the script tag.
 */
export function serializeJsonLd(value: JsonValue): string {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}

const websiteId = `${absoluteUrl("/")}#website`;
const operatorId = `${absoluteUrl("/")}#operator`;

export function websiteSchema(): JsonValue {
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        "@id": websiteId,
        url: absoluteUrl("/"),
        name: siteConfig.name,
        description: siteConfig.description,
        inLanguage: siteConfig.language,
        publisher: { "@id": operatorId },
      },
      {
        "@type": "Person",
        "@id": operatorId,
        name: siteConfig.operator.name,
        email: siteConfig.operator.email,
        url: absoluteUrl("/about/"),
      },
    ],
  };
}

/**
 * The app is a free download. A zero-price offer is emitted because that fact is
 * real. No rating or review is emitted, because neither exists for this product.
 */
export function softwareApplicationSchema(): JsonValue {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "@id": `${absoluteUrl("/")}#app`,
    name: product.name,
    applicationCategory: "BusinessApplication",
    applicationSubCategory: product.category,
    operatingSystem: `${product.platform} ${product.minimumOS.replace("macOS ", "")}`,
    isAccessibleForFree: true,
    author: { "@id": operatorId },
    url: absoluteUrl("/"),
    downloadUrl: download.url,
    softwareVersion: "1.0",
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
      url: absoluteUrl("/"),
    },
    description: siteConfig.description,
  };
}

export function articleSchema(record: ContentRecord): JsonValue {
  const author = authorById(record.authorId);
  const url = absoluteUrl(routeOf(record));
  return {
    "@context": "https://schema.org",
    "@type": record.type === "article" || record.type === "guide" ? "BlogPosting" : "WebPage",
    "@id": `${url}#content`,
    headline: record.title,
    description: record.description,
    inLanguage: record.language,
    mainEntityOfPage: url,
    url,
    image: absoluteAssetUrl(shareImage.path),
    author: { "@type": "Person", name: author.name, url: absoluteUrl("/about/") },
    publisher: { "@id": operatorId },
    isPartOf: { "@id": websiteId },
    ...(record.datePublished ? { datePublished: record.datePublished } : {}),
    ...(record.dateModified ? { dateModified: record.dateModified } : {}),
    timeRequired: `PT${readingMinutes(record)}M`,
  };
}

export function breadcrumbSchema(trail: { name: string; route: string }[]): JsonValue {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: trail.map((step, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: step.name,
      item: absoluteUrl(step.route),
    })),
  };
}

export function collectionSchema(
  name: string,
  route: string,
  items: { title: string; route: string }[],
): JsonValue {
  return {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "@id": `${absoluteUrl(route)}#collection`,
    name,
    url: absoluteUrl(route),
    isPartOf: { "@id": websiteId },
    mainEntity: {
      "@type": "ItemList",
      itemListElement: items.map((item, index) => ({
        "@type": "ListItem",
        position: index + 1,
        name: item.title,
        url: absoluteUrl(item.route),
      })),
    },
  };
}
