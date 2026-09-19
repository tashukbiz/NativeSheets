import Foundation

/// Little-endian cursor over a `Data` buffer, indexed from zero regardless of
/// the buffer's own `startIndex`.
struct ByteReader {
    private let data: Data
    private let base: Data.Index
    private(set) var position: Int = 0

    init(_ data: Data) {
        self.data = data
        self.base = data.startIndex
    }

    var count: Int { data.count }

    mutating func seek(to offset: Int) throws {
        guard offset >= 0, offset <= data.count else { throw ZipError.corruptEntry }
        position = offset
    }

    mutating func skip(_ bytes: Int) throws {
        try seek(to: position + bytes)
    }

    mutating func readBytes(_ count: Int) throws -> Data {
        guard count >= 0, position + count <= data.count else { throw ZipError.corruptEntry }
        let start = base + position
        position += count
        return data[start..<(start + count)]
    }

    mutating func readU16() throws -> UInt16 {
        let bytes = try readBytes(2)
        return bytes.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: UInt8.self)
            return UInt16(buffer[0]) | (UInt16(buffer[1]) << 8)
        }
    }

    mutating func readU32() throws -> UInt32 {
        let bytes = try readBytes(4)
        return bytes.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: UInt8.self)
            var value: UInt32 = 0
            for index in (0..<4).reversed() { value = (value << 8) | UInt32(buffer[index]) }
            return value
        }
    }

    mutating func readU64() throws -> UInt64 {
        let bytes = try readBytes(8)
        return bytes.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: UInt8.self)
            var value: UInt64 = 0
            for index in (0..<8).reversed() { value = (value << 8) | UInt64(buffer[index]) }
            return value
        }
    }
}
