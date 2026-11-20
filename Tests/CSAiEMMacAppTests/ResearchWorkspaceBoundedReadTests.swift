import Foundation
import XCTest
@testable import CSAiEMMacApp

final class ResearchWorkspaceBoundedReadTests: XCTestCase {
  func testLargeSparseDocumentationAndWorkflowReadOnlyBoundedPrefixes() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-research-bounds-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let logicalSize: UInt64 = 512 * 1024 * 1024
    let documentationURL = root.appendingPathComponent("README.md")
    let workflowURL = root.appendingPathComponent(".github/workflows/review.yml")
    try writeSparseFile(at: documentationURL, prefix: "# Repository\n## Overview\n", logicalSize: logicalSize)
    try writeSparseFile(at: workflowURL, prefix: "name: Review\npermissions:\n  contents: read\nsteps:\n  - uses: actions/checkout@v4\n", logicalSize: logicalSize)

    let documentation = try XCTUnwrap(CSAiEMLocalDocumentationSummary.scan(path: documentationURL.path, maxBytes: 128))
    XCTAssertEqual(documentation.title, "Repository")
    XCTAssertEqual(documentation.headings, ["Repository", "Overview"])
    XCTAssertEqual(documentation.byteCount, Int(logicalSize))
    XCTAssertTrue(documentation.truncated)
    XCTAssertTrue(documentation.warnings.contains("Documentation read capped at 128 bytes."))

