import Darwin
import Foundation

enum LocalSourceResidualClassification: String, Codable, Sendable {
  case absent
  case empty
  case residualOnly
  case projectContent
  case unverified
}

enum LocalSourceResidualInventoryState: String, Codable, Sendable {
  case complete
  case truncated
  case failed
}

/// Metadata evidence about one explicitly selected source root. This is never
/// a checksum comparison with its destination and cannot authorize deletion.
struct LocalSourceResidualSummary: Codable, Equatable, Sendable {
  let rootPath: String
  let rootExists: Bool
  let classification: LocalSourceResidualClassification
  let state: LocalSourceResidualInventoryState
  let entryCount: Int
  let fileCount: Int
  let directoryCount: Int
  let symlinkCount: Int
  let otherEntryCount: Int
  let logicalByteCount: Int64
  let placeholderCount: Int
  let generatedRootEntryCount: Int
  let finderMetadataRootEntryCount: Int
  let remainingPathSample: [String]
  let errorCount: Int
  let errors: [String]
  let truncationReasons: [String]

  var truncated: Bool { !truncationReasons.isEmpty }
  var metadataOnly: Bool { true }
  var deletionAuthorized: Bool { false }
  var hasPlaceholders: Bool { placeholderCount > 0 }
  var cleanupComplete: Bool { !rootExists && state == .complete && classification == .absent }
  var cleanupIncomplete: Bool { !cleanupComplete }
}

struct LocalSourceResidualRecord: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let sourcePath: String
  let destinationPath: String?
  let summary: LocalSourceResidualSummary
  let scannedAt: Date

  init(sourcePath: String, destinationPath: String? = nil, summary: LocalSourceResidualSummary, scannedAt: Date = Date()) {
    let normalized = (sourcePath as NSString).standardizingPath
    id = normalized
    self.sourcePath = normalized
    self.destinationPath = destinationPath.map { ($0 as NSString).standardizingPath }
    self.summary = summary
    self.scannedAt = scannedAt
  }
}

enum LocalSourceResidualStore {
  /// Missing, unreadable, or malformed evidence throws instead of presenting an
  /// empty report as proof that no unresolved source roots remain.
  static func load(from url: URL) throws -> [LocalSourceResidualRecord] {
    try JSONDecoder().decode([LocalSourceResidualRecord].self, from: Data(contentsOf: url))
  }

  static func save(_ records: [LocalSourceResidualRecord], to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(records)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }
}

enum LocalSourceResidualScanner {
  // Match the native transfer engine's generated-directory exclusions. Finder
  // numbered copies of these directories are leftovers too, not new projects.
  private static let generatedDirectoryNames: Set<String> = [
    "node_modules", "vendor", ".venv", "venv", "pods", "deriveddata",
    "dist", "build", ".build", "target", ".next", ".nuxt", ".output", ".turbo",
    "coverage", ".nyc_output", ".cache", "caches", ".parcel-cache", ".vite",
    ".npm", ".pnpm-store", ".swiftpm", ".gradle", ".terraform", ".dart_tool",
    ".pytest_cache", ".tox", "__pycache__"
  ]

  static func inventory(
    rootPath: String,
    maxEntries: Int = 20_000,
    maxDepth: Int = 32,
    sampleLimit: Int = 12,
    maxDuration: TimeInterval = 2
  ) -> LocalSourceResidualSummary {
    var scan = Inventory(
      rootPath: (rootPath as NSString).standardizingPath,
      maxEntries: max(0, maxEntries),
      maxDepth: max(0, maxDepth),
      sampleLimit: min(128, max(0, sampleLimit)),
      maxDuration: max(0, maxDuration)
    )
    scan.run()
    return scan.summary
  }

  /// Recheck the exact old root after an operation. An empty directory, link,
  /// unreadable root, or truncated inventory still means cleanup is incomplete.
  static func postCleanupSummary(
    rootPath: String,
    maxEntries: Int = 20_000,
    maxDepth: Int = 32,
    sampleLimit: Int = 12,
    maxDuration: TimeInterval = 2
  ) -> LocalSourceResidualSummary {
    inventory(rootPath: rootPath, maxEntries: maxEntries, maxDepth: maxDepth,
              sampleLimit: sampleLimit, maxDuration: maxDuration)
  }

  static func isDatalessFile(flags: UInt32) -> Bool {
    // Darwin exposes this bit in stat.st_flags even on SDKs that omit its name.
    flags & 0x40000000 != 0
  }

