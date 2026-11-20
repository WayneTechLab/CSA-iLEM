import CryptoKit
import Darwin
import Foundation

/// A bounded-memory, complete read-back for large local transfer trees.
/// Checkout review keeps its smaller, detailed per-path manifest; native Move
/// and snapshot restore use this streaming digest so large roots remain usable.
struct StreamingTreeFingerprint: Sendable {
  let rootDevice: Int64
  let rootInode: UInt64
  let digest: String
  let fileCount: Int64
  let directoryCount: Int64
  let symlinkCount: Int64
  let totalBytes: Int64

  func hasSamePayload(as other: Self) -> Bool {
    digest == other.digest && fileCount == other.fileCount &&
      directoryCount == other.directoryCount && symlinkCount == other.symlinkCount &&
      totalBytes == other.totalBytes
  }
}

enum StreamingTreeVerifier {
  private struct Record: Encodable {
    let relativePath: String
    let kind: String
    let mode: UInt32
    let mtimeNanoseconds: Int64
    let flags: UInt32
    let size: Int64
    let contentSHA256: String?
    let linkTarget: String?
    let xattrSHA256: String
  }

  /// The deadline applies to one complete scan. No global file or byte count
  /// limit is imposed; only one directory's names and one file buffer are held.
  static func fingerprint(
    path: String,
    repairDittoLinkTimesAt destination: String? = nil,
    maxDuration: TimeInterval = 14_400,
    maxEntriesForTesting: Int64? = nil
  ) throws -> StreamingTreeFingerprint {
    guard maxDuration > 0 else { throw failure("A positive verification deadline is required.") }
    var initial = stat()
    guard lstat(path, &initial) == 0, initial.st_mode & S_IFMT == S_IFDIR else {
      throw failure("Transfer source must be a real, readable directory: \(path)")
    }
    guard initial.st_flags & 0x40000000 == 0 else {
      throw failure("A cloud placeholder blocked full transfer verification: \(path)")
    }
    let physical = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    let sourceFD = open(physical, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard sourceFD >= 0 else { throw posixFailure("Could not open transfer source") }
    var sourceOwned = true
    defer { if sourceOwned { close(sourceFD) } }
    let rootCheckFD = dup(sourceFD)
    guard rootCheckFD >= 0 else { throw posixFailure("Could not pin transfer source") }
    defer { close(rootCheckFD) }
    var opened = stat()
    guard fstat(sourceFD, &opened) == 0, opened.st_dev == initial.st_dev, opened.st_ino == initial.st_ino else {
      throw failure("Transfer source changed while opening.")
    }

    var repairFD: Int32? = nil
    if let destination {
      var destinationStatus = stat()
      guard lstat(destination, &destinationStatus) == 0,
            destinationStatus.st_mode & S_IFMT == S_IFDIR else {
        throw failure("The staged transfer is not a real directory: \(destination)")
      }
      let physicalDestination = URL(fileURLWithPath: destination).resolvingSymlinksInPath().path
      let fd = open(physicalDestination, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      guard fd >= 0 else { throw posixFailure("Could not open staged transfer") }
      var openedDestination = stat()
      guard fstat(fd, &openedDestination) == 0,
            openedDestination.st_dev == destinationStatus.st_dev,
            openedDestination.st_ino == destinationStatus.st_ino else {
        close(fd)
        throw failure("The staged transfer changed while opening.")
      }
      repairFD = fd
    }
    defer { if let repairFD { close(repairFD) } }

    let started = ProcessInfo.processInfo.systemUptime
    let rootAttributes = try attributes(fd: rootCheckFD)
    var builder = Builder(started: started, maxDuration: maxDuration, maxEntries: maxEntriesForTesting)
    try builder.append(Record(relativePath: "", kind: "root", mode: mode(initial),
      mtimeNanoseconds: nanoseconds(initial), flags: initial.st_flags, size: 0,
      contentSHA256: nil, linkTarget: nil, xattrSHA256: rootAttributes))
    sourceOwned = false // walk transfers ownership to fdopendir/closedir.
    try builder.walk(sourceFD, repairFD: repairFD, relative: "", depth: 0)
    var final = stat(), finalPath = stat()
    guard fstat(rootCheckFD, &final) == 0, lstat(path, &finalPath) == 0,
          sameStatus(initial, final), sameStatus(initial, finalPath),
          try attributes(fd: rootCheckFD) == rootAttributes else {
      throw failure("Transfer source changed during complete read-back: \(path)")
    }
    return StreamingTreeFingerprint(rootDevice: Int64(initial.st_dev), rootInode: UInt64(initial.st_ino),
      digest: hex(builder.hasher.finalize()), fileCount: builder.files,
      directoryCount: builder.directories, symlinkCount: builder.links, totalBytes: builder.bytes)
  }

  static func verifyCopy(
    from source: String,
    to destination: String,
    repairDittoLinkTimes: Bool = false,
    maxDuration: TimeInterval = 14_400
  ) throws -> StreamingTreeFingerprint {
    let sourceProof = try fingerprint(path: source,
      repairDittoLinkTimesAt: repairDittoLinkTimes ? destination : nil,
      maxDuration: maxDuration)
    let destinationProof = try fingerprint(path: destination, maxDuration: maxDuration)
    guard sourceProof.rootDevice != destinationProof.rootDevice ||
          sourceProof.rootInode != destinationProof.rootInode else {
      throw failure("Transfer source and destination are the same physical directory; the original was preserved.")
    }
    guard sourceProof.hasSamePayload(as: destinationProof) else {
      throw failure("Complete transfer read-back found missing or changed content or metadata at \(destination). The source was preserved.")
    }
    // The destination scan can be long; re-read the source before callers are
    // allowed to remove it. A changed tree is never accepted as copied.
    let freshSourceProof = try fingerprint(path: source, maxDuration: maxDuration)
    guard sourceProof.hasSamePayload(as: freshSourceProof),
          sourceProof.rootDevice == freshSourceProof.rootDevice,
          sourceProof.rootInode == freshSourceProof.rootInode else {
      throw failure("Transfer source changed after destination read-back; the source was preserved.")
    }
    return sourceProof
  }

  private struct Builder {
    let started: TimeInterval
    let maxDuration: TimeInterval
    let maxEntries: Int64?
    var hasher = SHA256()
    var files: Int64 = 0
    var directories: Int64 = 0
    var links: Int64 = 0
    var bytes: Int64 = 0
    var entries: Int64 = 0
    let encoder: JSONEncoder = {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      return encoder
    }()

    mutating func bound() throws {
      guard ProcessInfo.processInfo.systemUptime - started < maxDuration else {
        throw failure("Complete transfer read-back exceeded its \(Int(maxDuration))-second deadline; the source was preserved.")
      }
      if let maxEntries, entries >= maxEntries {
        throw failure("Complete transfer read-back reached its test entry bound; the source was preserved.")
      }
    }

    mutating func append(_ record: Record) throws {
      try bound()
      let data = try encoder.encode(record)
      var length = UInt64(data.count).bigEndian
      withUnsafeBytes(of: &length) { hasher.update(data: Data($0)) }
      hasher.update(data: data)
      let (next, overflow) = entries.addingReportingOverflow(1)
      guard !overflow else { throw failure("Transfer entry count overflowed; the source was preserved.") }
      entries = next
    }

    mutating func walk(_ fd: Int32, repairFD: Int32?, relative: String, depth: Int) throws {
      guard depth < 256 else { close(fd); throw failure("Transfer directory depth exceeded the safe limit.") }
      var before = stat()
      guard fstat(fd, &before) == 0 else { close(fd); throw posixFailure("Could not inspect transfer directory") }
      let beforeAttributes: String
      do { beforeAttributes = try attributes(fd: fd) }
      catch { close(fd); throw error }
      guard let directory = fdopendir(fd) else { close(fd); throw posixFailure("Could not enumerate transfer directory") }
      defer { closedir(directory) }
      var names: [String] = []
      while true {
        try bound()
        errno = 0
        guard let entry = readdir(directory) else {
          if errno != 0 { throw posixFailure("Could not read transfer directory") }
          break
        }
        let decoded = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
          pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(validatingCString: $0) }
        }
        guard let name = decoded else { throw failure("A transfer filename could not be decoded safely.") }
        if name != "." && name != ".." { names.append(name) }
      }
      guard Set(names).count == names.count else { throw failure("Transfer directory changed during enumeration.") }
      names.sort()
      for name in names {
        try bound()
        let path = relative.isEmpty ? name : relative + "/" + name
        var entryStatus = stat()
        guard fstatat(fd, name, &entryStatus, AT_SYMLINK_NOFOLLOW) == 0 else {
          throw posixFailure("Could not inspect transfer entry: \(path)")
        }
        guard entryStatus.st_flags & 0x40000000 == 0 else {
          throw failure("A cloud placeholder blocked complete transfer verification: \(path)")
        }
        let kind = entryStatus.st_mode & S_IFMT
        if kind == S_IFDIR {
          let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
          guard child >= 0 else { throw posixFailure("Could not open transfer directory: \(path)") }
          var actual = stat()
          guard fstat(child, &actual) == 0, sameStatus(entryStatus, actual) else {
            close(child); throw failure("Transfer directory changed while opening: \(path)")
          }
          let attrs: String
          do { attrs = try attributes(fd: child) }
          catch { close(child); throw error }
          do {
            try append(Record(relativePath: path, kind: "directory", mode: mode(entryStatus),
              mtimeNanoseconds: nanoseconds(entryStatus), flags: entryStatus.st_flags, size: 0,
              contentSHA256: nil, linkTarget: nil, xattrSHA256: attrs))
          } catch { close(child); throw error }
          let (next, overflow) = directories.addingReportingOverflow(1)
          guard !overflow else { close(child); throw failure("Transfer directory count overflowed.") }
          directories = next
          if let repairFD {
            let repairChild = openat(repairFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard repairChild >= 0 else { close(child); throw failure("A staged transfer directory is missing: \(path)") }
            do { try walk(child, repairFD: repairChild, relative: path, depth: depth + 1) }
            catch { close(repairChild); throw error }
            close(repairChild)
          } else {
            try walk(child, repairFD: nil, relative: path, depth: depth + 1)
          }
        } else if kind == S_IFREG {
          let file = openat(fd, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
          guard file >= 0 else { throw posixFailure("Could not read transfer file: \(path)") }
          defer { close(file) }
          var opened = stat()
          guard fstat(file, &opened) == 0, sameStatus(entryStatus, opened) else {
            throw failure("Transfer file changed while opening: \(path)")
          }
          let attrs = try attributes(fd: file)
          let (nextBytes, overflow) = bytes.addingReportingOverflow(entryStatus.st_size)
          guard !overflow else { throw failure("Transfer byte count overflowed.") }
          bytes = nextBytes
          var fileHash = SHA256()
          var buffer = [UInt8](repeating: 0, count: 1_048_576)
          while true {
            try bound()
            let count = Darwin.read(file, &buffer, buffer.count)
            guard count >= 0 else { throw posixFailure("Could not read transfer file: \(path)") }
            if count == 0 { break }
            fileHash.update(data: Data(buffer.prefix(count)))
          }
          var after = stat()
          guard fstat(file, &after) == 0, sameStatus(entryStatus, after),
                try attributes(fd: file) == attrs else {
            throw failure("Transfer file changed during hashing: \(path)")
          }
          try append(Record(relativePath: path, kind: "file", mode: mode(entryStatus),
            mtimeNanoseconds: nanoseconds(entryStatus), flags: entryStatus.st_flags,
            size: entryStatus.st_size, contentSHA256: hex(fileHash.finalize()),
            linkTarget: nil, xattrSHA256: attrs))
          let (next, countOverflow) = files.addingReportingOverflow(1)
          guard !countOverflow else { throw failure("Transfer file count overflowed.") }
          files = next
        } else if kind == S_IFLNK {
          let link = openat(fd, name, O_RDONLY | O_SYMLINK | O_CLOEXEC)
          guard link >= 0 else { throw posixFailure("Could not open transfer link: \(path)") }
          defer { close(link) }
          var opened = stat()
          guard fstat(link, &opened) == 0, sameStatus(entryStatus, opened) else {
            throw failure("Transfer link changed while opening: \(path)")
          }
          let attrs = try attributes(fd: link)
          var targetBuffer = [CChar](repeating: 0, count: 65_537)
          let count = readlinkat(fd, name, &targetBuffer, targetBuffer.count - 1)
          guard count >= 0, count < targetBuffer.count - 1,
                let target = String(bytes: targetBuffer.prefix(count).map { UInt8(bitPattern: $0) }, encoding: .utf8) else {
            throw failure("Could not decode transfer link: \(path)")
          }
          var after = stat()
          guard fstat(link, &after) == 0, sameStatus(entryStatus, after),
                try attributes(fd: link) == attrs else {
            throw failure("Transfer link changed during read-back: \(path)")
          }
          if let repairFD {
            var targetStatus = stat()
            guard fstatat(repairFD, name, &targetStatus, AT_SYMLINK_NOFOLLOW) == 0,
                  targetStatus.st_mode & S_IFMT == S_IFLNK else {
              throw failure("A staged transfer link is missing: \(path)")
            }
            let seconds = entryStatus.st_mtimespec.tv_sec
            let nanos = entryStatus.st_mtimespec.tv_nsec
            var times = [timespec(tv_sec: 0, tv_nsec: Int(UTIME_OMIT)),
                         timespec(tv_sec: seconds, tv_nsec: nanos)]
            guard utimensat(repairFD, name, &times, AT_SYMLINK_NOFOLLOW) == 0 else {
              throw posixFailure("Could not preserve staged link timestamp: \(path)")
            }
          }
          try append(Record(relativePath: path, kind: "symlink", mode: mode(entryStatus),
            mtimeNanoseconds: nanoseconds(entryStatus), flags: entryStatus.st_flags,
            size: entryStatus.st_size, contentSHA256: nil, linkTarget: target,
            xattrSHA256: attrs))
          let (next, overflow) = links.addingReportingOverflow(1)
          guard !overflow else { throw failure("Transfer link count overflowed.") }
          links = next
        } else {
          throw failure("A special filesystem entry requires separate preservation: \(path)")
        }
      }
      var after = stat()
      guard fstat(fd, &after) == 0, sameStatus(before, after),
            try attributes(fd: fd) == beforeAttributes else {
        throw failure("Transfer directory changed during full read-back: \(relative)")
      }
    }
  }

  private static func attributes(fd: Int32) throws -> String {
    let count = flistxattr(fd, nil, 0, 0)
    guard count >= 0, count <= 1_048_576 else { throw posixFailure("Could not list extended attributes") }
    var hasher = SHA256()
    if count == 0 { return hex(hasher.finalize()) }
    var raw = [CChar](repeating: 0, count: count)
    guard flistxattr(fd, &raw, count, 0) == count else {
      throw failure("Extended-attribute names changed during verification.")
    }
    let names = try raw.map { UInt8(bitPattern: $0) }.split(separator: 0).map { part -> String in
      guard let name = String(bytes: part, encoding: .utf8) else {
        throw failure("An extended-attribute name could not be decoded safely.")
      }
      return name
    }.sorted()
    guard Set(names).count == names.count else { throw failure("Extended-attribute names changed during verification.") }
    var captured = 0
    for name in names {
      let size = fgetxattr(fd, name, nil, 0, 0, 0)
      guard size >= 0, size <= 16 * 1_024 * 1_024 else {
        throw posixFailure("Could not read extended-attribute length")
      }
      let (next, overflow) = captured.addingReportingOverflow(size + name.utf8.count)
      guard !overflow, next <= 64 * 1_024 * 1_024 else {
        throw failure("One entry's extended attributes exceeded the 64 MB verification limit.")
      }
      captured = next
      var data = Data(count: size)
      let actual = data.withUnsafeMutableBytes { fgetxattr(fd, name, $0.baseAddress, size, 0, 0) }
      guard actual == size else { throw failure("Extended-attribute bytes changed during verification.") }
      updateLengthPrefixed(Data(name.utf8), into: &hasher)
      updateLengthPrefixed(data, into: &hasher)
    }
    return hex(hasher.finalize())
  }

  private static func updateLengthPrefixed(_ data: Data, into hasher: inout SHA256) {
    var length = UInt64(data.count).bigEndian
    withUnsafeBytes(of: &length) { hasher.update(data: Data($0)) }
    hasher.update(data: data)
  }

  private static func mode(_ value: stat) -> UInt32 { UInt32(value.st_mode & 0o7777) }
  private static func nanoseconds(_ value: stat) -> Int64 {
    Int64(value.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(value.st_mtimespec.tv_nsec)
  }
  private static func changeNanoseconds(_ value: stat) -> Int64 {
    Int64(value.st_ctimespec.tv_sec) * 1_000_000_000 + Int64(value.st_ctimespec.tv_nsec)
  }
  private static func sameStatus(_ first: stat, _ second: stat) -> Bool {
    first.st_dev == second.st_dev && first.st_ino == second.st_ino &&
      first.st_mode == second.st_mode && first.st_size == second.st_size &&
      nanoseconds(first) == nanoseconds(second) &&
      changeNanoseconds(first) == changeNanoseconds(second) &&
      first.st_flags == second.st_flags
  }
  private static func hex<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
    bytes.map { String(format: "%02x", $0) }.joined()
  }
  private static func failure(_ message: String) -> NSError {
    NSError(domain: "CSA-iEM.StreamingTreeVerifier", code: 1,
      userInfo: [NSLocalizedDescriptionKey: message])
  }
  private static func posixFailure(_ message: String) -> NSError {
    failure("\(message): \(String(cString: strerror(errno)))")
  }
}
