import Foundation

enum CSAiEMIncidentSeverity: String, Codable, CaseIterable, Identifiable {
  case recoverable
  case fatal

  var id: String { rawValue }

  var label: String {
    switch self {
    case .recoverable: return "Recoverable"
    case .fatal: return "Fatal blocker"
    }
  }
}

enum CSAiEMIncidentState: String, Codable, CaseIterable, Identifiable {
  case open
  case resolved

  var id: String { rawValue }
}

struct CSAiEMIncident: Identifiable, Codable, Hashable {
  let id: String
  let createdAt: Date
  let kind: String
  let title: String
  let target: String
  let detail: String
  let jobID: String
  let severity: CSAiEMIncidentSeverity
  var evidence: CSAiEMIncidentEvidence
  var state: CSAiEMIncidentState
  var resolution: String?

  init(id: String, createdAt: Date, kind: String, title: String, target: String, detail: String, jobID: String, severity: CSAiEMIncidentSeverity, evidence: CSAiEMIncidentEvidence = .empty, state: CSAiEMIncidentState, resolution: String?) {
    self.id = id
    self.createdAt = createdAt
    self.kind = kind
    self.title = title
    self.target = target
    self.detail = detail
    self.jobID = jobID
    self.severity = severity
    self.evidence = evidence
    self.state = state
    self.resolution = resolution
  }

  enum CodingKeys: String, CodingKey { case id, createdAt, kind, title, target, detail, jobID, severity, evidence, state, resolution }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    createdAt = try values.decode(Date.self, forKey: .createdAt)
    kind = try values.decode(String.self, forKey: .kind)
    title = try values.decode(String.self, forKey: .title)
    target = try values.decode(String.self, forKey: .target)
    detail = try values.decode(String.self, forKey: .detail)
    jobID = try values.decode(String.self, forKey: .jobID)
    severity = try values.decode(CSAiEMIncidentSeverity.self, forKey: .severity)
    evidence = try values.decodeIfPresent(CSAiEMIncidentEvidence.self, forKey: .evidence) ?? .empty
    state = try values.decode(CSAiEMIncidentState.self, forKey: .state)
    resolution = try values.decodeIfPresent(String.self, forKey: .resolution)
  }

  var statusLabel: String {
    state == .resolved ? "Resolved" : severity.label
  }
}

struct CSAiEMIncidentEvidence: Codable, Hashable {
  let stage: String
  let source: String?
  let destination: String?
  let receipt: String?
  let checkpoint: String?
  let nextAction: String

  static let empty = CSAiEMIncidentEvidence(stage: "unknown", source: nil, destination: nil, receipt: nil, checkpoint: nil, nextAction: "Review the job detail and choose Retry or Resolve.")

  var summaryLines: [String] {
    ["Stage: \(stage)", source.map { "Source: \($0)" }, destination.map { "Destination: \($0)" }, receipt.map { "Receipt: \($0)" }, checkpoint.map { "Checkpoint: \($0)" }, "Next action: \(nextAction)"].compactMap { $0 }
  }
}

enum CSAiEMIncidentClassifier {
  static func evidence(for job: BackgroundJobEntry, severity: CSAiEMIncidentSeverity) -> CSAiEMIncidentEvidence {
    let normalizedKind = job.kind.lowercased()
    let normalizedTitle = job.title.lowercased()
    let stage: String
    if normalizedTitle.contains("stage 3") || normalizedKind.contains("cleanup") {
      stage = "stage-3-cleanup"
    } else if normalizedTitle.contains("stage 2") || normalizedKind.contains("recovery") || normalizedKind.contains("migration") {
      stage = "stage-2-reconciliation"
    } else if normalizedKind.contains("codex") || normalizedKind.contains("index") {
      stage = "stage-1-index"
    } else {
      stage = normalizedKind.isEmpty ? "background-job" : normalizedKind
    }
    let source = value(after: "source", in: job.detail) ?? (stage == "stage-1-index" ? job.target : nil)
    let destination = value(after: "destination", in: job.detail)
    let receipt = value(after: "receipt", in: job.detail)
    let checkpoint = value(after: "checkpoint", in: job.detail)
    let nextAction: String
    if severity == .fatal {
      nextAction = "Resolve the identity, authorization, integrity, or destination blocker before retrying."
    } else if checkpoint != nil {
      nextAction = "Resume from the recorded checkpoint or retry only the affected job."
    } else {
      nextAction = "Retry the affected job; unrelated work can continue."
    }
    return CSAiEMIncidentEvidence(stage: stage, source: source, destination: destination, receipt: receipt, checkpoint: checkpoint, nextAction: nextAction)
  }

  static func severity(for detail: String) -> CSAiEMIncidentSeverity {
    let normalized = detail.lowercased()
    let fatalMarkers = [
      "fatal", "authorization", "identity", "integrity", "protected checkout",
      "destination conflict", "deletion safety", "unsafe destination", "permission denied"
    ]
    return fatalMarkers.contains(where: normalized.contains) ? .fatal : .recoverable
  }

  static func redactedIssueDraft(for incident: CSAiEMIncident) -> String {
    let detail = redact(incident.detail)
    let target = redact(incident.target)
    let resolution = incident.resolution.map(redact) ?? "Not resolved"
    return """
    ## CSA-iEM incident: \(incident.title)

    - Severity: \(incident.severity.label)
    - State: \(incident.state == .resolved ? "resolved" : "open")
    - Kind: \(incident.kind)
    - Target: \(target.isEmpty ? "(not provided)" : target)
    - Job ID: \(incident.jobID)

    ### Correlated evidence
    \(incident.evidence.summaryLines.joined(separator: "\n"))

    ### Detail
    \(detail)

    ### Resolution
    \(resolution)

    ### Safety boundary
    This draft was generated locally from redacted job evidence. It contains no credentials, prompt content, or raw conversation data. Review it before handing it to GitHub Issues.
    """
  }

  private static func value(after label: String, in detail: String) -> String? {
    let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: label) + "\\s*[:=]\\s*([^\\n,;]+)"
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(in: detail, range: NSRange(detail.startIndex..., in: detail)),
          let range = Range(match.range(at: 1), in: detail) else { return nil }
    let value = String(detail[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private static func redact(_ value: String) -> String {
    var result = value
    let home = NSString(string: "~").expandingTildeInPath
    if !home.isEmpty {
      result = result.replacingOccurrences(of: home, with: "~")
    }
    result = result.replacingOccurrences(of: #"(?i)(token|password|secret|authorization)\s*[:=]\s*[^\s,;]+"#, with: "$1=[REDACTED]", options: .regularExpression)
    result = result.replacingOccurrences(of: #"/Users/[^/\s]+"#, with: "~/[USER]", options: .regularExpression)
    return result
  }
}

enum CSAiEMIncidentStore {
  static func load(from path: String) -> [CSAiEMIncident] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return [] }
    return (try? JSONDecoder().decode([CSAiEMIncident].self, from: data)) ?? []
  }

  static func save(_ incidents: [CSAiEMIncident], to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(incidents) else { return }
    try? data.write(to: url, options: .atomic)
  }
}
