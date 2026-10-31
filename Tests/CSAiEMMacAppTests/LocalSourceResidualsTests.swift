import Darwin
import Foundation
import XCTest
@testable import CSAiEMMacApp

final class LocalSourceResidualsTests: XCTestCase {
  func testGeneratedOnlyOldRootIsResidualRatherThanReadyProject() throws {
    try fixture { root in
      try write("generated", at: root.appendingPathComponent("node_modules/@emnapi/core/LICENSE 2"))
      try write("finder", at: root.appendingPathComponent(".DS_Store"))
      let summary = LocalSourceResidualScanner.inventory(rootPath: root.path)

      XCTAssertEqual(summary.state, .complete)
      XCTAssertEqual(summary.classification, .residualOnly)
      XCTAssertEqual(summary.fileCount, 2)
      XCTAssertEqual(summary.directoryCount, 3)
      XCTAssertEqual(summary.logicalByteCount, 15)
      XCTAssertEqual(summary.generatedRootEntryCount, 1)
      XCTAssertEqual(summary.finderMetadataRootEntryCount, 1)
      XCTAssertTrue(summary.cleanupIncomplete)
      XCTAssertTrue(summary.metadataOnly)
      XCTAssertFalse(summary.deletionAuthorized)
    }
  }

  func testRealAndHiddenProjectFilesPreventResidualOnlyClassification() throws {
    try fixture { root in
      try write("generated", at: root.appendingPathComponent("node_modules/cached.js"))
      try write("project", at: root.appendingPathComponent("src/main.swift"))
      let privateSentinel = "private-test-sentinel-must-not-enter-evidence"
      try write(privateSentinel, at: root.appendingPathComponent(".env"))
      let summary = LocalSourceResidualScanner.inventory(rootPath: root.path)

      XCTAssertEqual(summary.classification, .projectContent)
      XCTAssertEqual(summary.fileCount, 3)
      XCTAssertTrue(summary.remainingPathSample.contains(".env"))
      let encoded = try JSONEncoder().encode(summary)
      XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(privateSentinel))
      XCTAssertFalse(summary.deletionAuthorized)
    }
  }

  func testNumberedGeneratedAndFinderConflictVariantsRemainCounted() throws {
    XCTAssertTrue(LocalSourceResidualScanner.isGeneratedDirectoryName("__pycache__"))
    XCTAssertTrue(LocalSourceResidualScanner.isGeneratedDirectoryName("__pycache__-4"))
    XCTAssertFalse(LocalSourceResidualScanner.isGeneratedDirectoryName("__pycache-4"))
    XCTAssertFalse(LocalSourceResidualScanner.isGeneratedDirectoryName("build-source2"))
    try fixture { root in
      for name in ["node_modules 2", "node_modules (3)", "build.2", "__pycache__-4"] {
        try write("x", at: root.appendingPathComponent(name + "/cache"))
      }
      try write("x", at: root.appendingPathComponent(".DS_Store 2"))
      try write("x", at: root.appendingPathComponent("._resource 2"))
      let summary = LocalSourceResidualScanner.inventory(rootPath: root.path)

      XCTAssertEqual(summary.state, .complete)
      XCTAssertEqual(summary.classification, .residualOnly)
      XCTAssertEqual(summary.generatedRootEntryCount, 4)
      XCTAssertEqual(summary.finderMetadataRootEntryCount, 2)
      XCTAssertEqual(summary.fileCount, 6)
    }
  }

  func testSymlinkTargetsAreNeverTraversed() throws {
    try fixture { root in
      let outside = root.deletingLastPathComponent().appendingPathComponent("outside-" + UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: outside) }
      try write(String(repeating: "outside", count: 100), at: outside.appendingPathComponent("must-not-be-counted"))
      try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("node_modules"), withDestinationURL: outside)
      let summary = LocalSourceResidualScanner.inventory(rootPath: root.path)

      XCTAssertEqual(summary.symlinkCount, 1)
      XCTAssertEqual(summary.fileCount, 0)
      XCTAssertEqual(summary.logicalByteCount, 0)
      XCTAssertEqual(summary.entryCount, 1)
      XCTAssertFalse(summary.remainingPathSample.contains(where: { $0.contains("must-not-be-counted") }))

      let linkedRoot = root.appendingPathComponent("node_modules")
      let linked = LocalSourceResidualScanner.inventory(rootPath: linkedRoot.path)
      XCTAssertEqual(linked.classification, .unverified)
      XCTAssertEqual(linked.state, .failed)
      XCTAssertTrue(linked.cleanupIncomplete)
      XCTAssertTrue(try LocalSourceResidualScanner.entryExistsNoFollow(atPath: linkedRoot.path))
    }
  }

  func testUnreadableDirectoryCannotBeReportedAsCleanOrVerified() throws {
    if geteuid() == 0 { throw XCTSkip("Root bypasses Unix mode-based read restrictions") }
    try fixture { root in
      let denied = root.appendingPathComponent("node_modules")
      try write("retained", at: denied.appendingPathComponent("hidden"))
      try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
      defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied.path) }
      let summary = LocalSourceResidualScanner.inventory(rootPath: root.path)

      XCTAssertEqual(summary.state, .failed)
      XCTAssertEqual(summary.classification, .unverified)
      XCTAssertGreaterThan(summary.errorCount, 0)
      XCTAssertFalse(summary.errors.isEmpty)
      XCTAssertTrue(summary.cleanupIncomplete)
      XCTAssertFalse(summary.deletionAuthorized)
    }
  }

  func testEntryDepthAndTimeBoundsRemainExplicitlyIncomplete() throws {
    try fixture { root in
      try write("x", at: root.appendingPathComponent("node_modules/deep/cache"))
      try write("x", at: root.appendingPathComponent(".DS_Store"))

      let entries = LocalSourceResidualScanner.inventory(rootPath: root.path, maxEntries: 1)
      XCTAssertEqual(entries.state, .truncated)
      XCTAssertEqual(entries.classification, .unverified)
      XCTAssertEqual(entries.entryCount, 1)
      XCTAssertTrue(entries.truncationReasons.contains("entryLimit"))

      let depth = LocalSourceResidualScanner.inventory(rootPath: root.path, maxDepth: 0)
      XCTAssertEqual(depth.state, .truncated)
      XCTAssertTrue(depth.truncationReasons.contains("depthLimit"))

      let duration = LocalSourceResidualScanner.inventory(rootPath: root.path, maxDuration: 0)
      XCTAssertEqual(duration.state, .truncated)
      XCTAssertTrue(duration.truncationReasons.contains("durationLimit"))
      XCTAssertTrue(duration.cleanupIncomplete)
    }
  }

  func testOnlyAnAbsentOldRootCompletesCleanup() throws {
    try fixture { root in
      let empty = LocalSourceResidualScanner.postCleanupSummary(rootPath: root.path)
      XCTAssertEqual(empty.classification, .empty)
      XCTAssertTrue(empty.cleanupIncomplete)

      try write("finder", at: root.appendingPathComponent(".DS_Store"))
      let metadata = LocalSourceResidualScanner.postCleanupSummary(rootPath: root.path)
      XCTAssertEqual(metadata.classification, .residualOnly)
      XCTAssertEqual(metadata.finderMetadataRootEntryCount, 1)
      XCTAssertTrue(metadata.cleanupIncomplete)

      let absentPath = root.appendingPathComponent("removed-source").path
      let absent = LocalSourceResidualScanner.postCleanupSummary(rootPath: absentPath)
      XCTAssertEqual(absent.classification, .absent)
      XCTAssertEqual(absent.state, .complete)
      XCTAssertTrue(absent.cleanupComplete)
      XCTAssertFalse(absent.cleanupIncomplete)
      XCTAssertFalse(try LocalSourceResidualScanner.entryExistsNoFollow(atPath: absentPath))
    }
  }

  func testDatalessMetadataFlagIsRecognizedWithoutReadingPayload() {
    XCTAssertTrue(LocalSourceResidualScanner.isDatalessFile(flags: 0x40000000))
    XCTAssertTrue(LocalSourceResidualScanner.isDatalessFile(flags: 0x40000002))
    XCTAssertFalse(LocalSourceResidualScanner.isDatalessFile(flags: 0))
    XCTAssertFalse(LocalSourceResidualScanner.isDatalessFile(flags: 0x00000002))
  }

  func testEvidenceStoreRoundTripsUnresolvedAndAbsentRecords() throws {
    try fixture { root in
      let source = root.appendingPathComponent("old-source")
      try write("retained", at: source.appendingPathComponent("node_modules/cache"))
      let reportURL = root.appendingPathComponent("reports/nested/residuals.json")
      let unresolved = LocalSourceResidualRecord(
        sourcePath: source.path + "/.", destinationPath: root.appendingPathComponent("destination").path,
        summary: LocalSourceResidualScanner.inventory(rootPath: source.path),
        scannedAt: Date(timeIntervalSince1970: 42)
      )
      XCTAssertEqual(unresolved.id, source.path)
      try LocalSourceResidualStore.save([unresolved], to: reportURL)
      XCTAssertEqual(try LocalSourceResidualStore.load(from: reportURL), [unresolved])

      let resolved = LocalSourceResidualRecord(
        sourcePath: source.appendingPathComponent("already-gone").path,
        summary: LocalSourceResidualScanner.postCleanupSummary(rootPath: source.appendingPathComponent("already-gone").path),
        scannedAt: Date(timeIntervalSince1970: 43)
      )
      try LocalSourceResidualStore.save([unresolved, resolved], to: reportURL)
      let loaded = try LocalSourceResidualStore.load(from: reportURL)
      XCTAssertEqual(loaded, [unresolved, resolved])
      XCTAssertTrue(loaded[0].summary.cleanupIncomplete)
      XCTAssertTrue(loaded[1].summary.cleanupComplete)
    }
  }

  func testEvidenceStoreReadAndWriteErrorsSurface() throws {
    try fixture { root in
      let parentFile = root.appendingPathComponent("not-a-directory")
      try write("keep me", at: parentFile)
      XCTAssertThrowsError(try LocalSourceResidualStore.save([], to: parentFile.appendingPathComponent("report.json")))
      XCTAssertEqual(try String(contentsOf: parentFile, encoding: .utf8), "keep me")
      XCTAssertThrowsError(try LocalSourceResidualStore.load(from: root.appendingPathComponent("missing.json")))
      let malformed = root.appendingPathComponent("malformed.json")
      try write("{ malformed", at: malformed)
      XCTAssertThrowsError(try LocalSourceResidualStore.load(from: malformed))
    }
  }

  private func fixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-residuals-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }

  private func write(_ text: String, at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }
}
