import Foundation

enum TransferArtifactSessionHistory {
  static let pageSize = 20

  static func updating(
    _ history: [TransferArtifactCleanupSession],
    with session: TransferArtifactCleanupSession
  ) -> [TransferArtifactCleanupSession] {
    [session] + history.filter { $0.reviewID != session.reviewID }
  }

  static func matching(
    _ history: [TransferArtifactCleanupSession],
    query: String
  ) -> [TransferArtifactCleanupSession] {
    let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !search.isEmpty else { return history }
    return history.filter { session in
      [session.reviewID, session.phase, session.reviewPath, session.resultPath,
       session.createdAt.formatted(date: .abbreviated, time: .shortened)]
        .contains { $0.localizedCaseInsensitiveContains(search) }
    }
  }

  static func visible(
    _ history: [TransferArtifactCleanupSession],
    query: String,
    count: Int
  ) -> [TransferArtifactCleanupSession] {
    Array(matching(history, query: query).prefix(max(pageSize, count)))
  }
}
