import Foundation

enum CSAiEMGitHubIssueMutation: String, CaseIterable, Identifiable, Hashable {
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

struct CSAiEMGitHubIssueCommand: Hashable {
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
