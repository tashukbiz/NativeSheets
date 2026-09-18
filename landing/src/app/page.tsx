import Link from "next/link";
import type { Metadata } from "next";
import { siteConfig } from "@/site/config";
import {
  benchmark,
  buildCommand,
  capabilities,
  download,
  installSteps,
  limitations,
  product,
} from "@/site/product";
import { articles, features, routeOf } from "@/site/content";
import { href } from "@/site/urls";
import { pageMetadata } from "@/site/metadata";
import { JsonLd } from "@/components/JsonLd";
import { softwareApplicationSchema } from "@/site/schema";
import { formatDate } from "@/components/ArticleLayout";

export const metadata: Metadata = pageMetadata({
  title: `${siteConfig.name} — ${siteConfig.tagline}`,
  description: siteConfig.description,
  route: "/",
});

export default function HomePage() {
  return (
    <>
      <JsonLd data={softwareApplicationSchema()} />

      <div className="container">
        <section className="hero">
          <div>
            <p className="eyebrow">Free · macOS · .xlsx</p>
            <h1>Open a spreadsheet without opening a spreadsheet suite</h1>
            <p className="lede">
              Native Sheets reads and edits .xlsx workbooks on macOS. It keeps the parts of a file
              it does not model instead of throwing them away. Download it, or read a workbook in
              your browser right now.
            </p>
            <p className="button-row" style={{ marginTop: "var(--step-3)" }}>
              <a className="button button--primary" href={download.url}>
                Download for macOS
              </a>
              <Link className="button button--secondary" href={href("/viewer/")}>
                Open a workbook in the browser
              </Link>
            </p>
            <ul className="fact-list">
              <li>
                Free. {product.minimumOS}, {product.architecture}. No account and no runtime to
                install.
              </li>
              <li>The browser viewer parses your file in the page. Nothing is sent anywhere.</li>
            </ul>
          </div>
          <GridIllustration />
        </section>
      </div>

      <section className="section section--surface">
        <div className="container">
          <h2 style={{ marginTop: 0 }}>Three steps to read a workbook here</h2>
          <ol className="grid" style={{ counterReset: "step" }}>
            {[
              {
                title: "Choose your file",
                body: "Pick an .xlsx file or drag it onto the page. The browser reads it from disk.",
              },
              {
                title: "Move between sheets",
                body: "Every worksheet in the workbook appears as a tab, in the workbook's own order.",
              },
              {
                title: "Read cells and formulas",
                body: "Click any cell for its address, its stored value and the formula behind it. Export the sheet as CSV.",
              },
            ].map((step) => (
              <li className="card" key={step.title}>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </li>
            ))}
          </ol>
          <p>
            <Link className="button button--primary" href={href("/viewer/")}>
              Start with a workbook
            </Link>
          </p>
        </div>
      </section>

      <section className="section">
        <div className="container">
          <h2 style={{ marginTop: 0 }}>What the macOS app does</h2>
          <p className="lede">
            Everything below is behaviour that exists in the app&rsquo;s code and its test suite.
          </p>
          <ul className="grid">
            {capabilities.map((capability) => (
              <li className="card" key={capability.id}>
                <h3>
                  {capability.route ? (
                    <Link href={href(capability.route)}>{capability.title}</Link>
                  ) : (
                    capability.title
                  )}
                </h3>
                <p>{capability.summary}</p>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="section section--surface">
        <div className="container">
          <h2 style={{ marginTop: 0 }}>Measured, not asserted</h2>
          <p className="prose">
            The numbers below come from the project&rsquo;s own sample workbook: {benchmark.workbook}
            , in a release build. They are reproducible from the repository rather than collected
            from users.
          </p>
          <div className="table-scroll" style={{ maxWidth: "var(--measure)" }}>
            <table>
              <caption>{benchmark.note}</caption>
              <thead>
                <tr>
                  <th scope="col">Operation</th>
                  <th scope="col">Result</th>
                </tr>
              </thead>
              <tbody>
                {benchmark.rows.map((row) => (
                  <tr key={row.label}>
                    <th scope="row">{row.label}</th>
                    <td>{row.value}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="container">
          <div style={{ display: "grid", gap: "var(--step-4)" }}>
            <div className="prose">
              <h2 style={{ marginTop: 0 }}>What it does not do</h2>
              <p>
                Knowing this before you install something is more useful than finding out
                afterwards.
              </p>
              <ul>
                {limitations.map((limitation) => (
                  <li key={limitation}>{limitation}</li>
                ))}
              </ul>
            </div>

            <div className="panel prose" id="download">
              <h2 style={{ marginTop: 0 }}>Getting the app</h2>
              <p>
                {product.accessNote} It needs {product.minimumOS} on {product.architecture}.
              </p>
              <p className="button-row">
                <a className="button button--primary" href={download.url}>
                  Download {download.fileName}
                </a>
              </p>
              <h3>Installing</h3>
              <ol>
                {installSteps.map((step) => (
                  <li key={step}>{step}</li>
                ))}
              </ol>
              <p>
                You only do step 4 once. Alternatively, build the app yourself from source with a
                Swift 6 toolchain (Xcode 16 or newer):
              </p>
              <pre>
                <code>{buildCommand}</code>
              </pre>
              <p>
                The source is on <a href={download.repositoryUrl}>GitHub</a>. If you would rather
                install nothing, the <Link href={href("/viewer/")}>browser viewer</Link> reads
                workbooks in this tab.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="section section--surface">
        <div className="container">
          <h2 style={{ marginTop: 0 }}>Questions people actually ask</h2>
          <div className="faq prose">
            <div>
              <h3>What does it cost?</h3>
              <p>
                Nothing. There is no paid tier, no trial, no subscription and no account. Nothing on
                this site asks for payment.
              </p>
            </div>
            <div>
              <h3>Does my file get uploaded when I use the viewer?</h3>
              <p>
                No. This site is a set of static files with no server to receive an upload. The
                workbook is decompressed and parsed inside the browser tab and discarded when you
                close it.
              </p>
            </div>
            <div>
              <h3>Will my formulas recalculate?</h3>
              <p>
                In the macOS app, if they use one of the 91 functions the engine evaluates.{" "}
                <Link href={href("/blog/will-my-formulas-work/")}>
                  The full list, and what is missing from it
                </Link>
                , is worth a minute before you decide. The browser viewer never recalculates; it
                shows the values stored in the file.
              </p>
            </div>
            <div>
              <h3>Which macOS versions?</h3>
              <p>
                {product.minimumOS}, on {product.architecture}. There is no Intel, Windows, Linux
                or iOS build of the editor. The browser viewer works in any current browser that
                supports decompression streams.
              </p>
            </div>
            <div>
              <h3>Is it on the App Store?</h3>
              <p>
                No. You download it from this site. Because the app is not notarised by Apple,
                macOS blocks the first launch until you allow it in Privacy &amp; Security. The{" "}
                <a href="#download">install steps</a> above cover it.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="container">
          <h2 style={{ marginTop: 0 }}>Guides</h2>
          <ul className="grid">
            {articles.map((article) => (
              <li className="card" key={article.id}>
                <p className="card__meta">
                  {article.category} · {article.datePublished && formatDate(article.datePublished)}
                </p>
                <h3>
                  <Link href={href(routeOf(article))}>{article.title}</Link>
                </h3>
                <p>{article.description}</p>
              </li>
            ))}
          </ul>
          <p className="button-row">
            <a className="button button--primary" href={download.url}>
              Download for macOS
            </a>
            <Link className="button button--secondary" href={href("/viewer/")}>
              Open a workbook in the browser
            </Link>
            <Link className="button button--secondary" href={href("/blog/")}>
              All guides
            </Link>
            {features.length > 0 && (
              <Link className="button button--secondary" href={href("/features/")}>
                Feature detail
              </Link>
            )}
          </p>
        </div>
      </section>
    </>
  );
}

/** A faithful sketch of a grid, not a screenshot: it depicts no specific build. */
function GridIllustration() {
  const columns = ["A", "B", "C", "D"];
  const rows = [
    ["Region", "Units", "Price", "Total"],
    ["North", "120", "4.50", "540.00"],
    ["South", "98", "4.50", "441.00"],
    ["East", "143", "4.25", "607.75"],
  ];
  return (
    <figure style={{ margin: 0 }}>
      <svg
        viewBox="0 0 520 300"
        width="520"
        height="300"
        role="img"
        aria-label="An illustration of a spreadsheet grid with a formula bar showing the total column computed with SUM"
        style={{ width: "100%", height: "auto", borderRadius: "var(--radius)", border: "1px solid var(--line)" }}
      >
        <rect width="520" height="300" fill="var(--paper)" />
        <rect width="520" height="34" fill="var(--surface-strong)" />
        <circle cx="18" cy="17" r="5" fill="var(--line-strong)" />
        <circle cx="36" cy="17" r="5" fill="var(--line-strong)" />
        <circle cx="54" cy="17" r="5" fill="var(--line-strong)" />
        <text x="250" y="22" fontSize="12" fill="var(--ink-faint)" fontFamily="sans-serif">
          quarterly.xlsx
        </text>
        <rect x="0" y="34" width="520" height="28" fill="var(--paper)" />
        <rect x="10" y="40" width="60" height="18" rx="3" fill="var(--surface)" stroke="var(--line)" />
        <text x="22" y="53" fontSize="11" fill="var(--ink-muted)" fontFamily="monospace">
          D2
        </text>
        <text x="84" y="53" fontSize="11" fill="var(--ink)" fontFamily="monospace">
          =B2*C2
        </text>
        {columns.map((column, index) => (
          <g key={column}>
            <rect
              x={60 + index * 110}
              y={62}
              width="110"
              height="26"
              fill="var(--surface-strong)"
              stroke="var(--line)"
            />
            <text
              x={115 + index * 110}
              y={79}
              fontSize="11"
              textAnchor="middle"
              fill="var(--ink-faint)"
              fontFamily="sans-serif"
            >
              {column}
            </text>
          </g>
        ))}
        {rows.map((row, rowIndex) => (
          <g key={rowIndex}>
            <rect x="0" y={88 + rowIndex * 32} width="60" height="32" fill="var(--surface-strong)" stroke="var(--line)" />
            <text x="30" y={108 + rowIndex * 32} fontSize="11" textAnchor="middle" fill="var(--ink-faint)" fontFamily="sans-serif">
              {rowIndex + 1}
            </text>
            {row.map((cell, cellIndex) => (
              <g key={cellIndex}>
                <rect
                  x={60 + cellIndex * 110}
                  y={88 + rowIndex * 32}
                  width="110"
                  height="32"
                  fill={rowIndex === 1 && cellIndex === 3 ? "var(--accent-wash)" : "var(--paper)"}
                  stroke="var(--line)"
                />
                <text
                  x={cellIndex === 0 ? 70 : 160 + cellIndex * 110}
                  y={108 + rowIndex * 32}
                  fontSize="12"
                  textAnchor={cellIndex === 0 ? "start" : "end"}
                  fill={rowIndex === 0 ? "var(--ink)" : "var(--ink-muted)"}
                  fontFamily="sans-serif"
                  fontWeight={rowIndex === 0 ? 600 : 400}
                >
                  {cell}
                </text>
              </g>
            ))}
          </g>
        ))}
        <rect x="0" y="216" width="520" height="84" fill="var(--paper)" />
        <rect x="10" y="226" width="90" height="26" rx="4" fill="var(--paper)" stroke="var(--accent)" />
        <text x="55" y="243" fontSize="11" textAnchor="middle" fill="var(--ink)" fontFamily="sans-serif">
          Q3
        </text>
        <rect x="106" y="226" width="90" height="26" rx="4" fill="var(--surface)" stroke="var(--line)" />
        <text x="151" y="243" fontSize="11" textAnchor="middle" fill="var(--ink-faint)" fontFamily="sans-serif">
          Q4
        </text>
        <rect x="202" y="226" width="90" height="26" rx="4" fill="var(--surface)" stroke="var(--line)" />
        <text x="247" y="243" fontSize="11" textAnchor="middle" fill="var(--ink-faint)" fontFamily="sans-serif">
          Notes
        </text>
      </svg>
      <figcaption style={{ fontSize: "0.8125rem", color: "var(--ink-faint)", marginTop: "0.5rem" }}>
        An illustration of the editing model: a formula bar, a grid, and sheet tabs along the
        bottom. It is a drawing, not a screenshot of a build.
      </figcaption>
    </figure>
  );
}
