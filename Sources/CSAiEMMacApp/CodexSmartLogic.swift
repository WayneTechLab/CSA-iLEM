import Foundation

enum CodexDecisionClass: String, Codable, CaseIterable, Identifiable, Sendable {
  case canonical
  case mergeCandidate
  case sameNameReview
  case brokenMetadataReview
  case shadowCopy
  case unknownOwnerReview
  case unrelated
  case fatalIdentityConflict

  var id: String { rawValue }

  var label: String {
    switch self {
    case .canonical: return "Canonical candidate"
    case .mergeCandidate: return "Merge candidate"
    case .sameNameReview: return "Same-name review"
    case .brokenMetadataReview: return "Broken metadata review"
    case .shadowCopy: return "Shadow-copy review"
    case .unknownOwnerReview: return "Unknown-owner review"
    case .unrelated: return "Unrelated"
    case .fatalIdentityConflict: return "Fatal identity conflict"
    }
  }

  var systemImage: String {
    switch self {
    case .canonical: return "checkmark.seal"
    case .mergeCandidate: return "arrow.triangle.merge"
    case .sameNameReview, .brokenMetadataReview, .shadowCopy, .unknownOwnerReview: return "exclamationmark.magnifyingglass"
    case .unrelated: return "minus.circle"
    case .fatalIdentityConflict: return "xmark.octagon"
    }
  }

  var isReview: Bool {
    switch self {
    case .sameNameReview, .brokenMetadataReview, .shadowCopy, .unknownOwnerReview, .fatalIdentityConflict:
      return true
    case .canonical, .mergeCandidate, .unrelated:
      return false
    }
  }
}

enum CodexReviewDisposition: String, Codable, CaseIterable, Sendable {
  case deferred
  case excluded

  var label: String {
    switch self {
    case .deferred: return "Deferred"
    case .excluded: return "Explicitly excluded"
    }
  }
}

struct CodexReviewAuditEntry: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let sessionID: String
  let sourcePath: String
  let groupKey: String
  let previousDisposition: CodexReviewDisposition?
  let nextDisposition: CodexReviewDisposition?
  let action: String
  let detail: String
  let occurredAt: Date
}

struct CodexSourceDelta: Codable, Hashable, Identifiable, Sendable {
  enum Kind: String, Codable, Sendable {
    case added
    case changed
    case unchanged
    case removed
  }

  let sourcePath: String
  let kind: Kind
  let previousFingerprint: String?
  let currentFingerprint: String?

  var id: String { sourcePath }
}

enum CodexIncidentSeverity: String, Codable, CaseIterable, Sendable {
  case recoverable
  case fatal
}

struct CodexSourceEvidence: Codable, Hashable, Sendable {
  let path: String
  let name: String
  let remoteURL: String?
  let branch: String?
  let hasGit: Bool
  let hasLocalChanges: Bool
  let mainLabel: String
  let ideState: String
  let toolEvidence: [CodexToolEvidence]
  let activeToolEvidence: [CodexToolEvidence]
  let snapshot: CodexProjectSnapshot
  let markers: [String]
  let owner: String?
  let observedAt: Date
}

struct CodexSmartDecision: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let sourcePath: String
  let groupKey: String
  let classification: CodexDecisionClass
  let confidence: Double
  let leadRank: Int
  let isRecommendedLead: Bool
  let evidence: CodexSourceEvidence
  let reasons: [String]
  let recommendedDestination: String?
  let ruleVersion: String
  let createdAt: Date
}

struct CodexSmartGroupSummary: Codable, Hashable, Identifiable, Sendable {
  let groupKey: String
  let sourceCount: Int
  let reviewCount: Int
  let fatalCount: Int
  let snapshotCoverageCount: Int
  let latestSnapshotAt: Date?
  let recommendedLeadPath: String?
  let recommendedLeadName: String?

  var id: String { groupKey }

  var isBlocked: Bool { reviewCount > 0 }

  var snapshotState: String {
    if snapshotCoverageCount == sourceCount && sourceCount > 0 { return "bounded snapshots complete" }
    if snapshotCoverageCount > 0 { return "partial snapshot coverage" }
    return "snapshot unavailable"
  }

  var freshnessLabel: String {
    guard let latestSnapshotAt else { return "freshness unavailable" }
    return ISO8601DateFormatter().string(from: latestSnapshotAt)
  }

  var displayName: String {
    if groupKey.hasPrefix("remote:") { return String(groupKey.dropFirst("remote:".count)) }
    if groupKey.hasPrefix("name:") { return String(groupKey.dropFirst("name:".count)) }
    return groupKey
  }
}

struct CodexScanSession: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let profile: String
  let sourceRoots: [String]
  let createdAt: Date
  let ruleVersion: String
  let decisionCount: Int
}

struct CodexScanTimingEvidence: Codable, Hashable, Sendable {
  let sessionID: String
  let discoveryMilliseconds: Int
  let decisionMilliseconds: Int
  let totalMilliseconds: Int
  let discoveredSourceCount: Int
  let evaluatedSourceCount: Int
  let reusedSourceCount: Int
  let changedSourceCount: Int
  let affectedGroupCount: Int
}

struct CodexCatalogSessionSummary: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let profile: String
  let sourceRoots: [String]
  let createdAt: Date
  let ruleVersion: String
  let decisionCount: Int

  var shortID: String { String(id.prefix(8)) }
}

struct CodexSessionDiffSummary: Codable, Hashable, Sendable {
  let currentSessionID: String
  let previousSessionID: String?
  let addedCount: Int
  let changedCount: Int
  let unchangedCount: Int
  let removedCount: Int
  let affectedGroupCount: Int
  let evaluatedSourceCount: Int
  let reusedSourceCount: Int
  let timing: CodexScanTimingEvidence

  var headline: String {
    if previousSessionID == nil {
      return "Baseline session · evaluated (evaluatedSourceCount) source row(s)"
    }
    return "Compared with session (String(previousSessionID!.prefix(8))) · (changedCount + addedCount + removedCount) changed/removed row(s) · (reusedSourceCount) reused"
  }
}

struct CodexDecisionSnapshot: Codable, Hashable, Identifiable, Sendable {
  let sourcePath: String
  let groupKey: String
  let classification: CodexDecisionClass
  let confidence: Double

  var id: String { sourcePath }
}

enum CodexDecisionComparisonKind: String, Codable, Sendable {
  case added
  case removed
  case changed
  case unchanged
}

struct CodexDecisionComparisonRow: Codable, Hashable, Identifiable, Sendable {
  let sourcePath: String
  let kind: CodexDecisionComparisonKind
  let previousGroupKey: String?
  let currentGroupKey: String?
  let previousClassification: CodexDecisionClass?
  let currentClassification: CodexDecisionClass?
  let previousFingerprint: String?
  let currentFingerprint: String?

  var id: String { sourcePath }

  var explanation: String {
    switch kind {
    case .added:
      return "New source in the selected session."
    case .removed:
      return "Source was present in the comparison session but is absent from the selected session."
    case .unchanged:
      return "Decision, identity group, and indexed fingerprint are unchanged."
    case .changed:
      var changes: [String] = []
      if previousGroupKey != currentGroupKey { changes.append("identity group changed") }
      if previousClassification != currentClassification {
        changes.append("classification changed from \(previousClassification?.label ?? "none") to \(currentClassification?.label ?? "none")")
      }
      if previousFingerprint != currentFingerprint { changes.append("indexed evidence fingerprint changed") }
      return changes.isEmpty ? "Decision evidence changed without a classified transition." : changes.joined(separator: "; ") + "."
    }
  }
}

struct CodexComparisonEvidenceBundle: Codable, Hashable, Sendable {
  let exportedAt: Date
  let currentSessionID: String
  let baselineSessionID: String?
  let currentRuleVersion: String?
  let baselineRuleVersion: String?
  let rows: [CodexDecisionComparisonRow]
  let selectedScanProfile: CodexEvidenceScanProfile?
  let profileAssessment: CodexEvidenceProfileAssessment?
}

enum CodexEvidenceCompatibilityState: String, Codable, CaseIterable, Identifiable, Sendable {
  case complete
  case partial
  case legacy

  var id: String { rawValue }

  var label: String {
    switch self {
    case .complete: return "profile metadata complete"
    case .partial: return "profile metadata partial"
    case .legacy: return "legacy profile metadata"
    }
  }

  var explanation: String {
    switch self {
    case .complete: return "Scan profile and profile assessment are both present."
    case .partial: return "Only one profile metadata field is present; review before relying on the assessment."
    case .legacy: return "Export predates profile metadata and should be treated as unknown context."
    }
  }
}

