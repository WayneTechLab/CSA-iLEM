import CryptoKit
import Darwin
import Foundation

struct CheckoutManifestEntry: Codable, Equatable, Sendable {
  let kind: String
  let mode: UInt32
  let mtimeNanoseconds: Int64
  let flags: UInt32
  let size: Int64
  let sha256: String?
  let gitBlobSHA1: String?
  let linkTarget: String?
  let xattrs: [String: String]
}

struct CheckoutFileInventory: Codable, Equatable, Sendable {
  let rootDevice: Int64
  let rootInode: UInt64
  let rootMode: UInt32
  let rootMtimeNanoseconds: Int64
  let rootFlags: UInt32
  let rootXattrs: [String: String]
  let entries: [String: CheckoutManifestEntry]
  let fileCount: Int
  let directoryCount: Int
  let symlinkCount: Int
  let totalBytes: Int64
  let manifestDigest: String
}

struct CheckoutGitEvidence: Codable, Sendable {
  let origin: CheckoutRemoteIdentity?
  let branch: String?
  let head: String?
  let commonDirectory: String?
  let trackedChanges: Int
  let untrackedFiles: Int
  let visiblePaths: [String]
}

struct CheckoutGitHubEvidence: Codable, Sendable {
  let repositoryID: Int64
  let fullName: String
  let browserURL: String
  let defaultBranch: String
  let head: String
  let treeFileCount: Int
  let matchingFiles: Int
  let differentPaths: [String]
  let missingPaths: [String]
  let localOnlyPaths: [String]
  let historyStatus: String
}

struct CheckoutSnapshot: Codable, Sendable {
  let path: String
  let inventory: CheckoutFileInventory
  let git: CheckoutGitEvidence
  let github: CheckoutGitHubEvidence?
  let errors: [String]
  var rootDevice: Int64 { inventory.rootDevice }
  var rootInode: UInt64 { inventory.rootInode }
  var fileCount: Int { inventory.fileCount }
  var directoryCount: Int { inventory.directoryCount }
  var symlinkCount: Int { inventory.symlinkCount }
  var totalBytes: Int64 { inventory.totalBytes }
  var manifestDigest: String { inventory.manifestDigest }
}

struct CheckoutPairDelta: Codable, Sendable {
  let identicalFiles: Int
  let differentPaths: [String]
  let firstOnlyPaths: [String]
  let secondOnlyPaths: [String]
}

struct CheckoutPairReview: Codable, Identifiable, Sendable {
  let id: String
  let createdAt: Date
  let first: CheckoutSnapshot
  let second: CheckoutSnapshot
  let delta: CheckoutPairDelta
  let evidencePath: String
  let blockers: [String]
  var canRetire: Bool { blockers.isEmpty }
}

struct CheckoutRetirementReceipt: Codable, Identifiable, Sendable {
  let id: String
  let createdAt: Date
  let originalPath: String
  let archivePath: String
  let keptPath: String
  let receiptPath: String
  let reviewEvidencePath: String
  let inventory: CheckoutFileInventory
  var fileCount: Int { inventory.fileCount }
  var directoryCount: Int { inventory.directoryCount }
  var symlinkCount: Int { inventory.symlinkCount }
  var totalBytes: Int64 { inventory.totalBytes }
  var manifestDigest: String { inventory.manifestDigest }
}

struct CheckoutRestoreReceipt: Codable, Sendable {
  let originalPath: String
  let archivePath: String
  let receiptPath: String
  let retirementReceiptPath: String
  let restoredAt: Date
}

