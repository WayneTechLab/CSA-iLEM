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
  var state: CSAiEMIncidentState
  var resolution: String?

  var statusLabel: String {
    state == .resolved ? "Resolved" : severity.label
  }
}

enum CSAiEMIncidentClassifier {
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

    ### Detail
    \(detail)

    ### Resolution
    \(resolution)

    ### Safety boundary
    This draft was generated locally from redacted job evidence. It contains no credentials, prompt content, or raw conversation data. Review it before handing it to GitHub Issues.
    """
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
