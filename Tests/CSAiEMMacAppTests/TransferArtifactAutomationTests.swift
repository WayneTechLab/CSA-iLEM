import XCTest
@testable import CSAiEMMacApp

final class TransferArtifactAutomationTests: XCTestCase {
  func testNativeMigrationCanFollowSuccessOrIncompleteCleanup() {
    for title in ["Import old workspace", "Move workspace", "Export local files"] {
      for state in [BackgroundJobState.succeeded, .cleanupIncomplete] {
        XCTAssertTrue(TransferArtifactAutomation.shouldRun(enabled: true, kind: "Migration", title: title, state: state))
      }
    }
  }

  func testActualImportCodexAndAppliedCleanupJobsAreEligibleAfterSuccess() {
    let jobs: [(String, String)] = [
      ("Import", "Codespace -> Local"),
      ("Import", "Repo -> Local"),
      ("Import", "Repo -> Local + Devcontainer + Actions"),
      ("Codex", "Backup Only Codex projects"),
      ("Codex", "Copy to Output Codex projects"),
      ("Codex", "Sync and Move Codex projects"),
      ("Codex", "Sync and Sync Codex projects"),
      ("Codex", "Scan & Backup (Auto Merge) Codex projects"),
      ("Codex", "Full Auto CODEX lifecycle"),
      ("Cleanup", "Applied GitHub cleanup")
    ]
    for (kind, title) in jobs {
      XCTAssertTrue(TransferArtifactAutomation.shouldRun(enabled: true, kind: kind, title: title, state: .succeeded), title)
      XCTAssertFalse(TransferArtifactAutomation.shouldRun(enabled: true, kind: kind, title: title, state: .cleanupIncomplete), title)
    }
  }

  func testDisabledDryRunAndNonterminalOrFailedJobsCannotStartAutomation() {
    let jobs = [("Migration", "Move workspace"), ("Codex", "Full Auto CODEX lifecycle"), ("Import", "Repo -> Local"), ("Cleanup", "Applied GitHub cleanup")]
    for (kind, title) in jobs {
      XCTAssertFalse(TransferArtifactAutomation.shouldRun(enabled: false, kind: kind, title: title, state: .succeeded))
      XCTAssertFalse(TransferArtifactAutomation.shouldRun(enabled: true, kind: kind, title: title, state: .succeeded, isDryRun: true))
      for state in [BackgroundJobState.queued, .running, .failed, .cancelled] {
        XCTAssertFalse(TransferArtifactAutomation.shouldRun(enabled: true, kind: kind, title: title, state: state))
      }
    }
  }

  func testReadOnlyRecoveryRetirementAndOwnJobsNeverTriggerAnotherPass() {
    let jobs = [
      ("Audit", "Scan old source leftovers"),
      ("GitHub", "Repository catalog"),
      ("GitHub", "GitHub billing report"),
      ("Storage", "Storage summary"),
      ("Startup", "Startup checks"),
      ("Snapshot", "Create snapshot"),
      ("Snapshot", "Restore snapshot"),
      ("Recovery", "Restore retired checkout"),
      ("Recovery", "Restore transfer artifact"),
      ("Recovery", "Recover local workspace"),
      ("Migration", "Retire reviewed checkout"),
      ("Migration", "Automatic transfer artifact cleanup"),
      ("Import", "List repositories"),
      ("Codex", "Scan Codex projects"),
      ("Codex", "Inspect saved Codex projects"),
      ("Codex", "Unexpected future operation Codex projects"),
      ("Cleanup", "Preview GitHub cleanup"),
      ("Cleanup", "Dry run GitHub cleanup")
    ]
    for (kind, title) in jobs {
      for state in [BackgroundJobState.succeeded, .cleanupIncomplete] {
        XCTAssertFalse(TransferArtifactAutomation.shouldRun(enabled: true, kind: kind, title: title, state: state), "\(kind): \(title)")
      }
    }
  }

  func testPartialResultsAndRemainingOriginalSourcesKeepCleanupIncomplete() {
    XCTAssertEqual(TransferArtifactAutomation.completionState(requested: .succeeded, artifactFailures: true, originalResidualsRemain: false), .cleanupIncomplete)
    XCTAssertEqual(TransferArtifactAutomation.completionState(requested: .cleanupIncomplete, artifactFailures: true, originalResidualsRemain: false), .cleanupIncomplete)
    XCTAssertEqual(TransferArtifactAutomation.completionState(requested: .succeeded, artifactFailures: false, originalResidualsRemain: true), .cleanupIncomplete)
    XCTAssertEqual(TransferArtifactAutomation.completionState(requested: .cleanupIncomplete, artifactFailures: false, originalResidualsRemain: true), .cleanupIncomplete)
    XCTAssertEqual(TransferArtifactAutomation.completionState(requested: .cleanupIncomplete, artifactFailures: false, originalResidualsRemain: false), .succeeded)
    XCTAssertEqual(TransferArtifactAutomation.completionState(requested: .succeeded, artifactFailures: false, originalResidualsRemain: false), .succeeded)
  }

  func testCompletionCannotDowngradeFailureOrPromoteNonterminalState() {
    for state in [BackgroundJobState.failed, .cancelled, .queued, .running] {
      XCTAssertEqual(TransferArtifactAutomation.completionState(requested: state, artifactFailures: false, originalResidualsRemain: false), state)
      XCTAssertEqual(TransferArtifactAutomation.completionState(requested: state, artifactFailures: true, originalResidualsRemain: true), state)
    }
  }
}
