import Foundation

public enum ZipError: Error, LocalizedError {
    case notAZipArchive
    case corruptEntry
    case unsupportedCompression(UInt16)
    case entryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .notAZipArchive: return "The file is not a valid .xlsx archive."
        case .corruptEntry: return "The archive contains a damaged entry."
        case .unsupportedCompression(let method):
            return "The archive uses an unsupported compression method (\(method))."
        case .entryNotFound(let name): return "The archive is missing \(name)."
        }
    }
}

/// One file inside the archive.
public struct ZipEntry: Sendable {
    public let name: String
    let compressionMethod: UInt16
    let crc32: UInt32
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
}

/// Reads a ZIP archive held in memory.
///
/// Entries are inflated on demand: opening a workbook only pays for the parts
/// that are actually read.
public struct ZipArchive {
    private let data: Data
    public let entries: [ZipEntry]
    private let index: [String: Int]

    public init(data: Data) throws {
        self.data = data
        self.entries = try ZipArchive.readCentralDirectory(data)
        var index: [String: Int] = [:]
        for (position, entry) in entries.enumerated() { index[entry.name] = position }
        self.index = index
    }

    public init(url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .mappedIfSafe))
    }

    public var entryNames: [String] { entries.map(\.name) }

    public func contains(_ name: String) -> Bool { index[name] != nil }

    public func data(for name: String) throws -> Data {
        guard let position = index[name] else { throw ZipError.entryNotFound(name) }
        return try read(entries[position])
    }

    public func read(_ entry: ZipEntry) throws -> Data {
        var reader = ByteReader(data)
        try reader.seek(to: entry.localHeaderOffset)
        guard try reader.readU32() == 0x0403_4B50 else { throw ZipError.corruptEntry }
        try reader.skip(22)
        let nameLength = Int(try reader.readU16())
        let extraLength = Int(try reader.readU16())
        try reader.skip(nameLength + extraLength)
        let payload = try reader.readBytes(entry.compressedSize)

        switch entry.compressionMethod {
        case 0:
            return payload
        case 8:
            return try Deflate.decompress(payload, expectedSize: entry.uncompressedSize)
        default:
            throw ZipError.unsupportedCompression(entry.compressionMethod)
        }
    }

    // MARK: - Central directory

    private static func readCentralDirectory(_ data: Data) throws -> [ZipEntry] {
        guard let eocdOffset = findEndOfCentralDirectory(data) else { throw ZipError.notAZipArchive }

        var reader = ByteReader(data)
        try reader.seek(to: eocdOffset + 10)
        var entryCount = Int(try reader.readU16())
        try reader.skip(4)
        var directoryOffset = Int(try reader.readU32())

        if entryCount == 0xFFFF || directoryOffset == 0xFFFF_FFFF {
            (entryCount, directoryOffset) = try readZip64Locator(data, eocdOffset: eocdOffset)
        }

        var directory = ByteReader(data)
        try directory.seek(to: directoryOffset)
        var entries: [ZipEntry] = []
        entries.reserveCapacity(entryCount)

        for _ in 0..<entryCount {
            guard try directory.readU32() == 0x0201_4B50 else { break }
            try directory.skip(6)
            let method = try directory.readU16()
            try directory.skip(4)
            let crc = try directory.readU32()
            var compressedSize = Int(try directory.readU32())
            var uncompressedSize = Int(try directory.readU32())
            let nameLength = Int(try directory.readU16())
            let extraLength = Int(try directory.readU16())
            let commentLength = Int(try directory.readU16())
            try directory.skip(8)
            var localOffset = Int(try directory.readU32())
            let nameBytes = try directory.readBytes(nameLength)
            let extra = try directory.readBytes(extraLength)
            try directory.skip(commentLength)

            if compressedSize == 0xFFFF_FFFF || uncompressedSize == 0xFFFF_FFFF || localOffset == 0xFFFF_FFFF {
                applyZip64Extra(
                    extra,
                    uncompressedSize: &uncompressedSize,
                    compressedSize: &compressedSize,
                    localOffset: &localOffset
                )
            }

            let name = String(decoding: nameBytes, as: UTF8.self)
            entries.append(ZipEntry(
                name: name,
                compressionMethod: method,
                crc32: crc,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localOffset
            ))
        }
        return entries
    }

    private static func findEndOfCentralDirectory(_ data: Data) -> Int? {
        let count = data.count
        guard count >= 22 else { return nil }
        let lowestStart = max(0, count - 22 - 65535)
        var offset = count - 22
        let base = data.startIndex
        while offset >= lowestStart {
            if data[base + offset] == 0x50, data[base + offset + 1] == 0x4B,
               data[base + offset + 2] == 0x05, data[base + offset + 3] == 0x06 {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func readZip64Locator(_ data: Data, eocdOffset: Int) throws -> (count: Int, offset: Int) {
        guard eocdOffset >= 20 else { throw ZipError.corruptEntry }
        var locator = ByteReader(data)
        try locator.seek(to: eocdOffset - 20)
        guard try locator.readU32() == 0x0706_4B50 else { throw ZipError.corruptEntry }
        try locator.skip(4)
        let zip64Offset = Int(try locator.readU64())

        var record = ByteReader(data)
        try record.seek(to: zip64Offset)
        guard try record.readU32() == 0x0606_4B50 else { throw ZipError.corruptEntry }
        try record.skip(28)
        let count = Int(try record.readU64())
        try record.skip(8)
        let directoryOffset = Int(try record.readU64())
        return (count, directoryOffset)
    }

    /// Zip64 extended information (header id 0x0001) restores whichever of the
    /// three fields were parked at their 32-bit sentinel, in a fixed order.
    private static func applyZip64Extra(
        _ extra: Data,
        uncompressedSize: inout Int,
        compressedSize: inout Int,
        localOffset: inout Int
    ) {
        var reader = ByteReader(extra)
        while let headerID = try? reader.readU16(), let size = try? reader.readU16() {
            let fieldEnd = reader.position + Int(size)
            if headerID == 0x0001 {
                if uncompressedSize == 0xFFFF_FFFF, let value = try? reader.readU64() {
                    uncompressedSize = Int(value)
                }
                if compressedSize == 0xFFFF_FFFF, let value = try? reader.readU64() {
                    compressedSize = Int(value)
                }
                if localOffset == 0xFFFF_FFFF, let value = try? reader.readU64() {
                    localOffset = Int(value)
                }
                return
            }
            guard (try? reader.seek(to: fieldEnd)) != nil else { return }
        }
    }
}
