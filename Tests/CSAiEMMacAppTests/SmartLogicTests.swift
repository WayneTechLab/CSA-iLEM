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

  func testGitHubProviderOutcomeClassifiesPermissionAuthNotFoundAndTimeout() {
    XCTAssertEqual(CSAiEMGitHubProviderOutcome.classify(status: 1, output: "HTTP 403: Resource not accessible by integration"), .permissionDenied)
    XCTAssertEqual(CSAiEMGitHubProviderOutcome.classify(status: 1, output: "authentication required"), .authenticationRequired)
    XCTAssertEqual(CSAiEMGitHubProviderOutcome.classify(status: 1, output: "Could not resolve to an issue or pull request"), .notFound)
    XCTAssertEqual(CSAiEMGitHubProviderOutcome.classify(status: 124, output: "Command timed out."), .timeout)
  }

  func testGitHubIssueRetryRecordRoundTripsReviewedPayload() throws {
    let command = try CSAiEMGitHubIssueCommand.make(mutation: .addLabel, issueNumber: 7, body: "", labels: "recovery")
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let record = CSAiEMGitHubIssueRetryRecord(id: "github.com|WayneTechLab/Test|7|addLabel", host: "github.com", repository: "WayneTechLab/Test", command: command, createdAt: date, lastAttemptAt: date, attempts: 2, lastError: "Permission denied")
    let encoded = try JSONEncoder().encode(record)
    let decoded = try JSONDecoder().decode(CSAiEMGitHubIssueRetryRecord.self, from: encoded)
    XCTAssertEqual(decoded, record)
    XCTAssertTrue(decoded.summary.contains("2 attempts"))
  }

  func testResearchSnapshotBuildsConservativeMetadataAndRelationshipNotes() throws {
    let metadata = try JSONDecoder().decode(CSAiEMResearchRepositoryMetadata.self, from: Data("""
    {
      "nameWithOwner":"WayneTechLab/Flowers-Field-Guide",
      "description":"A retained test guide",
      "defaultBranchRef":{"name":"main"},
      "isArchived":false,
      "isFork":true,
      "homepageUrl":null,
      "licenseInfo":{"key":"mit","name":"MIT License"},
      "primaryLanguage":{"name":"JavaScript"},
      "repositoryTopics":["flowers","test"],
      "pushedAt":"2026-08-11T07:57:53Z",
      "updatedAt":"2026-08-11T07:58:10Z",
      "createdAt":"2026-08-11T07:54:02Z",
      "stargazerCount":0,
      "forkCount":1,
      "issues":{"totalCount":1},
      "pullRequests":{"totalCount":2}
    }
    """.utf8))

    let snapshot = CSAiEMResearchSnapshot.build(metadata: metadata, localMatches: ["/tmp/flowers-main", "/tmp/flowers-copy"], capturedAt: observedDate)
    XCTAssertEqual(snapshot.repository, "WayneTechLab/Flowers-Field-Guide")
    XCTAssertEqual(snapshot.defaultBranch, "main")
    XCTAssertEqual(snapshot.primaryLanguage, "JavaScript")
    XCTAssertEqual(snapshot.topics, ["flowers", "test"])
    XCTAssertEqual(snapshot.localMatches.count, 2)
    XCTAssertTrue(snapshot.riskNotes.contains { $0.contains("Multiple local paths") })
    XCTAssertTrue(snapshot.relationshipNotes.contains { $0.contains("does not select a canonical") })
    XCTAssertTrue(snapshot.summary.contains("2 local path matches"))
  }

  func testLocalResearchSummaryParsesDependenciesAndSkipsGeneratedTrees() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-research-(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules/generated"), withIntermediateDirectories: true)
    try Data("# fixture\nfastapi>=1.0\nrequests==2.0\n".utf8).write(to: root.appendingPathComponent("requirements.txt"))
    try Data("{\"dependencies\":{\"swift-markdown\":\"^1.0\"},\"devDependencies\":{\"vitest\":\"^2.0\"}}".utf8).write(to: root.appendingPathComponent("package.json"))
    try Data("import Foundation\n".utf8).write(to: root.appendingPathComponent("Sources/App.swift"))
    try Data("generated\n".utf8).write(to: root.appendingPathComponent("node_modules/generated/index.js"))

    let summary = CSAiEMLocalCodebaseSummary.scan(path: root.path)
    XCTAssertEqual(summary.fileCount, 3)
    XCTAssertEqual(summary.sourceFileCount, 1)
    XCTAssertEqual(summary.manifests, ["package.json", "requirements.txt"])
    XCTAssertEqual(summary.dependencies, ["fastapi", "requests", "swift-markdown", "vitest"])
    XCTAssertTrue(summary.hasGit == false)
    XCTAssertTrue(summary.warnings.contains { $0.contains("No .git") })
    XCTAssertFalse(summary.topLevelEntries.contains("node_modules"))
  }

  func testResearchReleaseAndChangelogEvidenceIsBoundedAndProvenanceAware() throws {
    let releases = try JSONDecoder().decode([CSAiEMResearchReleaseEntry].self, from: Data("""
    [{"tagName":"v1.2.0","name":"Spring release","publishedAt":"2026-08-13T00:00:00Z","isDraft":false,"isPrerelease":true,"url":"https://github.com/example/repo/releases/tag/v1.2.0"}]
    """.utf8))
    XCTAssertEqual(releases.first?.displayTitle, "Spring release")
    XCTAssertTrue(releases.first?.isPrerelease == true)

    let path = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-changelog-(UUID().uuidString).md")
    defer { try? FileManager.default.removeItem(at: path) }
    let content = "# Changelog\n\n## Unreleased\n\n## 1.2.0\n\n## 1.1.0\n"
    try Data(content.utf8).write(to: path)
    let summary = try XCTUnwrap(CSAiEMLocalChangelogSummary.scan(path: path.path, maxBytes: 256_000, maxHeadings: 10))
    XCTAssertTrue(summary.hasUnreleasedSection)
    XCTAssertEqual(summary.headings, ["Changelog", "Unreleased", "1.2.0", "1.1.0"])
    XCTAssertFalse(summary.truncated)
    XCTAssertTrue(summary.path.hasSuffix(".md"))
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

  func testRouteReceiptsPersistStateAndSummarizePendingWorkAcrossRestart() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-route-receipts-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let sources = [
      project(path: "/tmp/route-safe", name: "Safe", remoteURL: "https://github.com/example/safe.git", branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized),
      project(path: "/tmp/route-review", name: "Review", remoteURL: nil, branch: nil, ideState: .linked, hasLocalChanges: true, mainState: .noGit, hasGit: false)
    ]
    let decisions = CodexSmartLogicEngine.evaluate(sources)
    let session = CodexScanSession(id: "route-session", profile: "fast-index", sourceRoots: ["/tmp"], createdAt: observedDate, ruleVersion: CodexSmartLogicEngine.ruleVersion, decisionCount: decisions.count)
    let deltas = sources.map { CodexSourceDelta(sourcePath: $0.path, kind: .unchanged, previousFingerprint: "same", currentFingerprint: "same") }
    let planned = CodexSmartLogicEngine.routeReceipts(sessionID: session.id, decisions: decisions, deltas: deltas, dispositions: [:], updatedAt: observedDate)
    let safe = planned.first { $0.sourcePath == "/tmp/route-safe" }!
    let review = planned.first { $0.sourcePath == "/tmp/route-review" }!
    let completed = CodexScanRouteReceipt(sessionID: safe.sessionID, sourcePath: safe.sourcePath, route: safe.route, state: .completed, attemptCount: 1, updatedAt: observedDate.addingTimeInterval(1), detail: "completed")
    let failed = CodexScanRouteReceipt(sessionID: review.sessionID, sourcePath: review.sourcePath, route: review.route, state: .failed, attemptCount: 1, updatedAt: observedDate.addingTimeInterval(1), detail: "failed")
    let store = CodexCatalogStore(rootPath: root.path)
    try store.save(session: session, decisions: decisions, routeReceipts: [completed, failed], deltas: deltas)
    let restored = CodexCatalogStore(rootPath: root.path).routeReceipts(for: session.id)

    XCTAssertEqual(restored.count, 2)
    XCTAssertEqual(restored.first { $0.sourcePath == completed.sourcePath }?.state, .completed)
    XCTAssertEqual(restored.first { $0.sourcePath == failed.sourcePath }?.state, .failed)
    let summary = CodexSmartLogicEngine.routeReceiptSummary(restored)
    XCTAssertEqual(summary.completedCount, 1)
    XCTAssertEqual(summary.failedCount, 1)
    XCTAssertEqual(summary.pendingCount, 1)
  }

  func testPendingRouteReceiptPreviewExcludesCompletedAndSkippedAndOrdersFailuresFirst() {
    let base = CodexScanRouteReceipt(sessionID: "preview", sourcePath: "/tmp/base", route: .targetedVerification, state: .planned, attemptCount: 0, updatedAt: observedDate, detail: "planned")
    let receipts = [
      base,
      CodexScanRouteReceipt(sessionID: "preview", sourcePath: "/tmp/completed", route: .metadataTriage, state: .completed, attemptCount: 1, updatedAt: observedDate, detail: "done"),
      CodexScanRouteReceipt(sessionID: "preview", sourcePath: "/tmp/skipped", route: .noDeepScan, state: .skipped, attemptCount: 0, updatedAt: observedDate, detail: "excluded"),
      CodexScanRouteReceipt(sessionID: "preview", sourcePath: "/tmp/failed", route: .targetedVerification, state: .failed, attemptCount: 2, updatedAt: observedDate, detail: "retry")
    ]

    let pending = CodexSmartLogicEngine.pendingRouteReceipts(receipts)
    XCTAssertEqual(pending.map(\.sourcePath), ["/tmp/failed", "/tmp/base"])
    XCTAssertFalse(pending.contains { $0.state == .completed || $0.state == .skipped })
  }

  func testRouteReceiptExportWritesPortableJSONAndCSVWithoutChangingReceiptOrder() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-route-export-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let receipts = [
      CodexScanRouteReceipt(sessionID: "export-session", sourcePath: "/tmp/z-source", route: .targetedVerification, state: .failed, attemptCount: 2, updatedAt: observedDate.addingTimeInterval(2), detail: "needs, review"),
      CodexScanRouteReceipt(sessionID: "export-session", sourcePath: "/tmp/a-source", route: .metadataTriage, state: .completed, attemptCount: 1, updatedAt: observedDate, detail: "completed")
    ]
    let store = CodexCatalogStore(rootPath: root.path)
    let paths = try store.exportRouteReceipts(sessionID: "export-session", receipts: receipts)

    XCTAssertEqual(paths.map { URL(fileURLWithPath: $0).pathExtension }, ["json", "csv"])
    let bundle = try JSONDecoder().decode(CodexRouteReceiptExportBundle.self, from: Data(contentsOf: URL(fileURLWithPath: paths[0])))
    XCTAssertEqual(bundle.sessionID, "export-session")
    XCTAssertEqual(bundle.receipts.map(\.sourcePath), ["/tmp/a-source", "/tmp/z-source"])
    XCTAssertEqual(bundle.summary.failedCount, 1)
    let csv = try String(contentsOfFile: paths[1], encoding: .utf8)
    XCTAssertTrue(csv.contains("session_id,source_path,route,state,attempt_count,updated_at,detail"))
    XCTAssertTrue(csv.contains("\"needs, review\""))
  }

  func testRouteReceiptComparisonKeepsImportedOnlyRowsReadOnlyAndSortsBySource() {
    let live = CodexScanRouteReceipt(sessionID: "live", sourcePath: "/tmp/a-source", route: .targetedVerification, state: .completed, attemptCount: 2, updatedAt: observedDate, detail: "live")
    let imported = [
      CodexScanRouteReceipt(sessionID: "imported", sourcePath: "/tmp/z-source", route: .metadataTriage, state: .planned, attemptCount: 0, updatedAt: observedDate, detail: "imported only"),
      CodexScanRouteReceipt(sessionID: "imported", sourcePath: "/tmp/a-source", route: .targetedVerification, state: .failed, attemptCount: 1, updatedAt: observedDate, detail: "older state")
    ]

    let rows = CodexSmartLogicEngine.compareRouteReceipts(live: [live], imported: imported)
    XCTAssertEqual(rows.map(\.sourcePath), ["/tmp/a-source", "/tmp/z-source"])
    XCTAssertEqual(rows.map(\.kind), [.changed, .importedOnly])
    XCTAssertTrue(rows[1].explanation.contains("cannot enter live execution"))
    let summary = CodexSmartLogicEngine.routeReceiptComparisonSummary(rows)
    XCTAssertEqual(summary.changedCount, 1)
    XCTAssertEqual(summary.importedOnlyCount, 1)
    XCTAssertEqual(summary.liveOnlyCount, 0)
  }

  func testRouteReceiptBaselineDecisionStatesComparisonOnlyAuthority() throws {
    let decision = CodexRouteReceiptBaselineDecision(
      id: "baseline-1",
      liveSessionID: "live-session",
      importedSessionID: "imported-session",
      importedSourceName: "route-receipts-imported.json",
      decidedAt: observedDate,
      detail: "comparison only"
    )
    let data = try JSONEncoder().encode(decision)
    let restored = try JSONDecoder().decode(CodexRouteReceiptBaselineDecision.self, from: data)
    XCTAssertEqual(restored, decision)
    XCTAssertTrue(restored.detail.contains("comparison"))
    XCTAssertNotEqual(restored.liveSessionID, restored.importedSessionID)
  }

  func testRouteReceiptBaselineAuditEventRoundTripsAcceptanceAndRevocation() throws {
    let events = [
      CodexRouteReceiptBaselineAuditEvent(id: "revoke", action: .revoked, liveSessionID: "live", importedSessionID: "imported", importedSourceName: "bundle.json", occurredAt: observedDate.addingTimeInterval(1), detail: "revoked"),
      CodexRouteReceiptBaselineAuditEvent(id: "accept", action: .accepted, liveSessionID: "live", importedSessionID: "imported", importedSourceName: "bundle.json", occurredAt: observedDate, detail: "accepted")
    ]
    let data = try JSONEncoder().encode(events)
    let restored = try JSONDecoder().decode([CodexRouteReceiptBaselineAuditEvent].self, from: data)
    XCTAssertEqual(restored, events)
    XCTAssertEqual(restored.map(\.action), [.revoked, .accepted])
    XCTAssertTrue(restored.first?.detail.contains("revoked") == true)
  }

  func testRouteReceiptBaselineAuditExportIsDeterministicAndReadOnly() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-baseline-audit-export-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let newer = CodexRouteReceiptBaselineAuditEvent(
      id: "event-new",
      action: .revoked,
      liveSessionID: "live",
      importedSessionID: "imported",
      importedSourceName: "bundle.json",
      occurredAt: observedDate.addingTimeInterval(10),
      detail: "revoked, retained as read-only"
    )
    let older = CodexRouteReceiptBaselineAuditEvent(
      id: "event-old",
      action: .accepted,
      liveSessionID: "live",
      importedSessionID: "imported",
      importedSourceName: "bundle.json",
      occurredAt: observedDate,
      detail: "accepted comparison only"
    )
    let store = CodexCatalogStore(rootPath: root.path)
    let paths = try store.exportRouteReceiptBaselineAudit(events: [older, newer])
    XCTAssertEqual(paths.map { URL(fileURLWithPath: $0).pathExtension }, ["json", "csv"])
    let bundle = try JSONDecoder().decode(
      CodexRouteReceiptBaselineAuditExportBundle.self,
      from: Data(contentsOf: URL(fileURLWithPath: paths[0]))
    )
    XCTAssertEqual(bundle.auditVersion, "baseline-audit-v1")
    XCTAssertEqual(bundle.events.map(\.id), ["event-new", "event-old"])
    let csv = try String(contentsOfFile: paths[1], encoding: .utf8)
    XCTAssertTrue(csv.hasPrefix("id,action,live_session_id"))
    XCTAssertTrue(csv.contains("\"revoked, retained as read-only\""))
    XCTAssertFalse(FileManager.default.fileExists(atPath: (root.path as NSString).appendingPathComponent(".SYSTEMX/Index/catalog.sqlite")))
  }

  func testImportedBaselineAuditHistoryRetainsCompatibilityMetadata() throws {
    let event = CodexRouteReceiptBaselineAuditEvent(
      id: "event",
      action: .accepted,
      liveSessionID: "live",
      importedSessionID: "imported",
      importedSourceName: "bundle.json",
      occurredAt: observedDate,
      detail: "comparison only"
    )
    let record = CodexImportedBaselineAuditRecord(
      id: "history",
      sourceName: "bundle.json",
      importedAt: observedDate,
      auditVersion: "baseline-audit-v1",
      acceptedCount: 1,
      revokedCount: 0,
      events: [event]
    )
    let restored = try JSONDecoder().decode(
      CodexImportedBaselineAuditRecord.self,
      from: JSONEncoder().encode(record)
    )
    XCTAssertEqual(restored, record)
    XCTAssertEqual(restored.compatibilityLabel, "schema compatible")
    XCTAssertEqual(restored.acceptedCount, 1)
    XCTAssertEqual(restored.revokedCount, 0)
  }

  func testCatalogStorePersistsSessionDeltaAndTimingEvidenceAcrossRestart() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-session-diff-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let source = project(path: "/tmp/session-diff-source", name: "Session Diff", remoteURL: nil, branch: nil, ideState: .unavailable, hasLocalChanges: false, mainState: .noOriginMain)
    let decision = CodexSmartLogicEngine.evaluate([source]).first!
    let session = CodexScanSession(id: "session-diff", profile: "fast-index", sourceRoots: ["/tmp/root-a", "/tmp/root-b"], createdAt: observedDate, ruleVersion: CodexSmartLogicEngine.ruleVersion, decisionCount: 1)
    let delta = CodexSourceDelta(sourcePath: source.path, kind: .unchanged, previousFingerprint: "old", currentFingerprint: "new")
    let timing = CodexScanTimingEvidence(sessionID: session.id, discoveryMilliseconds: 12, decisionMilliseconds: 4, totalMilliseconds: 16, discoveredSourceCount: 1, evaluatedSourceCount: 0, reusedSourceCount: 1, changedSourceCount: 0, affectedGroupCount: 0)

    let store = CodexCatalogStore(rootPath: root.path)
    try store.save(session: session, decisions: [decision], deltas: [delta], timing: timing)
    let reopened = CodexCatalogStore(rootPath: root.path)

    XCTAssertEqual(reopened.recentSessions(limit: 1).first?.id, session.id)
    XCTAssertEqual(reopened.recentSessions(limit: 1).first?.sourceRoots, session.sourceRoots)
    XCTAssertEqual(reopened.timing(for: session.id), timing)
    XCTAssertEqual(reopened.sourceDeltas(for: session.id), [delta])
  }

  func testCatalogStoreExportsPortableComparisonEvidenceWithoutSourceFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-comparison-export-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let row = CodexDecisionComparisonRow(
      sourcePath: "/tmp/export-source",
      kind: .changed,
      previousGroupKey: "name:old",
      currentGroupKey: "name:new",
      previousClassification: .shadowCopy,
      currentClassification: .mergeCandidate,
      previousFingerprint: "old",
      currentFingerprint: "new"
    )

    let store = CodexCatalogStore(rootPath: root.path)
    let routeSummary = CodexEvidenceScanRouteSummary(totalCount: 1, metadataTriageCount: 0, targetedVerificationCount: 1, noDeepScanCount: 0)
    let assessment = CodexSmartLogicEngine.profileAssessment(profile: .fastIndex, routeSummary: routeSummary)
    let paths = try store.exportComparison(
      currentSessionID: "current",
      baselineSessionID: "baseline",
      rows: [row],
      selectedScanProfile: .fastIndex,
      profileAssessment: assessment
    )
    XCTAssertEqual(paths.count, 2)
    XCTAssertTrue(paths.allSatisfy { FileManager.default.fileExists(atPath: $0) })
    let bundle = try JSONDecoder().decode(CodexComparisonEvidenceBundle.self, from: Data(contentsOf: URL(fileURLWithPath: paths[0])))
    XCTAssertEqual(bundle.currentSessionID, "current")
    XCTAssertEqual(bundle.baselineSessionID, "baseline")
    XCTAssertEqual(bundle.rows, [row])
    XCTAssertEqual(bundle.selectedScanProfile, .fastIndex)
    XCTAssertEqual(bundle.profileAssessment, assessment)
    XCTAssertTrue(try String(contentsOfFile: paths[1]).contains("/tmp/export-source"))
    XCTAssertFalse(FileManager.default.fileExists(atPath: "/tmp/export-source"))
  }

  func testImportedEvidenceRecordRoundTripsForLocalHistory() throws {
    let bundle = CodexComparisonEvidenceBundle(
      exportedAt: observedDate,
      currentSessionID: "current-history",
      baselineSessionID: "baseline-history",
      currentRuleVersion: "smart-logic-v2.9",
      baselineRuleVersion: "smart-logic-v2.8",
      rows: [],
      selectedScanProfile: nil,
      profileAssessment: nil
    )
    let record = CodexImportedEvidenceRecord(id: "history-1", sourceName: "comparison.json", importedAt: observedDate, bundle: bundle)
    let restored = try JSONDecoder().decode(CodexImportedEvidenceRecord.self, from: JSONEncoder().encode(record))
    XCTAssertEqual(restored, record)
    XCTAssertEqual(restored.bundle.currentSessionID, "current-history")
    XCTAssertEqual(restored.profileLabel, "unknown")
    XCTAssertEqual(restored.profileAuditLabel, "assessment unavailable")
    XCTAssertEqual(restored.compatibilityState, .legacy)
    XCTAssertTrue(CodexEvidenceHistoryFilter.legacyUnknown.includes(restored))
    XCTAssertFalse(CodexEvidenceHistoryFilter.profileMatched.includes(restored))
  }

  func testImportedEvidenceCompatibilityDistinguishesCompleteAndPartialMetadata() {
    let routeSummary = CodexEvidenceScanRouteSummary(totalCount: 1, metadataTriageCount: 0, targetedVerificationCount: 0, noDeepScanCount: 1)
    let assessment = CodexSmartLogicEngine.profileAssessment(profile: .fastIndex, routeSummary: routeSummary)
    let completeBundle = CodexComparisonEvidenceBundle(
      exportedAt: observedDate,
      currentSessionID: "complete",
      baselineSessionID: nil,
      currentRuleVersion: "smart-logic-v3.9",
      baselineRuleVersion: nil,
      rows: [],
      selectedScanProfile: .fastIndex,
      profileAssessment: assessment
    )
    let partialBundle = CodexComparisonEvidenceBundle(
      exportedAt: observedDate,
      currentSessionID: "partial",
      baselineSessionID: nil,
      currentRuleVersion: "smart-logic-v3.9",
      baselineRuleVersion: nil,
      rows: [],
      selectedScanProfile: .fastIndex,
      profileAssessment: nil
    )

    XCTAssertEqual(CodexImportedEvidenceRecord(id: "complete", sourceName: "complete.json", importedAt: observedDate, bundle: completeBundle).compatibilityState, .complete)
    XCTAssertEqual(CodexImportedEvidenceRecord(id: "partial", sourceName: "partial.json", importedAt: observedDate, bundle: partialBundle).compatibilityState, .partial)
  }

  func testSmartScanPlanRoutesChangedAndReviewSourcesWithoutDeepScanningSafeSources() {
    let projects = [
      project(path: "/tmp/canonical", name: "canonical", remoteURL: "https://github.com/example/canonical.git", branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized),
      project(path: "/tmp/changed", name: "changed", remoteURL: "https://github.com/example/changed.git", branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized),
      project(path: "/tmp/review", name: "review", remoteURL: nil, branch: nil, ideState: .linked, hasLocalChanges: true, mainState: .noGit, hasGit: false),
      project(path: "/tmp/excluded", name: "excluded", remoteURL: "https://github.com/example/excluded.git", branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized)
    ]
    let decisions = CodexSmartLogicEngine.evaluate(projects, destinationRoot: "/tmp/output")
    let deltas = [
      CodexSourceDelta(sourcePath: "/tmp/canonical", kind: .unchanged, previousFingerprint: "a", currentFingerprint: "a"),
      CodexSourceDelta(sourcePath: "/tmp/changed", kind: .changed, previousFingerprint: "a", currentFingerprint: "b"),
      CodexSourceDelta(sourcePath: "/tmp/review", kind: .added, previousFingerprint: nil, currentFingerprint: "c"),
      CodexSourceDelta(sourcePath: "/tmp/excluded", kind: .unchanged, previousFingerprint: "d", currentFingerprint: "d")
    ]
    let reviewDecision = decisions.first { $0.sourcePath == "/tmp/review" }!
    let plan = CodexSmartLogicEngine.smartScanPlan(
      decisions: decisions,
      deltas: deltas,
      dispositions: [reviewDecision.sourcePath: .deferred, "/tmp/excluded": .excluded]
    )

    XCTAssertEqual(plan.totalCount, 4)
    XCTAssertEqual(plan.metadataTriageCount, 1)
    XCTAssertEqual(plan.targetedVerificationCount, 2)
    XCTAssertEqual(plan.noDeepScanCount, 1)
    XCTAssertEqual(plan.reviewRequiredCount, 1)
    XCTAssertTrue(plan.profileGuidance(.fastIndex).contains("Full Verification"))
    XCTAssertFalse(plan.profileGuidance(.verified).contains("remains recommended"))
  }

  func testAuthorityComparisonKeepsLiveAndImportedEvidenceDistinct() {
    let live = [
      CodexDecisionComparisonRow(sourcePath: "/tmp/shared", kind: .changed, previousGroupKey: "old", currentGroupKey: "new", previousClassification: .shadowCopy, currentClassification: .mergeCandidate, previousFingerprint: "a", currentFingerprint: "b"),
      CodexDecisionComparisonRow(sourcePath: "/tmp/live-only", kind: .added, previousGroupKey: nil, currentGroupKey: "live", previousClassification: nil, currentClassification: .canonical, previousFingerprint: nil, currentFingerprint: "c")
    ]
    let imported = CodexComparisonEvidenceBundle(
      exportedAt: observedDate,
      currentSessionID: "imported-session",
      baselineSessionID: "baseline",
      currentRuleVersion: "smart-logic-v3.1",
      baselineRuleVersion: "smart-logic-v3.0",
      rows: [live[0], CodexDecisionComparisonRow(sourcePath: "/tmp/imported-only", kind: .removed, previousGroupKey: "old", currentGroupKey: nil, previousClassification: .canonical, currentClassification: nil, previousFingerprint: "d", currentFingerprint: nil)],
      selectedScanProfile: nil,
      profileAssessment: nil
    )

    let comparison = CodexSmartLogicEngine.authorityComparison(liveSessionID: "live-session", liveRows: live, importedBundle: imported)
    XCTAssertFalse(comparison.sameCurrentSession)
    XCTAssertEqual(comparison.overlappingSourceCount, 1)
    XCTAssertEqual(comparison.liveOnlySourceCount, 1)
    XCTAssertEqual(comparison.importedOnlySourceCount, 1)
  }

  func testProvenanceRowsFilterWithoutPromotingImportedEvidence() {
    let live = [
      CodexDecisionComparisonRow(sourcePath: "/tmp/shared", kind: .changed, previousGroupKey: "old", currentGroupKey: "new", previousClassification: .shadowCopy, currentClassification: .mergeCandidate, previousFingerprint: "a", currentFingerprint: "b"),
      CodexDecisionComparisonRow(sourcePath: "/tmp/live-only", kind: .added, previousGroupKey: nil, currentGroupKey: "live", previousClassification: nil, currentClassification: .canonical, previousFingerprint: nil, currentFingerprint: "c")
    ]
    let imported = CodexComparisonEvidenceBundle(
      exportedAt: observedDate,
      currentSessionID: "imported-session",
      baselineSessionID: "baseline",
      currentRuleVersion: "smart-logic-v3.1",
      baselineRuleVersion: "smart-logic-v3.0",
      rows: [live[0], CodexDecisionComparisonRow(sourcePath: "/tmp/imported-only", kind: .removed, previousGroupKey: "old", currentGroupKey: nil, previousClassification: .canonical, currentClassification: nil, previousFingerprint: "d", currentFingerprint: nil)],
      selectedScanProfile: nil,
      profileAssessment: nil
    )

    let liveOnly = CodexSmartLogicEngine.provenanceRows(liveRows: live, importedBundle: imported, filter: .liveOnly)
    let importedOnly = CodexSmartLogicEngine.provenanceRows(liveRows: live, importedBundle: imported, filter: .importedOnly)
    let overlapping = CodexSmartLogicEngine.provenanceRows(liveRows: live, importedBundle: imported, filter: .overlapping)

    XCTAssertEqual(liveOnly.map(\.sourcePath), ["/tmp/live-only"])
    XCTAssertEqual(importedOnly.map(\.sourcePath), ["/tmp/imported-only"])
    XCTAssertEqual(overlapping.map(\.sourcePath), ["/tmp/shared"])
    XCTAssertEqual(overlapping.first?.liveKind, .changed)
    XCTAssertEqual(overlapping.first?.importedKind, .changed)
    XCTAssertEqual(liveOnly.first?.actionability, .liveReviewRequired)
    XCTAssertEqual(overlapping.first?.actionability, .liveComparison)
    XCTAssertEqual(importedOnly.first?.actionability, .importedContextOnly)
    XCTAssertEqual(liveOnly.first?.scanRoute, .targetedVerification)
    XCTAssertEqual(overlapping.first?.scanRoute, .targetedVerification)
    XCTAssertEqual(importedOnly.first?.scanRoute, .noDeepScan)
    let routeSummary = CodexSmartLogicEngine.scanRouteSummary(liveOnly + overlapping + importedOnly)
    XCTAssertEqual(routeSummary.totalCount, 3)
    XCTAssertEqual(routeSummary.targetedVerificationCount, 2)
    XCTAssertEqual(routeSummary.noDeepScanCount, 1)
    XCTAssertEqual(routeSummary.deepScanAvoidedCount, 1)
    let fastAssessment = CodexSmartLogicEngine.profileAssessment(profile: .fastIndex, routeSummary: routeSummary)
    let verifiedAssessment = CodexSmartLogicEngine.profileAssessment(profile: .verified, routeSummary: routeSummary)
    let yoloAssessment = CodexSmartLogicEngine.profileAssessment(profile: .yolo, routeSummary: routeSummary)
    XCTAssertTrue(fastAssessment.strongerProfileRecommended)
    XCTAssertFalse(verifiedAssessment.strongerProfileRecommended)
    XCTAssertTrue(yoloAssessment.strongerProfileRecommended)
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
    XCTAssertEqual(catalog.count, 18)
    XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
    XCTAssertEqual(Set(catalog.map(\.tag)).count, catalog.count)
    XCTAssertTrue(catalog.contains { $0.tag == "engine.smart-logic" && $0.version == "smart-logic-v5.0" })
    XCTAssertTrue(catalog.contains { $0.tag == "engine.receipts" && $0.version == "receipt-v3.12" })
    XCTAssertTrue(catalog.contains { $0.tag == "engine.recovery" })
    XCTAssertTrue(catalog.contains { $0.tag == "runtime.install" })
    XCTAssertTrue(catalog.contains { $0.tag == "runtime.toolbar" })
    XCTAssertTrue(catalog.contains { $0.tag == "feature.incidents" && $0.version == "incident-v1.2" })
    XCTAssertTrue(catalog.contains { $0.tag == "bridge.github" && $0.version == "issues-v1.4" })
    XCTAssertTrue(catalog.contains { $0.tag == "feature.research" && $0.version == "research-v3.4" })
  }

  func testLocalWorkflowSummaryFlagsDangerousSurfacesAndExtractsActions() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-workflow-" + UUID().uuidString)
    let workflowDirectory = root.appendingPathComponent(".github/workflows")
    try FileManager.default.createDirectory(at: workflowDirectory, withIntermediateDirectories: true)
    let workflow = workflowDirectory.appendingPathComponent("build.yml")
    try """
    name: CI
    on:
      pull_request_target:
    permissions:
      contents: read
    jobs:
      build:
        steps:
          - uses: actions/checkout@v4
          - run: echo \"${{ secrets.TEST_TOKEN }}\"
    """.write(to: workflow, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let summaries = CSAiEMLocalWorkflowSummary.scan(paths: [root.path])
    XCTAssertEqual(summaries.count, 1)
    XCTAssertEqual(summaries[0].workflowName, "CI")
    XCTAssertEqual(summaries[0].actionReferences, ["actions/checkout@v4"])
    XCTAssertTrue(summaries[0].hasPermissionsBlock)
    XCTAssertTrue(summaries[0].usesPullRequestTarget)
    XCTAssertTrue(summaries[0].referencesSecrets)
    XCTAssertFalse(summaries[0].warnings.isEmpty)
  }

  func testResearchSecuritySummaryKeepsReadBoundaryExplicit() {
    let summary = CSAiEMResearchSecuritySummary(
      vulnerabilityAlerts: "permission denied",
      secretScanningAlerts: "available",
      codeScanningAlerts: "not enabled or unavailable",
      workflowCount: 2,
      localWorkflowCount: 1,
      localWorkflowWarnings: 2,
      readBoundary: "Read-only metadata and bounded local workflow text; no secret values, workflow writes, alert dismissal, or administrative changes.",
      warnings: ["Remote workflow inventory unavailable [permission denied]."]
    )
    XCTAssertTrue(summary.summary.contains("2 remote workflows"))
    XCTAssertTrue(summary.readBoundary.contains("no secret values"))
    XCTAssertEqual(summary.warnings.count, 1)
  }

  func testLocalDocumentationSummaryFindsHiddenGitHubAndDocsFilesWithinBounds() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-docs-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root.appendingPathComponent(".github"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
    try "# Project README\n\nOverview\n".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    try "# Security\n\nPolicy\n".write(to: root.appendingPathComponent(".github/SECURITY.md"), atomically: true, encoding: .utf8)
    try "# Operations\n\nRunbook\n".write(to: root.appendingPathComponent("docs/operations.md"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let summaries = CSAiEMLocalDocumentationSummary.scan(paths: [root.path])
    XCTAssertEqual(summaries.count, 3)
    XCTAssertTrue(summaries.contains { $0.kind == "README" && $0.title == "Project README" })
    XCTAssertTrue(summaries.contains { $0.kind == "Security" && $0.title == "Security" })
    XCTAssertTrue(summaries.contains { $0.kind == "Project documentation" && $0.title == "Operations" })
  }

  func testResearchDocumentationSummaryRetainsRemoteAvailabilityAndWarnings() {
    let summary = CSAiEMResearchDocumentationSummary(
      local: [],
      remote: [CSAiEMRemoteDocumentationEntry(path: "docs/guide.md", name: "guide.md", type: "file", size: 12, htmlURL: nil)],
      remoteStatus: "available",
      warnings: ["Local inventory capped."]
    )
    XCTAssertTrue(summary.summary.contains("0 local documentation files"))
    XCTAssertTrue(summary.summary.contains("1 remote documentation entries"))
    XCTAssertEqual(summary.warnings, ["Local inventory capped."])
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

  func testActiveHostToolEvidenceIsSeparateFromProjectMarkerEvidence() {
    XCTAssertEqual(
      CodexToolEvidenceDetector.activeHostTools(processNames: ["Visual Studio Code", "LM Studio", "unrelated-helper"]),
      [.visualStudioCode, .lmStudio]
    )
    XCTAssertEqual(CodexToolEvidenceDetector.activeHostTools(processNames: ["unrelated-helper"]), [])
  }

  func testSmartLogicCarriesBoundedSnapshotAndHostActivityWithoutPromotingIdentity() {
    let source = project(
      path: "/tmp/active-tool-source",
      name: "Flowers",
      remoteURL: "https://github.com/WayneTechLab/flowers.git",
      branch: "main",
      ideState: .linked,
      hasLocalChanges: false,
      mainState: .synchronized,
      activeToolEvidence: [.visualStudioCode],
      snapshot: CodexProjectSnapshot(fileCount: 400, byteCount: 12_345, latestModification: observedDate, truncated: true)
    )
    let decision = CodexSmartLogicEngine.evaluate([source]).first!
    XCTAssertEqual(decision.classification, .canonical)
    XCTAssertEqual(decision.evidence.activeToolEvidence, [.visualStudioCode])
    XCTAssertTrue(decision.evidence.snapshot.truncated)
    XCTAssertTrue(decision.reasons.contains { $0.contains("does not prove the process opened this project") })
    XCTAssertTrue(decision.reasons.contains { $0.contains("deep content verification remains separate") })
  }

  func testSmartLogicGroupSummaryAggregatesLeadFreshnessAndBlockers() {
    let captured = CodexProjectSnapshot(fileCount: 12, byteCount: 1200, latestModification: observedDate, truncated: false)
    let lead = project(
      path: "/tmp/flowers-lead",
      name: "Flowers",
      remoteURL: "https://github.com/WayneTechLab/flowers.git",
      branch: "main",
      ideState: .linked,
      hasLocalChanges: false,
      mainState: .synchronized,
      snapshot: captured
    )
    let shadow = project(
      path: "/tmp/flowers-shadow",
      name: "Flowers-copy",
      remoteURL: "https://github.com/WayneTechLab/flowers.git",
      branch: "main",
      ideState: .unlinked,
      hasLocalChanges: false,
      mainState: .synchronized,
      snapshot: captured
    )

    let summary = CodexSmartLogicEngine.groupSummaries(CodexSmartLogicEngine.evaluate([lead, shadow])).first!
    XCTAssertEqual(summary.sourceCount, 2)
    XCTAssertEqual(summary.reviewCount, 1)
    XCTAssertEqual(summary.fatalCount, 0)
    XCTAssertEqual(summary.snapshotCoverageCount, 2)
    XCTAssertEqual(summary.recommendedLeadPath, "/tmp/flowers-lead")
    XCTAssertEqual(summary.recommendedLeadName, "Flowers")
    XCTAssertTrue(summary.isBlocked)
    XCTAssertEqual(summary.snapshotState, "bounded snapshots complete")
  }

  func testReviewDispositionExcludesOnlyExplicitSourcesAndRoundTrips() throws {
    let first = project(path: "/tmp/first", name: "First", remoteURL: "https://github.com/WayneTechLab/first", branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized)
    let second = project(path: "/tmp/second", name: "Second", remoteURL: "https://github.com/WayneTechLab/second", branch: "main", ideState: .unlinked, hasLocalChanges: false, mainState: .synchronized)
    let decisions = CodexSmartLogicEngine.evaluate([first, second])
    let dispositions = [second.path: CodexReviewDisposition.excluded]
    let active = CodexSmartLogicEngine.activeDecisions(decisions, dispositions: dispositions)
    XCTAssertEqual(active.map(\.sourcePath), [first.path])

    let data = try JSONEncoder().encode(dispositions)
    let restored = try JSONDecoder().decode([String: CodexReviewDisposition].self, from: data)
    XCTAssertEqual(restored, dispositions)
  }

  func testSourceFingerprintDeltaDetectsAddedChangedUnchangedAndRemovedRows() {
    let unchanged = project(path: "/tmp/unchanged", name: "Unchanged", remoteURL: nil, branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized)
    let changed = project(path: "/tmp/changed", name: "Changed", remoteURL: nil, branch: "main", ideState: .linked, hasLocalChanges: true, mainState: .diverged(ahead: 1, behind: 1))
    let current = [unchanged, changed, project(path: "/tmp/added", name: "Added", remoteURL: nil, branch: nil, ideState: .unavailable, hasLocalChanges: false, mainState: .noOriginMain)]
    let previous = [
      unchanged.path: CodexSmartLogicEngine.sourceFingerprint(unchanged),
      changed.path: CodexSmartLogicEngine.sourceFingerprint(project(path: changed.path, name: changed.name, remoteURL: nil, branch: "main", ideState: .linked, hasLocalChanges: false, mainState: .synchronized)),
      "/tmp/removed": "old-fingerprint"
    ]

    let deltas = CodexSmartLogicEngine.sourceDeltas(previous: previous, current: current)
    XCTAssertEqual(deltas.first(where: { $0.sourcePath == unchanged.path })?.kind, .unchanged)
    XCTAssertEqual(deltas.first(where: { $0.sourcePath == changed.path })?.kind, .changed)
    XCTAssertEqual(deltas.first(where: { $0.sourcePath == "/tmp/added" })?.kind, .added)
    XCTAssertEqual(deltas.first(where: { $0.sourcePath == "/tmp/removed" })?.kind, .removed)
  }

  func testReviewAuditEntryRoundTripsReversibleDispositionMetadata() throws {
    let entry = CodexReviewAuditEntry(
      id: "audit-1",
      sessionID: "session-1",
      sourcePath: "/tmp/shadow",
      groupKey: "remote:https://github.com/example/project",
      previousDisposition: nil,
      nextDisposition: .excluded,
      action: "disposition-changed",
      detail: "Operator excluded a false-positive shadow copy.",
      occurredAt: observedDate
    )
    let restored = try JSONDecoder().decode(CodexReviewAuditEntry.self, from: JSONEncoder().encode(entry))
    XCTAssertEqual(restored, entry)
    XCTAssertEqual(restored.nextDisposition, .excluded)
    XCTAssertNil(restored.previousDisposition)
  }

  func testDecisionComparisonExplainsGroupClassificationAndFingerprintTransitions() {
    let baseline = [
      CodexDecisionSnapshot(sourcePath: "/tmp/lead", groupKey: "name:flowers", classification: .canonical, confidence: 0.98),
      CodexDecisionSnapshot(sourcePath: "/tmp/shadow", groupKey: "name:flowers", classification: .shadowCopy, confidence: 0.55),
      CodexDecisionSnapshot(sourcePath: "/tmp/removed", groupKey: "name:flowers", classification: .mergeCandidate, confidence: 0.8)
    ]
    let current = [
      CodexDecisionSnapshot(sourcePath: "/tmp/lead", groupKey: "remote:github.com/example/flowers", classification: .canonical, confidence: 0.98),
      CodexDecisionSnapshot(sourcePath: "/tmp/shadow", groupKey: "name:flowers", classification: .mergeCandidate, confidence: 0.86),
      CodexDecisionSnapshot(sourcePath: "/tmp/added", groupKey: "name:flowers", classification: .brokenMetadataReview, confidence: 0.15)
    ]

    let rows = CodexSmartLogicEngine.compareSnapshots(
      current: current,
      baseline: baseline,
      currentFingerprints: ["/tmp/lead": "new-lead", "/tmp/shadow": "same-shadow", "/tmp/added": "added"],
      baselineFingerprints: ["/tmp/lead": "old-lead", "/tmp/shadow": "same-shadow", "/tmp/removed": "removed"]
    )

    XCTAssertEqual(rows.first(where: { $0.sourcePath == "/tmp/added" })?.kind, .added)
    XCTAssertEqual(rows.first(where: { $0.sourcePath == "/tmp/removed" })?.kind, .removed)
    XCTAssertEqual(rows.first(where: { $0.sourcePath == "/tmp/shadow" })?.kind, .changed)
    XCTAssertTrue(rows.first(where: { $0.sourcePath == "/tmp/shadow" })?.explanation.contains("classification changed") == true)
    XCTAssertTrue(rows.first(where: { $0.sourcePath == "/tmp/lead" })?.explanation.contains("identity group changed") == true)
  }

  func testDecisionComparisonCSVIsStableAndEscapesEvidenceFields() {
    let row = CodexDecisionComparisonRow(
      sourcePath: "/tmp/Flowers, copy",
      kind: .changed,
      previousGroupKey: "name:flowers",
      currentGroupKey: "remote:github.com/example/flowers",
      previousClassification: .shadowCopy,
      currentClassification: .mergeCandidate,
      previousFingerprint: "old",
      currentFingerprint: "new"
    )

    let csv = CodexSmartLogicEngine.comparisonCSV([row])
    XCTAssertTrue(csv.hasPrefix("source_path,kind,previous_group"))
    XCTAssertTrue(csv.contains("\"/tmp/Flowers, copy\""))
    XCTAssertTrue(csv.contains("classification changed from Shadow-copy review to Merge candidate"))
    XCTAssertEqual(csv.split(separator: "\n").count, 2)
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
    toolEvidence: [CodexToolEvidence] = [],
    activeToolEvidence: [CodexToolEvidence] = [],
    snapshot: CodexProjectSnapshot = CodexProjectSnapshot(fileCount: 0, byteCount: 0, latestModification: nil, truncated: false)
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
      activeToolEvidence: activeToolEvidence,
      snapshot: snapshot,
      remoteURL: remoteURL,
      branch: branch,
      ideState: ideState,
      gitStatus: CodexGitWorkspaceStatus(branch: branch, upstream: "origin/main", mainState: mainState, hasLocalChanges: hasLocalChanges)
    )
  }
}
