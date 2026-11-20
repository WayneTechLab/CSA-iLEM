import Foundation

enum CodexCatalogStatusLoader {
  static func load(
    for store: CodexCatalogStore,
    summarize: @escaping @Sendable (CodexCatalogStore) -> String? = { $0.latestCheckpointSummary() }
  ) async -> String {
    await Task.detached(priority: .utility) {
      let base = store.status
      guard let checkpoint = summarize(store) else { return base }
      return "\(base) · latest checkpoint \(checkpoint)"
    }.value
  }
}
