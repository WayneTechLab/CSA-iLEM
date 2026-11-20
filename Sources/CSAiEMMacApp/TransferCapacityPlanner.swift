import Darwin
import Foundation

/// Estimates the space needed before a verified copy begins. This planner
/// reads metadata through no-follow directory descriptors and keeps only one
/// directory's names in memory. The later checksum verifier remains the
/// authority for content and metadata equality.
enum TransferCapacityPlanner {
  struct Copy: Sendable {
    let source: String
    let destination: String
  }

  struct Usage: Equatable, Sendable {
    var logicalBytes: UInt64 = 0
    var entries: UInt64 = 0
    var files: UInt64 = 0
    var directories: UInt64 = 0
    var symlinks: UInt64 = 0
  }

  struct VolumePlan: Sendable {
    let device: Int64
    let destination: String
    let sourceUsage: Usage
    let requiredBytes: UInt64
    let availableBytes: UInt64
  }

  private struct CapacityError: LocalizedError {
    let detail: String
    var errorDescription: String? { detail }
  }

  static func ensureAvailable(
    for copies: [Copy],
    maxDuration: TimeInterval = 3_600,
    fixedMarginBytes: UInt64 = 512 * 1_024 * 1_024
  ) throws -> [VolumePlan] {
    struct Group {
      var usage = Usage()
      var destination: String
      var availableBytes: UInt64
    }
    var groups: [Int64: Group] = [:]
    let deadline = ProcessInfo.processInfo.systemUptime + max(0, maxDuration)
    for copy in copies {
      let source = (copy.source as NSString).standardizingPath
      let destination = (copy.destination as NSString).standardizingPath
      guard source.hasPrefix("/"), destination.hasPrefix("/"),
            source != destination, !destination.hasPrefix(source + "/") else {
        throw CapacityError(detail: "A copy source and destination overlap; no files were moved.")
      }
      try requireMountedVolumeIfNeeded(destination)
      let remaining = deadline - ProcessInfo.processInfo.systemUptime
      guard remaining > 0 else {
        throw CapacityError(detail: "Copy capacity review exceeded its time limit; no files were moved.")
      }
      let usage = try inspect(path: source, maxDuration: remaining)
      let ancestor = try existingDestinationAncestor(destination)
      var fs = statfs()
      guard statfs(ancestor, &fs) == 0 else {
        throw posixFailure("Could not inspect destination free space")
      }
      var ancestorStatus = stat()
      guard lstat(ancestor, &ancestorStatus) == 0, ancestorStatus.st_mode & S_IFMT == S_IFDIR else {
        throw CapacityError(detail: "Destination parent changed before capacity review; no files were moved.")
      }
      let device = Int64(ancestorStatus.st_dev)
      let (available, availableOverflow) = UInt64(fs.f_bavail).multipliedReportingOverflow(by: UInt64(fs.f_bsize))
      guard !availableOverflow else { throw CapacityError(detail: "Destination free-space calculation overflowed; no files were moved.") }
      var group = groups[device] ?? Group(destination: destination, availableBytes: available)
      group.usage = try adding(group.usage, usage)
      group.availableBytes = min(group.availableBytes, available)
      groups[device] = group
    }
    let plans = try groups.map { device, group in
      VolumePlan(device: device, destination: group.destination, sourceUsage: group.usage,
        requiredBytes: try requiredBytes(for: group.usage, fixedMarginBytes: fixedMarginBytes),
        availableBytes: group.availableBytes)
    }.sorted { $0.device < $1.device }
    for plan in plans { try requireSpace(requiredBytes: plan.requiredBytes, availableBytes: plan.availableBytes, destination: plan.destination) }
    return plans
  }

