import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { articles, routeOf } from "@/site/content";
import { pageMetadata } from "@/site/metadata";
import { ArticleLayout } from "@/components/ArticleLayout";

export function generateStaticParams() {
  return articles.map((article) => ({ slug: article.slug }));
}

function articleBySlug(slug: string) {
  return articles.find((article) => article.slug === slug);
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const article = articleBySlug(slug);
  if (!article) return {};
  return pageMetadata({
    title: article.title,
    description: article.description,
    route: routeOf(article),
    type: "article",
    publishedTime: article.datePublished,
    modifiedTime: article.dateModified,
    indexable: article.indexable,
  });
}

export default async function ArticlePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const article = articleBySlug(slug);
  if (!article) notFound();

  return (
    <>
      <ArticleLayout
        record={article}
        eyebrow={article.category ?? "Guide"}
        breadcrumb={[
          { name: "Home", route: "/" },
          { name: "Guides", route: "/blog/" },
        ]}
      />
    </>
  );
}
