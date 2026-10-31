import Foundation
import XCTest
@testable import CSAiEMMacApp

final class TransferArtifactCleanupTests: XCTestCase {
  func testReviewMapsExactStageAndBackupNamesAndInventoriesAllFiles() throws {
    try fixture { fixture in
      let stage = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage")
      let backup = try fixture.artifact(owner: "OwnerB", name: "Project", kind: "backup", role: "Runtime")
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stage.source.appendingPathComponent("README.md").path)
      let review = try fixture.review([stage.source, backup.source])
      XCTAssertEqual(review.readyCount, 2)
      XCTAssertEqual(review.blockedCount, 0)
      let item = try XCTUnwrap(review.items.first(where: { $0.artifactPath == stage.source.path }))
      XCTAssertEqual(item.canonicalPath, stage.canonical.path)
      XCTAssertEqual(item.artifactKind, "stage")
      XCTAssertEqual(item.inventory?.fileCount, 26)
      let inventoryPath = try XCTUnwrap(item.inventoryPath)
      let inventory = try JSONDecoder().decode(CheckoutFileInventory.self, from: Data(contentsOf: URL(fileURLWithPath: inventoryPath)))
      XCTAssertNotNil(inventory.entries[".git/config"])
      XCTAssertNotNil(inventory.entries[".hidden/checkpoint"])
      XCTAssertNotNil(inventory.entries["node_modules/pkg/LICENSE 2"])
      XCTAssertNotNil(inventory.entries["unique.bin"])
      XCTAssertGreaterThan(item.missingCount, 0)
      XCTAssertFalse(item.missingPaths.isEmpty)
      XCTAssertTrue(item.differentPaths.contains("src/main.swift"))
      XCTAssertGreaterThan(item.metadataDifferentCount, 0)
      XCTAssertTrue(item.metadataDifferentPaths.contains("README.md"))
      XCTAssertGreaterThan(item.identicalFiles, 0)
      XCTAssertTrue(FileManager.default.fileExists(atPath: review.evidencePath))
    }
  }

  func testApplyPreservesAllMissingDifferentAndGitDataWithoutChangingCanonical() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage")
      let canonicalBefore = try CheckoutPairReviewEngine.inventory(path: project.canonical.path)
      let sourceBefore = try CheckoutPairReviewEngine.inventory(path: project.source.path)
      let result = try fixture.apply(fixture.review([project.source]))
      XCTAssertTrue(result.completedAll)
      XCTAssertTrue(result.failures.isEmpty)
      let receipt = try XCTUnwrap(result.receipts.first)
      let archive = URL(fileURLWithPath: receipt.archivePath)
      XCTAssertFalse(FileManager.default.fileExists(atPath: project.source.path))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: archive.path), sourceBefore)
      XCTAssertEqual(try Data(contentsOf: archive.appendingPathComponent("unique.bin")), Data([0, 1, 2, 255]))
      XCTAssertEqual(try String(contentsOf: archive.appendingPathComponent("src/main.swift"), encoding: .utf8), "older artifact version\n")
      XCTAssertTrue(FileManager.default.fileExists(atPath: archive.appendingPathComponent("node_modules/pkg/LICENSE 2").path))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: project.canonical.path), canonicalBefore)
      XCTAssertTrue(FileManager.default.fileExists(atPath: receipt.receiptPath))
      XCTAssertTrue(FileManager.default.fileExists(atPath: result.resultPath))
    }
  }

  func testSameBasenameAndTransactionAcrossOwnersAndRolesUseDistinctRecoveryPaths() throws {
    try fixture { fixture in
      let transaction = UUID().uuidString
      let a = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage", transaction: transaction)
      let b = try fixture.artifact(owner: "OwnerB", name: "Project", kind: "stage", transaction: transaction)
      let c = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage", role: "Runtime", transaction: transaction)
      let result = try fixture.apply(fixture.review([a.source, b.source, c.source]))
      XCTAssertTrue(result.completedAll)
      XCTAssertEqual(result.receipts.count, 3)
      XCTAssertEqual(Set(result.receipts.map(\.archivePath)).count, 3)
      XCTAssertEqual(Set(result.receipts.map(\.originalPath)), Set([a.source.path, b.source.path, c.source.path]))
      for receipt in result.receipts {
        XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: receipt.archivePath).fileCount, 26)
      }
    }
  }

  func testChangedArtifactAfterReviewBlocksCleanupWithoutDiscardingNewWork() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage")
      let review = try fixture.review([project.source])
      let changed = project.source.appendingPathComponent("new-work.txt")
      try write("new work must remain", to: changed)
      let result = try fixture.apply(review)
      XCTAssertFalse(result.completedAll)
      XCTAssertTrue(result.receipts.isEmpty)
      XCTAssertEqual(result.failures.count, 1)
      XCTAssertEqual(try String(contentsOf: changed, encoding: .utf8), "new work must remain")
    }
  }

  func testChangedCanonicalAfterReviewBlocksCleanupAndPreservesBothSides() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "backup")
      let sourceBefore = try CheckoutPairReviewEngine.inventory(path: project.source.path)
      let review = try fixture.review([project.source])
      let changed = project.canonical.appendingPathComponent("src/main.swift")
      try write("new canonical work must remain", to: changed)
      let result = try fixture.apply(review)
      XCTAssertFalse(result.completedAll)
      XCTAssertTrue(result.receipts.isEmpty)
      XCTAssertEqual(result.failures.count, 1)
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: project.source.path), sourceBefore)
      XCTAssertEqual(try String(contentsOf: changed, encoding: .utf8), "new canonical work must remain")
    }
  }

  func testSymlinkMalformedNamesOutsideRootsAndProtectedSourcesAreBlocked() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage")
      let link = project.source.deletingLastPathComponent().appendingPathComponent("Alias.csa-iem-stage-" + UUID().uuidString)
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: project.source)
      let malformed = project.source.deletingLastPathComponent().appendingPathComponent("Project.csa-iem-stage-not-a-uuid")
      try FileManager.default.createDirectory(at: malformed, withIntermediateDirectories: true)
      let outside = fixture.root.appendingPathComponent("unmanaged/OwnerA/Project.csa-iem-stage-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
      let review = try fixture.review([link, malformed, outside, project.source], protected: [project.source.path])
      XCTAssertEqual(review.readyCount, 0)
      XCTAssertEqual(review.blockedCount, 4)
      XCTAssertTrue(review.items.allSatisfy { !$0.canClean && !$0.blockers.isEmpty })
      XCTAssertTrue(FileManager.default.fileExists(atPath: project.source.path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }
  }

  func testProtectedCanonicalCanBeReadWhileOnlyArtifactIsRetired() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "ProtectedApp", kind: "stage")
      let canonicalBefore = try CheckoutPairReviewEngine.inventory(path: project.canonical.path)
      let review = try fixture.review([project.source], protected: [project.canonical.path])
      XCTAssertEqual(review.readyCount, 1)
      let result = try fixture.apply(review, protected: [project.canonical.path])
      XCTAssertTrue(result.completedAll)
      XCTAssertFalse(FileManager.default.fileExists(atPath: project.source.path))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: project.canonical.path), canonicalBefore)
    }
  }

  func testOrphanCanonicalIsBlockedAndDoesNotPreventAnotherVerifiedItem() throws {
    try fixture { fixture in
      let ready = try fixture.artifact(owner: "OwnerA", name: "Ready", kind: "stage")
      let orphan = try fixture.artifact(owner: "OwnerB", name: "Orphan", kind: "backup", createCanonical: false)
      let review = try fixture.review([ready.source, orphan.source])
      XCTAssertEqual(review.readyCount, 1)
      XCTAssertEqual(review.blockedCount, 1)
      let result = try fixture.apply(review)
      XCTAssertFalse(result.completedAll)
      XCTAssertEqual(result.receipts.count, 1)
      XCTAssertEqual(result.failures.count, 1)
      XCTAssertEqual(result.failures.first?.artifactPath, orphan.source.path)
      XCTAssertFalse(FileManager.default.fileExists(atPath: ready.source.path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: orphan.source.path))
    }
  }

  func testPostRenameFailureRollsBackOneArtifactAndReportsIncompleteBatch() throws {
    try fixture { fixture in
      let a = try fixture.artifact(owner: "OwnerA", name: "First", kind: "stage")
      let b = try fixture.artifact(owner: "OwnerB", name: "Second", kind: "backup")
      let bBefore = try CheckoutPairReviewEngine.inventory(path: b.source.path)
      let review = try fixture.review([a.source, b.source])
      var environment = fixture.environment
      environment["CSA_IEM_TEST_FAIL_ARTIFACT_ARCHIVE_AFTER_RENAME"] = b.source.path
      let result = try fixture.apply(review, environment: environment)
      XCTAssertFalse(result.completedAll)
      XCTAssertEqual(result.receipts.count, 1)
      XCTAssertEqual(result.receipts.first?.originalPath, a.source.path)
      XCTAssertEqual(result.failures.count, 1)
      XCTAssertEqual(result.failures.first?.artifactPath, b.source.path)
      XCTAssertFalse(FileManager.default.fileExists(atPath: a.source.path))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: b.source.path), bBefore)
    }
  }

  func testActiveArtifactProcessBlocksCleanup() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage")
      let review = try fixture.review([project.source])
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/bin/sleep")
      process.arguments = ["30"]
      process.currentDirectoryURL = project.source
      try process.run()
      defer {
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
      }
      let result = try fixture.apply(review)
      XCTAssertFalse(result.completedAll)
      XCTAssertTrue(result.receipts.isEmpty)
      XCTAssertEqual(result.failures.count, 1)
      XCTAssertTrue(FileManager.default.fileExists(atPath: project.source.path))
    }
  }

  func testSavedResultLoadsAndExistingRestoreReturnsWholeArtifact() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "backup")
      let before = try CheckoutPairReviewEngine.inventory(path: project.source.path)
      let review = try fixture.review([project.source])
      let result = try fixture.apply(review)
      let loaded = try JSONDecoder().decode(TransferArtifactCleanupResult.self, from: Data(contentsOf: URL(fileURLWithPath: result.resultPath)))
      let loadedReview = try JSONDecoder().decode(TransferArtifactCleanupReview.self, from: Data(contentsOf: URL(fileURLWithPath: review.evidencePath)))
      XCTAssertEqual(loaded.reviewID, review.id)
      XCTAssertEqual(loadedReview.items.first?.artifactPath, project.source.path)
      let receipt = try XCTUnwrap(loaded.receipts.first)
      _ = try TransferArtifactCleanupEngine.restore(receipt: receipt, protectedRootPaths: [], environment: fixture.environment)
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: project.source.path), before)
      XCTAssertFalse(FileManager.default.fileExists(atPath: receipt.archivePath))
    }
  }

  func testNextDiscoveryAfterCleanupReportsZeroRemainingArtifacts() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage")
      let ownerRoot = project.source.deletingLastPathComponent()
      let before = try FileManager.default.contentsOfDirectory(at: ownerRoot, includingPropertiesForKeys: nil)
        .filter { CheckoutDiscoveryRules.isTransferArtifactName($0.lastPathComponent) }
      XCTAssertEqual(before.map { $0.resolvingSymlinksInPath().path }, [project.source.resolvingSymlinksInPath().path])
      _ = try fixture.apply(fixture.review([project.source]))
      XCTAssertFalse(FileManager.default.fileExists(atPath: project.source.path))
      let nextPaths = try FileManager.default.contentsOfDirectory(at: ownerRoot, includingPropertiesForKeys: nil)
        .filter { CheckoutDiscoveryRules.isTransferArtifactName($0.lastPathComponent) }
      let nextReview = try fixture.review(nextPaths)
      XCTAssertTrue(nextReview.items.isEmpty)
      XCTAssertEqual(nextReview.readyCount, 0)
      XCTAssertEqual(nextReview.blockedCount, 0)
      XCTAssertFalse(nextReview.canApply)
    }
  }

  func testInterruptedBatchRecoveryVerifiesMovedTreesWithoutMovingRemainingSources() throws {
    try fixture { fixture in
      let first = try fixture.artifact(owner: "OwnerA", name: "First", kind: "stage")
      let interrupted = try fixture.artifact(owner: "OwnerB", name: "Second", kind: "backup")
      let untouched = try fixture.artifact(owner: "OwnerC", name: "Third", kind: "stage")
      let interruptedBefore = try CheckoutPairReviewEngine.inventory(path: interrupted.source.path)
      let untouchedBefore = try CheckoutPairReviewEngine.inventory(path: untouched.source.path)
      let review = try fixture.review([first.source, interrupted.source, untouched.source])
      var environment = fixture.environment
      environment["CSA_IEM_TEST_INTERRUPT_ARTIFACT_ARCHIVE_AFTER_RENAME"] = interrupted.source.path
      XCTAssertThrowsError(try fixture.apply(review, environment: environment))

      let batch = fixture.recovery.appendingPathComponent(review.id)
      let previous = try JSONDecoder().decode(TransferArtifactCleanupResult.self, from: Data(contentsOf: batch.appendingPathComponent("result.json")))
      XCTAssertEqual(previous.receipts.map(\.originalPath), [first.source.path])
      let ledger = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: batch.appendingPathComponent("pending-ledger.json"))) as? [String: Any])
      let locations = try XCTUnwrap(ledger["locations"] as? [[String: Any]])
      XCTAssertEqual(locations.count, 2)
      for location in locations {
        let preparedPath = try XCTUnwrap(location["preparedReceiptPath"] as? String)
        let prepared = try JSONDecoder().decode(CheckoutRetirementReceipt.self, from: Data(contentsOf: URL(fileURLWithPath: preparedPath)))
        XCTAssertEqual(prepared.inventory.fileCount, 26)
      }
      XCTAssertFalse(FileManager.default.fileExists(atPath: interrupted.source.path))

      let recovered = try fixture.recover(review)
      XCTAssertEqual(Set(recovered.receipts.map(\.originalPath)), Set([first.source.path, interrupted.source.path]))
      XCTAssertFalse(recovered.completedAll)
      XCTAssertTrue(recovered.failures.contains(where: { $0.artifactPath == untouched.source.path }))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: untouched.source.path), untouchedBefore)
      let restored = try XCTUnwrap(recovered.receipts.first(where: { $0.originalPath == interrupted.source.path }))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: restored.archivePath), interruptedBefore)
      _ = try TransferArtifactCleanupEngine.restore(receipt: restored, protectedRootPaths: [], environment: fixture.environment)
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: interrupted.source.path), interruptedBefore)
    }
  }

  func testRecoverRetainsVerifiedArchiveWhenCanonicalLaterChanges() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "stage")
      let review = try fixture.review([project.source])
      let initial = try fixture.apply(review)
      let previous = try XCTUnwrap(initial.receipts.first)
      try write("new canonical work after preservation", to: project.canonical.appendingPathComponent("src/main.swift"))

      let recovered = try fixture.recover(review)
      XCTAssertFalse(recovered.completedAll)
      XCTAssertEqual(recovered.receipts.first?.archivePath, previous.archivePath)
      XCTAssertTrue(recovered.failures.contains(where: { $0.artifactPath == project.source.path }))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: previous.archivePath).fileCount, 26)
      _ = try TransferArtifactCleanupEngine.restore(receipt: previous, protectedRootPaths: [], environment: fixture.environment)
      XCTAssertEqual(try String(contentsOf: project.canonical.appendingPathComponent("src/main.swift"), encoding: .utf8), "new canonical work after preservation")
      XCTAssertTrue(FileManager.default.fileExists(atPath: project.source.appendingPathComponent("unique.bin").path))
    }
  }

  func testRepeatedApplyCannotOverwriteSavedBatchEvidence() throws {
    try fixture { fixture in
      let project = try fixture.artifact(owner: "OwnerA", name: "Project", kind: "backup")
      let review = try fixture.review([project.source])
      let result = try fixture.apply(review)
      let resultURL = URL(fileURLWithPath: result.resultPath)
      let ledgerURL = resultURL.deletingLastPathComponent().appendingPathComponent("pending-ledger.json")
      let resultBefore = try Data(contentsOf: resultURL)
      let ledgerBefore = try Data(contentsOf: ledgerURL)
      XCTAssertThrowsError(try fixture.apply(review))
      XCTAssertEqual(try Data(contentsOf: resultURL), resultBefore)
      XCTAssertEqual(try Data(contentsOf: ledgerURL), ledgerBefore)
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: XCTUnwrap(result.receipts.first).archivePath).fileCount, 26)
    }
  }

  func testEmptyApplyAndRecoveryAreCompletedWithoutMovingAnySource() throws {
    try fixture { fixture in
      let review = try fixture.review([])
      let applied = try fixture.apply(review)
      XCTAssertTrue(applied.completedAll)
      XCTAssertEqual(applied.attemptedCount, 0)
      XCTAssertTrue(applied.receipts.isEmpty)
      XCTAssertTrue(applied.failures.isEmpty)
      let recovered = try fixture.recover(review)
      XCTAssertTrue(recovered.completedAll)
      XCTAssertEqual(recovered.attemptedCount, 0)
    }
  }

  func testRegisteredGitWorktreesAndCanonicalSymlinkDependenciesRemainBlocked() throws {
    try fixture { fixture in
      let registered = try fixture.artifact(owner: "OwnerA", name: "Registered", kind: "stage")
      let own = try fixture.artifact(owner: "OwnerB", name: "OwnDependency", kind: "stage")
      let referrer = try fixture.artifact(owner: "OwnerC", name: "Referrer", kind: "stage")
      let target = try fixture.artifact(owner: "OwnerD", name: "Target", kind: "backup")
      try write("external worktree registration", to: registered.source.appendingPathComponent(".git/worktrees/linked/gitdir"))
      try FileManager.default.createSymbolicLink(at: own.canonical.appendingPathComponent("source-link"), withDestinationURL: own.source.appendingPathComponent("unique.bin"))
      try FileManager.default.createSymbolicLink(at: referrer.canonical.appendingPathComponent("cross-source-link"), withDestinationURL: target.source.appendingPathComponent("unique.bin"))
      let review = try fixture.review([registered.source, own.source, referrer.source, target.source])
      for source in [registered.source, own.source, target.source] {
        let item = try XCTUnwrap(review.items.first(where: { $0.artifactPath == source.path }))
        XCTAssertFalse(item.canClean)
        XCTAssertFalse(item.blockers.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
      }
      XCTAssertTrue(review.items.first(where: { $0.artifactPath == referrer.source.path })?.canClean == true)
    }
  }

  private struct Project {
    let canonical: URL
    let source: URL
  }

  private struct Fixture {
    let root: URL
    let repositoryRoots: [String]
    let evidence: URL
    let recovery: URL
    let environment: [String: String]

    func artifact(owner: String, name: String, kind: String, role: String = "Code", transaction: String = UUID().uuidString, createCanonical: Bool = true) throws -> Project {
      let ownerRoot = root.appendingPathComponent(role + "/Repos/" + owner)
      let canonical = ownerRoot.appendingPathComponent(name)
      let source = ownerRoot.appendingPathComponent(name + ".csa-iem-" + kind + "-" + transaction)
      if createCanonical {
        try TransferArtifactCleanupTests.write("identical product note\n", to: canonical.appendingPathComponent("README.md"))
        try TransferArtifactCleanupTests.write("current canonical version\n", to: canonical.appendingPathComponent("src/main.swift"))
        try TransferArtifactCleanupTests.write("canonical git state\n", to: canonical.appendingPathComponent(".git/config"))
      }
      try TransferArtifactCleanupTests.write("identical product note\n", to: source.appendingPathComponent("README.md"))
      try TransferArtifactCleanupTests.write("older artifact version\n", to: source.appendingPathComponent("src/main.swift"))
      try TransferArtifactCleanupTests.write("preserved artifact git state\n", to: source.appendingPathComponent(".git/config"))
      try TransferArtifactCleanupTests.write("hidden checkpoint to retain\n", to: source.appendingPathComponent(".hidden/checkpoint"))
      try TransferArtifactCleanupTests.write("numbered dependency fixture\n", to: source.appendingPathComponent("node_modules/pkg/LICENSE 2"))
      try Data([0, 1, 2, 255]).write(to: source.appendingPathComponent("unique.bin"))
      for index in 0..<20 {
        try TransferArtifactCleanupTests.write("git metadata fixture \(index)\n", to: source.appendingPathComponent(".git/objects/fixture-\(index)"))
      }
      return Project(canonical: canonical, source: source)
    }

    func review(_ paths: [URL], protected: [String] = []) throws -> TransferArtifactCleanupReview {
      try TransferArtifactCleanupEngine.review(paths: paths.map(\.path), allowedRepositoryRoots: repositoryRoots,
        protectedRootPaths: protected, evidenceRoot: evidence.path)
    }

    func apply(_ review: TransferArtifactCleanupReview, protected: [String] = [], environment: [String: String]? = nil) throws -> TransferArtifactCleanupResult {
      try TransferArtifactCleanupEngine.apply(review: review, recoveryRoot: recovery.path,
        allowedRepositoryRoots: repositoryRoots, protectedRootPaths: protected, environment: environment ?? self.environment)
    }

    func recover(_ review: TransferArtifactCleanupReview) throws -> TransferArtifactCleanupResult {
      try TransferArtifactCleanupEngine.recoverPending(review: review, recoveryRoot: recovery.path,
        allowedRepositoryRoots: repositoryRoots, protectedRootPaths: [], environment: environment)
    }
  }

  private func fixture(_ body: (Fixture) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("csa-transfer-artifact-tests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let repositoryRoots = [root.appendingPathComponent("Code/Repos"), root.appendingPathComponent("Runtime/Repos")]
    for path in repositoryRoots { try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true) }
    var environment = ProcessInfo.processInfo.environment
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    try body(Fixture(root: root, repositoryRoots: repositoryRoots.map(\.path), evidence: root.appendingPathComponent("evidence"),
                     recovery: root.appendingPathComponent("recovery"), environment: environment))
  }

  private static func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }

  private func write(_ text: String, to url: URL) throws {
    try Self.write(text, to: url)
  }
}
