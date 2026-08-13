import XCTest
@testable import CSAiEMMacApp

final class SmartLogicTests: XCTestCase {
  private let observedDate = Date(timeIntervalSince1970: 1_754_931_600)

  func testIncidentClassifierSeparatesRecoverableWarningsFromFatalBlockers() {
    XCTAssertEqual(CSAiEMIncidentClassifier.severity(for: "One source scan timed out; unrelated sources may continue."), .recoverable)
    XCTAssertEqual(CSAiEMIncidentClassifier.severity(for: "Fatal identity conflict: destination conflict requires operator review."), .fatal)
  }

  func testIncidentIssueDraftRedactsCredentialsAndHomePaths() {
    let incident = CSAiEMIncident(
      id: "incident-1",
      createdAt: observedDate,
      kind: "Import",
      title: "Import failed",
      target: "/Users/alice/CSA-iEM/Code/Flowers",
      detail: "authorization: ghp_super-secret-value; inspect /Users/alice/CSA-iEM/Code/Flowers",
      jobID: "job-1",
      severity: .fatal,
      state: .open,
      resolution: nil
    )

    let draft = CSAiEMIncidentClassifier.redactedIssueDraft(for: incident)
    XCTAssertTrue(draft.contains("[REDACTED]"))
    XCTAssertFalse(draft.contains("ghp_super-secret-value"))
    XCTAssertFalse(draft.contains("/Users/alice"))
    XCTAssertTrue(draft.contains("job-1"))
  }

  func testIncidentStoreRoundTripsLocalRecords() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-incidents-\(UUID().uuidString).json").path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let incident = CSAiEMIncident(id: "incident-2", createdAt: observedDate, kind: "Recovery", title: "Recovery warning", target: "Flowers", detail: "retryable", jobID: "job-2", severity: .recoverable, state: .open, resolution: nil)

