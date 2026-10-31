import Foundation
import XCTest
@testable import CSAiEMMacApp

final class LocalTransferCleanupTests: XCTestCase {
  func testMoveReportsDependencyOnlySourceWhenCleanupFailsAfterPromotion() throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }

    let outcome = try CleanupViewModel.performTransactionalTransfers(
      operations: [LocalTransferOperation(source: fixture.source.path, destination: fixture.destination.path)],
      mode: .move,
      overwrite: false,
      environment: ["CSA_IEM_TEST_FAIL_SOURCE_CLEANUP": "1"]
    )

    XCTAssertEqual(outcome.residualSources.count, 1)
    XCTAssertFalse(outcome.warnings.isEmpty)
    let recorded = try XCTUnwrap(outcome.residualSources.first)
    XCTAssertEqual(recorded.sourcePath, fixture.source.path)
    XCTAssertEqual(recorded.destinationPath, fixture.destination.path)
    XCTAssertEqual(recorded.summary.classification, .residualOnly)
    XCTAssertTrue(recorded.summary.cleanupIncomplete)
    XCTAssertEqual(try Data(contentsOf: fixture.sourceFile), fixture.payload)
    XCTAssertEqual(try Data(contentsOf: fixture.destinationFile), fixture.payload)

    let residual = LocalSourceResidualScanner.postCleanupSummary(rootPath: fixture.source.path)
    XCTAssertEqual(residual.classification, .residualOnly)
    XCTAssertEqual(residual.state, .complete)
    XCTAssertTrue(residual.cleanupIncomplete)
    XCTAssertEqual(residual.fileCount, 1)
    XCTAssertTrue(residual.remainingPathSample.contains("node_modules/fixture/LICENSE 2"))
  }

  func testOrdinaryMoveRemovesSourceWithoutReportingCleanupResidual() throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }

    let outcome = try CleanupViewModel.performTransactionalTransfers(
      operations: [LocalTransferOperation(source: fixture.source.path, destination: fixture.destination.path)],
      mode: .move,
      overwrite: false,
      environment: [:]
    )

    XCTAssertTrue(outcome.residualSources.isEmpty)
    XCTAssertTrue(outcome.warnings.isEmpty)
    XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.source.path))
    XCTAssertEqual(try Data(contentsOf: fixture.destinationFile), fixture.payload)
    XCTAssertTrue(LocalSourceResidualScanner.postCleanupSummary(rootPath: fixture.source.path).cleanupComplete)
  }

  func testCopyBackupRetainsSourceWithoutReportingCleanupFailure() throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }

    let outcome = try CleanupViewModel.performTransactionalTransfers(
      operations: [LocalTransferOperation(source: fixture.source.path, destination: fixture.destination.path)],
      mode: .copyBackup,
      overwrite: false,
      environment: ["CSA_IEM_TEST_FAIL_SOURCE_CLEANUP": "1"]
    )

    XCTAssertTrue(outcome.residualSources.isEmpty)
    XCTAssertTrue(outcome.warnings.isEmpty)
    XCTAssertEqual(try Data(contentsOf: fixture.sourceFile), fixture.payload)
    XCTAssertEqual(try Data(contentsOf: fixture.destinationFile), fixture.payload)
  }

  private func makeFixture() throws -> (
    root: URL, source: URL, destination: URL,
    sourceFile: URL, destinationFile: URL, payload: Data
  ) {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("csa-iem-source-cleanup-\(UUID().uuidString)")
    let source = root.appendingPathComponent("source")
    let destination = root.appendingPathComponent("destination")
    let relativeFile = "node_modules/fixture/LICENSE 2"
    let sourceFile = source.appendingPathComponent(relativeFile)
    let destinationFile = destination.appendingPathComponent(relativeFile)
    let payload = Data("dependency-only cleanup fixture\n".utf8)
    try FileManager.default.createDirectory(at: sourceFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try payload.write(to: sourceFile)
    return (root, source, destination, sourceFile, destinationFile, payload)
  }
}