struct CodexImportedEvidenceRecord: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let sourceName: String
  let importedAt: Date
  let bundle: CodexComparisonEvidenceBundle

  var profileLabel: String {
    bundle.selectedScanProfile?.rawValue ?? "unknown"
  }

  var profileAuditLabel: String {
    guard let assessment = bundle.profileAssessment else { return "assessment unavailable" }
    return assessment.strongerProfileRecommended ? "Full Verification recommended" : "profile matched route"
  }

  var compatibilityState: CodexEvidenceCompatibilityState {
    switch (bundle.selectedScanProfile != nil, bundle.profileAssessment != nil) {
    case (true, true): return .complete
    case (false, false): return .legacy
    default: return .partial
    }
  }
}

enum CodexEvidenceHistoryFilter: String, Codable, CaseIterable, Identifiable, Sendable {
  case all
  case verificationRecommended
  case profileMatched
  case legacyUnknown

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all: return "All retained evidence"
    case .verificationRecommended: return "Full Verification recommended"
    case .profileMatched: return "Profile matched route"
    case .legacyUnknown: return "Legacy or unknown profile"
    }
  }

  func includes(_ record: CodexImportedEvidenceRecord) -> Bool {
    switch self {
    case .all: return true
    case .verificationRecommended: return record.profileAuditLabel == "Full Verification recommended"
    case .profileMatched: return record.profileAuditLabel == "profile matched route"
    case .legacyUnknown: return record.profileLabel == "unknown" || record.profileAuditLabel == "assessment unavailable"
    }
  }
}

struct CodexEvidenceAuthorityComparison: Codable, Hashable, Sendable {
  let liveSessionID: String
  let importedCurrentSessionID: String
  let liveRowCount: Int
  let importedRowCount: Int
  let overlappingSourceCount: Int
  let liveOnlySourceCount: Int
  let importedOnlySourceCount: Int

  var sameCurrentSession: Bool { liveSessionID == importedCurrentSessionID }
}

enum CodexEvidenceProvenance: String, Codable, CaseIterable, Sendable {
  case overlapping
  case liveOnly
  case importedOnly

  var label: String {
    switch self {
    case .overlapping: return "Overlapping"
    case .liveOnly: return "Live only"
    case .importedOnly: return "Imported only"
    }
  }
}

enum CodexEvidenceActionability: String, Codable, CaseIterable, Sendable {
  case liveReviewRequired
  case liveComparison
  case importedContextOnly

  var label: String {
    switch self {
    case .liveReviewRequired: return "Live review required"
    case .liveComparison: return "Compare with live catalog"
    case .importedContextOnly: return "Imported context only"
    }
  }
}

enum CodexEvidenceScanRoute: String, Codable, CaseIterable, Sendable {
  case metadataTriage
  case targetedVerification
  case noDeepScan

  var label: String {
    switch self {
    case .metadataTriage: return "Metadata triage"
    case .targetedVerification: return "Targeted verification"
    case .noDeepScan: return "No deep scan"
    }
  }
}

enum CodexEvidenceProvenanceFilter: String, Codable, CaseIterable, Identifiable, Sendable {
  case all
  case overlapping
  case liveOnly
  case importedOnly

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all: return "All provenance"
    case .overlapping: return "Overlapping sources"
    case .liveOnly: return "Live-only sources"
    case .importedOnly: return "Imported-only sources"
    }
  }

  func includes(_ provenance: CodexEvidenceProvenance) -> Bool {
    switch self {
    case .all: return true
    case .overlapping: return provenance == .overlapping
    case .liveOnly: return provenance == .liveOnly
    case .importedOnly: return provenance == .importedOnly
    }
  }
}

struct CodexEvidenceProvenanceRow: Codable, Hashable, Identifiable, Sendable {
  let sourcePath: String
  let provenance: CodexEvidenceProvenance
  let liveKind: CodexDecisionComparisonKind?
  let importedKind: CodexDecisionComparisonKind?

  var id: String { sourcePath }

  var actionability: CodexEvidenceActionability {
    switch provenance {
    case .liveOnly: return .liveReviewRequired
    case .overlapping: return .liveComparison
    case .importedOnly: return .importedContextOnly
    }
  }

  var scanRoute: CodexEvidenceScanRoute {
    switch provenance {
    case .importedOnly:
      return .noDeepScan
    case .liveOnly:
      return .targetedVerification
    case .overlapping:
      let hasChange = liveKind == .added || liveKind == .changed || importedKind == .added || importedKind == .changed
      return hasChange ? .targetedVerification : .metadataTriage
    }
  }
}

struct CodexEvidenceScanRouteSummary: Codable, Hashable, Sendable {
  let totalCount: Int
  let metadataTriageCount: Int
  let targetedVerificationCount: Int
  let noDeepScanCount: Int

  var deepScanAvoidedCount: Int { metadataTriageCount + noDeepScanCount }

  var headline: String {
    "(totalCount) source(s) · (metadataTriageCount) metadata triage · (targetedVerificationCount) targeted · (noDeepScanCount) deep scan avoided"
  }
}

struct CodexSmartScanPlan: Codable, Hashable, Sendable {
  let totalCount: Int
  let metadataTriageCount: Int
  let targetedVerificationCount: Int
  let noDeepScanCount: Int
  let reviewRequiredCount: Int

  var deepScanAvoidedCount: Int { metadataTriageCount + noDeepScanCount }

  var headline: String {
    "(totalCount) indexed source(s) · (metadataTriageCount) metadata triage · (targetedVerificationCount) targeted verification · (noDeepScanCount) deep scan avoided"
  }

  func profileGuidance(_ profile: CodexEvidenceScanProfile) -> String {
    if targetedVerificationCount == 0 {
      return "The current indexed evidence has no targeted verification route. (profile.rawValue) can remain bounded to the selected operation."
    }
    if profile == .verified {
      return "Full Verification matches the (targetedVerificationCount) targeted route(s) identified by Smart Logic."
    }
    return "Smart Logic identified (targetedVerificationCount) targeted route(s); Full Verification remains recommended before a cleanup-capable operation."
  }
}

enum CodexRouteReceiptState: String, Codable, CaseIterable, Sendable {
  case planned
  case skipped
  case completed
  case interrupted
  case failed
}

struct CodexScanRouteReceipt: Codable, Hashable, Identifiable, Sendable {
  let sessionID: String
  let sourcePath: String
  let route: CodexEvidenceScanRoute
  let state: CodexRouteReceiptState
  let attemptCount: Int
  let updatedAt: Date
  let detail: String

  var id: String { sessionID + "|" + sourcePath }
}

struct CodexRouteReceiptSummary: Codable, Hashable, Sendable {
  let totalCount: Int
  let plannedCount: Int
  let skippedCount: Int
  let completedCount: Int
  let interruptedCount: Int
  let failedCount: Int

  var pendingCount: Int { plannedCount + interruptedCount + failedCount }

  var headline: String {
    "(completedCount) completed · (pendingCount) pending · (skippedCount) skipped"
  }
}

struct CodexRouteReceiptExportBundle: Codable, Hashable, Sendable {
  let exportedAt: Date
  let sessionID: String
  let summary: CodexRouteReceiptSummary
  let receipts: [CodexScanRouteReceipt]
}

extension CodexSmartLogicEngine {
  static func pendingRouteReceipts(_ receipts: [CodexScanRouteReceipt]) -> [CodexScanRouteReceipt] {
    receipts
      .filter { receipt in
        receipt.state == .planned || receipt.state == .interrupted || receipt.state == .failed
      }
      .sorted { lhs, rhs in
        if lhs.state != rhs.state {
          let order: [CodexRouteReceiptState: Int] = [.failed: 0, .interrupted: 1, .planned: 2, .skipped: 3, .completed: 4]
          return (order[lhs.state] ?? 9) < (order[rhs.state] ?? 9)
        }
        return lhs.sourcePath.localizedStandardCompare(rhs.sourcePath) == .orderedAscending
      }
  }
}

enum CodexEvidenceScanProfile: String, Codable, CaseIterable, Sendable {
  case fastIndex
  case verified
  case yolo
}

struct CodexEvidenceProfileAssessment: Codable, Hashable, Sendable {
  let profile: CodexEvidenceScanProfile
  let targetedRouteCount: Int
  let strongerProfileRecommended: Bool

  var headline: String {
    if strongerProfileRecommended {
      return "Full Verification recommended for (targetedRouteCount) targeted route(s)."
    }
    switch profile {
    case .fastIndex:
      return "Fast Index is sufficient for the current route summary."
    case .verified:
      return "Full Verification matches the current route summary."
    case .yolo:
      return "YOLO remains limited to the existing non-destructive safety boundary."
    }
  }
}

