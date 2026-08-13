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

struct CodexScanSession: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let profile: String
  let sourceRoots: [String]
  let createdAt: Date
  let ruleVersion: String
  let decisionCount: Int
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

enum CodexSmartLogicEngine {
  static let ruleVersion = "smart-logic-v2"

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
      } else if sameGroupCount > 1 {
        classification = .mergeCandidate
        confidence = project.gitStatus.hasLocalChanges || !project.gitStatus.isMainSynchronized || project.branch != "main" ? 0.86 : 0.92
        reasons.append("Multiple source folders share the same verified remote identity.")
        if isRecommendedLead {
          reasons.append("Deterministic lead recommendation: this source has the strongest synchronized, clean, and linked evidence in the identity group.")
        } else {
          reasons.append("Lead rank (leadRank) in the identity group; preserve this source as a review candidate until the operator confirms the canonical source.")
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
  func save(session: CodexScanSession, decisions: [CodexSmartDecision], checkpoints: [CodexSessionCheckpoint] = []) throws -> String {
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

  private var schemaSQL: String {
    """
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS scan_sessions (id TEXT PRIMARY KEY, profile TEXT NOT NULL, source_roots TEXT NOT NULL, created_at TEXT NOT NULL, rule_version TEXT NOT NULL, decision_count INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS decisions (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, source_path TEXT NOT NULL, group_key TEXT NOT NULL, classification TEXT NOT NULL, confidence REAL NOT NULL, evidence_json TEXT NOT NULL, reasons_json TEXT NOT NULL, destination_path TEXT NOT NULL, rule_version TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS session_checkpoints (session_id TEXT NOT NULL, source_path TEXT NOT NULL, stage TEXT NOT NULL, state TEXT NOT NULL, updated_at TEXT NOT NULL, detail TEXT NOT NULL, PRIMARY KEY (session_id, source_path, stage));
    CREATE TABLE IF NOT EXISTS scan_index_records (source_path TEXT NOT NULL, destination_path TEXT NOT NULL, source_index_path TEXT NOT NULL, destination_index_path TEXT NOT NULL, options_key TEXT NOT NULL, source_index_digest TEXT NOT NULL, destination_index_digest TEXT NOT NULL, source_file_count INTEGER NOT NULL, source_byte_count INTEGER NOT NULL, captured_at TEXT NOT NULL, PRIMARY KEY (source_path, destination_path, options_key));
    CREATE INDEX IF NOT EXISTS decisions_session_idx ON decisions(session_id);
    CREATE INDEX IF NOT EXISTS decisions_group_idx ON decisions(group_key);
    CREATE INDEX IF NOT EXISTS scan_index_records_digest_idx ON scan_index_records(source_index_digest);
    """
  }
}
