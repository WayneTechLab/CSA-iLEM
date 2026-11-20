import Foundation

/// A small, read-only view of durable cleanup evidence. The caller must load
/// each result from its saved path and independently verify archives before
/// placing their paths in `verifiedArchivePaths`.
struct TransferArtifactIncidentBatch: Sendable {
  struct Receipt: Sendable {
    let originalPath: String
    let archivePath: String
  }

  let reviewID: String
  let completedAt: Date
  let attemptedCount: Int
  let receipts: [Receipt]
  let failedPaths: [String]

  init(_ result: TransferArtifactCleanupResult) {
    reviewID = result.reviewID
    completedAt = result.createdAt
    attemptedCount = result.attemptedCount
    receipts = result.receipts.map { Receipt(originalPath: $0.originalPath, archivePath: $0.archivePath) }
    failedPaths = result.failures.map(\.artifactPath)
  }

  init(reviewID: String, completedAt: Date, attemptedCount: Int, receipts: [Receipt], failedPaths: [String]) {
    self.reviewID = reviewID
    self.completedAt = completedAt
    self.attemptedCount = attemptedCount
    self.receipts = receipts
    self.failedPaths = failedPaths
  }
}

struct TransferArtifactIncidentScan: Sendable {
  /// Only a fresh, complete discovery run may set this to true.
  let complete: Bool
  let currentArtifactPaths: Set<String>
  /// Explicit no-follow existence checks of every path in the incident batch.
  let confirmedAbsentSourcePaths: Set<String>
  /// Paths whose archived trees and saved receipts passed integrity readback.
  let verifiedArchivePaths: Set<String>
}

enum TransferArtifactIncidentReconciliation {
  enum RetryRoute: Equatable {
    case verifyInterruptedCleanup
    case reviewStagingAndBackupFolders
    case scanOldSourceLeftovers
    case existingRetry
  }

  static func retryRoute(for job: BackgroundJobEntry, artifactSessionApplying: Bool) -> RetryRoute {
    if job.kind == "Artifact Cleanup" || job.kind == "Artifact Review" {
      return artifactSessionApplying ? .verifyInterruptedCleanup : .reviewStagingAndBackupFolders
    }
    return job.state == .cleanupIncomplete ? .scanOldSourceLeftovers : .existingRetry
  }

  /// Incidents persist across launches, while the in-memory job queue does not.
  /// The UI can still offer an honest route for an artifact incident.
  static func retryRoute(for incident: CSAiEMIncident, artifactSessionApplying: Bool) -> RetryRoute {
    if incident.kind == "Artifact Cleanup" || incident.kind == "Artifact Review" {
      return artifactSessionApplying ? .verifyInterruptedCleanup : .reviewStagingAndBackupFolders
    }
    return .existingRetry
  }

  /// Historic incidents predate a stored review ID. A unique near-time batch,
  /// exact target count, and exact outcome counts are required to associate it.
  /// Ambiguity or incomplete evidence leaves the incident open.
  static func resolvedIncidentIDs(
    incidents: [CSAiEMIncident],
    batches: [TransferArtifactIncidentBatch],
    scan: TransferArtifactIncidentScan
  ) -> [String] {
    guard scan.complete, scan.currentArtifactPaths.isEmpty else { return [] }
    return incidents.compactMap { incident in
      guard incident.state == .open,
            incident.severity == .recoverable,
            incident.kind == "Artifact Cleanup",
            incident.title == "Preserve and clean staging folders",
            let targetCount = folderCount(incident.target) else { return nil }

      let candidates = batches.filter { batch in
        let lag = incident.createdAt.timeIntervalSince(batch.completedAt)
        return lag >= 0 && lag <= 30 && batch.attemptedCount == targetCount &&
          !batch.failedPaths.isEmpty &&
          batch.attemptedCount == batch.receipts.count + batch.failedPaths.count &&
          incident.detail.contains("\(batch.receipts.count) folders preserved") &&
          incident.detail.contains("\(batch.failedPaths.count) need attention")
      }
      guard candidates.count == 1, let failedBatch = candidates.first else { return nil }
      let attemptedPaths = failedBatch.receipts.map(\.originalPath) + failedBatch.failedPaths
      guard Set(attemptedPaths).count == failedBatch.attemptedCount,
            Set(attemptedPaths).isSubset(of: scan.confirmedAbsentSourcePaths) else { return nil }

      let laterReceipts = batches
        .filter { $0.completedAt > incident.createdAt && $0.failedPaths.isEmpty && $0.attemptedCount == $0.receipts.count }
        .flatMap(\.receipts)
      let allReceipts = failedBatch.receipts + laterReceipts
      for path in attemptedPaths {
        let matching = allReceipts.filter { $0.originalPath == path && scan.verifiedArchivePaths.contains($0.archivePath) }
        guard !matching.isEmpty else { return nil }
      }
      return incident.id
    }
  }

  private static func folderCount(_ target: String) -> Int? {
    let parts = target.split(separator: " ")
    guard parts.count == 2, parts[1] == "folders", let count = Int(parts[0]), count > 0 else { return nil }
    return count
  }
}
