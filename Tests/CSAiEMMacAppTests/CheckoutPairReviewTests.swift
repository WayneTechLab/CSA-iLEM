import Darwin
import Foundation
import XCTest
@testable import CSAiEMMacApp

final class CheckoutPairReviewTests: XCTestCase {
  func testInventoryIncludesHiddenGeneratedAndGitFilesWithoutFollowingLinks() throws {
    try withRoot { root in
      let source = root.appendingPathComponent("source")
      let outside = root.appendingPathComponent("outside-secret")
      try write("must remain outside the inventory", to: outside)
      try write("git fixture", to: source.appendingPathComponent(".git/config"))
      try write("hidden fixture", to: source.appendingPathComponent(".hidden/retain.txt"))
      try write("abc", to: source.appendingPathComponent("node_modules/pkg/LICENSE 2"))
      try FileManager.default.createSymbolicLink(at: source.appendingPathComponent("external-link"), withDestinationURL: outside)

      let inventory = try CheckoutPairReviewEngine.inventory(path: source.path)
      XCTAssertEqual(inventory.fileCount, 3)
      XCTAssertEqual(inventory.directoryCount, 4)
      XCTAssertEqual(inventory.symlinkCount, 1)
      XCTAssertEqual(inventory.entries["node_modules/pkg/LICENSE 2"]?.sha256,
                     "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
      XCTAssertEqual(inventory.entries["node_modules/pkg/LICENSE 2"]?.gitBlobSHA1,
                     try command("/usr/bin/git", ["hash-object", source.appendingPathComponent("node_modules/pkg/LICENSE 2").path]).trimmingCharacters(in: .whitespacesAndNewlines))
      XCTAssertEqual(inventory.entries["external-link"]?.kind, "symlink")
      XCTAssertEqual(inventory.entries["external-link"]?.linkTarget, outside.path)
      XCTAssertNil(inventory.entries["outside-secret"])
      XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "must remain outside the inventory")

      let rootLink = root.appendingPathComponent("source-alias")
      try FileManager.default.createSymbolicLink(at: rootLink, withDestinationURL: source)
      XCTAssertThrowsError(try CheckoutPairReviewEngine.inventory(path: rootLink.path))
    }
  }

  func testDistinctGitHubRepositoriesAndWorkingFileParityRemainSeparateEvidence() throws {
    try withFixture(unrelatedKeeperHistory: true) { fixture in
      let indexBefore = try Data(contentsOf: fixture.first.appendingPathComponent(".git/index"))
      let notesBefore = try Data(contentsOf: fixture.second.appendingPathComponent("Prompt_Inject.MD"))
      let review = try fixture.review()
      let first = try XCTUnwrap(review.first.github)
      let second = try XCTUnwrap(review.second.github)

      XCTAssertEqual(first.repositoryID, 101)
      XCTAssertEqual(second.repositoryID, 202)
      XCTAssertNotEqual(first.repositoryID, second.repositoryID)
      XCTAssertNotEqual(review.first.git.origin?.groupingKey, review.second.git.origin?.groupingKey)
      XCTAssertEqual(first.treeFileCount, 1)
      XCTAssertEqual(first.matchingFiles, 1)
      XCTAssertTrue(first.differentPaths.isEmpty)
      XCTAssertTrue(first.missingPaths.isEmpty)
      XCTAssertNotEqual(review.first.git.head, first.head)
      XCTAssertTrue(first.historyStatus.localizedCaseInsensitiveContains("ancestry"))
      XCTAssertTrue(second.missingPaths.contains("README.md"))
      XCTAssertNil(review.second.git.head)
      XCTAssertTrue(review.delta.secondOnlyPaths.contains("Prompt_Inject.MD"))
      XCTAssertEqual(try Data(contentsOf: fixture.first.appendingPathComponent(".git/index")), indexBefore)
      XCTAssertEqual(try Data(contentsOf: fixture.second.appendingPathComponent("Prompt_Inject.MD")), notesBefore)
      XCTAssertTrue(FileManager.default.fileExists(atPath: review.evidencePath))
    }
  }