struct CodexSessionCheckpoint: Codable, Hashable, Sendable {
  let sessionID: String
  let sourcePath: String
  let stage: String
  let state: String
  let updatedAt: Date
  let detail: String
}

struct CodexScanIndexRecord: Codable, Hashable, Sendable {
  let sourcePath: String
  let destinationPath: String?
  let sourceIndexPath: String
  let destinationIndexPath: String?
  let optionsKey: String
  let sourceIndexDigest: String
  let destinationIndexDigest: String?
  let sourceFileCount: Int
  let sourceByteCount: Int64
  let capturedAt: Date
}

enum CodexBackupMedium: String, Codable, CaseIterable, Identifiable, Sendable {
  case rawDirectory
  case apfsClone
  case sparseImage
  case verifiedZip

  var id: String { rawValue }

  var label: String {
    switch self {
    case .rawDirectory: return "Raw directory snapshot"
    case .apfsClone: return "APFS clone"
    case .sparseImage: return "Sparse disk image"
    case .verifiedZip: return "Verified ZIP"
    }
  }

  var subtitle: String {
    switch self {
    case .rawDirectory: return "Canonical preservation without repackaging."
    case .apfsClone: return "Fast same-volume preservation when APFS supports it."
    case .sparseImage: return "Mac image container for a stable local volume snapshot."
    case .verifiedZip: return "Optional portable interchange artifact."
    }
  }
}

struct CodexBackupManifest: Codable, Hashable, Sendable {
  let sourcePath: String
  let destinationPath: String
  let medium: CodexBackupMedium
  let fileCount: Int
  let byteCount: Int64
  let createdAt: Date
  let verified: Bool
  let notes: [String]
}

enum CodexAdvisoryProviderKind: String, Codable, CaseIterable, Sendable {
  case lmStudio
  case ollama
}

struct CodexAdvisoryInput: Codable, Hashable, Sendable {
  let ruleVersion: String
  let decisions: [CodexSmartDecision]
  let redactionPolicy: String
}

struct CodexAIAdvisory: Codable, Hashable, Sendable {
  let provider: CodexAdvisoryProviderKind
  let model: String
  let summary: String
  let suggestedReviewIDs: [String]
  let generatedAt: Date
  let isAuthoritative: Bool
}

protocol CodexAdvisoryProvider: Sendable {
  var kind: CodexAdvisoryProviderKind { get }
  func advise(_ input: CodexAdvisoryInput) async throws -> CodexAIAdvisory
}

struct DeterministicOnlyCodexAdvisoryProvider: CodexAdvisoryProvider {
  let kind: CodexAdvisoryProviderKind = .lmStudio

  func advise(_ input: CodexAdvisoryInput) async throws -> CodexAIAdvisory {
    let reviewIDs = input.decisions.filter { $0.classification.isReview }.map(\.id)
    return CodexAIAdvisory(
      provider: kind,
      model: "deterministic-fallback",
      summary: "No local model response was used. Deterministic Smart Logic remains authoritative.",
      suggestedReviewIDs: reviewIDs,
      generatedAt: Date(),
      isAuthoritative: false
    )
  }
}

struct LocalCodexAdvisoryProvider: CodexAdvisoryProvider {
  let kind: CodexAdvisoryProviderKind
  let model: String

  private var endpoint: URL {
    switch kind {
    case .lmStudio:
      return URL(string: "http://127.0.0.1:1234/v1/chat/completions")!
    case .ollama:
      return URL(string: "http://127.0.0.1:11434/api/chat")!
    }
  }

  func advise(_ input: CodexAdvisoryInput) async throws -> CodexAIAdvisory {
    let redactedDecisions = input.decisions.map { decision in
      [
        "id": decision.id,
        "group": decision.groupKey,
        "classification": decision.classification.rawValue,
        "confidence": String(format: "%.2f", decision.confidence),
        "lead_rank": String(decision.leadRank),
        "name": decision.evidence.name,
        "has_git": decision.evidence.hasGit ? "true" : "false",
        "local_changes": decision.evidence.hasLocalChanges ? "true" : "false",
        "main_state": decision.evidence.mainLabel,
        "ide_state": decision.evidence.ideState,
        "tool_context": decision.evidence.toolEvidence.map(\.rawValue).joined(separator: ", "),
        "active_host_tools": decision.evidence.activeToolEvidence.map(\.rawValue).joined(separator: ", "),
        "snapshot": decision.evidence.snapshot.summary,
        "reasons": decision.reasons.joined(separator: " ")
      ]
    }
    let factsData = try JSONSerialization.data(withJSONObject: redactedDecisions, options: [.sortedKeys])
    let facts = String(data: factsData, encoding: .utf8) ?? "[]"
    let instruction = "You are a local review assistant for CSA-iLEM. Deterministic classifications are authoritative. Return JSON only with keys summary (string) and suggested_review_ids (array of decision ids). Suggest review order only; never choose a canonical source, authorize writes, or recommend deletion. Evidence is redacted indexed metadata, not source content. Rule version: \(input.ruleVersion). Evidence: \(facts)"

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any]
    switch kind {
    case .lmStudio:
      body = [
        "model": model,
        "temperature": 0,
        "messages": [["role": "user", "content": instruction]]
      ]
    case .ollama:
      body = [
        "model": model,
        "stream": false,
        "format": "json",
        "options": ["temperature": 0],
        "messages": [["role": "user", "content": instruction]]
      ]
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw NSError(domain: "CSAiEM.LocalAdvisory", code: status, userInfo: [NSLocalizedDescriptionKey: "Local model endpoint returned HTTP \(status)."])
    }
    let responseObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    let content: String
    if kind == .lmStudio,
       let choices = responseObject["choices"] as? [[String: Any]],
       let message = choices.first?["message"] as? [String: Any],
       let value = message["content"] as? String {
      content = value
    } else if let message = responseObject["message"] as? [String: Any],
              let value = message["content"] as? String {
      content = value
    } else {
      throw NSError(domain: "CSAiEM.LocalAdvisory", code: 2, userInfo: [NSLocalizedDescriptionKey: "Local model response did not contain message content."])
    }

    let parsed = Self.parseAdvisoryJSON(content)
    let validIDs = Set(input.decisions.map(\.id))
    let suggestions = parsed.ids.filter { validIDs.contains($0) }
    return CodexAIAdvisory(
      provider: kind,
      model: model,
      summary: parsed.summary,
      suggestedReviewIDs: suggestions,
      generatedAt: Date(),
      isAuthoritative: false
    )
  }

  static func parseAdvisoryJSON(_ content: String) -> (summary: String, ids: [String]) {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    let candidate = trimmed.hasPrefix("```")
      ? trimmed.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
      : trimmed
    guard let data = candidate.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return (trimmed, [])
    }
    let summary = object["summary"] as? String ?? "Local model returned no summary."
    let ids = object["suggested_review_ids"] as? [String] ?? []
    return (summary, ids)
  }
}

enum CodexSmartLogicEngine {
  static let ruleVersion = "smart-logic-v2.7"

  static func sourceFingerprint(_ project: CodexProjectEntry) -> String {
    let latestModification = project.snapshot.latestModification.map { ISO8601DateFormatter().string(from: $0) } ?? ""
    let gitState = project.gitStatus.hasLocalChanges ? "dirty" : "clean"
    let synchronizationState = project.gitStatus.isMainSynchronized ? "main-synchronized" : "main-unsynchronized"
    let repositoryState = project.hasGit ? "git" : "no-git"
    let manifestState = project.hasPackageManifest ? "manifest" : "no-manifest"
    let snapshotState = project.snapshot.truncated ? "bounded" : "complete"
    let toolMarkers = project.toolEvidence.map { $0.rawValue }.sorted().joined(separator: ",")
    let activeToolMarkers = project.activeToolEvidence.map { $0.rawValue }.sorted().joined(separator: ",")
    var values: [String] = []
    values.append(project.path)
    values.append(project.name)
    values.append(project.discoveredBy)
    values.append(project.remoteURL ?? "")
    values.append(project.branch ?? "")
    values.append(project.ideState.rawValue)
    values.append(project.gitStatus.mainLabel)
    values.append(gitState)
    values.append(synchronizationState)
    values.append(repositoryState)
    values.append(manifestState)
    values.append(project.snapshot.fileCount.description)
    values.append(project.snapshot.byteCount.description)
    values.append(latestModification)
    values.append(snapshotState)
    values.append(toolMarkers)
    values.append(activeToolMarkers)
    let bytes = Array(values.joined(separator: "\u{1F}").utf8)
    var hash: UInt64 = 1469598103934665603
    for byte in bytes {
      hash ^= UInt64(byte)
      hash = hash &* 1099511628211
    }
    return String(format: "%016llx", hash)
  }

