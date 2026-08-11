import XCTest
@testable import CSAiEMMacApp

final class SmartLogicTests: XCTestCase {
  private let observedDate = Date(timeIntervalSince1970: 1_754_931_600)

  func testVerifiedRemoteVariantsGroupAsMergeCandidates() {
    let first = project(
      path: "/tmp/flowers-main",
      name: "Flowers",
      remoteURL: "git@github.com:WayneTechLab/Flowers.git",
      branch: "main",
      ideState: .linked,
      hasLocalChanges: false,
      mainState: .synchronized
    )
    let second = project(
      path: "/tmp/flowers-copy",
      name: "Flowers-copy",
      remoteURL: "https://github.com/WayneTechLab/Flowers/",
      branch: "feature/test",
      ideState: .unlinked,
      hasLocalChanges: true,
      mainState: .ahead(2)
    )

    let decisions = CodexSmartLogicEngine.evaluate([first, second], destinationRoot: "/tmp/destination")

    XCTAssertEqual(decisions.count, 2)
    XCTAssertEqual(decisions[0].classification, .mergeCandidate)
    XCTAssertEqual(decisions[1].classification, .mergeCandidate)
    XCTAssertEqual(decisions[0].groupKey, decisions[1].groupKey)
    XCTAssertTrue(decisions[1].reasons.contains { $0.contains("uncommitted") })
    XCTAssertTrue(decisions[1].reasons.contains { $0.contains("feature/test") })
    XCTAssertEqual(decisions[1].recommendedDestination, "/tmp/destination/Flowers-copy")
  }

  func testMissingGitIsBrokenMetadataReviewAndNeverCanonical() {
    let decision = CodexSmartLogicEngine.evaluate([
      project(
        path: "/tmp/no-git",
        name: "Flowers",
        remoteURL: nil,
        branch: nil,
        ideState: .linked,
        hasLocalChanges: false,
        mainState: .noGit,
        hasGit: false
      )
    ]).first

    XCTAssertEqual(decision?.classification, .brokenMetadataReview)
    XCTAssertEqual(decision?.confidence, 0.15)
    XCTAssertTrue(decision?.classification.isReview == true)
    XCTAssertTrue(decision?.reasons.contains("No Git worktree was detected.") == true)
  }

  func testUnlinkedSynchronizedProjectIsShadowCopyReview() {
    let decision = CodexSmartLogicEngine.evaluate([
      project(
        path: "/tmp/shadow",
        name: "Space",
        remoteURL: "https://github.com/WayneTechLab/Space.git",
        branch: "main",
        ideState: .unlinked,
        hasLocalChanges: false,
        mainState: .synchronized
      )
    ]).first

    XCTAssertEqual(decision?.classification, .shadowCopy)
    XCTAssertEqual(decision?.confidence, 0.45)
    XCTAssertTrue(decision?.reasons.contains("The folder is not linked to the active local project registry.") == true)
  }

  func testDeterministicAdvisorySuggestsOnlyReviewDecisions() async throws {
    let projects = [
      project(path: "/tmp/canonical", name: "Birds", remoteURL: "https://github.com/WayneTechLab/Birds", branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized),
      project(path: "/tmp/review", name: "Birds-copy", remoteURL: nil, branch: nil, ideState: .unavailable, hasLocalChanges: false, mainState: .noOriginMain)
    ]
    let decisions = CodexSmartLogicEngine.evaluate(projects)
    let advisory = try await DeterministicOnlyCodexAdvisoryProvider().advise(
      CodexAdvisoryInput(ruleVersion: CodexSmartLogicEngine.ruleVersion, decisions: decisions, redactionPolicy: "paths-only")
    )

    XCTAssertFalse(advisory.isAuthoritative)
    XCTAssertEqual(advisory.model, "deterministic-fallback")
    XCTAssertEqual(advisory.suggestedReviewIDs, [decisions[1].id])
  }

  func testCatalogStorePersistsReceiptBoundSessionAndCheckpoint() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }

    let source = project(path: "/tmp/catalog-source", name: "Catalog", remoteURL: nil, branch: nil, ideState: .unavailable, hasLocalChanges: false, mainState: .noOriginMain)
    let decision = CodexSmartLogicEngine.evaluate([source]).first!
    let session = CodexScanSession(id: "session-test", profile: "full-verification", sourceRoots: ["/tmp"], createdAt: observedDate, ruleVersion: CodexSmartLogicEngine.ruleVersion, decisionCount: 1)
    let checkpoint = CodexSessionCheckpoint(sessionID: session.id, sourcePath: source.path, stage: "index", state: "completed", updatedAt: observedDate, detail: "fixture")

    let databasePath = try CodexCatalogStore(rootPath: root.path).save(session: session, decisions: [decision], checkpoints: [checkpoint])
    XCTAssertTrue(FileManager.default.fileExists(atPath: databasePath))
    XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".SYSTEMX/Index/Exports/session-test-decisions.json").path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".SYSTEMX/Index/Exports/session-test-decisions.csv").path))
  }

  private func project(
    path: String,
    name: String,
    remoteURL: String?,
    branch: String?,
    ideState: CodexIDEProjectState,
    hasLocalChanges: Bool,
    mainState: CodexGitMainState,
    hasGit: Bool = true
  ) -> CodexProjectEntry {
    CodexProjectEntry(
      path: path,
      name: name,
      discoveredBy: "test-fixture",
      hasGit: hasGit,
      hasPackageManifest: true,
      hasDevcontainer: false,
      hasSystemX: true,
      localDevProfile: nil,
      remoteURL: remoteURL,
      branch: branch,
      ideState: ideState,
      gitStatus: CodexGitWorkspaceStatus(branch: branch, upstream: "origin/main", mainState: mainState, hasLocalChanges: hasLocalChanges)
    )
  }
}
