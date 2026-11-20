import Foundation
import XCTest
@testable import CSAiEMMacApp

final class CodexPathSafetyTests: XCTestCase {
  func testDistinctPhysicalDirectoriesAreAllowedThroughAnAncestorAlias() throws {
    try withFixture { root in
      let parent = root.appendingPathComponent("physical", isDirectory: true)
      let source = parent.appendingPathComponent("source", isDirectory: true)
      let destination = parent.appendingPathComponent("destination", isDirectory: true)
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
      let alias = root.appendingPathComponent("alias")
      try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: parent)

      XCTAssertNoThrow(try CodexPathSafety.validate(
        sourcePath: alias.appendingPathComponent("source").path,
        destinationPath: alias.appendingPathComponent("destination").path
      ))
    }
  }

  func testRejectsEqualAndAncestorOverlapsIncludingMissingDestination() throws {
    try withFixture { root in
      let source = root.appendingPathComponent("source", isDirectory: true)
      let child = source.appendingPathComponent("child", isDirectory: true)
      try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)

      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: source.path, destinationPath: source.path))
      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: source.path, destinationPath: child.path))
      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: child.path, destinationPath: source.path))
      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: source.path, destinationPath: source.appendingPathComponent("new/output").path))
    }
  }

  func testRejectsPhysicalOverlapThroughAncestorAlias() throws {
    try withFixture { root in
      let source = root.appendingPathComponent("source", isDirectory: true)
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      let alias = root.appendingPathComponent("alias")
      try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: source)

      XCTAssertThrowsError(try CodexPathSafety.validate(
        sourcePath: source.path,
        destinationPath: alias.appendingPathComponent("new/output").path
      ))
    }
  }

  func testRejectsSymbolicLinkRootsAndUnavailableSource() throws {
    try withFixture { root in
      let source = root.appendingPathComponent("source", isDirectory: true)
      let destination = root.appendingPathComponent("destination", isDirectory: true)
      try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
      let sourceAlias = root.appendingPathComponent("source-alias")
      let destinationAlias = root.appendingPathComponent("destination-alias")
      try FileManager.default.createSymbolicLink(at: sourceAlias, withDestinationURL: source)
      try FileManager.default.createSymbolicLink(at: destinationAlias, withDestinationURL: destination)

      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: sourceAlias.path, destinationPath: destination.path))
      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: source.path, destinationPath: destinationAlias.path))
      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: root.appendingPathComponent("missing").path, destinationPath: destination.path))
      XCTAssertThrowsError(try CodexPathSafety.validate(sourcePath: "relative/source", destinationPath: destination.path))
    }
  }

  private func withFixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("csa-iem-path-safety-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }
}
