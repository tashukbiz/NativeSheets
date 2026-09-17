import { serializeJsonLd } from "@/site/schema";

type JsonValue = Parameters<typeof serializeJsonLd>[0];

/** Renders structured data with `</` escaped so a value cannot end the script. */
export function JsonLd({ data }: { data: JsonValue }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: serializeJsonLd(data) }}
    />
  );
}
