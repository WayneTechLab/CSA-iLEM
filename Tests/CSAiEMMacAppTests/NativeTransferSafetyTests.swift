import Foundation
import XCTest
@testable import CSAiEMMacApp

final class NativeTransferSafetyTests: XCTestCase {
  func testChangedStagedTreeBlocksPromotionAndPreservesEveryOriginal() throws {
    try fixture { root in
      let operations = try pair(root)
      do {
        _ = try CleanupViewModel.performTransactionalTransfers(operations: operations, mode: .move, overwrite: true,
          environment: ["CSA_IEM_TEST_CORRUPT_NATIVE_STAGE_INDEX": "1"])
        XCTFail("Expected full-tree verification to reject the changed stage")
      } catch let error as CleanupViewModel.NativeTransferFailure {
        XCTAssertTrue(error.detail.contains("verification"))
        XCTAssertEqual(error.residualSources.count, 2)
        XCTAssertTrue(error.residualSources.contains { FileManager.default.fileExists(atPath: $0.sourcePath + "/injected-stage-only.fixture") })
      }
      try assertOriginalsAndSources(operations)
    }
  }

  func testVerifiedMoveIncludesHiddenFilesAndSymlinks() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source/one")
      let destination = root.appendingPathComponent("out/one")
      try write("private", at: source.appendingPathComponent(".hidden"))
      try write("payload", at: source.appendingPathComponent("nested/data.txt"))
      try FileManager.default.createSymbolicLink(atPath: source.appendingPathComponent("link").path, withDestinationPath: "nested/data.txt")
      let result = try CleanupViewModel.performTransactionalTransfers(
        operations: [LocalTransferOperation(source: source.path, destination: destination.path)],
        mode: .move, overwrite: false, environment: [:])
      XCTAssertTrue(result.residualSources.isEmpty)
      XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
      XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent(".hidden"), encoding: .utf8), "private")
      XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: destination.appendingPathComponent("link").path), "nested/data.txt")
    }
  }

  func testSourceChangedAfterPromotionRemainsForRecovery() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source/one")
      let destination = root.appendingPathComponent("out/one")
      try write("original", at: source.appendingPathComponent("data.txt"))
      let result = try CleanupViewModel.performTransactionalTransfers(
        operations: [LocalTransferOperation(source: source.path, destination: destination.path)],
        mode: .move, overwrite: false,
        environment: ["CSA_IEM_TEST_MUTATE_NATIVE_SOURCE_BEFORE_CLEANUP": source.path])
      XCTAssertEqual(result.residualSources.count, 1)
      XCTAssertTrue(result.warnings.first?.contains("Cleanup incomplete") == true)
      XCTAssertEqual(try String(contentsOf: source.appendingPathComponent("late-change.fixture"), encoding: .utf8), "New source data")
      XCTAssertEqual(try String(contentsOf: source.appendingPathComponent("data.txt"), encoding: .utf8), "original")
      XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("data.txt"), encoding: .utf8), "original")
    }
  }

  func testPartialSecondStagePreservesBothUntouchedOriginalDestinations() throws {
    try fixture { root in
      let operations = try pair(root)
      do {
        _ = try CleanupViewModel.performTransactionalTransfers(operations: operations, mode: .move, overwrite: true,
          environment: ["CSA_IEM_TEST_FAIL_NATIVE_STAGE_INDEX": "1"])
        XCTFail("Expected a staging failure")
      } catch let error as CleanupViewModel.NativeTransferFailure {
        XCTAssertEqual(error.residualSources.count, 2)
        XCTAssertTrue(error.residualSources.allSatisfy { $0.sourcePath.contains(".csa-iem-stage-") })
        for record in error.residualSources { XCTAssertTrue(FileManager.default.fileExists(atPath: record.sourcePath)) }
        XCTAssertTrue(error.residualSources.contains { FileManager.default.fileExists(atPath: $0.sourcePath + "/partial-copy.fixture") })
      }
      try assertOriginalsAndSources(operations)
    }
  }

  func testSecondBackupFailureRestoresOnlyTheDestinationThatActuallyMoved() throws {
    try fixture { root in
      let operations = try pair(root)
      XCTAssertThrowsError(try CleanupViewModel.performTransactionalTransfers(operations: operations, mode: .move, overwrite: true,
        environment: ["CSA_IEM_TEST_FAIL_NATIVE_BACKUP_INDEX": "1"]))
      try assertOriginalsAndSources(operations)
      let siblings = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("out").path)
      XCTAssertFalse(siblings.contains { $0.contains(".csa-iem-backup-") })
      XCTAssertEqual(siblings.filter { $0.contains(".csa-iem-stage-") }.count, 2)
    }
  }

  func testPostPromotionRollbackPreservesPromotedBytesBeforeRestoringOriginals() throws {
    try fixture { root in
      let operations = try pair(root)
      do {
        _ = try CleanupViewModel.performTransactionalTransfers(operations: operations, mode: .copyBackup, overwrite: true,
          environment: ["CSA_IEM_TEST_FAIL_AFTER_TRANSACTION_PROMOTION": "1"])
        XCTFail("Expected a post-promotion failure")
      } catch let error as CleanupViewModel.NativeTransferFailure {
        XCTAssertEqual(error.residualSources.count, 2)
        for record in error.residualSources {
          let label = (try XCTUnwrap(record.destinationPath) as NSString).lastPathComponent
          XCTAssertEqual(try String(contentsOfFile: record.sourcePath + "/data.txt", encoding: .utf8), "new-" + label)
        }
      }
      try assertOriginalsAndSources(operations)
    }
  }

  func testSuccessfulOverwriteRetainsFullPriorDestinationAndReportsIt() throws {
    try fixture { root in
      let operations = try pair(root)
      let outcome = try CleanupViewModel.performTransactionalTransfers(operations: operations, mode: .move, overwrite: true, environment: [:])
      XCTAssertEqual(outcome.residualSources.count, 2)
      XCTAssertEqual(outcome.warnings.count, 2)
      for operation in operations {
        let label = (operation.destination as NSString).lastPathComponent
        XCTAssertFalse(FileManager.default.fileExists(atPath: operation.source))
        XCTAssertEqual(try String(contentsOfFile: operation.destination + "/data.txt", encoding: .utf8), "new-" + label)
        let backup = try XCTUnwrap(outcome.residualSources.first { $0.destinationPath == operation.destination })
        XCTAssertTrue(backup.sourcePath.contains(".csa-iem-backup-"))
        XCTAssertEqual(try String(contentsOfFile: backup.sourcePath + "/data.txt", encoding: .utf8), "old-" + label)
        XCTAssertEqual(try String(contentsOfFile: backup.sourcePath + "/old-only.txt", encoding: .utf8), "unique-old-" + label)
        XCTAssertTrue(backup.summary.cleanupIncomplete)
      }
      let temp = root.appendingPathComponent("out/_temp")
      XCTAssertTrue((try FileManager.default.contentsOfDirectory(atPath: temp.path)).isEmpty)
    }
  }

  func testSuccessfulCopyLeavesSourcesAndRemovesOnlyEmptyTransactionContainers() throws {
    try fixture { root in
      let source = root.appendingPathComponent("source")
      let destination = root.appendingPathComponent("out/project")
      try write("payload", at: source.appendingPathComponent("data.txt"))
      let unrelated = root.appendingPathComponent("out/_temp/keep-this/note.txt")
      try write("retained unrelated data", at: unrelated)
      let outcome = try CleanupViewModel.performTransactionalTransfers(
        operations: [LocalTransferOperation(source: source.path, destination: destination.path)],
        mode: .copyBackup, overwrite: false, environment: [:])
      XCTAssertTrue(outcome.warnings.isEmpty)
      XCTAssertTrue(outcome.residualSources.isEmpty)
      XCTAssertEqual(try String(contentsOf: source.appendingPathComponent("data.txt"), encoding: .utf8), "payload")
      XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("data.txt"), encoding: .utf8), "payload")
      XCTAssertEqual(try String(contentsOf: unrelated, encoding: .utf8), "retained unrelated data")
      XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("out/_temp").path), ["keep-this"])
    }
  }

  func testWorkspaceRelocationStagingFailureDoesNotTouchExistingRoots() throws {
    try fixture { root in
      let names = ["Code", "Import", "Runtime"]
      for name in names {
        try write("new-" + name, at: root.appendingPathComponent("source/" + name + "/data.txt"))
        try write("old-" + name, at: root.appendingPathComponent("out/" + name + "/data.txt"))
      }
      XCTAssertThrowsError(try CleanupViewModel.relocateWorkspaceRoots(scope: .workspace, style: .split,
        codeRoot: root.appendingPathComponent("source/Code").path,
        importRoot: root.appendingPathComponent("source/Import").path,
        runtimeRoot: root.appendingPathComponent("source/Runtime").path,
        destinationBase: root.appendingPathComponent("out").path, overwrite: true,
        environment: ["CSA_IEM_TEST_FAIL_NATIVE_STAGE_INDEX": "1"]))
      for name in names {
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("source/" + name + "/data.txt"), encoding: .utf8), "new-" + name)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("out/" + name + "/data.txt"), encoding: .utf8), "old-" + name)
      }
    }
  }

  func testSnapshotBackupFailureCannotRemoveAnyOriginalWorkspaceRoot() throws {
    try fixture { root in
      let names = ["Code", "Import", "Runtime"]
      for name in names {
        try write("old-" + name, at: root.appendingPathComponent("workspace/" + name + "/Repos/owner/project/data.txt"))
        try write("new-" + name, at: root.appendingPathComponent("payload/" + name + "/Repos/owner/project/data.txt"))
      }
      do {
        _ = try CleanupViewModel.restoreSnapshotPayload(payloadPath: root.appendingPathComponent("payload").path,
          roots: (root.appendingPathComponent("workspace/Code").path, root.appendingPathComponent("workspace/Import").path, root.appendingPathComponent("workspace/Runtime").path),
          environment: ["CSA_IEM_TEST_FAIL_SNAPSHOT_BACKUP_INDEX": "1"])
        XCTFail("Expected preparatory backup failure")
      } catch let error as CleanupViewModel.NativeTransferFailure {
        XCTAssertTrue(error.detail.contains("never began"))
        for record in error.residualSources {
          XCTAssertTrue(FileManager.default.fileExists(atPath: record.sourcePath))
          // This test owns its temporary preparatory backups too.
          try FileManager.default.removeItem(atPath: record.sourcePath)
        }
      }
      for name in names {
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("workspace/" + name + "/Repos/owner/project/data.txt"), encoding: .utf8), "old-" + name)
      }
    }
  }

  func testSnapshotRestoreRejectsChangedPreparatoryBackupBeforeMerge() throws {
    try fixture { root in
      let code = root.appendingPathComponent("workspace/Code")
      let payload = root.appendingPathComponent("payload")
      try write("original", at: code.appendingPathComponent("Repos/owner/project/data.txt"))
      try write("incoming", at: payload.appendingPathComponent("Code/Repos/owner/project/data.txt"))
      do {
        _ = try CleanupViewModel.restoreSnapshotPayload(payloadPath: payload.path,
          roots: (code.path, root.appendingPathComponent("workspace/Import").path, root.appendingPathComponent("workspace/Runtime").path),
          environment: ["CSA_IEM_TEST_CORRUPT_SNAPSHOT_BACKUP_INDEX": "0"])
        XCTFail("Expected full backup verification to reject a changed copy")
      } catch let error as CleanupViewModel.NativeTransferFailure {
        XCTAssertTrue(error.detail.contains("never began"))
        XCTAssertEqual(error.residualSources.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: error.residualSources[0].sourcePath + "/root-0/injected-backup-only.fixture"))
      }
      XCTAssertEqual(try String(contentsOf: code.appendingPathComponent("Repos/owner/project/data.txt"), encoding: .utf8), "original")
    }
  }

  func testSnapshotRestoreKeepsVerifiedPreviousWorkspaceAfterSuccess() throws {
    try fixture { root in
      let code = root.appendingPathComponent("workspace/Code")
      let payload = root.appendingPathComponent("payload")
      try write("original", at: code.appendingPathComponent("Repos/owner/project/data.txt"))
      try write("unique-old", at: code.appendingPathComponent("Repos/owner/project/old-only.txt"))
      try write("incoming", at: payload.appendingPathComponent("Code/Repos/owner/project/data.txt"))
      let retained = try CleanupViewModel.restoreSnapshotPayload(payloadPath: payload.path,
        roots: (code.path, root.appendingPathComponent("workspace/Import").path, root.appendingPathComponent("workspace/Runtime").path), environment: [:])
      XCTAssertTrue(retained.contains("/Recovery/SnapshotRestores/"))
      XCTAssertEqual(try String(contentsOf: code.appendingPathComponent("Repos/owner/project/data.txt"), encoding: .utf8), "incoming")
      XCTAssertEqual(try String(contentsOfFile: retained + "/root-0/Repos/owner/project/data.txt", encoding: .utf8), "original")
      XCTAssertEqual(try String(contentsOfFile: retained + "/root-0/Repos/owner/project/old-only.txt", encoding: .utf8), "unique-old")
    }
  }

  private func pair(_ root: URL) throws -> [LocalTransferOperation] {
    try ["a", "b"].map { label in
      let source = root.appendingPathComponent("source/" + label)
      let destination = root.appendingPathComponent("out/" + label)
      try write("new-" + label, at: source.appendingPathComponent("data.txt"))
      try write("old-" + label, at: destination.appendingPathComponent("data.txt"))
      try write("unique-old-" + label, at: destination.appendingPathComponent("old-only.txt"))
      return LocalTransferOperation(source: source.path, destination: destination.path)
    }
  }

  private func assertOriginalsAndSources(_ operations: [LocalTransferOperation]) throws {
    for operation in operations {
      let label = (operation.destination as NSString).lastPathComponent
      XCTAssertEqual(try String(contentsOfFile: operation.source + "/data.txt", encoding: .utf8), "new-" + label)
      XCTAssertEqual(try String(contentsOfFile: operation.destination + "/data.txt", encoding: .utf8), "old-" + label)
      XCTAssertEqual(try String(contentsOfFile: operation.destination + "/old-only.txt", encoding: .utf8), "unique-old-" + label)
    }
  }

  private func fixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-iem-native-transfer-safety-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }

  private func write(_ text: String, at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }
}