  static func sourceDeltas(previous: [String: String], current: [CodexProjectEntry]) -> [CodexSourceDelta] {
    let currentFingerprints = Dictionary(uniqueKeysWithValues: current.map { ($0.path, sourceFingerprint($0)) })
    let paths = Set(previous.keys).union(currentFingerprints.keys).sorted()
    return paths.map { path in
      let old = previous[path]
      let now = currentFingerprints[path]
      let kind: CodexSourceDelta.Kind
      switch (old, now) {
      case (nil, .some): kind = .added
      case (.some, nil): kind = .removed
      case let (.some(oldValue), .some(newValue)) where oldValue == newValue: kind = .unchanged
      case (.some, .some): kind = .changed
      case (nil, nil): kind = .unchanged
      }
      return CodexSourceDelta(sourcePath: path, kind: kind, previousFingerprint: old, currentFingerprint: now)
    }
  }

  static func evaluate(_ projects: [CodexProjectEntry], destinationRoot: String? = nil) -> [CodexSmartDecision] {
    let grouped = Dictionary(grouping: projects) { project in
      if let remote = normalizedRemote(project.remoteURL), !remote.isEmpty {
        return "remote:\(remote)"
      }
      return "name:\(project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    let leadRanks = grouped.reduce(into: [String: Int]()) { ranks, group in
      let ordered = group.value.sorted { lhs, rhs in
        let lhsScore = leadScore(lhs)
        let rhsScore = leadScore(rhs)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
      }
      for (index, project) in ordered.enumerated() {
        ranks[project.path] = index + 1
      }
    }

    return projects.map { project in
      let remote = normalizedRemote(project.remoteURL)
      let hasVerifiedRemote = project.hasGit && remote?.isEmpty == false
      let sameGroupCount = grouped[groupKey(for: project)]?.count ?? 1
      let leadRank = leadRanks[project.path] ?? 1
      let isRecommendedLead = sameGroupCount > 1 && leadRank == 1 && project.hasGit && hasVerifiedRemote
      var reasons: [String] = []
      let classification: CodexDecisionClass
      let confidence: Double

      if !project.hasGit {
        classification = .brokenMetadataReview
        confidence = 0.15
        reasons.append("No Git worktree was detected.")
      } else if !hasVerifiedRemote {
        classification = .sameNameReview
        confidence = 0.25
        reasons.append("No verified GitHub remote identity is available.")
      } else if sameGroupCount > 1 &&
                project.ideState == .unlinked &&
                !project.gitStatus.hasLocalChanges &&
                project.gitStatus.isMainSynchronized &&
                project.branch == "main" {
        classification = .shadowCopy
        confidence = 0.55
        reasons.append("This synchronized copy is not linked to the active local project registry.")
        reasons.append("Treat it as a shadow-copy review candidate until the operator confirms its role.")
      } else if sameGroupCount > 1 {
        classification = .mergeCandidate
        confidence = project.gitStatus.hasLocalChanges || !project.gitStatus.isMainSynchronized || project.branch != "main" ? 0.86 : 0.92
        reasons.append("Multiple source folders share the same verified remote identity.")
        if isRecommendedLead {
          reasons.append("Deterministic lead recommendation: this source has the strongest synchronized, clean, and linked evidence in the identity group.")
        } else {
          reasons.append("Lead rank \(leadRank) in the identity group; preserve this source as a review candidate until the operator confirms the canonical source.")
        }
        if project.gitStatus.hasLocalChanges {
          reasons.append("This source has uncommitted local changes that must be preserved before reconciliation.")
        }
        if !project.gitStatus.isMainSynchronized {
          reasons.append("This source is not synchronized with the stored origin/main reference.")
        }
        if let branch = project.branch, branch != "main" {
          reasons.append("This source is on branch \(branch), not main; keep it isolated until branch intent is confirmed.")
        }
        if project.ideState == .unlinked {
          reasons.append("The folder is not linked to the active local project registry; treat it as an external source.")
        }
      } else if project.branch != nil && project.branch != "main" {
        classification = .mergeCandidate
        confidence = 0.76
        reasons.append("The source is on branch \(project.branch ?? "unknown"), not main; keep it isolated until branch intent is confirmed.")
        if project.ideState == .unlinked {
          reasons.append("The folder is not linked to the active local project registry; treat it as an external source.")
        }
      } else if project.ideState == .unlinked {
        classification = .shadowCopy
        confidence = 0.45
        reasons.append("The folder is not linked to the active local project registry.")
      } else if project.gitStatus.hasLocalChanges || !project.gitStatus.isMainSynchronized {
        classification = .mergeCandidate
        confidence = 0.72
        reasons.append("The source has local changes or is not synchronized with the stored origin/main reference.")
      } else {
        classification = .canonical
        confidence = 0.98
        reasons.append("Verified Git identity, linked project state, and synchronized main reference agree.")
      }

      if project.ideState == .unavailable {
        reasons.append("Editor/project-registry evidence was unavailable; it is not used as an identity proof.")
      }
      if !project.toolEvidence.isEmpty {
        let tools = project.toolEvidence.map(\.rawValue).joined(separator: ", ")
        reasons.append("Read-only tool evidence: \(tools). Tool markers describe possible editor or harness context; they do not establish repository identity or write authority.")
      }
      if !project.activeToolEvidence.isEmpty {
        let tools = project.activeToolEvidence.map(\.rawValue).joined(separator: ", ")
        reasons.append("Read-only host activity evidence: \(tools) appears to be running on this Mac; this does not prove the process opened this project or grant write authority.")
      }
      if project.snapshot.truncated {
        reasons.append("The source snapshot is bounded at (project.snapshot.fileCount) files; deep content verification remains separate.")
      }

      return CodexSmartDecision(
        id: stableID(for: project.path),
        sourcePath: project.path,
        groupKey: groupKey(for: project),
        classification: classification,
        confidence: confidence,
        leadRank: leadRank,
        isRecommendedLead: isRecommendedLead,
        evidence: CodexSourceEvidence(
          path: project.path,
          name: project.name,
          remoteURL: project.remoteURL,
          branch: project.branch,
          hasGit: project.hasGit,
          hasLocalChanges: project.gitStatus.hasLocalChanges,
          mainLabel: project.gitStatus.mainLabel,
          ideState: project.ideState.rawValue,
          toolEvidence: project.toolEvidence,
          activeToolEvidence: project.activeToolEvidence,
          snapshot: project.snapshot,
          markers: project.badges,
          owner: owner(from: remote),
          observedAt: Date()
        ),
        reasons: reasons,
        recommendedDestination: destinationRoot.map { root in
          (root as NSString).appendingPathComponent(project.name)
        },
        ruleVersion: ruleVersion,
        createdAt: Date()
      )
    }
  }

  static func groupSummaries(_ decisions: [CodexSmartDecision]) -> [CodexSmartGroupSummary] {
    Dictionary(grouping: decisions, by: \.groupKey).map { groupKey, groupDecisions in
      let ordered = groupDecisions.sorted {
        if $0.leadRank != $1.leadRank { return $0.leadRank < $1.leadRank }
        return $0.sourcePath.localizedStandardCompare($1.sourcePath) == .orderedAscending
      }
      let lead = ordered.first(where: { $0.isRecommendedLead }) ?? ordered.first(where: { $0.classification == .canonical }) ?? ordered.first
      let snapshotDates = groupDecisions.compactMap { $0.evidence.snapshot.latestModification }
      return CodexSmartGroupSummary(
        groupKey: groupKey,
        sourceCount: groupDecisions.count,
        reviewCount: groupDecisions.filter { $0.classification.isReview }.count,
        fatalCount: groupDecisions.filter { $0.classification == .fatalIdentityConflict }.count,
        snapshotCoverageCount: groupDecisions.filter { $0.evidence.snapshot.fileCount > 0 || $0.evidence.snapshot.byteCount > 0 }.count,
        latestSnapshotAt: snapshotDates.max(),
        recommendedLeadPath: lead?.sourcePath,
        recommendedLeadName: lead?.evidence.name
      )
    }
    .sorted { $0.groupKey.localizedCaseInsensitiveCompare($1.groupKey) == .orderedAscending }
  }

  static func activeDecisions(_ decisions: [CodexSmartDecision], dispositions: [String: CodexReviewDisposition]) -> [CodexSmartDecision] {
    decisions.filter { dispositions[$0.sourcePath] != .excluded }
  }

