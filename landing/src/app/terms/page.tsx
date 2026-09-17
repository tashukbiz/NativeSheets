import Link from "next/link";
import type { Metadata } from "next";
import { contact, siteConfig } from "@/site/config";
import { href } from "@/site/urls";
import { pageMetadata } from "@/site/metadata";

const title = "Terms of use";
const description =
  "The terms on which this website and its browser viewer are offered: free, as-is, with no account and no warranty.";

export const metadata: Metadata = pageMetadata({ title, description, route: "/terms/" });

export default function TermsPage() {
  return (
    <div className="container section--tight prose">
      <h1>{title}</h1>
      <p className="lede">{description}</p>

      <h2>What this covers</h2>
      <p>
        These terms cover this website, including the{" "}
        <Link href={href("/viewer/")}>browser viewer</Link> and the guides. The {siteConfig.name}{" "}
        macOS application is distributed separately with its own repository and licence, and those
        terms govern the application itself.
      </p>

      <h2>Use of the site</h2>
      <p>
        The site is free to use and requires no account. You may read the guides, use the viewer for
        your own files, and link to any page. Please do not attempt to disrupt the site, use it to
        break the law, or present its content as your own work.
      </p>

      <h2>Your files</h2>
      <p>
        You keep every right in the workbooks you open in the viewer. Because the viewer parses your
        file inside your own browser and uploads nothing, no rights in your files are granted to
        anyone by using it. You are responsible for having the right to open a file you use here.
      </p>

      <h2>No warranty</h2>
      <p>
        The site and the viewer are provided as-is, without warranty of any kind. The viewer is a
        reader: it can misread an unusual workbook, it does not recalculate formulas, and it does not
        display charts, images or conditional formatting. Do not rely on it as the sole source for a
        decision that matters. Verify important numbers against an application that recalculates
        them.
      </p>
      <p>
        Nothing here is professional, financial or accounting advice. To the extent the law allows,
        the operator is not liable for loss arising from use of this site.
      </p>

      <h2>Availability and changes</h2>
      <p>
        This is a personal project. Pages may change, the viewer may change, and the site may be
        unavailable without notice. Content is corrected when it turns out to be wrong; material
        changes to these terms will be reflected on this page.
      </p>

      <h2>Third-party names</h2>
      <p>
        Microsoft, Excel, Apple, macOS and Numbers are trademarks of their respective owners.
        Mentioning them describes compatibility and does not imply any endorsement or affiliation.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about these terms go to <a href={contact.mailto}>{contact.email}</a>.
      </p>
    </div>
  );
}
