import Darwin
import Foundation
import XCTest
@testable import CSAiEMMacApp

final class StreamingTreeVerifierTests: XCTestCase {
  func testGeneratedTreeScansBeyondInjectedEntryBoundWithConstantSizeState() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source")
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      for index in 0..<512 {
        let folder = source.appendingPathComponent("group-\(index / 64)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data([UInt8(index & 0xff)]).write(to: folder.appendingPathComponent("entry-\(index)"))
      }
      XCTAssertThrowsError(try StreamingTreeVerifier.fingerprint(path: source.path, maxEntriesForTesting: 32))
      let proof = try StreamingTreeVerifier.fingerprint(path: source.path)
      XCTAssertEqual(proof.fileCount, 512)
      XCTAssertEqual(proof.directoryCount, 8)
      XCTAssertEqual(proof.totalBytes, 512)
    }
  }

  func testCompleteReadbackRejectsChangedHiddenFileModeAndExtendedAttributes() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source")
      let destination = root.appendingPathComponent("destination")
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      try Data("original".utf8).write(to: source.appendingPathComponent(".hidden"))
      try copyWithDitto(source, destination)
      XCTAssertNoThrow(try StreamingTreeVerifier.verifyCopy(from: source.path, to: destination.path))

      try Data("changed".utf8).write(to: destination.appendingPathComponent(".hidden"))
      XCTAssertThrowsError(try StreamingTreeVerifier.verifyCopy(from: source.path, to: destination.path))

      try FileManager.default.removeItem(at: destination)
      try copyWithDitto(source, destination)
      XCTAssertEqual(chmod(destination.appendingPathComponent(".hidden").path, 0o600), 0)
      XCTAssertThrowsError(try StreamingTreeVerifier.verifyCopy(from: source.path, to: destination.path))

      try FileManager.default.removeItem(at: destination)
      try copyWithDitto(source, destination)
      let file = destination.appendingPathComponent(".hidden")
      let value = [UInt8]("extra".utf8)
      let result = value.withUnsafeBytes { bytes in
        setxattr(file.path, "com.waynetechlab.csa-iem-verifier-test", bytes.baseAddress, bytes.count, 0, 0)
      }
      XCTAssertEqual(result, 0)
      XCTAssertThrowsError(try StreamingTreeVerifier.verifyCopy(from: source.path, to: destination.path))
    }
  }

  func testLinkTargetAndNoFollowReadback() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source")
      let destination = root.appendingPathComponent("destination")
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      try Data("outside".utf8).write(to: root.appendingPathComponent("outside"))
      try FileManager.default.createSymbolicLink(atPath: source.appendingPathComponent("link").path,
        withDestinationPath: "../outside")
      try copyWithDitto(source, destination)
      XCTAssertNoThrow(try StreamingTreeVerifier.verifyCopy(from: source.path, to: destination.path,
        repairDittoLinkTimes: true))
      try FileManager.default.removeItem(at: destination.appendingPathComponent("link"))
      try FileManager.default.createSymbolicLink(atPath: destination.appendingPathComponent("link").path,
        withDestinationPath: "elsewhere")
      XCTAssertThrowsError(try StreamingTreeVerifier.verifyCopy(from: source.path, to: destination.path))
    }
  }

  private func copyWithDitto(_ source: URL, _ destination: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = [source.path, destination.path]
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
  }

  private func fixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-streaming-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }
}