    CSAiEMIncidentStore.save([incident], to: path)
    XCTAssertEqual(CSAiEMIncidentStore.load(from: path), [incident])
  }

  func testIncidentEvidenceCorrelatesStageAndCheckpointHints() {
    let job = BackgroundJobEntry(
      id: "job-correlated",
      kind: "Recovery",
      title: "Stage 2 reconciliation",
      target: "Flowers",
      detail: "source: /Users/alice/Import/Flowers, destination: /Users/alice/Code/Flowers, receipt: receipt-42, checkpoint: session-7/index",
      progressText: "blocked",
      state: .failed,
      createdAt: observedDate,
      startedAt: observedDate,
      finishedAt: observedDate,
      log: ""
    )

    let evidence = CSAiEMIncidentClassifier.evidence(for: job, severity: .recoverable)
    XCTAssertEqual(evidence.stage, "stage-2-reconciliation")
    XCTAssertEqual(evidence.source, "/Users/alice/Import/Flowers")
    XCTAssertEqual(evidence.destination, "/Users/alice/Code/Flowers")
    XCTAssertEqual(evidence.receipt, "receipt-42")
    XCTAssertEqual(evidence.checkpoint, "session-7/index")
    XCTAssertTrue(evidence.nextAction.contains("checkpoint"))
  }

  func testGitHubIssueEntryDecodesReadOnlyListShape() throws {
    let issue = try JSONDecoder().decode(GitHubIssueEntry.self, from: Data("""
    {"number":42,"title":"Broken import","state":"OPEN","createdAt":"2026-08-13T00:00:00Z","updatedAt":"2026-08-13T01:00:00Z","url":"https://github.com/example/repo/issues/42"}
    """.utf8))
    XCTAssertEqual(issue.number, 42)
    XCTAssertEqual(issue.title, "Broken import")
    XCTAssertEqual(issue.state, "OPEN")
    XCTAssertEqual(issue.url, "https://github.com/example/repo/issues/42")
    XCTAssertTrue(issue.labels.isEmpty)
  }

  func testGitHubIssueCommandBuildsReviewedCommentAndLabelArguments() throws {
    let comment = try CSAiEMGitHubIssueCommand.make(mutation: .comment, issueNumber: 42, body: "  checkpoint verified  ", labels: "")
    XCTAssertEqual(comment.arguments, ["issue", "comment", "42", "--body", "checkpoint verified"])

    let labels = try CSAiEMGitHubIssueCommand.make(mutation: .addLabel, issueNumber: 42, body: "", labels: "needs-review, recovery")
    XCTAssertEqual(labels.labels, ["needs-review", "recovery"])
    XCTAssertEqual(labels.arguments, ["issue", "edit", "42", "--add-label", "needs-review", "--add-label", "recovery"])
  }

  func testGitHubIssueCommandRejectsUnarmedPayloadInputs() {
    XCTAssertThrowsError(try CSAiEMGitHubIssueCommand.make(mutation: .comment, issueNumber: nil, body: "comment", labels: "")) { error in
      XCTAssertEqual(error as? CSAiEMGitHubIssueCommand.ValidationError, .invalidIssueNumber)
    }
    XCTAssertThrowsError(try CSAiEMGitHubIssueCommand.make(mutation: .comment, issueNumber: 42, body: " ", labels: "")) { error in
      XCTAssertEqual(error as? CSAiEMGitHubIssueCommand.ValidationError, .missingBody)
    }
    XCTAssertThrowsError(try CSAiEMGitHubIssueCommand.make(mutation: .addLabel, issueNumber: 42, body: "", labels: ",")) { error in
      XCTAssertEqual(error as? CSAiEMGitHubIssueCommand.ValidationError, .missingLabels)
    }
  }

  func testGitHubIssueVerifierConfirmsStateLabelsAndCommentPresence() throws {
    let close = try CSAiEMGitHubIssueCommand.make(mutation: .close, issueNumber: 42, body: "", labels: "")
    let closedPayload = try JSONDecoder().decode(CSAiEMGitHubIssueVerificationPayload.self, from: Data("""
    {"state":"CLOSED","labels":[{"name":"incident"}],"comments":[]}
    """.utf8))
    XCTAssertEqual(try CSAiEMGitHubIssueVerifier.verify(closedPayload, command: close).get(), "Closed state verified.")

    let addLabel = try CSAiEMGitHubIssueCommand.make(mutation: .addLabel, issueNumber: 42, body: "", labels: "Recovery")
    let labeledPayload = try JSONDecoder().decode(CSAiEMGitHubIssueVerificationPayload.self, from: Data("""
    {"state":"OPEN","labels":[{"name":"recovery"}],"comments":[]}
    """.utf8))
    XCTAssertEqual(try CSAiEMGitHubIssueVerifier.verify(labeledPayload, command: addLabel).get(), "Added label(s) verified.")

    let comment = try CSAiEMGitHubIssueCommand.make(mutation: .comment, issueNumber: 42, body: "checkpoint verified", labels: "")
    let commentedPayload = try JSONDecoder().decode(CSAiEMGitHubIssueVerificationPayload.self, from: Data("""
    {"state":"OPEN","labels":[],"comments":[{"body":"checkpoint verified"}]}
    """.utf8))
    XCTAssertEqual(try CSAiEMGitHubIssueVerifier.verify(commentedPayload, command: comment).get(), "Comment presence verified.")
    XCTAssertEqual(CSAiEMGitHubIssueVerifier.arguments(for: 42), ["issue", "view", "42", "--json", "state,labels,comments"])
  }

  func testGitHubIssueVerifierFailsWhenProviderStateDoesNotMatch() throws {
    let reopen = try CSAiEMGitHubIssueCommand.make(mutation: .reopen, issueNumber: 42, body: "", labels: "")
    let payload = try JSONDecoder().decode(CSAiEMGitHubIssueVerificationPayload.self, from: Data("""
    {"state":"CLOSED","labels":[],"comments":[]}
    """.utf8))
    guard case .failure(.mismatch(let detail)) = CSAiEMGitHubIssueVerifier.verify(payload, command: reopen) else {
      return XCTFail("Expected a provider-state mismatch.")
    }
    XCTAssertEqual(detail, "Provider read-back state is CLOSED, expected OPEN.")
  }

  func testIncidentClustersGroupSameSourceStageAndDestination() {
    let first = CSAiEMIncident(id: "cluster-1", createdAt: observedDate, kind: "Recovery", title: "Checkpoint warning", target: "Flowers", detail: "retry", jobID: "job-1", severity: .recoverable, evidence: CSAiEMIncidentEvidence(stage: "stage-2-reconciliation", source: "/tmp/flowers", destination: "/tmp/managed/flowers", receipt: "receipt-1", checkpoint: "session-1/index", nextAction: "Resume"), state: .open, resolution: nil)
    let second = CSAiEMIncident(id: "cluster-2", createdAt: observedDate.addingTimeInterval(10), kind: "Recovery", title: "Retry warning", target: "Flowers", detail: "retry", jobID: "job-2", severity: .fatal, evidence: CSAiEMIncidentEvidence(stage: "stage-2-reconciliation", source: "/tmp/flowers", destination: "/tmp/managed/flowers", receipt: "receipt-2", checkpoint: "session-1/reconcile", nextAction: "Review"), state: .open, resolution: nil)

    let clusters = CSAiEMIncidentCluster.group([first, second])
    XCTAssertEqual(clusters.count, 1)
    XCTAssertEqual(clusters[0].incidentIDs, ["cluster-1", "cluster-2"])
    XCTAssertEqual(clusters[0].openCount, 2)
    XCTAssertEqual(clusters[0].fatalCount, 1)
  }

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
    XCTAssertEqual(decisions[0].leadRank, 1)
    XCTAssertTrue(decisions[0].isRecommendedLead)
    XCTAssertEqual(decisions[1].leadRank, 2)
    XCTAssertFalse(decisions[1].isRecommendedLead)
    XCTAssertTrue(decisions[0].reasons.contains { $0.contains("lead recommendation") })
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

  func testGroupedUnlinkedSynchronizedCopyIsShadowReviewAndBlocksLeadGroup() {
    let lead = project(
      path: "/tmp/birds-lead",
      name: "Birds",
      remoteURL: "https://github.com/WayneTechLab/Birds.git",
      branch: "main",
      ideState: .linked,
      hasLocalChanges: false,
      mainState: .synchronized
    )
    let shadow = project(
      path: "/tmp/birds-shadow",
      name: "Birds-shadow",
      remoteURL: "https://github.com/WayneTechLab/Birds.git",
      branch: "main",
      ideState: .unlinked,
      hasLocalChanges: false,
      mainState: .synchronized
    )

    let decisions = CodexSmartLogicEngine.evaluate([lead, shadow])

    XCTAssertEqual(decisions[0].classification, .mergeCandidate)
    XCTAssertEqual(decisions[1].classification, .shadowCopy)
    XCTAssertTrue(decisions[1].classification.isReview)
    XCTAssertTrue(decisions[1].reasons.contains { $0.contains("shadow-copy") })
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

  func testLocalAdvisoryParserAcceptsFencedJSONAndPreservesOnlyContractFields() {
    let parsed = LocalCodexAdvisoryProvider.parseAdvisoryJSON("""
    ```json
    {"summary":"Review the dirty shadow copy first.","suggested_review_ids":["review-1"],"canonical_source":"/unsafe/path","delete":true}
    ```
    """)

    XCTAssertEqual(parsed.summary, "Review the dirty shadow copy first.")
    XCTAssertEqual(parsed.ids, ["review-1"])
  }

  func testLocalAdvisoryParserFailsClosedForInvalidModelOutput() {
    let parsed = LocalCodexAdvisoryProvider.parseAdvisoryJSON("not-json")

    XCTAssertEqual(parsed.summary, "not-json")
    XCTAssertTrue(parsed.ids.isEmpty)
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

  func testCatalogStorePersistsChangedOnlyIndexRecordAfterRestart() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-index-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let sourceIndex = root.appendingPathComponent("source-index.json")
    let destinationIndex = root.appendingPathComponent("destination-index.json")
    try Data("source-v1".utf8).write(to: sourceIndex)
    try Data("destination-v1".utf8).write(to: destinationIndex)
    let record = CodexScanIndexRecord(
      sourcePath: "/tmp/catalog-source",
      destinationPath: "/tmp/catalog-destination",
      sourceIndexPath: sourceIndex.path,
      destinationIndexPath: destinationIndex.path,
      optionsKey: "git=1;finder=0;deps=0;checksum=0",
      sourceIndexDigest: CodexCatalogStore.artifactDigest(at: sourceIndex.path)!,
      destinationIndexDigest: CodexCatalogStore.artifactDigest(at: destinationIndex.path)!,
      sourceFileCount: 12,
      sourceByteCount: 4096,
      capturedAt: observedDate
    )
    let store = CodexCatalogStore(rootPath: root.path)
    try store.saveIndexRecords([record])
    XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".SYSTEMX/Index/catalog.sqlite").path))
    let reopened = CodexCatalogStore(rootPath: root.path)
    XCTAssertNil(reopened.latestCheckpointSummary())
    XCTAssertTrue(reopened.indexRecordMatches(
      sourcePath: record.sourcePath,
      destinationPath: record.destinationPath,
      optionsKey: record.optionsKey,
      sourceIndexPath: record.sourceIndexPath,
      destinationIndexPath: record.destinationIndexPath
    ))
    XCTAssertFalse(reopened.indexRecordMatches(
      sourcePath: record.sourcePath,
      destinationPath: record.destinationPath,
      optionsKey: "git=0;finder=0;deps=0;checksum=0",
      sourceIndexPath: record.sourceIndexPath,
      destinationIndexPath: record.destinationIndexPath
    ))
    let query = Process()
    query.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    query.arguments = [store.databasePath, "SELECT source_path || '|' || options_key || '|' || source_index_digest FROM scan_index_records;"]
    let output = Pipe()
    query.standardOutput = output
    try query.run()
    query.waitUntilExit()
    let row = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    XCTAssertTrue(row.contains("/tmp/catalog-source|git=1;finder=0;deps=0;checksum=0|"))
    XCTAssertTrue(row.contains(record.sourceIndexDigest))
  }

  func testCatalogStoreReportsLatestCheckpointAfterReopen() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-checkpoint-status-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let source = project(path: "/tmp/checkpoint-source", name: "Checkpoint", remoteURL: nil, branch: nil, ideState: .unavailable, hasLocalChanges: false, mainState: .noOriginMain)
    let decision = CodexSmartLogicEngine.evaluate([source]).first!
    let session = CodexScanSession(id: "checkpoint-session", profile: "fast-index", sourceRoots: ["/tmp"], createdAt: observedDate, ruleVersion: CodexSmartLogicEngine.ruleVersion, decisionCount: 1)
    let checkpoint = CodexSessionCheckpoint(
      sessionID: session.id,
      sourcePath: source.path,
      stage: "stage1-preflight",
      state: "indexed",
      updatedAt: observedDate,
      detail: "unchanged index retained"
    )

    let store = CodexCatalogStore(rootPath: root.path)
    try store.save(session: session, decisions: [decision], checkpoints: [checkpoint])
    let reopened = CodexCatalogStore(rootPath: root.path)

    XCTAssertEqual(
      reopened.latestCheckpointSummary(),
      "stage1-preflight=indexed at 2025-08-11T17:00:00Z"
    )
  }

  func testInterruptedLaterStageRemainsVisibleAfterCatalogRestart() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-interrupted-session-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let source = project(path: "/tmp/interrupted-source", name: "Interrupted", remoteURL: nil, branch: nil, ideState: .unavailable, hasLocalChanges: false, mainState: .noOriginMain)
    let decision = CodexSmartLogicEngine.evaluate([source]).first!
    let session = CodexScanSession(id: "interrupted-session", profile: "full-verification", sourceRoots: ["/tmp"], createdAt: observedDate, ruleVersion: CodexSmartLogicEngine.ruleVersion, decisionCount: 1)
    let indexed = CodexSessionCheckpoint(
      sessionID: session.id,
      sourcePath: source.path,
      stage: "stage1-preflight",
      state: "completed",
      updatedAt: observedDate,
      detail: "index retained"
    )
    let interrupted = CodexSessionCheckpoint(
      sessionID: session.id,
      sourcePath: source.path,
      stage: "stage2-reconcile",
      state: "interrupted",
      updatedAt: observedDate.addingTimeInterval(60),
      detail: "process stopped after destination preservation"
    )

    let store = CodexCatalogStore(rootPath: root.path)
    try store.save(session: session, decisions: [decision], checkpoints: [indexed])
    try store.saveCheckpoints([interrupted])
    let reopened = CodexCatalogStore(rootPath: root.path)

    XCTAssertEqual(
      reopened.latestCheckpointSummary(),
      "stage2-reconcile=interrupted at 2025-08-11T17:01:00Z"
    )
  }

  func testCodexIndexIsDeterministicAndSkipsGeneratedTrees() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-index-corpus-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: root.appendingPathComponent("node_modules/generated"), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: root.appendingPathComponent(".build/generated"), withIntermediateDirectories: true)

    for index in 0..<250 {
      let file = root.appendingPathComponent("Sources/file-\(String(format: "%03d", index)).txt")
      try Data("fixture-\(index)".utf8).write(to: file)
    }
    try Data("must-be-excluded".utf8).write(to: root.appendingPathComponent("node_modules/generated/package.js"))
    try Data("must-be-excluded".utf8).write(to: root.appendingPathComponent(".build/generated/object.o"))

    let first = try CleanupViewModel.buildCodexFileIndex(
      root: root.path,
      includeGit: false,
      includeFinderMetadata: false,
      includeDependencies: false
    )
    let second = try CleanupViewModel.buildCodexFileIndex(
      root: root.path,
      includeGit: false,
      includeFinderMetadata: false,
      includeDependencies: false
    )

    let firstFiles = first.entries.filter { $0.kind == .file }
    let secondFiles = second.entries.filter { $0.kind == .file }
    XCTAssertEqual(firstFiles.count, 250)
    XCTAssertEqual(first.byteCount, second.byteCount)
    XCTAssertEqual(firstFiles.map(\.relativePath), secondFiles.map(\.relativePath))
    XCTAssertFalse(first.entries.contains { $0.relativePath.hasPrefix("node_modules/") })
    XCTAssertFalse(first.entries.contains { $0.relativePath.hasPrefix(".build/") })
  }

  func testCodexIndexCoversSixtyProjectCorpusAndSkipsGeneratedTrees() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-sixty-project-corpus-(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let fileManager = FileManager.default

    for projectIndex in 0..<60 {
      let projectLabel = String(format: "project-%02d", projectIndex)
      let projectRoot = root.appendingPathComponent(projectLabel)
      let sourceRoot = projectRoot.appendingPathComponent("Sources")
      try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
      for fileIndex in 0..<12 {
        let fileName = String(format: "file-%02d.txt", fileIndex)
        let file = sourceRoot.appendingPathComponent(fileName)
        let contents = "project-" + String(projectIndex) + "-file-" + String(fileIndex)
        try Data(contents.utf8).write(to: file)
      }
      try fileManager.createDirectory(at: projectRoot.appendingPathComponent("node_modules/generated"), withIntermediateDirectories: true)
      try Data("generated".utf8).write(to: projectRoot.appendingPathComponent("node_modules/generated/index.js"))
    }

    let snapshot = try CleanupViewModel.buildCodexFileIndex(
      root: root.path,
      includeGit: false,
      includeFinderMetadata: false,
      includeDependencies: false
    )
    let files = snapshot.entries.filter { $0.kind == .file }

    XCTAssertEqual(files.count, 60 * 12)
    let expectedProjects = Set((0..<60).map { String(format: "project-%02d", $0) })
    XCTAssertEqual(Set(files.compactMap { $0.relativePath.split(separator: "/").first.map(String.init) }), expectedProjects)
    XCTAssertFalse(files.contains { $0.relativePath.contains("node_modules/") })
    XCTAssertGreaterThan(snapshot.byteCount, 0)
  }

  func testPostPromotionRollbackRestoresParkedSourceAndRemovesNewDestination() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-rollback-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appendingPathComponent("source")
    let parked = root.appendingPathComponent("source.csa-iem-source-test")
    let destination = root.appendingPathComponent("destination")
    try FileManager.default.createDirectory(at: parked, withIntermediateDirectories: true)
    try Data("source bytes".utf8).write(to: parked.appendingPathComponent("README.md"))
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try Data("promoted bytes".utf8).write(to: destination.appendingPathComponent("README.md"))
    try FileManager.default.createSymbolicLink(atPath: original.path, withDestinationPath: destination.path)

    try CleanupViewModel.rollbackCodexPromotion(
      destination: destination.path,
      originalSource: original.path,
      parkedSource: parked.path
    )

    XCTAssertTrue(FileManager.default.fileExists(atPath: original.appendingPathComponent("README.md").path))
    XCTAssertEqual(try String(contentsOf: original.appendingPathComponent("README.md")), "source bytes")
    XCTAssertFalse(FileManager.default.fileExists(atPath: parked.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
  }

  func testLocalExportTransactionRollsBackAllPromotionsOnLaterFailure() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-export-rollback-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceA = root.appendingPathComponent("source-a")
    let sourceB = root.appendingPathComponent("source-b")
    let destinationA = root.appendingPathComponent("out/a")
    let destinationB = root.appendingPathComponent("out/b")
    try FileManager.default.createDirectory(at: sourceA, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sourceB, withIntermediateDirectories: true)
    try Data("A".utf8).write(to: sourceA.appendingPathComponent("data.txt"))
    try Data("B".utf8).write(to: sourceB.appendingPathComponent("data.txt"))
    let operations = [
      LocalTransferOperation(source: sourceA.path, destination: destinationA.path),
      LocalTransferOperation(source: sourceB.path, destination: destinationB.path)
    ]

    XCTAssertThrowsError(try CleanupViewModel.performTransactionalTransfers(
      operations: operations,
      mode: .copyBackup,
      overwrite: false,
      environment: ["CSA_IEM_TEST_FAIL_AFTER_TRANSACTION_PROMOTION": "1"]
    ))
    XCTAssertFalse(FileManager.default.fileExists(atPath: destinationA.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: destinationB.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: sourceA.appendingPathComponent("data.txt").path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: sourceB.appendingPathComponent("data.txt").path))
  }

  func testSnapshotRestoreRollsBackWorkspaceRootsOnLaterFailure() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-restore-rollback-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let payload = root.appendingPathComponent("payload")
    let codeRoot = root.appendingPathComponent("workspace/Code")
    let importRoot = root.appendingPathComponent("workspace/Import")
    let runtimeRoot = root.appendingPathComponent("workspace/Runtime")
    let existingCode = codeRoot.appendingPathComponent("Repos/owner/project/README.md")
    let incomingCode = payload.appendingPathComponent("Code/Repos/owner/project/README.md")
    let incomingImport = payload.appendingPathComponent("Import/Repos/owner/imported/data.txt")
    try FileManager.default.createDirectory(at: existingCode.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: incomingCode.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: incomingImport.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("before".utf8).write(to: existingCode)
    try Data("incoming".utf8).write(to: incomingCode)
    try Data("new import".utf8).write(to: incomingImport)

    XCTAssertThrowsError(try CleanupViewModel.restoreSnapshotPayload(
      payloadPath: payload.path,
      roots: (codeRoot.path, importRoot.path, runtimeRoot.path),
      environment: ["CSA_IEM_TEST_FAIL_DURING_SNAPSHOT_RESTORE": "1"]
    ))
    XCTAssertEqual(try String(contentsOf: existingCode), "before")
    XCTAssertFalse(FileManager.default.fileExists(atPath: importRoot.path))
  }

  func testWorkspaceRelocationRollsBackCrossRootPromotionOnLaterFailure() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-relocation-rollback-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let code = root.appendingPathComponent("source/Code")
    let imported = root.appendingPathComponent("source/Import")
    let runtime = root.appendingPathComponent("source/Runtime")
    let destination = root.appendingPathComponent("destination")
    let sourceFiles = [
      code.appendingPathComponent("marker.txt"),
      imported.appendingPathComponent("marker.txt"),
      runtime.appendingPathComponent("marker.txt")
    ]
    for file in sourceFiles {
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data("new-\(file.lastPathComponent)-\(file.deletingLastPathComponent().lastPathComponent)".utf8).write(to: file)
    }
    let existingDestinationFiles = [
      destination.appendingPathComponent("Code/marker.txt"),
      destination.appendingPathComponent("Import/marker.txt"),
      destination.appendingPathComponent("Runtime/marker.txt")
    ]
    for file in existingDestinationFiles {
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data("old".utf8).write(to: file)
    }

    XCTAssertThrowsError(try CleanupViewModel.relocateWorkspaceRoots(
      scope: .workspace,
      style: .split,
      codeRoot: code.path,
      importRoot: imported.path,
      runtimeRoot: runtime.path,
      destinationBase: destination.path,
      overwrite: true,
      environment: ["CSA_IEM_TEST_FAIL_AFTER_WORKSPACE_PROMOTION": "1"]
    ))
    for file in sourceFiles {
      XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
    for file in existingDestinationFiles {
      XCTAssertEqual(try String(contentsOf: file), "old")
    }
  }

  func testModuleMatrixHasUniqueStableTagsAndRequiredLocalSurfaces() {
    let catalog = CSAiEMModuleTag.catalog
    XCTAssertEqual(CSAiEMModuleTag.matrixVersion, "matrix-1.0")
    XCTAssertEqual(catalog.count, 17)
    XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
    XCTAssertEqual(Set(catalog.map(\.tag)).count, catalog.count)
    XCTAssertTrue(catalog.contains { $0.tag == "engine.smart-logic" })
    XCTAssertTrue(catalog.contains { $0.tag == "engine.recovery" })
    XCTAssertTrue(catalog.contains { $0.tag == "runtime.install" })
    XCTAssertTrue(catalog.contains { $0.tag == "runtime.toolbar" })
    XCTAssertTrue(catalog.contains { $0.tag == "feature.incidents" && $0.version == "incident-v1.2" })
    XCTAssertTrue(catalog.contains { $0.tag == "bridge.github" && $0.version == "issues-v1.3" })
  }

  func testDecisionReviewSemanticsKeepFatalConditionsVisible() {
    XCTAssertFalse(CodexDecisionClass.canonical.isReview)
    XCTAssertFalse(CodexDecisionClass.mergeCandidate.isReview)
    XCTAssertTrue(CodexDecisionClass.sameNameReview.isReview)
    XCTAssertTrue(CodexDecisionClass.brokenMetadataReview.isReview)
    XCTAssertTrue(CodexDecisionClass.shadowCopy.isReview)
    XCTAssertTrue(CodexDecisionClass.unknownOwnerReview.isReview)
    XCTAssertTrue(CodexDecisionClass.fatalIdentityConflict.isReview)
    XCTAssertFalse(CodexDecisionClass.unrelated.isReview)
  }

  func testToolEvidenceIsPersistedAsReadOnlyDecisionContext() {
    let source = project(
      path: "/tmp/tool-evidence-project",
      name: "Tool Evidence",
      remoteURL: "https://github.com/WayneTechLab/tool-evidence.git",
      branch: "main",
      ideState: .linked,
      hasLocalChanges: false,
      mainState: .synchronized,
      toolEvidence: [.visualStudioCode, .claude, .lmStudio]
    )

    let decision = CodexSmartLogicEngine.evaluate([source]).first!
    XCTAssertEqual(decision.evidence.toolEvidence, [.visualStudioCode, .claude, .lmStudio])
    XCTAssertTrue(decision.reasons.contains { $0.contains("Read-only tool evidence") })
    XCTAssertTrue(decision.reasons.contains { $0.contains("do not establish repository identity or write authority") })
  }

  func testToolEvidenceDetectorReadsOnlyBoundedProjectMarkers() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-tool-evidence-(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appendingPathComponent(".vscode"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent(".claude"), withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: root.appendingPathComponent("lmstudio.json"))

    XCTAssertEqual(
      CodexToolEvidenceDetector.detect(projectPath: root.path, codexState: .linked),
      [.codex, .visualStudioCode, .claude, .lmStudio]
    )
    XCTAssertEqual(
      CodexToolEvidenceDetector.detect(projectPath: root.path, codexState: .unavailable),
      [.visualStudioCode, .claude, .lmStudio]
    )
  }

  func testBackupMediumPolicyNamesRawPreservationAndOptionalInterchange() {
    XCTAssertEqual(CodexBackupMedium.rawDirectory.label, "Raw directory snapshot")
    XCTAssertTrue(CodexBackupMedium.rawDirectory.subtitle.contains("without repackaging"))
    XCTAssertTrue(CodexBackupMedium.apfsClone.subtitle.contains("same-volume"))
    XCTAssertTrue(CodexBackupMedium.sparseImage.subtitle.contains("Mac image"))
    XCTAssertTrue(CodexBackupMedium.verifiedZip.subtitle.contains("interchange"))
  }

  private func project(
    path: String,
    name: String,
    remoteURL: String?,
    branch: String?,
    ideState: CodexIDEProjectState,
    hasLocalChanges: Bool,
    mainState: CodexGitMainState,
    hasGit: Bool = true,
    toolEvidence: [CodexToolEvidence] = []
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
      toolEvidence: toolEvidence,
      remoteURL: remoteURL,
      branch: branch,
      ideState: ideState,
      gitStatus: CodexGitWorkspaceStatus(branch: branch, upstream: "origin/main", mainState: mainState, hasLocalChanges: hasLocalChanges)
    )
  }
}
