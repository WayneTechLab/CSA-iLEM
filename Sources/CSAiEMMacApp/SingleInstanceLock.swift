import Darwin
import Foundation

enum CSAiEMSingleInstanceLockResult: Equatable {
  case acquired
  case alreadyRunning
  case unavailable(String)
}

/// Keeps all copies of the native app on the same Mac user account behind one
/// process-level lock. The installer still removes stale bundles; this lock is
/// the runtime defense when an old copy or direct source build is launched.
final class CSAiEMSingleInstanceLock {
  let lockPath: String
  private var fileDescriptor: Int32 = -1

  init(lockPath: String = CSAiEMSingleInstanceLock.defaultLockPath) {
    self.lockPath = lockPath
  }

  deinit {
    release()
  }

  @discardableResult
  func acquire() -> CSAiEMSingleInstanceLockResult {
    if fileDescriptor >= 0 {
      return .acquired
    }

    let descriptor = Darwin.open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
      return .unavailable(Self.errorMessage(for: errno))
    }

    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      let lockError = errno
      Darwin.close(descriptor)
      if lockError == EWOULDBLOCK || lockError == EAGAIN {
        return .alreadyRunning
      }
      return .unavailable(Self.errorMessage(for: lockError))
    }

    fileDescriptor = descriptor
    let pidText = "\(getpid())\n"
    _ = ftruncate(descriptor, 0)
    _ = pidText.withCString { pointer in
      Darwin.write(descriptor, pointer, strlen(pointer))
    }
    return .acquired
  }

  func release() {
    guard fileDescriptor >= 0 else { return }
    _ = flock(fileDescriptor, LOCK_UN)
    Darwin.close(fileDescriptor)
    fileDescriptor = -1
  }

  static var defaultLockPath: String {
    (NSTemporaryDirectory() as NSString)
      .appendingPathComponent("com.waynetechlab.csa-iem.instance.lock")
  }

  private static func errorMessage(for errorNumber: Int32) -> String {
    String(cString: strerror(errorNumber))
  }
}
