import Link from "next/link";
import type { Metadata } from "next";
import { contact, integrations, siteConfig } from "@/site/config";
import { href } from "@/site/urls";
import { pageMetadata } from "@/site/metadata";
import { ConsentPreferencesLink } from "@/components/ConsentManager";

const title = "Privacy";
const description =
  "What this site does and does not collect, what happens to a workbook you open in the browser viewer, and how to change any choice you have made.";

export const metadata: Metadata = pageMetadata({ title, description, route: "/privacy/" });

const analyticsEnabled = integrations.analytics.enabled;
const adsState = integrations.ads.state;
const adsLive = adsState === "live";

export default function PrivacyPage() {
  return (
    <div className="container section--tight prose">
      <h1>Privacy</h1>
      <p className="lede">{description}</p>
      <p className="article-meta">
        This page describes how the site behaves as it is deployed now. It is updated when that
        behaviour changes, not on a schedule.
      </p>

      <h2>The short version</h2>
      <ul>
        <li>Workbooks you open in the browser viewer are never uploaded.</li>
        <li>There is no account, no login and no newsletter.</li>
        <li>
          {analyticsEnabled
            ? "Measurement runs only if you allow it."
            : "No analytics or measurement service is configured, so none runs."}
        </li>
        <li>
          {adsLive
            ? "Advertising is served only if you allow it."
            : `Advertising is currently ${adsState}: no advertising script is loaded and no ad request is made.`}
        </li>
      </ul>

      <h2>Files you open in the viewer</h2>
      <p>
        The <Link href={href("/viewer/")}>XLSX viewer</Link> reads your file with the browser&rsquo;s
        own file API. The workbook is decompressed and parsed inside the page, and the result stays
        in the tab&rsquo;s memory. It is not transmitted anywhere. This site is served as static
        files and has no server-side component that could receive a file, and no file name, sheet
        name or cell value is included in anything the site sends.
      </p>
      <p>
        When you close or reload the tab, the parsed workbook is discarded. A CSV you export is
        generated in the browser and saved by your own browser&rsquo;s download handling.
      </p>

      <h2>Hosting and server logs</h2>
      <p>
        The site is hosted as static files on GitHub Pages, operated by GitHub, Inc. Like any web
        host, it receives the technical information your browser sends in order to serve a page,
        including your IP address and user agent. That processing is GitHub&rsquo;s, under its own
        terms and privacy practices, and this project has no access to those logs and does not
        receive a copy of them.
      </p>

      <h2>Storage on your device</h2>
      {analyticsEnabled || adsLive ? (
        <p>
          If you make a privacy choice, it is saved in your browser&rsquo;s local storage under a
          single key so the site does not ask again. It contains your choices and the time you made
          them, nothing else. Clearing your browser storage removes it and the site will ask again.
        </p>
      ) : (
        <p>
          Nothing. With no measurement or advertising configured, the site sets no cookies and
          writes nothing to local storage.
        </p>
      )}

      <h2>Measurement</h2>
      {analyticsEnabled ? (
        <>
          <p>
            Measurement uses Google Analytics 4, provided by Google. It loads only after you allow
            it, and it does not load at all before a choice is made. It records which pages are
            viewed, how the viewer is used in coarse terms (a workbook was opened, a read failed, a
            CSV was exported), and standard technical information the provider collects.
          </p>
          <p>
            Page addresses are stripped of query strings and fragments before they are sent. File
            names, sheet names, cell contents and anything else from a workbook are never included.
          </p>
        </>
      ) : (
        <p>
          No measurement or analytics service is configured for this site, so no analytics script is
          loaded and no measurement request is made. If that changes, this page will describe the
          provider and what it receives before the change takes effect, and you will be asked first.
        </p>
      )}

      <h2>Advertising</h2>
      {adsLive ? (
        <p>
          Advertising is served by Google AdSense on guide, feature and tool pages. Ad requests are
          made only after you permit advertising. Google may set and read cookies or similar
          identifiers to serve and measure ads; its own policies govern that processing.
        </p>
      ) : (
        <p>
          This site is built to carry advertising on its guide, feature and tool pages, but
          advertising is currently <strong>{adsState}</strong>. No advertising script is loaded, no
          ad request is made and no advertising identifier is set. Should advertising be switched
          on, ads would be labelled, kept out of the viewer&rsquo;s controls, and requested only
          after you permit them, and this page would name the provider first.
        </p>
      )}

      <h2>Your choices</h2>
      {analyticsEnabled || adsLive ? (
        <p>
          You can change or withdraw any choice at any time: <ConsentPreferencesLink />. Withdrawing
          stops further measurement and advertising requests and clears the identifiers this site can
          reach from your browser. It cannot delete records a provider has already stored; for that,
          use the provider&rsquo;s own controls.
        </p>
      ) : (
        <p>
          There is nothing optional to turn off at the moment, so the site does not ask you for
          anything. The viewer has never depended on any choice and never will: it is the free part
          of this site.
        </p>
      )}
      <p>
        If your browser sends a privacy signal such as Global Privacy Control, the site treats it as
        a refusal of optional processing and does not ask again in that session.
      </p>

      <h2>Children</h2>
      <p>
        {siteConfig.name} is aimed at people who work with spreadsheet files, not at children. The
        site does not knowingly collect information from children, and it has no accounts or
        profiles through which it could.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about this page go to <a href={contact.mailto}>{contact.email}</a>. It is a
        single-person project, so replies are not immediate.
      </p>
    </div>
  );
}
