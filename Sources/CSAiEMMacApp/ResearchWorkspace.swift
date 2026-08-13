import Foundation

struct CSAiEMLocalCodebaseSummary: Identifiable, Hashable, Codable {
  let path: String
  let fileCount: Int
  let sourceFileCount: Int
  let byteCount: Int64
  let topLevelEntries: [String]
  let manifests: [String]
  let dependencyFiles: [String]
  let dependencies: [String]
  let sourceExtensions: [String]
  let hasGit: Bool
  let hasReadme: Bool
  let warnings: [String]

  var id: String { path }

  var summary: String {
    let size = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    let dependencyLabel = dependencies.isEmpty ? "no parsed dependencies" : String(dependencies.count) + " parsed dependencies"
    return String(fileCount) + " files · " + String(sourceFileCount) + " source files · " + size + " · " + dependencyLabel
  }

  static func scan(
    paths: [String],
    maxFiles: Int = 5_000,
    maxDepth: Int = 4
  ) -> [Self] {
    paths
      .map { scan(path: $0, maxFiles: maxFiles, maxDepth: maxDepth) }
      .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
  }

  static func scan(path: String, maxFiles: Int = 5_000, maxDepth: Int = 4) -> Self {
    let root = URL(fileURLWithPath: path).standardizedFileURL
    let fileManager = FileManager.default
    let ignoredDirectories: Set<String> = [".git", "node_modules", ".build", "DerivedData", "Pods", "vendor", "dist", "build"]
    let sourceExtensions: Set<String> = ["c", "cc", "cpp", "h", "hpp", "m", "mm", "swift", "ts", "tsx", "js", "jsx", "vue", "svelte", "py", "rb", "go", "rs", "java", "kt", "cs", "php", "lua", "sh", "ps1", "sql", "html", "css", "scss", "less", "liquid"]
    let dependencyFileNames: Set<String> = ["package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "package.resolved", "package.swift", "cargo.toml", "cargo.lock", "pyproject.toml", "requirements.txt", "poetry.lock", "pipfile", "pipfile.lock", "gemfile", "gemfile.lock", "go.mod", "go.sum", "pom.xml", "build.gradle", "composer.json", "composer.lock", "podfile", "podfile.lock"]
    let manifestNames: Set<String> = ["package.json", "package.swift", "cargo.toml", "pyproject.toml", "requirements.txt", "gemfile", "go.mod", "pom.xml", "build.gradle", "composer.json", "podfile"]

    var fileCount = 0
    var sourceFileCount = 0
    var byteCount: Int64 = 0
    var topLevelEntries: Set<String> = []
    var manifests: Set<String> = []
    var dependencyFiles: Set<String> = []
    var dependencies: Set<String> = []
    var extensionCounts: [String: Int] = [:]
    var warnings: [String] = []

    guard fileManager.fileExists(atPath: root.path) else {
      return Self(path: root.path, fileCount: 0, sourceFileCount: 0, byteCount: 0, topLevelEntries: [], manifests: [], dependencyFiles: [], dependencies: [], sourceExtensions: [], hasGit: false, hasReadme: false, warnings: ["Path does not exist."])
    }

    let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .nameKey]
    let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles], errorHandler: { _, _ in true })
    while let url = enumerator?.nextObject() as? URL {
      let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
      let components = relative.split(separator: "/")
      if url.path.split(separator: "/").contains(where: { ignoredDirectories.contains(String($0)) }) {
        continue
      }
      if components.count > maxDepth + 1 {
        continue
      }
      var isDirectory = ObjCBool(false)
      if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
        continue
      }
      guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)), values.isDirectory != true else {
        continue
      }
      fileCount += 1
      if fileCount > maxFiles {
        warnings.append("File scan capped at " + String(maxFiles) + " entries.")
        break
      }
      byteCount += Int64(values.fileSize ?? 0)
      if let first = components.first { topLevelEntries.insert(String(first)) }
      let name = values.name ?? url.lastPathComponent
      let lowerName = name.lowercased()
      if manifestNames.contains(lowerName) { manifests.insert(name) }
      if dependencyFileNames.contains(lowerName) { dependencyFiles.insert(name) }
      let ext = url.pathExtension.lowercased()
      if sourceExtensions.contains(ext) {
        sourceFileCount += 1
        extensionCounts[ext, default: 0] += 1
      }
      if lowerName == "package.json" { dependencies.formUnion(parsePackageJSONDependencies(at: url)) }
      if lowerName == "requirements.txt" { dependencies.formUnion(parseRequirementsDependencies(at: url)) }
      if lowerName == "go.mod" { dependencies.formUnion(parseGoModuleDependencies(at: url)) }
      if lowerName == "cargo.toml" { dependencies.formUnion(parseCargoDependencies(at: url)) }
    }

    if fileManager.fileExists(atPath: root.appendingPathComponent(".git").path) == false {
      warnings.append("No .git directory was found at this path.")
    }
    if fileManager.fileExists(atPath: root.appendingPathComponent("README.md").path) == false && fileManager.fileExists(atPath: root.appendingPathComponent("README").path) == false {
      warnings.append("No top-level README was found.")
    }

    return Self(
      path: root.path,
      fileCount: fileCount,
      sourceFileCount: sourceFileCount,
      byteCount: byteCount,
      topLevelEntries: topLevelEntries.sorted(),
      manifests: manifests.sorted(),
      dependencyFiles: dependencyFiles.sorted(),
      dependencies: dependencies.sorted(),
      sourceExtensions: extensionCounts.keys.sorted(),
      hasGit: fileManager.fileExists(atPath: root.appendingPathComponent(".git").path),
      hasReadme: fileManager.fileExists(atPath: root.appendingPathComponent("README.md").path) || fileManager.fileExists(atPath: root.appendingPathComponent("README").path),
      warnings: Array(Set(warnings)).sorted()
    )
  }

  private static func readManifest(_ url: URL, limit: Int = 256_000) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    let data = (try? handle.read(upToCount: limit)) ?? Data()
    return String(data: data, encoding: .utf8)
  }

  private static func parsePackageJSONDependencies(at url: URL) -> Set<String> {
    guard let data = readManifest(url)?.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
    let sections = ["dependencies", "devDependencies", "peerDependencies", "optionalDependencies"]
    return Set(sections.flatMap { (object[$0] as? [String: Any])?.keys.map { String($0) } ?? [] })
  }

  private static func parseRequirementsDependencies(at url: URL) -> Set<String> {
    Set((readManifest(url) ?? "").split(whereSeparator: \.isNewline).compactMap { line in
      let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard value.isEmpty == false, value.hasPrefix("#") == false else { return nil }
      return value.split(whereSeparator: { $0 == "=" || $0 == "<" || $0 == ">" || $0 == "!" || $0 == "~" }).first.map(String.init)
    })
  }

  private static func parseGoModuleDependencies(at url: URL) -> Set<String> {
    Set((readManifest(url) ?? "").split(whereSeparator: \.isNewline).compactMap { line in
      let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard value.hasPrefix("module ") == false, value.hasPrefix("require ") == false, value.hasPrefix("replace ") == false, value.contains("/") else { return nil }
      return value.split(whereSeparator: \.isWhitespace).first.map(String.init)
    })
  }

  private static func parseCargoDependencies(at url: URL) -> Set<String> {
    var inDependencies = false
    var result: Set<String> = []
    for line in (readManifest(url) ?? "").split(whereSeparator: \.isNewline) {
      let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if value.hasPrefix("[") { inDependencies = value == "[dependencies]" || value == "[dev-dependencies]"; continue }
      guard inDependencies, let separator = value.firstIndex(of: "=") else { continue }
      let name = value[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
      if name.isEmpty == false, name.hasPrefix("#") == false { result.insert(String(name)) }
    }
    return result
  }
}

