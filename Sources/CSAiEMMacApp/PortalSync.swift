import CryptoKit
import Darwin
import Foundation
import Security
import SwiftUI

enum PortalWorkspaceArea: String, Codable, Sendable {
  case code, importStaging = "import", runtime, local

  var label: String {
    switch self {
    case .code: return "Code"
    case .importStaging: return "Import staging"
    case .runtime: return "Runtime"
    case .local: return "Local checkout"
    }
  }
}

struct PortalProject: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let location: String
  let area: PortalWorkspaceArea
  let repository: String?

  init(name: String, path: String, area: PortalWorkspaceArea = .local, origin: String? = nil) {
    id = Self.localPath(path)
    self.name = name
    location = id
    self.area = area
    if let identity = CheckoutRemoteIdentity.parse(origin), identity.host == "github.com",
       identity.owner.utf8.count <= 100, identity.repository.utf8.count <= 100 {
      repository = "\(identity.owner)/\(identity.repository)"
    } else {
      repository = nil
    }
  }

  static func localPath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.path
  }
}

private struct PortalCredential: Codable {
  let deviceId: String
  let secret: String

  static func make() throws -> Self {
    var bytes = Data(count: 32)
    let status = bytes.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
    }
    guard status == errSecSuccess else { throw PortalSyncError.local("Could not create a device credential.") }
    let token = bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return Self(deviceId: UUID().uuidString.lowercased(), secret: token)
  }
}

private struct PortalKeychain {
  let service: String

  private var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
     kSecAttrAccount as String: "paired-device", kSecAttrSynchronizable as String: false]
  }

  func read() throws -> PortalCredential? {
    let lookup = query.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, new in new }
    var result: CFTypeRef?
    let status = SecItemCopyMatching(lookup as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw PortalSyncError.local("The device credential could not be read from Keychain.")
    }
    return try JSONDecoder().decode(PortalCredential.self, from: data)
  }

  func save(_ value: PortalCredential) throws {
    let data = try JSONEncoder().encode(value)
    let update = [kSecValueData as String: data]
    var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw PortalSyncError.local("The device credential could not be saved in Keychain.")
    }
  }

  func remove() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw PortalSyncError.local("The device credential could not be removed from Keychain.")
    }
  }
}

private struct PortalServiceFailure: Decodable { let error: String }

private enum PortalSyncError: LocalizedError {
  case local(String)
  case service(status: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .local(let message), .service(_, let message): return message
    }
  }
}

private struct PortalSyncRow: Codable, Equatable {
  let id: String
  let name: String
  let location: String
  var projectId: String?
  var verifiedAt: String?
  var repository: String?
  var area: PortalWorkspaceArea?
  var available: Bool?
  var isExport: Bool?
}

private struct PortalSyncBatch: Codable {
  let version: Int
  let batchId: String
  let projects: [PortalSyncRow]
  let backups: [PortalSyncRow]

  init(projects: [PortalSyncRow], backups: [PortalSyncRow]) {
    version = 1
    batchId = UUID().uuidString.lowercased()
    self.projects = projects
    self.backups = backups
  }
}

private struct PortalSyncState: Codable {
  var namespace = UUID().uuidString
  var deviceId: String?
  var selected: Set<String> = []
  var sharePaths = false
  var automatic = false
  var revoked = false
  var previousProjects: [PortalSyncRow] = []
  var outbox: [PortalSyncBatch] = []
  var lastSuccessfulSync: Date?
}

private final class PortalNoRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

@MainActor
final class PortalSyncModel: ObservableObject {
  @Published private(set) var message = "Pair your Mac from the web portal to share selected metadata."
  @Published private(set) var busy = false
  @Published private var state = PortalSyncState()
  private var credential: PortalCredential?
  private var pendingCredential: PortalCredential?
  private var retry: Task<Void, Never>?
  private var retryDelay = 2.0
  private let endpoint: URL
  private let stateFile: URL
  private let keychain: PortalKeychain
  private let transport: URLSession
  let portalURL: URL

