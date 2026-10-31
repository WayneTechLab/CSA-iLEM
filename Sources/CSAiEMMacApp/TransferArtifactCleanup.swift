import CryptoKit
import Darwin
import Foundation

struct TransferArtifactInventorySummary: Codable, Equatable, Sendable {
  let rootDevice: Int64
  let rootInode: UInt64
  let fileCount: Int
  let directoryCount: Int
  let symlinkCount: Int
  let totalBytes: Int64
  let manifestDigest: String
  let rootMetadataDigest: String

  init(_ inventory: CheckoutFileInventory) throws {
    rootDevice = inventory.rootDevice; rootInode = inventory.rootInode
    fileCount = inventory.fileCount; directoryCount = inventory.directoryCount
    symlinkCount = inventory.symlinkCount; totalBytes = inventory.totalBytes
    manifestDigest = inventory.manifestDigest
    struct RootMetadata: Encodable {
      let mode: UInt32
      let mtime: Int64
      let flags: UInt32
      let xattrs: [String: String]
    }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    let metadata = RootMetadata(mode: inventory.rootMode, mtime: inventory.rootMtimeNanoseconds,
      flags: inventory.rootFlags, xattrs: inventory.rootXattrs)
    rootMetadataDigest = SHA256.hash(data: try encoder.encode(metadata)).map { String(format: "%02x", $0) }.joined()
  }
}

struct TransferArtifactCleanupItem: Codable, Identifiable, Sendable {
  let id: String
  let artifactPath: String
  let canonicalPath: String
  let artifactKind: String
  let transactionID: String
  let inventory: TransferArtifactInventorySummary?
  let canonicalInventory: TransferArtifactInventorySummary?
  let inventoryPath: String?
  let canonicalInventoryPath: String?
  let missingPaths: [String]
  let differentPaths: [String]
  let metadataDifferentPaths: [String]
  let missingCount: Int
  let differentCount: Int
  let metadataDifferentCount: Int
  let identicalFiles: Int
  var blockers: [String]
  var canClean: Bool { blockers.isEmpty && inventory != nil && canonicalInventory != nil && inventoryPath != nil && canonicalInventoryPath != nil }
  var fileCount: Int { inventory?.fileCount ?? 0 }
  var directoryCount: Int { inventory?.directoryCount ?? 0 }
  var symlinkCount: Int { inventory?.symlinkCount ?? 0 }
  var totalBytes: Int64 { inventory?.totalBytes ?? 0 }
}

struct TransferArtifactCleanupReview: Codable, Identifiable, Sendable {
  let id: String
  let createdAt: Date
  let items: [TransferArtifactCleanupItem]
  let evidencePath: String
  var readyCount: Int { items.filter(\.canClean).count }
  var blockedCount: Int { items.count - readyCount }
  var canApply: Bool { readyCount > 0 }
}

struct TransferArtifactCleanupReceipt: Codable, Identifiable, Sendable {
  let id: String
  let createdAt: Date
  let originalPath: String
  let archivePath: String
  let keptPath: String
  let receiptPath: String
  let reviewEvidencePath: String
  let inventory: TransferArtifactInventorySummary
  var fileCount: Int { inventory.fileCount }
  var directoryCount: Int { inventory.directoryCount }
  var symlinkCount: Int { inventory.symlinkCount }
  var totalBytes: Int64 { inventory.totalBytes }
  var manifestDigest: String { inventory.manifestDigest }
}

struct TransferArtifactCleanupFailure: Codable, Sendable {
  let artifactPath: String
  let detail: String
}

struct TransferArtifactCleanupResult: Codable, Sendable {
  let reviewID: String
  let createdAt: Date
  let receipts: [TransferArtifactCleanupReceipt]
  let failures: [TransferArtifactCleanupFailure]
  let resultPath: String
  let attemptedCount: Int
  var completedAll: Bool { failures.isEmpty && receipts.count == attemptedCount }
}

/// Review transaction-shaped repository folders, then retire each whole tree
/// into recoverable storage. A filename match alone never authorizes cleanup.
/// Reports contain lightweight summaries; complete evidence is stored per tree.
enum TransferArtifactCleanupEngine {
  typealias Progress = @Sendable (String, Int, Int) -> Void
  private struct PendingLocation: Codable {
    let originalPath: String
    let archivePath: String
    let preparedReceiptPath: String
    let receiptPath: String
  }
  private struct PendingLedger: Codable {
    let reviewID: String
    let reviewEvidencePath: String
    let recoveryRoot: String
    let resultPath: String
    var locations: [PendingLocation]
  }
  private struct SimulatedInterruption: LocalizedError {
    var errorDescription: String? { "Simulated interruption after preserving an artifact. Resume verification from the saved session." }
  }