  static func compareSnapshots(
    current: [CodexDecisionSnapshot],
    baseline: [CodexDecisionSnapshot],
    currentFingerprints: [String: String],
    baselineFingerprints: [String: String]
  ) -> [CodexDecisionComparisonRow] {
    let currentByPath = Dictionary(uniqueKeysWithValues: current.map { ($0.sourcePath, $0) })
    let baselineByPath = Dictionary(uniqueKeysWithValues: baseline.map { ($0.sourcePath, $0) })
    let paths = Set(currentByPath.keys).union(baselineByPath.keys).union(currentFingerprints.keys).union(baselineFingerprints.keys).sorted()
    return paths.map { path in
      let previous = baselineByPath[path]
      let now = currentByPath[path]
      let previousFingerprint = baselineFingerprints[path]
      let currentFingerprint = currentFingerprints[path]
      let kind: CodexDecisionComparisonKind
      switch (previous, now) {
      case (nil, .some): kind = .added
      case (.some, nil): kind = .removed
      case let (.some(old), .some(new)) where old.groupKey == new.groupKey && old.classification == new.classification && old.confidence == new.confidence && previousFingerprint == currentFingerprint:
        kind = .unchanged
      case (.some, .some): kind = .changed
      case (nil, nil): kind = .changed
      }
      return CodexDecisionComparisonRow(
        sourcePath: path,
        kind: kind,
        previousGroupKey: previous?.groupKey,
        currentGroupKey: now?.groupKey,
        previousClassification: previous?.classification,
        currentClassification: now?.classification,
        previousFingerprint: previousFingerprint,
        currentFingerprint: currentFingerprint
      )
    }
  }

  static func comparisonCSV(_ rows: [CodexDecisionComparisonRow]) -> String {
    var output = "source_path,kind,previous_group,current_group,previous_classification,current_classification,previous_fingerprint,current_fingerprint,explanation\n"
    for row in rows {
      let values = [
        row.sourcePath,
        row.kind.rawValue,
        row.previousGroupKey ?? "",
        row.currentGroupKey ?? "",
        row.previousClassification?.rawValue ?? "",
        row.currentClassification?.rawValue ?? "",
        row.previousFingerprint ?? "",
        row.currentFingerprint ?? "",
        row.explanation
      ].map(csvEscape).joined(separator: ",")
      output += values + "\n"
    }
    return output
  }

  static func authorityComparison(
    liveSessionID: String,
    liveRows: [CodexDecisionComparisonRow],
    importedBundle: CodexComparisonEvidenceBundle
  ) -> CodexEvidenceAuthorityComparison {
    let liveSources = Set(liveRows.map(\.sourcePath))
    let importedSources = Set(importedBundle.rows.map(\.sourcePath))
    return CodexEvidenceAuthorityComparison(
      liveSessionID: liveSessionID,
      importedCurrentSessionID: importedBundle.currentSessionID,
      liveRowCount: liveRows.count,
      importedRowCount: importedBundle.rows.count,
      overlappingSourceCount: liveSources.intersection(importedSources).count,
      liveOnlySourceCount: liveSources.subtracting(importedSources).count,
      importedOnlySourceCount: importedSources.subtracting(liveSources).count
    )
  }

  static func provenanceRows(
    liveRows: [CodexDecisionComparisonRow],
    importedBundle: CodexComparisonEvidenceBundle,
    filter: CodexEvidenceProvenanceFilter = .all
  ) -> [CodexEvidenceProvenanceRow] {
    let liveByPath = Dictionary(uniqueKeysWithValues: liveRows.map { ($0.sourcePath, $0) })
    let importedByPath = Dictionary(uniqueKeysWithValues: importedBundle.rows.map { ($0.sourcePath, $0) })
    let paths = Set(liveByPath.keys).union(importedByPath.keys).sorted()
    return paths.compactMap { path in
      let live = liveByPath[path]
      let imported = importedByPath[path]
      let provenance: CodexEvidenceProvenance
      switch (live, imported) {
      case (.some, .some): provenance = .overlapping
      case (.some, nil): provenance = .liveOnly
      case (nil, .some): provenance = .importedOnly
      case (nil, nil): return nil
      }
      guard filter.includes(provenance) else { return nil }
      return CodexEvidenceProvenanceRow(
        sourcePath: path,
        provenance: provenance,
        liveKind: live?.kind,
        importedKind: imported?.kind
      )
    }
  }

  static func scanRouteSummary(_ rows: [CodexEvidenceProvenanceRow]) -> CodexEvidenceScanRouteSummary {
    CodexEvidenceScanRouteSummary(
      totalCount: rows.count,
      metadataTriageCount: rows.filter { $0.scanRoute == .metadataTriage }.count,
      targetedVerificationCount: rows.filter { $0.scanRoute == .targetedVerification }.count,
      noDeepScanCount: rows.filter { $0.scanRoute == .noDeepScan }.count
    )
  }

  static func smartScanPlan(
    decisions: [CodexSmartDecision],
    deltas: [CodexSourceDelta],
    dispositions: [String: CodexReviewDisposition]
  ) -> CodexSmartScanPlan {
    let deltaByPath = Dictionary(uniqueKeysWithValues: deltas.map { ($0.sourcePath, $0.kind) })
    var metadataTriageCount = 0
    var targetedVerificationCount = 0
    var noDeepScanCount = 0
    var reviewRequiredCount = 0

    for decision in decisions {
      switch smartScanRoute(for: decision, delta: deltaByPath[decision.sourcePath], disposition: dispositions[decision.sourcePath]) {
      case .noDeepScan:
        noDeepScanCount += 1
      case .targetedVerification:
        targetedVerificationCount += 1
        if decision.classification.isReview { reviewRequiredCount += 1 }
      case .metadataTriage:
        metadataTriageCount += 1
      }
    }

    return CodexSmartScanPlan(
      totalCount: decisions.count,
      metadataTriageCount: metadataTriageCount,
      targetedVerificationCount: targetedVerificationCount,
      noDeepScanCount: noDeepScanCount,
      reviewRequiredCount: reviewRequiredCount
    )
  }

  static func smartScanRoute(
    for decision: CodexSmartDecision,
    delta: CodexSourceDelta.Kind?,
    disposition: CodexReviewDisposition?
  ) -> CodexEvidenceScanRoute {
    if disposition == .excluded || decision.classification == .unrelated { return .noDeepScan }
    if decision.classification.isReview || delta == .added || delta == .changed { return .targetedVerification }
    return .metadataTriage
  }

  static func routeReceipts(
    sessionID: String,
    decisions: [CodexSmartDecision],
    deltas: [CodexSourceDelta],
    dispositions: [String: CodexReviewDisposition],
    updatedAt: Date = Date()
  ) -> [CodexScanRouteReceipt] {
    let deltaByPath = Dictionary(uniqueKeysWithValues: deltas.map { ($0.sourcePath, $0.kind) })
    return decisions.map { decision in
      let route = smartScanRoute(for: decision, delta: deltaByPath[decision.sourcePath], disposition: dispositions[decision.sourcePath])
      let skipped = route == .noDeepScan
      return CodexScanRouteReceipt(
        sessionID: sessionID,
        sourcePath: decision.sourcePath,
        route: route,
        state: skipped ? .skipped : .planned,
        attemptCount: 0,
        updatedAt: updatedAt,
        detail: skipped ? "Route avoided deep scan by deterministic Smart Logic." : "Route planned from indexed decision and source delta evidence."
      )
    }
  }

  static func routeReceiptSummary(_ receipts: [CodexScanRouteReceipt]) -> CodexRouteReceiptSummary {
    CodexRouteReceiptSummary(
      totalCount: receipts.count,
      plannedCount: receipts.filter { $0.state == .planned }.count,
      skippedCount: receipts.filter { $0.state == .skipped }.count,
      completedCount: receipts.filter { $0.state == .completed }.count,
      interruptedCount: receipts.filter { $0.state == .interrupted }.count,
      failedCount: receipts.filter { $0.state == .failed }.count
    )
  }

  static func profileAssessment(
    profile: CodexEvidenceScanProfile,
    routeSummary: CodexEvidenceScanRouteSummary
  ) -> CodexEvidenceProfileAssessment {
    CodexEvidenceProfileAssessment(
      profile: profile,
      targetedRouteCount: routeSummary.targetedVerificationCount,
      strongerProfileRecommended: routeSummary.targetedVerificationCount > 0 && profile != .verified
    )
  }

  static func csvEscape(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ") + "\""
  }

