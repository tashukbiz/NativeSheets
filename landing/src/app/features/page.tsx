import Link from "next/link";
import type { Metadata } from "next";
import { features, routeOf } from "@/site/content";
import { capabilities, limitations } from "@/site/product";
import { href } from "@/site/urls";
import { pageMetadata } from "@/site/metadata";
import { JsonLd } from "@/components/JsonLd";
import { breadcrumbSchema, collectionSchema } from "@/site/schema";

const title = "What Native Sheets does";
const description =
  "The capabilities of the Native Sheets macOS editor, in detail: round-trip fidelity for parts it does not model, and a dependency-ordered formula engine, with the limits of each.";

export const metadata: Metadata = pageMetadata({ title, description, route: "/features/" });

export default function FeaturesIndexPage() {
  return (
    <div className="container section--tight">
      <JsonLd
        data={collectionSchema(
          title,
          "/features/",
          features.map((feature) => ({ title: feature.title, route: routeOf(feature) })),
        )}
      />
      <JsonLd
        data={breadcrumbSchema([
          { name: "Home", route: "/" },
          { name: "Features", route: "/features/" },
        ])}
      />

      <header className="prose">
        <p className="eyebrow">Features</p>
        <h1>{title}</h1>
        <p className="lede">{description}</p>
      </header>

      <section aria-labelledby="detailed-heading">
        <h2 id="detailed-heading">In detail</h2>
        <ul className="grid">
          {features.map((feature) => (
            <li className="card" key={feature.id}>
              <h3>
                <Link href={href(routeOf(feature))}>{feature.title}</Link>
              </h3>
              <p>{feature.description}</p>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="everything-heading">
        <h2 id="everything-heading">Everything else it does</h2>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th scope="col">Capability</th>
                <th scope="col">What that means</th>
              </tr>
            </thead>
            <tbody>
              {capabilities.map((capability) => (
                <tr key={capability.id}>
                  <th scope="row">{capability.title}</th>
                  <td>{capability.summary}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="prose" aria-labelledby="limits-heading">
        <h2 id="limits-heading">Limits</h2>
        <ul>
          {limitations.map((limitation) => (
            <li key={limitation}>{limitation}</li>
          ))}
        </ul>
        <p className="button-row">
          <Link className="button button--primary" href={href("/viewer/")}>
            Open a workbook in the browser
          </Link>
          <Link className="button button--secondary" href={href("/blog/")}>
            Read the guides
          </Link>
        </p>
      </section>
    </div>
  );
}
