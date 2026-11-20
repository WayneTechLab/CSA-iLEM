import Foundation
import XCTest
@testable import CSAiEMMacApp

final class TransferCapacityPlannerTests: XCTestCase {
  func testMetadataScanCountsHiddenFilesWithoutFollowingLinksOutsideSource() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source")
      let nested = source.appendingPathComponent("nested")
      try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
      try Data(repeating: 0x41, count: 7).write(to: source.appendingPathComponent(".hidden"))
      try Data(repeating: 0x42, count: 11).write(to: nested.appendingPathComponent("data"))
      try Data(repeating: 0x43, count: 1_000_000).write(to: root.appendingPathComponent("outside"))
      try FileManager.default.createSymbolicLink(atPath: source.appendingPathComponent("outside-link").path,
        withDestinationPath: root.appendingPathComponent("outside").path)

      let usage = try TransferCapacityPlanner.inspect(path: source.path)
      XCTAssertEqual(usage.logicalBytes, 18)
      XCTAssertEqual(usage.entries, 5)
      XCTAssertEqual(usage.files, 2)
      XCTAssertEqual(usage.directories, 2)
      XCTAssertEqual(usage.symlinks, 1)
    }
  }

  func testLargeGeneratedDirectoryHasNoLegacyEntryCap() throws {
    try fixture { root in
      let source = root.appendingPathComponent("many")
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      for index in 0..<1_024 {
        XCTAssertTrue(FileManager.default.createFile(atPath: source.appendingPathComponent("file-\(index)").path,
          contents: Data([UInt8(index & 0xff)])))
      }
      let usage = try TransferCapacityPlanner.inspect(path: source.path)
      XCTAssertEqual(usage.entries, 1_025)
      XCTAssertEqual(usage.files, 1_024)
      XCTAssertEqual(usage.logicalBytes, 1_024)
    }
  }

  func testCapacityThresholdIncludesEntryReserveAndSafetyMargin() throws {
    let usage = TransferCapacityPlanner.Usage(logicalBytes: 10_000, entries: 3,
      files: 2, directories: 1, symlinks: 0)
    let required = try TransferCapacityPlanner.requiredBytes(for: usage, fixedMarginBytes: 1_000)
    XCTAssertEqual(required, 24_288)
    XCTAssertNoThrow(try TransferCapacityPlanner.requireSpace(requiredBytes: required,
      availableBytes: required, destination: "/tmp/destination"))
    XCTAssertThrowsError(try TransferCapacityPlanner.requireSpace(requiredBytes: required,
      availableBytes: required - 1, destination: "/tmp/destination")) { error in
      XCTAssertTrue(error.localizedDescription.contains("source was preserved"))
    }
  }

  func testCapacityPlanGroupsCopiesOnSameVolumeAndRejectsOverlap() throws {
    try fixture { root in
      let first = root.appendingPathComponent("first")
      let second = root.appendingPathComponent("second")
      try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
      try Data(repeating: 1, count: 100).write(to: first.appendingPathComponent("data"))
      try Data(repeating: 2, count: 200).write(to: second.appendingPathComponent("data"))
      let plans = try TransferCapacityPlanner.ensureAvailable(for: [
        .init(source: first.path, destination: root.appendingPathComponent("out/a").path),
        .init(source: second.path, destination: root.appendingPathComponent("out/b").path)
      ], fixedMarginBytes: 0)
      XCTAssertEqual(plans.count, 1)
      XCTAssertEqual(plans[0].sourceUsage.logicalBytes, 300)
      XCTAssertEqual(plans[0].sourceUsage.entries, 4)
      XCTAssertEqual(plans[0].requiredBytes,
        try TransferCapacityPlanner.requiredBytes(for: plans[0].sourceUsage, fixedMarginBytes: 0))
      XCTAssertThrowsError(try TransferCapacityPlanner.ensureAvailable(for: [
        .init(source: first.path, destination: first.appendingPathComponent("nested").path)
      ], fixedMarginBytes: 0))
    }
  }

  func testSourceRootMustNotBeSymlinkAndExpiredScanFailsClosed() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source")
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      let link = root.appendingPathComponent("link")
      try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: source.path)
      XCTAssertThrowsError(try TransferCapacityPlanner.inspect(path: link.path))
      XCTAssertThrowsError(try TransferCapacityPlanner.inspect(path: source.path, maxDuration: 0))
    }
  }

  func testUnmountedExternalDestinationCannotFallBackToInternalDisk() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source")
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      let missingVolume = "/Volumes/csa-iem-unmounted-\(UUID().uuidString)"
      XCTAssertThrowsError(try TransferCapacityPlanner.ensureAvailable(for: [
        .init(source: source.path, destination: missingVolume + "/copy")
      ], fixedMarginBytes: 0)) { error in
        XCTAssertTrue(error.localizedDescription.contains("not mounted"))
      }
      XCTAssertFalse(FileManager.default.fileExists(atPath: missingVolume))
    }
  }

  private func fixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-capacity-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }
}