  private static func leadScore(_ project: CodexProjectEntry) -> Int {
    var score = 0
    if project.hasGit { score += 100 }
    if normalizedRemote(project.remoteURL)?.isEmpty == false { score += 50 }
    if project.gitStatus.isMainSynchronized { score += 40 }
    if !project.gitStatus.hasLocalChanges { score += 30 }
    if project.branch == "main" { score += 20 }
    switch project.ideState {
    case .active: score += 15
    case .linked: score += 10
    case .unlinked: break
    case .unavailable: score -= 5
    }
    if project.hasPackageManifest { score += 3 }
    return score
  }

  private static func groupKey(for project: CodexProjectEntry) -> String {
    if let remote = normalizedRemote(project.remoteURL), !remote.isEmpty {
      return "remote:\(remote)"
    }
    return "name:\(project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
  }

  private static func normalizedRemote(_ value: String?) -> String? {
    guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    if value.hasSuffix(".git") { value.removeLast(4) }
    if value.hasPrefix("git@"), let separator = value.firstIndex(of: ":") {
      value = "https://" + value[..<separator].replacingOccurrences(of: "git@", with: "") + "/" + value[value.index(after: separator)...]
    }
    return value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  private static func owner(from remote: String?) -> String? {
    guard let remote else { return nil }
    let components = remote.split(separator: "/")
    return components.dropLast().last.map(String.init)
  }

  private static func stableID(for path: String) -> String {
    let bytes = Array(path.utf8)
    var hash: UInt64 = 1469598103934665603
    for byte in bytes {
      hash ^= UInt64(byte)
      hash = hash &* 1099511628211
    }
    return String(format: "%016llx", hash)
  }
}

final class CodexCatalogStore: @unchecked Sendable {
  let rootPath: String
  let catalogDirectory: String
  let databasePath: String
  let exportDirectory: String

  init(rootPath: String) {
    self.rootPath = rootPath
    catalogDirectory = (rootPath as NSString).appendingPathComponent(".SYSTEMX/Index")
    databasePath = (catalogDirectory as NSString).appendingPathComponent("catalog.sqlite")
    exportDirectory = (catalogDirectory as NSString).appendingPathComponent("Exports")
  }

  var status: String {
    FileManager.default.fileExists(atPath: databasePath) ? "SQLite catalog ready" : "SQLite catalog will be created on first scan"
  }

  static func artifactDigest(at path: String) -> String? {
    guard let data = FileManager.default.contents(atPath: path) else { return nil }
    var hash: UInt64 = 1469598103934665603
    for byte in data {
      hash ^= UInt64(byte)
      hash = hash &* 1099511628211
    }
    return String(format: "%016llx", hash)
  }

  @discardableResult
  func save(
    session: CodexScanSession,
    decisions: [CodexSmartDecision],
    checkpoints: [CodexSessionCheckpoint] = [],
    routeReceipts: [CodexScanRouteReceipt] = [],
    deltas: [CodexSourceDelta] = [],
    timing: CodexScanTimingEvidence? = nil
  ) throws -> String {
    let fm = FileManager.default
    try fm.createDirectory(atPath: catalogDirectory, withIntermediateDirectories: true, attributes: nil)
    try fm.createDirectory(atPath: exportDirectory, withIntermediateDirectories: true, attributes: nil)
    try runSQL(schemaSQL)

    var statements = ["BEGIN IMMEDIATE TRANSACTION;"]
    statements.append("INSERT OR REPLACE INTO scan_sessions (id, profile, source_roots, created_at, rule_version, decision_count) VALUES (\(quote(session.id)), \(quote(session.profile)), \(quote(session.sourceRoots.joined(separator: "\n"))), \(quote(iso(session.createdAt))), \(quote(session.ruleVersion)), \(session.decisionCount));")
    for decision in decisions {
      let evidenceJSON = try encode(decision.evidence)
      let reasonsJSON = try encode(decision.reasons)
      statements.append("INSERT OR REPLACE INTO decisions (id, session_id, source_path, group_key, classification, confidence, evidence_json, reasons_json, destination_path, rule_version, created_at) VALUES (\(quote(decision.id)), \(quote(session.id)), \(quote(decision.sourcePath)), \(quote(decision.groupKey)), \(quote(decision.classification.rawValue)), \(decision.confidence), \(quote(evidenceJSON)), \(quote(reasonsJSON)), \(quote(decision.recommendedDestination ?? "")), \(quote(decision.ruleVersion)), \(quote(iso(decision.createdAt))));")
    }
    for checkpoint in checkpoints {
      statements.append("INSERT OR REPLACE INTO session_checkpoints (session_id, source_path, stage, state, updated_at, detail) VALUES (\(quote(checkpoint.sessionID)), \(quote(checkpoint.sourcePath)), \(quote(checkpoint.stage)), \(quote(checkpoint.state)), \(quote(iso(checkpoint.updatedAt))), \(quote(checkpoint.detail))); ")
    }
    for receipt in routeReceipts {
      statements.append("INSERT OR REPLACE INTO scan_route_receipts (session_id, source_path, route, state, attempt_count, updated_at, detail) VALUES (\(quote(receipt.sessionID)), \(quote(receipt.sourcePath)), \(quote(receipt.route.rawValue)), \(quote(receipt.state.rawValue)), \(receipt.attemptCount), \(quote(iso(receipt.updatedAt))), \(quote(receipt.detail))); ")
    }
    for delta in deltas {
      statements.append("INSERT OR REPLACE INTO session_source_deltas (session_id, source_path, kind, previous_fingerprint, current_fingerprint) VALUES (\(quote(session.id)), \(quote(delta.sourcePath)), \(quote(delta.kind.rawValue)), \(quote(delta.previousFingerprint ?? "")), \(quote(delta.currentFingerprint ?? ""))); ")
    }
    if let timing {
      statements.append("INSERT OR REPLACE INTO session_timing (session_id, discovery_ms, decision_ms, total_ms, discovered_count, evaluated_count, reused_count, changed_count, affected_group_count) VALUES (\(quote(timing.sessionID)), \(timing.discoveryMilliseconds), \(timing.decisionMilliseconds), \(timing.totalMilliseconds), \(timing.discoveredSourceCount), \(timing.evaluatedSourceCount), \(timing.reusedSourceCount), \(timing.changedSourceCount), \(timing.affectedGroupCount));")
    }
    statements.append("COMMIT;")
    try runSQL(statements.joined(separator: "\n"))
    try writeExports(session: session, decisions: decisions)
    return databasePath
  }

  func saveCheckpoints(_ checkpoints: [CodexSessionCheckpoint]) throws {
    guard !checkpoints.isEmpty else { return }
    let fm = FileManager.default
    try fm.createDirectory(atPath: catalogDirectory, withIntermediateDirectories: true, attributes: nil)
    try runSQL(schemaSQL)
    var statements = ["BEGIN IMMEDIATE TRANSACTION;"]
    for checkpoint in checkpoints {
      statements.append("INSERT OR REPLACE INTO session_checkpoints (session_id, source_path, stage, state, updated_at, detail) VALUES (\(quote(checkpoint.sessionID)), \(quote(checkpoint.sourcePath)), \(quote(checkpoint.stage)), \(quote(checkpoint.state)), \(quote(iso(checkpoint.updatedAt))), \(quote(checkpoint.detail))); ")
    }
    statements.append("COMMIT;")
    try runSQL(statements.joined(separator: "\n"))
  }

  func saveRouteReceipts(_ receipts: [CodexScanRouteReceipt]) throws {
    guard !receipts.isEmpty else { return }
    try FileManager.default.createDirectory(atPath: catalogDirectory, withIntermediateDirectories: true, attributes: nil)
    try runSQL(schemaSQL)
    var statements = ["BEGIN IMMEDIATE TRANSACTION;"]
    for receipt in receipts {
      statements.append("INSERT OR REPLACE INTO scan_route_receipts (session_id, source_path, route, state, attempt_count, updated_at, detail) VALUES (\(quote(receipt.sessionID)), \(quote(receipt.sourcePath)), \(quote(receipt.route.rawValue)), \(quote(receipt.state.rawValue)), \(receipt.attemptCount), \(quote(iso(receipt.updatedAt))), \(quote(receipt.detail))); ")
    }
    statements.append("COMMIT;")
    try runSQL(statements.joined(separator: "\n"))
  }

