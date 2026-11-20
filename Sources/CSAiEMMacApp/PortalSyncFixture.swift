import Foundation
import SwiftUI

enum PortalSyncFixture {
  static var requested: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("--portal-sync-fixture")
    #else
    false
    #endif
  }

  #if DEBUG
  struct Session: Decodable {
    let url: URL
    let project: String
    let functions: String
    let ready: Bool
  }

  static func load() throws -> (endpoint: URL, portal: URL, directory: URL) {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "--portal-sync-fixture"), index + 1 < args.count else { throw invalid() }
    let file = URL(fileURLWithPath: args[index + 1]).standardizedFileURL
    guard file.lastPathComponent == "session.json",
          file.deletingLastPathComponent().lastPathComponent == ".portal-local",
          let details = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
          details.isRegularFile == true, details.isSymbolicLink != true,
          let size = details.fileSize, size < 64_000 else { throw invalid() }
    let session = try JSONDecoder().decode(Session.self, from: Data(contentsOf: file))
    guard session.ready, session.project == "demo-csa-iem", session.url.scheme == "http",
          session.url.host == "127.0.0.1", session.url.port != nil,
          let endpoint = URL(string: "http://\(session.functions)/demo-csa-iem/us-west1"),
          endpoint.host == "127.0.0.1", let port = endpoint.port,
          endpoint.path == "/demo-csa-iem/us-west1" else { throw invalid() }
    let folder = file.deletingLastPathComponent().appendingPathComponent("native-\(port)", isDirectory: true)
    return (endpoint, session.url.appendingPathComponent("devices/pair"), folder)
  }

  private static func invalid() -> CocoaError { CocoaError(.fileReadCorruptFile) }
  #endif
}

#if DEBUG
struct PortalSyncFixtureRoot: View {
  var body: some View {
    if let scope = try? PortalSyncFixture.load() {
      PortalSyncFixtureWindow(endpoint: scope.endpoint, portal: scope.portal, directory: scope.directory)
    } else {
      Text("Start the CSA-iEM local session before opening its debug Mac app.").padding(24)
    }
  }
}

private struct PortalSyncFixtureWindow: View {
  let directory: URL
  let project: PortalProject
  @StateObject private var model: PortalSyncModel
  @State private var fixtureStatus = ""
  @State private var offline = false
  @State private var makingBackup = false

  init(endpoint: URL, portal: URL, directory: URL) {
    self.directory = directory
    project = PortalProject(name: "Emulator Test Workspace", path: directory.appendingPathComponent("Development Project", isDirectory: true).path)
    _model = StateObject(wrappedValue: PortalSyncModel(
      stateDirectory: directory, endpoint: endpoint, portalURL: portal,
      keychainService: "com.waynetechlab.csa-iem.portal.fixture.\(directory.lastPathComponent)"
    ))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Settings").font(.largeTitle.bold())
        Text("Local Firebase test workspace").foregroundStyle(.secondary)
        PortalSyncPane(model: model, projects: [project])
        GroupBox("Fixture backup") {
          VStack(alignment: .leading, spacing: 10) {
            Toggle("Simulate lost connection", isOn: $offline).onChange(of: offline) { newValue in
              model.simulateConnectionLoss = newValue
            }
            Button("Create and verify fixture backup") { verifyFixture() }
              .disabled(makingBackup)
            if !fixtureStatus.isEmpty { Text(fixtureStatus).textSelection(.enabled) }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
        }
      }
      .padding(22)
    }
    .frame(minWidth: 530, minHeight: 670)
  }

  private func verifyFixture() {
    let projectPath = project.location
    let backup = directory.appendingPathComponent("Recovery", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    makingBackup = true
    Task {
      defer { makingBackup = false }
      do {
        let proof = try await Task.detached(priority: .utility) {
          let files = FileManager.default
          let source = URL(fileURLWithPath: projectPath, isDirectory: true)
          try files.createDirectory(at: source, withIntermediateDirectories: true)
          try "CSA-iEM emulator fixture\n".write(to: source.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
          try files.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
          let copy = Process()
          copy.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
          copy.arguments = [source.path, backup.path]
          try copy.run()
          copy.waitUntilExit()
          guard copy.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
          return try StreamingTreeVerifier.verifyCopy(from: source.path, to: backup.path)
        }.value
        fixtureStatus = "Fixture backup verified. \(proof.fileCount) file read back successfully."
        model.saveVerifiedBackup(project: project, artifact: backup.path, receipt: backup.lastPathComponent, verifiedAt: Date())
      } catch { fixtureStatus = "Fixture backup did not verify: \(error.localizedDescription)" }
    }
  }
}
#endif