  static func requiredBytes(for usage: Usage, fixedMarginBytes: UInt64 = 512 * 1_024 * 1_024) throws -> UInt64 {
    // Logical file length conservatively estimates a copy of sparse or
    // compressed files. Reserve one allocation block per entry, ten percent
    // for attributes/filesystem overhead, and a fixed free-space buffer.
    let (entryOverhead, entryOverflow) = usage.entries.multipliedReportingOverflow(by: 4_096)
    guard !entryOverflow else { throw CapacityError(detail: "Transfer capacity estimate overflowed; no files were moved.") }
    let (withEntries, firstOverflow) = usage.logicalBytes.addingReportingOverflow(entryOverhead)
    let (withPercent, secondOverflow) = withEntries.addingReportingOverflow(usage.logicalBytes / 10)
    let (required, thirdOverflow) = withPercent.addingReportingOverflow(fixedMarginBytes)
    guard !firstOverflow, !secondOverflow, !thirdOverflow else {
      throw CapacityError(detail: "Transfer capacity estimate overflowed; no files were moved.")
    }
    return required
  }

  static func requireSpace(requiredBytes: UInt64, availableBytes: UInt64, destination: String) throws {
    guard requiredBytes <= availableBytes else {
      throw CapacityError(detail: "Insufficient free space for verified copy near \(destination): \(format(requiredBytes)) required, \(format(availableBytes)) available. The source was preserved.")
    }
  }

  static func inspect(path: String, maxDuration: TimeInterval = 3_600) throws -> Usage {
    let root = (path as NSString).standardizingPath
    guard root.hasPrefix("/") else { throw CapacityError(detail: "A copy source must be an absolute folder.") }
    try requireMountedVolumeIfNeeded(root)
    var initial = stat()
    guard lstat(root, &initial) == 0, initial.st_mode & S_IFMT == S_IFDIR else {
      throw CapacityError(detail: "A copy source must be a real, readable directory: \(root)")
    }
    guard initial.st_flags & 0x40000000 == 0 else {
      throw CapacityError(detail: "A cloud placeholder source must be downloaded before a verified copy: \(root)")
    }
    let rootFD = open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard rootFD >= 0 else { throw posixFailure("Could not open copy source") }
    var opened = stat()
    guard fstat(rootFD, &opened) == 0, sameStatus(initial, opened) else {
      close(rootFD)
      throw CapacityError(detail: "Copy source changed while opening; no files were moved.")
    }
    var scanner = Scanner(deadline: ProcessInfo.processInfo.systemUptime + max(0, maxDuration))
    scanner.usage.entries = 1
    scanner.usage.directories = 1
    try scanner.walk(fd: rootFD, depth: 0)
    var final = stat()
    guard lstat(root, &final) == 0, sameStatus(initial, final) else {
      throw CapacityError(detail: "Copy source changed during capacity review; no files were moved.")
    }
    return scanner.usage
  }

  private struct Scanner {
    let deadline: TimeInterval
    var usage = Usage()

