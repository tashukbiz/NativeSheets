import Compression
import Foundation

/// Raw DEFLATE (RFC 1951) over the system Compression framework.
///
/// `COMPRESSION_ZLIB` in Apple's framework is headerless DEFLATE, which is
/// exactly what ZIP method 8 stores.
enum Deflate {
    static func compress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        // Incompressible input can grow; give the encoder room and fall back to
        // stored if it still does not fit.
        let capacity = data.count + (data.count / 2) + 64
        var output = Data(count: capacity)
        let written = output.withUnsafeMutableBytes { dst -> Int in
            data.withUnsafeBytes { src -> Int in
                compression_encode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!, capacity,
                    src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else { return nil }
        output.removeSubrange(written...)
        return output
    }

    static func decompress(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { dst -> Int in
            data.withUnsafeBytes { src -> Int in
                compression_decode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                    src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == expectedSize else { throw ZipError.corruptEntry }
        return output
    }
}