  #if DEBUG
  var simulateConnectionLoss = false
  #endif

  var paired: Bool { credential != nil }
  var revoked: Bool { state.revoked }
  var selected: Set<String> { state.selected }
  var automatic: Bool { state.automatic }
  var sharePaths: Bool { state.sharePaths }
  var queuedCount: Int { state.outbox.reduce(0) { $0 + $1.projects.count + $1.backups.count } }
  var lastSync: Date? { state.lastSuccessfulSync }

  init(
    stateDirectory: URL,
    endpoint: URL = URL(string: "https://us-west1-csa-ilem.cloudfunctions.net")!,
    portalURL: URL = URL(string: "https://csa-ilem.web.app/devices/pair")!,
    keychainService: String = "com.waynetechlab.csa-iem.portal"
  ) {
    self.endpoint = endpoint
    self.portalURL = portalURL
    stateFile = stateDirectory.appendingPathComponent("portal-sync.json")
    keychain = PortalKeychain(service: keychainService)
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 12
    config.timeoutIntervalForResource = 20
    config.httpShouldSetCookies = false
    transport = URLSession(configuration: config, delegate: PortalNoRedirects(), delegateQueue: nil)

    if FileManager.default.fileExists(atPath: stateFile.path) {
      do {
        state = try JSONDecoder().decode(PortalSyncState.self, from: Data(contentsOf: stateFile))
        let stored = try keychain.read()
        if let stored, state.deviceId == stored.deviceId {
          credential = stored
          message = state.revoked ? "Device access was revoked. Disconnect this Mac, then pair again." : "This Mac is paired."
        } else if state.deviceId != nil {
          message = "The saved connection is unavailable. Pair this Mac again."
        }
      } catch {
        message = "The saved connection could not be opened. Review this Mac’s connection before pairing again."
      }
    }
  }

  private func persist(_ next: PortalSyncState) throws {
    let directory = stateFile.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(next)
    let temporary = directory.appendingPathComponent(".portal-sync-\(UUID().uuidString)")
    guard FileManager.default.createFile(atPath: temporary.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
      throw PortalSyncError.local("Could not save the local sync queue.")
    }
    defer { try? FileManager.default.removeItem(at: temporary) }
    if rename(temporary.path, stateFile.path) != 0 { throw PortalSyncError.local("Could not save the local sync queue.") }
    state = next
  }

  private func digest(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  private func bounded(_ value: String, length: Int) -> String {
    String(decoding: value.trimmingCharacters(in: .whitespacesAndNewlines).utf16.prefix(length), as: UTF16.self)
  }

  private func transmit<Payload: Encodable, Reply: Decodable>(
    _ function: String, body: Payload, using key: PortalCredential? = nil
  ) async throws -> Reply {
    #if DEBUG
    if simulateConnectionLoss { throw URLError(.notConnectedToInternet) }
    #endif
    var request = URLRequest(url: endpoint.appendingPathComponent(function))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let key { request.setValue("Bearer \(key.deviceId).\(key.secret)", forHTTPHeaderField: "Authorization") }
    request.httpBody = try JSONEncoder().encode(body)
    let (data, response) = try await transport.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw PortalSyncError.local("The portal service did not respond.") }
    guard (200...299).contains(http.statusCode) else {
      let error = try? JSONDecoder().decode(PortalServiceFailure.self, from: data)
      throw PortalSyncError.service(status: http.statusCode, message: error?.error ?? "The portal could not complete this request.")
    }
    return try JSONDecoder().decode(Reply.self, from: data)
  }

