import Foundation
import XCTest
@testable import CSAiEMMacApp

final class TransferArtifactIncidentReconciliationTests: XCTestCase {
  private let start = Date(timeIntervalSinceReferenceDate: 815_137_350)

  func testFirstBatchThirteenOfFifteenThenSecondBatchTwoResolvesOnlyMatchingIncident() {
    let first = firstBatch()
    let second = secondBatch()
    let incident = cleanupIncident()
    let unrelated = CSAiEMIncident(id: "other", createdAt: start, kind: "Recovery", title: "Recovery warning", target: "Unrelated", detail: "retry", jobID: "other-job", severity: .recoverable, state: .open, resolution: nil)
    let verified = Set((first.receipts + second.receipts).map(\.archivePath))
    let absent = Set((first.receipts + second.receipts).map(\.originalPath))
    let scan = TransferArtifactIncidentScan(complete: true, currentArtifactPaths: [], confirmedAbsentSourcePaths: absent, verifiedArchivePaths: verified)

    XCTAssertEqual(TransferArtifactIncidentReconciliation.resolvedIncidentIDs(incidents: [incident, unrelated], batches: [first, second], scan: scan), [incident.id])
  }

  func testIncompleteOrUnverifiedEvidenceLeavesIncidentOpen() {
    let first = firstBatch()
    let second = secondBatch()
    let incident = cleanupIncident()
    let receipts = first.receipts + second.receipts
    let absent = Set(receipts.map(\.originalPath))
    func ids(_ scan: TransferArtifactIncidentScan, _ batches: [TransferArtifactIncidentBatch] = [first, second]) -> [String] {
      TransferArtifactIncidentReconciliation.resolvedIncidentIDs(incidents: [incident], batches: batches, scan: scan)
    }

    XCTAssertTrue(ids(.init(complete: false, currentArtifactPaths: [], confirmedAbsentSourcePaths: absent, verifiedArchivePaths: Set(receipts.map(\.archivePath)))).isEmpty)
    XCTAssertTrue(ids(.init(complete: true, currentArtifactPaths: ["/tmp/new-stage"], confirmedAbsentSourcePaths: absent, verifiedArchivePaths: Set(receipts.map(\.archivePath)))).isEmpty)
    XCTAssertTrue(ids(.init(complete: true, currentArtifactPaths: [], confirmedAbsentSourcePaths: Set(first.receipts.map(\.originalPath)), verifiedArchivePaths: Set(receipts.map(\.archivePath)))).isEmpty)
    XCTAssertTrue(ids(.init(complete: true, currentArtifactPaths: [], confirmedAbsentSourcePaths: absent, verifiedArchivePaths: Set(first.receipts.map(\.archivePath)))).isEmpty)
    XCTAssertTrue(ids(.init(complete: true, currentArtifactPaths: [], confirmedAbsentSourcePaths: absent, verifiedArchivePaths: Set(receipts.map(\.archivePath))), [first]).isEmpty)
  }

  func testAmbiguousOrUnrelatedBatchCannotResolveHistoricIncident() {
    let first = firstBatch()
    let second = secondBatch()
    let incident = cleanupIncident()
    let receipts = first.receipts + second.receipts
    let scan = TransferArtifactIncidentScan(complete: true, currentArtifactPaths: [], confirmedAbsentSourcePaths: Set(receipts.map(\.originalPath)), verifiedArchivePaths: Set(receipts.map(\.archivePath)))
    var unrelated = incident
    unrelated = CSAiEMIncident(id: "wrong-count", createdAt: unrelated.createdAt, kind: unrelated.kind, title: unrelated.title, target: "14 folders", detail: unrelated.detail, jobID: unrelated.jobID, severity: unrelated.severity, state: .open, resolution: nil)
    XCTAssertTrue(TransferArtifactIncidentReconciliation.resolvedIncidentIDs(incidents: [unrelated], batches: [first, second], scan: scan).isEmpty)
    XCTAssertTrue(TransferArtifactIncidentReconciliation.resolvedIncidentIDs(incidents: [incident], batches: [first, first, second], scan: scan).isEmpty)
  }

  func testRetryRoutesArtifactCleanupBeforeGenericIncompleteFallback() {
    let artifact = job(kind: "Artifact Cleanup", title: "Preserve and clean staging folders", state: .cleanupIncomplete)
    XCTAssertEqual(TransferArtifactIncidentReconciliation.retryRoute(for: artifact, artifactSessionApplying: false), .reviewStagingAndBackupFolders)
    XCTAssertEqual(TransferArtifactIncidentReconciliation.retryRoute(for: artifact, artifactSessionApplying: true), .verifyInterruptedCleanup)
    let review = job(kind: "Artifact Review", title: "Review staging and backup folders", state: .failed)
    XCTAssertEqual(TransferArtifactIncidentReconciliation.retryRoute(for: review, artifactSessionApplying: false), .reviewStagingAndBackupFolders)
    let source = job(kind: "Migration", title: "Move workspace", state: .cleanupIncomplete)
    XCTAssertEqual(TransferArtifactIncidentReconciliation.retryRoute(for: source, artifactSessionApplying: false), .scanOldSourceLeftovers)
    XCTAssertEqual(TransferArtifactIncidentReconciliation.retryRoute(for: job(kind: "Local", title: "Port monitor", state: .failed), artifactSessionApplying: false), .existingRetry)
    XCTAssertEqual(TransferArtifactIncidentReconciliation.retryRoute(for: cleanupIncident(), artifactSessionApplying: false), .reviewStagingAndBackupFolders)
    XCTAssertEqual(TransferArtifactIncidentReconciliation.retryRoute(for: cleanupIncident(), artifactSessionApplying: true), .verifyInterruptedCleanup)
  }

  private func firstBatch() -> TransferArtifactIncidentBatch {
    let receipts = (0..<13).map { path in
      TransferArtifactIncidentBatch.Receipt(originalPath: "/tmp/stage-\(path)", archivePath: "/tmp/recovery/first/stage-\(path)")
    }
    return .init(reviewID: "first", completedAt: start, attemptedCount: 15, receipts: receipts, failedPaths: ["/tmp/stage-13", "/tmp/stage-14"])
  }

  private func secondBatch() -> TransferArtifactIncidentBatch {
    .init(reviewID: "second", completedAt: start.addingTimeInterval(500), attemptedCount: 2,
      receipts: [13, 14].map { path in .init(originalPath: "/tmp/stage-\(path)", archivePath: "/tmp/recovery/second/stage-\(path)") },
      failedPaths: [])
  }

  private func cleanupIncident() -> CSAiEMIncident {
    CSAiEMIncident(id: "cleanup", createdAt: start.addingTimeInterval(1), kind: "Artifact Cleanup",
      title: "Preserve and clean staging folders", target: "15 folders",
      detail: "13 folders preserved and removed from active entries; 2 need attention; 2 current transaction folders remain.",
      jobID: "first-job", severity: .recoverable, state: .open, resolution: nil)
  }

  private func job(kind: String, title: String, state: BackgroundJobState) -> BackgroundJobEntry {
    BackgroundJobEntry(id: "job", kind: kind, title: title, target: "target", detail: "detail", progressText: "", state: state, createdAt: start, startedAt: start, finishedAt: start, log: "")
  }
}