  static func entryExistsNoFollow(atPath path: String) throws -> Bool {
    var status = stat()
    if lstat(path, &status) == 0 { return true }
    let failure = errno
    if failure == ENOENT { return false }
    throw NSError(domain: NSPOSIXErrorDomain, code: Int(failure), userInfo: [NSFilePathErrorKey: path])
  }

  private static func isNumberedVariant(_ name: String, of baseName: String) -> Bool {
    let normalized = name.lowercased()
    if normalized == baseName { return true }
    guard normalized.hasPrefix(baseName) else { return false }
    // Match only the suffix after a known basename. Stripping punctuation
    // from the entire name would also strip meaningful trailing underscores
    // from names such as __pycache__-4.
    let suffix = String(normalized.dropFirst(baseName.count))
    return suffix.range(of: #"^(?:[ ._-]+[0-9]+| ?\([0-9]+\))+$"#, options: .regularExpression) != nil
  }

  static func isGeneratedDirectoryName(_ name: String) -> Bool {
    generatedDirectoryNames.contains { isNumberedVariant(name, of: $0) }
  }

  static func isFinderMetadataName(_ name: String) -> Bool {
    isNumberedVariant(name, of: ".ds_store") || name.hasPrefix("._")
  }

  private struct Inventory {
    let rootPath: String
    let maxEntries: Int
    let maxDepth: Int
    let sampleLimit: Int
    let maxDuration: TimeInterval
    let startedAt = ProcessInfo.processInfo.systemUptime
    var rootExists = false
    var rootWasAbsent = false
    var entryCount = 0
    var fileCount = 0
    var directoryCount = 0
    var symlinkCount = 0
    var otherEntryCount = 0
    var logicalByteCount: Int64 = 0
    var placeholderCount = 0
    var generatedRootEntryCount = 0
    var finderMetadataRootEntryCount = 0
    var hasProjectRootContent = false
    var remainingPathSample: [String] = []
    var errorCount = 0
    var errors: [String] = []
    var truncationReasons: [String] = []

    var summary: LocalSourceResidualSummary {
      let state: LocalSourceResidualInventoryState = errorCount > 0 ? .failed : truncationReasons.isEmpty ? .complete : .truncated
      let classification: LocalSourceResidualClassification
      if state != .complete {
        classification = .unverified
      } else if rootWasAbsent {
        classification = .absent
      } else if entryCount == 0 {
        classification = .empty
      } else if hasProjectRootContent {
        classification = .projectContent
      } else {
        classification = .residualOnly
      }
      return LocalSourceResidualSummary(
        rootPath: rootPath, rootExists: rootExists, classification: classification, state: state,
        entryCount: entryCount, fileCount: fileCount, directoryCount: directoryCount,
        symlinkCount: symlinkCount, otherEntryCount: otherEntryCount,
        logicalByteCount: logicalByteCount, placeholderCount: placeholderCount,
        generatedRootEntryCount: generatedRootEntryCount,
        finderMetadataRootEntryCount: finderMetadataRootEntryCount,
        remainingPathSample: remainingPathSample.sorted(), errorCount: errorCount,
        errors: errors, truncationReasons: truncationReasons
      )
    }

    mutating func run() {
      guard rootPath.hasPrefix("/"), rootPath != "/" else {
        recordError("An explicit absolute source folder is required; filesystem root scanning is refused.")
        return
      }
      var rootStatus = stat()
      guard lstat(rootPath, &rootStatus) == 0 else {
        let failure = errno
        if failure == ENOENT {
          rootWasAbsent = true
        } else {
          recordPOSIXError("Cannot inspect source root", relativePath: ".", code: failure)
        }
        return
      }
      rootExists = true
      guard rootStatus.st_mode & S_IFMT == S_IFDIR else {
        if rootStatus.st_mode & S_IFMT == S_IFLNK { symlinkCount = 1 }
        recordError("Source root is not a real directory; symlink targets are never traversed.")
        return
      }
      if LocalSourceResidualScanner.isDatalessFile(flags: rootStatus.st_flags) {
        placeholderCount += 1
        recordError("Source root is dataless; it was not opened or hydrated.")
        return
      }
      let descriptor = open(rootPath, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      guard descriptor >= 0 else {
        recordPOSIXError("Cannot open source root metadata", relativePath: ".", code: errno)
        return
      }
      var openedStatus = stat()
      guard fstat(descriptor, &openedStatus) == 0,
            openedStatus.st_ino == rootStatus.st_ino,
            openedStatus.st_dev == rootStatus.st_dev else {
        close(descriptor)
        recordError("Source root changed while opening its inventory; recheck required.")
        return
      }
      walk(descriptor: descriptor, relativePath: "", depth: 0)
    }

    mutating func walk(descriptor: Int32, relativePath: String, depth: Int) {
      // fdopendir owns this descriptor. O_NOFOLLOW/openat bind traversal to
      // inspected directory entries instead of following links or path swaps.
      guard let directory = fdopendir(descriptor) else {
        let failure = errno
        close(descriptor)
        recordPOSIXError("Cannot enumerate directory metadata", relativePath: relativePath, code: failure)
        return
      }
      defer { closedir(directory) }
      while true {
        if ProcessInfo.processInfo.systemUptime - startedAt >= maxDuration {
          truncate("durationLimit")
          return
        }
        errno = 0
        guard let entry = readdir(directory) else {
          if errno != 0 { recordPOSIXError("Directory enumeration failed", relativePath: relativePath, code: errno) }
          return
        }
        let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
          pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(validatingCString: $0) }
        }
        guard let name else {
          recordError("An unreadable filename was encountered under \(relativePath.isEmpty ? "." : relativePath).")
          continue
        }
        if name == "." || name == ".." { continue }
        guard entryCount < maxEntries else {
          truncate("entryLimit")
          return
        }
        let childPath = relativePath.isEmpty ? name : relativePath + "/" + name
        entryCount += 1
        if remainingPathSample.count < sampleLimit { remainingPathSample.append(childPath) }
        var childStatus = stat()
        guard fstatat(descriptor, name, &childStatus, AT_SYMLINK_NOFOLLOW) == 0 else {
          recordPOSIXError("Cannot inspect entry metadata", relativePath: childPath, code: errno)
          continue
        }
        let kind = childStatus.st_mode & S_IFMT
        if depth == 0 {
          if (kind == S_IFDIR || kind == S_IFLNK) && LocalSourceResidualScanner.isGeneratedDirectoryName(name) {
            generatedRootEntryCount += 1
          } else if kind == S_IFREG && LocalSourceResidualScanner.isFinderMetadataName(name) {
            finderMetadataRootEntryCount += 1
          } else {
            hasProjectRootContent = true
          }
        }
        let dataless = LocalSourceResidualScanner.isDatalessFile(flags: childStatus.st_flags)
        if dataless { placeholderCount += 1 }
        switch kind {
        case S_IFREG:
          fileCount += 1
          let bytes = max(0, Int64(childStatus.st_size))
          let (total, overflow) = logicalByteCount.addingReportingOverflow(bytes)
          if overflow {
            logicalByteCount = .max
            recordError("Logical byte count overflow; inventory requires review.")
          } else { logicalByteCount = total }
        case S_IFLNK:
          symlinkCount += 1
        case S_IFDIR:
          directoryCount += 1
          if dataless {
            recordError("Dataless directory not expanded or hydrated: \(childPath)")
            continue
          }
          guard depth < maxDepth else {
            truncate("depthLimit")
            continue
          }
          let childDescriptor = openat(descriptor, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
          guard childDescriptor >= 0 else {
            recordPOSIXError("Cannot open directory metadata", relativePath: childPath, code: errno)
            continue
          }
          var openedStatus = stat()
          guard fstat(childDescriptor, &openedStatus) == 0,
                openedStatus.st_ino == childStatus.st_ino,
                openedStatus.st_dev == childStatus.st_dev else {
            close(childDescriptor)
            recordError("Directory changed during inventory: \(childPath)")
            continue
          }
          walk(descriptor: childDescriptor, relativePath: childPath, depth: depth + 1)
          if truncationReasons.contains("entryLimit") || truncationReasons.contains("durationLimit") { return }
        default:
          otherEntryCount += 1
          recordError("Special filesystem entry requires review: \(childPath)")
        }
      }
    }

    mutating func recordPOSIXError(_ message: String, relativePath: String, code: Int32) {
      recordError("\(message) at \(relativePath.isEmpty ? "." : relativePath): \(String(cString: strerror(code))) [\(code)]")
    }

    mutating func recordError(_ message: String) {
      errorCount += 1
      if errors.count < 20 { errors.append(message) }
    }

    mutating func truncate(_ reason: String) {
      if !truncationReasons.contains(reason) { truncationReasons.append(reason) }
    }
  }
}
