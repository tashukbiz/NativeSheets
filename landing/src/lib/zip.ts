/**
 * A minimal reader for the ZIP container an .xlsx file is. Only what a
 * spreadsheet package uses: stored and deflated entries, with the Zip64 size
 * fields handled when a producer writes them.
 */

const EOCD_SIGNATURE = 0x06054b50;
const CENTRAL_SIGNATURE = 0x02014b50;
const ZIP64_EOCD_LOCATOR_SIGNATURE = 0x07064b50;
const ZIP64_EOCD_SIGNATURE = 0x06064b50;

export class ZipError extends Error {}

interface ZipEntry {
  name: string;
  compressionMethod: number;
  compressedSize: number;
  localHeaderOffset: number;
}

export class ZipArchive {
  private constructor(
    private readonly bytes: Uint8Array,
    private readonly entries: Map<string, ZipEntry>,
  ) {}

  static open(buffer: ArrayBuffer): ZipArchive {
    const bytes = new Uint8Array(buffer);
    const view = new DataView(buffer);
    const eocd = findEndOfCentralDirectory(view, bytes.length);
    const entries = new Map<string, ZipEntry>();

    let offset = eocd.centralDirectoryOffset;
    for (let index = 0; index < eocd.entryCount; index += 1) {
      if (offset + 46 > bytes.length || view.getUint32(offset, true) !== CENTRAL_SIGNATURE) {
        throw new ZipError("The central directory of this file is damaged or not a ZIP archive.");
      }
      const compressionMethod = view.getUint16(offset + 10, true);
      let compressedSize = view.getUint32(offset + 20, true);
      const nameLength = view.getUint16(offset + 28, true);
      const extraLength = view.getUint16(offset + 30, true);
      const commentLength = view.getUint16(offset + 32, true);
      let localHeaderOffset = view.getUint32(offset + 42, true);
      const name = decodeName(bytes.subarray(offset + 46, offset + 46 + nameLength));

      if (compressedSize === 0xffffffff || localHeaderOffset === 0xffffffff) {
        const zip64 = readZip64Extra(
          view,
          offset + 46 + nameLength,
          extraLength,
          view.getUint32(offset + 24, true) === 0xffffffff,
          compressedSize === 0xffffffff,
          localHeaderOffset === 0xffffffff,
        );
        if (zip64.compressedSize !== undefined) compressedSize = zip64.compressedSize;
        if (zip64.localHeaderOffset !== undefined) localHeaderOffset = zip64.localHeaderOffset;
      }

      entries.set(name, { name, compressionMethod, compressedSize, localHeaderOffset });
      offset += 46 + nameLength + extraLength + commentLength;
    }

    return new ZipArchive(bytes, entries);
  }

  has(name: string): boolean {
    return this.entries.has(name);
  }

  names(): string[] {
    return [...this.entries.keys()];
  }

  /** Inflates one entry and decodes it as UTF-8 text. */
  async text(name: string): Promise<string> {
    const entry = this.entries.get(name);
    if (!entry) throw new ZipError(`This workbook has no part named ${name}.`);

    const view = new DataView(this.bytes.buffer, this.bytes.byteOffset, this.bytes.byteLength);
    const header = entry.localHeaderOffset;
    const nameLength = view.getUint16(header + 26, true);
    const extraLength = view.getUint16(header + 28, true);
    const start = header + 30 + nameLength + extraLength;
    const compressed = this.bytes.subarray(start, start + entry.compressedSize);

    if (entry.compressionMethod === 0) return new TextDecoder().decode(compressed);
    if (entry.compressionMethod !== 8) {
      throw new ZipError(
        `Part ${name} uses an unsupported compression method (${entry.compressionMethod}).`,
      );
    }
    return inflate(compressed);
  }
}

async function inflate(compressed: Uint8Array): Promise<string> {
  if (typeof DecompressionStream === "undefined") {
    throw new ZipError(
      "This browser cannot decompress ZIP data. A current version of Safari, Chrome, Edge or Firefox is needed.",
    );
  }
  const stream = new Blob([compressed as BlobPart])
    .stream()
    .pipeThrough(new DecompressionStream("deflate-raw"));
  return new Response(stream).text();
}

function decodeName(bytes: Uint8Array): string {
  return new TextDecoder("utf-8").decode(bytes);
}

interface EndOfCentralDirectory {
  entryCount: number;
  centralDirectoryOffset: number;
}

function findEndOfCentralDirectory(view: DataView, length: number): EndOfCentralDirectory {
  const earliest = Math.max(0, length - 65557);
  for (let offset = length - 22; offset >= earliest; offset -= 1) {
    if (view.getUint32(offset, true) !== EOCD_SIGNATURE) continue;
    let entryCount = view.getUint16(offset + 10, true);
    let centralDirectoryOffset = view.getUint32(offset + 16, true);

    if (entryCount === 0xffff || centralDirectoryOffset === 0xffffffff) {
      const zip64 = findZip64EndOfCentralDirectory(view, offset);
      entryCount = zip64.entryCount;
      centralDirectoryOffset = zip64.centralDirectoryOffset;
    }
    return { entryCount, centralDirectoryOffset };
  }
  throw new ZipError("This file is not a ZIP archive, so it is not an .xlsx workbook.");
}

function findZip64EndOfCentralDirectory(view: DataView, eocdOffset: number): EndOfCentralDirectory {
  const locator = eocdOffset - 20;
  if (locator < 0 || view.getUint32(locator, true) !== ZIP64_EOCD_LOCATOR_SIGNATURE) {
    throw new ZipError("This archive claims Zip64 but has no Zip64 locator.");
  }
  const zip64Offset = Number(view.getBigUint64(locator + 8, true));
  if (view.getUint32(zip64Offset, true) !== ZIP64_EOCD_SIGNATURE) {
    throw new ZipError("The Zip64 end-of-central-directory record is damaged.");
  }
  return {
    entryCount: Number(view.getBigUint64(zip64Offset + 32, true)),
    centralDirectoryOffset: Number(view.getBigUint64(zip64Offset + 48, true)),
  };
}

/** Zip64 extra fields are positional: only the overflowed values are present. */
function readZip64Extra(
  view: DataView,
  extraStart: number,
  extraLength: number,
  hasUncompressed: boolean,
  hasCompressed: boolean,
  hasOffset: boolean,
): { compressedSize?: number; localHeaderOffset?: number } {
  let cursor = extraStart;
  const end = extraStart + extraLength;
  while (cursor + 4 <= end) {
    const id = view.getUint16(cursor, true);
    const size = view.getUint16(cursor + 2, true);
    if (id !== 0x0001) {
      cursor += 4 + size;
      continue;
    }
    let field = cursor + 4;
    const result: { compressedSize?: number; localHeaderOffset?: number } = {};
    if (hasUncompressed) field += 8;
    if (hasCompressed) {
      result.compressedSize = Number(view.getBigUint64(field, true));
      field += 8;
    }
    if (hasOffset) {
      result.localHeaderOffset = Number(view.getBigUint64(field, true));
    }
    return result;
  }
  return {};
}