    let workflow = try XCTUnwrap(CSAiEMLocalWorkflowSummary.scan(path: workflowURL.path, maxBytes: 128))
    XCTAssertEqual(workflow.workflowName, "Review")
    XCTAssertEqual(workflow.actionReferences, ["actions/checkout@v4"])
    XCTAssertTrue(workflow.hasPermissionsBlock)
    XCTAssertTrue(workflow.warnings.contains("Workflow read capped at 128 bytes."))
  }

  func testDocumentationExactlyAtLimitIsNotMarkedTruncated() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("csa-research-exact-" + UUID().uuidString + ".md")
    defer { try? FileManager.default.removeItem(at: url) }
    let content = "# Small\n"
    try content.write(to: url, atomically: true, encoding: .utf8)

    let summary = try XCTUnwrap(CSAiEMLocalDocumentationSummary.scan(path: url.path, maxBytes: content.utf8.count))
    XCTAssertEqual(summary.byteCount, content.utf8.count)
    XCTAssertEqual(summary.headings, ["Small"])
    XCTAssertFalse(summary.truncated)
  }

  func testSymlinksAndSpecialFilesAreExcluded() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-research-links-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let original = root.appendingPathComponent("original.md")
    try "# Safe\n".write(to: original, atomically: true, encoding: .utf8)
    let linkedDocumentation = root.appendingPathComponent("README.md")
    let linkedWorkflow = root.appendingPathComponent("review.yml")
    try FileManager.default.createSymbolicLink(at: linkedDocumentation, withDestinationURL: original)
    try FileManager.default.createSymbolicLink(at: linkedWorkflow, withDestinationURL: URL(fileURLWithPath: "/dev/zero"))

    XCTAssertNil(CSAiEMLocalDocumentationSummary.scan(path: linkedDocumentation.path))
    XCTAssertNil(CSAiEMLocalWorkflowSummary.scan(path: linkedWorkflow.path))
    XCTAssertNil(CSAiEMLocalDocumentationSummary.scan(path: "/dev/zero"))
  }

  func testInventoryWalkStopsBeforeLateMatchesAfterEntryLimit() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("csa-research-walk-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let docs = root.appendingPathComponent("docs/only-directory")
    let workflows = root.appendingPathComponent(".github/workflows/only-directory")
    try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: workflows, withIntermediateDirectories: true)
    for index in 0..<100 {
      let name = String(format: "noise-%03d.bin", index)
      try Data().write(to: docs.appendingPathComponent(name))
      try Data().write(to: workflows.appendingPathComponent(name))
    }
    try "# Late\n".write(to: docs.appendingPathComponent("late.md"), atomically: true, encoding: .utf8)
    try "name: Late\n".write(to: workflows.appendingPathComponent("late.yml"), atomically: true, encoding: .utf8)

    let docsAtLimit = CSAiEMLocalDocumentationSummary.scanWithWarnings(paths: [root.path], maxVisitedEntries: 1)
    XCTAssertTrue(docsAtLimit.summaries.isEmpty)
    XCTAssertTrue(docsAtLimit.warnings.contains("Local documentation walk capped at 1 entries."))
    let workflowsAtLimit = CSAiEMLocalWorkflowSummary.scanWithWarnings(paths: [root.path], maxVisitedEntries: 1)
    XCTAssertTrue(workflowsAtLimit.summaries.isEmpty)
    XCTAssertTrue(workflowsAtLimit.warnings.contains("Local workflow walk capped at 1 entries."))

    XCTAssertTrue(CSAiEMLocalDocumentationSummary.scan(paths: [root.path], maxVisitedEntries: 500).contains { $0.title == "Late" })
    XCTAssertTrue(CSAiEMLocalWorkflowSummary.scan(paths: [root.path], maxVisitedEntries: 500).contains { $0.workflowName == "Late" })
  }

  func testInventoryWalkRejectsSymlinkedRootsAndDeepDescendants() throws {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent("csa-research-roots-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: parent) }
    let root = parent.appendingPathComponent("real-repo")
    let deepDocs = root.appendingPathComponent("docs/level-one/level-two")
    let deepWorkflows = root.appendingPathComponent(".github/workflows/level-one/level-two")
    try FileManager.default.createDirectory(at: deepDocs, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: deepWorkflows, withIntermediateDirectories: true)
    try "# Deep\n".write(to: deepDocs.appendingPathComponent("deep.md"), atomically: true, encoding: .utf8)
    try "name: Deep\n".write(to: deepWorkflows.appendingPathComponent("deep.yml"), atomically: true, encoding: .utf8)

    let linkedRoot = parent.appendingPathComponent("linked-repo")
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: root)
    XCTAssertTrue(CSAiEMLocalDocumentationSummary.scan(paths: [linkedRoot.path]).isEmpty)
    XCTAssertTrue(CSAiEMLocalWorkflowSummary.scan(paths: [linkedRoot.path]).isEmpty)

    let externalDocs = parent.appendingPathComponent("external-docs")
    let externalWorkflows = parent.appendingPathComponent("external-workflows")
    try FileManager.default.createDirectory(at: externalDocs, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: externalWorkflows, withIntermediateDirectories: true)
    try "# Outside\n".write(to: externalDocs.appendingPathComponent("outside.md"), atomically: true, encoding: .utf8)
    try "name: Outside\n".write(to: externalWorkflows.appendingPathComponent("outside.yml"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("docs/linked"), withDestinationURL: externalDocs)
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(".github/workflows/linked"), withDestinationURL: externalWorkflows)
    let docsWithLink = CSAiEMLocalDocumentationSummary.scanWithWarnings(paths: [root.path])
    XCTAssertFalse(docsWithLink.summaries.contains { $0.title == "Outside" })
    XCTAssertTrue(docsWithLink.warnings.contains("Skipped symlinked documentation entry."))
    let workflowsWithLink = CSAiEMLocalWorkflowSummary.scanWithWarnings(paths: [root.path])
    XCTAssertFalse(workflowsWithLink.summaries.contains { $0.workflowName == "Outside" })
    XCTAssertTrue(workflowsWithLink.warnings.contains("Skipped symlinked workflow entry."))

    let linkedScanRoots = parent.appendingPathComponent("linked-scan-roots")
    try FileManager.default.createDirectory(at: linkedScanRoots.appendingPathComponent(".github"), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedScanRoots.appendingPathComponent("docs"), withDestinationURL: externalDocs)
    try FileManager.default.createSymbolicLink(at: linkedScanRoots.appendingPathComponent(".github/workflows"), withDestinationURL: externalWorkflows)
    XCTAssertTrue(CSAiEMLocalDocumentationSummary.scan(paths: [linkedScanRoots.path]).isEmpty)
    XCTAssertTrue(CSAiEMLocalWorkflowSummary.scan(paths: [linkedScanRoots.path]).isEmpty)

    let shallowDocs = CSAiEMLocalDocumentationSummary.scanWithWarnings(paths: [root.path], maxDepth: 1)
    XCTAssertTrue(shallowDocs.summaries.isEmpty)
    XCTAssertTrue(shallowDocs.warnings.contains("Local documentation walk capped at depth 1."))
    let shallowWorkflows = CSAiEMLocalWorkflowSummary.scanWithWarnings(paths: [root.path], maxDepth: 1)
    XCTAssertTrue(shallowWorkflows.summaries.isEmpty)
    XCTAssertTrue(shallowWorkflows.warnings.contains("Local workflow walk capped at depth 1."))
  }

  private func writeSparseFile(at url: URL, prefix: String, logicalSize: UInt64) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(prefix.utf8).write(to: url)
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seek(toOffset: logicalSize - 1)
    try handle.write(contentsOf: Data([0x0A]))
  }
}
