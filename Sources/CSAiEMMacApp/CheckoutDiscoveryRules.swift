import Foundation

enum CheckoutDiscoveryRules {
  /// Recognize a transaction-shaped basename for separate, visible review.
  /// A matching name is not proof that the directory is disposable: callers
  /// must retain it and its evidence until its contents are verified.
  static func isTransferArtifactName(_ name: String) -> Bool {
    guard !name.isEmpty, !name.contains("/"), !name.contains("\0") else { return false }
    for marker in [".csa-iem-stage-", ".csa-iem-backup-"] {
      guard let suffixStart = name.range(of: marker, options: .backwards),
            suffixStart.lowerBound != name.startIndex else { continue }
      let suffix = String(name[suffixStart.upperBound...])
      guard suffix.utf8.count == 36, let transactionID = UUID(uuidString: suffix) else { continue }
      if transactionID.uuidString.caseInsensitiveCompare(suffix) == .orderedSame {
        return true
      }
    }
    return false
  }
}