  static func review(
    paths: [String], allowedRepositoryRoots: [String], protectedRootPaths: [String],
    evidenceRoot: String, progress: Progress? = nil
  ) throws -> TransferArtifactCleanupReview {
    guard paths.count <= 128 else { throw failure("Review at most 128 transaction folders at a time.") }
    let roots = try allowedRoots(allowedRepositoryRoots)
    let inputs = Array(Set(paths.map { ($0 as NSString).standardizingPath })).sorted()
    let evidenceBase = try physicalFutureDirectory(evidenceRoot)
    // Check both lexical and physical sources before creating any report path.
    for input in inputs {
      let source = !input.hasPrefix("/") || (try? directoryStatus(input)) == nil ? input : physicalExistingPath(input)
      guard !isWithin(evidenceBase, source), !isWithin(evidenceBase, input) else {
        throw failure("Artifact evidence must be stored outside every reviewed source.")
      }
      if let parsed = parseArtifactName((input as NSString).lastPathComponent) {
        let canonical = physicalExistingPath(((input as NSString).deletingLastPathComponent as NSString).appendingPathComponent(parsed.base))
        guard !isWithin(evidenceBase, canonical) else { throw failure("Artifact evidence must be stored outside every canonical checkout.") }
      }
    }
    let id = UUID().uuidString
    let directory = URL(fileURLWithPath: evidenceBase).appendingPathComponent(id, isDirectory: true)
    try privateDirectory(directory.path)
    var canonicalManifests: [String: String] = [:]
    var seenSources = Set<String>()
    var items: [TransferArtifactCleanupItem] = []
    for (index, input) in inputs.enumerated() {
      progress?("Reviewing \((input as NSString).lastPathComponent)", index + 1, inputs.count)
      let source = !input.hasPrefix("/") || (try? directoryStatus(input)) == nil ? input : physicalExistingPath(input)
      if !seenSources.insert(source).inserted { continue }
      let item = reviewItem(source: source, allowedRoots: roots, protectedRootPaths: protectedRootPaths,
        directory: directory, canonicalManifests: &canonicalManifests)
      items.append(item)
    }
    let references = canonicalReferenceBlockers(items, allowedRoots: roots, useCurrentInventory: false, progress: progress)
    for index in items.indices {
      items[index].blockers += references.bySource[items[index].artifactPath] ?? []
      if let error = references.error, items[index].canClean { items[index].blockers.append(error) }
    }
    let report = TransferArtifactCleanupReview(id: id, createdAt: Date(), items: items,
      evidencePath: directory.appendingPathComponent("review.json").path)
    try save(report, to: report.evidencePath)
    progress?("Artifact review saved", report.items.count, report.items.count)
    return report
  }

  static func apply(
    review: TransferArtifactCleanupReview, recoveryRoot: String,
    allowedRepositoryRoots: [String], protectedRootPaths: [String],
    environment: [String: String], progress: Progress? = nil
  ) throws -> TransferArtifactCleanupResult {
    let age = Date().timeIntervalSince(review.createdAt)
    guard age >= 0, age < 1_800, let batchID = UUID(uuidString: review.id),
          batchID.uuidString.caseInsensitiveCompare(review.id) == .orderedSame else {
      throw failure("Run a fresh artifact review before cleanup; this review has expired or has an invalid identity.")
    }
    let roots = try allowedRoots(allowedRepositoryRoots)
    let recovery = try physicalFutureDirectory(recoveryRoot)
    for item in review.items {
      for path in [item.artifactPath, item.canonicalPath] where !path.isEmpty {
        guard !isWithin(recovery, path) else { throw failure("Recovery storage must be outside all reviewed source and canonical folders.") }
      }
    }
    try privateDirectory(recovery)
    let container = (recovery as NSString).appendingPathComponent(review.id)
    guard Darwin.mkdir(container, 0o700) == 0 else {
      throw failure("This cleanup batch already exists or cannot be created. Resume its verification before starting a fresh review.")
    }
    let resultPath = (container as NSString).appendingPathComponent("result.json")
    let ledgerPath = (container as NSString).appendingPathComponent("pending-ledger.json")
    guard !existsNoFollow(resultPath), !existsNoFollow(ledgerPath) else {
      throw failure("This cleanup batch already has durable session evidence. Resume verification before starting a fresh review.")
    }
    var receipts: [TransferArtifactCleanupReceipt] = []
    var failures: [TransferArtifactCleanupFailure] = []
    var ledger = PendingLedger(reviewID: review.id, reviewEvidencePath: review.evidencePath,
      recoveryRoot: recovery, resultPath: resultPath, locations: [])
    try save(ledger, to: ledgerPath)
    try save(TransferArtifactCleanupResult(reviewID: review.id, createdAt: Date(), receipts: [], failures: [],
      resultPath: resultPath, attemptedCount: review.items.count), to: resultPath)
    let references = canonicalReferenceBlockers(review.items, allowedRoots: roots, useCurrentInventory: true, progress: progress)
    for (index, item) in review.items.enumerated() {
      progress?("Preserving \((item.artifactPath as NSString).lastPathComponent)", index + 1, review.items.count)
      let dependencies = (references.bySource[item.artifactPath] ?? []) + (references.error.map { [$0] } ?? [])
      if !dependencies.isEmpty {
        failures.append(TransferArtifactCleanupFailure(artifactPath: item.artifactPath, detail: dependencies.joined(separator: " ")))
      } else if !item.canClean {
        failures.append(TransferArtifactCleanupFailure(artifactPath: item.artifactPath,
          detail: item.blockers.isEmpty ? "Complete preservation evidence is unavailable." : item.blockers.joined(separator: " ")))
      } else {
        do {
          let receipt = try archiveItem(item, reviewEvidencePath: review.evidencePath, container: container,
            allowedRoots: roots, protectedRootPaths: protectedRootPaths, environment: environment) { full in
              ledger.locations.append(PendingLocation(originalPath: full.originalPath, archivePath: full.archivePath,
                preparedReceiptPath: (full.receiptPath as NSString).deletingLastPathComponent + "/retirement-prepared.json",
                receiptPath: full.receiptPath))
              try save(ledger, to: ledgerPath)
            }
          receipts.append(receipt)
        } catch {
          if error is SimulatedInterruption { throw error }
          failures.append(TransferArtifactCleanupFailure(artifactPath: item.artifactPath, detail: error.localizedDescription))
        }
      }
      // Persist progress after each item so partial completion survives restart.
      let interim = TransferArtifactCleanupResult(reviewID: review.id, createdAt: Date(), receipts: receipts,
        failures: failures, resultPath: resultPath, attemptedCount: review.items.count)
      try save(interim, to: resultPath)
    }
    let result = TransferArtifactCleanupResult(reviewID: review.id, createdAt: Date(), receipts: receipts,
      failures: failures, resultPath: resultPath, attemptedCount: review.items.count)
    try save(result, to: resultPath)
    progress?(result.completedAll ? "All transaction folders preserved and retired" : "Artifact cleanup needs review",
      review.items.count, review.items.count)
    return result
  }