struct CSAiEMResearchRepositoryMetadata: Decodable, Hashable {
  struct Branch: Decodable, Hashable {
    let name: String
  }

  struct License: Decodable, Hashable {
    let key: String?
    let name: String?
  }

  struct Language: Decodable, Hashable {
    let name: String?
  }

  struct Count: Decodable, Hashable {
    let totalCount: Int
  }

  let nameWithOwner: String
  let description: String?
  let defaultBranchRef: Branch?
  let isArchived: Bool
  let isFork: Bool
  let homepageUrl: String?
  let licenseInfo: License?
  let primaryLanguage: Language?
  let repositoryTopics: [String]?
  let pushedAt: String?
  let updatedAt: String?
  let createdAt: String?
  let stargazerCount: Int
  let forkCount: Int
  let issues: Count
  let pullRequests: Count

  enum CodingKeys: String, CodingKey {
    case nameWithOwner, description, defaultBranchRef, isArchived, isFork,
      homepageUrl, licenseInfo, primaryLanguage, repositoryTopics, pushedAt,
      updatedAt, createdAt, stargazerCount, forkCount, issues, pullRequests
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    nameWithOwner = try values.decode(String.self, forKey: .nameWithOwner)
    description = try values.decodeIfPresent(String.self, forKey: .description)
    defaultBranchRef = try values.decodeIfPresent(Branch.self, forKey: .defaultBranchRef)
    isArchived = try values.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    isFork = try values.decodeIfPresent(Bool.self, forKey: .isFork) ?? false
    homepageUrl = try values.decodeIfPresent(String.self, forKey: .homepageUrl)
    licenseInfo = try values.decodeIfPresent(License.self, forKey: .licenseInfo)
    primaryLanguage = try values.decodeIfPresent(Language.self, forKey: .primaryLanguage)
    repositoryTopics = try values.decodeIfPresent([String].self, forKey: .repositoryTopics)
    pushedAt = try values.decodeIfPresent(String.self, forKey: .pushedAt)
    updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt)
    createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt)
    stargazerCount = try values.decodeIfPresent(Int.self, forKey: .stargazerCount) ?? 0
    forkCount = try values.decodeIfPresent(Int.self, forKey: .forkCount) ?? 0
    issues = try values.decodeIfPresent(Count.self, forKey: .issues) ?? Count(totalCount: 0)
    pullRequests = try values.decodeIfPresent(Count.self, forKey: .pullRequests) ?? Count(totalCount: 0)
  }
}