  func routeReceipts(for sessionID: String) -> [CodexScanRouteReceipt] {
    guard FileManager.default.fileExists(atPath: databasePath) else { return [] }
    let sql = "SELECT source_path || char(9) || route || char(9) || state || char(9) || attempt_count || char(9) || updated_at || char(9) || detail FROM scan_route_receipts WHERE session_id=\(quote(sessionID)) ORDER BY source_path;"
    guard let output = runQuery(sql) else { return [] }
    let formatter = ISO8601DateFormatter()
    return output.split(whereSeparator: \.isNewline).compactMap { row in
      let fields = row.split(separator: "\t", maxSplits: 5).map(String.init)
      guard fields.count == 6,
            let route = CodexEvidenceScanRoute(rawValue: fields[1]),
            let state = CodexRouteReceiptState(rawValue: fields[2]),
            let attempts = Int(fields[3]),
            let updatedAt = formatter.date(from: fields[4]) else { return nil }
      return CodexScanRouteReceipt(sessionID: sessionID, sourcePath: fields[0], route: route, state: state, attemptCount: attempts, updatedAt: updatedAt, detail: fields[5])
    }
  }

  func saveIndexRecords(_ records: [CodexScanIndexRecord]) throws {
    guard !records.isEmpty else { return }
    let fm = FileManager.default
    try fm.createDirectory(atPath: catalogDirectory, withIntermediateDirectories: true, attributes: nil)
    try runSQL(schemaSQL)
    var statements = ["BEGIN IMMEDIATE TRANSACTION;"]
    for record in records {
      let destination = quote(record.destinationPath ?? "")
      let destinationIndex = quote(record.destinationIndexPath ?? "")
      let destinationDigest = quote(record.destinationIndexDigest ?? "")
      statements.append("INSERT OR REPLACE INTO scan_index_records (source_path, destination_path, source_index_path, destination_index_path, options_key, source_index_digest, destination_index_digest, source_file_count, source_byte_count, captured_at) VALUES (\(quote(record.sourcePath)), \(destination), \(quote(record.sourceIndexPath)), \(destinationIndex), \(quote(record.optionsKey)), \(quote(record.sourceIndexDigest)), \(destinationDigest), \(record.sourceFileCount), \(record.sourceByteCount), \(quote(iso(record.capturedAt))));")
    }
    statements.append("COMMIT;")
    try runSQL(statements.joined(separator: "\n"))
  }

  func indexRecordMatches(
    sourcePath: String,
    destinationPath: String?,
    optionsKey: String,
    sourceIndexPath: String,
    destinationIndexPath: String?
  ) -> Bool {
    guard FileManager.default.fileExists(atPath: databasePath),
          let sourceDigest = Self.artifactDigest(at: sourceIndexPath) else { return false }
    let destinationDigest = destinationIndexPath.flatMap(Self.artifactDigest(at:)) ?? ""
    let destination = quote(destinationPath ?? "")
    let destinationIndex = quote(destinationIndexPath ?? "")
    let sql = "SELECT count(*) FROM scan_index_records WHERE source_path=\(quote(sourcePath)) AND destination_path=\(destination) AND options_key=\(quote(optionsKey)) AND source_index_path=\(quote(sourceIndexPath)) AND destination_index_path=\(destinationIndex) AND source_index_digest=\(quote(sourceDigest)) AND destination_index_digest=\(quote(destinationDigest));"
    return runQuery(sql)?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
  }

  func latestCheckpointSummary() -> String? {
    guard FileManager.default.fileExists(atPath: databasePath) else { return nil }
    let sql = "SELECT stage || '|' || state || '|' || updated_at FROM session_checkpoints ORDER BY updated_at DESC LIMIT 1;"
    guard let row = runQuery(sql)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !row.isEmpty else { return nil }
    let fields = row.split(separator: "|", maxSplits: 2).map(String.init)
    guard fields.count == 3 else { return nil }
    return "\(fields[0])=\(fields[1]) at \(fields[2])"
  }

  func recentSessions(limit: Int = 5) -> [CodexCatalogSessionSummary] {
    guard FileManager.default.fileExists(atPath: databasePath) else { return [] }
    let safeLimit = max(1, min(limit, 20))
    let sql = "SELECT id || char(9) || profile || char(9) || replace(source_roots, char(10), '␤') || char(9) || created_at || char(9) || rule_version || char(9) || decision_count FROM scan_sessions ORDER BY created_at DESC LIMIT \(safeLimit);"
    guard let output = runQuery(sql) else { return [] }
    let formatter = ISO8601DateFormatter()
    return output.split(whereSeparator: \.isNewline).compactMap { row in
      let fields = row.split(separator: "\t", maxSplits: 5).map(String.init)
      guard fields.count == 6,
            let date = formatter.date(from: fields[3]),
            let decisionCount = Int(fields[5]) else { return nil }
      return CodexCatalogSessionSummary(
        id: fields[0],
        profile: fields[1],
        sourceRoots: fields[2].split(separator: "␤").map(String.init),
        createdAt: date,
        ruleVersion: fields[4],
        decisionCount: decisionCount
      )
    }
  }

  func timing(for sessionID: String) -> CodexScanTimingEvidence? {
    guard FileManager.default.fileExists(atPath: databasePath) else { return nil }
    let sql = "SELECT discovery_ms || char(9) || decision_ms || char(9) || total_ms || char(9) || discovered_count || char(9) || evaluated_count || char(9) || reused_count || char(9) || changed_count || char(9) || affected_group_count FROM session_timing WHERE session_id=\(quote(sessionID));"
    guard let row = runQuery(sql)?.split(whereSeparator: \.isNewline).first else { return nil }
    let fields = row.split(separator: "\t").compactMap { Int($0) }
    guard fields.count == 8 else { return nil }
    return CodexScanTimingEvidence(sessionID: sessionID, discoveryMilliseconds: fields[0], decisionMilliseconds: fields[1], totalMilliseconds: fields[2], discoveredSourceCount: fields[3], evaluatedSourceCount: fields[4], reusedSourceCount: fields[5], changedSourceCount: fields[6], affectedGroupCount: fields[7])
  }

  func sourceDeltas(for sessionID: String) -> [CodexSourceDelta] {
    guard FileManager.default.fileExists(atPath: databasePath) else { return [] }
    let sql = "SELECT source_path || char(9) || kind || char(9) || previous_fingerprint || char(9) || current_fingerprint FROM session_source_deltas WHERE session_id=\(quote(sessionID)) ORDER BY source_path;"
    guard let output = runQuery(sql) else { return [] }
    return output.split(whereSeparator: \.isNewline).compactMap { row in
      let fields = row.split(separator: "\t", maxSplits: 3).map(String.init)
      guard fields.count == 4, let kind = CodexSourceDelta.Kind(rawValue: fields[1]) else { return nil }
      return CodexSourceDelta(
        sourcePath: fields[0],
        kind: kind,
        previousFingerprint: fields[2].isEmpty ? nil : fields[2],
        currentFingerprint: fields[3].isEmpty ? nil : fields[3]
      )
    }
  }

  func decisionSnapshots(for sessionID: String) -> [CodexDecisionSnapshot] {
    guard FileManager.default.fileExists(atPath: databasePath) else { return [] }
    let sql = "SELECT hex(source_path) || char(9) || group_key || char(9) || classification || char(9) || confidence FROM decisions WHERE session_id=\(quote(sessionID)) ORDER BY source_path;"
    guard let output = runQuery(sql) else { return [] }
    return output.split(whereSeparator: \.isNewline).compactMap { row in
      let fields = row.split(separator: "\t", maxSplits: 3).map(String.init)
      guard fields.count == 4,
            let pathData = Self.decodeHex(fields[0]),
            let path = String(data: pathData, encoding: .utf8),
            let classification = CodexDecisionClass(rawValue: fields[2]),
            let confidence = Double(fields[3]) else { return nil }
      return CodexDecisionSnapshot(sourcePath: path, groupKey: fields[1], classification: classification, confidence: confidence)
    }
  }

  func currentFingerprints(for sessionID: String) -> [String: String] {
    guard FileManager.default.fileExists(atPath: databasePath) else { return [:] }
    let sql = "SELECT hex(source_path) || char(9) || current_fingerprint FROM session_source_deltas WHERE session_id=\(quote(sessionID));"
    guard let output = runQuery(sql) else { return [:] }
    var fingerprints: [String: String] = [:]
    for row in output.split(whereSeparator: \.isNewline) {
      let fields = row.split(separator: "\t", maxSplits: 1).map(String.init)
      guard fields.count == 2,
            let pathData = Self.decodeHex(fields[0]),
            let path = String(data: pathData, encoding: .utf8),
            !fields[1].isEmpty else { continue }
      fingerprints[path] = fields[1]
    }
    return fingerprints
  }

