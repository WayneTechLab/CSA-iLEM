import Foundation
import XCTest
@testable import CSAiEMMacApp

final class CodexCatalogStatusLoaderTests: XCTestCase {
  func testCatalogSummaryRunsOffMainActor() async {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-status-" + UUID().uuidString)
    let store = CodexCatalogStore(rootPath: root.path)
    let status = await Task { @MainActor in
      await CodexCatalogStatusLoader.load(for: store) { _ in
        Thread.isMainThread ? "main thread" : "background thread"
      }
    }.value
    XCTAssertTrue(status.contains("background thread"), status)
  }

  func testSavedCheckpointAppearsInCachedStatus() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-status-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CodexCatalogStore(rootPath: root.path)
    try store.saveCheckpoints([
      CodexSessionCheckpoint(
        sessionID: "status-session", sourcePath: "/tmp/source", stage: "stage1-preflight",
        state: "indexed", updatedAt: Date(timeIntervalSince1970: 1_754_931_600), detail: "saved"
      )
    ])
    let status = await CodexCatalogStatusLoader.load(for: store)
    XCTAssertTrue(status.contains("SQLite catalog ready"), status)
    XCTAssertTrue(status.contains("latest checkpoint stage1-preflight=indexed"), status)
  }
}
