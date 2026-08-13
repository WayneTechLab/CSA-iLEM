import Foundation

enum CSAiEMGitHubIssueMutation: String, CaseIterable, Identifiable, Hashable, Codable {
  case comment
  case close
  case reopen
  case addLabel
  case removeLabel

  var id: String { rawValue }

  var title: String {
    switch self {
    case .comment: return "Comment"
    case .close: return "Close"
    case .reopen: return "Reopen"
    case .addLabel: return "Add label"
    case .removeLabel: return "Remove label"
    }
  }

  var requiresBody: Bool { self == .comment }
  var requiresLabels: Bool { self == .addLabel || self == .removeLabel }
}

struct CSAiEMGitHubIssueCommand: Hashable, Codable {
  let mutation: CSAiEMGitHubIssueMutation
  let issueNumber: Int
  let body: String
  let labels: [String]

  enum ValidationError: LocalizedError, Equatable {
    case invalidIssueNumber
    case missingBody
    case missingLabels

    var errorDescription: String {
      switch self {
      case .invalidIssueNumber: return "Select a valid GitHub issue first."
      case .missingBody: return "A comment body is required."
      case .missingLabels: return "Enter at least one label."
      }
    }
  }

  static func make(mutation: CSAiEMGitHubIssueMutation, issueNumber: Int?, body: String, labels: String) throws -> Self {
    guard let issueNumber, issueNumber > 0 else { throw ValidationError.invalidIssueNumber }
    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    let parsedLabels = labels
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    if mutation.requiresBody && trimmedBody.isEmpty { throw ValidationError.missingBody }
    if mutation.requiresLabels && parsedLabels.isEmpty { throw ValidationError.missingLabels }
    return Self(mutation: mutation, issueNumber: issueNumber, body: trimmedBody, labels: parsedLabels)
  }

  var arguments: [String] {
    let issue = "\(issueNumber)"
    switch mutation {
    case .comment: return ["issue", "comment", issue, "--body", body]
    case .close: return ["issue", "close", issue]
    case .reopen: return ["issue", "reopen", issue]
    case .addLabel: return ["issue", "edit", issue] + labels.flatMap { ["--add-label", $0] }
    case .removeLabel: return ["issue", "edit", issue] + labels.flatMap { ["--remove-label", $0] }
    }
  }
}

struct CSAiEMGitHubIssueRetryRecord: Identifiable, Hashable, Codable {
  let id: String
  let host: String
  let repository: String
  let command: CSAiEMGitHubIssueCommand
  let createdAt: Date
  var lastAttemptAt: Date
  var attempts: Int
  var lastError: String

  var summary: String {
    "\(repository)#\(command.issueNumber) · \(command.mutation.title) · \(attempts) attempt\(attempts == 1 ? "" : "s")"
  }
}

enum CSAiEMGitHubProviderOutcome: String, Codable, Hashable {
  case permissionDenied
  case authenticationRequired
  case notFound
  case timeout
  case failed

  var title: String {
    switch self {
    case .permissionDenied: return "Permission denied"
    case .authenticationRequired: return "Authentication required"
    case .notFound: return "Issue or repository not found"
    case .timeout: return "Provider timeout"
    case .failed: return "Provider failure"
    }
  }

  static func classify(status: Int, output: String) -> Self {
    if status == 124 { return .timeout }
    let lower = output.lowercased()
    if lower.contains("bad credentials") || lower.contains("authentication") || lower.contains("not logged in") {
      return .authenticationRequired
    }
    if lower.contains("permission") || lower.contains("forbidden") || lower.contains("resource not accessible") || lower.contains("insufficient permission") {
      return .permissionDenied
    }
    if lower.contains("could not resolve to an issue") || lower.contains("not found") || lower.contains("repository not found") {
      return .notFound
    }
    return .failed
  }
}

struct CSAiEMGitHubIssueVerificationPayload: Decodable, Hashable {
  let state: String
  let labels: [String]
  let comments: [String]

  private struct Label: Decodable { let name: String }
  private struct Comment: Decodable { let body: String }

  enum CodingKeys: String, CodingKey { case state, labels, comments }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    state = try values.decode(String.self, forKey: .state)
    labels = (try values.decodeIfPresent([Label].self, forKey: .labels) ?? []).map(\.name).sorted()
    comments = (try values.decodeIfPresent([Comment].self, forKey: .comments) ?? []).map(\.body)
  }
}

enum CSAiEMGitHubIssueVerifier {
  enum VerificationError: LocalizedError, Equatable {
    case mismatch(String)

    var errorDescription: String {
      switch self { case .mismatch(let detail): return detail }
    }
  }

  static func arguments(for issueNumber: Int) -> [String] {
    ["issue", "view", "\(issueNumber)", "--json", "state,labels,comments"]
  }

  static func verify(_ payload: CSAiEMGitHubIssueVerificationPayload, command: CSAiEMGitHubIssueCommand) -> Result<String, VerificationError> {
    let state = payload.state.lowercased()
    switch command.mutation {
    case .comment:
      guard payload.comments.contains(command.body) else {
        return .failure(.mismatch("Provider read-back did not contain the submitted comment."))
      }
      return .success("Comment presence verified.")
    case .close:
      guard state == "closed" else { return .failure(.mismatch("Provider read-back state is \(payload.state), expected CLOSED.")) }
      return .success("Closed state verified.")
    case .reopen:
      guard state == "open" else { return .failure(.mismatch("Provider read-back state is \(payload.state), expected OPEN.")) }
      return .success("Open state verified.")
    case .addLabel:
      let actual = Set(payload.labels.map { $0.lowercased() })
      let missing = command.labels.filter { !actual.contains($0.lowercased()) }
      guard missing.isEmpty else { return .failure(.mismatch("Provider read-back is missing label(s): \(missing.joined(separator: ", ")).")) }
      return .success("Added label(s) verified.")
    case .removeLabel:
      let actual = Set(payload.labels.map { $0.lowercased() })
      let present = command.labels.filter { actual.contains($0.lowercased()) }
      guard present.isEmpty else { return .failure(.mismatch("Provider read-back still contains label(s): \(present.joined(separator: ", ")).")) }
      return .success("Removed label(s) verified.")
    }
  }
}
