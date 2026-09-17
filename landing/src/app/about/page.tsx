import Link from "next/link";
import type { Metadata } from "next";
import { contact, siteConfig } from "@/site/config";
import { product } from "@/site/product";
import { href } from "@/site/urls";
import { pageMetadata } from "@/site/metadata";
import { JsonLd } from "@/components/JsonLd";
import { breadcrumbSchema } from "@/site/schema";

const title = "About and contact";
const description =
  "Who runs Native Sheets and this site, how to get in touch, and what the project is and is not.";

export const metadata: Metadata = pageMetadata({ title, description, route: "/about/" });

export default function AboutPage() {
  return (
    <div className="container section--tight prose">
      <JsonLd
        data={breadcrumbSchema([
          { name: "Home", route: "/" },
          { name: "About", route: "/about/" },
        ])}
      />
      <h1>{title}</h1>
      <p className="lede">{description}</p>

      <h2>Who operates this site</h2>
      <p>
        Native Sheets and this website are made and run by an individual developer, {siteConfig.operator.name},
        not a company. There is no team, no investor and no support desk behind it.
      </p>

      <h2>Contact</h2>
      <p>
        Email: <a href={contact.mailto}>{contact.email}</a>
      </p>
      <p>{contact.responseExpectation}</p>
      <p>
        Bug reports are more useful than most messages if they say which macOS version you are on
        and what the workbook contains. Please do not attach confidential spreadsheets.
      </p>

      <h2>What the project is</h2>
      <p>
        Native Sheets is a {product.price.toLowerCase()} {product.category.toLowerCase()} for{" "}
        {product.platform}, written without third-party dependencies: the ZIP container, the XML,
        the number formats, the formula engine and the grid are all implemented in the project
        itself. {product.accessNote}
      </p>
      <p>
        This site also hosts a free browser viewer for .xlsx files. It reads workbooks in the page
        and uploads nothing, which is described in more detail on the{" "}
        <Link href={href("/privacy/")}>privacy page</Link>.
      </p>

      <h2>Editorial responsibility</h2>
      <p>
        The guides here are written by the same person who writes the app. Claims about what the
        software does are taken from its source and its test suite, and measurements are stated with
        the workbook they were measured on. Where something is not supported, the guides say so
        rather than leaving it out.
      </p>
      <p>
        If you find something on this site that is wrong or out of date, email the address above and
        it will be corrected.
      </p>

      <h2>Relationships to disclose</h2>
      <p>
        This site is operated by the developer of the product it describes, so it is not a neutral
        review. Other software mentioned in the guides, such as LibreOffice, Apple Numbers, Microsoft
        Excel and openpyxl, is not affiliated with this project, and no arrangement exists with any
        of them.
      </p>

      <p className="button-row">
        <Link className="button button--primary" href={href("/viewer/")}>
          Open a workbook in the browser
        </Link>
      </p>
    </div>
  );
}