  func pair(code: String, name: String, projects: [PortalProject], selection: Set<String>, allowPaths: Bool) async -> Bool {
    guard !paired, !busy else { return false }
    let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleanCode.range(of: #"^[A-Za-z0-9_-]{32}$"#, options: .regularExpression) != nil,
          !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      message = "Enter a fresh pairing code and device name."
      return false
    }
    struct Claim: Encodable {
      let code: String
      let deviceId: String
      let credentialHash: String
      let name: String
      let sharePaths: Bool
    }
    struct Paired: Decodable {
      let deviceId: String
      let sharePaths: Bool
    }
    busy = true
    defer { busy = false }
    do {
      let key = try pendingCredential ?? PortalCredential.make()
      pendingCredential = key
      let reply: Paired = try await transmit("claimDevicePairCode", body: Claim(
        code: cleanCode, deviceId: key.deviceId, credentialHash: digest(key.secret),
        name: bounded(name, length: 120), sharePaths: allowPaths
      ))
      guard reply.deviceId == key.deviceId else { throw PortalSyncError.local("The pairing response could not be verified.") }
      var next = PortalSyncState()
      next.deviceId = key.deviceId
      next.sharePaths = reply.sharePaths
      next.selected = selection.intersection(Set(projects.map(\.id)))
      try keychain.save(key)
      try persist(next)
      credential = key
      pendingCredential = nil
      message = "Mac paired. Sync now to send the selected projects."
      return true
    } catch {
      message = error.localizedDescription
      return false
    }
  }

  func disconnect() {
    guard !busy else { return }
    do {
      try keychain.remove()
      try persist(PortalSyncState())
      retry?.cancel()
      credential = nil
      pendingCredential = nil
      message = "Disconnected on this Mac. Review device access in the portal."
    } catch { message = error.localizedDescription }
  }

  func setSelection(_ selection: Set<String>, projects: [PortalProject]) {
    guard paired, !revoked, !busy else { return }
    var next = state
    next.selected = selection
    let allowed = Set(selection.map { digest(state.namespace + $0) })
    next.previousProjects = next.previousProjects.filter { allowed.contains($0.id) }
    next.outbox = state.outbox.compactMap { batch in
      let selectedProjects = batch.projects.filter { allowed.contains($0.id) }
      let selectedBackups = batch.backups.filter { record in
        record.projectId.map { allowed.contains($0) } ?? false
      }
      if selectedProjects.isEmpty && selectedBackups.isEmpty { return nil }
      if selectedProjects == batch.projects && selectedBackups == batch.backups { return batch }
      return PortalSyncBatch(projects: selectedProjects, backups: selectedBackups)
    }
    do {
      try persist(next)
      observeProjects(projects)
    } catch { message = error.localizedDescription }
  }

  func setAutomatic(_ enabled: Bool, projects: [PortalProject]) {
    guard paired, !revoked else { return }
    var next = state
    next.automatic = enabled
    do {
      try persist(next)
      if enabled { syncNow(projects: projects) }
      else { retry?.cancel(); retry = nil }
    } catch { message = error.localizedDescription }
  }

  private func projectRow(_ project: PortalProject) -> PortalSyncRow {
    PortalSyncRow(
      id: digest(state.namespace + project.id), name: bounded(project.name, length: 120),
      location: state.sharePaths ? bounded(project.location, length: 1000) : "",
      repository: project.repository, area: project.area, available: true
    )
  }

  private func queueProjects(_ projects: [PortalProject], force: Bool) throws {
    let current = projects.filter { state.selected.contains($0.id) }.map(projectRow)
    let currentIDs = Set(current.map(\.id))
    let selectedIDs = Set(state.selected.map { digest(state.namespace + $0) })
    let missing = state.previousProjects.filter { selectedIDs.contains($0.id) && !currentIDs.contains($0.id) }.map { old in
      var row = old
      row.available = false
      return row
    }
    let rows = (current + missing).sorted { $0.id < $1.id }
    let previous = Dictionary(uniqueKeysWithValues: state.previousProjects.map { ($0.id, $0) })
    let updates = force ? rows : rows.filter { previous[$0.id] != $0 }
    guard !updates.isEmpty else { return }
    var next = state
    for start in stride(from: 0, to: updates.count, by: 12) {
      next.outbox.append(PortalSyncBatch(projects: Array(updates[start..<min(start + 12, updates.count)]), backups: []))
    }
    next.previousProjects = rows
    try persist(next)
  }

