enum TransferArtifactAutomation {
  /// Eligibility for a post-operation artifact pass. Scans, recovery actions,
  /// and this automation's own jobs never start another automatic pass.
  static func shouldRun(
    enabled: Bool,
    kind: String,
    title: String,
    state: BackgroundJobState,
    isDryRun: Bool = false
  ) -> Bool {
    guard enabled, !isDryRun else { return false }
    if kind == "Migration" {
      guard state == .succeeded || state == .cleanupIncomplete else { return false }
      return ["Import old workspace", "Move workspace", "Export local files"].contains(title)
    }
    guard state == .succeeded else { return false }
    switch kind {
    case "Import":
      return ImportExecutionMode.allCases.contains { $0.label == title }
    case "Codex":
      if title == "Full Auto CODEX lifecycle" { return true }
      // These exact transfer labels end with " Codex projects". An arbitrary
      // scan with the same suffix must not become a write-automation trigger.
      return CodexProjectTransferMode.allCases.contains { "\($0.label) Codex projects" == title }
    case "Cleanup":
      return title == "Applied GitHub cleanup"
    default:
      return false
    }
  }

  /// Refine an eligible terminal job only after its automatic pass finishes.
  /// Remaining source paths or partial artifact failures keep the warning.
  static func completionState(
    requested: BackgroundJobState,
    artifactFailures: Bool,
    originalResidualsRemain: Bool
  ) -> BackgroundJobState {
    switch requested {
    case .failed, .cancelled, .queued, .running:
      return requested
    case .succeeded, .cleanupIncomplete:
      return artifactFailures || originalResidualsRemain ? .cleanupIncomplete : .succeeded
    }
  }
}
