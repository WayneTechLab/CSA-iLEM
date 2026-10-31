import XCTest
@testable import CSAiEMMacApp

final class CheckoutDiscoveryRulesTests: XCTestCase {
  private let transactionID = "15AD85CC-ECCF-4A02-9529-6D455C45D349"

  func testExactStageAndBackupTransactionNamesAreRecognized() {
    for prefix in ["Control-Lamma-Command", "Project with spaces", ".hidden-project", "Project_2"] {
      for marker in [".csa-iem-stage-", ".csa-iem-backup-"] {
        XCTAssertTrue(CheckoutDiscoveryRules.isTransferArtifactName(prefix + marker + transactionID))
        XCTAssertTrue(CheckoutDiscoveryRules.isTransferArtifactName(prefix + marker + transactionID.lowercased()))
      }
    }
  }

  func testOrdinaryAndSimilarProjectNamesRemainOrdinary() {
    let ordinary = [
      "", "Control-Lamma-Command", "Command-Lamma-Control", "project.csa-iem-stage-words",
      "project.csa-iem-backup-important", "project.csa-iem-stage-" + transactionID + "-notes",
      "project.csa-iem-backup-" + transactionID + ".git",
      "project.CSA-IEM-STAGE-" + transactionID,
      "project.csa-iem-source-20261031-004500", "CSA-iEM-staging-" + transactionID,
      "_temp", "project.csa-iem-stage", "project.csa-iem-backup"
    ]
    for name in ordinary {
      XCTAssertFalse(CheckoutDiscoveryRules.isTransferArtifactName(name), name)
    }
  }

  func testOnlyAnExactUUIDSuffixAndNonemptyPrefixMatch() {
    let rejected = [
      ".csa-iem-stage-" + transactionID, ".csa-iem-backup-" + transactionID,
      "project.csa-iem-stage-15AD85CC-ECCF-4A02-9529-6D455C45D34",
      "project.csa-iem-stage-15AD85CC-ECCF-4A02-9529-6D455C45D34Z",
      "project.csa-iem-stage-15AD85CCECCF4A0295296D455C45D349",
      "project.csa-iem-stage-{\(transactionID)}",
      "project.csa-iem-stage-" + transactionID + "\n",
      "path/project.csa-iem-stage-" + transactionID,
      "project.csa-iem-stage-" + transactionID + "/",
      "project\0.csa-iem-stage-" + transactionID
    ]
    for name in rejected {
      XCTAssertFalse(CheckoutDiscoveryRules.isTransferArtifactName(name), name)
    }
  }
}