  func exportComparison(
    currentSessionID: String,
    baselineSessionID: String?,
    rows: [CodexDecisionComparisonRow],
    selectedScanProfile: CodexEvidenceScanProfile? = nil,
    profileAssessment: CodexEvidenceProfileAssessment? = nil
  ) throws -> [String] {
    let fm = FileManager.default
    try fm.createDirectory(atPath: exportDirectory, withIntermediateDirectories: true, attributes: nil)
    let sessions = recentSessions(limit: 20)
    let currentRuleVersion = sessions.first(where: { $0.id == currentSessionID })?.ruleVersion
    let baselineRuleVersion = baselineSessionID.flatMap { id in sessions.first(where: { $0.id == id })?.ruleVersion }
    let bundle = CodexComparisonEvidenceBundle(
      exportedAt: Date(),
      currentSessionID: currentSessionID,
      baselineSessionID: baselineSessionID,
      currentRuleVersion: currentRuleVersion,
      baselineRuleVersion: baselineRuleVersion,
      rows: rows,
      selectedScanProfile: selectedScanProfile,
      profileAssessment: profileAssessment
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let baselineStem = baselineSessionID ?? "baseline"
    let stem = "comparison-\(currentSessionID)-\(baselineStem)"
    let jsonPath = (exportDirectory as NSString).appendingPathComponent("\(stem).json")
    let csvPath = (exportDirectory as NSString).appendingPathComponent("\(stem).csv")
    try encoder.encode(bundle).write(to: URL(fileURLWithPath: jsonPath), options: .atomic)
    try CodexSmartLogicEngine.comparisonCSV(rows).write(toFile: csvPath, atomically: true, encoding: .utf8)
    return [jsonPath, csvPath]
  }

  func exportRouteReceipts(
    sessionID: String,
    receipts: [CodexScanRouteReceipt]
  ) throws -> [String] {
    let fm = FileManager.default
    try fm.createDirectory(atPath: exportDirectory, withIntermediateDirectories: true, attributes: nil)
    let orderedReceipts = receipts.sorted { lhs, rhs in
      if lhs.sourcePath != rhs.sourcePath { return lhs.sourcePath < rhs.sourcePath }
      return lhs.updatedAt < rhs.updatedAt
    }
    let bundle = CodexRouteReceiptExportBundle(
      exportedAt: Date(),
      sessionID: sessionID,
      summary: CodexSmartLogicEngine.routeReceiptSummary(orderedReceipts),
      receipts: orderedReceipts
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let stem = "route-receipts-" + sessionID
    let jsonPath = (exportDirectory as NSString).appendingPathComponent(stem + ".json")
    let csvPath = (exportDirectory as NSString).appendingPathComponent(stem + ".csv")
    try encoder.encode(bundle).write(to: URL(fileURLWithPath: jsonPath), options: .atomic)
    var csv = "session_id,source_path,route,state,attempt_count,updated_at,detail\n"
    let dateFormatter = ISO8601DateFormatter()
    for receipt in orderedReceipts {
      let row = [
        receipt.sessionID,
        receipt.sourcePath,
        receipt.route.rawValue,
        receipt.state.rawValue,
        String(receipt.attemptCount),
        dateFormatter.string(from: receipt.updatedAt),
        receipt.detail
      ].map(CodexSmartLogicEngine.csvEscape).joined(separator: ",")
      csv += row + "\n"
    }
    try csv.write(toFile: csvPath, atomically: true, encoding: .utf8)
    return [jsonPath, csvPath]
  }

  private func writeExports(session: CodexScanSession, decisions: [CodexSmartDecision]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let json = try encoder.encode(decisions)
    let jsonPath = (exportDirectory as NSString).appendingPathComponent("\(session.id)-decisions.json")
    try json.write(to: URL(fileURLWithPath: jsonPath), options: .atomic)

    var csv = "id,source_path,group_key,classification,confidence,remote_url,branch,main_state,ide_state,reasons\n"
    for decision in decisions {
      let row = [
        decision.id,
        decision.sourcePath,
        decision.groupKey,
        decision.classification.rawValue,
        String(decision.confidence),
        decision.evidence.remoteURL ?? "",
        decision.evidence.branch ?? "",
        decision.evidence.mainLabel,
        decision.evidence.ideState,
        decision.reasons.joined(separator: " | ")
      ].map(csvEscape).joined(separator: ",")
      csv += row + "\n"
    }
    let csvPath = (exportDirectory as NSString).appendingPathComponent("\(session.id)-decisions.csv")
    try csv.write(toFile: csvPath, atomically: true, encoding: .utf8)
  }

  private func runSQL(_ sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = ["-batch", databasePath]
    let input = Pipe()
    let error = Pipe()
    process.standardInput = input
    process.standardError = error
    try process.run()
    input.fileHandleForWriting.write(Data(sql.utf8))
    input.fileHandleForWriting.closeFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let message = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "sqlite3 failed"
      throw NSError(domain: "CSAiEM.CodexCatalog", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)])
    }
  }

  private func runQuery(_ sql: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = ["-batch", databasePath]
    let input = Pipe()
    let output = Pipe()
    process.standardInput = input
    process.standardOutput = output
    do {
      try process.run()
      input.fileHandleForWriting.write(Data(sql.utf8))
      input.fileHandleForWriting.closeFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return nil }
      return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    } catch {
      return nil
    }
  }

  private func encode<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    return String(data: data, encoding: .utf8) ?? "null"
  }

  private func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

  private func quote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
  }

  private func csvEscape(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ") + "\""
  }

  private static func decodeHex(_ value: String) -> Data? {
    guard value.count.isMultiple(of: 2) else { return nil }
    var data = Data(capacity: value.count / 2)
    var index = value.startIndex
    while index < value.endIndex {
      let next = value.index(index, offsetBy: 2)
      guard let byte = UInt8(value[index..<next], radix: 16) else { return nil }
      data.append(byte)
      index = next
    }
    return data
  }

  private var schemaSQL: String {
    """
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS scan_sessions (id TEXT PRIMARY KEY, profile TEXT NOT NULL, source_roots TEXT NOT NULL, created_at TEXT NOT NULL, rule_version TEXT NOT NULL, decision_count INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS decisions (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, source_path TEXT NOT NULL, group_key TEXT NOT NULL, classification TEXT NOT NULL, confidence REAL NOT NULL, evidence_json TEXT NOT NULL, reasons_json TEXT NOT NULL, destination_path TEXT NOT NULL, rule_version TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS session_checkpoints (session_id TEXT NOT NULL, source_path TEXT NOT NULL, stage TEXT NOT NULL, state TEXT NOT NULL, updated_at TEXT NOT NULL, detail TEXT NOT NULL, PRIMARY KEY (session_id, source_path, stage));
    CREATE TABLE IF NOT EXISTS scan_route_receipts (session_id TEXT NOT NULL, source_path TEXT NOT NULL, route TEXT NOT NULL, state TEXT NOT NULL, attempt_count INTEGER NOT NULL, updated_at TEXT NOT NULL, detail TEXT NOT NULL, PRIMARY KEY (session_id, source_path));
    CREATE TABLE IF NOT EXISTS scan_index_records (source_path TEXT NOT NULL, destination_path TEXT NOT NULL, source_index_path TEXT NOT NULL, destination_index_path TEXT NOT NULL, options_key TEXT NOT NULL, source_index_digest TEXT NOT NULL, destination_index_digest TEXT NOT NULL, source_file_count INTEGER NOT NULL, source_byte_count INTEGER NOT NULL, captured_at TEXT NOT NULL, PRIMARY KEY (source_path, destination_path, options_key));
    CREATE TABLE IF NOT EXISTS session_source_deltas (session_id TEXT NOT NULL, source_path TEXT NOT NULL, kind TEXT NOT NULL, previous_fingerprint TEXT NOT NULL, current_fingerprint TEXT NOT NULL, PRIMARY KEY (session_id, source_path));
    CREATE TABLE IF NOT EXISTS session_timing (session_id TEXT PRIMARY KEY, discovery_ms INTEGER NOT NULL, decision_ms INTEGER NOT NULL, total_ms INTEGER NOT NULL, discovered_count INTEGER NOT NULL, evaluated_count INTEGER NOT NULL, reused_count INTEGER NOT NULL, changed_count INTEGER NOT NULL, affected_group_count INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS decisions_session_idx ON decisions(session_id);
    CREATE INDEX IF NOT EXISTS decisions_group_idx ON decisions(group_key);
    CREATE INDEX IF NOT EXISTS scan_index_records_digest_idx ON scan_index_records(source_index_digest);
    CREATE INDEX IF NOT EXISTS session_source_deltas_session_idx ON session_source_deltas(session_id);
    CREATE INDEX IF NOT EXISTS scan_route_receipts_session_idx ON scan_route_receipts(session_id);
    """
  }
}
