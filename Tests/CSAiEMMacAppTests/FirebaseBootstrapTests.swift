import Foundation
import XCTest
@testable import CSAiEMMacApp

final class FirebaseBootstrapTests: XCTestCase {
  func testValidCSAConfigPassesWithoutExposingClientFields() throws {
    let configURL = try writeConfiguration()
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

    let document = try CSAiEMFirebaseConfigurationDocument.validated(at: configURL)

    XCTAssertEqual(document.bundleIdentifier, "com.waynetechlab.csa-iem")
    XCTAssertEqual(document.projectIdentifier, "csa-ilem")
  }

  func testBundleMismatchFailsClosed() throws {
    let configURL = try writeConfiguration(bundleIdentifier: "com.example.wrong-app")
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

    XCTAssertThrowsError(try CSAiEMFirebaseConfigurationDocument.validated(at: configURL)) { error in
      XCTAssertEqual(error as? CSAiEMFirebaseConfigurationError, .bundleIdentifierMismatch)
    }
  }

  func testProjectMismatchFailsClosed() throws {
    let configURL = try writeConfiguration(projectIdentifier: "wrong-project")
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

    XCTAssertThrowsError(try CSAiEMFirebaseConfigurationDocument.validated(at: configURL)) { error in
      XCTAssertEqual(error as? CSAiEMFirebaseConfigurationError, .projectIdentifierMismatch)
    }
  }

  func testMissingRequiredClientFieldFailsClosed() throws {
    let configURL = try writeConfiguration(omitting: "API_KEY")
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

    XCTAssertThrowsError(try CSAiEMFirebaseConfigurationDocument.validated(at: configURL)) { error in
      XCTAssertEqual(error as? CSAiEMFirebaseConfigurationError, .missingRequiredField("API_KEY"))
    }
  }

  func testOperatorStatusNeverIncludesFirebaseIdentifiers() {
    let labels = [
      CSAiEMFirebaseBootstrapStatus.notStarted,
      .configured,
      .alreadyConfigured,
      .missingConfiguration,
      .invalidConfiguration,
      .bundleIdentifierMismatch,
      .projectIdentifierMismatch
    ].map(\.safeLogMessage)

    XCTAssertFalse(labels.joined().contains("API_KEY"))
    XCTAssertFalse(labels.joined().contains("GOOGLE_APP_ID"))
    XCTAssertFalse(labels.joined().contains("csa-ilem"))
  }

  private func writeConfiguration(
    bundleIdentifier: String = "com.waynetechlab.csa-iem",
    projectIdentifier: String = "csa-ilem",
    omitting omittedField: String? = nil
  ) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("csa-ilem-firebase-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("GoogleService-Info.plist")
    var values: [String: Any] = [
      "API_KEY": "test-only-public-client-key",
      "BUNDLE_ID": bundleIdentifier,
      "GCM_SENDER_ID": "100000000000",
      "GOOGLE_APP_ID": "1:100000000000:ios:test-only",
      "PROJECT_ID": projectIdentifier
    ]
    if let omittedField {
      values.removeValue(forKey: omittedField)
    }
    let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
    try data.write(to: url, options: .atomic)
    return url
  }
}