  func observeProjects(_ projects: [PortalProject]) {
    guard paired, automatic, !revoked else { return }
    do { try queueProjects(projects, force: false); sendQueue() }
    catch { message = error.localizedDescription }
  }

  func syncNow(projects: [PortalProject]) {
    guard paired, !revoked, !busy else { return }
    do {
      try queueProjects(projects, force: state.outbox.isEmpty)
      if state.outbox.isEmpty { message = "Select a project to sync." }
      sendQueue()
    } catch { message = error.localizedDescription }
  }

  func saveVerifiedBackup(
    project: PortalProject, artifact: String, receipt: String, verifiedAt: Date, isExport: Bool = false
  ) {
    guard paired, !revoked, state.selected.contains(project.id) else { return }
    var projectRecord = projectRow(project)
    projectRecord.available = (try? URL(fileURLWithPath: project.location).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    let backup = PortalSyncRow(
      id: digest(state.namespace + receipt),
      name: bounded(project.name + (isExport ? " verified export" : " verified backup"), length: 120),
      location: state.sharePaths ? bounded(artifact, length: 1000) : "",
      projectId: projectRecord.id, verifiedAt: ISO8601DateFormatter().string(from: verifiedAt),
      isExport: isExport ? true : nil
    )
    var next = state
    next.outbox.append(PortalSyncBatch(projects: [projectRecord], backups: [backup]))
    next.previousProjects.removeAll { $0.id == projectRecord.id }
    next.previousProjects.append(projectRecord)
    do {
      try persist(next)
      if automatic { sendQueue() }
      else { message = "Verified backup queued. Use Sync now to send it." }
    } catch { message = error.localizedDescription }
  }

  private func sendQueue() {
    guard let credential, !revoked, !busy, !state.outbox.isEmpty else { return }
    retry?.cancel()
    retry = nil
    busy = true
    message = "Sending selected metadata…"
    Task {
      defer { busy = false }
      do {
        while let batch = state.outbox.first {
          struct Acknowledgement: Decodable { let synced: Int }
          let _: Acknowledgement = try await transmit("syncLinkedDevice", body: batch, using: credential)
          var next = state
          next.outbox.removeFirst()
          next.lastSuccessfulSync = Date()
          try persist(next)
        }
        retryDelay = 2
        message = "Workspace metadata synced."
      } catch PortalSyncError.service(let code, let description) {
        if code == 401 || code == 403 {
          var next = state
          next.revoked = true
          next.automatic = false
          try? persist(next)
          message = "Device access was revoked or could not be verified. Review the connection in the portal."
        } else {
          message = "Sync queued. \(description)"
          if code >= 500 { scheduleRetry() }
        }
      } catch {
        message = "Sync queued. Reconnect or use Sync now to retry."
        scheduleRetry()
      }
    }
  }

  private func scheduleRetry() {
    guard automatic, !revoked else { return }
    let delay = retryDelay
    retryDelay = min(delay * 2, 60)
    retry = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      self?.sendQueue()
    }
  }
}

struct PortalSyncPane: View {
  @ObservedObject var model: PortalSyncModel
  let projects: [PortalProject]
  var refreshing = false
  var refresh: (() -> Void)?
  var openInCodex: ((PortalProject) -> Void)?
  @State private var code = ""
  @State private var deviceName = Host.current().localizedName ?? "CSA-iEM Mac"
  @State private var sharePaths = false
  @State private var approved = false
  @State private var draftSelection: Set<String> = []
  @State private var search = ""

  private var selected: Set<String> { model.paired ? model.selected : draftSelection }

