import Foundation
import XCTest
@testable import CSAiEMMacApp

final class CheckoutRemoteIdentityTests: XCTestCase {
  func testTransportCaseSuffixAndTrailingSlashVariantsShareIdentity() throws {
    let variants = [
      "git@github.com:WayneTechLab/Command-Lamma-Control.git",
      "https://github.com/WayneTechLab/Command-Lamma-Control",
      "ssh://git@GITHUB.COM:22/WayneTechLab/Command-Lamma-Control.GIT/",
      "git://github.com:9418/WayneTechLab/Command-Lamma-Control.git///",
      "HTTP://github.com:80/WayneTechLab/Command-Lamma-Control.GIT",
      "https://github.com.:443/WayneTechLab/Command-Lamma-Control.git/"
    ]
    for raw in variants {
      let identity = try XCTUnwrap(CheckoutRemoteIdentity.parse(raw))
      XCTAssertEqual(identity.host, "github.com")
      XCTAssertEqual(identity.owner, "WayneTechLab")
      XCTAssertEqual(identity.repository, "Command-Lamma-Control")
      XCTAssertEqual(identity.groupingKey, "github.com/waynetechlab/command-lamma-control")
      XCTAssertEqual(identity.browserURL, "https://github.com/WayneTechLab/Command-Lamma-Control")
    }
    XCTAssertEqual(CheckoutIdentityRelation.compare(variants[0], variants[2]), .sameOrigin)
  }

  func testCredentialsQueryAndFragmentNeverReachStoredOrDisplayFields() throws {
    let raw = "https://synthetic-user:synthetic-password@github.com/WayneTechLab/Command-Lamma-Control.GIT/?token=synthetic-query#synthetic-fragment"
    let identity = try XCTUnwrap(CheckoutRemoteIdentity.parse(raw))
    let encoded = try JSONEncoder().encode(identity)
    let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
    XCTAssertFalse(text.contains("synthetic"))
    XCTAssertFalse(identity.browserURL.contains("@"))
    XCTAssertFalse(identity.browserURL.contains("?"))
    XCTAssertFalse(identity.browserURL.contains("#"))
    XCTAssertEqual(identity.groupingKey, "github.com/waynetechlab/command-lamma-control")
    XCTAssertEqual(try JSONDecoder().decode(CheckoutRemoteIdentity.self, from: encoded), identity)
  }

  func testSCPUserInfoAndQueryAreSanitized() throws {
    let identity = try XCTUnwrap(CheckoutRemoteIdentity.parse("synthetic-user@github.com:Owner/Repo.git?token=synthetic-query@unrelated.example#synthetic-fragment"))
    XCTAssertEqual(identity.browserURL, "https://github.com/Owner/Repo")
    XCTAssertEqual(identity.groupingKey, "github.com/owner/repo")
  }

  func testLocalDisabledUnsupportedAndMalformedValuesRemainUnknown() {
    let invalid: [String?] = [
      nil, "", "   ", "/Users/example/project", "../project", "C:\\Repos\\project",
      "file:///Users/example/project", "disabled://template-upstream",
      "ftp://github.com/owner/repo", "https://github.com/owner",
      "https://github.com/owner/repo/tree/main", "https://github.com/owner//repo",
      "https://github.com/owner/..", "https://github.com/%2e%2e/repo",
      "https://github.com/owner%2frepo/other", "https://github.com/owner/repo%252fother",
      "https://github.com/%2fowner/repo", "https://github.com/owner/repo%2f",
      "https://github.com/owner/repo name", "https://github.com/owner/repo\nother",
      "https://github..com/owner/repo", "https://-github.com/owner/repo",
      "https://127.0.0.1/owner/repo", "ssh://git@localhost/owner/repo",
      "git@github.com:", "git@github.com:owner/", "https:github.com/owner/repo",
      "https://github.com:8443/owner/repo", "ssh://git@github.com:2222/owner/repo"
    ]
    for raw in invalid {
      XCTAssertNil(CheckoutRemoteIdentity.parse(raw), "Should remain unknown: \(String(describing: raw))")
      XCTAssertEqual(CheckoutIdentityRelation.compare(raw, "https://github.com/owner/repo"), .unknown)
    }
  }

  func testDifferentRepositoryOrHostDoesNotGroupBySimilarFolderWords() {
    let canonical = "https://github.com/WayneTechLab/Command-Lamma-Control.git"
    XCTAssertEqual(CheckoutIdentityRelation.compare(canonical, "https://github.com/WayneTechLab/Control-Lamma-Command.git"), .differentOrigins)
    XCTAssertEqual(CheckoutIdentityRelation.compare(canonical, "https://git.example.test/WayneTechLab/Command-Lamma-Control.git"), .differentOrigins)
    XCTAssertEqual(CheckoutIdentityRelation.compare(canonical, "https://www.github.com/WayneTechLab/Command-Lamma-Control.git"), .differentOrigins)
  }

  func testPercentEncodedSafeComponentsDecodeOnceAndGitSuffixStripsOnce() throws {
    let identity = try XCTUnwrap(CheckoutRemoteIdentity.parse("https://github.com/%57ayneTechLab/Repo.git.git/"))
    XCTAssertEqual(identity.owner, "WayneTechLab")
    XCTAssertEqual(identity.repository, "Repo.git")
    XCTAssertEqual(identity.groupingKey, "github.com/waynetechlab/repo.git")
    XCTAssertEqual(try JSONDecoder().decode(CheckoutRemoteIdentity.self, from: JSONEncoder().encode(identity)), identity)
  }

  func testDecodedEvidenceCannotSupplyUnsafeOrInconsistentDisplayFields() throws {
    let unsafe = Data(#"{"host":"token@github.com","owner":"owner","repository":"repo"}"#.utf8)
    let inconsistent = Data(#"{"host":"github.com","owner":"owner","repository":"repo","browserURL":"https://unrelated.example/owner/repo"}"#.utf8)
    XCTAssertThrowsError(try JSONDecoder().decode(CheckoutRemoteIdentity.self, from: unsafe))
    XCTAssertThrowsError(try JSONDecoder().decode(CheckoutRemoteIdentity.self, from: inconsistent))
  }
}
