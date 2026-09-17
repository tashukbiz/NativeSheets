import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { features, routeOf } from "@/site/content";
import { pageMetadata } from "@/site/metadata";
import { ArticleLayout } from "@/components/ArticleLayout";

export function generateStaticParams() {
  return features.map((feature) => ({ slug: feature.slug }));
}

function featureBySlug(slug: string) {
  return features.find((feature) => feature.slug === slug);
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const feature = featureBySlug(slug);
  if (!feature) return {};
  return pageMetadata({
    title: feature.title,
    description: feature.description,
    route: routeOf(feature),
    indexable: feature.indexable,
  });
}

export default async function FeaturePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const feature = featureBySlug(slug);
  if (!feature) notFound();

  return (
    <>
      <ArticleLayout
        record={feature}
        eyebrow="Feature"
        breadcrumb={[
          { name: "Home", route: "/" },
          { name: "Features", route: "/features/" },
        ]}
      />
    </>
  );
}
