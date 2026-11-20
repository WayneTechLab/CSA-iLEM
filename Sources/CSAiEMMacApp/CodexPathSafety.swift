import Darwin
import Foundation

enum CodexPathSafety {
  enum ValidationError: LocalizedError {
    case invalidPath
    case unavailableSource(String)
    case unsafeRoot(String)
    case unreadablePath(String)
    case overlappingRoots(String, String)

    var errorDescription: String? {
      switch self {
      case .invalidPath:
        return "Choose absolute source and destination folder paths without dot components."
      case .unavailableSource(let path):
        return "The Codex source folder is unavailable: \(path). Mount or choose it before transfer."
      case .unsafeRoot(let path):
        return "The Codex transfer root is a symbolic link or is not a directory: \(path). Choose a physical folder."
      case .unreadablePath(let path):
        return "The Codex transfer path could not be resolved safely: \(path). Check its parent folder and permissions."
      case .overlappingRoots(let source, let destination):
        return "Codex source and destination overlap after resolving filesystem paths: \(source) and \(destination). Choose separate folders."
      }
    }
  }

  /// Validates the physical source and destination boundary before a Codex transfer.
  /// The source must exist; a destination may be created under a resolvable directory.
  /// Call again immediately before writes because mounted volumes and symlinks can change.
  nonisolated static func validate(sourcePath: String, destinationPath: String) throws {
    let source = try inspect(sourcePath, mustExist: true)
    let destination = try inspect(destinationPath, mustExist: false)
    if contains(source.physicalPath, destination.physicalPath)
        || contains(destination.physicalPath, source.physicalPath)
        || (source.leafIdentity.map { destination.ancestorIdentities.contains($0) } ?? false)
        || (destination.leafIdentity.map { source.ancestorIdentities.contains($0) } ?? false) {
      throw ValidationError.overlappingRoots(sourcePath, destinationPath)
    }
  }

  private struct InspectedPath {
    let physicalPath: String
    let leafIdentity: String?
    let ancestorIdentities: Set<String>
  }

  private nonisolated static func inspect(_ rawPath: String, mustExist: Bool) throws -> InspectedPath {
    guard rawPath.hasPrefix("/"),
          !rawPath.utf8.contains(0),
          !rawPath.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
      throw ValidationError.invalidPath
    }
    let normalized = URL(fileURLWithPath: rawPath).standardizedFileURL.path
    let components = normalized.split(separator: "/").map(String.init)
    guard !components.isEmpty else { throw ValidationError.invalidPath }

    var rootEntry = stat()
    guard lstat("/", &rootEntry) == 0,
          (rootEntry.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else {
      throw ValidationError.unreadablePath("/")
    }
    let rootIdentity = "\(rootEntry.st_dev):\(rootEntry.st_ino)"

    var cursor = ""
    var nearestExisting = "/"
    var missingComponents: [String] = []
    var identities: Set<String> = [rootIdentity]
    var leafIdentity: String?
    var nearestIdentity = rootIdentity

    for (index, component) in components.enumerated() {
      cursor += "/" + component
      if !missingComponents.isEmpty {
        missingComponents.append(component)
        continue
      }

      var entry = stat()
      if lstat(cursor, &entry) != 0 {
        if errno == ENOENT {
          missingComponents.append(component)
          continue
        }
        throw ValidationError.unreadablePath(cursor)
      }

      let isLeaf = index == components.count - 1
      if (entry.st_mode & mode_t(S_IFMT)) == mode_t(S_IFLNK) {
        if isLeaf { throw ValidationError.unsafeRoot(cursor) }
        var target = stat()
        guard stat(cursor, &target) == 0,
              (target.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else {
          throw ValidationError.unreadablePath(cursor)
        }
        entry = target
      } else if (entry.st_mode & mode_t(S_IFMT)) != mode_t(S_IFDIR) {
        throw ValidationError.unsafeRoot(cursor)
      }

      nearestExisting = cursor
      let identity = "\(entry.st_dev):\(entry.st_ino)"
      identities.insert(identity)
      nearestIdentity = identity
      if isLeaf { leafIdentity = identity }
    }

    if mustExist && !missingComponents.isEmpty {
      throw ValidationError.unavailableSource(rawPath)
    }

    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    guard realpath(nearestExisting, &buffer) != nil else {
      throw ValidationError.unreadablePath(nearestExisting)
    }
    let resolvedAncestor = String(
      decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
      as: UTF8.self
    )
    var resolvedEntry = stat()
    guard stat(resolvedAncestor, &resolvedEntry) == 0,
          "\(resolvedEntry.st_dev):\(resolvedEntry.st_ino)" == nearestIdentity else {
      throw ValidationError.unreadablePath(nearestExisting)
    }
    let physical = missingComponents.reduce(resolvedAncestor) { path, component in
      (path as NSString).appendingPathComponent(component)
    }
    return InspectedPath(
      physicalPath: URL(fileURLWithPath: physical).standardizedFileURL.path,
      leafIdentity: leafIdentity,
      ancestorIdentities: identities
    )
  }

  private nonisolated static func contains(_ parent: String, _ child: String) -> Bool {
    parent == child || parent == "/" || child.hasPrefix(parent + "/")
  }
}
