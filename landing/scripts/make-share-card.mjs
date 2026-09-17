/**
 * Renders the 1200x630 social card to public/share-card.png.
 *
 * Social platforms do not reliably render SVG share images, so the card is
 * rasterised at build time from the same markup the site's tokens describe.
 */
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { Resvg } from "@resvg/resvg-js";

const output = resolve(process.cwd(), "public/share-card.png");

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="#ffffff"/>
  <rect x="0" y="0" width="1200" height="14" fill="#0a6b51"/>
  <g font-family="Helvetica, Arial, sans-serif">
    <text x="80" y="150" font-size="30" fill="#0a6b51" letter-spacing="4">FREE · MACOS · .XLSX</text>
    <text x="80" y="250" font-size="74" font-weight="700" fill="#16191c">Native Sheets</text>
    <text x="80" y="330" font-size="40" fill="#4d5560">A native macOS editor for .xlsx files,</text>
    <text x="80" y="386" font-size="40" fill="#4d5560">and a browser viewer that uploads nothing.</text>
  </g>
  <g transform="translate(80 452)">
    <rect width="1040" height="120" rx="12" fill="#f6f7f5" stroke="#d9ddd6"/>
    <line x1="0" y1="44" x2="1040" y2="44" stroke="#d9ddd6"/>
    <line x1="0" y1="82" x2="1040" y2="82" stroke="#d9ddd6"/>
    <line x1="140" y1="0" x2="140" y2="120" stroke="#d9ddd6"/>
    <line x1="420" y1="0" x2="420" y2="120" stroke="#d9ddd6"/>
    <line x1="700" y1="0" x2="700" y2="120" stroke="#d9ddd6"/>
    <rect x="420" y="44" width="280" height="38" fill="#e7f2ed"/>
    <g font-family="Helvetica, Arial, sans-serif" font-size="24" fill="#4d5560">
      <text x="24" y="30">A</text>
      <text x="164" y="30">B</text>
      <text x="444" y="30">C</text>
      <text x="724" y="30">D</text>
      <text x="164" y="70">Region</text>
      <text x="444" y="70" fill="#0a6b51">=SUM(B2:B9)</text>
      <text x="724" y="70">Total</text>
      <text x="164" y="108">North</text>
      <text x="444" y="108">540.00</text>
      <text x="724" y="108">4.50</text>
    </g>
  </g>
</svg>`;

const png = new Resvg(svg, { fitTo: { mode: "width", value: 1200 } }).render().asPng();
await mkdir(dirname(output), { recursive: true });
await writeFile(output, png);
console.log(`Wrote ${output} (${png.length} bytes)`);
