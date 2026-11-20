import Foundation
import XCTest
@testable import CSAiEMMacApp

final class CodexOwnerContainerDiscoveryTests: XCTestCase {
  func testWorkspaceReposRootDiscoversProjectsInsideManagedOwner() throws {
    try withWorkspace { root in
      let repos = root.appendingPathComponent("Code/Repos", isDirectory: true)
      let owner = repos.appendingPathComponent("Owner", isDirectory: true)
      let first = owner.appendingPathComponent("RepoA", isDirectory: true)
      let second = owner.appendingPathComponent("RepoB", isDirectory: true)
      let linked = root.appendingPathComponent("OutsideRepo", isDirectory: true)
      for directory in [
        owner.appendingPathComponent(".SYSTEMX"),
        first.appendingPathComponent(".git"),
        second.appendingPathComponent(".git"),
        linked
      ] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      }
      for project in [first, second, linked] {
        try #"{"name":"fixture"}"#.write(
          to: project.appendingPathComponent("package.json"),
          atomically: true,
          encoding: .utf8
        )
      }
      try FileManager.default.createSymbolicLink(
        at: owner.appendingPathComponent("LinkedRepo"),
        withDestinationURL: linked
      )

      for scanRoot in [repos, owner] {
        let projects = CleanupViewModel.discoverCodexProjects(
          scanRoots: [scanRoot.path],
          environment: ["HOME": root.path]
        )
        XCTAssertEqual(Set(projects.map(\.path)), Set([first.path, second.path]))
      }
    }
  }

  func testRealProjectRootDoesNotDiscoverNestedTemplate() throws {
    try withWorkspace { root in
      let project = root.appendingPathComponent("Code/Repos/Owner/RepoA", isDirectory: true)
      let template = project.appendingPathComponent("templates/Nested", isDirectory: true)
      try FileManager.default.createDirectory(at: template, withIntermediateDirectories: true)
      for directory in [project, template] {
        try #"{"name":"fixture"}"#.write(
          to: directory.appendingPathComponent("package.json"),
          atomically: true,
          encoding: .utf8
        )
      }

      let projects = CleanupViewModel.discoverCodexProjects(
        scanRoots: [project.path],
        environment: ["HOME": root.path]
      )
      XCTAssertEqual(projects.map(\.path), [project.path])
    }
  }

  func testManagedCompositeProjectOutsideReposOwnerShapeStaysWhole() throws {
    try withWorkspace { root in
      let project = root.appendingPathComponent("Projects/Composite", isDirectory: true)
      let frontend = project.appendingPathComponent("frontend", isDirectory: true)
      let backend = project.appendingPathComponent("backend", isDirectory: true)
      for directory in [project.appendingPathComponent(".SYSTEMX"), frontend, backend] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      }
      try "Root-owned data".write(
        to: project.appendingPathComponent("README.md"),
        atomically: true,
        encoding: .utf8
      )
      for component in [frontend, backend] {
        try #"{"name":"component"}"#.write(
          to: component.appendingPathComponent("package.json"),
          atomically: true,
          encoding: .utf8
        )
      }

      let projects = CleanupViewModel.discoverCodexProjects(
        scanRoots: [project.path],
        environment: ["HOME": root.path]
      )
      XCTAssertEqual(projects.map(\.path), [project.path])
    }
  }

  private func withWorkspace(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("csa-iem-owner-discovery-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }
}
