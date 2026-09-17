"use client";

import { useCallback, useId, useMemo, useRef, useState } from "react";
import {
  MAX_ROWS,
  XlsxError,
  columnName,
  readWorkbook,
  sheetToCsv,
  type ParsedWorkbook,
} from "@/lib/xlsx";
import { track } from "@/site/analytics";

type Status =
  | { kind: "idle" }
  | { kind: "reading"; name: string }
  | { kind: "ready"; workbook: ParsedWorkbook }
  | { kind: "error"; message: string };

interface Selection {
  row: number;
  column: number;
}

export function WorkbookViewer() {
  const [status, setStatus] = useState<Status>({ kind: "idle" });
  const [sheetIndex, setSheetIndex] = useState(0);
  const [selection, setSelection] = useState<Selection | null>(null);
  const [dragging, setDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const inputId = useId();

  const open = useCallback(async (file: File) => {
    setStatus({ kind: "reading", name: file.name });
    setSheetIndex(0);
    setSelection(null);
    track("tool_start", { tool_id: "viewer", placement: "viewer-page" });
    try {
      const workbook = await readWorkbook(file);
      setStatus({ kind: "ready", workbook });
      track("tool_complete", { tool_id: "viewer", outcome: "workbook_opened" });
    } catch (error) {
      const message =
        error instanceof XlsxError
          ? error.message
          : "This file could not be read. It may not be an .xlsx workbook.";
      setStatus({ kind: "error", message });
      track("tool_complete", { tool_id: "viewer", outcome: "read_failed" });
    }
  }, []);

  const reset = useCallback(() => {
    setStatus({ kind: "idle" });
    setSelection(null);
    setSheetIndex(0);
    if (inputRef.current) inputRef.current.value = "";
  }, []);

  const workbook = status.kind === "ready" ? status.workbook : null;
  const sheet = workbook?.sheets[sheetIndex] ?? null;

  const downloadCsv = useCallback(() => {
    if (!sheet || !workbook) return;
    const blob = new Blob([sheetToCsv(sheet)], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `${sheet.name.replace(/[^\w.-]+/g, "-")}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
    track("tool_complete", { tool_id: "viewer", outcome: "csv_exported" });
  }, [sheet, workbook]);

  const selectedCell = useMemo(() => {
    if (!sheet || !selection) return null;
    const cell = sheet.rows[selection.row]?.[selection.column];
    return {
      address: `${columnName(selection.column)}${selection.row + 1}`,
      value: cell?.text ?? "",
      formula: cell?.formula ?? "",
    };
  }, [sheet, selection]);

  return (
    <div className="viewer">
      <div
        className={dragging ? "dropzone dropzone--active" : "dropzone"}
        onDragOver={(event) => {
          event.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(event) => {
          event.preventDefault();
          setDragging(false);
          const file = event.dataTransfer.files[0];
          if (file) void open(file);
        }}
      >
        <label className="button button--primary" htmlFor={inputId}>
          Choose an .xlsx file
        </label>
        <input
          ref={inputRef}
          id={inputId}
          type="file"
          accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          className="visually-hidden"
          onChange={(event) => {
            const file = event.target.files?.[0];
            if (file) void open(file);
          }}
        />
        <p>or drag a workbook here. It is read on this device and never uploaded.</p>
      </div>

      <div aria-live="polite">
        {status.kind === "reading" && (
          <p className="viewer-status">Reading {status.name}…</p>
        )}
        {status.kind === "error" && (
          <p className="viewer-status viewer-status--error">
            {status.message}{" "}
            <button type="button" className="link-like" onClick={reset}>
              Try another file
            </button>
          </p>
        )}
        {status.kind === "idle" && (
          <p className="viewer-status">No workbook open. Choose a file to begin.</p>
        )}
      </div>

      {workbook && sheet && (
        <>
          <div className="viewer-toolbar">
            <p className="viewer-toolbar__facts">
              <strong>{workbook.fileName}</strong> · {formatBytes(workbook.fileSize)} ·{" "}
              {workbook.sheets.length} {workbook.sheets.length === 1 ? "sheet" : "sheets"}
              {workbook.carriedParts.length > 0 && (
                <> · contains {workbook.carriedParts.join(", ")}, which this viewer does not draw</>
              )}
            </p>
            <div className="button-row">
              <button type="button" className="button button--secondary" onClick={downloadCsv}>
                Download this sheet as CSV
              </button>
              <button type="button" className="button button--secondary" onClick={reset}>
                Close workbook
              </button>
            </div>
          </div>

          <div className="sheet-tabs" role="tablist" aria-label="Sheets">
            {workbook.sheets.map((candidate, index) => (
              <button
                key={`${candidate.name}-${index}`}
                type="button"
                role="tab"
                className="sheet-tab"
                aria-selected={index === sheetIndex}
                onClick={() => {
                  setSheetIndex(index);
                  setSelection(null);
                }}
              >
                {candidate.name}
              </button>
            ))}
          </div>

          {sheet.rowCount === 0 ? (
            <p className="viewer-status">This sheet has no cells with content.</p>
          ) : (
            <div className="grid-scroll" tabIndex={0} role="group" aria-label={`Sheet ${sheet.name}`}>
              <table className="cell-grid">
                <caption className="visually-hidden">
                  {sheet.name}, {sheet.rowCount} rows by {sheet.columnCount} columns
                </caption>
                <thead>
                  <tr>
                    <th scope="col">
                      <span className="visually-hidden">Row</span>
                    </th>
                    {Array.from({ length: sheet.columnCount }, (_, index) => (
                      <th key={index} scope="col">
                        {columnName(index)}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {sheet.rows.map((row, rowIndex) => (
                    <tr key={rowIndex}>
                      <th scope="row">{rowIndex + 1}</th>
                      {Array.from({ length: sheet.columnCount }, (_, columnIndex) => {
                        const cell = row[columnIndex];
                        const isSelected =
                          selection?.row === rowIndex && selection.column === columnIndex;
                        return (
                          <td
                            key={columnIndex}
                            className={cell?.numeric ? "is-number" : undefined}
                            aria-selected={isSelected}
                            title={cell?.formula ? `=${cell.formula}` : undefined}
                            onClick={() => setSelection({ row: rowIndex, column: columnIndex })}
                          >
                            {cell?.text ?? ""}
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <dl className="cell-readout">
            <div>
              <dt style={{ display: "inline" }}>Cell</dt>
              <dd>{selectedCell?.address ?? "—"}</dd>
            </div>
            <div>
              <dt style={{ display: "inline" }}>Value</dt>
              <dd>{selectedCell?.value || "empty"}</dd>
            </div>
            <div>
              <dt style={{ display: "inline" }}>Formula</dt>
              <dd>{selectedCell?.formula ? `=${selectedCell.formula}` : "none"}</dd>
            </div>
          </dl>

          {sheet.truncated && (
            <p className="viewer-status">
              This sheet is larger than the viewer displays. The first {MAX_ROWS.toLocaleString()}{" "}
              rows are shown; the CSV export contains the same visible range.
            </p>
          )}
        </>
      )}
    </div>
  );
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} bytes`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