  func testRetirementPreservesWholeCheckoutAndCanRestoreWithoutChangingKeeper() throws {
    try withFixture { fixture in
      _ = try command("/usr/bin/xattr", ["-w", "com.csa.checkout-fixture", "preserved metadata", fixture.second.appendingPathComponent("Prompt_Inject.MD").path])
      let indexBefore = try Data(contentsOf: fixture.first.appendingPathComponent(".git/index"))
      let keeperBefore = try CheckoutPairReviewEngine.inventory(path: fixture.first.path)
      let sourceBefore = try CheckoutPairReviewEngine.inventory(path: fixture.second.path)
      let review = try fixture.review()
      XCTAssertTrue(review.canRetire, review.blockers.joined(separator: "\n"))

      let receipt = try fixture.retire(review)
      let archive = URL(fileURLWithPath: receipt.archivePath)
      XCTAssertEqual(receipt.originalPath, fixture.second.path)
      XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.second.path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))
      XCTAssertEqual(try Data(contentsOf: archive.appendingPathComponent("Prompt_Inject.MD")), Data("handoff note to preserve\n".utf8))
      XCTAssertEqual(try Data(contentsOf: archive.appendingPathComponent("node_modules/pkg/LICENSE 2")), Data("numbered dependency fixture\n".utf8))
      XCTAssertTrue(FileManager.default.fileExists(atPath: archive.appendingPathComponent(".git/config").path))
      XCTAssertEqual(try command("/usr/bin/xattr", ["-p", "com.csa.checkout-fixture", archive.appendingPathComponent("Prompt_Inject.MD").path]).trimmingCharacters(in: .newlines), "preserved metadata")
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: archive.path).manifestDigest, sourceBefore.manifestDigest)
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: fixture.first.path).manifestDigest, keeperBefore.manifestDigest)
      XCTAssertEqual(try Data(contentsOf: fixture.first.appendingPathComponent(".git/index")), indexBefore)
      XCTAssertTrue(FileManager.default.fileExists(atPath: receipt.receiptPath))

      _ = try CheckoutPairReviewEngine.restore(receipt: receipt, protectedRootPaths: [], environment: fixture.environment)
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.second.path))
      XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: fixture.second.path).manifestDigest, sourceBefore.manifestDigest)
      XCTAssertEqual(try Data(contentsOf: fixture.first.appendingPathComponent(".git/index")), indexBefore)
    }
  }

  func testChangedSourceAfterReviewBlocksRetirementAndPreservesBothVersions() throws {
    try withFixture { fixture in
      let review = try fixture.review()
      let changed = Data("new work added after review\n".utf8)
      try changed.write(to: fixture.second.appendingPathComponent("Prompt_Inject.MD"))
      XCTAssertThrowsError(try fixture.retire(review))
      XCTAssertEqual(try Data(contentsOf: fixture.second.appendingPathComponent("Prompt_Inject.MD")), changed)
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.first.appendingPathComponent("README.md").path))
    }
  }

  func testFailureAfterArchiveRenameRollsBackToOriginalLocation() throws {
    try withFixture { fixture in
      let before = try CheckoutPairReviewEngine.inventory(path: fixture.second.path)
      let review = try fixture.review()
      var environment = fixture.environment
      environment["CSA_IEM_TEST_FAIL_CHECKOUT_ARCHIVE_AFTER_RENAME"] = "1"
      XCTAssertThrowsError(try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: fixture.first.path, retiringPath: fixture.second.path,
        recoveryRoot: fixture.recovery.path, protectedRootPaths: [], environment: environment
      ))
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.second.path))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: fixture.second.path).manifestDigest, before.manifestDigest)
      XCTAssertEqual(try Data(contentsOf: fixture.first.appendingPathComponent("README.md")), Data("keeper product file\n".utf8))
    }
  }

  func testProtectedOrSameCheckoutCannotBeRetired() throws {
    try withFixture { fixture in
      let review = try fixture.review()
      XCTAssertThrowsError(try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: fixture.first.path, retiringPath: fixture.second.path,
        recoveryRoot: fixture.recovery.path, protectedRootPaths: [fixture.second.path], environment: fixture.environment
      ))
      XCTAssertThrowsError(try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: fixture.first.path, retiringPath: fixture.first.path,
        recoveryRoot: fixture.recovery.path, protectedRootPaths: [], environment: fixture.environment
      ))
      XCTAssertThrowsError(try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: fixture.first.path, retiringPath: fixture.second.path,
        recoveryRoot: fixture.second.appendingPathComponent("nested-recovery").path,
        protectedRootPaths: [], environment: fixture.environment
      ))
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.first.path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.second.path))
    }
  }

  func testRestoreRefusesToOverwriteNewWorkAtOriginalPath() throws {
    try withFixture { fixture in
      let receipt = try fixture.retire(fixture.review())
      let newFile = fixture.second.appendingPathComponent("new-work.txt")
      try write("new work must remain", to: newFile)
      XCTAssertThrowsError(try CheckoutPairReviewEngine.restore(
        receipt: receipt, protectedRootPaths: [], environment: fixture.environment
      ))
      XCTAssertEqual(try String(contentsOf: newFile, encoding: .utf8), "new work must remain")
      XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: receipt.archivePath).appendingPathComponent("Prompt_Inject.MD")), Data("handoff note to preserve\n".utf8))
    }
  }

  func testActiveCheckoutProcessBlocksRetirement() throws {
    try withFixture { fixture in
      let review = try fixture.review()
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/bin/sleep")
      process.arguments = ["30"]
      process.currentDirectoryURL = fixture.second
      try process.run()
      defer {
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
      }
      XCTAssertTrue(process.isRunning)
      XCTAssertThrowsError(try fixture.retire(review))
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.second.appendingPathComponent("Prompt_Inject.MD").path))
    }
  }

  func testIntentionalLinkedWorktreeIsReviewRequiredRatherThanDisposableCopy() throws {
    try withFixture { fixture in
      let linked = fixture.root.appendingPathComponent("intentional-worktree")
      _ = try command("/usr/bin/git", ["-C", fixture.first.path, "worktree", "add", "--detach", linked.path, "HEAD"], environment: fixture.environment)
      let review = try CheckoutPairReviewEngine.review(
        firstPath: fixture.first.path, secondPath: linked.path, ghExecutable: fixture.gh.path,
        environment: fixture.environment, evidenceRoot: fixture.evidence.path, protectedRootPaths: []
      )
      XCTAssertEqual(review.first.git.commonDirectory, review.second.git.commonDirectory)
      XCTAssertFalse(review.canRetire)
      XCTAssertTrue(review.blockers.contains(where: { $0.localizedCaseInsensitiveContains("worktree") }))
      XCTAssertThrowsError(try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: fixture.first.path, retiringPath: linked.path,
        recoveryRoot: fixture.recovery.path, protectedRootPaths: [], environment: fixture.environment
      ))
      XCTAssertTrue(FileManager.default.fileExists(atPath: linked.appendingPathComponent("README.md").path))
    }
  }

  func testUnreadableEntriesCannotProduceVerifiedInventory() throws {
    if geteuid() == 0 { throw XCTSkip("Root bypasses Unix permission fixtures") }
    try withRoot { root in
      let source = root.appendingPathComponent("source")
      let unreadable = source.appendingPathComponent("node_modules/blocked")
      try write("retained payload", to: unreadable.appendingPathComponent("LICENSE 2"))
      try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: unreadable.path)
      defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: unreadable.path) }
      XCTAssertThrowsError(try CheckoutPairReviewEngine.inventory(path: source.path))
    }
  }

  func testTruncatedOrUnavailableProviderEvidenceCannotAuthorizeRetirement() throws {
    try withFixture { fixture in
      try write("{\"truncated\":true,\"tree\":[]}", to: fixture.providerFixtures.appendingPathComponent("keeper-tree.json"))
      let review = try fixture.review()
      XCTAssertFalse(review.canRetire)
      XCTAssertFalse(review.blockers.isEmpty)
      XCTAssertThrowsError(try fixture.retire(review))
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.second.path))
    }
  }

  func testEvidenceAndRecoveryParentAliasesCannotCreateFoldersInsideKeeper() throws {
    try withFixture { fixture in
      let alias = fixture.root.appendingPathComponent("keeper-alias")
      try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.first)
      let keeperBefore = try CheckoutPairReviewEngine.inventory(path: fixture.first.path)
      XCTAssertThrowsError(try CheckoutPairReviewEngine.review(
        firstPath: fixture.first.path, secondPath: fixture.second.path, ghExecutable: fixture.gh.path,
        environment: fixture.environment, evidenceRoot: alias.appendingPathComponent("forbidden-evidence").path,
        protectedRootPaths: []
      ))
      XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.first.appendingPathComponent("forbidden-evidence").path))

      let review = try fixture.review()
      XCTAssertThrowsError(try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: fixture.first.path, retiringPath: fixture.second.path,
        recoveryRoot: alias.appendingPathComponent("forbidden-recovery").path,
        protectedRootPaths: [], environment: fixture.environment
      ))
      XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.first.appendingPathComponent("forbidden-recovery").path))
      XCTAssertEqual(try CheckoutPairReviewEngine.inventory(path: fixture.first.path).manifestDigest, keeperBefore.manifestDigest)
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.second.path))
    }
  }

  func testReviewDoesNotExecuteConfiguredCleanFilterOrFilesystemMonitor() throws {
    try withFixture { fixture in
      let sentinel = fixture.root.appendingPathComponent("forbidden-driver-executed")
      let driver = fixture.root.appendingPathComponent("untrusted-git-driver")
      try write("#!/bin/sh\n/usr/bin/touch \(shellQuote(sentinel.path))\n/bin/cat\n", to: driver)
      try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: driver.path)
      _ = try command("/usr/bin/git", ["-C", fixture.first.path, "config", "filter.fixture.clean", shellQuote(driver.path)], environment: fixture.environment)
      _ = try command("/usr/bin/git", ["-C", fixture.first.path, "config", "filter.fixture.required", "true"], environment: fixture.environment)
      _ = try command("/usr/bin/git", ["-C", fixture.first.path, "config", "core.fsmonitor", driver.path], environment: fixture.environment)
      try write("README.md filter=fixture\n", to: fixture.first.appendingPathComponent(".gitattributes"))
      try write("dirty product content must be read without executing a clean driver\n", to: fixture.first.appendingPathComponent("README.md"))

      let review = try fixture.review()
      XCTAssertFalse(FileManager.default.fileExists(atPath: sentinel.path))
      XCTAssertGreaterThan(review.first.git.trackedChanges, 0)
      XCTAssertEqual(try String(contentsOf: fixture.first.appendingPathComponent("README.md"), encoding: .utf8), "dirty product content must be read without executing a clean driver\n")
    }
  }

  func testRestoreRejectsChangedAncestorAliasEvenWhenImmediateParentIsDirectory() throws {
    try withFixture { fixture in
      let sourceParent = fixture.root.appendingPathComponent("source-parent")
      let nested = sourceParent.appendingPathComponent("nested")
      try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
      let source = nested.appendingPathComponent(fixture.second.lastPathComponent)
      try FileManager.default.moveItem(at: fixture.second, to: source)
      let review = try CheckoutPairReviewEngine.review(
        firstPath: fixture.first.path, secondPath: source.path, ghExecutable: fixture.gh.path,
        environment: fixture.environment, evidenceRoot: fixture.evidence.path, protectedRootPaths: []
      )
      let receipt = try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: fixture.first.path, retiringPath: source.path,
        recoveryRoot: fixture.recovery.path, protectedRootPaths: [], environment: fixture.environment
      )
      let renamedParent = fixture.root.appendingPathComponent("previous-source-parent")
      let replacementParent = fixture.root.appendingPathComponent("replacement-parent")
      try FileManager.default.moveItem(at: sourceParent, to: renamedParent)
      try FileManager.default.createDirectory(at: replacementParent.appendingPathComponent("nested"), withIntermediateDirectories: true)
      try FileManager.default.createSymbolicLink(at: sourceParent, withDestinationURL: replacementParent)

      XCTAssertThrowsError(try CheckoutPairReviewEngine.restore(receipt: receipt, protectedRootPaths: [], environment: fixture.environment))
      XCTAssertFalse(FileManager.default.fileExists(atPath: replacementParent.appendingPathComponent("nested/" + fixture.second.lastPathComponent).path))
      XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: receipt.archivePath).appendingPathComponent("Prompt_Inject.MD")), Data("handoff note to preserve\n".utf8))
    }
  }

  func testUnverifiedProviderHostDoesNotInvokeAuthenticatedGitHubClient() throws {
    try withFixture { fixture in
      for (path, name) in [(fixture.first.path, "keeper"), (fixture.second.path, "placeholder")] {
        _ = try command("/usr/bin/git", ["-C", path, "remote", "set-url", "origin", "https://unverified.example.test/test-owner/" + name + ".git"], environment: fixture.environment)
      }
      let sentinel = fixture.root.appendingPathComponent("authenticated-client-invoked")
      try write("#!/bin/sh\n/usr/bin/touch \(shellQuote(sentinel.path))\nexit 64\n", to: fixture.gh)
      let review = try fixture.review()
      XCTAssertFalse(review.canRetire)
      XCTAssertNil(review.first.github)
      XCTAssertNil(review.second.github)
      XCTAssertFalse(FileManager.default.fileExists(atPath: sentinel.path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.first.path))
      XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.second.path))
    }
  }

  private struct Fixture {
    let root: URL
    let first: URL
    let second: URL
    let evidence: URL
    let recovery: URL
    let gh: URL
    let providerFixtures: URL
    let environment: [String: String]

    func review() throws -> CheckoutPairReview {
      try CheckoutPairReviewEngine.review(
        firstPath: first.path, secondPath: second.path, ghExecutable: gh.path,
        environment: environment, evidenceRoot: evidence.path, protectedRootPaths: []
      )
    }

    func retire(_ review: CheckoutPairReview) throws -> CheckoutRetirementReceipt {
      try CheckoutPairReviewEngine.retire(
        review: review, keepingPath: first.path, retiringPath: second.path,
        recoveryRoot: recovery.path, protectedRootPaths: [], environment: environment
      )
    }
  }

  private func withFixture(unrelatedKeeperHistory: Bool = false, _ body: (Fixture) throws -> Void) throws {
    try withRoot { root in
      let first = root.appendingPathComponent("Control-Lamma-Command")
      let second = root.appendingPathComponent("Command-Lamma-Control")
      let environment = testEnvironment()
      for directory in [first, second] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try command("/usr/bin/git", ["init", "--quiet", "--initial-branch=main", directory.path], environment: environment)
      }
      try write("keeper product file\n", to: first.appendingPathComponent("README.md"))
      _ = try command("/usr/bin/git", ["-C", first.path, "add", "README.md"], environment: environment)
      _ = try command("/usr/bin/git", ["-C", first.path, "-c", "user.name=CSA fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgSign=false", "commit", "--quiet", "-m", "fixture"], environment: environment)
      _ = try command("/usr/bin/git", ["-C", first.path, "remote", "add", "origin", "https://github.com/test-owner/keeper.git"], environment: environment)
      _ = try command("/usr/bin/git", ["-C", second.path, "remote", "add", "origin", "git@github.com:test-owner/placeholder.git"], environment: environment)
      try write("handoff note to preserve\n", to: second.appendingPathComponent("Prompt_Inject.MD"))
      try write("handoff transfer fixture\n", to: second.appendingPathComponent("Transfer_Note.MD"))
      try write("hidden fixture\n", to: second.appendingPathComponent(".retained/hidden.txt"))
      try write("numbered dependency fixture\n", to: second.appendingPathComponent("node_modules/pkg/LICENSE 2"))
      let head = try command("/usr/bin/git", ["-C", first.path, "rev-parse", "HEAD"], environment: environment).trimmingCharacters(in: .whitespacesAndNewlines)
      let readmeSHA = try command("/usr/bin/git", ["hash-object", first.appendingPathComponent("README.md").path], environment: environment).trimmingCharacters(in: .whitespacesAndNewlines)
      let provider = root.appendingPathComponent("provider-fixtures")
      try FileManager.default.createDirectory(at: provider, withIntermediateDirectories: true)
      try writeJSON(["id": 101, "full_name": "test-owner/keeper", "html_url": "https://github.com/test-owner/keeper", "default_branch": "main"], to: provider.appendingPathComponent("keeper-meta.json"))
      try writeJSON(["id": 202, "full_name": "test-owner/placeholder", "html_url": "https://github.com/test-owner/placeholder", "default_branch": "main"], to: provider.appendingPathComponent("placeholder-meta.json"))
      try writeJSON(["sha": unrelatedKeeperHistory ? String(repeating: "a", count: 40) : head], to: provider.appendingPathComponent("keeper-commit.json"))
      try writeJSON(["sha": String(repeating: "c", count: 40)], to: provider.appendingPathComponent("placeholder-commit.json"))
      try writeJSON(["truncated": false, "tree": [["path": "README.md", "type": "blob", "mode": "100644", "sha": readmeSHA]]], to: provider.appendingPathComponent("keeper-tree.json"))
      try writeJSON(["truncated": false, "tree": [["path": "README.md", "type": "blob", "mode": "100644", "sha": String(repeating: "d", count: 40)]]], to: provider.appendingPathComponent("placeholder-tree.json"))
      let gh = root.appendingPathComponent("mock-gh")
      let providerQuoted = shellQuote(provider.path)
      let script = """
      #!/bin/sh
      route=''
      for arg in "$@"; do
        case "$arg" in repos/*) route="$arg";; esac
      done
      fixture=\(providerQuoted)
      case "$route" in
        repos/test-owner/keeper) /bin/cat "$fixture/keeper-meta.json";;
        repos/test-owner/placeholder) /bin/cat "$fixture/placeholder-meta.json";;
        repos/test-owner/keeper/commits/main) /bin/cat "$fixture/keeper-commit.json";;
        repos/test-owner/placeholder/commits/main) /bin/cat "$fixture/placeholder-commit.json";;
        repos/test-owner/keeper/git/trees/*) /bin/cat "$fixture/keeper-tree.json";;
        repos/test-owner/placeholder/git/trees/*) /bin/cat "$fixture/placeholder-tree.json";;
        repos/test-owner/keeper/compare/*) echo 'No common ancestor (HTTP 404)' >&2; exit 1;;
        *) echo 'Unexpected fixture API route' >&2; exit 64;;
      esac
      """
      try write(script, to: gh)
      try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: gh.path)
      try body(Fixture(root: root, first: first, second: second,
                       evidence: root.appendingPathComponent("evidence"), recovery: root.appendingPathComponent("recovery"),
                       gh: gh, providerFixtures: provider, environment: environment))
    }
  }

  private func withRoot(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("csa-checkout-review-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }

  private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }

  private func writeJSON(_ object: Any, to url: URL) throws {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url)
  }

  private func testEnvironment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment["GIT_CONFIG_NOSYSTEM"] = "1"
    environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
    environment["GIT_TERMINAL_PROMPT"] = "0"
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    return environment
  }

  private func command(_ executable: String, _ arguments: [String], environment: [String: String]? = nil) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment ?? testEnvironment()
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let output = String(decoding: data, as: UTF8.self)
    guard process.terminationStatus == 0 else {
      throw NSError(domain: "CheckoutPairReviewTests", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Fixture command failed: \(executable) \(arguments.joined(separator: " "))\n\(output)"])
    }
    return output
  }

  private func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}
