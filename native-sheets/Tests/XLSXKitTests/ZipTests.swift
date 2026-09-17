import XCTest
@testable import XLSXKit

final class ZipTests: XCTestCase {
    func testRoundTripsEntries() throws {
        let entries = [
            ZipWriter.Entry(name: "[Content_Types].xml", data: Data("<Types/>".utf8)),
            ZipWriter.Entry(name: "xl/worksheets/sheet1.xml", data: Data(String(repeating: "<c r=\"A1\"/>", count: 5000).utf8)),
            ZipWriter.Entry(name: "empty.bin", data: Data()),
        ]
        let archive = try ZipArchive(data: ZipWriter.archive(entries))

        XCTAssertEqual(archive.entryNames, entries.map(\.name))
        for entry in entries {
            XCTAssertEqual(try archive.data(for: entry.name), entry.data, entry.name)
        }
    }

    func testCompressesRepetitiveData() throws {
        let payload = Data(String(repeating: "spreadsheet", count: 10_000).utf8)
        let archive = ZipWriter.archive([ZipWriter.Entry(name: "a.xml", data: payload)])
        XCTAssertLessThan(archive.count, payload.count / 10)
        XCTAssertEqual(try ZipArchive(data: archive).data(for: "a.xml"), payload)
    }

    func testStoresIncompressibleDataWithoutGrowing() throws {
        var random = Data(count: 4096)
        random.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, 4096, $0.baseAddress!) }
        let archive = ZipWriter.archive([ZipWriter.Entry(name: "r.bin", data: random)])
        XCTAssertEqual(try ZipArchive(data: archive).data(for: "r.bin"), random)
        XCTAssertLessThan(archive.count, random.count + 512)
    }

    func testPreservesUTF8Names() throws {
        let name = "xl/worksheets/лист-日本.xml"
        let archive = try ZipArchive(data: ZipWriter.archive([
            ZipWriter.Entry(name: name, data: Data("ok".utf8))
        ]))
        XCTAssertEqual(archive.entryNames, [name])
    }

    func testChecksumMatchesKnownVector() {
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
    }

    func testRejectsNonArchive() {
        XCTAssertThrowsError(try ZipArchive(data: Data("not a zip".utf8)))
    }

    func testReadsArchiveWrittenByTheSystemZip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ziptest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("payload.xml")
        let body = String(repeating: "<row r=\"1\"/>", count: 2000)
        try Data(body.utf8).write(to: source)

        let zipURL = directory.appendingPathComponent("out.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-j", "-q", zipURL.path, source.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let archive = try ZipArchive(url: zipURL)
        XCTAssertEqual(try archive.data(for: "payload.xml"), Data(body.utf8))
    }

    func testSystemUnzipReadsOurArchive() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ziptest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let zipURL = directory.appendingPathComponent("ours.zip")
        try ZipWriter.archive([
            ZipWriter.Entry(name: "a/b.xml", data: Data(String(repeating: "x", count: 5000).utf8)),
            ZipWriter.Entry(name: "c.txt", data: Data("hello".utf8)),
        ]).write(to: zipURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", zipURL.path]
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "system unzip rejected the archive")
    }
}