/// Explicit checkout review and reversible retirement. No fetch, reset, pull,
/// checkout, package hook, provider mutation, or permanent deletion is used.
enum CheckoutPairReviewEngine {
  private static func failure(_ detail: String) -> NSError {
    NSError(domain: "CSA-iEM.CheckoutReview", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
  }

  static func review(
    firstPath: String, secondPath: String, ghExecutable: String?,
    environment: [String: String], evidenceRoot: String, protectedRootPaths: [String]
  ) throws -> CheckoutPairReview {
    let firstPath = try explicitDirectory(firstPath)
    let secondPath = try explicitDirectory(secondPath)
    try validatePair(firstPath, secondPath, protectedRootPaths: protectedRootPaths)
    let evidenceBase = try physicalFutureDirectory(evidenceRoot)
    guard !isWithin(evidenceBase, firstPath), !isWithin(evidenceBase, secondPath) else {
      throw failure("Review evidence must be saved outside both checkout folders.")
    }
    let first = try snapshot(firstPath, ghExecutable: ghExecutable, environment: environment)
    let second = try snapshot(secondPath, ghExecutable: ghExecutable, environment: environment)
    var blockers = first.errors + second.errors
    if first.rootDevice == second.rootDevice && first.rootInode == second.rootInode {
      blockers.append("Both paths identify the same physical directory.")
    }
    if let common = first.git.commonDirectory, common == second.git.commonDirectory {
      blockers.append("These checkouts share Git storage and may be intentional linked worktrees.")
    }
    if first.github == nil || second.github == nil {
      blockers.append("Live GitHub repository evidence is required for both checkouts before retirement.")
    }
    let a = first.inventory.entries, b = second.inventory.entries
    let common = Set(a.keys).intersection(b.keys)
    let different = common.filter { !sameContent(a[$0]!, b[$0]!) }.sorted()
    let identicalFiles = common.filter { a[$0]!.kind == "file" && sameContent(a[$0]!, b[$0]!) }.count
    let id = UUID().uuidString
    let directory = URL(fileURLWithPath: evidenceBase).appendingPathComponent(id, isDirectory: true)
    try privateDirectory(directory)
    let result = CheckoutPairReview(
      id: id, createdAt: Date(), first: first, second: second,
      delta: CheckoutPairDelta(identicalFiles: identicalFiles, differentPaths: different,
        firstOnlyPaths: Set(a.keys).subtracting(b.keys).sorted(), secondOnlyPaths: Set(b.keys).subtracting(a.keys).sorted()),
      evidencePath: directory.appendingPathComponent("review.json").path,
      blockers: Array(Set(blockers)).sorted()
    )
    try save(result, to: result.evidencePath)
    return result
  }

  static func retire(
    review: CheckoutPairReview, keepingPath: String, retiringPath: String,
    recoveryRoot: String, protectedRootPaths: [String], environment: [String: String]
  ) throws -> CheckoutRetirementReceipt {
    let reviewAge = Date().timeIntervalSince(review.createdAt)
    guard review.canRetire, reviewAge >= 0, reviewAge < 1_800 else {
      throw failure("A fresh, unblocked pair review is required before retiring a checkout.")
    }
    let keep = try explicitDirectory(keepingPath), source = try explicitDirectory(retiringPath)
    try validatePair(keep, source, protectedRootPaths: protectedRootPaths)
    guard Set([keep, source]) == Set([review.first.path, review.second.path]) else {
      throw failure("The selected keeper and retirement source do not match this review.")
    }
    let selected = source == review.first.path ? review.first : review.second
    let keeper = keep == review.first.path ? review.first : review.second
    let fresh = try inventory(path: source)
    guard fresh == selected.inventory else { throw failure("The retirement source changed after review. Review it again; all files remain in place.") }
    let keepInfo = try directoryStatus(keep)
    guard Int64(keepInfo.st_dev) == keeper.rootDevice, UInt64(keepInfo.st_ino) == keeper.rootInode else {
      throw failure("The keeper directory changed after review.")
    }
    try ensureInactive(source, environment: environment)
    let recovery = URL(fileURLWithPath: try physicalFutureDirectory(recoveryRoot), isDirectory: true)
    guard !isWithin(recovery.path, source), !isWithin(recovery.path, keep) else {
      throw failure("The recovery folder must be outside both reviewed checkouts.")
    }
    try privateDirectory(recovery)
    let recoveryInfo = try directoryStatus(recovery.path)
    guard Int64(recoveryInfo.st_dev) == fresh.rootDevice else {
      throw failure("Reversible retirement requires a recovery folder on the same volume.")
    }
    let id = UUID().uuidString
    let container = recovery.appendingPathComponent(id, isDirectory: true)
    try privateDirectory(container)
    let archive = container.appendingPathComponent((source as NSString).lastPathComponent, isDirectory: true)
    let receipt = CheckoutRetirementReceipt(id: id, createdAt: Date(), originalPath: source,
      archivePath: archive.path, keptPath: keep, receiptPath: container.appendingPathComponent("retirement.json").path,
      reviewEvidencePath: review.evidencePath, inventory: fresh)
    try save(receipt, to: container.appendingPathComponent("retirement-prepared.json").path)
    guard !existsNoFollow(archive.path) else { throw failure("The recovery destination already exists.") }
    // rename preserves all payloads, Git metadata, resource forks, and xattrs.
    guard renameExclusive(source, archive.path) == 0 else { throw posixFailure("Could not retire checkout") }
    do {
      if environment["CSA_IEM_TEST_FAIL_CHECKOUT_ARCHIVE_AFTER_RENAME"] == "1" {
        throw failure("Injected post-retirement verification failure.")
      }
      guard !existsNoFollow(source), try inventory(path: archive.path) == fresh else {
        throw failure("Recovery read-back did not match the reviewed source.")
      }
      try save(receipt, to: receipt.receiptPath)
      return receipt
    } catch {
      if !existsNoFollow(source), renameExclusive(archive.path, source) == 0 { throw error }
      throw failure("Retirement verification stopped. Files remain preserved at \(archive.path). The original path could not be restored: \(error.localizedDescription)")
    }
  }

  static func restore(
    receipt: CheckoutRetirementReceipt, protectedRootPaths: [String], environment: [String: String], inventoryMaxDuration: TimeInterval = 60
  ) throws -> CheckoutRestoreReceipt {
    let archive = try explicitDirectory(receipt.archivePath)
    guard archive == receipt.archivePath else { throw failure("The recovery path's physical parents changed. Inspect the preserved checkout before restoration.") }
    let storedOriginal = try absolutePath(receipt.originalPath)
    let original = try physicalFutureDirectory(storedOriginal)
    guard original == storedOriginal else { throw failure("The original path's physical parents changed; restoration is blocked.") }
    try validateProtected(original, protectedRootPaths: protectedRootPaths)
    guard !existsNoFollow(original) else { throw failure("Restore is blocked because the original path is already occupied.") }
    guard !isWithin(original, archive), !isWithin(archive, original) else { throw failure("Restore paths overlap.") }
    let keeper = URL(fileURLWithPath: receipt.keptPath).resolvingSymlinksInPath().path
    guard !isWithin(original, keeper), !isWithin(keeper, original) else { throw failure("Restoration would overlap the preserved keeper checkout.") }
    let current = try inventory(path: archive, maxDuration: inventoryMaxDuration)
    guard current == receipt.inventory else { throw failure("The preserved checkout changed. Inspect it before restoration.") }
    try ensureInactive(archive, environment: environment)
    let parentInfo = try directoryStatus((original as NSString).deletingLastPathComponent)
    guard Int64(parentInfo.st_dev) == current.rootDevice else { throw failure("Restore requires the original volume.") }
    if environment["CSA_IEM_TEST_OCCUPY_CHECKOUT_RESTORE_DESTINATION"] == "1" {
      try FileManager.default.createDirectory(atPath: original, withIntermediateDirectories: false)
    }
    guard renameExclusive(archive, original) == 0 else { throw posixFailure("Could not restore checkout; the preserved source remains in recovery") }
    do {
      guard try inventory(path: original, maxDuration: inventoryMaxDuration) == current else { throw failure("Restored checkout failed read-back verification.") }
      let result = CheckoutRestoreReceipt(originalPath: original, archivePath: archive,
        receiptPath: (receipt.receiptPath as NSString).deletingLastPathComponent + "/restoration.json",
        retirementReceiptPath: receipt.receiptPath, restoredAt: Date())
      try save(result, to: result.receiptPath)
      return result
    } catch {
      if !existsNoFollow(archive), renameExclusive(original, archive) == 0 { throw error }
      throw failure("Restore verification stopped. Files remain at \(original): \(error.localizedDescription)")
    }
  }

  static func inventory(path: String, maxDuration: TimeInterval = 60) throws -> CheckoutFileInventory {
    let path = try explicitDirectory(path)
    var builder = InventoryBuilder(root: path, maxDuration: min(300, max(0, maxDuration)))
    return try builder.run()
  }

  private static func snapshot(_ path: String, ghExecutable: String?, environment: [String: String]) throws -> CheckoutSnapshot {
    let inventory = try inventory(path: path)
    let git = try gitEvidence(path, environment: environment)
    var errors: [String] = []
    var provider: CheckoutGitHubEvidence?
    if let ghExecutable, let origin = git.origin {
      do { provider = try githubEvidence(origin, git: git, inventory: inventory, gh: ghExecutable, environment: environment) }
      catch { errors.append("GitHub verification for \((path as NSString).lastPathComponent): \(error.localizedDescription)") }
    } else { errors.append("A recognized Git origin and the authenticated GitHub CLI are required for \((path as NSString).lastPathComponent).") }
    return CheckoutSnapshot(path: path, inventory: inventory, git: git, github: provider, errors: errors)
  }

  private static func gitEvidence(_ path: String, environment: [String: String]) throws -> CheckoutGitEvidence {
    var env = environment
    env["GIT_OPTIONAL_LOCKS"] = "0"; env["GIT_NO_LAZY_FETCH"] = "1"
    let baseArguments = ["-c", "core.fsmonitor=false", "-c", "core.untrackedCache=false", "-c", "core.hooksPath=/dev/null", "-c", "diff.external=", "-C", path]
    // status can invoke clean/process drivers from .gitattributes. Discover
    // configured driver names without executing them, then disable all drivers.
    let filters = try run("/usr/bin/git", baseArguments + ["config", "--name-only", "--get-regexp", "^filter\\..*\\.(clean|process|required)$"], environment: env)
    guard filters.code == 0 || filters.code == 1 else { throw failure("Git filter configuration could not be inspected safely.") }
    var driverPrefixes = Set<String>()
    for key in filters.text.split(whereSeparator: \.isNewline).map(String.init) {
      guard key.range(of: "^filter\\.[A-Za-z0-9._-]+\\.(clean|process|required)$", options: .regularExpression) != nil,
            let separator = key.lastIndex(of: ".") else { throw failure("An unusual Git filter name requires manual inspection before checkout review.") }
      driverPrefixes.insert(String(key[..<separator]))
    }
    let disabledFilters = driverPrefixes.sorted().flatMap { ["-c", $0 + ".clean=", "-c", $0 + ".process=", "-c", $0 + ".required=false"] }
    func git(_ args: [String]) throws -> CommandResult {
      try run("/usr/bin/git", baseArguments + disabledFilters + args, environment: env)
    }
    guard try git(["rev-parse", "--is-inside-work-tree"]).text.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
      throw failure("The selected folder is not a Git checkout: \(path)")
    }
    let topLevel = try git(["rev-parse", "--show-toplevel"])
    let topLevelPath = topLevel.text.trimmingCharacters(in: .newlines)
    guard topLevel.code == 0,
          URL(fileURLWithPath: topLevelPath).resolvingSymlinksInPath().path == path else {
      throw failure("Select the actual Git checkout root, not a subfolder inheriting its parent's repository identity.")
    }
    let rawOrigin = try git(["config", "--get", "remote.origin.url"])
    let branchResult = try git(["symbolic-ref", "--quiet", "--short", "HEAD"])
    let headResult = try git(["rev-parse", "--verify", "--quiet", "HEAD"])
    let common = try git(["rev-parse", "--path-format=absolute", "--git-common-dir"])
    let status = try git(["status", "--porcelain=v1", "-z", "--untracked-files=all", "--ignore-submodules=all"])
    let visible = try git(["ls-files", "--cached", "--others", "--exclude-standard", "-z"])
    guard status.code == 0, common.code == 0, visible.code == 0 else { throw failure("Git status or worktree storage could not be verified: \(path)") }
    let records = status.text.split(separator: "\0", omittingEmptySubsequences: true)
    var tracked = 0, untracked = 0, index = 0
    while index < records.count {
      let prefix = String(records[index].prefix(2))
      if prefix == "??" { untracked += 1 } else { tracked += 1 }
      if prefix.contains("R") || prefix.contains("C") { index += 1 }
      index += 1
    }
    func trimmed(_ result: CommandResult) -> String? {
      let value = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
      return result.code == 0 && !value.isEmpty ? value : nil
    }
    return CheckoutGitEvidence(origin: CheckoutRemoteIdentity.parse(trimmed(rawOrigin)), branch: trimmed(branchResult),
      head: trimmed(headResult), commonDirectory: trimmed(common).map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }, trackedChanges: tracked, untrackedFiles: untracked,
      visiblePaths: Array(Set(visible.text.split(separator: "\0").map(String.init))).sorted())
  }

  private struct ProviderRepository: Decodable { let id: Int64; let full_name: String; let html_url: String; let default_branch: String }
  private struct ProviderCommit: Decodable { let sha: String }
  private struct ProviderTree: Decodable {
    struct Item: Decodable { let path: String; let type: String; let mode: String; let sha: String }
    let truncated: Bool
    let tree: [Item]
  }
  private static func githubEvidence(_ origin: CheckoutRemoteIdentity, git: CheckoutGitEvidence, inventory: CheckoutFileInventory, gh: String, environment: [String: String]) throws -> CheckoutGitHubEvidence {
    guard origin.host == "github.com" else {
      throw failure("Live provider reads are limited to github.com. This origin requires separate host verification.")
    }
    func api(_ endpoint: String) throws -> CommandResult { try run(gh, ["api", "--hostname", origin.host, endpoint], environment: environment, timeout: 20) }
    func decode<T: Decodable>(_ type: T.Type, _ endpoint: String) throws -> T {
      let result = try api(endpoint)
      guard result.code == 0 else { throw failure("GitHub read failed (exit \(result.code)); repository access or identity could not be verified.") }
      return try JSONDecoder().decode(type, from: result.data)
    }
    let endpoint = "repos/\(origin.owner)/\(origin.repository)"
    let repository = try decode(ProviderRepository.self, endpoint)
    guard repository.id > 0, let canonical = CheckoutRemoteIdentity.parse(repository.html_url),
          canonical.host == origin.host, repository.full_name.lowercased() == "\(canonical.owner)/\(canonical.repository)".lowercased(),
          !repository.default_branch.isEmpty else { throw failure("GitHub returned inconsistent repository identity.") }
    let branch = repository.default_branch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))) ?? ""
    guard !branch.isEmpty else { throw failure("The GitHub default branch could not be encoded safely.") }
    let commit = try decode(ProviderCommit.self, endpoint + "/commits/" + branch)
    guard commit.sha.range(of: "^[0-9a-fA-F]{40,64}$", options: .regularExpression) != nil else { throw failure("GitHub returned an invalid commit identifier.") }
    let tree = try decode(ProviderTree.self, endpoint + "/git/trees/" + commit.sha + "?recursive=1")
    guard !tree.truncated else { throw failure("GitHub truncated the repository tree; a complete delta is unavailable.") }
    var matches = 0, missing: [String] = [], different: [String] = [], remotePaths = Set<String>()
    for item in tree.tree where item.type == "blob" || item.type == "commit" {
      guard safeRelative(item.path), remotePaths.insert(item.path).inserted else { throw failure("GitHub returned an unsafe or duplicate tree path.") }
      guard let local = inventory.entries[item.path] else { missing.append(item.path); continue }
      let correctKind = item.mode == "120000" ? local.kind == "symlink" : item.type == "commit" ? local.kind == "directory" : local.kind == "file"
      let correctExecutableMode = item.mode == "100755" ? local.mode & 0o111 != 0 : item.mode == "100644" ? local.mode & 0o111 == 0 : true
      if correctKind && correctExecutableMode && item.type != "commit" && local.gitBlobSHA1?.lowercased() == item.sha.lowercased() { matches += 1 }
      else { different.append(item.path) }
    }
    let localOnly = git.visiblePaths.filter { path in
      inventory.entries[path] != nil && path != ".git" && !path.hasPrefix(".git/") && !remotePaths.contains(path)
    }.sorted()
    var history = git.head == nil ? "Local branch has no commit; GitHub has \(commit.sha)." : "Local HEAD \(git.head!) differs from live GitHub \(commit.sha)."
    if git.head == commit.sha { history = "Local HEAD matches live GitHub." }
    else if let localHead = git.head {
      let compared = try api(endpoint + "/compare/" + localHead + "..." + commit.sha)
      if compared.code == 0, let object = try? JSONSerialization.jsonObject(with: compared.data) as? [String: Any] {
        history = "GitHub history: \(object["status"] as? String ?? "compared"), ahead \(object["ahead_by"] as? Int ?? 0), behind \(object["behind_by"] as? Int ?? 0)."
      } else { history = "GitHub could not establish an ancestry comparison. Local Git metadata must not be reset or pulled automatically." }
    }
    return CheckoutGitHubEvidence(repositoryID: repository.id, fullName: repository.full_name,
      browserURL: canonical.browserURL, defaultBranch: repository.default_branch, head: commit.sha,
      treeFileCount: remotePaths.count, matchingFiles: matches, differentPaths: different.sorted(),
      missingPaths: missing.sorted(), localOnlyPaths: localOnly, historyStatus: history)
  }

  private struct CommandResult { let code: Int32; let data: Data; var text: String { String(decoding: data, as: UTF8.self) } }
  private static func run(_ executable: String, _ arguments: [String], environment: [String: String], timeout: TimeInterval = 15) throws -> CommandResult {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-checkout-command-" + UUID().uuidString)
    try privateDirectory(temp)
    defer { try? FileManager.default.removeItem(at: temp) }
    let output = temp.appendingPathComponent("output")
    guard FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw failure("Could not create private command output.") }
    let handle = try FileHandle(forWritingTo: output)
    defer { try? handle.close() }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
    process.environment = environment; process.standardOutput = handle; process.standardError = handle
    process.standardInput = FileHandle.nullDevice
    try process.run()
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    while process.isRunning {
      if ProcessInfo.processInfo.systemUptime >= deadline {
        stop(process)
        throw failure("A read-only checkout command timed out; no checkout was changed.")
      }
      var outputInfo = stat()
      if lstat(output.path, &outputInfo) == 0, outputInfo.st_size > 32 * 1_024 * 1_024 {
        stop(process); throw failure("Read-only command output exceeded the 32 MB review limit.")
      }
      Thread.sleep(forTimeInterval: 0.02)
    }
    try handle.synchronize()
    var finalOutput = stat()
    guard lstat(output.path, &finalOutput) == 0, finalOutput.st_size <= 32 * 1_024 * 1_024 else {
      throw failure("Read-only command output exceeded the 32 MB review limit.")
    }
    return CommandResult(code: process.terminationStatus, data: try Data(contentsOf: output))
  }

  private static func stop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    let gracefulDeadline = ProcessInfo.processInfo.systemUptime + 0.5
    while process.isRunning && ProcessInfo.processInfo.systemUptime < gracefulDeadline { Thread.sleep(forTimeInterval: 0.02) }
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    let forcedDeadline = ProcessInfo.processInfo.systemUptime + 1
    while process.isRunning && ProcessInfo.processInfo.systemUptime < forcedDeadline { Thread.sleep(forTimeInterval: 0.02) }
  }

  private static func ensureInactive(_ path: String, environment: [String: String]) throws {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).resolvingSymlinksInPath().path
    guard !isWithin(cwd, path) else { throw failure("This checkout contains the active application working directory.") }
    let result = try run("/usr/sbin/lsof", ["-Fpn", "+D", path], environment: environment, timeout: 20)
    guard result.code == 1 && result.data.isEmpty else { throw failure("Retirement is blocked by active files, a process working directory, or an incomplete process-ownership check.") }
  }

  private static func sameContent(_ lhs: CheckoutManifestEntry, _ rhs: CheckoutManifestEntry) -> Bool {
    lhs.kind == rhs.kind && lhs.size == rhs.size && lhs.sha256 == rhs.sha256 && lhs.linkTarget == rhs.linkTarget
  }
  private static func safeRelative(_ path: String) -> Bool {
    !path.isEmpty && !path.hasPrefix("/") && !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == "." || $0 == ".." || $0.isEmpty })
  }
  private static func isWithin(_ child: String, _ parent: String) -> Bool { child == parent || child.hasPrefix(parent + "/") }
  private static func absolutePath(_ raw: String) throws -> String {
    let path = (raw as NSString).standardizingPath
    guard path.hasPrefix("/"), path != "/", !path.contains("\0") else { throw failure("An explicit absolute checkout path is required.") }
    return path
  }
  private static func physicalFutureDirectory(_ raw: String) throws -> String {
    var existing = URL(fileURLWithPath: try absolutePath(raw), isDirectory: true)
    var suffix: [String] = []
    while !existsNoFollow(existing.path) {
      suffix.insert(existing.lastPathComponent, at: 0)
      let parent = existing.deletingLastPathComponent()
      guard parent.path != existing.path else { throw failure("The destination has no inspectable parent directory.") }
      existing = parent
    }
    let base = try explicitDirectory(existing.path)
    return suffix.reduce(base) { ($0 as NSString).appendingPathComponent($1) }
  }
  private static func explicitDirectory(_ raw: String) throws -> String {
    let path = try absolutePath(raw)
    _ = try directoryStatus(path)
    // Accept system parent aliases such as /var -> /private/var, while refusing
    // a selected root that is itself a link. All subsequent traversal is bound
    // to no-follow descriptors for this canonical physical directory.
    return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
  }
  private static func validatePair(_ first: String, _ second: String, protectedRootPaths: [String]) throws {
    guard !isWithin(first, second), !isWithin(second, first) else { throw failure("The selected checkout paths overlap or identify one folder.") }
    try validateProtected(first, protectedRootPaths: protectedRootPaths)
    try validateProtected(second, protectedRootPaths: protectedRootPaths)
  }
  private static func validateProtected(_ path: String, protectedRootPaths: [String]) throws {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    guard !["/Users", "/Volumes", home, home + "/Documents"].contains(path) else { throw failure("A workspace or system root cannot be retired as a checkout.") }
    for protected in protectedRootPaths {
      let normalized = URL(fileURLWithPath: (protected as NSString).standardizingPath).resolvingSymlinksInPath().path
      if !normalized.isEmpty && (isWithin(path, normalized) || isWithin(normalized, path)) {
        throw failure("The selected path overlaps a protected active workspace.")
      }
    }
  }
  private static func directoryStatus(_ path: String) throws -> stat {
    var value = stat()
    guard lstat(path, &value) == 0 else { throw posixFailure("Could not inspect directory") }
    guard value.st_mode & S_IFMT == S_IFDIR else { throw failure("The path must be a real directory; symlink targets are not traversed.") }
    return value
  }
  private static func existsNoFollow(_ path: String) -> Bool { var value = stat(); return lstat(path, &value) == 0 || errno != ENOENT }
  private static func renameExclusive(_ source: String, _ destination: String) -> Int32 {
    source.withCString { from in destination.withCString { to in renamex_np(from, to, UInt32(RENAME_EXCL)) } }
  }
  private static func privateDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    _ = try explicitDirectory(url.path)
  }
  private static func posixFailure(_ prefix: String) -> NSError { failure("\(prefix): \(String(cString: strerror(errno)))") }
  private static func save<T: Encodable>(_ object: T, to path: String) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(object)
    let target = URL(fileURLWithPath: path), temp = target.deletingLastPathComponent().appendingPathComponent(".review-" + UUID().uuidString)
    guard FileManager.default.createFile(atPath: temp.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw failure("Could not create private review evidence.") }
    defer { try? FileManager.default.removeItem(at: temp) }
    let handle = try FileHandle(forWritingTo: temp)
    do { try handle.write(contentsOf: data); try handle.synchronize(); try handle.close() }
    catch { try? handle.close(); throw error }
    guard Darwin.rename(temp.path, target.path) == 0 else { throw posixFailure("Could not save review evidence") }
  }

  private struct InventoryBuilder {
    let root: String
    let maxDuration: TimeInterval
    let started = ProcessInfo.processInfo.systemUptime
    var entries: [String: CheckoutManifestEntry] = [:]
    var files = 0, directories = 0, links = 0
    var bytes: Int64 = 0
    var metadataBytes = 0

    mutating func run() throws -> CheckoutFileInventory {
      let initial = try directoryStatus(root)
      guard initial.st_flags & 0x40000000 == 0 else { throw failure("A cloud placeholder directory must be downloaded before full review.") }
      let descriptor = open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      guard descriptor >= 0 else { throw posixFailure("Could not open checkout directory") }
      var opened = stat()
      guard fstat(descriptor, &opened) == 0, opened.st_dev == initial.st_dev, opened.st_ino == initial.st_ino else {
        close(descriptor); throw failure("Checkout root changed during inspection.")
      }
      let rootAttrs: [String: String]
      do { rootAttrs = try attributes(fd: descriptor); try countMetadata(rootAttrs) }
      catch { close(descriptor); throw error }
      try walk(descriptor, relative: "", depth: 0)
      let final = try directoryStatus(root)
      guard sameStatus(initial, final), try attributes(path: root) == rootAttrs else { throw failure("Checkout root changed while being reviewed.") }
      let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
      let manifestData = try encoder.encode(entries)
      return CheckoutFileInventory(rootDevice: Int64(initial.st_dev), rootInode: UInt64(initial.st_ino),
        rootMode: UInt32(initial.st_mode & 0o7777), rootMtimeNanoseconds: nanoseconds(initial), rootFlags: initial.st_flags,
        rootXattrs: rootAttrs, entries: entries, fileCount: files, directoryCount: directories,
        symlinkCount: links, totalBytes: bytes, manifestDigest: hex(SHA256.hash(data: manifestData)))
    }

    mutating func bound() throws {
      guard entries.count < 200_000, bytes <= 10 * 1_024 * 1_024 * 1_024, ProcessInfo.processInfo.systemUptime - started < maxDuration else {
        throw failure("Full checkout review reached its 200,000-entry, 10 GB, or \(Int(maxDuration))-second limit. Nothing was changed.")
      }
    }
    mutating func countMetadata(_ attributes: [String: String]) throws {
      let captured = attributes.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count }
      let (total, overflow) = metadataBytes.addingReportingOverflow(captured)
      guard !overflow, total <= 64 * 1_024 * 1_024 else {
        throw failure("Extended-attribute evidence exceeded the 64 MB review limit. Nothing was changed.")
      }
      metadataBytes = total
    }
    mutating func walk(_ fd: Int32, relative: String, depth: Int) throws {
      guard depth < 128 else { close(fd); throw failure("Directory depth exceeded the full review limit.") }
      guard let directory = fdopendir(fd) else { let error = posixFailure("Could not enumerate checkout"); close(fd); throw error }
      defer { closedir(directory) }
      var before = stat()
      guard fstat(fd, &before) == 0 else { throw posixFailure("Could not inspect checkout directory") }
      while true {
        try bound(); errno = 0
        guard let entry = readdir(directory) else {
          if errno != 0 { throw posixFailure("Could not read checkout directory") }
          break
        }
        let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
          pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(validatingCString: $0) }
        }
        guard let name else { throw failure("A checkout filename could not be decoded safely.") }
        if name == "." || name == ".." { continue }
        let rel = relative.isEmpty ? name : relative + "/" + name
        var status = stat()
        guard fstatat(fd, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else { throw posixFailure("Could not inspect checkout entry") }
        guard status.st_flags & 0x40000000 == 0 else { throw failure("Cloud placeholder remains at \(rel); download it before review.") }
        let kind = status.st_mode & S_IFMT
        var sha: String?, blob: String?, target: String?
        let attrs: [String: String]
        if kind == S_IFDIR {
          let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
          guard child >= 0 else { throw posixFailure("Could not open checkout directory") }
          var actual = stat()
          guard fstat(child, &actual) == 0, sameStatus(status, actual) else { close(child); throw failure("Directory changed while opening: \(rel)") }
          do { attrs = try attributes(fd: child) }
          catch { close(child); throw error }
          do { try countMetadata(attrs) }
          catch { close(child); throw error }
          directories += 1
          entries[rel] = entryValue("directory", status, attrs: attrs)
          try walk(child, relative: rel, depth: depth + 1)
          continue
        } else if kind == S_IFREG {
          let file = openat(fd, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
          guard file >= 0 else { throw posixFailure("Could not read checkout file") }
          defer { close(file) }
          var actual = stat()
          guard fstat(file, &actual) == 0, sameStatus(status, actual) else { throw failure("File changed while opening: \(rel)") }
          attrs = try attributes(fd: file)
          try countMetadata(attrs)
          let (next, overflow) = bytes.addingReportingOverflow(status.st_size)
          guard !overflow, next <= 10 * 1_024 * 1_024 * 1_024 else { throw failure("Checkout byte count exceeds the review limit.") }
          bytes = next; files += 1
          var shaHasher = SHA256(), blobHasher = Insecure.SHA1()
          blobHasher.update(data: Data("blob \(status.st_size)\0".utf8))
          var buffer = [UInt8](repeating: 0, count: 65_536)
          while true {
            try bound()
            let count = Darwin.read(file, &buffer, buffer.count)
            guard count >= 0 else { throw posixFailure("Could not read checkout file bytes") }
            if count == 0 { break }
            let data = Data(buffer.prefix(count)); shaHasher.update(data: data); blobHasher.update(data: data)
          }
          var after = stat()
          guard fstat(file, &after) == 0, sameStatus(status, after), try attributes(fd: file) == attrs else { throw failure("File changed during hashing: \(rel)") }
          sha = hex(shaHasher.finalize()); blob = hex(blobHasher.finalize())
        } else if kind == S_IFLNK {
          let link = openat(fd, name, O_RDONLY | O_SYMLINK | O_CLOEXEC)
          guard link >= 0 else { throw posixFailure("Could not open checkout link metadata") }
          defer { close(link) }
          var linkStatus = stat()
          guard fstat(link, &linkStatus) == 0, sameStatus(status, linkStatus) else { throw failure("Link changed while opening metadata: \(rel)") }
          var buffer = [CChar](repeating: 0, count: 65_537)
          let count = readlinkat(fd, name, &buffer, buffer.count - 1)
          guard count >= 0, count < buffer.count - 1 else { throw posixFailure("Could not inspect checkout link") }
          guard let decoded = buffer.withUnsafeBufferPointer({ String(bytes: $0.prefix(count).map { UInt8(bitPattern: $0) }, encoding: .utf8) }) else { throw failure("A link target could not be decoded safely.") }
          target = decoded; links += 1
          let data = Data(decoded.utf8); var hasher = Insecure.SHA1(); hasher.update(data: Data("blob \(data.count)\0".utf8)); hasher.update(data: data)
          blob = hex(hasher.finalize()); attrs = try attributes(fd: link)
          try countMetadata(attrs)
          var after = stat()
          guard fstatat(fd, name, &after, AT_SYMLINK_NOFOLLOW) == 0, sameStatus(status, after) else { throw failure("Link changed during review: \(rel)") }
        } else { throw failure("A special filesystem entry requires separate preservation: \(rel)") }
        entries[rel] = entryValue(kind == S_IFREG ? "file" : "symlink", status, attrs: attrs, sha: sha, blob: blob, target: target)
      }
      var after = stat()
      guard fstat(fd, &after) == 0, sameStatus(before, after) else { throw failure("Directory contents changed during full review: \(relative)") }
    }
    private func entryValue(_ kind: String, _ status: stat, attrs: [String: String], sha: String? = nil, blob: String? = nil, target: String? = nil) -> CheckoutManifestEntry {
      CheckoutManifestEntry(kind: kind, mode: UInt32(status.st_mode & 0o7777), mtimeNanoseconds: nanoseconds(status),
        flags: status.st_flags, size: kind == "directory" ? 0 : status.st_size, sha256: sha, gitBlobSHA1: blob, linkTarget: target, xattrs: attrs)
    }
  }

  private static func nanoseconds(_ value: stat) -> Int64 { Int64(value.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(value.st_mtimespec.tv_nsec) }
  private static func sameStatus(_ a: stat, _ b: stat) -> Bool {
    a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_mode == b.st_mode && a.st_size == b.st_size && nanoseconds(a) == nanoseconds(b) && a.st_flags == b.st_flags
  }
  private static func hex<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 { bytes.map { String(format: "%02x", $0) }.joined() }
  private static func attributes(fd: Int32) throws -> [String: String] {
    try readAttributes(list: { buffer, size in flistxattr(fd, buffer, size, 0) }, value: { name, buffer, size in fgetxattr(fd, name, buffer, size, 0, 0) })
  }
  private static func attributes(path: String) throws -> [String: String] {
    try readAttributes(list: { buffer, size in listxattr(path, buffer, size, XATTR_NOFOLLOW) }, value: { name, buffer, size in getxattr(path, name, buffer, size, 0, XATTR_NOFOLLOW) })
  }
  private static func readAttributes(list: (UnsafeMutablePointer<CChar>?, Int) -> Int, value: (String, UnsafeMutableRawPointer?, Int) -> Int) throws -> [String: String] {
    let size = list(nil, 0)
    guard size >= 0, size <= 1_024 * 1_024 else { throw posixFailure("Extended-attribute names could not be preserved") }
    if size == 0 { return [:] }
    var names = [CChar](repeating: 0, count: size)
    guard list(&names, size) == size else { throw failure("Extended attributes changed during inspection.") }
    let raw = names.map { UInt8(bitPattern: $0) }
    var result: [String: String] = [:]
    var capturedBytes = 0
    for part in raw.split(separator: 0) {
      guard let name = String(bytes: part, encoding: .utf8) else { throw failure("An extended-attribute name could not be decoded safely.") }
      let count = value(name, nil, 0)
      guard count >= 0, count <= 16 * 1_024 * 1_024 else { throw posixFailure("Extended-attribute bytes could not be preserved") }
      let encodedSize = 4 * ((count + 2) / 3)
      let (next, overflow) = capturedBytes.addingReportingOverflow(encodedSize + name.utf8.count)
      guard !overflow, next <= 64 * 1_024 * 1_024 else { throw failure("One entry's extended attributes exceeded the 64 MB evidence limit.") }
      capturedBytes = next
      var data = Data(count: count)
      let actual = data.withUnsafeMutableBytes { value(name, $0.baseAddress, count) }
      guard actual == count else { throw failure("Extended-attribute bytes changed during inspection.") }
      result[name] = data.base64EncodedString()
    }
    return result
  }
}
