import Link from "next/link";
import { Fragment, type ReactNode } from "react";
import type { Block, Inline } from "@/site/content/types";
import { href } from "@/site/urls";

function renderInline(content: Inline[]): ReactNode {
  return content.map((part, index) => {
    if (typeof part === "string") return <Fragment key={index}>{part}</Fragment>;
    if ("code" in part) return <code key={index}>{part.code}</code>;
    if ("strong" in part) return <strong key={index}>{part.strong}</strong>;
    if (part.external) {
      return (
        <a key={index} href={part.href} rel="noopener">
          {part.text}
        </a>
      );
    }
    return (
      <Link key={index} href={href(part.href)}>
        {part.text}
      </Link>
    );
  });
}

export function Blocks({ blocks }: { blocks: Block[] }) {
  return (
    <>
      {blocks.map((block, index) => (
        <BlockView key={index} block={block} />
      ))}
    </>
  );
}

function BlockView({ block }: { block: Block }) {
  switch (block.kind) {
    case "heading":
      return <h2 id={block.id}>{block.text}</h2>;
    case "paragraph":
      return <p>{renderInline(block.content)}</p>;
    case "list":
      return block.ordered ? (
        <ol>
          {block.items.map((item, index) => (
            <li key={index}>{renderInline(item)}</li>
          ))}
        </ol>
      ) : (
        <ul>
          {block.items.map((item, index) => (
            <li key={index}>{renderInline(item)}</li>
          ))}
        </ul>
      );
    case "table":
      return (
        <div className="table-scroll">
          <table>
            {block.caption && <caption>{block.caption}</caption>}
            <thead>
              <tr>
                {block.head.map((cell) => (
                  <th key={cell} scope="col">
                    {cell}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {block.rows.map((row, rowIndex) => (
                <tr key={rowIndex}>
                  {row.map((cell, cellIndex) => (
                    <td key={cellIndex}>{cell}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    case "code":
      return (
        <pre>
          <code>{block.code}</code>
        </pre>
      );
    case "note":
      return (
        <div className="note">
          <h3>{block.title}</h3>
          <p>{renderInline(block.content)}</p>
        </div>
      );
    case "faq":
      return (
        <div className="faq">
          {block.items.map((item) => (
            <div key={item.question}>
              <h3>{item.question}</h3>
              <p>{renderInline(item.answer)}</p>
            </div>
          ))}
        </div>
      );
  }
}