struct CSAiEMResearchSnapshot: Identifiable, Hashable, Codable {
  let id: String
  let repository: String
  let capturedAt: Date
  let description: String
  let defaultBranch: String
  let primaryLanguage: String
  let topics: [String]
  let license: String
  let isArchived: Bool
  let isFork: Bool
  let stars: Int
  let forks: Int
  let issueCount: Int
  let pullRequestCount: Int
  let pushedAt: String
  let updatedAt: String
  let localMatches: [String]
  let localSummaries: [CSAiEMLocalCodebaseSummary]
  let riskNotes: [String]
  let relationshipNotes: [String]

  var summary: String {
    let activity = pushedAt.isEmpty ? "activity date unavailable" : "last push " + pushedAt
    let local = localMatches.isEmpty ? "no local path match" : String(localMatches.count) + " local path match" + (localMatches.count == 1 ? "" : "es")
    return repository + " · " + defaultBranch + " · " + primaryLanguage + " · " + activity + " · " + local
  }

  static func build(
    metadata: CSAiEMResearchRepositoryMetadata,
    localMatches: [String],
    localSummaries: [CSAiEMLocalCodebaseSummary] = [],
    capturedAt: Date = Date()
  ) -> Self {
    var risks: [String] = []
    if metadata.isArchived { risks.append("Repository is archived; review before treating it as an active lead.") }
    if metadata.isFork { risks.append("Repository is a fork; compare its upstream relationship before promoting it.") }
    if metadata.defaultBranchRef == nil { risks.append("Default branch metadata is unavailable.") }
    if metadata.licenseInfo == nil { risks.append("License metadata is unavailable.") }
    if metadata.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
      risks.append("Repository description is empty; identity confidence should come from additional evidence.")
    }
    if localMatches.count > 1 { risks.append("Multiple local paths match this repository; inspect shadow-copy relationships before operating.") }

    var relationships: [String] = []
    if localMatches.isEmpty {
      relationships.append("No local project path matched this GitHub repository in the current workspace scan.")
    } else {
      relationships.append("Local matches are evidence for review only; this snapshot does not select a canonical path or authorize a merge.")
    }
    if metadata.isFork { relationships.append("Fork status is provider metadata, not proof that the local copy is a merge candidate.") }
    if metadata.issues.totalCount > 0 || metadata.pullRequests.totalCount > 0 {
      relationships.append("Open work exists remotely; review Issues and Pull Requests before backup or cleanup.")
    }

    return Self(
      id: "research|\(metadata.nameWithOwner)",
      repository: metadata.nameWithOwner,
      capturedAt: capturedAt,
      description: metadata.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
      defaultBranch: metadata.defaultBranchRef?.name ?? "unknown",
      primaryLanguage: metadata.primaryLanguage?.name ?? "unknown",
      topics: (metadata.repositoryTopics ?? []).sorted(),
      license: metadata.licenseInfo?.name ?? metadata.licenseInfo?.key ?? "unknown",
      isArchived: metadata.isArchived,
      isFork: metadata.isFork,
      stars: metadata.stargazerCount,
      forks: metadata.forkCount,
      issueCount: metadata.issues.totalCount,
      pullRequestCount: metadata.pullRequests.totalCount,
      pushedAt: metadata.pushedAt ?? "",
      updatedAt: metadata.updatedAt ?? "",
      localMatches: localMatches.sorted(),
      localSummaries: localSummaries.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending },
      riskNotes: risks,
      relationshipNotes: relationships
    )
  }
}
