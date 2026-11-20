import Foundation
import XCTest
@testable import CSAiEMMacApp

final class OldSourceDiscoveryAndMigrationTests: XCTestCase {
  private let transactionID = "15AD85CC-ECCF-4A02-9529-6D455C45D349"

  func testBroadOldSourceScanReportsProjectMarkedCandidateAndSkipsActiveRoot() throws {
    try fixture { root in
      let oldContainer = root.appendingPathComponent("Documents/ChatGPT")
      let oldProject = oldContainer.appendingPathComponent("old-owner/old-project")
      let activeProject = oldContainer.appendingPathComponent("active-owner/active-project")
      try write("ref: refs/heads/main", at: oldProject.appendingPathComponent(".git/HEAD"))
      try write("keep", at: oldProject.appendingPathComponent("src/main.swift"))
      try write("current", at: activeProject.appendingPathComponent("package.json"))

      let discovery = CleanupViewModel.discoverOldSourceCandidatePaths(
        parents: [oldContainer.path], activeRoots: [activeProject.path])

      XCTAssertTrue(discovery.warnings.isEmpty)
      XCTAssertEqual(discovery.paths, [oldProject.path])
      XCTAssertEqual(try String(contentsOf: oldProject.appendingPathComponent("src/main.swift"), encoding: .utf8), "keep")
    }
  }

  func testGeneratedOnlyOldFolderAndSymlinkAreClassifiedWithoutTraversal() throws {
    try fixture { root in
      let oldContainer = root.appendingPathComponent("Documents/ChatGPT")
      let leftover = oldContainer.appendingPathComponent("old-project")
      try write("cached", at: leftover.appendingPathComponent("node_modules/@emnapi/core/LICENSE 2"))
      let outside = root.appendingPathComponent("outside-project")
      try write("outside", at: outside.appendingPathComponent("package.json"))
      try FileManager.default.createSymbolicLink(
        atPath: oldContainer.appendingPathComponent("linked-project").path,
        withDestinationPath: outside.path)

      let discovery = CleanupViewModel.discoverOldSourceCandidatePaths(
        parents: [oldContainer.path], activeRoots: [])

      XCTAssertEqual(discovery.paths, [leftover.path])
      XCTAssertFalse(discovery.paths.contains(outside.path))
    }
  }

  func testLegacyMigrationCountsOnlyRealProjectsAndExcludesTransactionFolders() throws {
    try fixture { root in
      let repos = root.appendingPathComponent("Code/Repos")
      let owner = repos.appendingPathComponent("WayneTechLab")
      let canonical = owner.appendingPathComponent("AlWeather")
      try write("real", at: canonical.appendingPathComponent("data.txt"))
      try write("stage", at: owner.appendingPathComponent("AlWeather.csa-iem-stage-\(transactionID)/data.txt"))
      try write("backup", at: owner.appendingPathComponent("AlWeather.csa-iem-backup-\(transactionID)/data.txt"))
      try FileManager.default.createSymbolicLink(
        atPath: owner.appendingPathComponent("symlink-project").path,
        withDestinationPath: canonical.path)

      let children = CleanupViewModel.ownerRepoChildren(under: repos.path)

      XCTAssertEqual(children.map(\.repo), ["AlWeather"])
      XCTAssertEqual(children.first?.path, canonical.path)
      XCTAssertEqual(CleanupViewModel.countOwnerRepoChildren(under: repos.path), 1)
    }
  }

  private func fixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-old-source-discovery-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }

  private func write(_ text: String, at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }
}