  /// Recover a saved interrupted batch without making any new source moves.
  /// Complete source proofs keep preserved archives visible and restorable.
  /// Later canonical changes are reported separately; untouched sources need
  /// a fresh review before any move.
  static func recoverPending(
    review: TransferArtifactCleanupReview, recoveryRoot: String,
    allowedRepositoryRoots: [String], protectedRootPaths: [String],
    environment: [String: String], progress: Progress? = nil
  ) throws -> TransferArtifactCleanupResult {
    guard let id = UUID(uuidString: review.id), id.uuidString.caseInsensitiveCompare(review.id) == .orderedSame else {
      throw failure("The saved cleanup review has an invalid session identity.")
    }
    let roots = try allowedRoots(allowedRepositoryRoots)
    let recovery = try physicalFutureDirectory(recoveryRoot)
    let container = (recovery as NSString).appendingPathComponent(review.id)
    if review.items.isEmpty {
      try privateDirectory(recovery)
      try privateDirectory(container)
      let path = (container as NSString).appendingPathComponent("result.json")
      if existsNoFollow(path) {
        let previous = try load(TransferArtifactCleanupResult.self, from: path)
        guard previous.reviewID == review.id, previous.attemptedCount == 0,
              previous.receipts.isEmpty, previous.failures.isEmpty else { throw failure("An existing nonempty cleanup session cannot be replaced by an empty review.") }
      }
      let result = TransferArtifactCleanupResult(reviewID: review.id, createdAt: Date(), receipts: [], failures: [], resultPath: path, attemptedCount: 0)
      try save(result, to: path)
      progress?("No transaction folders require cleanup", 0, 0)
      return result
    }
    guard try physicalDirectory(container) == container else { throw failure("The saved cleanup session's physical parents changed.") }
    let resultPath = (container as NSString).appendingPathComponent("result.json")
    let ledger = try load(PendingLedger.self, from: (container as NSString).appendingPathComponent("pending-ledger.json"))
    guard ledger.reviewID == review.id, ledger.reviewEvidencePath == review.evidencePath,
          ledger.recoveryRoot == recovery, ledger.resultPath == resultPath else {
      throw failure("The saved pending ledger does not match this cleanup session.")
    }
    let previous = try load(TransferArtifactCleanupResult.self, from: resultPath)
    guard previous.reviewID == review.id, previous.attemptedCount == review.items.count else { throw failure("The saved result does not match this pending cleanup review.") }
    var receiptMap = Dictionary(previous.receipts.map { ($0.originalPath, $0) }, uniquingKeysWith: { first, _ in first })
    var failures: [TransferArtifactCleanupFailure] = []
    for (index, item) in review.items.enumerated() {
      progress?("Verifying interrupted preservation: \((item.artifactPath as NSString).lastPathComponent)", index + 1, review.items.count)
      do {
        try validateSourceLocation(item.artifactPath, allowedRoots: roots, protectedRootPaths: protectedRootPaths)
        let locations = ledger.locations.filter { $0.originalPath == item.artifactPath }
        guard locations.count == 1, let location = locations.first else {
          throw failure(item.blockers.isEmpty ? "This source was not moved. Run a fresh review of the remaining transaction folders." : item.blockers.joined(separator: " "))
        }
        let originalExists = existsNoFollow(item.artifactPath), archiveExists = existsNoFollow(location.archivePath)
        guard !originalExists, archiveExists else {
          if originalExists && archiveExists { throw failure("Both the original and preserved folders exist. Both were retained; inspect them before continuing.") }
          if originalExists { throw failure("The original source remains in place. Run a fresh review before moving it.") }
          throw failure("Neither the original nor its recorded archive is available. Review recovery storage before continuing.")
        }
        guard location.archivePath.hasPrefix(container + "/") else { throw failure("A pending archive points outside this recovery session.") }
        let relative = String(location.archivePath.dropFirst(container.count + 1)).split(separator: "/", omittingEmptySubsequences: false)
        guard relative.count == 2, let locationID = UUID(uuidString: String(relative[0])),
              locationID.uuidString.caseInsensitiveCompare(String(relative[0])) == .orderedSame,
              String(relative[1]) == (item.artifactPath as NSString).lastPathComponent else {
          throw failure("The pending archive location is not an exact session item directory.")
        }
        let leaf = (container as NSString).appendingPathComponent(String(relative[0]))
        guard try physicalDirectory(leaf) == leaf,
              location.preparedReceiptPath == (leaf as NSString).appendingPathComponent("retirement-prepared.json"),
              location.receiptPath == (leaf as NSString).appendingPathComponent("retirement.json") else {
          throw failure("The pending receipt location or its physical parents changed.")
        }
        guard let summary = item.inventory, let canonicalSummary = item.canonicalInventory else { throw failure("The pending item has no complete review proof.") }
        let full = try load(CheckoutRetirementReceipt.self, from: location.preparedReceiptPath)
        try validateManifestDigest(full.inventory)
        guard UUID(uuidString: full.id) != nil, full.originalPath == item.artifactPath, full.keptPath == item.canonicalPath,
              full.archivePath == location.archivePath, full.receiptPath == location.receiptPath,
              full.reviewEvidencePath == review.evidencePath,
              full.archivePath == (container as NSString).appendingPathComponent(full.id + "/" + (item.artifactPath as NSString).lastPathComponent),
              location.preparedReceiptPath == (full.receiptPath as NSString).deletingLastPathComponent + "/retirement-prepared.json",
              try TransferArtifactInventorySummary(full.inventory) == summary else {
          throw failure("The pending archive or full prepared receipt does not match the reviewed source.")
        }
        guard try physicalDirectory(full.archivePath) == full.archivePath else { throw failure("The pending archive's physical parents changed.") }
        let archived = try CheckoutPairReviewEngine.inventory(path: full.archivePath, maxDuration: 300)
        guard try TransferArtifactInventorySummary(archived) == summary else { throw failure("The pending archive failed full checksum and metadata read-back.") }
        do { try verifyCanonical(item.canonicalPath, expected: canonicalSummary) }
        catch {
          failures.append(TransferArtifactCleanupFailure(artifactPath: item.artifactPath,
            detail: "The complete archive is checksum verified and remains restorable. The canonical sibling changed after the saved review: \(error.localizedDescription)"))
        }
        try save(full, to: full.receiptPath)
        let light = TransferArtifactCleanupReceipt(id: full.id, createdAt: full.createdAt,
          originalPath: full.originalPath, archivePath: full.archivePath, keptPath: full.keptPath,
          receiptPath: full.receiptPath, reviewEvidencePath: full.reviewEvidencePath, inventory: summary)
        try save(light, to: (full.receiptPath as NSString).deletingLastPathComponent + "/retirement-summary.json")
        receiptMap[light.originalPath] = light
      } catch {
        failures.append(TransferArtifactCleanupFailure(artifactPath: item.artifactPath, detail: error.localizedDescription))
      }
    }
    let receipts = receiptMap.values.sorted { $0.originalPath < $1.originalPath }
    let result = TransferArtifactCleanupResult(reviewID: review.id, createdAt: Date(), receipts: receipts, failures: failures,
      resultPath: resultPath, attemptedCount: review.items.count)
    try save(result, to: resultPath)
    progress?(result.completedAll ? "Interrupted preservation verified" : "Verified archives retained; remaining sources need review", review.items.count, review.items.count)
    return result
  }

