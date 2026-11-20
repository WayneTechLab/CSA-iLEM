import Foundation
import XCTest
@testable import CSAiEMMacApp

final class TransferArtifactSessionHistoryTests: XCTestCase {
  func testMoreThanFiftyRecoveryPointersRemainReachableThroughPages() throws {
    var history: [TransferArtifactCleanupSession] = []
    for index in 0..<55 {
      history = TransferArtifactSessionHistory.updating(history, with: session(index))
    }
    XCTAssertEqual(history.count, 55)
    XCTAssertEqual(TransferArtifactSessionHistory.visible(history, query: "", count: 20).count, 20)
    XCTAssertEqual(TransferArtifactSessionHistory.visible(history, query: "", count: 40).count, 40)
    XCTAssertEqual(TransferArtifactSessionHistory.visible(history, query: "", count: 60).count, 55)
    XCTAssertEqual(TransferArtifactSessionHistory.visible(history, query: "", count: 60).last?.reviewID, "batch-0")

    let saved = try JSONEncoder().encode(history)
    let loaded = try JSONDecoder().decode([TransferArtifactCleanupSession].self, from: saved)
    XCTAssertEqual(loaded.count, 55)
    XCTAssertEqual(loaded.last?.reviewID, "batch-0")
  }

  func testUpdatingExistingBatchPreservesOtherRecoveryPointers() {
    let original = [session(0), session(1), session(2)]
    let revised = TransferArtifactCleanupSessionHistoryFixture.completed(session(1))
    let updated = TransferArtifactSessionHistory.updating(original, with: revised)
    XCTAssertEqual(updated.map(\.reviewID), ["batch-1", "batch-0", "batch-2"])
    XCTAssertEqual(updated.first?.phase, "completed")
    XCTAssertEqual(TransferArtifactSessionHistory.matching(updated, query: "BATCH-2").map(\.reviewID), ["batch-2"])
  }

  private func session(_ index: Int) -> TransferArtifactCleanupSession {
    TransferArtifactCleanupSession(
      reviewID: "batch-\(index)", reviewPath: "/tmp/review-\(index).json",
      recoveryRoot: "/tmp/recovery", resultPath: "/tmp/result-\(index).json",
      allowedRepositoryRoots: ["/tmp/repos"], createdAt: Date(timeIntervalSince1970: TimeInterval(index)), phase: "reviewed"
    )
  }
}

private enum TransferArtifactCleanupSessionHistoryFixture {
  static func completed(_ session: TransferArtifactCleanupSession) -> TransferArtifactCleanupSession {
    var copy = session
    copy.phase = "completed"
    return copy
  }
}