    mutating func walk(fd: Int32, depth: Int) throws {
      guard depth < 256 else {
        close(fd)
        throw CapacityError(detail: "Copy source exceeds the supported directory depth; no files were moved.")
      }
      guard let directory = fdopendir(fd) else {
        let error = posixFailure("Could not enumerate copy source")
        close(fd)
        throw error
      }
      defer { closedir(directory) }
      var before = stat()
      guard fstat(fd, &before) == 0 else { throw posixFailure("Could not inspect copy source directory") }
      var names: [String] = []
      while true {
        try checkDeadline()
        errno = 0
        guard let entry = readdir(directory) else {
          if errno != 0 { throw posixFailure("Could not read copy source directory") }
          break
        }
        let decoded = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
          pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(validatingCString: $0) }
        }
        guard let name = decoded else { throw CapacityError(detail: "A source filename could not be decoded safely.") }
        if name != "." && name != ".." { names.append(name) }
      }
      names.sort()
      for name in names {
        try checkDeadline()
        var entry = stat()
        guard fstatat(fd, name, &entry, AT_SYMLINK_NOFOLLOW) == 0 else { throw posixFailure("Could not inspect source entry") }
        guard entry.st_flags & 0x40000000 == 0 else { throw CapacityError(detail: "A cloud placeholder blocked copy capacity review.") }
        usage.entries = try plus(usage.entries, 1)
        switch entry.st_mode & S_IFMT {
        case S_IFDIR:
          let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
          guard child >= 0 else { throw posixFailure("Could not open source directory") }
          var actual = stat()
          guard fstat(child, &actual) == 0, sameStatus(entry, actual) else {
            close(child)
            throw CapacityError(detail: "A source directory changed while opening; no files were moved.")
          }
          usage.directories = try plus(usage.directories, 1)
          try walk(fd: child, depth: depth + 1)
        case S_IFREG:
          guard entry.st_size >= 0 else { throw CapacityError(detail: "Invalid source file length blocked capacity review.") }
          usage.files = try plus(usage.files, 1)
          usage.logicalBytes = try plus(usage.logicalBytes, UInt64(entry.st_size))
        case S_IFLNK:
          usage.symlinks = try plus(usage.symlinks, 1)
        default:
          throw CapacityError(detail: "A special source file requires separate review before copying.")
        }
      }
      var after = stat()
      guard fstat(fd, &after) == 0, sameStatus(before, after) else {
        throw CapacityError(detail: "A source directory changed during capacity review; no files were moved.")
      }
    }

    private func checkDeadline() throws {
      guard ProcessInfo.processInfo.systemUptime < deadline else {
        throw CapacityError(detail: "Copy capacity review exceeded its time limit; no files were moved.")
      }
    }
  }

  private static func existingDestinationAncestor(_ raw: String) throws -> String {
    var candidate = (raw as NSString).standardizingPath
    guard candidate.hasPrefix("/") else { throw CapacityError(detail: "Destination must be an absolute path.") }
    while true {
      var info = stat()
      if lstat(candidate, &info) == 0 {
        guard info.st_mode & S_IFMT == S_IFDIR else {
          throw CapacityError(detail: "Destination parent is not a real directory: \(candidate)")
        }
        return candidate
      }
      guard errno == ENOENT else { throw posixFailure("Could not inspect destination parent") }
      let parent = (candidate as NSString).deletingLastPathComponent
      guard parent != candidate else { throw CapacityError(detail: "No destination filesystem is available.") }
      candidate = parent
    }
  }

  private static func requireMountedVolumeIfNeeded(_ path: String) throws {
    let components = path.split(separator: "/")
    guard components.count >= 2, components[0] == "Volumes" else { return }
    let mountPath = "/Volumes/\(components[1])"
    var info = stat()
    guard lstat(mountPath, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
      throw CapacityError(detail: "External volume is not mounted at \(mountPath); no files were moved.")
    }
    var fs = statfs()
    guard statfs(mountPath, &fs) == 0 else { throw posixFailure("Could not inspect external volume mount") }
    let actualMount = withUnsafePointer(to: &fs.f_mntonname) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
    }
    guard actualMount == mountPath else {
      throw CapacityError(detail: "External volume is not mounted at \(mountPath); no files were moved.")
    }
  }

  private static func adding(_ first: Usage, _ second: Usage) throws -> Usage {
    Usage(logicalBytes: try plus(first.logicalBytes, second.logicalBytes),
      entries: try plus(first.entries, second.entries),
      files: try plus(first.files, second.files),
      directories: try plus(first.directories, second.directories),
      symlinks: try plus(first.symlinks, second.symlinks))
  }

  private static func plus(_ first: UInt64, _ second: UInt64) throws -> UInt64 {
    let (value, overflow) = first.addingReportingOverflow(second)
    guard !overflow else { throw CapacityError(detail: "Transfer size or entry count overflowed; no files were moved.") }
    return value
  }

  private static func sameStatus(_ a: stat, _ b: stat) -> Bool {
    a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_mode == b.st_mode &&
      a.st_size == b.st_size && a.st_flags == b.st_flags &&
      a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
      a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
  }

  private static func format(_ bytes: UInt64) -> String {
    String(format: "%.2f GiB", Double(bytes) / 1_073_741_824)
  }

  private static func posixFailure(_ detail: String) -> NSError {
    NSError(domain: "CSA-iEM.TransferCapacity", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "\(detail): \(String(cString: strerror(errno)))"])
  }
}
