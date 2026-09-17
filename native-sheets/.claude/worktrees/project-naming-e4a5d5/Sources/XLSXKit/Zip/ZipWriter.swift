import Foundation

/// Builds a ZIP archive in memory.
///
/// Entries keep the order they are given: OOXML requires `[Content_Types].xml`
/// to come first, and some readers rely on it.
public struct ZipWriter {
    public struct Entry {
        public let name: String
        public let data: Data
        /// Already-compressed parts (images, embedded archives) only grow when
        /// deflated again.
        public let compress: Bool

        public init(name: String, data: Data, compress: Bool = true) {
            self.name = name
            self.data = data
            self.compress = compress
        }
    }

    private struct DirectoryRecord {
        let name: Data
        let method: UInt16
        let crc: UInt32
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
    }

    public static func archive(_ entries: [Entry], modified: Date = Date()) -> Data {
        var output = Data()
        var records: [DirectoryRecord] = []
        records.reserveCapacity(entries.count)
        let (dosTime, dosDate) = dosTimestamp(modified)

        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            let crc = CRC32.checksum(entry.data)
            var method: UInt16 = 0
            var payload = entry.data

            if entry.compress, !entry.data.isEmpty,
               let deflated = Deflate.compress(entry.data), deflated.count < entry.data.count {
                method = 8
                payload = deflated
            }

            let record = DirectoryRecord(
                name: nameBytes,
                method: method,
                crc: crc,
                compressedSize: payload.count,
                uncompressedSize: entry.data.count,
                localOffset: output.count
            )
            records.append(record)

            let needsZip64 = record.compressedSize >= 0xFFFF_FFFF || record.uncompressedSize >= 0xFFFF_FFFF
            let zip64Extra = needsZip64
                ? zip64ExtraField(uncompressed: record.uncompressedSize, compressed: record.compressedSize, offset: nil)
                : Data()

            output.appendU32(0x0403_4B50)
            output.appendU16(needsZip64 ? 45 : 20)
            output.appendU16(0x0800)  // UTF-8 file names
            output.appendU16(method)
            output.appendU16(dosTime)
            output.appendU16(dosDate)
            output.appendU32(crc)
            output.appendU32(needsZip64 ? 0xFFFF_FFFF : UInt32(record.compressedSize))
            output.appendU32(needsZip64 ? 0xFFFF_FFFF : UInt32(record.uncompressedSize))
            output.appendU16(UInt16(nameBytes.count))
            output.appendU16(UInt16(zip64Extra.count))
            output.append(nameBytes)
            output.append(zip64Extra)
            output.append(payload)
        }

        let directoryOffset = output.count
        for record in records {
            let bigSizes = record.compressedSize >= 0xFFFF_FFFF || record.uncompressedSize >= 0xFFFF_FFFF
            let bigOffset = record.localOffset >= 0xFFFF_FFFF
            let extra = (bigSizes || bigOffset)
                ? zip64ExtraField(
                    uncompressed: bigSizes ? record.uncompressedSize : nil,
                    compressed: bigSizes ? record.compressedSize : nil,
                    offset: bigOffset ? record.localOffset : nil
                )
                : Data()

            output.appendU32(0x0201_4B50)
            output.appendU16(0x031E)  // made by UNIX, spec 3.0
            output.appendU16((bigSizes || bigOffset) ? 45 : 20)
            output.appendU16(0x0800)
            output.appendU16(record.method)
            output.appendU16(dosTime)
            output.appendU16(dosDate)
            output.appendU32(record.crc)
            output.appendU32(bigSizes ? 0xFFFF_FFFF : UInt32(record.compressedSize))
            output.appendU32(bigSizes ? 0xFFFF_FFFF : UInt32(record.uncompressedSize))
            output.appendU16(UInt16(record.name.count))
            output.appendU16(UInt16(extra.count))
            output.appendU16(0)  // comment length
            output.appendU16(0)  // disk number
            output.appendU16(0)  // internal attributes
            output.appendU32(0x8180_0000)  // external attributes: -rw-r--r--
            output.appendU32(bigOffset ? 0xFFFF_FFFF : UInt32(record.localOffset))
            output.append(record.name)
            output.append(extra)
        }
        let directorySize = output.count - directoryOffset

        let needsZip64EOCD = records.count >= 0xFFFF
            || directoryOffset >= 0xFFFF_FFFF
            || directorySize >= 0xFFFF_FFFF
        if needsZip64EOCD {
            let zip64EOCDOffset = output.count
            output.appendU32(0x0606_4B50)
            output.appendU64(44)  // size of the remainder of this record
            output.appendU16(0x031E)
            output.appendU16(45)
            output.appendU32(0)
            output.appendU32(0)
            output.appendU64(UInt64(records.count))
            output.appendU64(UInt64(records.count))
            output.appendU64(UInt64(directorySize))
            output.appendU64(UInt64(directoryOffset))

            output.appendU32(0x0706_4B50)
            output.appendU32(0)
            output.appendU64(UInt64(zip64EOCDOffset))
            output.appendU32(1)
        }

        output.appendU32(0x0605_4B50)
        output.appendU16(0)
        output.appendU16(0)
        output.appendU16(needsZip64EOCD ? 0xFFFF : UInt16(records.count))
        output.appendU16(needsZip64EOCD ? 0xFFFF : UInt16(records.count))
        output.appendU32(needsZip64EOCD ? 0xFFFF_FFFF : UInt32(directorySize))
        output.appendU32(needsZip64EOCD ? 0xFFFF_FFFF : UInt32(directoryOffset))
        output.appendU16(0)
        return output
    }

    private static func zip64ExtraField(uncompressed: Int?, compressed: Int?, offset: Int?) -> Data {
        var body = Data()
        if let uncompressed { body.appendU64(UInt64(uncompressed)) }
        if let compressed { body.appendU64(UInt64(compressed)) }
        if let offset { body.appendU64(UInt64(offset)) }
        var field = Data()
        field.appendU16(0x0001)
        field.appendU16(UInt16(body.count))
        field.append(body)
        return field
    }

    private static func dosTimestamp(_ date: Date) -> (time: UInt16, date: UInt16) {
        let parts = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        let year = max(1980, parts.year ?? 1980) - 1980
        let time = UInt16((parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | ((parts.second ?? 0) / 2))
        let day = UInt16(year << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1))
        return (time, day)
    }
}

extension Data {
    mutating func appendU16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendU32(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) { append(UInt8((value >> UInt32(shift)) & 0xFF)) }
    }

    mutating func appendU64(_ value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) { append(UInt8((value >> UInt64(shift)) & 0xFF)) }
    }
}
