import Foundation
import XCTest
@testable import CSAiEMMacApp

final class CodexLocalDevProfileBoundedTests: XCTestCase {
  private let manifestLimit = 1_048_576

  func testExactLimitManifestStillFindsDevelopmentCommand() throws {
    try withProject { project in
      let prefix = #"{"scripts":{"dev":"vite"},"padding":""#
      let suffix = #""}"#
      let paddingCount = manifestLimit - prefix.utf8.count - suffix.utf8.count
      let manifest = prefix + String(repeating: "a", count: paddingCount) + suffix
      XCTAssertEqual(manifest.utf8.count, manifestLimit)
      try manifest.write(to: project.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

      let profile = CleanupViewModel.readCodexLocalDevProfile(projectPath: project.path)
      XCTAssertEqual(profile?.script, "dev")
      XCTAssertEqual(profile?.commandLabel, "npm run dev")
    }
  }

  func testSparseOversizedManifestIsRejected() throws {
    try withProject { project in
      let manifest = project.appendingPathComponent("package.json")
      try #"{"scripts":{"dev":"vite"}}"#.write(to: manifest, atomically: true, encoding: .utf8)
      let handle = try FileHandle(forWritingTo: manifest)
      try handle.truncate(atOffset: 512 * 1024 * 1024)
      try handle.close()

      XCTAssertNil(CleanupViewModel.readCodexLocalDevProfile(projectPath: project.path))
    }
  }

  func testSymlinkToSpecialFileIsRejected() throws {
    try withProject { project in
      try FileManager.default.createSymbolicLink(
        at: project.appendingPathComponent("package.json"),
        withDestinationURL: URL(fileURLWithPath: "/dev/zero")
      )
      XCTAssertNil(CleanupViewModel.readCodexLocalDevProfile(projectPath: project.path))
    }
  }

  private func withProject(_ body: (URL) throws -> Void) throws {
    let project = FileManager.default.temporaryDirectory
      .appendingPathComponent("csa-iem-dev-profile-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: project) }
    try body(project)
  }
}
