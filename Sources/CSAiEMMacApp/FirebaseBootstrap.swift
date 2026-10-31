import Foundation
import FirebaseCore

enum CSAiEMFirebaseConfigurationError: Error, Equatable {
  case unreadable
  case invalidPropertyList
  case missingRequiredField(String)
  case bundleIdentifierMismatch
  case projectIdentifierMismatch
}

struct CSAiEMFirebaseConfigurationDocument: Equatable {
  static let expectedBundleIdentifier = "com.waynetechlab.csa-iem"
  static let expectedProjectIdentifier = "csa-ilem"
  static let requiredStringFields = [
    "API_KEY",
    "BUNDLE_ID",
    "GCM_SENDER_ID",
    "GOOGLE_APP_ID",
    "PROJECT_ID"
  ]

  let bundleIdentifier: String
  let projectIdentifier: String

  static func validated(at url: URL) throws -> CSAiEMFirebaseConfigurationDocument {
    guard let data = try? Data(contentsOf: url) else {
      throw CSAiEMFirebaseConfigurationError.unreadable
    }
    guard
      let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
      let dictionary = propertyList as? [String: Any]
    else {
      throw CSAiEMFirebaseConfigurationError.invalidPropertyList
    }

    for field in requiredStringFields {
      guard let value = dictionary[field] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw CSAiEMFirebaseConfigurationError.missingRequiredField(field)
      }
    }

    guard dictionary["BUNDLE_ID"] as? String == expectedBundleIdentifier else {
      throw CSAiEMFirebaseConfigurationError.bundleIdentifierMismatch
    }
    guard dictionary["PROJECT_ID"] as? String == expectedProjectIdentifier else {
      throw CSAiEMFirebaseConfigurationError.projectIdentifierMismatch
    }

    return CSAiEMFirebaseConfigurationDocument(
      bundleIdentifier: expectedBundleIdentifier,
      projectIdentifier: expectedProjectIdentifier
    )
  }
}

enum CSAiEMFirebaseBootstrapStatus: String, Equatable {
  case notStarted
  case configured
  case alreadyConfigured
  case missingConfiguration
  case invalidConfiguration
  case bundleIdentifierMismatch
  case projectIdentifierMismatch

  var operatorLabel: String {
    switch self {
    case .notStarted:
      return "Starting"
    case .configured, .alreadyConfigured:
      return "Ready"
    case .missingConfiguration:
      return "Configuration missing"
    case .invalidConfiguration:
      return "Configuration invalid"
    case .bundleIdentifierMismatch:
      return "Bundle mismatch"
    case .projectIdentifierMismatch:
      return "Project mismatch"
    }
  }

  var safeLogMessage: String {
    "Firebase Core: \(operatorLabel.lowercased())."
  }
}

@MainActor
enum CSAiEMFirebaseBootstrap {
  static func configure(bundle: Bundle = .main) -> CSAiEMFirebaseBootstrapStatus {
    if FirebaseApp.app() != nil {
      return .alreadyConfigured
    }

    guard let configurationURL = bundle.url(forResource: "GoogleService-Info", withExtension: "plist") else {
      return .missingConfiguration
    }

    do {
      _ = try CSAiEMFirebaseConfigurationDocument.validated(at: configurationURL)
    } catch CSAiEMFirebaseConfigurationError.bundleIdentifierMismatch {
      return .bundleIdentifierMismatch
    } catch CSAiEMFirebaseConfigurationError.projectIdentifierMismatch {
      return .projectIdentifierMismatch
    } catch {
      return .invalidConfiguration
    }

    guard let options = FirebaseOptions(contentsOfFile: configurationURL.path) else {
      return .invalidConfiguration
    }

    FirebaseApp.configure(options: options)
    return FirebaseApp.app() == nil ? .invalidConfiguration : .configured
  }
}