  static func restore(
    receipt: TransferArtifactCleanupReceipt, protectedRootPaths: [String], environment: [String: String]
  ) throws -> CheckoutRestoreReceipt {
    let full = try load(CheckoutRetirementReceipt.self, from: receipt.receiptPath)
    try validateManifestDigest(full.inventory)
    guard full.id == receipt.id, full.originalPath == receipt.originalPath, full.archivePath == receipt.archivePath,
          full.keptPath == receipt.keptPath, full.receiptPath == receipt.receiptPath,
          try TransferArtifactInventorySummary(full.inventory) == receipt.inventory else {
      throw failure("The saved retirement receipt does not match its selected source and recovery evidence.")
    }
    return try CheckoutPairReviewEngine.restore(receipt: full, protectedRootPaths: protectedRootPaths,
      environment: environment, inventoryMaxDuration: 300)
  }

  private static func reviewItem(
    source: String, allowedRoots: [String], protectedRootPaths: [String], directory: URL,
    canonicalManifests: inout [String: String]
  ) -> TransferArtifactCleanupItem {
    let parsed = parseArtifactName((source as NSString).lastPathComponent)
    let canonical = parsed.map { ((source as NSString).deletingLastPathComponent as NSString).appendingPathComponent($0.base) } ?? ""
    var artifactSummary: TransferArtifactInventorySummary?, canonicalSummary: TransferArtifactInventorySummary?
    var sourceManifestPath: String?, canonicalManifestPath: String?
    var missing: [String] = [], different: [String] = [], metadata: [String] = []
    var identical = 0, blockers: [String] = []
    do {
      guard let parsed else { throw failure("The folder name is not an exact CSA-iEM stage/backup transaction name with a UUID.") }
      guard !CheckoutDiscoveryRules.isTransferArtifactName(parsed.base) else { throw failure("The canonical sibling is another transaction artifact; manual review is required.") }
      try validateSource(source, allowedRoots: allowedRoots, protectedRootPaths: protectedRootPaths)
      let physicalCanonical = try physicalDirectory(canonical)
      guard physicalCanonical == canonical, !isWithin(source, canonical), !isWithin(canonical, source) else {
        throw failure("The artifact and canonical sibling must be distinct real directories with stable physical parents.")
      }
      let sourceInventory = try CheckoutPairReviewEngine.inventory(path: source, maxDuration: 300)
      try validateGitStorage(sourceInventory, sourcePath: source)
      artifactSummary = try TransferArtifactInventorySummary(sourceInventory)
      let sourcePath = directory.appendingPathComponent("source-" + pathKey(source) + ".json").path
      try save(sourceInventory, to: sourcePath); sourceManifestPath = sourcePath
      let canonicalInventory: CheckoutFileInventory
      if let saved = canonicalManifests[canonical] {
        canonicalInventory = try load(CheckoutFileInventory.self, from: saved)
        try validateManifestDigest(canonicalInventory)
        canonicalManifestPath = saved
      } else {
        canonicalInventory = try CheckoutPairReviewEngine.inventory(path: canonical, maxDuration: 300)
        let canonicalPath = directory.appendingPathComponent("canonical-" + pathKey(canonical) + ".json").path
        try save(canonicalInventory, to: canonicalPath)
        canonicalManifests[canonical] = canonicalPath; canonicalManifestPath = canonicalPath
      }
      canonicalSummary = try TransferArtifactInventorySummary(canonicalInventory)
      guard sourceInventory.rootDevice != canonicalInventory.rootDevice || sourceInventory.rootInode != canonicalInventory.rootInode else {
        throw failure("The artifact and canonical sibling identify the same physical directory.")
      }
      for (path, entry) in sourceInventory.entries {
        guard let keeper = canonicalInventory.entries[path] else { missing.append(path); continue }
        if contentMatches(entry, keeper) {
          if entry.kind == "file" { identical += 1 }
        } else { different.append(path) }
        if entry.mode != keeper.mode || entry.mtimeNanoseconds != keeper.mtimeNanoseconds || entry.flags != keeper.flags || entry.xattrs != keeper.xattrs {
          metadata.append(path)
        }
      }
      if artifactSummary?.rootMetadataDigest != canonicalSummary?.rootMetadataDigest { metadata.append(".") }
    } catch { blockers.append(error.localizedDescription) }
    missing.sort(); different.sort(); metadata.sort()
    return TransferArtifactCleanupItem(id: source, artifactPath: source, canonicalPath: canonical,
      artifactKind: parsed?.kind ?? "unknown", transactionID: parsed?.transactionID ?? "",
      inventory: artifactSummary, canonicalInventory: canonicalSummary, inventoryPath: sourceManifestPath,
      canonicalInventoryPath: canonicalManifestPath, missingPaths: Array(missing.prefix(20)),
      differentPaths: Array(different.prefix(20)), metadataDifferentPaths: Array(metadata.prefix(20)),
      missingCount: missing.count, differentCount: different.count, metadataDifferentCount: metadata.count,
      identicalFiles: identical, blockers: blockers)
  }

