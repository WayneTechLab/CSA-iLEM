import CoreFoundation
import Foundation
import SQLite3
import XCTest
@testable import CSAiEMMacApp

final class CatalogReentrancyTests: XCTestCase {
  func testCatalogReadsAndWritesDoNotServiceQueuedMainRunLoopWork() throws {
    try onMainThread {
      let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-catalog-reentrancy-" + UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: root) }
      let store = CodexCatalogStore(rootPath: root.path)
      let observed = Date(timeIntervalSince1970: 1_754_931_600)
      let checkpoint = CodexSessionCheckpoint(
        sessionID: "render-session", sourcePath: "/tmp/source", stage: "stage1-preflight",
        state: "indexed", updatedAt: observed, detail: "checkpoint retained"
      )
      let receipt = CodexScanRouteReceipt(
        sessionID: "render-session", sourcePath: "/tmp/source", route: .targetedVerification,
        state: .planned, attemptCount: 0, updatedAt: observed, detail: "local | receipt"
      )
      try store.saveCheckpoints([checkpoint])
      try store.saveRouteReceipts([receipt])

      let callback = MainRunLoopCallback()
      CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue) {
        callback.fired = true
      }
      CFRunLoopWakeUp(CFRunLoopGetMain())

      // SwiftUI can read both properties during one AttributeGraph update.
      // Servicing the queued block here would permit a nested UI update, which
      // the previous Process.waitUntilExit-based implementation could do.
      XCTAssertEqual(store.latestCheckpointSummary(), "stage1-preflight=indexed at 2025-08-11T17:00:00Z")
      XCTAssertEqual(store.routeReceipts(for: "render-session"), [receipt])
      try store.saveCheckpoints([checkpoint])
      XCTAssertFalse(callback.fired, "Synchronous catalog access must not re-enter the main run loop")

      // Prove the queued work was actually runnable rather than a false pass.
      CFRunLoopRunInMode(.defaultMode, 0.01, false)
      XCTAssertTrue(callback.fired)
    }
  }

  func testCatalogReadFailureIsNonDestructiveAndWriteFailureIsReported() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-catalog-invalid-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CodexCatalogStore(rootPath: root.path)
    try FileManager.default.createDirectory(atPath: store.catalogDirectory, withIntermediateDirectories: true)
    let invalidDatabase = Data("not a SQLite database".utf8)
    try invalidDatabase.write(to: URL(fileURLWithPath: store.databasePath))

    XCTAssertNil(store.latestCheckpointSummary())
    XCTAssertTrue(store.routeReceipts(for: "missing-session").isEmpty)
    XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: store.databasePath)), invalidDatabase)

    let checkpoint = CodexSessionCheckpoint(
      sessionID: "session", sourcePath: "/tmp/source", stage: "preflight", state: "indexed",
      updatedAt: Date(), detail: "retained"
    )
    XCTAssertThrowsError(try store.saveCheckpoints([checkpoint])) { error in
      XCTAssertEqual((error as NSError).domain, "CSAiEM.CodexCatalog")
    }
  }

  func testCatalogWriteLockReturnsWithinBoundedTimeout() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-catalog-busy-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CodexCatalogStore(rootPath: root.path)
    let checkpoint = CodexSessionCheckpoint(
      sessionID: "session", sourcePath: "/tmp/source", stage: "preflight", state: "indexed",
      updatedAt: Date(), detail: "retained"
    )
    try store.saveCheckpoints([checkpoint])
    var lockDatabase: OpaquePointer?
    XCTAssertEqual(sqlite3_open(store.databasePath, &lockDatabase), SQLITE_OK)
    let locked = try XCTUnwrap(lockDatabase)
    defer { sqlite3_close_v2(locked) }
    XCTAssertEqual(sqlite3_exec(locked, "BEGIN IMMEDIATE;", nil, nil, nil), SQLITE_OK)
    defer { sqlite3_exec(locked, "ROLLBACK;", nil, nil, nil) }

    let started = Date()
    XCTAssertThrowsError(try store.saveCheckpoints([checkpoint])) { error in
      XCTAssertEqual((error as NSError).domain, "CSAiEM.CodexCatalog")
      XCTAssertEqual((error as NSError).code, Int(SQLITE_BUSY))
    }
    XCTAssertLessThan(Date().timeIntervalSince(started), 2, "A locked catalog must not leave the GUI waiting indefinitely")
  }

  private func onMainThread(_ body: () throws -> Void) throws {
    if Thread.isMainThread {
      try body()
    } else {
      try DispatchQueue.main.sync(execute: body)
    }
  }
}

private final class MainRunLoopCallback: @unchecked Sendable {
  var fired = false
}