  private var visibleProjects: [PortalProject] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return projects }
    return projects.filter { project in
      [project.name, project.repository ?? "", project.area.label, project.location]
        .contains { $0.localizedCaseInsensitiveContains(term) }
    }
  }

  private func updateSelection(_ selection: Set<String>) {
    if model.paired {
      model.setSelection(selection, projects: projects)
    } else {
      draftSelection = selection
      approved = false
    }
  }

  var body: some View {
    GroupBox("Cloud workspace sync") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Share selected checkouts, their GitHub repositories, workspace areas, and verified export or backup receipts.")
          .font(.subheadline)
        HStack {
          Link("Open Pair a Mac", destination: model.portalURL)
          if let refresh {
            Button("Refresh workspace inventory", action: refresh).disabled(refreshing)
          }
          if refreshing { ProgressView().controlSize(.small) }
        }
        if !model.paired {
          TextField("Device name", text: $deviceName)
          SecureField("Pairing code", text: $code)
          Toggle("Allow exact paths in project and backup records", isOn: $sharePaths)
        }
        if projects.isEmpty {
          Text("Scan or import a project to make it available for sharing.").foregroundStyle(.secondary)
        } else {
          Text("Checkouts to share").font(.headline)
          HStack {
            TextField("Find a project, repository, or folder", text: $search)
            Button("Select visible") {
              updateSelection(selected.union(visibleProjects.map(\.id)))
            }.disabled(model.busy || model.revoked || refreshing || visibleProjects.isEmpty)
            Button("Clear selection") { updateSelection([]) }
              .disabled(model.busy || model.revoked || refreshing || selected.isEmpty)
          }
          Text("\(projects.filter { selected.contains($0.id) }.count) current folders selected")
            .font(.caption).foregroundStyle(.secondary)
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 9) {
              ForEach(visibleProjects) { project in
                HStack(alignment: .top) {
                  Toggle(isOn: Binding(
                    get: { selected.contains(project.id) },
                    set: { enabled in
                      var next = selected
                      if enabled { next.insert(project.id) } else { next.remove(project.id) }
                      updateSelection(next)
                    }
                  )) {
                    VStack(alignment: .leading, spacing: 2) {
                      Text(project.name)
                      Text([project.area.label, project.repository].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                      Text(project.location).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                  }
                  .disabled(model.busy || model.revoked || refreshing)
                  Spacer()
                  if let openInCodex {
                    Button("Open in Codex") { openInCodex(project) }
                      .accessibilityLabel("Open \(project.name) in Codex")
                  }
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxHeight: 240)
        }
        if model.paired {
          Text(model.revoked ? "Access revoked" : model.sharePaths ? "Paired · exact paths enabled" : "Paired · exact paths stay on this Mac")
          Toggle("Automatically sync selected metadata", isOn: Binding(
            get: { model.automatic }, set: { model.setAutomatic($0, projects: projects) }
          )).disabled(model.revoked || refreshing)
          HStack {
            Button("Sync now") { model.syncNow(projects: projects) }.disabled(model.busy || model.revoked || refreshing)
            Button("Disconnect locally") { model.disconnect() }.disabled(model.busy)
          }
          Text("\(model.queuedCount) queued · Last successful sync: \(model.lastSync?.formatted() ?? "None")")
            .font(.caption).foregroundStyle(.secondary)
        } else {
          Toggle("I approve sharing the selected metadata", isOn: $approved)
          Button("Pair this Mac") {
            Task {
              if await model.pair(code: code, name: deviceName, projects: projects, selection: draftSelection, allowPaths: sharePaths) {
                code = ""
                approved = false
              }
            }
          }.disabled(!approved || code.isEmpty || model.busy || refreshing)
        }
        Text(model.message).foregroundStyle(.secondary).textSelection(.enabled)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
    }
    .onChange(of: sharePaths) { _ in approved = false }
  }
}