  private static func archiveItem(
    _ item: TransferArtifactCleanupItem, reviewEvidencePath: String, container: String,
    allowedRoots: [String], protectedRootPaths: [String], environment: [String: String],
    willMove: (CheckoutRetirementReceipt) throws -> Void
  ) throws -> TransferArtifactCleanupReceipt {
    try validateSource(item.artifactPath, allowedRoots: allowedRoots, protectedRootPaths: protectedRootPaths)
    guard let sourceSummary = item.inventory, let canonicalSummary = item.canonicalInventory,
          let manifestPath = item.inventoryPath, let canonicalManifestPath = item.canonicalInventoryPath,
          let parsed = parseArtifactName((item.artifactPath as NSString).lastPathComponent),
          ((item.artifactPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(parsed.base) == item.canonicalPath else {
      throw failure("The reviewed artifact identity or preservation evidence is incomplete.")
    }
    // Verify durable proof before any move; light summaries include root state.
    try verifySavedManifest(manifestPath, expected: sourceSummary)
    try verifySavedManifest(canonicalManifestPath, expected: canonicalSummary)
    try verifyCanonical(item.canonicalPath, expected: canonicalSummary, artifactPath: item.artifactPath)
    let freshSource = try CheckoutPairReviewEngine.inventory(path: item.artifactPath, maxDuration: 300)
    try validateGitStorage(freshSource, sourcePath: item.artifactPath)
    guard try TransferArtifactInventorySummary(freshSource) == sourceSummary else { throw failure("The artifact changed after review. Its files remain in place; run another review.") }
    try ensureInactive(item.artifactPath, environment: environment)
    let containerInfo = try directoryStatus(container)
    guard Int64(containerInfo.st_dev) == sourceSummary.rootDevice else { throw failure("Reversible cleanup requires recovery storage on the artifact's volume.") }
    let id = UUID().uuidString
    let itemContainer = (container as NSString).appendingPathComponent(id)
    try privateDirectory(itemContainer)
    let archive = (itemContainer as NSString).appendingPathComponent((item.artifactPath as NSString).lastPathComponent)
    let fullReceipt = CheckoutRetirementReceipt(id: id, createdAt: Date(), originalPath: item.artifactPath,
      archivePath: archive, keptPath: item.canonicalPath,
      receiptPath: (itemContainer as NSString).appendingPathComponent("retirement.json"),
      reviewEvidencePath: reviewEvidencePath, inventory: freshSource)
    let light = TransferArtifactCleanupReceipt(id: id, createdAt: fullReceipt.createdAt,
      originalPath: fullReceipt.originalPath, archivePath: archive, keptPath: item.canonicalPath,
      receiptPath: fullReceipt.receiptPath, reviewEvidencePath: reviewEvidencePath, inventory: sourceSummary)
    try save(fullReceipt, to: (itemContainer as NSString).appendingPathComponent("retirement-prepared.json"))
    try willMove(fullReceipt)
    guard renameExclusive(item.artifactPath, archive) == 0 else { throw posixFailure("Could not preserve transaction folder") }
    do {
      let interrupted = environment["CSA_IEM_TEST_INTERRUPT_ARTIFACT_ARCHIVE_AFTER_RENAME"]
      if interrupted == "1" || interrupted == item.artifactPath { throw SimulatedInterruption() }
      let injected = environment["CSA_IEM_TEST_FAIL_ARTIFACT_ARCHIVE_AFTER_RENAME"]
      if injected == "1" || injected == item.artifactPath { throw failure("Injected artifact preservation verification failure.") }
      guard !existsNoFollow(item.artifactPath),
            try TransferArtifactInventorySummary(CheckoutPairReviewEngine.inventory(path: archive, maxDuration: 300)) == sourceSummary else {
        throw failure("The preserved transaction folder failed full read-back verification.")
      }
      try verifyCanonical(item.canonicalPath, expected: canonicalSummary, artifactPath: item.artifactPath)
      try save(fullReceipt, to: fullReceipt.receiptPath)
      try save(light, to: (itemContainer as NSString).appendingPathComponent("retirement-summary.json"))
      return light
    } catch {
      if error is SimulatedInterruption { throw error }
      if !existsNoFollow(item.artifactPath), renameExclusive(archive, item.artifactPath) == 0 { throw error }
      throw failure("Preservation stopped; the complete transaction folder remains at \(archive). The original path could not be restored: \(error.localizedDescription)")
    }
  }

  private static func verifyCanonical(_ path: String, expected: TransferArtifactInventorySummary, artifactPath: String? = nil) throws {
    guard try physicalDirectory(path) == path else { throw failure("The canonical sibling's physical parents changed.") }
    let current = try CheckoutPairReviewEngine.inventory(path: path, maxDuration: 300)
    guard try TransferArtifactInventorySummary(current) == expected else { throw failure("The canonical sibling changed after review. Cleanup is blocked; no canonical file was overwritten.") }
    if let artifactPath, !referencedSources(canonicalPath: path, inventory: current, sources: [artifactPath]).isEmpty {
      throw failure("The canonical checkout has a symlink into this transaction folder. Preserve the folder and repair that dependency before retirement.")
    }
  }
  private struct CanonicalReferences { let bySource: [String: [String]]; let error: String? }
  private static func canonicalReferenceBlockers(
    _ items: [TransferArtifactCleanupItem], allowedRoots: [String], useCurrentInventory: Bool, progress: Progress?
  ) -> CanonicalReferences {
    let sources = items.map(\.artifactPath)
    var bySource: [String: [String]] = [:], visited = Set<String>()
    for (index, item) in items.enumerated() where !item.canonicalPath.isEmpty {
      guard (try? validateSourceLocation(item.artifactPath, allowedRoots: allowedRoots, protectedRootPaths: [])) != nil,
            let parsed = parseArtifactName((item.artifactPath as NSString).lastPathComponent),
            ((item.artifactPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(parsed.base) == item.canonicalPath else { continue }
      guard visited.insert(item.canonicalPath).inserted else { continue }
      if !existsNoFollow(item.canonicalPath) { continue }
      progress?("Checking canonical link dependencies: \((item.canonicalPath as NSString).lastPathComponent)", index + 1, items.count)
      do {
        guard try physicalDirectory(item.canonicalPath) == item.canonicalPath else { throw failure("A canonical link dependency path's physical parents changed.") }
        let inventory: CheckoutFileInventory
        if useCurrentInventory || item.canonicalInventoryPath == nil {
          inventory = try CheckoutPairReviewEngine.inventory(path: item.canonicalPath, maxDuration: 300)
        } else {
          inventory = try load(CheckoutFileInventory.self, from: item.canonicalInventoryPath!)
          try validateManifestDigest(inventory)
        }
        for source in referencedSources(canonicalPath: item.canonicalPath, inventory: inventory, sources: sources) {
          bySource[source, default: []].append("Canonical checkout \(item.canonicalPath) has a symlink into this transaction folder. Its dependency must be repaired before retirement.")
        }
      } catch {
        return CanonicalReferences(bySource: bySource,
          error: "Canonical link dependency verification could not complete: \(error.localizedDescription)")
      }
    }
    return CanonicalReferences(bySource: bySource, error: nil)
  }
  private static func referencedSources(canonicalPath: String, inventory: CheckoutFileInventory, sources: [String]) -> Set<String> {
    var referenced = Set<String>()
    for (relative, entry) in inventory.entries where entry.kind == "symlink" {
      guard let target = entry.linkTarget else { continue }
      let link = (canonicalPath as NSString).appendingPathComponent(relative)
      let raw = target.hasPrefix("/") ? target : ((link as NSString).deletingLastPathComponent as NSString).appendingPathComponent(target)
      let lexical = (raw as NSString).standardizingPath, physical = physicalExistingPath(lexical)
      for source in sources where isWithin(lexical, source) || isWithin(physical, source) { referenced.insert(source) }
    }
    return referenced
  }
  private static func verifySavedManifest(_ path: String, expected: TransferArtifactInventorySummary) throws {
    let saved = try load(CheckoutFileInventory.self, from: path)
    try validateManifestDigest(saved)
    guard try TransferArtifactInventorySummary(saved) == expected else { throw failure("Saved full-file preservation evidence no longer matches this review.") }
  }
  private static func validateManifestDigest(_ inventory: CheckoutFileInventory) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    let digest = SHA256.hash(data: try encoder.encode(inventory.entries)).map { String(format: "%02x", $0) }.joined()
    guard digest == inventory.manifestDigest else { throw failure("The saved full-file manifest failed its integrity check.") }
  }
  private static func validateGitStorage(_ inventory: CheckoutFileInventory, sourcePath: String) throws {
    if let git = inventory.entries[".git"], git.kind != "directory" {
      throw failure("Linked or external Git storage requires separate checkout review; this artifact remains in place.")
    }
    if inventory.entries[".git/commondir"] != nil { throw failure("Shared Git storage requires separate checkout review before retirement.") }
    if inventory.entries[".git/worktrees"] != nil { throw failure("Registered external Git worktrees require separate checkout review before retirement.") }
    if let config = inventory.entries[".git/config"], config.kind == "file" {
      guard config.size <= 1_024 * 1_024 else { throw failure("Large Git configuration requires manual storage review before artifact cleanup.") }
      let root = open(sourcePath, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      guard root >= 0 else { throw posixFailure("Could not inspect Git storage metadata") }
      defer { close(root) }
      let git = openat(root, ".git", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      guard git >= 0 else { throw posixFailure("Could not inspect Git storage directory") }
      defer { close(git) }
      let file = openat(git, "config", O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
      guard file >= 0 else { throw posixFailure("Could not inspect Git worktree configuration") }
      let handle = FileHandle(fileDescriptor: file, closeOnDealloc: true); defer { try? handle.close() }
      let data = try handle.read(upToCount: 1_024 * 1_024 + 1) ?? Data()
      guard data.count <= 1_024 * 1_024,
            SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == config.sha256,
            let text = String(data: data, encoding: .utf8) else { throw failure("Git storage metadata changed or could not be reviewed safely.") }
      var core = false
      for line in text.components(separatedBy: .newlines) {
        let value = line.trimmingCharacters(in: .whitespaces).lowercased()
        if value.hasPrefix("#") || value.hasPrefix(";") { continue }
        if value.hasPrefix("["), let end = value.firstIndex(of: "]") {
          core = value[value.index(after: value.startIndex)..<end].trimmingCharacters(in: .whitespaces) == "core"
        } else if core && value.range(of: "^worktree\\s*(=|$)", options: .regularExpression) != nil {
          throw failure("Explicit Git core.worktree storage requires separate checkout review before retirement.")
        }
      }
    }
  }
  private static func contentMatches(_ a: CheckoutManifestEntry, _ b: CheckoutManifestEntry) -> Bool {
    a.kind == b.kind && a.size == b.size && a.sha256 == b.sha256 && a.linkTarget == b.linkTarget
  }
  private struct ParsedName { let base: String; let kind: String; let transactionID: String }
  private static func parseArtifactName(_ name: String) -> ParsedName? {
    guard !name.contains("/"), !name.contains("\0") else { return nil }
    for (marker, kind) in [(".csa-iem-stage-", "stage"), (".csa-iem-backup-", "backup")] {
      guard let range = name.range(of: marker, options: .backwards), range.lowerBound != name.startIndex else { continue }
      let suffix = String(name[range.upperBound...]), base = String(name[..<range.lowerBound])
      guard base != ".", base != "..", suffix.utf8.count == 36,
            let id = UUID(uuidString: suffix), id.uuidString.caseInsensitiveCompare(suffix) == .orderedSame else { continue }
      return ParsedName(base: base, kind: kind, transactionID: id.uuidString)
    }
    return nil
  }
  private static func validateSource(_ path: String, allowedRoots: [String], protectedRootPaths: [String]) throws {
    try validateSourceLocation(path, allowedRoots: allowedRoots, protectedRootPaths: protectedRootPaths)
    guard try physicalDirectory(path) == path else { throw failure("The transaction source's physical parents changed.") }
  }
  private static func validateSourceLocation(_ path: String, allowedRoots: [String], protectedRootPaths: [String]) throws {
    guard let parsed = parseArtifactName((path as NSString).lastPathComponent), !parsed.base.isEmpty else { throw failure("The selected folder is not a recognized transaction artifact.") }
    let physical = try physicalFutureDirectory(path)
    guard physical == path, allowedRoots.contains(where: { path != $0 && isWithin(path, $0) }) else { throw failure("The artifact must remain inside an explicitly allowed repository root with stable physical parents.") }
    for raw in protectedRootPaths where !raw.isEmpty {
      let protected = physicalExistingPath(raw)
      if isWithin(path, protected) || isWithin(protected, path) { throw failure("This transaction folder overlaps a protected active workspace and cannot be retired.") }
    }
  }
  private static func allowedRoots(_ paths: [String]) throws -> [String] {
    guard !paths.isEmpty else { throw failure("Explicit repository roots are required for transaction cleanup.") }
    var roots: [String] = []
    for path in paths {
      let normalized = try absolutePath(path)
      if existsNoFollow(normalized) { roots.append(try physicalDirectory(normalized)) }
    }
    guard !roots.isEmpty else { throw failure("None of the allowed repository roots is available.") }
    return Array(Set(roots))
  }
  private static func ensureInactive(_ path: String, environment: [String: String]) throws {
    let cwd = physicalExistingPath(FileManager.default.currentDirectoryPath)
    guard !isWithin(cwd, path) else { throw failure("The transaction folder contains the active process working directory.") }
    let temporary = (FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path as NSString).appendingPathComponent("csa-artifact-ownership-" + UUID().uuidString)
    try privateDirectory(temporary)
    defer { try? FileManager.default.removeItem(atPath: temporary) }
    let outputPath = (temporary as NSString).appendingPathComponent("lsof-output")
    guard FileManager.default.createFile(atPath: outputPath, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw failure("Could not create private process-ownership evidence.") }
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath)); defer { try? handle.close() }
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-Fpn", "+D", path]; process.environment = environment
    process.standardInput = FileHandle.nullDevice; process.standardOutput = handle; process.standardError = handle
    try process.run()
    let deadline = ProcessInfo.processInfo.systemUptime + 60
    while process.isRunning {
      var info = stat()
      if ProcessInfo.processInfo.systemUptime >= deadline || (lstat(outputPath, &info) == 0 && info.st_size > 4 * 1_024 * 1_024) {
        stop(process); throw failure("Process-ownership verification exceeded its time or output limit; the artifact remains in place.")
      }
      Thread.sleep(forTimeInterval: 0.02)
    }
    try handle.synchronize()
    var final = stat()
    guard lstat(outputPath, &final) == 0, final.st_size == 0, process.terminationStatus == 1 else {
      throw failure("The artifact has active files, a process working directory, or an incomplete ownership check. Close it before cleanup.")
    }
  }
  private static func stop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate(); let deadline = ProcessInfo.processInfo.systemUptime + 0.5
    while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { Thread.sleep(forTimeInterval: 0.02) }
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    let forced = ProcessInfo.processInfo.systemUptime + 1
    while process.isRunning && ProcessInfo.processInfo.systemUptime < forced { Thread.sleep(forTimeInterval: 0.02) }
  }
  private static func isWithin(_ path: String, _ parent: String) -> Bool { path == parent || path.hasPrefix(parent + "/") }
  private static func physicalExistingPath(_ raw: String) -> String {
    URL(fileURLWithPath: (raw as NSString).standardizingPath).resolvingSymlinksInPath().path
  }
  private static func absolutePath(_ raw: String) throws -> String {
    let path = (raw as NSString).standardizingPath
    guard path.hasPrefix("/"), path != "/", !path.contains("\0") else { throw failure("An explicit absolute transaction-folder path is required.") }
    return path
  }
  private static func physicalDirectory(_ raw: String) throws -> String {
    let path = try absolutePath(raw); _ = try directoryStatus(path)
    return physicalExistingPath(path)
  }
  private static func physicalFutureDirectory(_ raw: String) throws -> String {
    var current = URL(fileURLWithPath: try absolutePath(raw), isDirectory: true), suffix: [String] = []
    while !existsNoFollow(current.path) {
      suffix.insert(current.lastPathComponent, at: 0)
      let parent = current.deletingLastPathComponent()
      guard parent.path != current.path else { throw failure("The evidence or recovery destination has no inspectable parent.") }
      current = parent
    }
    let base = try physicalDirectory(current.path)
    return suffix.reduce(base) { ($0 as NSString).appendingPathComponent($1) }
  }
  private static func directoryStatus(_ path: String) throws -> stat {
    var info = stat()
    guard lstat(path, &info) == 0 else { throw posixFailure("Could not inspect transaction folder") }
    guard info.st_mode & S_IFMT == S_IFDIR else { throw failure("Transaction and canonical roots must be real directories; symlink roots are not followed.") }
    return info
  }
  private static func privateDirectory(_ path: String) throws {
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    _ = try directoryStatus(path)
  }
  private static func existsNoFollow(_ path: String) -> Bool { var info = stat(); return lstat(path, &info) == 0 || errno != ENOENT }
  private static func renameExclusive(_ source: String, _ destination: String) -> Int32 {
    source.withCString { from in destination.withCString { to in renamex_np(from, to, UInt32(RENAME_EXCL)) } }
  }
  private static func pathKey(_ path: String) -> String { SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined() }
  private static func failure(_ detail: String) -> NSError { NSError(domain: "CSA-iEM.TransferArtifactCleanup", code: 1, userInfo: [NSLocalizedDescriptionKey: detail]) }
  private static func posixFailure(_ detail: String) -> NSError { failure("\(detail): \(String(cString: strerror(errno)))") }
  private static func load<T: Decodable>(_ type: T.Type, from path: String) throws -> T {
    var info = stat()
    guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
          info.st_size <= 512 * 1_024 * 1_024 else { throw failure("Saved preservation evidence is missing, linked, or exceeds the 512 MB limit.") }
    let fd = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { throw posixFailure("Could not open saved preservation evidence") }
    var opened = stat()
    guard fstat(fd, &opened) == 0, opened.st_dev == info.st_dev, opened.st_ino == info.st_ino,
          opened.st_size == info.st_size else { close(fd); throw failure("Saved preservation evidence changed while opening.") }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? handle.close() }
    var data = Data()
    let readDeadline = ProcessInfo.processInfo.systemUptime + 300
    while true {
      guard ProcessInfo.processInfo.systemUptime < readDeadline else { throw failure("Reading saved preservation evidence exceeded the five-minute limit.") }
      guard let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty else { break }
      guard ProcessInfo.processInfo.systemUptime < readDeadline else { throw failure("Reading saved preservation evidence exceeded the five-minute limit.") }
      guard data.count <= 512 * 1_024 * 1_024 - chunk.count else { throw failure("Saved preservation evidence exceeded its read limit.") }
      data.append(chunk)
    }
    guard ProcessInfo.processInfo.systemUptime < readDeadline else { throw failure("Reading saved preservation evidence exceeded the five-minute limit.") }
    var after = stat()
    guard fstat(fd, &after) == 0, after.st_size == opened.st_size,
          after.st_mtimespec.tv_sec == opened.st_mtimespec.tv_sec,
          after.st_mtimespec.tv_nsec == opened.st_mtimespec.tv_nsec else {
      throw failure("Saved preservation evidence changed while being read.")
    }
    guard !data.isEmpty else { throw failure("Saved preservation evidence is empty.") }
    return try JSONDecoder().decode(type, from: data)
  }
  private static func save<T: Encodable>(_ value: T, to path: String) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    guard data.count <= 512 * 1_024 * 1_024 else { throw failure("Preservation evidence exceeds the 512 MB restore limit. No source move is authorized.") }
    let target = URL(fileURLWithPath: path), temp = target.deletingLastPathComponent().appendingPathComponent(".artifact-proof-" + UUID().uuidString)
    guard FileManager.default.createFile(atPath: temp.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw failure("Could not create private preservation evidence.") }
    defer { try? FileManager.default.removeItem(at: temp) }
    let handle = try FileHandle(forWritingTo: temp)
    do { try handle.write(contentsOf: data); try handle.synchronize(); try handle.close() }
    catch { try? handle.close(); throw error }
    guard Darwin.rename(temp.path, target.path) == 0 else { throw posixFailure("Could not save preservation evidence") }
  }
}
