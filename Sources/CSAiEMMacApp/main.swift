import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import Darwin

private func readFirstLine(from path: String) -> String? {
  guard !path.isEmpty,
        let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
    return nil
  }

  let version = contents
    .split(whereSeparator: \.isNewline)
    .first?
    .trimmingCharacters(in: .whitespacesAndNewlines)

  return version?.isEmpty == false ? version : nil
}

private func resolvedAppVersion() -> String {
  if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
     !bundleVersion.isEmpty {
    return bundleVersion
  }

  let fileManager = FileManager.default
  let candidates: [String?] = [
    Bundle.main.resourceURL?.appendingPathComponent("VERSION").path,
    Bundle.main.resourceURL?.appendingPathComponent("CLI/VERSION").path,
    ProcessInfo.processInfo.environment["CSA_IEM_ROOT"].map { ($0 as NSString).appendingPathComponent("VERSION") },
    (fileManager.currentDirectoryPath as NSString).appendingPathComponent("VERSION")
  ]

  for candidate in candidates.compactMap({ $0 }) {
    if let version = readFirstLine(from: candidate) {
      return version
    }
  }

  return "0.0.0"
}

private let appTitle = "CSA-iEM"
private let appFullName = "Container Setup & Action Import Engine Manager"
private let appSubtitle = "Codespaces & Actions -> Into Local Environment Mac"
let appVersion = resolvedAppVersion()
private let companyName = "Wayne Tech Lab LLC"
private let companyWebsite = "www.WayneTechLab.com"
private let companyWebsiteURL = "https://www.WayneTechLab.com"
private let publicDefaultRoot = NSString(string: "~/CSA-iEM").expandingTildeInPath
private let publicDefaultCodeRoot = (publicDefaultRoot as NSString).appendingPathComponent("Code")
private let publicDefaultImportRoot = (publicDefaultRoot as NSString).appendingPathComponent("Import")
private let publicDefaultRuntimeRoot = (publicDefaultRoot as NSString).appendingPathComponent("Runtime")
private let configBaseDir = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
  ?? NSString(string: "~/.config").expandingTildeInPath
private let profileConfigDir = (configBaseDir as NSString).appendingPathComponent("csa-iem")
private let legacyProfileConfigDir = (configBaseDir as NSString).appendingPathComponent("csa-ilem")
private let appSupportDir = NSString(string: "~/Library/Application Support/CSA-iEM").expandingTildeInPath
private let lastSessionFile = (appSupportDir as NSString).appendingPathComponent("last-session.env")
private let settingsFile = (appSupportDir as NSString).appendingPathComponent("settings.json")
private let incidentsFile = (appSupportDir as NSString).appendingPathComponent("incidents.json")
private let issueTemplatesFile = (appSupportDir as NSString).appendingPathComponent("issue-templates.json")
private let issueMutationRetriesFile = (appSupportDir as NSString).appendingPathComponent("issue-mutation-retries.json")
private let codexScanRootsFile = (appSupportDir as NSString).appendingPathComponent("codex-scan-roots.json")
private let administratorTerminalModeKey = "com.waynetechlab.csa-iem.administrator-terminal-mode"
private let codexOutputRootKey = "com.waynetechlab.csa-iem.codex-output-root"
private let codexTransferModeKey = "com.waynetechlab.csa-iem.codex-transfer-mode"
private let codexCreateBackupKey = "com.waynetechlab.csa-iem.codex-create-backup"
private let codexIncludeGitMetadataKey = "com.waynetechlab.csa-iem.codex-include-git"
private let codexIncludeFinderMetadataKey = "com.waynetechlab.csa-iem.codex-include-finder-metadata"
private let codexIncludeDependenciesKey = "com.waynetechlab.csa-iem.codex-include-generated-content"
private let codexFullChecksumAuditKey = "com.waynetechlab.csa-iem.codex-full-checksum-audit"
private let codexSmartScanModeKey = "com.waynetechlab.csa-iem.codex-smart-scan-mode"
private let codexBackupMediumKey = "com.waynetechlab.csa-iem.codex-backup-medium"
private let codexCreateCompatibilityLinkKey = "com.waynetechlab.csa-iem.codex-create-compatibility-link"
private let codexRearmGitMainKey = "com.waynetechlab.csa-iem.codex-rearm-git-main"
private let codexAutoResumeExistingKey = "com.waynetechlab.csa-iem.codex-auto-resume-existing"
private let codexReviewDispositionsFile = (appSupportDir as NSString).appendingPathComponent("codex-review-dispositions.json")
private let codexReviewAuditFile = (appSupportDir as NSString).appendingPathComponent("codex-review-audit.json")
private let codexSourceFingerprintsFile = (appSupportDir as NSString).appendingPathComponent("codex-source-fingerprints.json")
private let codexSmartDecisionsFile = (appSupportDir as NSString).appendingPathComponent("codex-smart-decisions.json")
private let codexImportedEvidenceHistoryFile = (appSupportDir as NSString).appendingPathComponent("codex-imported-evidence-history.json")
private let codexImportedRouteReceiptHistoryFile = (appSupportDir as NSString).appendingPathComponent("codex-imported-route-receipt-history.json")
private let codexImportedBaselineAuditHistoryFile = (appSupportDir as NSString).appendingPathComponent("codex-imported-baseline-audit-history.json")
private let codexRejectedBaselineAuditImportsFile = (appSupportDir as NSString).appendingPathComponent("codex-rejected-baseline-audit-imports.json")
private let codexRouteReceiptBaselineDecisionFile = (appSupportDir as NSString).appendingPathComponent("codex-route-receipt-baseline-decision.json")
private let codexRouteReceiptBaselineAuditFile = (appSupportDir as NSString).appendingPathComponent("codex-route-receipt-baseline-audit.json")
private let stage2SourceRootKey = "com.waynetechlab.csa-iem.stage2-source-root"
private let stage2ManagedRootKey = "com.waynetechlab.csa-iem.stage2-managed-root"
private let stage2GitHubOwnerAccountsKey = "com.waynetechlab.csa-iem.stage2-github-owner-accounts"
private let stage2CreateMissingReposKey = "com.waynetechlab.csa-iem.stage2-create-missing-repos"
private let stage2RetireSourcesKey = "com.waynetechlab.csa-iem.stage2-retire-sources"
private let stage2SourceRetentionKey = "com.waynetechlab.csa-iem.stage2-source-retention"
private let stage2ArchiveSourcesKey = "com.waynetechlab.csa-iem.stage2-archive-sources"
private let stage2CleanupTransactionTempKey = "com.waynetechlab.csa-iem.stage2-cleanup-transaction-temp"
private let stage2PrepareRuntimeKey = "com.waynetechlab.csa-iem.stage2-prepare-runtime"
private let stage2OpenAfterApplyKey = "com.waynetechlab.csa-iem.stage2-open-after-apply"
private let codexLifecycleScopeKey = "com.waynetechlab.csa-iem.codex-lifecycle-scope"
private let codexLifecycleDeleteStage1Key = "com.waynetechlab.csa-iem.codex-lifecycle-delete-stage1"
private let codexLifecycleRunStage2Key = "com.waynetechlab.csa-iem.codex-lifecycle-run-stage2"
private let codexLifecycleCleanupScopeKey = "com.waynetechlab.csa-iem.codex-lifecycle-cleanup-scope"
private let contextsFile = (appSupportDir as NSString).appendingPathComponent("contexts.json")
private let taskTemplatesFile = (appSupportDir as NSString).appendingPathComponent("task-templates.json")
private let favoriteProjectsFile = (appSupportDir as NSString).appendingPathComponent("favorite-projects.json")
private let savedViewsFile = (appSupportDir as NSString).appendingPathComponent("saved-project-views.json")
private let snapshotsDirectory = (appSupportDir as NSString).appendingPathComponent("Snapshots")
private let legacyAppSupportDir = NSString(string: "~/Library/Application Support/CSA-iLEM").expandingTildeInPath
private let legacyLastSessionFile = (legacyAppSupportDir as NSString).appendingPathComponent("last-session.env")
private let cleanerAppSupportDir = NSString(string: "~/Library/Application Support/GH Workflow Clean").expandingTildeInPath
private let cleanerLastSessionFile = (cleanerAppSupportDir as NSString).appendingPathComponent("last-session.env")
private let legacyCleanerAppSupportDir = NSString(string: "~/Library/Application Support/GitHub Action Clean-Up Tool").expandingTildeInPath
private let legacyCleanerLastSessionFile = (legacyCleanerAppSupportDir as NSString).appendingPathComponent("last-session.env")
private let bundledHelpDirectory = "Help"
private let defaultSearchPaths = [
  "/opt/homebrew/bin",
  "/usr/local/bin",
  "/usr/bin",
  "/bin",
  "/usr/sbin",
  "/sbin"
]
private let defaultTermsOfServiceText = """
CSA-iEM
Container Setup & Action Import Engine Manager
Provided by Wayne Tech Lab LLC
www.WayneTechLab.com

Warning! This tool can modify GitHub Actions, local runners, local devcontainers, and local workspace state. Use at your own risk.

By accepting and using this product, you acknowledge and agree that:

1. This tool is intended only for authorized, professional GitHub migration, cleanup, self-hosted runner, and devcontainer work.
2. This tool can permanently delete workflow runs, artifacts, caches, Codespaces, and workflow configurations, and can stop local services and containers.
3. You are solely responsible for verifying the GitHub host, account, repository, workspace root, and operation scope before execution.
4. You will use this software only on repositories, organizations, accounts, machines, and storage locations you are authorized to manage.
5. You accept full responsibility for data loss, workflow interruption, billing changes, repository impact, local system impact, and any other outcome caused by use or misuse of this tool.
6. This software is provided as-is, without warranties, guarantees, or assurances of fitness for any purpose.
7. Wayne Tech Lab LLC, its operators, authors, affiliates, and contributors are not liable for damages, losses, claims, or operational impact resulting from use of this software.

If you do not accept these terms, do not use this product.
"""

enum LaunchProfile: String, CaseIterable, Identifiable {
  case diamond
  case wtl
  case `public`

  var id: String { rawValue }

  var label: String {
    switch self {
    case .diamond, .wtl: return "Custom"
    case .public: return "Default"
    }
  }
}

enum WorkspaceStyle: String, CaseIterable, Identifiable {
  case single
  case split

  var id: String { rawValue }

  var label: String {
    switch self {
    case .single: return "Legacy Single Root"
    case .split: return "Code / Import / Runtime"
    }
  }

  var subtitle: String {
    switch self {
    case .single:
      return "Legacy layout where code and runtime still share one root."
    case .split:
      return "Default three-root layout for code, import staging, and runtime."
    }
  }
}

struct WorkspaceSuggestion {
  let profile: LaunchProfile
  let style: WorkspaceStyle
  let title: String
  let detail: String
  let codeRoot: String
  let importRoot: String
  let runtimeRoot: String
}

struct AuthHostConfig {
  let host: String
  let activeUser: String?
  let users: [String]
}

struct CommandResult {
  let status: Int32
  let output: String
}

struct RepoCatalogEntry: Identifiable, Hashable, Decodable {
  let nameWithOwner: String
  let visibility: String?
  let isPrivate: Bool?
  let updatedAt: String?
  let url: String?

  var id: String { nameWithOwner }

  var shortName: String {
    nameWithOwner.split(separator: "/").last.map(String.init) ?? nameWithOwner
  }

  var owner: String {
    nameWithOwner.split(separator: "/").dropLast().first.map(String.init) ?? ""
  }

  var visibilityLabel: String {
    if let visibility, !visibility.isEmpty {
      return visibility.uppercased()
    }
    return isPrivate == true ? "PRIVATE" : "PUBLIC"
  }

  var updatedLabel: String {
    guard let updatedAt, updatedAt.count >= 10 else {
      return "Updated: unknown"
    }
    return "Updated: \(String(updatedAt.prefix(10)))"
  }
}

struct LocalProjectEntry: Identifiable, Hashable {
  let slug: String
  let owner: String
  let repo: String
  let codePath: String?
  let runtimePath: String?
  let hasDevcontainer: Bool
  let hasGeneratedStarter: Bool
  let hasRunner: Bool

  var id: String { slug }

  var locationLabel: String {
    if let codePath, let runtimePath, codePath != runtimePath {
      return "split"
    }
    if runtimePath != nil {
      return "runtime"
    }
    return "code"
  }

  var preferredOpenPath: String? {
    runtimePath ?? codePath
  }

  var badges: [String] {
    var values = [locationLabel]
    if hasDevcontainer {
      values.append(hasGeneratedStarter ? "local-starter" : "devcontainer")
    }
    if hasRunner {
      values.append("runner")
    }
    return values
  }

  var searchableText: String {
    ([slug, owner, repo] + badges).joined(separator: " ").lowercased()
  }
}

enum CodexProjectTransferMode: String, CaseIterable, Identifiable {
  case backupOnly
  case copy
  case syncAndMove
  case syncAndSync
  case scanAndBackup

  var id: String { rawValue }

  var label: String {
    switch self {
    case .backupOnly: return "Backup Only"
    case .copy: return "Copy to Output"
    case .syncAndMove: return "Sync and Move"
    case .syncAndSync: return "Sync and Sync"
    case .scanAndBackup: return "Scan & Backup (Auto Merge)"
    }
  }

  var subtitle: String {
    switch self {
    case .backupOnly:
      return "Create a verified ZIP and handoff notes without creating or changing an output project."
    case .copy:
      return "Stage a new output project, verify it, and leave the source untouched."
    case .syncAndMove:
      return "Checksum-sync the output, verify both sides, then retire the source only after success."
    case .syncAndSync:
      return "Reconcile both folders by checksum and modification time; preserve conflicts for review."
    case .scanAndBackup:
      return "Scan the output, auto-merge missing or changed source files, and create a verified backup."
    }
  }

  var writesDestination: Bool { self != .backupOnly }
  var removesSource: Bool { self == .syncAndMove }
  var performsBidirectionalSync: Bool { self == .syncAndSync }
  var performsScanAndBackup: Bool { self == .scanAndBackup }
  var requiresExistingDestinationMerge: Bool {
    self == .syncAndMove || self == .syncAndSync || self == .scanAndBackup
  }
}

enum CodexSmartScanMode: String, CaseIterable, Identifiable {
  case fastIndex
  case verified
  case yolo

  var id: String { rawValue }

  var label: String {
    switch self {
    case .fastIndex: return "Fast Index"
    case .verified: return "Full Verification"
    case .yolo: return "YOLO · Skip Deep Preflight"
    }
  }

  var subtitle: String {
    switch self {
    case .fastIndex:
      return "Use path, type, size, date, and link metadata first; the existing final verification gate still protects writes."
    case .verified:
      return "Checksum-audit metadata matches during planning before the transfer or lifecycle can proceed."
    case .yolo:
      return "Move quickly through the decision scan for a non-destructive copy or backup. Final write verification and all deletion gates remain enforced."
    }
  }

  var icon: String {
    switch self {
    case .fastIndex: return "speedometer"
    case .verified: return "checkmark.shield"
    case .yolo: return "bolt.horizontal.circle"
    }
  }
}

enum Stage2OpenOption: String, CaseIterable, Identifiable {
  case none
  case codex
  case code
  case copilot
  case finder
  case devcontainer

  var id: String { rawValue }

  var label: String {
    switch self {
    case .none: return "Do Not Open"
    case .codex: return "Codex"
    case .code: return "Visual Studio Code"
    case .copilot: return "GitHub Copilot"
    case .finder: return "Finder"
    case .devcontainer: return "Start Devcontainer"
    }
  }
}

enum Stage2SourceRetention: String, CaseIterable, Identifiable, Sendable {
  case keep
  case retire
  case delete

  var id: String { rawValue }

  var label: String {
    switch self {
    case .keep: return "Keep Stage 1 Inputs"
    case .retire: return "Retire to _temp"
    case .delete: return "Delete After Two Verifications"
    }
  }
}

enum CodexLifecycleScope: String, CaseIterable, Identifiable, Sendable {
  case selected
  case all

  var id: String { rawValue }
  var label: String { self == .selected ? "Selected Projects" : "All Eligible Projects" }
}

enum CodexLifecycleCleanupScope: String, CaseIterable, Identifiable, Sendable {
  case none
  case currentTransaction
  case allVerifiedTemp

  var id: String { rawValue }

  var label: String {
    switch self {
    case .none: return "Keep Temporary Data"
    case .currentTransaction: return "Clean Current Transaction"
    case .allVerifiedTemp: return "Clean All Receipt-Linked Temp"
    }
  }
}

enum CodexIDEProjectState: String, Hashable, Sendable {
  case active = "Active here"
  case linked = "Codex linked"
  case unlinked = "Unlinked"
  case unavailable = "Codex status unavailable"
}

enum CodexToolEvidence: String, Codable, CaseIterable, Hashable, Sendable {
  case codex = "Codex"
  case visualStudioCode = "VS Code / Copilot"
  case claude = "Claude"
  case lmStudio = "LM Studio"
}

enum CodexToolEvidenceDetector {
  static func detect(projectPath: String, codexState: CodexIDEProjectState) -> [CodexToolEvidence] {
    let fileManager = FileManager.default
    var evidence: Set<CodexToolEvidence> = []
    if codexState == .active || codexState == .linked {
      evidence.insert(.codex)
    }

    let markers: [(CodexToolEvidence, [String])] = [
      (.visualStudioCode, [".vscode"]),
      (.claude, [".claude", "CLAUDE.md"]),
      (.lmStudio, [".lmstudio", "lmstudio.json"])
    ]
    for (tool, names) in markers where names.contains(where: { name in
      fileManager.fileExists(atPath: (projectPath as NSString).appendingPathComponent(name))
    }) {
      evidence.insert(tool)
    }
    return CodexToolEvidence.allCases.filter { evidence.contains($0) }
  }

  static func activeHostTools(processNames: [String]) -> [CodexToolEvidence] {
    let names = Set(processNames.map { $0.lowercased() })
    let matches: [(CodexToolEvidence, Set<String>)] = [
      (.codex, ["codex", "codex desktop"]),
      (.visualStudioCode, ["code", "visual studio code", "cursor", "vscodium"]),
      (.claude, ["claude", "claude desktop"]),
      (.lmStudio, ["lm studio", "lmstudio"])
    ]
    return matches.compactMap { tool, aliases in
      aliases.contains(where: { alias in names.contains(alias) || names.contains { $0.contains(alias) } }) ? tool : nil
    }
  }

  static func activeHostTools() -> [CodexToolEvidence] {
    let processNames = NSWorkspace.shared.runningApplications.flatMap { application in
      [application.localizedName, application.bundleIdentifier].compactMap { $0 }
    }
    return activeHostTools(processNames: processNames)
  }
}

enum CodexGitMainState: Hashable, Sendable {
  case synchronized
  case ahead(Int)
  case behind(Int)
  case diverged(ahead: Int, behind: Int)
  case noOriginMain
  case unavailable
  case noGit
}

struct CodexGitWorkspaceStatus: Hashable, Sendable {
  let branch: String?
  let upstream: String?
  let mainState: CodexGitMainState
  let hasLocalChanges: Bool

  var mainLabel: String {
    switch mainState {
    case .synchronized:
      return branch == "main" ? "Main: synced" : "Main: same commit"
    case let .ahead(count):
      return "Main: ahead \(count)"
    case let .behind(count):
      return "Main: behind \(count)"
    case let .diverged(ahead, behind):
      return "Main: +\(ahead) / -\(behind)"
    case .noOriginMain:
      return "Main: not tracked"
    case .unavailable:
      return "Git status unavailable"
    case .noGit:
      return "No Git"
    }
  }

  var mainDetail: String {
    switch mainState {
    case .synchronized:
      return "HEAD matches the locally stored origin/main commit."
    case let .ahead(count):
      return "HEAD is \(count) commit(s) ahead of the locally stored origin/main commit."
    case let .behind(count):
      return "HEAD is \(count) commit(s) behind the locally stored origin/main commit."
    case let .diverged(ahead, behind):
      return "HEAD is \(ahead) commit(s) ahead and \(behind) commit(s) behind the locally stored origin/main commit."
    case .noOriginMain:
      return "No local origin/main reference is available."
    case .unavailable:
      return "The local Git status check did not complete."
    case .noGit:
      return "This project has no Git worktree."
    }
  }

  var isMainSynchronized: Bool {
    if case .synchronized = mainState { return true }
    return false
  }
}

private struct CodexDesktopProjectRegistry: Sendable {
  let isAvailable: Bool
  let linkedRootPaths: Set<String>
  let activeRootPaths: Set<String>

  func state(for projectPath: String) -> CodexIDEProjectState {
    guard isAvailable else { return .unavailable }
    let projectVariants = Self.normalizedPathVariants(projectPath)
    if Self.matches(projectVariants: projectVariants, registryRoots: activeRootPaths) {
      return .active
    }
    if Self.matches(projectVariants: projectVariants, registryRoots: linkedRootPaths) {
      return .linked
    }
    return .unlinked
  }

  static func normalizedPathVariants(_ path: String) -> Set<String> {
    let expanded = NSString(string: path).expandingTildeInPath
    let standardized = NSString(string: expanded).standardizingPath
    let resolved = URL(fileURLWithPath: standardized).resolvingSymlinksInPath().path
    return Set([standardized, resolved].filter { !$0.isEmpty })
  }

  private static func matches(projectVariants: Set<String>, registryRoots: Set<String>) -> Bool {
    projectVariants.contains { projectPath in
      registryRoots.contains { rootPath in
        projectPath == rootPath || projectPath.hasPrefix(rootPath + "/")
      }
    }
  }
}

struct CodexProjectEntry: Identifiable, Hashable, Sendable {
  let path: String
  let name: String
  let discoveredBy: String
  let hasGit: Bool
  let hasPackageManifest: Bool
  let hasDevcontainer: Bool
  let hasSystemX: Bool
  let localDevProfile: CodexLocalDevProfile?
  let toolEvidence: [CodexToolEvidence]
  let activeToolEvidence: [CodexToolEvidence]
  let snapshot: CodexProjectSnapshot
  let remoteURL: String?
  let branch: String?
  let ideState: CodexIDEProjectState
  let gitStatus: CodexGitWorkspaceStatus

  var id: String { path }

  var badges: [String] {
    var values: [String] = []
    if hasGit { values.append("git") }
    if hasPackageManifest { values.append("manifest") }
    if hasDevcontainer { values.append("devcontainer") }
    if hasSystemX { values.append("SYSTEMX") }
    if let localDevProfile { values.append(localDevProfile.badge) }
    values.append(contentsOf: toolEvidence.map(\.rawValue))
    values.append(contentsOf: activeToolEvidence.map { "active:\($0.rawValue)" })
    values.append(snapshot.summary)
    return values
  }

  var searchableText: String {
    ([name, path, discoveredBy, remoteURL ?? "", branch ?? "", ideState.rawValue, gitStatus.mainLabel, localDevProfile?.commandLabel ?? ""] + badges)
      .joined(separator: " ")
      .lowercased()
  }
}

struct CodexProjectSnapshot: Codable, Hashable, Sendable {
  let fileCount: Int
  let byteCount: Int64
  let latestModification: Date?
  let truncated: Bool

  var summary: String {
    let size = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    return "snapshot:\(fileCount) files / \(size)" + (truncated ? " / bounded" : "")
  }
}

struct CodexLocalDevProfile: Hashable, Sendable {
  let script: String
  let label: String
  let badge: String

  var commandLabel: String {
    "npm run \(script)"
  }
}

private final class CodexProjectEntryCollector: @unchecked Sendable {
  private let lock = NSLock()
  private var entries: [CodexProjectEntry?]

  init(count: Int) {
    entries = Array(repeating: nil, count: count)
  }

  func store(_ entry: CodexProjectEntry, at index: Int) {
    lock.lock()
    entries[index] = entry
    lock.unlock()
  }

  func collectedEntries() -> [CodexProjectEntry] {
    lock.lock()
    defer { lock.unlock() }
    return entries.compactMap { $0 }
  }
}

struct CodexProjectTransferOutcome {
  let projectName: String
  let originalSourcePath: String
  let currentSourcePath: String?
  let destinationPath: String?
  let backupPath: String?
  let archivePath: String?
  let warnings: [String]
  let resumedExistingDestination: Bool
  let reconciledFileCount: Int
  let conflictCount: Int
  var receiptPath: String? = nil
}

struct CodexFileIndexEntry: Codable, Hashable {
  enum Kind: String, Codable, Hashable {
    case directory
    case file
    case symbolicLink
    case other
  }

  let relativePath: String
  let kind: Kind
  let byteCount: Int64
  let modifiedAt: TimeInterval
  let symbolicLinkDestination: String?

  func isMetadataEquivalent(to other: CodexFileIndexEntry) -> Bool {
    kind == other.kind &&
      byteCount == other.byteCount &&
      Int64(modifiedAt) == Int64(other.modifiedAt) &&
      symbolicLinkDestination == other.symbolicLinkDestination
  }
}

struct CodexFileIndexSnapshot: Codable {
  let formatVersion: Int
  let rootPath: String
  let createdAt: Date
  let entries: [CodexFileIndexEntry]

  var byteCount: Int64 {
    entries.reduce(0) { $0 + $1.byteCount }
  }
}

struct CodexTransferPlan: Identifiable, Codable {
  let projectName: String
  let projectPath: String
  let destinationPath: String?
  let createdAt: Date
  let sourceFileCount: Int
  let sourceByteCount: Int64
  let destinationFileCount: Int
  let destinationByteCount: Int64
  let requiresInitialMirror: Bool
  let missingPaths: [String]
  let metadataChangedPaths: [String]
  let checksumChangedPaths: [String]
  let destinationOnlyPaths: [String]
  let typeConflictPaths: [String]
  let metadataMatchedCount: Int
  let fullChecksumAudit: Bool
  let sourceIndexPath: String
  let destinationIndexPath: String?
  let planPath: String
  let cacheFormatVersion: Int?
  let includeGitMetadata: Bool?
  let includeFinderMetadata: Bool?
  let includeDependencies: Bool?
  let usedVerifiedCache: Bool?

  var id: String { projectPath }

  var plannedPaths: [String] {
    Array(Set(missingPaths + metadataChangedPaths + checksumChangedPaths + typeConflictPaths)).sorted()
  }

  var plannedByteCount: Int64 {
    // The plan file deliberately carries byte totals only for files that need
    // a source-to-destination transfer; directories are recreated by rsync.
    // This value is populated while building the plan and stored in its JSON.
    plannedEntryByteCount
  }

  let plannedEntryByteCount: Int64

  var planningLabel: String {
    if requiresInitialMirror {
      return "Initial mirror required"
    }
    if plannedPaths.isEmpty {
      return usedVerifiedCache == true ? "Verified cache: no copy needed" : "No file copy needed"
    }
    return "\(plannedPaths.count) path(s) need transfer"
  }

  var summaryLine: String {
    let planned = ByteCountFormatter.string(fromByteCount: plannedEntryByteCount, countStyle: .file)
    if requiresInitialMirror {
      return "New destination: \(sourceFileCount) indexed entries, \(planned) baseline copy."
    }
    if usedVerifiedCache == true, plannedPaths.isEmpty {
      return "Saved index verified against the current folders. No paths or bytes need transfer."
    }
    let audit = fullChecksumAudit
      ? " Deep checksum audit included during planning; final whole-tree checksum required."
      : " Metadata matches are skipped during copy planning; final whole-tree checksum required."
    return "\(plannedPaths.count) planned, \(destinationOnlyPaths.count) destination-only, \(metadataMatchedCount) metadata-matched. \(planned) to copy.\(audit)"
  }
}

struct LiveContainerEntry: Identifiable, Hashable {
  let containerID: String
  let name: String
  let image: String
  let status: String
  let workspacePath: String
  let slug: String
  let repo: String
  let codePath: String?
  let runtimePath: String?

  var id: String { containerID }
}

struct RunnerServiceEntry: Identifiable, Hashable {
  let slug: String
  let repo: String
  let runnerPath: String
  let serviceLabel: String
  let servicePlistPath: String?
  let isRunning: Bool
  let codePath: String?
  let runtimePath: String?

  var id: String { slug }

  var statusLabel: String {
    isRunning ? "running" : "stopped"
  }
}

struct LegacyWorkspaceCandidate: Identifiable, Hashable {
  let id: String
  let label: String
  let codeRoot: String
  let importRoot: String
  let runtimeRoot: String
  let projectCount: Int
  let runnerCount: Int

  var summary: String {
    "\(projectCount) projects · \(runnerCount) runners"
  }
}

enum BackgroundJobState: String, Codable, CaseIterable, Identifiable {
  case queued
  case running
  case succeeded
  case failed
  case cancelled

  var id: String { rawValue }

  var label: String { rawValue.capitalized }

  var statusKind: StatusKind {
    switch self {
    case .queued: return .warning
    case .running: return .running
    case .succeeded: return .ready
    case .failed: return .error
    case .cancelled: return .warning
    }
  }
}

struct BackgroundJobEntry: Identifiable, Hashable, Codable {
  let id: String
  var kind: String
  var title: String
  var target: String
  var detail: String
  var progressText: String
  var state: BackgroundJobState
  var createdAt: Date
  var startedAt: Date?
  var finishedAt: Date?
  var log: String
}

struct AppSettings: Codable, Hashable {
  var defaultGitHubHost = "github.com"
  var preferDetectedWorkspace = true
  var preferVSCodeCLI = true
  var preferredEditorPath = ""
  var runDockerChecksOnRefresh = true
  var autoLoadRepoHealth = true
  var autoLoadWorkflowRuns = true
  var showAdvancedTools = false
  var keepTerminalFallbacksVisible = false
  var autoConfirmTerminalGates = true
  var privacyFirstMode = true
  var firstRunComplete = false
}

struct SavedGitHubContext: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var host: String
  var account: String
  var owner: String
}

struct RepoHealthEntry: Identifiable, Hashable {
  let slug: String
  let workflowsTotal: Int
  let workflowsEnabled: Int
  let recentRuns: Int
  let activeCodespaces: Int
  let hasLocalRunner: Bool
  let githubHostedIndicators: Int
  let riskScore: Int
  let riskLabel: String
  let summary: String

  var id: String { slug }
}

struct GitHubBillingBreakdownEntry: Identifiable, Hashable {
  let platform: String
  let minutes: Double

  var id: String { platform }
}

struct GitHubBillingSummary: Hashable {
  let owner: String
  let actionsMinutes: Double?
  let paidActionsMinutes: Double?
  let includedActionsMinutes: Double?
  let storageGBDays: Double?
  let packageGBDays: Double?
  let actionBreakdown: [GitHubBillingBreakdownEntry]
  let unavailableReports: [String]

  var actionUsageLabel: String {
    guard let actionsMinutes else { return "Unavailable" }
    return "\(Int(actionsMinutes.rounded())) min"
  }

  var paidUsageLabel: String {
    guard let paidActionsMinutes else { return "Unavailable" }
    return "\(Int(paidActionsMinutes.rounded())) min"
  }

  var storageUsageLabel: String {
    guard let storageGBDays else { return "Unavailable" }
    return String(format: "%.2f GB-days", storageGBDays)
  }

  var packageUsageLabel: String {
    guard let packageGBDays else { return "Unavailable" }
    return String(format: "%.2f GB-days", packageGBDays)
  }
}

struct StartupReadinessEntry: Identifiable, Hashable {
  let id: String
  let title: String
  let detail: String
  let kind: StatusKind
  let canAutoFix: Bool
}

struct ExternalVolumeEntry: Identifiable, Hashable {
  let path: String
  let name: String
  let totalCapacity: Int64
  let availableCapacity: Int64

  var id: String { path }

  var capacityLabel: String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    let free = formatter.string(fromByteCount: max(0, availableCapacity))
    let total = formatter.string(fromByteCount: max(0, totalCapacity))
    return "\(free) free of \(total)"
  }
}

struct WorkflowCatalogEntry: Identifiable, Hashable, Decodable {
  let id: Int
  let name: String
  let path: String
  let state: String
}

struct WorkflowRunEntry: Identifiable, Hashable, Decodable {
  let databaseId: Int64
  let name: String?
  let workflowName: String?
  let displayTitle: String?
  let event: String?
  let headBranch: String?
  let status: String?
  let conclusion: String?
  let createdAt: String?
  let updatedAt: String?

  var id: Int64 { databaseId }
}

struct CodespaceInventoryEntry: Identifiable, Hashable {
  let name: String
  let displayName: String
  let repo: String
  let state: String
  let machineName: String
  let lastUsedAt: String

  var id: String { name }
}

struct SecretRecord: Identifiable, Hashable, Decodable {
  let name: String
  let updatedAt: String?
  let visibility: String?

  var id: String { name }
}

struct GitHubIssueEntry: Identifiable, Hashable, Decodable {
  let number: Int
  let title: String
  let state: String
  let createdAt: String?
  let updatedAt: String?
  let url: String?
  let labels: [String]

  enum CodingKeys: String, CodingKey { case number, title, state, createdAt, updatedAt, url, labels }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    number = try values.decode(Int.self, forKey: .number)
    title = try values.decode(String.self, forKey: .title)
    state = try values.decode(String.self, forKey: .state)
    createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt)
    updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt)
    url = try values.decodeIfPresent(String.self, forKey: .url)
    let rawLabels = try values.decodeIfPresent([[String: String]].self, forKey: .labels) ?? []
    labels = rawLabels.compactMap { $0["name"] }.sorted()
  }

  var id: Int { number }
}

struct GitHubIssueTemplate: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var titlePrefix: String
  var body: String
  var labels: String
}

struct VariableRecord: Identifiable, Hashable, Decodable {
  let name: String
  let updatedAt: String?
  let visibility: String?

  var id: String { name }
}

struct RulesetRecord: Identifiable, Hashable {
  let id: String
  let name: String
  let target: String
  let enforcement: String
  let source: String
}

struct BranchProtectionSummary: Hashable {
  let branch: String
  let requiredStatusChecks: Int
  let requiredPullRequestReviews: Bool
  let enforceAdmins: Bool
}

struct StorageInsightEntry: Identifiable, Hashable {
  let id: String
  let label: String
  let path: String
  let sizeLabel: String
}

struct ProjectSyncEntry: Identifiable, Hashable {
  let slug: String
  let codeDirty: Bool
  let runtimeDirty: Bool
  let codeAhead: Int
  let codeBehind: Int
  let runtimeAhead: Int
  let runtimeBehind: Int
  let summary: String

  var id: String { slug }
}

struct PortMonitorEntry: Identifiable, Hashable {
  let id: String
  let proto: String
  let port: String
  let pid: String
  let processName: String
}

enum ProjectTaskLocation: String, Codable, CaseIterable, Identifiable {
  case code
  case runtime

  var id: String { rawValue }

  var label: String {
    switch self {
    case .code: return "Code"
    case .runtime: return "Runtime"
    }
  }
}

struct ProjectTaskTemplate: Identifiable, Hashable, Codable {
  let id: String
  var slug: String
  var name: String
  var command: String
  var location: ProjectTaskLocation
}

struct SavedProjectView: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var query: String
  var favoritesOnly: Bool
}

enum BackupPreset: String, CaseIterable, Identifiable {
  case codeOnly
  case runtimeOnly
  case projectBundle
  case runnerBundle
  case fullWorkspace

  var id: String { rawValue }

  var label: String {
    switch self {
    case .codeOnly: return "Code Only"
    case .runtimeOnly: return "Runtime Only"
    case .projectBundle: return "Project Bundle"
    case .runnerBundle: return "Runner Bundle"
    case .fullWorkspace: return "Full Workspace"
    }
  }
}

struct SnapshotEntry: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var createdAt: Date
  var sourceScope: String
  var destinationPath: String
  var itemCount: Int
}

struct LocalOperationPreview: Hashable {
  let kind: LocalOperationKind
  let title: String
  let destinationPath: String
  let itemCount: Int
  let totalSizeLabel: String
  let collisions: [String]
  let preparedStamp: String?
}

struct LocalTransferOperation: Hashable {
  let source: String
  let destination: String
}

struct LocalTransferOutcome {
  let warnings: [String]
}

enum LocalOperationKind: String, Hashable {
  case workspaceMove
  case localExport
}

enum ImportExecutionMode: String, CaseIterable, Identifiable {
  case codespaceToLocal
  case repoToLocal
  case repoToLocalPlus

  var id: String { rawValue }

  var label: String {
    switch self {
    case .codespaceToLocal: return "Codespace -> Local"
    case .repoToLocal: return "Repo -> Local"
    case .repoToLocalPlus: return "Repo -> Local + Devcontainer + Actions"
    }
  }

  var summary: String {
    switch self {
    case .codespaceToLocal:
      return "Best when you want a local runtime workspace, quick devcontainer validation, runner prep, and optional cleanup preview."
    case .repoToLocal:
      return "Clones the repo locally, prepares the workspace, and keeps the flow lighter without runner or workflow patching."
    case .repoToLocalPlus:
      return "Full local-prep path with devcontainer quick check, local runner install, workflow patching, and validation notes."
    }
  }

  var cliValue: String {
    switch self {
    case .codespaceToLocal: return "codespace"
    case .repoToLocal: return "repo"
    case .repoToLocalPlus: return "repo-plus"
    }
  }
}

enum LocalFileTransferMode: String, CaseIterable, Identifiable {
  case copyBackup
  case move

  var id: String { rawValue }

  var label: String {
    switch self {
    case .copyBackup: return "Copy Backup"
    case .move: return "Move"
    }
  }
}

enum LocalFileExportScope: String, CaseIterable, Identifiable {
  case selectedProjects
  case codeWorkspace
  case runtimeWorkspace
  case workspaceBundle

  var id: String { rawValue }

  var label: String {
    switch self {
    case .selectedProjects: return "Selected Projects"
    case .codeWorkspace: return "Code Workspace"
    case .runtimeWorkspace: return "Runtime Workspace"
    case .workspaceBundle: return "Full Workspace Bundle"
    }
  }
}

enum WorkspaceRelocationScope: String, CaseIterable, Identifiable {
  case workspace
  case codeRoot
  case runtimeRoot

  var id: String { rawValue }

  var label: String {
    switch self {
    case .workspace: return "Move Workspace"
    case .codeRoot: return "Move Code Root"
    case .runtimeRoot: return "Move Runtime Root"
    }
  }
}

enum WorkspaceRelocationResult {
  case single(String)
  case split(codeRoot: String, importRoot: String, runtimeRoot: String)
}

struct WorkspaceRelocationOutcome {
  let result: WorkspaceRelocationResult
  let warnings: [String]
}

enum StatusKind {
  case ready
  case warning
  case error
  case running

  var tint: Color {
    switch self {
    case .ready: return Color(red: 79 / 255, green: 169 / 255, blue: 139 / 255)
    case .warning: return Color(red: 209 / 255, green: 165 / 255, blue: 82 / 255)
    case .error: return Color(red: 196 / 255, green: 98 / 255, blue: 141 / 255)
    case .running: return Color(red: 121 / 255, green: 180 / 255, blue: 245 / 255)
    }
  }

  var icon: String {
    switch self {
    case .ready: return "checkmark.shield"
    case .warning: return "exclamationmark.triangle"
    case .error: return "xmark.octagon"
    case .running: return "waveform.path.ecg"
    }
  }
}

private enum AppDestination: String, CaseIterable, Identifiable {
  case home
  case jobs
  case incidents
  case issues
  case githubAccount
  case githubBilling
  case imports
  case projects
  case codexPortal
  case projectBackups
  case localFiles
  case cleanup
  case workspace
  case settings
  case helpCenter
  case terms
  case security
  case brandSystem
  case macOSNotes
  case projectInfo
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .home: return "Home"
    case .jobs: return "Jobs"
    case .incidents: return "Incidents"
    case .issues: return "GitHub Issues"
    case .githubAccount: return "GitHub Account"
    case .githubBilling: return "GitHub Billing Reports"
    case .imports: return "Import"
    case .projects: return "Projects"
    case .codexPortal: return "CODEX ~ GPT PORTAL"
    case .projectBackups: return "Project Backups"
    case .localFiles: return "Local Files"
    case .cleanup: return "Cleanup"
    case .workspace: return "Workspace"
    case .settings: return "Settings"
    case .helpCenter: return "Help Center"
    case .terms: return "Terms of Service"
    case .security: return "Security Notes"
    case .brandSystem: return "Brand System"
    case .macOSNotes: return "macOS App Notes"
    case .projectInfo: return "Project Info"
    case .about: return "About"
    }
  }

  var subtitle: String {
    switch self {
    case .home:
      return "Simple starting point with session state, workspace summary, and the next best actions."
    case .jobs:
      return "Track background operations, progress, status, retries, and logs without opening Terminal."
    case .incidents:
      return "Turn recoverable warnings and fatal blockers into local recovery records and reviewable issue drafts."
    case .issues:
      return "Read GitHub issues, compose locally, and apply reviewed comments, lifecycle, and label actions through the native GitHub bridge."
    case .githubAccount:
      return "Manage the connected GitHub host, account, organizations, and repository inventory from the app."
    case .githubBilling:
      return "Review GitHub Actions usage by project, organization-level usage, and links to GitHub billing reports."
    case .imports:
      return "Select repositories, choose the local import mode, and run background imports without dropping into Terminal."
    case .projects:
      return "Browse imported local projects on-screen, search them, and open them without dropping into Terminal."
    case .codexPortal:
      return "Discover Codex workspaces, preserve project data, and transfer one or many projects through a verified workflow."
    case .projectBackups:
      return "Back up one project or a complete local workflow through the same import, index, merge, verify, archive, and recovery stages."
    case .localFiles:
      return "Move workspace roots, export selected projects, and back up local data to another location or external drive."
    case .cleanup:
      return "Choose repositories, review scope, and run cleanup in the GUI while the CLI works in the background."
    case .workspace:
      return "Set where your local data lives, use the standard setup, or apply the detected setup on this Mac."
    case .settings:
      return "Control onboarding, preferred paths, advanced visibility, saved contexts, and GUI-first defaults."
    case .helpCenter:
      return "Operational guidance, safety model, target selection rules, and first-run workflow."
    case .terms:
      return "Every-launch responsibility, risk acceptance, and authorized-use conditions."
    case .security:
      return "Secret handling, token safety, stored-data scope, and review notes."
    case .brandSystem:
      return "Official logo, icon, color, and artwork usage requirements for production consistency."
    case .macOSNotes:
      return "Native app packaging, icon, installer, and macOS integration guidance."
    case .projectInfo:
      return "Bundle metadata, resource map, product identity, and project-level implementation notes."
    case .about:
      return "Product identity, company details, bundle state, install details, and local app storage."
    }
  }

  var icon: String {
    switch self {
    case .home: return "house"
    case .jobs: return "list.bullet.rectangle.portrait"
    case .incidents: return "exclamationmark.bubble"
    case .issues: return "checklist"
    case .githubAccount: return "person.crop.circle"
    case .githubBilling: return "chart.bar.xaxis"
    case .imports: return "square.and.arrow.down.on.square"
    case .projects: return "shippingbox"
    case .codexPortal: return "terminal"
    case .projectBackups: return "externaldrive.badge.timemachine"
    case .localFiles: return "folder.badge.gearshape"
    case .cleanup: return "trash"
    case .workspace: return "internaldrive"
    case .settings: return "gearshape"
    case .helpCenter: return "questionmark.circle"
    case .terms: return "checklist"
    case .security: return "lock.shield"
    case .brandSystem: return "paintpalette"
    case .macOSNotes: return "laptopcomputer"
    case .projectInfo: return "shippingbox"
    case .about: return "info.circle"
    }
  }

  var tint: Color {
    switch self {
    case .home: return DashboardTheme.accent
    case .jobs: return DashboardTheme.warning
    case .incidents: return DashboardTheme.danger
    case .issues: return DashboardTheme.warning
    case .githubAccount: return DashboardTheme.link
    case .githubBilling: return DashboardTheme.warning
    case .imports: return DashboardTheme.success
    case .projects: return DashboardTheme.deepBlue
    case .codexPortal: return DashboardTheme.success
    case .projectBackups: return DashboardTheme.deepBlue
    case .localFiles: return DashboardTheme.warning
    case .cleanup: return DashboardTheme.warning
    case .workspace: return DashboardTheme.success
    case .settings: return DashboardTheme.accentPink
    case .helpCenter: return DashboardTheme.success
    case .terms: return DashboardTheme.warning
    case .security: return DashboardTheme.deepBlue
    case .brandSystem: return DashboardTheme.brightPink
    case .macOSNotes: return DashboardTheme.accentPink
    case .projectInfo: return DashboardTheme.success
    case .about: return DashboardTheme.link
    }
  }

  var bundleDocumentName: String? {
    switch self {
    case .helpCenter: return "Help-Center.md"
    case .terms: return "TERMS-OF-SERVICE.md"
    case .security: return "SECURITY.md"
    case .brandSystem: return "Brand-System.md"
    case .macOSNotes: return "macOS-App-Notes.md"
    case .projectInfo: return "PROJECT-INFO.md"
    case .home, .jobs, .incidents, .issues, .githubAccount, .githubBilling, .imports, .projects, .codexPortal, .projectBackups, .localFiles, .cleanup, .workspace, .settings, .about: return nil
    }
  }

  var fallbackDocumentText: String {
    switch self {
    case .terms:
      return bundledTermsOfServiceText()
    case .about:
      return ""
    default:
      return "This bundled document is missing from the current app package."
    }
  }
}

private let workspaceDestinations: [AppDestination] = [.home, .jobs, .incidents, .issues, .githubAccount, .githubBilling, .imports, .projects, .codexPortal, .projectBackups, .localFiles, .cleanup, .workspace, .settings, .about]
private let knowledgeDestinations: [AppDestination] = [.helpCenter, .terms, .security, .brandSystem, .macOSNotes, .projectInfo]

@MainActor
final class CleanupViewModel: ObservableObject {
  @Published var selectedProfile: LaunchProfile = .public {
    didSet {
      if selectedProfile != oldValue {
        safetyArmEnabled = false
        syncWorkspaceDraftsFromResolvedRoots()
        refreshLocalProjects()
      }
    }
  }
  @Published var useCurrentRoot = true {
    didSet {
      if useCurrentRoot != oldValue {
        syncWorkspaceDraftsFromResolvedRoots()
        refreshLocalProjects()
      }
    }
  }
  @Published var workspaceSingleRootDraft = publicDefaultRoot
  @Published var workspaceCodeRootDraft = publicDefaultCodeRoot
  @Published var workspaceImportRootDraft = publicDefaultImportRoot
  @Published var workspaceRuntimeRootDraft = publicDefaultRuntimeRoot
  @Published var workspaceMoveDestinationDraft = ""
  @Published var localExportDestinationDraft = ""
  @Published var projectMoveDestinationDraft = ""
  @Published var host = "github.com" {
    didSet {
      if host != oldValue {
        stage2SafetyArmed = false
        codexLifecycleSafetyArmed = false
        isAuthenticated = false
        clearRepoCatalog(resetOwner: false)
        reloadAccountChoices()
        refreshAuthStatus()
        if host != oldValue {
          safetyArmEnabled = false
        }
      }
    }
  }
  @Published var account = "" {
    didSet {
      if account != oldValue {
        stage2SafetyArmed = false
        codexLifecycleSafetyArmed = false
        if repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || repoOwner == oldValue {
          repoOwner = account
        }
        clearRepoCatalog(resetOwner: false)
        if isAuthenticated && !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          fetchAvailableRepos()
        }
      }
    }
  }
  @Published var repoTarget = "" {
    didSet {
      if repoTarget != oldValue {
        safetyArmEnabled = false
      }
    }
  }
  @Published var repoOwner = "" {
    didSet {
      if repoOwner != oldValue {
        clearRepoCatalog(resetOwner: false)
      }
    }
  }
  @Published var repoSearch = ""
  @Published var localProjectSearch = ""
  @Published var codexProjectSearch = ""
  @Published var codexScanRootsDraft = NSString(string: "~/Documents").expandingTildeInPath
  @Published var codexScanRootEntryDraft = ""
  @Published var isCodexScanRootDropTarget = false
  @Published var codexOutputRootDraft = NSString(string: "~/CODEX PROJECTS").expandingTildeInPath {
    didSet {
      UserDefaults.standard.set(codexOutputRootDraft, forKey: codexOutputRootKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexTransferMode: CodexProjectTransferMode = .backupOnly {
    didSet {
      UserDefaults.standard.set(codexTransferMode.rawValue, forKey: codexTransferModeKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexSmartScanMode: CodexSmartScanMode = .fastIndex {
    didSet {
      UserDefaults.standard.set(codexSmartScanMode.rawValue, forKey: codexSmartScanModeKey)
      switch codexSmartScanMode {
      case .fastIndex, .yolo:
        codexFullChecksumAudit = false
      case .verified:
        codexFullChecksumAudit = true
      }
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexBackupMedium: CodexBackupMedium = .rawDirectory {
    didSet {
      UserDefaults.standard.set(codexBackupMedium.rawValue, forKey: codexBackupMediumKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexCreateBackup = false {
    didSet {
      UserDefaults.standard.set(codexCreateBackup, forKey: codexCreateBackupKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexIncludeGitMetadata = true {
    didSet {
      UserDefaults.standard.set(codexIncludeGitMetadata, forKey: codexIncludeGitMetadataKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexIncludeFinderMetadata = true {
    didSet {
      UserDefaults.standard.set(codexIncludeFinderMetadata, forKey: codexIncludeFinderMetadataKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexIncludeDependencies = false {
    didSet {
      UserDefaults.standard.set(codexIncludeDependencies, forKey: codexIncludeDependenciesKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexFullChecksumAudit = false {
    didSet {
      UserDefaults.standard.set(codexFullChecksumAudit, forKey: codexFullChecksumAuditKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexCreateCompatibilityLink = true {
    didSet {
      UserDefaults.standard.set(codexCreateCompatibilityLink, forKey: codexCreateCompatibilityLinkKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexRearmGitMain = true {
    didSet {
      UserDefaults.standard.set(codexRearmGitMain, forKey: codexRearmGitMainKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexAutoResumeExisting = true {
    didSet {
      UserDefaults.standard.set(codexAutoResumeExisting, forKey: codexAutoResumeExistingKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2SourceRootDraft = NSString(string: "~/CODEX PROJECTS").expandingTildeInPath {
    didSet {
      UserDefaults.standard.set(stage2SourceRootDraft, forKey: stage2SourceRootKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2ManagedRootDraft = publicDefaultRoot {
    didSet {
      UserDefaults.standard.set(stage2ManagedRootDraft, forKey: stage2ManagedRootKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2GitHubOwnerAccountsDraft = "" {
    didSet {
      UserDefaults.standard.set(stage2GitHubOwnerAccountsDraft, forKey: stage2GitHubOwnerAccountsKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2CreateMissingRepos = false {
    didSet {
      UserDefaults.standard.set(stage2CreateMissingRepos, forKey: stage2CreateMissingReposKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2SourceRetention: Stage2SourceRetention = .keep {
    didSet {
      UserDefaults.standard.set(stage2SourceRetention.rawValue, forKey: stage2SourceRetentionKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2ArchiveSources = false {
    didSet {
      UserDefaults.standard.set(stage2ArchiveSources, forKey: stage2ArchiveSourcesKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2CleanupTransactionTemp = true {
    didSet {
      UserDefaults.standard.set(stage2CleanupTransactionTemp, forKey: stage2CleanupTransactionTempKey)
      stage2SafetyArmed = false
    }
  }
  @Published var stage2PrepareRuntime = false {
    didSet {
      UserDefaults.standard.set(stage2PrepareRuntime, forKey: stage2PrepareRuntimeKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2OpenAfterApply: Stage2OpenOption = .none {
    didSet {
      UserDefaults.standard.set(stage2OpenAfterApply.rawValue, forKey: stage2OpenAfterApplyKey)
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var stage2SafetyArmed = false
  @Published var stage2Status = "Scan the Stage 1 folder, review GitHub identity and worktree state, then preflight selected projects or run safety-gated Full Auto."
  @Published var codexLifecycleScope: CodexLifecycleScope = .selected {
    didSet {
      UserDefaults.standard.set(codexLifecycleScope.rawValue, forKey: codexLifecycleScopeKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexLifecycleDeleteStage1Originals = false {
    didSet {
      UserDefaults.standard.set(codexLifecycleDeleteStage1Originals, forKey: codexLifecycleDeleteStage1Key)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexLifecycleRunStage2 = true {
    didSet {
      UserDefaults.standard.set(codexLifecycleRunStage2, forKey: codexLifecycleRunStage2Key)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexLifecycleCleanupScope: CodexLifecycleCleanupScope = .currentTransaction {
    didSet {
      UserDefaults.standard.set(codexLifecycleCleanupScope.rawValue, forKey: codexLifecycleCleanupScopeKey)
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexLifecycleSafetyArmed = false
  @Published var codexLifecycleStatus = "Preflight Stage 1, then run the selected or all-project lifecycle through verified Stage 2 and receipt-linked Stage 3 cleanup."
  @Published var administratorTerminalMode = false
  @Published var savedViewNameDraft = ""
  @Published var contextNameDraft = ""
  @Published var taskNameDraft = ""
  @Published var taskCommandDraft = ""
  @Published var taskLocationDraft: ProjectTaskLocation = .runtime
  @Published var importMode: ImportExecutionMode = .codespaceToLocal {
    didSet {
      if importMode == .repoToLocal {
        importCleanupPreview = false
      }
    }
  }
  @Published var importCleanupPreview = false
  @Published var fullCleanup = true
  @Published var disableWorkflows = true
  @Published var deleteRuns = true
  @Published var deleteArtifacts = true
  @Published var deleteCaches = true
  @Published var deleteCodespaces = false
  @Published var dryRun = false
  @Published var runTarget = ""
  @Published var runFilter = ""
  @Published var safetyArmEnabled = false
  @Published var localFileTransferMode: LocalFileTransferMode = .copyBackup
  @Published var localFileExportScope: LocalFileExportScope = .selectedProjects
  @Published var includeProjectCodeExport = true
  @Published var includeProjectRuntimeExport = true
  @Published var includeProjectRunnerExport = true
  @Published var overwriteLocalFileDestination = false
  @Published var showFavoritesOnly = false
  @Published var selectedBackupPreset: BackupPreset = .projectBundle
  @Published var localOperationPreview: LocalOperationPreview?
  @Published var localExportPreparedStamp = ""
  @Published var legacyWorkspaceCandidates: [LegacyWorkspaceCandidate] = []
  @Published var selectedLegacyWorkspaceID = ""
  @Published var legacyWorkspaceScanStatus = "Scan for older CSA-iEM workspace roots before migrating projects."
  @Published var recoverySourcePath = ""
  @Published var recoverySourceStatus = "Choose an old or partially moved workspace to scan before recovering files."
  @Published var recoveryCandidate: LegacyWorkspaceCandidate?
  @Published var appSettings = AppSettings()

  @Published var availableHosts: [String] = []
  @Published var availableAccounts: [String] = []
  @Published var availableRepos: [RepoCatalogEntry] = []
  @Published var localProjects: [LocalProjectEntry] = []
  @Published var codexProjects: [CodexProjectEntry] = []
  @Published var selectedCodexProjectPaths: Set<String> = [] {
    didSet {
      guard selectedCodexProjectPaths != oldValue else { return }
      codexTransferPlans.removeAll()
      codexCanonicalSourceByGroup.removeAll()
      stage2SafetyArmed = false
      codexLifecycleSafetyArmed = false
    }
  }
  @Published var codexTransferPlans: [CodexTransferPlan] = []
  @Published var codexSmartDecisions: [CodexSmartDecision] = []
  @Published var codexReviewDispositions: [String: CodexReviewDisposition] = [:]
  @Published var codexReviewAudit: [CodexReviewAuditEntry] = []
  @Published var codexSourceDeltas: [CodexSourceDelta] = []
  @Published var codexScanDeltaStatus = "No prior scan baseline is available; the first scan evaluates all discovered sources."
  @Published var codexGroupReviewStatus = "No group has been re-evaluated from the saved decision evidence."
  @Published var codexAdvisoryProviderKind: CodexAdvisoryProviderKind = .lmStudio
  @Published var codexAdvisory: CodexAIAdvisory?
  @Published var codexAdvisoryStatus = "No local advisory requested. Deterministic Smart Logic remains authoritative."
  @Published var codexCanonicalSourceByGroup: [String: String] = [:]
  @Published var codexCatalogStatus = "SQLite catalog will be created on the first decision scan."
  @Published var codexActiveSessionID = ""
  @Published var codexSessionDiffSummary: CodexSessionDiffSummary?
  @Published var codexRecentSessions: [CodexCatalogSessionSummary] = []
  @Published var codexComparisonSessionID = ""
  @Published var codexComparisonGroupKey = ""
  @Published var codexEvidenceProvenanceFilter: CodexEvidenceProvenanceFilter = .all
  @Published var codexComparisonDeltas: [CodexSourceDelta] = []
  @Published var codexDecisionComparisonRows: [CodexDecisionComparisonRow] = []
  @Published var codexComparisonBaselineSessionID = ""
  @Published var codexComparisonExportStatus = ""
  @Published var codexRouteReceiptExportStatus = ""
  @Published var codexRouteReceiptBaselineAuditExportStatus = ""
  @Published var codexImportedRouteReceiptBundle: CodexRouteReceiptExportBundle?
  @Published var codexImportedRouteReceiptHistory: [CodexImportedRouteReceiptRecord] = []
  @Published var codexImportedRouteReceiptStatus = "No external route receipt bundle loaded."
  @Published var codexRouteReceiptBaselineDecision: CodexRouteReceiptBaselineDecision?
  @Published var codexRouteReceiptBaselineAudit: [CodexRouteReceiptBaselineAuditEvent] = []
  @Published var codexSelectedRouteReceiptBaselineAuditID: String?
  @Published var codexImportedBaselineAuditEvents: [CodexRouteReceiptBaselineAuditEvent] = []
  @Published var codexImportedBaselineAuditHistory: [CodexImportedBaselineAuditRecord] = []
  @Published var codexRejectedBaselineAuditImports: [CodexRejectedBaselineAuditImport] = []
  @Published var codexImportedBaselineAuditStatus = "No external baseline-audit bundle loaded."
  @Published var codexImportedEvidenceBundle: CodexComparisonEvidenceBundle?
  @Published var codexImportedEvidenceHistory: [CodexImportedEvidenceRecord] = []
  @Published var codexEvidenceHistoryFilter: CodexEvidenceHistoryFilter = .all
  @Published var codexImportedEvidenceStatus = "No external comparison evidence loaded."
  @Published var codexComparisonStatus = "Select a saved session after the first scan to inspect source-level changes."
  @Published var codexBaselineRebuildReason = ""
  private var codexResumeOriginalSelection: Set<String>?
  @Published var activeContainers: [LiveContainerEntry] = []
  @Published var runnerServices: [RunnerServiceEntry] = []
  @Published var viewerOrganizations: [String] = []
  @Published var backgroundJobs: [BackgroundJobEntry] = []
  @Published var incidents: [CSAiEMIncident] = []
  @Published var selectedIncidentID: String?
  @Published var selectedIncidentClusterKey: String?
  @Published var githubIssues: [GitHubIssueEntry] = []
  @Published var selectedIssueNumber: Int?
  @Published var issueTemplates: [GitHubIssueTemplate] = []
  @Published var selectedIssueTemplateID: String?
  @Published var issueDraftTitle = ""
  @Published var issueDraftBody = ""
  @Published var issueDraftLabels = ""
  @Published var issueStatus = "Load issues for the selected repository."
  @Published var isLoadingIssues = false
  @Published var issueWriteArmed = false
  @Published var selectedIssueMutation: CSAiEMGitHubIssueMutation = .comment
  @Published var issueMutationBody = ""
  @Published var issueMutationLabels = ""
  @Published var issueMutationStatus = "Select a loaded issue before preparing a remote update."
  @Published var issueMutationArmed = false
  @Published var issueMutationRetries: [CSAiEMGitHubIssueRetryRecord] = []
  private var issueMutationRetryCommands: [String: CSAiEMGitHubIssueCommand] = [:]
  @Published var selectedJobID: String?
  @Published var savedContexts: [SavedGitHubContext] = []
  @Published var favoriteProjects: Set<String> = []
  @Published var savedProjectViews: [SavedProjectView] = []
  @Published var taskTemplates: [ProjectTaskTemplate] = []
  @Published var snapshots: [SnapshotEntry] = []
  @Published var repoHealthEntries: [RepoHealthEntry] = []
  @Published var researchSnapshot: CSAiEMResearchSnapshot?
  @Published var workflows: [WorkflowCatalogEntry] = []
  @Published var workflowRuns: [WorkflowRunEntry] = []
  @Published var codespaces: [CodespaceInventoryEntry] = []
  @Published var repoSecrets: [SecretRecord] = []
  @Published var orgSecrets: [SecretRecord] = []
  @Published var repoVariables: [VariableRecord] = []
  @Published var orgVariables: [VariableRecord] = []
  @Published var rulesets: [RulesetRecord] = []
  @Published var branchProtectionSummary: BranchProtectionSummary?
  @Published var githubBillingSummary: GitHubBillingSummary?
  @Published var storageInsights: [StorageInsightEntry] = []
  @Published var projectSyncEntries: [ProjectSyncEntry] = []
  @Published var portMonitorEntries: [PortMonitorEntry] = []
  @Published var startupReadiness: [StartupReadinessEntry] = []
  @Published var externalVolumes: [ExternalVolumeEntry] = []
  @Published var selectedExternalVolumePath = ""
  @Published var externalDefaultMoveConfirmed = false
  @Published var externalWorkspaceSizeLabel = "Prepare Move uses the current roots to show the relocation destination and collision risk before anything changes."
  @Published var selectedRepos: Set<String> = [] {
    didSet {
      if selectedRepos != oldValue {
        safetyArmEnabled = false
      }
    }
  }
  @Published var repoCatalogStatus = "Load repositories for the selected GitHub account or owner."
  @Published var importStatus = "Select one or more repositories, choose the import mode, and run the import in the background."
  @Published var localProjectStatus = "Scan local imported projects for the current workspace roots."
  @Published var codexPortalStatus = "Choose one source set and one final destination. Smart Logic will index first, then show what needs review."
  @Published var codexPortalProgressText = "Ready to scan."
  @Published var codexPortalProgress = 0.0
  @Published var codexLocalDevStatus = "Select one discovered project with a supported local development script."
  @Published var codexLocalDevProjectPath: String?
  @Published var codexLocalDevCommand = ""
  @Published var liveServicesStatus = "Scan active local devcontainers and runner services for the current workspace."
  @Published var githubAccountStatus = "Refresh the connected account to load organizations and account-level details."
  @Published var localFilesStatus = "Choose a destination and move or export local files from the current workspace."
  @Published var settingsStatus = "Use the settings page to control onboarding, saved contexts, and advanced GUI defaults."
  @Published var jobCenterStatus = "Background jobs will appear here as the app runs local and GitHub operations."
  @Published var repoHealthStatus = "Load repository health to inspect workflow state, local runner coverage, run activity, and cost risk."
  @Published var researchStatus = "Select one repository to build a read-only intelligence snapshot."
  @Published var workflowStatus = "Select a repository target to inspect workflows, runs, and GitHub Actions administration details."
  @Published var codespacesStatus = "Load Codespaces after selecting a repository target."
  @Published var secretsStatus = "Load secrets and variables for the selected repository or owner."
  @Published var rulesStatus = "Load branch protection and rulesets for the selected repository."
  @Published var githubBillingStatus = "Load GitHub Actions usage and available account or organization billing reports."
  @Published var storageStatus = "Load storage insights for the current workspace."
  @Published var syncStatus = "Load project sync status to compare code and runtime worktrees."
  @Published var portsStatus = "Scan local listening ports and service endpoints."
  @Published var taskStatus = "Create reusable per-project tasks and run them from the GUI."
  @Published var startupReadinessStatus = "Checking local tools and GitHub CLI login state."
  @Published var externalVolumesStatus = "Scan for mounted external drives to use as a backup or move destination."
  @Published var snapshotStatus = "Create point-in-time snapshots before major local file changes."
  @Published var logText = "[gui] CSA-iEM ready.\n"
  @Published var statusTitle = "Checking GitHub CLI"
  @Published var statusDetail = "Loading local GitHub configuration."
  @Published var statusKind: StatusKind = .running
  @Published var isRunning = false
  @Published var isAuthenticated = false
  @Published var isLoggingOut = false
  @Published var isLoadingRepos = false
  @Published var isLoadingLocalProjects = false
  @Published var isScanningCodexProjects = false
  @Published var isBuildingCodexTransferPlan = false
  @Published var isRunningCodexTransfer = false
  @Published var isLoadingLiveServices = false
  @Published var isLoadingGitHubAccountDetails = false
  @Published var isRunningLocalFileOperation = false
  @Published var isLoadingRepoHealth = false
  @Published var isLoadingResearchSnapshot = false
  @Published var isLoadingWorkflowData = false
  @Published var isLoadingCodespaces = false
  @Published var isLoadingSecretsData = false
  @Published var isLoadingRulesData = false
  @Published var isLoadingGitHubBilling = false
  @Published var isLoadingStorageInsights = false
  @Published var isLoadingProjectSync = false
  @Published var isLoadingPorts = false
  @Published var isRunningTask = false
  @Published var isRunningCodexLocalDev = false

  private var hostConfigs: [AuthHostConfig] = []
  private var runningProcess: Process?
  private var codexLocalDevProcess: Process?
  private var codexLocalDevJobID: String?
  private var activeJobID: String?
  private var pendingRepoTargets: [String] = []
  private var completedRepoTargets: [String] = []
  private var failedRepoTargets: [String] = []
  private var activeRepoTarget = ""
  private var totalRepoTargets = 0
  private var cancellationRequested = false
  private var isAutoRecoveringWorkspace = false
  private var codexCatalogStore: CodexCatalogStore?
  private let processQueue = DispatchQueue(label: "com.waynetechlab.csaiem.process", qos: .userInitiated)

  init() {
    bootstrap()
  }

  private static let defaultIssueTemplates: [GitHubIssueTemplate] = [
    GitHubIssueTemplate(id: "incident", name: "Automation incident", titlePrefix: "[CSA-iEM] ", body: "## What happened\n\n## Correlated evidence\n\n## Recovery attempted\n\n## Expected next action\n", labels: "csa-iem,incident"),
    GitHubIssueTemplate(id: "bug", name: "Bug report", titlePrefix: "Bug: ", body: "## Summary\n\n## Steps to reproduce\n\n## Expected behavior\n\n## Actual behavior\n\n## Environment\n", labels: "bug"),
    GitHubIssueTemplate(id: "recovery", name: "Recovery task", titlePrefix: "Recovery: ", body: "## Affected project\n\n## Last confirmed checkpoint\n\n## Safe recovery plan\n\n## Validation required\n", labels: "recovery,csa-iem")
  ]

  private var cliRootPath: String? {
    let fm = FileManager.default

    if let envRoot = ProcessInfo.processInfo.environment["CSA_IEM_ROOT"], !envRoot.isEmpty {
      let directScript = (envRoot as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: directScript) {
        return envRoot
      }
    }

    if let bundledCLI = Bundle.main.resourceURL?.appendingPathComponent("CLI").path {
      let bundledScript = (bundledCLI as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: bundledScript) {
        return bundledCLI
      }
    }

    if let resourceRoot = Bundle.main.resourceURL?.path {
      let directScript = (resourceRoot as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: directScript) {
        return resourceRoot
      }
    }

    let cwd = fm.currentDirectoryPath
    let cwdScript = (cwd as NSString).appendingPathComponent("CSA-iLEM.sh")
    if fm.isExecutableFile(atPath: cwdScript) {
      return cwd
    }

    return nil
  }

  var cliPath: String? {
    let fm = FileManager.default

    if let cliRootPath {
      let bundled = (cliRootPath as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: bundled) {
        return bundled
      }
    }

    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent("csa-iem")
      if fm.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }

    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent("csa-ilem")
      if fm.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }

    return nil
  }

  var ghPath: String? {
    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent("gh")
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }

    return nil
  }

  var dockerPath: String? {
    executablePath(named: "docker")
  }

  var bundledIcon: NSImage? {
    guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
      return NSWorkspace.shared.icon(for: .application)
    }
    return NSImage(contentsOf: iconURL)
  }

  var bundledBrandMark: NSImage? {
    if let appIconURL = bundledResourceURL(named: "appicon-512x512@2x.png", subdirectory: "AppIcon.appiconset"),
       let appIconImage = NSImage(contentsOf: appIconURL) {
      return appIconImage
    }
    return bundledImage(named: "icon-1024.png") ?? bundledImage(named: "logo-card-square.png")
  }

  var bundledLockup: NSImage? {
    bundledImage(named: "logo-horizontal-lockup.png")
  }

  var bundledHero: NSImage? {
    bundledImage(named: "hero-2560x1600.png")
  }

  var bundleIdentitySummary: String {
    "\(Bundle.main.bundleIdentifier ?? "com.waynetechlab.csaiem") · Version \(appVersion)"
  }

  var canRunCleanup: Bool {
    !isRunning &&
      cliPath != nil &&
      ghPath != nil &&
      isAuthenticated &&
      !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !cleanupTargets.isEmpty &&
      (fullCleanup || disableWorkflows || deleteRuns || deleteArtifacts || deleteCaches || deleteCodespaces) &&
      safetyArmEnabled &&
      statusKind != .error
  }

  var canRunImport: Bool {
    !isRunning &&
      cliPath != nil &&
      ghPath != nil &&
      isAuthenticated &&
      !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !cleanupTargets.isEmpty &&
      statusKind != .error
  }

  var selectedHostConfig: AuthHostConfig? {
    hostConfigs.first(where: { $0.host == host.trimmingCharacters(in: .whitespacesAndNewlines) })
  }

  var authHeadline: String {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "github.com" : host.trimmingCharacters(in: .whitespacesAndNewlines)
    if isAuthenticated {
      return "GitHub Ready @ \(selectedHost)"
    }
    return "GitHub Login Required @ \(selectedHost)"
  }

  var authSummary: String {
    let resolvedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    if isAuthenticated && !resolvedAccount.isEmpty {
      return "User \(resolvedAccount) on account \(resolvedAccount) ready on \(resolvedHost)."
    }
    return "No authenticated GitHub account is ready for cleanup."
  }

  var authActionHint: String {
    if isAuthenticated {
      return "Selected account is ready. You can refresh, log out, or continue to repository cleanup."
    }
    return "Log in with GitHub CLI first, then select the account you want to use."
  }

  var sessionCompactLabel: String {
    let resolvedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "github.com" : host.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let accountValue = resolvedAccount.isEmpty ? (selectedHostConfig?.activeUser ?? "no account") : resolvedAccount
    return isAuthenticated ? "\(accountValue) @ \(resolvedHost) ready" : "Login required @ \(resolvedHost)"
  }

  var selectionCompactLabel: String {
    let count = cleanupTargets.count
    if count == 0 {
      return "No targets selected"
    }
    if count == 1, let target = cleanupTargets.first {
      return target
    }
    return "\(count) targets selected"
  }

  var statusCompactLabel: String {
    let trimmedTitle = statusTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedTitle.isEmpty {
      return "Idle"
    }
    return trimmedTitle
  }

  var activeOperationLabel: String? {
    if isRunningLocalFileOperation { return "Moving or exporting local files…" }
    if isLoadingLocalProjects { return "Scanning local folders for Git and Docker projects…" }
    if isLoadingLiveServices { return "Checking Docker containers and runner services…" }
    if isRunningCodexLocalDev { return "Running the selected local development session…" }
    if isRunningTask { return "Running the selected project task…" }
    if isRunning { return "Running GitHub cleanup…" }
    if isLoadingGitHubBilling { return "Loading GitHub usage and billing reports…" }
    if isLoadingRepoHealth { return "Loading repository health…" }
    if isLoadingWorkflowData { return "Loading workflow and run data…" }
    if isLoadingRepos { return "Loading repositories…" }
    if isLoadingGitHubAccountDetails { return "Refreshing connected account…" }
    if isLoadingStorageInsights { return "Calculating local storage usage…" }
    if isLoadingProjectSync { return "Comparing local project worktrees…" }
    if isLoadingPorts { return "Scanning listening ports…" }
    return nil
  }

  var resolvedProfileRootsForDisplay: (codeRoot: String, importRoot: String, runtimeRoot: String) {
    resolvedProfileRoots()
  }

  var lastSessionSummary: String? {
    nil
  }

  var filteredRepos: [RepoCatalogEntry] {
    let query = repoSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else {
      return availableRepos
    }

    return availableRepos.filter { repo in
      repo.nameWithOwner.lowercased().contains(query) ||
      repo.shortName.lowercased().contains(query) ||
      repo.owner.lowercased().contains(query) ||
      (repo.visibility?.lowercased().contains(query) ?? false)
    }
  }

  var filteredLocalProjects: [LocalProjectEntry] {
    let query = localProjectSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return localProjects.filter { project in
      let matchesQuery = query.isEmpty || project.searchableText.contains(query)
      let matchesFavorite = !showFavoritesOnly || favoriteProjects.contains(project.slug)
      return matchesQuery && matchesFavorite
    }
  }

  var filteredCodexProjects: [CodexProjectEntry] {
    let query = codexProjectSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return codexProjects }
    return codexProjects.filter { $0.searchableText.contains(query) }
  }

  var selectedCodexProjects: [CodexProjectEntry] {
    codexProjects.filter { selectedCodexProjectPaths.contains($0.path) }
  }

  var isCodexPortalBusy: Bool {
    isScanningCodexProjects || isBuildingCodexTransferPlan || isRunningCodexTransfer
  }

  var stage2SelectedProjects: [CodexProjectEntry] {
    let sourceRoot = normalizeWorkspacePath(stage2SourceRootDraft)
    return selectedCodexProjects.filter { project in
      let projectPath = normalizeWorkspacePath(project.path)
      return projectPath == sourceRoot || projectPath.hasPrefix(sourceRoot + "/")
    }
  }

  var stage2SelectionSummary: String {
    let sourceRoot = normalizeWorkspacePath(stage2SourceRootDraft)
    let discoveredCount = codexProjects.filter { project in
      let projectPath = normalizeWorkspacePath(project.path)
      return projectPath == sourceRoot || projectPath.hasPrefix(sourceRoot + "/")
    }.count
    return "\(discoveredCount) Stage 1 project(s) found · \(stage2SelectedProjects.count) selected · managed root \(normalizeWorkspacePath(stage2ManagedRootDraft))"
  }

  var codexStage2GroupBlockerSummaries: [String] {
    Dictionary(grouping: codexActiveSmartDecisions, by: \.groupKey).compactMap { groupKey, groupDecisions in
      let blockers = groupDecisions.filter { decision in
        switch decision.classification {
        case .shadowCopy, .brokenMetadataReview, .unknownOwnerReview, .fatalIdentityConflict, .sameNameReview:
          return true
        case .canonical, .mergeCandidate, .unrelated:
          return false
        }
      }
      guard !blockers.isEmpty, groupDecisions.count > 1 else { return nil }
      let names = blockers.map { $0.evidence.name }.sorted().joined(separator: ", ")
      let selectedLead = codexCanonicalSourceByGroup[groupKey].map { " Canonical source selected: \($0)." } ?? " No canonical source has been selected."
      return "Group \(groupKey) is blocked for Stage 2 apply by review source(s): \(names).\(selectedLead) Resolve or explicitly exclude every unresolved source before arming workspace writes."
    }
    .sorted()
  }

  var codexStage2ApplyBlocked: Bool {
    !codexStage2GroupBlockerSummaries.isEmpty
  }

  var areAllVisibleCodexProjectsSelected: Bool {
    !filteredCodexProjects.isEmpty && filteredCodexProjects.allSatisfy { selectedCodexProjectPaths.contains($0.path) }
  }

  var codexProjectSummary: String {
    let selectedCount = selectedCodexProjectPaths.count
    let activeCount = codexProjects.filter { $0.ideState == .active }.count
    let linkedCount = codexProjects.filter { $0.ideState == .linked }.count
    let unlinkedCount = codexProjects.filter { $0.ideState == .unlinked }.count
    let synchronizedMainCount = codexProjects.filter { $0.gitStatus.isMainSynchronized }.count
    return "\(codexProjects.count) found · Codex \(activeCount) active here / \(linkedCount) linked / \(unlinkedCount) unlinked · \(synchronizedMainCount) main synced · \(selectedCount) selected"
  }

  var codexTransferPlanSummary: String {
    guard !codexTransferPlans.isEmpty else {
      return "Run preflight to build the virtual file-transfer table."
    }
    let plannedPathCount = codexTransferPlans.reduce(0) { $0 + $1.plannedPaths.count }
    let plannedByteCount = codexTransferPlans.reduce(Int64(0)) { $0 + $1.plannedByteCount }
    let initialMirrors = codexTransferPlans.filter(\.requiresInitialMirror).count
    let destinationOnly = codexTransferPlans.reduce(0) { $0 + $1.destinationOnlyPaths.count }
    let cachedPlans = codexTransferPlans.filter { $0.usedVerifiedCache == true }.count
    let prefix: String
    if initialMirrors > 0 {
      prefix = "\(initialMirrors) initial mirror(s)"
    } else if cachedPlans == codexTransferPlans.count {
      prefix = "\(cachedPlans) verified cache hit(s)"
    } else if cachedPlans > 0 {
      prefix = "Index ready · \(cachedPlans) cache hit(s)"
    } else {
      prefix = "Index ready"
    }
    return "\(prefix) · \(plannedPathCount) path(s) planned · \(ByteCountFormatter.string(fromByteCount: plannedByteCount, countStyle: .file)) · \(destinationOnly) destination-only"
  }

  var codexSmartIndexPath: String {
    let outputRoot = normalizeWorkspacePath(codexOutputRootDraft)
    return (outputRoot as NSString).appendingPathComponent("_temp/Transfer-Indexes")
  }

  var codexSmartIndexStatus: String {
    if let codexCatalogStore {
      let base = codexCatalogStore.status
      if let checkpoint = codexCatalogStore.latestCheckpointSummary() {
        return "\(base) · latest checkpoint \(checkpoint)"
      }
      return base
    }
    let indexPath = codexSmartIndexPath
    return FileManager.default.fileExists(atPath: indexPath) ? "Saved transfer index available" : "No saved index yet"
  }

  var codexSmartGroupSummaries: [CodexSmartGroupSummary] {
    CodexSmartLogicEngine.groupSummaries(codexActiveSmartDecisions)
  }

  var codexActiveSmartDecisions: [CodexSmartDecision] {
    CodexSmartLogicEngine.activeDecisions(codexSmartDecisions, dispositions: codexReviewDispositions)
  }

  var codexExcludedSmartDecisions: [CodexSmartDecision] {
    codexSmartDecisions.filter { codexReviewDispositions[$0.sourcePath] == .excluded }
  }

  var codexVisibleComparisonDeltas: [CodexSourceDelta] {
    guard !codexComparisonGroupKey.isEmpty else { return codexComparisonDeltas }
    let paths = Set(codexSmartDecisions.filter { $0.groupKey == codexComparisonGroupKey }.map(\.sourcePath))
    return codexComparisonDeltas.filter { paths.contains($0.sourcePath) }
  }

  var codexVisibleDecisionComparisonRows: [CodexDecisionComparisonRow] {
    guard !codexComparisonGroupKey.isEmpty else { return codexDecisionComparisonRows }
    return codexDecisionComparisonRows.filter { $0.currentGroupKey == codexComparisonGroupKey || $0.previousGroupKey == codexComparisonGroupKey }
  }

  var codexImportedAuthorityComparison: CodexEvidenceAuthorityComparison? {
    guard let imported = codexImportedEvidenceBundle, !codexComparisonSessionID.isEmpty else { return nil }
    return CodexSmartLogicEngine.authorityComparison(
      liveSessionID: codexComparisonSessionID,
      liveRows: codexVisibleDecisionComparisonRows,
      importedBundle: imported
    )
  }

  var codexVisibleEvidenceProvenanceRows: [CodexEvidenceProvenanceRow] {
    guard let imported = codexImportedEvidenceBundle else { return [] }
    return CodexSmartLogicEngine.provenanceRows(
      liveRows: codexVisibleDecisionComparisonRows,
      importedBundle: imported,
      filter: codexEvidenceProvenanceFilter
    )
  }

  var codexEvidenceScanRouteSummary: CodexEvidenceScanRouteSummary? {
    guard codexImportedEvidenceBundle != nil else { return nil }
    return CodexSmartLogicEngine.scanRouteSummary(codexVisibleEvidenceProvenanceRows)
  }

  var codexEvidenceProfileAssessment: CodexEvidenceProfileAssessment? {
    guard let routeSummary = codexEvidenceScanRouteSummary,
          let profile = CodexEvidenceScanProfile(rawValue: codexSmartScanMode.rawValue) else { return nil }
    return CodexSmartLogicEngine.profileAssessment(profile: profile, routeSummary: routeSummary)
  }

  var codexSmartScanPlan: CodexSmartScanPlan? {
    guard !codexActiveSmartDecisions.isEmpty else { return nil }
    return CodexSmartLogicEngine.smartScanPlan(
      decisions: codexActiveSmartDecisions,
      deltas: codexSourceDeltas,
      dispositions: codexReviewDispositions
    )
  }

  var codexRouteReceipts: [CodexScanRouteReceipt] {
    guard !codexActiveSessionID.isEmpty, let codexCatalogStore else { return [] }
    return codexCatalogStore.routeReceipts(for: codexActiveSessionID)
  }

  var codexRouteReceiptSummary: CodexRouteReceiptSummary? {
    let receipts = codexRouteReceipts
    guard !receipts.isEmpty else { return nil }
    return CodexSmartLogicEngine.routeReceiptSummary(receipts)
  }

  var codexPendingRoutePaths: Set<String> {
    Set(CodexSmartLogicEngine.pendingRouteReceipts(codexRouteReceipts).map(\.sourcePath))
  }

  var codexPendingRouteCount: Int {
    codexPendingRoutePaths.intersection(Set(codexProjects.map(\.path))).count
  }

  var codexPendingRouteReceipts: [CodexScanRouteReceipt] {
    let availablePaths = Set(codexProjects.map(\.path))
    return CodexSmartLogicEngine.pendingRouteReceipts(codexRouteReceipts)
      .filter { availablePaths.contains($0.sourcePath) }
  }

  var codexRouteReceiptComparisonRows: [CodexRouteReceiptComparisonRow] {
    guard let imported = codexImportedRouteReceiptBundle else { return [] }
    return CodexSmartLogicEngine.compareRouteReceipts(live: codexRouteReceipts, imported: imported.receipts)
  }

  var codexRouteReceiptComparisonSummary: CodexRouteReceiptComparisonSummary? {
    let rows = codexRouteReceiptComparisonRows
    guard !rows.isEmpty else { return nil }
    return CodexSmartLogicEngine.routeReceiptComparisonSummary(rows)
  }

  var codexSelectedRouteReceiptBaselineAudit: CodexRouteReceiptBaselineAuditEvent? {
    guard let selectedID = codexSelectedRouteReceiptBaselineAuditID else { return nil }
    return codexRouteReceiptBaselineAudit.first { $0.id == selectedID }
  }

  var codexVisibleEvidenceHistory: [CodexImportedEvidenceRecord] {
    codexImportedEvidenceHistory.filter { codexEvidenceHistoryFilter.includes($0) }
  }

  var codexSmartArchivePath: String {
    let managedRoot = normalizeWorkspacePath(stage2ManagedRootDraft)
    return (managedRoot as NSString).appendingPathComponent(".SYSTEMX/Archive_Data")
  }

  var codexSmartReadyCount: Int {
    if !codexActiveSmartDecisions.isEmpty {
      return codexActiveSmartDecisions.filter { $0.classification == .canonical }.count
    }
    return codexProjects.filter { project in
      project.hasGit &&
        project.remoteURL?.isEmpty == false &&
        project.ideState != .unlinked &&
        project.gitStatus.isMainSynchronized &&
        !project.gitStatus.hasLocalChanges
    }.count
  }

  var codexSmartReviewCount: Int {
    if !codexActiveSmartDecisions.isEmpty {
      return codexActiveSmartDecisions.filter { $0.classification.isReview }.count
    }
    return codexProjects.filter { project in
      project.ideState == .unlinked ||
        project.remoteURL?.isEmpty != false ||
        project.gitStatus.hasLocalChanges ||
        !project.gitStatus.isMainSynchronized
    }.count
  }

  var codexSmartOutputCount: Int {
    codexTransferPlans.isEmpty ? selectedCodexProjectPaths.count : codexTransferPlans.count
  }

  var codexCanonicalGroupCount: Int {
    Set(codexActiveSmartDecisions.map(\.groupKey)).count
  }

  var codexCanonicalSelectionSummary: String {
    guard codexCanonicalGroupCount > 0 else { return "Choose one canonical source per verified identity group before merge or move." }
    let selected = codexCanonicalSourceByGroup.count
    return "Canonical source selection \(selected)/\(codexCanonicalGroupCount) identity group(s)"
  }

  var codexMissingCanonicalGroupCount: Int {
    let eligibleGroups = Set(codexActiveSmartDecisions.filter { decision in
      decision.classification == .canonical || decision.classification == .mergeCandidate
    }.map(\.groupKey))
    return eligibleGroups.subtracting(codexCanonicalSourceByGroup.keys).count
  }

  var codexSmartDecisionSummary: String {
    if codexProjects.isEmpty {
      return "Start with a bounded source scan. The first pass reads folder evidence and does not copy or delete anything."
    }
    if !codexActiveSmartDecisions.isEmpty {
      let grouped = Set(codexActiveSmartDecisions.map(\.groupKey)).count
      if codexSmartReviewCount == 0 {
        return "Smart Logic grouped \(codexActiveSmartDecisions.count) active source(s) into \(grouped) verified project identity group(s). One destination can be prepared without a review blocker."
      }
      return "Smart Logic grouped \(codexActiveSmartDecisions.count) active source(s) into \(grouped) identity group(s); \(codexSmartReviewCount) source(s) remain review-only until their identity or destination is confirmed."
    }
    if codexSmartReviewCount == 0 {
      return "Smart Logic sees a clean candidate set. One destination can be prepared for the selected projects; no ambiguity is currently visible."
    }
    return "Smart Logic found \(codexSmartReviewCount) project(s) that need review before an automatic merge. Unlinked, dirty, missing-remote, or unsynchronized sources remain visible instead of being silently merged."
  }

  var codexSmartSafetySummary: String {
    switch codexSmartScanMode {
    case .fastIndex:
      return "Fast Index is the default: reuse a saved file table when it still matches, then verify before any cleanup-capable receipt."
    case .verified:
      return "Full Verification reads checksum evidence during planning. It is slower, but gives the strongest early answer for ambiguous sources."
    case .yolo:
      return "YOLO is intentionally limited in this release: it skips deep preflight only. It never authorizes deletion, Stage 2 retirement, or a write without the existing final verification gate."
    }
  }

  var codexBridgeSummary: String {
    let bridgeIDs: Set<String> = ["github-cli", "vscode", "devcontainer", "docker"]
    let bridges = startupReadiness.filter { bridgeIDs.contains($0.id) }
    guard !bridges.isEmpty else { return "Bridge readiness pending" }
    let ready = bridges.filter { $0.kind == .ready }.count
    return "\(ready)/\(bridges.count) local bridges ready"
  }

  var localProjectSummary: String {
    guard !localProjects.isEmpty else {
      return "No local projects detected"
    }

    let splitCount = localProjects.filter { $0.locationLabel == "split" }.count
    let devcontainerCount = localProjects.filter(\.hasDevcontainer).count
    let runnerCount = localProjects.filter(\.hasRunner).count
    let favoriteCount = favoriteProjects.count
    return "\(localProjects.count) local projects · \(splitCount) split · \(devcontainerCount) devcontainers · \(runnerCount) runners · \(favoriteCount) favorites"
  }

  var localProjectSplitCount: Int {
    localProjects.filter { $0.locationLabel == "split" }.count
  }

  var localProjectRuntimeOnlyCount: Int {
    localProjects.filter { $0.codePath == nil && $0.runtimePath != nil }.count
  }

  var localProjectDevcontainerCount: Int {
    localProjects.filter(\.hasDevcontainer).count
  }

  var localProjectGeneratedStarterCount: Int {
    localProjects.filter(\.hasGeneratedStarter).count
  }

  var localProjectRunnerCount: Int {
    localProjects.filter(\.hasRunner).count
  }

  var activeContainerCount: Int {
    activeContainers.count
  }

  var runningRunnerServiceCount: Int {
    runnerServices.filter(\.isRunning).count
  }

  var liveServiceSummary: String {
    "\(activeContainerCount) active devcontainers · \(runningRunnerServiceCount) running runners · \(runnerServices.count) configured runner services"
  }

  var selectedLocalProjects: [LocalProjectEntry] {
    localProjects.filter { selectedRepos.contains($0.slug) }
  }

  var selectedLocalProjectExportSummary: String {
    let count = selectedLocalProjects.count
    if count == 0 {
      return "No local projects targeted for export"
    }
    if count == 1, let only = selectedLocalProjects.first {
      return "1 local project targeted: \(only.slug)"
    }
    return "\(count) local projects targeted"
  }

  var viewerOrganizationsSummary: String {
    if viewerOrganizations.isEmpty {
      return isLoadingGitHubAccountDetails ? "Loading organizations..." : "No organizations loaded yet"
    }
    return viewerOrganizations.joined(separator: ", ")
  }

  var localFilesPrimaryActionTitle: String {
    switch (localFileTransferMode, localFileExportScope) {
    case (.copyBackup, .selectedProjects):
      return "Copy Selected Projects"
    case (.move, .selectedProjects):
      return "Move Selected Projects"
    case (.copyBackup, .codeWorkspace):
      return "Copy Code Workspace"
    case (.move, .codeWorkspace):
      return "Move Code Workspace"
    case (.copyBackup, .runtimeWorkspace):
      return "Copy Runtime Workspace"
    case (.move, .runtimeWorkspace):
      return "Move Runtime Workspace"
    case (.copyBackup, .workspaceBundle):
      return "Copy Full Workspace Bundle"
    case (.move, .workspaceBundle):
      return "Move Full Workspace Bundle"
    }
  }

  var localFilesScopeSummary: String {
    switch localFileExportScope {
    case .selectedProjects:
      return "\(selectedLocalProjectExportSummary). Use project targets below to move or back up one repo or a custom set."
    case .codeWorkspace:
      return "Export the entire plain code workspace root."
    case .runtimeWorkspace:
      return "Export the entire runtime workspace root, including local devcontainer content and reports."
    case .workspaceBundle:
      return "Export both workspace roots into one structured bundle."
    }
  }

  var selectedLocalProjectCount: Int {
    localProjects.filter { selectedRepos.contains($0.slug) }.count
  }

  var selectedJob: BackgroundJobEntry? {
    guard let selectedJobID else { return backgroundJobs.first }
    return backgroundJobs.first(where: { $0.id == selectedJobID }) ?? backgroundJobs.first
  }

  var primaryRepoSlug: String? {
    if let selected = selectedRepos.sorted().first {
      return normalizeRepoSlug(selected)
    }

    let manual = repoTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    if !manual.isEmpty {
      return normalizeRepoSlug(manual)
    }

    return availableRepos.first?.nameWithOwner ?? localProjects.first?.slug
  }

  var primaryLocalProject: LocalProjectEntry? {
    if let slug = primaryRepoSlug,
       let project = localProjects.first(where: { $0.slug == slug }) {
      return project
    }
    return filteredLocalProjects.first ?? localProjects.first
  }

  var primaryActiveContainer: LiveContainerEntry? {
    if let project = primaryLocalProject,
       let container = activeContainers.first(where: { $0.slug == project.slug }) {
      return container
    }
    return activeContainers.first
  }

  var filteredTaskTemplates: [ProjectTaskTemplate] {
    guard let primaryLocalProject else { return [] }
    return taskTemplates.filter { $0.slug == primaryLocalProject.slug }
  }

  var favoriteProjectCount: Int {
    favoriteProjects.count
  }

  var runningJobCount: Int {
    backgroundJobs.filter { $0.state == .running || $0.state == .queued }.count
  }

  var recentJobSummary: String {
    if backgroundJobs.isEmpty {
      return "No background jobs recorded yet"
    }
    let successCount = backgroundJobs.filter { $0.state == .succeeded }.count
    let failedCount = backgroundJobs.filter { $0.state == .failed }.count
    return "\(backgroundJobs.count) jobs · \(runningJobCount) active · \(successCount) succeeded · \(failedCount) failed"
  }

  var areAllVisibleLocalProjectsSelected: Bool {
    !filteredLocalProjects.isEmpty && filteredLocalProjects.allSatisfy { selectedRepos.contains($0.slug) }
  }

  var profileRootSummary: (codeRoot: String, importRoot: String, runtimeRoot: String) {
    resolvedProfileRoots()
  }

  var selectedWorkspaceStyle: WorkspaceStyle {
    selectedProfile == .wtl ? .single : .split
  }

  var workspaceStyleLabel: String {
    selectedProfile == .wtl ? "legacy single-root workspace" : "three-root workspace"
  }

  var workspaceHeadline: String {
    "Code, Import, and Runtime roots"
  }

  var workspaceSummary: String {
    let roots = resolvedProfileRoots()
    return "Code: \(roots.codeRoot)\nImport: \(roots.importRoot)\nRuntime: \(roots.runtimeRoot)"
  }

  var workspaceExecutionLabel: String {
    "three-root workspace"
  }

  var standardWorkspaceSuggestion: WorkspaceSuggestion {
    WorkspaceSuggestion(
      profile: .public,
      style: .split,
      title: "Standard local workspace",
      detail: "Best default for local use. Keep code, import staging, and runtime state in three clear folders under your home directory.",
      codeRoot: publicDefaultCodeRoot,
      importRoot: publicDefaultImportRoot,
      runtimeRoot: publicDefaultRuntimeRoot
    )
  }

  var detectedWorkspaceSuggestion: WorkspaceSuggestion? {
    detectedWorkspaceConfiguration()
  }

  var cleanupTargets: [String] {
    if !selectedRepos.isEmpty {
      return selectedRepos.sorted()
    }

    let manualTarget = repoTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    return manualTarget.isEmpty ? [] : [manualTarget]
  }

  var areAllLoadedReposSelected: Bool {
    !availableRepos.isEmpty && availableRepos.allSatisfy { selectedRepos.contains($0.nameWithOwner) }
  }

  var selectedRepoSummary: String {
    if !selectedRepos.isEmpty {
      if selectedRepos.count == 1, let only = selectedRepos.first {
        return "1 repository selected: \(only)"
      }
      return "\(selectedRepos.count) repositories selected"
    }

    let manualTarget = repoTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    if !manualTarget.isEmpty {
      return "Manual target: \(manualTarget)"
    }

    return "No repository selected yet"
  }

  func bootstrap() {
    loadPersistentState()

    if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      host = appSettings.defaultGitHubHost
    }

    adoptDetectedWorkspaceIfNeeded()
    syncWorkspaceDraftsFromResolvedRoots()
    configureStage2DefaultsIfNeeded()
    refreshCodexCatalogStore()
    reloadAuthInventory()
    refreshAuthStatus()
    refreshLocalProjects()
    refreshStartupReadiness()
    scanExternalVolumes()
    scanLegacyWorkspaces()
  }

  private func refreshCodexCatalogStore() {
    let root = normalizeWorkspacePath(codexOutputRootDraft)
    guard !root.isEmpty else {
      codexCatalogStore = nil
      codexCatalogStatus = "Choose a local output root before saving a Smart Logic catalog."
      return
    }
    codexCatalogStore = CodexCatalogStore(rootPath: root)
    codexCatalogStatus = codexCatalogStore?.status ?? "SQLite catalog unavailable"
  }

  private func recordCodexSmartDecisions(
    _ projects: [CodexProjectEntry],
    sourceRoots: [String],
    profile: CodexSmartScanMode,
    discoveryMilliseconds: Int = 0
  ) {
    let decisionStartedAt = Date()
    refreshCodexCatalogStore()
    let destinationRoot = normalizeWorkspacePath(codexOutputRootDraft)
    let previousFingerprints: [String: String] = readJSON([String: String].self, from: codexSourceFingerprintsFile) ?? [:]
    let deltas = CodexSmartLogicEngine.sourceDeltas(previous: previousFingerprints, current: projects)
    codexSourceDeltas = deltas
    let changedPaths = Set(deltas.filter { $0.kind != .unchanged }.map(\.sourcePath))
    let evaluateAll = codexSmartDecisions.isEmpty || previousFingerprints.isEmpty
    let changedGroupKeys = Set(projects.filter { changedPaths.contains($0.path) }.map { project in
      if let remote = project.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !remote.isEmpty {
        return "remote:\(remote.lowercased().hasSuffix(".git") ? String(remote.dropLast(4)) : remote.lowercased())"
      }
      return "name:\(project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    })
    let projectsToEvaluate: [CodexProjectEntry]
    if evaluateAll {
      projectsToEvaluate = projects
      codexScanDeltaStatus = "Initial baseline: evaluated all (projects.count) discovered source row(s)."
    } else {
      projectsToEvaluate = projects.filter { project in
        changedPaths.contains(project.path) || changedGroupKeys.contains { key in
          if let remote = project.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !remote.isEmpty {
            let normalized = remote.lowercased().hasSuffix(".git") ? String(remote.dropLast(4)) : remote.lowercased()
            return key == "remote:\(normalized)"
          }
          return key == "name:\(project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }
      }
      codexScanDeltaStatus = changedPaths.isEmpty
        ? "No source fingerprints changed: retained (codexSmartDecisions.count) saved decision row(s) without re-evaluation."
        : "Delta scan: (changedPaths.count) source row(s) changed; evaluated (projectsToEvaluate.count) row(s) across (changedGroupKeys.count) affected group(s)."
    }
    let refreshed = CodexSmartLogicEngine.evaluate(projectsToEvaluate, destinationRoot: destinationRoot)
    let decisions: [CodexSmartDecision]
    if evaluateAll {
      decisions = refreshed
    } else {
      let refreshedPaths = Set(refreshed.map(\.sourcePath))
      let currentPaths = Set(projects.map(\.path))
      decisions = codexSmartDecisions
        .filter { currentPaths.contains($0.sourcePath) && !refreshedPaths.contains($0.sourcePath) }
        + refreshed
    }
    codexSmartDecisions = decisions
    writeJSON(decisions, to: codexSmartDecisionsFile)
    let currentFingerprints = Dictionary(uniqueKeysWithValues: projects.map { ($0.path, CodexSmartLogicEngine.sourceFingerprint($0)) })
    writeJSON(currentFingerprints, to: codexSourceFingerprintsFile)
    codexReviewDispositions = codexReviewDispositions.filter { entry in
      decisions.contains { $0.sourcePath == entry.key }
    }
    persistCodexReviewDispositions()
    let validGroups = Set(decisions.map(\.groupKey))
    codexCanonicalSourceByGroup = codexCanonicalSourceByGroup.filter { entry in
      validGroups.contains(entry.key) && decisions.contains { decision in
        decision.groupKey == entry.key && decision.sourcePath == entry.value
      }
    }
    let session = CodexScanSession(
      id: UUID().uuidString,
      profile: profile.rawValue,
      sourceRoots: sourceRoots,
      createdAt: Date(),
      ruleVersion: CodexSmartLogicEngine.ruleVersion,
      decisionCount: decisions.count
    )
    codexActiveSessionID = session.id
    let decisionMilliseconds = max(0, Int(Date().timeIntervalSince(decisionStartedAt) * 1_000))
    let changedCount = deltas.filter { $0.kind == .changed || $0.kind == .added || $0.kind == .removed }.count
    let reusedCount = deltas.filter { $0.kind == .unchanged }.count
    let timing = CodexScanTimingEvidence(
      sessionID: session.id,
      discoveryMilliseconds: max(0, discoveryMilliseconds),
      decisionMilliseconds: decisionMilliseconds,
      totalMilliseconds: max(0, discoveryMilliseconds) + decisionMilliseconds,
      discoveredSourceCount: projects.count,
      evaluatedSourceCount: projectsToEvaluate.count,
      reusedSourceCount: reusedCount,
      changedSourceCount: changedCount,
      affectedGroupCount: changedGroupKeys.count
    )
    let routeReceipts = CodexSmartLogicEngine.routeReceipts(
      sessionID: session.id,
      decisions: decisions,
      deltas: deltas,
      dispositions: codexReviewDispositions
    )
    do {
      _ = try codexCatalogStore?.save(session: session, decisions: decisions, routeReceipts: routeReceipts, deltas: deltas, timing: timing)
      let sessions = codexCatalogStore?.recentSessions(limit: 6) ?? []
      codexRecentSessions = sessions
      let previousSessionID = sessions.dropFirst().first?.id
      codexSessionDiffSummary = CodexSessionDiffSummary(
        currentSessionID: session.id,
        previousSessionID: previousSessionID,
        addedCount: deltas.filter { $0.kind == .added }.count,
        changedCount: deltas.filter { $0.kind == .changed }.count,
        unchangedCount: deltas.filter { $0.kind == .unchanged }.count,
        removedCount: deltas.filter { $0.kind == .removed }.count,
        affectedGroupCount: changedGroupKeys.count,
        evaluatedSourceCount: projectsToEvaluate.count,
        reusedSourceCount: reusedCount,
        timing: timing
      )
      codexCatalogStatus = "Catalog saved · session \(session.id.prefix(8)) · JSON/CSV exports ready"
      selectCodexComparisonSession(session.id)
    } catch {
      codexCatalogStatus = "Catalog warning: \(error.localizedDescription)"
      appendLog("[codex] Smart Logic catalog warning: \(error.localizedDescription)\n")
    }
  }

  func selectCodexComparisonSession(_ sessionID: String) {
    guard !sessionID.isEmpty, let store = codexCatalogStore else {
      codexComparisonStatus = "Choose a local output root and run a scan before selecting a catalog session."
      return
    }
    let sessions = store.recentSessions(limit: 20)
    guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
      codexComparisonStatus = "The selected catalog session is no longer available in the current output root."
      return
    }
    guard let timing = store.timing(for: sessionID) else {
      codexComparisonSessionID = sessionID
      codexComparisonDeltas = store.sourceDeltas(for: sessionID)
      codexComparisonBaselineSessionID = sessions.dropFirst(index + 1).first?.id ?? ""
      compareCodexSessions(currentSessionID: sessionID, baselineSessionID: codexComparisonBaselineSessionID)
      codexComparisonStatus = "Session \(String(sessionID.prefix(8))) has no timing receipt; older sessions remain visible but cannot be compared quantitatively."
      return
    }
    let previousSessionID = sessions.dropFirst(index + 1).first?.id
    let deltas = store.sourceDeltas(for: sessionID)
    let summary = CodexSessionDiffSummary(
      currentSessionID: sessionID,
      previousSessionID: previousSessionID,
      addedCount: deltas.filter { $0.kind == .added }.count,
      changedCount: deltas.filter { $0.kind == .changed }.count,
      unchangedCount: deltas.filter { $0.kind == .unchanged }.count,
      removedCount: deltas.filter { $0.kind == .removed }.count,
      affectedGroupCount: timing.affectedGroupCount,
      evaluatedSourceCount: timing.evaluatedSourceCount,
      reusedSourceCount: timing.reusedSourceCount,
      timing: timing
    )
    codexComparisonSessionID = sessionID
    codexComparisonDeltas = deltas
    codexComparisonGroupKey = ""
    codexComparisonBaselineSessionID = previousSessionID ?? ""
    codexSessionDiffSummary = summary
    compareCodexSessions(currentSessionID: sessionID, baselineSessionID: codexComparisonBaselineSessionID)
    codexComparisonStatus = "Loaded SQLite session \(String(sessionID.prefix(8))) with \(deltas.count) source-level delta row(s)."
  }

  func compareCodexSessions(currentSessionID: String, baselineSessionID: String) {
    guard let store = codexCatalogStore, !currentSessionID.isEmpty else { return }
    let current = store.decisionSnapshots(for: currentSessionID)
    let baseline = baselineSessionID.isEmpty ? [] : store.decisionSnapshots(for: baselineSessionID)
    let currentFingerprints = store.currentFingerprints(for: currentSessionID)
    let baselineFingerprints = baselineSessionID.isEmpty ? [:] : store.currentFingerprints(for: baselineSessionID)
    codexDecisionComparisonRows = CodexSmartLogicEngine.compareSnapshots(
      current: current,
      baseline: baseline,
      currentFingerprints: currentFingerprints,
      baselineFingerprints: baselineFingerprints
    )
    codexComparisonStatus = baselineSessionID.isEmpty
      ? "Compared session \(String(currentSessionID.prefix(8))) with no baseline; all rows are treated as added evidence."
      : "Compared session \(String(currentSessionID.prefix(8))) with baseline \(String(baselineSessionID.prefix(8))) across \(codexDecisionComparisonRows.count) source row(s)."
  }

  func exportCodexComparisonEvidence() {
    guard let store = codexCatalogStore, !codexComparisonSessionID.isEmpty else {
      codexComparisonExportStatus = "Select a saved session before exporting comparison evidence."
      return
    }
    do {
      let paths = try store.exportComparison(
        currentSessionID: codexComparisonSessionID,
        baselineSessionID: codexComparisonBaselineSessionID.isEmpty ? nil : codexComparisonBaselineSessionID,
        rows: codexVisibleDecisionComparisonRows,
        selectedScanProfile: CodexEvidenceScanProfile(rawValue: codexSmartScanMode.rawValue),
        profileAssessment: codexEvidenceProfileAssessment
      )
      codexComparisonExportStatus = "Evidence exported locally: \(paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", "))"
      codexCatalogStatus = "Catalog saved · comparison JSON/CSV evidence ready"
    } catch {
      codexComparisonExportStatus = "Comparison export failed: \(error.localizedDescription)"
      appendLog("[codex] Comparison evidence export failed: \(error.localizedDescription)\n")
    }
  }

  func exportCodexRouteReceipts() {
    guard let store = codexCatalogStore, !codexActiveSessionID.isEmpty else {
      codexRouteReceiptExportStatus = "Run or load a catalog session before exporting route receipts."
      return
    }
    do {
      let paths = try store.exportRouteReceipts(sessionID: codexActiveSessionID, receipts: codexRouteReceipts)
      codexRouteReceiptExportStatus = "Route receipts exported locally: " + paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
      codexCatalogStatus = "Catalog saved · route receipt JSON/CSV evidence ready"
    } catch {
      codexRouteReceiptExportStatus = "Route receipt export failed: " + error.localizedDescription
      appendLog("[codex] Route receipt export failed: " + error.localizedDescription + "\n")
    }
  }

  func exportCodexRouteReceiptBaselineAudit() {
    guard let store = codexCatalogStore else {
      codexRouteReceiptBaselineAuditExportStatus = "The local catalog is not available for baseline-audit export."
      return
    }
    do {
      let paths = try store.exportRouteReceiptBaselineAudit(events: codexRouteReceiptBaselineAudit)
      let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
      codexRouteReceiptBaselineAuditExportStatus = "Baseline audit exported locally: " + names + ". Read-only evidence only; no baseline was activated."
      codexCatalogStatus = "Catalog saved · baseline audit JSON/CSV evidence ready"
    } catch {
      codexRouteReceiptBaselineAuditExportStatus = "Baseline audit export failed: " + error.localizedDescription
      appendLog("[codex] Baseline audit export failed: " + error.localizedDescription + "\n")
    }
  }

  func chooseCodexRouteReceiptBaselineAuditBundle() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    panel.prompt = "Inspect Baseline Audit"
    panel.message = "Choose a CSA-iLEM baseline-audit JSON export. It will be inspected read-only and will not replace the live audit history or activate a baseline."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      let bundle = try JSONDecoder().decode(CodexRouteReceiptBaselineAuditExportBundle.self, from: data)
      let validationIssues = bundle.validationIssues
      guard validationIssues.isEmpty else {
        throw CodexBaselineAuditValidationError(issues: validationIssues)
      }
      codexImportedBaselineAuditEvents = bundle.events
      let record = CodexImportedBaselineAuditRecord(
        id: UUID().uuidString,
        sourceName: url.lastPathComponent,
        importedAt: Date(),
        auditVersion: bundle.auditVersion,
        acceptedCount: bundle.events.filter { $0.action == .accepted }.count,
        revokedCount: bundle.events.filter { $0.action == .revoked }.count,
        fingerprint: CodexSmartLogicEngine.baselineAuditFingerprint(auditVersion: bundle.auditVersion, events: bundle.events),
        validationState: "validated",
        events: bundle.events
      )
      let replacedExisting = codexImportedBaselineAuditHistory.contains { $0.fingerprint == record.fingerprint }
      codexImportedBaselineAuditHistory = CodexImportedBaselineAuditRecord.upsert(record, into: codexImportedBaselineAuditHistory)
      persistCodexImportedBaselineAuditHistory()
      let operation = replacedExisting ? "matching fingerprint refreshed" : "new fingerprint retained"
      codexImportedBaselineAuditStatus = "Read-only baseline audit loaded: " + url.lastPathComponent + " · " + String(bundle.events.count) + " event(s) · structure validated · " + operation + ". Live audit history and baseline authority unchanged."
      appendLog("[codex] Read-only baseline audit bundle loaded from " + url.path + "\n")
    } catch {
      codexImportedBaselineAuditEvents = []
      let rejection = CodexRejectedBaselineAuditImport(
        id: UUID().uuidString,
        sourceName: url.lastPathComponent,
        rejectedAt: Date(),
        reasons: [error.localizedDescription]
      )
      codexRejectedBaselineAuditImports.insert(rejection, at: 0)
      codexRejectedBaselineAuditImports = Array(codexRejectedBaselineAuditImports.prefix(20))
      persistCodexRejectedBaselineAuditImports()
      codexImportedBaselineAuditStatus = "Baseline audit import rejected: " + error.localizedDescription
      appendLog("[codex] Baseline audit bundle rejected: " + error.localizedDescription + "\n")
    }
  }

  func inspectCodexImportedBaselineAuditRecord(_ record: CodexImportedBaselineAuditRecord) {
    codexImportedBaselineAuditEvents = record.events
    codexImportedBaselineAuditStatus = "Read-only baseline audit history entry: " + record.sourceName + " · " + String(record.events.count) + " event(s). Live audit history and baseline authority unchanged."
  }

  func removeCodexImportedBaselineAuditRecord(_ record: CodexImportedBaselineAuditRecord) {
    codexImportedBaselineAuditHistory.removeAll { $0.id == record.id }
    persistCodexImportedBaselineAuditHistory()
    if codexImportedBaselineAuditEvents == record.events {
      codexImportedBaselineAuditEvents = []
      codexImportedBaselineAuditStatus = "Imported baseline-audit history entry removed; live audit history was not changed."
    }
  }

  func clearCodexImportedBaselineAuditHistory() {
    codexImportedBaselineAuditHistory = []
    codexImportedBaselineAuditEvents = []
    persistCodexImportedBaselineAuditHistory()
    codexImportedBaselineAuditStatus = "Imported baseline-audit history cleared; live audit history was not changed."
  }

  func chooseCodexRouteReceiptBundle() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    panel.prompt = "Inspect Route Receipts"
    panel.message = "Choose a CSA-iLEM route-receipt JSON export. It will be inspected read-only and will not be added to the live SQLite catalog."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      let bundle = try JSONDecoder().decode(CodexRouteReceiptExportBundle.self, from: data)
      let record = CodexImportedRouteReceiptRecord(id: UUID().uuidString, sourceName: url.lastPathComponent, importedAt: Date(), bundle: bundle)
      codexImportedRouteReceiptBundle = bundle
      codexRouteReceiptBaselineDecision = nil
      persistCodexRouteReceiptBaselineDecision()
      codexImportedRouteReceiptHistory.removeAll { $0.sourceName == record.sourceName && $0.bundle.sessionID == record.bundle.sessionID }
      codexImportedRouteReceiptHistory.insert(record, at: 0)
      persistCodexImportedRouteReceiptHistory()
      codexImportedRouteReceiptStatus = "Read-only route receipts loaded: " + url.lastPathComponent + " · " + String(bundle.receipts.count) + " receipt(s). Live catalog authority unchanged."
      appendLog("[codex] Read-only route receipt bundle loaded from " + url.path + "\n")
    } catch {
      codexImportedRouteReceiptBundle = nil
      codexImportedRouteReceiptStatus = "Route receipt import rejected: " + error.localizedDescription
      appendLog("[codex] Route receipt bundle rejected: " + error.localizedDescription + "\n")
    }
  }

  func inspectCodexImportedRouteReceiptRecord(_ record: CodexImportedRouteReceiptRecord) {
    codexImportedRouteReceiptBundle = record.bundle
    codexImportedRouteReceiptStatus = "Read-only route receipt history entry: " + record.sourceName + " · " + String(record.bundle.receipts.count) + " receipt(s). Live catalog authority unchanged."
  }

  func acceptCodexRouteReceiptBaseline() {
    guard let imported = codexImportedRouteReceiptBundle, !codexActiveSessionID.isEmpty else {
      codexImportedRouteReceiptStatus = "Load an imported route-receipt bundle and a live catalog session before accepting a comparison baseline."
      return
    }
    let sourceName = codexImportedRouteReceiptHistory.first(where: { $0.bundle == imported })?.sourceName ?? "imported-route-receipts.json"
    let decision = CodexRouteReceiptBaselineDecision(
      id: UUID().uuidString,
      liveSessionID: codexActiveSessionID,
      importedSessionID: imported.sessionID,
      importedSourceName: sourceName,
      decidedAt: Date(),
      detail: "Operator accepted imported receipts as a comparison baseline only; live SQLite receipts remain authoritative."
    )
    codexRouteReceiptBaselineDecision = decision
    persistCodexRouteReceiptBaselineDecision()
    appendCodexRouteReceiptBaselineAudit(
      action: .accepted,
      liveSessionID: decision.liveSessionID,
      importedSessionID: decision.importedSessionID,
      importedSourceName: decision.importedSourceName,
      detail: decision.detail
    )
    codexImportedRouteReceiptStatus = "Comparison baseline accepted: " + sourceName + " · read-only evidence only; live execution authority unchanged."
    appendLog("[codex] Imported route receipts accepted as comparison baseline only for live session " + codexActiveSessionID + "\n")
  }

  func revokeCodexRouteReceiptBaseline() {
    guard let decision = codexRouteReceiptBaselineDecision else {
      codexImportedRouteReceiptStatus = "No comparison baseline is currently accepted."
      return
    }
    appendCodexRouteReceiptBaselineAudit(
      action: .revoked,
      liveSessionID: decision.liveSessionID,
      importedSessionID: decision.importedSessionID,
      importedSourceName: decision.importedSourceName,
      detail: "Operator revoked comparison-baseline acceptance; imported evidence remains retained and read-only."
    )
    codexRouteReceiptBaselineDecision = nil
    persistCodexRouteReceiptBaselineDecision()
    codexImportedRouteReceiptStatus = "Comparison baseline revoked; imported evidence remains available as read-only history and live execution authority is unchanged."
  }

  func inspectCodexRouteReceiptBaselineAudit(_ event: CodexRouteReceiptBaselineAuditEvent) {
    codexSelectedRouteReceiptBaselineAuditID = event.id
    codexImportedRouteReceiptStatus = "Read-only baseline audit event selected: " + event.action.rawValue + " · no baseline was activated or changed."
  }

  private func appendCodexRouteReceiptBaselineAudit(
    action: CodexRouteReceiptBaselineAuditAction,
    liveSessionID: String,
    importedSessionID: String,
    importedSourceName: String,
    detail: String
  ) {
    let event = CodexRouteReceiptBaselineAuditEvent(
      id: UUID().uuidString,
      action: action,
      liveSessionID: liveSessionID,
      importedSessionID: importedSessionID,
      importedSourceName: importedSourceName,
      occurredAt: Date(),
      detail: detail
    )
    codexRouteReceiptBaselineAudit.insert(event, at: 0)
    codexRouteReceiptBaselineAudit = Array(codexRouteReceiptBaselineAudit.prefix(50))
    persistCodexRouteReceiptBaselineAudit()
  }

  func removeCodexImportedRouteReceiptRecord(_ record: CodexImportedRouteReceiptRecord) {
    codexImportedRouteReceiptHistory.removeAll { $0.id == record.id }
    if codexImportedRouteReceiptBundle == record.bundle {
      codexImportedRouteReceiptBundle = nil
      codexRouteReceiptBaselineDecision = nil
      persistCodexRouteReceiptBaselineDecision()
      codexImportedRouteReceiptStatus = "Selected imported route receipt bundle cleared; the live catalog was not changed."
    }
    persistCodexImportedRouteReceiptHistory()
  }

  func clearCodexImportedRouteReceiptHistory() {
    codexImportedRouteReceiptHistory.removeAll()
    codexImportedRouteReceiptBundle = nil
    codexRouteReceiptBaselineDecision = nil
    persistCodexRouteReceiptBaselineDecision()
    codexImportedRouteReceiptStatus = "Imported route receipt history cleared; the live catalog was not changed."
    persistCodexImportedRouteReceiptHistory()
  }

  func chooseCodexEvidenceBundle() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    panel.prompt = "Inspect Evidence"
    panel.message = "Choose a CSA-iLEM comparison JSON export. It will be inspected read-only and will not be added to the live catalog."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      let bundle = try JSONDecoder().decode(CodexComparisonEvidenceBundle.self, from: data)
      codexImportedEvidenceBundle = bundle
      let record = CodexImportedEvidenceRecord(id: UUID().uuidString, sourceName: url.lastPathComponent, importedAt: Date(), bundle: bundle)
      codexImportedEvidenceHistory.removeAll { $0.sourceName == record.sourceName && $0.bundle.currentSessionID == record.bundle.currentSessionID && $0.bundle.baselineSessionID == record.bundle.baselineSessionID }
      codexImportedEvidenceHistory.insert(record, at: 0)
      persistCodexImportedEvidenceHistory()
      codexImportedEvidenceStatus = "Read-only evidence loaded: " + url.lastPathComponent + " · " + String(bundle.rows.count) + " row(s)."
      appendLog("[codex] Read-only comparison evidence loaded from " + url.path + "\n")
    } catch {
      codexImportedEvidenceBundle = nil
      codexImportedEvidenceStatus = "Evidence import rejected: " + error.localizedDescription
      appendLog("[codex] Read-only comparison evidence rejected: " + error.localizedDescription + "\n")
    }
  }

  func inspectCodexEvidenceRecord(_ record: CodexImportedEvidenceRecord) {
    codexImportedEvidenceBundle = record.bundle
    codexImportedEvidenceStatus = "Read-only history entry: " + record.sourceName + " · " + String(record.bundle.rows.count) + " row(s)."
  }

  func removeCodexEvidenceRecord(_ record: CodexImportedEvidenceRecord) {
    codexImportedEvidenceHistory.removeAll { $0.id == record.id }
    if codexImportedEvidenceBundle == record.bundle {
      codexImportedEvidenceBundle = nil
      codexImportedEvidenceStatus = "Selected imported evidence cleared; the live catalog was not changed."
    }
    persistCodexImportedEvidenceHistory()
  }

  func clearCodexEvidenceHistory() {
    codexImportedEvidenceHistory.removeAll()
    codexImportedEvidenceBundle = nil
    codexImportedEvidenceStatus = "Imported evidence history cleared; the live catalog was not changed."
    persistCodexImportedEvidenceHistory()
  }

  func setCodexComparisonGroup(_ groupKey: String) {
    codexComparisonGroupKey = groupKey
    if groupKey.isEmpty {
      codexComparisonStatus = "Showing all source-level delta rows for session \(String(codexComparisonSessionID.prefix(8)))."
    } else {
      codexComparisonStatus = "Showing source-level delta rows for identity group \(groupKey)."
    }
  }

  func rebuildCodexScanBaseline() {
    let reason = codexBaselineRebuildReason.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !reason.isEmpty else {
      codexPortalStatus = "Enter a reason before rebuilding the scan baseline."
      return
    }
    let oldDecisionCount = codexSmartDecisions.count
    try? FileManager.default.removeItem(atPath: codexSourceFingerprintsFile)
    codexSmartDecisions.removeAll()
    codexComparisonDeltas.removeAll()
    codexSessionDiffSummary = nil
    codexBaselineRebuildReason = ""
    appendCodexReviewAudit(
      sourcePath: "baseline",
      groupKey: "baseline",
      previousDisposition: nil,
      nextDisposition: nil,
      action: "baseline-rebuilt",
      detail: "Operator requested a full scan baseline rebuild: \(reason) Previously retained \(oldDecisionCount) decision row(s); source data was not deleted."
    )
    codexScanDeltaStatus = "Baseline rebuild armed by operator. The next scan will evaluate all discovered sources."
    codexPortalStatus = "Scan baseline cleared for a full re-evaluation. No source files, destinations, or remote repositories were changed."
  }

  func requestCodexLocalAdvisory() {
    guard !codexActiveSmartDecisions.isEmpty else {
      codexAdvisory = nil
      codexAdvisoryStatus = "Run Scan Sources before requesting a local advisory."
      return
    }
    let providerKind = codexAdvisoryProviderKind
    let model = providerKind == .lmStudio ? "local-model" : "llama3.2"
    let input = CodexAdvisoryInput(
      ruleVersion: CodexSmartLogicEngine.ruleVersion,
      decisions: codexActiveSmartDecisions,
      redactionPolicy: "indexed-metadata-only; no source content, credentials, prompts, or raw conversation logs"
    )
    codexAdvisory = nil
    codexAdvisoryStatus = "Contacting \(providerKind.rawValue) on localhost. No write action is attached to the advisory."
    let provider = LocalCodexAdvisoryProvider(kind: providerKind, model: model)
    Task { [weak self] in
      do {
        let advisory = try await provider.advise(input)
        self?.codexAdvisory = advisory
        self?.codexAdvisoryStatus = "Local advisory received from \(advisory.provider.rawValue) / \(advisory.model). Deterministic Smart Logic remains authoritative."
      } catch {
        self?.codexAdvisoryStatus = "Local advisory unavailable: \(error.localizedDescription). Deterministic Smart Logic remains authoritative."
      }
    }
  }

  func chooseCodexCanonicalSource(_ decision: CodexSmartDecision) {
    guard decision.classification != .sameNameReview,
          decision.classification != .brokenMetadataReview,
          decision.classification != .fatalIdentityConflict else {
      codexPortalStatus = "This source has no safe identity proof and cannot be selected as canonical."
      return
    }
    codexCanonicalSourceByGroup[decision.groupKey] = decision.sourcePath
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
    codexLifecycleSafetyArmed = false
    codexPortalStatus = "Canonical source selected for \(decision.evidence.name). Rebuild the decision scan before any merge or move."
  }

  func setCodexReviewDisposition(_ decision: CodexSmartDecision, disposition: CodexReviewDisposition?) {
    guard decision.classification.isReview || disposition == nil else {
      codexPortalStatus = "Only review-classified sources can be deferred or excluded."
      return
    }
    let previousDisposition = codexReviewDispositions[decision.sourcePath]
    if let disposition {
      codexReviewDispositions[decision.sourcePath] = disposition
      if disposition == .excluded {
        selectedCodexProjectPaths.remove(decision.sourcePath)
      }
      if codexCanonicalSourceByGroup[decision.groupKey] == decision.sourcePath {
        codexCanonicalSourceByGroup.removeValue(forKey: decision.groupKey)
      }
      codexPortalStatus = disposition == .excluded
        ? "Excluded \(decision.evidence.name) from active group readiness. The source remains retained in the review ledger."
        : "Deferred \(decision.evidence.name). It remains visible as a blocker until resumed or explicitly excluded."
    } else {
      codexReviewDispositions.removeValue(forKey: decision.sourcePath)
      codexPortalStatus = "Restored \(decision.evidence.name) to active group readiness review."
    }
    appendCodexReviewAudit(
      sourcePath: decision.sourcePath,
      groupKey: decision.groupKey,
      previousDisposition: previousDisposition,
      nextDisposition: disposition,
      action: "disposition-changed",
      detail: "Operator changed the review disposition for \(decision.evidence.name)."
    )
    persistCodexReviewDispositions()
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
    codexLifecycleSafetyArmed = false
  }

  func undoLastCodexReviewAction() {
    guard let index = codexReviewAudit.lastIndex(where: { $0.action == "disposition-changed" }) else {
      codexPortalStatus = "No reversible review disposition is recorded."
      return
    }
    let entry = codexReviewAudit[index]
    guard let decision = codexSmartDecisions.first(where: { $0.sourcePath == entry.sourcePath }) else {
      codexPortalStatus = "The source for the last review action is not in the current decision table; scan before undoing it."
      return
    }
    codexReviewDispositions.removeValue(forKey: entry.sourcePath)
    if let previous = entry.previousDisposition {
      codexReviewDispositions[entry.sourcePath] = previous
    }
    appendCodexReviewAudit(
      sourcePath: entry.sourcePath,
      groupKey: entry.groupKey,
      previousDisposition: entry.nextDisposition,
      nextDisposition: entry.previousDisposition,
      action: "disposition-undone",
      detail: "Operator reverted the previous review disposition for \(decision.evidence.name)."
    )
    persistCodexReviewDispositions()
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
    codexLifecycleSafetyArmed = false
    codexPortalStatus = "Reverted the last review disposition for \(decision.evidence.name). Recheck the group before applying any operation."
  }

  func reEvaluateCodexGroup(_ groupKey: String) {
    let sourcePaths = Set(codexSmartDecisions.filter { $0.groupKey == groupKey }.map(\.sourcePath))
    let projects = codexProjects.filter { sourcePaths.contains($0.path) }
    guard !projects.isEmpty else {
      codexGroupReviewStatus = "No indexed source rows are available for \(groupKey). Run Scan Sources first."
      return
    }
    let destinationRoot = normalizeWorkspacePath(codexOutputRootDraft)
    let refreshed = CodexSmartLogicEngine.evaluate(projects, destinationRoot: destinationRoot)
    codexSmartDecisions = codexSmartDecisions.filter { $0.groupKey != groupKey } + refreshed
    codexCanonicalSourceByGroup.removeValue(forKey: groupKey)
    codexGroupReviewStatus = "Re-evaluated \(groupKey) from \(projects.count) saved indexed source row(s); unrelated groups were not rescanned."
    appendCodexReviewAudit(
      sourcePath: "group:\(groupKey)",
      groupKey: groupKey,
      previousDisposition: nil,
      nextDisposition: nil,
      action: "group-re-evaluated",
      detail: "Targeted group re-evaluation used saved indexed source rows; unrelated groups were retained."
    )
    persistCodexReviewDispositions()
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
    codexLifecycleSafetyArmed = false
  }

  private func persistCodexReviewDispositions() {
    writeJSON(codexReviewDispositions, to: codexReviewDispositionsFile)
  }

  private func appendCodexReviewAudit(
    sourcePath: String,
    groupKey: String,
    previousDisposition: CodexReviewDisposition?,
    nextDisposition: CodexReviewDisposition?,
    action: String,
    detail: String
  ) {
    let entry = CodexReviewAuditEntry(
      id: UUID().uuidString,
      sessionID: codexActiveSessionID,
      sourcePath: sourcePath,
      groupKey: groupKey,
      previousDisposition: previousDisposition,
      nextDisposition: nextDisposition,
      action: action,
      detail: detail,
      occurredAt: Date()
    )
    codexReviewAudit.append(entry)
    if codexReviewAudit.count > 200 {
      codexReviewAudit = Array(codexReviewAudit.suffix(200))
    }
    writeJSON(codexReviewAudit, to: codexReviewAuditFile)
  }

  private func recordCodexTransferCheckpoints(_ plans: [CodexTransferPlan]) {
    guard !codexActiveSessionID.isEmpty, let codexCatalogStore else { return }
    let checkpoints = plans.map { plan in
      CodexSessionCheckpoint(
        sessionID: codexActiveSessionID,
        sourcePath: plan.projectPath,
        stage: "stage1-preflight",
        state: "indexed",
        updatedAt: Date(),
        detail: plan.summaryLine
      )
    }
    do {
      try codexCatalogStore.saveCheckpoints(checkpoints)
      let indexRecords = plans.compactMap { plan -> CodexScanIndexRecord? in
        guard let sourceDigest = CodexCatalogStore.artifactDigest(at: plan.sourceIndexPath) else { return nil }
        return CodexScanIndexRecord(
          sourcePath: plan.projectPath,
          destinationPath: plan.destinationPath,
          sourceIndexPath: plan.sourceIndexPath,
          destinationIndexPath: plan.destinationIndexPath,
          optionsKey: [
            plan.includeGitMetadata == true ? "git=1" : "git=0",
            plan.includeFinderMetadata == true ? "finder=1" : "finder=0",
            plan.includeDependencies == true ? "deps=1" : "deps=0",
            plan.fullChecksumAudit ? "checksum=1" : "checksum=0"
          ].joined(separator: ";"),
          sourceIndexDigest: sourceDigest,
          destinationIndexDigest: plan.destinationIndexPath.flatMap { CodexCatalogStore.artifactDigest(at: $0) },
          sourceFileCount: plan.sourceFileCount,
          sourceByteCount: plan.sourceByteCount,
          capturedAt: plan.createdAt
        )
      }
      try codexCatalogStore.saveIndexRecords(indexRecords)
      codexCatalogStatus = "Catalog and Stage 1 checkpoints saved · session \(codexActiveSessionID.prefix(8))"
    } catch {
      codexCatalogStatus = "Catalog checkpoint warning: \(error.localizedDescription)"
      appendLog("[codex] Catalog checkpoint warning: \(error.localizedDescription)\n")
    }
  }

  private func updateCodexRouteReceipts(
    completedPaths: Set<String>,
    interruptedPaths: Set<String>,
    failedPaths: Set<String>
  ) {
    guard !codexActiveSessionID.isEmpty, let codexCatalogStore else { return }
    let now = Date()
    let receipts = codexCatalogStore.routeReceipts(for: codexActiveSessionID).map { receipt -> CodexScanRouteReceipt in
      if receipt.state == .skipped { return receipt }
      let nextState: CodexRouteReceiptState
      let detail: String
      if failedPaths.contains(receipt.sourcePath) {
        nextState = .failed
        detail = "Route stopped at this source; retry is available from the persisted receipt."
      } else if interruptedPaths.contains(receipt.sourcePath) {
        nextState = .interrupted
        detail = "Route was not reached before the operation stopped; resume can reuse the saved decision and index."
      } else if completedPaths.contains(receipt.sourcePath) {
        nextState = .completed
        detail = "Route completed with the selected operation's verification boundary."
      } else {
        return receipt
      }
      return CodexScanRouteReceipt(
        sessionID: receipt.sessionID,
        sourcePath: receipt.sourcePath,
        route: receipt.route,
        state: nextState,
        attemptCount: receipt.attemptCount + 1,
        updatedAt: now,
        detail: detail
      )
    }
    do {
      try codexCatalogStore.saveRouteReceipts(receipts)
    } catch {
      appendLog("[codex] Route receipt update warning: \(error.localizedDescription)\n")
    }
  }

  private func loadPersistentState() {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true, attributes: nil)
    try? fm.createDirectory(atPath: snapshotsDirectory, withIntermediateDirectories: true, attributes: nil)

    if let loadedSettings: AppSettings = readJSON(AppSettings.self, from: settingsFile) {
      appSettings = loadedSettings
    }
    if let savedCodexRoots: [String] = readJSON([String].self, from: codexScanRootsFile), !savedCodexRoots.isEmpty {
      codexScanRootsDraft = savedCodexRoots.joined(separator: "\n")
    }
    if let savedDispositions: [String: CodexReviewDisposition] = readJSON([String: CodexReviewDisposition].self, from: codexReviewDispositionsFile) {
      codexReviewDispositions = savedDispositions
    }
    if let savedAudit: [CodexReviewAuditEntry] = readJSON([CodexReviewAuditEntry].self, from: codexReviewAuditFile) {
      codexReviewAudit = Array(savedAudit.suffix(200))
    }
    if let savedDecisions: [CodexSmartDecision] = readJSON([CodexSmartDecision].self, from: codexSmartDecisionsFile) {
      codexSmartDecisions = savedDecisions
    }
    if let savedEvidence: [CodexImportedEvidenceRecord] = readJSON([CodexImportedEvidenceRecord].self, from: codexImportedEvidenceHistoryFile) {
      codexImportedEvidenceHistory = Array(savedEvidence.prefix(10))
    }
    if let savedRouteReceiptEvidence: [CodexImportedRouteReceiptRecord] = readJSON([CodexImportedRouteReceiptRecord].self, from: codexImportedRouteReceiptHistoryFile) {
      codexImportedRouteReceiptHistory = Array(savedRouteReceiptEvidence.prefix(10))
    }
    if let savedBaselineAuditEvidence: [CodexImportedBaselineAuditRecord] = readJSON([CodexImportedBaselineAuditRecord].self, from: codexImportedBaselineAuditHistoryFile) {
      codexImportedBaselineAuditHistory = Array(savedBaselineAuditEvidence.prefix(20))
    }
    if let savedRejectedBaselineAudits: [CodexRejectedBaselineAuditImport] = readJSON([CodexRejectedBaselineAuditImport].self, from: codexRejectedBaselineAuditImportsFile) {
      codexRejectedBaselineAuditImports = Array(savedRejectedBaselineAudits.prefix(20))
    }
    codexRouteReceiptBaselineDecision = readJSON(CodexRouteReceiptBaselineDecision.self, from: codexRouteReceiptBaselineDecisionFile)
    if let savedBaselineAudit: [CodexRouteReceiptBaselineAuditEvent] = readJSON([CodexRouteReceiptBaselineAuditEvent].self, from: codexRouteReceiptBaselineAuditFile) {
      codexRouteReceiptBaselineAudit = Array(savedBaselineAudit.prefix(50))
    }
    let defaults = UserDefaults.standard
    if let savedOutputRoot = defaults.string(forKey: codexOutputRootKey), !savedOutputRoot.isEmpty {
      codexOutputRootDraft = savedOutputRoot
    }
    if let savedMode = defaults.string(forKey: codexTransferModeKey),
       let mode = CodexProjectTransferMode(rawValue: savedMode) {
      codexTransferMode = mode
    }
    if defaults.object(forKey: codexCreateBackupKey) != nil {
      codexCreateBackup = defaults.bool(forKey: codexCreateBackupKey)
    }
    if defaults.object(forKey: codexIncludeGitMetadataKey) != nil {
      codexIncludeGitMetadata = defaults.bool(forKey: codexIncludeGitMetadataKey)
    }
    if defaults.object(forKey: codexIncludeFinderMetadataKey) != nil {
      codexIncludeFinderMetadata = defaults.bool(forKey: codexIncludeFinderMetadataKey)
    }
    if defaults.object(forKey: codexIncludeDependenciesKey) != nil {
      codexIncludeDependencies = defaults.bool(forKey: codexIncludeDependenciesKey)
    }
    if defaults.object(forKey: codexFullChecksumAuditKey) != nil {
      codexFullChecksumAudit = defaults.bool(forKey: codexFullChecksumAuditKey)
    }
    if let savedSmartMode = defaults.string(forKey: codexSmartScanModeKey),
       let smartMode = CodexSmartScanMode(rawValue: savedSmartMode) {
      codexSmartScanMode = smartMode
    } else {
      codexSmartScanMode = codexFullChecksumAudit ? .verified : .fastIndex
    }
    if let savedBackupMedium = defaults.string(forKey: codexBackupMediumKey),
       let backupMedium = CodexBackupMedium(rawValue: savedBackupMedium) {
      codexBackupMedium = backupMedium
    }
    if defaults.object(forKey: codexCreateCompatibilityLinkKey) != nil {
      codexCreateCompatibilityLink = defaults.bool(forKey: codexCreateCompatibilityLinkKey)
    }
    if defaults.object(forKey: codexRearmGitMainKey) != nil {
      codexRearmGitMain = defaults.bool(forKey: codexRearmGitMainKey)
    }
    if defaults.object(forKey: codexAutoResumeExistingKey) != nil {
      codexAutoResumeExisting = defaults.bool(forKey: codexAutoResumeExistingKey)
    }
    if let savedStage2Source = defaults.string(forKey: stage2SourceRootKey), !savedStage2Source.isEmpty {
      stage2SourceRootDraft = savedStage2Source
    }
    if let savedStage2Root = defaults.string(forKey: stage2ManagedRootKey), !savedStage2Root.isEmpty {
      stage2ManagedRootDraft = savedStage2Root
    }
    if let savedOwnerAccounts = defaults.string(forKey: stage2GitHubOwnerAccountsKey) {
      stage2GitHubOwnerAccountsDraft = savedOwnerAccounts
    }
    if defaults.object(forKey: stage2CreateMissingReposKey) != nil {
      stage2CreateMissingRepos = defaults.bool(forKey: stage2CreateMissingReposKey)
    }
    if let savedRetention = defaults.string(forKey: stage2SourceRetentionKey),
       let retention = Stage2SourceRetention(rawValue: savedRetention) {
      stage2SourceRetention = retention
    } else if defaults.bool(forKey: stage2RetireSourcesKey) {
      stage2SourceRetention = .retire
    }
    if defaults.object(forKey: stage2ArchiveSourcesKey) != nil {
      stage2ArchiveSources = defaults.bool(forKey: stage2ArchiveSourcesKey)
    }
    if defaults.object(forKey: stage2CleanupTransactionTempKey) != nil {
      stage2CleanupTransactionTemp = defaults.bool(forKey: stage2CleanupTransactionTempKey)
    }
    if defaults.object(forKey: stage2PrepareRuntimeKey) != nil {
      stage2PrepareRuntime = defaults.bool(forKey: stage2PrepareRuntimeKey)
    }
    if let savedStage2Open = defaults.string(forKey: stage2OpenAfterApplyKey),
       let openOption = Stage2OpenOption(rawValue: savedStage2Open) {
      stage2OpenAfterApply = openOption
    }
    if let savedScope = defaults.string(forKey: codexLifecycleScopeKey),
       let scope = CodexLifecycleScope(rawValue: savedScope) {
      codexLifecycleScope = scope
    }
    if defaults.object(forKey: codexLifecycleDeleteStage1Key) != nil {
      codexLifecycleDeleteStage1Originals = defaults.bool(forKey: codexLifecycleDeleteStage1Key)
    }
    if defaults.object(forKey: codexLifecycleRunStage2Key) != nil {
      codexLifecycleRunStage2 = defaults.bool(forKey: codexLifecycleRunStage2Key)
    }
    if let savedCleanup = defaults.string(forKey: codexLifecycleCleanupScopeKey),
       let cleanup = CodexLifecycleCleanupScope(rawValue: savedCleanup) {
      codexLifecycleCleanupScope = cleanup
    }
    administratorTerminalMode = defaults.bool(forKey: administratorTerminalModeKey)
    if appSettings.privacyFirstMode == false,
       let loadedContexts: [SavedGitHubContext] = readJSON([SavedGitHubContext].self, from: contextsFile) {
      savedContexts = loadedContexts
    } else {
      savedContexts = []
      try? fm.removeItem(atPath: contextsFile)
    }
    if let loadedTasks: [ProjectTaskTemplate] = readJSON([ProjectTaskTemplate].self, from: taskTemplatesFile) {
      taskTemplates = loadedTasks
    }
    if let loadedFavorites: [String] = readJSON([String].self, from: favoriteProjectsFile) {
      favoriteProjects = Set(loadedFavorites)
    }
    if let loadedViews: [SavedProjectView] = readJSON([SavedProjectView].self, from: savedViewsFile) {
      savedProjectViews = loadedViews
    }
    incidents = CSAiEMIncidentStore.load(from: incidentsFile)
    if let loadedIssueTemplates: [GitHubIssueTemplate] = readJSON([GitHubIssueTemplate].self, from: issueTemplatesFile), !loadedIssueTemplates.isEmpty {
      issueTemplates = loadedIssueTemplates
    } else {
      issueTemplates = Self.defaultIssueTemplates
    }
    issueMutationRetries = readJSON([CSAiEMGitHubIssueRetryRecord].self, from: issueMutationRetriesFile) ?? []

    loadSnapshots()
    if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      host = appSettings.defaultGitHubHost
    }
  }

  private func persistSettings() {
    writeJSON(appSettings, to: settingsFile)
  }

  private func persistIssueMutationRetries() {
    writeJSON(issueMutationRetries, to: issueMutationRetriesFile)
  }

  private func persistCodexScanRoots() {
    writeJSON(parsedCodexScanRoots(), to: codexScanRootsFile)
  }

  private func persistCodexImportedEvidenceHistory() {
    writeJSON(Array(codexImportedEvidenceHistory.prefix(10)), to: codexImportedEvidenceHistoryFile)
  }

  private func persistCodexImportedRouteReceiptHistory() {
    writeJSON(Array(codexImportedRouteReceiptHistory.prefix(10)), to: codexImportedRouteReceiptHistoryFile)
  }

  private func persistCodexImportedBaselineAuditHistory() {
    writeJSON(Array(codexImportedBaselineAuditHistory.prefix(20)), to: codexImportedBaselineAuditHistoryFile)
  }

  private func persistCodexRejectedBaselineAuditImports() {
    writeJSON(Array(codexRejectedBaselineAuditImports.prefix(20)), to: codexRejectedBaselineAuditImportsFile)
  }

  private func persistCodexRouteReceiptBaselineDecision() {
    if let decision = codexRouteReceiptBaselineDecision {
      writeJSON(decision, to: codexRouteReceiptBaselineDecisionFile)
    } else {
      try? FileManager.default.removeItem(atPath: codexRouteReceiptBaselineDecisionFile)
    }
  }

  private func persistCodexRouteReceiptBaselineAudit() {
    writeJSON(Array(codexRouteReceiptBaselineAudit.prefix(50)), to: codexRouteReceiptBaselineAuditFile)
  }

  private func configureStage2DefaultsIfNeeded() {
    let defaults = UserDefaults.standard
    let roots = resolvedProfileRoots()
    let codeParent = (roots.codeRoot as NSString).deletingLastPathComponent
    let importParent = (roots.importRoot as NSString).deletingLastPathComponent
    let runtimeParent = (roots.runtimeRoot as NSString).deletingLastPathComponent
    let managedRoot = codeParent == importParent && codeParent == runtimeParent
      ? codeParent
      : publicDefaultRoot

    if defaults.object(forKey: stage2ManagedRootKey) == nil {
      stage2ManagedRootDraft = managedRoot
    }
    if defaults.object(forKey: stage2SourceRootKey) == nil {
      let stage1Output = normalizeWorkspacePath(codexOutputRootDraft)
      if !stage1Output.isEmpty {
        stage2SourceRootDraft = stage1Output
      } else if (managedRoot as NSString).lastPathComponent == "CSA-iEM" {
        stage2SourceRootDraft = ((managedRoot as NSString).deletingLastPathComponent as NSString)
          .appendingPathComponent("CODEX PROJECTS")
      }
    }
  }

  private func persistContexts() {
    writeJSON(savedContexts, to: contextsFile)
  }

  private func persistTasks() {
    writeJSON(taskTemplates, to: taskTemplatesFile)
  }

  private func persistFavorites() {
    writeJSON(Array(favoriteProjects).sorted(), to: favoriteProjectsFile)
  }

  private func persistSavedViews() {
    writeJSON(savedProjectViews, to: savedViewsFile)
  }

  private func loadSnapshots() {
    let fm = FileManager.default
    let snapshotFiles = (try? fm.contentsOfDirectory(atPath: snapshotsDirectory))?.sorted() ?? []
    var loaded: [SnapshotEntry] = []
    for file in snapshotFiles where file.hasSuffix(".json") {
      let path = (snapshotsDirectory as NSString).appendingPathComponent(file)
      if let entry: SnapshotEntry = readJSON(SnapshotEntry.self, from: path) {
        loaded.append(entry)
      }
    }
    snapshots = loaded.sorted { $0.createdAt > $1.createdAt }
  }

  private func writeSnapshot(_ entry: SnapshotEntry) {
    let path = (snapshotsDirectory as NSString).appendingPathComponent("\(entry.id).json")
    writeJSON(entry, to: path)
    loadSnapshots()
  }

  private func deleteSnapshot(_ entry: SnapshotEntry) {
    let jsonPath = (snapshotsDirectory as NSString).appendingPathComponent("\(entry.id).json")
    let payloadPath = (snapshotsDirectory as NSString).appendingPathComponent(entry.id)
    try? FileManager.default.removeItem(atPath: jsonPath)
    try? FileManager.default.removeItem(atPath: payloadPath)
    loadSnapshots()
  }

  private func writeJSON<T: Encodable>(_ value: T, to path: String) {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(value) else { return }
    try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
  }

  private func readJSON<T: Decodable>(_ type: T.Type, from path: String) -> T? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
      return nil
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(T.self, from: data)
  }

  func setWorkspaceStyle(_ style: WorkspaceStyle) {
    switch style {
    case .single:
      selectedProfile = .wtl
    case .split:
      selectedProfile = .public
    }
  }

  func applyStandardWorkspace() {
    let suggestion = standardWorkspaceSuggestion
    applyWorkspaceSuggestion(suggestion)
  }

  func enableAutoMode() {
    selectedProfile = .public
    useCurrentRoot = true
    syncWorkspaceDraftsFromResolvedRoots()
    refreshOperatorState()
    settingsStatus = "Auto mode is using the Default workspace and current saved roots."
  }

  func applyDetectedWorkspace() {
    guard let suggestion = detectedWorkspaceSuggestion else {
      appendLog("[gui] No detected workspace setup was found on this Mac.\n")
      return
    }
    applyWorkspaceSuggestion(suggestion)
  }

  func saveWorkspaceDrafts() {
    let codeRoot = normalizeWorkspacePath(workspaceCodeRootDraft.isEmpty ? publicDefaultCodeRoot : workspaceCodeRootDraft)
    let importRoot = normalizeWorkspacePath(workspaceImportRootDraft.isEmpty ? publicDefaultImportRoot : workspaceImportRootDraft)
    let runtimeRoot = normalizeWorkspacePath(workspaceRuntimeRootDraft.isEmpty ? publicDefaultRuntimeRoot : workspaceRuntimeRootDraft)
    writeProfileConfig(
      profile: selectedProfile,
      values: [
        "SAVED_CODE_ROOT": codeRoot,
        "SAVED_IMPORT_ROOT": importRoot,
        "SAVED_RUNTIME_ROOT": runtimeRoot
      ]
    )
    useCurrentRoot = true
    syncWorkspaceDraftsFromResolvedRoots()
    refreshLocalProjects()
  }

  func chooseSingleWorkspaceFolder() {
    let startingPath = workspaceSingleRootDraft.isEmpty ? profileRootSummary.runtimeRoot : workspaceSingleRootDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceSingleRootDraft = selectedPath
    }
  }

  func chooseCodeWorkspaceFolder() {
    let startingPath = workspaceCodeRootDraft.isEmpty ? profileRootSummary.codeRoot : workspaceCodeRootDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceCodeRootDraft = selectedPath
    }
  }

  func chooseImportWorkspaceFolder() {
    let startingPath = workspaceImportRootDraft.isEmpty ? profileRootSummary.importRoot : workspaceImportRootDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceImportRootDraft = selectedPath
    }
  }

  func chooseRuntimeWorkspaceFolder() {
    let startingPath = workspaceRuntimeRootDraft.isEmpty ? profileRootSummary.runtimeRoot : workspaceRuntimeRootDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceRuntimeRootDraft = selectedPath
    }
  }

  func chooseWorkspaceMoveDestinationFolder() {
    let startingPath = workspaceMoveDestinationDraft.isEmpty ? NSString(string: "~").expandingTildeInPath : workspaceMoveDestinationDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceMoveDestinationDraft = selectedPath
    }
  }

  func chooseLocalExportDestinationFolder() {
    let startingPath = localExportDestinationDraft.isEmpty ? NSString(string: "~").expandingTildeInPath : localExportDestinationDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      localExportDestinationDraft = selectedPath
    }
  }

  func scanExternalVolumes() {
    // File Provider and slow external disks can block volume metadata calls.
    // Keep startup and the SwiftUI main thread responsive while scanning.
    DispatchQueue.global(qos: .utility).async { [weak self] in
      let fm = FileManager.default
      let volumesRoot = "/Volumes"
      let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsLocalKey]
      let urls = (try? fm.contentsOfDirectory(
        at: URL(fileURLWithPath: volumesRoot, isDirectory: true),
        includingPropertiesForKeys: Array(keys),
        options: [.skipsHiddenFiles]
      )) ?? []

      let volumes = urls.compactMap { url -> ExternalVolumeEntry? in
        guard let values = try? url.resourceValues(forKeys: keys), values.volumeIsLocal == true else { return nil }
        let path = (url.path as NSString).standardizingPath
        let name = url.lastPathComponent
        let itemType = (try? fm.attributesOfItem(atPath: url.path)[.type]) as? FileAttributeType
        guard path != volumesRoot, name.isEmpty == false, itemType != .typeSymbolicLink else { return nil }
        return ExternalVolumeEntry(
          path: path,
          name: name,
          totalCapacity: Int64(values.volumeTotalCapacity ?? 0),
          availableCapacity: Int64(values.volumeAvailableCapacity ?? 0)
        )
      }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

      DispatchQueue.main.async {
        guard let self else { return }
        self.externalVolumes = volumes
        if self.selectedExternalVolumePath.isEmpty || !volumes.contains(where: { $0.path == self.selectedExternalVolumePath }) {
          self.selectedExternalVolumePath = volumes.first?.path ?? ""
        }
        self.externalVolumesStatus = volumes.isEmpty
          ? "No mounted external drives detected. Connect a drive, then refresh, or choose any destination folder manually."
          : "Detected \(volumes.count) mounted external drive\(volumes.count == 1 ? "" : "s")."
      }
    }
  }

  func selectExternalVolume(_ volume: ExternalVolumeEntry) {
    selectedExternalVolumePath = volume.path
    localExportDestinationDraft = volume.path
    workspaceMoveDestinationDraft = volume.path
    externalVolumesStatus = "Selected \(volume.name) as the backup or move destination."
  }

  func externalWorkspaceBase(for volume: ExternalVolumeEntry) -> String {
    (volume.path as NSString).appendingPathComponent("CSA-iEM")
  }

  func setExternalVolumeAsDefault(_ volume: ExternalVolumeEntry) {
    let base = externalWorkspaceBase(for: volume)
    let code = (base as NSString).appendingPathComponent("Code")
    let importRoot = (base as NSString).appendingPathComponent("Import")
    let runtime = (base as NSString).appendingPathComponent("Runtime")
    writeProfileConfig(profile: .public, values: [
      "SAVED_CODE_ROOT": code,
      "SAVED_IMPORT_ROOT": importRoot,
      "SAVED_RUNTIME_ROOT": runtime
    ])
    selectedProfile = .public
    useCurrentRoot = true
    selectedExternalVolumePath = volume.path
    workspaceMoveDestinationDraft = base
    localExportDestinationDraft = volume.path
    syncWorkspaceDraftsFromResolvedRoots()
    refreshLocalProjects()
    externalVolumesStatus = "\(volume.name) is now the saved Default workspace. Existing local files were not moved."
  }

  func prepareExternalDefaultMove(_ volume: ExternalVolumeEntry) {
    selectedExternalVolumePath = volume.path
    workspaceMoveDestinationDraft = externalWorkspaceBase(for: volume)
    localExportDestinationDraft = volume.path
    externalDefaultMoveConfirmed = false
    previewWorkspaceMove(.workspace)
    externalVolumesStatus = "Preview ready. Confirm the move below before relocating all current workspace roots to \(volume.name)."
  }

  func moveWorkspaceToExternalDefault(_ volume: ExternalVolumeEntry) {
    guard externalDefaultMoveConfirmed else {
      externalVolumesStatus = "Confirm that you reviewed the preview before moving all local workspace roots."
      return
    }
    selectedExternalVolumePath = volume.path
    workspaceMoveDestinationDraft = externalWorkspaceBase(for: volume)
    relocateWorkspace(.workspace)
  }

  func restoreInternalDefaultWorkspace() {
    writeProfileConfig(profile: .public, values: [
      "SAVED_CODE_ROOT": publicDefaultCodeRoot,
      "SAVED_IMPORT_ROOT": publicDefaultImportRoot,
      "SAVED_RUNTIME_ROOT": publicDefaultRuntimeRoot
    ])
    selectedProfile = .public
    useCurrentRoot = true
    externalDefaultMoveConfirmed = false
    syncWorkspaceDraftsFromResolvedRoots()
    refreshLocalProjects()
    externalVolumesStatus = "Restored the Default workspace paths under \(publicDefaultRoot). Files remain where they are until you copy or move them."
  }

  func revealExternalWorkspace(_ volume: ExternalVolumeEntry) {
    let base = externalWorkspaceBase(for: volume)
    try? FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
    revealPath(base)
  }


  func revealExternalVolume(_ volume: ExternalVolumeEntry) {
    revealPath(volume.path)
  }

  func scanLegacyWorkspaces() {
    let roots = resolvedProfileRoots()
    let currentRoots: Set<String> = [
      normalizeWorkspacePath(roots.codeRoot),
      normalizeWorkspacePath(roots.importRoot),
      normalizeWorkspacePath(roots.runtimeRoot)
    ]
    DispatchQueue.global(qos: .utility).async { [weak self] in
      let candidates = Self.scanLegacyWorkspaceCandidates(excluding: currentRoots)
      DispatchQueue.main.async {
        guard let self else { return }
        self.legacyWorkspaceCandidates = candidates
        if self.selectedLegacyWorkspaceID.isEmpty || !candidates.contains(where: { $0.id == self.selectedLegacyWorkspaceID }) {
          self.selectedLegacyWorkspaceID = candidates.first?.id ?? ""
        }
        self.legacyWorkspaceScanStatus = candidates.isEmpty
          ? "No older workspace roots were found."
          : "Found \(candidates.count) older workspace roots ready for review."

        if self.recoveryCandidate == nil, let firstCandidate = candidates.first {
          self.recoveryCandidate = firstCandidate
          self.recoverySourcePath = firstCandidate.runtimeRoot
          self.recoverySourceStatus = "Auto-detected \(firstCandidate.label). Review the source and active roots, then recover missing files."
        } else if candidates.isEmpty, self.recoveryCandidate == nil {
          self.recoverySourceStatus = "No known old roots were detected. Choose a source folder to scan manually."
        }
      }
    }
  }

  func migrateSelectedLegacyWorkspace() {
    guard let candidate = legacyWorkspaceCandidates.first(where: { $0.id == selectedLegacyWorkspaceID }) else {
      legacyWorkspaceScanStatus = "Select a scanned old workspace before migrating."
      return
    }

    let roots = resolvedProfileRoots()
    let mode = localFileTransferMode
    let overwrite = overwriteLocalFileDestination
    let environment = baseEnvironment()
    let jobID = createJob(kind: "Migration", title: "Import old workspace", target: candidate.label, detail: "Migrating old workspace into current roots…", initialState: .running)
    legacyWorkspaceScanStatus = "\(mode.label) in progress from \(candidate.label)..."
    appendLog("[gui] \(mode.label) old workspace \(candidate.label) into current roots.\n")

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      do {
        let summary = try Self.migrateLegacyWorkspace(
          candidate: candidate,
          destinationRoots: roots,
          mode: mode,
          overwrite: overwrite,
          environment: environment
        )
        DispatchQueue.main.async {
          self.legacyWorkspaceScanStatus = summary
          self.localFilesStatus = summary
          self.appendLog("[gui] \(summary)\n")
          self.finishJob(id: jobID, state: .succeeded, detail: summary)
          self.refreshOperatorState()
          self.scanLegacyWorkspaces()
        }
      } catch {
        DispatchQueue.main.async {
          self.legacyWorkspaceScanStatus = error.localizedDescription
          self.appendLog("[gui] Old workspace migration failed: \(error.localizedDescription)\n")
          self.finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
        }
      }
    }
  }

  func chooseRecoverySource() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Scan Folder"
    panel.message = "Choose the old, backup, or partially moved CSA-iEM workspace."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    recoverySourcePath = url.path
    scanRecoverySource()
  }

  func scanRecoverySource() {
    let source = normalizeWorkspacePath(recoverySourcePath)
    guard !source.isEmpty, FileManager.default.fileExists(atPath: source) else {
      recoveryCandidate = nil
      recoverySourceStatus = "Choose an existing source folder before scanning."
      return
    }

    let codeRoot = FileManager.default.fileExists(atPath: (source as NSString).appendingPathComponent("Code"))
      ? (source as NSString).appendingPathComponent("Code") : source
    let importRoot = (source as NSString).appendingPathComponent("Import")
    let runtimeRoot = FileManager.default.fileExists(atPath: (source as NSString).appendingPathComponent("Runtime"))
      ? (source as NSString).appendingPathComponent("Runtime") : source
    let codeRepos = (codeRoot as NSString).appendingPathComponent("Repos")
    let runtimeRepos = (runtimeRoot as NSString).appendingPathComponent("Repos")
    let runners = (runtimeRoot as NSString).appendingPathComponent("Runners")
    let candidate = LegacyWorkspaceCandidate(
      id: "recovery|\(source)",
      label: "Recovery source: \((source as NSString).lastPathComponent)",
      codeRoot: codeRoot,
      importRoot: importRoot,
      runtimeRoot: runtimeRoot,
      projectCount: Self.countOwnerRepoChildren(under: codeRepos) + (runtimeRepos == codeRepos ? 0 : Self.countOwnerRepoChildren(under: runtimeRepos)),
      runnerCount: Self.countOwnerRepoChildren(under: runners)
    )
    recoveryCandidate = candidate
    recoverySourceStatus = "Recovery scan ready. \(candidate.summary) will be merged into the active workspace roots."
  }

  func recoverSelectedSource() {
    guard let candidate = recoveryCandidate else {
      recoverySourceStatus = "Scan a recovery source before starting."
      return
    }
    let roots = resolvedProfileRoots()
    let mode: LocalFileTransferMode = .copyBackup
    let environment = baseEnvironment()
    let jobID = createJob(kind: "Recovery", title: "Recover local workspace", target: candidate.label, detail: "Merging recoverable files into current roots…", initialState: .running)
    isRunningLocalFileOperation = true
    recoverySourceStatus = "Recovery in progress. Existing destination files are preserved."

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      do {
        let summary = try Self.migrateLegacyWorkspace(candidate: candidate, destinationRoots: roots, mode: mode, overwrite: false, environment: environment)
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.recoverySourceStatus = summary
          self.localFilesStatus = summary
          self.appendLog("[gui] \(summary)\n")
          self.finishJob(id: jobID, state: .succeeded, detail: summary)
          self.refreshLocalProjects()
          self.refreshLiveServices()
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.recoverySourceStatus = "Recovery stopped: \(error.localizedDescription)"
          self.appendLog("[gui] Recovery failed: \(error.localizedDescription)\n")
          self.finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
        }
      }
    }
  }

  func relocateWorkspace(_ scope: WorkspaceRelocationScope) {
    let baseDestination = normalizeWorkspacePath(workspaceMoveDestinationDraft)
    guard !baseDestination.isEmpty else {
      localFilesStatus = "Choose a destination folder before moving workspace files."
      return
    }

    let roots = resolvedProfileRoots()
    let currentStyle = selectedWorkspaceStyle
    let environment = baseEnvironment()
    let overwrite = overwriteLocalFileDestination

    isRunningLocalFileOperation = true
    localFilesStatus = "Moving workspace files..."
    appendLog("[gui] Starting workspace move to \(baseDestination)\n")

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        let outcome = try Self.relocateWorkspaceRoots(
          scope: scope,
          style: currentStyle,
          codeRoot: roots.codeRoot,
          importRoot: roots.importRoot,
          runtimeRoot: roots.runtimeRoot,
          destinationBase: baseDestination,
          overwrite: overwrite,
          environment: environment
        )

        DispatchQueue.main.async {
          switch outcome.result {
          case .single(let newRoot):
            self.writeProfileConfig(profile: .public, values: ["SAVED_DEFAULT_ROOT": newRoot])
            self.selectedProfile = .public
          case .split(let newCodeRoot, let newImportRoot, let newRuntimeRoot):
            self.writeProfileConfig(
              profile: self.selectedProfile,
              values: [
                "SAVED_CODE_ROOT": newCodeRoot,
                "SAVED_IMPORT_ROOT": newImportRoot,
                "SAVED_RUNTIME_ROOT": newRuntimeRoot
              ]
            )
          }
          self.useCurrentRoot = true
          self.syncWorkspaceDraftsFromResolvedRoots()
          self.isRunningLocalFileOperation = false
          self.localOperationPreview = nil
          if outcome.warnings.isEmpty {
            self.localFilesStatus = "Workspace move finished."
          } else {
            self.localFilesStatus = "Workspace move finished with cleanup warnings."
            outcome.warnings.forEach { self.appendLog("[gui] \($0)\n") }
          }
          self.appendLog("[gui] Workspace move finished.\n")
          self.refreshLocalProjects()
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.localFilesStatus = error.localizedDescription
          self.appendLog("[gui] Workspace move failed: \(error.localizedDescription)\n")
        }
      }
    }
  }

  func runLocalExport() {
    let destination = normalizeWorkspacePath(localExportDestinationDraft)
    guard !destination.isEmpty else {
      localFilesStatus = "Choose an export destination before running a backup or export."
      return
    }

    let exportMode = localFileTransferMode
    let exportScope = localFileExportScope
    let selectedProjects = self.selectedLocalProjects
    let roots = resolvedProfileRoots()
    let overwrite = overwriteLocalFileDestination
    let includeCode = includeProjectCodeExport
    let includeRuntime = includeProjectRuntimeExport
    let includeRunners = includeProjectRunnerExport
    let environment = baseEnvironment()
    let preparedStamp = localExportPreparedStamp.isEmpty ? Self.timestampStamp() : localExportPreparedStamp

    if exportScope == .selectedProjects && selectedProjects.isEmpty {
      localFilesStatus = "Target one or more local projects before exporting selected projects."
      return
    }

    if exportScope == .selectedProjects && !includeCode && !includeRuntime && !includeRunners {
      localFilesStatus = "Choose at least one selected-project export option: code, runtime, or runner folders."
      return
    }

    isRunningLocalFileOperation = true
    localFilesStatus = "Running local file export..."
    appendLog("[gui] Starting \(exportMode.label.lowercased()) to \(destination)\n")

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        let summary = try Self.exportLocalFiles(
          scope: exportScope,
          mode: exportMode,
          destinationBase: destination,
          preparedStamp: preparedStamp,
          roots: roots,
          selectedProjects: selectedProjects,
          includeCode: includeCode,
          includeRuntime: includeRuntime,
          includeRunners: includeRunners,
          overwrite: overwrite,
          environment: environment
        )

        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.localExportPreparedStamp = ""
          self.localOperationPreview = nil
          self.localFilesStatus = summary
          self.appendLog("[gui] \(summary)\n")
          self.refreshLocalProjects()
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.localExportPreparedStamp = ""
          self.localFilesStatus = error.localizedDescription
          self.appendLog("[gui] Local file export failed: \(error.localizedDescription)\n")
        }
      }
    }
  }

  func reloadAuthInventory() {
    hostConfigs = parseGitHubConfig()
    availableHosts = hostConfigs.map(\.host)

    if !availableHosts.isEmpty {
      if availableHosts.contains(host) == false {
        host = availableHosts.first ?? "github.com"
      }
    } else if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      host = "github.com"
    }

    reloadAccountChoices()
  }

  func reloadAccountChoices() {
    let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let hostConfig = hostConfigs.first(where: { $0.host == currentHost })
    var accounts = hostConfig?.users ?? []

    if accounts.isEmpty, let activeUser = hostConfig?.activeUser, !activeUser.isEmpty {
      accounts = [activeUser]
    }

    availableAccounts = accounts

    if let existing = hostConfig?.users.first(where: { $0 == account }) {
      account = existing
      return
    }

    if let active = hostConfig?.activeUser, !active.isEmpty {
      account = active
    } else if let first = accounts.first {
      account = first
    } else if availableAccounts.isEmpty {
      account = ""
    }
  }

  func clearRepoCatalog(resetOwner: Bool) {
    availableRepos = []
    selectedRepos = []
    repoSearch = ""
    repoCatalogStatus = "Load repositories for the selected GitHub account or owner."

    if resetOwner {
      repoOwner = ""
    }
  }

  func openImportedProjectsInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse-projects"], exitLabel: "Imported Projects") else {
      return
    }
    openTerminalCommand(command)
  }

  func refreshLocalProjects() {
    isLoadingLocalProjects = true
    localProjectStatus = "Scanning local projects for the \(workspaceStyleLabel.lowercased()) workspace..."
    let workspaceLabel = workspaceStyleLabel
    let roots = resolvedProfileRoots()

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.scanLocalProjects(
        workspaceLabel: workspaceLabel,
        codeRoot: roots.codeRoot,
        runtimeRoot: roots.runtimeRoot
      )

      DispatchQueue.main.async {
        if result.projects.isEmpty,
           !self.isAutoRecoveringWorkspace,
           let fallback = self.workspaceRecoverySuggestion(currentCodeRoot: roots.codeRoot, currentRuntimeRoot: roots.runtimeRoot) {
          self.isLoadingLocalProjects = false
          self.isAutoRecoveringWorkspace = true
          self.localProjectStatus = "No local projects were found in the current workspace. Switching to \(fallback.title.lowercased()) and rescanning..."
          self.applyRecoveredWorkspaceSuggestion(fallback)
          self.isAutoRecoveringWorkspace = false
          return
        }
        self.isLoadingLocalProjects = false
        self.localProjects = result.projects
        self.localProjectStatus = result.status
        self.refreshLiveServices()
      }
    }
  }

  private func workspaceRecoverySuggestion(currentCodeRoot: String, currentRuntimeRoot: String) -> WorkspaceSuggestion? {
    let currentCode = normalizeWorkspacePath(currentCodeRoot)
    let currentRuntime = normalizeWorkspacePath(currentRuntimeRoot)
    var candidates: [WorkspaceSuggestion] = []

    if let detected = detectedWorkspaceConfiguration() {
      candidates.append(detected)
    }
    if let saved = savedWorkspaceConfiguration() {
      candidates.append(saved)
    }

    var seenKeys: Set<String> = []
    for candidate in candidates {
      let key = "\(candidate.profile.rawValue)|\(normalizeWorkspacePath(candidate.codeRoot))|\(normalizeWorkspacePath(candidate.importRoot))|\(normalizeWorkspacePath(candidate.runtimeRoot))"
      guard seenKeys.insert(key).inserted else { continue }

      let candidateCode = normalizeWorkspacePath(candidate.codeRoot)
      let candidateRuntime = normalizeWorkspacePath(candidate.runtimeRoot)
      if candidateCode == currentCode && candidateRuntime == currentRuntime {
        continue
      }

      let candidateResult = Self.scanLocalProjects(
        workspaceLabel: candidate.profile == .wtl ? "legacy single-root" : "three-root",
        codeRoot: candidateCode,
        runtimeRoot: candidateRuntime
      )
      if !candidateResult.projects.isEmpty {
        return candidate
      }
    }

    return nil
  }

  private func applyRecoveredWorkspaceSuggestion(_ suggestion: WorkspaceSuggestion) {
    selectedProfile = suggestion.profile
    useCurrentRoot = true
    syncWorkspaceDraftsFromResolvedRoots()
  }

  func refreshLiveServices() {
    isLoadingLiveServices = true
    liveServicesStatus = "Scanning active devcontainers and runner services for the current workspace..."
    let roots = resolvedProfileRoots()
    let currentProjects = localProjects
    let environment = baseEnvironment()
    let includeDockerChecks = appSettings.runDockerChecksOnRefresh

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.scanLiveServices(
        localProjects: currentProjects,
        runtimeRoot: roots.runtimeRoot,
        includeDocker: includeDockerChecks,
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingLiveServices = false
        self.activeContainers = result.containers
        self.runnerServices = result.runners
        self.liveServicesStatus = result.status
      }
    }
  }

  func openLocalProject(_ project: LocalProjectEntry, preferRuntime: Bool) {
    openProjectPaths(
      codePath: project.codePath,
      runtimePath: project.runtimePath,
      fallbackPath: project.preferredOpenPath,
      preferRuntime: preferRuntime,
      label: project.slug
    )
  }

  func openLocalProject(_ project: LocalProjectEntry, preferRuntime: Bool, inApplication appName: String) {
    openProjectPaths(
      codePath: project.codePath,
      runtimePath: project.runtimePath,
      fallbackPath: project.preferredOpenPath,
      preferRuntime: preferRuntime,
      label: project.slug,
      appName: appName
    )
  }

  func openPrimaryLocalProject(preferRuntime: Bool) {
    guard let project = primaryLocalProject else {
      appendLog("[gui] No loaded local project is available to open.\n")
      return
    }
    openLocalProject(project, preferRuntime: preferRuntime)
  }

  func openPrimaryLocalProject(preferRuntime: Bool, inApplication appName: String) {
    guard let project = primaryLocalProject else {
      appendLog("[gui] No loaded local project is available to open in \(appName).\n")
      return
    }
    openLocalProject(project, preferRuntime: preferRuntime, inApplication: appName)
  }

  func revealLocalProject(_ project: LocalProjectEntry) {
    guard let targetPath = project.preferredOpenPath else {
      appendLog("[gui] No local path was found for \(project.slug)\n")
      return
    }
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: targetPath)])
  }

  func revealPrimaryLocalProject() {
    guard let project = primaryLocalProject else {
      appendLog("[gui] No loaded local project is available to reveal.\n")
      return
    }
    revealLocalProject(project)
  }

  func copyPrimaryLocalProjectSlug() {
    guard let slug = primaryLocalProject?.slug else {
      appendLog("[gui] No loaded local project is available to copy.\n")
      return
    }
    copyToClipboard(slug, label: "project slug")
  }

  func copyPrimaryLocalProjectPath() {
    guard let project = primaryLocalProject else {
      appendLog("[gui] No loaded local project is available to copy.\n")
      return
    }
    let path = project.preferredOpenPath ?? project.codePath ?? project.runtimePath ?? project.slug
    copyToClipboard(path, label: "project path")
  }

  func copyPrimaryLocalProjectURL() {
    guard let slug = primaryLocalProject?.slug else {
      appendLog("[gui] No loaded local project is available to copy.\n")
      return
    }

    let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appSettings.defaultGitHubHost : host
    guard let url = URL(string: "https://\(normalizedHost)/\(slug)") else {
      appendLog("[gui] Could not build a repository URL for \(slug).\n")
      return
    }
    copyToClipboard(url.absoluteString, label: "repository URL")
  }

  func openPrimaryLocalProjectInTerminal() {
    guard let project = primaryLocalProject else {
      appendLog("[gui] No loaded local project is available to open in Terminal.\n")
      return
    }
    let path = project.preferredOpenPath ?? project.codePath ?? project.runtimePath
    guard let path, !path.isEmpty else {
      appendLog("[gui] No local path was found for \(project.slug)\n")
      return
    }
    openTerminalCommand("cd \(shellQuote(path)) && exec \(shellQuote(ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"))")
  }

  func openPrimaryLocalProjectInBrowser() {
    guard let slug = primaryLocalProject?.slug else {
      appendLog("[gui] No loaded local project is available to open in the browser.\n")
      return
    }

    let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appSettings.defaultGitHubHost : host
    guard let url = URL(string: "https://\(normalizedHost)/\(slug)") else {
      appendLog("[gui] Could not build a browser URL for \(slug).\n")
      return
    }
    NSWorkspace.shared.open(url)
    appendLog("[gui] Opening repository in browser: \(url.absoluteString)\n")
  }

  func revealCodeRoot() {
    let roots = resolvedProfileRoots()
    revealPath(roots.codeRoot)
  }

  func copyCodeRoot() {
    copyToClipboard(resolvedProfileRoots().codeRoot, label: "code root")
  }

  func revealImportRoot() {
    let roots = resolvedProfileRoots()
    revealPath(roots.importRoot)
  }

  func copyImportRoot() {
    copyToClipboard(resolvedProfileRoots().importRoot, label: "import root")
  }

  func revealRuntimeRoot() {
    let roots = resolvedProfileRoots()
    revealPath(roots.runtimeRoot)
  }

  func copyRuntimeRoot() {
    copyToClipboard(resolvedProfileRoots().runtimeRoot, label: "runtime root")
  }

  func copyWorkspaceSummary() {
    let roots = resolvedProfileRoots()
    let summary = [
      "Profile: \(selectedProfile.label)",
      "Code: \(roots.codeRoot)",
      "Import: \(roots.importRoot)",
      "Runtime: \(roots.runtimeRoot)"
    ].joined(separator: "\n")
    copyToClipboard(summary, label: "workspace summary")
  }

  func openApplicationSupportFolder() {
    revealPath(appSupportDir)
  }

  func openSettingsFolder() {
    revealPath(profileConfigDir)
  }

  func resetLaunchWarningAcceptance() {
    appSettings.firstRunComplete = false
    persistSettings()
    settingsStatus = "Launch warning reset. The agreement sheet will show again on next launch."
  }

  func openContainerProject(_ entry: LiveContainerEntry, preferRuntime: Bool) {
    openProjectPaths(
      codePath: entry.codePath,
      runtimePath: entry.runtimePath,
      fallbackPath: entry.workspacePath,
      preferRuntime: preferRuntime,
      label: entry.slug
    )
  }

  func openContainerProject(_ entry: LiveContainerEntry, preferRuntime: Bool, inApplication appName: String) {
    openProjectPaths(
      codePath: entry.codePath,
      runtimePath: entry.runtimePath,
      fallbackPath: entry.workspacePath,
      preferRuntime: preferRuntime,
      label: entry.slug,
      appName: appName
    )
  }

  func revealContainer(_ entry: LiveContainerEntry) {
    revealPath(entry.workspacePath)
  }

  func stopContainer(_ entry: LiveContainerEntry) {
    guard let dockerPath else {
      appendLog("[gui] Docker CLI was not found.\n")
      return
    }

    appendLog("[gui] Stopping devcontainer \(entry.name) for \(entry.slug)\n")
    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: dockerPath,
        arguments: ["stop", entry.containerID],
        environment: environment
      )

      DispatchQueue.main.async {
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
          self.appendLog(result.output + "\n")
        }
        self.refreshLiveServices()
      }
    }
  }

  func removeContainer(_ entry: LiveContainerEntry) {
    guard let dockerPath else {
      appendLog("[gui] Docker CLI was not found.\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Container", title: "Remove container", target: entry.slug, detail: "Removing container…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: dockerPath,
        arguments: ["rm", "-f", entry.containerID],
        environment: environment
      )

      DispatchQueue.main.async {
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          self.appendLog(result.output + "\n")
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: "Container removed.")
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to remove container." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
        self.refreshLiveServices()
      }
    }
  }

  func openContainerLogs(_ entry: LiveContainerEntry) {
    guard let dockerPath else {
      appendLog("[gui] Docker CLI was not found.\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Container", title: "Container logs", target: entry.slug, detail: "Loading container logs…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: dockerPath,
        arguments: ["logs", "--tail", "200", entry.containerID],
        environment: environment
      )

      DispatchQueue.main.async {
        if !result.output.isEmpty {
          self.appendLog(result.output + (result.output.hasSuffix("\n") ? "" : "\n"))
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: "Container logs loaded.")
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load container logs." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func openRunnerProject(_ entry: RunnerServiceEntry, preferRuntime: Bool) {
    openProjectPaths(
      codePath: entry.codePath,
      runtimePath: entry.runtimePath,
      fallbackPath: entry.runnerPath,
      preferRuntime: preferRuntime,
      label: entry.slug
    )
  }

  func openRunnerProject(_ entry: RunnerServiceEntry, preferRuntime: Bool, inApplication appName: String) {
    openProjectPaths(
      codePath: entry.codePath,
      runtimePath: entry.runtimePath,
      fallbackPath: entry.runnerPath,
      preferRuntime: preferRuntime,
      label: entry.slug,
      appName: appName
    )
  }

  func revealRunnerService(_ entry: RunnerServiceEntry) {
    revealPath(entry.runnerPath)
  }

  func stopRunnerService(_ entry: RunnerServiceEntry) {
    let svcPath = (entry.runnerPath as NSString).appendingPathComponent("svc.sh")
    guard FileManager.default.isExecutableFile(atPath: svcPath) else {
      appendLog("[gui] Runner service script was not found for \(entry.slug)\n")
      return
    }

    appendLog("[gui] Stopping runner service for \(entry.slug)\n")
    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: "/bin/bash",
        arguments: ["-lc", "cd \(shellQuote(entry.runnerPath)) && ./svc.sh stop"],
        environment: environment
      )

      DispatchQueue.main.async {
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
          self.appendLog(result.output + "\n")
        }
        self.refreshLiveServices()
      }
    }
  }

  func startRunnerService(_ entry: RunnerServiceEntry) {
    runRunnerService(entry, command: "./svc.sh start", title: "Start runner", successMessage: "Runner service started.")
  }

  func stopAllActiveRunnerServices() {
    let activeRunners = runnerServices.filter(\.isRunning)
    guard !activeRunners.isEmpty else {
      appendLog("[gui] No running runner services were detected.\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Runner", title: "Stop all runners", target: "\(activeRunners.count) active", detail: "Stopping all active runner services…", initialState: .running)
    appendLog("[gui] Stopping all active runner services (\(activeRunners.count)).\n")

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      var logLines: [String] = []
      var failures: [String] = []

      for runner in activeRunners {
        let svcPath = (runner.runnerPath as NSString).appendingPathComponent("svc.sh")
        guard FileManager.default.isExecutableFile(atPath: svcPath) else {
          failures.append("\(runner.slug): missing svc.sh")
          continue
        }

        let result = Self.runCommand(
          executable: "/bin/bash",
          arguments: ["-lc", "cd \(shellQuote(runner.runnerPath)) && ./svc.sh stop"],
          environment: environment
        )
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          logLines.append("[\(runner.slug)]\n\(result.output)")
        }
        if result.status != 0 {
          failures.append(runner.slug)
        }
      }

      DispatchQueue.main.async {
        if !logLines.isEmpty {
          let output = logLines.joined(separator: "\n")
          self.appendLog(output + "\n")
          self.updateJob(id: jobID, appendLog: output)
        }
        if failures.isEmpty {
          self.finishJob(id: jobID, state: .succeeded, detail: "Stopped \(activeRunners.count) runner services.")
        } else {
          self.finishJob(id: jobID, state: .failed, detail: "Some runner services did not stop: \(failures.joined(separator: ", "))")
        }
        self.refreshLiveServices()
      }
    }
  }

  func startOnlyRunnerService(_ entry: RunnerServiceEntry) {
    let otherActiveRunners = runnerServices.filter { $0.id != entry.id && $0.isRunning }
    let environment = baseEnvironment()
    let jobID = createJob(kind: "Runner", title: "Start only runner", target: entry.slug, detail: "Stopping other runners, then starting selected runner…", initialState: .running)
    appendLog("[gui] Starting only \(entry.slug); stopping \(otherActiveRunners.count) other active runners first.\n")

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      var logLines: [String] = []
      var failures: [String] = []

      for runner in otherActiveRunners {
        let svcPath = (runner.runnerPath as NSString).appendingPathComponent("svc.sh")
        guard FileManager.default.isExecutableFile(atPath: svcPath) else {
          failures.append("\(runner.slug): missing svc.sh")
          continue
        }
        let result = Self.runCommand(
          executable: "/bin/bash",
          arguments: ["-lc", "cd \(shellQuote(runner.runnerPath)) && ./svc.sh stop"],
          environment: environment
        )
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          logLines.append("[stop \(runner.slug)]\n\(result.output)")
        }
        if result.status != 0 {
          failures.append("stop \(runner.slug)")
        }
      }

      let startPath = (entry.runnerPath as NSString).appendingPathComponent("svc.sh")
      if FileManager.default.isExecutableFile(atPath: startPath) {
        let result = Self.runCommand(
          executable: "/bin/bash",
          arguments: ["-lc", "cd \(shellQuote(entry.runnerPath)) && ./svc.sh start"],
          environment: environment
        )
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          logLines.append("[start \(entry.slug)]\n\(result.output)")
        }
        if result.status != 0 {
          failures.append("start \(entry.slug)")
        }
      } else {
        failures.append("\(entry.slug): missing svc.sh")
      }

      DispatchQueue.main.async {
        if !logLines.isEmpty {
          let output = logLines.joined(separator: "\n")
          self.appendLog(output + "\n")
          self.updateJob(id: jobID, appendLog: output)
        }
        if failures.isEmpty {
          self.finishJob(id: jobID, state: .succeeded, detail: "Only \(entry.slug) should be running.")
        } else {
          self.finishJob(id: jobID, state: .failed, detail: "Runner selection had failures: \(failures.joined(separator: ", "))")
        }
        self.refreshLiveServices()
      }
    }
  }

  func restartRunnerService(_ entry: RunnerServiceEntry) {
    runRunnerService(entry, command: "./svc.sh stop || true; ./svc.sh start", title: "Restart runner", successMessage: "Runner service restarted.")
  }

  func verifyRunnerService(_ entry: RunnerServiceEntry) {
    runRunnerService(entry, command: "./svc.sh status", title: "Verify runner", successMessage: "Runner service status loaded.")
  }

  private func runRunnerService(_ entry: RunnerServiceEntry, command: String, title: String, successMessage: String) {
    let svcPath = (entry.runnerPath as NSString).appendingPathComponent("svc.sh")
    guard FileManager.default.isExecutableFile(atPath: svcPath) else {
      appendLog("[gui] Runner service script was not found for \(entry.slug)\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Runner", title: title, target: entry.slug, detail: "\(title)…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: "/bin/bash",
        arguments: ["-lc", "cd \(shellQuote(entry.runnerPath)) && \(command)"],
        environment: environment
      )

      DispatchQueue.main.async {
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          self.appendLog(result.output + "\n")
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(title) failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
        self.refreshLiveServices()
      }
    }
  }

  func openDevcontainerConfig(for project: LocalProjectEntry) {
    let roots = [project.runtimePath, project.codePath].compactMap { $0 }
    for root in roots {
      let configPath = (root as NSString).appendingPathComponent(".devcontainer/devcontainer.json")
      if FileManager.default.fileExists(atPath: configPath) {
        openProjectPaths(codePath: configPath, runtimePath: nil, fallbackPath: configPath, preferRuntime: false, label: project.slug)
        return
      }
    }
    appendLog("[gui] No devcontainer config was found for \(project.slug)\n")
  }

  func buildDevcontainer(for project: LocalProjectEntry) {
    runDevcontainerCommand(for: project, title: "Build devcontainer", arguments: ["build", "--workspace-folder"])
  }

  func upDevcontainer(for project: LocalProjectEntry) {
    runDevcontainerCommand(for: project, title: "Start devcontainer", arguments: ["up", "--workspace-folder", "--skip-post-create"])
  }

  func rebuildDevcontainer(for project: LocalProjectEntry) {
    runDevcontainerCommand(for: project, title: "Rebuild devcontainer", arguments: ["up", "--workspace-folder", "--remove-existing-container", "--skip-post-create"])
  }

  private func runDevcontainerCommand(for project: LocalProjectEntry, title: String, arguments: [String]) {
    guard let workspacePath = project.runtimePath ?? project.codePath else {
      appendLog("[gui] No local workspace was found for \(project.slug)\n")
      return
    }
    guard let devcontainerPath = executablePath(named: "devcontainer") else {
      appendLog("[gui] Devcontainer CLI was not found.\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Devcontainer", title: title, target: project.slug, detail: "\(title)…", initialState: .running)
    let fullArguments = arguments + [workspacePath]

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: devcontainerPath, arguments: fullArguments, environment: environment)
      DispatchQueue.main.async {
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          self.appendLog(result.output + "\n")
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: "\(title) finished.")
          self.refreshLiveServices()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(title) failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func refreshAuthStatus() {
    guard let ghPath else {
      isAuthenticated = false
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first. The GUI and CLI both depend on gh."
      refreshStartupReadiness()
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedHost.isEmpty else {
      isAuthenticated = false
      statusKind = .warning
      statusTitle = "GitHub Host Required"
      statusDetail = "Enter a GitHub host, then refresh login status."
      refreshStartupReadiness()
      return
    }

    statusKind = .running
    statusTitle = "Checking Login Status"
    statusDetail = "Validating GitHub CLI authentication for \(selectedHost)."

    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["auth", "status", "--hostname", selectedHost],
        environment: environment
      )

      DispatchQueue.main.async {
        self.reloadAuthInventory()
        let cleaned = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedCleaned = redactSensitiveText(cleaned)
        let resolvedAccount = self.account.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.status == 0 {
          self.isAuthenticated = !resolvedAccount.isEmpty || self.selectedHostConfig?.activeUser != nil
          if self.repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.repoOwner = resolvedAccount.isEmpty ? (self.selectedHostConfig?.activeUser ?? "") : resolvedAccount
          }
          self.statusKind = .ready
          self.statusTitle = "GitHub Ready @ \(selectedHost)"
          self.statusDetail = "GitHub CLI has an active local session. CSA-iEM does not import, store, or log tokens, API keys, or account identity."
          self.githubAccountStatus = self.statusDetail
        } else {
          self.isAuthenticated = false
          self.clearRepoCatalog(resetOwner: false)
          self.statusKind = .warning
          self.statusTitle = "GitHub Login Required @ \(selectedHost)"
          self.statusDetail = sanitizedCleaned.isEmpty
            ? "Run gh auth login -h \(selectedHost) before cleanup."
            : sanitizedCleaned
          self.githubAccountStatus = self.statusDetail
          self.viewerOrganizations = []
        }
        self.refreshStartupReadiness()
      }
    }
  }

  func refreshStartupReadiness() {
    var checks = [StartupReadinessEntry]()
    let ghReady = ghPath != nil && isAuthenticated
    checks.append(StartupReadinessEntry(
      id: "github-cli",
      title: ghReady ? "GitHub CLI session ready" : (ghPath == nil ? "GitHub CLI is missing" : "GitHub CLI login is required"),
      detail: ghReady ? "An existing local GitHub CLI session is available for this launch. Identity and credentials stay outside CSA-iEM." : (ghPath == nil ? "Install GitHub CLI to connect repositories and Actions." : "Sign in through GitHub CLI when you choose to connect."),
      kind: ghReady ? .ready : .warning,
      canAutoFix: true
    ))

    let dockerReady = dockerPath != nil
    checks.append(StartupReadinessEntry(
      id: "docker",
      title: dockerReady ? "Docker CLI ready" : "Docker CLI is missing",
      detail: dockerReady ? "Local devcontainer checks are available." : "Install or start Docker Desktop to use devcontainer controls.",
      kind: dockerReady ? .ready : .warning,
      canAutoFix: true
    ))

    let devcontainerReady = executablePath(named: "devcontainer") != nil
    checks.append(StartupReadinessEntry(
      id: "devcontainer",
      title: devcontainerReady ? "Dev Containers CLI ready" : "Dev Containers CLI is missing",
      detail: devcontainerReady ? "Local devcontainer build and lifecycle controls are available." : "Install the Dev Containers CLI to build and manage local containers.",
      kind: devcontainerReady ? .ready : .warning,
      canAutoFix: true
    ))

    let codeReady = executablePath(named: "code") != nil || FileManager.default.fileExists(atPath: "/Applications/Visual Studio Code.app")
    checks.append(StartupReadinessEntry(
      id: "vscode",
      title: codeReady ? "Visual Studio Code ready" : "Visual Studio Code is optional",
      detail: codeReady ? "Projects can open in VS Code from the app and toolbar." : "Install Visual Studio Code to enable one-click project opening.",
      kind: codeReady ? .ready : .warning,
      canAutoFix: false
    ))

    startupReadiness = checks
    let unresolved = checks.filter { $0.kind != .ready }
    startupReadinessStatus = unresolved.isEmpty ? "Local setup is ready. GitHub identity and credentials remain managed by GitHub CLI." : "\(unresolved.count) setup item(s) need attention. You can auto-fix, review manual steps, or continue without changing anything."
  }

  func autoFixStartupReadiness() {
    if ghPath == nil {
      NSWorkspace.shared.open(URL(string: "https://cli.github.com")!)
    } else if !isAuthenticated {
      openGitHubLogin()
    }
    if dockerPath == nil {
      launchDetached(executable: "/usr/bin/open", arguments: ["-a", "Docker"])
    }
    if executablePath(named: "devcontainer") == nil {
      openTerminalCommand("npm install -g @devcontainers/cli")
    }
    refreshStartupReadiness()
  }

  func openGitHubLogin() {
    guard let ghPath else {
      appendLog("[gui] GitHub CLI was not found.\n")
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first, then try login again."
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let command = [
      "export PATH=\(shellQuote(defaultSearchPaths.joined(separator: ":")))",
      "\(shellQuote(ghPath)) auth login -h \(shellQuote(selectedHost.isEmpty ? "github.com" : selectedHost))",
      "EXIT_CODE=$?",
      "printf '\\n'",
      "if [ $EXIT_CODE -eq 0 ]; then echo 'GitHub login finished.'; else echo \"GitHub login exited with code $EXIT_CODE.\"; fi",
      "echo",
      "read -r -p 'Press Enter to close this window...' _"
    ].joined(separator: "; ")

    openTerminalCommand(command)
  }

  private func profileArguments() -> [String] {
    let profileName = selectedProfile == .public ? "default" : "custom"
    var args = ["--profile", profileName]
    if useCurrentRoot {
      args.append("--use-current-root")
    }
    return args
  }

  private func terminalCommandString(arguments: [String], exitLabel: String) -> String? {
    guard let cliPath else {
      appendLog("[gui] Bundled CLI was not found.\n")
      return nil
    }

    let commandParts = [shellQuote(cliPath)] + arguments.map(shellQuote)
    let autoConfirm = appSettings.autoConfirmTerminalGates ? "1" : "0"
    let cliCommand = commandParts.joined(separator: " ")
    var commands = [
      "export PATH=\(shellQuote(defaultSearchPaths.joined(separator: ":")))",
      "export CSA_IEM_AUTO_CONFIRM_TERMINAL_GATES=\(shellQuote(autoConfirm))",
      "export CSA_IEM_PAUSE_ON_SECURITY_GATE=1"
    ]
    if administratorTerminalMode {
      commands.append("echo 'CSA-iEM administrator mode: macOS will request authorization in this Terminal window.'")
      commands.append("if ! sudo -v; then echo 'Administrator authorization was cancelled or denied.'; read -r -p 'Press Enter to close this window...' _; exit 1; fi")
      commands.append("sudo -E \(cliCommand)")
    } else {
      commands.append(cliCommand)
    }
    commands.append(contentsOf: [
      "EXIT_CODE=$?",
      "printf '\\n'",
      "if [ $EXIT_CODE -eq 0 ]; then echo '\(exitLabel) finished.'; else echo \"\(exitLabel) exited with code $EXIT_CODE.\"; fi",
      "echo",
      "read -r -p 'Press Enter or y to close this window...' _"
    ])
    return commands.joined(separator: "; ")
  }

  func openCLIInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments(), exitLabel: appTitle) else {
      return
    }
    openTerminalCommand(command)
  }

  func openProjectBrowserInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse"], exitLabel: "Project Browser") else {
      return
    }
    openTerminalCommand(command)
  }

  func refreshOperatorState() {
    refreshLocalProjects()
    refreshLiveServices()
    loadStorageInsights()
    loadProjectSyncStatus()
    loadPortMonitor()
  }

  func openCostControlReviewInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse-cost-control"], exitLabel: "Cost-Control Review") else {
      return
    }
    openTerminalCommand(command)
  }

  func openInstalledDevcontainersInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse-devcontainers"], exitLabel: "Installed Devcontainers") else {
      return
    }
    openTerminalCommand(command)
  }

  func chooseCodexScanRoot() {
    let firstRoot = parsedCodexScanRoots().first ?? NSString(string: "~").expandingTildeInPath
    guard let selectedPath = chooseDirectory(startingAt: firstRoot) else { return }
    guard appendCodexScanRoot(selectedPath) else {
      codexPortalStatus = "The selected custom search folder is not readable. Choose a local or mounted folder that Finder can open."
      return
    }
    codexPortalStatus = "Added the selected folder as a custom project-search root. Only folders with project evidence will be offered as projects."
  }

  func addCodexScanRootDraft() {
    let rawPath = codexScanRootEntryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawPath.isEmpty else {
      codexPortalStatus = "Enter a custom folder path before adding it to the project search."
      return
    }
    guard appendCodexScanRoot(rawPath) else {
      codexPortalStatus = "The custom search folder is not readable. Check the path or choose a mounted folder that Finder can open."
      return
    }
    codexScanRootEntryDraft = ""
    codexPortalStatus = "Added the custom folder path. Scan Projects checks only folders with Git, manifests, or enough project context."
  }

  func receiveCodexScanRootDrop(_ providers: [NSItemProvider]) -> Bool {
    let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
    guard !fileProviders.isEmpty else {
      codexPortalStatus = "Drop one or more folders, not individual files, to add custom project-search roots."
      return false
    }

    for provider in fileProviders {
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
        let fileURL: URL?
        if let data = item as? Data {
          fileURL = URL(dataRepresentation: data, relativeTo: nil)
        } else if let url = item as? URL {
          fileURL = url
        } else if let url = item as? NSURL {
          fileURL = url as URL
        } else {
          fileURL = nil
        }
        guard let fileURL, fileURL.isFileURL else { return }
        DispatchQueue.main.async {
          guard let self else { return }
          if self.appendCodexScanRoot(fileURL.path) {
            self.codexPortalStatus = "Added dropped folder \(fileURL.lastPathComponent) as a custom project-search root. Only folders with project evidence will be offered as projects."
          } else {
            self.codexPortalStatus = "\(fileURL.lastPathComponent) is not a readable folder, so it was not added to the project search."
          }
        }
      }
    }
    return true
  }

  @discardableResult
  private func appendCodexScanRoot(_ rawPath: String) -> Bool {
    let path = normalizeWorkspacePath(rawPath)
    var isDirectory: ObjCBool = false
    guard !path.isEmpty,
          FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      return false
    }
    var roots = parsedCodexScanRoots()
    guard !roots.contains(path) else { return true }
    roots.append(path)
    codexScanRootsDraft = roots.joined(separator: "\n")
    persistCodexScanRoots()
    return true
  }

  func addCommonCodexScanRoots() {
    var roots = parsedCodexScanRoots()
    for root in Self.commonCodexProjectScanRoots(environment: baseEnvironment()) where !roots.contains(root) {
      roots.append(root)
    }
    codexScanRootsDraft = roots.joined(separator: "\n")
    persistCodexScanRoots()
    codexPortalStatus = "Added readable Documents, development, Codex worktree, and mounted-drive project folders. Scan Projects uses folder context even when Codex no longer has a linked project record."
  }

  func chooseCodexOutputRoot() {
    guard let selectedPath = chooseDirectory(startingAt: codexOutputRootDraft) else { return }
    codexOutputRootDraft = selectedPath
  }

  func chooseStage2SourceRoot() {
    guard let selectedPath = chooseDirectory(startingAt: stage2SourceRootDraft) else { return }
    stage2SourceRootDraft = selectedPath
    stage2Status = "Stage 2 source changed. Scan it before selecting projects."
  }

  func chooseStage2ManagedRoot() {
    guard let selectedPath = chooseDirectory(startingAt: stage2ManagedRootDraft) else { return }
    stage2ManagedRootDraft = selectedPath
    stage2Status = "Managed root changed. Run a new Stage 2 preflight before applying."
  }

  func revealStage2SourceRoot() {
    let path = normalizeWorkspacePath(stage2SourceRootDraft)
    guard FileManager.default.fileExists(atPath: path) else {
      stage2Status = "The Stage 1 source folder is not mounted or does not exist."
      return
    }
    launchDetached(executable: "/usr/bin/open", arguments: [path])
  }

  func revealStage2ManagedRoot() {
    let path = normalizeWorkspacePath(stage2ManagedRootDraft)
    guard FileManager.default.fileExists(atPath: path) else {
      stage2Status = "The managed root does not exist yet. Stage 2 preflight creates its report folders."
      return
    }
    launchDetached(executable: "/usr/bin/open", arguments: [path])
  }

  func scanStage2Projects() {
    let sourceRoot = normalizeWorkspacePath(stage2SourceRootDraft)
    guard FileManager.default.fileExists(atPath: sourceRoot) else {
      stage2Status = "The Stage 1 source folder is not mounted or does not exist: \(sourceRoot)"
      return
    }
    codexScanRootsDraft = sourceRoot
    persistCodexScanRoots()
    stage2Status = "Scanning the Stage 1 output folder. Temporary and transaction folders are excluded during Stage 2 planning."
    scanCodexProjects()
  }

  func openCodexProjectDevcontainer(_ project: CodexProjectEntry) {
    guard project.hasDevcontainer else {
      codexPortalStatus = "No .devcontainer/devcontainer.json was detected for \(project.name)."
      return
    }
    let command = [
      "cd \(shellQuote(project.path))",
      "if command -v devcontainer >/dev/null 2>&1; then devcontainer up --workspace-folder \(shellQuote(project.path)); else echo 'Dev Containers CLI is not installed.'; fi"
    ].joined(separator: "; ")
    openTerminalCommand(command)
  }

  func runCodexLocalDev(_ project: CodexProjectEntry) {
    guard !isRunningCodexLocalDev else {
      codexLocalDevStatus = "A local development session is already running. Stop it before starting another project."
      return
    }
    guard let profile = project.localDevProfile else {
      codexLocalDevStatus = "No supported local development script was detected in \(project.name)'s package.json."
      return
    }
    guard let npmPath = executablePath(named: "npm") else {
      codexLocalDevStatus = "npm was not found in the configured local tool paths. Install Node.js before starting local development."
      return
    }
    guard FileManager.default.fileExists(atPath: project.path) else {
      codexLocalDevStatus = "The project path is not mounted or no longer exists: \(project.path)"
      return
    }

    var environment = baseEnvironment()
    environment["BROWSER"] = "none"
    let process = Process()
    let pipe = Pipe()
    let jobID = createJob(
      kind: "Local Dev",
      title: profile.label,
      target: project.name,
      detail: "Starting \(profile.commandLabel)…",
      initialState: .running
    )
    process.executableURL = URL(fileURLWithPath: npmPath)
    process.arguments = ["run", profile.script]
    process.currentDirectoryURL = URL(fileURLWithPath: project.path, isDirectory: true)
    process.environment = environment
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = pipe
    process.standardError = pipe

    codexLocalDevProcess = process
    codexLocalDevJobID = jobID
    codexLocalDevProjectPath = project.path
    codexLocalDevCommand = profile.commandLabel
    isRunningCodexLocalDev = true
    codexLocalDevStatus = "Starting \(profile.label.lowercased()) in \(project.path)."
    appendLog("[local-dev] Starting \(profile.commandLabel) in \(project.path)\n")

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
      DispatchQueue.main.async {
        self?.appendLog(chunk)
        self?.updateJob(id: jobID, appendLog: chunk)
      }
    }

    process.terminationHandler = { [weak self] terminated in
      let tail = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.readabilityHandler = nil
      let tailText = String(data: tail, encoding: .utf8) ?? ""
      DispatchQueue.main.async {
        guard let self else { return }
        if !tailText.isEmpty {
          self.appendLog(tailText)
          self.updateJob(id: jobID, appendLog: tailText)
        }

        let stopping = self.codexLocalDevStatus.hasPrefix("Stopping")
        self.codexLocalDevProcess = nil
        self.codexLocalDevJobID = nil
        self.isRunningCodexLocalDev = false

        if stopping {
          self.codexLocalDevStatus = "Local development session stopped."
          self.finishJob(id: jobID, state: .succeeded, detail: self.codexLocalDevStatus)
        } else if terminated.terminationStatus == 0 {
          self.codexLocalDevStatus = "Local development session exited successfully."
          self.finishJob(id: jobID, state: .succeeded, detail: self.codexLocalDevStatus)
        } else {
          self.codexLocalDevStatus = "Local development session stopped with exit code \(terminated.terminationStatus). See Jobs for output."
          self.finishJob(id: jobID, state: .failed, detail: self.codexLocalDevStatus)
        }
        self.loadPortMonitor()
      }
    }

    do {
      try process.run()
      for delay in [2.0, 8.0] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
          guard let self, self.isRunningCodexLocalDev else { return }
          self.loadPortMonitor()
        }
      }
    } catch {
      codexLocalDevProcess = nil
      codexLocalDevJobID = nil
      isRunningCodexLocalDev = false
      codexLocalDevStatus = "Could not start \(profile.commandLabel): \(error.localizedDescription)"
      finishJob(id: jobID, state: .failed, detail: codexLocalDevStatus)
    }
  }

  func stopCodexLocalDev() {
    guard let process = codexLocalDevProcess else {
      codexLocalDevStatus = "No local development session is running."
      isRunningCodexLocalDev = false
      return
    }
    codexLocalDevStatus = "Stopping local development session…"
    process.terminate()
  }

  func runStage2PreflightSelected() {
    runStage2InTerminal(action: "preflight", fullAuto: false)
  }

  func runStage2ApplySelected() {
    runStage2InTerminal(action: "apply", fullAuto: false)
  }

  func runStage2PreflightAll() {
    runStage2InTerminal(action: "preflight", fullAuto: true)
  }

  func runStage2FullAuto() {
    runStage2InTerminal(action: "apply", fullAuto: true)
  }

  func runStage3Preflight() {
    runStage3InTerminal(action: "preflight")
  }

  func runStage3Cleanup() {
    runStage3InTerminal(action: "apply")
  }

  private nonisolated static func isSafeGitHubPrincipal(_ value: String) -> Bool {
    guard !value.isEmpty,
          value.count <= 39,
          value.first != "-",
          value.last != "-" else {
      return false
    }
    return value.unicodeScalars.allSatisfy { scalar in
      switch scalar.value {
      case 45, 48...57, 65...90, 97...122:
        return true
      default:
        return false
      }
    }
  }

  private func parsedStage2GitHubOwnerAccounts() throws -> [String] {
    let trimmedDraft = stage2GitHubOwnerAccountsDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDraft.isEmpty else { return [] }

    let normalizedDraft = stage2GitHubOwnerAccountsDraft
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let rawEntries = normalizedDraft.components(separatedBy: CharacterSet(charactersIn: "\n;"))
    var ownerLogins: [String: String] = [:]
    var bindings: [String] = []

    for (offset, rawEntry) in rawEntries.enumerated() {
      let entryNumber = offset + 1
      let entry = rawEntry.trimmingCharacters(in: .whitespaces)
      guard !entry.isEmpty else {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "GitHub owner-account entry \(entryNumber) is empty. Remove blank rows and repeated or trailing separators, or clear the field to use the selected single account."]
        )
      }

      let components = entry.components(separatedBy: "=")
      guard components.count == 2 else {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "GitHub owner-account entry \(entryNumber) must be OWNER=LOGIN with exactly one equals sign."]
        )
      }

      let owner = components[0].trimmingCharacters(in: .whitespaces)
      let login = components[1].trimmingCharacters(in: .whitespaces)
      guard Self.isSafeGitHubPrincipal(owner), Self.isSafeGitHubPrincipal(login) else {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "GitHub owner-account entry \(entryNumber) must use 1–39 ASCII letters, numbers, or hyphens for both OWNER and LOGIN; neither value may begin or end with a hyphen."]
        )
      }

      let ownerKey = owner.lowercased()
      if let existingLogin = ownerLogins[ownerKey] {
        let detail = existingLogin.caseInsensitiveCompare(login) == .orderedSame
          ? "duplicates an earlier binding"
          : "conflicts with the earlier login \(existingLogin)"
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "GitHub owner-account entry \(entryNumber) \(detail) for owner \(owner). Keep exactly one binding per owner."]
        )
      }

      ownerLogins[ownerKey] = login
      bindings.append("\(owner)=\(login)")
    }

    return bindings
  }

  private func runStage3InTerminal(action: String) {
    guard !isCodexPortalBusy else {
      codexLifecycleStatus = "Wait for the active project scan, preflight, or lifecycle run to finish before starting Stage 3."
      return
    }
    let sourceRoot = normalizeWorkspacePath(stage2SourceRootDraft)
    let managedRoot = normalizeWorkspacePath(stage2ManagedRootDraft)
    let githubOwnerAccounts: [String]
    do {
      githubOwnerAccounts = try parsedStage2GitHubOwnerAccounts()
    } catch {
      codexLifecycleStatus = "Stage 3 configuration error: \(error.localizedDescription)"
      return
    }
    guard FileManager.default.fileExists(atPath: sourceRoot), FileManager.default.fileExists(atPath: managedRoot) else {
      codexLifecycleStatus = "Stage 3 needs mounted Stage 1 and managed roots before it can read receipts."
      return
    }
    if action == "apply" && !codexLifecycleSafetyArmed {
      codexLifecycleStatus = "Arm Full Auto before applying permanent Stage 3 cleanup."
      return
    }
    var arguments = ["stage3", "--source", sourceRoot, "--managed-root", managedRoot, "--all"]
    for binding in githubOwnerAccounts {
      arguments.append(contentsOf: ["--github-account", binding])
    }
    if codexLifecycleScope == .selected {
      guard !selectedCodexProjects.isEmpty else {
        codexLifecycleStatus = "Select one or more projects, or switch lifecycle scope to All Eligible Projects."
        return
      }
      for project in selectedCodexProjects {
        arguments.append(contentsOf: ["--project", project.name])
      }
    }
    if codexLifecycleDeleteStage1Originals { arguments.append("--delete-stage1-originals") }
    if stage2SourceRetention == .delete { arguments.append("--delete-stage2-inputs") }
    switch codexLifecycleCleanupScope {
    case .none:
      break
    case .currentTransaction:
      arguments.append("--cleanup-transaction-temp")
    case .allVerifiedTemp:
      arguments.append("--cleanup-all-verified-temp")
    }
    guard arguments.contains(where: {
      $0 == "--delete-stage1-originals" || $0 == "--delete-stage2-inputs" || $0.hasPrefix("--cleanup-")
    }) else {
      codexLifecycleStatus = "Choose at least one source or temporary-data cleanup policy before Stage 3."
      return
    }
    if action == "apply" {
      arguments.append(contentsOf: ["--apply", "--yes", "--confirm-delete", "VERIFIED-STAGE3"])
    } else {
      arguments.append("--preflight")
    }
    guard let command = terminalCommandString(
      arguments: arguments,
      exitLabel: action == "apply" ? "Stage 3 Cleanup" : "Stage 3 Preflight"
    ) else {
      codexLifecycleStatus = "The bundled Stage 3 CLI was not found."
      return
    }
    codexLifecycleStatus = action == "apply"
      ? "Stage 3 is running in Terminal. Only receipt-linked rows that pass live verification can be deleted."
      : "Stage 3 preflight is building a receipt-linked cleanup plan without changing files."
    openTerminalCommand(command)
    if action == "apply" { codexLifecycleSafetyArmed = false }
  }

  private func runStage2InTerminal(action: String, fullAuto: Bool) {
    guard !isCodexPortalBusy else {
      stage2Status = "Wait for the active project scan, preflight, or lifecycle run to finish before starting Stage 2."
      return
    }
    let sourceRoot = normalizeWorkspacePath(stage2SourceRootDraft)
    let managedRoot = normalizeWorkspacePath(stage2ManagedRootDraft)
    let githubOwnerAccounts: [String]
    do {
      githubOwnerAccounts = try parsedStage2GitHubOwnerAccounts()
    } catch {
      stage2Status = "Stage 2 configuration error: \(error.localizedDescription)"
      return
    }
    guard FileManager.default.fileExists(atPath: sourceRoot) else {
      stage2Status = "Stage 2 cannot start because the Stage 1 source is unavailable: \(sourceRoot)"
      return
    }
    guard sourceRoot != managedRoot,
          !sourceRoot.hasPrefix(managedRoot + "/"),
          !managedRoot.hasPrefix(sourceRoot + "/") else {
      stage2Status = "Stage 1 source and the managed CSA-iEM root must be separate folders."
      return
    }
    if action == "apply" && codexStage2ApplyBlocked {
      stage2SafetyArmed = false
      stage2Status = "Stage 2 apply is blocked by unresolved Smart Logic identity-group review. Run preflight, resolve or explicitly exclude the named sources, then rescan before arming workspace writes."
      return
    }
    if action == "apply" && !stage2SafetyArmed {
      stage2Status = "Arm Stage 2 writes after reviewing the source, managed root, GitHub account, and options."
      return
    }
    if action == "apply" && codexMissingCanonicalGroupCount > 0 {
      stage2Status = "Choose one canonical source for each verified identity group before applying Stage 2. Missing (codexMissingCanonicalGroupCount) canonical choice(s)."
      return
    }

    var arguments = ["stage2", "--source", sourceRoot, "--managed-root", managedRoot]
    if !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      arguments.append(contentsOf: ["--host", host])
    }
    if !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      arguments.append(contentsOf: ["--account", account])
    }
    for binding in githubOwnerAccounts {
      arguments.append(contentsOf: ["--github-account", binding])
    }
    for activeProject in codexProjects.filter({ $0.ideState == .active }) {
      arguments.append(contentsOf: ["--exclude-path", activeProject.path])
    }

    if fullAuto {
      arguments.append(action == "apply" ? "--full-auto" : "--all")
      if action == "preflight" { arguments.append("--preflight") }
    } else {
      guard !stage2SelectedProjects.isEmpty else {
        stage2Status = "Select one or more projects found inside the Stage 1 source folder."
        return
      }
      arguments.append(action == "apply" ? "--apply" : "--preflight")
      for project in stage2SelectedProjects {
        arguments.append(contentsOf: ["--project", project.path])
      }
    }

    if stage2CreateMissingRepos { arguments.append("--create-missing-repos") }
    if stage2ArchiveSources { arguments.append("--archive-sources") }
    switch stage2SourceRetention {
    case .keep:
      break
    case .retire:
      arguments.append("--retire-sources")
    case .delete:
      // Stage 2 may only move verified inputs into managed _temp. Permanent
      // receipt-linked deletion is owned by Stage 3.
      arguments.append("--retire-sources")
    }
    if stage2PrepareRuntime { arguments.append("--prepare-runtime") }
    if action == "apply" {
      arguments.append("--yes")
      if stage2CleanupTransactionTemp { arguments.append("--cleanup-transaction-temp") }
      if stage2OpenAfterApply != .none {
        arguments.append(contentsOf: ["--open", stage2OpenAfterApply.rawValue])
      }
    }

    guard let command = terminalCommandString(
      arguments: arguments,
      exitLabel: action == "apply" ? "Stage 2 Reconciliation" : "Stage 2 Preflight"
    ) else {
      stage2Status = "The bundled Stage 2 CLI was not found."
      return
    }
    stage2Status = action == "apply"
      ? "Stage 2 is running in Terminal with live PLAN and PROGRESS rows. Safety-blocked projects will be skipped and reported."
      : "Stage 2 preflight is running in Terminal. No canonical project files will be changed."
    openTerminalCommand(command)
    if action == "apply" { stage2SafetyArmed = false }
  }

  func toggleCodexProject(_ project: CodexProjectEntry) {
    if selectedCodexProjectPaths.contains(project.path) {
      selectedCodexProjectPaths.remove(project.path)
    } else {
      selectedCodexProjectPaths.insert(project.path)
    }
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
  }

  func setVisibleCodexProjectsSelected(_ enabled: Bool) {
    for project in filteredCodexProjects {
      if enabled {
        selectedCodexProjectPaths.insert(project.path)
      } else {
        selectedCodexProjectPaths.remove(project.path)
      }
    }
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
  }

  func selectAllCodexProjects() {
    selectedCodexProjectPaths = Set(codexProjects.map(\.path))
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
  }

  func armCodexAutoAll() {
    guard !codexProjects.isEmpty else {
      codexPortalStatus = "Scan for Codex projects before arming Auto All."
      return
    }
    let eligibleProjects = codexProjects.filter { Self.codexAutoAllSkipReason(for: $0) == nil }
    let skippedCount = codexProjects.count - eligibleProjects.count
    selectedCodexProjectPaths = Set(eligibleProjects.map(\.path))
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
    codexAutoResumeExisting = true
    codexPortalProgressText = "Auto All armed for \(eligibleProjects.count) active project(s)."
    let skippedSummary = skippedCount > 0
      ? " \(skippedCount) folder(s) marked bad, moved-backup, or temporary work data remain available for manual selection."
      : ""
    codexPortalStatus = "Auto All will verify saved zero-delta indexes first, reuse uniquely matched Git destinations, and rebuild a complete index only for projects that changed. Planned iCloud files download before targeted transfer. Your saved ZIP policy remains unchanged.\(skippedSummary)"
  }

  func clearCodexProjectSelection() {
    selectedCodexProjectPaths.removeAll()
    codexTransferPlans.removeAll()
    stage2SafetyArmed = false
  }

  func openCodexProject(_ project: CodexProjectEntry, inApplication appName: String) {
    openPathInApplication(project.path, appName: appName, label: project.name)
  }

  func revealCodexProject(_ project: CodexProjectEntry) {
    launchDetached(executable: "/usr/bin/open", arguments: ["-R", project.path])
  }

  func openCodexOutputRoot() {
    let path = normalizeWorkspacePath(codexOutputRootDraft)
    guard FileManager.default.fileExists(atPath: path) else {
      codexPortalStatus = "The output folder does not exist yet. Run Preflight or choose an existing folder."
      return
    }
    launchDetached(executable: "/usr/bin/open", arguments: [path])
  }

  func revealCodexTransferIndexes() {
    let outputRoot = normalizeWorkspacePath(codexOutputRootDraft)
    let indexDirectory = ((outputRoot as NSString).appendingPathComponent("_temp") as NSString)
      .appendingPathComponent("Transfer-Indexes")
    guard FileManager.default.fileExists(atPath: indexDirectory) else {
      codexPortalStatus = "No transfer index has been saved yet. Run Preflight first."
      return
    }
    launchDetached(executable: "/usr/bin/open", arguments: [indexDirectory])
  }

  func openAdministratorTerminalCheck() {
    let command = [
      "echo 'CSA-iEM administrator Terminal check'",
      "if sudo -v; then echo 'Administrator authorization is ready. CSA-iEM did not store the password.'; else echo 'Authorization cancelled or denied.'; fi",
      "read -r -p 'Press Enter to close this window...' _"
    ].joined(separator: "; ")
    openTerminalCommand(command)
  }

  func scanCodexProjects() {
    guard !isScanningCodexProjects, !isBuildingCodexTransferPlan, !isRunningCodexTransfer else { return }
    let roots = parsedCodexScanRoots()
    persistCodexScanRoots()
    let commonRoots = Self.commonCodexProjectScanRoots(environment: baseEnvironment())
    isScanningCodexProjects = true
    codexPortalProgress = 0
    codexPortalProgressText = roots.isEmpty
      ? "Reading local Codex history because no source folder was selected..."
      : "Scanning \(roots.count) selected source root(s) from on-disk project context..."
    codexPortalStatus = "Project discovery is running. Selected folders are scanned first and do not depend on a linked Codex project record."
    let environment = baseEnvironment()
    let smartProfile = codexSmartScanMode
    let scanStartedAt = Date()

    processQueue.async { [weak self] in
      var projects = Self.discoverCodexProjects(scanRoots: roots, environment: environment)
      var usedCommonFolders = false
      if projects.isEmpty {
        let fallbackRoots = commonRoots.filter { !roots.contains($0) }
        if !fallbackRoots.isEmpty {
          usedCommonFolders = true
          projects = Self.discoverCodexProjects(scanRoots: fallbackRoots, environment: environment)
        }
      }
      let discoveryMilliseconds = max(0, Int(Date().timeIntervalSince(scanStartedAt) * 1_000))
      DispatchQueue.main.async {
        guard let self else { return }
        self.codexProjects = projects
        self.recordCodexSmartDecisions(
          projects,
          sourceRoots: roots,
          profile: smartProfile,
          discoveryMilliseconds: discoveryMilliseconds
        )
        self.selectedCodexProjectPaths = self.selectedCodexProjectPaths.intersection(Set(projects.map(\.path)))
        self.codexTransferPlans.removeAll()
        self.isScanningCodexProjects = false
        self.codexPortalProgress = projects.isEmpty ? 0 : 1
        self.codexPortalProgressText = projects.isEmpty ? "Scan finished with no project matches." : "Scan complete: \(projects.count) projects found."
        self.codexPortalStatus = projects.isEmpty
          ? "No project folders were recognized. Add a parent folder or use Scan Common Folders; the scanner recognizes Git, manifests, source folders, editor settings, Docker/config files, and existing transfer notes."
          : usedCommonFolders
            ? "No selected-root match was found, so discovery scanned common local and mounted-drive folders using on-disk project context. Choose one, many, visible, or all projects."
            : "Discovery used the selected folders' on-disk project context. Choose one, many, visible, or all projects."
      }
    }
  }

  func preflightCodexTransfer() {
    guard !isBuildingCodexTransferPlan, !isRunningCodexTransfer, !isScanningCodexProjects else { return }
    let projects = selectedCodexProjects
    guard !projects.isEmpty else {
      codexPortalStatus = "Select at least one discovered project before preflight."
      return
    }

    let outputRoot = normalizeWorkspacePath(codexOutputRootDraft)
    let resolvedDestinations: [String: String]
    do {
      resolvedDestinations = try Self.preflightCodexTransfer(
        projects: projects,
        outputRoot: outputRoot,
        mode: codexTransferMode,
        resumeExisting: codexTransferMode.writesDestination && (codexAutoResumeExisting || codexTransferMode.requiresExistingDestinationMerge)
      )
      if codexRearmGitMain && !codexIncludeGitMetadata && codexTransferMode.writesDestination,
         projects.contains(where: { ($0.remoteURL ?? "").isEmpty }) {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Git main re-arm needs a detected remote for every selected project."])
      }
    } catch {
      codexPortalStatus = "Preflight failed: \(error.localizedDescription)"
      codexPortalProgressText = "Resolve the preflight issue before running."
      return
    }

    let mode = codexTransferMode
    let includeGit = codexIncludeGitMetadata
    let includeFinderMetadata = codexIncludeFinderMetadata
    let includeDependencies = codexIncludeDependencies
    let fullChecksumAudit = codexFullChecksumAudit
    let environment = baseEnvironment()
    isBuildingCodexTransferPlan = true
    codexTransferPlans.removeAll()
    codexPortalProgress = 0
    codexPortalProgressText = "Building source and destination file indexes..."
    codexPortalStatus = "Preflight passed. CSA-iEM is creating a virtual file table before it transfers anything."

    processQueue.async { [weak self] in
      var plans: [CodexTransferPlan] = []
      var failure: Error?

      for (index, project) in projects.enumerated() {
        let progressHandler: (String, Int, Int64) -> Void = { phase, fileCount, byteCount in
          Task { @MainActor [weak self] in
            guard let self, self.isBuildingCodexTransferPlan else { return }
            self.codexPortalProgress = (Double(index) + 0.5) / Double(max(projects.count, 1))
            self.codexPortalProgressText = "Preflight \(index + 1) of \(projects.count): \(phase) \(fileCount) entries (\(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)))."
          }
        }
        do {
          let plan = try Self.buildCodexTransferPlan(
            project: project,
            outputRoot: outputRoot,
            mode: mode,
            destinationPath: resolvedDestinations[project.path],
            includeGit: includeGit,
            includeFinderMetadata: includeFinderMetadata,
            includeDependencies: includeDependencies,
            fullChecksumAudit: fullChecksumAudit,
            environment: environment,
            progress: progressHandler
          )
          plans.append(plan)
        } catch {
          failure = error
          break
        }
      }

      DispatchQueue.main.async {
        guard let self else { return }
        self.isBuildingCodexTransferPlan = false
        if let failure {
          self.codexPortalProgress = 0
          self.codexPortalProgressText = "Resolve the preflight issue before running."
          self.codexPortalStatus = "Preflight index failed: \(failure.localizedDescription)"
          return
        }
        self.codexTransferPlans = plans
        self.recordCodexTransferCheckpoints(plans)
        self.codexPortalProgress = 1
        self.codexPortalProgressText = "Preflight complete: \(plans.count) project index table(s) saved under the output _temp folder."
        self.codexPortalStatus = "Preflight passed for \(projects.count) project(s). \(self.codexTransferPlanSummary)"
      }
    }
  }

  func preflightCodexLifecycle() {
    guard prepareCodexLifecycleSelection() else { return }
    guard validateCodexLifecycleConfiguration() else { return }
    codexLifecycleStatus = "Lifecycle options passed. Building the Stage 1 virtual file table; Stage 2 and Stage 3 will remain read-only until Full Auto is armed and started."
    preflightCodexTransfer()
  }

  func runCodexLifecycle() {
    guard prepareCodexLifecycleSelection() else { return }
    guard validateCodexLifecycleConfiguration() else { return }
    guard codexLifecycleSafetyArmed else {
      codexLifecycleStatus = "Arm Full Auto after reviewing scope, selected projects, ZIP, source-retention, Stage 2, and Stage 3 cleanup options."
      return
    }
    codexLifecycleSafetyArmed = false
    runCodexTransfer(runLifecycle: true)
  }

  func runCodexTransfer() {
    runCodexTransfer(runLifecycle: false)
  }

  func resumeCodexPendingRoutes() {
    guard !isCodexPortalBusy else {
      codexPortalStatus = "Wait for the current Codex operation to finish before resuming pending routes."
      return
    }
    let availablePaths = Set(codexProjects.map(\.path))
    let pendingPaths = codexPendingRoutePaths.intersection(availablePaths)
    guard !pendingPaths.isEmpty else {
      codexPortalStatus = "No pending route receipts match the currently indexed projects. Run Scan Sources to refresh the local index."
      return
    }
    codexResumeOriginalSelection = selectedCodexProjectPaths
    selectedCodexProjectPaths = pendingPaths
    codexPortalStatus = "Resuming (pendingPaths.count) pending route(s) from the persisted receipt set. Completed and skipped routes remain untouched."
    runCodexTransfer(runLifecycle: false)
  }

  private func restoreCodexResumeSelection() {
    guard let original = codexResumeOriginalSelection else { return }
    selectedCodexProjectPaths = original.intersection(Set(codexProjects.map(\.path)))
    codexResumeOriginalSelection = nil
  }

  private func prepareCodexLifecycleSelection() -> Bool {
    if codexLifecycleScope == .all {
      guard !codexProjects.isEmpty else {
        codexLifecycleStatus = "Scan for projects before running All Eligible Projects."
        return false
      }
      let eligible = codexProjects.filter { Self.codexAutoAllSkipReason(for: $0) == nil }
      selectedCodexProjectPaths = Set(eligible.map(\.path))
      codexTransferPlans.removeAll()
    }
    guard !selectedCodexProjects.isEmpty else {
      codexLifecycleStatus = "Select at least one project for the lifecycle."
      return false
    }
    if let protected = selectedCodexProjects.first(where: { Self.codexAutoAllSkipReason(for: $0) == "active CSA-iEM workspace" }) {
      codexLifecycleStatus = "The active CSA-iEM workspace is protected from Full Auto: \(protected.path)"
      return false
    }
    return true
  }

  private func validateCodexLifecycleConfiguration() -> Bool {
    if codexSmartScanMode == .yolo {
      codexLifecycleStatus = "YOLO mode is limited to a non-destructive Stage 1 Backup or Copy. Use Fast Index or Full Verification before Stage 2, Stage 3, source retirement, or Full Auto."
      return false
    }
    let outputRoot = normalizeWorkspacePath(codexOutputRootDraft)
    let managedRoot = normalizeWorkspacePath(stage2ManagedRootDraft)
    do {
      _ = try parsedStage2GitHubOwnerAccounts()
    } catch {
      codexLifecycleStatus = "Lifecycle configuration error: \(error.localizedDescription)"
      return false
    }
    if codexLifecycleRunStage2 && !codexTransferMode.writesDestination {
      codexLifecycleStatus = "Stage 2 requires a Stage 1 mode that creates or reconciles an output project."
      return false
    }
    if codexLifecycleDeleteStage1Originals && !codexTransferMode.writesDestination {
      codexLifecycleStatus = "Deleting Stage 1 originals requires a verified output destination; Backup Only always keeps the source."
      return false
    }
    if codexLifecycleDeleteStage1Originals,
       selectedCodexProjects.contains(where: \.hasGit),
       !codexIncludeGitMetadata {
      codexLifecycleStatus = "Deleting a Git source requires Preserve .git metadata so repository-local state can be verified before cleanup."
      return false
    }
    if codexLifecycleDeleteStage1Originals,
       selectedCodexProjects.contains(where: \.hasGit),
       !codexLifecycleRunStage2 {
      codexLifecycleStatus = "Deleting a Git source requires Stage 2 so a full verified Git-state snapshot reaches the canonical workspace before Stage 3."
      return false
    }
    if codexLifecycleRunStage2 && (
      outputRoot == managedRoot ||
      outputRoot.hasPrefix(managedRoot + "/") ||
      managedRoot.hasPrefix(outputRoot + "/")
    ) {
      codexLifecycleStatus = "The Stage 1 output and managed CSA-iEM root must be separate folders."
      return false
    }
    return true
  }

  private func runCodexTransfer(runLifecycle: Bool) {
    guard !isRunningCodexTransfer, !isScanningCodexProjects, !isBuildingCodexTransferPlan else { return }
    if codexSmartScanMode == .yolo && (runLifecycle || codexTransferMode.removesSource || codexTransferMode.performsBidirectionalSync || codexTransferMode.performsScanAndBackup) {
      codexPortalStatus = "YOLO mode is limited to a non-destructive Backup or Copy. It cannot run Sync and Move, bidirectional sync, Scan & Backup, Stage 2, or Stage 3."
      return
    }
    let projects = selectedCodexProjects
    guard !projects.isEmpty else {
      codexPortalStatus = "Select at least one discovered project before running."
      return
    }

    let outputRoot = normalizeWorkspacePath(codexOutputRootDraft)
    let resolvedDestinations: [String: String]
    do {
      resolvedDestinations = try Self.preflightCodexTransfer(
        projects: projects,
        outputRoot: outputRoot,
        mode: codexTransferMode,
        resumeExisting: codexTransferMode.writesDestination && (codexAutoResumeExisting || codexTransferMode.requiresExistingDestinationMerge)
      )
    } catch {
      codexPortalStatus = "Preflight failed: \(error.localizedDescription)"
      restoreCodexResumeSelection()
      return
    }

    let mode = codexTransferMode
    let backupMedium = codexBackupMedium
    let createBackup = codexCreateBackup || codexBackupMedium == .verifiedZip || mode == .backupOnly || mode.performsScanAndBackup
    let includeGit = codexIncludeGitMetadata
    let includeFinderMetadata = codexIncludeFinderMetadata
    let includeDependencies = codexIncludeDependencies
    let fullChecksumAudit = codexFullChecksumAudit
    let compatibilityLink = codexCreateCompatibilityLink
    let rearmGitMain = codexRearmGitMain && !includeGit && mode.writesDestination
    let autoResumeExisting = mode.writesDestination && (codexAutoResumeExisting || mode.requiresExistingDestinationMerge)
    let destinationUseCounts = resolvedDestinations.values.reduce(into: [String: Int]()) { counts, destination in
      counts[Self.codexDestinationComparisonKey(destination), default: 0] += 1
    }
    if rearmGitMain, projects.contains(where: { ($0.remoteURL ?? "").isEmpty }) {
      codexPortalStatus = "Preflight failed: Git main re-arm needs a detected remote for every selected project."
      return
    }
    let lifecycleRunStage2 = runLifecycle && codexLifecycleRunStage2
    let lifecycleDeleteStage1 = runLifecycle && codexLifecycleDeleteStage1Originals
    let lifecycleCleanupScope = codexLifecycleCleanupScope
    let lifecycleManagedRoot = normalizeWorkspacePath(stage2ManagedRootDraft)
    let lifecycleRetention = stage2SourceRetention
    let lifecycleArchiveStage2 = stage2ArchiveSources
    let lifecycleCreateMissingRepos = stage2CreateMissingRepos
    let lifecyclePrepareRuntime = stage2PrepareRuntime
    let lifecycleOpenAfterApply = stage2OpenAfterApply.rawValue
    let lifecycleHost = host
    let lifecycleAccount = account
    let lifecycleGitHubOwnerAccounts: [String]
    do {
      lifecycleGitHubOwnerAccounts = runLifecycle ? try parsedStage2GitHubOwnerAccounts() : []
    } catch {
      codexLifecycleStatus = "Lifecycle configuration error: \(error.localizedDescription)"
      codexPortalStatus = codexLifecycleStatus
      return
    }
    let lifecycleActiveProjectPaths = codexProjects.filter { $0.ideState == .active }.map(\.path)
    let lifecycleCLIPath = cliPath
    let environment = baseEnvironment()
    let jobID = createJob(
      kind: "Codex",
      title: runLifecycle ? "Full Auto CODEX lifecycle" : "\(mode.label) Codex projects",
      target: "\(projects.count) project(s)",
      detail: "Preflight passed. Building current file indexes before targeted transfer.",
      initialState: .running
    )
    isRunningCodexTransfer = true
    codexPortalProgress = 0
    codexPortalProgressText = "Building the current index for the first project..."
    codexPortalStatus = "CSA-iEM will refresh each selected file table immediately before execution, then transfer only planned paths. Sources are never removed before final verification succeeds."

    processQueue.async { [weak self] in
      var outcomes: [CodexProjectTransferOutcome] = []
      var failure: Error?
      var processedPaths: Set<String> = []
      var failedPath: String?
      var lifecycleSummary = ""

      for (index, project) in projects.enumerated() {
        Task { @MainActor [weak self] in
          guard let self else { return }
          self.codexPortalProgress = Double(index) / Double(max(projects.count, 1))
          self.codexPortalProgressText = "\(index + 1) of \(projects.count): indexing \(project.name)"
          self.updateJob(id: jobID, progressText: self.codexPortalProgressText)
        }

        do {
          let progressHandler: (String, Int, Int64) -> Void = { phase, fileCount, byteCount in
            Task { @MainActor [weak self] in
              guard let self else { return }
              self.codexPortalProgress = (Double(index) + 0.25) / Double(max(projects.count, 1))
              self.codexPortalProgressText = "\(index + 1) of \(projects.count): \(phase) \(fileCount) entries (\(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)))"
              self.updateJob(id: jobID, progressText: self.codexPortalProgressText)
            }
          }
          let plan = try Self.buildCodexTransferPlan(
            project: project,
            outputRoot: outputRoot,
            mode: mode,
            destinationPath: resolvedDestinations[project.path],
            includeGit: includeGit,
            includeFinderMetadata: includeFinderMetadata,
            includeDependencies: includeDependencies,
            fullChecksumAudit: fullChecksumAudit,
            environment: environment,
            progress: progressHandler
          )
          Task { @MainActor [weak self] in
            guard let self else { return }
            self.codexTransferPlans.removeAll { $0.projectPath == project.path }
            self.codexTransferPlans.append(plan)
            self.codexPortalProgress = (Double(index) + 0.5) / Double(max(projects.count, 1))
            self.codexPortalProgressText = "\(index + 1) of \(projects.count): \(plan.planningLabel) for \(project.name)"
            self.updateJob(id: jobID, progressText: self.codexPortalProgressText)
          }
          if !plan.plannedPaths.isEmpty {
            guard let sourceIndex = Self.readCodexIndexArtifact(
              CodexFileIndexSnapshot.self,
              from: plan.sourceIndexPath
            ) else {
              throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "The saved source index for \(project.name) could not be reopened before transfer."])
            }
            _ = try Self.materializeCodexSourceFiles(
              sourceRoot: project.path,
              sourceIndex: sourceIndex,
              relativePaths: plan.plannedPaths,
              outputRoot: outputRoot,
              projectName: project.name,
              environment: environment
            ) { completed, total, bytes in
              Task { @MainActor [weak self] in
                guard let self else { return }
                self.codexPortalProgress = (Double(index) + 0.6) / Double(max(projects.count, 1))
                self.codexPortalProgressText = "\(index + 1) of \(projects.count): downloading iCloud files \(completed) of \(total) (\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))"
                self.updateJob(id: jobID, progressText: self.codexPortalProgressText)
              }
            }
          }
          Task { @MainActor [weak self] in
            guard let self else { return }
            self.codexPortalProgressText = "\(index + 1) of \(projects.count): transferring \(plan.plannedPaths.count) planned path(s) for \(project.name)"
            self.updateJob(id: jobID, progressText: self.codexPortalProgressText)
          }
          var outcome = try Self.performCodexTransfer(
            project: project,
            outputRoot: outputRoot,
            mode: mode,
            createBackup: createBackup,
            backupMedium: backupMedium,
            includeGit: includeGit,
            includeFinderMetadata: includeFinderMetadata,
            includeDependencies: includeDependencies,
            createCompatibilityLink: compatibilityLink,
            rearmGitMain: rearmGitMain,
            autoResumeExisting: autoResumeExisting || (plan.destinationPath.map {
              destinationUseCounts[Self.codexDestinationComparisonKey($0), default: 0] > 1
            } ?? false),
            transferPlan: plan,
            environment: environment
          )
          outcome.receiptPath = try Self.writeCodexStage1Receipt(
            project: project,
            outcome: outcome,
            transferPlan: plan,
            outputRoot: outputRoot,
            mode: mode,
            includeGit: includeGit,
            includeFinderMetadata: includeFinderMetadata,
            includeDependencies: includeDependencies
          )
          outcomes.append(outcome)
          processedPaths.insert(project.path)
        } catch {
          failure = error
          failedPath = project.path
          break
        }
      }

      if failure == nil, runLifecycle {
        Task { @MainActor [weak self] in
          guard let self else { return }
          self.codexPortalProgress = 0.82
          self.codexPortalProgressText = "Stage 1 verified. Running Stage 2 reconciliation and Stage 3 receipt cleanup..."
          self.codexLifecycleStatus = self.codexPortalProgressText
          self.updateJob(id: jobID, progressText: self.codexPortalProgressText)
        }
        do {
          guard let lifecycleCLIPath else {
            throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "The bundled lifecycle CLI was not found."])
          }
          lifecycleSummary = try Self.performCodexLifecycleStages(
            outcomes: outcomes,
            outputRoot: outputRoot,
            managedRoot: lifecycleManagedRoot,
            cliPath: lifecycleCLIPath,
            runStage2: lifecycleRunStage2,
            deleteStage1Originals: lifecycleDeleteStage1,
            cleanupScope: lifecycleCleanupScope,
            sourceRetention: lifecycleRetention,
            archiveStage2Sources: lifecycleArchiveStage2,
            createMissingRepos: lifecycleCreateMissingRepos,
            prepareRuntime: lifecyclePrepareRuntime,
            openAfterApply: lifecycleOpenAfterApply,
            host: lifecycleHost,
            account: lifecycleAccount,
            githubOwnerAccounts: lifecycleGitHubOwnerAccounts,
            activeProjectPaths: lifecycleActiveProjectPaths,
            environment: environment
          )
        } catch {
          failure = error
        }
      }

      Task { @MainActor [weak self] in
        guard let self else { return }
        self.isRunningCodexTransfer = false
        if let failure {
          let allPaths = Set(projects.map(\.path))
          let failedPaths = failedPath.map { Set([$0]) } ?? Set<String>()
          self.updateCodexRouteReceipts(
            completedPaths: processedPaths,
            interruptedPaths: allPaths.subtracting(processedPaths).subtracting(failedPaths),
            failedPaths: failedPaths
          )
          self.codexPortalProgressText = "Stopped after \(outcomes.count) completed project(s)."
          self.codexPortalStatus = "Transfer stopped safely: \(failure.localizedDescription)"
          if runLifecycle { self.codexLifecycleStatus = self.codexPortalStatus }
          self.updateJob(id: jobID, state: .failed, detail: self.codexPortalStatus, progressText: self.codexPortalProgressText)
          self.appendLog("[codex] \(self.codexPortalStatus)\n")
        } else {
          self.updateCodexRouteReceipts(
            completedPaths: processedPaths,
            interruptedPaths: [],
            failedPaths: []
          )
          let warningCount = outcomes.reduce(0) { $0 + $1.warnings.count }
          let resumedCount = outcomes.filter(\.resumedExistingDestination).count
          let reconciledCount = outcomes.reduce(0) { $0 + $1.reconciledFileCount }
          let conflictCount = outcomes.reduce(0) { $0 + $1.conflictCount }
          self.codexPortalProgress = 1
          self.codexPortalProgressText = "Completed \(outcomes.count) of \(projects.count) project(s)."
          let resumeSummary = resumedCount > 0
            ? " Auto-resumed \(resumedCount) existing destination(s); \(reconciledCount) missing or changed file(s) were reconciled."
            : ""
          let conflictSummary = conflictCount > 0
            ? " \(conflictCount) conflict(s) were preserved in a review folder."
            : ""
          self.codexPortalStatus = warningCount == 0
            ? "Verified \(mode.label.lowercased()) completed for \(outcomes.count) project(s).\(resumeSummary)\(conflictSummary) \(lifecycleSummary)"
            : "Completed with \(warningCount) preservation warning(s).\(resumeSummary)\(conflictSummary) \(lifecycleSummary)"
          if runLifecycle { self.codexLifecycleStatus = self.codexPortalStatus }
          self.updateJob(id: jobID, state: .succeeded, detail: self.codexPortalStatus, progressText: self.codexPortalProgressText)
          self.appendLog("[codex] \(self.codexPortalStatus)\n")
        }
        self.restoreCodexResumeSelection()
      }
    }
  }

  private nonisolated static func lifecycleSummaryValue(_ key: String, output: String) -> Int? {
    guard let summary = output.split(whereSeparator: \.isNewline).last(where: { $0.hasPrefix("SUMMARY |") }) else {
      return nil
    }
    for token in summary.split(whereSeparator: \.isWhitespace) {
      let parts = token.split(separator: "=", maxSplits: 1)
      if parts.count == 2, parts[0] == Substring(key) {
        return Int(parts[1])
      }
    }
    return nil
  }

  private nonisolated static func stage2ReceiptPaths(from output: String) -> [String] {
    var paths: [String] = []
    for line in output.split(whereSeparator: \.isNewline) {
      let text = String(line)
      guard let marker = text.range(of: "Stage 2 receipt:") else { continue }
      let path = text[marker.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
      if !path.isEmpty, !paths.contains(path) { paths.append(path) }
    }
    return paths
  }

  private nonisolated static func performCodexLifecycleStages(
    outcomes: [CodexProjectTransferOutcome],
    outputRoot: String,
    managedRoot: String,
    cliPath: String,
    runStage2: Bool,
    deleteStage1Originals: Bool,
    cleanupScope: CodexLifecycleCleanupScope,
    sourceRetention: Stage2SourceRetention,
    archiveStage2Sources: Bool,
    createMissingRepos: Bool,
    prepareRuntime: Bool,
    openAfterApply: String,
    host: String,
    account: String,
    githubOwnerAccounts: [String],
    activeProjectPaths: [String],
    environment: [String: String]
  ) throws -> String {
    let stage1Receipts = outcomes.compactMap(\.receiptPath)
    guard stage1Receipts.count == outcomes.count else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Stage 1 finished without a receipt for every project; later stages were not started."])
    }

    var stage2Receipts: [String] = []
    if runStage2 {
      let outcomeDestinations = outcomes.compactMap(\.destinationPath)
      guard outcomeDestinations.count == outcomes.count else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Stage 2 requires a verified destination for every Stage 1 project."])
      }
      var seenDestinations: Set<String> = []
      let destinations = outcomeDestinations.compactMap { destination -> String? in
        let normalized = NSString(string: destination).standardizingPath
        let comparisonKey = codexDestinationComparisonKey(normalized)
        return seenDestinations.insert(comparisonKey).inserted ? normalized : nil
      }
      var arguments = ["stage2", "--source", outputRoot, "--managed-root", managedRoot, "--apply", "--yes"]
      if !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        arguments.append(contentsOf: ["--host", host])
      }
      if !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        arguments.append(contentsOf: ["--account", account])
      }
      for binding in githubOwnerAccounts {
        arguments.append(contentsOf: ["--github-account", binding])
      }
      for destination in destinations {
        arguments.append(contentsOf: ["--project", destination])
      }
      for activePath in activeProjectPaths {
        arguments.append(contentsOf: ["--exclude-path", activePath])
      }
      if createMissingRepos { arguments.append("--create-missing-repos") }
      if archiveStage2Sources { arguments.append("--archive-sources") }
      if prepareRuntime { arguments.append("--prepare-runtime") }
      switch sourceRetention {
      case .keep:
        break
      case .retire:
        arguments.append("--retire-sources")
      case .delete:
        // Stage 2 may only retire verified inputs to managed _temp. Stage 3 is
        // the sole permanent-cleanup owner and consumes the exact receipts.
        arguments.append("--retire-sources")
      }
      if openAfterApply != Stage2OpenOption.none.rawValue {
        arguments.append(contentsOf: ["--open", openAfterApply])
      }
      let result = runCommand(executable: cliPath, arguments: arguments, environment: environment)
      let failed = lifecycleSummaryValue("failed", output: result.output) ?? -1
      let blocked = lifecycleSummaryValue("blocked", output: result.output) ?? -1
      let needsRepo = lifecycleSummaryValue("needs_repo", output: result.output) ?? -1
      let applied = lifecycleSummaryValue("applied", output: result.output) ?? -1
      guard result.status == 0, failed == 0, blocked == 0, needsRepo == 0, applied == destinations.count else {
        throw NSError(
          domain: appTitle,
          code: Int(result.status),
          userInfo: [NSLocalizedDescriptionKey: "Stage 2 stopped before cleanup. \(redactSensitiveText(result.output))"]
        )
      }
      stage2Receipts = stage2ReceiptPaths(from: result.output)
      guard stage2Receipts.count == destinations.count else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Stage 2 did not emit one verified receipt per unique destination; Stage 3 was not started."])
      }
    }

    let hasStage1SourceToDelete = deleteStage1Originals && outcomes.contains { $0.currentSourcePath != nil }
    let hasCurrentStage2Temp = runStage2 && (
      cleanupScope != .none || sourceRetention == .delete
    )
    let hasIndexedTemp = cleanupScope == .allVerifiedTemp
    if hasStage1SourceToDelete || hasCurrentStage2Temp || hasIndexedTemp {
      var commonArguments = ["stage3", "--source", outputRoot, "--managed-root", managedRoot]
      for binding in githubOwnerAccounts {
        commonArguments.append(contentsOf: ["--github-account", binding])
      }
      for receipt in stage1Receipts + stage2Receipts {
        commonArguments.append(contentsOf: ["--receipt", receipt])
      }
      if hasStage1SourceToDelete { commonArguments.append("--delete-stage1-originals") }
      if runStage2 && (sourceRetention == .delete || cleanupScope != .none) {
        commonArguments.append("--delete-stage2-inputs")
      }
      switch cleanupScope {
      case .none:
        if sourceRetention == .delete { commonArguments.append("--cleanup-transaction-temp") }
      case .currentTransaction:
        if runStage2 { commonArguments.append("--cleanup-transaction-temp") }
      case .allVerifiedTemp:
        commonArguments.append("--cleanup-all-verified-temp")
      }

      var preflightArguments = commonArguments
      preflightArguments.append("--preflight")
      let preflight = runCommand(executable: cliPath, arguments: preflightArguments, environment: environment)
      let preflightBlocked = lifecycleSummaryValue("blocked", output: preflight.output) ?? -1
      guard preflight.status == 0, preflightBlocked == 0 else {
        throw NSError(domain: appTitle, code: Int(preflight.status), userInfo: [NSLocalizedDescriptionKey: "Stage 3 preflight blocked cleanup. \(redactSensitiveText(preflight.output))"])
      }

      var applyArguments = commonArguments
      applyArguments.append(contentsOf: ["--apply", "--yes", "--confirm-delete", "VERIFIED-STAGE3"])
      let apply = runCommand(executable: cliPath, arguments: applyArguments, environment: environment)
      let failed = lifecycleSummaryValue("failed", output: apply.output) ?? -1
      let blocked = lifecycleSummaryValue("blocked", output: apply.output) ?? -1
      guard apply.status == 0, failed == 0, blocked == 0 else {
        throw NSError(domain: appTitle, code: Int(apply.status), userInfo: [NSLocalizedDescriptionKey: "Stage 3 stopped safely. \(redactSensitiveText(apply.output))"])
      }
    }

    let stage2Label = runStage2 ? ", Stage 2 receipts \(stage2Receipts.count)" : ""
    return "Full Auto verified: Stage 1 receipts \(stage1Receipts.count)\(stage2Label); selected cleanup policy completed."
  }

  private func parsedCodexScanRoots() -> [String] {
    var seen: Set<String> = []
    return codexScanRootsDraft
      .components(separatedBy: .newlines)
      .flatMap { $0.components(separatedBy: ";") }
      .map { normalizeWorkspacePath($0) }
      .filter { !$0.isEmpty && seen.insert($0).inserted }
  }

  func cancelRun() {
    cancellationRequested = true
    pendingRepoTargets.removeAll()
    runningProcess?.terminate()
  }

  func logoutSelectedAccount() {
    guard let ghPath else {
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first."
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedHost.isEmpty, !selectedAccount.isEmpty else {
      statusKind = .warning
      statusTitle = "No Account Selected"
      statusDetail = "Choose an authenticated account before logging out."
      return
    }

    isLoggingOut = true
    appendLog("[gui] Logging out \(selectedAccount) on \(selectedHost)\n")

    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["auth", "logout", "--hostname", selectedHost, "--user", selectedAccount],
        environment: environment,
        stdin: "y\n"
      )

      DispatchQueue.main.async {
        self.isLoggingOut = false
        let cleaned = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
          self.appendLog(cleaned + "\n")
        }
        self.viewerOrganizations = []
        self.githubAccountStatus = "Logged out. Refresh or log in again to load connected account details."
        self.safetyArmEnabled = false
        self.clearRepoCatalog(resetOwner: false)
        self.reloadAuthInventory()
        self.refreshAuthStatus()
      }
    }
  }

  func fetchViewerOrganizations() {
    guard let ghPath else {
      githubAccountStatus = "GitHub CLI was not found."
      return
    }

    guard isAuthenticated else {
      viewerOrganizations = []
      githubAccountStatus = "Log in first to load organizations and connected account details."
      return
    }

    isLoadingGitHubAccountDetails = true
    githubAccountStatus = "Loading connected GitHub account details..."
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let environment = baseEnvironment().merging(["GH_HOST": selectedHost]) { _, new in new }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["api", "user/orgs", "--jq", ".[].login"],
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingGitHubAccountDetails = false
        if result.status == 0 {
          self.viewerOrganizations = result.output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
          let orgLabel = self.viewerOrganizations.isEmpty ? "No org memberships reported." : "\(self.viewerOrganizations.count) organization memberships loaded."
          self.githubAccountStatus = "\(self.sessionCompactLabel)\n\(orgLabel)"
        } else {
          self.viewerOrganizations = []
          let cleaned = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.githubAccountStatus = cleaned.isEmpty ? "Failed to load organizations for the connected account." : cleaned
        }
      }
    }
  }

  func openGitHubHostPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)") else {
      appendLog("[gui] GitHub host URL is invalid.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func loadGitHubBillingReport() {
    guard let ghPath else {
      githubBillingStatus = "GitHub CLI was not found."
      return
    }
    guard isAuthenticated else {
      githubBillingStatus = "Log in with GitHub CLI first, then load usage."
      return
    }

    let owner = repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? account.trimmingCharacters(in: .whitespacesAndNewlines)
      : repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !owner.isEmpty else {
      githubBillingStatus = "Choose an account or organization first."
      return
    }

    isLoadingGitHubBilling = true
    githubBillingStatus = "Loading Actions, storage, and package usage for \(owner)…"
    let environment = baseEnvironment()
    let isPersonalScope = owner == account.trimmingCharacters(in: .whitespacesAndNewlines)
    let jobID = createJob(kind: "GitHub", title: "Billing usage report", target: owner, detail: "Loading GitHub billing usage…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let orgPrefix = "orgs/\(owner)/settings/billing"
      let userPrefix = "user/settings/billing"
      var unavailable = [String]()

      func load(_ suffix: String) -> [String: Any]? {
        let orgResult = Self.runCommand(executable: ghPath, arguments: ["api", "\(orgPrefix)/\(suffix)"], environment: environment)
        if let payload = Self.jsonObject(orgResult.output) {
          return payload
        }
        if isPersonalScope {
          let userResult = Self.runCommand(executable: ghPath, arguments: ["api", "\(userPrefix)/\(suffix)"], environment: environment)
          if let payload = Self.jsonObject(userResult.output) {
            return payload
          }
        }
        unavailable.append(suffix)
        return nil
      }

      let actions = load("actions")
      let sharedStorage = load("shared-storage")
      let packages = load("packages")
      let summary = Self.makeGitHubBillingSummary(owner: owner, actions: actions, sharedStorage: sharedStorage, packages: packages, unavailableReports: unavailable)

      DispatchQueue.main.async {
        self.isLoadingGitHubBilling = false
        self.githubBillingSummary = summary
        if unavailable.isEmpty {
          self.githubBillingStatus = "Loaded GitHub billing usage for \(owner). Amounts are GitHub usage units; open the GitHub billing report for current charges."
          self.finishJob(id: jobID, state: .succeeded, detail: "Loaded Actions, storage, and package usage.")
        } else {
          self.githubBillingStatus = "Loaded available usage for \(owner). GitHub did not grant access to: \(unavailable.joined(separator: ", ")). Open the billing report or add organization billing read access."
          self.finishJob(id: jobID, state: .succeeded, detail: "Loaded partial billing usage; unavailable: \(unavailable.joined(separator: ", ")).")
        }
      }
    }
  }

  func openGitHubBillingReport() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let owner = repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? account.trimmingCharacters(in: .whitespacesAndNewlines)
      : repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)
    let isOrganization = viewerOrganizations.contains(owner)
    let path = isOrganization ? "organizations/\(owner)/settings/billing/summary" : "settings/billing"
    guard let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(path)") else {
      appendLog("[gui] GitHub billing URL is invalid.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openGitHubAccountPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedAccount.isEmpty,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(selectedAccount)") else {
      appendLog("[gui] No connected GitHub account is selected.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openGitHubRepositoriesPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedAccount.isEmpty,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(selectedAccount)?tab=repositories") else {
      appendLog("[gui] No connected GitHub account is selected.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openGitHubSettingsPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/settings/profile") else {
      appendLog("[gui] GitHub settings URL is invalid.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openRepoSettingsPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let repo = primaryRepoSlug,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(repo)/settings") else {
      appendLog("[gui] No repository target is available to open in settings.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openRepoActionsPage() {
    openPrimaryRepoPage(pathSuffix: "?tab=actions")
  }

  func openRepoIssuesPage() {
    openPrimaryRepoPage(pathSuffix: "?tab=issues")
  }

  func openRepoPullRequestsPage() {
    openPrimaryRepoPage(pathSuffix: "?tab=pulls")
  }

  func openRepoProjectsPage() {
    openPrimaryRepoPage(pathSuffix: "?tab=projects")
  }

  func openRepoSecurityPage() {
    openPrimaryRepoPage(pathSuffix: "?tab=security")
  }

  func openRepoInsightsPage() {
    openPrimaryRepoPage(pathSuffix: "?tab=insights")
  }

  func copyGitHubHost() {
    copyToClipboard(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appSettings.defaultGitHubHost : host, label: "GitHub host")
  }

  func copyGitHubAccount() {
    copyToClipboard(account.trimmingCharacters(in: .whitespacesAndNewlines), label: "GitHub account")
  }

  func copyPrimaryRepoSlug() {
    copyToClipboard(primaryRepoSlug ?? "", label: "repository slug")
  }

  func copyPrimaryRepoURL() {
    guard let url = primaryRepoURL() else {
      appendLog("[gui] No repository target is available to copy.\n")
      return
    }
    copyToClipboard(url.absoluteString, label: "repository URL")
  }

  func copySelectedRepoSummary() {
    let repos = selectedRepos.sorted()
    guard !repos.isEmpty else {
      appendLog("[gui] No selected repositories are available to copy.\n")
      return
    }
    copyToClipboard(repos.joined(separator: "\n"), label: "selected repositories")
  }

  func openRepoOwnerPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let owner = repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? account.trimmingCharacters(in: .whitespacesAndNewlines)
      : repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !owner.isEmpty,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(owner)") else {
      appendLog("[gui] No owner or org is available to open.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  private func primaryRepoURL() -> URL? {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let repo = primaryRepoSlug else { return nil }
    return URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(repo)")
  }

  private func openPrimaryRepoPage(pathSuffix: String) {
    guard let baseURL = primaryRepoURL() else {
      appendLog("[gui] No repository target is available.\n")
      return
    }

    let finalURL = URL(string: pathSuffix, relativeTo: baseURL) ?? baseURL
    NSWorkspace.shared.open(finalURL)
  }

  func openBundledHelpDocument(_ fileName: String) {
    guard let url = bundledResourceURL(named: fileName, subdirectory: bundledHelpDirectory) ?? bundledResourceURL(named: fileName) else {
      appendLog("[gui] Help document not found: \(fileName)\n")
      return
    }

    NSWorkspace.shared.open(url)
  }

  func openCompanyWebsite() {
    guard let url = URL(string: companyWebsiteURL) else {
      appendLog("[gui] Company website URL is invalid.\n")
      return
    }

    NSWorkspace.shared.open(url)
  }

  func revealSessionStorage() {
    let supportURL = URL(fileURLWithPath: appSupportDir, isDirectory: true)
    try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
    NSWorkspace.shared.activateFileViewerSelecting([supportURL])
  }

  func revealBundledHelpDirectory() {
    guard let helpURL = bundledResourceURL(named: bundledHelpDirectory) ?? bundledResourceURL(named: "docs") else {
      appendLog("[gui] Bundled help directory was not found.\n")
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting([helpURL])
  }

  func setAllLoadedReposSelected(_ enabled: Bool) {
    if enabled {
      selectedRepos.formUnion(availableRepos.map(\.nameWithOwner))
    } else {
      selectedRepos.subtract(availableRepos.map(\.nameWithOwner))
    }

    if appSettings.autoLoadRepoHealth, !selectedRepos.isEmpty {
      loadRepoHealthForSelectedRepos()
    }
  }

  func toggleRepoSelection(_ repo: RepoCatalogEntry) {
    if selectedRepos.contains(repo.nameWithOwner) {
      selectedRepos.remove(repo.nameWithOwner)
    } else {
      selectedRepos.insert(repo.nameWithOwner)
    }

    if appSettings.autoLoadRepoHealth, !selectedRepos.isEmpty {
      loadRepoHealthForSelectedRepos()
    }
  }

  func setFilteredLocalProjectsSelected(_ enabled: Bool) {
    let slugs = filteredLocalProjects.map(\.slug)
    if enabled {
      selectedRepos.formUnion(slugs)
    } else {
      selectedRepos.subtract(slugs)
    }
  }

  func toggleLocalProjectTarget(_ project: LocalProjectEntry) {
    if selectedRepos.contains(project.slug) {
      selectedRepos.remove(project.slug)
    } else {
      selectedRepos.insert(project.slug)
    }
  }

  func toggleFavorite(_ project: LocalProjectEntry) {
    if favoriteProjects.contains(project.slug) {
      favoriteProjects.remove(project.slug)
    } else {
      favoriteProjects.insert(project.slug)
    }
    persistFavorites()
  }

  func saveCurrentProjectView() {
    let trimmedName = savedViewNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      settingsStatus = "Enter a name before saving a project view."
      return
    }

    let entry = SavedProjectView(
      id: UUID().uuidString,
      name: trimmedName,
      query: localProjectSearch,
      favoritesOnly: showFavoritesOnly
    )
    savedProjectViews.insert(entry, at: 0)
    persistSavedViews()
    savedViewNameDraft = ""
    settingsStatus = "Saved project view: \(entry.name)"
  }

  func applyProjectView(_ view: SavedProjectView) {
    localProjectSearch = view.query
    showFavoritesOnly = view.favoritesOnly
  }

  func deleteProjectView(_ view: SavedProjectView) {
    savedProjectViews.removeAll { $0.id == view.id }
    persistSavedViews()
  }

  func saveCurrentContext() {
    guard appSettings.privacyFirstMode == false else {
      settingsStatus = "Saved GitHub contexts are disabled in Privacy-First Mode."
      return
    }
    let name = contextNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      settingsStatus = "Enter a name before saving a GitHub context."
      return
    }

    let context = SavedGitHubContext(
      id: UUID().uuidString,
      name: name,
      host: host.trimmingCharacters(in: .whitespacesAndNewlines),
      account: account.trimmingCharacters(in: .whitespacesAndNewlines),
      owner: repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    savedContexts.insert(context, at: 0)
    persistContexts()
    contextNameDraft = ""
    settingsStatus = "Saved GitHub context: \(context.name)"
  }

  func applyContext(_ context: SavedGitHubContext) {
    host = context.host
    account = context.account
    repoOwner = context.owner
    repoTarget = ""
    selectedRepos.removeAll()
    refreshAuthStatus()
  }

  func deleteContext(_ context: SavedGitHubContext) {
    savedContexts.removeAll { $0.id == context.id }
    persistContexts()
  }

  func saveSettings() {
    appSettings.defaultGitHubHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appSettings.defaultGitHubHost : host.trimmingCharacters(in: .whitespacesAndNewlines)
    appSettings.firstRunComplete = true
    persistSettings()
    UserDefaults.standard.set(administratorTerminalMode, forKey: administratorTerminalModeKey)
    settingsStatus = "Settings saved."
  }

  func markLaunchWarningAccepted() {
    appSettings.firstRunComplete = true
    persistSettings()
  }

  func applyBackupPreset(_ preset: BackupPreset) {
    selectedBackupPreset = preset
    switch preset {
    case .codeOnly:
      localFileExportScope = .codeWorkspace
      includeProjectCodeExport = true
      includeProjectRuntimeExport = false
      includeProjectRunnerExport = false
    case .runtimeOnly:
      localFileExportScope = .runtimeWorkspace
      includeProjectCodeExport = false
      includeProjectRuntimeExport = true
      includeProjectRunnerExport = false
    case .projectBundle:
      localFileExportScope = .selectedProjects
      includeProjectCodeExport = true
      includeProjectRuntimeExport = true
      includeProjectRunnerExport = true
    case .runnerBundle:
      localFileExportScope = .selectedProjects
      includeProjectCodeExport = false
      includeProjectRuntimeExport = false
      includeProjectRunnerExport = true
    case .fullWorkspace:
      localFileExportScope = .workspaceBundle
      includeProjectCodeExport = true
      includeProjectRuntimeExport = true
      includeProjectRunnerExport = true
    }
  }

  func previewWorkspaceMove(_ scope: WorkspaceRelocationScope) {
    let destination = normalizeWorkspacePath(workspaceMoveDestinationDraft)
    guard !destination.isEmpty else {
      localFilesStatus = "Choose a destination before previewing the workspace move."
      return
    }

    let roots = resolvedProfileRoots()
    localExportPreparedStamp = ""
    localOperationPreview = Self.buildWorkspaceMovePreview(
      scope: scope,
      style: selectedWorkspaceStyle,
      codeRoot: roots.codeRoot,
      importRoot: roots.importRoot,
      runtimeRoot: roots.runtimeRoot,
      destinationBase: destination
    )
    localFilesStatus = "Preview ready for \(localOperationPreview?.title.lowercased() ?? "workspace move")."
  }

  func previewLocalExport() {
    let destination = normalizeWorkspacePath(localExportDestinationDraft)
    guard !destination.isEmpty else {
      localFilesStatus = "Choose a destination before previewing the local file export."
      return
    }

    let roots = resolvedProfileRoots()
    let preparedStamp = Self.timestampStamp()
    localExportPreparedStamp = preparedStamp
    localOperationPreview = Self.buildLocalExportPreview(
      scope: localFileExportScope,
      mode: localFileTransferMode,
      destinationBase: destination,
      preparedStamp: preparedStamp,
      roots: roots,
      selectedProjects: selectedLocalProjects,
      includeCode: includeProjectCodeExport,
      includeRuntime: includeProjectRuntimeExport,
      includeRunners: includeProjectRunnerExport
    )
    localFilesStatus = "Preview ready for \(localOperationPreview?.title.lowercased() ?? "local file export")."
  }

  func createSnapshot() {
    let roots = resolvedProfileRoots()
    let selectedProjects = selectedLocalProjects
    let snapshotID = UUID().uuidString
    let payloadPath = (snapshotsDirectory as NSString).appendingPathComponent(snapshotID)
    let environment = baseEnvironment()
    let scope = localFileExportScope
    let fallbackPrimaryProject = primaryLocalProject
    let includeCode = includeProjectCodeExport
    let includeRuntime = includeProjectRuntimeExport
    let includeRunners = includeProjectRunnerExport

    let jobID = createJob(kind: "Snapshot", title: "Create snapshot", target: primaryRepoSlug ?? "", detail: "Preparing snapshot…", initialState: .running)
    isRunningLocalFileOperation = true
    snapshotStatus = "Creating snapshot..."

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        try FileManager.default.createDirectory(atPath: payloadPath, withIntermediateDirectories: true, attributes: nil)
        _ = try Self.exportLocalFiles(
          scope: scope,
          mode: .copyBackup,
          destinationBase: payloadPath,
          roots: roots,
          selectedProjects: selectedProjects.isEmpty ? (fallbackPrimaryProject.map { [$0] } ?? []) : selectedProjects,
          includeCode: includeCode,
          includeRuntime: includeRuntime,
          includeRunners: includeRunners,
          overwrite: true,
          environment: environment
        )

        let itemCount = (selectedProjects.isEmpty ? (fallbackPrimaryProject == nil ? 0 : 1) : selectedProjects.count)
        let entry = SnapshotEntry(
          id: snapshotID,
          name: "Snapshot \(Self.timestampStamp())",
          createdAt: Date(),
          sourceScope: scope.label,
          destinationPath: payloadPath,
          itemCount: itemCount
        )

        DispatchQueue.main.async {
          self.writeSnapshot(entry)
          self.isRunningLocalFileOperation = false
          self.snapshotStatus = "Snapshot created."
          self.updateJob(id: jobID, appendLog: "Snapshot created at \(payloadPath)")
          self.finishJob(id: jobID, state: .succeeded, detail: "Snapshot created.")
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.snapshotStatus = error.localizedDescription
          self.finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
        }
      }
    }
  }

  func restoreSnapshot(_ entry: SnapshotEntry) {
    let roots = resolvedProfileRoots()
    let payloadPath = entry.destinationPath
    let environment = baseEnvironment()
    let jobID = createJob(kind: "Snapshot", title: "Restore snapshot", target: entry.name, detail: "Restoring snapshot…", initialState: .running)
    snapshotStatus = "Restoring snapshot..."

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        try Self.restoreSnapshotPayload(payloadPath: payloadPath, roots: roots, environment: environment)
        DispatchQueue.main.async {
          self.snapshotStatus = "Snapshot restored."
          self.finishJob(id: jobID, state: .succeeded, detail: "Snapshot restored.")
          self.refreshLocalProjects()
        }
      } catch {
        DispatchQueue.main.async {
          self.snapshotStatus = error.localizedDescription
          self.finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
        }
      }
    }
  }

  func removeSnapshot(_ entry: SnapshotEntry) {
    deleteSnapshot(entry)
    snapshotStatus = "Snapshot removed."
  }

  func addTaskTemplate() {
    guard let project = primaryLocalProject else {
      taskStatus = "Select or target a local project before adding a task."
      return
    }
    let name = taskNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    let command = taskCommandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !command.isEmpty else {
      taskStatus = "Enter both a task name and command."
      return
    }

    let task = ProjectTaskTemplate(
      id: UUID().uuidString,
      slug: project.slug,
      name: name,
      command: command,
      location: taskLocationDraft
    )
    taskTemplates.insert(task, at: 0)
    persistTasks()
    taskNameDraft = ""
    taskCommandDraft = ""
    taskStatus = "Saved task \(task.name) for \(project.slug)."
  }

  func removeTaskTemplate(_ task: ProjectTaskTemplate) {
    taskTemplates.removeAll { $0.id == task.id }
    persistTasks()
  }

  func runTaskTemplate(_ task: ProjectTaskTemplate) {
    guard let project = localProjects.first(where: { $0.slug == task.slug }) else {
      taskStatus = "Project for task \(task.name) was not found."
      return
    }

    let workingPath: String?
    switch task.location {
    case .code: workingPath = project.codePath ?? project.runtimePath
    case .runtime: workingPath = project.runtimePath ?? project.codePath
    }

    guard let workingPath else {
      taskStatus = "No working path was found for \(project.slug)."
      return
    }

    isRunningTask = true
    let jobID = createJob(kind: "Task", title: task.name, target: project.slug, detail: "Running task…", initialState: .running)
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-lc", "cd \(shellQuote(workingPath)) && \(task.command)"]
    process.environment = baseEnvironment()
    process.standardOutput = pipe
    process.standardError = pipe
    runningProcess = process
    activeJobID = jobID

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard data.isEmpty == false, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
      DispatchQueue.main.async {
        self?.appendLog(chunk)
        self?.updateJob(id: jobID, appendLog: chunk)
      }
    }

    process.terminationHandler = { [weak self] process in
      let tail = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.readabilityHandler = nil
      let tailText = String(data: tail, encoding: .utf8) ?? ""
      DispatchQueue.main.async {
        guard let self else { return }
        if !tailText.isEmpty {
          self.appendLog(tailText)
          self.updateJob(id: jobID, appendLog: tailText)
        }
        self.runningProcess = nil
        self.activeJobID = nil
        self.isRunningTask = false
        if process.terminationStatus == 0 {
          self.taskStatus = "Task finished successfully."
          self.finishJob(id: jobID, state: .succeeded, detail: "Task finished successfully.")
        } else {
          self.taskStatus = "Task failed with exit code \(process.terminationStatus)."
          self.finishJob(id: jobID, state: .failed, detail: "Task failed with exit code \(process.terminationStatus).")
        }
      }
    }

    do {
      try process.run()
    } catch {
      runningProcess = nil
      activeJobID = nil
      isRunningTask = false
      taskStatus = error.localizedDescription
      finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
    }
  }

  func fetchAvailableRepos() {
    guard let ghPath else {
      repoCatalogStatus = "GitHub CLI was not found."
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let targetOwner = repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? account.trimmingCharacters(in: .whitespacesAndNewlines)
      : repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !selectedHost.isEmpty else {
      repoCatalogStatus = "Enter a GitHub host first."
      return
    }

    guard isAuthenticated else {
      repoCatalogStatus = "Log into GitHub CLI first, then load repositories."
      return
    }

    guard !targetOwner.isEmpty else {
      repoCatalogStatus = "Enter an owner or org to list repositories."
      return
    }

    isLoadingRepos = true
    repoCatalogStatus = "Loading repositories for \(targetOwner) on \(selectedHost)..."
    appendLog("[gui] Loading repositories for \(targetOwner) on \(selectedHost)\n")

    let environment = baseEnvironment().merging(["GH_HOST": selectedHost]) { _, new in new }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: [
          "repo", "list", targetOwner,
          "--limit", "1000",
          "--json", "nameWithOwner,visibility,isPrivate,updatedAt,url"
        ],
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingRepos = false
        let cleaned = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedCleaned = redactSensitiveText(cleaned)

        guard result.status == 0 else {
          self.availableRepos = []
          self.repoCatalogStatus = sanitizedCleaned.isEmpty
            ? "Failed to load repositories for \(targetOwner)."
            : sanitizedCleaned
          return
        }

        let data = Data(result.output.utf8)
        do {
          let decoded = try JSONDecoder().decode([RepoCatalogEntry].self, from: data)
          self.availableRepos = decoded.sorted { $0.nameWithOwner.localizedCaseInsensitiveCompare($1.nameWithOwner) == .orderedAscending }
          if self.availableRepos.isEmpty {
            self.repoCatalogStatus = "No repositories found for \(targetOwner) on \(selectedHost)."
          } else {
            self.repoCatalogStatus = "Loaded \(self.availableRepos.count) repositories for \(targetOwner)."
          }
        } catch {
          self.availableRepos = []
          self.repoCatalogStatus = "Failed to decode repository list: \(error.localizedDescription)"
        }
      }
    }
  }

  var selectedIssue: GitHubIssueEntry? {
    guard let selectedIssueNumber else { return githubIssues.first }
    return githubIssues.first(where: { $0.number == selectedIssueNumber }) ?? githubIssues.first
  }

  var selectedIssueTemplate: GitHubIssueTemplate? {
    guard let selectedIssueTemplateID else { return issueTemplates.first }
    return issueTemplates.first(where: { $0.id == selectedIssueTemplateID }) ?? issueTemplates.first
  }

  func loadGitHubIssues() {
    guard let ghPath else {
      issueStatus = "GitHub CLI was not found."
      return
    }
    guard isAuthenticated else {
      issueStatus = "Log into GitHub CLI first, then load issues."
      return
    }
    guard let repo = primaryRepoSlug, !repo.isEmpty else {
      issueStatus = "Select or enter a repository before loading issues."
      return
    }

    isLoadingIssues = true
    issueStatus = "Loading issues for \(repo)…"
    let previousSelection = selectedIssueNumber
    let environment = baseEnvironment().merging(["GH_HOST": host.trimmingCharacters(in: .whitespacesAndNewlines)], uniquingKeysWith: { _, new in new })
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["issue", "list", "--repo", repo, "--limit", "100", "--state", "all", "--json", "number,title,state,createdAt,updatedAt,url,labels"],
        environment: environment
      )
      DispatchQueue.main.async {
        self.isLoadingIssues = false
        guard result.status == 0 else {
          self.githubIssues = []
          self.issueStatus = redactSensitiveText(result.output).trimmingCharacters(in: .whitespacesAndNewlines)
          return
        }
        do {
          self.githubIssues = try JSONDecoder().decode([GitHubIssueEntry].self, from: Data(result.output.utf8))
          self.selectedIssueNumber = self.githubIssues.contains(where: { $0.number == previousSelection }) ? previousSelection : self.githubIssues.first?.number
          self.issueMutationArmed = false
          self.issueMutationStatus = self.githubIssues.isEmpty ? "No issue selected." : "Select an issue and review the proposed remote action."
          self.issueStatus = "Loaded \(self.githubIssues.count) issue(s) for \(repo)."
        } catch {
          self.githubIssues = []
          self.issueStatus = "Could not decode the GitHub issue list: \(error.localizedDescription)"
        }
      }
    }
  }

  func applySelectedIssueTemplate() {
    guard let template = selectedIssueTemplate else { return }
    issueDraftTitle = template.titlePrefix
    issueDraftBody = template.body
    issueDraftLabels = template.labels
    issueWriteArmed = false
    issueStatus = "Template loaded locally. Review the title and body before arming a remote create."
  }

  func resetIssueMutationArm(_ status: String? = nil) {
    issueMutationArmed = false
    if let status { issueMutationStatus = status }
  }

  func prepareIssueMutationRetry(_ record: CSAiEMGitHubIssueRetryRecord) {
    selectedIssueNumber = record.command.issueNumber
    selectedIssueMutation = record.command.mutation
    issueMutationBody = record.command.body
    issueMutationLabels = record.command.labels.joined(separator: ",")
    issueMutationArmed = false
    issueMutationStatus = "Retry prepared for \(record.repository)#\(record.command.issueNumber). Review the retained payload and arm the remote action again."
  }

  private func rememberIssueMutationRetry(command: CSAiEMGitHubIssueCommand, repository: String, error: String) {
    let hostValue = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appSettings.defaultGitHubHost : host.trimmingCharacters(in: .whitespacesAndNewlines)
    let retryID = "\(hostValue)|\(repository)|\(command.issueNumber)|\(command.mutation.rawValue)"
    let now = Date()
    if let index = issueMutationRetries.firstIndex(where: { $0.id == retryID }) {
      issueMutationRetries[index].lastAttemptAt = now
      issueMutationRetries[index].attempts += 1
      issueMutationRetries[index].lastError = redactSensitiveText(error)
    } else {
      issueMutationRetries.insert(CSAiEMGitHubIssueRetryRecord(id: retryID, host: hostValue, repository: repository, command: command, createdAt: now, lastAttemptAt: now, attempts: 1, lastError: redactSensitiveText(error)), at: 0)
    }
    issueMutationRetries.sort { $0.lastAttemptAt > $1.lastAttemptAt }
    persistIssueMutationRetries()
  }

  private func clearIssueMutationRetry(command: CSAiEMGitHubIssueCommand, repository: String) {
    let hostValue = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appSettings.defaultGitHubHost : host.trimmingCharacters(in: .whitespacesAndNewlines)
    let retryID = "\(hostValue)|\(repository)|\(command.issueNumber)|\(command.mutation.rawValue)"
    issueMutationRetries.removeAll { $0.id == retryID }
    persistIssueMutationRetries()
  }

  private func providerFailureDetail(prefix: String, status: Int, output: String) -> String {
    let outcome = CSAiEMGitHubProviderOutcome.classify(status: status, output: output)
    let detail = redactSensitiveText(output).trimmingCharacters(in: .whitespacesAndNewlines)
    return "\(prefix) [\(outcome.title)]: \(detail)"
  }

  func mutateSelectedGitHubIssue() {
    guard issueMutationArmed else {
      issueMutationStatus = "Arm the reviewed issue action before making a remote change."
      return
    }
    guard let ghPath, let repo = primaryRepoSlug, !repo.isEmpty else {
      issueMutationStatus = "Select a repository and confirm GitHub CLI availability first."
      return
    }
    guard isAuthenticated else {
      issueMutationStatus = "GitHub CLI login is required before a remote issue change can be made."
      return
    }
    let command: CSAiEMGitHubIssueCommand
    do {
      command = try CSAiEMGitHubIssueCommand.make(mutation: selectedIssueMutation, issueNumber: selectedIssueNumber, body: issueMutationBody, labels: issueMutationLabels)
    } catch {
      issueMutationStatus = error.localizedDescription
      return
    }

    let arguments = command.arguments + ["--repo", repo]
    let jobID = createJob(kind: "GitHub", title: "Update GitHub issue", target: "\(repo)#\(command.issueNumber)", detail: "Applying a reviewed \(command.mutation.title.lowercased()) action…", initialState: .running)
    issueMutationRetryCommands[jobID] = command
    issueMutationStatus = "Applying the reviewed \(command.mutation.title.lowercased()) action to \(repo)#\(command.issueNumber)…"
    let environment = baseEnvironment().merging(["GH_HOST": host.trimmingCharacters(in: .whitespacesAndNewlines)], uniquingKeysWith: { _, new in new })
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: arguments, environment: environment, timeout: 60)
      DispatchQueue.main.async {
        self.issueMutationArmed = false
        if result.status == 0 {
          self.issueMutationStatus = "Remote action accepted. Verifying provider state…"
          let verificationArguments = CSAiEMGitHubIssueVerifier.arguments(for: command.issueNumber) + ["--repo", repo]
          DispatchQueue.global(qos: .userInitiated).async {
            let verification = Self.runCommand(executable: ghPath, arguments: verificationArguments, environment: environment, timeout: 60)
            DispatchQueue.main.async {
              guard verification.status == 0 else {
                let detail = self.providerFailureDetail(prefix: "Remote action was accepted, but provider read-back failed", status: Int(verification.status), output: verification.output)
                self.issueMutationStatus = detail
                self.rememberIssueMutationRetry(command: command, repository: repo, error: detail)
                self.finishJob(id: jobID, state: .failed, detail: detail)
                self.loadGitHubIssues()
                return
              }
              do {
                let payload = try JSONDecoder().decode(CSAiEMGitHubIssueVerificationPayload.self, from: Data(verification.output.utf8))
                switch CSAiEMGitHubIssueVerifier.verify(payload, command: command) {
                case .success(let detail):
                  self.issueMutationStatus = "\(detail) Remote issue state confirmed."
                  self.clearIssueMutationRetry(command: command, repository: repo)
                  self.updateJob(id: jobID, state: .succeeded, detail: detail)
                case .failure(let error):
                  let detail = "Remote action was accepted, but provider read-back did not match: \(error.localizedDescription)"
                  self.issueMutationStatus = detail
                  self.rememberIssueMutationRetry(command: command, repository: repo, error: detail)
                  self.finishJob(id: jobID, state: .failed, detail: detail)
                }
              } catch {
                let detail = "Remote action was accepted, but provider read-back could not be decoded: \(error.localizedDescription)"
                self.issueMutationStatus = detail
                self.rememberIssueMutationRetry(command: command, repository: repo, error: detail)
                self.finishJob(id: jobID, state: .failed, detail: detail)
              }
              self.loadGitHubIssues()
            }
          }
        } else {
          let detail = self.providerFailureDetail(prefix: "GitHub issue action failed", status: Int(result.status), output: result.output)
          self.issueMutationStatus = detail
          self.rememberIssueMutationRetry(command: command, repository: repo, error: detail)
          self.finishJob(id: jobID, state: .failed, detail: self.issueMutationStatus)
        }
      }
    }
  }

  func prepareIssueDraft(for incident: CSAiEMIncident) {
    selectedIssueTemplateID = "incident"
    issueDraftTitle = "[CSA-iEM] \(incident.title)"
    issueDraftBody = CSAiEMIncidentClassifier.redactedIssueDraft(for: incident)
    issueDraftLabels = "csa-iem,incident"
    issueWriteArmed = false
    issueStatus = "Incident draft prepared locally. No GitHub write has occurred."
  }

  func createGitHubIssueFromDraft() {
    guard issueWriteArmed else {
      issueStatus = "Arm the reviewed issue draft before creating a remote issue."
      return
    }
    guard let ghPath, let repo = primaryRepoSlug else {
      issueStatus = "Select a repository and confirm GitHub CLI availability first."
      return
    }
    guard isAuthenticated else {
      issueStatus = "GitHub CLI login is required before a remote issue can be created."
      return
    }
    let title = issueDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let body = issueDraftBody.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, !body.isEmpty else {
      issueStatus = "Issue title and body are required."
      return
    }

    let arguments: [String] = {
      var values = ["issue", "create", "--repo", repo, "--title", title, "--body", body]
      if !issueDraftLabels.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        values.append(contentsOf: ["--label", issueDraftLabels])
      }
      return values
    }()
    let jobID = createJob(kind: "GitHub", title: "Create GitHub issue", target: repo, detail: "Creating a reviewed issue…", initialState: .running)
    issueStatus = "Creating the reviewed issue for \(repo)…"
    let environment = baseEnvironment().merging(["GH_HOST": host.trimmingCharacters(in: .whitespacesAndNewlines)], uniquingKeysWith: { _, new in new })
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: arguments, environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.issueWriteArmed = false
          self.issueStatus = "Issue created. Review the returned GitHub URL before continuing."
          self.updateJob(id: jobID, state: .succeeded, detail: redactSensitiveText(result.output).trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
          self.issueStatus = "Issue creation failed: \(redactSensitiveText(result.output).trimmingCharacters(in: .whitespacesAndNewlines))"
          self.finishJob(id: jobID, state: .failed, detail: self.issueStatus)
        }
      }
    }
  }

  func loadRepoHealthForSelectedRepos() {
    let targets = selectedRepos.isEmpty ? (primaryRepoSlug.map { [$0] } ?? []) : Array(selectedRepos).sorted()
    loadRepoHealth(for: targets, label: "selected")
  }

  func loadRepoHealthForVisibleRepos() {
    let visible = filteredRepos.prefix(20).map(\.nameWithOwner)
    loadRepoHealth(for: visible, label: "visible")
  }

  private func loadRepoHealth(for targets: [String], label: String) {
    guard let ghPath else {
      repoHealthStatus = "GitHub CLI was not found."
      return
    }
    guard !targets.isEmpty else {
      repoHealthStatus = "Select or load at least one repository first."
      return
    }

    isLoadingRepoHealth = true
    let environment = baseEnvironment()
    let localProjects = self.localProjects
    let jobID = createJob(kind: "GitHub", title: "Repo health scan", target: "\(targets.count) repos", detail: "Loading repo health…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let entries = targets.map { slug in
        Self.scanRepoHealth(slug: slug, ghPath: ghPath, localProjects: localProjects, environment: environment)
      }

      DispatchQueue.main.async {
        self.isLoadingRepoHealth = false
        self.repoHealthEntries = entries.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
        self.repoHealthStatus = "Loaded repo health for \(entries.count) \(label) repos."
        self.finishJob(id: jobID, state: .succeeded, detail: "Loaded repo health for \(entries.count) repos.")
      }
    }
  }

  func loadResearchSnapshot() {
    guard let ghPath else {
      researchStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug, !repo.isEmpty else {
      researchStatus = "Select one repository before building an intelligence snapshot."
      return
    }

    isLoadingResearchSnapshot = true
    researchStatus = "Building a read-only metadata snapshot for " + repo + "…"
    let localProjects = self.localProjects
    let environment = baseEnvironment().merging(["GH_HOST": host.trimmingCharacters(in: .whitespacesAndNewlines)], uniquingKeysWith: { _, new in new })
    let jobID = createJob(kind: "Research", title: "Repository intelligence snapshot", target: repo, detail: "Reading repository metadata…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: [
          "repo", "view", repo, "--json",
          "nameWithOwner,description,defaultBranchRef,isArchived,isFork,homepageUrl,licenseInfo,primaryLanguage,repositoryTopics,pushedAt,updatedAt,createdAt,stargazerCount,forkCount,issues,pullRequests"
        ],
        environment: environment,
        timeout: 30
      )

      DispatchQueue.main.async {
        self.isLoadingResearchSnapshot = false
        guard result.status == 0,
              let metadata = Self.decodeJSONArray(CSAiEMResearchRepositoryMetadata.self, from: result.output) else {
          let outcome = CSAiEMGitHubProviderOutcome.classify(status: Int(result.status), output: result.output)
          let detail = redactSensitiveText(result.output).trimmingCharacters(in: .whitespacesAndNewlines)
          self.researchStatus = "Snapshot failed [" + outcome.title + "]: " + (detail.isEmpty ? "GitHub returned no detail." : detail)
          self.finishJob(id: jobID, state: .failed, detail: self.researchStatus)
          return
        }

        let matches = localProjects
          .filter { $0.slug.caseInsensitiveCompare(repo) == .orderedSame }
          .flatMap { project in
            [project.codePath, project.runtimePath].compactMap { $0 }
          }
        let uniqueMatches = Array(Set(matches)).sorted()
        let localSummaries = CSAiEMLocalCodebaseSummary.scan(paths: uniqueMatches)
        let localDocumentation = CSAiEMLocalDocumentationSummary.scan(paths: uniqueMatches)
        let localWorkflows = CSAiEMLocalWorkflowSummary.scan(paths: uniqueMatches)
        let remoteWorkflowsResult = Self.runCommand(
          executable: ghPath,
          arguments: ["workflow", "list", "--all", "--json", "id,name,path,state", "-R", repo],
          environment: environment,
          timeout: 30
        )
        let remoteWorkflows = remoteWorkflowsResult.status == 0 ? (Self.decodeJSONArray([WorkflowCatalogEntry].self, from: remoteWorkflowsResult.output) ?? []) : []
        let vulnerabilityResult = Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)/vulnerability-alerts", "--silent"], environment: environment, timeout: 30)
        let secretScanningResult = Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)/secret-scanning/alerts?per_page=1", "--silent"], environment: environment, timeout: 30)
        let codeScanningResult = Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)/code-scanning/alerts?per_page=1", "--silent"], environment: environment, timeout: 30)
        let remoteDocumentationResult = Self.runCommand(
          executable: ghPath,
          arguments: ["api", "repos/\(repo)/contents?ref=\(metadata.defaultBranchRef?.name ?? "")", "--silent"],
          environment: environment,
          timeout: 30
        )
        let remoteDocumentation = remoteDocumentationResult.status == 0
          ? (Self.decodeJSONArray([CSAiEMRemoteDocumentationEntry].self, from: remoteDocumentationResult.output) ?? []).filter { entry in
              let value = (entry.name + "/" + entry.path).lowercased()
              return value.contains("readme") || value.contains("docs") || value.contains("wiki") || value.contains("contribut") || value.contains("security") || value.contains("changelog") || value.contains("history") || value.contains("release") || value.contains("license")
            }.prefix(40).map { $0 }
          : []
        let documentation = CSAiEMResearchDocumentationSummary(
          local: localDocumentation,
          remote: remoteDocumentation,
          remoteStatus: remoteDocumentationResult.status == 0 ? "available" : CSAiEMGitHubProviderOutcome.classify(status: Int(remoteDocumentationResult.status), output: remoteDocumentationResult.output).title,
          warnings: [
            remoteDocumentationResult.status == 0 ? nil : "Remote documentation inventory unavailable [" + CSAiEMGitHubProviderOutcome.classify(status: Int(remoteDocumentationResult.status), output: remoteDocumentationResult.output).title + "].",
            localDocumentation.count >= 32 ? "Local documentation inventory capped at 32 files." : nil
          ].compactMap { $0 }
        )
        let security = CSAiEMResearchSecuritySummary(
          vulnerabilityAlerts: Self.researchAvailabilityLabel(vulnerabilityResult),
          secretScanningAlerts: Self.researchAvailabilityLabel(secretScanningResult),
          codeScanningAlerts: Self.researchAvailabilityLabel(codeScanningResult),
          workflowCount: remoteWorkflows.count,
          localWorkflowCount: localWorkflows.count,
          localWorkflowWarnings: localWorkflows.reduce(0) { $0 + $1.warnings.count },
          readBoundary: "Read-only metadata and bounded local workflow text; no secret values, workflow writes, alert dismissal, or administrative changes.",
          warnings: [
            remoteWorkflowsResult.status == 0 ? nil : "Remote workflow inventory unavailable [" + CSAiEMGitHubProviderOutcome.classify(status: Int(remoteWorkflowsResult.status), output: remoteWorkflowsResult.output).title + "].",
            localWorkflows.count >= 40 ? "Local workflow inventory capped at 40 files." : nil
          ].compactMap { $0 }
        )
        let releaseResult = Self.runCommand(
          executable: ghPath,
          arguments: ["release", "list", "--repo", repo, "--limit", "20", "--json", "tagName,name,publishedAt,isDraft,isPrerelease,url"],
          environment: environment,
          timeout: 30
        )
        let releases = releaseResult.status == 0 ? (Self.decodeJSONArray([CSAiEMResearchReleaseEntry].self, from: releaseResult.output) ?? []) : []
        let localChangelogs = CSAiEMLocalChangelogSummary.scan(paths: uniqueMatches)
        self.researchSnapshot = CSAiEMResearchSnapshot.build(metadata: metadata, localMatches: uniqueMatches, localSummaries: localSummaries, releases: releases, localChangelogs: localChangelogs, documentation: documentation, localWorkflows: localWorkflows, security: security)
        let releaseNote = releaseResult.status == 0 ? "" : " Release history was unavailable [" + CSAiEMGitHubProviderOutcome.classify(status: Int(releaseResult.status), output: releaseResult.output).title + "]; local evidence remains available."
        self.researchStatus = "Read-only intelligence snapshot ready for " + repo + ". Review evidence before any import, merge, backup, or cleanup action." + releaseNote
        self.finishJob(id: jobID, state: .succeeded, detail: self.researchSnapshot?.summary ?? "Research snapshot ready.")
      }
    }
  }

  func loadWorkflowCatalog() {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }

    isLoadingWorkflowData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Workflow catalog", target: repo, detail: "Loading workflows…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["workflow", "list", "--all", "--json", "id,name,path,state", "-R", repo],
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingWorkflowData = false
        if result.status == 0, let data = result.output.data(using: .utf8), let decoded = try? JSONDecoder().decode([WorkflowCatalogEntry].self, from: data) {
          self.workflows = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
          self.workflowStatus = "Loaded \(decoded.count) workflows for \(repo)."
          self.finishJob(id: jobID, state: .succeeded, detail: "Loaded \(decoded.count) workflows.")
          if self.appSettings.autoLoadWorkflowRuns {
            self.loadWorkflowRuns()
          }
        } else {
          self.workflowStatus = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load workflows." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: self.workflowStatus)
        }
      }
    }
  }

  func loadWorkflowRuns() {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }

    isLoadingWorkflowData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Workflow runs", target: repo, detail: "Loading workflow runs…", initialState: .running)
    let arguments = ["run", "list", "--all", "--limit", "50", "--json", "databaseId,name,workflowName,displayTitle,event,headBranch,status,conclusion,createdAt,updatedAt", "-R", repo]

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: arguments, environment: environment)
      DispatchQueue.main.async {
        self.isLoadingWorkflowData = false
        if result.status == 0, let data = result.output.data(using: .utf8), let decoded = try? JSONDecoder().decode([WorkflowRunEntry].self, from: data) {
          self.workflowRuns = decoded
          self.workflowStatus = "Loaded \(decoded.count) workflow runs for \(repo)."
          self.finishJob(id: jobID, state: .succeeded, detail: "Loaded \(decoded.count) workflow runs.")
        } else {
          self.workflowStatus = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load workflow runs." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: self.workflowStatus)
        }
      }
    }
  }

  func enableWorkflow(_ workflow: WorkflowCatalogEntry) {
    mutateWorkflow(workflow, verb: "enable", successMessage: "Workflow enabled.")
  }

  func disableWorkflow(_ workflow: WorkflowCatalogEntry) {
    mutateWorkflow(workflow, verb: "disable", successMessage: "Workflow disabled.")
  }

  private func mutateWorkflow(_ workflow: WorkflowCatalogEntry, verb: String, successMessage: String) {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "\(verb.capitalized) workflow", target: workflow.name, detail: "\(verb.capitalized) workflow…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: ["workflow", verb, "\(workflow.id)", "-R", repo], environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.workflowStatus = successMessage
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
          self.loadWorkflowCatalog()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workflow action failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.workflowStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func runWorkflow(_ workflow: WorkflowCatalogEntry) {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Dispatch workflow", target: workflow.name, detail: "Triggering workflow dispatch…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: ["workflow", "run", workflow.path, "-R", repo], environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.workflowStatus = "Workflow dispatch requested for \(workflow.name)."
          self.finishJob(id: jobID, state: .succeeded, detail: self.workflowStatus)
          self.loadWorkflowRuns()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to dispatch workflow." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.workflowStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func openWorkflowSource(_ workflow: WorkflowCatalogEntry) {
    guard let repo = primaryRepoSlug else { return }
    if let project = localProjects.first(where: { $0.slug == repo }), let codePath = project.codePath {
      let localPath = (codePath as NSString).appendingPathComponent(workflow.path)
      if FileManager.default.fileExists(atPath: localPath) {
        openProjectPaths(codePath: localPath, runtimePath: nil, fallbackPath: localPath, preferRuntime: false, label: workflow.name)
        return
      }
    }
    if let url = URL(string: "https://\(host)/\(repo)/blob/HEAD/\(workflow.path)") {
      NSWorkspace.shared.open(url)
    }
  }

  func cancelWorkflowRun(_ run: WorkflowRunEntry) {
    mutateRun(run, args: ["run", "cancel", "\(run.databaseId)", "-R", primaryRepoSlug ?? ""], successMessage: "Workflow run cancelled.")
  }

  func rerunWorkflowRun(_ run: WorkflowRunEntry) {
    mutateRun(run, args: ["run", "rerun", "\(run.databaseId)", "-R", primaryRepoSlug ?? ""], successMessage: "Workflow run rerun requested.")
  }

  func deleteWorkflowRun(_ run: WorkflowRunEntry) {
    mutateRun(run, args: ["run", "delete", "\(run.databaseId)", "-R", primaryRepoSlug ?? ""], successMessage: "Workflow run deleted.")
  }

  private func mutateRun(_ run: WorkflowRunEntry, args: [String], successMessage: String) {
    guard let ghPath, let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Workflow run action", target: "\(run.databaseId)", detail: "Running workflow run action…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: args, environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.workflowStatus = successMessage
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
          self.loadWorkflowRuns()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Run action failed for \(repo)." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.workflowStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func openWorkflowRunInBrowser(_ run: WorkflowRunEntry) {
    guard let repo = primaryRepoSlug,
          let url = URL(string: "https://\(host)/\(repo)/actions/runs/\(run.databaseId)") else { return }
    NSWorkspace.shared.open(url)
  }

  func loadCodespaces() {
    guard let ghPath else {
      codespacesStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      codespacesStatus = "Select a repository target first."
      return
    }
    isLoadingCodespaces = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Codespaces inventory", target: repo, detail: "Loading Codespaces…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["codespace", "list", "--repo", repo, "--json", "name,displayName,state,lastUsedAt,machineName,repository"],
        environment: environment
      )
      DispatchQueue.main.async {
        self.isLoadingCodespaces = false
        if result.status == 0 {
          self.codespaces = Self.parseCodespaces(result.output)
          self.codespacesStatus = "Loaded \(self.codespaces.count) Codespaces for \(repo)."
          self.finishJob(id: jobID, state: .succeeded, detail: self.codespacesStatus)
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load Codespaces." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.codespacesStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func stopCodespace(_ entry: CodespaceInventoryEntry) {
    mutateCodespace(entry, args: ["codespace", "stop", "--codespace", entry.name], successMessage: "Codespace stopped.")
  }

  func deleteCodespace(_ entry: CodespaceInventoryEntry) {
    mutateCodespace(entry, args: ["codespace", "delete", "--codespace", entry.name, "--force"], successMessage: "Codespace deleted.")
  }

  private func mutateCodespace(_ entry: CodespaceInventoryEntry, args: [String], successMessage: String) {
    guard let ghPath else {
      codespacesStatus = "GitHub CLI was not found."
      return
    }
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Codespace action", target: entry.name, detail: "Running Codespace action…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: args, environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.codespacesStatus = successMessage
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
          self.loadCodespaces()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Codespace action failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.codespacesStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func loadSecretsAndVariables() {
    guard let ghPath else {
      secretsStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      secretsStatus = "Select a repository target first."
      return
    }

    let owner = repo.split(separator: "/").first.map(String.init) ?? repoOwner
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let knownOrganizations = viewerOrganizations
    let shouldQueryOrgScope = !owner.isEmpty && (owner != selectedAccount || knownOrganizations.contains(owner))
    isLoadingSecretsData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Secrets and variables", target: repo, detail: "Loading secrets and variables…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let repoSecretsResult = Self.runCommand(executable: ghPath, arguments: ["secret", "list", "--json", "name,updatedAt,visibility", "-R", repo], environment: environment)
      let repoVariablesResult = Self.runCommand(executable: ghPath, arguments: ["variable", "list", "--json", "name,updatedAt,visibility", "-R", repo], environment: environment)
      let orgSecretsResult = shouldQueryOrgScope
        ? Self.runCommand(executable: ghPath, arguments: ["secret", "list", "--json", "name,updatedAt,visibility", "--org", owner], environment: environment)
        : CommandResult(status: 0, output: "[]")
      let orgVariablesResult = shouldQueryOrgScope
        ? Self.runCommand(executable: ghPath, arguments: ["variable", "list", "--json", "name,updatedAt,visibility", "--org", owner], environment: environment)
        : CommandResult(status: 0, output: "[]")

      DispatchQueue.main.async {
        self.isLoadingSecretsData = false
        self.repoSecrets = repoSecretsResult.status == 0 ? (Self.decodeJSONArray([SecretRecord].self, from: repoSecretsResult.output) ?? []) : []
        self.repoVariables = repoVariablesResult.status == 0 ? (Self.decodeJSONArray([VariableRecord].self, from: repoVariablesResult.output) ?? []) : []
        self.orgSecrets = orgSecretsResult.status == 0 ? (Self.decodeJSONArray([SecretRecord].self, from: orgSecretsResult.output) ?? []) : []
        self.orgVariables = orgVariablesResult.status == 0 ? (Self.decodeJSONArray([VariableRecord].self, from: orgVariablesResult.output) ?? []) : []

        var failures: [String] = []
        if repoSecretsResult.status != 0 { failures.append("repo secrets") }
        if repoVariablesResult.status != 0 { failures.append("repo variables") }
        if shouldQueryOrgScope {
          if orgSecretsResult.status != 0 { failures.append("org secrets") }
          if orgVariablesResult.status != 0 { failures.append("org variables") }
        }

        let orgScopeNote = shouldQueryOrgScope ? nil : "Organization-level inventory was skipped because the selected owner does not appear to be an organization context for this session."
        let summary = "Loaded \(self.repoSecrets.count) repo secrets, \(self.repoVariables.count) repo variables, \(self.orgSecrets.count) org secrets, and \(self.orgVariables.count) org variables."

        if failures.isEmpty {
          self.secretsStatus = [summary, orgScopeNote].compactMap { $0 }.joined(separator: "\n")
          self.finishJob(id: jobID, state: .succeeded, detail: summary)
        } else {
          let failureSummary = "Partial load only. Failed: \(failures.joined(separator: ", "))."
          self.secretsStatus = [summary, failureSummary, orgScopeNote].compactMap { $0 }.joined(separator: "\n")
          self.finishJob(id: jobID, state: .failed, detail: failureSummary)
        }
      }
    }
  }

  func loadBranchProtectionAndRulesets() {
    guard let ghPath else {
      rulesStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      rulesStatus = "Select a repository target first."
      return
    }
    isLoadingRulesData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Rules and protection", target: repo, detail: "Loading rulesets and branch protection…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let repoMeta = Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)"], environment: environment)
      let defaultBranch = Self.extractDefaultBranch(repoMeta.output)
      let protection = defaultBranch.isEmpty ? CommandResult(status: 0, output: "") : Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)/branches/\(defaultBranch)/protection"], environment: environment)
      let rulesets = Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)/rulesets"], environment: environment)

      DispatchQueue.main.async {
        self.isLoadingRulesData = false
        let protectionOutput = protection.output.lowercased()
        let branchIsUnprotected = protection.status != 0 && (
          protectionOutput.contains("branch not protected") ||
          protectionOutput.contains("\"message\":\"not found\"") ||
          protectionOutput.contains("\"message\": \"not found\"")
        )

        self.branchProtectionSummary = (protection.status == 0 || branchIsUnprotected)
          ? Self.parseBranchProtection(branch: defaultBranch, output: protection.output)
          : nil
        self.rulesets = rulesets.status == 0 ? Self.parseRulesets(rulesets.output) : []

        var failures: [String] = []
        if repoMeta.status != 0 { failures.append("repo metadata") }
        if !defaultBranch.isEmpty && protection.status != 0 && !branchIsUnprotected { failures.append("branch protection") }
        if rulesets.status != 0 { failures.append("rulesets") }

        let baseSummary: String
        if defaultBranch.isEmpty {
          baseSummary = "No default branch was reported for \(repo). Rulesets loaded: \(self.rulesets.count)."
        } else if branchIsUnprotected {
          baseSummary = "Loaded rulesets for \(repo). The default branch is not currently protected."
        } else {
          baseSummary = "Loaded branch rules for \(repo)."
        }

        if failures.isEmpty {
          self.rulesStatus = baseSummary
          self.finishJob(id: jobID, state: .succeeded, detail: baseSummary)
        } else {
          let failureSummary = "\(baseSummary)\nPartial load only. Failed: \(failures.joined(separator: ", "))."
          self.rulesStatus = failureSummary
          self.finishJob(id: jobID, state: .failed, detail: failureSummary)
        }
      }
    }
  }

  func loadStorageInsights() {
    let roots = resolvedProfileRoots()
    isLoadingStorageInsights = true
    let jobID = createJob(kind: "Local", title: "Storage insights", target: workspaceStyleLabel, detail: "Scanning storage usage…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let metrics = Self.scanStorageInsights(roots: roots)
      DispatchQueue.main.async {
        self.isLoadingStorageInsights = false
        self.storageInsights = metrics
        self.storageStatus = "Loaded \(metrics.count) storage metrics."
        self.finishJob(id: jobID, state: .succeeded, detail: self.storageStatus)
      }
    }
  }

  func loadProjectSyncStatus() {
    let localProjects = self.localProjects
    let environment = baseEnvironment()
    isLoadingProjectSync = true
    let jobID = createJob(kind: "Local", title: "Project sync status", target: "\(localProjects.count) projects", detail: "Scanning project sync state…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let entries = Self.scanProjectSync(localProjects: localProjects, environment: environment)
      DispatchQueue.main.async {
        self.isLoadingProjectSync = false
        self.projectSyncEntries = entries
        self.syncStatus = "Loaded sync status for \(entries.count) projects."
        self.finishJob(id: jobID, state: .succeeded, detail: self.syncStatus)
      }
    }
  }

  func loadPortMonitor() {
    let environment = baseEnvironment()
    isLoadingPorts = true
    let jobID = createJob(kind: "Local", title: "Port monitor", target: "Local services", detail: "Scanning listening ports…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let entries = Self.scanPorts(environment: environment)
      DispatchQueue.main.async {
        self.isLoadingPorts = false
        self.portMonitorEntries = entries
        self.portsStatus = "Loaded \(entries.count) listening ports."
        self.finishJob(id: jobID, state: .succeeded, detail: self.portsStatus)
      }
    }
  }

  func runImport() {
    guard let cliPath else {
      statusKind = .error
      statusTitle = "CLI Engine Missing"
      statusDetail = "The bundled CSA-iEM CLI engine was not found."
      importStatus = statusDetail
      return
    }

    guard ghPath != nil else {
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first."
      importStatus = statusDetail
      return
    }

    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedTargets = cleanupTargets

    guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      statusKind = .error
      statusTitle = "GitHub Host Required"
      statusDetail = "Select or enter a GitHub host before running imports."
      importStatus = statusDetail
      return
    }

    guard !selectedAccount.isEmpty else {
      statusKind = .warning
      statusTitle = "GitHub Account Required"
      statusDetail = "Login first, then choose which authenticated account should run imports."
      importStatus = statusDetail
      return
    }

    guard !selectedTargets.isEmpty else {
      statusKind = .warning
      statusTitle = "Repository Required"
      statusDetail = "Check one or more repositories or enter a manual repo target before importing."
      importStatus = statusDetail
      return
    }

    pendingRepoTargets = selectedTargets
    completedRepoTargets = []
    failedRepoTargets = []
    activeRepoTarget = ""
    totalRepoTargets = selectedTargets.count
    cancellationRequested = false
    statusKind = .running
    statusTitle = "Running Import"
    statusDetail = "\(selectedAccount) -> \(selectedTargets.count) target(s) in \(workspaceExecutionLabel)"
    importStatus = "Running \(importMode.label.lowercased()) for \(selectedTargets.count) target(s)."
    logText = "[gui] Starting \(importMode.label) across \(selectedTargets.count) target(s) with \(selectedAccount) using the \(workspaceExecutionLabel)\n"

    let jobID = createJob(
      kind: "Import",
      title: importMode.label,
      target: selectedTargets.count == 1 ? selectedTargets[0] : "\(selectedTargets.count) repositories",
      detail: "Preparing import queue…",
      initialState: .running
    )
    activeJobID = jobID
    isRunning = true
    launchImport(for: pendingRepoTargets.removeFirst(), using: cliPath, account: selectedAccount, jobID: jobID)
  }

  private func launchImport(for repoTarget: String, using cliPath: String, account selectedAccount: String, jobID: String) {
    let resolvedHost = repoHostOverride(from: repoTarget) ?? host.trimmingCharacters(in: .whitespacesAndNewlines)
    activeRepoTarget = repoTarget
    let currentIndex = completedRepoTargets.count + failedRepoTargets.count + 1

    statusKind = .running
    statusTitle = "Running Import"
    statusDetail = totalRepoTargets > 1
      ? "\(selectedAccount) -> \(currentIndex)/\(totalRepoTargets): \(repoTarget)"
      : "\(selectedAccount) -> \(repoTarget)"
    importStatus = totalRepoTargets > 1
      ? "Running \(importMode.label.lowercased()) for \(currentIndex) of \(totalRepoTargets): \(repoTarget)"
      : "Running \(importMode.label.lowercased()) for \(repoTarget)"
    updateJob(
      id: jobID,
      state: .running,
      detail: "Importing \(repoTarget)…",
      progressText: "Importing \(currentIndex) of \(totalRepoTargets): \(repoTarget)"
    )
    appendLog("[gui] [\(currentIndex)/\(totalRepoTargets)] Starting \(importMode.label) for \(repoTarget) on \(resolvedHost) with \(selectedAccount)\n")

    var arguments = profileArguments() + [
      "--host", resolvedHost,
      "--account", selectedAccount,
      "--repo", repoTarget,
      "--import-mode", importMode.cliValue,
      "--import-full-auto",
      "--yes",
      "--no-color"
    ]

    if importCleanupPreview {
      arguments.append("--import-cleanup-preview")
    }

    let environment = baseEnvironment()
    let pipe = Pipe()
    let stdinPipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: cliPath)
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = stdinPipe
    runningProcess = process

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard data.isEmpty == false,
            let chunk = String(data: data, encoding: .utf8),
            chunk.isEmpty == false else {
        return
      }

      DispatchQueue.main.async {
        guard let self else { return }
        self.appendLog(chunk)
        self.updateJob(id: jobID, appendLog: chunk)
        self.handleTerminalGate(chunk, stdinPipe: stdinPipe, jobID: jobID)
      }
    }

    process.terminationHandler = { [weak self] terminated in
      let tail = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.readabilityHandler = nil
      let tailText = String(data: tail, encoding: .utf8) ?? ""

      DispatchQueue.main.async {
        guard let self else { return }
        if !tailText.isEmpty {
          self.appendLog(tailText)
          self.updateJob(id: jobID, appendLog: tailText)
        }
        self.runningProcess = nil
        try? stdinPipe.fileHandleForWriting.close()

        if self.cancellationRequested {
          self.finishImportQueue(cancelled: true, jobID: jobID)
          return
        }

        if terminated.terminationStatus == 0 {
          self.completedRepoTargets.append(repoTarget)
        } else {
          self.failedRepoTargets.append(repoTarget)
          self.appendLog("[gui] Import failed for \(repoTarget) with exit code \(terminated.terminationStatus)\n")
        }

        if let nextTarget = self.pendingRepoTargets.first {
          self.pendingRepoTargets.removeFirst()
          self.launchImport(for: nextTarget, using: cliPath, account: selectedAccount, jobID: jobID)
        } else {
          self.finishImportQueue(cancelled: false, jobID: jobID)
        }
      }
    }

    processQueue.async {
      do {
        try process.run()
      } catch {
        DispatchQueue.main.async {
          try? stdinPipe.fileHandleForWriting.close()
          self.failedRepoTargets.append(repoTarget)
          self.appendLog("[gui] Failed to launch import: \(error.localizedDescription)\n")
          self.updateJob(id: jobID, appendLog: "Failed to launch import: \(error.localizedDescription)")
          if let nextTarget = self.pendingRepoTargets.first {
            self.pendingRepoTargets.removeFirst()
            self.launchImport(for: nextTarget, using: cliPath, account: selectedAccount, jobID: jobID)
          } else {
            self.finishImportQueue(cancelled: false, jobID: jobID)
          }
        }
      }
    }
  }

  private func finishImportQueue(cancelled: Bool, jobID: String) {
    isRunning = false
    runningProcess = nil
    activeJobID = nil
    let completedCount = completedRepoTargets.count
    let failedCount = failedRepoTargets.count
    let summary = "Completed \(completedCount) of \(totalRepoTargets). Failed: \(failedCount)."

    if cancelled {
      statusKind = .warning
      statusTitle = "Import Cancelled"
      statusDetail = summary
      importStatus = "Import cancelled. \(summary)"
      appendLog("[gui] Import cancelled by user.\n")
      finishJob(id: jobID, state: .cancelled, detail: "Import cancelled by user.")
    } else if failedCount == 0 {
      statusKind = .ready
      statusTitle = "Import Finished"
      statusDetail = summary
      importStatus = "Import finished successfully. \(summary)"
      finishJob(id: jobID, state: .succeeded, detail: "Import finished. \(summary)")
    } else {
      statusKind = .error
      statusTitle = "Import Finished With Errors"
      statusDetail = summary
      importStatus = "Import finished with errors. \(summary)"
      finishJob(id: jobID, state: .failed, detail: "Import finished with errors. \(summary)")
    }

    pendingRepoTargets.removeAll()
    activeRepoTarget = ""
    totalRepoTargets = 0
    cancellationRequested = false
    refreshLocalProjects()
  }

  func runCleanup() {
    guard let cliPath else {
      statusKind = .error
      statusTitle = "CLI Engine Missing"
      statusDetail = "The bundled CSA-iEM CLI engine was not found."
      return
    }

    guard ghPath != nil else {
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first."
      return
    }

    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedTargets = cleanupTargets

    guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      statusKind = .error
      statusTitle = "GitHub Host Required"
      statusDetail = "Select or enter a GitHub host before running cleanup."
      return
    }

    guard !selectedAccount.isEmpty else {
      statusKind = .warning
      statusTitle = "GitHub Account Required"
      statusDetail = "Login first, then choose which authenticated account should run cleanup."
      return
    }

    guard !selectedTargets.isEmpty else {
      statusKind = .warning
      statusTitle = "Repository Required"
      statusDetail = "Enter a manual repo target or check one or more repositories from the repo browser."
      return
    }

    if !fullCleanup && !(disableWorkflows || deleteRuns || deleteArtifacts || deleteCaches || deleteCodespaces) {
      statusKind = .warning
      statusTitle = "Cleanup Action Required"
      statusDetail = "Choose at least one cleanup action or enable full cleanup."
      return
    }

    guard safetyArmEnabled else {
      statusKind = .warning
      statusTitle = "Safety Lock Enabled"
      statusDetail = "Turn on the permanent delete confirmation switch before running cleanup."
      return
    }

    pendingRepoTargets = selectedTargets
    completedRepoTargets = []
    failedRepoTargets = []
    activeRepoTarget = ""
    totalRepoTargets = selectedTargets.count
    cancellationRequested = false
    statusKind = .running
    statusTitle = dryRun ? "Running Dry Run" : "Running Cleanup"
    statusDetail = "\(selectedAccount) -> \(selectedTargets.count) target(s) in \(workspaceExecutionLabel)"
    logText = "[gui] Starting cleanup across \(selectedTargets.count) target(s) with \(selectedAccount) using the \(workspaceExecutionLabel)\n"
    isRunning = true
    launchCleanup(for: pendingRepoTargets.removeFirst(), using: cliPath, account: selectedAccount)
  }

  private func launchCleanup(for repoTarget: String, using cliPath: String, account selectedAccount: String) {
    let resolvedHost = repoHostOverride(from: repoTarget) ?? host.trimmingCharacters(in: .whitespacesAndNewlines)
    activeRepoTarget = repoTarget
    let currentIndex = completedRepoTargets.count + failedRepoTargets.count + 1

    statusKind = .running
    statusTitle = dryRun ? "Running Dry Run" : "Running Cleanup"
    statusDetail = totalRepoTargets > 1
      ? "\(selectedAccount) -> \(currentIndex)/\(totalRepoTargets): \(repoTarget)"
      : "\(selectedAccount) -> \(repoTarget)"
    appendLog("[gui] [\(currentIndex)/\(totalRepoTargets)] Starting cleanup for \(repoTarget) on \(resolvedHost) with \(selectedAccount)\n")

    var arguments = profileArguments() + [
      "--host", resolvedHost,
      "--account", selectedAccount,
      "--repo", repoTarget,
      "--yes",
      "--no-color"
    ]

    if fullCleanup {
      arguments.append("--all")
    } else {
      if disableWorkflows { arguments.append("--disable-workflows") }
      if deleteRuns { arguments.append("--delete-runs") }
      if deleteArtifacts { arguments.append("--delete-artifacts") }
      if deleteCaches { arguments.append("--delete-caches") }
    }

    if deleteCodespaces {
      arguments.append("--delete-codespaces")
    }

    if !runTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      arguments.append(contentsOf: ["--run", runTarget.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    if !runFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      arguments.append(contentsOf: ["--run-filter", runFilter.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    if dryRun {
      arguments.append("--dry-run")
    }

    let environment = baseEnvironment()
    let pipe = Pipe()
    let stdinPipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: cliPath)
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = stdinPipe
    runningProcess = process

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard data.isEmpty == false,
            let chunk = String(data: data, encoding: .utf8),
            chunk.isEmpty == false else {
        return
      }

      DispatchQueue.main.async {
        guard let self else { return }
        self.appendLog(chunk)
        self.handleTerminalGate(chunk, stdinPipe: stdinPipe, jobID: nil)
      }
    }

    process.terminationHandler = { [weak self] terminated in
      let tail = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.readabilityHandler = nil
      let tailText = String(data: tail, encoding: .utf8) ?? ""

      DispatchQueue.main.async {
        guard let self else { return }
        if !tailText.isEmpty {
          self.appendLog(tailText)
        }
        self.runningProcess = nil
        try? stdinPipe.fileHandleForWriting.close()

        if self.cancellationRequested {
          self.finishCleanupQueue(cancelled: true)
          return
        }

        if terminated.terminationStatus == 0 {
          self.completedRepoTargets.append(repoTarget)
        } else {
          self.failedRepoTargets.append(repoTarget)
          self.appendLog("[gui] Cleanup failed for \(repoTarget) with exit code \(terminated.terminationStatus)\n")
        }

        if let nextTarget = self.pendingRepoTargets.first {
          self.pendingRepoTargets.removeFirst()
          self.launchCleanup(for: nextTarget, using: cliPath, account: selectedAccount)
        } else {
          self.finishCleanupQueue(cancelled: false)
        }
      }
    }

    processQueue.async {
      do {
        try process.run()
      } catch {
        DispatchQueue.main.async {
          try? stdinPipe.fileHandleForWriting.close()
          self.failedRepoTargets.append(repoTarget)
          self.appendLog("[gui] Failed to launch cleanup: \(error.localizedDescription)\n")
          if let nextTarget = self.pendingRepoTargets.first {
            self.pendingRepoTargets.removeFirst()
            self.launchCleanup(for: nextTarget, using: cliPath, account: selectedAccount)
          } else {
            self.finishCleanupQueue(cancelled: false)
          }
        }
      }
    }
  }

  private func finishCleanupQueue(cancelled: Bool) {
    isRunning = false
    runningProcess = nil
    safetyArmEnabled = false
    let completedCount = completedRepoTargets.count
    let failedCount = failedRepoTargets.count
    let summary = "Completed \(completedCount) of \(totalRepoTargets). Failed: \(failedCount)."

    if cancelled {
      statusKind = .warning
      statusTitle = "Cleanup Cancelled"
      statusDetail = summary
      appendLog("[gui] Cleanup cancelled by user.\n")
    } else if failedCount == 0 {
      statusKind = .ready
      statusTitle = dryRun ? "Dry Run Finished" : "Cleanup Finished"
      statusDetail = summary
    } else {
      statusKind = .error
      statusTitle = "Cleanup Finished With Errors"
      statusDetail = summary
    }

    pendingRepoTargets.removeAll()
    activeRepoTarget = ""
    totalRepoTargets = 0
    cancellationRequested = false
    reloadAuthInventory()
  }

  private func handleTerminalGate(_ chunk: String, stdinPipe: Pipe, jobID: String?) {
    guard Self.looksLikeTerminalGate(chunk) else {
      return
    }

    if Self.looksLikeCredentialGate(chunk) {
      let message = "[gui] Security gate detected. This looks like a sudo/password/auth prompt, so CSA-iEM paused for manual approval instead of auto-typing credentials.\n"
      appendLog(message)
      if let jobID {
        updateJob(id: jobID, state: .running, detail: "Waiting for manual security approval.", appendLog: message)
      }
      return
    }

    guard appSettings.autoConfirmTerminalGates else {
      let message = "[gui] Confirmation gate detected. Auto-confirm is off, so answer the terminal prompt manually or enable Auto-confirm terminal gates in Settings.\n"
      appendLog(message)
      if let jobID {
        updateJob(id: jobID, state: .running, detail: "Waiting for manual confirmation.", appendLog: message)
      }
      return
    }

    guard let data = "y\n".data(using: .utf8) else {
      return
    }

    stdinPipe.fileHandleForWriting.write(data)
    let message = "[gui] Auto-confirmed a terminal yes/no gate with y.\n"
    appendLog(message)
    if let jobID {
      updateJob(id: jobID, appendLog: message)
    }
  }

  private func appendLog(_ text: String) {
    logText += redactRuntimeIdentity(text)
  }

  private func redactRuntimeIdentity(_ text: String) -> String {
    var sanitized = redactSensitiveText(text)
    let identities = Set(([account] + availableAccounts).filter { !$0.isEmpty })
    for identity in identities {
      sanitized = sanitized.replacingOccurrences(of: identity, with: "[GITHUB_IDENTITY]")
    }
    return sanitized
  }

  @discardableResult
  private func createJob(kind: String, title: String, target: String = "", detail: String, initialState: BackgroundJobState = .queued) -> String {
    let job = BackgroundJobEntry(
      id: UUID().uuidString,
      kind: kind,
      title: title,
      target: target,
      detail: detail,
      progressText: detail,
      state: initialState,
      createdAt: Date(),
      startedAt: initialState == .running ? Date() : nil,
      finishedAt: nil,
      log: ""
    )
    backgroundJobs.insert(job, at: 0)
    selectedJobID = job.id
    jobCenterStatus = recentJobSummary
    return job.id
  }

  private func updateJob(
    id: String,
    state: BackgroundJobState? = nil,
    detail: String? = nil,
    progressText: String? = nil,
    appendLog logChunk: String? = nil
  ) {
    guard let index = backgroundJobs.firstIndex(where: { $0.id == id }) else { return }
    if let state {
      backgroundJobs[index].state = state
      if state == .running, backgroundJobs[index].startedAt == nil {
        backgroundJobs[index].startedAt = Date()
      }
      if state == .succeeded || state == .failed || state == .cancelled {
        backgroundJobs[index].finishedAt = Date()
      }
    }
    if let detail {
      backgroundJobs[index].detail = detail
    }
    if let progressText {
      backgroundJobs[index].progressText = progressText
    }
    if let logChunk, !logChunk.isEmpty {
      backgroundJobs[index].log += redactRuntimeIdentity(logChunk)
      if backgroundJobs[index].log.hasSuffix("\n") == false {
        backgroundJobs[index].log += "\n"
      }
    }
    jobCenterStatus = recentJobSummary
  }

  private func finishJob(id: String, state: BackgroundJobState, detail: String) {
    updateJob(id: id, state: state, detail: detail, progressText: detail)
    guard state == .failed || state == .cancelled,
          let job = backgroundJobs.first(where: { $0.id == id }) else { return }
    recordIncident(for: job)
  }

  private func recordIncident(for job: BackgroundJobEntry) {
    guard incidents.contains(where: { $0.jobID == job.id }) == false else { return }
    let incident = CSAiEMIncident(
      id: UUID().uuidString,
      createdAt: job.finishedAt ?? Date(),
      kind: job.kind,
      title: job.title,
      target: job.target,
      detail: job.detail,
      jobID: job.id,
      severity: CSAiEMIncidentClassifier.severity(for: job.detail),
      evidence: CSAiEMIncidentClassifier.evidence(for: job, severity: CSAiEMIncidentClassifier.severity(for: job.detail)),
      state: .open,
      resolution: nil
    )
    incidents.insert(incident, at: 0)
    selectedIncidentID = incident.id
    CSAiEMIncidentStore.save(incidents, to: incidentsFile)
    selectedIncidentClusterKey = incidentClusters.first(where: { $0.incidentIDs.contains(incident.id) })?.key
  }

  var openIncidentCount: Int {
    incidents.filter { $0.state == .open }.count
  }

  var incidentClusters: [CSAiEMIncidentCluster] {
    CSAiEMIncidentCluster.group(incidents)
  }

  var selectedIncident: CSAiEMIncident? {
    guard let selectedIncidentID else { return incidents.first }
    return incidents.first(where: { $0.id == selectedIncidentID }) ?? incidents.first
  }

  func selectIncidentCluster(_ cluster: CSAiEMIncidentCluster) {
    selectedIncidentClusterKey = cluster.key
    selectedIncidentID = cluster.incidentIDs.first
  }

  func resolveIncident(_ incident: CSAiEMIncident, note: String = "Resolved from CSA-iEM Jobs and Incidents.") {
    guard let index = incidents.firstIndex(where: { $0.id == incident.id }) else { return }
    incidents[index].state = .resolved
    incidents[index].resolution = note
    CSAiEMIncidentStore.save(incidents, to: incidentsFile)
  }

  func clearResolvedIncidents() {
    incidents.removeAll { $0.state == .resolved }
    if let selectedIncidentID, incidents.contains(where: { $0.id == selectedIncidentID }) == false {
      self.selectedIncidentID = incidents.first?.id
    }
    CSAiEMIncidentStore.save(incidents, to: incidentsFile)
    selectedIncidentClusterKey = incidentClusters.first?.key
  }

  func clearCompletedJobs() {
    backgroundJobs.removeAll { $0.state == .succeeded || $0.state == .failed || $0.state == .cancelled }
    if let selectedJobID,
       backgroundJobs.contains(where: { $0.id == selectedJobID }) == false {
      self.selectedJobID = backgroundJobs.first?.id
    }
    jobCenterStatus = recentJobSummary
  }

  func retryJob(_ job: BackgroundJobEntry) {
    switch (job.kind, job.title) {
    case ("GitHub", "Repo health scan"):
      if selectedRepos.isEmpty {
        loadRepoHealthForVisibleRepos()
      } else {
        loadRepoHealthForSelectedRepos()
      }
    case ("Research", "Repository intelligence snapshot"):
      loadResearchSnapshot()
    case ("GitHub", "Workflow catalog"):
      loadWorkflowCatalog()
    case ("GitHub", "Workflow runs"):
      loadWorkflowRuns()
    case ("GitHub", "Codespaces inventory"):
      loadCodespaces()
    case ("GitHub", "Secrets and variables"):
      loadSecretsAndVariables()
    case ("GitHub", "Update GitHub issue"):
      if let command = issueMutationRetryCommands[job.id] {
        selectedIssueNumber = command.issueNumber
        selectedIssueMutation = command.mutation
        issueMutationBody = command.body
        issueMutationLabels = command.labels.joined(separator: ",")
        issueMutationArmed = false
        issueMutationStatus = "Retry prepared for issue #\(command.issueNumber). Review the retained payload and arm the remote action again."
      } else if let record = issueMutationRetries.first(where: { "\($0.repository)#\($0.command.issueNumber)" == job.target }) {
        prepareIssueMutationRetry(record)
      } else {
        jobCenterStatus = "This GitHub issue retry has no retained reviewed payload. Prepare the action again from the Issues page."
      }
    case ("GitHub", "Rules and protection"):
      loadBranchProtectionAndRulesets()
    case ("Local", "Storage insights"):
      loadStorageInsights()
    case ("Local", "Project sync status"):
      loadProjectSyncStatus()
    case ("Local", "Port monitor"):
      loadPortMonitor()
    case ("Import", _):
      runImport()
    default:
      jobCenterStatus = "Retry is available for catalog, health, workflow, Codespaces, secrets, storage, sync, and port jobs."
    }
  }

  func cancelJob(_ job: BackgroundJobEntry) {
    if activeJobID == job.id {
      cancelRun()
      finishJob(id: job.id, state: .cancelled, detail: "Job cancelled by user.")
    } else {
      jobCenterStatus = "This job cannot be cancelled because it is no longer active."
    }
  }

  private func loadLastSession() -> [String: String] {
    let sessionPath: String

    if FileManager.default.fileExists(atPath: lastSessionFile) {
      sessionPath = lastSessionFile
    } else if FileManager.default.fileExists(atPath: legacyLastSessionFile) {
      sessionPath = legacyLastSessionFile
    } else if FileManager.default.fileExists(atPath: cleanerLastSessionFile) {
      sessionPath = cleanerLastSessionFile
    } else if FileManager.default.fileExists(atPath: legacyCleanerLastSessionFile) {
      sessionPath = legacyCleanerLastSessionFile
    } else {
      return [:]
    }

    guard let contents = try? String(contentsOfFile: sessionPath, encoding: .utf8) else {
      return [:]
    }

    var values: [String: String] = [:]
    for line in contents.split(separator: "\n") {
      let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
      if parts.count == 2 {
        values[parts[0]] = parts[1]
      }
    }
    return values
  }

  private func parseGitHubConfig() -> [AuthHostConfig] {
    let configHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
      ?? (NSString(string: "~/.config").expandingTildeInPath)
    let hostsPath = (configHome as NSString).appendingPathComponent("gh/hosts.yml")

    guard let contents = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
      return []
    }

    var configs: [AuthHostConfig] = []
    var currentHost: String?
    var activeUser: String?
    var users: [String] = []
    var inUsers = false

    func flushCurrent() {
      guard let currentHost else { return }
      let uniqueUsers = Array(NSOrderedSet(array: users)) as? [String] ?? users
      configs.append(AuthHostConfig(host: currentHost, activeUser: activeUser, users: uniqueUsers))
    }

    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = String(rawLine)

      if line.hasPrefix(" ") == false, line.hasSuffix(":") {
        flushCurrent()
        currentHost = String(line.dropLast())
        activeUser = nil
        users = []
        inUsers = false
        continue
      }

      if line.hasPrefix("    user: ") {
        activeUser = String(line.dropFirst("    user: ".count))
        continue
      }

      if line == "    users:" {
        inUsers = true
        continue
      }

      if inUsers, line.hasPrefix("        "), line.hasSuffix(":") {
        var user = String(line.dropFirst(8))
        user.removeLast()
        users.append(user)
        continue
      }

      if line.hasPrefix("    "), line != "    users:" {
        inUsers = false
      }
    }

    flushCurrent()
    return configs
  }

  private func loadProfileConfigValues(profile: LaunchProfile) -> [String: String] {
    let fm = FileManager.default
    let candidates = [
      (profileConfigDir as NSString).appendingPathComponent("\(profile.rawValue).env"),
      (legacyProfileConfigDir as NSString).appendingPathComponent("\(profile.rawValue).env"),
    ]

    guard let configPath = candidates.first(where: { fm.fileExists(atPath: $0) }),
          let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
      return [:]
    }

    var values: [String: String] = [:]
    for line in contents.split(separator: "\n") {
      let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      values[parts[0]] = shellUnescape(parts[1])
    }
    return values
  }

  private func shellUnescape(_ value: String) -> String {
    var result = ""
    var isEscaped = false

    for character in value {
      if isEscaped {
        result.append(character)
        isEscaped = false
      } else if character == "\\" {
        isEscaped = true
      } else {
        result.append(character)
      }
    }

    if isEscaped {
      result.append("\\")
    }

    return result
  }

  private func shellEscapeForConfig(_ value: String) -> String {
    var escaped = ""
    let charactersToEscape = CharacterSet(charactersIn: " \\\"'`$&|;<>*?()[]{}!#")

    for scalar in value.unicodeScalars {
      if charactersToEscape.contains(scalar) {
        escaped.append("\\")
      }
      escaped.append(String(scalar))
    }

    return escaped
  }

  private func normalizeWorkspacePath(_ value: String) -> String {
    NSString(string: value.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
  }

  private func normalizeRepoSlug(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return trimmed
    }

    if let url = URL(string: trimmed),
       let host = url.host,
       !host.isEmpty {
      let pathParts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
      if pathParts.count >= 2 {
        let owner = pathParts[pathParts.count - 2]
        let repo = pathParts.last?.replacingOccurrences(of: ".git", with: "") ?? ""
        return "\(owner)/\(repo)"
      }
    }

    let parts = trimmed.split(separator: "/").map(String.init)
    if parts.count >= 3, parts[0].contains(".") {
      return "\(parts[1])/\(parts[2].replacingOccurrences(of: ".git", with: ""))"
    }
    if parts.count >= 2 {
      return "\(parts[parts.count - 2])/\(parts.last?.replacingOccurrences(of: ".git", with: "") ?? "")"
    }

    return trimmed
  }

  private func writeProfileConfig(profile: LaunchProfile, values: [String: String]) {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: profileConfigDir, withIntermediateDirectories: true)
    let configPath = (profileConfigDir as NSString).appendingPathComponent("\(profile.rawValue).env")
    let contents = values
      .filter { !$0.value.isEmpty }
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\(shellEscapeForConfig($0.value))" }
      .joined(separator: "\n")

    try? (contents + "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
  }

  private func chooseDirectory(startingAt path: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Folder"

    let normalized = normalizeWorkspacePath(path)
    if !normalized.isEmpty {
      panel.directoryURL = URL(fileURLWithPath: normalized, isDirectory: true)
    }

    return panel.runModal() == .OK ? panel.urls.first?.path : nil
  }

  private func applyWorkspaceSuggestion(_ suggestion: WorkspaceSuggestion) {
    writeProfileConfig(
      profile: suggestion.profile,
      values: [
        "SAVED_CODE_ROOT": suggestion.codeRoot,
        "SAVED_IMPORT_ROOT": suggestion.importRoot,
        "SAVED_RUNTIME_ROOT": suggestion.runtimeRoot
      ]
    )
    selectedProfile = suggestion.profile
    useCurrentRoot = true
    syncWorkspaceDraftsFromResolvedRoots()
    refreshLocalProjects()
  }

  private func syncWorkspaceDraftsFromResolvedRoots() {
    let roots = resolvedProfileRoots()
    workspaceSingleRootDraft = roots.runtimeRoot
    workspaceCodeRootDraft = roots.codeRoot
    workspaceImportRootDraft = roots.importRoot
    workspaceRuntimeRootDraft = roots.runtimeRoot
  }

  private func savedWorkspaceConfiguration() -> WorkspaceSuggestion? {
    let publicValues = loadProfileConfigValues(profile: .public)
    let publicSavedCodeRoot = normalizeWorkspacePath(publicValues["SAVED_CODE_ROOT"] ?? "")
    let publicSavedImportRoot = normalizeWorkspacePath(publicValues["SAVED_IMPORT_ROOT"] ?? "")
    let publicSavedRuntimeRoot = normalizeWorkspacePath(publicValues["SAVED_RUNTIME_ROOT"] ?? "")
    if !publicSavedCodeRoot.isEmpty, !publicSavedImportRoot.isEmpty, !publicSavedRuntimeRoot.isEmpty {
      return WorkspaceSuggestion(
        profile: .public,
        style: .split,
        title: "Saved workspace setup",
        detail: "Using the public Code / Import / Runtime workspace you already configured on this Mac.",
        codeRoot: publicSavedCodeRoot,
        importRoot: publicSavedImportRoot,
        runtimeRoot: publicSavedRuntimeRoot
      )
    }

    let savedDefaultRoot = normalizeWorkspacePath(publicValues["SAVED_DEFAULT_ROOT"] ?? "")
    if !savedDefaultRoot.isEmpty {
      return WorkspaceSuggestion(
        profile: .public,
        style: .split,
        title: "Saved workspace setup",
        detail: "Using a legacy default workspace and mapping it into Code / Import / Runtime roots for compatibility.",
        codeRoot: savedDefaultRoot,
        importRoot: (savedDefaultRoot as NSString).appendingPathComponent("Import"),
        runtimeRoot: savedDefaultRoot
      )
    }

    return nil
  }

  private func detectedWorkspaceConfiguration() -> WorkspaceSuggestion? {
    if let saved = savedWorkspaceConfiguration() {
      return saved
    }

    return nil
  }

  private func adoptDetectedWorkspaceIfNeeded() {
    if let saved = savedWorkspaceConfiguration() {
      selectedProfile = saved.profile
      return
    }

    selectedProfile = .public
  }

  private func resolvedProfileRoots() -> (codeRoot: String, importRoot: String, runtimeRoot: String) {
    let values = loadProfileConfigValues(profile: selectedProfile)

    switch selectedProfile {
    case .public:
      let legacyRoot = normalizeWorkspacePath(values["SAVED_DEFAULT_ROOT"] ?? "")
      let fallbackCodeRoot = legacyRoot.isEmpty ? publicDefaultCodeRoot : legacyRoot
      let fallbackImportRoot = legacyRoot.isEmpty ? publicDefaultImportRoot : (legacyRoot as NSString).appendingPathComponent("Import")
      let fallbackRuntimeRoot = legacyRoot.isEmpty ? publicDefaultRuntimeRoot : legacyRoot
      let codeRoot = normalizeWorkspacePath(
        useCurrentRoot ? (values["SAVED_CODE_ROOT"] ?? fallbackCodeRoot) : publicDefaultCodeRoot
      )
      let importRoot = normalizeWorkspacePath(
        useCurrentRoot ? (values["SAVED_IMPORT_ROOT"] ?? fallbackImportRoot) : publicDefaultImportRoot
      )
      let runtimeRoot = normalizeWorkspacePath(
        useCurrentRoot ? (values["SAVED_RUNTIME_ROOT"] ?? fallbackRuntimeRoot) : publicDefaultRuntimeRoot
      )
      return (codeRoot, importRoot, runtimeRoot)
    case .wtl, .diamond:
      return (publicDefaultCodeRoot, publicDefaultImportRoot, publicDefaultRuntimeRoot)
    }
  }

  private nonisolated static func repoDirectories(in reposRoot: String) -> [(owner: String, repo: String, path: String)] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: reposRoot) else {
      return []
    }

    var results: [(String, String, String)] = []
    let owners = (try? fm.contentsOfDirectory(atPath: reposRoot))?.sorted() ?? []

    for owner in owners {
      let ownerPath = (reposRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let repoPath = (ownerPath as NSString).appendingPathComponent(repo)
        var isRepoDir: ObjCBool = false
        guard fm.fileExists(atPath: repoPath, isDirectory: &isRepoDir), isRepoDir.boolValue else {
          continue
        }

        let gitPath = (repoPath as NSString).appendingPathComponent(".git")
        if fm.fileExists(atPath: gitPath) {
          results.append((owner, repo, repoPath))
        }
      }
    }

    return results
  }

  private nonisolated static func discoveredProjectDirectories(in roots: [String]) -> [(owner: String, repo: String, path: String, hasDevcontainer: Bool)] {
    let fm = FileManager.default
    let ignoredNames: Set<String> = [".git", "node_modules", ".build", "Pods", "DerivedData", "Library", "Caches", "tmp"]
    var results: [(owner: String, repo: String, path: String, hasDevcontainer: Bool)] = []
    var seenPaths = Set<String>()

    for root in roots {
      let normalizedRoot = NSString(string: root).standardizingPath
      guard fm.fileExists(atPath: normalizedRoot) else { continue }
      guard let enumerator = fm.enumerator(
        at: URL(fileURLWithPath: normalizedRoot, isDirectory: true),
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      ) else { continue }

      for case let url as URL in enumerator {
        let path = url.path
        let name = url.lastPathComponent
        if ignoredNames.contains(name) || name.hasPrefix(".") {
          enumerator.skipDescendants()
          continue
        }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }

        let gitPath = url.appendingPathComponent(".git").path
        let devcontainerPath = url.appendingPathComponent(".devcontainer/devcontainer.json").path
        let dockerComposePath = url.appendingPathComponent("docker-compose.yml").path
        let composePath = url.appendingPathComponent("compose.yml").path
        guard fm.fileExists(atPath: gitPath) || fm.fileExists(atPath: devcontainerPath) || fm.fileExists(atPath: dockerComposePath) || fm.fileExists(atPath: composePath) else { continue }
        guard seenPaths.insert(NSString(string: path).standardizingPath).inserted else { continue }

        let repo = name
        let owner = url.deletingLastPathComponent().lastPathComponent.isEmpty ? "local" : url.deletingLastPathComponent().lastPathComponent
        results.append((owner, repo, path, fm.fileExists(atPath: devcontainerPath)))
        enumerator.skipDescendants()
      }
    }
    return results
  }

  private nonisolated static func scanLocalProjects(
    workspaceLabel: String,
    codeRoot: String,
    runtimeRoot: String
  ) -> (projects: [LocalProjectEntry], status: String) {
    let fm = FileManager.default
    let codeReposRoot = (codeRoot as NSString).appendingPathComponent("Repos")
    let runtimeReposRoot = (runtimeRoot as NSString).appendingPathComponent("Repos")
    let runnersRoot = (runtimeRoot as NSString).appendingPathComponent("Runners")

    var merged: [String: LocalProjectEntry] = [:]

    for item in repoDirectories(in: codeReposRoot) {
      let slug = "\(item.owner)/\(item.repo)"
      let existing = merged[slug]
      merged[slug] = LocalProjectEntry(
        slug: slug,
        owner: item.owner,
        repo: item.repo,
        codePath: item.path,
        runtimePath: existing?.runtimePath,
        hasDevcontainer: existing?.hasDevcontainer ?? false,
        hasGeneratedStarter: existing?.hasGeneratedStarter ?? false,
        hasRunner: existing?.hasRunner ?? false
      )
    }

    for item in repoDirectories(in: runtimeReposRoot) {
      let slug = "\(item.owner)/\(item.repo)"
      let devcontainerPath = (item.path as NSString).appendingPathComponent(".devcontainer/devcontainer.json")
      let generatedMarker = (item.path as NSString).appendingPathComponent(".devcontainer/.csa-ilem-generated")
      let existing = merged[slug]
      merged[slug] = LocalProjectEntry(
        slug: slug,
        owner: item.owner,
        repo: item.repo,
        codePath: existing?.codePath,
        runtimePath: item.path,
        hasDevcontainer: fm.fileExists(atPath: devcontainerPath),
        hasGeneratedStarter: fm.fileExists(atPath: generatedMarker),
        hasRunner: existing?.hasRunner ?? false
      )
    }

    let runnerOwners = (try? fm.contentsOfDirectory(atPath: runnersRoot))?.sorted() ?? []
    for owner in runnerOwners {
      let ownerPath = (runnersRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let runnerPath = (ownerPath as NSString).appendingPathComponent(repo)
        let runnerConfigPath = (runnerPath as NSString).appendingPathComponent(".runner")
        guard fm.fileExists(atPath: runnerConfigPath) else {
          continue
        }

        let slug = "\(owner)/\(repo)"
        let existing = merged[slug]
        merged[slug] = LocalProjectEntry(
          slug: slug,
          owner: owner,
          repo: repo,
          codePath: existing?.codePath,
          runtimePath: existing?.runtimePath,
          hasDevcontainer: existing?.hasDevcontainer ?? false,
          hasGeneratedStarter: existing?.hasGeneratedStarter ?? false,
          hasRunner: true
        )
      }
    }

    // Keep the CSA layout authoritative, then discover ordinary local checkouts and Docker projects.
    // This covers existing Documents/Sync/backup folders without forcing users to reorganize them.
    if merged.isEmpty {
      let codeParent = (codeRoot as NSString).deletingLastPathComponent
      let runtimeParent = (runtimeRoot as NSString).deletingLastPathComponent
      let documentsRoot = NSString(string: "~/Documents").expandingTildeInPath
      let discoveryRoots = Array(Set([codeParent, runtimeParent, documentsRoot])).filter { !$0.isEmpty }
      for item in discoveredProjectDirectories(in: discoveryRoots) {
        let slug = "\(item.owner)/\(item.repo)"
        merged[slug] = LocalProjectEntry(
          slug: slug,
          owner: item.owner,
          repo: item.repo,
          codePath: item.path,
          runtimePath: nil,
          hasDevcontainer: item.hasDevcontainer,
          hasGeneratedStarter: false,
          hasRunner: false
        )
      }
    }

    let projects = merged.values.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
    let status = projects.isEmpty
      ? "No local Git or Docker projects were found. Check macOS Files and Folders access, then refresh."
      : "Loaded \(projects.count) local projects from the current workspace and nearby sync folders."
    return (projects, status)
  }

  private func repoHostOverride(from target: String) -> String? {
    let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else {
      return nil
    }

    if let url = URL(string: trimmed),
       let host = url.host,
       url.pathComponents.count >= 3 {
      return host
    }

    let components = trimmed.split(separator: "/")
    if components.count == 3 {
      return String(components[0])
    }

    return nil
  }

  private func baseEnvironment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = defaultSearchPaths.joined(separator: ":")
    environment["CSA_IEM_AUTO_CONFIRM_TERMINAL_GATES"] = appSettings.autoConfirmTerminalGates ? "1" : "0"
    environment["CSA_IEM_PAUSE_ON_SECURITY_GATE"] = "1"
    if let cliRootPath {
      environment["CSA_IEM_ROOT"] = cliRootPath
    }
    return environment
  }

  func executablePath(named command: String) -> String? {
    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent(command)
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }
    return nil
  }

  private func launchDetached(executable: String, arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = baseEnvironment()

    do {
      try process.run()
    } catch {
      appendLog("[gui] Failed to launch \(executable): \(error.localizedDescription)\n")
    }
  }

  private func revealPath(_ path: String) {
    let targetURL = URL(fileURLWithPath: path, isDirectory: true)
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else {
      appendLog("[gui] Path was not found: \(path)\n")
      return
    }
    NSWorkspace.shared.activateFileViewerSelecting([targetURL])
  }

  private func openProjectPaths(codePath: String?, runtimePath: String?, fallbackPath: String?, preferRuntime: Bool, label: String, appName: String? = nil) {
    let targetPath = preferRuntime ? (runtimePath ?? codePath ?? fallbackPath) : (codePath ?? runtimePath ?? fallbackPath)
    guard let targetPath else {
      appendLog("[gui] No local path was found for \(label)\n")
      return
    }

    if let appName, !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      openPathInApplication(targetPath, appName: appName, label: label)
      return
    }

    let preferredEditorPath = normalizeWorkspacePath(appSettings.preferredEditorPath)
    if appSettings.preferVSCodeCLI,
       !preferredEditorPath.isEmpty,
       FileManager.default.isExecutableFile(atPath: preferredEditorPath) {
      launchDetached(executable: preferredEditorPath, arguments: [targetPath])
      return
    }

    if appSettings.preferVSCodeCLI, let codePath = executablePath(named: "code") {
      launchDetached(executable: codePath, arguments: [targetPath])
      return
    }

    launchDetached(executable: "/usr/bin/open", arguments: ["-a", "Visual Studio Code", targetPath])
  }

  private func openPathInApplication(_ path: String, appName: String, label: String) {
    guard FileManager.default.fileExists(atPath: path) else {
      appendLog("[gui] Path was not found for \(label): \(path)\n")
      return
    }

    launchDetached(executable: "/usr/bin/open", arguments: ["-a", appName, path])
    appendLog("[gui] Opening \(label) in \(appName): \(path)\n")
  }

  private func copyToClipboard(_ value: String, label: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    appendLog("[gui] Copied \(label) to clipboard.\n")
  }

  func copyResearchSnapshotSummary() {
    guard let snapshot = researchSnapshot else { return }
    copyToClipboard(snapshot.summary, label: "research snapshot summary")
  }

  func copyIncidentDraft(_ incident: CSAiEMIncident) {
    copyToClipboard(CSAiEMIncidentClassifier.redactedIssueDraft(for: incident), label: "incident issue draft")
  }

  func copyIssueDraft() {
    copyToClipboard(issueDraftBody, label: "GitHub issue draft")
  }

  private func openTerminalCommand(_ command: String) {
    let appleScript = """
    tell application "Terminal"
      activate
      do script \(quotedAppleScript(commandLine: "/bin/bash -lc " + shellQuote(command)))
    end tell
    """

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", appleScript]
    process.environment = baseEnvironment()

    do {
      try process.run()
    } catch {
      appendLog("[gui] Failed to open Terminal command: \(error.localizedDescription)\n")
    }
  }

  private nonisolated static func runCommand(
    executable: String,
    arguments: [String],
    environment: [String: String],
    stdin: String? = nil,
    timeout: TimeInterval? = nil
  ) -> CommandResult {
    let process = Process()
    let pipe = Pipe()
    let stdinPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = stdinPipe

    do {
      try process.run()
    } catch {
      return CommandResult(status: 1, output: error.localizedDescription)
    }

    if let stdin {
      if let data = stdin.data(using: .utf8) {
        stdinPipe.fileHandleForWriting.write(data)
      }
    }
    stdinPipe.fileHandleForWriting.closeFile()

    // Drain command output while the process is running. Waiting first can
    // deadlock rsync and other verbose tools when their pipe buffer fills.
    let outputLock = NSLock()
    var capturedData = Data()
    let outputReader = DispatchWorkItem {
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      outputLock.lock()
      capturedData = data
      outputLock.unlock()
    }
    DispatchQueue.global(qos: .utility).async(execute: outputReader)
    var timedOut = false
    if let timeout {
      let deadline = Date().addingTimeInterval(max(1, timeout))
      while process.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.1)
      }
      if process.isRunning {
        timedOut = true
        process.terminate()
        let terminationDeadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < terminationDeadline {
          Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning {
          kill(process.processIdentifier, SIGKILL)
        }
      }
    }
    process.waitUntilExit()
    outputReader.wait()
    outputLock.lock()
    let data = capturedData
    outputLock.unlock()
    var output = String(data: data, encoding: .utf8) ?? ""
    if timedOut {
      output += output.hasSuffix("\n") || output.isEmpty ? "Command timed out.\n" : "\nCommand timed out.\n"
    }
    return CommandResult(status: timedOut ? 124 : process.terminationStatus, output: output)
  }

  private nonisolated static func looksLikeTerminalGate(_ output: String) -> Bool {
    let lower = output.lowercased()
    if looksLikeCredentialGate(lower) {
      return true
    }

    let confirmationMarkers = [
      "(y/n)",
      "[y/n]",
      "[y/n]:",
      "[y/n]?",
      "[y/n] ",
      "[y/n]:",
      "[y/n]",
      "[yes/no]",
      "yes/no",
      "proceed?",
      "continue?",
      "do you want to continue",
      "are you sure",
      "type y",
      "press y"
    ]
    return confirmationMarkers.contains { lower.contains($0) }
  }

  private nonisolated static func looksLikeCredentialGate(_ output: String) -> Bool {
    let lower = output.lowercased()
    let credentialMarkers = [
      "password:",
      "passphrase",
      "sudo",
      "authentication required",
      "administrator password",
      "touch id",
      "authorization required",
      "keychain",
      "enter pin"
    ]
    return credentialMarkers.contains { lower.contains($0) }
  }

  private nonisolated static func decodeJSONArray<T: Decodable>(_ type: T.Type, from output: String) -> T? {
    guard let data = output.data(using: .utf8) else {
      return nil
    }
    return try? JSONDecoder().decode(type, from: data)
  }

  private nonisolated static func researchAvailabilityLabel(_ result: CommandResult) -> String {
    if result.status == 0 { return "available" }
    let outcome = CSAiEMGitHubProviderOutcome.classify(status: Int(result.status), output: result.output)
    switch outcome {
    case .permissionDenied: return "permission denied"
    case .authenticationRequired: return "authentication required"
    case .notFound: return "not enabled or unavailable"
    case .timeout: return "timeout"
    case .failed: return "unavailable"
    }
  }

  private nonisolated static func extractDefaultBranch(_ output: String) -> String {
    guard let data = output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return ""
    }
    return (object["default_branch"] as? String) ?? ""
  }

  private nonisolated static func parseBranchProtection(branch: String, output: String) -> BranchProtectionSummary? {
    guard !branch.isEmpty,
          let data = output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          object["message"] == nil else {
      return nil
    }

    let requiredStatusChecks = ((object["required_status_checks"] as? [String: Any])?["contexts"] as? [Any])?.count ?? 0
    let requiredReviews = object["required_pull_request_reviews"] != nil
    let enforceAdmins = ((object["enforce_admins"] as? [String: Any])?["enabled"] as? Bool) ?? false
    return BranchProtectionSummary(
      branch: branch,
      requiredStatusChecks: requiredStatusChecks,
      requiredPullRequestReviews: requiredReviews,
      enforceAdmins: enforceAdmins
    )
  }

  private nonisolated static func parseRulesets(_ output: String) -> [RulesetRecord] {
    guard let data = output.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }

    return array.compactMap { item in
      let idValue = item["id"].map { String(describing: $0) } ?? UUID().uuidString
      let name = (item["name"] as? String) ?? "Unnamed Ruleset"
      let target = (item["target"] as? String) ?? "unknown"
      let enforcement = (item["enforcement"] as? String) ?? "unknown"
      let source = (item["source_type"] as? String) ?? (item["source"] as? String) ?? "repo"
      return RulesetRecord(id: idValue, name: name, target: target, enforcement: enforcement, source: source)
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private nonisolated static func parseCodespaces(_ output: String) -> [CodespaceInventoryEntry] {
    guard let data = output.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }

    return array.compactMap { item in
      let name = (item["name"] as? String) ?? ""
      guard !name.isEmpty else { return nil }
      let displayName = (item["displayName"] as? String) ?? name
      let state = (item["state"] as? String) ?? "unknown"
      let machineName = (item["machineName"] as? String) ?? "unknown"
      let lastUsedAt = (item["lastUsedAt"] as? String) ?? "unknown"
      let repository = item["repository"] as? [String: Any]
      let repo = (repository?["fullName"] as? String)
        ?? (repository?["nameWithOwner"] as? String)
        ?? {
          let owner = (repository?["owner"] as? [String: Any])?["login"] as? String
          let repoName = repository?["name"] as? String
          if let owner, let repoName {
            return "\(owner)/\(repoName)"
          }
          return ""
        }()
      return CodespaceInventoryEntry(
        name: name,
        displayName: displayName,
        repo: repo,
        state: state,
        machineName: machineName,
        lastUsedAt: lastUsedAt
      )
    }
    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }

  private nonisolated static func directorySizeKilobytes(at path: String) -> Int64 {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else {
      return 0
    }

    if let attrs = try? fm.attributesOfItem(atPath: path),
       let type = attrs[.type] as? FileAttributeType,
       type != .typeDirectory,
       let size = attrs[.size] as? NSNumber {
      return Int64(size.int64Value / 1024)
    }

    var totalBytes: Int64 = 0
    if let enumerator = fm.enumerator(atPath: path) {
      for case let item as String in enumerator {
        let childPath = (path as NSString).appendingPathComponent(item)
        if let attrs = try? fm.attributesOfItem(atPath: childPath),
           let type = attrs[.type] as? FileAttributeType,
           type != .typeDirectory,
           let size = attrs[.size] as? NSNumber {
          totalBytes += size.int64Value
        }
      }
    }
    return totalBytes / 1024
  }

  private nonisolated static func formatKilobytes(_ kilobytes: Int64) -> String {
    let value = Double(kilobytes)
    if value >= 1024 * 1024 {
      return String(format: "%.1f GB", value / (1024 * 1024))
    }
    if value >= 1024 {
      return String(format: "%.1f MB", value / 1024)
    }
    return "\(max(0, kilobytes)) KB"
  }

  private nonisolated static func buildWorkspaceMovePreview(
    scope: WorkspaceRelocationScope,
    style: WorkspaceStyle,
    codeRoot: String,
    importRoot: String,
    runtimeRoot: String,
    destinationBase: String
  ) -> LocalOperationPreview {
    let normalizedDestination = NSString(string: destinationBase).standardizingPath
    var targets: [(source: String, destination: String)] = []

    switch style {
    case .single:
      targets = [(runtimeRoot, (normalizedDestination as NSString).appendingPathComponent("Workspace"))]
    case .split:
      switch scope {
      case .workspace:
        targets = [
          (codeRoot, (normalizedDestination as NSString).appendingPathComponent("Code")),
          (importRoot, (normalizedDestination as NSString).appendingPathComponent("Import")),
          (runtimeRoot, (normalizedDestination as NSString).appendingPathComponent("Runtime"))
        ]
      case .codeRoot:
        targets = [(codeRoot, (normalizedDestination as NSString).appendingPathComponent("Code"))]
      case .runtimeRoot:
        targets = [(runtimeRoot, (normalizedDestination as NSString).appendingPathComponent("Runtime"))]
      }
    }

    let totalSize = targets.reduce(Int64(0)) { $0 + directorySizeKilobytes(at: $1.source) }
    let collisions = targets
      .map(\.destination)
      .filter { FileManager.default.fileExists(atPath: $0) }

    return LocalOperationPreview(
      kind: .workspaceMove,
      title: "\(scope.label) Preview",
      destinationPath: normalizedDestination,
      itemCount: targets.count,
      totalSizeLabel: formatKilobytes(totalSize),
      collisions: collisions,
      preparedStamp: nil
    )
  }

  private nonisolated static func buildLocalExportPreview(
    scope: LocalFileExportScope,
    mode: LocalFileTransferMode,
    destinationBase: String,
    preparedStamp: String,
    roots: (codeRoot: String, importRoot: String, runtimeRoot: String),
    selectedProjects: [LocalProjectEntry],
    includeCode: Bool,
    includeRuntime: Bool,
    includeRunners: Bool
  ) -> LocalOperationPreview {
    let destinationRoot = localExportRoot(destinationBase: destinationBase, stamp: preparedStamp)
    let operations = (try? plannedLocalExportOperations(
      scope: scope,
      destinationRoot: destinationRoot,
      roots: roots,
      selectedProjects: selectedProjects,
      includeCode: includeCode,
      includeRuntime: includeRuntime,
      includeRunners: includeRunners
    )) ?? []
    let totalSize = operations.reduce(Int64(0)) { $0 + directorySizeKilobytes(at: $1.source) }
    let collisions = operations
      .map(\.destination)
      .filter { FileManager.default.fileExists(atPath: $0) }

    return LocalOperationPreview(
      kind: .localExport,
      title: "\(mode.label) Preview",
      destinationPath: destinationRoot,
      itemCount: operations.count,
      totalSizeLabel: formatKilobytes(totalSize),
      collisions: collisions.isEmpty && FileManager.default.fileExists(atPath: destinationRoot) ? [destinationRoot] : collisions,
      preparedStamp: preparedStamp
    )
  }

  private nonisolated static func mergeOwnerRepoTree(from sourceRoot: String, to destinationRoot: String, environment: [String: String]) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: sourceRoot) else {
      return
    }

    let owners = (try? fm.contentsOfDirectory(atPath: sourceRoot))?.sorted() ?? []
    for owner in owners {
      let ownerPath = (sourceRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let repoPath = (ownerPath as NSString).appendingPathComponent(repo)
        let target = (destinationRoot as NSString).appendingPathComponent("\(owner)/\(repo)")
        try transferItem(from: repoPath, to: target, mode: .copyBackup, overwrite: true, environment: environment)
      }
    }
  }

  nonisolated static func restoreSnapshotPayload(
    payloadPath: String,
    roots: (codeRoot: String, importRoot: String, runtimeRoot: String),
    environment: [String: String]
  ) throws {
    let fm = FileManager.default
    let transactionRoot = fm.temporaryDirectory.appendingPathComponent("csa-iem-restore-\(UUID().uuidString)").path
    let candidateRoots = [roots.codeRoot, roots.importRoot, roots.runtimeRoot].map { NSString(string: $0).standardizingPath }
    var targets: [String] = []
    var seenTargets: Set<String> = []
    for target in candidateRoots where seenTargets.insert(target).inserted {
      targets.append(target)
    }
    var backups: [(target: String, backup: String)] = []
    try fm.createDirectory(atPath: transactionRoot, withIntermediateDirectories: true, attributes: nil)

    do {
      for (index, target) in targets.enumerated() where fm.fileExists(atPath: target) {
        let backup = (transactionRoot as NSString).appendingPathComponent("root-\(index)")
        try transferItem(from: target, to: backup, mode: .copyBackup, overwrite: false, environment: environment)
        backups.append((target: target, backup: backup))
      }

      try restoreSnapshotPayloadMerge(
        payloadPath: payloadPath,
        roots: roots,
        environment: environment
      )

      if environment["CSA_IEM_TEST_FAIL_DURING_SNAPSHOT_RESTORE"] == "1" {
        throw NSError(domain: appTitle, code: 97, userInfo: [NSLocalizedDescriptionKey: "Injected snapshot restore failure for rollback verification."])
      }
      try? fm.removeItem(atPath: transactionRoot)
    } catch {
      for target in targets where fm.fileExists(atPath: target) {
        try? fm.removeItem(atPath: target)
      }
      for backup in backups {
        if fm.fileExists(atPath: backup.backup) {
          try? transferItem(from: backup.backup, to: backup.target, mode: .copyBackup, overwrite: true, environment: environment)
        }
      }
      try? fm.removeItem(atPath: transactionRoot)
      throw error
    }
  }

  private nonisolated static func restoreSnapshotPayloadMerge(
    payloadPath: String,
    roots: (codeRoot: String, importRoot: String, runtimeRoot: String),
    environment: [String: String]
  ) throws {
    let fm = FileManager.default
    var restoreRoot = payloadPath

    let directCode = (restoreRoot as NSString).appendingPathComponent("Code")
    let directImport = (restoreRoot as NSString).appendingPathComponent("Import")
    let directRuntime = (restoreRoot as NSString).appendingPathComponent("Runtime")
    if !fm.fileExists(atPath: directCode), !fm.fileExists(atPath: directImport), !fm.fileExists(atPath: directRuntime) {
      let children = (try? fm.contentsOfDirectory(atPath: restoreRoot))?.sorted() ?? []
      if let nested = children
        .map({ (restoreRoot as NSString).appendingPathComponent($0) })
        .first(where: {
          fm.fileExists(atPath: ($0 as NSString).appendingPathComponent("Code")) ||
          fm.fileExists(atPath: ($0 as NSString).appendingPathComponent("Import")) ||
          fm.fileExists(atPath: ($0 as NSString).appendingPathComponent("Runtime"))
        }) {
        restoreRoot = nested
      }
    }

    let codeExport = (restoreRoot as NSString).appendingPathComponent("Code")
    if fm.fileExists(atPath: codeExport) {
      let reposExport = (codeExport as NSString).appendingPathComponent("Repos")
      if fm.fileExists(atPath: reposExport) {
        try mergeOwnerRepoTree(
          from: reposExport,
          to: (roots.codeRoot as NSString).appendingPathComponent("Repos"),
          environment: environment
        )
      } else {
        try transferItem(from: codeExport, to: roots.codeRoot, mode: .copyBackup, overwrite: true, environment: environment)
      }
    }

    let importExport = (restoreRoot as NSString).appendingPathComponent("Import")
    if fm.fileExists(atPath: importExport) {
      let reposExport = (importExport as NSString).appendingPathComponent("Repos")
      if fm.fileExists(atPath: reposExport) {
        try mergeOwnerRepoTree(
          from: reposExport,
          to: (roots.importRoot as NSString).appendingPathComponent("Repos"),
          environment: environment
        )
      } else {
        try transferItem(from: importExport, to: roots.importRoot, mode: .copyBackup, overwrite: true, environment: environment)
      }
    }

    let runtimeExport = (restoreRoot as NSString).appendingPathComponent("Runtime")
    if fm.fileExists(atPath: runtimeExport) {
      let reposExport = (runtimeExport as NSString).appendingPathComponent("Repos")
      let runnersExport = (runtimeExport as NSString).appendingPathComponent("Runners")

      if fm.fileExists(atPath: reposExport) {
        try mergeOwnerRepoTree(
          from: reposExport,
          to: (roots.runtimeRoot as NSString).appendingPathComponent("Repos"),
          environment: environment
        )
      } else {
        try transferItem(from: runtimeExport, to: roots.runtimeRoot, mode: .copyBackup, overwrite: true, environment: environment)
      }

      if fm.fileExists(atPath: runnersExport) {
        try mergeOwnerRepoTree(
          from: runnersExport,
          to: (roots.runtimeRoot as NSString).appendingPathComponent("Runners"),
          environment: environment
        )
      }
    }
  }

  private nonisolated static func jsonObject(_ text: String) -> [String: Any]? {
    guard let data = text.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let dictionary = object as? [String: Any] else {
      return nil
    }
    return dictionary
  }

  private nonisolated static func billingNumber(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? String { return Double(value) }
    return nil
  }

  private nonisolated static func makeGitHubBillingSummary(
    owner: String,
    actions: [String: Any]?,
    sharedStorage: [String: Any]?,
    packages: [String: Any]?,
    unavailableReports: [String]
  ) -> GitHubBillingSummary {
    let breakdown = (actions?["minutes_used_breakdown"] as? [String: Any] ?? [:])
      .compactMap { key, value in billingNumber(value).map { GitHubBillingBreakdownEntry(platform: key, minutes: $0) } }
      .sorted { $0.platform.localizedCaseInsensitiveCompare($1.platform) == .orderedAscending }
    return GitHubBillingSummary(
      owner: owner,
      actionsMinutes: billingNumber(actions?["total_minutes_used"]),
      paidActionsMinutes: billingNumber(actions?["total_paid_minutes_used"]),
      includedActionsMinutes: billingNumber(actions?["included_minutes_used"]),
      storageGBDays: billingNumber(sharedStorage?["total_gigabytes_used"]),
      packageGBDays: billingNumber(packages?["total_gigabytes_used"]),
      actionBreakdown: breakdown,
      unavailableReports: unavailableReports
    )
  }

  private nonisolated static func scanRepoHealth(
    slug: String,
    ghPath: String,
    localProjects: [LocalProjectEntry],
    environment: [String: String]
  ) -> RepoHealthEntry {
    let workflows = decodeJSONArray([WorkflowCatalogEntry].self, from: runCommand(
      executable: ghPath,
      arguments: ["workflow", "list", "--all", "--json", "id,name,path,state", "-R", slug],
      environment: environment
    ).output) ?? []

    let runs = decodeJSONArray([WorkflowRunEntry].self, from: runCommand(
      executable: ghPath,
      arguments: ["run", "list", "--all", "--limit", "20", "--json", "databaseId,name,workflowName,status,conclusion,createdAt", "-R", slug],
      environment: environment
    ).output) ?? []

    let codespaces = parseCodespaces(runCommand(
      executable: ghPath,
      arguments: ["codespace", "list", "--repo", slug, "--json", "name,state,repository"],
      environment: environment
    ).output)

    let localProject = localProjects.first(where: { $0.slug == slug })
    var githubHostedIndicators = 0
    if let workflowRootBase = localProject?.codePath ?? localProject?.runtimePath {
      let workflowRoot = (workflowRootBase as NSString).appendingPathComponent(".github/workflows")
      if let enumerator = FileManager.default.enumerator(atPath: workflowRoot) {
        for case let relative as String in enumerator where relative.hasSuffix(".yml") || relative.hasSuffix(".yaml") {
          let path = (workflowRoot as NSString).appendingPathComponent(relative)
          if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
            let lowered = contents.lowercased()
            let matches = [
              "ubuntu-latest",
              "windows-latest",
              "macos-latest",
              "ubuntu-",
              "windows-",
              "macos-"
            ]
            if matches.contains(where: { lowered.contains($0) }) {
              githubHostedIndicators += 1
            }
          }
        }
      }
    }

    let workflowsEnabled = workflows.filter { $0.state.lowercased() == "active" }.count
    let recentRuns = runs.count
    let activeCodespaces = codespaces.filter { !$0.state.lowercased().contains("shutdown") && !$0.state.lowercased().contains("stopped") }.count
    let hasLocalRunner = localProject?.hasRunner ?? false

    var riskScore = 0
    if githubHostedIndicators > 0 { riskScore += 25 }
    if workflowsEnabled > 0 && !hasLocalRunner { riskScore += 20 }
    if activeCodespaces > 0 { riskScore += 15 }
    if recentRuns > 10 { riskScore += 10 }
    if workflowsEnabled > 0 && githubHostedIndicators > 0 { riskScore += 20 }
    riskScore = min(100, riskScore)

    let riskLabel: String
    switch riskScore {
    case ..<25: riskLabel = "Low"
    case ..<50: riskLabel = "Moderate"
    case ..<75: riskLabel = "High"
    default: riskLabel = "Critical"
    }

    let summary = "\(workflowsEnabled)/\(workflows.count) workflows enabled · \(recentRuns) recent runs · \(activeCodespaces) active Codespaces · \(hasLocalRunner ? "local runner ready" : "no local runner")"
    return RepoHealthEntry(
      slug: slug,
      workflowsTotal: workflows.count,
      workflowsEnabled: workflowsEnabled,
      recentRuns: recentRuns,
      activeCodespaces: activeCodespaces,
      hasLocalRunner: hasLocalRunner,
      githubHostedIndicators: githubHostedIndicators,
      riskScore: riskScore,
      riskLabel: riskLabel,
      summary: summary
    )
  }

  private nonisolated static func scanStorageInsights(
    roots: (codeRoot: String, importRoot: String, runtimeRoot: String)
  ) -> [StorageInsightEntry] {
    let candidates: [(String, String)] = [
      ("Code Root", roots.codeRoot),
      ("Import Root", roots.importRoot),
      ("Runtime Root", roots.runtimeRoot),
      ("Reports", (roots.runtimeRoot as NSString).appendingPathComponent("Reports")),
      ("Runners", (roots.runtimeRoot as NSString).appendingPathComponent("Runners")),
      ("Snapshots", snapshotsDirectory),
      ("Docker App Data", NSString(string: "~/Library/Containers/com.docker.docker").expandingTildeInPath)
    ]

    return candidates.compactMap { label, path in
      guard FileManager.default.fileExists(atPath: path) else { return nil }
      let sizeKB = directorySizeKilobytes(at: path)
      return StorageInsightEntry(
        id: label.lowercased().replacingOccurrences(of: " ", with: "-"),
        label: label,
        path: path,
        sizeLabel: formatKilobytes(sizeKB)
      )
    }
  }

  private nonisolated static func gitState(for path: String, environment: [String: String]) -> (dirty: Bool, ahead: Int, behind: Int) {
    guard let gitPath = resolveExecutablePath(named: "git"),
          FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent(".git")) else {
      return (false, 0, 0)
    }

    let status = runCommand(executable: gitPath, arguments: ["-C", path, "status", "--porcelain"], environment: environment)
    let dirty = !status.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    let counts = runCommand(executable: gitPath, arguments: ["-C", path, "rev-list", "--left-right", "--count", "@{upstream}...HEAD"], environment: environment)
    let tokens = counts.output.split(whereSeparator: \.isWhitespace).map(String.init)
    let behind = tokens.count >= 1 ? Int(tokens[0]) ?? 0 : 0
    let ahead = tokens.count >= 2 ? Int(tokens[1]) ?? 0 : 0
    return (dirty, ahead, behind)
  }

  private nonisolated static func scanProjectSync(
    localProjects: [LocalProjectEntry],
    environment: [String: String]
  ) -> [ProjectSyncEntry] {
    localProjects.map { project in
      let codeState = project.codePath.map { gitState(for: $0, environment: environment) } ?? (dirty: false, ahead: 0, behind: 0)
      let runtimeState: (dirty: Bool, ahead: Int, behind: Int)
      if let runtimePath = project.runtimePath, runtimePath != project.codePath {
        runtimeState = gitState(for: runtimePath, environment: environment)
      } else {
        runtimeState = codeState
      }

      let summary = [
        "Code \(codeState.dirty ? "dirty" : "clean") \(codeState.ahead)/\(codeState.behind)",
        "Runtime \(runtimeState.dirty ? "dirty" : "clean") \(runtimeState.ahead)/\(runtimeState.behind)"
      ].joined(separator: " · ")

      return ProjectSyncEntry(
        slug: project.slug,
        codeDirty: codeState.dirty,
        runtimeDirty: runtimeState.dirty,
        codeAhead: codeState.ahead,
        codeBehind: codeState.behind,
        runtimeAhead: runtimeState.ahead,
        runtimeBehind: runtimeState.behind,
        summary: summary
      )
    }
    .sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
  }

  private nonisolated static func scanPorts(environment: [String: String]) -> [PortMonitorEntry] {
    guard let lsofPath = resolveExecutablePath(named: "lsof") else {
      return []
    }

    let result = runCommand(executable: lsofPath, arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"], environment: environment)
    guard result.status == 0 else {
      return []
    }

    return result.output
      .split(whereSeparator: \.isNewline)
      .dropFirst()
      .compactMap { line -> PortMonitorEntry? in
        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 9 else { return nil }
        let processName = parts[0]
        let pid = parts[1]
        let proto = parts[7]
        let nameField = parts.last ?? ""
        let port = nameField
          .split(separator: ":")
          .last
          .map(String.init)?
          .split(separator: " ")
          .first
          .map(String.init) ?? nameField
        return PortMonitorEntry(
          id: "\(pid)-\(port)-\(processName)",
          proto: proto,
          port: port,
          pid: pid,
          processName: processName
        )
      }
      .sorted {
        if $0.port == $1.port {
          return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
        }
        return ($0.port as NSString).integerValue < ($1.port as NSString).integerValue
      }
  }

  private nonisolated static func scanLiveServices(
    localProjects: [LocalProjectEntry],
    runtimeRoot: String,
    includeDocker: Bool,
    environment: [String: String]
  ) -> (containers: [LiveContainerEntry], runners: [RunnerServiceEntry], status: String) {
    let fm = FileManager.default
    var projectsByPath: [String: LocalProjectEntry] = [:]
    for project in localProjects {
      if let codePath = project.codePath {
        projectsByPath[NSString(string: codePath).standardizingPath] = project
      }
      if let runtimePath = project.runtimePath {
        projectsByPath[NSString(string: runtimePath).standardizingPath] = project
      }
    }

    var containers: [LiveContainerEntry] = []
    if includeDocker, let dockerPath = resolveExecutablePath(named: "docker") {
      let idsResult = runCommand(executable: dockerPath, arguments: ["ps", "-q"], environment: environment)
      if idsResult.status == 0 {
        let containerIDs = idsResult.output.split(whereSeparator: \.isNewline).map(String.init)
        for containerID in containerIDs {
          let inspectResult = runCommand(
            executable: dockerPath,
            arguments: [
              "inspect",
              "--format",
              "{{ index .Config.Labels \"devcontainer.local_folder\" }}|{{ .Name }}|{{ .Config.Image }}|{{ .State.Status }}",
              containerID
            ],
            environment: environment
          )
          guard inspectResult.status == 0 else {
            continue
          }

          let parts = inspectResult.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map(String.init)
          guard parts.count >= 4 else {
            continue
          }

          let workspacePath = NSString(string: parts[0]).standardizingPath
          guard !workspacePath.isEmpty else {
            continue
          }

          let project = projectsByPath[workspacePath]
          let name = parts[1].hasPrefix("/") ? String(parts[1].dropFirst()) : parts[1]
          let repo = project?.repo ?? ((workspacePath as NSString).lastPathComponent)
          let slug = project?.slug ?? repo

          containers.append(
            LiveContainerEntry(
              containerID: containerID,
              name: name,
              image: parts[2],
              status: parts[3],
              workspacePath: workspacePath,
              slug: slug,
              repo: repo,
              codePath: project?.codePath,
              runtimePath: project?.runtimePath
            )
          )
        }
      }
    }

    var activeLabels: Set<String> = []
    if let launchctlPath = resolveExecutablePath(named: "launchctl") {
      let launchctlResult = runCommand(executable: launchctlPath, arguments: ["list"], environment: environment)
      if launchctlResult.status == 0 {
        for line in launchctlResult.output.split(whereSeparator: \.isNewline).dropFirst() {
          let columns = line.split(whereSeparator: \.isWhitespace)
          if let label = columns.last {
            activeLabels.insert(String(label))
          }
        }
      }
    }

    var runners: [RunnerServiceEntry] = []
    let runnersRoot = (runtimeRoot as NSString).appendingPathComponent("Runners")
    let owners = (try? fm.contentsOfDirectory(atPath: runnersRoot))?.sorted() ?? []
    for owner in owners {
      let ownerPath = (runnersRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let runnerPath = (ownerPath as NSString).appendingPathComponent(repo)
        let runnerConfigPath = (runnerPath as NSString).appendingPathComponent(".runner")
        guard fm.fileExists(atPath: runnerConfigPath) else {
          continue
        }

        let slug = "\(owner)/\(repo)"
        let project = localProjects.first(where: { $0.slug == slug })
        let serviceFilePath = (runnerPath as NSString).appendingPathComponent(".service")
        let rawServicePlistPath = try? String(contentsOfFile: serviceFilePath, encoding: .utf8)
        let servicePlistPath = rawServicePlistPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let serviceLabel: String
        if let servicePlistPath, !servicePlistPath.isEmpty {
          serviceLabel = URL(fileURLWithPath: servicePlistPath).deletingPathExtension().lastPathComponent
        } else {
          serviceLabel = repo
        }

        runners.append(
          RunnerServiceEntry(
            slug: slug,
            repo: repo,
            runnerPath: runnerPath,
            serviceLabel: serviceLabel,
            servicePlistPath: servicePlistPath,
            isRunning: activeLabels.contains(serviceLabel),
            codePath: project?.codePath,
            runtimePath: project?.runtimePath
          )
        )
      }
    }

    let sortedContainers = containers.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
    let sortedRunners = runners.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
    let status = "\(sortedContainers.count) active devcontainers and \(sortedRunners.count) runner services detected for the current workspace."
    return (sortedContainers, sortedRunners, status)
  }

  private nonisolated static func resolveExecutablePath(named command: String) -> String? {
    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent(command)
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }
    return nil
  }

  private nonisolated static func scanLegacyWorkspaceCandidates(excluding currentRoots: Set<String>) -> [LegacyWorkspaceCandidate] {
    let fm = FileManager.default
    let home = NSString(string: "~").expandingTildeInPath
    let configBase = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
      ?? NSString(string: "~/.config").expandingTildeInPath

    var roots: [(label: String, code: String, importRoot: String, runtime: String)] = [
      (
        "Old Diamond external workspace",
        "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-X/GH",
        "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH/Import",
        "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH"
      ),
      (
        "Old WTL external workspace",
        "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH",
        "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH/Import",
        "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH"
      ),
      (
        "Legacy CSA-iLEM workspace",
        (home as NSString).appendingPathComponent("CSA-iLEM"),
        (home as NSString).appendingPathComponent("CSA-iLEM/Import"),
        (home as NSString).appendingPathComponent("CSA-iLEM")
      )
    ]

    for profile in ["diamond", "wtl", "public", "default", "custom"] {
      for base in [profileConfigDir, legacyProfileConfigDir, (configBase as NSString).appendingPathComponent("csa-iem"), (configBase as NSString).appendingPathComponent("csa-ilem")] {
        let configPath = (base as NSString).appendingPathComponent("\(profile).env")
        let values = readEnvFile(configPath)
        let defaultRoot = normalizedPath(values["SAVED_DEFAULT_ROOT"] ?? "")
        let codeRoot = normalizedPath(values["SAVED_CODE_ROOT"] ?? defaultRoot)
        let importRoot = normalizedPath(values["SAVED_IMPORT_ROOT"] ?? (defaultRoot.isEmpty ? "" : (defaultRoot as NSString).appendingPathComponent("Import")))
        let runtimeRoot = normalizedPath(values["SAVED_RUNTIME_ROOT"] ?? defaultRoot)
        if !codeRoot.isEmpty || !runtimeRoot.isEmpty {
          roots.append((
            "Saved old \(profile) workspace",
            codeRoot.isEmpty ? runtimeRoot : codeRoot,
            importRoot.isEmpty ? ((runtimeRoot.isEmpty ? codeRoot : runtimeRoot) as NSString).appendingPathComponent("Import") : importRoot,
            runtimeRoot.isEmpty ? codeRoot : runtimeRoot
          ))
        }
      }
    }

    var seen: Set<String> = []
    var candidates: [LegacyWorkspaceCandidate] = []

    for root in roots {
      let codeRoot = normalizedPath(root.code)
      let importRoot = normalizedPath(root.importRoot)
      let runtimeRoot = normalizedPath(root.runtime)
      let key = "\(codeRoot)|\(importRoot)|\(runtimeRoot)"
      guard seen.insert(key).inserted else { continue }
      guard !currentRoots.contains(codeRoot) || !currentRoots.contains(runtimeRoot) else { continue }

      let codeRepos = (codeRoot as NSString).appendingPathComponent("Repos")
      let runtimeRepos = (runtimeRoot as NSString).appendingPathComponent("Repos")
      let runners = (runtimeRoot as NSString).appendingPathComponent("Runners")
      let hasContent = fm.fileExists(atPath: codeRepos) || fm.fileExists(atPath: runtimeRepos) || fm.fileExists(atPath: runners)
      guard hasContent else { continue }

      let projectCount = countOwnerRepoChildren(under: codeRepos) + (runtimeRepos == codeRepos ? 0 : countOwnerRepoChildren(under: runtimeRepos))
      let runnerCount = countOwnerRepoChildren(under: runners)
      candidates.append(
        LegacyWorkspaceCandidate(
          id: key,
          label: root.label,
          codeRoot: codeRoot,
          importRoot: importRoot,
          runtimeRoot: runtimeRoot,
          projectCount: projectCount,
          runnerCount: runnerCount
        )
      )
    }

    return candidates.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
  }

  private nonisolated static func migrateLegacyWorkspace(
    candidate: LegacyWorkspaceCandidate,
    destinationRoots: (codeRoot: String, importRoot: String, runtimeRoot: String),
    mode: LocalFileTransferMode,
    overwrite: Bool,
    environment: [String: String]
  ) throws -> String {
    let fm = FileManager.default
    var operations: [LocalTransferOperation] = []

    func appendOwnerRepoTransfers(from sourceBase: String, to destinationBase: String) {
      let owners = (try? fm.contentsOfDirectory(atPath: sourceBase))?.sorted() ?? []
      for owner in owners {
        let ownerPath = (sourceBase as NSString).appendingPathComponent(owner)
        var isOwnerDir: ObjCBool = false
        guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else { continue }
        let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
        for repo in repos {
          let source = (ownerPath as NSString).appendingPathComponent(repo)
          var isRepoDir: ObjCBool = false
          guard fm.fileExists(atPath: source, isDirectory: &isRepoDir), isRepoDir.boolValue else { continue }
          let destination = (destinationBase as NSString).appendingPathComponent("\(owner)/\(repo)")
          if normalizedPath(source) != normalizedPath(destination) {
            operations.append(LocalTransferOperation(source: source, destination: destination))
          }
        }
      }
    }

    appendOwnerRepoTransfers(
      from: (candidate.codeRoot as NSString).appendingPathComponent("Repos"),
      to: (destinationRoots.codeRoot as NSString).appendingPathComponent("Repos")
    )
    appendOwnerRepoTransfers(
      from: (candidate.runtimeRoot as NSString).appendingPathComponent("Repos"),
      to: (destinationRoots.runtimeRoot as NSString).appendingPathComponent("Repos")
    )
    appendOwnerRepoTransfers(
      from: (candidate.runtimeRoot as NSString).appendingPathComponent("Runners"),
      to: (destinationRoots.runtimeRoot as NSString).appendingPathComponent("Runners")
    )

    var seenDestinations: Set<String> = []
    operations = operations.filter { seenDestinations.insert(normalizedPath($0.destination)).inserted }

    guard !operations.isEmpty else {
      return "No movable projects or runners were found in \(candidate.label)."
    }

    let outcome = try performTransactionalTransfers(
      operations: operations,
      mode: mode,
      overwrite: overwrite,
      environment: environment
    )
    let warnings = outcome.warnings.isEmpty ? "" : " Warnings: \(outcome.warnings.joined(separator: " "))"
    return "\(mode.label) migrated \(operations.count) project/runner folders from \(candidate.label) into current workspace roots." + warnings
  }

  private nonisolated static func countOwnerRepoChildren(under root: String) -> Int {
    let fm = FileManager.default
    guard fm.fileExists(atPath: root) else { return 0 }
    let owners = (try? fm.contentsOfDirectory(atPath: root)) ?? []
    return owners.reduce(0) { total, owner in
      let ownerPath = (root as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else { return total }
      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath)) ?? []
      return total + repos.filter {
        let repoPath = (ownerPath as NSString).appendingPathComponent($0)
        var isRepoDir: ObjCBool = false
        return fm.fileExists(atPath: repoPath, isDirectory: &isRepoDir) && isRepoDir.boolValue
      }.count
    }
  }

  private nonisolated static func readEnvFile(_ path: String) -> [String: String] {
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
    var values: [String: String] = [:]
    for line in contents.split(whereSeparator: \.isNewline).map(String.init) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else { continue }
      let key = String(trimmed[..<separator])
      var value = String(trimmed[trimmed.index(after: separator)...])
      if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
        value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "'\"'\"'", with: "'")
      }
      values[key] = NSString(string: value).expandingTildeInPath
    }
    return values
  }

  private nonisolated static func normalizedPath(_ value: String) -> String {
    NSString(string: value.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
  }

  nonisolated static func relocateWorkspaceRoots(
    scope: WorkspaceRelocationScope,
    style: WorkspaceStyle,
    codeRoot: String,
    importRoot: String,
    runtimeRoot: String,
    destinationBase: String,
    overwrite: Bool,
    environment: [String: String]
  ) throws -> WorkspaceRelocationOutcome {
    let destinationRoot = NSString(string: destinationBase).standardizingPath
    let fm = FileManager.default
    let transactionID = UUID().uuidString
    let operations: [(source: String, destination: String)]

    switch style {
    case .single:
      operations = [(runtimeRoot, (destinationRoot as NSString).appendingPathComponent("Workspace"))]
    case .split:
      switch scope {
      case .workspace:
        operations = [
          (codeRoot, (destinationRoot as NSString).appendingPathComponent("Code")),
          (importRoot, (destinationRoot as NSString).appendingPathComponent("Import")),
          (runtimeRoot, (destinationRoot as NSString).appendingPathComponent("Runtime"))
        ]
      case .codeRoot:
        operations = [(codeRoot, (destinationRoot as NSString).appendingPathComponent("Code"))]
      case .runtimeRoot:
        operations = [(runtimeRoot, (destinationRoot as NSString).appendingPathComponent("Runtime"))]
      }
    }

    for operation in operations {
      guard fm.fileExists(atPath: operation.source) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Source path was not found: \(operation.source)"])
      }
      let normalizedSource = NSString(string: operation.source).standardizingPath
      let normalizedDestination = NSString(string: operation.destination).standardizingPath
      if normalizedDestination == normalizedSource || normalizedDestination.hasPrefix(normalizedSource + "/") {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination cannot be the same as or inside the source path: \(normalizedDestination)"])
      }
      if fm.fileExists(atPath: normalizedDestination), !overwrite {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(normalizedDestination)"])
      }
    }

    var stagePathsByDestination: [String: String] = [:]
    var backupPathsByDestination: [String: String] = [:]

    do {
      for operation in operations {
        let stagePath = try stagingPath(for: operation.destination, transactionID: transactionID)
        try? fm.removeItem(atPath: stagePath)
        try transferItem(from: operation.source, to: stagePath, mode: .copyBackup, overwrite: true, environment: environment)
        stagePathsByDestination[operation.destination] = stagePath
      }

      for operation in operations where fm.fileExists(atPath: operation.destination) {
        let backupPath = operation.destination + ".csa-iem-backup-\(transactionID)"
        try? fm.removeItem(atPath: backupPath)
        try fm.moveItem(atPath: operation.destination, toPath: backupPath)
        backupPathsByDestination[operation.destination] = backupPath
      }

      for operation in operations {
        guard let stagePath = stagePathsByDestination[operation.destination] else { continue }
        try fm.moveItem(atPath: stagePath, toPath: operation.destination)
        stagePathsByDestination.removeValue(forKey: operation.destination)
      }
      if environment["CSA_IEM_TEST_FAIL_AFTER_WORKSPACE_PROMOTION"] == "1" {
        throw NSError(domain: appTitle, code: 96, userInfo: [NSLocalizedDescriptionKey: "Injected workspace relocation failure for rollback verification."])
      }
    } catch {
      for operation in operations {
        if fm.fileExists(atPath: operation.destination) {
          try? fm.removeItem(atPath: operation.destination)
        }
      }
      for (destination, backupPath) in backupPathsByDestination {
        if fm.fileExists(atPath: backupPath) {
          try? fm.moveItem(atPath: backupPath, toPath: destination)
        }
      }
      throw error
    }

    var cleanupWarnings: [String] = []
    for operation in operations {
      if fm.fileExists(atPath: operation.source) {
        do {
          try fm.removeItem(atPath: operation.source)
        } catch {
          cleanupWarnings.append("Source cleanup failed for \(operation.source). The new destination is ready, but the old path still needs manual cleanup.")
        }
      }
    }
    for backupPath in backupPathsByDestination.values {
      try? fm.removeItem(atPath: backupPath)
    }

    switch style {
    case .single:
      let target = operations.first?.destination ?? runtimeRoot
      return WorkspaceRelocationOutcome(result: .single(target), warnings: cleanupWarnings)
    case .split:
      let newCodeRoot: String
      let newImportRoot: String
      let newRuntimeRoot: String
      switch scope {
      case .workspace:
        newCodeRoot = operations.first(where: { NSString(string: $0.destination).lastPathComponent == "Code" })?.destination ?? codeRoot
        newImportRoot = operations.first(where: { NSString(string: $0.destination).lastPathComponent == "Import" })?.destination ?? importRoot
        newRuntimeRoot = operations.first(where: { NSString(string: $0.destination).lastPathComponent == "Runtime" })?.destination ?? runtimeRoot
      case .codeRoot:
        newCodeRoot = operations.first?.destination ?? codeRoot
        newImportRoot = importRoot
        newRuntimeRoot = runtimeRoot
      case .runtimeRoot:
        newCodeRoot = codeRoot
        newImportRoot = importRoot
        newRuntimeRoot = operations.first?.destination ?? runtimeRoot
      }
      return WorkspaceRelocationOutcome(result: .split(codeRoot: newCodeRoot, importRoot: newImportRoot, runtimeRoot: newRuntimeRoot), warnings: cleanupWarnings)
    }
  }

  private nonisolated static func exportLocalFiles(
    scope: LocalFileExportScope,
    mode: LocalFileTransferMode,
    destinationBase: String,
    preparedStamp: String? = nil,
    roots: (codeRoot: String, importRoot: String, runtimeRoot: String),
    selectedProjects: [LocalProjectEntry],
    includeCode: Bool,
    includeRuntime: Bool,
    includeRunners: Bool,
    overwrite: Bool,
    environment: [String: String]
  ) throws -> String {
    let stamp = preparedStamp ?? timestampStamp()
    let exportRoot = localExportRoot(destinationBase: destinationBase, stamp: stamp)
    let operations = try plannedLocalExportOperations(
      scope: scope,
      destinationRoot: exportRoot,
      roots: roots,
      selectedProjects: selectedProjects,
      includeCode: includeCode,
      includeRuntime: includeRuntime,
      includeRunners: includeRunners
    )
    let outcome = try performTransactionalTransfers(
      operations: operations,
      mode: mode,
      overwrite: overwrite,
      environment: environment
    )

    let warningSuffix = outcome.warnings.isEmpty
      ? ""
      : " Warnings: " + outcome.warnings.joined(separator: " ")

    switch scope {
    case .workspaceBundle:
      return "\(mode.label) finished for the full workspace bundle at \(exportRoot)." + warningSuffix
    case .codeWorkspace:
      let target = (exportRoot as NSString).appendingPathComponent("Code")
      return "\(mode.label) finished for the code workspace at \(target)." + warningSuffix
    case .runtimeWorkspace:
      let target = (exportRoot as NSString).appendingPathComponent("Runtime")
      return "\(mode.label) finished for the runtime workspace at \(target)." + warningSuffix
    case .selectedProjects:
      return "\(mode.label) finished for \(selectedProjects.count) selected projects (\(operations.count) items) at \(exportRoot)." + warningSuffix
    }
  }

  private nonisolated static func plannedLocalExportOperations(
    scope: LocalFileExportScope,
    destinationRoot: String,
    roots: (codeRoot: String, importRoot: String, runtimeRoot: String),
    selectedProjects: [LocalProjectEntry],
    includeCode: Bool,
    includeRuntime: Bool,
    includeRunners: Bool
  ) throws -> [LocalTransferOperation] {
    switch scope {
    case .workspaceBundle:
      var operations = [
        LocalTransferOperation(
          source: roots.codeRoot,
          destination: (destinationRoot as NSString).appendingPathComponent("Code")
        )
      ]
      if NSString(string: roots.importRoot).standardizingPath != NSString(string: roots.codeRoot).standardizingPath,
         NSString(string: roots.importRoot).standardizingPath != NSString(string: roots.runtimeRoot).standardizingPath {
        operations.append(
          LocalTransferOperation(
            source: roots.importRoot,
            destination: (destinationRoot as NSString).appendingPathComponent("Import")
          )
        )
      }
      if NSString(string: roots.runtimeRoot).standardizingPath != NSString(string: roots.codeRoot).standardizingPath {
        operations.append(
          LocalTransferOperation(
            source: roots.runtimeRoot,
            destination: (destinationRoot as NSString).appendingPathComponent("Runtime")
          )
        )
      }
      return operations
    case .codeWorkspace:
      return [
        LocalTransferOperation(
          source: roots.codeRoot,
          destination: (destinationRoot as NSString).appendingPathComponent("Code")
        )
      ]
    case .runtimeWorkspace:
      return [
        LocalTransferOperation(
          source: roots.runtimeRoot,
          destination: (destinationRoot as NSString).appendingPathComponent("Runtime")
        )
      ]
    case .selectedProjects:
      guard !selectedProjects.isEmpty else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "No local projects were selected for export."])
      }

      let runtimeRunnerRoot = (roots.runtimeRoot as NSString).appendingPathComponent("Runners")
      var operations: [LocalTransferOperation] = []

      for project in selectedProjects {
        if includeCode, let codePath = project.codePath {
          operations.append(
            LocalTransferOperation(
              source: codePath,
              destination: (destinationRoot as NSString).appendingPathComponent("Code/Repos/\(project.owner)/\(project.repo)")
            )
          )
        }

        if includeRuntime, let runtimePath = project.runtimePath {
          operations.append(
            LocalTransferOperation(
              source: runtimePath,
              destination: (destinationRoot as NSString).appendingPathComponent("Runtime/Repos/\(project.owner)/\(project.repo)")
            )
          )
        }

        if includeRunners {
          let runnerPath = (runtimeRunnerRoot as NSString).appendingPathComponent("\(project.owner)/\(project.repo)")
          if FileManager.default.fileExists(atPath: runnerPath) {
            operations.append(
              LocalTransferOperation(
                source: runnerPath,
                destination: (destinationRoot as NSString).appendingPathComponent("Runtime/Runners/\(project.owner)/\(project.repo)")
              )
            )
          }
        }
      }

      return operations
    }
  }

  private nonisolated static func commonCodexProjectScanRoots(environment: [String: String]) -> [String] {
    let fm = FileManager.default
    let home = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      ? environment["HOME"]!
      : NSHomeDirectory()
    var candidates = [
      (home as NSString).appendingPathComponent("Documents"),
      (home as NSString).appendingPathComponent("Desktop"),
      (home as NSString).appendingPathComponent("Developer"),
      (home as NSString).appendingPathComponent("Development"),
      (home as NSString).appendingPathComponent("Projects"),
      (home as NSString).appendingPathComponent("Code"),
      (home as NSString).appendingPathComponent("CODEX PROJECTS"),
      (home as NSString).appendingPathComponent(".codex/worktrees"),
      (home as NSString).appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Documents")
    ]

    if let volumeNames = try? fm.contentsOfDirectory(atPath: "/Volumes") {
      for volumeName in volumeNames where !volumeName.hasPrefix(".") {
        let volumeRoot = ("/Volumes" as NSString).appendingPathComponent(volumeName)
        candidates.append((volumeRoot as NSString).appendingPathComponent("CODEX PROJECTS"))
        candidates.append((volumeRoot as NSString).appendingPathComponent("Development"))
        candidates.append((volumeRoot as NSString).appendingPathComponent("Projects"))
      }
    }

    var seen: Set<String> = []
    return candidates
      .map { NSString(string: $0).standardizingPath }
      .filter { path in
        var isDirectory: ObjCBool = false
        return fm.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue && seen.insert(path).inserted
      }
  }

  private nonisolated static func codexProjectEvidence(at path: String, fileManager fm: FileManager) -> [String] {
    guard let contents = try? fm.contentsOfDirectory(atPath: path), !contents.isEmpty else {
      return []
    }
    let names = Set(contents)
    let lowercaseNames = Set(contents.map { $0.lowercased() })
    let manifestNames: Set<String> = [
      "package.json", "package.swift", "cargo.toml", "pyproject.toml", "requirements.txt",
      "gemfile", "go.mod", "firebase.json", "composer.json", "pom.xml", "build.gradle",
      "build.gradle.kts", "mix.exs", "pubspec.yaml", "deno.json", "deno.jsonc"
    ]
    let codeFolderNames: Set<String> = [
      "src", "app", "lib", "server", "client", "functions", "ios", "android", "packages",
      "apps", "tests", "test", "scripts", "public", "web", "api"
    ]
    let sourceExtensions: Set<String> = [
      "c", "cc", "cpp", "cs", "css", "go", "html", "java", "js", "jsx", "kt", "kts",
      "m", "mm", "php", "py", "rb", "rs", "scala", "sh", "sql", "swift", "ts", "tsx",
      "vue", "yaml", "yml"
    ]
    let hasGit = names.contains(".git")
    let hasManifest = !manifestNames.intersection(lowercaseNames).isEmpty
    let hasManagedWorkspace = names.contains(".devcontainer") || names.contains(".SYSTEMX")
    let hasWorkspaceConfig = names.contains(".vscode") || names.contains(".cursor") || names.contains(".idea") ||
      names.contains(".github") || names.contains("Dockerfile") || names.contains("docker-compose.yml") ||
      names.contains("docker-compose.yaml") || names.contains("Makefile") || lowercaseNames.contains(where: {
        $0.hasPrefix("vite.config.") || $0.hasPrefix("next.config.") || $0.hasPrefix("webpack.config.") ||
          $0.hasPrefix("tsconfig") || $0.hasPrefix("eslint.config")
      })
    let hasCodeFolder = !codeFolderNames.intersection(lowercaseNames).isEmpty
    let hasProjectDocs = lowercaseNames.contains("readme") || lowercaseNames.contains("readme.md") ||
      names.contains("Transfer_Note.MD") || names.contains("Prompt_Inject.MD")
    let hasNestedManifest = contents.contains { name in
      guard codeFolderNames.contains(name.lowercased()) else { return false }
      let nestedPath = (path as NSString).appendingPathComponent(name)
      return manifestNames.contains { manifestName in
        fm.fileExists(atPath: (nestedPath as NSString).appendingPathComponent(manifestName))
      }
    }
    let sourceFileCount = contents.reduce(into: 0) { count, name in
      guard !name.hasPrefix(".") else { return }
      let extensionName = (name as NSString).pathExtension.lowercased()
      if sourceExtensions.contains(extensionName) {
        count += 1
      }
    }

    var evidence: [String] = []
    if hasGit { evidence.append("Git") }
    if hasManifest { evidence.append("manifest") }
    if hasManagedWorkspace { evidence.append("managed workspace") }
    if hasGit || hasManifest || hasManagedWorkspace {
      return evidence
    }

    let contextSignals = [hasWorkspaceConfig, hasCodeFolder, hasProjectDocs, hasNestedManifest, sourceFileCount > 0]
      .filter { $0 }
      .count
    if (hasCodeFolder && contextSignals >= 2) || hasNestedManifest ||
      (sourceFileCount >= 2 && (hasWorkspaceConfig || hasProjectDocs)) ||
      ((names.contains("Transfer_Note.MD") || names.contains("Prompt_Inject.MD")) && (hasCodeFolder || sourceFileCount > 0)) {
      evidence.append("folder context")
    }
    return evidence
  }

  private nonisolated static func readCodexLocalDevProfile(projectPath: String) -> CodexLocalDevProfile? {
    let packagePath = (projectPath as NSString).appendingPathComponent("package.json")
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: packagePath)),
          let object = try? JSONSerialization.jsonObject(with: data),
          let package = object as? [String: Any],
          let scripts = package["scripts"] as? [String: Any] else {
      return nil
    }

    let candidates: [(script: String, label: String, badge: String)] = [
      ("dev:firebase", "Imported Firebase session", "Firebase dev"),
      ("dev:systemx", "Imported Firebase session", "Firebase dev"),
      ("dev:firebase:raw", "Firebase emulator session", "Firebase dev"),
      ("dev", "Local development server", "Local dev")
    ]

    for candidate in candidates {
      guard let command = scripts[candidate.script] as? String,
            !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        continue
      }
      return CodexLocalDevProfile(
        script: candidate.script,
        label: candidate.label,
        badge: candidate.badge
      )
    }

    return nil
  }

  private nonisolated static func discoverCodexProjects(
    scanRoots: [String],
    environment: [String: String]
  ) -> [CodexProjectEntry] {
    let fm = FileManager.default
    let skippedNames: Set<String> = [
      ".git", ".Trash", ".cache", ".npm", ".pnpm-store", ".yarn", ".swiftpm",
      "node_modules", "Pods", "DerivedData", "dist", "build", ".build", ".next", ".turbo",
      ".terraform", ".gradle", "coverage", "_temp", "backup"
    ]
    let skippedLowercaseNames = Set(skippedNames.map { $0.lowercased() })
    let scanDeadline = Date().addingTimeInterval(45)
    var scannedDirectories = 0
    var discovered: [String: String] = [:]

    func shouldSkipDirectoryName(_ name: String) -> Bool {
      let lowercaseName = name.lowercased()
      return skippedNames.contains(name) ||
        skippedLowercaseNames.contains(lowercaseName) ||
        isCodexAuxiliaryDestinationName(name)
    }

    func addCandidate(_ path: String, source: String) {
      var isDirectory: ObjCBool = false
      let normalized = NSString(string: path).standardizingPath
      guard fm.fileExists(atPath: normalized, isDirectory: &isDirectory),
            isDirectory.boolValue,
            !isCodexAuxiliaryDestinationName((normalized as NSString).lastPathComponent) else { return }
      let evidence = codexProjectEvidence(at: normalized, fileManager: fm)
      guard !evidence.isEmpty else { return }
      let discoverySource = evidence.contains("folder context") ? "\(source), folder context" : source
      if let existing = discovered[normalized], !existing.contains(discoverySource) {
        discovered[normalized] = existing + ", " + discoverySource
      } else if discovered[normalized] == nil {
        discovered[normalized] = discoverySource
      }
    }

    // Selected folders are the fast, deterministic path. Their results are
    // scoped to those folders, so parsing session history first only wastes
    // time and can block on large or cloud-backed JSONL files. History is a
    // fallback when no folder has been selected.
    if scanRoots.isEmpty {
      let codexSessionsRoot = NSString(string: "~/.codex/sessions").expandingTildeInPath
      if let enumerator = fm.enumerator(
        at: URL(fileURLWithPath: codexSessionsRoot, isDirectory: true),
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      ) {
        var sessionFiles: [(url: URL, date: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
          let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
          guard values?.isRegularFile == true, (values?.fileSize ?? 0) <= 10_000_000 else { continue }
          sessionFiles.append((url, values?.contentModificationDate ?? .distantPast))
        }

        let pattern = #"\"cwd\"\s*:\s*\"((?:\\.|[^\"\\])*)\""#
        let regex = try? NSRegularExpression(pattern: pattern)
        var totalBytes = 0
        for item in sessionFiles.sorted(by: { $0.date > $1.date }).prefix(200) {
          guard Date() < scanDeadline else { break }
          guard totalBytes < 50_000_000,
                let data = try? Data(contentsOf: item.url, options: .mappedIfSafe),
                let contents = String(data: data, encoding: .utf8) else { continue }
          totalBytes += data.count
          let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
          regex?.enumerateMatches(in: contents, range: range) { match, _, _ in
            guard let match, let valueRange = Range(match.range(at: 1), in: contents) else { return }
            let encoded = "\"" + String(contents[valueRange]) + "\""
            guard let encodedData = encoded.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(String.self, from: encodedData) else { return }
            addCandidate(decoded, source: "Codex history")
          }
        }
      }
    }

    for root in scanRoots {
      guard Date() < scanDeadline, scannedDirectories < 50_000 else { break }
      let normalizedRoot = NSString(string: root).standardizingPath
      addCandidate(normalizedRoot, source: "scan root")
      let rootIsProject = !codexProjectEvidence(at: normalizedRoot, fileManager: fm).isEmpty
      // A selected project root is already an actionable result. Avoid
      // recursively walking its templates and generated trees; container
      // roots still recurse so multiple projects can be discovered.
      if rootIsProject {
        continue
      }
      let rootDepth = URL(fileURLWithPath: normalizedRoot).pathComponents.count
      guard let enumerator = fm.enumerator(
        at: URL(fileURLWithPath: normalizedRoot, isDirectory: true),
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsPackageDescendants]
      ) else { continue }

      for case let url as URL in enumerator {
        if Date() >= scanDeadline || scannedDirectories >= 50_000 {
          enumerator.skipDescendants()
          break
        }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values?.isDirectory == true else { continue }
        scannedDirectories += 1
        let depth = url.pathComponents.count - rootDepth
        if values?.isSymbolicLink == true || depth >= 7 || shouldSkipDirectoryName(url.lastPathComponent) {
          enumerator.skipDescendants()
          continue
        }
        let evidence = codexProjectEvidence(at: url.path, fileManager: fm)
        if !evidence.isEmpty {
          addCandidate(url.path, source: "folder scan")
          enumerator.skipDescendants()
        }
      }
    }

    if !scanRoots.isEmpty {
      let normalizedRoots = scanRoots.map { NSString(string: $0).standardizingPath }
      let projectRoots = normalizedRoots.filter { root in
        !codexProjectEvidence(at: root, fileManager: fm).isEmpty
      }
      discovered = discovered.filter { path, _ in
        if projectRoots.contains(path) {
          return true
        }
        if projectRoots.contains(where: { path.hasPrefix($0 + "/") }) {
          return false
        }
        return normalizedRoots.contains { root in
          path == root || path.hasPrefix(root + "/")
        }
      }
    }

    let codexRegistry = readCodexDesktopProjectRegistry(environment: environment)
    let activeToolEvidence = CodexToolEvidenceDetector.activeHostTools()
    let candidates = discovered.map { (path: $0.key, source: $0.value) }
      .sorted {
        ($0.path as NSString).lastPathComponent.localizedCaseInsensitiveCompare(
          ($1.path as NSString).lastPathComponent
        ) == .orderedAscending
      }
    let collector = CodexProjectEntryCollector(count: candidates.count)
    let gitStatusQueue = OperationQueue()
    gitStatusQueue.name = "com.waynetechlab.csaiem.codex-git-status"
    gitStatusQueue.qualityOfService = .userInitiated
    gitStatusQueue.maxConcurrentOperationCount = max(2, min(6, ProcessInfo.processInfo.activeProcessorCount / 2))

    for (index, candidate) in candidates.enumerated() {
      gitStatusQueue.addOperation {
        let fileManager = FileManager.default
        let metadata = readCodexGitMetadata(projectPath: candidate.path)
        let gitStatus = readCodexGitWorkspaceStatus(
          projectPath: candidate.path,
          metadata: metadata,
          environment: environment
        )
        let snapshot = readCodexProjectSnapshot(projectPath: candidate.path)
        let entry = CodexProjectEntry(
          path: candidate.path,
          name: (candidate.path as NSString).lastPathComponent,
          discoveredBy: candidate.source,
          hasGit: metadata.hasGit,
          hasPackageManifest: ["package.json", "Package.swift", "Cargo.toml", "pyproject.toml", "requirements.txt", "Gemfile", "go.mod"]
            .contains { fileManager.fileExists(atPath: (candidate.path as NSString).appendingPathComponent($0)) },
          hasDevcontainer: fileManager.fileExists(atPath: (candidate.path as NSString).appendingPathComponent(".devcontainer")),
          hasSystemX: fileManager.fileExists(atPath: (candidate.path as NSString).appendingPathComponent(".SYSTEMX")),
          localDevProfile: readCodexLocalDevProfile(projectPath: candidate.path),
          toolEvidence: readCodexToolEvidence(projectPath: candidate.path, codexState: codexRegistry.state(for: candidate.path)),
          activeToolEvidence: activeToolEvidence,
          snapshot: snapshot,
          remoteURL: metadata.remoteURL,
          branch: gitStatus.branch ?? metadata.branch,
          ideState: codexRegistry.state(for: candidate.path),
          gitStatus: gitStatus
        )
        collector.store(entry, at: index)
      }
    }
    gitStatusQueue.waitUntilAllOperationsAreFinished()
    return collector.collectedEntries()
  }

  private nonisolated static func readCodexGitMetadata(projectPath: String) -> (hasGit: Bool, remoteURL: String?, branch: String?) {
    let fm = FileManager.default
    let dotGitPath = (projectPath as NSString).appendingPathComponent(".git")
    var isDirectory: ObjCBool = false
    guard fm.fileExists(atPath: dotGitPath, isDirectory: &isDirectory) else {
      return (false, nil, nil)
    }

    var gitDirectory = dotGitPath
    if !isDirectory.boolValue,
       let pointer = try? String(contentsOfFile: dotGitPath, encoding: .utf8),
       let gitdirLine = pointer.split(whereSeparator: \.isNewline).first(where: { $0.lowercased().hasPrefix("gitdir:") }) {
      let rawPath = gitdirLine.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespacesAndNewlines)
      gitDirectory = rawPath.hasPrefix("/")
        ? rawPath
        : ((projectPath as NSString).appendingPathComponent(rawPath) as NSString).standardizingPath
    }

    var configPath: String?
    var probe = gitDirectory
    for _ in 0..<5 {
      let candidate = (probe as NSString).appendingPathComponent("config")
      if fm.fileExists(atPath: candidate) {
        configPath = candidate
        break
      }
      let parent = (probe as NSString).deletingLastPathComponent
      if parent == probe { break }
      probe = parent
    }

    var remoteURL: String?
    if let configPath, let config = try? String(contentsOfFile: configPath, encoding: .utf8) {
      var inOrigin = false
      for rawLine in config.split(whereSeparator: \.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("[") {
          inOrigin = line.lowercased() == "[remote \"origin\"]"
        } else if inOrigin, line.lowercased().hasPrefix("url") {
          let pieces = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          if pieces.count == 2, !pieces[1].isEmpty {
            remoteURL = pieces[1]
            break
          }
        }
      }
    }

    let headPath = (gitDirectory as NSString).appendingPathComponent("HEAD")
    let head = (try? String(contentsOfFile: headPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    let branch = head?.hasPrefix("ref: refs/heads/") == true
      ? String(head!.dropFirst("ref: refs/heads/".count))
      : nil
    return (true, remoteURL, branch)
  }

  private nonisolated static func readCodexToolEvidence(
    projectPath: String,
    codexState: CodexIDEProjectState
  ) -> [CodexToolEvidence] {
    CodexToolEvidenceDetector.detect(projectPath: projectPath, codexState: codexState)
  }

  private nonisolated static func readCodexProjectSnapshot(projectPath: String, maxFiles: Int = 400, maxDepth: Int = 3) -> CodexProjectSnapshot {
    let root = URL(fileURLWithPath: projectPath).standardizedFileURL
    let ignored: Set<String> = [".git", "node_modules", ".build", "DerivedData", "Pods", "dist", "build", ".next", ".turbo"]
    let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
    var fileCount = 0
    var byteCount: Int64 = 0
    var latest: Date?
    var truncated = false
    guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsPackageDescendants], errorHandler: { _, _ in true }) else {
      return CodexProjectSnapshot(fileCount: 0, byteCount: 0, latestModification: nil, truncated: false)
    }
    while let url = enumerator.nextObject() as? URL {
      let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
      let components = relative.split(separator: "/")
      if components.contains(where: { ignored.contains(String($0)) }) {
        enumerator.skipDescendants()
        continue
      }
      if components.count > maxDepth + 1 {
        enumerator.skipDescendants()
        continue
      }
      guard let values = try? url.resourceValues(forKeys: keys) else { continue }
      if values.isDirectory == true { continue }
      fileCount += 1
      if fileCount > maxFiles {
        truncated = true
        break
      }
      byteCount += Int64(values.fileSize ?? 0)
      if let date = values.contentModificationDate, date > (latest ?? .distantPast) { latest = date }
    }
    return CodexProjectSnapshot(fileCount: min(fileCount, maxFiles), byteCount: byteCount, latestModification: latest, truncated: truncated)
  }

  private nonisolated static func readCodexDesktopProjectRegistry(
    environment: [String: String]
  ) -> CodexDesktopProjectRegistry {
    let unavailable = CodexDesktopProjectRegistry(
      isAvailable: false,
      linkedRootPaths: [],
      activeRootPaths: []
    )
    let home = environment["HOME"] ?? NSHomeDirectory()
    let configuredCodexHome = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
    let codexHome = configuredCodexHome?.isEmpty == false
      ? NSString(string: configuredCodexHome!).expandingTildeInPath
      : (home as NSString).appendingPathComponent(".codex")
    let statePath = (codexHome as NSString).appendingPathComponent(".codex-global-state.json")

    guard let data = try? Data(contentsOf: URL(fileURLWithPath: statePath), options: .mappedIfSafe),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return unavailable
    }

    let rawProjects = root["local-projects"] as? [String: Any] ?? [:]
    var rootsByProjectID: [String: Set<String>] = [:]
    var linkedRoots: Set<String> = []
    for (projectID, rawProject) in rawProjects {
      guard let project = rawProject as? [String: Any],
            let rawRootPaths = project["rootPaths"] as? [Any] else { continue }
      let projectRoots = rawRootPaths.reduce(into: Set<String>()) { result, value in
        guard let path = value as? String else { return }
        result.formUnion(CodexDesktopProjectRegistry.normalizedPathVariants(path))
      }
      rootsByProjectID[projectID] = projectRoots
      linkedRoots.formUnion(projectRoots)
    }

    let selectedProject = root["selected-project"] as? [String: Any]
    let selectedProjectID = selectedProject?["projectId"] as? String
    let activeRoots = selectedProjectID.flatMap { rootsByProjectID[$0] } ?? []
    return CodexDesktopProjectRegistry(
      isAvailable: true,
      linkedRootPaths: linkedRoots,
      activeRootPaths: activeRoots
    )
  }

  private nonisolated static func readCodexGitWorkspaceStatus(
    projectPath: String,
    metadata: (hasGit: Bool, remoteURL: String?, branch: String?),
    environment: [String: String]
  ) -> CodexGitWorkspaceStatus {
    guard metadata.hasGit else {
      return CodexGitWorkspaceStatus(
        branch: nil,
        upstream: nil,
        mainState: .noGit,
        hasLocalChanges: false
      )
    }

    let gitCandidates = [
      environment["GIT"],
      "/usr/bin/git",
      "/opt/homebrew/bin/git",
      "/usr/local/bin/git"
    ].compactMap { $0 }
    guard let git = gitCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
      return CodexGitWorkspaceStatus(
        branch: metadata.branch,
        upstream: nil,
        mainState: .unavailable,
        hasLocalChanges: false
      )
    }

    var gitEnvironment = environment
    gitEnvironment["GIT_OPTIONAL_LOCKS"] = "0"
    gitEnvironment["GIT_TERMINAL_PROMPT"] = "0"
    gitEnvironment["GIT_LFS_SKIP_SMUDGE"] = "1"
    let safeDirectory = "safe.directory=\(projectPath)"
    let statusResult = runCommand(
      executable: git,
      arguments: [
        "-c", safeDirectory,
        "-C", projectPath,
        "status", "--porcelain=v2", "--branch", "--untracked-files=normal"
      ],
      environment: gitEnvironment,
      timeout: 8
    )
    guard statusResult.status == 0 else {
      return CodexGitWorkspaceStatus(
        branch: metadata.branch,
        upstream: nil,
        mainState: .unavailable,
        hasLocalChanges: false
      )
    }

    var branch = metadata.branch
    var upstream: String?
    var upstreamAhead: Int?
    var upstreamBehind: Int?
    var hasLocalChanges = false
    for rawLine in statusResult.output.split(whereSeparator: \.isNewline) {
      let line = String(rawLine)
      if line.hasPrefix("# branch.head ") {
        let value = String(line.dropFirst("# branch.head ".count))
        branch = value == "(detached)" ? nil : value
      } else if line.hasPrefix("# branch.upstream ") {
        upstream = String(line.dropFirst("# branch.upstream ".count))
      } else if line.hasPrefix("# branch.ab ") {
        let values = line.split(whereSeparator: \.isWhitespace)
        if values.count >= 4 {
          upstreamAhead = Int(values[2].dropFirst())
          upstreamBehind = Int(values[3].dropFirst())
        }
      } else if !line.hasPrefix("# ") {
        hasLocalChanges = true
      }
    }

    let mainState: CodexGitMainState
    if upstream == "origin/main", let ahead = upstreamAhead, let behind = upstreamBehind {
      mainState = codexGitMainState(ahead: ahead, behind: behind)
    } else {
      let comparison = runCommand(
        executable: git,
        arguments: [
          "-c", safeDirectory,
          "-C", projectPath,
          "rev-list", "--left-right", "--count", "origin/main...HEAD"
        ],
        environment: gitEnvironment,
        timeout: 8
      )
      let counts = comparison.output.split(whereSeparator: \.isWhitespace)
      if comparison.status == 0,
         counts.count >= 2,
         let behind = Int(counts[0]),
         let ahead = Int(counts[1]) {
        mainState = codexGitMainState(ahead: ahead, behind: behind)
      } else if comparison.status == 124 {
        mainState = .unavailable
      } else {
        mainState = .noOriginMain
      }
    }

    return CodexGitWorkspaceStatus(
      branch: branch,
      upstream: upstream,
      mainState: mainState,
      hasLocalChanges: hasLocalChanges
    )
  }

  private nonisolated static func codexGitMainState(ahead: Int, behind: Int) -> CodexGitMainState {
    switch (ahead, behind) {
    case (0, 0): return .synchronized
    case (_, 0): return .ahead(ahead)
    case (0, _): return .behind(behind)
    default: return .diverged(ahead: ahead, behind: behind)
    }
  }

  private nonisolated static func codexAutoAllSkipReason(for project: CodexProjectEntry) -> String? {
    let normalizedName = project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let projectIdentity = compactCodexIdentity(project.name)
    let remoteIdentity = compactCodexIdentity(normalizedCodexGitRemoteIdentifier(project.remoteURL) ?? "")
    if project.ideState == .active ||
       projectIdentity == "csaiem" || projectIdentity == "csailem" ||
       remoteIdentity == compactCodexIdentity("WayneTechLab/CSA-iLEM") {
      return "active CSA-iEM workspace"
    }
    if normalizedName.contains(".moved-to-backup-") || normalizedName.contains(".csa-iem-source-") {
      return "prior move source"
    }
    if normalizedName.hasSuffix("-bad") || normalizedName.contains(".partial-backup-") {
      return "folder marked as incomplete"
    }

    let pathComponents = URL(fileURLWithPath: project.path).pathComponents.map { $0.lowercased() }
    let nameParts = project.name.split(separator: ".", omittingEmptySubsequences: false)
    if pathComponents.contains("work"),
       let suffix = nameParts.last,
       suffix.count == 6,
       suffix.allSatisfy({ $0.isLetter || $0.isNumber }) {
      return "temporary work folder"
    }
    return nil
  }

  private nonisolated static func normalizedCodexGitRemoteIdentifier(_ rawURL: String?) -> String? {
    guard var value = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }

    if let url = URL(string: value), let host = url.host {
      value = host + url.path
    } else if let colon = value.firstIndex(of: ":"),
              let at = value[..<colon].lastIndex(of: "@") {
      let hostStart = value.index(after: at)
      let pathStart = value.index(after: colon)
      value = String(value[hostStart..<colon]) + "/" + String(value[pathStart...])
    } else if let scheme = value.range(of: "://") {
      value = String(value[scheme.upperBound...])
    }

    if let query = value.firstIndex(where: { $0 == "?" || $0 == "#" }) {
      value = String(value[..<query])
    }
    value = value.replacingOccurrences(of: "\\", with: "/")
    while value.hasSuffix("/") { value.removeLast() }
    if value.lowercased().hasSuffix(".git") {
      value.removeLast(4)
    }
    return value.isEmpty ? nil : value.lowercased()
  }

  private nonisolated static func casedCodexGitHubRepositoryIdentifier(_ rawURL: String?) -> String? {
    guard var value = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    var host = ""
    var repositoryPath = ""
    if let url = URL(string: value), let urlHost = url.host {
      host = urlHost
      repositoryPath = url.path
    } else if value.hasPrefix("git@"), let colon = value.firstIndex(of: ":") {
      host = String(value[value.index(value.startIndex, offsetBy: 4)..<colon])
      repositoryPath = String(value[value.index(after: colon)...])
    } else {
      if let query = value.firstIndex(where: { $0 == "?" || $0 == "#" }) {
        value = String(value[..<query])
      }
      let components = value.replacingOccurrences(of: "\\", with: "/").split(separator: "/")
      guard components.count >= 3 else { return nil }
      host = String(components[0])
      repositoryPath = components.dropFirst().joined(separator: "/")
    }
    guard host.caseInsensitiveCompare("github.com") == .orderedSame ||
            host.caseInsensitiveCompare("www.github.com") == .orderedSame else {
      return nil
    }
    if let query = repositoryPath.firstIndex(where: { $0 == "?" || $0 == "#" }) {
      repositoryPath = String(repositoryPath[..<query])
    }
    let components = repositoryPath
      .replacingOccurrences(of: "\\", with: "/")
      .split(separator: "/")
      .map(String.init)
    guard components.count == 2 else { return nil }
    let owner = components[0].removingPercentEncoding ?? components[0]
    var repository = components[1].removingPercentEncoding ?? components[1]
    if repository.lowercased().hasSuffix(".git") {
      repository.removeLast(4)
    }
    guard !owner.isEmpty,
          !repository.isEmpty,
          !owner.contains("/"),
          !repository.contains("/") else { return nil }
    return "\(owner)/\(repository)"
  }

  private nonisolated static func compactCodexIdentity(_ value: String) -> String {
    String(value.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
  }

  private nonisolated static func codexDestinationComparisonKey(_ path: String) -> String {
    NSString(string: path).standardizingPath
      .precomposedStringWithCanonicalMapping
      .lowercased()
  }

  private nonisolated static func isCodexAuxiliaryDestinationName(_ name: String) -> Bool {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ||
      normalized.hasPrefix(".") ||
      ["_temp", "backup", "backups", "_backup", "_backups"].contains(normalized) ||
      normalized.contains(".csa-iem-stage-") ||
      normalized.contains(".csa-iem-source-") ||
      normalized.contains(".migrate-") ||
      normalized.contains(".moved-") ||
      normalized.contains(".partial-") ||
      normalized.contains(".partial-backup-") ||
      normalized.contains(".admin-verified") ||
      normalized.contains(".data-copy") ||
      normalized.contains(".transfer-candidate") ||
      normalized.contains(".moved-to-codex-projects-") ||
      normalized.contains(".moved-to-backup-")
  }

  private nonisolated static func codexRemotePreferenceScore(
    project: CodexProjectEntry,
    destination: String,
    remoteIdentifier: String
  ) -> Int {
    let sourceIdentity = compactCodexIdentity(project.name)
    let destinationIdentity = compactCodexIdentity((destination as NSString).lastPathComponent)
    let repositoryIdentity = compactCodexIdentity(String(remoteIdentifier.split(separator: "/").last ?? ""))
    var score = 0
    if !repositoryIdentity.isEmpty, sourceIdentity == repositoryIdentity { score += 100 }
    if !destinationIdentity.isEmpty, sourceIdentity == destinationIdentity { score += 90 }
    if sourceIdentity.count >= 5,
       (repositoryIdentity.contains(sourceIdentity) || sourceIdentity.contains(repositoryIdentity)) {
      score += 25
    }
    let loweredName = project.name.lowercased()
    if loweredName.hasSuffix("-bad") { score -= 150 }
    if loweredName.contains(".moved-to-backup-") { score -= 100 }
    return score
  }

  private nonisolated static func codexDestinationIdentity(at path: String) -> String? {
    if let remote = normalizedCodexGitRemoteIdentifier(readCodexGitMetadata(projectPath: path).remoteURL) {
      return remote
    }

    let transferNotePath = (path as NSString).appendingPathComponent("Transfer_Note.MD")
    guard let transferNote = try? String(contentsOfFile: transferNotePath, encoding: .utf8) else {
      return nil
    }
    for rawLine in transferNote.split(whereSeparator: \.isNewline) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard line.lowercased().hasPrefix("- git remote:") else { continue }
      let value = line.dropFirst("- Git remote:".count).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !value.isEmpty, value.caseInsensitiveCompare("Not detected") != .orderedSame else {
        return nil
      }
      return normalizedCodexGitRemoteIdentifier(value)
    }
    return nil
  }

  private nonisolated static func codexCanonicalRepositoryFolderName(
    projects: [CodexProjectEntry],
    remoteIdentifier: String
  ) -> String {
    for project in projects.sorted(by: { $0.path.localizedStandardCompare($1.path) == .orderedAscending }) {
      guard var value = project.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else { continue }
      if let query = value.firstIndex(where: { $0 == "?" || $0 == "#" }) {
        value = String(value[..<query])
      }
      value = value.replacingOccurrences(of: "\\", with: "/")
      while value.hasSuffix("/") { value.removeLast() }
      guard var candidate = value.split(separator: "/").last.map(String.init), !candidate.isEmpty else {
        continue
      }
      if candidate.lowercased().hasSuffix(".git") {
        candidate.removeLast(4)
      }
      candidate = candidate.removingPercentEncoding ?? candidate
      guard !candidate.isEmpty,
            candidate != ".",
            candidate != "..",
            !candidate.contains("/"),
            !candidate.contains(":"),
            !isCodexAuxiliaryDestinationName(candidate) else { continue }
      return candidate
    }

    let repositoryName = String(remoteIdentifier.split(separator: "/").last ?? "project")
    return isCodexAuxiliaryDestinationName(repositoryName) ? "project" : repositoryName
  }

  private nonisolated static func resolveCodexDestinationPaths(
    projects: [CodexProjectEntry],
    outputRoot: String,
    mode: CodexProjectTransferMode,
    fileManager fm: FileManager
  ) throws -> [String: String] {
    guard mode.writesDestination else { return [:] }

    var resolved: [String: String] = [:]
    var projectsByRemote: [String: [CodexProjectEntry]] = [:]
    var projectsWithoutRemote: [CodexProjectEntry] = []

    for project in projects {
      guard !isCodexAuxiliaryDestinationName(project.name) else {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Auxiliary or staging folders cannot be transfer candidates: \(project.path)"]
        )
      }
      if let remote = normalizedCodexGitRemoteIdentifier(project.remoteURL) {
        projectsByRemote[remote, default: []].append(project)
      } else {
        projectsWithoutRemote.append(project)
      }
    }

    var destinationsByRemote: [String: [String]] = [:]
    let destinationURLs = (try? fm.contentsOfDirectory(
      at: URL(fileURLWithPath: outputRoot, isDirectory: true),
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
      options: [.skipsHiddenFiles]
    )) ?? []
    for url in destinationURLs {
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      guard values?.isDirectory == true,
            values?.isSymbolicLink != true,
            !isCodexAuxiliaryDestinationName(url.lastPathComponent),
            let remote = codexDestinationIdentity(at: url.path) else {
        continue
      }
      destinationsByRemote[remote, default: []].append(url.path)
    }

    for (remote, remoteProjects) in projectsByRemote {
      var identityCandidates = Set((destinationsByRemote[remote] ?? []).map {
        NSString(string: $0).standardizingPath
      })
      var unidentifiedExactCandidates: Set<String> = []

      for project in remoteProjects {
        let exactDestination = NSString(
          string: (outputRoot as NSString).appendingPathComponent(project.name)
        ).standardizingPath
        guard fm.fileExists(atPath: exactDestination) else { continue }
        if let destinationRemote = codexDestinationIdentity(at: exactDestination) {
          guard destinationRemote == remote else {
            throw NSError(
              domain: appTitle,
              code: 1,
              userInfo: [NSLocalizedDescriptionKey: "Destination Git identity does not match \(project.name): \(exactDestination)"]
            )
          }
          identityCandidates.insert(exactDestination)
        } else {
          unidentifiedExactCandidates.insert(exactDestination)
        }
      }

      guard identityCandidates.count <= 1 else {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "More than one existing destination has the Git identity used by \(remoteProjects.map(\.name).joined(separator: ", ")). Move old partial copies under _temp, then run Preflight again."]
        )
      }

      let canonicalDestination: String
      if let identifiedDestination = identityCandidates.first {
        let competingUnknowns = unidentifiedExactCandidates.filter { $0 != identifiedDestination }
        guard competingUnknowns.isEmpty else {
          throw NSError(
            domain: appTitle,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The Git identity for \(remoteProjects.map(\.name).joined(separator: ", ")) has both an identified destination and an unidentified exact-name destination. Move the old copy under _temp or restore its Git identity before retrying."]
          )
        }
        canonicalDestination = identifiedDestination
      } else if unidentifiedExactCandidates.count == 1, let exactDestination = unidentifiedExactCandidates.first {
        canonicalDestination = exactDestination
      } else if unidentifiedExactCandidates.count > 1 {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Multiple existing folders could be the canonical destination for \(remoteProjects.map(\.name).joined(separator: ", ")), but none has a verifiable Git identity. Move old copies under _temp or restore one origin remote before retrying."]
        )
      } else {
        let canonicalName = codexCanonicalRepositoryFolderName(
          projects: remoteProjects,
          remoteIdentifier: remote
        )
        canonicalDestination = NSString(
          string: (outputRoot as NSString).appendingPathComponent(canonicalName)
        ).standardizingPath
        if fm.fileExists(atPath: canonicalDestination),
           let destinationRemote = codexDestinationIdentity(at: canonicalDestination),
           destinationRemote != remote {
          throw NSError(
            domain: appTitle,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Canonical destination \(canonicalDestination) belongs to a different Git identity."]
          )
        }
      }

      for project in remoteProjects {
        resolved[project.path] = canonicalDestination
      }
    }

    for project in projectsWithoutRemote {
      let exactDestination = NSString(
        string: (outputRoot as NSString).appendingPathComponent(project.name)
      ).standardizingPath
      if fm.fileExists(atPath: exactDestination), codexDestinationIdentity(at: exactDestination) != nil {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Cannot prove that \(project.name) belongs to the existing Git destination \(exactDestination) because the source has no detected remote."]
        )
      }
      resolved[project.path] = exactDestination
    }

    var destinationIdentityClaims: [String: String] = [:]
    for project in projects {
      guard let destination = resolved[project.path] else { continue }
      let destinationKey = codexDestinationComparisonKey(destination)
      let identity = normalizedCodexGitRemoteIdentifier(project.remoteURL)
        .map { "remote:\($0)" }
        ?? "local:\(NSString(string: project.path).standardizingPath.lowercased())"
      if let claimedIdentity = destinationIdentityClaims[destinationKey], claimedIdentity != identity {
        throw NSError(
          domain: appTitle,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Different project identities would share the destination \(destination). Rename or separate the ambiguous source folders before retrying."]
        )
      }
      destinationIdentityClaims[destinationKey] = identity
    }
    return resolved
  }

  private nonisolated static func preflightCodexTransfer(
    projects: [CodexProjectEntry],
    outputRoot: String,
    mode: CodexProjectTransferMode,
    resumeExisting: Bool
  ) throws -> [String: String] {
    let fm = FileManager.default
    guard !outputRoot.isEmpty else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose an output folder."])
    }
    try fm.createDirectory(atPath: outputRoot, withIntermediateDirectories: true, attributes: nil)

    let testPath = (outputRoot as NSString).appendingPathComponent(".csa-iem-write-test-\(UUID().uuidString)")
    let writeTest = runCommand(
      executable: "/usr/bin/touch",
      arguments: [testPath],
      environment: ProcessInfo.processInfo.environment
    )
    guard writeTest.status == 0 else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "The output folder is not writable: \(outputRoot)"])
    }
    try? fm.removeItem(atPath: testPath)

    let resolvedDestinations = try resolveCodexDestinationPaths(
      projects: projects,
      outputRoot: outputRoot,
      mode: mode,
      fileManager: fm
    )
    var projectsByDestination: [String: [CodexProjectEntry]] = [:]
    if mode.writesDestination {
      for project in projects {
        guard let destination = resolvedDestinations[project.path] else {
          throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not resolve an output destination for \(project.name)."])
        }
        projectsByDestination[codexDestinationComparisonKey(destination), default: []].append(project)
      }
      for (_, destinationProjects) in projectsByDestination where destinationProjects.count > 1 {
        let destination = resolvedDestinations[destinationProjects[0].path] ?? outputRoot
        let identities = destinationProjects.compactMap { normalizedCodexGitRemoteIdentifier($0.remoteURL) }
        guard identities.count == destinationProjects.count, Set(identities).count == 1 else {
          throw NSError(
            domain: appTitle,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "More than one selected project would use \(destination), but their normalized Git identities are missing or different."]
          )
        }
      }
    }

    for project in projects {
      let source = NSString(string: project.path).standardizingPath
      guard fm.fileExists(atPath: source) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Project source is missing: \(source)"])
      }
      guard !isCodexAuxiliaryDestinationName((source as NSString).lastPathComponent) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Auxiliary or staging folders cannot be transfer candidates: \(source)"])
      }
      if outputRoot == source || outputRoot.hasPrefix(source + "/") {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Output cannot be inside project source: \(source)"])
      }
      if mode.writesDestination {
        guard let destination = resolvedDestinations[project.path] else {
          throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not resolve an output destination for \(project.name)."])
        }
        if destination == source {
          throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "\(project.name) is already in the selected output folder. Use Backup Only to create a preservation package."])
        }
        let destinationKey = codexDestinationComparisonKey(destination)
        let sharedIdentityDestination = (projectsByDestination[destinationKey]?.count ?? 0) > 1
        if fm.fileExists(atPath: destination), destination != source, !resumeExisting, !sharedIdentityDestination {
          throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(destination). Choose another output folder or use Backup Only."])
        }
        if (resumeExisting || sharedIdentityDestination), fm.fileExists(atPath: destination) {
          var isDirectory: ObjCBool = false
          guard fm.fileExists(atPath: destination, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Auto-resume destination is not a folder: \(destination)"])
          }
          if (try? fm.destinationOfSymbolicLink(atPath: destination)) != nil {
            throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Auto-resume will not merge through a symbolic-link destination: \(destination)"])
          }
        }
        if fm.fileExists(atPath: destination),
           let sourceIdentity = normalizedCodexGitRemoteIdentifier(project.remoteURL),
           let destinationIdentity = codexDestinationIdentity(at: destination),
           sourceIdentity != destinationIdentity {
          throw NSError(
            domain: appTitle,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Destination identity changed or does not match \(project.name): \(destination)"]
          )
        }
      }
    }
    return resolvedDestinations
  }

  private nonisolated static func codexRsyncExclusions(
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool
  ) -> [String] {
    var exclusions: [String] = [
      "--no-specials", "--no-devices", "--exclude=/.csa-iem-recovery/"
    ]
    if !includeFinderMetadata {
      exclusions.append(contentsOf: ["--exclude=.DS_Store", "--exclude=._*"])
    }
    if !includeDependencies {
      exclusions.append(contentsOf: codexGeneratedFolderNames.map { "--exclude=\($0)/" })
    }
    if !includeGit {
      exclusions.append("--exclude=.git/")
    }
    return exclusions
  }

  private nonisolated static func shouldIndexCodexPath(
    _ relativePath: String,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool
  ) -> Bool {
    let components = relativePath.split(separator: "/").map(String.init)
    guard !components.isEmpty else { return false }
    let name = components.last ?? ""
    if components.contains(".csa-iem-recovery") { return false }
    if !includeGit && components.contains(".git") { return false }
    if !includeDependencies,
       components.contains(where: { codexGeneratedFolderNameSet.contains($0) }) {
      return false
    }
    if !includeFinderMetadata && (name == ".DS_Store" || name.hasPrefix("._")) { return false }
    return true
  }

  private nonisolated static var codexGeneratedFolderNames: [String] {
    [
      "node_modules", "vendor", ".venv", "venv", "Pods", "DerivedData",
      "dist", "build", ".build", "target", ".next", ".nuxt", ".output", ".turbo",
      "coverage", ".nyc_output", ".cache", "Caches", ".parcel-cache", ".vite",
      ".npm", ".pnpm-store", ".swiftpm", ".gradle", ".terraform", ".dart_tool",
      ".pytest_cache", ".tox", "__pycache__"
    ]
  }

  private nonisolated static var codexGeneratedFolderNameSet: Set<String> {
    Set(codexGeneratedFolderNames)
  }

  private nonisolated static func isCodexManagedHandoffPath(_ relativePath: String) -> Bool {
    relativePath == "Transfer_Note.MD" || relativePath == "Prompt_Inject.MD"
  }

  private nonisolated static func codexIndexDirectory(
    outputRoot: String,
    projectName: String,
    projectPath: String? = nil
  ) throws -> String {
    let safeName = projectName
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
    let storageName: String
    if let projectPath, !projectPath.isEmpty {
      storageName = "\(safeName)-\(codexStablePathSuffix(projectPath))"
    } else {
      storageName = safeName
    }
    let directory = (((outputRoot as NSString).appendingPathComponent("_temp") as NSString)
      .appendingPathComponent("Transfer-Indexes") as NSString)
      .appendingPathComponent(storageName)
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    return directory
  }

  private nonisolated static func codexStablePathSuffix(_ path: String) -> String {
    let bytes = Array(NSString(string: path).standardizingPath.utf8)
    var hash: UInt64 = 1469598103934665603
    for byte in bytes {
      hash ^= UInt64(byte)
      hash = hash &* 1099511628211
    }
    return String(format: "%016llx", hash)
  }

  private nonisolated static func writeCodexIndexArtifact<T: Encodable>(_ value: T, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
  }

  private nonisolated static func readCodexIndexArtifact<T: Decodable>(
    _ type: T.Type,
    from path: String
  ) -> T? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(type, from: data)
  }

  nonisolated static func buildCodexFileIndex(
    root: String,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool,
    progress: ((Int, Int64) -> Void)? = nil
  ) throws -> CodexFileIndexSnapshot {
    let fm = FileManager.default
    let normalizedRoot = NSString(string: root).standardizingPath
    var isDirectory: ObjCBool = false
    guard fm.fileExists(atPath: normalizedRoot, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Project root is missing or is not a folder: \(normalizedRoot)"])
    }

    let resourceKeys: Set<URLResourceKey> = [
      .isDirectoryKey,
      .isRegularFileKey,
      .isSymbolicLinkKey,
      .fileSizeKey,
      .contentModificationDateKey
    ]
    guard let enumerator = fm.enumerator(atPath: normalizedRoot) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "CSA-iEM could not enumerate the project folder: \(normalizedRoot)"])
    }

    var entries: [CodexFileIndexEntry] = []
    var byteCount: Int64 = 0
    for case let relativePath as String in enumerator {
      guard !relativePath.isEmpty else { continue }
      let absolutePath = (normalizedRoot as NSString).appendingPathComponent(relativePath)
      let url = URL(fileURLWithPath: absolutePath)

      let values = try? url.resourceValues(forKeys: resourceKeys)
      let isSymbolicLink = values?.isSymbolicLink == true
      if isSymbolicLink {
        guard shouldIndexCodexPath(
          relativePath,
          includeGit: includeGit,
          includeFinderMetadata: includeFinderMetadata,
          includeDependencies: includeDependencies
        ) else {
          enumerator.skipDescendants()
          continue
        }
        entries.append(
          CodexFileIndexEntry(
            relativePath: relativePath,
            kind: .symbolicLink,
            byteCount: 0,
            modifiedAt: values?.contentModificationDate?.timeIntervalSince1970 ?? 0,
            symbolicLinkDestination: try? fm.destinationOfSymbolicLink(atPath: absolutePath)
          )
        )
        if entries.count % 250 == 0 {
          progress?(entries.count, byteCount)
        }
        continue
      }

      if values?.isDirectory == true {
        if !shouldIndexCodexPath(
          relativePath,
          includeGit: includeGit,
          includeFinderMetadata: includeFinderMetadata,
          includeDependencies: includeDependencies
        ) {
          enumerator.skipDescendants()
        } else {
          entries.append(
            CodexFileIndexEntry(
              relativePath: relativePath,
              kind: .directory,
              byteCount: 0,
              modifiedAt: values?.contentModificationDate?.timeIntervalSince1970 ?? 0,
              symbolicLinkDestination: nil
            )
          )
          if entries.count % 250 == 0 {
            progress?(entries.count, byteCount)
          }
        }
        continue
      }
      guard shouldIndexCodexPath(
        relativePath,
        includeGit: includeGit,
        includeFinderMetadata: includeFinderMetadata,
        includeDependencies: includeDependencies
      ) else {
        continue
      }

      // Live sockets, pipes, and device nodes are runtime endpoints rather
      // than portable project content. Rsync omits the same special types.
      guard values?.isRegularFile == true else { continue }
      let fileSize = Int64(values?.fileSize ?? 0)
      entries.append(
        CodexFileIndexEntry(
          relativePath: relativePath,
          kind: .file,
          byteCount: fileSize,
          modifiedAt: values?.contentModificationDate?.timeIntervalSince1970 ?? 0,
          symbolicLinkDestination: nil
        )
      )
      byteCount += fileSize
      if entries.count % 250 == 0 {
        progress?(entries.count, byteCount)
      }
    }
    progress?(entries.count, byteCount)
    return CodexFileIndexSnapshot(
      formatVersion: 1,
      rootPath: normalizedRoot,
      createdAt: Date(),
      entries: entries.sorted { $0.relativePath < $1.relativePath }
    )
  }

  private nonisolated static func writeCodexPathList(
    _ paths: [String],
    outputRoot: String,
    projectName: String,
    label: String
  ) throws -> String {
    let normalizedPaths = Array(Set(paths)).sorted()
    guard normalizedPaths.allSatisfy({ path in
      !path.isEmpty && !path.contains("\n") && !path.hasPrefix("/") && path != ".." && !path.hasPrefix("../")
    }) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "A planned project path cannot be represented safely in the targeted rsync manifest."])
    }
    let indexDirectory = try codexIndexDirectory(outputRoot: outputRoot, projectName: projectName)
    let manifestDirectory = (indexDirectory as NSString).appendingPathComponent("Manifests")
    try FileManager.default.createDirectory(atPath: manifestDirectory, withIntermediateDirectories: true, attributes: nil)
    let safeLabel = label.replacingOccurrences(of: "/", with: "-")
    let path = (manifestDirectory as NSString).appendingPathComponent("\(safeLabel)-\(UUID().uuidString).txt")
    let contents = normalizedPaths.joined(separator: "\n") + (normalizedPaths.isEmpty ? "" : "\n")
    try contents.write(toFile: path, atomically: true, encoding: .utf8)
    return path
  }

  private nonisolated static func writeCodexNullPathList(
    _ paths: [String],
    outputRoot: String,
    projectName: String,
    label: String
  ) throws -> String {
    guard paths.allSatisfy({ !$0.isEmpty && !$0.contains("\0") }) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "A cloud-backed project path cannot be represented safely for local download preparation."])
    }
    let indexDirectory = try codexIndexDirectory(outputRoot: outputRoot, projectName: projectName)
    let manifestDirectory = (indexDirectory as NSString).appendingPathComponent("Manifests")
    try FileManager.default.createDirectory(atPath: manifestDirectory, withIntermediateDirectories: true, attributes: nil)
    let safeLabel = label.replacingOccurrences(of: "/", with: "-")
    let path = (manifestDirectory as NSString).appendingPathComponent("\(safeLabel)-\(UUID().uuidString).bin")
    var data = Data()
    for value in paths {
      data.append(contentsOf: value.utf8)
      data.append(0)
    }
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    return path
  }

  private nonisolated static func isCodexDatalessFile(atPath path: String) -> Bool {
    // Darwin's UF_DATALESS (0x40000000) is present in st_flags but is not
    // exposed by every Swift SDK overlay.
    let datalessFlag: UInt32 = 0x40000000
    var fileStatus = stat()
    guard lstat(path, &fileStatus) == 0 else { return false }
    return (fileStatus.st_flags & datalessFlag) != 0
  }

  @discardableResult
  private nonisolated static func materializeCodexSourceFiles(
    sourceRoot: String,
    sourceIndex: CodexFileIndexSnapshot,
    relativePaths: [String],
    outputRoot: String,
    projectName: String,
    environment: [String: String],
    progress: ((Int, Int, Int64) -> Void)? = nil
  ) throws -> Int {
    guard !relativePaths.isEmpty else { return 0 }
    let selectedPaths = Set(relativePaths)
    let candidates = sourceIndex.entries.filter {
      $0.kind == .file && selectedPaths.contains($0.relativePath)
    }
    let datalessFiles = candidates.compactMap { entry -> (path: String, byteCount: Int64)? in
      let path = (sourceRoot as NSString).appendingPathComponent(entry.relativePath)
      return isCodexDatalessFile(atPath: path) ? (path, entry.byteCount) : nil
    }
    guard !datalessFiles.isEmpty else { return 0 }

    let fileManager = FileManager.default
    let workerCount = max(4, min(32, ProcessInfo.processInfo.activeProcessorCount * 2))
    let batchSize = 32
    var completedCount = 0
    var completedBytes: Int64 = 0
    progress?(0, datalessFiles.count, 0)

    for start in stride(from: 0, to: datalessFiles.count, by: batchSize) {
      let end = min(start + batchSize, datalessFiles.count)
      let batch = Array(datalessFiles[start..<end])
      for file in batch {
        try? fileManager.startDownloadingUbiquitousItem(at: URL(fileURLWithPath: file.path))
      }
      let manifest = try writeCodexNullPathList(
        batch.map(\.path),
        outputRoot: outputRoot,
        projectName: projectName,
        label: "cloud-materialize"
      )
      defer { try? fileManager.removeItem(atPath: manifest) }

      let command = """
      /usr/bin/xargs -0 -P \(workerCount) -n 1 /bin/cat < \(shellQuote(manifest)) > /dev/null &
      worker_pid=$!
      trap '/bin/kill -TERM "$worker_pid" 2>/dev/null || true; /usr/bin/pkill -TERM -P "$worker_pid" 2>/dev/null || true' TERM INT
      wait "$worker_pid"
      exit_code=$?
      trap - TERM INT
      exit "$exit_code"
      """
      var lastResult = CommandResult(status: 1, output: "Cloud-backed file preparation did not start.")
      for attempt in 1...3 {
        lastResult = runCommand(
          executable: "/bin/zsh",
          arguments: ["-lc", command],
          environment: environment,
          timeout: 180
        )
        if lastResult.status == 0 { break }
        if attempt < 3 {
          Thread.sleep(forTimeInterval: Double(attempt * 2))
        }
      }
      guard lastResult.status == 0 else {
        throw NSError(
          domain: appTitle,
          code: Int(lastResult.status),
          userInfo: [NSLocalizedDescriptionKey: "iCloud could not download \(batch.count) planned file(s) for \(projectName) after three attempts: \(redactSensitiveText(lastResult.output))"]
        )
      }
      completedCount += batch.count
      completedBytes += batch.reduce(Int64(0)) { $0 + $1.byteCount }
      progress?(completedCount, datalessFiles.count, completedBytes)
    }
    return datalessFiles.count
  }

  private nonisolated static let codexTransferCacheFormatVersion = 1

  private nonisolated static func cachedCodexTransferPlanIfCurrent(
    project: CodexProjectEntry,
    outputRoot: String,
    mode: CodexProjectTransferMode,
    destinationPath: String?,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool,
    fullChecksumAudit: Bool,
    environment: [String: String],
    progress: ((String, Int, Int64) -> Void)?
  ) -> CodexTransferPlan? {
    let fileManager = FileManager.default
    guard !fullChecksumAudit,
          mode.writesDestination,
          !mode.performsBidirectionalSync,
          let destinationPath,
          fileManager.fileExists(atPath: destinationPath),
          let indexDirectory = try? codexIndexDirectory(outputRoot: outputRoot, projectName: project.name, projectPath: project.path) else {
      return nil
    }

    let sourceIndexPath = (indexDirectory as NSString).appendingPathComponent("source-index.json")
    let destinationIndexPath = (indexDirectory as NSString).appendingPathComponent("destination-index.json")
    let planPath = (indexDirectory as NSString).appendingPathComponent("transfer-plan.json")
    let optionsKey = [
      includeGit ? "git=1" : "git=0",
      includeFinderMetadata ? "finder=1" : "finder=0",
      includeDependencies ? "deps=1" : "deps=0",
      fullChecksumAudit ? "checksum=1" : "checksum=0"
    ].joined(separator: ";")
    guard let cachedPlan = readCodexIndexArtifact(CodexTransferPlan.self, from: planPath),
          let sourceIndex = readCodexIndexArtifact(CodexFileIndexSnapshot.self, from: sourceIndexPath),
          let destinationIndex = readCodexIndexArtifact(CodexFileIndexSnapshot.self, from: destinationIndexPath),
          cachedPlan.cacheFormatVersion == codexTransferCacheFormatVersion,
          cachedPlan.includeGitMetadata == includeGit,
          cachedPlan.includeFinderMetadata == includeFinderMetadata,
          cachedPlan.includeDependencies == includeDependencies,
          cachedPlan.projectPath == project.path,
          cachedPlan.destinationPath == destinationPath,
          cachedPlan.typeConflictPaths.isEmpty,
          NSString(string: sourceIndex.rootPath).standardizingPath == NSString(string: project.path).standardizingPath,
          NSString(string: destinationIndex.rootPath).standardizingPath == NSString(string: destinationPath).standardizingPath,
          CodexCatalogStore(rootPath: outputRoot).indexRecordMatches(
            sourcePath: project.path,
            destinationPath: destinationPath,
            optionsKey: optionsKey,
            sourceIndexPath: sourceIndexPath,
            destinationIndexPath: destinationIndexPath
          ) else {
      return nil
    }

    let sourceEntries = sourceIndex.entries.filter {
      !isCodexManagedHandoffPath($0.relativePath) && shouldIndexCodexPath(
        $0.relativePath,
        includeGit: includeGit,
        includeFinderMetadata: includeFinderMetadata,
        includeDependencies: includeDependencies
      )
    }
    progress?("Validating saved index", sourceEntries.count, sourceEntries.reduce(0) { $0 + $1.byteCount })
    let exclusions = codexRsyncExclusions(
      includeGit: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies
    )
    guard let rawDifferences = try? rsyncChangedPaths(
      source: project.path,
      destination: destinationPath,
      exclusions: exclusions,
      protectedPaths: [],
      environment: environment,
      useChecksums: true
    ) else {
      return nil
    }
    let contentDifferences = codexContentDifferences(
      Set(rawDifferences.filter { !isCodexManagedHandoffPath($0) }),
      source: project.path,
      destination: destinationPath
    )
    guard contentDifferences.isEmpty else { return nil }

    let sourcePaths = Set(sourceEntries.map(\.relativePath))
    let destinationOnlyEntries = destinationIndex.entries.filter {
      !isCodexManagedHandoffPath($0.relativePath) &&
        !sourcePaths.contains($0.relativePath) &&
        shouldIndexCodexPath(
          $0.relativePath,
          includeGit: includeGit,
          includeFinderMetadata: includeFinderMetadata,
          includeDependencies: includeDependencies
        )
    }
    let refreshedDestinationIndex = CodexFileIndexSnapshot(
      formatVersion: 1,
      rootPath: NSString(string: destinationPath).standardizingPath,
      createdAt: Date(),
      entries: (sourceEntries + destinationOnlyEntries).sorted { $0.relativePath < $1.relativePath }
    )
    let plan = CodexTransferPlan(
      projectName: project.name,
      projectPath: project.path,
      destinationPath: destinationPath,
      createdAt: Date(),
      sourceFileCount: sourceEntries.count,
      sourceByteCount: sourceEntries.reduce(0) { $0 + $1.byteCount },
      destinationFileCount: refreshedDestinationIndex.entries.count,
      destinationByteCount: refreshedDestinationIndex.byteCount,
      requiresInitialMirror: false,
      missingPaths: [],
      metadataChangedPaths: [],
      checksumChangedPaths: [],
      destinationOnlyPaths: destinationOnlyEntries.map(\.relativePath).sorted(),
      typeConflictPaths: [],
      metadataMatchedCount: sourceEntries.count,
      fullChecksumAudit: false,
      sourceIndexPath: sourceIndexPath,
      destinationIndexPath: destinationIndexPath,
      planPath: planPath,
      cacheFormatVersion: codexTransferCacheFormatVersion,
      includeGitMetadata: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies,
      usedVerifiedCache: true,
      plannedEntryByteCount: 0
    )
    try? writeCodexIndexArtifact(refreshedDestinationIndex, to: destinationIndexPath)
    try? writeCodexIndexArtifact(plan, to: planPath)
    progress?("Verified saved index", sourceEntries.count, plan.sourceByteCount)
    return plan
  }

  private nonisolated static func buildCodexTransferPlan(
    project: CodexProjectEntry,
    outputRoot: String,
    mode: CodexProjectTransferMode,
    destinationPath resolvedDestinationPath: String?,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool,
    fullChecksumAudit: Bool,
    environment: [String: String],
    progress: ((String, Int, Int64) -> Void)? = nil
  ) throws -> CodexTransferPlan {
    let fm = FileManager.default
    let indexDirectory = try codexIndexDirectory(outputRoot: outputRoot, projectName: project.name, projectPath: project.path)
    let destinationPath = mode.writesDestination ? resolvedDestinationPath : nil
    if mode.writesDestination, destinationPath == nil {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "The transfer destination for \(project.name) was not resolved during preflight."])
    }
    if let cachedPlan = cachedCodexTransferPlanIfCurrent(
      project: project,
      outputRoot: outputRoot,
      mode: mode,
      destinationPath: destinationPath,
      includeGit: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies,
      fullChecksumAudit: fullChecksumAudit,
      environment: environment,
      progress: progress
    ) {
      return cachedPlan
    }
    progress?("Indexing source", 0, 0)
    let sourceIndex = try buildCodexFileIndex(
      root: project.path,
      includeGit: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies
    ) { count, bytes in
      progress?("Indexing source", count, bytes)
    }
    let sourceIndexPath = (indexDirectory as NSString).appendingPathComponent("source-index.json")
    try writeCodexIndexArtifact(sourceIndex, to: sourceIndexPath)

    let destinationExists = destinationPath.map { fm.fileExists(atPath: $0) } ?? false
    var destinationIndex: CodexFileIndexSnapshot?
    var destinationIndexPath: String?
    if let destinationPath, destinationExists {
      progress?("Indexing destination", 0, 0)
      let index = try buildCodexFileIndex(
        root: destinationPath,
        includeGit: includeGit,
        includeFinderMetadata: includeFinderMetadata,
        includeDependencies: includeDependencies
      ) { count, bytes in
        progress?("Indexing destination", count, bytes)
      }
      let path = (indexDirectory as NSString).appendingPathComponent("destination-index.json")
      try writeCodexIndexArtifact(index, to: path)
      destinationIndex = index
      destinationIndexPath = path
    }

    let sourceEntries = sourceIndex.entries.filter { !isCodexManagedHandoffPath($0.relativePath) }
    let sourceEntriesByPath = Dictionary(uniqueKeysWithValues: sourceEntries.map { ($0.relativePath, $0) })
    let destinationEntries = destinationIndex?.entries.filter { !isCodexManagedHandoffPath($0.relativePath) } ?? []
    let destinationEntriesByPath = Dictionary(uniqueKeysWithValues: destinationEntries.map { ($0.relativePath, $0) })
    var missingPaths: [String] = []
    var metadataChangedPaths: [String] = []
    var checksumChangedPaths: [String] = []
    var destinationOnlyPaths: [String] = []
    var typeConflictPaths: [String] = []
    var metadataMatchedPaths: [String] = []
    var checksumAuditPaths: [String] = []

    if destinationPath != nil && !destinationExists {
      missingPaths = sourceEntries.map(\.relativePath)
    } else if destinationPath != nil {
      for entry in sourceEntries {
        guard let destinationEntry = destinationEntriesByPath[entry.relativePath] else {
          missingPaths.append(entry.relativePath)
          continue
        }
        guard entry.kind == destinationEntry.kind else {
          typeConflictPaths.append(entry.relativePath)
          continue
        }
        if entry.kind == .directory {
          metadataMatchedPaths.append(entry.relativePath)
          continue
        }
        if entry.isMetadataEquivalent(to: destinationEntry) {
          metadataMatchedPaths.append(entry.relativePath)
          checksumAuditPaths.append(entry.relativePath)
        } else {
          metadataChangedPaths.append(entry.relativePath)
        }
      }
      destinationOnlyPaths = destinationEntries
        .map(\.relativePath)
        .filter { sourceEntriesByPath[$0] == nil }
        .sorted()

      if fullChecksumAudit, let destinationPath, !checksumAuditPaths.isEmpty {
        progress?("Checksum-auditing metadata matches", checksumAuditPaths.count, sourceIndex.byteCount)
        _ = try materializeCodexSourceFiles(
          sourceRoot: project.path,
          sourceIndex: sourceIndex,
          relativePaths: checksumAuditPaths,
          outputRoot: outputRoot,
          projectName: project.name,
          environment: environment
        ) { completed, total, bytes in
          progress?("Downloading iCloud files \(completed)/\(total)", completed, bytes)
        }
        let exclusions = codexRsyncExclusions(
          includeGit: includeGit,
          includeFinderMetadata: includeFinderMetadata,
          includeDependencies: includeDependencies
        )
        checksumChangedPaths = Array(
          try rsyncChangedPaths(
            source: project.path,
            destination: destinationPath,
            exclusions: exclusions,
            protectedPaths: [],
            environment: environment,
            useChecksums: true,
            filePaths: checksumAuditPaths,
            manifestOutputRoot: outputRoot,
            manifestProjectName: project.name,
            manifestLabel: "deep-checksum"
          )
        ).sorted()
      }
    }

    let plannedPaths = Array(
      Set(missingPaths + metadataChangedPaths + checksumChangedPaths + typeConflictPaths)
    )
    let plannedEntryByteCount = plannedPaths.reduce(Int64(0)) { total, path in
      total + (sourceEntriesByPath[path]?.byteCount ?? 0)
    }
    let planPath = (indexDirectory as NSString).appendingPathComponent("transfer-plan.json")
    let plan = CodexTransferPlan(
      projectName: project.name,
      projectPath: project.path,
      destinationPath: destinationPath,
      createdAt: Date(),
      sourceFileCount: sourceEntries.count,
      sourceByteCount: sourceEntries.reduce(0) { $0 + $1.byteCount },
      destinationFileCount: destinationEntries.count,
      destinationByteCount: destinationEntries.reduce(0) { $0 + $1.byteCount },
      requiresInitialMirror: destinationPath != nil && !destinationExists,
      missingPaths: missingPaths.sorted(),
      metadataChangedPaths: metadataChangedPaths.sorted(),
      checksumChangedPaths: checksumChangedPaths.sorted(),
      destinationOnlyPaths: destinationOnlyPaths,
      typeConflictPaths: typeConflictPaths.sorted(),
      metadataMatchedCount: metadataMatchedPaths.count,
      fullChecksumAudit: fullChecksumAudit,
      sourceIndexPath: sourceIndexPath,
      destinationIndexPath: destinationIndexPath,
      planPath: planPath,
      cacheFormatVersion: codexTransferCacheFormatVersion,
      includeGitMetadata: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies,
      usedVerifiedCache: false,
      plannedEntryByteCount: plannedEntryByteCount
    )
    try writeCodexIndexArtifact(plan, to: planPath)
    return plan
  }

  private nonisolated static func writeCodexStage1Receipt(
    project: CodexProjectEntry,
    outcome: CodexProjectTransferOutcome,
    transferPlan: CodexTransferPlan,
    outputRoot: String,
    mode: CodexProjectTransferMode,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool
  ) throws -> String {
    let receiptDirectory = ((outputRoot as NSString).appendingPathComponent("_temp") as NSString)
      .appendingPathComponent("Transfer-Receipts")
    try FileManager.default.createDirectory(atPath: receiptDirectory, withIntermediateDirectories: true, attributes: nil)
    let safeName = project.name
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
    let receiptPath = (receiptDirectory as NSString)
      .appendingPathComponent("\(timestampStamp())-\(safeName)-\(UUID().uuidString).receipt")
    let repository = casedCodexGitHubRepositoryIdentifier(project.remoteURL) ?? ""
    let values: [(String, String)] = [
      ("format", "1"),
      ("stage", "1"),
      ("status", outcome.currentSourcePath == nil ? "source-deleted" : "verified-source-kept"),
      ("transaction", UUID().uuidString),
      ("project_name", project.name),
      ("repository", repository),
      ("source_root", (project.path as NSString).deletingLastPathComponent),
      ("original_source", outcome.originalSourcePath),
      ("current_source", outcome.currentSourcePath ?? ""),
      ("destination", outcome.destinationPath ?? ""),
      ("backup", outcome.backupPath ?? ""),
      ("archive", outcome.archivePath ?? ""),
      ("mode", mode.rawValue),
      ("include_git", includeGit ? "1" : "0"),
      ("include_finder", includeFinderMetadata ? "1" : "0"),
      ("include_dependencies", includeDependencies ? "1" : "0"),
      ("content_verification", "full-checksum"),
      ("deletion_eligible", (!project.hasGit || includeGit) ? "1" : "0"),
      ("zip_authoritative", "0"),
      ("cleanup_owner", "stage3"),
      ("plan", transferPlan.planPath),
      ("source_index", transferPlan.sourceIndexPath),
      ("destination_index", transferPlan.destinationIndexPath ?? ""),
      ("verified_at", ISO8601DateFormatter().string(from: Date()))
    ]
    guard values.allSatisfy({ !$0.1.contains("\n") && !$0.1.contains("\r") }) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "A Stage 1 receipt value contains an unsupported line break."])
    }
    let receipt = values.map { "\($0.0)=\($0.1)" }.joined(separator: "\n") + "\n"
    try receipt.write(toFile: receiptPath, atomically: true, encoding: .utf8)
    return receiptPath
  }

  private nonisolated static func performCodexTransfer(
    project: CodexProjectEntry,
    outputRoot: String,
    mode: CodexProjectTransferMode,
    createBackup: Bool,
    backupMedium: CodexBackupMedium,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool,
    createCompatibilityLink: Bool,
    rearmGitMain: Bool,
    autoResumeExisting: Bool,
    transferPlan: CodexTransferPlan,
    environment: [String: String]
  ) throws -> CodexProjectTransferOutcome {
    let fm = FileManager.default
    let stamp = timestampStamp()
    let safeName = project.name.replacingOccurrences(of: "/", with: "-")
    let transactionRoot = ((outputRoot as NSString)
      .appendingPathComponent("_temp") as NSString)
      .appendingPathComponent("CSA-iEM-Codex-\(safeName)-\(UUID().uuidString)")
    let stagedProject = (transactionRoot as NSString).appendingPathComponent(safeName)
    let backupRoot = ((outputRoot as NSString)
      .appendingPathComponent("backup") as NSString)
      .appendingPathComponent("\(safeName)-\(stamp)")
    var warnings: [String] = []
    var archivePath: String?
    var currentSourcePath: String? = project.path

    let exclusions = codexRsyncExclusions(
      includeGit: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies
    )

    let destinationPath = mode.writesDestination ? transferPlan.destinationPath : nil
    let destination = destinationPath
    if mode.performsBidirectionalSync,
       let destinationPath,
       fm.fileExists(atPath: destinationPath),
       autoResumeExisting {
      try? fm.removeItem(atPath: transactionRoot)
      return try performCodexBidirectionalSync(
        project: project,
        destination: destinationPath,
        createBackup: createBackup,
        backupMedium: backupMedium,
        includeGit: includeGit,
        includeFinderMetadata: includeFinderMetadata,
        includeDependencies: includeDependencies,
        createCompatibilityLink: createCompatibilityLink,
        rearmGitMain: rearmGitMain,
        transferPlan: transferPlan,
        exclusions: exclusions,
        environment: environment
      )
    }
    if autoResumeExisting, let destination, fm.fileExists(atPath: destination) {
      try? fm.removeItem(atPath: transactionRoot)
      return try performCodexResumeTransfer(
        project: project,
        destination: destination,
        mode: mode,
        createBackup: createBackup,
        backupMedium: backupMedium,
        includeGit: includeGit,
        includeFinderMetadata: includeFinderMetadata,
        includeDependencies: includeDependencies,
        createCompatibilityLink: createCompatibilityLink,
        rearmGitMain: rearmGitMain,
        transferPlan: transferPlan,
        exclusions: exclusions,
        environment: environment
      )
    }

    try fm.createDirectory(atPath: stagedProject, withIntermediateDirectories: true, attributes: nil)

    // External APFS volumes with ownership disabled cannot faithfully apply
    // source uid/gid/mode metadata. Preserve file contents and Git data while
    // avoiding metadata stalls on iCloud-backed source trees.
    var copyArguments = ["-a", "--no-owner", "--no-group", "--no-perms", "--timeout=120", "--rsync-path=/usr/bin/rsync", "--delete"] + exclusions
    copyArguments.append(project.path.hasSuffix("/") ? project.path : project.path + "/")
    copyArguments.append(stagedProject + "/")
    var copyEnvironment = environment
    copyEnvironment["COPYFILE_DISABLE"] = "1"
    let copyResult = runCodexRsync(arguments: copyArguments, environment: copyEnvironment)
    guard copyResult.status == 0 else {
      throw NSError(domain: appTitle, code: Int(copyResult.status), userInfo: [NSLocalizedDescriptionKey: "Staging failed for \(project.name): \(redactSensitiveText(copyResult.output))"])
    }

    let transferNote = codexTransferNote(
      project: project,
      destination: destinationPath,
      backupRoot: createBackup ? backupRoot : nil,
      includeGit: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies,
      rearmGitMain: rearmGitMain,
      mode: mode
    )
    let promptInject = codexPromptInject(
      project: project,
      destination: destinationPath,
      rearmGitMain: rearmGitMain
    )
    try transferNote.write(toFile: (stagedProject as NSString).appendingPathComponent("Transfer_Note.MD"), atomically: true, encoding: String.Encoding.utf8)
    try promptInject.write(toFile: (stagedProject as NSString).appendingPathComponent("Prompt_Inject.MD"), atomically: true, encoding: String.Encoding.utf8)

    var verifyArguments = ["-rcln", "--no-owner", "--no-group", "--no-perms", "--timeout=120", "--rsync-path=/usr/bin/rsync", "--delete"] + exclusions
    verifyArguments.append(project.path.hasSuffix("/") ? project.path : project.path + "/")
    verifyArguments.append(stagedProject + "/")
    let verifyResult = runCodexRsync(arguments: verifyArguments, environment: copyEnvironment)
    let verifyOutput = verifyResult.output
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .filter {
        !$0.hasSuffix("Transfer_Note.MD") &&
          !$0.hasSuffix("Prompt_Inject.MD") &&
          !$0.hasPrefix("skipping non-regular file ")
      }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard verifyResult.status == 0, verifyOutput.isEmpty else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Checksum verification failed for \(project.name). Staging was retained at \(transactionRoot)."])
    }

    if createBackup {
      try fm.createDirectory(atPath: backupRoot, withIntermediateDirectories: true, attributes: nil)
      try transferNote.write(toFile: (backupRoot as NSString).appendingPathComponent("Transfer_Note.MD"), atomically: true, encoding: String.Encoding.utf8)
      try promptInject.write(toFile: (backupRoot as NSString).appendingPathComponent("Prompt_Inject.MD"), atomically: true, encoding: String.Encoding.utf8)
      archivePath = try createCodexBackup(
        source: stagedProject,
        backupRoot: backupRoot,
        baseName: "\(safeName)-source",
        medium: backupMedium,
        environment: environment,
        label: "source backup for \(project.name)"
      )
      /*
      let zipResult = runCommand(
        executable: "/usr/bin/ditto",
        arguments: ["-c", "-k", "--keepParent", stagedProject, zipPath],
        environment: copyEnvironment
      )
      guard zipResult.status == 0 else {
        throw NSError(domain: appTitle, code: Int(zipResult.status), userInfo: [NSLocalizedDescriptionKey: "ZIP backup failed for \(project.name): \(redactSensitiveText(zipResult.output))"])
      }
      let zipVerify = runCommand(executable: "/usr/bin/unzip", arguments: ["-tq", zipPath], environment: environment)
      guard zipVerify.status == 0 else {
        throw NSError(domain: appTitle, code: Int(zipVerify.status), userInfo: [NSLocalizedDescriptionKey: "ZIP verification failed for \(project.name)."])
      }
      */

      if includeGit && project.hasGit {
        let gitArchive = (backupRoot as NSString).appendingPathComponent("git-metadata.tar")
        let gitArchiveResult = runCommand(
          executable: "/bin/zsh",
          arguments: ["-lc", "cd \(shellQuote(project.path)) && /usr/bin/tar -cpf \(shellQuote(gitArchive)) .git"],
          environment: copyEnvironment
        )
        if gitArchiveResult.status != 0 {
          warnings.append("Raw .git archive could not be created; the verified source ZIP remains available.")
        }
      }
    }

    if mode.writesDestination {
      guard let destination = destinationPath else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "The planned destination for \(project.name) is missing."])
      }
      guard !fm.fileExists(atPath: destination) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination appeared during transfer: \(destination)"])
      }
      try fm.moveItem(atPath: stagedProject, toPath: destination)
      var parkedSourcePath: String?
      do {
        _ = try preserveCodexSourceRecovery(
          source: project.path,
          destination: destination,
          safeName: safeName,
          stamp: stamp,
          environment: environment
        )

        if environment["CSA_IEM_TEST_FAIL_AFTER_DESTINATION_PROMOTION"] == "1" {
          throw NSError(domain: appTitle, code: 99, userInfo: [NSLocalizedDescriptionKey: "Injected post-promotion failure for rollback verification."])
        }

        if rearmGitMain {
          guard let remoteURL = project.remoteURL, !remoteURL.isEmpty else {
            throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Git main re-arm requires a detected remote for \(project.name)."])
          }
          try rearmGitMainAtDestination(destination: destination, remoteURL: remoteURL, environment: environment)
        }

        var finalVerifyArguments = ["-rcln", "--no-owner", "--no-group", "--no-perms", "--timeout=120", "--rsync-path=/usr/bin/rsync", "--delete"] + exclusions
        finalVerifyArguments.append(project.path.hasSuffix("/") ? project.path : project.path + "/")
        finalVerifyArguments.append(destination + "/")
        let finalVerify = runCodexRsync(arguments: finalVerifyArguments, environment: copyEnvironment)
        let finalVerifyOutput = finalVerify.output
          .split(whereSeparator: \.isNewline)
          .map(String.init)
          .filter {
            !$0.hasSuffix("Transfer_Note.MD") &&
              !$0.hasSuffix("Prompt_Inject.MD") &&
              !$0.hasPrefix("skipping non-regular file ")
          }
          .joined(separator: "\n")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        guard finalVerify.status == 0, finalVerifyOutput.isEmpty else {
          throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Final verification failed for \(project.name). The source was not removed."])
        }

        if mode.removesSource {
          let parkedSource = project.path + ".csa-iem-source-\(stamp)"
          try fm.moveItem(atPath: project.path, toPath: parkedSource)
          parkedSourcePath = parkedSource
          currentSourcePath = parkedSource
          if createCompatibilityLink {
            do {
              try fm.createSymbolicLink(atPath: project.path, withDestinationPath: destination)
            } catch {
              try? fm.moveItem(atPath: parkedSource, toPath: project.path)
              parkedSourcePath = nil
              throw error
            }
          }
          warnings.append("The verified source is parked at \(parkedSource) pending receipt-linked Stage 3 cleanup.")
        }
      } catch {
        try? rollbackCodexPromotion(destination: destination, originalSource: project.path, parkedSource: parkedSourcePath)
        throw error
      }
    }

    try? fm.removeItem(atPath: transactionRoot)
    return CodexProjectTransferOutcome(
      projectName: project.name,
      originalSourcePath: project.path,
      currentSourcePath: currentSourcePath,
      destinationPath: destinationPath,
      backupPath: createBackup ? backupRoot : nil,
      archivePath: archivePath,
      warnings: warnings,
      resumedExistingDestination: false,
      reconciledFileCount: transferPlan.plannedPaths.count,
      conflictCount: 0
    )
  }

  /// Rolls back a newly promoted destination when a later verification or
  /// source-retirement step fails. The destination is known to be new in this
  /// transaction; a parked source is restored before the failure is surfaced.
  nonisolated static func rollbackCodexPromotion(destination: String, originalSource: String, parkedSource: String?) throws {
    let fm = FileManager.default
    if let parkedSource, fm.fileExists(atPath: parkedSource) {
      if fm.fileExists(atPath: originalSource) || (try? fm.destinationOfSymbolicLink(atPath: originalSource)) != nil {
        try fm.removeItem(atPath: originalSource)
      }
      try fm.moveItem(atPath: parkedSource, toPath: originalSource)
    }
    if fm.fileExists(atPath: destination) || (try? fm.destinationOfSymbolicLink(atPath: destination)) != nil {
      try fm.removeItem(atPath: destination)
    }
  }

  private nonisolated static func performCodexBidirectionalSync(
    project: CodexProjectEntry,
    destination: String,
    createBackup: Bool,
    backupMedium: CodexBackupMedium,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool,
    createCompatibilityLink: Bool,
    rearmGitMain: Bool,
    transferPlan: CodexTransferPlan,
    exclusions: [String],
    environment: [String: String]
  ) throws -> CodexProjectTransferOutcome {
    let fm = FileManager.default
    let stamp = timestampStamp()
    let safeName = project.name.replacingOccurrences(of: "/", with: "-")
    let outputRoot = (destination as NSString).deletingLastPathComponent
    let backupRoot = ((outputRoot as NSString).appendingPathComponent("backup") as NSString)
      .appendingPathComponent("\(safeName)-\(stamp)")
    let conflictRoot = ((outputRoot as NSString).appendingPathComponent("_temp") as NSString)
      .appendingPathComponent("CSA-iEM-conflicts-\(safeName)-\(stamp)")
    var warnings: [String] = []
    var archivePath: String?
    guard transferPlan.projectPath == project.path, transferPlan.destinationPath == destination else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "The transfer plan no longer matches \(project.name). Run Preflight again before synchronizing both folders."])
    }

    let sourceCandidates = try rsyncChangedPaths(
      source: project.path,
      destination: destination,
      exclusions: exclusions,
      protectedPaths: [] as Set<String>,
      environment: environment,
      useChecksums: true
    )
    let destinationCandidates = try rsyncChangedPaths(
      source: destination,
      destination: project.path,
      exclusions: exclusions,
      protectedPaths: [] as Set<String>,
      environment: environment,
      useChecksums: true
    )
    let candidates = sourceCandidates.union(destinationCandidates)

    var sourceWins: Set<String> = []
    var destinationWins: Set<String> = []
    var conflicts: Set<String> = []

    for relativePath in candidates.sorted() {
      let sourcePath = (project.path as NSString).appendingPathComponent(relativePath)
      let destinationPath = (destination as NSString).appendingPathComponent(relativePath)
      var sourceIsDirectory: ObjCBool = false
      var destinationIsDirectory: ObjCBool = false
      let sourceExists = fm.fileExists(atPath: sourcePath, isDirectory: &sourceIsDirectory)
      let destinationExists = fm.fileExists(atPath: destinationPath, isDirectory: &destinationIsDirectory)

      if sourceExists && !destinationExists {
        sourceWins.insert(relativePath)
        continue
      }
      if destinationExists && !sourceExists {
        destinationWins.insert(relativePath)
        continue
      }
      guard sourceExists && destinationExists else { continue }

      if sourceIsDirectory.boolValue || destinationIsDirectory.boolValue {
        if sourceIsDirectory.boolValue && destinationIsDirectory.boolValue {
          continue
        }
        conflicts.insert(relativePath)
        continue
      }

      let sourceAttributes = try? fm.attributesOfItem(atPath: sourcePath)
      let destinationAttributes = try? fm.attributesOfItem(atPath: destinationPath)
      let sourceSize = (sourceAttributes?[.size] as? NSNumber)?.int64Value ?? -1
      let destinationSize = (destinationAttributes?[.size] as? NSNumber)?.int64Value ?? -1
      let sourceDate = sourceAttributes?[.modificationDate] as? Date ?? .distantPast
      let destinationDate = destinationAttributes?[.modificationDate] as? Date ?? .distantPast

      if sourceSize == destinationSize,
         abs(sourceDate.timeIntervalSince(destinationDate)) < 0.5,
         codexFilesEqual(sourcePath, destinationPath, environment: environment) {
        continue
      }
      if sourceDate.timeIntervalSince(destinationDate) > 1 {
        sourceWins.insert(relativePath)
      } else if destinationDate.timeIntervalSince(sourceDate) > 1 {
        destinationWins.insert(relativePath)
      } else if sourceSize == destinationSize,
                codexFilesEqual(sourcePath, destinationPath, environment: environment) {
        continue
      } else {
        conflicts.insert(relativePath)
      }
    }

    if createBackup {
      try fm.createDirectory(atPath: backupRoot, withIntermediateDirectories: true, attributes: nil)
      let sourceArchive = try createCodexBackup(
        source: project.path,
        backupRoot: backupRoot,
        baseName: "\(safeName)-source-before-sync",
        medium: backupMedium,
        environment: environment,
        label: "source backup for \(project.name)"
      )
      archivePath = sourceArchive
      _ = try createCodexBackup(
        source: destination,
        backupRoot: backupRoot,
        baseName: "\(safeName)-destination-before-sync",
        medium: backupMedium,
        environment: environment,
        label: "destination backup for \(project.name)"
      )
    }

    let sourceProtected = destinationWins.union(conflicts)
    let destinationProtected = sourceWins.union(conflicts)
    try applyRsyncMerge(
      source: project.path,
      destination: destination,
      exclusions: exclusions,
      protectedPaths: sourceProtected,
      environment: environment,
      label: "source-to-destination",
      transferPaths: sourceWins,
      manifestOutputRoot: outputRoot,
      manifestProjectName: project.name
    )
    try applyRsyncMerge(
      source: destination,
      destination: project.path,
      exclusions: exclusions,
      protectedPaths: destinationProtected,
      environment: environment,
      label: "destination-to-source",
      transferPaths: destinationWins,
      manifestOutputRoot: outputRoot,
      manifestProjectName: project.name
    )

    // Fast Mode may use metadata to build its transfer plan, but every merge
    // is checksum-audited before conflicts are finalized or a receipt exists.
    let exactDifferences = try codexFullChecksumDifferences(
      source: project.path,
      destination: destination,
      exclusions: exclusions,
      protectedPaths: conflicts,
      environment: environment
    )
    conflicts.formUnion(exactDifferences)

    if !conflicts.isEmpty {
      for relativePath in conflicts.sorted() {
        let sourcePath = (project.path as NSString).appendingPathComponent(relativePath)
        let destinationPath = (destination as NSString).appendingPathComponent(relativePath)
        try copyConflictSide(
          sourcePath: sourcePath,
          conflictRoot: conflictRoot,
          side: "source",
          relativePath: relativePath
        )
        try copyConflictSide(
          sourcePath: destinationPath,
          conflictRoot: conflictRoot,
          side: "destination",
          relativePath: relativePath
        )
      }
      let report = """
      # CSA-iEM Sync Conflict Report

      Generated by CSA-iEM \(appVersion) on \(Date().formatted(date: .numeric, time: .standard)).

      Neither side was overwritten for the paths below. The source and destination copies are under this report's `source/` and `destination/` folders.

      - Project: \(project.name)
      - Source: \(project.path)
      - Destination: \(destination)
      - Conflict count: \(conflicts.count)

      ## Conflicts

      \(conflicts.sorted().map { "- `\($0)`" }.joined(separator: "\n"))
      """
      try fm.createDirectory(atPath: conflictRoot, withIntermediateDirectories: true, attributes: nil)
      try report.write(
        toFile: (conflictRoot as NSString).appendingPathComponent("Conflict_Report.MD"),
        atomically: true,
        encoding: .utf8
      )
      warnings.append("\(conflicts.count) conflict(s) were preserved at \(conflictRoot).")
    }

    if rearmGitMain {
      guard let remoteURL = project.remoteURL, !remoteURL.isEmpty else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Git main re-arm requires a detected remote for \(project.name)."])
      }
      try rearmGitMainAtDestination(destination: destination, remoteURL: remoteURL, environment: environment)
    }

    let transferNote = codexTransferNote(
      project: project,
      destination: destination,
      backupRoot: createBackup ? backupRoot : nil,
      includeGit: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies,
      rearmGitMain: rearmGitMain,
      mode: .syncAndSync
    )
    let promptInject = codexPromptInject(project: project, destination: destination, rearmGitMain: rearmGitMain)
    try transferNote.write(toFile: (destination as NSString).appendingPathComponent("Transfer_Note.MD"), atomically: true, encoding: String.Encoding.utf8)
    try promptInject.write(toFile: (destination as NSString).appendingPathComponent("Prompt_Inject.MD"), atomically: true, encoding: String.Encoding.utf8)
    if createBackup {
      try transferNote.write(toFile: (backupRoot as NSString).appendingPathComponent("Transfer_Note.MD"), atomically: true, encoding: String.Encoding.utf8)
      try promptInject.write(toFile: (backupRoot as NSString).appendingPathComponent("Prompt_Inject.MD"), atomically: true, encoding: String.Encoding.utf8)
    }

    let forwardVerify = try codexFullChecksumDifferences(
      source: project.path,
      destination: destination,
      exclusions: exclusions,
      protectedPaths: conflicts,
      environment: environment
    )
    let reverseVerify = try codexFullChecksumDifferences(
      source: destination,
      destination: project.path,
      exclusions: exclusions,
      protectedPaths: conflicts,
      environment: environment
    )
    guard forwardVerify.isEmpty && reverseVerify.isEmpty else {
      throw NSError(
        domain: appTitle,
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Full checksum sync verification found unresolved non-conflict differences for \(project.name). Both folders were retained and no deletion-capable receipt was written."]
      )
    }

    return CodexProjectTransferOutcome(
      projectName: project.name,
      originalSourcePath: project.path,
      currentSourcePath: project.path,
      destinationPath: destination,
      backupPath: createBackup ? backupRoot : nil,
      archivePath: archivePath,
      warnings: warnings,
      resumedExistingDestination: true,
      reconciledFileCount: sourceWins.count + destinationWins.count,
      conflictCount: conflicts.count
    )
  }

  private nonisolated static func isTransientCodexRsyncFailure(_ output: String) -> Bool {
    let lower = output.lowercased()
    return lower.contains("operation canceled") ||
      lower.contains("resource temporarily unavailable") ||
      lower.contains("connection reset by peer") ||
      lower.contains("connection unexpectedly closed") ||
      lower.contains("rsync error: timeout") ||
      lower.contains("mmap")
  }

  private nonisolated static func runCodexRsync(
    arguments: [String],
    environment: [String: String],
    maxAttempts: Int = 3
  ) -> CommandResult {
    var result = CommandResult(status: 1, output: "Rsync did not start.")
    for attempt in 1...max(1, maxAttempts) {
      result = runCommand(
        executable: "/usr/bin/rsync",
        arguments: arguments,
        environment: environment
      )
      guard result.status != 0,
            attempt < maxAttempts,
            isTransientCodexRsyncFailure(result.output) else {
        return result
      }
      Thread.sleep(forTimeInterval: Double(attempt * 2))
    }
    return result
  }

  private nonisolated static func rsyncChangedPaths(
    source: String,
    destination: String,
    exclusions: [String],
    protectedPaths: Set<String>,
    environment: [String: String],
    useChecksums: Bool = false,
    filePaths: [String]? = nil,
    manifestOutputRoot: String? = nil,
    manifestProjectName: String? = nil,
    manifestLabel: String = "scan"
  ) throws -> Set<String> {
    var arguments = [
      useChecksums ? "-acn" : "-an",
      "--no-owner",
      "--no-group",
      "--no-perms",
      "--timeout=120",
      "--rsync-path=/usr/bin/rsync",
      "--out-format=%n"
    ] + exclusions
    arguments.append(contentsOf: protectedPaths.sorted().map { "--exclude=/\($0)" })
    if let filePaths {
      guard !filePaths.isEmpty else { return [] }
      guard let manifestOutputRoot, let manifestProjectName else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "A targeted rsync scan needs an output folder for its path manifest."])
      }
      let manifest = try writeCodexPathList(
        filePaths,
        outputRoot: manifestOutputRoot,
        projectName: manifestProjectName,
        label: manifestLabel
      )
      arguments.append("--files-from=\(manifest)")
    }
    arguments.append(source.hasSuffix("/") ? source : source + "/")
    arguments.append(destination.hasSuffix("/") ? destination : destination + "/")
    var commandEnvironment = environment
    commandEnvironment["COPYFILE_DISABLE"] = "1"
    let result = runCodexRsync(arguments: arguments, environment: commandEnvironment)
    guard result.status == 0 else {
      throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Rsync scan failed between \(source) and \(destination): \(redactSensitiveText(result.output))"])
    }

    var paths: Set<String> = []
    for rawLine in result.output.split(whereSeparator: \.isNewline) {
      var line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty,
            line != ".",
            line != "./",
            !line.hasPrefix("sending incremental file list"),
            !line.hasPrefix("receiving incremental file list"),
            !line.hasPrefix("delta-transmission"),
            !line.hasPrefix("skipping non-regular file "),
            !line.hasPrefix("sent "),
            !line.hasPrefix("received "),
            !line.hasPrefix("total size is ") else { continue }
      while line.hasPrefix("./") {
        line.removeFirst(2)
      }
      while line.hasSuffix("/") {
        line.removeLast()
      }
      guard !line.isEmpty, !line.hasPrefix("/"), line != "..", !line.hasPrefix("../") else { continue }
      paths.insert(line)
    }
    return paths
  }

  private nonisolated static func applyTargetedCodexRsync(
    source: String,
    destination: String,
    plannedPaths: [String],
    exclusions: [String],
    environment: [String: String],
    outputRoot: String,
    projectName: String,
    label: String
  ) throws -> Int {
    guard !plannedPaths.isEmpty else { return 0 }
    let manifest = try writeCodexPathList(
      plannedPaths,
      outputRoot: outputRoot,
      projectName: projectName,
      label: label
    )
    var arguments = [
      "-a",
      "--no-owner",
      "--no-group",
      "--no-perms",
      "--timeout=120",
      "--rsync-path=/usr/bin/rsync",
      "--partial",
      "--stats",
      "--files-from=\(manifest)"
    ] + exclusions
    arguments.append(source.hasSuffix("/") ? source : source + "/")
    arguments.append(destination.hasSuffix("/") ? destination : destination + "/")
    var commandEnvironment = environment
    commandEnvironment["COPYFILE_DISABLE"] = "1"
    let result = runCodexRsync(arguments: arguments, environment: commandEnvironment)
    guard result.status == 0 else {
      throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Targeted rsync failed during \(label): \(redactSensitiveText(result.output))"])
    }
    return rsyncTransferredFileCount(result.output)
  }

  private nonisolated static func applyRsyncMerge(
    source: String,
    destination: String,
    exclusions: [String],
    protectedPaths: Set<String>,
    environment: [String: String],
    label: String,
    transferPaths: Set<String>? = nil,
    manifestOutputRoot: String? = nil,
    manifestProjectName: String? = nil
  ) throws {
    if let transferPaths, transferPaths.isEmpty {
      return
    }
    var arguments = [
      "-ac",
      "--no-owner",
      "--no-group",
      "--no-perms",
      "--timeout=120",
      "--rsync-path=/usr/bin/rsync",
      "--partial"
    ] + exclusions
    arguments.append(contentsOf: protectedPaths.sorted().map { "--exclude=/\($0)" })
    if let transferPaths {
      guard let manifestOutputRoot, let manifestProjectName else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "A targeted sync needs an output folder for its path manifest."])
      }
      let manifest = try writeCodexPathList(
        Array(transferPaths),
        outputRoot: manifestOutputRoot,
        projectName: manifestProjectName,
        label: label
      )
      arguments.append("--files-from=\(manifest)")
    }
    arguments.append(source.hasSuffix("/") ? source : source + "/")
    arguments.append(destination.hasSuffix("/") ? destination : destination + "/")
    var commandEnvironment = environment
    commandEnvironment["COPYFILE_DISABLE"] = "1"
    let result = runCodexRsync(arguments: arguments, environment: commandEnvironment)
    guard result.status == 0 else {
      throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Sync failed during \(label): \(redactSensitiveText(result.output))"])
    }
  }

  private nonisolated static func codexFilesEqual(
    _ lhs: String,
    _ rhs: String,
    environment: [String: String]
  ) -> Bool {
    runCommand(executable: "/usr/bin/cmp", arguments: ["-s", lhs, rhs], environment: environment).status == 0
  }

  private nonisolated static func codexFullChecksumDifferences(
    source: String,
    destination: String,
    exclusions: [String],
    protectedPaths: Set<String>,
    environment: [String: String]
  ) throws -> Set<String> {
    let rawDifferences = try rsyncChangedPaths(
      source: source,
      destination: destination,
      exclusions: exclusions,
      protectedPaths: protectedPaths,
      environment: environment,
      useChecksums: true
    )
    return codexContentDifferences(
      Set(rawDifferences.filter { !isCodexManagedHandoffPath($0) }),
      source: source,
      destination: destination
    )
  }

  private nonisolated static func codexContentDifferences(
    _ differences: Set<String>,
    source: String,
    destination: String
  ) -> Set<String> {
    let fm = FileManager.default
    return Set(differences.filter { relativePath in
      let sourcePath = (source as NSString).appendingPathComponent(relativePath)
      let destinationPath = (destination as NSString).appendingPathComponent(relativePath)
      var sourceIsDirectory: ObjCBool = false
      var destinationIsDirectory: ObjCBool = false
      let sourceExists = fm.fileExists(atPath: sourcePath, isDirectory: &sourceIsDirectory)
      let destinationExists = fm.fileExists(atPath: destinationPath, isDirectory: &destinationIsDirectory)
      let sourceIsSymbolicLink = (try? fm.destinationOfSymbolicLink(atPath: sourcePath)) != nil
      let destinationIsSymbolicLink = (try? fm.destinationOfSymbolicLink(atPath: destinationPath)) != nil

      // External filesystems can normalize directory timestamps when their
      // retained children differ. Directory-only drift does not represent a
      // content mismatch; symlinks and every non-directory path still do.
      return !(sourceExists && destinationExists &&
        sourceIsDirectory.boolValue && destinationIsDirectory.boolValue &&
        !sourceIsSymbolicLink && !destinationIsSymbolicLink)
    })
  }

  private nonisolated static func copyConflictSide(
    sourcePath: String,
    conflictRoot: String,
    side: String,
    relativePath: String
  ) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: sourcePath) else { return }
    let destinationPath = ((conflictRoot as NSString).appendingPathComponent(side) as NSString)
      .appendingPathComponent(relativePath)
    let parent = (destinationPath as NSString).deletingLastPathComponent
    try fm.createDirectory(atPath: parent, withIntermediateDirectories: true, attributes: nil)
    try fm.copyItem(atPath: sourcePath, toPath: destinationPath)
  }

  private nonisolated static func validatedCodexRelativePath(_ relativePath: String) throws -> String {
    let components = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard !relativePath.isEmpty,
          !relativePath.hasPrefix("/"),
          !components.contains(""),
          !components.contains("."),
          !components.contains(".."),
          !components.contains(".csa-iem-recovery") else {
      throw NSError(
        domain: appTitle,
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Unsafe recovery-relative path: \(relativePath)"]
      )
    }
    return components.joined(separator: "/")
  }

  private nonisolated static func codexPathExistsIncludingSymlink(_ path: String) -> Bool {
    FileManager.default.fileExists(atPath: path) ||
      (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
  }

  private nonisolated static func copyCodexRecoveryPathVerified(
    sourcePath: String,
    destinationPath: String,
    environment: [String: String]
  ) throws {
    let fm = FileManager.default
    guard codexPathExistsIncludingSymlink(sourcePath) else { return }
    guard !codexPathExistsIncludingSymlink(destinationPath) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Recovery target already exists: \(destinationPath)"])
    }
    try fm.createDirectory(
      atPath: (destinationPath as NSString).deletingLastPathComponent,
      withIntermediateDirectories: true,
      attributes: nil
    )
    let copy = runCommand(
      executable: "/usr/bin/ditto",
      arguments: [sourcePath, destinationPath],
      environment: environment
    )
    guard copy.status == 0 else {
      throw NSError(
        domain: appTitle,
        code: Int(copy.status),
        userInfo: [NSLocalizedDescriptionKey: "Recovery preservation failed: \(redactSensitiveText(copy.output))"]
      )
    }

    if let sourceTarget = try? fm.destinationOfSymbolicLink(atPath: sourcePath) {
      let destinationTarget = try fm.destinationOfSymbolicLink(atPath: destinationPath)
      guard sourceTarget == destinationTarget else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Recovery symlink verification failed: \(sourcePath)"])
      }
      return
    }
    var isDirectory: ObjCBool = false
    guard fm.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Recovery source disappeared: \(sourcePath)"])
    }
    if isDirectory.boolValue {
      let forward = try codexFullChecksumDifferences(
        source: sourcePath,
        destination: destinationPath,
        exclusions: [],
        protectedPaths: [],
        environment: environment
      )
      let reverse = try codexFullChecksumDifferences(
        source: destinationPath,
        destination: sourcePath,
        exclusions: [],
        protectedPaths: [],
        environment: environment
      )
      guard forward.isEmpty && reverse.isEmpty else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Recovery directory checksum verification failed: \(sourcePath)"])
      }
    } else {
      guard codexFilesEqual(sourcePath, destinationPath, environment: environment) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Recovery file checksum verification failed: \(sourcePath)"])
      }
    }
  }

  private nonisolated static func ensureCodexRecoveryExcluded(_ destination: String) throws {
    let fm = FileManager.default
    let excludePath = ((destination as NSString).appendingPathComponent(".git/info") as NSString)
      .appendingPathComponent("exclude")
    guard fm.fileExists(atPath: (destination as NSString).appendingPathComponent(".git")) else { return }
    try fm.createDirectory(
      atPath: (excludePath as NSString).deletingLastPathComponent,
      withIntermediateDirectories: true,
      attributes: nil
    )
    let existing = (try? String(contentsOfFile: excludePath, encoding: .utf8)) ?? ""
    let entry = "/.csa-iem-recovery/"
    guard !existing.split(whereSeparator: \.isNewline).map(String.init).contains(entry) else { return }
    let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
    try (existing + separator + entry + "\n").write(
      toFile: excludePath,
      atomically: true,
      encoding: .utf8
    )
  }

  private nonisolated static func preserveCodexSourceRecovery(
    source: String,
    destination: String,
    safeName: String,
    stamp: String,
    environment: [String: String]
  ) throws -> String? {
    let sourceRecovery = (source as NSString).appendingPathComponent(".csa-iem-recovery")
    guard codexPathExistsIncludingSymlink(sourceRecovery) else { return nil }
    let recoveryRoot = (((destination as NSString)
      .appendingPathComponent(".csa-iem-recovery/prior-recovery") as NSString)
      .appendingPathComponent("\(stamp)-\(UUID().uuidString)") as NSString)
      .appendingPathComponent(safeName)
    let snapshot = (recoveryRoot as NSString).appendingPathComponent("source-recovery")
    try copyCodexRecoveryPathVerified(
      sourcePath: sourceRecovery,
      destinationPath: snapshot,
      environment: environment
    )
    try ensureCodexRecoveryExcluded(destination)
    return snapshot
  }

  private nonisolated static func preserveCodexDestinationPaths(
    destination: String,
    relativePaths: [String],
    safeName: String,
    stamp: String,
    environment: [String: String]
  ) throws -> (root: String?, preservedRoots: [String]) {
    let fm = FileManager.default
    let safePaths = try Array(Set(relativePaths.map(validatedCodexRelativePath))).sorted {
      let leftCount = $0.split(separator: "/").count
      let rightCount = $1.split(separator: "/").count
      return leftCount == rightCount ? $0 < $1 : leftCount < rightCount
    }
    var roots: [String] = []
    for relativePath in safePaths {
      let sourcePath = (destination as NSString).appendingPathComponent(relativePath)
      guard codexPathExistsIncludingSymlink(sourcePath) else { continue }
      let isCovered = roots.contains { root in
        relativePath == root || relativePath.hasPrefix(root + "/")
      }
      if !isCovered { roots.append(relativePath) }
    }
    guard !roots.isEmpty else { return (nil, []) }
    let recoveryRoot = (((destination as NSString)
      .appendingPathComponent(".csa-iem-recovery/variants") as NSString)
      .appendingPathComponent("\(stamp)-\(UUID().uuidString)") as NSString)
      .appendingPathComponent(safeName)
    let snapshotRoot = (recoveryRoot as NSString).appendingPathComponent("destination-before-merge")
    for relativePath in roots {
      try copyCodexRecoveryPathVerified(
        sourcePath: (destination as NSString).appendingPathComponent(relativePath),
        destinationPath: (snapshotRoot as NSString).appendingPathComponent(relativePath),
        environment: environment
      )
    }
    let manifest: [String: Any] = [
      "format": 1,
      "destination": destination,
      "preservedPaths": roots,
      "contentVerification": "full-checksum"
    ]
    let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    try fm.createDirectory(atPath: recoveryRoot, withIntermediateDirectories: true, attributes: nil)
    try manifestData.write(
      to: URL(fileURLWithPath: (recoveryRoot as NSString).appendingPathComponent("manifest.json")),
      options: .atomic
    )
    try ensureCodexRecoveryExcluded(destination)
    return (recoveryRoot, roots)
  }

  private nonisolated static func createCodexBackup(
    source: String,
    backupRoot: String,
    baseName: String,
    medium: CodexBackupMedium,
    environment: [String: String],
    label: String
  ) throws -> String {
    let fm = FileManager.default
    try fm.createDirectory(atPath: backupRoot, withIntermediateDirectories: true, attributes: nil)
    let artifact: String
    switch medium {
    case .rawDirectory:
      artifact = (backupRoot as NSString).appendingPathComponent(baseName)
      let result = runCommand(executable: "/usr/bin/ditto", arguments: [source, artifact], environment: environment)
      guard result.status == 0 else {
        throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Raw directory backup failed for \(label): \(redactSensitiveText(result.output))"])
      }
    case .apfsClone:
      artifact = (backupRoot as NSString).appendingPathComponent(baseName)
      let result = runCommand(executable: "/bin/cp", arguments: ["-cR", source, artifact], environment: environment)
      guard result.status == 0 else {
        throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "APFS clone failed for \(label): \(redactSensitiveText(result.output))"])
      }
    case .sparseImage:
      artifact = (backupRoot as NSString).appendingPathComponent(baseName + ".sparseimage")
      let result = runCommand(executable: "/usr/bin/hdiutil", arguments: ["create", "-srcfolder", source, "-format", "UDSP", "-ov", artifact], environment: environment)
      guard result.status == 0 else {
        throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Sparse image backup failed for \(label): \(redactSensitiveText(result.output))"])
      }
    case .verifiedZip:
      artifact = (backupRoot as NSString).appendingPathComponent(baseName + ".zip")
      try createVerifiedCodexZip(source: source, zipPath: artifact, environment: environment, label: label)
      return artifact
    }

    if medium == .sparseImage {
      let mountPoint = (backupRoot as NSString).appendingPathComponent(".verify-\(UUID().uuidString)")
      try fm.createDirectory(atPath: mountPoint, withIntermediateDirectories: true, attributes: nil)
      let attach = runCommand(executable: "/usr/bin/hdiutil", arguments: ["attach", "-readonly", "-nobrowse", "-mountpoint", mountPoint, artifact], environment: environment)
      guard attach.status == 0 else {
        try? fm.removeItem(atPath: mountPoint)
        throw NSError(domain: appTitle, code: Int(attach.status), userInfo: [NSLocalizedDescriptionKey: "Sparse image verification mount failed for \(label)."])
      }
      defer {
        _ = runCommand(executable: "/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"], environment: environment)
        try? fm.removeItem(atPath: mountPoint)
      }
      try verifyCodexBackupTree(source: source, backup: mountPoint, environment: environment, label: label)
    } else {
      try verifyCodexBackupTree(source: source, backup: artifact, environment: environment, label: label)
    }
    return artifact
  }

  private nonisolated static func verifyCodexBackupTree(
    source: String,
    backup: String,
    environment: [String: String],
    label: String
  ) throws {
    let arguments = ["-rcln", "--no-owner", "--no-group", "--no-perms", "--delete", source.hasSuffix("/") ? source : source + "/", backup.hasSuffix("/") ? backup : backup + "/"]
    let result = runCodexRsync(arguments: arguments, environment: environment)
    let output = result.output
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .filter { !$0.hasPrefix("skipping non-regular file ") }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard result.status == 0, output.isEmpty else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Backup verification failed for \(label). The artifact was retained."])
    }
  }

  private nonisolated static func createVerifiedCodexZip(
    source: String,
    zipPath: String,
    environment: [String: String],
    label: String
  ) throws {
    let parent = (zipPath as NSString).deletingLastPathComponent
    try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true, attributes: nil)
    var commandEnvironment = environment
    commandEnvironment["COPYFILE_DISABLE"] = "1"
    let zipResult = runCommand(
      executable: "/usr/bin/ditto",
      arguments: ["-c", "-k", "--keepParent", source, zipPath],
      environment: commandEnvironment
    )
    guard zipResult.status == 0 else {
      throw NSError(domain: appTitle, code: Int(zipResult.status), userInfo: [NSLocalizedDescriptionKey: "ZIP creation failed for \(label): \(redactSensitiveText(zipResult.output))"])
    }
    let verify = runCommand(executable: "/usr/bin/unzip", arguments: ["-tq", zipPath], environment: environment)
    guard verify.status == 0 else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "ZIP verification failed for \(label)."])
    }
  }

  private nonisolated static func performCodexResumeTransfer(
    project: CodexProjectEntry,
    destination: String,
    mode: CodexProjectTransferMode,
    createBackup: Bool,
    backupMedium: CodexBackupMedium,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool,
    createCompatibilityLink: Bool,
    rearmGitMain: Bool,
    transferPlan: CodexTransferPlan,
    exclusions: [String],
    environment: [String: String]
  ) throws -> CodexProjectTransferOutcome {
    let fm = FileManager.default
    let stamp = timestampStamp()
    let safeName = project.name.replacingOccurrences(of: "/", with: "-")
    let backupDirectory = ((destination as NSString).deletingLastPathComponent as NSString)
      .appendingPathComponent("backup")
    let backupRoot = (backupDirectory as NSString).appendingPathComponent("\(safeName)-\(stamp)")
    var warnings: [String] = []
    var archivePath: String?
    var currentSourcePath: String? = project.path
    let outputRoot = (destination as NSString).deletingLastPathComponent
    guard transferPlan.projectPath == project.path, transferPlan.destinationPath == destination else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "The transfer plan no longer matches \(project.name). Run Preflight again before modifying an existing destination."])
    }
    if createBackup {
      // Capture both sides before reconciliation so an interrupted merge can
      // always roll back to the exact pre-run state.
      try fm.createDirectory(atPath: backupRoot, withIntermediateDirectories: true, attributes: nil)
      let sourceArchive = try createCodexBackup(
        source: project.path,
        backupRoot: backupRoot,
        baseName: "\(safeName)-source-before-merge",
        medium: backupMedium,
        environment: environment,
        label: "source backup for \(project.name)"
      )
      archivePath = sourceArchive
      _ = try createCodexBackup(
        source: destination,
        backupRoot: backupRoot,
        baseName: "\(safeName)-destination-before-merge",
        medium: backupMedium,
        environment: environment,
        label: "destination backup for \(project.name)"
      )
    }
    _ = try preserveCodexSourceRecovery(
      source: project.path,
      destination: destination,
      safeName: safeName,
      stamp: stamp,
      environment: environment
    )
    let preserved = try preserveCodexDestinationPaths(
      destination: destination,
      relativePaths: transferPlan.plannedPaths,
      safeName: safeName,
      stamp: stamp,
      environment: environment
    )
    if let recoveryRoot = preserved.root {
      warnings.append(
        "\(preserved.preservedRoots.count) pre-merge destination path(s) were checksum-preserved at \(recoveryRoot)."
      )
    }
    let typeConflictRoots = try Array(
      Set(transferPlan.typeConflictPaths.map(validatedCodexRelativePath))
    ).sorted {
      let leftCount = $0.split(separator: "/").count
      let rightCount = $1.split(separator: "/").count
      return leftCount == rightCount ? $0 < $1 : leftCount < rightCount
    }.reduce(into: [String]()) { roots, path in
      if !roots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
        roots.append(path)
      }
    }
    for relativePath in typeConflictRoots {
      let wasPreserved = preserved.preservedRoots.contains {
        relativePath == $0 || relativePath.hasPrefix($0 + "/")
      }
      guard wasPreserved else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Type-conflict path was not preserved before replacement: \(relativePath)"])
      }
      let destinationPath = (destination as NSString).appendingPathComponent(relativePath)
      if codexPathExistsIncludingSymlink(destinationPath) {
        try fm.removeItem(atPath: destinationPath)
      }
    }
    // Existing destinations use the preflight file table as an rsync manifest.
    // That means the repeat path copies only missing, metadata-changed, or
    // deep-audit-failed entries rather than re-sending the entire project.
    var reconciledFileCount = try applyTargetedCodexRsync(
      source: project.path,
      destination: destination,
      plannedPaths: transferPlan.plannedPaths,
      exclusions: exclusions,
      environment: environment,
      outputRoot: outputRoot,
      projectName: project.name,
      label: "resume-copy"
    )
    let rawTargetedDifferences = try rsyncChangedPaths(
      source: project.path,
      destination: destination,
      exclusions: exclusions,
      protectedPaths: [],
      environment: environment,
      useChecksums: true,
      filePaths: transferPlan.plannedPaths,
      manifestOutputRoot: outputRoot,
      manifestProjectName: project.name,
      manifestLabel: "resume-verify"
    )
    let targetedDifferences = codexContentDifferences(
      rawTargetedDifferences,
      source: project.path,
      destination: destination
    )
    guard targetedDifferences.isEmpty else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Targeted checksum verification found \(targetedDifferences.count) unresolved path(s) for \(project.name). The destination was retained for a later resume."])
    }

    if rearmGitMain {
      guard let remoteURL = project.remoteURL, !remoteURL.isEmpty else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Git main re-arm requires a detected remote for \(project.name)."])
      }
      try rearmGitMainAtDestination(destination: destination, remoteURL: remoteURL, environment: environment)
    }

    let transferNote = codexTransferNote(
      project: project,
      destination: destination,
      backupRoot: createBackup ? backupRoot : nil,
      includeGit: includeGit,
      includeFinderMetadata: includeFinderMetadata,
      includeDependencies: includeDependencies,
      rearmGitMain: rearmGitMain,
      mode: mode
    )
    let promptInject = codexPromptInject(project: project, destination: destination, rearmGitMain: rearmGitMain)
    try transferNote.write(toFile: (destination as NSString).appendingPathComponent("Transfer_Note.MD"), atomically: true, encoding: String.Encoding.utf8)
    try promptInject.write(toFile: (destination as NSString).appendingPathComponent("Prompt_Inject.MD"), atomically: true, encoding: String.Encoding.utf8)

    if createBackup {
      try transferNote.write(toFile: (backupRoot as NSString).appendingPathComponent("Transfer_Note.MD"), atomically: true, encoding: String.Encoding.utf8)
      try promptInject.write(toFile: (backupRoot as NSString).appendingPathComponent("Prompt_Inject.MD"), atomically: true, encoding: String.Encoding.utf8)
    }

    var preservedPathCount = preserved.preservedRoots.count
    var fullDifferences = try codexFullChecksumDifferences(
      source: project.path,
      destination: destination,
      exclusions: exclusions,
      protectedPaths: [],
      environment: environment
    )

    // Fast Mode deliberately avoids checksumming metadata-matched files during
    // planning. The mandatory final whole-tree checksum can therefore discover
    // a rare same-size, same-timestamp mutation. Preserve the destination side,
    // repair only those checksum-only misses, and verify the whole tree again.
    // No cleanup-capable receipt can be written unless this second pass is clean.
    if !fullDifferences.isEmpty {
      let checksumRepairPaths = fullDifferences.sorted()
      let checksumPreserved = try preserveCodexDestinationPaths(
        destination: destination,
        relativePaths: checksumRepairPaths,
        safeName: safeName,
        stamp: stamp,
        environment: environment
      )
      preservedPathCount += checksumPreserved.preservedRoots.count
      if let recoveryRoot = checksumPreserved.root {
        warnings.append(
          "Fast Mode found \(checksumRepairPaths.count) checksum-only difference(s); \(checksumPreserved.preservedRoots.count) prior destination path(s) were preserved at \(recoveryRoot) before repair."
        )
      }

      reconciledFileCount += try applyTargetedCodexRsync(
        source: project.path,
        destination: destination,
        plannedPaths: checksumRepairPaths,
        exclusions: exclusions,
        environment: environment,
        outputRoot: outputRoot,
        projectName: project.name,
        label: "fast-mode-checksum-repair"
      )

      let checksumRepairDifferences = try rsyncChangedPaths(
        source: project.path,
        destination: destination,
        exclusions: exclusions,
        protectedPaths: [],
        environment: environment,
        useChecksums: true,
        filePaths: checksumRepairPaths,
        manifestOutputRoot: outputRoot,
        manifestProjectName: project.name,
        manifestLabel: "fast-mode-checksum-repair-verify"
      )
      guard codexContentDifferences(
        checksumRepairDifferences,
        source: project.path,
        destination: destination
      ).isEmpty else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Fast Mode checksum repair did not converge for \(project.name). The source and preserved destination variants were retained and no deletion-capable receipt was written."])
      }

      fullDifferences = try codexFullChecksumDifferences(
        source: project.path,
        destination: destination,
        exclusions: exclusions,
        protectedPaths: [],
        environment: environment
      )
    }
    guard fullDifferences.isEmpty else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Full checksum verification found \(fullDifferences.count) unresolved path(s) for \(project.name). The source was retained and no deletion-capable receipt was written."])
    }

    if mode.removesSource {
      let parkedSource = project.path + ".csa-iem-source-\(stamp)"
      try fm.moveItem(atPath: project.path, toPath: parkedSource)
      currentSourcePath = parkedSource
      if createCompatibilityLink {
        do {
          try fm.createSymbolicLink(atPath: project.path, withDestinationPath: destination)
        } catch {
          try? fm.moveItem(atPath: parkedSource, toPath: project.path)
          throw error
        }
      }
      warnings.append("The verified source is parked at \(parkedSource) pending receipt-linked Stage 3 cleanup.")
    }

    return CodexProjectTransferOutcome(
      projectName: project.name,
      originalSourcePath: project.path,
      currentSourcePath: currentSourcePath,
      destinationPath: destination,
      backupPath: createBackup ? backupRoot : nil,
      archivePath: archivePath,
      warnings: warnings,
      resumedExistingDestination: true,
      reconciledFileCount: reconciledFileCount,
      conflictCount: preservedPathCount
    )
  }

  private nonisolated static func rsyncTransferredFileCount(_ output: String) -> Int {
    let markers = [
      "Number of regular files transferred:",
      "Number of files transferred:"
    ]
    for marker in markers {
      for line in output.split(whereSeparator: \.isNewline) {
        let text = String(line)
        guard let range = text.range(of: marker) else { continue }
        let value = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if let count = Int(value) {
          return count
        }
      }
    }
    return 0
  }

  private nonisolated static func codexTransferNote(
    project: CodexProjectEntry,
    destination: String?,
    backupRoot: String?,
    includeGit: Bool,
    includeFinderMetadata: Bool,
    includeDependencies: Bool,
    rearmGitMain: Bool,
    mode: CodexProjectTransferMode
  ) -> String {
    """
    # Transfer Note

    Generated by CSA-iEM \(appVersion) on \(Date().formatted(date: .numeric, time: .standard)).

    - Project: \(project.name)
    - Original path: \(project.path)
    - Destination: \(destination ?? "Backup package only")
    - Backup folder: \(backupRoot ?? "Disabled")
    - Mode: \(mode.label)
    - Git metadata included: \(includeGit ? "Yes" : "No")
    - Finder metadata included: \(includeFinderMetadata ? "Yes" : "No")
    - Git main branch re-armed after copy: \(rearmGitMain ? "Yes; origin/main fetched and index rebuilt without working-tree overwrite" : "No")
    - Generated dependencies and build outputs included: \(includeDependencies ? "Yes" : "No; restore dependencies from lockfiles and rebuild outputs")
    - Git remote: \(project.remoteURL ?? "Not detected")
    - Git branch: \(project.branch ?? "Not detected")

    ## Verification

    CSA-iEM saves a source and destination file table under the output folder's `_temp/Transfer-Indexes` directory before execution. Repeat transfers use the table to send only missing, metadata-changed, or deep-audit-failed paths. Metadata comparison checks relative path, type, size, date, and symlink target; the optional deep audit moves checksum detection into planning. Fast Mode still concludes every published, resumed, or bidirectionally synchronized destination with a whole-tree checksum verification. If that final audit discovers a rare same-size, same-date content mutation, CSA-iEM checksum-preserves the prior destination variant, repairs only the affected path, and repeats the whole-tree audit before a cleanup-capable receipt can be written. New destinations are staged and fully verified before publication. Verified ZIP archives are created when backup is enabled. When Git metadata is excluded, the destination can be re-armed from its detected remote without checking out or overwriting the copied working tree.

    ## Reconnect

    Open the destination folder as a project in Codex, VS Code, or your preferred editor. CSA-iEM does not edit undocumented Codex application databases. The compatibility link option preserves the previous filesystem path after a move.

    ## Dependencies

    Reinstall generated dependencies from project lockfiles. Typical commands include `npm ci`, the repository's documented build command, and a nested install for folders such as `functions` when that folder has its own lockfile.
    """
  }

  private nonisolated static func codexPromptInject(project: CodexProjectEntry, destination: String?, rearmGitMain: Bool) -> String {
    let gitReconnectNote = rearmGitMain
      ? "    Git was re-armed from `origin/main`; only the index was rebuilt. Confirm the working tree before making changes."
      : ""
    return """
    # Codex Project Reconnect Prompt

    Review this transferred project before changing files.

    1. Confirm the active workspace root is `\(destination ?? project.path)`.
    2. Read `Transfer_Note.MD` and inspect `git status`, the current branch, and configured remotes.
    3. Verify lockfiles and reinstall generated dependency folders when they were excluded.
    4. Run the project's existing tests and build commands.
    5. Do not delete backup artifacts until the transferred project has been opened and validated.
    \(gitReconnectNote)

    Project identity: \(project.name)
    Original path: \(project.path)
    Git remote: \(project.remoteURL ?? "Not detected")
    """
  }

  private nonisolated static func rearmGitMainAtDestination(
    destination: String,
    remoteURL: String,
    environment: [String: String]
  ) throws {
    let git = "/usr/bin/git"
    let initResult = runCommand(executable: git, arguments: ["-C", destination, "init", "-b", "main"], environment: environment)
    guard initResult.status == 0 else {
      throw NSError(domain: appTitle, code: Int(initResult.status), userInfo: [NSLocalizedDescriptionKey: "Could not initialize Git main in \(destination): \(redactSensitiveText(initResult.output))"])
    }

    let setURL = runCommand(executable: git, arguments: ["-C", destination, "remote", "set-url", "origin", remoteURL], environment: environment)
    if setURL.status != 0 {
      let addRemote = runCommand(executable: git, arguments: ["-C", destination, "remote", "add", "origin", remoteURL], environment: environment)
      guard addRemote.status == 0 else {
        throw NSError(domain: appTitle, code: Int(addRemote.status), userInfo: [NSLocalizedDescriptionKey: "Could not configure the Git origin for \(destination): \(redactSensitiveText(addRemote.output))"])
      }
    }

    let fetch = runCommand(executable: git, arguments: ["-C", destination, "fetch", "--no-tags", "origin", "main"], environment: environment)
    guard fetch.status == 0 else {
      throw NSError(domain: appTitle, code: Int(fetch.status), userInfo: [NSLocalizedDescriptionKey: "Git origin/main fetch failed for \(destination): \(redactSensitiveText(fetch.output))"])
    }

    let branch = runCommand(executable: git, arguments: ["-C", destination, "branch", "--force", "main", "FETCH_HEAD"], environment: environment)
    guard branch.status == 0 else {
      throw NSError(domain: appTitle, code: Int(branch.status), userInfo: [NSLocalizedDescriptionKey: "Could not point Git main at FETCH_HEAD for \(destination): \(redactSensitiveText(branch.output))"])
    }

    let head = runCommand(executable: git, arguments: ["-C", destination, "symbolic-ref", "HEAD", "refs/heads/main"], environment: environment)
    guard head.status == 0 else {
      throw NSError(domain: appTitle, code: Int(head.status), userInfo: [NSLocalizedDescriptionKey: "Could not activate Git main for \(destination): \(redactSensitiveText(head.output))"])
    }

    // Rebuild only the index from the fetched branch. A mixed reset does not
    // checkout or overwrite the copied working tree.
    let index = runCommand(executable: git, arguments: ["-C", destination, "reset", "--mixed", "main"], environment: environment)
    guard index.status == 0 else {
      throw NSError(domain: appTitle, code: Int(index.status), userInfo: [NSLocalizedDescriptionKey: "Could not rebuild the Git index for \(destination) without changing copied files: \(redactSensitiveText(index.output))"])
    }

    for (key, value) in [("branch.main.remote", "origin"), ("branch.main.merge", "refs/heads/main")] {
      let config = runCommand(executable: git, arguments: ["-C", destination, "config", key, value], environment: environment)
      guard config.status == 0 else {
        throw NSError(domain: appTitle, code: Int(config.status), userInfo: [NSLocalizedDescriptionKey: "Could not save Git main tracking configuration for \(destination): \(redactSensitiveText(config.output))"])
      }
    }
  }

  nonisolated static func performTransactionalTransfers(
    operations: [LocalTransferOperation],
    mode: LocalFileTransferMode,
    overwrite: Bool,
    environment: [String: String]
  ) throws -> LocalTransferOutcome {
    let fm = FileManager.default
    let transactionID = UUID().uuidString
    var normalizedOperations: [LocalTransferOperation] = []
    var seenDestinations: Set<String> = []

    for operation in operations {
      let normalizedSource = NSString(string: operation.source).standardizingPath
      let normalizedDestination = NSString(string: operation.destination).standardizingPath

      guard fm.fileExists(atPath: normalizedSource) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Source path was not found: \(normalizedSource)"])
      }

      if normalizedDestination == normalizedSource || normalizedDestination.hasPrefix(normalizedSource + "/") {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination cannot be the same as or inside the source path: \(normalizedDestination)"])
      }

      if !seenDestinations.insert(normalizedDestination).inserted {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Duplicate destination detected during export preparation: \(normalizedDestination)"])
      }

      if fm.fileExists(atPath: normalizedDestination), !overwrite {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(normalizedDestination)"])
      }

      normalizedOperations.append(LocalTransferOperation(source: normalizedSource, destination: normalizedDestination))
    }

    var stagePathsByDestination: [String: String] = [:]
    var backupPathsByDestination: [String: String] = [:]

    do {
      for operation in normalizedOperations {
        let stagePath = try stagingPath(for: operation.destination, transactionID: transactionID)
        try? fm.removeItem(atPath: stagePath)
        try transferItem(
          from: operation.source,
          to: stagePath,
          mode: .copyBackup,
          overwrite: true,
          environment: environment
        )
        stagePathsByDestination[operation.destination] = stagePath
      }

      for operation in normalizedOperations where fm.fileExists(atPath: operation.destination) {
        let backupPath = operation.destination + ".csa-iem-backup-\(transactionID)"
        try? fm.removeItem(atPath: backupPath)
        try fm.moveItem(atPath: operation.destination, toPath: backupPath)
        backupPathsByDestination[operation.destination] = backupPath
      }

      for operation in normalizedOperations {
        guard let stagePath = stagePathsByDestination[operation.destination] else { continue }
        try fm.moveItem(atPath: stagePath, toPath: operation.destination)
        stagePathsByDestination.removeValue(forKey: operation.destination)
      }
      if environment["CSA_IEM_TEST_FAIL_AFTER_TRANSACTION_PROMOTION"] == "1" {
        throw NSError(domain: appTitle, code: 98, userInfo: [NSLocalizedDescriptionKey: "Injected transactional promotion failure for rollback verification."])
      }
    } catch {
      for operation in normalizedOperations {
        if fm.fileExists(atPath: operation.destination) {
          try? fm.removeItem(atPath: operation.destination)
        }
      }
      for (destination, backupPath) in backupPathsByDestination {
        if fm.fileExists(atPath: backupPath) {
          try? fm.moveItem(atPath: backupPath, toPath: destination)
        }
      }
      throw error
    }

    var cleanupWarnings: [String] = []
    if mode == .move {
      for operation in normalizedOperations where fm.fileExists(atPath: operation.source) {
        do {
          try fm.removeItem(atPath: operation.source)
        } catch {
          cleanupWarnings.append("Source cleanup failed for \(operation.source). The new destination is ready, but the old path still needs manual cleanup.")
        }
      }
    }

    for backupPath in backupPathsByDestination.values {
      try? fm.removeItem(atPath: backupPath)
    }

    return LocalTransferOutcome(warnings: cleanupWarnings)
  }

  private nonisolated static func transferItem(
    from source: String,
    to destination: String,
    mode: LocalFileTransferMode,
    overwrite: Bool,
    environment: [String: String]
  ) throws {
    let fm = FileManager.default
    let normalizedSource = NSString(string: source).standardizingPath
    let normalizedDestination = NSString(string: destination).standardizingPath

    guard fm.fileExists(atPath: normalizedSource) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Source path was not found: \(normalizedSource)"])
    }

    if normalizedDestination == normalizedSource || normalizedDestination.hasPrefix(normalizedSource + "/") {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination cannot be the same as or inside the source path: \(normalizedDestination)"])
    }

    let parentDirectory = (normalizedDestination as NSString).deletingLastPathComponent
    try fm.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true, attributes: nil)

    if fm.fileExists(atPath: normalizedDestination) {
      if overwrite {
        try fm.removeItem(atPath: normalizedDestination)
      } else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(normalizedDestination)"])
      }
    }

    let dittoPath = resolveExecutablePath(named: "ditto") ?? "/usr/bin/ditto"
    let result = runCommand(executable: dittoPath, arguments: [normalizedSource, normalizedDestination], environment: environment)
    guard result.status == 0 else {
      let output = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
      throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Failed to transfer \(normalizedSource)." : output])
    }

    if mode == .move {
      try fm.removeItem(atPath: normalizedSource)
    }
  }

  private nonisolated static func stagingPath(for destination: String, transactionID: String) throws -> String {
    let fm = FileManager.default
    let normalizedDestination = NSString(string: destination).standardizingPath
    let destinationParent = (normalizedDestination as NSString).deletingLastPathComponent
    let stagingRoot = ((destinationParent as NSString)
      .appendingPathComponent("_temp") as NSString)
      .appendingPathComponent("CSA-iEM-staging-\(transactionID)")
    try fm.createDirectory(atPath: stagingRoot, withIntermediateDirectories: true, attributes: nil)
    return (stagingRoot as NSString).appendingPathComponent((normalizedDestination as NSString).lastPathComponent)
  }

  private nonisolated static func timestampStamp() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: Date())
  }

  private nonisolated static func localExportRoot(destinationBase: String, stamp: String) -> String {
    (destinationBase as NSString).appendingPathComponent("CSA-iEM-Export-\(stamp)")
  }
}

private func shellQuote(_ value: String) -> String {
  "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}

private func quotedAppleScript(commandLine: String) -> String {
  let escaped = commandLine
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
  return "\"\(escaped)\""
}

private func bundledTermsOfServiceText() -> String {
  guard let url = bundledResourceURL(named: "TERMS-OF-SERVICE.md"),
        let contents = try? String(contentsOf: url, encoding: .utf8),
        contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
    return defaultTermsOfServiceText
  }

  return contents
}

private func localResourceRoots() -> [URL] {
  var roots: [URL] = []

  if let bundleRoot = Bundle.main.resourceURL {
    roots.append(bundleRoot)
    roots.append(bundleRoot.appendingPathComponent("Help", isDirectory: true))
    roots.append(bundleRoot.appendingPathComponent("assets", isDirectory: true))
    roots.append(bundleRoot.appendingPathComponent("assets/logos", isDirectory: true))
    roots.append(bundleRoot.appendingPathComponent("assets/social", isDirectory: true))
  }

  if let envRoot = ProcessInfo.processInfo.environment["CSA_IEM_ROOT"], envRoot.isEmpty == false {
    let envURL = URL(fileURLWithPath: envRoot, isDirectory: true)
    roots.append(envURL)
    roots.append(envURL.appendingPathComponent("Help", isDirectory: true))
    roots.append(envURL.appendingPathComponent("assets", isDirectory: true))
    roots.append(envURL.appendingPathComponent("assets/logos", isDirectory: true))
    roots.append(envURL.appendingPathComponent("assets/social", isDirectory: true))
    roots.append(envURL.appendingPathComponent("docs", isDirectory: true))
  }

  let cwdRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
  roots.append(cwdRoot)
  roots.append(cwdRoot.appendingPathComponent("Help", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("assets", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("assets/logos", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("assets/social", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("docs", isDirectory: true))

  var unique: [URL] = []
  var seen: Set<String> = []
  for root in roots {
    let key = root.standardizedFileURL.path
    if seen.insert(key).inserted {
      unique.append(root)
    }
  }
  return unique
}

private func bundledResourceURL(named name: String, subdirectory: String? = nil) -> URL? {
  let fm = FileManager.default

  for root in localResourceRoots() {
    if let subdirectory {
      let url = root.appendingPathComponent(subdirectory, isDirectory: true).appendingPathComponent(name)
      if fm.fileExists(atPath: url.path) {
        return url
      }
    }

    let directURL = root.appendingPathComponent(name)
    if fm.fileExists(atPath: directURL.path) {
      return directURL
    }
  }

  return nil
}

private func bundledImage(named name: String) -> NSImage? {
  guard let url = bundledResourceURL(named: name) else {
    return nil
  }
  return NSImage(contentsOf: url)
}

private func bundledDocumentText(named name: String, fallback: String = "") -> String {
  if let helpURL = bundledResourceURL(named: name, subdirectory: bundledHelpDirectory),
     let contents = try? String(contentsOf: helpURL, encoding: .utf8),
     contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
    return contents
  }

  if let directURL = bundledResourceURL(named: name),
     let contents = try? String(contentsOf: directURL, encoding: .utf8),
     contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
    return contents
  }

  return fallback
}

private func attributedMarkdown(_ markdown: String) -> AttributedString {
  if let parsed = try? AttributedString(
    markdown: markdown,
    options: AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .full,
      failurePolicy: .returnPartiallyParsedIfPossible
    )
  ) {
    return parsed
  }

  return AttributedString(markdown)
}

private func redactSensitiveText(_ text: String) -> String {
  let replacements: [(pattern: String, replacement: String)] = [
    ("ghp_[A-Za-z0-9]{20,}", "[REDACTED_GITHUB_TOKEN]"),
    ("github_pat_[A-Za-z0-9_]{20,}", "[REDACTED_GITHUB_TOKEN]"),
    ("gho_[A-Za-z0-9]{20,}", "[REDACTED_GITHUB_TOKEN]"),
    ("AKIA[0-9A-Z]{16}", "[REDACTED_AWS_KEY]"),
    ("AIza[0-9A-Za-z\\-_]{20,}", "[REDACTED_API_KEY]"),
    ("(?i)authorization:\\s*bearer\\s+[A-Za-z0-9._\\-]+", "Authorization: Bearer [REDACTED]"),
    ("(?i)(gh_token|github_token|access_token|client_secret|api_key)\\s*[:=]\\s*[^\\s\\n]+", "$1=[REDACTED]")
  ]

  var sanitized = text
  for item in replacements {
    guard let regex = try? NSRegularExpression(pattern: item.pattern, options: []) else {
      continue
    }
    let range = NSRange(sanitized.startIndex..., in: sanitized)
    sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: item.replacement)
  }

  return sanitized
}

private enum DashboardTheme {
  static let navyOutline = Color(red: 31 / 255, green: 77 / 255, blue: 134 / 255)
  static let deepBlue = Color(red: 21 / 255, green: 80 / 255, blue: 143 / 255)
  static let brightPink = Color(red: 246 / 255, green: 95 / 255, blue: 165 / 255)
  static let accentPink = Color(red: 217 / 255, green: 44 / 255, blue: 123 / 255)
  static let coolWhite = Color(red: 247 / 255, green: 248 / 255, blue: 250 / 255)
  static let gridGray = Color(red: 216 / 255, green: 221 / 255, blue: 227 / 255)

  static let canvasTop = Color(red: 15 / 255, green: 23 / 255, blue: 32 / 255)
  static let canvasBottom = Color(red: 17 / 255, green: 25 / 255, blue: 35 / 255)
  static let panel = Color(red: 24 / 255, green: 32 / 255, blue: 43 / 255)
  static let panelAlt = Color(red: 27 / 255, green: 37 / 255, blue: 49 / 255)
  static let panelStrong = Color(red: 20 / 255, green: 28 / 255, blue: 38 / 255)
  static let field = Color(red: 30 / 255, green: 40 / 255, blue: 53 / 255)
  static let border = Color.white.opacity(0.08)
  static let text = coolWhite
  static let muted = Color(red: 211 / 255, green: 219 / 255, blue: 230 / 255)
  static let subtle = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
  static let accent = Color(red: 125 / 255, green: 178 / 255, blue: 239 / 255)
  static let success = Color(red: 42 / 255, green: 110 / 255, blue: 88 / 255)
  static let warning = Color(red: 209 / 255, green: 165 / 255, blue: 82 / 255)
  static let danger = Color(red: 133 / 255, green: 49 / 255, blue: 94 / 255)
  static let link = Color(red: 141 / 255, green: 198 / 255, blue: 255 / 255)
  static let warningSurface = Color(red: 250 / 255, green: 239 / 255, blue: 219 / 255)
  static let warningText = Color(red: 74 / 255, green: 54 / 255, blue: 24 / 255)
  static let warningSubtle = Color(red: 107 / 255, green: 83 / 255, blue: 46 / 255)
}

private extension CodexIDEProjectState {
  var dashboardTint: Color {
    switch self {
    case .active: return DashboardTheme.success
    case .linked: return DashboardTheme.deepBlue
    case .unlinked: return DashboardTheme.subtle
    case .unavailable: return DashboardTheme.warning
    }
  }

  var dashboardHelp: String {
    switch self {
    case .active:
      return "This folder is the selected local project in the Codex desktop app."
    case .linked:
      return "This folder is linked to a local Codex desktop project but is not selected now."
    case .unlinked:
      return "This folder was found on disk but is not in Codex's current local-project registry."
    case .unavailable:
      return "CSA-iEM could not read the local Codex desktop project registry."
    }
  }
}

private extension CodexGitWorkspaceStatus {
  var dashboardTint: Color {
    if hasLocalChanges { return DashboardTheme.warning }
    switch mainState {
    case .synchronized: return DashboardTheme.success
    case .noGit: return DashboardTheme.subtle
    case .ahead, .behind, .diverged, .noOriginMain, .unavailable: return DashboardTheme.warning
    }
  }
}

private extension View {
  func dashboardFieldStyle() -> some View {
    self
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(DashboardTheme.field)
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(DashboardTheme.border, lineWidth: 1)
          )
      )
  }
}

struct PanelCard<Content: View>: View {
  let title: String
  let subtitle: String
  let compact: Bool
  @ViewBuilder let content: Content

  init(title: String, subtitle: String, compact: Bool = false, @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.compact = compact
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 14 : 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
        Text(subtitle)
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineSpacing(2)
      }

      content
    }
    .padding(compact ? 18 : 22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(DashboardTheme.panelAlt)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

private struct ModuleMatrixStrip: View {
  let destination: AppDestination?

  private var primaryCount: Int {
    CSAiEMModuleTag.catalog.filter { $0.state == "primary" }.count
  }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "point.3.connected.trianglepath.dotted")
        .foregroundStyle(DashboardTheme.accent)
      Text("Unified module matrix")
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
      Text("v\(appVersion) · \(CSAiEMModuleTag.matrixVersion) · \(primaryCount) tagged modules")
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 0)
      if let destination {
        PillBadge(text: destination.title, tint: destination.tint)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(DashboardTheme.accent.opacity(0.22), lineWidth: 1)
        )
    )
  }
}

private struct ModuleMatrixCard: View {
  let width: CGFloat

  var body: some View {
    PanelCard(
      title: "Module and runtime matrix",
      subtitle: "Every dashboard page, engine, bridge, runtime, and install surface carries one searchable version/tag identity."
    ) {
      if width >= 1100 {
        LazyVGrid(columns: [
          GridItem(.flexible(minimum: 220), alignment: .leading),
          GridItem(.flexible(minimum: 120), alignment: .leading),
          GridItem(.flexible(minimum: 180), alignment: .leading),
          GridItem(.flexible(minimum: 120), alignment: .leading)
        ], alignment: .leading, spacing: 9) {
          matrixHeader("Module")
          matrixHeader("Area")
          matrixHeader("Tag")
          matrixHeader("Version")
          ForEach(CSAiEMModuleTag.catalog) { module in
            Text(module.name)
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            Text(module.area)
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
            Text(module.tag)
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.link)
            Text(module.version)
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.muted)
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(CSAiEMModuleTag.catalog) { module in
            HStack(spacing: 10) {
              Text(module.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
                .lineLimit(1)
              Spacer(minLength: 0)
              Text(module.tag)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.link)
                .lineLimit(1)
              Text(module.version)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.muted)
            }
            if module.id != CSAiEMModuleTag.catalog.last?.id {
              Divider().overlay(DashboardTheme.border)
            }
          }
        }
      }
    }
  }

  private func matrixHeader(_ text: String) -> some View {
    Text(text.uppercased())
      .font(.system(size: 10, weight: .bold, design: .rounded))
      .foregroundStyle(DashboardTheme.subtle)
  }
}

struct PillBadge: View {
  let text: String
  let tint: Color

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold, design: .rounded))
      .foregroundStyle(DashboardTheme.text)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(DashboardTheme.field)
      .overlay(
        Capsule()
          .stroke(tint.opacity(0.38), lineWidth: 1)
      )
      .clipShape(Capsule())
  }
}

struct BannerCard: View {
  let title: String
  let detail: String
  let kind: StatusKind

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: kind.icon)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(kind.tint)
        .frame(width: 36, height: 36)
        .background(DashboardTheme.panelStrong)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
        Text(detail)
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineSpacing(3)
      }

      Spacer(minLength: 0)
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(DashboardTheme.field)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(kind.tint.opacity(0.30), lineWidth: 1)
        )
    )
  }
}

struct BrandMarkSquareView: View {
  let image: NSImage?
  let size: CGFloat
  let cornerRadius: CGFloat

  init(image: NSImage?, size: CGFloat, cornerRadius: CGFloat = 24) {
    self.image = image
    self.size = size
    self.cornerRadius = cornerRadius
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )

      if let image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
          .frame(width: size, height: size)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      } else {
        Image(systemName: "app.dashed")
          .font(.system(size: size * 0.24, weight: .semibold))
          .foregroundStyle(DashboardTheme.subtle)
      }
    }
    .frame(width: size, height: size)
  }
}

struct HeaderPanel: View {
  let brandMark: NSImage?
  let compact: Bool

  var body: some View {
    ZStack(alignment: .topTrailing) {
      HStack(spacing: 0) {
        Color.clear
          .frame(width: compact ? 120 : 200, height: 1)

        VStack(alignment: .center, spacing: compact ? 8 : 10) {
          Text(appTitle)
            .font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .multilineTextAlignment(.center)
            .lineLimit(2)

          Text(appFullName)
            .font(.system(size: compact ? 14 : 16, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .multilineTextAlignment(.center)
            .lineLimit(2)

          Text(appSubtitle)
            .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.warning)
            .multilineTextAlignment(.center)

          Text("Provided by: \(companyName) · \(companyWebsite)")
            .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        BrandMarkSquareView(
          image: brandMark,
          size: compact ? 120 : 200,
          cornerRadius: compact ? 20 : 26
        )
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, compact ? 18 : 20)
    .frame(minHeight: compact ? 132 : 164)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(DashboardTheme.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct DashboardShell<Content: View>: View {
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      ModuleMatrixStrip(destination: nil)
      content
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(DashboardTheme.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
    .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
  }
}

private struct MenuSectionHeader: View {
  let text: String

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 11, weight: .bold, design: .rounded))
      .foregroundStyle(DashboardTheme.subtle)
  }
}

private struct DestinationMenuButton: View {
  let destination: AppDestination
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: destination.icon)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(isSelected ? DashboardTheme.text : destination.tint)
          .frame(width: 20)

        Text(destination.title)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
          .lineLimit(1)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(isSelected ? destination.tint.opacity(0.42) : DashboardTheme.field)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(isSelected ? destination.tint.opacity(0.65) : DashboardTheme.border, lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }
}

private struct WorkspaceToolbarStrip: View {
  let destination: AppDestination
  let menuVisible: Bool
  let usesSidebar: Bool
  let toggleMenu: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(menuVisible ? "Hide Menu" : "Show Menu") {
        toggleMenu()
      }
      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

      PillBadge(text: destination.title, tint: destination.tint)

      Spacer(minLength: 0)

      Text(menuVisible ? (usesSidebar ? "Sidebar menu" : "Top menu") : "Focus mode")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(1)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DashboardTheme.panelAlt)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

private struct BottomStatusBar: View {
  let kind: StatusKind
  let status: String
  let session: String
  let selection: String
  let destination: AppDestination

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: kind.icon)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(kind.tint)

      Text(status)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
        .lineLimit(1)
        .minimumScaleFactor(0.85)

      Text("•")
        .foregroundStyle(DashboardTheme.subtle)

      Text(session)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .truncationMode(.middle)

      Text("•")
        .foregroundStyle(DashboardTheme.subtle)

      Text(selection)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .truncationMode(.middle)

      Spacer(minLength: 0)

      PillBadge(text: destination.title, tint: destination.tint)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DashboardTheme.panelAlt)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

private struct CompactDestinationBar: View {
  let selection: AppDestination
  let onSelect: (AppDestination) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(AppDestination.allCases) { destination in
          Button(action: { onSelect(destination) }) {
            HStack(spacing: 8) {
              Image(systemName: destination.icon)
                .font(.system(size: 12, weight: .bold))
              Text(destination.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selection == destination ? DashboardTheme.text : DashboardTheme.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
              Capsule()
                .fill(selection == destination ? destination.tint.opacity(0.42) : DashboardTheme.field)
                .overlay(
                  Capsule()
                    .stroke(selection == destination ? destination.tint.opacity(0.65) : DashboardTheme.border, lineWidth: 1)
                )
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 4)
    }
  }
}

private struct AppSidebarMenu: View {
  let selection: AppDestination
  let onSelect: (AppDestination) -> Void

  var body: some View {
    PanelCard(title: "App Menu", subtitle: "Move between the main product pages and the bundled in-app reference pages.", compact: true) {
      VStack(alignment: .leading, spacing: 12) {
        MenuSectionHeader(text: "Main Pages")
        ForEach(workspaceDestinations) { destination in
          DestinationMenuButton(destination: destination, isSelected: selection == destination) {
            onSelect(destination)
          }
        }

        Divider().overlay(DashboardTheme.border)

        MenuSectionHeader(text: "Reference")
        ForEach(knowledgeDestinations) { destination in
          DestinationMenuButton(destination: destination, isSelected: selection == destination) {
            onSelect(destination)
          }
        }
      }
    }
  }
}

private struct DocumentReaderCard: View {
  let destination: AppDestination
  let markdown: String

  var body: some View {
    PanelCard(title: destination.title, subtitle: destination.subtitle) {
      BannerCard(
        title: destination.title,
        detail: "This page is bundled inside the native app and stays available without leaving the interface.",
        kind: .ready
      )

      Text(attributedMarkdown(markdown))
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .lineSpacing(4)
        .padding(18)
        .background(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(DashboardTheme.panelStrong)
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DashboardTheme.border, lineWidth: 1)
            )
        )
    }
  }
}

private struct DestinationShortcutTile: View {
  let destination: AppDestination
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: destination.icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isSelected ? DashboardTheme.text : destination.tint)
          Spacer(minLength: 0)
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(destination.tint)
          }
        }

        Text(destination.title)
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
          .multilineTextAlignment(.leading)

        Text(destination.subtitle)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineLimit(3)
          .multilineTextAlignment(.leading)
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(isSelected ? destination.tint.opacity(0.18) : DashboardTheme.field)
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(isSelected ? destination.tint.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }
}

struct FieldLabel: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .semibold, design: .rounded))
      .foregroundStyle(DashboardTheme.muted)
  }
}

struct FixedValueRow: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(text: label)

      Text(value)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardFieldStyle()
    }
  }
}

struct RepoSelectionRow: View {
  let repo: RepoCatalogEntry
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? DashboardTheme.success : DashboardTheme.subtle)

        VStack(alignment: .leading, spacing: 4) {
          Text(repo.shortName)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .lineLimit(1)

          Text(repo.nameWithOwner)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 12)

        VStack(alignment: .trailing, spacing: 4) {
          Text(repo.visibilityLabel)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(repo.isPrivate == true ? DashboardTheme.warning : DashboardTheme.accent)

          Text(repo.updatedLabel)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.subtle)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(isSelected ? DashboardTheme.field.opacity(1.0) : DashboardTheme.panelStrong)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(isSelected ? DashboardTheme.success.opacity(0.45) : DashboardTheme.border, lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }
}

struct LocalProjectRow: View {
  let project: LocalProjectEntry
  let isTargeted: Bool
  let isFavorite: Bool
  let toggleTarget: () -> Void
  let toggleFavorite: () -> Void
  let openRuntime: () -> Void
  let openCode: () -> Void
  let reveal: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Image(systemName: isTargeted ? "checkmark.circle.fill" : "circle")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(isTargeted ? DashboardTheme.success : DashboardTheme.subtle)

            Text(project.repo)
              .font(.system(size: 14, weight: .bold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
              .lineLimit(1)
          }

          Text(project.slug)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        HStack(spacing: 6) {
          Button(action: toggleFavorite) {
            Image(systemName: isFavorite ? "star.fill" : "star")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(isFavorite ? DashboardTheme.warning : DashboardTheme.subtle)
              .padding(8)
              .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .fill(DashboardTheme.field)
              )
          }
          .buttonStyle(.plain)

          ForEach(project.badges, id: \.self) { badge in
            PillBadge(text: badge, tint: badge == "runner" ? DashboardTheme.warning : DashboardTheme.accent)
          }
        }
      }

      HStack(spacing: 10) {
        Button(isTargeted ? "Untarget" : "Target") {
          toggleTarget()
        }
        .buttonStyle(DashboardButtonStyle(tint: isTargeted ? DashboardTheme.success : DashboardTheme.warning, bordered: true))

        Button("Runtime") {
          openRuntime()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Code") {
          openCode()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Finder") {
          reveal()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      DisclosureGroup {
        VStack(alignment: .leading, spacing: 10) {
          if let codePath = project.codePath {
            LocalProjectTreeView(title: "Code", path: codePath)
          }
          if let runtimePath = project.runtimePath, runtimePath != project.codePath {
            LocalProjectTreeView(title: "Runtime", path: runtimePath)
          }
        }
        .padding(.top, 4)
      } label: {
        Label("Show project tree", systemImage: "list.bullet.indent")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(DashboardTheme.link)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isTargeted ? DashboardTheme.success.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

private struct LocalProjectTreeView: View {
  let title: String
  let path: String
  @State private var entries: [LocalProjectTreeEntry] = []
  @State private var isLoading = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Image(systemName: "folder.fill")
          .foregroundStyle(DashboardTheme.warning)
        Text(title)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
        Text(path)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(DashboardTheme.subtle)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      if isLoading {
        ProgressView()
          .controlSize(.small)
      } else if entries.isEmpty {
        Text("No readable top-level entries.")
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.subtle)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(entries) { entry in
            if entry.isDirectory {
              DisclosureGroup {
                LocalProjectTreeView(title: entry.name, path: entry.path)
                  .padding(.leading, 12)
              } label: {
                treeEntryLabel(entry)
              }
            } else {
              treeEntryLabel(entry)
            }
          }
        }
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(DashboardTheme.field.opacity(0.72))
    )
    .task(id: path) {
      await loadEntries()
    }
  }

  @ViewBuilder
  private func treeEntryLabel(_ entry: LocalProjectTreeEntry) -> some View {
    Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
      .font(.system(size: 11, weight: .medium, design: .rounded))
      .foregroundStyle(entry.isDirectory ? DashboardTheme.text : DashboardTheme.muted)
      .lineLimit(1)
      .truncationMode(.middle)
  }

  private func loadEntries() async {
    guard entries.isEmpty else { return }
    isLoading = true
    let loaded = await Task.detached(priority: .utility) {
      LocalProjectTreeEntry.load(path: path)
    }.value
    entries = loaded
    isLoading = false
  }
}

private struct LocalProjectTreeEntry: Identifiable, Hashable, Sendable {
  let path: String
  let name: String
  let isDirectory: Bool

  var id: String { path }

  static func load(path: String) -> [LocalProjectTreeEntry] {
    let excludedNames: Set<String> = [".git", ".DS_Store", "node_modules", ".build", "dist", "build", "coverage"]
    let fileManager = FileManager.default
    guard let names = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
    return names
      .filter { !$0.hasPrefix(".") && !excludedNames.contains($0) }
      .sorted { lhs, rhs in
        let lhsURL = URL(fileURLWithPath: path).appendingPathComponent(lhs)
        let rhsURL = URL(fileURLWithPath: path).appendingPathComponent(rhs)
        let lhsDirectory = (try? lhsURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let rhsDirectory = (try? rhsURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
      }
      .prefix(32)
      .map { name in
        let childPath = URL(fileURLWithPath: path).appendingPathComponent(name).path
        let isDirectory = (try? URL(fileURLWithPath: childPath).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return LocalProjectTreeEntry(path: childPath, name: name, isDirectory: isDirectory)
      }
  }
}

struct LiveContainerRow: View {
  let container: LiveContainerEntry
  let openRuntime: () -> Void
  let openCode: () -> Void
  let reveal: () -> Void
  let logs: () -> Void
  let stop: () -> Void
  let remove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(container.repo)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .lineLimit(1)

          Text(container.slug)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 6) {
          PillBadge(text: "container", tint: DashboardTheme.deepBlue)
          PillBadge(text: container.status, tint: DashboardTheme.success)
        }
      }

      Text("\(container.name) · \(container.image)")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.subtle)
        .lineLimit(2)

      HStack(spacing: 10) {
        Button("Runtime") {
          openRuntime()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Code") {
          openCode()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Finder") {
          reveal()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Logs") {
          logs()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Stop") {
          stop()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))

        Button("Remove") {
          remove()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct RunnerServiceRow: View {
  let runner: RunnerServiceEntry
  let openRuntime: () -> Void
  let openCode: () -> Void
  let reveal: () -> Void
  let start: () -> Void
  let startOnly: () -> Void
  let restart: () -> Void
  let verify: () -> Void
  let stop: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(runner.repo)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .lineLimit(1)

          Text(runner.slug)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 6) {
          PillBadge(text: "runner", tint: DashboardTheme.warning)
          PillBadge(text: runner.statusLabel, tint: runner.isRunning ? DashboardTheme.success : DashboardTheme.subtle)
        }
      }

      Text(runner.serviceLabel)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.subtle)
        .lineLimit(2)

      HStack(spacing: 10) {
        Button("Runtime") {
          openRuntime()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Code") {
          openCode()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Finder") {
          reveal()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Start") {
          start()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        .disabled(runner.isRunning)

        Button("Only This") {
          startOnly()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Restart") {
          restart()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Verify") {
          verify()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Stop") {
          stop()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
        .disabled(!runner.isRunning)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(runner.isRunning ? DashboardTheme.success.opacity(0.35) : DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct MetricTile: View {
  let label: String
  let value: String
  let tint: Color
  let icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(tint)
          .frame(width: 34, height: 34)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(tint.opacity(0.18))
          )

        Spacer(minLength: 0)
      }

      Text(value)
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)

      Text(label)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(2)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct DashboardButtonStyle: ButtonStyle {
  let tint: Color
  let bordered: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .bold, design: .rounded))
      .foregroundStyle(DashboardTheme.text)
      .padding(.horizontal, 16)
      .padding(.vertical, 11)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(
            bordered
              ? DashboardTheme.panelStrong.opacity(configuration.isPressed ? 0.88 : 1.0)
              : tint.opacity(configuration.isPressed ? 0.82 : 1.0)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(bordered ? tint.opacity(0.72) : tint.opacity(0.95), lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
  }
}

struct SafetyCard: View {
  @Binding var isArmed: Bool
  let dryRun: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(DashboardTheme.warningSurface)
          .frame(width: 40, height: 40)
          .background(DashboardTheme.warningText)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text("Warning: Permanent Delete")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.warningText)

          Text(dryRun ? "Dry run is enabled, but this app is built for destructive cleanup. Confirm the repo and account before you continue." : "This will permanently delete GitHub Actions data. Workflow runs, artifacts, caches, and disabled workflows cannot be restored.")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.warningSubtle)
            .lineSpacing(3)
        }
      }

      Toggle(isOn: $isArmed) {
        Text("Arm destructive cleanup")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.warningText)
      }
      .toggleStyle(.switch)
      .tint(DashboardTheme.deepBlue)

      Text(isArmed ? "Safety lock is OFF. Cleanup buttons are unlocked." : "Safety lock is ON. Turn this switch on before cleanup can run.")
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(isArmed ? DashboardTheme.warningText : DashboardTheme.warningSubtle)
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(DashboardTheme.warningSurface)
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(DashboardTheme.warning.opacity(0.65), lineWidth: 1)
        )
    )
  }
}

struct LaunchWarningSheet: View {
  @Binding var acceptedRisk: Bool
  @Binding var acceptedPurpose: Bool
  let brandMark: NSImage?
  let continueAction: () -> Void
  let quitAction: () -> Void

  private let termsText = bundledTermsOfServiceText()

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [DashboardTheme.canvasTop, DashboardTheme.canvasBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack(alignment: .top, spacing: 18) {
            BrandMarkSquareView(image: brandMark, size: 92, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 8) {
              Text("Warning!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)

              Text("This is a destructive admin tool. Use at your own risk.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.warning)

              Text("\(appTitle) is a professional migration, cleanup, and local-actions management tool provided by \(companyName). Review the terms below every time before using the product.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
                .lineSpacing(3)

              Link(companyWebsite, destination: URL(string: companyWebsiteURL)!)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tint(DashboardTheme.link)
            }
          }

          PanelCard(title: "Terms of Service", subtitle: "You must accept responsibility and intended-use conditions before the tool unlocks.") {
            ScrollView {
              Text(termsText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 280, maxHeight: 320)
            .padding(2)
            .background(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DashboardTheme.panelStrong)
                .overlay(
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DashboardTheme.border, lineWidth: 1)
                )
            )

            Toggle("I understand this tool can permanently delete GitHub Actions data and I accept full responsibility for its use.", isOn: $acceptedRisk)
              .toggleStyle(.switch)
              .tint(DashboardTheme.danger)
              .foregroundStyle(DashboardTheme.text)

            Toggle("I will use this product only for its intended professional migration, cleanup, and local-actions management purpose and only where I am authorized to make these changes.", isOn: $acceptedPurpose)
              .toggleStyle(.switch)
              .tint(DashboardTheme.accent)
              .foregroundStyle(DashboardTheme.text)
          }

          HStack(spacing: 12) {
            Button("Quit App") {
              quitAction()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

            Button("Accept and Continue") {
              continueAction()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: false))
            .disabled(!(acceptedRisk && acceptedPurpose))
          }

            Text("Your acceptance is saved locally and can be reset from Settings when needed.")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.subtle)
        }
        .padding(24)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity)
      }
    }
    .frame(minWidth: 920, minHeight: 760)
    .preferredColorScheme(.dark)
  }
}

struct StartupReadinessSheet: View {
  @ObservedObject var model: CleanupViewModel
  let continueAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Startup Check")
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)

      Text("CSA-iEM checks this Mac locally before you start. It does not import, store, or log GitHub tokens, API keys, account identity, repositories, or organization data during this check.")
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(3)

      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(model.startupReadiness) { entry in
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: entry.kind.icon)
                .foregroundStyle(entry.kind.tint)
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                  .font(.system(size: 14, weight: .bold, design: .rounded))
                  .foregroundStyle(DashboardTheme.text)
                Text(entry.detail)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
              }
              Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DashboardTheme.panelStrong))
          }
        }
      }
      .frame(maxHeight: 280)

      Text("Manual setup: install GitHub CLI, Docker Desktop, and the Dev Containers CLI as needed. Then select Refresh Check. Choose Continue to use local-only features without changing your system.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      HStack(spacing: 10) {
        Button("Auto Fix") { model.autoFixStartupReadiness() }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: false))

        Button("Refresh Check") { model.refreshAuthStatus() }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Spacer()

        Button("Ignore and Continue") { continueAction() }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }
    }
    .padding(24)
    .frame(width: 640, height: 580)
    .background(DashboardTheme.canvasTop)
  }
}

struct LogConsoleView: NSViewRepresentable {
  let text: String

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder

    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = true
    textView.backgroundColor = NSColor(calibratedRed: 20 / 255, green: 28 / 255, blue: 38 / 255, alpha: 1)
    textView.textColor = NSColor(calibratedRed: 247 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1)
    textView.insertionPointColor = .clear
    textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.textContainerInset = NSSize(width: 12, height: 12)
    textView.isRichText = false
    textView.string = text

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }
    textView.string = text
    textView.backgroundColor = NSColor(calibratedRed: 20 / 255, green: 28 / 255, blue: 38 / 255, alpha: 1)
    textView.textColor = NSColor(calibratedRed: 247 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1)
    textView.scrollToEndOfDocument(nil)
  }
}

private struct TopNavigationBar: View {
  let selection: AppDestination
  let menuVisible: Bool
  let onSelect: (AppDestination) -> Void
  let toggleMenu: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Label("CSA-iEM", systemImage: "square.stack.3d.up.fill")
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)

      Text("Native operator console")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      PillBadge(text: selection.title, tint: selection.tint)

      Spacer(minLength: 8)

      Button(menuVisible ? "Hide Navigation" : "Show Navigation") {
        toggleMenu()
      }
      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

      Menu {
        Section("Workspace") {
          ForEach(workspaceDestinations) { destination in
            Button {
              onSelect(destination)
            } label: {
              Label(destination.title, systemImage: destination.icon)
            }
          }
        }

        Section("Reference") {
          ForEach(knowledgeDestinations) { destination in
            Button {
              onSelect(destination)
            } label: {
              Label(destination.title, systemImage: destination.icon)
            }
          }
        }
      } label: {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(DashboardTheme.text)
          .frame(width: 40, height: 34)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(DashboardTheme.field)
              .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .stroke(DashboardTheme.accent.opacity(0.65), lineWidth: 1)
              )
          )
      }
      .menuStyle(.borderlessButton)
      .help("Open the persistent CSA-iEM navigation menu")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(DashboardTheme.panelAlt)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

private struct CodexFlowStageCard: View {
  let stage: String
  let title: String
  let detail: String
  let rows: [String]
  let icon: String
  let tint: Color
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(tint)
          .frame(width: 38, height: 38)
          .background(tint.opacity(0.16))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          Text(stage.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
          Text(title)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
          Text(detail)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(3)
        }
      }

      VStack(alignment: .leading, spacing: 7) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          HStack(alignment: .top, spacing: 8) {
            Circle()
              .fill(tint)
              .frame(width: 6, height: 6)
              .padding(.top, 5)
            Text(row)
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
              .lineLimit(2)
          }
        }
      }

      Button(actionTitle, action: action)
        .buttonStyle(DashboardButtonStyle(tint: tint, bordered: true))
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 208, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(tint.opacity(0.42), lineWidth: 1)
        )
    )
  }
}

private struct CodexFlowConnector: View {
  let mode: CodexSmartScanMode

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 4) {
        Rectangle()
          .fill(DashboardTheme.link.opacity(0.65))
          .frame(height: 2)
        Image(systemName: "chevron.right.2")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(DashboardTheme.link)
      }

      Image(systemName: mode.icon)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(DashboardTheme.warning)

      Text("Smart Logic")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.warning)
        .multilineTextAlignment(.center)

      Text(mode.label)
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
    .frame(width: 112)
  }
}

private struct CodexDecisionReviewPanel: View {
  let decisions: [CodexSmartDecision]
  let excludedDecisions: [CodexSmartDecision]
  let groupSummaries: [CodexSmartGroupSummary]
  let dispositions: [String: CodexReviewDisposition]
  let catalogStatus: String
  let sessionID: String
  let canonicalSourceByGroup: [String: String]
  @Binding var advisoryProvider: CodexAdvisoryProviderKind
  let advisory: CodexAIAdvisory?
  let advisoryStatus: String
  let onRequestAdvisory: () -> Void
  let onChooseCanonical: (CodexSmartDecision) -> Void
  let onSetDisposition: (CodexSmartDecision, CodexReviewDisposition?) -> Void
  let onReevaluateGroup: (String) -> Void

  private var groupBlockerSummaries: [String] {
    Dictionary(grouping: decisions, by: \.groupKey).compactMap { groupKey, groupDecisions in
      let blockers = groupDecisions.filter { decision in
        switch decision.classification {
        case .shadowCopy, .brokenMetadataReview, .unknownOwnerReview, .fatalIdentityConflict, .sameNameReview:
          return true
        case .canonical, .mergeCandidate, .unrelated:
          return false
        }
      }
      guard !blockers.isEmpty, groupDecisions.count > 1 else { return nil }
      let names = blockers.map { $0.evidence.name }.joined(separator: ", ")
      return "Group \(groupKey): automatic apply remains blocked by review source(s): \(names). Confirm one lead and resolve or explicitly exclude the remaining source(s)."
    }
    .sorted()
  }

  var body: some View {
    PanelCard(
      title: "Smart Logic Decision Review",
      subtitle: "Deterministic evidence is authoritative. Review-only sources remain visible and cannot be silently merged."
    ) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 10) {
          Label(catalogStatus, systemImage: "cylinder.split.1x2")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.accent)
          Spacer()
          if !sessionID.isEmpty {
            Text("Session \(sessionID.prefix(8))")
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.muted)
          }
        }

        HStack(spacing: 8) {
          Picker("Local advisor", selection: $advisoryProvider) {
            ForEach(CodexAdvisoryProviderKind.allCases, id: \.self) { provider in
              Text(provider.rawValue).tag(provider)
            }
          }
          .pickerStyle(.menu)
          Button {
            onRequestAdvisory()
          } label: {
            Label("Ask Local Advisor", systemImage: "sparkles")
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
          Spacer()
        }
        Text(advisoryStatus)
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)

        if let advisory {
          BannerCard(
            title: "Non-authoritative local advisory",
            detail: advisory.summary + "\nSuggested review order: " + (advisory.suggestedReviewIDs.isEmpty ? "none returned" : advisory.suggestedReviewIDs.prefix(5).joined(separator: ", ")),
            kind: .ready
          )
        }

        if groupSummaries.isEmpty == false {
          FieldLabel(text: "Identity groups and destination readiness")
          LazyVStack(alignment: .leading, spacing: 7) {
            ForEach(groupSummaries) { group in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: group.isBlocked ? "exclamationmark.triangle" : "checkmark.seal")
                  .foregroundStyle(group.isBlocked ? DashboardTheme.warning : DashboardTheme.success)
                  .frame(width: 16)
                VStack(alignment: .leading, spacing: 3) {
                  Text(group.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Text("\(group.sourceCount) source(s) · \(group.reviewCount) review blocker(s) · \(group.fatalCount) fatal")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(group.isBlocked ? DashboardTheme.warning : DashboardTheme.muted)
                  Text(group.snapshotState + " · latest change " + group.freshnessLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DashboardTheme.muted)
                  if let lead = group.recommendedLeadName {
                    Text("Lead candidate: " + lead)
                      .font(.system(size: 10, weight: .semibold, design: .rounded))
                      .foregroundStyle(DashboardTheme.deepBlue)
                  }
                  Button("Re-evaluate") {
                    onReevaluateGroup(group.groupKey)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
                  .controlSize(.small)
                }
                Spacer(minLength: 4)
                PillBadge(text: group.isBlocked ? "REVIEW" : "READY", tint: group.isBlocked ? DashboardTheme.warning : DashboardTheme.success)
              }
              .padding(8)
              .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(DashboardTheme.field))
            }
          }
        }

        ForEach(groupBlockerSummaries, id: \.self) { summary in
          BannerCard(
            title: "Identity group requires review",
            detail: summary,
            kind: .warning
          )
        }

        if excludedDecisions.isEmpty == false {
          BannerCard(
            title: "Explicitly excluded sources retained",
            detail: excludedDecisions.map { $0.evidence.name + " — " + $0.sourcePath }.joined(separator: "\n"),
            kind: .ready
          )
          ForEach(excludedDecisions) { decision in
            HStack(spacing: 8) {
              Text(decision.evidence.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
              Spacer(minLength: 4)
              Button("Restore to review") {
                onSetDisposition(decision, nil)
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
              .controlSize(.small)
            }
          }
        }

        if decisions.isEmpty {
          Text("Run Scan Sources to create a persisted identity decision table.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
        } else {
          ForEach(Array(decisions.prefix(8))) { decision in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: decision.classification.systemImage)
                .foregroundStyle(decision.classification.isReview ? DashboardTheme.warning : DashboardTheme.success)
                .frame(width: 18)
              VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                  Text(decision.evidence.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  PillBadge(text: decision.classification.label, tint: decision.classification.isReview ? DashboardTheme.warning : DashboardTheme.success)
                  if decision.isRecommendedLead {
                    PillBadge(text: "Recommended lead", tint: DashboardTheme.success)
                  } else if decision.leadRank > 1 {
                    PillBadge(text: "Lead rank \(decision.leadRank)", tint: DashboardTheme.warning)
                  }
                }
                Text(decision.reasons.joined(separator: " "))
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(2)
                if !decision.evidence.toolEvidence.isEmpty {
                  Label(
                    "Tool context: \(decision.evidence.toolEvidence.map(\.rawValue).joined(separator: ", "))",
                    systemImage: "wrench.and.screwdriver"
                  )
                  .font(.system(size: 10, weight: .semibold, design: .rounded))
                  .foregroundStyle(DashboardTheme.link)
                }
                if !decision.evidence.activeToolEvidence.isEmpty {
                  Label(
                    "Host activity: \(decision.evidence.activeToolEvidence.map(\.rawValue).joined(separator: ", "))",
                    systemImage: "desktopcomputer"
                  )
                  .font(.system(size: 10, weight: .semibold, design: .rounded))
                  .foregroundStyle(DashboardTheme.deepBlue)
                }
                Text(decision.evidence.snapshot.summary)
                  .font(.system(size: 10, weight: .medium, design: .monospaced))
                  .foregroundStyle(DashboardTheme.muted)
                Text(decision.sourcePath)
                  .font(.system(size: 10, weight: .medium, design: .monospaced))
                  .foregroundStyle(DashboardTheme.muted.opacity(0.85))
                  .lineLimit(1)
                if canonicalSourceByGroup[decision.groupKey] == decision.sourcePath {
                  Label("Canonical source for this identity group", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.success)
                } else if decision.classification != .sameNameReview && decision.classification != .brokenMetadataReview && decision.classification != .fatalIdentityConflict {
                  Button {
                    onChooseCanonical(decision)
                  } label: {
                    Label("Use as canonical", systemImage: "checkmark.seal")
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
                  .controlSize(.small)
                }
                if decision.classification.isReview {
                  HStack(spacing: 6) {
                    let disposition = dispositions[decision.sourcePath]
                    Button(disposition == .deferred ? "Resume review" : "Defer") {
                      onSetDisposition(decision, disposition == .deferred ? nil : .deferred)
                    }
                    .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                    .controlSize(.small)
                    Button("Exclude") {
                      onSetDisposition(decision, .excluded)
                    }
                    .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
                    .controlSize(.small)
                    if let disposition {
                      PillBadge(text: disposition.label, tint: disposition == .deferred ? DashboardTheme.warning : DashboardTheme.deepBlue)
                    }
                  }
                }
              }
              Spacer(minLength: 8)
              Text("\(Int(decision.confidence * 100))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            }
            .padding(.vertical, 6)
            Divider().overlay(DashboardTheme.border)
          }
          if decisions.count > 8 {
            Text("Showing 8 of \(decisions.count) decisions. Use the project list for the complete set.")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          }
        }
      }
    }
  }
}

struct ContentView: View {
  @ObservedObject private var model: CleanupViewModel
  @State private var selectedDestination: AppDestination = .home
  @State private var isMenuVisible = true
  @State private var showLaunchWarning = false
  @State private var showStartupReadiness = false
  @State private var acceptedRisk = false
  @State private var acceptedPurpose = false

  init(model: CleanupViewModel) {
    self.model = model
  }

  private var actionToggleTint: Color { DashboardTheme.accent }

  var body: some View {
    GeometryReader { geometry in
      let canUseSidebarMenu = geometry.size.width >= 1440
      let showSidebarMenu = canUseSidebarMenu && isMenuVisible
      let showCompactMenu = !canUseSidebarMenu && isMenuVisible
      let detailWidth = max(geometry.size.width - (showSidebarMenu ? 360 : 32), 640)

      ZStack {
        LinearGradient(
          colors: [DashboardTheme.canvasTop, DashboardTheme.canvasBottom],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 12) {
          TopNavigationBar(
            selection: selectedDestination,
            menuVisible: isMenuVisible,
            onSelect: { destination in
              selectedDestination = destination
            },
            toggleMenu: {
              isMenuVisible.toggle()
            }
          )

          if let activeOperationLabel = model.activeOperationLabel {
            ActivityStrip(
              title: activeOperationLabel,
              detail: model.isRunningLocalFileOperation ? "The app is working in the background. Keep this window open to follow the operation." : "The app is checking local or connected services. You can continue browsing other pages.",
              isIndeterminate: true
            )
            .transition(.move(edge: .top).combined(with: .opacity))
          }

          Group {
            if showSidebarMenu {
              HStack(alignment: .top, spacing: 18) {
                AppSidebarMenu(selection: selectedDestination) { destination in
                  selectedDestination = destination
                }
                .frame(width: 320)

                pageContainer(for: detailWidth, usesSidebar: canUseSidebarMenu)
                  .frame(maxWidth: .infinity, alignment: .topLeading)
              }
            }
            else {
              VStack(spacing: 12) {
                if showCompactMenu {
                  CompactDestinationBar(selection: selectedDestination) { destination in
                    selectedDestination = destination
                  }
                }

                pageContainer(for: detailWidth, usesSidebar: canUseSidebarMenu)
                  .frame(maxWidth: .infinity, alignment: .topLeading)
              }
            }
          }

          BottomStatusBar(
            kind: model.statusKind,
            status: model.statusCompactLabel,
            session: model.sessionCompactLabel,
            selection: model.selectionCompactLabel,
            destination: selectedDestination
          )
        }
        .padding(16)
      }
    }
    .frame(minWidth: 760, minHeight: 640)
    .preferredColorScheme(.dark)
    .tint(DashboardTheme.link)
    .onAppear {
      let shouldShowWarning = !model.appSettings.firstRunComplete
      showLaunchWarning = shouldShowWarning
      showStartupReadiness = false
      acceptedRisk = !shouldShowWarning
      acceptedPurpose = !shouldShowWarning
    }
    .sheet(isPresented: $showLaunchWarning) {
      LaunchWarningSheet(
        acceptedRisk: $acceptedRisk,
        acceptedPurpose: $acceptedPurpose,
        brandMark: model.bundledBrandMark,
        continueAction: {
          model.markLaunchWarningAccepted()
          showLaunchWarning = false
          showStartupReadiness = true
        },
        quitAction: {
          NSApp.terminate(nil)
        }
      )
      .interactiveDismissDisabled(true)
    }
    .sheet(isPresented: $showStartupReadiness) {
      StartupReadinessSheet(model: model) {
        model.markLaunchWarningAccepted()
        showStartupReadiness = false
      }
      .interactiveDismissDisabled(true)
    }
  }

  @ViewBuilder
  private func pageContainer(for width: CGFloat, usesSidebar: Bool) -> some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(spacing: 18) {
        switch selectedDestination {
        case .home:
          homePage(for: width, usesSidebar: usesSidebar)
        case .jobs:
          jobsPage(for: width, usesSidebar: usesSidebar)
        case .incidents:
          incidentsPage(for: width, usesSidebar: usesSidebar)
        case .issues:
          issuesPage(for: width, usesSidebar: usesSidebar)
        case .githubAccount:
          githubAccountPage(for: width, usesSidebar: usesSidebar)
        case .githubBilling:
          githubBillingPage(for: width, usesSidebar: usesSidebar)
        case .imports:
          importPage(for: width, usesSidebar: usesSidebar)
        case .projects:
          projectsPage(for: width, usesSidebar: usesSidebar)
        case .codexPortal:
          codexPortalPage(for: width, usesSidebar: usesSidebar)
        case .projectBackups:
          projectBackupPage(for: width, usesSidebar: usesSidebar)
        case .localFiles:
          localFilesPage(for: width, usesSidebar: usesSidebar)
        case .cleanup:
          cleanupPage(for: width, usesSidebar: usesSidebar)
        case .workspace:
          workspacePage(for: width, usesSidebar: usesSidebar)
        case .settings:
          settingsPage(for: width, usesSidebar: usesSidebar)
        case .about:
          aboutPage(usesSidebar: usesSidebar)
        case .helpCenter, .terms, .security, .brandSystem, .macOSNotes, .projectInfo:
          documentPage(for: selectedDestination, usesSidebar: usesSidebar)
        }
      }
      .frame(maxWidth: 3200)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  private func homePage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: selectedDestination,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      homeLayout(for: width)
    }
  }

  private func jobsPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .jobs,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1500 {
        HStack(alignment: .top, spacing: 18) {
          jobsCenterPanel
            .frame(maxWidth: 520, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            repoHealthPanel
            logPanel(minHeight: 420)
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          jobsCenterPanel
          repoHealthPanel
          logPanel(minHeight: 320)
        }
      }
    }
  }

  private func incidentsPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(brandMark: model.bundledBrandMark, compact: width < 1280)
      WorkspaceToolbarStrip(destination: .incidents, menuVisible: isMenuVisible, usesSidebar: usesSidebar) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        PanelCard(title: "Incident Hub", subtitle: "Recoverable work should continue; fatal identity, integrity, authorization, and deletion-safety blockers remain visible and require review.") {
          BannerCard(
            title: "\(model.openIncidentCount) open incident\(model.openIncidentCount == 1 ? "" : "s")",
            detail: "Failures and cancellations from the Jobs Center are retained locally with their job, target, detail, and next review path.",
            kind: model.openIncidentCount == 0 ? .ready : .warning
          )
          HStack(spacing: 10) {
            Button("Clear Resolved") { model.clearResolvedIncidents() }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
              .disabled(model.incidents.allSatisfy { $0.state != .resolved })
            Text("Local only · no credentials or raw prompts are stored")
              .font(.system(size: 12, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          }
        }

        incidentClustersPanel

        if width >= 1200 {
          HStack(alignment: .top, spacing: 18) {
            incidentListPanel
              .frame(maxWidth: 520, alignment: .topLeading)
            incidentDetailPanel
              .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          incidentListPanel
          incidentDetailPanel
        }
      }
    }
  }

  private var incidentClustersPanel: some View {
    PanelCard(title: "Correlated incident chains", subtitle: "Incidents with the same operation, lifecycle stage, source, and destination are grouped so repeated failures do not look like unrelated projects.") {
      if model.incidentClusters.isEmpty {
        Text("No incident chains are available yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
          ForEach(model.incidentClusters) { cluster in
            Button { model.selectIncidentCluster(cluster) } label: {
              VStack(alignment: .leading, spacing: 7) {
                HStack {
                  Text(cluster.target.isEmpty ? "Unknown target" : cluster.target)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 5)
                  if cluster.fatalCount > 0 { PillBadge(text: "\(cluster.fatalCount) fatal", tint: DashboardTheme.danger) }
                }
                Text(cluster.summary)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(2)
              }
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(model.selectedIncidentClusterKey == cluster.key ? DashboardTheme.field : DashboardTheme.panelStrong))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func issuesPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(brandMark: model.bundledBrandMark, compact: width < 1280)
      WorkspaceToolbarStrip(destination: .issues, menuVisible: isMenuVisible, usesSidebar: usesSidebar) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        PanelCard(title: "GitHub Issues", subtitle: "Read first. Draft locally. Create remotely only after reviewing and arming the exact title, body, repository, and labels.") {
          BannerCard(title: model.issueStatus, detail: "Remote issue creation is disabled until the reviewed draft is explicitly armed.", kind: model.issueWriteArmed ? .warning : .ready)
          HStack(spacing: 10) {
            Button("Load Issues") { model.loadGitHubIssues() }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
              .disabled(model.isLoadingIssues)
            Button("Open Issues in GitHub") { model.openRepoIssuesPage() }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))
            Button("Copy Draft") { model.copyIssueDraft() }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
              .disabled(model.issueDraftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }

        if width >= 1200 {
          HStack(alignment: .top, spacing: 18) {
            issuesListPanel.frame(maxWidth: 520, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 18) {
              issueComposerPanel
              issueMutationPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          issuesListPanel
          issueComposerPanel
          issueMutationPanel
        }
      }
    }
  }

  private var issuesListPanel: some View {
    PanelCard(title: "Remote issue list", subtitle: "Read-only `gh issue list` results for the selected repository.") {
      if model.githubIssues.isEmpty {
        Text("No issue results loaded yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(model.githubIssues) { issue in
              Button {
                model.selectedIssueNumber = issue.number
                model.issueMutationLabels = issue.labels.joined(separator: ",")
                model.resetIssueMutationArm("Issue #\(issue.number) selected. Review the remote action before arming it.")
              } label: {
                VStack(alignment: .leading, spacing: 7) {
                  HStack {
                    Text("#\(issue.number) \(issue.title)")
                      .font(.system(size: 14, weight: .bold, design: .rounded))
                      .foregroundStyle(DashboardTheme.text)
                      .lineLimit(2)
                    Spacer(minLength: 6)
                    PillBadge(text: issue.state, tint: issue.state.lowercased() == "open" ? DashboardTheme.success : DashboardTheme.muted)
                  }
                  Text([issue.createdAt, issue.updatedAt].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(model.selectedIssueNumber == issue.number ? DashboardTheme.field : DashboardTheme.panelStrong))
              }
              .buttonStyle(.plain)
            }
          }
        }
        .frame(minHeight: 220, idealHeight: 360, maxHeight: 520)
      }
    }
  }

  private var issueComposerPanel: some View {
    PanelCard(title: "Local issue composer", subtitle: "Templates and incident drafts stay local until you deliberately arm the remote operation.") {
      HStack(spacing: 10) {
        Picker("Template", selection: Binding(get: { model.selectedIssueTemplateID ?? model.issueTemplates.first?.id ?? "" }, set: { model.selectedIssueTemplateID = $0 })) {
          ForEach(model.issueTemplates) { template in
            Text(template.name).tag(template.id)
          }
        }
        .pickerStyle(.menu)
        Button("Load Template") { model.applySelectedIssueTemplate() }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        Button("Use Selected Incident") {
          if let incident = model.selectedIncident { model.prepareIssueDraft(for: incident) }
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.selectedIncident == nil)
      }

      FieldLabel(text: "Title")
      TextField("Issue title", text: $model.issueDraftTitle)
        .textFieldStyle(.plain)
        .foregroundStyle(DashboardTheme.text)
        .dashboardFieldStyle()
        .onChange(of: model.issueDraftTitle) { _ in model.issueWriteArmed = false }

      FieldLabel(text: "Labels (comma-separated)")
      TextField("csa-iem,incident", text: $model.issueDraftLabels)
        .textFieldStyle(.plain)
        .foregroundStyle(DashboardTheme.text)
        .dashboardFieldStyle()
        .onChange(of: model.issueDraftLabels) { _ in model.issueWriteArmed = false }

      FieldLabel(text: "Body")
      TextEditor(text: $model.issueDraftBody)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(DashboardTheme.text)
        .frame(minHeight: 280)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DashboardTheme.field))
        .onChange(of: model.issueDraftBody) { _ in model.issueWriteArmed = false }

      Toggle("I reviewed the exact repository, title, body, and labels; arm remote create", isOn: $model.issueWriteArmed)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)

      Button("Create GitHub Issue") { model.createGitHubIssueFromDraft() }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
        .disabled(!model.issueWriteArmed)
    }
  }

  private var issueMutationPanel: some View {
    PanelCard(title: "Reviewed issue action", subtitle: "Comment, lifecycle, and label changes stay disabled until you select an issue and explicitly arm this exact remote mutation.") {
      BannerCard(title: model.issueMutationStatus, detail: "The action is executed through the authenticated GitHub CLI session. CSA-iLEM reads the provider state back and marks the job successful only when it matches.", kind: model.issueMutationArmed ? .warning : .ready)

      if !model.issueMutationRetries.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          FieldLabel(text: "Saved retry records")
          ForEach(model.issueMutationRetries) { record in
            HStack(spacing: 10) {
              VStack(alignment: .leading, spacing: 3) {
                Text(record.summary)
                  .font(.system(size: 12, weight: .bold, design: .rounded))
                  .foregroundStyle(DashboardTheme.text)
                Text(record.lastError)
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(2)
              }
              Spacer(minLength: 4)
              Button("Prepare") { model.prepareIssueMutationRetry(record) }
                .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DashboardTheme.panelStrong))
          }
        }
      }

      HStack(spacing: 10) {
        Picker("Action", selection: Binding(get: { model.selectedIssueMutation }, set: { value in
          model.selectedIssueMutation = value
          model.resetIssueMutationArm("Action changed to \(value.title). Review the payload before arming it.")
        })) {
          ForEach(CSAiEMGitHubIssueMutation.allCases) { mutation in
            Text(mutation.title).tag(mutation)
          }
        }
        .pickerStyle(.menu)
        Spacer(minLength: 4)
        if let issue = model.selectedIssue {
          PillBadge(text: "#\(issue.number) · \(issue.state)", tint: issue.state.lowercased() == "open" ? DashboardTheme.success : DashboardTheme.muted)
        } else {
          PillBadge(text: "No issue", tint: DashboardTheme.muted)
        }
      }

      if model.selectedIssueMutation.requiresBody {
        FieldLabel(text: "Comment")
        TextEditor(text: $model.issueMutationBody)
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(DashboardTheme.text)
          .frame(minHeight: 130)
          .padding(10)
          .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DashboardTheme.field))
          .onChange(of: model.issueMutationBody) { _ in model.resetIssueMutationArm() }
      }

      if model.selectedIssueMutation.requiresLabels {
        FieldLabel(text: "Labels (comma-separated)")
        TextField("needs-review, recovery", text: $model.issueMutationLabels)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
          .onChange(of: model.issueMutationLabels) { _ in model.resetIssueMutationArm() }
      }

      Toggle("I reviewed the exact issue, action, and payload; arm remote update", isOn: $model.issueMutationArmed)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .disabled(model.selectedIssue == nil)

      Button("Apply GitHub Issue Action") { model.mutateSelectedGitHubIssue() }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
        .disabled(!model.issueMutationArmed || model.selectedIssue == nil)
    }
  }

  private var incidentListPanel: some View {
    PanelCard(title: "Recorded incidents", subtitle: "Select an incident to inspect evidence, retry the originating job, or resolve it with an operator note.") {
      if model.incidents.isEmpty {
        Text("No failed or cancelled jobs have been recorded.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(model.incidents) { incident in
              Button { model.selectedIncidentID = incident.id } label: {
                VStack(alignment: .leading, spacing: 7) {
                  HStack {
                    Text(incident.title)
                      .font(.system(size: 14, weight: .bold, design: .rounded))
                      .foregroundStyle(DashboardTheme.text)
                    Spacer(minLength: 6)
                    PillBadge(text: incident.statusLabel, tint: incident.state == .resolved ? DashboardTheme.success : (incident.severity == .fatal ? DashboardTheme.danger : DashboardTheme.warning))
                  }
                  Text([incident.kind, incident.target, incident.detail].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                    .lineLimit(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(model.selectedIncidentID == incident.id ? DashboardTheme.field : DashboardTheme.panelStrong))
              }
              .buttonStyle(.plain)
            }
          }
        }
        .frame(minHeight: 220, idealHeight: 360, maxHeight: 520)
      }
    }
  }

  private var incidentDetailPanel: some View {
    PanelCard(title: "Incident evidence and handoff", subtitle: "The issue draft is deterministic and redacted. Review it before using any external issue tracker.") {
        if let incident = model.selectedIncident {
        BannerCard(title: incident.title, detail: [incident.kind, incident.target, incident.detail, incident.evidence.summaryLines.joined(separator: "\n")].filter { !$0.isEmpty }.joined(separator: "\n"), kind: incident.severity == .fatal ? .error : .warning)
        HStack(spacing: 10) {
          Button("Retry originating job") {
            if let job = model.backgroundJobs.first(where: { $0.id == incident.jobID }) { model.retryJob(job) }
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
          Button(incident.state == .resolved ? "Resolved" : "Mark resolved") {
            model.resolveIncident(incident)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
          .disabled(incident.state == .resolved)
          Button("Copy issue draft") {
            model.copyIncidentDraft(incident)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        }
        Text(CSAiEMIncidentClassifier.redactedIssueDraft(for: incident))
          .font(.system(size: 12, weight: .regular, design: .monospaced))
          .foregroundStyle(DashboardTheme.text)
          .textSelection(.enabled)
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DashboardTheme.panelStrong))
      } else {
        Text("Select an incident to see its evidence and recovery actions.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
    }
  }

  private func projectsPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .projects,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        if width >= 1400 {
          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
              overviewPanel
              rootsPanel
              favoritesAndViewsPanel
            }
            .frame(maxWidth: 420, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
              localProjectsPanel
              projectQuickActionsPanel
              taskTemplatesPanel
            }
              .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          overviewPanel
          rootsPanel
          favoritesAndViewsPanel
          localProjectsPanel
          projectQuickActionsPanel
          taskTemplatesPanel
        }

        liveServicesPanel

        if width >= 1450 {
          HStack(alignment: .top, spacing: 18) {
            projectSyncPanel
            storageInsightsPanel
            portMonitorPanel
          }
        } else {
          projectSyncPanel
          storageInsightsPanel
          portMonitorPanel
        }
      }
    }
  }

  private func codexFlowDashboard(for width: CGFloat) -> some View {
    PanelCard(
      title: "Codex Project Control Plane",
      subtitle: "One bounded source set on the left, one final destination on the right, and a visible Smart Logic decision path between them."
    ) {
      Group {
        if width >= 1050 {
          HStack(alignment: .top, spacing: 12) {
            CodexFlowStageCard(
              stage: "01 · Import",
              title: "Source folders",
              detail: "Read local evidence from selected roots. No copy, merge, upload, or delete happens during this scan.",
              rows: [
                "\(model.codexProjects.count) project candidate(s) currently indexed",
                "\(model.selectedCodexProjectPaths.count) source(s) selected for this run",
                "Roots: \(model.codexScanRootsDraft.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Add a source folder")"
              ],
              icon: "square.and.arrow.down",
              tint: DashboardTheme.accent,
              actionTitle: model.isScanningCodexProjects ? "Scanning…" : "Scan Sources",
              action: {
                model.scanCodexProjects()
              }
            )

            CodexFlowConnector(mode: model.codexSmartScanMode)
              .padding(.top, 54)

            CodexFlowStageCard(
              stage: "02 · Output",
              title: "Final destination",
              detail: "Keep one destination per project identity. Extra or ambiguous material is routed to review or Archive_Data.",
              rows: [
                "\(model.codexSmartOutputCount) destination candidate(s) in the current run",
                "\(model.codexSmartIndexStatus) · resume without rebuilding unchanged tables",
                "Archive lane: \(model.codexSmartArchivePath)"
              ],
              icon: "externaldrive.fill",
              tint: DashboardTheme.deepBlue,
              actionTitle: "Open Output Folder",
              action: {
                model.openCodexOutputRoot()
              }
            )
          }
        } else {
          VStack(alignment: .leading, spacing: 12) {
            CodexFlowStageCard(
              stage: "01 · Import",
              title: "Source folders",
              detail: "Read local evidence first; no destructive action is attached to the scan button.",
              rows: [
                "\(model.codexProjects.count) candidate(s) · \(model.selectedCodexProjectPaths.count) selected",
                "\(model.codexScanRootsDraft.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Add a source folder")"
              ],
              icon: "square.and.arrow.down",
              tint: DashboardTheme.accent,
              actionTitle: model.isScanningCodexProjects ? "Scanning…" : "Scan Sources",
              action: {
                model.scanCodexProjects()
              }
            )

            CodexFlowConnector(mode: model.codexSmartScanMode)
              .frame(maxWidth: .infinity)

            CodexFlowStageCard(
              stage: "02 · Output",
              title: "Final destination",
              detail: "One final destination per project identity; ambiguous data stays visible for review.",
              rows: [
                "\(model.codexSmartOutputCount) destination candidate(s)",
                "\(model.codexSmartIndexStatus) · \(model.codexSmartArchivePath)"
              ],
              icon: "externaldrive.fill",
              tint: DashboardTheme.deepBlue,
              actionTitle: "Open Output Folder",
              action: {
                model.openCodexOutputRoot()
              }
            )
          }
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
        MetricTile(label: "Sources indexed", value: "\(model.codexProjects.count)", tint: DashboardTheme.accent, icon: "folder.badge.questionmark")
        MetricTile(label: "Ready candidates", value: "\(model.codexSmartReadyCount)", tint: DashboardTheme.success, icon: "checkmark.seal")
        MetricTile(label: "Needs review", value: "\(model.codexSmartReviewCount)", tint: DashboardTheme.warning, icon: "exclamationmark.magnifyingglass")
        MetricTile(label: "Output plans", value: "\(model.codexSmartOutputCount)", tint: DashboardTheme.deepBlue, icon: "arrow.right.doc.on.clipboard")
      }

      Divider().overlay(DashboardTheme.border)

      VStack(alignment: .leading, spacing: 10) {
        FieldLabel(text: "Smart Scan Profile")
        Picker("Smart Scan Profile", selection: $model.codexSmartScanMode) {
          ForEach(CodexSmartScanMode.allCases) { mode in
            Label(mode.label, systemImage: mode.icon)
              .tag(mode)
          }
        }
        .pickerStyle(.segmented)

        Text(model.codexSmartScanMode.subtitle)
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineSpacing(2)

        Text(model.codexSmartSafetySummary)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(model.codexSmartScanMode == .yolo ? DashboardTheme.warning : DashboardTheme.text)
          .lineSpacing(2)

        if let plan = model.codexSmartScanPlan {
          VStack(alignment: .leading, spacing: 4) {
            Text("Smart Logic route plan")
              .font(.system(size: 11, weight: .bold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            Text(plan.headline)
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.muted)
            Text(plan.profileGuidance(CodexEvidenceScanProfile(rawValue: model.codexSmartScanMode.rawValue) ?? .fastIndex))
              .font(.system(size: 10, weight: .medium, design: .rounded))
              .foregroundStyle(plan.targetedVerificationCount > 0 && model.codexSmartScanMode != .verified ? DashboardTheme.warning : DashboardTheme.muted)
          }
          .padding(8)
          .background(DashboardTheme.field, in: RoundedRectangle(cornerRadius: 8))
        }

        codexRouteReceiptPanel()

        FieldLabel(text: "Backup Medium")
        Picker("Backup Medium", selection: $model.codexBackupMedium) {
          ForEach(CodexBackupMedium.allCases) { medium in
            Text(medium.label).tag(medium)
          }
        }
        .pickerStyle(.menu)

        Text(model.codexBackupMedium.subtitle)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }

      HStack(spacing: 10) {
        Picker("Transfer", selection: $model.codexTransferMode) {
          ForEach(CodexProjectTransferMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 260, alignment: .leading)

        Button {
          model.preflightCodexTransfer()
        } label: {
          Label(model.isBuildingCodexTransferPlan ? "Indexing…" : "Build Decision Scan", systemImage: "checkmark.shield")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.selectedCodexProjectPaths.isEmpty || model.isCodexPortalBusy)

        Button {
          model.runCodexTransfer()
        } label: {
          Label(model.isRunningCodexTransfer ? "Running…" : "Run Selected", systemImage: "play.fill")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.selectedCodexProjectPaths.isEmpty || model.isCodexPortalBusy)
      }

      BannerCard(
        title: model.codexSmartDecisionSummary,
        detail: "Index: \(model.codexSmartIndexPath)\nOutput: \(model.codexOutputRootDraft)\nBridges: \(model.codexBridgeSummary)",
        kind: model.isCodexPortalBusy ? .running : (model.codexSmartReviewCount > 0 ? .warning : .ready)
      )

      Text(model.codexGroupReviewStatus)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      HStack(spacing: 8) {
        Text(model.codexScanDeltaStatus)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
        Spacer()
        Button("Undo last review action") {
          model.undoLastCodexReviewAction()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .controlSize(.small)
        .disabled(!model.codexReviewAudit.contains { $0.action == "disposition-changed" })
      }

      if let sessionDiff = model.codexSessionDiffSummary {
        PanelCard(
          title: "Indexed session diff",
          subtitle: "SQLite-backed evidence for what this scan evaluated and what it safely reused."
        ) {
          VStack(alignment: .leading, spacing: 7) {
            Text(sessionDiff.headline)
              .font(.system(size: 12, weight: .bold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            Text("Added \(sessionDiff.addedCount) · changed \(sessionDiff.changedCount) · unchanged \(sessionDiff.unchangedCount) · removed \(sessionDiff.removedCount) · affected groups \(sessionDiff.affectedGroupCount)")
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.muted)
            Text("Evaluated \(sessionDiff.evaluatedSourceCount) source row(s) · reused \(sessionDiff.reusedSourceCount) · discovery \(sessionDiff.timing.discoveryMilliseconds) ms · decision \(sessionDiff.timing.decisionMilliseconds) ms · total \(sessionDiff.timing.totalMilliseconds) ms")
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.muted)
            Picker("Compare saved session", selection: Binding(
              get: { model.codexComparisonSessionID },
              set: { model.selectCodexComparisonSession($0) }
            )) {
              ForEach(model.codexRecentSessions) { session in
                Text("\(session.shortID) · \(session.profile) · \(session.decisionCount) decisions")
                  .tag(session.id)
              }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 420, alignment: .leading)

            Picker("Compare against baseline", selection: Binding(
              get: { model.codexComparisonBaselineSessionID },
              set: {
                model.codexComparisonBaselineSessionID = $0
                model.compareCodexSessions(currentSessionID: model.codexComparisonSessionID, baselineSessionID: $0)
              }
            )) {
              Text("No baseline").tag("")
              ForEach(model.codexRecentSessions.filter { $0.id != model.codexComparisonSessionID }) { session in
                Text("\(session.shortID) · \(session.profile) · \(session.decisionCount) decisions")
                  .tag(session.id)
              }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 420, alignment: .leading)

            Picker("Identity group filter", selection: Binding(
              get: { model.codexComparisonGroupKey },
              set: { model.setCodexComparisonGroup($0) }
            )) {
              Text("All identity groups").tag("")
              ForEach(Array(Set(model.codexSmartDecisions.map(\.groupKey))).sorted(), id: \.self) { groupKey in
                Text(groupKey).tag(groupKey)
              }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 420, alignment: .leading)

            Text(model.codexComparisonStatus)
              .font(.system(size: 10, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
            HStack(spacing: 8) {
              Button("Export comparison evidence") {
                model.exportCodexComparisonEvidence()
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
              .controlSize(.small)
              .disabled(model.codexComparisonSessionID.isEmpty || model.codexVisibleDecisionComparisonRows.isEmpty)
              Text("Writes read-only JSON and CSV to the local catalog Exports folder.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }
            if !model.codexComparisonExportStatus.isEmpty {
              Text(model.codexComparisonExportStatus)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.muted)
                .textSelection(.enabled)
            }
            HStack(spacing: 8) {
              Button("Inspect exported JSON") {
                model.chooseCodexEvidenceBundle()
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
              .controlSize(.small)
              Text("Imported evidence stays outside the live SQLite catalog.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }
            Text(model.codexImportedEvidenceStatus)
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.muted)
              .textSelection(.enabled)
            if !model.codexImportedEvidenceHistory.isEmpty {
              DisclosureGroup("Imported evidence history · " + String(model.codexImportedEvidenceHistory.count)) {
                VStack(alignment: .leading, spacing: 5) {
                  Picker("History filter", selection: $model.codexEvidenceHistoryFilter) {
                    ForEach(CodexEvidenceHistoryFilter.allCases) { filter in
                      Text(filter.label).tag(filter)
                    }
                  }
                  .pickerStyle(.menu)
                  .frame(maxWidth: 320, alignment: .leading)
                  let visibleHistoryCount = String(model.codexVisibleEvidenceHistory.count)
                  let totalHistoryCount = String(model.codexImportedEvidenceHistory.count)
                  Text("Showing " + visibleHistoryCount + " of " + totalHistoryCount + " retained entry(s).")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                  ForEach(model.codexVisibleEvidenceHistory) { record in
                    HStack(spacing: 8) {
                      let historyLabel = record.sourceName + " · " + String(record.bundle.rows.count) + " row(s) · " + record.profileLabel + " · " + record.profileAuditLabel + " · " + record.compatibilityState.label
                      Button(historyLabel) {
                        model.inspectCodexEvidenceRecord(record)
                      }
                      .buttonStyle(.plain)
                      .foregroundStyle(DashboardTheme.text)
                      Spacer()
                      Button("Remove") {
                        model.removeCodexEvidenceRecord(record)
                      }
                      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                      .controlSize(.mini)
                    }
                  }
                  Button("Clear imported evidence history") {
                    model.clearCodexEvidenceHistory()
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                  .controlSize(.small)
                }
              }
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            }
            if let authority = model.codexImportedAuthorityComparison {
              DisclosureGroup("Evidence authority boundary") {
                VStack(alignment: .leading, spacing: 4) {
                  Text("LIVE CATALOG · authoritative · session " + String(authority.liveSessionID.prefix(8)))
                  Text("IMPORTED BUNDLE · read-only · session " + String(authority.importedCurrentSessionID.prefix(8)))
                  Text("Current-session identity match: " + (authority.sameCurrentSession ? "yes" : "no"))
                  Text("Rows live/imported: " + String(authority.liveRowCount) + " / " + String(authority.importedRowCount) + " · overlapping sources: " + String(authority.overlappingSourceCount))
                  Text("Live-only sources: " + String(authority.liveOnlySourceCount) + " · imported-only sources: " + String(authority.importedOnlySourceCount))
                  Text("Imported evidence never overrides live catalog authority.")
                  Picker("Provenance filter", selection: $model.codexEvidenceProvenanceFilter) {
                    ForEach(CodexEvidenceProvenanceFilter.allCases) { filter in
                      Text(filter.label).tag(filter)
                    }
                  }
                  .pickerStyle(.menu)
                  .frame(maxWidth: 300, alignment: .leading)
                  Text("Showing " + String(model.codexVisibleEvidenceProvenanceRows.count) + " source(s) for this filter.")
                  if let routeSummary = model.codexEvidenceScanRouteSummary {
                    Text("Routing summary · " + routeSummary.headline)
                    Text("Fast path avoids " + String(routeSummary.deepScanAvoidedCount) + " deep scan(s); targeted verification remains operator-controlled.")
                    if let assessment = model.codexEvidenceProfileAssessment {
                      Text("Selected profile · " + model.codexSmartScanMode.label + " · " + assessment.headline)
                        .foregroundStyle(assessment.strongerProfileRecommended ? DashboardTheme.warning : DashboardTheme.muted)
                    }
                  }
                  ForEach(Array(model.codexVisibleEvidenceProvenanceRows.prefix(12))) { row in
                    let liveKind = row.liveKind?.rawValue.uppercased() ?? "—"
                    let importedKind = row.importedKind?.rawValue.uppercased() ?? "—"
                    let evidenceLabel = row.actionability.label.uppercased() + " · " + row.scanRoute.label.lowercased()
                    let transitionLabel = " · live " + liveKind + " · imported " + importedKind
                    Text(evidenceLabel + " · " + row.sourcePath + transitionLabel)
                      .textSelection(.enabled)
                  }
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.muted)
              }
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            }
            if let imported = model.codexImportedEvidenceBundle {
              let importedCurrentSession = String(imported.currentSessionID.prefix(8))
              let importedBaselineSession = imported.baselineSessionID.map { String($0.prefix(8)) } ?? "none"
              let importedRuleVersions = (imported.currentRuleVersion ?? "unknown") + " / " + (imported.baselineRuleVersion ?? "unknown")
              let importedRowCount = String(imported.rows.count)
              DisclosureGroup("Inspected evidence · " + importedRowCount + " row(s)") {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Current " + importedCurrentSession + " · baseline " + importedBaselineSession)
                  Text("Rule versions: " + importedRuleVersions)
                  Text("Profile metadata: " + CodexImportedEvidenceRecord(id: "inspected", sourceName: "", importedAt: imported.exportedAt, bundle: imported).compatibilityState.label)
                  if let importedProfile = imported.selectedScanProfile {
                    Text("Exported scan profile: " + importedProfile.rawValue)
                  }
                  if let importedAssessment = imported.profileAssessment {
                    Text("Exported profile assessment: " + importedAssessment.headline)
                  }
                  ForEach(Array(imported.rows.prefix(12))) { row in
                    Text("\(row.kind.rawValue.uppercased()) · \(row.sourcePath) · \(row.explanation)")
                      .textSelection(.enabled)
                  }
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.muted)
              }
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            }
            if !model.codexVisibleComparisonDeltas.isEmpty {
              LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(model.codexVisibleComparisonDeltas.prefix(12))) { delta in
                  Text("\(delta.kind.rawValue.uppercased()) · \(delta.sourcePath)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(delta.kind == .unchanged ? DashboardTheme.muted : DashboardTheme.warning)
                    .textSelection(.enabled)
                }
              }
            }

            if !model.codexVisibleDecisionComparisonRows.isEmpty {
              DisclosureGroup("Decision transitions · \(model.codexVisibleDecisionComparisonRows.count)") {
                LazyVStack(alignment: .leading, spacing: 5) {
                  ForEach(Array(model.codexVisibleDecisionComparisonRows.prefix(20))) { row in
                    VStack(alignment: .leading, spacing: 2) {
                      Text("\(row.kind.rawValue.uppercased()) · \(row.sourcePath)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(row.kind == .unchanged ? DashboardTheme.muted : DashboardTheme.warning)
                      Text(row.explanation)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(DashboardTheme.muted)
                    }
                  }
                }
              }
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            }

            HStack(spacing: 8) {
              TextField("Why rebuild the scan baseline?", text: $model.codexBaselineRebuildReason)
                .textFieldStyle(.plain)
                .foregroundStyle(DashboardTheme.text)
                .dashboardFieldStyle()
              Button("Rebuild baseline") {
                model.rebuildCodexScanBaseline()
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
              .disabled(model.codexBaselineRebuildReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !model.codexRecentSessions.isEmpty {
              DisclosureGroup("Recent catalog sessions · \(model.codexRecentSessions.count)") {
                ForEach(model.codexRecentSessions) { session in
                  Text("\(session.shortID) · \(session.profile) · \(session.decisionCount) decisions · \(ISO8601DateFormatter().string(from: session.createdAt))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DashboardTheme.muted)
                    .textSelection(.enabled)
                }
              }
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            }
          }
        }
      }

      if !model.codexReviewAudit.isEmpty {
        DisclosureGroup("Review audit · latest \(min(model.codexReviewAudit.count, 5))") {
          ForEach(Array(model.codexReviewAudit.suffix(5).reversed())) { entry in
            Text("\(entry.action) · \(entry.detail)")
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(DashboardTheme.muted)
              .textSelection(.enabled)
          }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
      }

      Text(model.codexCanonicalSelectionSummary)
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(model.codexMissingCanonicalGroupCount == 0 ? DashboardTheme.success : DashboardTheme.warning)

      CodexDecisionReviewPanel(
        decisions: model.codexActiveSmartDecisions,
        excludedDecisions: model.codexExcludedSmartDecisions,
        groupSummaries: model.codexSmartGroupSummaries,
        dispositions: model.codexReviewDispositions,
        catalogStatus: model.codexCatalogStatus,
        sessionID: model.codexActiveSessionID,
        canonicalSourceByGroup: model.codexCanonicalSourceByGroup,
        advisoryProvider: $model.codexAdvisoryProviderKind,
        advisory: model.codexAdvisory,
        advisoryStatus: model.codexAdvisoryStatus,
        onRequestAdvisory: {
          model.requestCodexLocalAdvisory()
        },
        onChooseCanonical: { decision in
          model.chooseCodexCanonicalSource(decision)
        },
        onSetDisposition: { decision, disposition in
          model.setCodexReviewDisposition(decision, disposition: disposition)
        },
        onReevaluateGroup: { groupKey in
          model.reEvaluateCodexGroup(groupKey)
        }
      )
    }
  }

  @ViewBuilder
  private func codexRouteReceiptPanel() -> some View {
    if let receiptSummary = model.codexRouteReceiptSummary {
      codexRouteReceiptSummaryView(receiptSummary)
      codexPendingReceiptAuditView()
      codexPendingReceiptResumeView()
      HStack(spacing: 8) {
        Button("Export route receipts") {
          model.exportCodexRouteReceipts()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .controlSize(.small)
        .disabled(model.codexRouteReceipts.isEmpty || model.isCodexPortalBusy)
        Text("Writes read-only JSON and CSV to the local catalog Exports folder.")
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
      if !model.codexRouteReceiptExportStatus.isEmpty {
        Text(model.codexRouteReceiptExportStatus)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(DashboardTheme.muted)
          .textSelection(.enabled)
      }
      HStack(spacing: 8) {
        Button("Inspect exported receipts") {
          model.chooseCodexRouteReceiptBundle()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .controlSize(.small)
        Text("Imported bundles remain read-only and never override live SQLite receipts.")
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
      Text(model.codexImportedRouteReceiptStatus)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(DashboardTheme.muted)
        .textSelection(.enabled)
      if let importedRouteReceipts = model.codexImportedRouteReceiptBundle {
        DisclosureGroup("Inspected route receipts · " + String(importedRouteReceipts.receipts.count) + " row(s)") {
          VStack(alignment: .leading, spacing: 4) {
            Text("Session " + importedRouteReceipts.sessionID + " · " + importedRouteReceipts.summary.headline)
            Text("IMPORTED BUNDLE · read-only · live SQLite catalog remains authoritative")
              .foregroundStyle(DashboardTheme.warning)
            ForEach(Array(importedRouteReceipts.receipts.prefix(12))) { receipt in
              Text(receipt.state.rawValue.uppercased() + " · " + receipt.route.rawValue + " · " + receipt.sourcePath)
                .textSelection(.enabled)
            }
          }
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(DashboardTheme.muted)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
      }
      codexRouteReceiptComparisonPanel()
      if !model.codexImportedRouteReceiptHistory.isEmpty {
        DisclosureGroup("Imported route receipt history · " + String(model.codexImportedRouteReceiptHistory.count)) {
          VStack(alignment: .leading, spacing: 5) {
            ForEach(model.codexImportedRouteReceiptHistory) { record in
              HStack(spacing: 8) {
                Button(record.sourceName + " · " + String(record.bundle.receipts.count) + " receipt(s)") {
                  model.inspectCodexImportedRouteReceiptRecord(record)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DashboardTheme.text)
                Spacer()
                Button("Remove") {
                  model.removeCodexImportedRouteReceiptRecord(record)
                }
                .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                .controlSize(.mini)
              }
            }
            Button("Clear imported route receipt history") {
              model.clearCodexImportedRouteReceiptHistory()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
            .controlSize(.small)
          }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
      }
    }
  }

  @ViewBuilder
  private func codexRouteReceiptComparisonPanel() -> some View {
    if let summary = model.codexRouteReceiptComparisonSummary {
      DisclosureGroup("Live vs imported receipt comparison · " + String(summary.totalCount) + " source(s)") {
        VStack(alignment: .leading, spacing: 5) {
          Text(summary.headline)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
          Text("Read-only comparison; imported evidence cannot alter live pending-route selection.")
            .foregroundStyle(DashboardTheme.warning)
          codexRouteReceiptBaselineDecisionView()
          ForEach(Array(model.codexRouteReceiptComparisonRows.prefix(12))) { row in
            VStack(alignment: .leading, spacing: 2) {
              Text(row.kind.label.uppercased() + " · " + row.sourcePath)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(row.kind == .changed ? DashboardTheme.warning : DashboardTheme.muted)
                .textSelection(.enabled)
              Text(row.explanation)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }
          }
          if model.codexRouteReceiptComparisonRows.count > 12 {
            Text("Showing the first 12 comparison rows.")
              .font(.system(size: 10, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          }
        }
        .padding(.top, 4)
      }
      .font(.system(size: 10, weight: .semibold, design: .rounded))
      .foregroundStyle(DashboardTheme.text)
    }
  }

  @ViewBuilder
  private func codexRouteReceiptBaselineDecisionView() -> some View {
    if let decision = model.codexRouteReceiptBaselineDecision {
      let liveSession = String(decision.liveSessionID.prefix(8))
      let importedSession = String(decision.importedSessionID.prefix(8))
      let baselineLabel = "BASELINE ACCEPTED · live session " + liveSession + " · imported session " + importedSession + " · comparison only"
      Text(baselineLabel)
        .foregroundStyle(DashboardTheme.success)
      Button("Revoke comparison baseline") {
        model.revokeCodexRouteReceiptBaseline()
      }
      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      .controlSize(.small)
      Text("Revocation removes only the baseline decision; imported evidence remains retained and read-only.")
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    } else {
      Button("Accept as comparison baseline") {
        model.acceptCodexRouteReceiptBaseline()
      }
      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      .controlSize(.small)
      Text("This records an operator decision for comparison context only; it does not promote imported receipts into the live catalog.")
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
    codexRouteReceiptBaselineAuditView()
  }

  private func codexRouteReceiptBaselineAuditRow(_ event: CodexRouteReceiptBaselineAuditEvent) -> some View {
    let action = event.action.rawValue.uppercased()
    let label = action + " · " + event.importedSourceName + " · " + event.detail
    return Button {
      model.inspectCodexRouteReceiptBaselineAudit(event)
    } label: {
      Text(label)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(event.action == .revoked ? DashboardTheme.warning : DashboardTheme.muted)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
  }

  private func codexRouteReceiptBaselineAuditView() -> AnyView {
    let auditEvents = Array(model.codexRouteReceiptBaselineAudit.prefix(10))
    let auditCount = model.codexRouteReceiptBaselineAudit.count
    let auditTitle = "Baseline decision audit · " + String(auditCount)
    let auditDisclosure = DisclosureGroup(auditTitle) {
      codexRouteReceiptBaselineAuditContent(auditEvents, importedEvents: model.codexImportedBaselineAuditEvents)
    }
    .font(.system(size: 10, weight: .semibold, design: .rounded))
    .foregroundStyle(DashboardTheme.text)
    return AnyView(auditDisclosure)
  }

  private func codexRouteReceiptBaselineAuditContent(
    _ events: [CodexRouteReceiptBaselineAuditEvent],
    importedEvents: [CodexRouteReceiptBaselineAuditEvent]
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(events) { event in
        codexRouteReceiptBaselineAuditRow(event)
      }
      HStack(spacing: 8) {
        Button("Export audit history") {
          model.exportCodexRouteReceiptBaselineAudit()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .controlSize(.small)
        Text("Writes read-only JSON and CSV; it never reactivates a baseline.")
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
      if !model.codexRouteReceiptBaselineAuditExportStatus.isEmpty {
        Text(model.codexRouteReceiptBaselineAuditExportStatus)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(DashboardTheme.muted)
          .textSelection(.enabled)
      }
      HStack(spacing: 8) {
        Button("Inspect audit JSON") {
          model.chooseCodexRouteReceiptBaselineAuditBundle()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .controlSize(.small)
        Text("Imported audit stays separate, read-only, and non-authoritative.")
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
      if !model.codexImportedBaselineAuditStatus.isEmpty {
        Text(model.codexImportedBaselineAuditStatus)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(DashboardTheme.muted)
          .textSelection(.enabled)
      }
      if !model.codexRejectedBaselineAuditImports.isEmpty {
        DisclosureGroup("Rejected audit imports · " + String(model.codexRejectedBaselineAuditImports.count)) {
          ForEach(model.codexRejectedBaselineAuditImports) { rejection in
            VStack(alignment: .leading, spacing: 2) {
              Text(rejection.sourceName + " · " + rejection.rejectedAt.formatted(.iso8601))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DashboardTheme.warning)
              ForEach(rejection.reasons, id: \.self) { reason in
                Text(reason)
                  .font(.system(size: 10, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .textSelection(.enabled)
              }
            }
          }
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
      }
      if !importedEvents.isEmpty {
        DisclosureGroup("Imported read-only audit · " + String(importedEvents.count) + " event(s)") {
          ForEach(Array(importedEvents.prefix(20))) { event in
            codexImportedBaselineAuditRow(event)
          }
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
      }
      if !model.codexImportedBaselineAuditHistory.isEmpty {
        DisclosureGroup("Imported audit history · " + String(model.codexImportedBaselineAuditHistory.count)) {
          VStack(alignment: .leading, spacing: 5) {
            ForEach(model.codexImportedBaselineAuditHistory) { record in
              codexImportedBaselineAuditHistoryRow(record)
            }
            Button("Clear imported audit history") {
              model.clearCodexImportedBaselineAuditHistory()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
            .controlSize(.small)
          }
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
      }
      codexRouteReceiptBaselineAuditSelectionView()
    }
  }

  private func codexImportedBaselineAuditRow(_ event: CodexRouteReceiptBaselineAuditEvent) -> some View {
    let label = event.action.rawValue.uppercased() + " · " + event.importedSourceName + " · " + event.detail
    return Text(label)
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      .foregroundStyle(DashboardTheme.muted)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func codexImportedBaselineAuditHistoryRow(_ record: CodexImportedBaselineAuditRecord) -> some View {
    let count = String(record.events.count)
    let label = record.sourceName + " · " + count + " event(s) · " + record.compatibilityLabel + " · " + record.validationLabel + " · " + record.fingerprint
    return HStack(spacing: 8) {
      Button(label) {
        model.inspectCodexImportedBaselineAuditRecord(record)
      }
      .buttonStyle(.plain)
      .foregroundStyle(DashboardTheme.text)
      Spacer()
      Button("Remove") {
        model.removeCodexImportedBaselineAuditRecord(record)
      }
      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      .controlSize(.mini)
    }
  }

  private func codexRouteReceiptBaselineAuditSelectionView() -> AnyView {
    guard let selected = model.codexSelectedRouteReceiptBaselineAudit else {
      return AnyView(EmptyView())
    }
    let action = selected.action.rawValue
    let liveID = String(selected.liveSessionID.prefix(8))
    let importedID = String(selected.importedSessionID.prefix(8))
    let summary = "Selected read-only event · " + action + " · live " + liveID + " · imported " + importedID
    let selection = VStack(alignment: .leading, spacing: 2) {
      Text(summary)
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(DashboardTheme.text)
      Text("History inspection never reactivates a baseline or changes live execution authority.")
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
    return AnyView(selection)
  }

  private func codexRouteReceiptSummaryView(_ summary: CodexRouteReceiptSummary) -> some View {
    Text("Route receipt · " + summary.headline + " · persisted in the local SQLite catalog")
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      .foregroundStyle(summary.pendingCount > 0 ? DashboardTheme.warning : DashboardTheme.muted)
  }

  @ViewBuilder
  private func codexPendingReceiptAuditView() -> some View {
    let pendingReceipts = model.codexPendingRouteReceipts
    let pendingCount = pendingReceipts.count
    if pendingCount > 0 {
      DisclosureGroup("Resume audit · " + String(pendingCount) + " matching source(s)") {
        VStack(alignment: .leading, spacing: 5) {
          ForEach(Array(pendingReceipts.prefix(12))) { receipt in
            codexPendingReceiptRow(receipt)
          }
          if pendingCount > 12 {
            Text("Showing the first 12 pending receipts; the resume action includes all matching pending sources.")
              .font(.system(size: 10, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          }
        }
        .padding(.top, 4)
      }
      .font(.system(size: 10, weight: .semibold, design: .rounded))
      .foregroundStyle(DashboardTheme.text)
    }
  }

  private func codexPendingReceiptRow(_ receipt: CodexScanRouteReceipt) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(receipt.sourcePath)
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .textSelection(.enabled)
      Text(receipt.route.label + " · " + receipt.state.rawValue + " · attempt " + String(receipt.attemptCount))
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(receipt.state == .failed ? DashboardTheme.warning : DashboardTheme.muted)
      Text(receipt.detail)
        .font(.system(size: 10, weight: .regular, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
  }

  @ViewBuilder
  private func codexPendingReceiptResumeView() -> some View {
    if model.codexPendingRouteCount > 0 {
      Button {
        model.resumeCodexPendingRoutes()
      } label: {
        Label("Resume \(model.codexPendingRouteCount) pending route(s)", systemImage: "arrow.clockwise.circle")
      }
      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      .controlSize(.small)
      .disabled(model.isCodexPortalBusy)
      Text("Completed and skipped routes remain outside this resume run; the prior project selection is restored afterward.")
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
  }

  private func codexPortalPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(brandMark: model.bundledBrandMark, compact: width < 1280)

      WorkspaceToolbarStrip(
        destination: .codexPortal,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      codexFlowDashboard(for: width)

      if width >= 1450 {
        HStack(alignment: .top, spacing: 18) {
          codexDiscoveryPanel
            .frame(maxWidth: 560, alignment: .topLeading)
          codexProjectSelectionPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)
          codexTransferPanel
            .frame(maxWidth: 520, alignment: .topLeading)
        }
      } else {
        codexDiscoveryPanel
        codexProjectSelectionPanel
        codexTransferPanel
      }

      codexLocalDevPanel
      codexStage2Panel
      codexLifecyclePanel
    }
  }

  private func projectBackupPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(brandMark: model.bundledBrandMark, compact: width < 1280)

      WorkspaceToolbarStrip(
        destination: .projectBackups,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      codexFlowDashboard(for: width)

      if width >= 1450 {
        HStack(alignment: .top, spacing: 18) {
          codexTransferPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)
          VStack(alignment: .leading, spacing: 18) {
            localFilesExportPanel
            backupPresetsPanel
          }
          .frame(maxWidth: 520, alignment: .topLeading)
        }
      } else {
        codexTransferPanel
        localFilesExportPanel
        backupPresetsPanel
      }

      codexStage2Panel
      codexLifecyclePanel
      snapshotsPanel
    }
  }

  private var codexDiscoveryPanel: some View {
    PanelCard(
      title: "Project Discovery",
      subtitle: "Search selected parent folders. Ordinary Documents folders are ignored unless they contain real project evidence."
    ) {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Scan Source Folders")
        TextEditor(text: $model.codexScanRootsDraft)
          .font(.system(size: 13, weight: .medium, design: .monospaced))
          .foregroundStyle(DashboardTheme.text)
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 90, maxHeight: 140)
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(DashboardTheme.field)
              .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .stroke(DashboardTheme.border, lineWidth: 1)
              )
          )

        HStack(spacing: 10) {
          TextField("Paste a custom parent-folder path", text: $model.codexScanRootEntryDraft)
            .textFieldStyle(.plain)
            .foregroundStyle(DashboardTheme.text)
            .dashboardFieldStyle()
            .onSubmit {
              model.addCodexScanRootDraft()
            }

          Button {
            model.addCodexScanRootDraft()
          } label: {
            Label("Add Path", systemImage: "folder.badge.plus")
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
          .disabled(model.codexScanRootEntryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isScanningCodexProjects || model.isBuildingCodexTransferPlan || model.isRunningCodexTransfer)
        }

        Label("Drop Folder", systemImage: "arrow.down.doc")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(model.isCodexScanRootDropTarget ? DashboardTheme.success : DashboardTheme.muted)
          .frame(maxWidth: .infinity, minHeight: 38)
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(model.isCodexScanRootDropTarget ? DashboardTheme.success.opacity(0.12) : DashboardTheme.field)
              .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .stroke(model.isCodexScanRootDropTarget ? DashboardTheme.success : DashboardTheme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
              )
          )
          .onDrop(of: [UTType.fileURL], isTargeted: $model.isCodexScanRootDropTarget) { providers in
            model.receiveCodexScanRootDrop(providers)
          }
          .disabled(model.isScanningCodexProjects || model.isBuildingCodexTransferPlan || model.isRunningCodexTransfer)
      }

      HStack(spacing: 10) {
        Button {
          model.chooseCodexScanRoot()
        } label: {
          Label("Add Folder", systemImage: "folder.badge.plus")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button {
          model.addCommonCodexScanRoots()
        } label: {
          Label("Common Folders", systemImage: "folder.badge.gearshape")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isScanningCodexProjects || model.isBuildingCodexTransferPlan || model.isRunningCodexTransfer)

        Button {
          model.scanCodexProjects()
        } label: {
          Label(model.isScanningCodexProjects ? "Scanning" : "Scan Projects", systemImage: "magnifyingglass")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.isScanningCodexProjects || model.isBuildingCodexTransferPlan || model.isRunningCodexTransfer)
      }

      if model.isScanningCodexProjects {
        ProgressView()
          .progressViewStyle(.linear)
          .tint(DashboardTheme.link)
          .frame(maxWidth: .infinity)
      }

      BannerCard(
        title: model.codexProjectSummary,
        detail: model.codexPortalStatus,
        kind: model.codexProjects.isEmpty ? .warning : .ready
      )

      Text("Discovery reads local paths and the Codex desktop project's local link registry. It offers a folder only when it sees Git, a manifest, or enough source, editor, Docker/config, or transfer-note context, so ordinary Documents folders are not treated as projects. Git status compares against the locally stored origin/main reference and does not fetch, upload history, or read prompts, credentials, or account data.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var codexLocalDevPanel: some View {
    PanelCard(
      title: "Local Development Runner",
      subtitle: "Run a detected local development script from the Mac app without opening Terminal or asking for a code command."
    ) {
      if model.selectedCodexProjects.count == 1, let project = model.selectedCodexProjects.first {
        BannerCard(
          title: project.name,
          detail: "\(project.path)\n\(project.localDevProfile?.commandLabel ?? "No supported npm development script detected")",
          kind: project.localDevProfile == nil ? .warning : (model.isRunningCodexLocalDev ? .running : .ready)
        )

        if let profile = project.localDevProfile {
          HStack(spacing: 10) {
            if model.isRunningCodexLocalDev && model.codexLocalDevProjectPath == project.path {
              Button("Stop Local Dev") {
                model.stopCodexLocalDev()
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: false))
            } else {
              Button("Run Local Dev") {
                model.runCodexLocalDev(project)
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
              .disabled(model.isRunningCodexLocalDev)
            }

            Button("Open Project") {
              model.revealCodexProject(project)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

            Button(model.isLoadingPorts ? "Scanning..." : "Scan Ports") {
              model.loadPortMonitor()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
            .disabled(model.isLoadingPorts)
          }

          Text("\(profile.label) · \(model.codexLocalDevStatus)")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineSpacing(2)

          if model.isRunningCodexLocalDev && model.codexLocalDevProjectPath == project.path {
            ProgressView()
              .progressViewStyle(.linear)
              .tint(DashboardTheme.success)
              .frame(maxWidth: .infinity)
          }
        } else {
          Text(model.codexLocalDevStatus)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.warning)
        }
      } else if model.selectedCodexProjects.isEmpty {
        Text("Select exactly one discovered project to enable its local development runner.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        Text("Select one project at a time for local development. Transfer selection can still contain multiple projects.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }

      if !model.portMonitorEntries.isEmpty {
        Divider()
        FieldLabel(text: "Current Listening Ports")
        ForEach(model.portMonitorEntries.prefix(8)) { entry in
          HStack {
            Text("\(entry.processName) · \(entry.proto)")
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            Spacer(minLength: 8)
            Text(":\(entry.port)")
              .font(.system(size: 12, weight: .bold, design: .monospaced))
              .foregroundStyle(DashboardTheme.accent)
          }
        }
      }

      Text("The runner reads only the selected project's package.json, chooses a known local development script, runs it with npm in that project folder, captures output in Jobs, and refreshes the native listener scan. It does not fetch Git, modify source files, or open Terminal.")
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var codexProjectSelectionPanel: some View {
    PanelCard(
      title: "Found Projects",
      subtitle: "Target one project, a filtered set, or every discovered workspace."
    ) {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Search Projects")
        TextField("Project name, path, remote, branch, or marker", text: $model.codexProjectSearch)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button(model.areAllVisibleCodexProjectsSelected ? "Clear Visible" : "Select Visible") {
          model.setVisibleCodexProjectsSelected(!model.areAllVisibleCodexProjectsSelected)
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.filteredCodexProjects.isEmpty)

        Button("Select All") {
          model.selectAllCodexProjects()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.codexProjects.isEmpty)

        Button {
          model.armCodexAutoAll()
        } label: {
          Label("Auto All", systemImage: "bolt.horizontal.circle")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        .disabled(model.codexProjects.isEmpty || model.isRunningCodexTransfer)

        Button("Clear") {
          model.clearCodexProjectSelection()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accentPink, bordered: true))
        .disabled(model.selectedCodexProjectPaths.isEmpty)
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.filteredCodexProjects.isEmpty {
            Text(model.codexProjects.isEmpty ? "Scan to load Codex projects." : "No discovered projects match the current search.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ForEach(model.filteredCodexProjects) { project in
              VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                  Button {
                    model.toggleCodexProject(project)
                  } label: {
                    Image(systemName: model.selectedCodexProjectPaths.contains(project.path) ? "checkmark.square.fill" : "square")
                      .font(.system(size: 18, weight: .semibold))
                      .foregroundStyle(model.selectedCodexProjectPaths.contains(project.path) ? DashboardTheme.success : DashboardTheme.muted)
                  }
                  .buttonStyle(.plain)
                  .help(model.selectedCodexProjectPaths.contains(project.path) ? "Remove from transfer" : "Add to transfer")

                  VStack(alignment: .leading, spacing: 5) {
                    Text(project.name)
                      .font(.system(size: 14, weight: .bold, design: .rounded))
                      .foregroundStyle(DashboardTheme.text)
                    Text(project.path)
                      .font(.system(size: 11, weight: .medium, design: .monospaced))
                      .foregroundStyle(DashboardTheme.muted)
                      .textSelection(.enabled)
                    Text([
                      project.discoveredBy,
                      project.branch.map { "branch \($0)" },
                      project.remoteURL
                    ].compactMap { $0 }.joined(separator: " · "))
                      .font(.system(size: 11, weight: .medium, design: .rounded))
                      .foregroundStyle(DashboardTheme.muted)
                      .lineLimit(2)
                  }
                  Spacer(minLength: 8)
                }

                HStack(spacing: 8) {
                  PillBadge(text: project.ideState.rawValue, tint: project.ideState.dashboardTint)
                    .help(project.ideState.dashboardHelp)
                  PillBadge(text: project.gitStatus.mainLabel, tint: project.gitStatus.dashboardTint)
                    .help(project.gitStatus.mainDetail + " No network fetch was performed.")
                  if project.gitStatus.hasLocalChanges {
                    PillBadge(text: "Local changes", tint: DashboardTheme.warning)
                      .help("Tracked or untracked working-tree changes are present in this local folder.")
                  }
                  Spacer(minLength: 8)
                }

                HStack(spacing: 8) {
                  ForEach(project.badges, id: \.self) { badge in
                    PillBadge(text: badge, tint: DashboardTheme.deepBlue)
                  }
                  Spacer(minLength: 8)
                  Button {
                    model.revealCodexProject(project)
                  } label: {
                    Image(systemName: "folder")
                  }
                  .buttonStyle(.plain)
                  .help("Reveal in Finder")
                  Button {
                    model.openCodexProject(project, inApplication: "Codex")
                  } label: {
                    Image(systemName: "terminal")
                  }
                  .buttonStyle(.plain)
                  .help("Open in Codex")
                  Button {
                    model.openCodexProject(project, inApplication: "Visual Studio Code")
                  } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                  }
                  .buttonStyle(.plain)
                  .help("Open in Visual Studio Code")
                  Button {
                    model.openCodexProject(project, inApplication: "GitHub Copilot")
                  } label: {
                    Image(systemName: "wand.and.stars")
                  }
                  .buttonStyle(.plain)
                  .help("Open in GitHub Copilot")
                  Button {
                    model.openCodexProjectDevcontainer(project)
                  } label: {
                    Image(systemName: "shippingbox")
                  }
                  .buttonStyle(.plain)
                  .disabled(!project.hasDevcontainer)
                  .help(project.hasDevcontainer ? "Start the project devcontainer" : "No devcontainer configuration detected")
                  if let profile = project.localDevProfile {
                    if model.isRunningCodexLocalDev && model.codexLocalDevProjectPath == project.path {
                      Button {
                        model.stopCodexLocalDev()
                      } label: {
                        Image(systemName: "stop.circle.fill")
                      }
                      .buttonStyle(.plain)
                      .foregroundStyle(DashboardTheme.warning)
                      .help("Stop \(profile.label.lowercased())")
                    } else {
                      Button {
                        model.runCodexLocalDev(project)
                      } label: {
                        Image(systemName: "play.circle")
                      }
                      .buttonStyle(.plain)
                      .disabled(model.isRunningCodexLocalDev)
                      .help(model.isRunningCodexLocalDev ? "Stop the active local development session first" : "Run \(profile.commandLabel) without opening Terminal")
                    }
                  }
                }
              }
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                      .stroke(model.selectedCodexProjectPaths.contains(project.path) ? DashboardTheme.success.opacity(0.65) : DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 260, idealHeight: 520, maxHeight: 680)
    }
  }

  private var codexTransferPanel: some View {
    PanelCard(
      title: "Preflight & Transfer",
      subtitle: "Scan, stage, reconcile, verify, and back up selected projects with a mode-specific source policy."
    ) {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Output Folder")
        TextField("Choose an output folder", text: $model.codexOutputRootDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button {
          model.chooseCodexOutputRoot()
        } label: {
          Label("Choose", systemImage: "folder")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button {
          model.openCodexOutputRoot()
        } label: {
          Label("Open", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Picker("Transfer Mode", selection: $model.codexTransferMode) {
        ForEach(CodexProjectTransferMode.allCases) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .pickerStyle(.menu)

      Text(model.codexTransferMode.subtitle)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      Toggle("Create verified ZIP backup", isOn: $model.codexCreateBackup)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .disabled(model.codexTransferMode == .backupOnly || model.codexTransferMode.performsScanAndBackup)

      Toggle("Preserve .git metadata", isOn: $model.codexIncludeGitMetadata)
        .toggleStyle(.switch)
        .tint(DashboardTheme.deepBlue)

      Toggle("Preserve Finder metadata (.DS_Store and ._* files)", isOn: $model.codexIncludeFinderMetadata)
        .toggleStyle(.switch)
        .tint(DashboardTheme.deepBlue)

      Toggle("Include generated dependencies and build outputs", isOn: $model.codexIncludeDependencies)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)

      Toggle("Deep checksum audit metadata-matched files", isOn: $model.codexFullChecksumAudit)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)

      Text("Fast Mode uses path, type, size, date, and symlink target to minimize copying, then requires a whole-tree checksum verification before any cleanup-capable receipt. A checksum-only miss is repaired only after the prior destination version is preserved; Deep Audit performs that detection earlier, during planning.")
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      Toggle("Auto-resume existing destination files", isOn: $model.codexAutoResumeExisting)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .disabled(!model.codexTransferMode.writesDestination || model.codexTransferMode.requiresExistingDestinationMerge)

      Toggle("Re-arm Git main from the detected remote after copy", isOn: $model.codexRearmGitMain)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .disabled(model.codexIncludeGitMetadata || !model.codexTransferMode.writesDestination)

      Toggle("Keep old path as compatibility link after move", isOn: $model.codexCreateCompatibilityLink)
        .toggleStyle(.switch)
        .tint(DashboardTheme.accent)
        .disabled(!model.codexTransferMode.removesSource)

      BannerCard(
        title: model.codexTransferPlans.isEmpty ? "\(model.selectedCodexProjectPaths.count) project(s) selected" : model.codexTransferPlanSummary,
        detail: model.codexPortalProgressText,
        kind: (model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan) ? .running : (model.selectedCodexProjectPaths.isEmpty ? .warning : .ready)
      )

      if model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan {
        ProgressView(value: model.codexPortalProgress, total: 1)
          .progressViewStyle(.linear)
          .tint(DashboardTheme.success)
          .frame(maxWidth: .infinity)
      }

      if !model.codexTransferPlans.isEmpty {
        Divider()

        HStack(spacing: 8) {
          Text("Virtual File Table")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
          Spacer(minLength: 8)
          Button {
            model.revealCodexTransferIndexes()
          } label: {
            Image(systemName: "folder.badge.gearshape")
          }
          .buttonStyle(.plain)
          .help("Open saved transfer indexes in Finder")
        }

        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
          GridRow {
            Text("Project")
            Text("Indexed")
            Text("Transfer")
            Text("Keep")
          }
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)

          ForEach(Array(model.codexTransferPlans.prefix(5))) { plan in
            GridRow {
              VStack(alignment: .leading, spacing: 2) {
                Text(plan.projectName)
                  .lineLimit(1)
                Text(plan.requiresInitialMirror ? "Initial baseline" : plan.usedVerifiedCache == true ? "Verified cache" : plan.fullChecksumAudit ? "Deep audit" : "Fast index")
                  .font(.system(size: 10, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
              }
              Text("\(plan.sourceFileCount)")
              Text("\(plan.plannedPaths.count)")
              Text("\(plan.destinationOnlyPaths.count)")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
          }
        }

        if model.codexTransferPlans.count > 5 {
          Text("Showing 5 of \(model.codexTransferPlans.count) indexed projects. The saved JSON table contains every indexed path.")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
        }

        if model.codexTransferPlans.contains(where: { !$0.typeConflictPaths.isEmpty }) {
          Text("File-versus-folder conflicts were found. Those paths are preserved and must be resolved before a targeted transfer can run.")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.warning)
        }
      }

      HStack(spacing: 10) {
        Button {
          model.preflightCodexTransfer()
        } label: {
          Label(model.isBuildingCodexTransferPlan ? "Indexing" : "Preflight", systemImage: "checkmark.shield")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.selectedCodexProjectPaths.isEmpty || model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan)

        Button {
          model.runCodexTransfer()
        } label: {
          Label(model.isRunningCodexTransfer ? "Running" : "Run", systemImage: "play.fill")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.selectedCodexProjectPaths.isEmpty || model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan)
      }

      BannerCard(
        title: "Transfer safety",
        detail: "Preflight saves source, destination, and plan JSON under the output folder's _temp/Transfer-Indexes directory. Repeat transfers use only planned paths for copying, while every published, resumed, or synchronized destination receives a final whole-tree checksum verification before cleanup is allowed. Initial mirrors and optional ZIP archives still read full project content.",
        kind: .ready
      )
    }
  }

  private var codexStage2Panel: some View {
    PanelCard(
      title: "Stage 2: Managed Workspace Merge",
      subtitle: "Resolve Stage 1 backups into the canonical Code / Import / Runtime workspace by GitHub repository identity."
    ) {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Stage 1 Source")
        TextField("CODEX PROJECTS folder", text: $model.stage2SourceRootDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button {
          model.chooseStage2SourceRoot()
        } label: {
          Label("Choose Source", systemImage: "folder")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button {
          model.scanStage2Projects()
        } label: {
          Label("Scan Stage 2", systemImage: "magnifyingglass")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        .disabled(model.isScanningCodexProjects || model.isBuildingCodexTransferPlan || model.isRunningCodexTransfer)

        Button {
          model.revealStage2SourceRoot()
        } label: {
          Image(systemName: "arrow.up.forward.app")
        }
        .buttonStyle(.plain)
        .help("Open the Stage 1 source")
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Managed CSA-iEM Root")
        TextField("CSA-iEM workspace base", text: $model.stage2ManagedRootDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button {
          model.chooseStage2ManagedRoot()
        } label: {
          Label("Choose Root", systemImage: "externaldrive")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button {
          model.revealStage2ManagedRoot()
        } label: {
          Label("Open Root", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "GitHub Owner-Account Bindings (Optional)")
        TextEditor(text: $model.stage2GitHubOwnerAccountsDraft)
          .font(.system(size: 13, weight: .medium, design: .monospaced))
          .foregroundStyle(DashboardTheme.text)
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 58, maxHeight: 96)
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(DashboardTheme.field)
              .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .stroke(DashboardTheme.border, lineWidth: 1)
              )
          )
        Text("Enter OWNER=LOGIN entries on separate lines or separated by semicolons. Leave empty to use the selected single-account fallback.")
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }

      Divider()

      Toggle("Create missing GitHub repositories as private and empty", isOn: $model.stage2CreateMissingRepos)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)

      Toggle("Prepare Runtime/Repos mirrors", isOn: $model.stage2PrepareRuntime)
        .toggleStyle(.switch)
        .tint(DashboardTheme.deepBlue)

      Toggle("Create and verify a Stage 2 ZIP before cleanup", isOn: $model.stage2ArchiveSources)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)

      Picker("Stage 1 Input Policy", selection: $model.stage2SourceRetention) {
        ForEach(Stage2SourceRetention.allCases) { option in
          Text(option.label).tag(option)
        }
      }
      .pickerStyle(.menu)

      Toggle("Clean this verified Stage 2 transaction", isOn: $model.stage2CleanupTransactionTemp)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)

      Picker("After Apply", selection: $model.stage2OpenAfterApply) {
        ForEach(Stage2OpenOption.allCases) { option in
          Text(option.label).tag(option)
        }
      }
      .pickerStyle(.menu)

      Toggle("Arm Stage 2 workspace writes", isOn: $model.stage2SafetyArmed)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .disabled(model.isCodexPortalBusy || model.codexStage2ApplyBlocked)

      BannerCard(
        title: model.stage2SelectionSummary,
        detail: model.stage2Status,
        kind: model.stage2SafetyArmed ? .warning : .ready
      )

      ForEach(model.codexStage2GroupBlockerSummaries, id: \.self) { summary in
        BannerCard(
          title: "Stage 2 apply blocked: identity group requires review",
          detail: summary,
          kind: .warning
        )
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
        Button {
          model.runStage2PreflightSelected()
        } label: {
          Label("Preflight Selected", systemImage: "checkmark.shield")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.stage2SelectedProjects.isEmpty || model.isCodexPortalBusy)

        Button {
          model.runStage2ApplySelected()
        } label: {
          Label("Apply Selected", systemImage: "play.fill")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.stage2SelectedProjects.isEmpty || !model.stage2SafetyArmed || model.isCodexPortalBusy)

        Button {
          model.runStage2PreflightAll()
        } label: {
          Label("Preflight All", systemImage: "list.bullet.clipboard")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isCodexPortalBusy)

        Button {
          model.runStage2FullAuto()
        } label: {
          Label("Stage 2 Full Auto", systemImage: "bolt.horizontal.circle.fill")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(!model.stage2SafetyArmed || model.isCodexPortalBusy)
      }

      Text("GitHub checks use repository ID, canonical owner/name, default branch, remote HEAD, and local ancestry. Active CSA-iEM, dirty destinations, staged work, identity conflicts, archived repositories, and diverged history remain blocked. Reports are saved under Runtime/Reports/Stage2.")
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var codexLifecyclePanel: some View {
    PanelCard(
      title: "Stage 3: Full Auto Lifecycle",
      subtitle: "Run Stage 1, Stage 2, and receipt-linked cleanup as one selected-project or all-project transaction."
    ) {
      Picker("Scope", selection: $model.codexLifecycleScope) {
        ForEach(CodexLifecycleScope.allCases) { scope in
          Text(scope.label).tag(scope)
        }
      }
      .pickerStyle(.segmented)

      Toggle("Stage 1 verified ZIP", isOn: $model.codexCreateBackup)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .disabled(model.codexTransferMode == .backupOnly || model.codexTransferMode.performsScanAndBackup)

      Toggle("Delete Stage 1 originals after receipt verification", isOn: $model.codexLifecycleDeleteStage1Originals)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .disabled(!model.codexTransferMode.writesDestination)

      Toggle("Continue into Stage 2 managed workspace", isOn: $model.codexLifecycleRunStage2)
        .toggleStyle(.switch)
        .tint(DashboardTheme.deepBlue)
        .disabled(!model.codexTransferMode.writesDestination)

      if model.codexLifecycleRunStage2 {
        Toggle("Stage 2 verified ZIP", isOn: $model.stage2ArchiveSources)
          .toggleStyle(.switch)
          .tint(DashboardTheme.success)

        Picker("Stage 2 Input Policy", selection: $model.stage2SourceRetention) {
          ForEach(Stage2SourceRetention.allCases) { option in
            Text(option.label).tag(option)
          }
        }
        .pickerStyle(.menu)

        Toggle("Create missing GitHub repositories as private and empty", isOn: $model.stage2CreateMissingRepos)
          .toggleStyle(.switch)
          .tint(DashboardTheme.warning)

        Toggle("Prepare Runtime/Repos mirrors", isOn: $model.stage2PrepareRuntime)
          .toggleStyle(.switch)
          .tint(DashboardTheme.deepBlue)
      }

      Picker("Stage 3 Cleanup", selection: $model.codexLifecycleCleanupScope) {
        ForEach(CodexLifecycleCleanupScope.allCases) { option in
          Text(option.label).tag(option)
        }
      }
      .pickerStyle(.menu)

      Toggle("Arm selected Full Auto lifecycle", isOn: $model.codexLifecycleSafetyArmed)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .disabled(model.isCodexPortalBusy)

      BannerCard(
        title: "\(model.codexLifecycleScope.label) · \(model.selectedCodexProjects.count) selected",
        detail: model.codexLifecycleStatus,
        kind: model.codexLifecycleSafetyArmed ? .warning : .ready
      )

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
        Button {
          model.preflightCodexLifecycle()
        } label: {
          Label("Preflight Lifecycle", systemImage: "checkmark.shield")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan || model.isScanningCodexProjects)

        Button {
          model.runCodexLifecycle()
        } label: {
          Label(model.isRunningCodexTransfer ? "Lifecycle Running" : "Run Full Auto", systemImage: "bolt.horizontal.circle.fill")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(!model.codexLifecycleSafetyArmed || model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan || model.isScanningCodexProjects)

        Button {
          model.runStage3Preflight()
        } label: {
          Label("Preflight Stage 3", systemImage: "doc.text.magnifyingglass")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan || model.isScanningCodexProjects)

        Button {
          model.runStage3Cleanup()
        } label: {
          Label("Apply Stage 3 Only", systemImage: "trash.slash")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(!model.codexLifecycleSafetyArmed || model.isRunningCodexTransfer || model.isBuildingCodexTransferPlan || model.isScanningCodexProjects)
      }

      Text("Permanent cleanup requires Stage 1 and Stage 2 receipts, a live source-to-destination verification, same-volume quarantine, a second verification, and explicit Stage 2/Stage 3 confirmation tokens. All Verified Temp removes only receipt-linked index and transaction paths; archives, reports, receipts, canonical repositories, and the active CSA-iEM workspace remain protected.")
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private func importPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .imports,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1560 {
        HStack(alignment: .top, spacing: 18) {
          VStack(alignment: .leading, spacing: 18) {
            authPanel
            repositoryPanel
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            importPanel
            importExecutionPanel
          }
          .frame(width: 480, alignment: .topLeading)

          logPanel(minHeight: 720)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          authPanel
          repositoryPanel
          importPanel
          importExecutionPanel
          logPanel(minHeight: 360)
        }
      }
    }
  }

  private func githubAccountPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .githubAccount,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        if width >= 1500 {
          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
              authPanel
              contextsPanel
            }
            .frame(maxWidth: 440, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
              githubAccountInsightsPanel
              repositoryPanel
              researchSnapshotPanel
              repoHealthPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          authPanel
          contextsPanel
          githubAccountInsightsPanel
          repositoryPanel
          researchSnapshotPanel
          repoHealthPanel
        }

        workflowControlPanel
        workflowRunsPanel
        codespacesPanel
        secretsAndVariablesPanel
        rulesetsPanel
      }
    }
  }

  private func githubBillingPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(brandMark: model.bundledBrandMark, compact: width < 1280)

      WorkspaceToolbarStrip(destination: .githubBilling, menuVisible: isMenuVisible, usesSidebar: usesSidebar) {
        isMenuVisible.toggle()
      }

      if width >= 1450 {
        HStack(alignment: .top, spacing: 18) {
          githubBillingOverviewPanel
            .frame(maxWidth: 520, alignment: .topLeading)
          repoHealthPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        githubBillingOverviewPanel
        repoHealthPanel
      }

      githubBillingProjectUsagePanel
    }
  }

  private func localFilesPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .localFiles,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        if width >= 1500 {
          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
              rootsPanel
              externalDrivesPanel
              recoveryModePanel
              legacyWorkspaceMigrationPanel
              localFilesRelocationPanel
              backupPresetsPanel
            }
            .frame(maxWidth: 520, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
              localFilesExportPanel
              localFilesPreviewPanel
              snapshotsPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          rootsPanel
          externalDrivesPanel
          recoveryModePanel
          legacyWorkspaceMigrationPanel
          localFilesRelocationPanel
          backupPresetsPanel
          localFilesExportPanel
          localFilesPreviewPanel
          snapshotsPanel
        }

        if width >= 1500 {
          HStack(alignment: .top, spacing: 18) {
            localProjectsPanel
            projectQuickActionsPanel
          }
        } else {
          localProjectsPanel
          projectQuickActionsPanel
        }
      }
    }
  }

  private func cleanupPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .cleanup,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1560 {
        HStack(alignment: .top, spacing: 18) {
          VStack(alignment: .leading, spacing: 18) {
            authPanel
            repositoryPanel
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            cleanupPanel
            executionPanel
          }
          .frame(width: 460, alignment: .topLeading)

          logPanel(minHeight: 720)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          authPanel
          repositoryPanel
          cleanupPanel
          executionPanel
          logPanel(minHeight: 360)
        }
      }
    }
  }

  private func workspacePage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .workspace,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1400 {
        HStack(alignment: .top, spacing: 18) {
          workspaceSetupPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            rootsPanel
            legacyWorkspaceMigrationPanel
            if model.appSettings.showAdvancedTools || model.appSettings.keepTerminalFallbacksVisible {
              advancedToolsPanel
            } else {
              settingsPanel
            }
          }
          .frame(maxWidth: 520, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          workspaceSetupPanel
          rootsPanel
          legacyWorkspaceMigrationPanel
          if model.appSettings.showAdvancedTools || model.appSettings.keepTerminalFallbacksVisible {
            advancedToolsPanel
          } else {
            settingsPanel
          }
        }
      }
    }
  }

  private func settingsPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .settings,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1500 {
        HStack(alignment: .top, spacing: 18) {
          VStack(alignment: .leading, spacing: 18) {
            settingsPanel
            contextsPanel
          }
          .frame(maxWidth: 520, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            favoritesAndViewsPanel
            libraryPanel
            advancedToolsPanel
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          settingsPanel
          contextsPanel
          favoritesAndViewsPanel
          libraryPanel
          advancedToolsPanel
        }
      }
    }
  }

  private func documentPage(for destination: AppDestination, usesSidebar: Bool) -> some View {
    let markdown = bundledDocumentText(
      named: destination.bundleDocumentName ?? "",
      fallback: destination.fallbackDocumentText
    )

    return DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: false
      )

      WorkspaceToolbarStrip(
        destination: destination,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      DocumentReaderCard(destination: destination, markdown: markdown)
    }
  }

  private func aboutPage(usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: false
      )

      WorkspaceToolbarStrip(
        destination: .about,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      PanelCard(title: "About \(appTitle)", subtitle: "Product identity, bundle metadata, local storage path, and utility actions without leaving the app shell.") {
        BannerCard(
          title: "Native macOS Workspace App",
          detail: "\(model.bundleIdentitySummary)\nProvided by \(companyName) · \(companyWebsite)",
          kind: .ready
        )

        if let brandMark = model.bundledBrandMark {
          HStack(alignment: .center, spacing: 16) {
            BrandMarkSquareView(image: brandMark, size: 120, cornerRadius: 24)

            VStack(alignment: .leading, spacing: 8) {
              Text("Official press-kit artwork loaded")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)

              Text("This screen stays inside the native app. Use the left-side menu or the compact top menu to move between Home, Projects, Cleanup, Workspace, Help, and About without external file popups.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
                .lineSpacing(3)
            }

            Spacer(minLength: 0)
          }
          .padding(16)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(DashboardTheme.panelStrong)
              .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .stroke(DashboardTheme.border, lineWidth: 1)
              )
          )
        }

        FixedValueRow(label: "App Version", value: appVersion)
        FixedValueRow(label: "Product", value: appFullName)
        FixedValueRow(label: "Tagline", value: appSubtitle)
        FixedValueRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.waynetechlab.csaiem")
        FixedValueRow(label: "Company", value: companyName)
        FixedValueRow(label: "Website", value: companyWebsite)
        FixedValueRow(label: "Local Session Storage", value: appSupportDir)

        HStack(spacing: 10) {
          Button("Open Website") {
            model.openCompanyWebsite()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Reveal Session Storage") {
            model.revealSessionStorage()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        }
      }
    }
  }

  @ViewBuilder
  private func homeLayout(for width: CGFloat) -> some View {
    if width >= 1500 {
      HStack(alignment: .top, spacing: 18) {
        VStack(alignment: .leading, spacing: 18) {
          homeSummaryPanel
          accountSummaryPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)

        VStack(alignment: .leading, spacing: 18) {
          overviewPanel
          quickStartPanel
          ModuleMatrixCard(width: width)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)

        logPanel(minHeight: 540)
          .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    } else {
      VStack(alignment: .leading, spacing: 18) {
        homeSummaryPanel
        accountSummaryPanel
        overviewPanel
        quickStartPanel
        ModuleMatrixCard(width: width)
        logPanel(minHeight: 280)
      }
    }
  }

  private var authPanel: some View {
    PanelCard(title: "GitHub Auth", subtitle: "Clear account state, login controls, and fixed-value handling.") {
      FixedValueRow(label: "Current GitHub Session", value: model.sessionCompactLabel)

      if model.availableHosts.count > 1 {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Detected GitHub Hosts")
          Picker("", selection: $model.host) {
            ForEach(model.availableHosts, id: \.self) { host in
              Text(host).tag(host)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
        }
      } else if let onlyHost = model.availableHosts.first {
        FixedValueRow(label: "Detected GitHub Host", value: onlyHost)
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "GitHub Host")
        TextField("github.com", text: $model.host)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      if model.availableAccounts.count > 1 {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Authenticated Account")
          Picker("", selection: $model.account) {
            ForEach(model.availableAccounts, id: \.self) { account in
              Text(account).tag(account)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
        }
      } else if let onlyAccount = model.availableAccounts.first {
        FixedValueRow(label: "Authenticated Account", value: onlyAccount)
      } else {
        FixedValueRow(label: "Authenticated Account", value: "No logged-in account found for this host")
      }

      Text("Account state is mirrored in the bottom status bar. Refresh or re-login here only when you need to change the active GitHub session.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 10) {
          Button("Refresh") {
            model.refreshAuthStatus()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button(model.isAuthenticated ? "Re-Login" : "Login") {
            model.openGitHubLogin()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        }

        Button("Logout Selected Account") {
          model.logoutSelectedAccount()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(!model.isAuthenticated || model.isLoggingOut || model.account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private var accountSummaryPanel: some View {
    PanelCard(title: "GitHub Account", subtitle: "Connected account summary and fast access to the full account-management page.") {
      BannerCard(
        title: model.authHeadline,
        detail: model.authSummary + "\n" + model.githubAccountStatus,
        kind: model.isAuthenticated ? .ready : .warning
      )

      if let lastSession = model.lastSessionSummary {
        FixedValueRow(label: "Last Session", value: lastSession)
      }

      HStack(spacing: 10) {
        Button("Open Account Page") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: false))

        Button("Refresh") {
          model.refreshAuthStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }
    }
  }

  private var githubAccountInsightsPanel: some View {
    PanelCard(title: "Connected Account", subtitle: "Inspect the current GitHub session, organization memberships, and account-level entry points without leaving the app.") {
      FixedValueRow(label: "Current Session", value: model.sessionCompactLabel)
      FixedValueRow(label: "Target Owner or Org", value: model.repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? model.account : model.repoOwner)
      FixedValueRow(label: "Loaded Repository Count", value: "\(model.availableRepos.count)")
      FixedValueRow(label: "Organizations", value: model.viewerOrganizationsSummary)

      if let lastSession = model.lastSessionSummary {
        FixedValueRow(label: "Last Session", value: lastSession)
      }

      BannerCard(
        title: model.isLoadingGitHubAccountDetails ? "Refreshing connected account details" : "Connected account status",
        detail: model.githubAccountStatus,
        kind: model.isAuthenticated ? .ready : .warning
      )

      HStack(spacing: 10) {
        Button("Refresh Account") {
          model.refreshAuthStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Load Organizations") {
          model.fetchViewerOrganizations()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(!model.isAuthenticated || model.isLoadingGitHubAccountDetails)

        Button("Load Repositories") {
          model.fetchAvailableRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        .disabled(!model.isAuthenticated)
      }

      HStack(spacing: 10) {
        Button("Load Workflows") {
          model.loadWorkflowCatalog()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isLoadingWorkflowData)

        Button("Load Runs") {
          model.loadWorkflowRuns()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingWorkflowData)

        Button("Load Secrets") {
          model.loadSecretsAndVariables()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.isLoadingSecretsData)
      }

      HStack(spacing: 10) {
        Button("Load Rules") {
          model.loadBranchProtectionAndRulesets()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.isLoadingRulesData)

        Button("Open GitHub Settings") {
          model.openGitHubSettingsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accentPink, bordered: true))

        Button("Open Repo Settings") {
          model.openRepoSettingsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Copy Repo URL") {
          model.copyPrimaryRepoURL()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Copy Selected") {
          model.copySelectedRepoSummary()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Open Owner Page") {
          model.openRepoOwnerPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Open GitHub") {
          model.openGitHubHostPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))

        Button("Open Account") {
          model.openGitHubAccountPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))

        Button("Open Owner/Org") {
          model.openRepoOwnerPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Open Repositories") {
          model.openGitHubRepositoriesPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Open Settings") {
          model.openGitHubSettingsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accentPink, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Copy Host") {
          model.copyGitHubHost()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Copy Account") {
          model.copyGitHubAccount()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Copy Repo") {
          model.copyPrimaryRepoSlug()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Open Login") {
          model.openGitHubLogin()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Load Repo Health") {
          model.loadRepoHealthForSelectedRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.isLoadingRepoHealth)

        Button("Load Codespaces") {
          model.loadCodespaces()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isLoadingCodespaces)
      }

      HStack(spacing: 10) {
        Button("Open Actions") {
          model.openRepoActionsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Open Issues") {
          model.openRepoIssuesPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Open Pulls") {
          model.openRepoPullRequestsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Open Projects") {
          model.openRepoProjectsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Open Security") {
          model.openRepoSecurityPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))

        Button("Open Insights") {
          model.openRepoInsightsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))
      }

      Text("This page is the dedicated place for host, account, org, and repository management. Cleanup can still use the same connected session, but the home screen stays simpler.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var homeSummaryPanel: some View {
    PanelCard(title: "Workspace Overview", subtitle: "The app now speaks in simple workspace terms instead of exposing internal preset details.") {
      BannerCard(
        title: model.workspaceHeadline,
        detail: model.workspaceSummary,
        kind: .ready
      )

      if let detected = model.detectedWorkspaceSuggestion {
        BannerCard(
          title: detected.title,
          detail: detected.detail,
          kind: .ready
        )
      } else {
        BannerCard(
          title: "Standard local setup available",
          detail: "The standard setup uses \(publicDefaultCodeRoot), \(publicDefaultImportRoot), and \(publicDefaultRuntimeRoot).",
          kind: .warning
        )
      }

      Text("Custom-drive layouts are still supported, but the GUI now treats them as detected migration examples instead of product-facing presets.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var quickStartPanel: some View {
    PanelCard(title: "Quick Start", subtitle: "Move into the exact page you need instead of working from one crowded dashboard.") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
        ForEach([AppDestination.githubAccount, .githubBilling, .projects, .codexPortal, .projectBackups, .jobs, .localFiles, .cleanup, .workspace, .settings]) { destination in
          DestinationShortcutTile(destination: destination, isSelected: selectedDestination == destination) {
            selectedDestination = destination
          }
        }
      }

      Text("Projects stays fully on-screen for browsing local workspaces, active devcontainers, and runner services. Jobs tracks long-running work, Cleanup runs the CLI engine in the background, and Workspace/Settings handle paths, onboarding, and advanced behavior.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var jobsCenterPanel: some View {
    PanelCard(title: "Jobs Center", subtitle: "Central queue for background work with state, logs, retries, and safe cancellation where supported.") {
      BannerCard(
        title: model.recentJobSummary,
        detail: model.jobCenterStatus,
        kind: model.runningJobCount > 0 ? .running : .ready
      )

      HStack(spacing: 10) {
        Button("Refresh Local Data") {
          model.refreshLocalProjects()
          model.loadStorageInsights()
          model.loadProjectSyncStatus()
          model.loadPortMonitor()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Clear Completed") {
          model.clearCompletedJobs()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.backgroundJobs.isEmpty)
      }

      if let selectedJob = model.selectedJob {
        BannerCard(
          title: "\(selectedJob.title) · \(selectedJob.state.label)",
          detail: [selectedJob.target, selectedJob.detail, selectedJob.progressText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n"),
          kind: selectedJob.state.statusKind
        )

        HStack(spacing: 10) {
          Button("Retry") {
            model.retryJob(selectedJob)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Cancel") {
            model.cancelJob(selectedJob)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
          .disabled(model.selectedJob?.state != .running)
        }
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.backgroundJobs.isEmpty {
            Text("No jobs recorded yet. Workflow scans, local analysis, task runs, and file operations will appear here.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ForEach(model.backgroundJobs) { job in
              Button {
                model.selectedJobID = job.id
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text(job.title)
                      .font(.system(size: 14, weight: .bold, design: .rounded))
                      .foregroundStyle(DashboardTheme.text)
                    Spacer(minLength: 8)
                    PillBadge(text: job.state.label, tint: job.state.statusKind.tint)
                  }

                  Text([job.kind, job.target, job.detail].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                    .lineLimit(3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(model.selectedJobID == job.id ? DashboardTheme.field : DashboardTheme.panelStrong)
                    .overlay(
                      RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(model.selectedJobID == job.id ? job.state.statusKind.tint.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
                    )
                )
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .frame(minHeight: 220, idealHeight: 320, maxHeight: 420)
    }
  }

  private var settingsPanel: some View {
    PanelCard(title: "Settings & Onboarding", subtitle: "Control default host, preferred tools, auto-load behavior, and how much advanced surface area stays visible.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Default GitHub Host")
        TextField("github.com", text: $model.appSettings.defaultGitHubHost)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Preferred Editor Path (optional)")
        TextField("Auto-detect Visual Studio Code CLI", text: $model.appSettings.preferredEditorPath)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      Toggle("Prefer detected workspace on this Mac", isOn: $model.appSettings.preferDetectedWorkspace)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Prefer VS Code CLI when opening folders", isOn: $model.appSettings.preferVSCodeCLI)
        .toggleStyle(.switch)
        .tint(DashboardTheme.accent)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Run Docker checks during refresh", isOn: $model.appSettings.runDockerChecksOnRefresh)
        .toggleStyle(.switch)
        .tint(DashboardTheme.deepBlue)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Auto-load repo health after repo scans", isOn: $model.appSettings.autoLoadRepoHealth)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Auto-load workflow runs after workflow catalog loads", isOn: $model.appSettings.autoLoadWorkflowRuns)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Auto-confirm terminal yes/no gates", isOn: $model.appSettings.autoConfirmTerminalGates)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Administrator Terminal mode (sudo)", isOn: $model.administratorTerminalMode)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      if model.administratorTerminalMode {
        BannerCard(
          title: "Administrator Terminal is opt-in",
          detail: "CLI launchers will open a visible Terminal, run sudo -v, and wait for your macOS authorization. CSA-iEM never reads, types, stores, or logs the administrator password.",
          kind: .warning
        )

        Button {
          model.openAdministratorTerminalCheck()
        } label: {
          Label("Test Administrator Terminal", systemImage: "lock.shield")
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      Toggle("Privacy-First Mode (do not save GitHub identity or contexts)", isOn: $model.appSettings.privacyFirstMode)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Show advanced tools in the workspace page", isOn: $model.appSettings.showAdvancedTools)
        .toggleStyle(.switch)
        .tint(DashboardTheme.accentPink)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Keep terminal fallbacks visible", isOn: $model.appSettings.keepTerminalFallbacksVisible)
        .toggleStyle(.switch)
        .tint(DashboardTheme.accentPink)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: "Prerequisites",
        detail: [
          "gh: \(model.ghPath ?? "Not found")",
          "docker: \(model.dockerPath ?? "Not found")",
          "code: \(model.executablePath(named: "code") ?? "Not found")",
          "devcontainer: \(model.executablePath(named: "devcontainer") ?? "Not found")"
        ].joined(separator: "\n"),
        kind: .ready
      )

      HStack(spacing: 10) {
        Button("Save Settings") {
          model.saveSettings()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Open Workspace Page") {
          selectedDestination = .workspace
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Copy Workspace Summary") {
          model.copyWorkspaceSummary()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Open App Support") {
          model.openApplicationSupportFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Open Settings Folder") {
          model.openSettingsFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Copy Code Root") {
          model.copyCodeRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Copy Import Root") {
          model.copyImportRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Copy Runtime Root") {
          model.copyRuntimeRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Reset Launch Warning") {
          model.resetLaunchWarningAcceptance()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
      }

      Text(model.settingsStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
  }

  private var contextsPanel: some View {
    PanelCard(title: "Saved Contexts", subtitle: "Store named GitHub host/account/owner combinations so you can switch focus quickly without retyping.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Context Name")
        TextField("WayneTechLab Production", text: $model.contextNameDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Save Current Context") {
          model.saveCurrentContext()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.appSettings.privacyFirstMode)

        Button("Refresh GitHub") {
          model.refreshAuthStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      if model.appSettings.privacyFirstMode {
        Text("Privacy-First Mode is on. GitHub account and owner contexts are not stored by CSA-iEM.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else if model.savedContexts.isEmpty {
        Text("No saved contexts yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.savedContexts) { context in
          HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
              Text(context.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("\(context.host) · \(context.account) · \(context.owner)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }

            Spacer(minLength: 8)

            Button("Apply") {
              model.applyContext(context)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

            Button("Delete") {
              model.deleteContext(context)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var githubBillingOverviewPanel: some View {
    PanelCard(title: "GitHub Billing Reports", subtitle: "GitHub API usage data for Actions, storage, and packages. Open GitHub for current currency charges and invoices.") {
      FixedValueRow(label: "Billing Scope", value: model.repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? model.account : model.repoOwner)

      HStack(spacing: 10) {
        Button(model.isLoadingGitHubBilling ? "Loading..." : "Load Usage") {
          model.loadGitHubBillingReport()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: false))
        .disabled(model.isLoadingGitHubBilling || !model.isAuthenticated)

        Button("Open GitHub Billing") {
          model.openGitHubBillingReport()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))
        .disabled(!model.isAuthenticated)
      }

      BannerCard(
        title: model.githubBillingSummary == nil ? "Usage report not loaded" : "GitHub usage report loaded",
        detail: model.githubBillingStatus,
        kind: model.githubBillingSummary == nil ? .warning : .ready
      )

      if let summary = model.githubBillingSummary {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
          MetricTile(label: "Actions", value: summary.actionUsageLabel, tint: DashboardTheme.warning, icon: "play.rectangle")
          MetricTile(label: "Paid Actions", value: summary.paidUsageLabel, tint: DashboardTheme.danger, icon: "creditcard")
          MetricTile(label: "Storage", value: summary.storageUsageLabel, tint: DashboardTheme.deepBlue, icon: "externaldrive")
          MetricTile(label: "Packages", value: summary.packageUsageLabel, tint: DashboardTheme.accent, icon: "shippingbox")
        }

        if let included = summary.includedActionsMinutes {
          FixedValueRow(label: "Included Actions Minutes Used", value: "\(Int(included.rounded())) min")
        }

        if summary.actionBreakdown.isEmpty == false {
          FieldLabel(text: "Actions Usage Breakdown")
          ForEach(summary.actionBreakdown) { item in
            FixedValueRow(label: item.platform, value: "\(Int(item.minutes.rounded())) min")
          }
        }
      }

      Text("Usage units are not a price quote. GitHub applies plan allowances, multipliers, and credits when calculating charges; the GitHub billing page is the source of truth for currency totals.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var githubBillingProjectUsagePanel: some View {
    PanelCard(title: "Actions Usage by Project", subtitle: "Loads current Actions activity per selected or visible repository. This is operational usage, not an allocated invoice by repository.") {
      HStack(spacing: 10) {
        Button(model.isLoadingRepoHealth ? "Loading..." : "Load Selected Projects") {
          model.loadRepoHealthForSelectedRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingRepoHealth)

        Button("Load Visible Projects") {
          model.loadRepoHealthForVisibleRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isLoadingRepoHealth || model.filteredRepos.isEmpty)
      }

      Text("The project report shows enabled workflows, recent run count, hosted-runner indicators, active Codespaces, and local-runner coverage. Use it to find likely cost drivers before you disable or clean up Actions.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      if model.repoHealthEntries.isEmpty == false {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(model.repoHealthEntries) { entry in
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(entry.slug)
                  .font(.system(size: 14, weight: .bold, design: .rounded))
                  .foregroundStyle(DashboardTheme.text)
                Text("\(entry.recentRuns) recent runs · \(entry.githubHostedIndicators) hosted-runner indicators · \(entry.activeCodespaces) active Codespaces")
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
              }
              Spacer(minLength: 8)
              PillBadge(text: "\(entry.riskLabel) \(entry.riskScore)", tint: entry.riskScore >= 50 ? DashboardTheme.warning : DashboardTheme.success)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DashboardTheme.panelStrong))
          }
        }
      }
    }
  }

  private var repoHealthPanel: some View {
    PanelCard(title: "Repo Health Dashboard", subtitle: "Read-first GitHub Actions health, self-hosted coverage, Codespaces activity, and likely cost/risk signals.") {
      HStack(spacing: 10) {
        Button(model.isLoadingRepoHealth ? "Loading..." : "Load Selected") {
          model.loadRepoHealthForSelectedRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingRepoHealth)

        Button("Load Visible") {
          model.loadRepoHealthForVisibleRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isLoadingRepoHealth || model.filteredRepos.isEmpty)
      }

      BannerCard(
        title: "Actions cost & risk analyzer",
        detail: model.repoHealthStatus,
        kind: model.repoHealthEntries.isEmpty ? .warning : .ready
      )

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.repoHealthEntries.isEmpty {
            Text("Load repo health to see enabled workflows, recent run volume, active Codespaces, self-hosted coverage, and risk score.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ForEach(model.repoHealthEntries) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(entry.slug)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: "\(entry.riskLabel) \(entry.riskScore)", tint: entry.riskScore >= 50 ? DashboardTheme.warning : DashboardTheme.success)
                }

                Text(entry.summary)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(3)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 240, maxHeight: 320)
    }
  }

  private var researchSnapshotPanel: some View {
    PanelCard(title: "Repository Intelligence Snapshot", subtitle: "Read-only metadata-first research for one selected repository. It provides evidence and review prompts; it never selects a canonical source or authorizes a write.") {
      HStack(spacing: 10) {
        Button(model.isLoadingResearchSnapshot ? "Scanning…" : "Build Snapshot") {
          model.loadResearchSnapshot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: false))
        .disabled(model.isLoadingResearchSnapshot || !model.isAuthenticated)

        if model.researchSnapshot != nil {
          Button("Copy Summary") {
            model.copyResearchSnapshotSummary()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        }
      }

      BannerCard(
        title: model.researchSnapshot == nil ? "Snapshot not loaded" : "Snapshot ready",
        detail: model.researchStatus,
        kind: model.researchSnapshot == nil ? .warning : .ready
      )

      if let snapshot = model.researchSnapshot {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(snapshot.repository)
              .font(.system(size: 15, weight: .bold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
            Spacer(minLength: 8)
            if snapshot.isArchived { PillBadge(text: "ARCHIVED", tint: DashboardTheme.warning) }
            if snapshot.isFork { PillBadge(text: "FORK", tint: DashboardTheme.deepBlue) }
          }

          Text(snapshot.description.isEmpty ? "No repository description." : snapshot.description)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(3)

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            FixedValueRow(label: "Default branch", value: snapshot.defaultBranch)
            FixedValueRow(label: "Language", value: snapshot.primaryLanguage)
            FixedValueRow(label: "Issues", value: String(snapshot.issueCount))
            FixedValueRow(label: "Pull requests", value: String(snapshot.pullRequestCount))
            FixedValueRow(label: "Stars / forks", value: String(snapshot.stars) + " / " + String(snapshot.forks))
            FixedValueRow(label: "License", value: snapshot.license)
          }

          if snapshot.topics.isEmpty == false {
            FieldLabel(text: "Topics")
            Text(snapshot.topics.joined(separator: " · "))
              .font(.system(size: 12, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          }

          if snapshot.localMatches.isEmpty == false {
            FieldLabel(text: "Local path evidence")
            ForEach(snapshot.localMatches, id: \.self) { path in
              Text(path)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.muted)
                .textSelection(.enabled)
            }
          }

          if snapshot.localSummaries.isEmpty == false {
            FieldLabel(text: "Local codebase and dependency summary")
            ForEach(snapshot.localSummaries) { summary in
              VStack(alignment: .leading, spacing: 5) {
                Text(summary.path)
                  .font(.system(size: 11, weight: .semibold, design: .monospaced))
                  .foregroundStyle(DashboardTheme.text)
                  .textSelection(.enabled)
                Text(summary.summary)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                if summary.manifests.isEmpty == false {
                  Text("Manifests: " + summary.manifests.joined(separator: ", "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                }
                if summary.dependencies.isEmpty == false {
                  Text("Dependencies: " + summary.dependencies.prefix(12).joined(separator: ", ") + (summary.dependencies.count > 12 ? "…" : ""))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                }
                if summary.warnings.isEmpty == false {
                  Text("Review: " + summary.warnings.joined(separator: " "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.warning)
                }
              }
              .padding(10)
              .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DashboardTheme.field))
            }
          }

          FieldLabel(text: "Release history")
          if snapshot.releases.isEmpty {
            Text("No release entries were returned by GitHub for this repository.")
              .font(.system(size: 12, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(snapshot.releases) { release in
              HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                  Text(release.displayTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Text([release.tagName, release.publishedAt ?? "date unavailable"].joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DashboardTheme.muted)
                }
                Spacer(minLength: 8)
                if release.isDraft { PillBadge(text: "DRAFT", tint: DashboardTheme.warning) }
                if release.isPrerelease { PillBadge(text: "PRE", tint: DashboardTheme.deepBlue) }
              }
            }
          }

          if snapshot.localChangelogs.isEmpty == false {
            FieldLabel(text: "Local changelog evidence")
            ForEach(snapshot.localChangelogs) { changelog in
              VStack(alignment: .leading, spacing: 4) {
                Text(changelog.path)
                  .font(.system(size: 11, weight: .semibold, design: .monospaced))
                  .foregroundStyle(DashboardTheme.text)
                  .textSelection(.enabled)
                Text(changelog.summary)
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                if changelog.headings.isEmpty == false {
                  Text(changelog.headings.prefix(8).joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                }
                if changelog.warnings.isEmpty == false {
                  Text("Review: " + changelog.warnings.joined(separator: " "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.warning)
                }
              }
              .padding(10)
              .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DashboardTheme.field))
            }
          }

          if let documentation = snapshot.documentation {
            FieldLabel(text: "Documentation snapshot")
            VStack(alignment: .leading, spacing: 8) {
              Text(documentation.summary)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              if documentation.local.isEmpty == false {
                ForEach(documentation.local) { document in
                  VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                      .font(.system(size: 11, weight: .semibold, design: .rounded))
                      .foregroundStyle(DashboardTheme.text)
                    Text(document.path)
                      .font(.system(size: 10, weight: .medium, design: .monospaced))
                      .foregroundStyle(DashboardTheme.muted)
                      .textSelection(.enabled)
                    Text(document.summary)
                      .font(.system(size: 11, weight: .medium, design: .rounded))
                      .foregroundStyle(DashboardTheme.muted)
                    if document.headings.isEmpty == false {
                      Text(document.headings.prefix(8).joined(separator: " · "))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(DashboardTheme.muted)
                    }
                    if document.warnings.isEmpty == false {
                      Text("Review: " + document.warnings.joined(separator: " "))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(DashboardTheme.warning)
                    }
                  }
                  .padding(8)
                  .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DashboardTheme.field))
                }
              } else {
                Text("No bounded local documentation files were found in the matched project paths.")
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
              }
              if documentation.remote.isEmpty == false {
                Text("Remote: " + documentation.remote.map(\.path).joined(separator: " · "))
                  .font(.system(size: 10, weight: .medium, design: .monospaced))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(3)
                  .textSelection(.enabled)
              }
              ForEach(documentation.warnings, id: \.self) { warning in
                Text("Review: " + warning)
                  .font(.system(size: 10, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.warning)
              }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DashboardTheme.field))
          }

          FieldLabel(text: "Repository navigation")
          HStack(spacing: 7) {
            Button("Actions") { model.openRepoActionsPage() }
            Button("Issues") { model.openRepoIssuesPage() }
            Button("Pull requests") { model.openRepoPullRequestsPage() }
          }
          HStack(spacing: 7) {
            Button("Projects") { model.openRepoProjectsPage() }
            Button("Security") { model.openRepoSecurityPage() }
            Button("Insights") { model.openRepoInsightsPage() }
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          if snapshot.localWorkflows.isEmpty == false {
            FieldLabel(text: "Local workflow surface")
            ForEach(snapshot.localWorkflows) { workflow in
              VStack(alignment: .leading, spacing: 4) {
                Text(workflow.path)
                  .font(.system(size: 11, weight: .semibold, design: .monospaced))
                  .foregroundStyle(DashboardTheme.text)
                  .textSelection(.enabled)
                Text(workflow.summary)
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                if workflow.actionReferences.isEmpty == false {
                  Text("Actions: " + workflow.actionReferences.prefix(8).joined(separator: ", ") + (workflow.actionReferences.count > 8 ? "…" : ""))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                }
                if workflow.warnings.isEmpty == false {
                  Text("Review: " + workflow.warnings.joined(separator: " "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.warning)
                }
              }
              .padding(10)
              .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DashboardTheme.field))
            }
          }

          if let security = snapshot.security {
            FieldLabel(text: "Security and permission surface")
            VStack(alignment: .leading, spacing: 5) {
              Text(security.summary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text(security.readBoundary)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
              ForEach(security.warnings, id: \.self) { warning in
                Text("Review: " + warning)
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.warning)
              }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DashboardTheme.field))
          }

          if snapshot.riskNotes.isEmpty == false {
            FieldLabel(text: "Review flags")
            ForEach(snapshot.riskNotes, id: \.self) { note in
              Text("• " + note)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.warning)
            }
          }

          if snapshot.relationshipNotes.isEmpty == false {
            FieldLabel(text: "Relationship evidence")
            ForEach(snapshot.relationshipNotes, id: \.self) { note in
              Text("• " + note)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }
          }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DashboardTheme.panelStrong))
      }
    }
  }

  private var workflowControlPanel: some View {
    PanelCard(title: "Workflow Control Center", subtitle: "Load repository workflows, open YAML locally, enable or disable them, or dispatch supported manual workflows.") {
      FixedValueRow(label: "Target Repository", value: model.primaryRepoSlug ?? "Select or target a repository first")

      HStack(spacing: 10) {
        Button(model.isLoadingWorkflowData ? "Loading..." : "Load Workflows") {
          model.loadWorkflowCatalog()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingWorkflowData)

        Button("Open GitHub Account") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.workflowStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.workflows.isEmpty {
            Text("No workflows loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.workflows) { workflow in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(workflow.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: workflow.state, tint: workflow.state.lowercased() == "active" ? DashboardTheme.success : DashboardTheme.warning)
                }

                Text(workflow.path)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)

                HStack(spacing: 10) {
                  Button("Open YAML") {
                    model.openWorkflowSource(workflow)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

                  Button("Dispatch") {
                    model.runWorkflow(workflow)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

                  Button(workflow.state.lowercased() == "active" ? "Disable" : "Enable") {
                    if workflow.state.lowercased() == "active" {
                      model.disableWorkflow(workflow)
                    } else {
                      model.enableWorkflow(workflow)
                    }
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 260, maxHeight: 340)
    }
  }

  private var workflowRunsPanel: some View {
    PanelCard(title: "Workflow Runs Explorer", subtitle: "Review recent runs, open them on GitHub, and cancel, rerun, or delete them without leaving the app.") {
      HStack(spacing: 10) {
        Button(model.isLoadingWorkflowData ? "Loading..." : "Load Runs") {
          model.loadWorkflowRuns()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingWorkflowData)

        Button("Preview Cleanup") {
          selectedDestination = .cleanup
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.workflowRuns.isEmpty {
            Text("No workflow runs loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.workflowRuns) { run in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(run.workflowName ?? run.name ?? "Workflow Run")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: run.status ?? "unknown", tint: (run.conclusion ?? "").lowercased() == "success" ? DashboardTheme.success : DashboardTheme.warning)
                }

                Text([run.displayTitle ?? "", run.headBranch ?? "", run.event ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)

                HStack(spacing: 10) {
                  Button("Open") {
                    model.openWorkflowRunInBrowser(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

                  Button("Rerun") {
                    model.rerunWorkflowRun(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

                  Button("Cancel") {
                    model.cancelWorkflowRun(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

                  Button("Delete") {
                    model.deleteWorkflowRun(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 260, maxHeight: 340)
    }
  }

  private var codespacesPanel: some View {
    PanelCard(title: "Codespaces Inventory", subtitle: "List, stop, and delete live Codespaces and compare them to the local runtime workspace.") {
      HStack(spacing: 10) {
        Button(model.isLoadingCodespaces ? "Loading..." : "Load Codespaces") {
          model.loadCodespaces()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingCodespaces)

        Button("Open Projects") {
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.codespacesStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.codespaces.isEmpty {
            Text("No Codespaces loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.codespaces) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(entry.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: entry.state, tint: entry.state.lowercased().contains("available") ? DashboardTheme.success : DashboardTheme.warning)
                }

                Text([entry.repo, entry.machineName, entry.lastUsedAt].filter { !$0.isEmpty }.joined(separator: " · "))
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)

                HStack(spacing: 10) {
                  Button("Stop") {
                    model.stopCodespace(entry)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

                  Button("Delete") {
                    model.deleteCodespace(entry)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 120, idealHeight: 220, maxHeight: 280)
    }
  }

  private var secretsAndVariablesPanel: some View {
    PanelCard(title: "Secrets & Variables", subtitle: "Compare repo and organization-level secret/variable presence without exposing secret values.") {
      HStack(spacing: 10) {
        Button(model.isLoadingSecretsData ? "Loading..." : "Load Secrets & Variables") {
          model.loadSecretsAndVariables()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingSecretsData)

        Button("Open Repo Settings") {
          model.openRepoSettingsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      BannerCard(
        title: "Repo \(model.repoSecrets.count) secrets · \(model.repoVariables.count) variables",
        detail: model.secretsStatus + "\nOrg \(model.orgSecrets.count) secrets · \(model.orgVariables.count) variables",
        kind: .ready
      )

      FixedValueRow(label: "Repo Secret Names", value: model.repoSecrets.isEmpty ? "None loaded" : model.repoSecrets.map(\.name).joined(separator: ", "))
      FixedValueRow(label: "Repo Variable Names", value: model.repoVariables.isEmpty ? "None loaded" : model.repoVariables.map(\.name).joined(separator: ", "))
      FixedValueRow(label: "Org Secret Names", value: model.orgSecrets.isEmpty ? "None loaded" : model.orgSecrets.map(\.name).joined(separator: ", "))
      FixedValueRow(label: "Org Variable Names", value: model.orgVariables.isEmpty ? "None loaded" : model.orgVariables.map(\.name).joined(separator: ", "))
    }
  }

  private var rulesetsPanel: some View {
    PanelCard(title: "Branch Protection & Rulesets", subtitle: "Read-first view of required checks, review policy, admin enforcement, and repo rulesets.") {
      HStack(spacing: 10) {
        Button(model.isLoadingRulesData ? "Loading..." : "Load Rules") {
          model.loadBranchProtectionAndRulesets()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingRulesData)

        Button("Open Cleanup") {
          selectedDestination = .cleanup
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      if let protection = model.branchProtectionSummary {
        BannerCard(
          title: "Default branch: \(protection.branch)",
          detail: "Required status checks: \(protection.requiredStatusChecks)\nRequired PR reviews: \(protection.requiredPullRequestReviews ? "yes" : "no")\nEnforce admins: \(protection.enforceAdmins ? "yes" : "no")",
          kind: .ready
        )
      } else {
        BannerCard(
          title: "No branch protection loaded",
          detail: model.rulesStatus,
          kind: .warning
        )
      }

      if model.rulesets.isEmpty {
        Text("No rulesets loaded yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.rulesets) { ruleset in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(ruleset.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("\(ruleset.target) · \(ruleset.enforcement) · \(ruleset.source)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }
            Spacer(minLength: 8)
            PillBadge(text: ruleset.enforcement, tint: DashboardTheme.warning)
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var workspaceSetupPanel: some View {
    let standardSuggestion = model.standardWorkspaceSuggestion
    let detectedSuggestion = model.detectedWorkspaceSuggestion

    return PanelCard(title: "Workspace Setup", subtitle: "Choose explicit Code, Import, and Runtime roots, use the standard path set, or apply the setup this Mac already has.") {
      Toggle("Follow the current saved workspace automatically", isOn: $model.useCurrentRoot)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: standardSuggestion.title,
        detail: standardSuggestion.detail + "\nCode: \(standardSuggestion.codeRoot)\nImport: \(standardSuggestion.importRoot)\nRuntime: \(standardSuggestion.runtimeRoot)",
        kind: .ready
      )

      if let detectedSuggestion {
        BannerCard(
          title: detectedSuggestion.title,
          detail: detectedSuggestion.detail + "\nCode: \(detectedSuggestion.codeRoot)\nImport: \(detectedSuggestion.importRoot)\nRuntime: \(detectedSuggestion.runtimeRoot)",
          kind: .ready
        )
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Code Folder")
        TextField("Choose the folder for plain repos", text: $model.workspaceCodeRootDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Import Folder")
        TextField("Choose the folder for Codespaces exports, zip drops, and staging", text: $model.workspaceImportRootDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Runtime Folder")
        TextField("Choose the folder for devcontainers, reports, logs, backups, and runners", text: $model.workspaceRuntimeRootDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Choose Code") {
          model.chooseCodeWorkspaceFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Choose Import") {
          model.chooseImportWorkspaceFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Choose Runtime") {
          model.chooseRuntimeWorkspaceFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Auto Mode") {
          model.enableAutoMode()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Use Standard") {
          model.applyStandardWorkspace()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))

        if detectedSuggestion != nil {
          Button("Use Detected Setup") {
            model.applyDetectedWorkspace()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        }
      }

      HStack(spacing: 10) {
        Button("Save Workspace") {
          model.saveWorkspaceDrafts()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Open Projects Page") {
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      Text("The standard setup is concrete and generic. Legacy external-drive layouts are still detected automatically on this Mac, but they are presented as optional migration setups instead of product presets.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var localFilesRelocationPanel: some View {
    PanelCard(title: "Relocate Workspace", subtitle: "Move the current workspace roots to a new base folder and update the saved workspace so the app follows the new location.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "New Base Folder")
        TextField("Choose a destination for the moved workspace", text: $model.workspaceMoveDestinationDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      Toggle("Allow overwrite if destination folders already exist", isOn: $model.overwriteLocalFileDestination)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: "Move the full workspace or move the main roots one by one",
        detail: model.localFilesStatus,
        kind: model.isRunningLocalFileOperation ? .running : .ready
      )

      if model.isRunningLocalFileOperation {
        ProgressView()
          .progressViewStyle(.linear)
          .tint(DashboardTheme.link)
          .frame(maxWidth: .infinity)
          .accessibilityLabel("Moving and verifying workspace files")
      }

      HStack(spacing: 10) {
        Button("Choose Destination") {
          model.chooseWorkspaceMoveDestinationFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Move Workspace") {
          model.relocateWorkspace(.workspace)
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: false))
        .disabled(model.isRunningLocalFileOperation)
      }

      if model.selectedWorkspaceStyle == .split {
        HStack(spacing: 10) {
          Button("Move Code Root Only") {
            model.relocateWorkspace(.codeRoot)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
          .disabled(model.isRunningLocalFileOperation)

          Button("Move Runtime Root Only") {
            model.relocateWorkspace(.runtimeRoot)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          .disabled(model.isRunningLocalFileOperation)
        }
      }

      Text("When you move workspace roots here, the app updates the saved workspace to point at the new location. This is the right path when you are relocating your active setup to another drive.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var legacyWorkspaceMigrationPanel: some View {
    PanelCard(title: "Old Workspace Migration", subtitle: "Find projects and runners from older Default, Diamond, WTL, or CSA-iLEM folders and import them into the current Default or Custom roots.") {
      HStack(spacing: 10) {
        Button("Scan Old Workspaces") {
          model.scanLegacyWorkspaces()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Use Default Roots") {
          model.applyStandardWorkspace()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))

        Button("Save Custom Roots") {
          model.saveWorkspaceDrafts()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.legacyWorkspaceScanStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      if !model.legacyWorkspaceCandidates.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Old Workspace To Import")
          Picker("", selection: $model.selectedLegacyWorkspaceID) {
            ForEach(model.legacyWorkspaceCandidates) { candidate in
              Text("\(candidate.label) · \(candidate.summary)").tag(candidate.id)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .dashboardFieldStyle()
        }

        if let selected = model.legacyWorkspaceCandidates.first(where: { $0.id == model.selectedLegacyWorkspaceID }) {
          VStack(alignment: .leading, spacing: 6) {
            FixedValueRow(label: "Old Code Root", value: selected.codeRoot)
            FixedValueRow(label: "Old Import Root", value: selected.importRoot)
            FixedValueRow(label: "Old Runtime Root", value: selected.runtimeRoot)
          }
        }

        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Migration Mode")
          Picker("", selection: $model.localFileTransferMode) {
            ForEach(LocalFileTransferMode.allCases) { mode in
              Text(mode.label).tag(mode)
            }
          }
          .labelsHidden()
          .pickerStyle(.segmented)
        }

        Toggle("Allow overwrite when destination project folders already exist", isOn: $model.overwriteLocalFileDestination)
          .toggleStyle(.switch)
          .tint(DashboardTheme.warning)
          .foregroundStyle(DashboardTheme.text)

        Button(model.localFileTransferMode == .move ? "Move Into Current Workspace" : "Copy Into Current Workspace") {
          model.migrateSelectedLegacyWorkspace()
        }
        .buttonStyle(DashboardButtonStyle(tint: model.localFileTransferMode == .move ? DashboardTheme.warning : DashboardTheme.success, bordered: false))
      }

      Text("Copy Backup is the safest migration mode. Move removes old project folders only after staged copies land in the current workspace. Docker/devcontainer and runner views refresh after migration.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var recoveryModePanel: some View {
    PanelCard(title: "Recovery Mode", subtitle: "Resume an interrupted move by scanning an old, backup, or partially moved folder and merging missing files into the active workspace.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Recovery Source")
        TextField("Choose an old workspace or backup folder", text: $model.recoverySourcePath)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Choose Source") {
          model.chooseRecoverySource()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Scan Source") {
          model.scanRecoverySource()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Recover Missing Files") {
          model.recoverSelectedSource()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.recoveryCandidate == nil || model.isRunningLocalFileOperation)
      }

      BannerCard(
        title: model.recoveryCandidate?.summary ?? "No recovery source scanned",
        detail: model.recoverySourceStatus,
        kind: model.recoveryCandidate == nil ? .warning : .ready
      )

      if let candidate = model.recoveryCandidate {
        FixedValueRow(label: "Source", value: candidate.label)
        FixedValueRow(label: "Active Code Root", value: model.resolvedProfileRootsForDisplay.codeRoot)
        FixedValueRow(label: "Active Runtime Root", value: model.resolvedProfileRootsForDisplay.runtimeRoot)
      }

      Text("Recovery always uses Copy Backup behavior: it fills missing files and preserves existing destination files. It does not delete the source, making it safe to run again after a failed or interrupted move.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var externalDrivesPanel: some View {
    PanelCard(title: "External Drives", subtitle: "Use a mounted drive for a backup, selected projects, or as the permanent Default workspace location.") {
      HStack(spacing: 10) {
        Button("Refresh Drives") {
          model.scanExternalVolumes()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Choose Folder") {
          model.chooseLocalExportDestinationFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.externalVolumesStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      Text(model.externalWorkspaceSizeLabel)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)

      if model.externalVolumes.isEmpty == false {
        ForEach(model.externalVolumes) { volume in
          HStack(alignment: .center, spacing: 12) {
            Image(systemName: "externaldrive.fill")
              .foregroundStyle(DashboardTheme.warning)
              .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
              Text(volume.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("\(volume.path) · \(volume.capacityLabel)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Use") { model.selectExternalVolume(volume) }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
            Button("Use As Default") { model.setExternalVolumeAsDefault(volume) }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
            Button("Reveal") { model.revealExternalVolume(volume) }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
          }
          .padding(12)
          .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DashboardTheme.panelStrong))
        }
      }

      if let selected = model.externalVolumes.first(where: { $0.path == model.selectedExternalVolumePath }) {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          Text("Make \(selected.name) The New Default")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
          FixedValueRow(label: "New Default Base", value: model.externalWorkspaceBase(for: selected))
          Text("Use As Default changes only the saved paths. Prepare Move creates a collision-aware preview. Move All copies every root to the new drive, verifies the staged destination, removes old roots only after success, and then saves the new Default paths.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineSpacing(2)
          HStack(spacing: 10) {
            Button("Prepare Move") { model.prepareExternalDefaultMove(selected) }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
            Button("Open New Workspace") { model.revealExternalWorkspace(selected) }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
          }
          Toggle("I reviewed the move preview and want to move all current workspace files", isOn: $model.externalDefaultMoveConfirmed)
            .toggleStyle(.switch)
            .tint(DashboardTheme.danger)
            .foregroundStyle(DashboardTheme.text)
          Button("Move All And Make Default") { model.moveWorkspaceToExternalDefault(selected) }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: false))
            .disabled(model.isRunningLocalFileOperation || !model.externalDefaultMoveConfirmed)
        }
      }

      Button("Restore Internal Default Paths") { model.restoreInternalDefaultWorkspace() }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

      Text("Use Full Workspace for all local CSA-iEM files. Use Selected Projects after selecting projects in the Local Project Library. Copy Backup keeps originals. The permanent move requires a prepared preview and a separate confirmation. Restoring internal paths never moves or deletes files.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var localFilesExportPanel: some View {
    PanelCard(title: "Backup & Export", subtitle: "Copy or move selected projects or workspace content into a structured export bundle for another drive, archive, or handoff.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Export Destination")
        TextField("Choose where the export bundle should be created", text: $model.localExportDestinationDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Choose Destination") {
          model.chooseLocalExportDestinationFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button(model.localFilesPrimaryActionTitle) {
          model.runLocalExport()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.isRunningLocalFileOperation)
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Transfer Mode")
        Picker("", selection: $model.localFileTransferMode) {
          ForEach(LocalFileTransferMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Export Scope")
        Picker("", selection: $model.localFileExportScope) {
          ForEach(LocalFileExportScope.allCases) { scope in
            Text(scope.label).tag(scope)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .dashboardFieldStyle()
      }

      if model.localFileExportScope == .selectedProjects {
        Toggle("Include code paths", isOn: $model.includeProjectCodeExport)
          .toggleStyle(.switch)
          .tint(DashboardTheme.deepBlue)
          .foregroundStyle(DashboardTheme.text)

        Toggle("Include runtime paths", isOn: $model.includeProjectRuntimeExport)
          .toggleStyle(.switch)
          .tint(DashboardTheme.success)
          .foregroundStyle(DashboardTheme.text)

        Toggle("Include runner folders", isOn: $model.includeProjectRunnerExport)
          .toggleStyle(.switch)
          .tint(DashboardTheme.warning)
          .foregroundStyle(DashboardTheme.text)
      }

      Toggle("Allow overwrite if export targets already exist", isOn: $model.overwriteLocalFileDestination)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: model.localFilesScopeSummary,
        detail: model.localFilesStatus,
        kind: model.isRunningLocalFileOperation ? .running : .ready
      )

      if model.isRunningLocalFileOperation {
        ProgressView()
          .progressViewStyle(.linear)
          .tint(DashboardTheme.link)
          .frame(maxWidth: .infinity)
          .accessibilityLabel("Exporting and verifying local files")
      }

      Text("Selected-project exports preserve a concrete structure under `Code/Repos`, `Runtime/Repos`, and `Runtime/Runners`. Use `Copy Backup` for safe archives and `Move` when you want to relocate items out of the current workspace.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var backupPresetsPanel: some View {
    PanelCard(title: "Backup Presets", subtitle: "Reusable local-file presets for common archive and transfer combinations.") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
        ForEach(BackupPreset.allCases) { preset in
          Button {
            model.applyBackupPreset(preset)
          } label: {
            HStack {
              Text(preset.label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Spacer(minLength: 8)
              if model.selectedBackupPreset == preset {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(DashboardTheme.success)
              }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(model.selectedBackupPreset == preset ? DashboardTheme.field : DashboardTheme.panelStrong)
                .overlay(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(model.selectedBackupPreset == preset ? DashboardTheme.success.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
                )
            )
          }
          .buttonStyle(.plain)
        }
      }

      Text("Use a preset first, then preview the export or snapshot before you move or copy local data.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
  }

  private var localFilesPreviewPanel: some View {
    PanelCard(title: "Preview & Move Wizard", subtitle: "Inspect destination, size, and collision risk before you move workspace roots or export local data.") {
      HStack(spacing: 10) {
        Button("Preview Workspace Move") {
          model.previewWorkspaceMove(.workspace)
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Preview Export") {
          model.previewLocalExport()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      if let preview = model.localOperationPreview {
        BannerCard(
          title: preview.title,
          detail: "Destination: \(preview.destinationPath)\nItems: \(preview.itemCount)\nEstimated size: \(preview.totalSizeLabel)",
          kind: preview.collisions.isEmpty ? .ready : .warning
        )

        if !preview.collisions.isEmpty {
          FixedValueRow(label: "Existing Destination Conflicts", value: preview.collisions.joined(separator: "\n"))
        }
      } else {
        Text("No preview generated yet. Use preview first, then run the move or export.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
    }
  }

  private var snapshotsPanel: some View {
    PanelCard(title: "Workspace Snapshots", subtitle: "Create point-in-time archives before major changes, then restore or remove them later.") {
      HStack(spacing: 10) {
        Button("Create Snapshot") {
          model.createSnapshot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.isRunningLocalFileOperation)

        Button("Refresh Storage") {
          model.loadStorageInsights()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      Text(model.snapshotStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      if model.snapshots.isEmpty {
        Text("No snapshots saved yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(model.snapshots.sorted(by: { $0.createdAt > $1.createdAt })) { snapshot in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(snapshot.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: snapshot.sourceScope, tint: DashboardTheme.warning)
                }

                Text("\(snapshot.itemCount) items · \(snapshot.destinationPath)")
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(3)

                HStack(spacing: 10) {
                  Button("Restore") {
                    model.restoreSnapshot(snapshot)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

                  Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: snapshot.destinationPath)])
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

                  Button("Delete") {
                    model.removeSnapshot(snapshot)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
        .frame(minHeight: 150, idealHeight: 220, maxHeight: 280)
      }
    }
  }

  private var projectQuickActionsPanel: some View {
    PanelCard(title: "Project Quick Actions", subtitle: "Native operator console for the selected local project: open, inspect, build, up, rebuild, and manage linked local services.") {
      if let project = model.primaryLocalProject {
        BannerCard(
          title: project.slug,
          detail: "Code: \(project.codePath ?? "Unavailable")\nRuntime: \(project.runtimePath ?? "Unavailable")",
          kind: .ready
        )

        HStack(spacing: 10) {
          Button("Open Runtime") {
            model.openLocalProject(project, preferRuntime: true)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Open Code") {
            model.openLocalProject(project, preferRuntime: false)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button("Finder") {
            model.revealLocalProject(project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

          Button(model.favoriteProjects.contains(project.slug) ? "Unfavorite" : "Favorite") {
            model.toggleFavorite(project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        }

        HStack(spacing: 10) {
          Button("Open in Browser") {
            model.openPrimaryLocalProjectInBrowser()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

          Button("Open in Terminal") {
            model.openPrimaryLocalProjectInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button("Copy Repo Slug") {
            model.copyPrimaryLocalProjectSlug()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Copy Repo Path") {
            model.copyPrimaryLocalProjectPath()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Copy Repo URL") {
            model.copyPrimaryLocalProjectURL()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        }

        HStack(spacing: 10) {
          Button("Open Devcontainer") {
            model.openDevcontainerConfig(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
          .disabled(!project.hasDevcontainer)

          Button("Build") {
            model.buildDevcontainer(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
          .disabled(project.preferredOpenPath == nil)

          Button("Up") {
            model.upDevcontainer(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
          .disabled(project.preferredOpenPath == nil)

          Button("Rebuild") {
            model.rebuildDevcontainer(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          .disabled(project.preferredOpenPath == nil)
        }
      } else {
        Text("Target or search to one local project to unlock quick actions.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
    }
  }

  private var favoritesAndViewsPanel: some View {
    PanelCard(title: "Favorites, Views & Quick Actions", subtitle: "Pin common repos, save library filters, and recall them instantly.") {
      BannerCard(
        title: "\(model.favoriteProjectCount) favorites · \(model.savedProjectViews.count) saved views",
        detail: "Local library filter: \(model.localProjectSearch.isEmpty ? "none" : model.localProjectSearch)\nFavorites only: \(model.showFavoritesOnly ? "on" : "off")",
        kind: .ready
      )

      Toggle("Show favorites only in Local Project Library", isOn: $model.showFavoritesOnly)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Save Current Project View")
        TextField("Favorites + self-hosted runners", text: $model.savedViewNameDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Save View") {
          model.saveCurrentProjectView()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Open Projects") {
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      if model.savedProjectViews.isEmpty {
        Text("No saved views yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.savedProjectViews) { view in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(view.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("Query: \(view.query.isEmpty ? "none" : view.query) · Favorites only: \(view.favoritesOnly ? "yes" : "no")")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }

            Spacer(minLength: 8)

            Button("Apply") {
              model.applyProjectView(view)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

            Button("Delete") {
              model.deleteProjectView(view)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var taskTemplatesPanel: some View {
    PanelCard(title: "Task Templates", subtitle: "Store reusable local project commands such as install, build, test, deploy, or Docker actions.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Task Name")
        TextField("Install dependencies", text: $model.taskNameDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Command")
        TextField("npm install && npm test", text: $model.taskCommandDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Run In")
        Picker("", selection: $model.taskLocationDraft) {
          ForEach(ProjectTaskLocation.allCases) { location in
            Text(location.label).tag(location)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
      }

      HStack(spacing: 10) {
        Button("Save Task") {
          model.addTaskTemplate()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        if model.isRunningTask {
          Button("Cancel Task") {
            model.cancelRun()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        }
      }

      Text(model.taskStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      if model.filteredTaskTemplates.isEmpty {
        Text("No saved tasks for the currently targeted project.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.filteredTaskTemplates) { task in
          HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
              Text(task.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("\(task.location.label) · \(task.command)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
                .lineLimit(3)
            }

            Spacer(minLength: 8)

            Button("Run") {
              model.runTaskTemplate(task)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

            Button("Delete") {
              model.removeTaskTemplate(task)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var storageInsightsPanel: some View {
    PanelCard(title: "Disk Usage & Storage Insights", subtitle: "Local storage reporting for workspace roots, runners, snapshots, and major local service footprints.") {
      HStack(spacing: 10) {
        Button(model.isLoadingStorageInsights ? "Loading..." : "Load Storage") {
          model.loadStorageInsights()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingStorageInsights)

        Button("Open Local Files") {
          selectedDestination = .localFiles
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.storageStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      if model.storageInsights.isEmpty {
        Text("No storage insights loaded yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.storageInsights) { entry in
          FixedValueRow(label: "\(entry.label) · \(entry.sizeLabel)", value: entry.path)
        }
      }
    }
  }

  private var projectSyncPanel: some View {
    PanelCard(title: "Project Sync Status", subtitle: "Compare code and runtime worktrees for ahead/behind/dirty state to spot drift before cleanup or backup.") {
      HStack(spacing: 10) {
        Button(model.isLoadingProjectSync ? "Loading..." : "Load Sync Status") {
          model.loadProjectSyncStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingProjectSync)

        Button("Open GitHub Account") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.syncStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.projectSyncEntries.isEmpty {
            Text("No project sync data loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.projectSyncEntries) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(entry.slug)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: entry.codeDirty || entry.runtimeDirty ? "dirty" : "clean", tint: entry.codeDirty || entry.runtimeDirty ? DashboardTheme.warning : DashboardTheme.success)
                }
                Text(entry.summary)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 220, maxHeight: 280)
    }
  }

  private var portMonitorPanel: some View {
    PanelCard(title: "Service & Port Monitor", subtitle: "Native view of listening local services and exposed development ports on this Mac.") {
      HStack(spacing: 10) {
        Button(model.isLoadingPorts ? "Loading..." : "Scan Ports") {
          model.loadPortMonitor()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingPorts)

        Button("Refresh Services") {
          model.refreshLiveServices()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.portsStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.portMonitorEntries.isEmpty {
            Text("No port scan results loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.portMonitorEntries.prefix(20)) { entry in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("\(entry.processName) · \(entry.proto)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Text("PID \(entry.pid) · Port \(entry.port)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                }
                Spacer(minLength: 8)
                PillBadge(text: entry.port, tint: DashboardTheme.accent)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 140, idealHeight: 220, maxHeight: 280)
    }
  }

  private var advancedToolsPanel: some View {
    PanelCard(title: "Advanced Tools", subtitle: "Use native pages first. Terminal fallbacks stay optional for edge cases and power workflows.") {
      HStack(spacing: 10) {
        Button("Projects Page") {
          model.refreshLocalProjects()
          model.refreshLiveServices()
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Cleanup Page") {
          selectedDestination = .cleanup
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Jobs Page") {
          selectedDestination = .jobs
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("GitHub Account") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
      }

      Text("Normal use should stay inside the native app: Projects for local work, Cleanup for GitHub cost-control, Jobs for execution state, and GitHub Account for repo administration.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      if model.appSettings.keepTerminalFallbacksVisible {
        Divider()
          .overlay(DashboardTheme.border)

        HStack(spacing: 10) {
          Button("Interactive CLI") {
            model.openCLIInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button("Terminal Browser") {
            model.openProjectBrowserInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        }

        HStack(spacing: 10) {
          Button("Terminal Cost-Control") {
            model.openCostControlReviewInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

          Button("Terminal Devcontainers") {
            model.openInstalledDevcontainersInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        }
      } else {
        Text("Terminal fallback buttons are hidden by default. You can re-enable them in Settings if you still want the legacy edge-case launchers.")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineSpacing(2)
      }
    }
  }

  private var rootsPanel: some View {
    let roots = model.profileRootSummary

    return PanelCard(title: "Active Workspace Paths", subtitle: "These are the live local paths the GUI is using right now for plain repos, import staging, runtime work, reports, and runners.") {
      FixedValueRow(label: "Code Root", value: roots.codeRoot)
      FixedValueRow(label: "Import Root", value: roots.importRoot)
      FixedValueRow(label: "Runtime Root", value: roots.runtimeRoot)

      HStack(spacing: 10) {
        Button("Reveal Code Root") {
          model.revealCodeRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Reveal Import Root") {
          model.revealImportRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Reveal Runtime Root") {
          model.revealRuntimeRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      Text(model.useCurrentRoot
        ? "The app is following your saved workspace setup. Use the Workspace page when you want to change paths or apply a different detected setup."
        : "The app is showing the built-in standard paths. Turn the saved-workspace toggle back on when you want the GUI to follow your stored setup again.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var overviewPanel: some View {
    let metricColumns = [
      GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12, alignment: .top)
    ]

    return PanelCard(title: "Local Inventory", subtitle: "Fast production snapshot of imported project coverage for the current workspace setup.") {
      LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
        MetricTile(
          label: "Imported Projects",
          value: "\(model.localProjects.count)",
          tint: DashboardTheme.accent,
          icon: "shippingbox"
        )

        MetricTile(
          label: "Split Code + Runtime",
          value: "\(model.localProjectSplitCount)",
          tint: DashboardTheme.deepBlue,
          icon: "square.split.2x1"
        )

        MetricTile(
          label: "Ready Devcontainers",
          value: "\(model.localProjectDevcontainerCount)",
          tint: DashboardTheme.success,
          icon: "shippingbox.circle"
        )

        MetricTile(
          label: "Local Runners",
          value: "\(model.localProjectRunnerCount)",
          tint: DashboardTheme.warning,
          icon: "bolt.shield"
        )

        MetricTile(
          label: "Active Devcontainers",
          value: "\(model.activeContainerCount)",
          tint: DashboardTheme.deepBlue,
          icon: "shippingbox.fill"
        )

        MetricTile(
          label: "Running Runner Services",
          value: "\(model.runningRunnerServiceCount)",
          tint: DashboardTheme.success,
          icon: "bolt.horizontal.circle"
        )
      }

      BannerCard(
        title: "Generated starters: \(model.localProjectGeneratedStarterCount) · Runtime-only workspaces: \(model.localProjectRuntimeOnlyCount)",
        detail: "\(model.localProjectStatus)\n\(model.liveServiceSummary)",
        kind: model.localProjects.isEmpty ? .warning : .ready
      )
    }
  }

  private var localProjectsPanel: some View {
    PanelCard(title: "Local Project Library", subtitle: "Search imported local workspaces and open them directly from the native app.") {
      HStack(spacing: 10) {
        Button(model.isLoadingLocalProjects ? "Refreshing..." : "Refresh Local Projects") {
          model.refreshLocalProjects()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingLocalProjects)

        Button(model.areAllVisibleLocalProjectsSelected ? "Untarget Visible" : "Target Visible") {
          model.setFilteredLocalProjectsSelected(!model.areAllVisibleLocalProjectsSelected)
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.filteredLocalProjects.isEmpty)
      }

      if model.isLoadingLocalProjects {
        ProgressView()
          .progressViewStyle(.linear)
          .tint(DashboardTheme.link)
          .frame(maxWidth: .infinity)
          .accessibilityLabel("Scanning local projects")
      }

      Toggle("Favorites only", isOn: $model.showFavoritesOnly)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Search Imported Projects")
        TextField("Filter by owner, repo name, workspace type, runner, or devcontainer", text: $model.localProjectSearch)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      BannerCard(
        title: model.localProjectSummary,
        detail: "\(model.localProjectStatus)\nCleanup targets from local library: \(model.selectedLocalProjectCount)",
        kind: model.localProjects.isEmpty ? .warning : .ready
      )

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.filteredLocalProjects.isEmpty {
            Text(model.localProjects.isEmpty ? "No imported local projects were found yet." : "No imported local projects match the current search.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 4)
          } else {
            ForEach(model.filteredLocalProjects) { project in
              LocalProjectRow(
                project: project,
                isTargeted: model.selectedRepos.contains(project.slug),
                isFavorite: model.favoriteProjects.contains(project.slug),
                toggleTarget: { model.toggleLocalProjectTarget(project) },
                toggleFavorite: { model.toggleFavorite(project) },
                openRuntime: { model.openLocalProject(project, preferRuntime: true) },
                openCode: { model.openLocalProject(project, preferRuntime: false) },
                reveal: { model.revealLocalProject(project) }
              )
            }
          }
        }
      }
      .frame(minHeight: 180, idealHeight: 260, maxHeight: 320)

      Text("This native library follows the active workspace setup, so you can search imported projects and jump straight into the code or runtime folder without leaving the app.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var liveServicesPanel: some View {
    PanelCard(title: "Live Local Services", subtitle: "Native view of active devcontainers and local runner services for the current workspace.") {
      HStack(spacing: 10) {
        Button(model.isLoadingLiveServices ? "Refreshing..." : "Refresh Live Services") {
          model.refreshLiveServices()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingLiveServices)

        Button("Open Advanced Tools") {
          selectedDestination = .workspace
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Open App Support") {
          model.openApplicationSupportFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      BannerCard(
        title: model.liveServiceSummary,
        detail: model.liveServicesStatus,
        kind: (model.activeContainers.isEmpty && model.runnerServices.isEmpty) ? .warning : .ready
      )

      if model.activeContainers.isEmpty && model.runnerServices.isEmpty {
        Text("No active devcontainers or configured runner services were detected for the current workspace yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        if !model.activeContainers.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "Active Devcontainers")

            ScrollView {
              LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(model.activeContainers) { container in
                  LiveContainerRow(
                    container: container,
                    openRuntime: { model.openContainerProject(container, preferRuntime: true) },
                    openCode: { model.openContainerProject(container, preferRuntime: false) },
                    reveal: { model.revealContainer(container) },
                    logs: { model.openContainerLogs(container) },
                    stop: { model.stopContainer(container) },
                    remove: { model.removeContainer(container) }
                  )
                }
              }
            }
            .frame(minHeight: 120, idealHeight: 180, maxHeight: 220)
          }
        }

        if !model.runnerServices.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "Local Runner Services")

            HStack(spacing: 10) {
              Button("Stop All Active Runners") {
                model.stopAllActiveRunnerServices()
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: false))

              Button("Refresh Services") {
                model.refreshLiveServices()
              }
              .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
            }

            ScrollView {
              LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(model.runnerServices) { runner in
                  RunnerServiceRow(
                    runner: runner,
                    openRuntime: { model.openRunnerProject(runner, preferRuntime: true) },
                    openCode: { model.openRunnerProject(runner, preferRuntime: false) },
                    reveal: { model.revealRunnerService(runner) },
                    start: { model.startRunnerService(runner) },
                    startOnly: { model.startOnlyRunnerService(runner) },
                    restart: { model.restartRunnerService(runner) },
                    verify: { model.verifyRunnerService(runner) },
                    stop: { model.stopRunnerService(runner) }
                  )
                }
              }
            }
            .frame(minHeight: 120, idealHeight: 180, maxHeight: 220)
          }
        }
      }

      Text("Use this page for the common local actions: inspect what is currently active, open the linked workspace, reveal it in Finder, or stop the container or runner without leaving the native app.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var repositoryPanel: some View {
    PanelCard(title: "Repository Targets", subtitle: "Browse repositories for the selected account or owner, then check one, many, or all.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Owner or Org to List")
        TextField("Defaults to the selected GitHub account", text: $model.repoOwner)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button(model.isLoadingRepos ? "Loading..." : "Load Repositories") {
          model.fetchAvailableRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingRepos || !model.isAuthenticated)

        Button("Clear All Targets") {
          model.selectedRepos.removeAll()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.selectedRepos.isEmpty)
      }

      Toggle(
        "Select all loaded repositories (\(model.availableRepos.count))",
        isOn: Binding(
          get: { model.areAllLoadedReposSelected },
          set: { model.setAllLoadedReposSelected($0) }
        )
      )
      .toggleStyle(.switch)
      .tint(DashboardTheme.success)
      .foregroundStyle(DashboardTheme.text)
      .disabled(model.availableRepos.isEmpty)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Search Loaded Repositories")
        TextField("Filter by owner, repo name, or visibility", text: $model.repoSearch)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
          .disabled(model.availableRepos.isEmpty)
      }

      BannerCard(
        title: model.selectedRepoSummary,
        detail: model.repoCatalogStatus,
        kind: model.cleanupTargets.isEmpty ? .warning : .ready
      )

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.filteredRepos.isEmpty {
            Text(model.availableRepos.isEmpty ? "No repositories loaded yet." : "No repositories match the current search.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 4)
          } else {
            ForEach(model.filteredRepos) { repo in
              RepoSelectionRow(
                repo: repo,
                isSelected: model.selectedRepos.contains(repo.nameWithOwner)
              ) {
                model.toggleRepoSelection(repo)
              }
            }
          }
        }
      }
      .frame(minHeight: 180, idealHeight: 260, maxHeight: 320)

      Divider().overlay(DashboardTheme.border)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Manual Repository or URL Fallback")
        TextField("OWNER/REPO or https://github.com/OWNER/REPO", text: $model.repoTarget)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      Text("If one or more repositories are checked above, the manual field is ignored. Use the manual field only when you want a one-off target that is not in the loaded list.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var importPanel: some View {
    PanelCard(title: "Import Mode", subtitle: "Choose how the selected repositories should be brought into the local workspace.") {
      Picker("Import Mode", selection: $model.importMode) {
        ForEach(ImportExecutionMode.allCases) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      BannerCard(
        title: model.importMode.label,
        detail: model.importMode.summary,
        kind: .ready
      )

      Toggle("Run cleanup preview after import", isOn: $model.importCleanupPreview)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.importMode == .repoToLocal)

      BannerCard(
        title: model.selectedRepoSummary,
        detail: model.importStatus,
        kind: model.cleanupTargets.isEmpty ? .warning : .ready
      )

      Text("Imports use the current Code, Import, and Runtime roots together: plain repo clones go to Code, staging and exported source drops go to Import, and runtime workspaces plus reports and runners stay under Runtime. The GUI path runs the bundled CLI in GUI-safe auto mode, so the work stays in Jobs and Output instead of opening Terminal.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var cleanupPanel: some View {
    PanelCard(title: "Cleanup Scope", subtitle: "Single control panel for actions, filters, and destructive state.") {
      Toggle("Full cleanup", isOn: $model.fullCleanup)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)

      Divider().overlay(DashboardTheme.border)

      Toggle("Disable workflows", isOn: $model.disableWorkflows)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete workflow runs", isOn: $model.deleteRuns)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete artifacts", isOn: $model.deleteArtifacts)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete caches", isOn: $model.deleteCaches)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete Codespaces", isOn: $model.deleteCodespaces)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)

      Divider().overlay(DashboardTheme.border)

      Toggle("Dry run only", isOn: $model.dryRun)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Specific Run ID or Run URL")
        TextField("Optional exact run target", text: $model.runTarget)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Run Filter")
        TextField("Optional run name filter", text: $model.runFilter)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }
    }
  }

  private var importExecutionPanel: some View {
    PanelCard(title: "Import Execution", subtitle: "Run imports in the background and keep the raw output visible in the native app.") {
      HStack(spacing: 10) {
        Button("Run Import") {
          model.runImport()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(!model.canRunImport)

        Button("Open Projects") {
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Clear Log") {
          model.logText = "[gui] \(appTitle) ready.\n"
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      if model.isRunning {
        Button("Cancel Active Run") {
          model.cancelRun()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      Text("Imports use your selected workspace, selected GitHub account, and the repositories checked in the repository panel. If no repositories are checked, the manual repository field is used instead.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var executionPanel: some View {
    VStack(alignment: .leading, spacing: 18) {
      SafetyCard(isArmed: $model.safetyArmEnabled, dryRun: model.dryRun)

      PanelCard(title: "Execution", subtitle: "The native app runs the bundled CSA-iEM CLI engine and keeps the raw terminal fallback available.", compact: true) {
        HStack(spacing: 10) {
          Button(model.dryRun ? "Preview Cleanup" : "Execute Cleanup") {
            model.runCleanup()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: false))
          .disabled(!model.canRunCleanup)

          Button("Open CLI") {
            model.openCLIInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Clear Log") {
            model.logText = "[gui] \(appTitle) ready.\n"
        }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        }

        if model.isRunning {
          Button("Cancel Active Run") {
            model.cancelRun()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        }

        Text(model.safetyArmEnabled ? "Safety arm is ON. Cleanup is unlocked for the selected target." : "Safety arm is OFF. Turn on the destructive cleanup switch before execution.")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(model.safetyArmEnabled ? DashboardTheme.success : DashboardTheme.warning)
      }
    }
  }

  private var libraryPanel: some View {
    PanelCard(title: "In-App Pages", subtitle: "Navigate to Help, Terms, Security, Brand, project notes, and About without leaving the app window.") {
      BannerCard(
        title: selectedDestination == .home ? "Home Active" : "\(selectedDestination.title) Active",
        detail: "Use the app menu to move between bundled pages. Documentation and product info now live inside the native interface instead of opening external markdown windows.",
        kind: .ready
      )

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
        ForEach(knowledgeDestinations + [.about]) { destination in
          DestinationShortcutTile(
            destination: destination,
            isSelected: selectedDestination == destination
          ) {
            selectedDestination = destination
          }
        }
      }

      Text("The app now uses a native multi-page menu system. Help, legal, security, brand, and project pages stay inside the product instead of opening external document windows.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private func logPanel(minHeight: CGFloat) -> some View {
    PanelCard(title: "Live Output", subtitle: "Readable, high-contrast CLI output streamed into the native app.") {
      LogConsoleView(text: model.logText)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: minHeight)
        .background(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(DashboardTheme.panelStrong)
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DashboardTheme.border, lineWidth: 1)
            )
        )
    }
  }
}

private struct ActivityStrip: View {
  let title: String
  let detail: String
  let isIndeterminate: Bool

  var body: some View {
    HStack(spacing: 12) {
      ProgressView()
        .controlSize(.small)
        .tint(DashboardTheme.link)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
        Text(detail)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      Text("In progress")
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.link)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(DashboardTheme.link.opacity(0.45), lineWidth: 1)
        )
    )
    .animation(.easeInOut(duration: 0.2), value: title)
  }
}

struct CSAiEMMenuBarView: View {
  @ObservedObject var model: CleanupViewModel

  private var roots: (codeRoot: String, importRoot: String, runtimeRoot: String) {
    model.profileRootSummary
  }

  private var runningRunnerCount: Int {
    model.runnerServices.filter(\.isRunning).count
  }

  private var primaryProjectLabel: String {
    model.primaryLocalProject?.slug ?? "No loaded repo"
  }

  private var primaryContainerLabel: String {
    model.primaryActiveContainer?.slug ?? "No active container"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "shippingbox.fill")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(DashboardTheme.success)
        VStack(alignment: .leading, spacing: 2) {
          Text("CSA-iEM Control")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
          Text("\(model.activeContainers.count) containers · \(runningRunnerCount)/\(model.runnerServices.count) runners")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
        }
        Spacer()
        Button {
          model.refreshOperatorState()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
        .help("Refresh workspace state")
      }

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("Loaded Repo")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
        Text(primaryProjectLabel)
          .font(.system(size: 13, weight: .semibold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
          .lineLimit(1)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          Button("VS Code") { model.openPrimaryLocalProject(preferRuntime: true, inApplication: "Visual Studio Code") }
            .disabled(model.primaryLocalProject == nil)
          Button("Codex") { model.openPrimaryLocalProject(preferRuntime: true, inApplication: "Codex") }
            .disabled(model.primaryLocalProject == nil)
          Button("GitHub Copilot") { model.openPrimaryLocalProject(preferRuntime: true, inApplication: "GitHub Copilot") }
            .disabled(model.primaryLocalProject == nil)
          Button("Finder") { model.revealPrimaryLocalProject() }
            .disabled(model.primaryLocalProject == nil)
          Button("CLI") { model.openCLIInTerminal() }
          Button("Browser") { model.openProjectBrowserInTerminal() }
        }
      }

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("Active Container")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
        Text(primaryContainerLabel)
          .font(.system(size: 13, weight: .semibold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
          .lineLimit(1)

        if let container = model.primaryActiveContainer {
          HStack(spacing: 8) {
            Button("Open") { model.openContainerProject(container, preferRuntime: true) }
            Button("Codex") { model.openContainerProject(container, preferRuntime: true, inApplication: "Codex") }
            Button("Logs") { model.openContainerLogs(container) }
            Button("Stop") { model.stopContainer(container) }
          }
        } else {
          Text("No running devcontainer was detected.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
        }
      }

      Divider()

      Menu("CODEX ~ GPT Stage 2") {
        Text("Source: \(model.stage2SourceRootDraft)")
        Text("Root: \(model.stage2ManagedRootDraft)")
        Divider()
        Button("Scan Stage 1 Projects") { model.scanStage2Projects() }
          .disabled(model.isCodexPortalBusy)
        Button("Preflight All") { model.runStage2PreflightAll() }
          .disabled(model.isCodexPortalBusy)
        Toggle("Arm Workspace Writes", isOn: $model.stage2SafetyArmed)
          .disabled(model.isCodexPortalBusy)
        Button("Stage 2 Full Auto") { model.runStage2FullAuto() }
          .disabled(!model.stage2SafetyArmed || model.isCodexPortalBusy)
        Divider()
        Button("Open Stage 1 Source") { model.revealStage2SourceRoot() }
        Button("Open Managed Root") { model.revealStage2ManagedRoot() }
      }

      Menu("CODEX ~ GPT Full Lifecycle") {
        Picker("Scope", selection: $model.codexLifecycleScope) {
          ForEach(CodexLifecycleScope.allCases) { scope in
            Text(scope.label).tag(scope)
          }
        }
        Toggle("Stage 1 ZIP", isOn: $model.codexCreateBackup)
        Toggle("Delete Stage 1 Originals", isOn: $model.codexLifecycleDeleteStage1Originals)
          .disabled(!model.codexTransferMode.writesDestination)
        Toggle("Run Stage 2", isOn: $model.codexLifecycleRunStage2)
        Toggle("Stage 2 ZIP", isOn: $model.stage2ArchiveSources)
          .disabled(!model.codexLifecycleRunStage2)
        Picker("Stage 2 Inputs", selection: $model.stage2SourceRetention) {
          ForEach(Stage2SourceRetention.allCases) { option in
            Text(option.label).tag(option)
          }
        }
        Picker("Stage 3 Cleanup", selection: $model.codexLifecycleCleanupScope) {
          ForEach(CodexLifecycleCleanupScope.allCases) { option in
            Text(option.label).tag(option)
          }
        }
        Divider()
        Button("Preflight Lifecycle") { model.preflightCodexLifecycle() }
          .disabled(model.isCodexPortalBusy)
        Button("Preflight Stage 3 Only") { model.runStage3Preflight() }
          .disabled(model.isCodexPortalBusy)
        Toggle("Arm Full Auto", isOn: $model.codexLifecycleSafetyArmed)
          .disabled(model.isCodexPortalBusy)
        Button("Run Full Auto") { model.runCodexLifecycle() }
          .disabled(!model.codexLifecycleSafetyArmed || model.isCodexPortalBusy)
        Button("Apply Stage 3 Only") { model.runStage3Cleanup() }
          .disabled(!model.codexLifecycleSafetyArmed || model.isCodexPortalBusy)
      }

      Divider()

      Menu("GitHub Action Runners") {
        if model.runnerServices.isEmpty {
          Text("No runner services detected")
        } else {
          Button("Stop All Active Runners") {
            model.stopAllActiveRunnerServices()
          }
          Divider()
          ForEach(model.runnerServices) { runner in
            Menu("\(runner.slug) (\(runner.statusLabel))") {
              Text(runner.runnerPath)
              Text("Service: \(runner.serviceLabel)")
              Divider()
              Button("Start Only This Runner") { model.startOnlyRunnerService(runner) }
              Button("Open in VS Code") { model.openRunnerProject(runner, preferRuntime: true) }
              Button("Open in Codex") { model.openRunnerProject(runner, preferRuntime: true, inApplication: "Codex") }
              Button("Reveal Runner Folder") { model.revealRunnerService(runner) }
              Divider()
              Button("Start Runner") { model.startRunnerService(runner) }
              Button("Stop Runner") { model.stopRunnerService(runner) }
              Button("Restart Runner") { model.restartRunnerService(runner) }
            }
          }
        }
      }

      Divider()

      Menu("GitHub Billing") {
        Text(model.githubBillingSummary.map { "\($0.owner): \($0.actionUsageLabel) Actions" } ?? "Usage report not loaded")
        Button("Load GitHub Usage") { model.loadGitHubBillingReport() }
          .disabled(model.isLoadingGitHubBilling || !model.isAuthenticated)
        Button("Open GitHub Billing Report") { model.openGitHubBillingReport() }
          .disabled(!model.isAuthenticated)
      }

      Menu("External Drives") {
        Button("Refresh Mounted Drives") { model.scanExternalVolumes() }
        if model.externalVolumes.isEmpty {
          Text("No external drives detected")
        } else {
          ForEach(model.externalVolumes) { volume in
            Menu("\(volume.name) · \(volume.capacityLabel)") {
              Text(volume.path)
              Button("Use for Backup or Move") { model.selectExternalVolume(volume) }
              Button("Use As Default Workspace") { model.setExternalVolumeAsDefault(volume) }
              Button("Prepare Move All To Default") { model.prepareExternalDefaultMove(volume) }
              Button("Open New Workspace") { model.revealExternalWorkspace(volume) }
              Button("Reveal Drive") { model.revealExternalVolume(volume) }
            }
          }
        }
      }

      Menu("Workspace Roots") {
        Text("Code: \(roots.codeRoot)")
        Text("Import: \(roots.importRoot)")
        Text("Runtime: \(roots.runtimeRoot)")
        Divider()
        Button("Reveal Code Root") { model.revealCodeRoot() }
        Button("Reveal Import Root") { model.revealImportRoot() }
        Button("Reveal Runtime Root") { model.revealRuntimeRoot() }
      }

      Button("Restore Internal Default Paths") { model.restoreInternalDefaultWorkspace() }

      HStack(spacing: 8) {
        Button("Open App") {
          NSApp.activate(ignoringOtherApps: true)
          NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        Button("Quit") {
          NSApp.terminate(nil)
        }
      }
    }
    .padding(14)
    .frame(width: 380)
  }
}

@main
struct CSAiEMMacApp: App {
  @NSApplicationDelegateAdaptor(CSAiEMAppDelegate.self) private var appDelegate
  @StateObject private var model = CleanupViewModel()

  var body: some Scene {
    WindowGroup(appTitle) {
      ContentView(model: model)
        .onAppear {
          appDelegate.attach(model: model)
        }
    }
    .commands {
      CommandGroup(replacing: .newItem) { }
    }
  }
}

@MainActor
final class CSAiEMAppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private weak var model: CleanupViewModel?

  func attach(model: CleanupViewModel) {
    self.model = model
    installStatusItemIfNeeded()
    rebuildStatusMenu()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
       let iconImage = NSImage(contentsOf: iconURL) {
      NSApplication.shared.applicationIconImage = iconImage
    }

    DispatchQueue.main.async {
      for window in NSApp.windows {
        self.configure(window)
      }
    }
  }

  private func installStatusItemIfNeeded() {
    guard statusItem == nil else { return }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.title = "CSA-iEM"
    item.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "CSA-iEM")
    item.button?.imagePosition = .imageLeading
    statusItem = item
  }

  private func rebuildStatusMenu() {
    guard let model, let statusItem else { return }

    let roots = model.profileRootSummary
    let runningRunners = model.runnerServices.filter(\.isRunning).count
    let menu = NSMenu()

    menu.addItem(disabledItem("Loaded Workspace"))
    menu.addItem(disabledItem("Code: \(roots.codeRoot)"))
    menu.addItem(disabledItem("Import: \(roots.importRoot)"))
    menu.addItem(disabledItem("Runtime: \(roots.runtimeRoot)"))
    menu.addItem(.separator())
    menu.addItem(disabledItem("\(model.activeContainers.count) active devcontainers · \(runningRunners)/\(model.runnerServices.count) runners running"))

    menu.addItem(actionItem("Open CSA-iEM App", action: #selector(openMainWindow)))
    menu.addItem(actionItem("Open CSA-iEM CLI", action: #selector(openCLI)))
    menu.addItem(actionItem("Open Project Browser", action: #selector(openProjectBrowser)))
    menu.addItem(actionItem("Refresh Workspace State", action: #selector(refreshWorkspaceState)))

    let stage2Menu = NSMenu()
    stage2Menu.addItem(disabledItem("Source: \(model.stage2SourceRootDraft)"))
    stage2Menu.addItem(disabledItem("Root: \(model.stage2ManagedRootDraft)"))
    stage2Menu.addItem(.separator())
    let scanStage2Item = actionItem("Scan Stage 1 Projects", action: #selector(scanStage2Projects))
    scanStage2Item.isEnabled = !model.isCodexPortalBusy
    stage2Menu.addItem(scanStage2Item)
    let preflightStage2Item = actionItem("Preflight All", action: #selector(preflightStage2All))
    preflightStage2Item.isEnabled = !model.isCodexPortalBusy
    stage2Menu.addItem(preflightStage2Item)
    let runStage2Item = actionItem("Stage 2 Full Auto", action: #selector(runStage2FullAuto))
    runStage2Item.isEnabled = model.stage2SafetyArmed && !model.isCodexPortalBusy
    stage2Menu.addItem(runStage2Item)
    stage2Menu.addItem(.separator())
    stage2Menu.addItem(actionItem("Open Stage 1 Source", action: #selector(revealStage2Source)))
    stage2Menu.addItem(actionItem("Open Managed Root", action: #selector(revealStage2Root)))
    let stage2Item = NSMenuItem(title: "CODEX ~ GPT Stage 2", action: nil, keyEquivalent: "")
    stage2Item.submenu = stage2Menu
    menu.addItem(stage2Item)

    let lifecycleMenu = NSMenu()
    lifecycleMenu.addItem(disabledItem("Scope: \(model.codexLifecycleScope.label)"))
    lifecycleMenu.addItem(disabledItem("Stage 2 inputs: \(model.stage2SourceRetention.label)"))
    lifecycleMenu.addItem(disabledItem("Stage 3: \(model.codexLifecycleCleanupScope.label)"))
    lifecycleMenu.addItem(.separator())
    let preflightLifecycleItem = actionItem("Preflight Full Lifecycle", action: #selector(preflightFullLifecycle))
    preflightLifecycleItem.isEnabled = !model.isCodexPortalBusy
    lifecycleMenu.addItem(preflightLifecycleItem)
    let preflightStage3Item = actionItem("Preflight Stage 3 Only", action: #selector(preflightStage3Only))
    preflightStage3Item.isEnabled = !model.isCodexPortalBusy
    lifecycleMenu.addItem(preflightStage3Item)
    let runLifecycleItem = actionItem("Run Armed Full Auto", action: #selector(runFullLifecycle))
    runLifecycleItem.isEnabled = model.codexLifecycleSafetyArmed && !model.isCodexPortalBusy
    lifecycleMenu.addItem(runLifecycleItem)
    let runStage3Item = actionItem("Apply Armed Stage 3 Only", action: #selector(runStage3Only))
    runStage3Item.isEnabled = model.codexLifecycleSafetyArmed && !model.isCodexPortalBusy
    lifecycleMenu.addItem(runStage3Item)
    lifecycleMenu.addItem(actionItem("Open App to Change Options", action: #selector(openMainWindow)))
    let lifecycleItem = NSMenuItem(title: "CODEX ~ GPT Full Lifecycle", action: nil, keyEquivalent: "")
    lifecycleItem.submenu = lifecycleMenu
    menu.addItem(lifecycleItem)

    let rootsMenu = NSMenu()
    rootsMenu.addItem(actionItem("Reveal Code Root", action: #selector(revealCodeRoot)))
    rootsMenu.addItem(actionItem("Reveal Import Root", action: #selector(revealImportRoot)))
    rootsMenu.addItem(actionItem("Reveal Runtime Root", action: #selector(revealRuntimeRoot)))
    let rootsItem = NSMenuItem(title: "Workspace Roots", action: nil, keyEquivalent: "")
    rootsItem.submenu = rootsMenu
    menu.addItem(rootsItem)

    let runnersMenu = NSMenu()
    if model.runnerServices.isEmpty {
      runnersMenu.addItem(disabledItem("No runner services detected"))
    } else {
      runnersMenu.addItem(actionItem("Stop All Active Runners", action: #selector(stopAllRunners)))
      runnersMenu.addItem(.separator())
      for runner in model.runnerServices {
        let runnerMenu = NSMenu()
        let status = runner.isRunning ? "running" : "stopped"
        runnerMenu.addItem(disabledItem(runner.runnerPath))
        runnerMenu.addItem(disabledItem("Service: \(runner.serviceLabel) · \(status)"))
        runnerMenu.addItem(runnerActionItem("Open Workspace", action: #selector(openRunnerWorkspace(_:)), runner: runner))
        runnerMenu.addItem(runnerActionItem("Reveal Runner Folder", action: #selector(revealRunner(_:)), runner: runner))
        runnerMenu.addItem(.separator())
        runnerMenu.addItem(runnerActionItem("Start Runner", action: #selector(startRunner(_:)), runner: runner))
        runnerMenu.addItem(runnerActionItem("Stop Runner", action: #selector(stopRunner(_:)), runner: runner))
        runnerMenu.addItem(runnerActionItem("Restart Runner", action: #selector(restartRunner(_:)), runner: runner))

        let item = NSMenuItem(title: "\(runner.slug) (\(status))", action: nil, keyEquivalent: "")
        item.submenu = runnerMenu
        runnersMenu.addItem(item)
      }
    }
    let runnersItem = NSMenuItem(title: "GitHub Action Runners", action: nil, keyEquivalent: "")
    runnersItem.submenu = runnersMenu
    menu.addItem(runnersItem)

    let billingMenu = NSMenu()
    billingMenu.addItem(disabledItem(model.githubBillingSummary.map { "\($0.owner): \($0.actionUsageLabel) Actions" } ?? "Usage report not loaded"))
    billingMenu.addItem(actionItem("Load GitHub Usage", action: #selector(loadGitHubBilling)))
    billingMenu.addItem(actionItem("Open GitHub Billing Report", action: #selector(openGitHubBilling)))
    let billingItem = NSMenuItem(title: "GitHub Billing", action: nil, keyEquivalent: "")
    billingItem.submenu = billingMenu
    menu.addItem(billingItem)

    let drivesMenu = NSMenu()
    drivesMenu.addItem(actionItem("Refresh Mounted Drives", action: #selector(refreshExternalDrives)))
    if model.externalVolumes.isEmpty {
      drivesMenu.addItem(disabledItem("No external drives detected"))
    } else {
      for volume in model.externalVolumes {
        let volumeMenu = NSMenu()
        volumeMenu.addItem(disabledItem(volume.path))
        volumeMenu.addItem(disabledItem(volume.capacityLabel))
        volumeMenu.addItem(volumeActionItem("Use for Backup or Move", action: #selector(selectExternalDrive(_:)), volume: volume))
        volumeMenu.addItem(volumeActionItem("Use As Default Workspace", action: #selector(setExternalDriveAsDefault(_:)), volume: volume))
        volumeMenu.addItem(volumeActionItem("Prepare Move All To Default", action: #selector(prepareExternalDefaultMove(_:)), volume: volume))
        volumeMenu.addItem(volumeActionItem("Open New Workspace", action: #selector(revealExternalWorkspace(_:)), volume: volume))
        volumeMenu.addItem(volumeActionItem("Reveal Drive", action: #selector(revealExternalDrive(_:)), volume: volume))
        let item = NSMenuItem(title: volume.name, action: nil, keyEquivalent: "")
        item.submenu = volumeMenu
        drivesMenu.addItem(item)
      }
    }
    let drivesItem = NSMenuItem(title: "External Drives", action: nil, keyEquivalent: "")
    drivesItem.submenu = drivesMenu
    menu.addItem(drivesItem)
    menu.addItem(actionItem("Restore Internal Default Paths", action: #selector(restoreInternalDefaultPaths)))

    menu.addItem(.separator())
    menu.addItem(actionItem("Quit CSA-iEM", action: #selector(quitApp)))
    statusItem.menu = menu
  }

  private func scheduleMenuRebuild(after delay: TimeInterval = 1.5) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.rebuildStatusMenu()
    }
  }

  private func disabledItem(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }

  private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  private func runnerActionItem(_ title: String, action: Selector, runner: RunnerServiceEntry) -> NSMenuItem {
    let item = actionItem(title, action: action)
    item.representedObject = runner
    return item
  }

  private func volumeActionItem(_ title: String, action: Selector, volume: ExternalVolumeEntry) -> NSMenuItem {
    let item = actionItem(title, action: action)
    item.representedObject = volume
    return item
  }

  @objc private func openMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first {
      window.makeKeyAndOrderFront(nil)
    }
  }

  @objc private func openCLI() {
    model?.openCLIInTerminal()
  }

  @objc private func openProjectBrowser() {
    model?.openProjectBrowserInTerminal()
  }

  @objc private func refreshWorkspaceState() {
    model?.refreshOperatorState()
    rebuildStatusMenu()
    scheduleMenuRebuild()
  }

  @objc private func scanStage2Projects() {
    model?.scanStage2Projects()
  }

  @objc private func preflightStage2All() {
    model?.runStage2PreflightAll()
  }

  @objc private func runStage2FullAuto() {
    guard let model else { return }
    if !model.stage2SafetyArmed {
      model.stage2Status = "Open the CODEX ~ GPT Portal, review Stage 2 paths and options, then arm workspace writes before Full Auto."
      openMainWindow()
      return
    }
    model.runStage2FullAuto()
  }

  @objc private func preflightFullLifecycle() {
    model?.preflightCodexLifecycle()
  }

  @objc private func runFullLifecycle() {
    guard let model else { return }
    if !model.codexLifecycleSafetyArmed {
      model.codexLifecycleStatus = "Open the CODEX ~ GPT Portal, review every lifecycle option, then arm Full Auto."
      openMainWindow()
      return
    }
    model.runCodexLifecycle()
  }

  @objc private func preflightStage3Only() {
    model?.runStage3Preflight()
  }

  @objc private func runStage3Only() {
    guard let model else { return }
    if !model.codexLifecycleSafetyArmed {
      model.codexLifecycleStatus = "Open the CODEX ~ GPT Portal, review Stage 3 cleanup options, then arm Full Auto."
      openMainWindow()
      return
    }
    model.runStage3Cleanup()
  }

  @objc private func revealStage2Source() {
    model?.revealStage2SourceRoot()
  }

  @objc private func revealStage2Root() {
    model?.revealStage2ManagedRoot()
  }

  @objc private func revealCodeRoot() {
    model?.revealCodeRoot()
  }

  @objc private func revealImportRoot() {
    model?.revealImportRoot()
  }

  @objc private func revealRuntimeRoot() {
    model?.revealRuntimeRoot()
  }

  @objc private func openRunnerWorkspace(_ sender: NSMenuItem) {
    guard let runner = sender.representedObject as? RunnerServiceEntry else { return }
    model?.openRunnerProject(runner, preferRuntime: true)
  }

  @objc private func revealRunner(_ sender: NSMenuItem) {
    guard let runner = sender.representedObject as? RunnerServiceEntry else { return }
    model?.revealRunnerService(runner)
  }

  @objc private func startRunner(_ sender: NSMenuItem) {
    guard let runner = sender.representedObject as? RunnerServiceEntry else { return }
    model?.startRunnerService(runner)
    scheduleMenuRebuild()
  }

  @objc private func stopRunner(_ sender: NSMenuItem) {
    guard let runner = sender.representedObject as? RunnerServiceEntry else { return }
    model?.stopRunnerService(runner)
    scheduleMenuRebuild()
  }

  @objc private func restartRunner(_ sender: NSMenuItem) {
    guard let runner = sender.representedObject as? RunnerServiceEntry else { return }
    model?.restartRunnerService(runner)
    scheduleMenuRebuild(after: 2.5)
  }

  @objc private func stopAllRunners() {
    model?.stopAllActiveRunnerServices()
    scheduleMenuRebuild(after: 2.5)
  }

  @objc private func loadGitHubBilling() {
    model?.loadGitHubBillingReport()
    scheduleMenuRebuild(after: 2.5)
  }

  @objc private func openGitHubBilling() {
    model?.openGitHubBillingReport()
  }

  @objc private func refreshExternalDrives() {
    model?.scanExternalVolumes()
    rebuildStatusMenu()
  }

  @objc private func selectExternalDrive(_ sender: NSMenuItem) {
    guard let volume = sender.representedObject as? ExternalVolumeEntry else { return }
    model?.selectExternalVolume(volume)
  }

  @objc private func setExternalDriveAsDefault(_ sender: NSMenuItem) {
    guard let volume = sender.representedObject as? ExternalVolumeEntry else { return }
    model?.setExternalVolumeAsDefault(volume)
    scheduleMenuRebuild()
  }

  @objc private func prepareExternalDefaultMove(_ sender: NSMenuItem) {
    guard let volume = sender.representedObject as? ExternalVolumeEntry else { return }
    model?.prepareExternalDefaultMove(volume)
  }

  @objc private func revealExternalWorkspace(_ sender: NSMenuItem) {
    guard let volume = sender.representedObject as? ExternalVolumeEntry else { return }
    model?.revealExternalWorkspace(volume)
  }

  @objc private func restoreInternalDefaultPaths() {
    model?.restoreInternalDefaultWorkspace()
    scheduleMenuRebuild()
  }

  @objc private func revealExternalDrive(_ sender: NSMenuItem) {
    guard let volume = sender.representedObject as? ExternalVolumeEntry else { return }
    model?.revealExternalVolume(volume)
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  private func configure(_ window: NSWindow) {
    let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1600, height: 920)
    let targetSize = idealWindowSize(for: visibleFrame.size)
    let targetOrigin = NSPoint(
      x: visibleFrame.origin.x + ((visibleFrame.width - targetSize.width) / 2),
      y: visibleFrame.origin.y + ((visibleFrame.height - targetSize.height) / 2)
    )

    window.minSize = NSSize(width: 760, height: 640)
    window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: true)
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.toolbarStyle = .unified
    window.backgroundColor = NSColor(calibratedRed: 9 / 255, green: 21 / 255, blue: 38 / 255, alpha: 1)
    window.isMovableByWindowBackground = false
    window.tabbingMode = .disallowed
  }

  private func idealWindowSize(for screenSize: NSSize) -> NSSize {
    let widthRatio: CGFloat
    let heightRatio: CGFloat

    switch screenSize.width {
    case ..<900:
      widthRatio = 0.98
      heightRatio = 0.94
    case ..<1280:
      widthRatio = 0.96
      heightRatio = 0.92
    case ..<1800:
      widthRatio = 0.92
      heightRatio = 0.90
    case ..<2600:
      widthRatio = 0.90
      heightRatio = 0.90
    default:
      widthRatio = 0.88
      heightRatio = 0.90
    }

    let width = min(max(screenSize.width * widthRatio, 760), 3200)
    let height = min(max(screenSize.height * heightRatio, 640), 1440)
    return NSSize(width: width, height: height)
  }
}
