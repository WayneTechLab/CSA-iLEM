import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

private let appTitle = "CSA-iEM"
private let appFullName = "Container Setup & Action Import Engine Manager"
private let appSubtitle = "Codespaces & Actions -> Into Local Environment Mac"
private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.3"
private let companyName = "Wayne Tech Lab LLC"
private let companyWebsite = "www.WayneTechLab.com"
private let companyWebsiteURL = "https://www.WayneTechLab.com"
private let publicDefaultRoot = NSString(string: "~/CSA-iEM").expandingTildeInPath
private let genericSplitCodeDefaultRoot = (publicDefaultRoot as NSString).appendingPathComponent("Code")
private let genericSplitRuntimeDefaultRoot = (publicDefaultRoot as NSString).appendingPathComponent("Runtime")
private let wtlDefaultRoot = "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH"
private let diamondCodeDefaultRoot = "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-X/GH"
private let diamondRuntimeDefaultRoot = "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH"
private let configBaseDir = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
  ?? NSString(string: "~/.config").expandingTildeInPath
private let profileConfigDir = (configBaseDir as NSString).appendingPathComponent("csa-iem")
private let legacyProfileConfigDir = (configBaseDir as NSString).appendingPathComponent("csa-ilem")
private let appSupportDir = NSString(string: "~/Library/Application Support/CSA-iEM").expandingTildeInPath
private let lastSessionFile = (appSupportDir as NSString).appendingPathComponent("last-session.env")
private let settingsFile = (appSupportDir as NSString).appendingPathComponent("settings.json")
private let contextsFile = (appSupportDir as NSString).appendingPathComponent("contexts.json")
private let taskTemplatesFile = (appSupportDir as NSString).appendingPathComponent("task-templates.json")
private let favoriteProjectsFile = (appSupportDir as NSString).appendingPathComponent("favorite-projects.json")
private let savedViewsFile = (appSupportDir as NSString).appendingPathComponent("saved-project-views.json")
private let snapshotsDirectory = (appSupportDir as NSString).appendingPathComponent("Snapshots")
private let legacyAppSupportDir = NSString(string: "~/Library/Application Support/CSA-iLEM").expandingTildeInPath
private let legacyLastSessionFile = (legacyAppSupportDir as NSString).appendingPathComponent("last-session.env")
private let cleanerAppSupportDir = NSString(string: "~/Library/Application Support/GH Workflow Clean").expandingTildeInPath
private let cleanerLastSessionFile = (cleanerAppSupportDir as NSString).appendingPathComponent("last-session.env")
private let legacyCleanerAppSupportDir = NSString(string: "~/Library/Application Support/GitHub Action Clean-Up Tool").expandingTildeInPath
private let legacyCleanerLastSessionFile = (legacyCleanerAppSupportDir as NSString).appendingPathComponent("last-session.env")
private let bundledHelpDirectory = "Help"
private let defaultSearchPaths = [
  "/opt/homebrew/bin",
  "/usr/local/bin",
  "/usr/bin",
  "/bin",
  "/usr/sbin",
  "/sbin"
]
private let defaultTermsOfServiceText = """
CSA-iEM
Container Setup & Action Import Engine Manager
Provided by Wayne Tech Lab LLC
www.WayneTechLab.com

Warning! This tool can modify GitHub Actions, local runners, local devcontainers, and local workspace state. Use at your own risk.

By accepting and using this product, you acknowledge and agree that:

1. This tool is intended only for authorized, professional GitHub migration, cleanup, self-hosted runner, and devcontainer work.
2. This tool can permanently delete workflow runs, artifacts, caches, Codespaces, and workflow configurations, and can stop local services and containers.
3. You are solely responsible for verifying the GitHub host, account, repository, workspace root, and operation scope before execution.
4. You will use this software only on repositories, organizations, accounts, machines, and storage locations you are authorized to manage.
5. You accept full responsibility for data loss, workflow interruption, billing changes, repository impact, local system impact, and any other outcome caused by use or misuse of this tool.
6. This software is provided as-is, without warranties, guarantees, or assurances of fitness for any purpose.
7. Wayne Tech Lab LLC, its operators, authors, affiliates, and contributors are not liable for damages, losses, claims, or operational impact resulting from use of this software.

If you do not accept these terms, do not use this product.
"""

enum LaunchProfile: String, CaseIterable, Identifiable {
  case diamond
  case wtl
  case `public`

  var id: String { rawValue }

  var label: String {
    switch self {
    case .diamond: return "Diamond"
    case .wtl: return "WTL"
    case .public: return "Public"
    }
  }
}

enum WorkspaceStyle: String, CaseIterable, Identifiable {
  case single
  case split

  var id: String { rawValue }

  var label: String {
    switch self {
    case .single: return "Single Folder"
    case .split: return "Split Folders"
    }
  }

  var subtitle: String {
    switch self {
    case .single:
      return "One root folder for repos, runtime work, reports, and runners."
    case .split:
      return "Separate code and runtime folders for a cleaner local setup."
    }
  }
}

struct WorkspaceSuggestion {
  let style: WorkspaceStyle
  let title: String
  let detail: String
  let codeRoot: String
  let runtimeRoot: String
}

struct AuthHostConfig {
  let host: String
  let activeUser: String?
  let users: [String]
}

struct CommandResult {
  let status: Int32
  let output: String
}

struct RepoCatalogEntry: Identifiable, Hashable, Decodable {
  let nameWithOwner: String
  let visibility: String?
  let isPrivate: Bool?
  let updatedAt: String?
  let url: String?

  var id: String { nameWithOwner }

  var shortName: String {
    nameWithOwner.split(separator: "/").last.map(String.init) ?? nameWithOwner
  }

  var owner: String {
    nameWithOwner.split(separator: "/").dropLast().first.map(String.init) ?? ""
  }

  var visibilityLabel: String {
    if let visibility, !visibility.isEmpty {
      return visibility.uppercased()
    }
    return isPrivate == true ? "PRIVATE" : "PUBLIC"
  }

  var updatedLabel: String {
    guard let updatedAt, updatedAt.count >= 10 else {
      return "Updated: unknown"
    }
    return "Updated: \(String(updatedAt.prefix(10)))"
  }
}

struct LocalProjectEntry: Identifiable, Hashable {
  let slug: String
  let owner: String
  let repo: String
  let codePath: String?
  let runtimePath: String?
  let hasDevcontainer: Bool
  let hasGeneratedStarter: Bool
  let hasRunner: Bool

  var id: String { slug }

  var locationLabel: String {
    if let codePath, let runtimePath, codePath != runtimePath {
      return "split"
    }
    if runtimePath != nil {
      return "runtime"
    }
    return "code"
  }

  var preferredOpenPath: String? {
    runtimePath ?? codePath
  }

  var badges: [String] {
    var values = [locationLabel]
    if hasDevcontainer {
      values.append(hasGeneratedStarter ? "local-starter" : "devcontainer")
    }
    if hasRunner {
      values.append("runner")
    }
    return values
  }

  var searchableText: String {
    ([slug, owner, repo] + badges).joined(separator: " ").lowercased()
  }
}

struct LiveContainerEntry: Identifiable, Hashable {
  let containerID: String
  let name: String
  let image: String
  let status: String
  let workspacePath: String
  let slug: String
  let repo: String
  let codePath: String?
  let runtimePath: String?

  var id: String { containerID }
}

struct RunnerServiceEntry: Identifiable, Hashable {
  let slug: String
  let repo: String
  let runnerPath: String
  let serviceLabel: String
  let servicePlistPath: String?
  let isRunning: Bool
  let codePath: String?
  let runtimePath: String?

  var id: String { slug }

  var statusLabel: String {
    isRunning ? "running" : "stopped"
  }
}

enum BackgroundJobState: String, Codable, CaseIterable, Identifiable {
  case queued
  case running
  case succeeded
  case failed
  case cancelled

  var id: String { rawValue }

  var label: String { rawValue.capitalized }

  var statusKind: StatusKind {
    switch self {
    case .queued: return .warning
    case .running: return .running
    case .succeeded: return .ready
    case .failed: return .error
    case .cancelled: return .warning
    }
  }
}

struct BackgroundJobEntry: Identifiable, Hashable, Codable {
  let id: String
  var kind: String
  var title: String
  var target: String
  var detail: String
  var progressText: String
  var state: BackgroundJobState
  var createdAt: Date
  var startedAt: Date?
  var finishedAt: Date?
  var log: String
}

struct AppSettings: Codable, Hashable {
  var defaultGitHubHost = "github.com"
  var preferDetectedWorkspace = true
  var preferVSCodeCLI = true
  var preferredEditorPath = ""
  var runDockerChecksOnRefresh = true
  var autoLoadRepoHealth = true
  var autoLoadWorkflowRuns = true
  var showAdvancedTools = false
  var keepTerminalFallbacksVisible = false
  var firstRunComplete = false
}

struct SavedGitHubContext: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var host: String
  var account: String
  var owner: String
}

struct RepoHealthEntry: Identifiable, Hashable {
  let slug: String
  let workflowsTotal: Int
  let workflowsEnabled: Int
  let recentRuns: Int
  let activeCodespaces: Int
  let hasLocalRunner: Bool
  let githubHostedIndicators: Int
  let riskScore: Int
  let riskLabel: String
  let summary: String

  var id: String { slug }
}

struct WorkflowCatalogEntry: Identifiable, Hashable, Decodable {
  let id: Int
  let name: String
  let path: String
  let state: String
}

struct WorkflowRunEntry: Identifiable, Hashable, Decodable {
  let databaseId: Int64
  let name: String?
  let workflowName: String?
  let displayTitle: String?
  let event: String?
  let headBranch: String?
  let status: String?
  let conclusion: String?
  let createdAt: String?
  let updatedAt: String?

  var id: Int64 { databaseId }
}

struct CodespaceInventoryEntry: Identifiable, Hashable {
  let name: String
  let displayName: String
  let repo: String
  let state: String
  let machineName: String
  let lastUsedAt: String

  var id: String { name }
}

struct SecretRecord: Identifiable, Hashable, Decodable {
  let name: String
  let updatedAt: String?
  let visibility: String?

  var id: String { name }
}

struct VariableRecord: Identifiable, Hashable, Decodable {
  let name: String
  let updatedAt: String?
  let visibility: String?

  var id: String { name }
}

struct RulesetRecord: Identifiable, Hashable {
  let id: String
  let name: String
  let target: String
  let enforcement: String
  let source: String
}

struct BranchProtectionSummary: Hashable {
  let branch: String
  let requiredStatusChecks: Int
  let requiredPullRequestReviews: Bool
  let enforceAdmins: Bool
}

struct StorageInsightEntry: Identifiable, Hashable {
  let id: String
  let label: String
  let path: String
  let sizeLabel: String
}

struct ProjectSyncEntry: Identifiable, Hashable {
  let slug: String
  let codeDirty: Bool
  let runtimeDirty: Bool
  let codeAhead: Int
  let codeBehind: Int
  let runtimeAhead: Int
  let runtimeBehind: Int
  let summary: String

  var id: String { slug }
}

struct PortMonitorEntry: Identifiable, Hashable {
  let id: String
  let proto: String
  let port: String
  let pid: String
  let processName: String
}

enum ProjectTaskLocation: String, Codable, CaseIterable, Identifiable {
  case code
  case runtime

  var id: String { rawValue }

  var label: String {
    switch self {
    case .code: return "Code"
    case .runtime: return "Runtime"
    }
  }
}

struct ProjectTaskTemplate: Identifiable, Hashable, Codable {
  let id: String
  var slug: String
  var name: String
  var command: String
  var location: ProjectTaskLocation
}

struct SavedProjectView: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var query: String
  var favoritesOnly: Bool
}

enum BackupPreset: String, CaseIterable, Identifiable {
  case codeOnly
  case runtimeOnly
  case projectBundle
  case runnerBundle
  case fullWorkspace

  var id: String { rawValue }

  var label: String {
    switch self {
    case .codeOnly: return "Code Only"
    case .runtimeOnly: return "Runtime Only"
    case .projectBundle: return "Project Bundle"
    case .runnerBundle: return "Runner Bundle"
    case .fullWorkspace: return "Full Workspace"
    }
  }
}

struct SnapshotEntry: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var createdAt: Date
  var sourceScope: String
  var destinationPath: String
  var itemCount: Int
}

struct LocalOperationPreview: Hashable {
  let kind: LocalOperationKind
  let title: String
  let destinationPath: String
  let itemCount: Int
  let totalSizeLabel: String
  let collisions: [String]
  let preparedStamp: String?
}

private struct LocalTransferOperation: Hashable {
  let source: String
  let destination: String
}

private struct LocalTransferOutcome {
  let warnings: [String]
}

enum LocalOperationKind: String, Hashable {
  case workspaceMove
  case localExport
}

enum LocalFileTransferMode: String, CaseIterable, Identifiable {
  case copyBackup
  case move

  var id: String { rawValue }

  var label: String {
    switch self {
    case .copyBackup: return "Copy Backup"
    case .move: return "Move"
    }
  }
}

enum LocalFileExportScope: String, CaseIterable, Identifiable {
  case selectedProjects
  case codeWorkspace
  case runtimeWorkspace
  case workspaceBundle

  var id: String { rawValue }

  var label: String {
    switch self {
    case .selectedProjects: return "Selected Projects"
    case .codeWorkspace: return "Code Workspace"
    case .runtimeWorkspace: return "Runtime Workspace"
    case .workspaceBundle: return "Full Workspace Bundle"
    }
  }
}

enum WorkspaceRelocationScope: String, CaseIterable, Identifiable {
  case workspace
  case codeRoot
  case runtimeRoot

  var id: String { rawValue }

  var label: String {
    switch self {
    case .workspace: return "Move Workspace"
    case .codeRoot: return "Move Code Root"
    case .runtimeRoot: return "Move Runtime Root"
    }
  }
}

enum WorkspaceRelocationResult {
  case single(String)
  case split(codeRoot: String, runtimeRoot: String)
}

struct WorkspaceRelocationOutcome {
  let result: WorkspaceRelocationResult
  let warnings: [String]
}

enum StatusKind {
  case ready
  case warning
  case error
  case running

  var tint: Color {
    switch self {
    case .ready: return Color(red: 79 / 255, green: 169 / 255, blue: 139 / 255)
    case .warning: return Color(red: 209 / 255, green: 165 / 255, blue: 82 / 255)
    case .error: return Color(red: 196 / 255, green: 98 / 255, blue: 141 / 255)
    case .running: return Color(red: 121 / 255, green: 180 / 255, blue: 245 / 255)
    }
  }

  var icon: String {
    switch self {
    case .ready: return "checkmark.shield"
    case .warning: return "exclamationmark.triangle"
    case .error: return "xmark.octagon"
    case .running: return "waveform.path.ecg"
    }
  }
}

private enum AppDestination: String, CaseIterable, Identifiable {
  case home
  case jobs
  case githubAccount
  case projects
  case localFiles
  case cleanup
  case workspace
  case settings
  case helpCenter
  case terms
  case security
  case brandSystem
  case macOSNotes
  case projectInfo
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .home: return "Home"
    case .jobs: return "Jobs"
    case .githubAccount: return "GitHub Account"
    case .projects: return "Projects"
    case .localFiles: return "Local Files"
    case .cleanup: return "Cleanup"
    case .workspace: return "Workspace"
    case .settings: return "Settings"
    case .helpCenter: return "Help Center"
    case .terms: return "Terms of Service"
    case .security: return "Security Notes"
    case .brandSystem: return "Brand System"
    case .macOSNotes: return "macOS App Notes"
    case .projectInfo: return "Project Info"
    case .about: return "About"
    }
  }

  var subtitle: String {
    switch self {
    case .home:
      return "Simple starting point with session state, workspace summary, and the next best actions."
    case .jobs:
      return "Track background operations, progress, status, retries, and logs without opening Terminal."
    case .githubAccount:
      return "Manage the connected GitHub host, account, organizations, and repository inventory from the app."
    case .projects:
      return "Browse imported local projects on-screen, search them, and open them without dropping into Terminal."
    case .localFiles:
      return "Move workspace roots, export selected projects, and back up local data to another location or external drive."
    case .cleanup:
      return "Choose repositories, review scope, and run cleanup in the GUI while the CLI works in the background."
    case .workspace:
      return "Set where your local data lives, use the standard setup, or apply the detected setup on this Mac."
    case .settings:
      return "Control onboarding, preferred paths, advanced visibility, saved contexts, and GUI-first defaults."
    case .helpCenter:
      return "Operational guidance, safety model, target selection rules, and first-run workflow."
    case .terms:
      return "Every-launch responsibility, risk acceptance, and authorized-use conditions."
    case .security:
      return "Secret handling, token safety, stored-data scope, and review notes."
    case .brandSystem:
      return "Official logo, icon, color, and artwork usage requirements for production consistency."
    case .macOSNotes:
      return "Native app packaging, icon, installer, and macOS integration guidance."
    case .projectInfo:
      return "Bundle metadata, resource map, product identity, and project-level implementation notes."
    case .about:
      return "Product identity, company details, bundle state, install details, and local app storage."
    }
  }

  var icon: String {
    switch self {
    case .home: return "house"
    case .jobs: return "list.bullet.rectangle.portrait"
    case .githubAccount: return "person.crop.circle"
    case .projects: return "shippingbox"
    case .localFiles: return "folder.badge.gearshape"
    case .cleanup: return "trash"
    case .workspace: return "internaldrive"
    case .settings: return "gearshape"
    case .helpCenter: return "questionmark.circle"
    case .terms: return "checklist"
    case .security: return "lock.shield"
    case .brandSystem: return "paintpalette"
    case .macOSNotes: return "laptopcomputer"
    case .projectInfo: return "shippingbox"
    case .about: return "info.circle"
    }
  }

  var tint: Color {
    switch self {
    case .home: return DashboardTheme.accent
    case .jobs: return DashboardTheme.warning
    case .githubAccount: return DashboardTheme.link
    case .projects: return DashboardTheme.deepBlue
    case .localFiles: return DashboardTheme.warning
    case .cleanup: return DashboardTheme.warning
    case .workspace: return DashboardTheme.success
    case .settings: return DashboardTheme.accentPink
    case .helpCenter: return DashboardTheme.success
    case .terms: return DashboardTheme.warning
    case .security: return DashboardTheme.deepBlue
    case .brandSystem: return DashboardTheme.brightPink
    case .macOSNotes: return DashboardTheme.accentPink
    case .projectInfo: return DashboardTheme.success
    case .about: return DashboardTheme.link
    }
  }

  var bundleDocumentName: String? {
    switch self {
    case .helpCenter: return "Help-Center.md"
    case .terms: return "TERMS-OF-SERVICE.md"
    case .security: return "SECURITY.md"
    case .brandSystem: return "Brand-System.md"
    case .macOSNotes: return "macOS-App-Notes.md"
    case .projectInfo: return "PROJECT-INFO.md"
    case .home, .jobs, .githubAccount, .projects, .localFiles, .cleanup, .workspace, .settings, .about: return nil
    }
  }

  var fallbackDocumentText: String {
    switch self {
    case .terms:
      return bundledTermsOfServiceText()
    case .about:
      return ""
    default:
      return "This bundled document is missing from the current app package."
    }
  }
}

private let workspaceDestinations: [AppDestination] = [.home, .jobs, .githubAccount, .projects, .localFiles, .cleanup, .workspace, .settings, .about]
private let knowledgeDestinations: [AppDestination] = [.helpCenter, .terms, .security, .brandSystem, .macOSNotes, .projectInfo]

@MainActor
final class CleanupViewModel: ObservableObject {
  @Published var selectedProfile: LaunchProfile = .public {
    didSet {
      if selectedProfile != oldValue {
        safetyArmEnabled = false
        syncWorkspaceDraftsFromResolvedRoots()
        refreshLocalProjects()
      }
    }
  }
  @Published var useCurrentRoot = true {
    didSet {
      if useCurrentRoot != oldValue {
        syncWorkspaceDraftsFromResolvedRoots()
        refreshLocalProjects()
      }
    }
  }
  @Published var workspaceSingleRootDraft = publicDefaultRoot
  @Published var workspaceCodeRootDraft = genericSplitCodeDefaultRoot
  @Published var workspaceRuntimeRootDraft = genericSplitRuntimeDefaultRoot
  @Published var workspaceMoveDestinationDraft = ""
  @Published var localExportDestinationDraft = ""
  @Published var projectMoveDestinationDraft = ""
  @Published var host = "github.com" {
    didSet {
      if host != oldValue {
        isAuthenticated = false
        clearRepoCatalog(resetOwner: false)
        reloadAccountChoices()
        refreshAuthStatus()
        if host != oldValue {
          safetyArmEnabled = false
        }
      }
    }
  }
  @Published var account = "" {
    didSet {
      if account != oldValue {
        if repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || repoOwner == oldValue {
          repoOwner = account
        }
        clearRepoCatalog(resetOwner: false)
        if isAuthenticated && !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          fetchAvailableRepos()
        }
      }
    }
  }
  @Published var repoTarget = "" {
    didSet {
      if repoTarget != oldValue {
        safetyArmEnabled = false
      }
    }
  }
  @Published var repoOwner = "" {
    didSet {
      if repoOwner != oldValue {
        clearRepoCatalog(resetOwner: false)
      }
    }
  }
  @Published var repoSearch = ""
  @Published var localProjectSearch = ""
  @Published var savedViewNameDraft = ""
  @Published var contextNameDraft = ""
  @Published var taskNameDraft = ""
  @Published var taskCommandDraft = ""
  @Published var taskLocationDraft: ProjectTaskLocation = .runtime
  @Published var fullCleanup = true
  @Published var disableWorkflows = true
  @Published var deleteRuns = true
  @Published var deleteArtifacts = true
  @Published var deleteCaches = true
  @Published var deleteCodespaces = false
  @Published var dryRun = false
  @Published var runTarget = ""
  @Published var runFilter = ""
  @Published var safetyArmEnabled = false
  @Published var localFileTransferMode: LocalFileTransferMode = .copyBackup
  @Published var localFileExportScope: LocalFileExportScope = .selectedProjects
  @Published var includeProjectCodeExport = true
  @Published var includeProjectRuntimeExport = true
  @Published var includeProjectRunnerExport = true
  @Published var overwriteLocalFileDestination = false
  @Published var showFavoritesOnly = false
  @Published var selectedBackupPreset: BackupPreset = .projectBundle
  @Published var localOperationPreview: LocalOperationPreview?
  @Published var localExportPreparedStamp = ""
  @Published var appSettings = AppSettings()

  @Published var availableHosts: [String] = []
  @Published var availableAccounts: [String] = []
  @Published var availableRepos: [RepoCatalogEntry] = []
  @Published var localProjects: [LocalProjectEntry] = []
  @Published var activeContainers: [LiveContainerEntry] = []
  @Published var runnerServices: [RunnerServiceEntry] = []
  @Published var viewerOrganizations: [String] = []
  @Published var backgroundJobs: [BackgroundJobEntry] = []
  @Published var selectedJobID: String?
  @Published var savedContexts: [SavedGitHubContext] = []
  @Published var favoriteProjects: Set<String> = []
  @Published var savedProjectViews: [SavedProjectView] = []
  @Published var taskTemplates: [ProjectTaskTemplate] = []
  @Published var snapshots: [SnapshotEntry] = []
  @Published var repoHealthEntries: [RepoHealthEntry] = []
  @Published var workflows: [WorkflowCatalogEntry] = []
  @Published var workflowRuns: [WorkflowRunEntry] = []
  @Published var codespaces: [CodespaceInventoryEntry] = []
  @Published var repoSecrets: [SecretRecord] = []
  @Published var orgSecrets: [SecretRecord] = []
  @Published var repoVariables: [VariableRecord] = []
  @Published var orgVariables: [VariableRecord] = []
  @Published var rulesets: [RulesetRecord] = []
  @Published var branchProtectionSummary: BranchProtectionSummary?
  @Published var storageInsights: [StorageInsightEntry] = []
  @Published var projectSyncEntries: [ProjectSyncEntry] = []
  @Published var portMonitorEntries: [PortMonitorEntry] = []
  @Published var selectedRepos: Set<String> = [] {
    didSet {
      if selectedRepos != oldValue {
        safetyArmEnabled = false
      }
    }
  }
  @Published var repoCatalogStatus = "Load repositories for the selected GitHub account or owner."
  @Published var localProjectStatus = "Scan local imported projects for the current workspace roots."
  @Published var liveServicesStatus = "Scan active local devcontainers and runner services for the current workspace."
  @Published var githubAccountStatus = "Refresh the connected account to load organizations and account-level details."
  @Published var localFilesStatus = "Choose a destination and move or export local files from the current workspace."
  @Published var settingsStatus = "Use the settings page to control onboarding, saved contexts, and advanced GUI defaults."
  @Published var jobCenterStatus = "Background jobs will appear here as the app runs local and GitHub operations."
  @Published var repoHealthStatus = "Load repository health to inspect workflow state, local runner coverage, run activity, and cost risk."
  @Published var workflowStatus = "Select a repository target to inspect workflows, runs, and GitHub Actions administration details."
  @Published var codespacesStatus = "Load Codespaces after selecting a repository target."
  @Published var secretsStatus = "Load secrets and variables for the selected repository or owner."
  @Published var rulesStatus = "Load branch protection and rulesets for the selected repository."
  @Published var storageStatus = "Load storage insights for the current workspace."
  @Published var syncStatus = "Load project sync status to compare code and runtime worktrees."
  @Published var portsStatus = "Scan local listening ports and service endpoints."
  @Published var taskStatus = "Create reusable per-project tasks and run them from the GUI."
  @Published var snapshotStatus = "Create point-in-time snapshots before major local file changes."
  @Published var logText = "[gui] CSA-iEM ready.\n"
  @Published var statusTitle = "Checking GitHub CLI"
  @Published var statusDetail = "Loading local GitHub configuration."
  @Published var statusKind: StatusKind = .running
  @Published var isRunning = false
  @Published var isAuthenticated = false
  @Published var isLoggingOut = false
  @Published var isLoadingRepos = false
  @Published var isLoadingLocalProjects = false
  @Published var isLoadingLiveServices = false
  @Published var isLoadingGitHubAccountDetails = false
  @Published var isRunningLocalFileOperation = false
  @Published var isLoadingRepoHealth = false
  @Published var isLoadingWorkflowData = false
  @Published var isLoadingCodespaces = false
  @Published var isLoadingSecretsData = false
  @Published var isLoadingRulesData = false
  @Published var isLoadingStorageInsights = false
  @Published var isLoadingProjectSync = false
  @Published var isLoadingPorts = false
  @Published var isRunningTask = false

  private var hostConfigs: [AuthHostConfig] = []
  private var runningProcess: Process?
  private var activeJobID: String?
  private var pendingRepoTargets: [String] = []
  private var completedRepoTargets: [String] = []
  private var failedRepoTargets: [String] = []
  private var activeRepoTarget = ""
  private var totalRepoTargets = 0
  private var cancellationRequested = false
  private var isAutoRecoveringWorkspace = false
  private let processQueue = DispatchQueue(label: "com.waynetechlab.csaiem.process", qos: .userInitiated)

  init() {
    bootstrap()
  }

  private var cliRootPath: String? {
    let fm = FileManager.default

    if let envRoot = ProcessInfo.processInfo.environment["CSA_IEM_ROOT"], !envRoot.isEmpty {
      let directScript = (envRoot as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: directScript) {
        return envRoot
      }
    }

    if let bundledCLI = Bundle.main.resourceURL?.appendingPathComponent("CLI").path {
      let bundledScript = (bundledCLI as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: bundledScript) {
        return bundledCLI
      }
    }

    if let resourceRoot = Bundle.main.resourceURL?.path {
      let directScript = (resourceRoot as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: directScript) {
        return resourceRoot
      }
    }

    let cwd = fm.currentDirectoryPath
    let cwdScript = (cwd as NSString).appendingPathComponent("CSA-iLEM.sh")
    if fm.isExecutableFile(atPath: cwdScript) {
      return cwd
    }

    return nil
  }

  var cliPath: String? {
    let fm = FileManager.default

    if let cliRootPath {
      let bundled = (cliRootPath as NSString).appendingPathComponent("CSA-iLEM.sh")
      if fm.isExecutableFile(atPath: bundled) {
        return bundled
      }
    }

    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent("csa-iem")
      if fm.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }

    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent("csa-ilem")
      if fm.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }

    return nil
  }

  var ghPath: String? {
    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent("gh")
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }

    return nil
  }

  var dockerPath: String? {
    executablePath(named: "docker")
  }

  var bundledIcon: NSImage? {
    guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
      return NSWorkspace.shared.icon(for: .application)
    }
    return NSImage(contentsOf: iconURL)
  }

  var bundledBrandMark: NSImage? {
    if let appIconURL = bundledResourceURL(named: "appicon-512x512@2x.png", subdirectory: "AppIcon.appiconset"),
       let appIconImage = NSImage(contentsOf: appIconURL) {
      return appIconImage
    }
    return bundledImage(named: "icon-1024.png") ?? bundledImage(named: "logo-card-square.png")
  }

  var bundledLockup: NSImage? {
    bundledImage(named: "logo-horizontal-lockup.png")
  }

  var bundledHero: NSImage? {
    bundledImage(named: "hero-2560x1600.png")
  }

  var bundleIdentitySummary: String {
    "\(Bundle.main.bundleIdentifier ?? "com.waynetechlab.csaiem") · Version \(appVersion)"
  }

  var canRunCleanup: Bool {
    !isRunning &&
      cliPath != nil &&
      ghPath != nil &&
      isAuthenticated &&
      !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !cleanupTargets.isEmpty &&
      (fullCleanup || disableWorkflows || deleteRuns || deleteArtifacts || deleteCaches || deleteCodespaces) &&
      safetyArmEnabled &&
      statusKind != .error
  }

  var selectedHostConfig: AuthHostConfig? {
    hostConfigs.first(where: { $0.host == host.trimmingCharacters(in: .whitespacesAndNewlines) })
  }

  var authHeadline: String {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "github.com" : host.trimmingCharacters(in: .whitespacesAndNewlines)
    if isAuthenticated {
      return "GitHub Ready @ \(selectedHost)"
    }
    return "GitHub Login Required @ \(selectedHost)"
  }

  var authSummary: String {
    let resolvedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    if isAuthenticated && !resolvedAccount.isEmpty {
      return "User \(resolvedAccount) on account \(resolvedAccount) ready on \(resolvedHost)."
    }
    return "No authenticated GitHub account is ready for cleanup."
  }

  var authActionHint: String {
    if isAuthenticated {
      return "Selected account is ready. You can refresh, log out, or continue to repository cleanup."
    }
    return "Log in with GitHub CLI first, then select the account you want to use."
  }

  var sessionCompactLabel: String {
    let resolvedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "github.com" : host.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let accountValue = resolvedAccount.isEmpty ? (selectedHostConfig?.activeUser ?? "no account") : resolvedAccount
    return isAuthenticated ? "\(accountValue) @ \(resolvedHost) ready" : "Login required @ \(resolvedHost)"
  }

  var selectionCompactLabel: String {
    let count = cleanupTargets.count
    if count == 0 {
      return "No targets selected"
    }
    if count == 1, let target = cleanupTargets.first {
      return target
    }
    return "\(count) targets selected"
  }

  var statusCompactLabel: String {
    let trimmedTitle = statusTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedTitle.isEmpty {
      return "Idle"
    }
    return trimmedTitle
  }

  var lastSessionSummary: String? {
    let session = loadLastSession()
    guard !session.isEmpty else { return nil }

    let hostValue = session["HOST"] ?? "github.com"
    let accountValue = session["ACCOUNT"] ?? "unknown"
    let repoValue = session["REPO"]?.replacingOccurrences(of: "\(hostValue)/", with: "") ?? "not set"
    return "Last session: \(accountValue) on \(hostValue) -> \(repoValue)"
  }

  var filteredRepos: [RepoCatalogEntry] {
    let query = repoSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else {
      return availableRepos
    }

    return availableRepos.filter { repo in
      repo.nameWithOwner.lowercased().contains(query) ||
      repo.shortName.lowercased().contains(query) ||
      repo.owner.lowercased().contains(query) ||
      (repo.visibility?.lowercased().contains(query) ?? false)
    }
  }

  var filteredLocalProjects: [LocalProjectEntry] {
    let query = localProjectSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return localProjects.filter { project in
      let matchesQuery = query.isEmpty || project.searchableText.contains(query)
      let matchesFavorite = !showFavoritesOnly || favoriteProjects.contains(project.slug)
      return matchesQuery && matchesFavorite
    }
  }

  var localProjectSummary: String {
    guard !localProjects.isEmpty else {
      return "No local projects detected"
    }

    let splitCount = localProjects.filter { $0.locationLabel == "split" }.count
    let devcontainerCount = localProjects.filter(\.hasDevcontainer).count
    let runnerCount = localProjects.filter(\.hasRunner).count
    let favoriteCount = favoriteProjects.count
    return "\(localProjects.count) local projects · \(splitCount) split · \(devcontainerCount) devcontainers · \(runnerCount) runners · \(favoriteCount) favorites"
  }

  var localProjectSplitCount: Int {
    localProjects.filter { $0.locationLabel == "split" }.count
  }

  var localProjectRuntimeOnlyCount: Int {
    localProjects.filter { $0.codePath == nil && $0.runtimePath != nil }.count
  }

  var localProjectDevcontainerCount: Int {
    localProjects.filter(\.hasDevcontainer).count
  }

  var localProjectGeneratedStarterCount: Int {
    localProjects.filter(\.hasGeneratedStarter).count
  }

  var localProjectRunnerCount: Int {
    localProjects.filter(\.hasRunner).count
  }

  var activeContainerCount: Int {
    activeContainers.count
  }

  var runningRunnerServiceCount: Int {
    runnerServices.filter(\.isRunning).count
  }

  var liveServiceSummary: String {
    "\(activeContainerCount) active devcontainers · \(runningRunnerServiceCount) running runners · \(runnerServices.count) configured runner services"
  }

  var selectedLocalProjects: [LocalProjectEntry] {
    localProjects.filter { selectedRepos.contains($0.slug) }
  }

  var selectedLocalProjectExportSummary: String {
    let count = selectedLocalProjects.count
    if count == 0 {
      return "No local projects targeted for export"
    }
    if count == 1, let only = selectedLocalProjects.first {
      return "1 local project targeted: \(only.slug)"
    }
    return "\(count) local projects targeted"
  }

  var viewerOrganizationsSummary: String {
    if viewerOrganizations.isEmpty {
      return isLoadingGitHubAccountDetails ? "Loading organizations..." : "No organizations loaded yet"
    }
    return viewerOrganizations.joined(separator: ", ")
  }

  var localFilesPrimaryActionTitle: String {
    switch (localFileTransferMode, localFileExportScope) {
    case (.copyBackup, .selectedProjects):
      return "Copy Selected Projects"
    case (.move, .selectedProjects):
      return "Move Selected Projects"
    case (.copyBackup, .codeWorkspace):
      return "Copy Code Workspace"
    case (.move, .codeWorkspace):
      return "Move Code Workspace"
    case (.copyBackup, .runtimeWorkspace):
      return "Copy Runtime Workspace"
    case (.move, .runtimeWorkspace):
      return "Move Runtime Workspace"
    case (.copyBackup, .workspaceBundle):
      return "Copy Full Workspace Bundle"
    case (.move, .workspaceBundle):
      return "Move Full Workspace Bundle"
    }
  }

  var localFilesScopeSummary: String {
    switch localFileExportScope {
    case .selectedProjects:
      return "\(selectedLocalProjectExportSummary). Use project targets below to move or back up one repo or a custom set."
    case .codeWorkspace:
      return "Export the entire plain code workspace root."
    case .runtimeWorkspace:
      return "Export the entire runtime workspace root, including local devcontainer content and reports."
    case .workspaceBundle:
      return "Export both workspace roots into one structured bundle."
    }
  }

  var selectedLocalProjectCount: Int {
    localProjects.filter { selectedRepos.contains($0.slug) }.count
  }

  var selectedJob: BackgroundJobEntry? {
    guard let selectedJobID else { return backgroundJobs.first }
    return backgroundJobs.first(where: { $0.id == selectedJobID }) ?? backgroundJobs.first
  }

  var primaryRepoSlug: String? {
    if let selected = selectedRepos.sorted().first {
      return normalizeRepoSlug(selected)
    }

    let manual = repoTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    if !manual.isEmpty {
      return normalizeRepoSlug(manual)
    }

    return availableRepos.first?.nameWithOwner ?? localProjects.first?.slug
  }

  var primaryLocalProject: LocalProjectEntry? {
    if let slug = primaryRepoSlug,
       let project = localProjects.first(where: { $0.slug == slug }) {
      return project
    }
    return filteredLocalProjects.first ?? localProjects.first
  }

  var filteredTaskTemplates: [ProjectTaskTemplate] {
    guard let primaryLocalProject else { return [] }
    return taskTemplates.filter { $0.slug == primaryLocalProject.slug }
  }

  var favoriteProjectCount: Int {
    favoriteProjects.count
  }

  var runningJobCount: Int {
    backgroundJobs.filter { $0.state == .running || $0.state == .queued }.count
  }

  var recentJobSummary: String {
    if backgroundJobs.isEmpty {
      return "No background jobs recorded yet"
    }
    let successCount = backgroundJobs.filter { $0.state == .succeeded }.count
    let failedCount = backgroundJobs.filter { $0.state == .failed }.count
    return "\(backgroundJobs.count) jobs · \(runningJobCount) active · \(successCount) succeeded · \(failedCount) failed"
  }

  var areAllVisibleLocalProjectsSelected: Bool {
    !filteredLocalProjects.isEmpty && filteredLocalProjects.allSatisfy { selectedRepos.contains($0.slug) }
  }

  var profileRootSummary: (codeRoot: String, runtimeRoot: String) {
    resolvedProfileRoots()
  }

  var selectedWorkspaceStyle: WorkspaceStyle {
    selectedProfile == .diamond ? .split : .single
  }

  var workspaceStyleLabel: String {
    selectedWorkspaceStyle.label
  }

  var workspaceHeadline: String {
    switch selectedWorkspaceStyle {
    case .single:
      return "Single workspace folder"
    case .split:
      return "Split code and runtime folders"
    }
  }

  var workspaceSummary: String {
    let roots = resolvedProfileRoots()
    switch selectedWorkspaceStyle {
    case .single:
      return roots.runtimeRoot
    case .split:
      return "Code: \(roots.codeRoot)\nRuntime: \(roots.runtimeRoot)"
    }
  }

  var workspaceExecutionLabel: String {
    switch selectedWorkspaceStyle {
    case .single:
      return "single-folder workspace"
    case .split:
      return "split-folder workspace"
    }
  }

  var standardWorkspaceSuggestion: WorkspaceSuggestion {
    switch selectedWorkspaceStyle {
    case .single:
      return WorkspaceSuggestion(
        style: .single,
        title: "Standard local workspace",
        detail: "Best default for public use. Everything lives in one root under your home folder.",
        codeRoot: publicDefaultRoot,
        runtimeRoot: publicDefaultRoot
      )
    case .split:
      return WorkspaceSuggestion(
        style: .split,
        title: "Standard split workspace",
        detail: "Generic public example with one code folder and one runtime folder under your home directory.",
        codeRoot: genericSplitCodeDefaultRoot,
        runtimeRoot: genericSplitRuntimeDefaultRoot
      )
    }
  }

  var detectedWorkspaceSuggestion: WorkspaceSuggestion? {
    detectedWorkspaceConfiguration()
  }

  var cleanupTargets: [String] {
    if !selectedRepos.isEmpty {
      return selectedRepos.sorted()
    }

    let manualTarget = repoTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    return manualTarget.isEmpty ? [] : [manualTarget]
  }

  var areAllLoadedReposSelected: Bool {
    !availableRepos.isEmpty && availableRepos.allSatisfy { selectedRepos.contains($0.nameWithOwner) }
  }

  var selectedRepoSummary: String {
    if !selectedRepos.isEmpty {
      if selectedRepos.count == 1, let only = selectedRepos.first {
        return "1 repository selected: \(only)"
      }
      return "\(selectedRepos.count) repositories selected"
    }

    let manualTarget = repoTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    if !manualTarget.isEmpty {
      return "Manual target: \(manualTarget)"
    }

    return "No repository selected yet"
  }

  func bootstrap() {
    loadPersistentState()

    let session = loadLastSession()
    if let savedHost = session["HOST"], !savedHost.isEmpty {
      host = savedHost
    }
    if let savedAccount = session["ACCOUNT"], !savedAccount.isEmpty {
      account = savedAccount
    }
    if let savedRepo = session["REPO"], !savedRepo.isEmpty {
      if savedRepo.hasPrefix("\(host)/") {
        repoTarget = String(savedRepo.dropFirst(host.count + 1))
      } else {
        repoTarget = savedRepo
      }
      let components = repoTarget.split(separator: "/")
      if components.count >= 2 {
        repoOwner = String(components[0])
      }
    }

    if repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      repoOwner = account
    }

    if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      host = appSettings.defaultGitHubHost
    }

    adoptDetectedWorkspaceIfNeeded()
    syncWorkspaceDraftsFromResolvedRoots()
    reloadAuthInventory()
    refreshAuthStatus()
    refreshLocalProjects()
  }

  private func loadPersistentState() {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true, attributes: nil)
    try? fm.createDirectory(atPath: snapshotsDirectory, withIntermediateDirectories: true, attributes: nil)

    if let loadedSettings: AppSettings = readJSON(AppSettings.self, from: settingsFile) {
      appSettings = loadedSettings
    }
    if let loadedContexts: [SavedGitHubContext] = readJSON([SavedGitHubContext].self, from: contextsFile) {
      savedContexts = loadedContexts
    }
    if let loadedTasks: [ProjectTaskTemplate] = readJSON([ProjectTaskTemplate].self, from: taskTemplatesFile) {
      taskTemplates = loadedTasks
    }
    if let loadedFavorites: [String] = readJSON([String].self, from: favoriteProjectsFile) {
      favoriteProjects = Set(loadedFavorites)
    }
    if let loadedViews: [SavedProjectView] = readJSON([SavedProjectView].self, from: savedViewsFile) {
      savedProjectViews = loadedViews
    }

    loadSnapshots()
    if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      host = appSettings.defaultGitHubHost
    }
  }

  private func persistSettings() {
    writeJSON(appSettings, to: settingsFile)
  }

  private func persistContexts() {
    writeJSON(savedContexts, to: contextsFile)
  }

  private func persistTasks() {
    writeJSON(taskTemplates, to: taskTemplatesFile)
  }

  private func persistFavorites() {
    writeJSON(Array(favoriteProjects).sorted(), to: favoriteProjectsFile)
  }

  private func persistSavedViews() {
    writeJSON(savedProjectViews, to: savedViewsFile)
  }

  private func loadSnapshots() {
    let fm = FileManager.default
    let snapshotFiles = (try? fm.contentsOfDirectory(atPath: snapshotsDirectory))?.sorted() ?? []
    var loaded: [SnapshotEntry] = []
    for file in snapshotFiles where file.hasSuffix(".json") {
      let path = (snapshotsDirectory as NSString).appendingPathComponent(file)
      if let entry: SnapshotEntry = readJSON(SnapshotEntry.self, from: path) {
        loaded.append(entry)
      }
    }
    snapshots = loaded.sorted { $0.createdAt > $1.createdAt }
  }

  private func writeSnapshot(_ entry: SnapshotEntry) {
    let path = (snapshotsDirectory as NSString).appendingPathComponent("\(entry.id).json")
    writeJSON(entry, to: path)
    loadSnapshots()
  }

  private func deleteSnapshot(_ entry: SnapshotEntry) {
    let jsonPath = (snapshotsDirectory as NSString).appendingPathComponent("\(entry.id).json")
    let payloadPath = (snapshotsDirectory as NSString).appendingPathComponent(entry.id)
    try? FileManager.default.removeItem(atPath: jsonPath)
    try? FileManager.default.removeItem(atPath: payloadPath)
    loadSnapshots()
  }

  private func writeJSON<T: Encodable>(_ value: T, to path: String) {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(value) else { return }
    try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
  }

  private func readJSON<T: Decodable>(_ type: T.Type, from path: String) -> T? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
      return nil
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(T.self, from: data)
  }

  func setWorkspaceStyle(_ style: WorkspaceStyle) {
    switch style {
    case .single:
      selectedProfile = .public
    case .split:
      selectedProfile = .diamond
    }
  }

  func applyStandardWorkspace() {
    let suggestion = standardWorkspaceSuggestion
    applyWorkspaceSuggestion(suggestion)
  }

  func applyDetectedWorkspace() {
    guard let suggestion = detectedWorkspaceSuggestion else {
      appendLog("[gui] No detected workspace setup was found on this Mac.\n")
      return
    }
    applyWorkspaceSuggestion(suggestion)
  }

  func saveWorkspaceDrafts() {
    switch selectedWorkspaceStyle {
    case .single:
      let root = normalizeWorkspacePath(workspaceSingleRootDraft.isEmpty ? publicDefaultRoot : workspaceSingleRootDraft)
      writeProfileConfig(
        profile: .public,
        values: ["SAVED_DEFAULT_ROOT": root]
      )
      selectedProfile = .public
    case .split:
      let codeRoot = normalizeWorkspacePath(workspaceCodeRootDraft.isEmpty ? genericSplitCodeDefaultRoot : workspaceCodeRootDraft)
      let runtimeRoot = normalizeWorkspacePath(workspaceRuntimeRootDraft.isEmpty ? genericSplitRuntimeDefaultRoot : workspaceRuntimeRootDraft)
      writeProfileConfig(
        profile: .diamond,
        values: [
          "SAVED_CODE_ROOT": codeRoot,
          "SAVED_RUNTIME_ROOT": runtimeRoot
        ]
      )
      selectedProfile = .diamond
    }
    useCurrentRoot = true
    syncWorkspaceDraftsFromResolvedRoots()
    refreshLocalProjects()
  }

  func chooseSingleWorkspaceFolder() {
    let startingPath = workspaceSingleRootDraft.isEmpty ? profileRootSummary.runtimeRoot : workspaceSingleRootDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceSingleRootDraft = selectedPath
    }
  }

  func chooseCodeWorkspaceFolder() {
    let startingPath = workspaceCodeRootDraft.isEmpty ? profileRootSummary.codeRoot : workspaceCodeRootDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceCodeRootDraft = selectedPath
    }
  }

  func chooseRuntimeWorkspaceFolder() {
    let startingPath = workspaceRuntimeRootDraft.isEmpty ? profileRootSummary.runtimeRoot : workspaceRuntimeRootDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceRuntimeRootDraft = selectedPath
    }
  }

  func chooseWorkspaceMoveDestinationFolder() {
    let startingPath = workspaceMoveDestinationDraft.isEmpty ? NSString(string: "~").expandingTildeInPath : workspaceMoveDestinationDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      workspaceMoveDestinationDraft = selectedPath
    }
  }

  func chooseLocalExportDestinationFolder() {
    let startingPath = localExportDestinationDraft.isEmpty ? NSString(string: "~").expandingTildeInPath : localExportDestinationDraft
    if let selectedPath = chooseDirectory(startingAt: startingPath) {
      localExportDestinationDraft = selectedPath
    }
  }

  func relocateWorkspace(_ scope: WorkspaceRelocationScope) {
    let baseDestination = normalizeWorkspacePath(workspaceMoveDestinationDraft)
    guard !baseDestination.isEmpty else {
      localFilesStatus = "Choose a destination folder before moving workspace files."
      return
    }

    let roots = resolvedProfileRoots()
    let currentStyle = selectedWorkspaceStyle
    let environment = baseEnvironment()
    let overwrite = overwriteLocalFileDestination

    isRunningLocalFileOperation = true
    localFilesStatus = "Moving workspace files..."
    appendLog("[gui] Starting workspace move to \(baseDestination)\n")

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        let outcome = try Self.relocateWorkspaceRoots(
          scope: scope,
          style: currentStyle,
          codeRoot: roots.codeRoot,
          runtimeRoot: roots.runtimeRoot,
          destinationBase: baseDestination,
          overwrite: overwrite,
          environment: environment
        )

        DispatchQueue.main.async {
          switch outcome.result {
          case .single(let newRoot):
            self.writeProfileConfig(profile: .public, values: ["SAVED_DEFAULT_ROOT": newRoot])
            self.selectedProfile = .public
          case .split(let newCodeRoot, let newRuntimeRoot):
            self.writeProfileConfig(
              profile: .diamond,
              values: [
                "SAVED_CODE_ROOT": newCodeRoot,
                "SAVED_RUNTIME_ROOT": newRuntimeRoot
              ]
            )
            self.selectedProfile = .diamond
          }
          self.useCurrentRoot = true
          self.syncWorkspaceDraftsFromResolvedRoots()
          self.isRunningLocalFileOperation = false
          self.localOperationPreview = nil
          if outcome.warnings.isEmpty {
            self.localFilesStatus = "Workspace move finished."
          } else {
            self.localFilesStatus = "Workspace move finished with cleanup warnings."
            outcome.warnings.forEach { self.appendLog("[gui] \($0)\n") }
          }
          self.appendLog("[gui] Workspace move finished.\n")
          self.refreshLocalProjects()
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.localFilesStatus = error.localizedDescription
          self.appendLog("[gui] Workspace move failed: \(error.localizedDescription)\n")
        }
      }
    }
  }

  func runLocalExport() {
    let destination = normalizeWorkspacePath(localExportDestinationDraft)
    guard !destination.isEmpty else {
      localFilesStatus = "Choose an export destination before running a backup or export."
      return
    }

    let exportMode = localFileTransferMode
    let exportScope = localFileExportScope
    let selectedProjects = self.selectedLocalProjects
    let roots = resolvedProfileRoots()
    let overwrite = overwriteLocalFileDestination
    let includeCode = includeProjectCodeExport
    let includeRuntime = includeProjectRuntimeExport
    let includeRunners = includeProjectRunnerExport
    let environment = baseEnvironment()
    let preparedStamp = localExportPreparedStamp.isEmpty ? Self.timestampStamp() : localExportPreparedStamp

    if exportScope == .selectedProjects && selectedProjects.isEmpty {
      localFilesStatus = "Target one or more local projects before exporting selected projects."
      return
    }

    if exportScope == .selectedProjects && !includeCode && !includeRuntime && !includeRunners {
      localFilesStatus = "Choose at least one selected-project export option: code, runtime, or runner folders."
      return
    }

    isRunningLocalFileOperation = true
    localFilesStatus = "Running local file export..."
    appendLog("[gui] Starting \(exportMode.label.lowercased()) to \(destination)\n")

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        let summary = try Self.exportLocalFiles(
          scope: exportScope,
          mode: exportMode,
          destinationBase: destination,
          preparedStamp: preparedStamp,
          roots: roots,
          selectedProjects: selectedProjects,
          includeCode: includeCode,
          includeRuntime: includeRuntime,
          includeRunners: includeRunners,
          overwrite: overwrite,
          environment: environment
        )

        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.localExportPreparedStamp = ""
          self.localOperationPreview = nil
          self.localFilesStatus = summary
          self.appendLog("[gui] \(summary)\n")
          self.refreshLocalProjects()
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.localExportPreparedStamp = ""
          self.localFilesStatus = error.localizedDescription
          self.appendLog("[gui] Local file export failed: \(error.localizedDescription)\n")
        }
      }
    }
  }

  func reloadAuthInventory() {
    hostConfigs = parseGitHubConfig()
    availableHosts = hostConfigs.map(\.host)

    if !availableHosts.isEmpty {
      if availableHosts.contains(host) == false {
        host = availableHosts.first ?? "github.com"
      }
    } else if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      host = "github.com"
    }

    reloadAccountChoices()
  }

  func reloadAccountChoices() {
    let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let hostConfig = hostConfigs.first(where: { $0.host == currentHost })
    var accounts = hostConfig?.users ?? []

    if accounts.isEmpty, let activeUser = hostConfig?.activeUser, !activeUser.isEmpty {
      accounts = [activeUser]
    }

    availableAccounts = accounts

    if let existing = hostConfig?.users.first(where: { $0 == account }) {
      account = existing
      return
    }

    if let lastAccount = loadLastSession()["ACCOUNT"], accounts.contains(lastAccount) {
      account = lastAccount
    } else if let active = hostConfig?.activeUser, !active.isEmpty {
      account = active
    } else if let first = accounts.first {
      account = first
    } else if availableAccounts.isEmpty {
      account = ""
    }
  }

  func clearRepoCatalog(resetOwner: Bool) {
    availableRepos = []
    selectedRepos = []
    repoSearch = ""
    repoCatalogStatus = "Load repositories for the selected GitHub account or owner."

    if resetOwner {
      repoOwner = ""
    }
  }

  func openImportedProjectsInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse-projects"], exitLabel: "Imported Projects") else {
      return
    }
    openTerminalCommand(command)
  }

  func refreshLocalProjects() {
    isLoadingLocalProjects = true
    localProjectStatus = "Scanning local projects for the \(workspaceStyleLabel.lowercased()) workspace..."
    let workspaceLabel = workspaceStyleLabel
    let roots = resolvedProfileRoots()

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.scanLocalProjects(
        workspaceLabel: workspaceLabel,
        codeRoot: roots.codeRoot,
        runtimeRoot: roots.runtimeRoot
      )

      DispatchQueue.main.async {
        if result.projects.isEmpty,
           !self.isAutoRecoveringWorkspace,
           let fallback = self.workspaceRecoverySuggestion(currentCodeRoot: roots.codeRoot, currentRuntimeRoot: roots.runtimeRoot) {
          self.isLoadingLocalProjects = false
          self.isAutoRecoveringWorkspace = true
          self.localProjectStatus = "No local projects were found in the current workspace. Switching to \(fallback.title.lowercased()) and rescanning..."
          self.applyRecoveredWorkspaceSuggestion(fallback)
          self.isAutoRecoveringWorkspace = false
          return
        }
        self.isLoadingLocalProjects = false
        self.localProjects = result.projects
        self.localProjectStatus = result.status
        self.refreshLiveServices()
      }
    }
  }

  private func workspaceRecoverySuggestion(currentCodeRoot: String, currentRuntimeRoot: String) -> WorkspaceSuggestion? {
    let currentCode = normalizeWorkspacePath(currentCodeRoot)
    let currentRuntime = normalizeWorkspacePath(currentRuntimeRoot)
    var candidates: [WorkspaceSuggestion] = []

    if let detected = detectedWorkspaceConfiguration() {
      candidates.append(detected)
    }
    if let saved = savedWorkspaceConfiguration() {
      candidates.append(saved)
    }

    var seenKeys: Set<String> = []
    for candidate in candidates {
      let key = "\(candidate.style.rawValue)|\(normalizeWorkspacePath(candidate.codeRoot))|\(normalizeWorkspacePath(candidate.runtimeRoot))"
      guard seenKeys.insert(key).inserted else { continue }

      let candidateCode = normalizeWorkspacePath(candidate.codeRoot)
      let candidateRuntime = normalizeWorkspacePath(candidate.runtimeRoot)
      if candidateCode == currentCode && candidateRuntime == currentRuntime {
        continue
      }

      let candidateResult = Self.scanLocalProjects(
        workspaceLabel: candidate.style == .split ? "split" : "single-folder",
        codeRoot: candidateCode,
        runtimeRoot: candidateRuntime
      )
      if !candidateResult.projects.isEmpty {
        return candidate
      }
    }

    return nil
  }

  private func applyRecoveredWorkspaceSuggestion(_ suggestion: WorkspaceSuggestion) {
    selectedProfile = suggestion.style == .split ? .diamond : .public
    useCurrentRoot = true
    syncWorkspaceDraftsFromResolvedRoots()
  }

  func refreshLiveServices() {
    isLoadingLiveServices = true
    liveServicesStatus = "Scanning active devcontainers and runner services for the current workspace..."
    let roots = resolvedProfileRoots()
    let currentProjects = localProjects
    let environment = baseEnvironment()
    let includeDockerChecks = appSettings.runDockerChecksOnRefresh

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.scanLiveServices(
        localProjects: currentProjects,
        runtimeRoot: roots.runtimeRoot,
        includeDocker: includeDockerChecks,
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingLiveServices = false
        self.activeContainers = result.containers
        self.runnerServices = result.runners
        self.liveServicesStatus = result.status
      }
    }
  }

  func openLocalProject(_ project: LocalProjectEntry, preferRuntime: Bool) {
    openProjectPaths(
      codePath: project.codePath,
      runtimePath: project.runtimePath,
      fallbackPath: project.preferredOpenPath,
      preferRuntime: preferRuntime,
      label: project.slug
    )
  }

  func revealLocalProject(_ project: LocalProjectEntry) {
    guard let targetPath = project.preferredOpenPath else {
      appendLog("[gui] No local path was found for \(project.slug)\n")
      return
    }
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: targetPath)])
  }

  func revealCodeRoot() {
    let roots = resolvedProfileRoots()
    revealPath(roots.codeRoot)
  }

  func revealRuntimeRoot() {
    let roots = resolvedProfileRoots()
    revealPath(roots.runtimeRoot)
  }

  func openContainerProject(_ entry: LiveContainerEntry, preferRuntime: Bool) {
    openProjectPaths(
      codePath: entry.codePath,
      runtimePath: entry.runtimePath,
      fallbackPath: entry.workspacePath,
      preferRuntime: preferRuntime,
      label: entry.slug
    )
  }

  func revealContainer(_ entry: LiveContainerEntry) {
    revealPath(entry.workspacePath)
  }

  func stopContainer(_ entry: LiveContainerEntry) {
    guard let dockerPath else {
      appendLog("[gui] Docker CLI was not found.\n")
      return
    }

    appendLog("[gui] Stopping devcontainer \(entry.name) for \(entry.slug)\n")
    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: dockerPath,
        arguments: ["stop", entry.containerID],
        environment: environment
      )

      DispatchQueue.main.async {
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
          self.appendLog(result.output + "\n")
        }
        self.refreshLiveServices()
      }
    }
  }

  func removeContainer(_ entry: LiveContainerEntry) {
    guard let dockerPath else {
      appendLog("[gui] Docker CLI was not found.\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Container", title: "Remove container", target: entry.slug, detail: "Removing container…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: dockerPath,
        arguments: ["rm", "-f", entry.containerID],
        environment: environment
      )

      DispatchQueue.main.async {
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          self.appendLog(result.output + "\n")
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: "Container removed.")
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to remove container." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
        self.refreshLiveServices()
      }
    }
  }

  func openContainerLogs(_ entry: LiveContainerEntry) {
    guard let dockerPath else {
      appendLog("[gui] Docker CLI was not found.\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Container", title: "Container logs", target: entry.slug, detail: "Loading container logs…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: dockerPath,
        arguments: ["logs", "--tail", "200", entry.containerID],
        environment: environment
      )

      DispatchQueue.main.async {
        if !result.output.isEmpty {
          self.appendLog(result.output + (result.output.hasSuffix("\n") ? "" : "\n"))
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: "Container logs loaded.")
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load container logs." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func openRunnerProject(_ entry: RunnerServiceEntry, preferRuntime: Bool) {
    openProjectPaths(
      codePath: entry.codePath,
      runtimePath: entry.runtimePath,
      fallbackPath: entry.runnerPath,
      preferRuntime: preferRuntime,
      label: entry.slug
    )
  }

  func revealRunnerService(_ entry: RunnerServiceEntry) {
    revealPath(entry.runnerPath)
  }

  func stopRunnerService(_ entry: RunnerServiceEntry) {
    let svcPath = (entry.runnerPath as NSString).appendingPathComponent("svc.sh")
    guard FileManager.default.isExecutableFile(atPath: svcPath) else {
      appendLog("[gui] Runner service script was not found for \(entry.slug)\n")
      return
    }

    appendLog("[gui] Stopping runner service for \(entry.slug)\n")
    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: "/bin/bash",
        arguments: ["-lc", "cd \(shellQuote(entry.runnerPath)) && ./svc.sh stop"],
        environment: environment
      )

      DispatchQueue.main.async {
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
          self.appendLog(result.output + "\n")
        }
        self.refreshLiveServices()
      }
    }
  }

  func startRunnerService(_ entry: RunnerServiceEntry) {
    runRunnerService(entry, command: "./svc.sh start", title: "Start runner", successMessage: "Runner service started.")
  }

  func restartRunnerService(_ entry: RunnerServiceEntry) {
    runRunnerService(entry, command: "./svc.sh stop || true; ./svc.sh start", title: "Restart runner", successMessage: "Runner service restarted.")
  }

  func verifyRunnerService(_ entry: RunnerServiceEntry) {
    runRunnerService(entry, command: "./svc.sh status", title: "Verify runner", successMessage: "Runner service status loaded.")
  }

  private func runRunnerService(_ entry: RunnerServiceEntry, command: String, title: String, successMessage: String) {
    let svcPath = (entry.runnerPath as NSString).appendingPathComponent("svc.sh")
    guard FileManager.default.isExecutableFile(atPath: svcPath) else {
      appendLog("[gui] Runner service script was not found for \(entry.slug)\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Runner", title: title, target: entry.slug, detail: "\(title)…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: "/bin/bash",
        arguments: ["-lc", "cd \(shellQuote(entry.runnerPath)) && \(command)"],
        environment: environment
      )

      DispatchQueue.main.async {
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          self.appendLog(result.output + "\n")
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(title) failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
        self.refreshLiveServices()
      }
    }
  }

  func openDevcontainerConfig(for project: LocalProjectEntry) {
    let roots = [project.runtimePath, project.codePath].compactMap { $0 }
    for root in roots {
      let configPath = (root as NSString).appendingPathComponent(".devcontainer/devcontainer.json")
      if FileManager.default.fileExists(atPath: configPath) {
        openProjectPaths(codePath: configPath, runtimePath: nil, fallbackPath: configPath, preferRuntime: false, label: project.slug)
        return
      }
    }
    appendLog("[gui] No devcontainer config was found for \(project.slug)\n")
  }

  func buildDevcontainer(for project: LocalProjectEntry) {
    runDevcontainerCommand(for: project, title: "Build devcontainer", arguments: ["build", "--workspace-folder"])
  }

  func upDevcontainer(for project: LocalProjectEntry) {
    runDevcontainerCommand(for: project, title: "Start devcontainer", arguments: ["up", "--workspace-folder", "--skip-post-create"])
  }

  func rebuildDevcontainer(for project: LocalProjectEntry) {
    runDevcontainerCommand(for: project, title: "Rebuild devcontainer", arguments: ["up", "--workspace-folder", "--remove-existing-container", "--skip-post-create"])
  }

  private func runDevcontainerCommand(for project: LocalProjectEntry, title: String, arguments: [String]) {
    guard let workspacePath = project.runtimePath ?? project.codePath else {
      appendLog("[gui] No local workspace was found for \(project.slug)\n")
      return
    }
    guard let devcontainerPath = executablePath(named: "devcontainer") else {
      appendLog("[gui] Devcontainer CLI was not found.\n")
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "Devcontainer", title: title, target: project.slug, detail: "\(title)…", initialState: .running)
    let fullArguments = arguments + [workspacePath]

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: devcontainerPath, arguments: fullArguments, environment: environment)
      DispatchQueue.main.async {
        if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          self.appendLog(result.output + "\n")
          self.updateJob(id: jobID, appendLog: result.output)
        }
        if result.status == 0 {
          self.finishJob(id: jobID, state: .succeeded, detail: "\(title) finished.")
          self.refreshLiveServices()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(title) failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func refreshAuthStatus() {
    guard let ghPath else {
      isAuthenticated = false
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first. The GUI and CLI both depend on gh."
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedHost.isEmpty else {
      isAuthenticated = false
      statusKind = .warning
      statusTitle = "GitHub Host Required"
      statusDetail = "Enter a GitHub host, then refresh login status."
      return
    }

    statusKind = .running
    statusTitle = "Checking Login Status"
    statusDetail = "Validating GitHub CLI authentication for \(selectedHost)."

    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["auth", "status", "--hostname", selectedHost],
        environment: environment
      )

      DispatchQueue.main.async {
        self.reloadAuthInventory()
        let cleaned = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedCleaned = redactSensitiveText(cleaned)
        let resolvedAccount = self.account.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.status == 0 {
          self.isAuthenticated = !resolvedAccount.isEmpty || self.selectedHostConfig?.activeUser != nil
          if self.repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.repoOwner = resolvedAccount.isEmpty ? (self.selectedHostConfig?.activeUser ?? "") : resolvedAccount
          }
          self.statusKind = .ready
          self.statusTitle = "GitHub Ready @ \(selectedHost)"
          self.statusDetail = sanitizedCleaned.isEmpty
            ? "User \(resolvedAccount.isEmpty ? (self.selectedHostConfig?.activeUser ?? "Unknown") : resolvedAccount) on account \(resolvedAccount.isEmpty ? (self.selectedHostConfig?.activeUser ?? "Unknown") : resolvedAccount) ready."
            : "User \(resolvedAccount.isEmpty ? (self.selectedHostConfig?.activeUser ?? "Unknown") : resolvedAccount) on account \(resolvedAccount.isEmpty ? (self.selectedHostConfig?.activeUser ?? "Unknown") : resolvedAccount) ready.\n\(sanitizedCleaned)"
          self.githubAccountStatus = self.statusDetail
          self.fetchAvailableRepos()
          self.fetchViewerOrganizations()
        } else {
          self.isAuthenticated = false
          self.clearRepoCatalog(resetOwner: false)
          self.statusKind = .warning
          self.statusTitle = "GitHub Login Required @ \(selectedHost)"
          self.statusDetail = sanitizedCleaned.isEmpty
            ? "Run gh auth login -h \(selectedHost) before cleanup."
            : sanitizedCleaned
          self.githubAccountStatus = self.statusDetail
          self.viewerOrganizations = []
        }
      }
    }
  }

  func openGitHubLogin() {
    guard let ghPath else {
      appendLog("[gui] GitHub CLI was not found.\n")
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first, then try login again."
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let command = [
      "export PATH=\(shellQuote(defaultSearchPaths.joined(separator: ":")))",
      "\(shellQuote(ghPath)) auth login -h \(shellQuote(selectedHost.isEmpty ? "github.com" : selectedHost))",
      "EXIT_CODE=$?",
      "printf '\\n'",
      "if [ $EXIT_CODE -eq 0 ]; then echo 'GitHub login finished.'; else echo \"GitHub login exited with code $EXIT_CODE.\"; fi",
      "echo",
      "read -r -p 'Press Enter to close this window...' _"
    ].joined(separator: "; ")

    openTerminalCommand(command)
  }

  private func profileArguments() -> [String] {
    var args = ["--profile", selectedProfile.rawValue]
    if useCurrentRoot {
      args.append("--use-current-root")
    }
    return args
  }

  private func terminalCommandString(arguments: [String], exitLabel: String) -> String? {
    guard let cliPath else {
      appendLog("[gui] Bundled CLI was not found.\n")
      return nil
    }

    let commandParts = [shellQuote(cliPath)] + arguments.map(shellQuote)
    return [
      "export PATH=\(shellQuote(defaultSearchPaths.joined(separator: ":")))",
      commandParts.joined(separator: " "),
      "EXIT_CODE=$?",
      "printf '\\n'",
      "if [ $EXIT_CODE -eq 0 ]; then echo '\(exitLabel) finished.'; else echo \"\(exitLabel) exited with code $EXIT_CODE.\"; fi",
      "echo",
      "read -r -p 'Press Enter to close this window...' _"
    ].joined(separator: "; ")
  }

  func openCLIInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments(), exitLabel: appTitle) else {
      return
    }
    openTerminalCommand(command)
  }

  func openProjectBrowserInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse"], exitLabel: "Project Browser") else {
      return
    }
    openTerminalCommand(command)
  }

  func openCostControlReviewInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse-cost-control"], exitLabel: "Cost-Control Review") else {
      return
    }
    openTerminalCommand(command)
  }

  func openInstalledDevcontainersInTerminal() {
    guard let command = terminalCommandString(arguments: profileArguments() + ["--browse-devcontainers"], exitLabel: "Installed Devcontainers") else {
      return
    }
    openTerminalCommand(command)
  }

  func cancelRun() {
    cancellationRequested = true
    pendingRepoTargets.removeAll()
    runningProcess?.terminate()
  }

  func logoutSelectedAccount() {
    guard let ghPath else {
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first."
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedHost.isEmpty, !selectedAccount.isEmpty else {
      statusKind = .warning
      statusTitle = "No Account Selected"
      statusDetail = "Choose an authenticated account before logging out."
      return
    }

    isLoggingOut = true
    appendLog("[gui] Logging out \(selectedAccount) on \(selectedHost)\n")

    let environment = baseEnvironment()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["auth", "logout", "--hostname", selectedHost, "--user", selectedAccount],
        environment: environment,
        stdin: "y\n"
      )

      DispatchQueue.main.async {
        self.isLoggingOut = false
        let cleaned = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
          self.appendLog(cleaned + "\n")
        }
        self.viewerOrganizations = []
        self.githubAccountStatus = "Logged out. Refresh or log in again to load connected account details."
        self.safetyArmEnabled = false
        self.clearRepoCatalog(resetOwner: false)
        self.reloadAuthInventory()
        self.refreshAuthStatus()
      }
    }
  }

  func fetchViewerOrganizations() {
    guard let ghPath else {
      githubAccountStatus = "GitHub CLI was not found."
      return
    }

    guard isAuthenticated else {
      viewerOrganizations = []
      githubAccountStatus = "Log in first to load organizations and connected account details."
      return
    }

    isLoadingGitHubAccountDetails = true
    githubAccountStatus = "Loading connected GitHub account details..."
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let environment = baseEnvironment().merging(["GH_HOST": selectedHost]) { _, new in new }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["api", "user/orgs", "--jq", ".[].login"],
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingGitHubAccountDetails = false
        if result.status == 0 {
          self.viewerOrganizations = result.output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
          let orgLabel = self.viewerOrganizations.isEmpty ? "No org memberships reported." : "\(self.viewerOrganizations.count) organization memberships loaded."
          self.githubAccountStatus = "\(self.sessionCompactLabel)\n\(orgLabel)"
        } else {
          self.viewerOrganizations = []
          let cleaned = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.githubAccountStatus = cleaned.isEmpty ? "Failed to load organizations for the connected account." : cleaned
        }
      }
    }
  }

  func openGitHubHostPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)") else {
      appendLog("[gui] GitHub host URL is invalid.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openGitHubAccountPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedAccount.isEmpty,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(selectedAccount)") else {
      appendLog("[gui] No connected GitHub account is selected.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openGitHubRepositoriesPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selectedAccount.isEmpty,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(selectedAccount)?tab=repositories") else {
      appendLog("[gui] No connected GitHub account is selected.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openGitHubSettingsPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/settings/profile") else {
      appendLog("[gui] GitHub settings URL is invalid.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openRepoSettingsPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let repo = primaryRepoSlug,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(repo)/settings") else {
      appendLog("[gui] No repository target is available to open in settings.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openRepoOwnerPage() {
    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let owner = repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? account.trimmingCharacters(in: .whitespacesAndNewlines)
      : repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !owner.isEmpty,
          let url = URL(string: "https://\(selectedHost.isEmpty ? "github.com" : selectedHost)/\(owner)") else {
      appendLog("[gui] No owner or org is available to open.\n")
      return
    }
    NSWorkspace.shared.open(url)
  }

  func openBundledHelpDocument(_ fileName: String) {
    guard let url = bundledResourceURL(named: fileName, subdirectory: bundledHelpDirectory) ?? bundledResourceURL(named: fileName) else {
      appendLog("[gui] Help document not found: \(fileName)\n")
      return
    }

    NSWorkspace.shared.open(url)
  }

  func openCompanyWebsite() {
    guard let url = URL(string: companyWebsiteURL) else {
      appendLog("[gui] Company website URL is invalid.\n")
      return
    }

    NSWorkspace.shared.open(url)
  }

  func revealSessionStorage() {
    let supportURL = URL(fileURLWithPath: appSupportDir, isDirectory: true)
    try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
    NSWorkspace.shared.activateFileViewerSelecting([supportURL])
  }

  func revealBundledHelpDirectory() {
    guard let helpURL = bundledResourceURL(named: bundledHelpDirectory) ?? bundledResourceURL(named: "docs") else {
      appendLog("[gui] Bundled help directory was not found.\n")
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting([helpURL])
  }

  func setAllLoadedReposSelected(_ enabled: Bool) {
    if enabled {
      selectedRepos.formUnion(availableRepos.map(\.nameWithOwner))
    } else {
      selectedRepos.subtract(availableRepos.map(\.nameWithOwner))
    }

    if appSettings.autoLoadRepoHealth, !selectedRepos.isEmpty {
      loadRepoHealthForSelectedRepos()
    }
  }

  func toggleRepoSelection(_ repo: RepoCatalogEntry) {
    if selectedRepos.contains(repo.nameWithOwner) {
      selectedRepos.remove(repo.nameWithOwner)
    } else {
      selectedRepos.insert(repo.nameWithOwner)
    }

    if appSettings.autoLoadRepoHealth, !selectedRepos.isEmpty {
      loadRepoHealthForSelectedRepos()
    }
  }

  func setFilteredLocalProjectsSelected(_ enabled: Bool) {
    let slugs = filteredLocalProjects.map(\.slug)
    if enabled {
      selectedRepos.formUnion(slugs)
    } else {
      selectedRepos.subtract(slugs)
    }
  }

  func toggleLocalProjectTarget(_ project: LocalProjectEntry) {
    if selectedRepos.contains(project.slug) {
      selectedRepos.remove(project.slug)
    } else {
      selectedRepos.insert(project.slug)
    }
  }

  func toggleFavorite(_ project: LocalProjectEntry) {
    if favoriteProjects.contains(project.slug) {
      favoriteProjects.remove(project.slug)
    } else {
      favoriteProjects.insert(project.slug)
    }
    persistFavorites()
  }

  func saveCurrentProjectView() {
    let trimmedName = savedViewNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      settingsStatus = "Enter a name before saving a project view."
      return
    }

    let entry = SavedProjectView(
      id: UUID().uuidString,
      name: trimmedName,
      query: localProjectSearch,
      favoritesOnly: showFavoritesOnly
    )
    savedProjectViews.insert(entry, at: 0)
    persistSavedViews()
    savedViewNameDraft = ""
    settingsStatus = "Saved project view: \(entry.name)"
  }

  func applyProjectView(_ view: SavedProjectView) {
    localProjectSearch = view.query
    showFavoritesOnly = view.favoritesOnly
  }

  func deleteProjectView(_ view: SavedProjectView) {
    savedProjectViews.removeAll { $0.id == view.id }
    persistSavedViews()
  }

  func saveCurrentContext() {
    let name = contextNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      settingsStatus = "Enter a name before saving a GitHub context."
      return
    }

    let context = SavedGitHubContext(
      id: UUID().uuidString,
      name: name,
      host: host.trimmingCharacters(in: .whitespacesAndNewlines),
      account: account.trimmingCharacters(in: .whitespacesAndNewlines),
      owner: repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    savedContexts.insert(context, at: 0)
    persistContexts()
    contextNameDraft = ""
    settingsStatus = "Saved GitHub context: \(context.name)"
  }

  func applyContext(_ context: SavedGitHubContext) {
    host = context.host
    account = context.account
    repoOwner = context.owner
    repoTarget = ""
    selectedRepos.removeAll()
    refreshAuthStatus()
  }

  func deleteContext(_ context: SavedGitHubContext) {
    savedContexts.removeAll { $0.id == context.id }
    persistContexts()
  }

  func saveSettings() {
    appSettings.defaultGitHubHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appSettings.defaultGitHubHost : host.trimmingCharacters(in: .whitespacesAndNewlines)
    appSettings.firstRunComplete = true
    persistSettings()
    settingsStatus = "Settings saved."
  }

  func applyBackupPreset(_ preset: BackupPreset) {
    selectedBackupPreset = preset
    switch preset {
    case .codeOnly:
      localFileExportScope = .codeWorkspace
      includeProjectCodeExport = true
      includeProjectRuntimeExport = false
      includeProjectRunnerExport = false
    case .runtimeOnly:
      localFileExportScope = .runtimeWorkspace
      includeProjectCodeExport = false
      includeProjectRuntimeExport = true
      includeProjectRunnerExport = false
    case .projectBundle:
      localFileExportScope = .selectedProjects
      includeProjectCodeExport = true
      includeProjectRuntimeExport = true
      includeProjectRunnerExport = true
    case .runnerBundle:
      localFileExportScope = .selectedProjects
      includeProjectCodeExport = false
      includeProjectRuntimeExport = false
      includeProjectRunnerExport = true
    case .fullWorkspace:
      localFileExportScope = .workspaceBundle
      includeProjectCodeExport = true
      includeProjectRuntimeExport = true
      includeProjectRunnerExport = true
    }
  }

  func previewWorkspaceMove(_ scope: WorkspaceRelocationScope) {
    let destination = normalizeWorkspacePath(workspaceMoveDestinationDraft)
    guard !destination.isEmpty else {
      localFilesStatus = "Choose a destination before previewing the workspace move."
      return
    }

    let roots = resolvedProfileRoots()
    localExportPreparedStamp = ""
    localOperationPreview = Self.buildWorkspaceMovePreview(
      scope: scope,
      style: selectedWorkspaceStyle,
      codeRoot: roots.codeRoot,
      runtimeRoot: roots.runtimeRoot,
      destinationBase: destination
    )
    localFilesStatus = "Preview ready for \(localOperationPreview?.title.lowercased() ?? "workspace move")."
  }

  func previewLocalExport() {
    let destination = normalizeWorkspacePath(localExportDestinationDraft)
    guard !destination.isEmpty else {
      localFilesStatus = "Choose a destination before previewing the local file export."
      return
    }

    let roots = resolvedProfileRoots()
    let preparedStamp = Self.timestampStamp()
    localExportPreparedStamp = preparedStamp
    localOperationPreview = Self.buildLocalExportPreview(
      scope: localFileExportScope,
      mode: localFileTransferMode,
      destinationBase: destination,
      preparedStamp: preparedStamp,
      roots: roots,
      selectedProjects: selectedLocalProjects,
      includeCode: includeProjectCodeExport,
      includeRuntime: includeProjectRuntimeExport,
      includeRunners: includeProjectRunnerExport
    )
    localFilesStatus = "Preview ready for \(localOperationPreview?.title.lowercased() ?? "local file export")."
  }

  func createSnapshot() {
    let roots = resolvedProfileRoots()
    let selectedProjects = selectedLocalProjects
    let snapshotID = UUID().uuidString
    let payloadPath = (snapshotsDirectory as NSString).appendingPathComponent(snapshotID)
    let environment = baseEnvironment()
    let scope = localFileExportScope
    let fallbackPrimaryProject = primaryLocalProject
    let includeCode = includeProjectCodeExport
    let includeRuntime = includeProjectRuntimeExport
    let includeRunners = includeProjectRunnerExport

    let jobID = createJob(kind: "Snapshot", title: "Create snapshot", target: primaryRepoSlug ?? "", detail: "Preparing snapshot…", initialState: .running)
    isRunningLocalFileOperation = true
    snapshotStatus = "Creating snapshot..."

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        try FileManager.default.createDirectory(atPath: payloadPath, withIntermediateDirectories: true, attributes: nil)
        _ = try Self.exportLocalFiles(
          scope: scope,
          mode: .copyBackup,
          destinationBase: payloadPath,
          roots: roots,
          selectedProjects: selectedProjects.isEmpty ? (fallbackPrimaryProject.map { [$0] } ?? []) : selectedProjects,
          includeCode: includeCode,
          includeRuntime: includeRuntime,
          includeRunners: includeRunners,
          overwrite: true,
          environment: environment
        )

        let itemCount = (selectedProjects.isEmpty ? (fallbackPrimaryProject == nil ? 0 : 1) : selectedProjects.count)
        let entry = SnapshotEntry(
          id: snapshotID,
          name: "Snapshot \(Self.timestampStamp())",
          createdAt: Date(),
          sourceScope: scope.label,
          destinationPath: payloadPath,
          itemCount: itemCount
        )

        DispatchQueue.main.async {
          self.writeSnapshot(entry)
          self.isRunningLocalFileOperation = false
          self.snapshotStatus = "Snapshot created."
          self.updateJob(id: jobID, appendLog: "Snapshot created at \(payloadPath)")
          self.finishJob(id: jobID, state: .succeeded, detail: "Snapshot created.")
        }
      } catch {
        DispatchQueue.main.async {
          self.isRunningLocalFileOperation = false
          self.snapshotStatus = error.localizedDescription
          self.finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
        }
      }
    }
  }

  func restoreSnapshot(_ entry: SnapshotEntry) {
    let roots = resolvedProfileRoots()
    let payloadPath = entry.destinationPath
    let environment = baseEnvironment()
    let jobID = createJob(kind: "Snapshot", title: "Restore snapshot", target: entry.name, detail: "Restoring snapshot…", initialState: .running)
    snapshotStatus = "Restoring snapshot..."

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }

      do {
        try Self.restoreSnapshotPayload(payloadPath: payloadPath, roots: roots, environment: environment)
        DispatchQueue.main.async {
          self.snapshotStatus = "Snapshot restored."
          self.finishJob(id: jobID, state: .succeeded, detail: "Snapshot restored.")
          self.refreshLocalProjects()
        }
      } catch {
        DispatchQueue.main.async {
          self.snapshotStatus = error.localizedDescription
          self.finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
        }
      }
    }
  }

  func removeSnapshot(_ entry: SnapshotEntry) {
    deleteSnapshot(entry)
    snapshotStatus = "Snapshot removed."
  }

  func addTaskTemplate() {
    guard let project = primaryLocalProject else {
      taskStatus = "Select or target a local project before adding a task."
      return
    }
    let name = taskNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    let command = taskCommandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !command.isEmpty else {
      taskStatus = "Enter both a task name and command."
      return
    }

    let task = ProjectTaskTemplate(
      id: UUID().uuidString,
      slug: project.slug,
      name: name,
      command: command,
      location: taskLocationDraft
    )
    taskTemplates.insert(task, at: 0)
    persistTasks()
    taskNameDraft = ""
    taskCommandDraft = ""
    taskStatus = "Saved task \(task.name) for \(project.slug)."
  }

  func removeTaskTemplate(_ task: ProjectTaskTemplate) {
    taskTemplates.removeAll { $0.id == task.id }
    persistTasks()
  }

  func runTaskTemplate(_ task: ProjectTaskTemplate) {
    guard let project = localProjects.first(where: { $0.slug == task.slug }) else {
      taskStatus = "Project for task \(task.name) was not found."
      return
    }

    let workingPath: String?
    switch task.location {
    case .code: workingPath = project.codePath ?? project.runtimePath
    case .runtime: workingPath = project.runtimePath ?? project.codePath
    }

    guard let workingPath else {
      taskStatus = "No working path was found for \(project.slug)."
      return
    }

    isRunningTask = true
    let jobID = createJob(kind: "Task", title: task.name, target: project.slug, detail: "Running task…", initialState: .running)
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-lc", "cd \(shellQuote(workingPath)) && \(task.command)"]
    process.environment = baseEnvironment()
    process.standardOutput = pipe
    process.standardError = pipe
    runningProcess = process
    activeJobID = jobID

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard data.isEmpty == false, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
      DispatchQueue.main.async {
        self?.appendLog(chunk)
        self?.updateJob(id: jobID, appendLog: chunk)
      }
    }

    process.terminationHandler = { [weak self] process in
      let tail = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.readabilityHandler = nil
      let tailText = String(data: tail, encoding: .utf8) ?? ""
      DispatchQueue.main.async {
        guard let self else { return }
        if !tailText.isEmpty {
          self.appendLog(tailText)
          self.updateJob(id: jobID, appendLog: tailText)
        }
        self.runningProcess = nil
        self.activeJobID = nil
        self.isRunningTask = false
        if process.terminationStatus == 0 {
          self.taskStatus = "Task finished successfully."
          self.finishJob(id: jobID, state: .succeeded, detail: "Task finished successfully.")
        } else {
          self.taskStatus = "Task failed with exit code \(process.terminationStatus)."
          self.finishJob(id: jobID, state: .failed, detail: "Task failed with exit code \(process.terminationStatus).")
        }
      }
    }

    do {
      try process.run()
    } catch {
      runningProcess = nil
      activeJobID = nil
      isRunningTask = false
      taskStatus = error.localizedDescription
      finishJob(id: jobID, state: .failed, detail: error.localizedDescription)
    }
  }

  func fetchAvailableRepos() {
    guard let ghPath else {
      repoCatalogStatus = "GitHub CLI was not found."
      return
    }

    let selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    let targetOwner = repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? account.trimmingCharacters(in: .whitespacesAndNewlines)
      : repoOwner.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !selectedHost.isEmpty else {
      repoCatalogStatus = "Enter a GitHub host first."
      return
    }

    guard isAuthenticated else {
      repoCatalogStatus = "Log into GitHub CLI first, then load repositories."
      return
    }

    guard !targetOwner.isEmpty else {
      repoCatalogStatus = "Enter an owner or org to list repositories."
      return
    }

    isLoadingRepos = true
    repoCatalogStatus = "Loading repositories for \(targetOwner) on \(selectedHost)..."
    appendLog("[gui] Loading repositories for \(targetOwner) on \(selectedHost)\n")

    let environment = baseEnvironment().merging(["GH_HOST": selectedHost]) { _, new in new }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: [
          "repo", "list", targetOwner,
          "--limit", "1000",
          "--json", "nameWithOwner,visibility,isPrivate,updatedAt,url"
        ],
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingRepos = false
        let cleaned = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedCleaned = redactSensitiveText(cleaned)

        guard result.status == 0 else {
          self.availableRepos = []
          self.repoCatalogStatus = sanitizedCleaned.isEmpty
            ? "Failed to load repositories for \(targetOwner)."
            : sanitizedCleaned
          return
        }

        let data = Data(result.output.utf8)
        do {
          let decoded = try JSONDecoder().decode([RepoCatalogEntry].self, from: data)
          self.availableRepos = decoded.sorted { $0.nameWithOwner.localizedCaseInsensitiveCompare($1.nameWithOwner) == .orderedAscending }
          if self.availableRepos.isEmpty {
            self.repoCatalogStatus = "No repositories found for \(targetOwner) on \(selectedHost)."
          } else {
            self.repoCatalogStatus = "Loaded \(self.availableRepos.count) repositories for \(targetOwner)."
          }
        } catch {
          self.availableRepos = []
          self.repoCatalogStatus = "Failed to decode repository list: \(error.localizedDescription)"
        }
      }
    }
  }

  func loadRepoHealthForSelectedRepos() {
    let targets = selectedRepos.isEmpty ? (primaryRepoSlug.map { [$0] } ?? []) : Array(selectedRepos).sorted()
    loadRepoHealth(for: targets, label: "selected")
  }

  func loadRepoHealthForVisibleRepos() {
    let visible = filteredRepos.prefix(20).map(\.nameWithOwner)
    loadRepoHealth(for: visible, label: "visible")
  }

  private func loadRepoHealth(for targets: [String], label: String) {
    guard let ghPath else {
      repoHealthStatus = "GitHub CLI was not found."
      return
    }
    guard !targets.isEmpty else {
      repoHealthStatus = "Select or load at least one repository first."
      return
    }

    isLoadingRepoHealth = true
    let environment = baseEnvironment()
    let localProjects = self.localProjects
    let jobID = createJob(kind: "GitHub", title: "Repo health scan", target: "\(targets.count) repos", detail: "Loading repo health…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let entries = targets.map { slug in
        Self.scanRepoHealth(slug: slug, ghPath: ghPath, localProjects: localProjects, environment: environment)
      }

      DispatchQueue.main.async {
        self.isLoadingRepoHealth = false
        self.repoHealthEntries = entries.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
        self.repoHealthStatus = "Loaded repo health for \(entries.count) \(label) repos."
        self.finishJob(id: jobID, state: .succeeded, detail: "Loaded repo health for \(entries.count) repos.")
      }
    }
  }

  func loadWorkflowCatalog() {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }

    isLoadingWorkflowData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Workflow catalog", target: repo, detail: "Loading workflows…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["workflow", "list", "--all", "--json", "id,name,path,state", "-R", repo],
        environment: environment
      )

      DispatchQueue.main.async {
        self.isLoadingWorkflowData = false
        if result.status == 0, let data = result.output.data(using: .utf8), let decoded = try? JSONDecoder().decode([WorkflowCatalogEntry].self, from: data) {
          self.workflows = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
          self.workflowStatus = "Loaded \(decoded.count) workflows for \(repo)."
          self.finishJob(id: jobID, state: .succeeded, detail: "Loaded \(decoded.count) workflows.")
          if self.appSettings.autoLoadWorkflowRuns {
            self.loadWorkflowRuns()
          }
        } else {
          self.workflowStatus = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load workflows." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: self.workflowStatus)
        }
      }
    }
  }

  func loadWorkflowRuns() {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }

    isLoadingWorkflowData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Workflow runs", target: repo, detail: "Loading workflow runs…", initialState: .running)
    let arguments = ["run", "list", "--all", "--limit", "50", "--json", "databaseId,name,workflowName,displayTitle,event,headBranch,status,conclusion,createdAt,updatedAt", "-R", repo]

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: arguments, environment: environment)
      DispatchQueue.main.async {
        self.isLoadingWorkflowData = false
        if result.status == 0, let data = result.output.data(using: .utf8), let decoded = try? JSONDecoder().decode([WorkflowRunEntry].self, from: data) {
          self.workflowRuns = decoded
          self.workflowStatus = "Loaded \(decoded.count) workflow runs for \(repo)."
          self.finishJob(id: jobID, state: .succeeded, detail: "Loaded \(decoded.count) workflow runs.")
        } else {
          self.workflowStatus = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load workflow runs." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.finishJob(id: jobID, state: .failed, detail: self.workflowStatus)
        }
      }
    }
  }

  func enableWorkflow(_ workflow: WorkflowCatalogEntry) {
    mutateWorkflow(workflow, verb: "enable", successMessage: "Workflow enabled.")
  }

  func disableWorkflow(_ workflow: WorkflowCatalogEntry) {
    mutateWorkflow(workflow, verb: "disable", successMessage: "Workflow disabled.")
  }

  private func mutateWorkflow(_ workflow: WorkflowCatalogEntry, verb: String, successMessage: String) {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }

    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "\(verb.capitalized) workflow", target: workflow.name, detail: "\(verb.capitalized) workflow…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: ["workflow", verb, "\(workflow.id)", "-R", repo], environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.workflowStatus = successMessage
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
          self.loadWorkflowCatalog()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workflow action failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.workflowStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func runWorkflow(_ workflow: WorkflowCatalogEntry) {
    guard let ghPath else {
      workflowStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Dispatch workflow", target: workflow.name, detail: "Triggering workflow dispatch…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: ["workflow", "run", workflow.path, "-R", repo], environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.workflowStatus = "Workflow dispatch requested for \(workflow.name)."
          self.finishJob(id: jobID, state: .succeeded, detail: self.workflowStatus)
          self.loadWorkflowRuns()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to dispatch workflow." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.workflowStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func openWorkflowSource(_ workflow: WorkflowCatalogEntry) {
    guard let repo = primaryRepoSlug else { return }
    if let project = localProjects.first(where: { $0.slug == repo }), let codePath = project.codePath {
      let localPath = (codePath as NSString).appendingPathComponent(workflow.path)
      if FileManager.default.fileExists(atPath: localPath) {
        openProjectPaths(codePath: localPath, runtimePath: nil, fallbackPath: localPath, preferRuntime: false, label: workflow.name)
        return
      }
    }
    if let url = URL(string: "https://\(host)/\(repo)/blob/HEAD/\(workflow.path)") {
      NSWorkspace.shared.open(url)
    }
  }

  func cancelWorkflowRun(_ run: WorkflowRunEntry) {
    mutateRun(run, args: ["run", "cancel", "\(run.databaseId)", "-R", primaryRepoSlug ?? ""], successMessage: "Workflow run cancelled.")
  }

  func rerunWorkflowRun(_ run: WorkflowRunEntry) {
    mutateRun(run, args: ["run", "rerun", "\(run.databaseId)", "-R", primaryRepoSlug ?? ""], successMessage: "Workflow run rerun requested.")
  }

  func deleteWorkflowRun(_ run: WorkflowRunEntry) {
    mutateRun(run, args: ["run", "delete", "\(run.databaseId)", "-R", primaryRepoSlug ?? ""], successMessage: "Workflow run deleted.")
  }

  private func mutateRun(_ run: WorkflowRunEntry, args: [String], successMessage: String) {
    guard let ghPath, let repo = primaryRepoSlug else {
      workflowStatus = "Select a repository target first."
      return
    }
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Workflow run action", target: "\(run.databaseId)", detail: "Running workflow run action…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: args, environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.workflowStatus = successMessage
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
          self.loadWorkflowRuns()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Run action failed for \(repo)." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.workflowStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func openWorkflowRunInBrowser(_ run: WorkflowRunEntry) {
    guard let repo = primaryRepoSlug,
          let url = URL(string: "https://\(host)/\(repo)/actions/runs/\(run.databaseId)") else { return }
    NSWorkspace.shared.open(url)
  }

  func loadCodespaces() {
    guard let ghPath else {
      codespacesStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      codespacesStatus = "Select a repository target first."
      return
    }
    isLoadingCodespaces = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Codespaces inventory", target: repo, detail: "Loading Codespaces…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(
        executable: ghPath,
        arguments: ["codespace", "list", "--repo", repo, "--json", "name,displayName,state,lastUsedAt,machineName,repository"],
        environment: environment
      )
      DispatchQueue.main.async {
        self.isLoadingCodespaces = false
        if result.status == 0 {
          self.codespaces = Self.parseCodespaces(result.output)
          self.codespacesStatus = "Loaded \(self.codespaces.count) Codespaces for \(repo)."
          self.finishJob(id: jobID, state: .succeeded, detail: self.codespacesStatus)
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Failed to load Codespaces." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.codespacesStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func stopCodespace(_ entry: CodespaceInventoryEntry) {
    mutateCodespace(entry, args: ["codespace", "stop", "--codespace", entry.name], successMessage: "Codespace stopped.")
  }

  func deleteCodespace(_ entry: CodespaceInventoryEntry) {
    mutateCodespace(entry, args: ["codespace", "delete", "--codespace", entry.name, "--force"], successMessage: "Codespace deleted.")
  }

  private func mutateCodespace(_ entry: CodespaceInventoryEntry, args: [String], successMessage: String) {
    guard let ghPath else {
      codespacesStatus = "GitHub CLI was not found."
      return
    }
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Codespace action", target: entry.name, detail: "Running Codespace action…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let result = Self.runCommand(executable: ghPath, arguments: args, environment: environment)
      DispatchQueue.main.async {
        if result.status == 0 {
          self.codespacesStatus = successMessage
          self.finishJob(id: jobID, state: .succeeded, detail: successMessage)
          self.loadCodespaces()
        } else {
          let detail = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Codespace action failed." : result.output.trimmingCharacters(in: .whitespacesAndNewlines))
          self.codespacesStatus = detail
          self.finishJob(id: jobID, state: .failed, detail: detail)
        }
      }
    }
  }

  func loadSecretsAndVariables() {
    guard let ghPath else {
      secretsStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      secretsStatus = "Select a repository target first."
      return
    }

    let owner = repo.split(separator: "/").first.map(String.init) ?? repoOwner
    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let knownOrganizations = viewerOrganizations
    let shouldQueryOrgScope = !owner.isEmpty && (owner != selectedAccount || knownOrganizations.contains(owner))
    isLoadingSecretsData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Secrets and variables", target: repo, detail: "Loading secrets and variables…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let repoSecretsResult = Self.runCommand(executable: ghPath, arguments: ["secret", "list", "--json", "name,updatedAt,visibility", "-R", repo], environment: environment)
      let repoVariablesResult = Self.runCommand(executable: ghPath, arguments: ["variable", "list", "--json", "name,updatedAt,visibility", "-R", repo], environment: environment)
      let orgSecretsResult = shouldQueryOrgScope
        ? Self.runCommand(executable: ghPath, arguments: ["secret", "list", "--json", "name,updatedAt,visibility", "--org", owner], environment: environment)
        : CommandResult(status: 0, output: "[]")
      let orgVariablesResult = shouldQueryOrgScope
        ? Self.runCommand(executable: ghPath, arguments: ["variable", "list", "--json", "name,updatedAt,visibility", "--org", owner], environment: environment)
        : CommandResult(status: 0, output: "[]")

      DispatchQueue.main.async {
        self.isLoadingSecretsData = false
        self.repoSecrets = repoSecretsResult.status == 0 ? (Self.decodeJSONArray([SecretRecord].self, from: repoSecretsResult.output) ?? []) : []
        self.repoVariables = repoVariablesResult.status == 0 ? (Self.decodeJSONArray([VariableRecord].self, from: repoVariablesResult.output) ?? []) : []
        self.orgSecrets = orgSecretsResult.status == 0 ? (Self.decodeJSONArray([SecretRecord].self, from: orgSecretsResult.output) ?? []) : []
        self.orgVariables = orgVariablesResult.status == 0 ? (Self.decodeJSONArray([VariableRecord].self, from: orgVariablesResult.output) ?? []) : []

        var failures: [String] = []
        if repoSecretsResult.status != 0 { failures.append("repo secrets") }
        if repoVariablesResult.status != 0 { failures.append("repo variables") }
        if shouldQueryOrgScope {
          if orgSecretsResult.status != 0 { failures.append("org secrets") }
          if orgVariablesResult.status != 0 { failures.append("org variables") }
        }

        let orgScopeNote = shouldQueryOrgScope ? nil : "Organization-level inventory was skipped because the selected owner does not appear to be an organization context for this session."
        let summary = "Loaded \(self.repoSecrets.count) repo secrets, \(self.repoVariables.count) repo variables, \(self.orgSecrets.count) org secrets, and \(self.orgVariables.count) org variables."

        if failures.isEmpty {
          self.secretsStatus = [summary, orgScopeNote].compactMap { $0 }.joined(separator: "\n")
          self.finishJob(id: jobID, state: .succeeded, detail: summary)
        } else {
          let failureSummary = "Partial load only. Failed: \(failures.joined(separator: ", "))."
          self.secretsStatus = [summary, failureSummary, orgScopeNote].compactMap { $0 }.joined(separator: "\n")
          self.finishJob(id: jobID, state: .failed, detail: failureSummary)
        }
      }
    }
  }

  func loadBranchProtectionAndRulesets() {
    guard let ghPath else {
      rulesStatus = "GitHub CLI was not found."
      return
    }
    guard let repo = primaryRepoSlug else {
      rulesStatus = "Select a repository target first."
      return
    }
    isLoadingRulesData = true
    let environment = baseEnvironment()
    let jobID = createJob(kind: "GitHub", title: "Rules and protection", target: repo, detail: "Loading rulesets and branch protection…", initialState: .running)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let repoMeta = Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)"], environment: environment)
      let defaultBranch = Self.extractDefaultBranch(repoMeta.output)
      let protection = defaultBranch.isEmpty ? CommandResult(status: 0, output: "") : Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)/branches/\(defaultBranch)/protection"], environment: environment)
      let rulesets = Self.runCommand(executable: ghPath, arguments: ["api", "repos/\(repo)/rulesets"], environment: environment)

      DispatchQueue.main.async {
        self.isLoadingRulesData = false
        let protectionOutput = protection.output.lowercased()
        let branchIsUnprotected = protection.status != 0 && (
          protectionOutput.contains("branch not protected") ||
          protectionOutput.contains("\"message\":\"not found\"") ||
          protectionOutput.contains("\"message\": \"not found\"")
        )

        self.branchProtectionSummary = (protection.status == 0 || branchIsUnprotected)
          ? Self.parseBranchProtection(branch: defaultBranch, output: protection.output)
          : nil
        self.rulesets = rulesets.status == 0 ? Self.parseRulesets(rulesets.output) : []

        var failures: [String] = []
        if repoMeta.status != 0 { failures.append("repo metadata") }
        if !defaultBranch.isEmpty && protection.status != 0 && !branchIsUnprotected { failures.append("branch protection") }
        if rulesets.status != 0 { failures.append("rulesets") }

        let baseSummary: String
        if defaultBranch.isEmpty {
          baseSummary = "No default branch was reported for \(repo). Rulesets loaded: \(self.rulesets.count)."
        } else if branchIsUnprotected {
          baseSummary = "Loaded rulesets for \(repo). The default branch is not currently protected."
        } else {
          baseSummary = "Loaded branch rules for \(repo)."
        }

        if failures.isEmpty {
          self.rulesStatus = baseSummary
          self.finishJob(id: jobID, state: .succeeded, detail: baseSummary)
        } else {
          let failureSummary = "\(baseSummary)\nPartial load only. Failed: \(failures.joined(separator: ", "))."
          self.rulesStatus = failureSummary
          self.finishJob(id: jobID, state: .failed, detail: failureSummary)
        }
      }
    }
  }

  func loadStorageInsights() {
    let roots = resolvedProfileRoots()
    isLoadingStorageInsights = true
    let jobID = createJob(kind: "Local", title: "Storage insights", target: workspaceStyleLabel, detail: "Scanning storage usage…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let metrics = Self.scanStorageInsights(roots: roots)
      DispatchQueue.main.async {
        self.isLoadingStorageInsights = false
        self.storageInsights = metrics
        self.storageStatus = "Loaded \(metrics.count) storage metrics."
        self.finishJob(id: jobID, state: .succeeded, detail: self.storageStatus)
      }
    }
  }

  func loadProjectSyncStatus() {
    let localProjects = self.localProjects
    let environment = baseEnvironment()
    isLoadingProjectSync = true
    let jobID = createJob(kind: "Local", title: "Project sync status", target: "\(localProjects.count) projects", detail: "Scanning project sync state…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let entries = Self.scanProjectSync(localProjects: localProjects, environment: environment)
      DispatchQueue.main.async {
        self.isLoadingProjectSync = false
        self.projectSyncEntries = entries
        self.syncStatus = "Loaded sync status for \(entries.count) projects."
        self.finishJob(id: jobID, state: .succeeded, detail: self.syncStatus)
      }
    }
  }

  func loadPortMonitor() {
    let environment = baseEnvironment()
    isLoadingPorts = true
    let jobID = createJob(kind: "Local", title: "Port monitor", target: "Local services", detail: "Scanning listening ports…", initialState: .running)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let entries = Self.scanPorts(environment: environment)
      DispatchQueue.main.async {
        self.isLoadingPorts = false
        self.portMonitorEntries = entries
        self.portsStatus = "Loaded \(entries.count) listening ports."
        self.finishJob(id: jobID, state: .succeeded, detail: self.portsStatus)
      }
    }
  }

  func runCleanup() {
    guard let cliPath else {
      statusKind = .error
      statusTitle = "CLI Engine Missing"
      statusDetail = "The bundled CSA-iEM CLI engine was not found."
      return
    }

    guard ghPath != nil else {
      statusKind = .error
      statusTitle = "GitHub CLI Missing"
      statusDetail = "Install GitHub CLI first."
      return
    }

    let selectedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedTargets = cleanupTargets

    guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      statusKind = .error
      statusTitle = "GitHub Host Required"
      statusDetail = "Select or enter a GitHub host before running cleanup."
      return
    }

    guard !selectedAccount.isEmpty else {
      statusKind = .warning
      statusTitle = "GitHub Account Required"
      statusDetail = "Login first, then choose which authenticated account should run cleanup."
      return
    }

    guard !selectedTargets.isEmpty else {
      statusKind = .warning
      statusTitle = "Repository Required"
      statusDetail = "Enter a manual repo target or check one or more repositories from the repo browser."
      return
    }

    if !fullCleanup && !(disableWorkflows || deleteRuns || deleteArtifacts || deleteCaches || deleteCodespaces) {
      statusKind = .warning
      statusTitle = "Cleanup Action Required"
      statusDetail = "Choose at least one cleanup action or enable full cleanup."
      return
    }

    guard safetyArmEnabled else {
      statusKind = .warning
      statusTitle = "Safety Lock Enabled"
      statusDetail = "Turn on the permanent delete confirmation switch before running cleanup."
      return
    }

    pendingRepoTargets = selectedTargets
    completedRepoTargets = []
    failedRepoTargets = []
    activeRepoTarget = ""
    totalRepoTargets = selectedTargets.count
    cancellationRequested = false
    statusKind = .running
    statusTitle = dryRun ? "Running Dry Run" : "Running Cleanup"
    statusDetail = "\(selectedAccount) -> \(selectedTargets.count) target(s) in \(workspaceExecutionLabel)"
    logText = "[gui] Starting cleanup across \(selectedTargets.count) target(s) with \(selectedAccount) using the \(workspaceExecutionLabel)\n"
    isRunning = true
    launchCleanup(for: pendingRepoTargets.removeFirst(), using: cliPath, account: selectedAccount)
  }

  private func launchCleanup(for repoTarget: String, using cliPath: String, account selectedAccount: String) {
    let resolvedHost = repoHostOverride(from: repoTarget) ?? host.trimmingCharacters(in: .whitespacesAndNewlines)
    activeRepoTarget = repoTarget
    let currentIndex = completedRepoTargets.count + failedRepoTargets.count + 1

    statusKind = .running
    statusTitle = dryRun ? "Running Dry Run" : "Running Cleanup"
    statusDetail = totalRepoTargets > 1
      ? "\(selectedAccount) -> \(currentIndex)/\(totalRepoTargets): \(repoTarget)"
      : "\(selectedAccount) -> \(repoTarget)"
    appendLog("[gui] [\(currentIndex)/\(totalRepoTargets)] Starting cleanup for \(repoTarget) on \(resolvedHost) with \(selectedAccount)\n")

    var arguments = profileArguments() + [
      "--host", resolvedHost,
      "--account", selectedAccount,
      "--repo", repoTarget,
      "--yes",
      "--no-color"
    ]

    if fullCleanup {
      arguments.append("--all")
    } else {
      if disableWorkflows { arguments.append("--disable-workflows") }
      if deleteRuns { arguments.append("--delete-runs") }
      if deleteArtifacts { arguments.append("--delete-artifacts") }
      if deleteCaches { arguments.append("--delete-caches") }
    }

    if deleteCodespaces {
      arguments.append("--delete-codespaces")
    }

    if !runTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      arguments.append(contentsOf: ["--run", runTarget.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    if !runFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      arguments.append(contentsOf: ["--run-filter", runFilter.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    if dryRun {
      arguments.append("--dry-run")
    }

    let environment = baseEnvironment()
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: cliPath)
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = pipe
    runningProcess = process

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard data.isEmpty == false,
            let chunk = String(data: data, encoding: .utf8),
            chunk.isEmpty == false else {
        return
      }

      DispatchQueue.main.async {
        self?.appendLog(chunk)
      }
    }

    process.terminationHandler = { [weak self] terminated in
      let tail = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.readabilityHandler = nil
      let tailText = String(data: tail, encoding: .utf8) ?? ""

      DispatchQueue.main.async {
        guard let self else { return }
        if !tailText.isEmpty {
          self.appendLog(tailText)
        }
        self.runningProcess = nil

        if self.cancellationRequested {
          self.finishCleanupQueue(cancelled: true)
          return
        }

        if terminated.terminationStatus == 0 {
          self.completedRepoTargets.append(repoTarget)
        } else {
          self.failedRepoTargets.append(repoTarget)
          self.appendLog("[gui] Cleanup failed for \(repoTarget) with exit code \(terminated.terminationStatus)\n")
        }

        if let nextTarget = self.pendingRepoTargets.first {
          self.pendingRepoTargets.removeFirst()
          self.launchCleanup(for: nextTarget, using: cliPath, account: selectedAccount)
        } else {
          self.finishCleanupQueue(cancelled: false)
        }
      }
    }

    processQueue.async {
      do {
        try process.run()
      } catch {
        DispatchQueue.main.async {
          self.failedRepoTargets.append(repoTarget)
          self.appendLog("[gui] Failed to launch cleanup: \(error.localizedDescription)\n")
          if let nextTarget = self.pendingRepoTargets.first {
            self.pendingRepoTargets.removeFirst()
            self.launchCleanup(for: nextTarget, using: cliPath, account: selectedAccount)
          } else {
            self.finishCleanupQueue(cancelled: false)
          }
        }
      }
    }
  }

  private func finishCleanupQueue(cancelled: Bool) {
    isRunning = false
    runningProcess = nil
    safetyArmEnabled = false
    let completedCount = completedRepoTargets.count
    let failedCount = failedRepoTargets.count
    let summary = "Completed \(completedCount) of \(totalRepoTargets). Failed: \(failedCount)."

    if cancelled {
      statusKind = .warning
      statusTitle = "Cleanup Cancelled"
      statusDetail = summary
      appendLog("[gui] Cleanup cancelled by user.\n")
    } else if failedCount == 0 {
      statusKind = .ready
      statusTitle = dryRun ? "Dry Run Finished" : "Cleanup Finished"
      statusDetail = summary
    } else {
      statusKind = .error
      statusTitle = "Cleanup Finished With Errors"
      statusDetail = summary
    }

    pendingRepoTargets.removeAll()
    activeRepoTarget = ""
    totalRepoTargets = 0
    cancellationRequested = false
    reloadAuthInventory()
  }

  private func appendLog(_ text: String) {
    logText += redactSensitiveText(text)
  }

  @discardableResult
  private func createJob(kind: String, title: String, target: String = "", detail: String, initialState: BackgroundJobState = .queued) -> String {
    let job = BackgroundJobEntry(
      id: UUID().uuidString,
      kind: kind,
      title: title,
      target: target,
      detail: detail,
      progressText: detail,
      state: initialState,
      createdAt: Date(),
      startedAt: initialState == .running ? Date() : nil,
      finishedAt: nil,
      log: ""
    )
    backgroundJobs.insert(job, at: 0)
    selectedJobID = job.id
    jobCenterStatus = recentJobSummary
    return job.id
  }

  private func updateJob(
    id: String,
    state: BackgroundJobState? = nil,
    detail: String? = nil,
    progressText: String? = nil,
    appendLog logChunk: String? = nil
  ) {
    guard let index = backgroundJobs.firstIndex(where: { $0.id == id }) else { return }
    if let state {
      backgroundJobs[index].state = state
      if state == .running, backgroundJobs[index].startedAt == nil {
        backgroundJobs[index].startedAt = Date()
      }
      if state == .succeeded || state == .failed || state == .cancelled {
        backgroundJobs[index].finishedAt = Date()
      }
    }
    if let detail {
      backgroundJobs[index].detail = detail
    }
    if let progressText {
      backgroundJobs[index].progressText = progressText
    }
    if let logChunk, !logChunk.isEmpty {
      backgroundJobs[index].log += redactSensitiveText(logChunk)
      if backgroundJobs[index].log.hasSuffix("\n") == false {
        backgroundJobs[index].log += "\n"
      }
    }
    jobCenterStatus = recentJobSummary
  }

  private func finishJob(id: String, state: BackgroundJobState, detail: String) {
    updateJob(id: id, state: state, detail: detail, progressText: detail)
  }

  func clearCompletedJobs() {
    backgroundJobs.removeAll { $0.state == .succeeded || $0.state == .failed || $0.state == .cancelled }
    if let selectedJobID,
       backgroundJobs.contains(where: { $0.id == selectedJobID }) == false {
      self.selectedJobID = backgroundJobs.first?.id
    }
    jobCenterStatus = recentJobSummary
  }

  func retryJob(_ job: BackgroundJobEntry) {
    switch (job.kind, job.title) {
    case ("GitHub", "Repo health scan"):
      if selectedRepos.isEmpty {
        loadRepoHealthForVisibleRepos()
      } else {
        loadRepoHealthForSelectedRepos()
      }
    case ("GitHub", "Workflow catalog"):
      loadWorkflowCatalog()
    case ("GitHub", "Workflow runs"):
      loadWorkflowRuns()
    case ("GitHub", "Codespaces inventory"):
      loadCodespaces()
    case ("GitHub", "Secrets and variables"):
      loadSecretsAndVariables()
    case ("GitHub", "Rules and protection"):
      loadBranchProtectionAndRulesets()
    case ("Local", "Storage insights"):
      loadStorageInsights()
    case ("Local", "Project sync status"):
      loadProjectSyncStatus()
    case ("Local", "Port monitor"):
      loadPortMonitor()
    default:
      jobCenterStatus = "Retry is available for catalog, health, workflow, Codespaces, secrets, storage, sync, and port jobs."
    }
  }

  func cancelJob(_ job: BackgroundJobEntry) {
    if activeJobID == job.id {
      cancelRun()
      finishJob(id: job.id, state: .cancelled, detail: "Job cancelled by user.")
    } else {
      jobCenterStatus = "This job cannot be cancelled because it is no longer active."
    }
  }

  private func loadLastSession() -> [String: String] {
    let sessionPath: String

    if FileManager.default.fileExists(atPath: lastSessionFile) {
      sessionPath = lastSessionFile
    } else if FileManager.default.fileExists(atPath: legacyLastSessionFile) {
      sessionPath = legacyLastSessionFile
    } else if FileManager.default.fileExists(atPath: cleanerLastSessionFile) {
      sessionPath = cleanerLastSessionFile
    } else if FileManager.default.fileExists(atPath: legacyCleanerLastSessionFile) {
      sessionPath = legacyCleanerLastSessionFile
    } else {
      return [:]
    }

    guard let contents = try? String(contentsOfFile: sessionPath, encoding: .utf8) else {
      return [:]
    }

    var values: [String: String] = [:]
    for line in contents.split(separator: "\n") {
      let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
      if parts.count == 2 {
        values[parts[0]] = parts[1]
      }
    }
    return values
  }

  private func parseGitHubConfig() -> [AuthHostConfig] {
    let configHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
      ?? (NSString(string: "~/.config").expandingTildeInPath)
    let hostsPath = (configHome as NSString).appendingPathComponent("gh/hosts.yml")

    guard let contents = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
      return []
    }

    var configs: [AuthHostConfig] = []
    var currentHost: String?
    var activeUser: String?
    var users: [String] = []
    var inUsers = false

    func flushCurrent() {
      guard let currentHost else { return }
      let uniqueUsers = Array(NSOrderedSet(array: users)) as? [String] ?? users
      configs.append(AuthHostConfig(host: currentHost, activeUser: activeUser, users: uniqueUsers))
    }

    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = String(rawLine)

      if line.hasPrefix(" ") == false, line.hasSuffix(":") {
        flushCurrent()
        currentHost = String(line.dropLast())
        activeUser = nil
        users = []
        inUsers = false
        continue
      }

      if line.hasPrefix("    user: ") {
        activeUser = String(line.dropFirst("    user: ".count))
        continue
      }

      if line == "    users:" {
        inUsers = true
        continue
      }

      if inUsers, line.hasPrefix("        "), line.hasSuffix(":") {
        var user = String(line.dropFirst(8))
        user.removeLast()
        users.append(user)
        continue
      }

      if line.hasPrefix("    "), line != "    users:" {
        inUsers = false
      }
    }

    flushCurrent()
    return configs
  }

  private func loadProfileConfigValues(profile: LaunchProfile) -> [String: String] {
    let fm = FileManager.default
    let candidates = [
      (profileConfigDir as NSString).appendingPathComponent("\(profile.rawValue).env"),
      (legacyProfileConfigDir as NSString).appendingPathComponent("\(profile.rawValue).env"),
    ]

    guard let configPath = candidates.first(where: { fm.fileExists(atPath: $0) }),
          let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
      return [:]
    }

    var values: [String: String] = [:]
    for line in contents.split(separator: "\n") {
      let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      values[parts[0]] = shellUnescape(parts[1])
    }
    return values
  }

  private func shellUnescape(_ value: String) -> String {
    var result = ""
    var isEscaped = false

    for character in value {
      if isEscaped {
        result.append(character)
        isEscaped = false
      } else if character == "\\" {
        isEscaped = true
      } else {
        result.append(character)
      }
    }

    if isEscaped {
      result.append("\\")
    }

    return result
  }

  private func shellEscapeForConfig(_ value: String) -> String {
    var escaped = ""
    let charactersToEscape = CharacterSet(charactersIn: " \\\"'`$&|;<>*?()[]{}!#")

    for scalar in value.unicodeScalars {
      if charactersToEscape.contains(scalar) {
        escaped.append("\\")
      }
      escaped.append(String(scalar))
    }

    return escaped
  }

  private func normalizeWorkspacePath(_ value: String) -> String {
    NSString(string: value.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
  }

  private func normalizeRepoSlug(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return trimmed
    }

    if let url = URL(string: trimmed),
       let host = url.host,
       !host.isEmpty {
      let pathParts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
      if pathParts.count >= 2 {
        let owner = pathParts[pathParts.count - 2]
        let repo = pathParts.last?.replacingOccurrences(of: ".git", with: "") ?? ""
        return "\(owner)/\(repo)"
      }
    }

    let parts = trimmed.split(separator: "/").map(String.init)
    if parts.count >= 3, parts[0].contains(".") {
      return "\(parts[1])/\(parts[2].replacingOccurrences(of: ".git", with: ""))"
    }
    if parts.count >= 2 {
      return "\(parts[parts.count - 2])/\(parts.last?.replacingOccurrences(of: ".git", with: "") ?? "")"
    }

    return trimmed
  }

  private func writeProfileConfig(profile: LaunchProfile, values: [String: String]) {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: profileConfigDir, withIntermediateDirectories: true)
    let configPath = (profileConfigDir as NSString).appendingPathComponent("\(profile.rawValue).env")
    let contents = values
      .filter { !$0.value.isEmpty }
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\(shellEscapeForConfig($0.value))" }
      .joined(separator: "\n")

    try? (contents + "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
  }

  private func chooseDirectory(startingAt path: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Folder"

    let normalized = normalizeWorkspacePath(path)
    if !normalized.isEmpty {
      panel.directoryURL = URL(fileURLWithPath: normalized, isDirectory: true)
    }

    return panel.runModal() == .OK ? panel.urls.first?.path : nil
  }

  private func applyWorkspaceSuggestion(_ suggestion: WorkspaceSuggestion) {
    switch suggestion.style {
    case .single:
      writeProfileConfig(profile: .public, values: ["SAVED_DEFAULT_ROOT": suggestion.runtimeRoot])
      selectedProfile = .public
    case .split:
      writeProfileConfig(
        profile: .diamond,
        values: [
          "SAVED_CODE_ROOT": suggestion.codeRoot,
          "SAVED_RUNTIME_ROOT": suggestion.runtimeRoot
        ]
      )
      selectedProfile = .diamond
    }

    useCurrentRoot = true
    syncWorkspaceDraftsFromResolvedRoots()
    refreshLocalProjects()
  }

  private func syncWorkspaceDraftsFromResolvedRoots() {
    let roots = resolvedProfileRoots()
    workspaceSingleRootDraft = roots.runtimeRoot
    workspaceCodeRootDraft = roots.codeRoot
    workspaceRuntimeRootDraft = roots.runtimeRoot
  }

  private func savedWorkspaceConfiguration() -> WorkspaceSuggestion? {
    let diamondValues = loadProfileConfigValues(profile: .diamond)
    let savedCodeRoot = normalizeWorkspacePath(diamondValues["SAVED_CODE_ROOT"] ?? "")
    let savedRuntimeRoot = normalizeWorkspacePath(diamondValues["SAVED_RUNTIME_ROOT"] ?? "")
    if !savedCodeRoot.isEmpty, !savedRuntimeRoot.isEmpty {
      return WorkspaceSuggestion(
        style: .split,
        title: "Saved workspace setup",
        detail: "Using the split workspace you already configured on this Mac.",
        codeRoot: savedCodeRoot,
        runtimeRoot: savedRuntimeRoot
      )
    }

    let publicValues = loadProfileConfigValues(profile: .public)
    let savedPublicRoot = normalizeWorkspacePath(publicValues["SAVED_DEFAULT_ROOT"] ?? "")
    if !savedPublicRoot.isEmpty {
      return WorkspaceSuggestion(
        style: .single,
        title: "Saved workspace setup",
        detail: "Using the single workspace folder you already configured on this Mac.",
        codeRoot: savedPublicRoot,
        runtimeRoot: savedPublicRoot
      )
    }

    let wtlValues = loadProfileConfigValues(profile: .wtl)
    let savedLegacyRoot = normalizeWorkspacePath(wtlValues["SAVED_DEFAULT_ROOT"] ?? "")
    if !savedLegacyRoot.isEmpty {
      return WorkspaceSuggestion(
        style: .single,
        title: "Saved workspace setup",
        detail: "Using a legacy single-folder setup detected from an earlier build.",
        codeRoot: savedLegacyRoot,
        runtimeRoot: savedLegacyRoot
      )
    }

    return nil
  }

  private func detectedWorkspaceConfiguration() -> WorkspaceSuggestion? {
    let fm = FileManager.default

    if let saved = savedWorkspaceConfiguration() {
      return saved
    }

    let hasLegacySplit = fm.fileExists(atPath: diamondCodeDefaultRoot) && fm.fileExists(atPath: diamondRuntimeDefaultRoot)
    if hasLegacySplit {
      return WorkspaceSuggestion(
        style: .split,
        title: "Detected current Mac setup",
        detail: "The app found your existing external-drive code and runtime folders and can use them automatically.",
        codeRoot: diamondCodeDefaultRoot,
        runtimeRoot: diamondRuntimeDefaultRoot
      )
    }

    if fm.fileExists(atPath: wtlDefaultRoot) {
      return WorkspaceSuggestion(
        style: .single,
        title: "Detected current Mac setup",
        detail: "The app found your existing external-drive workspace and can use it automatically as a single-folder setup.",
        codeRoot: wtlDefaultRoot,
        runtimeRoot: wtlDefaultRoot
      )
    }

    return nil
  }

  private func adoptDetectedWorkspaceIfNeeded() {
    if let saved = savedWorkspaceConfiguration() {
      selectedProfile = saved.style == .split ? .diamond : .public
      return
    }

    guard appSettings.preferDetectedWorkspace else {
      selectedProfile = .public
      return
    }

    if let detected = detectedWorkspaceConfiguration() {
      selectedProfile = detected.style == .split ? .diamond : .public
      return
    }

    selectedProfile = .public
  }

  private func resolvedProfileRoots() -> (codeRoot: String, runtimeRoot: String) {
    let values = loadProfileConfigValues(profile: selectedProfile)

    switch selectedProfile {
    case .public:
      let detectedRoot = detectedWorkspaceConfiguration()?.style == .single ? detectedWorkspaceConfiguration()?.runtimeRoot : nil
      let root = normalizeWorkspacePath(
        useCurrentRoot ? (values["SAVED_DEFAULT_ROOT"] ?? detectedRoot ?? publicDefaultRoot) : publicDefaultRoot
      )
      return (root, root)
    case .wtl:
      let root = normalizeWorkspacePath(useCurrentRoot ? (values["SAVED_DEFAULT_ROOT"] ?? wtlDefaultRoot) : wtlDefaultRoot)
      return (root, root)
    case .diamond:
      let detectedSplit = detectedWorkspaceConfiguration()?.style == .split ? detectedWorkspaceConfiguration() : nil
      let codeRoot = normalizeWorkspacePath(
        useCurrentRoot ? (values["SAVED_CODE_ROOT"] ?? detectedSplit?.codeRoot ?? genericSplitCodeDefaultRoot) : genericSplitCodeDefaultRoot
      )
      let runtimeRoot = normalizeWorkspacePath(
        useCurrentRoot ? (values["SAVED_RUNTIME_ROOT"] ?? detectedSplit?.runtimeRoot ?? genericSplitRuntimeDefaultRoot) : genericSplitRuntimeDefaultRoot
      )
      return (codeRoot, runtimeRoot)
    }
  }

  private nonisolated static func repoDirectories(in reposRoot: String) -> [(owner: String, repo: String, path: String)] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: reposRoot) else {
      return []
    }

    var results: [(String, String, String)] = []
    let owners = (try? fm.contentsOfDirectory(atPath: reposRoot))?.sorted() ?? []

    for owner in owners {
      let ownerPath = (reposRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let repoPath = (ownerPath as NSString).appendingPathComponent(repo)
        var isRepoDir: ObjCBool = false
        guard fm.fileExists(atPath: repoPath, isDirectory: &isRepoDir), isRepoDir.boolValue else {
          continue
        }

        let gitPath = (repoPath as NSString).appendingPathComponent(".git")
        if fm.fileExists(atPath: gitPath) {
          results.append((owner, repo, repoPath))
        }
      }
    }

    return results
  }

  private nonisolated static func scanLocalProjects(
    workspaceLabel: String,
    codeRoot: String,
    runtimeRoot: String
  ) -> (projects: [LocalProjectEntry], status: String) {
    let fm = FileManager.default
    let codeReposRoot = (codeRoot as NSString).appendingPathComponent("Repos")
    let runtimeReposRoot = (runtimeRoot as NSString).appendingPathComponent("Repos")
    let runnersRoot = (runtimeRoot as NSString).appendingPathComponent("Runners")

    var merged: [String: LocalProjectEntry] = [:]

    for item in repoDirectories(in: codeReposRoot) {
      let slug = "\(item.owner)/\(item.repo)"
      let existing = merged[slug]
      merged[slug] = LocalProjectEntry(
        slug: slug,
        owner: item.owner,
        repo: item.repo,
        codePath: item.path,
        runtimePath: existing?.runtimePath,
        hasDevcontainer: existing?.hasDevcontainer ?? false,
        hasGeneratedStarter: existing?.hasGeneratedStarter ?? false,
        hasRunner: existing?.hasRunner ?? false
      )
    }

    for item in repoDirectories(in: runtimeReposRoot) {
      let slug = "\(item.owner)/\(item.repo)"
      let devcontainerPath = (item.path as NSString).appendingPathComponent(".devcontainer/devcontainer.json")
      let generatedMarker = (item.path as NSString).appendingPathComponent(".devcontainer/.csa-ilem-generated")
      let existing = merged[slug]
      merged[slug] = LocalProjectEntry(
        slug: slug,
        owner: item.owner,
        repo: item.repo,
        codePath: existing?.codePath,
        runtimePath: item.path,
        hasDevcontainer: fm.fileExists(atPath: devcontainerPath),
        hasGeneratedStarter: fm.fileExists(atPath: generatedMarker),
        hasRunner: existing?.hasRunner ?? false
      )
    }

    let runnerOwners = (try? fm.contentsOfDirectory(atPath: runnersRoot))?.sorted() ?? []
    for owner in runnerOwners {
      let ownerPath = (runnersRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let runnerPath = (ownerPath as NSString).appendingPathComponent(repo)
        let runnerConfigPath = (runnerPath as NSString).appendingPathComponent(".runner")
        guard fm.fileExists(atPath: runnerConfigPath) else {
          continue
        }

        let slug = "\(owner)/\(repo)"
        let existing = merged[slug]
        merged[slug] = LocalProjectEntry(
          slug: slug,
          owner: owner,
          repo: repo,
          codePath: existing?.codePath,
          runtimePath: existing?.runtimePath,
          hasDevcontainer: existing?.hasDevcontainer ?? false,
          hasGeneratedStarter: existing?.hasGeneratedStarter ?? false,
          hasRunner: true
        )
      }
    }

    let projects = merged.values.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
    let status = projects.isEmpty
      ? "No imported local projects were found under the current \(workspaceLabel.lowercased()) workspace."
      : "Loaded \(projects.count) imported local projects from the current \(workspaceLabel.lowercased()) workspace."
    return (projects, status)
  }

  private func repoHostOverride(from target: String) -> String? {
    let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else {
      return nil
    }

    if let url = URL(string: trimmed),
       let host = url.host,
       url.pathComponents.count >= 3 {
      return host
    }

    let components = trimmed.split(separator: "/")
    if components.count == 3 {
      return String(components[0])
    }

    return nil
  }

  private func baseEnvironment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = defaultSearchPaths.joined(separator: ":")
    if let cliRootPath {
      environment["CSA_IEM_ROOT"] = cliRootPath
    }
    return environment
  }

  func executablePath(named command: String) -> String? {
    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent(command)
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }
    return nil
  }

  private func launchDetached(executable: String, arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = baseEnvironment()

    do {
      try process.run()
    } catch {
      appendLog("[gui] Failed to launch \(executable): \(error.localizedDescription)\n")
    }
  }

  private func revealPath(_ path: String) {
    let targetURL = URL(fileURLWithPath: path, isDirectory: true)
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else {
      appendLog("[gui] Path was not found: \(path)\n")
      return
    }
    NSWorkspace.shared.activateFileViewerSelecting([targetURL])
  }

  private func openProjectPaths(codePath: String?, runtimePath: String?, fallbackPath: String?, preferRuntime: Bool, label: String) {
    let targetPath = preferRuntime ? (runtimePath ?? codePath ?? fallbackPath) : (codePath ?? runtimePath ?? fallbackPath)
    guard let targetPath else {
      appendLog("[gui] No local path was found for \(label)\n")
      return
    }

    let preferredEditorPath = normalizeWorkspacePath(appSettings.preferredEditorPath)
    if appSettings.preferVSCodeCLI,
       !preferredEditorPath.isEmpty,
       FileManager.default.isExecutableFile(atPath: preferredEditorPath) {
      launchDetached(executable: preferredEditorPath, arguments: [targetPath])
      return
    }

    if appSettings.preferVSCodeCLI, let codePath = executablePath(named: "code") {
      launchDetached(executable: codePath, arguments: [targetPath])
      return
    }

    launchDetached(executable: "/usr/bin/open", arguments: ["-a", "Visual Studio Code", targetPath])
  }

  private func openTerminalCommand(_ command: String) {
    let appleScript = """
    tell application "Terminal"
      activate
      do script \(quotedAppleScript(commandLine: "/bin/bash -lc " + shellQuote(command)))
    end tell
    """

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", appleScript]
    process.environment = baseEnvironment()

    do {
      try process.run()
    } catch {
      appendLog("[gui] Failed to open Terminal command: \(error.localizedDescription)\n")
    }
  }

  private nonisolated static func runCommand(executable: String, arguments: [String], environment: [String: String], stdin: String? = nil) -> CommandResult {
    let process = Process()
    let pipe = Pipe()
    let stdinPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = stdinPipe

    do {
      try process.run()
    } catch {
      return CommandResult(status: 1, output: error.localizedDescription)
    }

    if let stdin {
      if let data = stdin.data(using: .utf8) {
        stdinPipe.fileHandleForWriting.write(data)
      }
    }
    stdinPipe.fileHandleForWriting.closeFile()

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return CommandResult(status: process.terminationStatus, output: output)
  }

  private nonisolated static func decodeJSONArray<T: Decodable>(_ type: T.Type, from output: String) -> T? {
    guard let data = output.data(using: .utf8) else {
      return nil
    }
    return try? JSONDecoder().decode(type, from: data)
  }

  private nonisolated static func extractDefaultBranch(_ output: String) -> String {
    guard let data = output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return ""
    }
    return (object["default_branch"] as? String) ?? ""
  }

  private nonisolated static func parseBranchProtection(branch: String, output: String) -> BranchProtectionSummary? {
    guard !branch.isEmpty,
          let data = output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          object["message"] == nil else {
      return nil
    }

    let requiredStatusChecks = ((object["required_status_checks"] as? [String: Any])?["contexts"] as? [Any])?.count ?? 0
    let requiredReviews = object["required_pull_request_reviews"] != nil
    let enforceAdmins = ((object["enforce_admins"] as? [String: Any])?["enabled"] as? Bool) ?? false
    return BranchProtectionSummary(
      branch: branch,
      requiredStatusChecks: requiredStatusChecks,
      requiredPullRequestReviews: requiredReviews,
      enforceAdmins: enforceAdmins
    )
  }

  private nonisolated static func parseRulesets(_ output: String) -> [RulesetRecord] {
    guard let data = output.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }

    return array.compactMap { item in
      let idValue = item["id"].map { String(describing: $0) } ?? UUID().uuidString
      let name = (item["name"] as? String) ?? "Unnamed Ruleset"
      let target = (item["target"] as? String) ?? "unknown"
      let enforcement = (item["enforcement"] as? String) ?? "unknown"
      let source = (item["source_type"] as? String) ?? (item["source"] as? String) ?? "repo"
      return RulesetRecord(id: idValue, name: name, target: target, enforcement: enforcement, source: source)
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private nonisolated static func parseCodespaces(_ output: String) -> [CodespaceInventoryEntry] {
    guard let data = output.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }

    return array.compactMap { item in
      let name = (item["name"] as? String) ?? ""
      guard !name.isEmpty else { return nil }
      let displayName = (item["displayName"] as? String) ?? name
      let state = (item["state"] as? String) ?? "unknown"
      let machineName = (item["machineName"] as? String) ?? "unknown"
      let lastUsedAt = (item["lastUsedAt"] as? String) ?? "unknown"
      let repository = item["repository"] as? [String: Any]
      let repo = (repository?["fullName"] as? String)
        ?? (repository?["nameWithOwner"] as? String)
        ?? {
          let owner = (repository?["owner"] as? [String: Any])?["login"] as? String
          let repoName = repository?["name"] as? String
          if let owner, let repoName {
            return "\(owner)/\(repoName)"
          }
          return ""
        }()
      return CodespaceInventoryEntry(
        name: name,
        displayName: displayName,
        repo: repo,
        state: state,
        machineName: machineName,
        lastUsedAt: lastUsedAt
      )
    }
    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
  }

  private nonisolated static func directorySizeKilobytes(at path: String) -> Int64 {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else {
      return 0
    }

    if let attrs = try? fm.attributesOfItem(atPath: path),
       let type = attrs[.type] as? FileAttributeType,
       type != .typeDirectory,
       let size = attrs[.size] as? NSNumber {
      return Int64(size.int64Value / 1024)
    }

    var totalBytes: Int64 = 0
    if let enumerator = fm.enumerator(atPath: path) {
      for case let item as String in enumerator {
        let childPath = (path as NSString).appendingPathComponent(item)
        if let attrs = try? fm.attributesOfItem(atPath: childPath),
           let type = attrs[.type] as? FileAttributeType,
           type != .typeDirectory,
           let size = attrs[.size] as? NSNumber {
          totalBytes += size.int64Value
        }
      }
    }
    return totalBytes / 1024
  }

  private nonisolated static func formatKilobytes(_ kilobytes: Int64) -> String {
    let value = Double(kilobytes)
    if value >= 1024 * 1024 {
      return String(format: "%.1f GB", value / (1024 * 1024))
    }
    if value >= 1024 {
      return String(format: "%.1f MB", value / 1024)
    }
    return "\(max(0, kilobytes)) KB"
  }

  private nonisolated static func buildWorkspaceMovePreview(
    scope: WorkspaceRelocationScope,
    style: WorkspaceStyle,
    codeRoot: String,
    runtimeRoot: String,
    destinationBase: String
  ) -> LocalOperationPreview {
    let normalizedDestination = NSString(string: destinationBase).standardizingPath
    var targets: [(source: String, destination: String)] = []

    switch style {
    case .single:
      targets = [(runtimeRoot, (normalizedDestination as NSString).appendingPathComponent("Workspace"))]
    case .split:
      switch scope {
      case .workspace:
        targets = [
          (codeRoot, (normalizedDestination as NSString).appendingPathComponent("Code")),
          (runtimeRoot, (normalizedDestination as NSString).appendingPathComponent("Runtime"))
        ]
      case .codeRoot:
        targets = [(codeRoot, (normalizedDestination as NSString).appendingPathComponent("Code"))]
      case .runtimeRoot:
        targets = [(runtimeRoot, (normalizedDestination as NSString).appendingPathComponent("Runtime"))]
      }
    }

    let totalSize = targets.reduce(Int64(0)) { $0 + directorySizeKilobytes(at: $1.source) }
    let collisions = targets
      .map(\.destination)
      .filter { FileManager.default.fileExists(atPath: $0) }

    return LocalOperationPreview(
      kind: .workspaceMove,
      title: "\(scope.label) Preview",
      destinationPath: normalizedDestination,
      itemCount: targets.count,
      totalSizeLabel: formatKilobytes(totalSize),
      collisions: collisions,
      preparedStamp: nil
    )
  }

  private nonisolated static func buildLocalExportPreview(
    scope: LocalFileExportScope,
    mode: LocalFileTransferMode,
    destinationBase: String,
    preparedStamp: String,
    roots: (codeRoot: String, runtimeRoot: String),
    selectedProjects: [LocalProjectEntry],
    includeCode: Bool,
    includeRuntime: Bool,
    includeRunners: Bool
  ) -> LocalOperationPreview {
    let destinationRoot = localExportRoot(destinationBase: destinationBase, stamp: preparedStamp)
    let operations = (try? plannedLocalExportOperations(
      scope: scope,
      destinationRoot: destinationRoot,
      roots: roots,
      selectedProjects: selectedProjects,
      includeCode: includeCode,
      includeRuntime: includeRuntime,
      includeRunners: includeRunners
    )) ?? []
    let totalSize = operations.reduce(Int64(0)) { $0 + directorySizeKilobytes(at: $1.source) }
    let collisions = operations
      .map(\.destination)
      .filter { FileManager.default.fileExists(atPath: $0) }

    return LocalOperationPreview(
      kind: .localExport,
      title: "\(mode.label) Preview",
      destinationPath: destinationRoot,
      itemCount: operations.count,
      totalSizeLabel: formatKilobytes(totalSize),
      collisions: collisions.isEmpty && FileManager.default.fileExists(atPath: destinationRoot) ? [destinationRoot] : collisions,
      preparedStamp: preparedStamp
    )
  }

  private nonisolated static func mergeOwnerRepoTree(from sourceRoot: String, to destinationRoot: String, environment: [String: String]) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: sourceRoot) else {
      return
    }

    let owners = (try? fm.contentsOfDirectory(atPath: sourceRoot))?.sorted() ?? []
    for owner in owners {
      let ownerPath = (sourceRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let repoPath = (ownerPath as NSString).appendingPathComponent(repo)
        let target = (destinationRoot as NSString).appendingPathComponent("\(owner)/\(repo)")
        try transferItem(from: repoPath, to: target, mode: .copyBackup, overwrite: true, environment: environment)
      }
    }
  }

  private nonisolated static func restoreSnapshotPayload(
    payloadPath: String,
    roots: (codeRoot: String, runtimeRoot: String),
    environment: [String: String]
  ) throws {
    let fm = FileManager.default
    var restoreRoot = payloadPath

    let directCode = (restoreRoot as NSString).appendingPathComponent("Code")
    let directRuntime = (restoreRoot as NSString).appendingPathComponent("Runtime")
    if !fm.fileExists(atPath: directCode), !fm.fileExists(atPath: directRuntime) {
      let children = (try? fm.contentsOfDirectory(atPath: restoreRoot))?.sorted() ?? []
      if let nested = children
        .map({ (restoreRoot as NSString).appendingPathComponent($0) })
        .first(where: {
          fm.fileExists(atPath: ($0 as NSString).appendingPathComponent("Code")) ||
          fm.fileExists(atPath: ($0 as NSString).appendingPathComponent("Runtime"))
        }) {
        restoreRoot = nested
      }
    }

    let codeExport = (restoreRoot as NSString).appendingPathComponent("Code")
    if fm.fileExists(atPath: codeExport) {
      let reposExport = (codeExport as NSString).appendingPathComponent("Repos")
      if fm.fileExists(atPath: reposExport) {
        try mergeOwnerRepoTree(
          from: reposExport,
          to: (roots.codeRoot as NSString).appendingPathComponent("Repos"),
          environment: environment
        )
      } else {
        try transferItem(from: codeExport, to: roots.codeRoot, mode: .copyBackup, overwrite: true, environment: environment)
      }
    }

    let runtimeExport = (restoreRoot as NSString).appendingPathComponent("Runtime")
    if fm.fileExists(atPath: runtimeExport) {
      let reposExport = (runtimeExport as NSString).appendingPathComponent("Repos")
      let runnersExport = (runtimeExport as NSString).appendingPathComponent("Runners")

      if fm.fileExists(atPath: reposExport) {
        try mergeOwnerRepoTree(
          from: reposExport,
          to: (roots.runtimeRoot as NSString).appendingPathComponent("Repos"),
          environment: environment
        )
      } else {
        try transferItem(from: runtimeExport, to: roots.runtimeRoot, mode: .copyBackup, overwrite: true, environment: environment)
      }

      if fm.fileExists(atPath: runnersExport) {
        try mergeOwnerRepoTree(
          from: runnersExport,
          to: (roots.runtimeRoot as NSString).appendingPathComponent("Runners"),
          environment: environment
        )
      }
    }
  }

  private nonisolated static func scanRepoHealth(
    slug: String,
    ghPath: String,
    localProjects: [LocalProjectEntry],
    environment: [String: String]
  ) -> RepoHealthEntry {
    let workflows = decodeJSONArray([WorkflowCatalogEntry].self, from: runCommand(
      executable: ghPath,
      arguments: ["workflow", "list", "--all", "--json", "id,name,path,state", "-R", slug],
      environment: environment
    ).output) ?? []

    let runs = decodeJSONArray([WorkflowRunEntry].self, from: runCommand(
      executable: ghPath,
      arguments: ["run", "list", "--all", "--limit", "20", "--json", "databaseId,name,workflowName,status,conclusion,createdAt", "-R", slug],
      environment: environment
    ).output) ?? []

    let codespaces = parseCodespaces(runCommand(
      executable: ghPath,
      arguments: ["codespace", "list", "--repo", slug, "--json", "name,state,repository"],
      environment: environment
    ).output)

    let localProject = localProjects.first(where: { $0.slug == slug })
    var githubHostedIndicators = 0
    if let workflowRootBase = localProject?.codePath ?? localProject?.runtimePath {
      let workflowRoot = (workflowRootBase as NSString).appendingPathComponent(".github/workflows")
      if let enumerator = FileManager.default.enumerator(atPath: workflowRoot) {
        for case let relative as String in enumerator where relative.hasSuffix(".yml") || relative.hasSuffix(".yaml") {
          let path = (workflowRoot as NSString).appendingPathComponent(relative)
          if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
            let lowered = contents.lowercased()
            let matches = [
              "ubuntu-latest",
              "windows-latest",
              "macos-latest",
              "ubuntu-",
              "windows-",
              "macos-"
            ]
            if matches.contains(where: { lowered.contains($0) }) {
              githubHostedIndicators += 1
            }
          }
        }
      }
    }

    let workflowsEnabled = workflows.filter { $0.state.lowercased() == "active" }.count
    let recentRuns = runs.count
    let activeCodespaces = codespaces.filter { !$0.state.lowercased().contains("shutdown") && !$0.state.lowercased().contains("stopped") }.count
    let hasLocalRunner = localProject?.hasRunner ?? false

    var riskScore = 0
    if githubHostedIndicators > 0 { riskScore += 25 }
    if workflowsEnabled > 0 && !hasLocalRunner { riskScore += 20 }
    if activeCodespaces > 0 { riskScore += 15 }
    if recentRuns > 10 { riskScore += 10 }
    if workflowsEnabled > 0 && githubHostedIndicators > 0 { riskScore += 20 }
    riskScore = min(100, riskScore)

    let riskLabel: String
    switch riskScore {
    case ..<25: riskLabel = "Low"
    case ..<50: riskLabel = "Moderate"
    case ..<75: riskLabel = "High"
    default: riskLabel = "Critical"
    }

    let summary = "\(workflowsEnabled)/\(workflows.count) workflows enabled · \(recentRuns) recent runs · \(activeCodespaces) active Codespaces · \(hasLocalRunner ? "local runner ready" : "no local runner")"
    return RepoHealthEntry(
      slug: slug,
      workflowsTotal: workflows.count,
      workflowsEnabled: workflowsEnabled,
      recentRuns: recentRuns,
      activeCodespaces: activeCodespaces,
      hasLocalRunner: hasLocalRunner,
      githubHostedIndicators: githubHostedIndicators,
      riskScore: riskScore,
      riskLabel: riskLabel,
      summary: summary
    )
  }

  private nonisolated static func scanStorageInsights(
    roots: (codeRoot: String, runtimeRoot: String)
  ) -> [StorageInsightEntry] {
    let candidates: [(String, String)] = [
      ("Code Root", roots.codeRoot),
      ("Runtime Root", roots.runtimeRoot),
      ("Reports", (roots.runtimeRoot as NSString).appendingPathComponent("Reports")),
      ("Runners", (roots.runtimeRoot as NSString).appendingPathComponent("Runners")),
      ("Snapshots", snapshotsDirectory),
      ("Docker App Data", NSString(string: "~/Library/Containers/com.docker.docker").expandingTildeInPath)
    ]

    return candidates.compactMap { label, path in
      guard FileManager.default.fileExists(atPath: path) else { return nil }
      let sizeKB = directorySizeKilobytes(at: path)
      return StorageInsightEntry(
        id: label.lowercased().replacingOccurrences(of: " ", with: "-"),
        label: label,
        path: path,
        sizeLabel: formatKilobytes(sizeKB)
      )
    }
  }

  private nonisolated static func gitState(for path: String, environment: [String: String]) -> (dirty: Bool, ahead: Int, behind: Int) {
    guard let gitPath = resolveExecutablePath(named: "git"),
          FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent(".git")) else {
      return (false, 0, 0)
    }

    let status = runCommand(executable: gitPath, arguments: ["-C", path, "status", "--porcelain"], environment: environment)
    let dirty = !status.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    let counts = runCommand(executable: gitPath, arguments: ["-C", path, "rev-list", "--left-right", "--count", "@{upstream}...HEAD"], environment: environment)
    let tokens = counts.output.split(whereSeparator: \.isWhitespace).map(String.init)
    let behind = tokens.count >= 1 ? Int(tokens[0]) ?? 0 : 0
    let ahead = tokens.count >= 2 ? Int(tokens[1]) ?? 0 : 0
    return (dirty, ahead, behind)
  }

  private nonisolated static func scanProjectSync(
    localProjects: [LocalProjectEntry],
    environment: [String: String]
  ) -> [ProjectSyncEntry] {
    localProjects.map { project in
      let codeState = project.codePath.map { gitState(for: $0, environment: environment) } ?? (dirty: false, ahead: 0, behind: 0)
      let runtimeState: (dirty: Bool, ahead: Int, behind: Int)
      if let runtimePath = project.runtimePath, runtimePath != project.codePath {
        runtimeState = gitState(for: runtimePath, environment: environment)
      } else {
        runtimeState = codeState
      }

      let summary = [
        "Code \(codeState.dirty ? "dirty" : "clean") \(codeState.ahead)/\(codeState.behind)",
        "Runtime \(runtimeState.dirty ? "dirty" : "clean") \(runtimeState.ahead)/\(runtimeState.behind)"
      ].joined(separator: " · ")

      return ProjectSyncEntry(
        slug: project.slug,
        codeDirty: codeState.dirty,
        runtimeDirty: runtimeState.dirty,
        codeAhead: codeState.ahead,
        codeBehind: codeState.behind,
        runtimeAhead: runtimeState.ahead,
        runtimeBehind: runtimeState.behind,
        summary: summary
      )
    }
    .sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
  }

  private nonisolated static func scanPorts(environment: [String: String]) -> [PortMonitorEntry] {
    guard let lsofPath = resolveExecutablePath(named: "lsof") else {
      return []
    }

    let result = runCommand(executable: lsofPath, arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"], environment: environment)
    guard result.status == 0 else {
      return []
    }

    return result.output
      .split(whereSeparator: \.isNewline)
      .dropFirst()
      .compactMap { line -> PortMonitorEntry? in
        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 9 else { return nil }
        let processName = parts[0]
        let pid = parts[1]
        let proto = parts[7]
        let nameField = parts.last ?? ""
        let port = nameField
          .split(separator: ":")
          .last
          .map(String.init)?
          .split(separator: " ")
          .first
          .map(String.init) ?? nameField
        return PortMonitorEntry(
          id: "\(pid)-\(port)-\(processName)",
          proto: proto,
          port: port,
          pid: pid,
          processName: processName
        )
      }
      .sorted {
        if $0.port == $1.port {
          return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
        }
        return ($0.port as NSString).integerValue < ($1.port as NSString).integerValue
      }
  }

  private nonisolated static func scanLiveServices(
    localProjects: [LocalProjectEntry],
    runtimeRoot: String,
    includeDocker: Bool,
    environment: [String: String]
  ) -> (containers: [LiveContainerEntry], runners: [RunnerServiceEntry], status: String) {
    let fm = FileManager.default
    var projectsByPath: [String: LocalProjectEntry] = [:]
    for project in localProjects {
      if let codePath = project.codePath {
        projectsByPath[NSString(string: codePath).standardizingPath] = project
      }
      if let runtimePath = project.runtimePath {
        projectsByPath[NSString(string: runtimePath).standardizingPath] = project
      }
    }

    var containers: [LiveContainerEntry] = []
    if includeDocker, let dockerPath = resolveExecutablePath(named: "docker") {
      let idsResult = runCommand(executable: dockerPath, arguments: ["ps", "-q"], environment: environment)
      if idsResult.status == 0 {
        let containerIDs = idsResult.output.split(whereSeparator: \.isNewline).map(String.init)
        for containerID in containerIDs {
          let inspectResult = runCommand(
            executable: dockerPath,
            arguments: [
              "inspect",
              "--format",
              "{{ index .Config.Labels \"devcontainer.local_folder\" }}|{{ .Name }}|{{ .Config.Image }}|{{ .State.Status }}",
              containerID
            ],
            environment: environment
          )
          guard inspectResult.status == 0 else {
            continue
          }

          let parts = inspectResult.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map(String.init)
          guard parts.count >= 4 else {
            continue
          }

          let workspacePath = NSString(string: parts[0]).standardizingPath
          guard !workspacePath.isEmpty else {
            continue
          }

          let project = projectsByPath[workspacePath]
          let name = parts[1].hasPrefix("/") ? String(parts[1].dropFirst()) : parts[1]
          let repo = project?.repo ?? ((workspacePath as NSString).lastPathComponent)
          let slug = project?.slug ?? repo

          containers.append(
            LiveContainerEntry(
              containerID: containerID,
              name: name,
              image: parts[2],
              status: parts[3],
              workspacePath: workspacePath,
              slug: slug,
              repo: repo,
              codePath: project?.codePath,
              runtimePath: project?.runtimePath
            )
          )
        }
      }
    }

    var activeLabels: Set<String> = []
    if let launchctlPath = resolveExecutablePath(named: "launchctl") {
      let launchctlResult = runCommand(executable: launchctlPath, arguments: ["list"], environment: environment)
      if launchctlResult.status == 0 {
        for line in launchctlResult.output.split(whereSeparator: \.isNewline).dropFirst() {
          let columns = line.split(whereSeparator: \.isWhitespace)
          if let label = columns.last {
            activeLabels.insert(String(label))
          }
        }
      }
    }

    var runners: [RunnerServiceEntry] = []
    let runnersRoot = (runtimeRoot as NSString).appendingPathComponent("Runners")
    let owners = (try? fm.contentsOfDirectory(atPath: runnersRoot))?.sorted() ?? []
    for owner in owners {
      let ownerPath = (runnersRoot as NSString).appendingPathComponent(owner)
      var isOwnerDir: ObjCBool = false
      guard fm.fileExists(atPath: ownerPath, isDirectory: &isOwnerDir), isOwnerDir.boolValue else {
        continue
      }

      let repos = (try? fm.contentsOfDirectory(atPath: ownerPath))?.sorted() ?? []
      for repo in repos {
        let runnerPath = (ownerPath as NSString).appendingPathComponent(repo)
        let runnerConfigPath = (runnerPath as NSString).appendingPathComponent(".runner")
        guard fm.fileExists(atPath: runnerConfigPath) else {
          continue
        }

        let slug = "\(owner)/\(repo)"
        let project = localProjects.first(where: { $0.slug == slug })
        let serviceFilePath = (runnerPath as NSString).appendingPathComponent(".service")
        let rawServicePlistPath = try? String(contentsOfFile: serviceFilePath, encoding: .utf8)
        let servicePlistPath = rawServicePlistPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let serviceLabel: String
        if let servicePlistPath, !servicePlistPath.isEmpty {
          serviceLabel = URL(fileURLWithPath: servicePlistPath).deletingPathExtension().lastPathComponent
        } else {
          serviceLabel = repo
        }

        runners.append(
          RunnerServiceEntry(
            slug: slug,
            repo: repo,
            runnerPath: runnerPath,
            serviceLabel: serviceLabel,
            servicePlistPath: servicePlistPath,
            isRunning: activeLabels.contains(serviceLabel),
            codePath: project?.codePath,
            runtimePath: project?.runtimePath
          )
        )
      }
    }

    let sortedContainers = containers.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
    let sortedRunners = runners.sorted { $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending }
    let status = "\(sortedContainers.count) active devcontainers and \(sortedRunners.count) runner services detected for the current workspace."
    return (sortedContainers, sortedRunners, status)
  }

  private nonisolated static func resolveExecutablePath(named command: String) -> String? {
    for base in defaultSearchPaths {
      let candidate = (base as NSString).appendingPathComponent(command)
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }
    return nil
  }

  private nonisolated static func relocateWorkspaceRoots(
    scope: WorkspaceRelocationScope,
    style: WorkspaceStyle,
    codeRoot: String,
    runtimeRoot: String,
    destinationBase: String,
    overwrite: Bool,
    environment: [String: String]
  ) throws -> WorkspaceRelocationOutcome {
    let destinationRoot = NSString(string: destinationBase).standardizingPath
    let fm = FileManager.default
    let transactionID = UUID().uuidString
    let operations: [(source: String, destination: String)]

    switch style {
    case .single:
      operations = [(runtimeRoot, (destinationRoot as NSString).appendingPathComponent("Workspace"))]
    case .split:
      switch scope {
      case .workspace:
        operations = [
          (codeRoot, (destinationRoot as NSString).appendingPathComponent("Code")),
          (runtimeRoot, (destinationRoot as NSString).appendingPathComponent("Runtime"))
        ]
      case .codeRoot:
        operations = [(codeRoot, (destinationRoot as NSString).appendingPathComponent("Code"))]
      case .runtimeRoot:
        operations = [(runtimeRoot, (destinationRoot as NSString).appendingPathComponent("Runtime"))]
      }
    }

    for operation in operations {
      guard fm.fileExists(atPath: operation.source) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Source path was not found: \(operation.source)"])
      }
      let normalizedSource = NSString(string: operation.source).standardizingPath
      let normalizedDestination = NSString(string: operation.destination).standardizingPath
      if normalizedDestination == normalizedSource || normalizedDestination.hasPrefix(normalizedSource + "/") {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination cannot be the same as or inside the source path: \(normalizedDestination)"])
      }
      if fm.fileExists(atPath: normalizedDestination), !overwrite {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(normalizedDestination)"])
      }
    }

    var stagePathsByDestination: [String: String] = [:]
    var backupPathsByDestination: [String: String] = [:]

    do {
      for operation in operations {
        let stagePath = operation.destination + ".csa-iem-stage-\(transactionID)"
        try? fm.removeItem(atPath: stagePath)
        try transferItem(from: operation.source, to: stagePath, mode: .copyBackup, overwrite: true, environment: environment)
        stagePathsByDestination[operation.destination] = stagePath
      }

      for operation in operations where fm.fileExists(atPath: operation.destination) {
        let backupPath = operation.destination + ".csa-iem-backup-\(transactionID)"
        try? fm.removeItem(atPath: backupPath)
        try fm.moveItem(atPath: operation.destination, toPath: backupPath)
        backupPathsByDestination[operation.destination] = backupPath
      }

      for operation in operations {
        guard let stagePath = stagePathsByDestination[operation.destination] else { continue }
        try fm.moveItem(atPath: stagePath, toPath: operation.destination)
        stagePathsByDestination.removeValue(forKey: operation.destination)
      }
    } catch {
      for operation in operations {
        if fm.fileExists(atPath: operation.destination) {
          try? fm.removeItem(atPath: operation.destination)
        }
      }
      for (destination, backupPath) in backupPathsByDestination {
        if fm.fileExists(atPath: backupPath) {
          try? fm.moveItem(atPath: backupPath, toPath: destination)
        }
      }
      for stagePath in stagePathsByDestination.values {
        try? fm.removeItem(atPath: stagePath)
      }
      throw error
    }

    var cleanupWarnings: [String] = []
    for operation in operations {
      if fm.fileExists(atPath: operation.source) {
        do {
          try fm.removeItem(atPath: operation.source)
        } catch {
          cleanupWarnings.append("Source cleanup failed for \(operation.source). The new destination is ready, but the old path still needs manual cleanup.")
        }
      }
    }
    for backupPath in backupPathsByDestination.values {
      try? fm.removeItem(atPath: backupPath)
    }

    switch style {
    case .single:
      let target = operations.first?.destination ?? runtimeRoot
      return WorkspaceRelocationOutcome(result: .single(target), warnings: cleanupWarnings)
    case .split:
      let newCodeRoot: String
      let newRuntimeRoot: String
      switch scope {
      case .workspace:
        newCodeRoot = operations.first(where: { NSString(string: $0.destination).lastPathComponent == "Code" })?.destination ?? codeRoot
        newRuntimeRoot = operations.first(where: { NSString(string: $0.destination).lastPathComponent == "Runtime" })?.destination ?? runtimeRoot
      case .codeRoot:
        newCodeRoot = operations.first?.destination ?? codeRoot
        newRuntimeRoot = runtimeRoot
      case .runtimeRoot:
        newCodeRoot = codeRoot
        newRuntimeRoot = operations.first?.destination ?? runtimeRoot
      }
      return WorkspaceRelocationOutcome(result: .split(codeRoot: newCodeRoot, runtimeRoot: newRuntimeRoot), warnings: cleanupWarnings)
    }
  }

  private nonisolated static func exportLocalFiles(
    scope: LocalFileExportScope,
    mode: LocalFileTransferMode,
    destinationBase: String,
    preparedStamp: String? = nil,
    roots: (codeRoot: String, runtimeRoot: String),
    selectedProjects: [LocalProjectEntry],
    includeCode: Bool,
    includeRuntime: Bool,
    includeRunners: Bool,
    overwrite: Bool,
    environment: [String: String]
  ) throws -> String {
    let stamp = preparedStamp ?? timestampStamp()
    let exportRoot = localExportRoot(destinationBase: destinationBase, stamp: stamp)
    let operations = try plannedLocalExportOperations(
      scope: scope,
      destinationRoot: exportRoot,
      roots: roots,
      selectedProjects: selectedProjects,
      includeCode: includeCode,
      includeRuntime: includeRuntime,
      includeRunners: includeRunners
    )
    let outcome = try performTransactionalTransfers(
      operations: operations,
      mode: mode,
      overwrite: overwrite,
      environment: environment
    )

    let warningSuffix = outcome.warnings.isEmpty
      ? ""
      : " Warnings: " + outcome.warnings.joined(separator: " ")

    switch scope {
    case .workspaceBundle:
      return "\(mode.label) finished for the full workspace bundle at \(exportRoot)." + warningSuffix
    case .codeWorkspace:
      let target = (exportRoot as NSString).appendingPathComponent("Code")
      return "\(mode.label) finished for the code workspace at \(target)." + warningSuffix
    case .runtimeWorkspace:
      let target = (exportRoot as NSString).appendingPathComponent("Runtime")
      return "\(mode.label) finished for the runtime workspace at \(target)." + warningSuffix
    case .selectedProjects:
      return "\(mode.label) finished for \(selectedProjects.count) selected projects (\(operations.count) items) at \(exportRoot)." + warningSuffix
    }
  }

  private nonisolated static func plannedLocalExportOperations(
    scope: LocalFileExportScope,
    destinationRoot: String,
    roots: (codeRoot: String, runtimeRoot: String),
    selectedProjects: [LocalProjectEntry],
    includeCode: Bool,
    includeRuntime: Bool,
    includeRunners: Bool
  ) throws -> [LocalTransferOperation] {
    switch scope {
    case .workspaceBundle:
      var operations = [
        LocalTransferOperation(
          source: roots.codeRoot,
          destination: (destinationRoot as NSString).appendingPathComponent("Code")
        )
      ]
      if NSString(string: roots.runtimeRoot).standardizingPath != NSString(string: roots.codeRoot).standardizingPath {
        operations.append(
          LocalTransferOperation(
            source: roots.runtimeRoot,
            destination: (destinationRoot as NSString).appendingPathComponent("Runtime")
          )
        )
      }
      return operations
    case .codeWorkspace:
      return [
        LocalTransferOperation(
          source: roots.codeRoot,
          destination: (destinationRoot as NSString).appendingPathComponent("Code")
        )
      ]
    case .runtimeWorkspace:
      return [
        LocalTransferOperation(
          source: roots.runtimeRoot,
          destination: (destinationRoot as NSString).appendingPathComponent("Runtime")
        )
      ]
    case .selectedProjects:
      guard !selectedProjects.isEmpty else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "No local projects were selected for export."])
      }

      let runtimeRunnerRoot = (roots.runtimeRoot as NSString).appendingPathComponent("Runners")
      var operations: [LocalTransferOperation] = []

      for project in selectedProjects {
        if includeCode, let codePath = project.codePath {
          operations.append(
            LocalTransferOperation(
              source: codePath,
              destination: (destinationRoot as NSString).appendingPathComponent("Code/Repos/\(project.owner)/\(project.repo)")
            )
          )
        }

        if includeRuntime, let runtimePath = project.runtimePath {
          operations.append(
            LocalTransferOperation(
              source: runtimePath,
              destination: (destinationRoot as NSString).appendingPathComponent("Runtime/Repos/\(project.owner)/\(project.repo)")
            )
          )
        }

        if includeRunners {
          let runnerPath = (runtimeRunnerRoot as NSString).appendingPathComponent("\(project.owner)/\(project.repo)")
          if FileManager.default.fileExists(atPath: runnerPath) {
            operations.append(
              LocalTransferOperation(
                source: runnerPath,
                destination: (destinationRoot as NSString).appendingPathComponent("Runtime/Runners/\(project.owner)/\(project.repo)")
              )
            )
          }
        }
      }

      return operations
    }
  }

  private nonisolated static func performTransactionalTransfers(
    operations: [LocalTransferOperation],
    mode: LocalFileTransferMode,
    overwrite: Bool,
    environment: [String: String]
  ) throws -> LocalTransferOutcome {
    let fm = FileManager.default
    let transactionID = UUID().uuidString
    var normalizedOperations: [LocalTransferOperation] = []
    var seenDestinations: Set<String> = []

    for operation in operations {
      let normalizedSource = NSString(string: operation.source).standardizingPath
      let normalizedDestination = NSString(string: operation.destination).standardizingPath

      guard fm.fileExists(atPath: normalizedSource) else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Source path was not found: \(normalizedSource)"])
      }

      if normalizedDestination == normalizedSource || normalizedDestination.hasPrefix(normalizedSource + "/") {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination cannot be the same as or inside the source path: \(normalizedDestination)"])
      }

      if !seenDestinations.insert(normalizedDestination).inserted {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Duplicate destination detected during export preparation: \(normalizedDestination)"])
      }

      if fm.fileExists(atPath: normalizedDestination), !overwrite {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(normalizedDestination)"])
      }

      normalizedOperations.append(LocalTransferOperation(source: normalizedSource, destination: normalizedDestination))
    }

    var stagePathsByDestination: [String: String] = [:]
    var backupPathsByDestination: [String: String] = [:]

    do {
      for operation in normalizedOperations {
        let stagePath = operation.destination + ".csa-iem-stage-\(transactionID)"
        try? fm.removeItem(atPath: stagePath)
        try transferItem(
          from: operation.source,
          to: stagePath,
          mode: .copyBackup,
          overwrite: true,
          environment: environment
        )
        stagePathsByDestination[operation.destination] = stagePath
      }

      for operation in normalizedOperations where fm.fileExists(atPath: operation.destination) {
        let backupPath = operation.destination + ".csa-iem-backup-\(transactionID)"
        try? fm.removeItem(atPath: backupPath)
        try fm.moveItem(atPath: operation.destination, toPath: backupPath)
        backupPathsByDestination[operation.destination] = backupPath
      }

      for operation in normalizedOperations {
        guard let stagePath = stagePathsByDestination[operation.destination] else { continue }
        try fm.moveItem(atPath: stagePath, toPath: operation.destination)
        stagePathsByDestination.removeValue(forKey: operation.destination)
      }
    } catch {
      for operation in normalizedOperations {
        if fm.fileExists(atPath: operation.destination) {
          try? fm.removeItem(atPath: operation.destination)
        }
      }
      for (destination, backupPath) in backupPathsByDestination {
        if fm.fileExists(atPath: backupPath) {
          try? fm.moveItem(atPath: backupPath, toPath: destination)
        }
      }
      for stagePath in stagePathsByDestination.values {
        try? fm.removeItem(atPath: stagePath)
      }
      throw error
    }

    var cleanupWarnings: [String] = []
    if mode == .move {
      for operation in normalizedOperations where fm.fileExists(atPath: operation.source) {
        do {
          try fm.removeItem(atPath: operation.source)
        } catch {
          cleanupWarnings.append("Source cleanup failed for \(operation.source). The new destination is ready, but the old path still needs manual cleanup.")
        }
      }
    }

    for backupPath in backupPathsByDestination.values {
      try? fm.removeItem(atPath: backupPath)
    }

    return LocalTransferOutcome(warnings: cleanupWarnings)
  }

  private nonisolated static func transferItem(
    from source: String,
    to destination: String,
    mode: LocalFileTransferMode,
    overwrite: Bool,
    environment: [String: String]
  ) throws {
    let fm = FileManager.default
    let normalizedSource = NSString(string: source).standardizingPath
    let normalizedDestination = NSString(string: destination).standardizingPath

    guard fm.fileExists(atPath: normalizedSource) else {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Source path was not found: \(normalizedSource)"])
    }

    if normalizedDestination == normalizedSource || normalizedDestination.hasPrefix(normalizedSource + "/") {
      throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination cannot be the same as or inside the source path: \(normalizedDestination)"])
    }

    let parentDirectory = (normalizedDestination as NSString).deletingLastPathComponent
    try fm.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true, attributes: nil)

    if fm.fileExists(atPath: normalizedDestination) {
      if overwrite {
        try fm.removeItem(atPath: normalizedDestination)
      } else {
        throw NSError(domain: appTitle, code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(normalizedDestination)"])
      }
    }

    let dittoPath = resolveExecutablePath(named: "ditto") ?? "/usr/bin/ditto"
    let result = runCommand(executable: dittoPath, arguments: [normalizedSource, normalizedDestination], environment: environment)
    guard result.status == 0 else {
      let output = redactSensitiveText(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
      throw NSError(domain: appTitle, code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Failed to transfer \(normalizedSource)." : output])
    }

    if mode == .move {
      try fm.removeItem(atPath: normalizedSource)
    }
  }

  private nonisolated static func timestampStamp() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: Date())
  }

  private nonisolated static func localExportRoot(destinationBase: String, stamp: String) -> String {
    (destinationBase as NSString).appendingPathComponent("CSA-iEM-Export-\(stamp)")
  }
}

private func shellQuote(_ value: String) -> String {
  "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}

private func quotedAppleScript(commandLine: String) -> String {
  let escaped = commandLine
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
  return "\"\(escaped)\""
}

private func bundledTermsOfServiceText() -> String {
  guard let url = bundledResourceURL(named: "TERMS-OF-SERVICE.md"),
        let contents = try? String(contentsOf: url, encoding: .utf8),
        contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
    return defaultTermsOfServiceText
  }

  return contents
}

private func localResourceRoots() -> [URL] {
  var roots: [URL] = []

  if let bundleRoot = Bundle.main.resourceURL {
    roots.append(bundleRoot)
    roots.append(bundleRoot.appendingPathComponent("Help", isDirectory: true))
    roots.append(bundleRoot.appendingPathComponent("assets", isDirectory: true))
    roots.append(bundleRoot.appendingPathComponent("assets/logos", isDirectory: true))
    roots.append(bundleRoot.appendingPathComponent("assets/social", isDirectory: true))
  }

  if let envRoot = ProcessInfo.processInfo.environment["CSA_IEM_ROOT"], envRoot.isEmpty == false {
    let envURL = URL(fileURLWithPath: envRoot, isDirectory: true)
    roots.append(envURL)
    roots.append(envURL.appendingPathComponent("Help", isDirectory: true))
    roots.append(envURL.appendingPathComponent("assets", isDirectory: true))
    roots.append(envURL.appendingPathComponent("assets/logos", isDirectory: true))
    roots.append(envURL.appendingPathComponent("assets/social", isDirectory: true))
    roots.append(envURL.appendingPathComponent("docs", isDirectory: true))
  }

  let cwdRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
  roots.append(cwdRoot)
  roots.append(cwdRoot.appendingPathComponent("Help", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("assets", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("assets/logos", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("assets/social", isDirectory: true))
  roots.append(cwdRoot.appendingPathComponent("docs", isDirectory: true))

  var unique: [URL] = []
  var seen: Set<String> = []
  for root in roots {
    let key = root.standardizedFileURL.path
    if seen.insert(key).inserted {
      unique.append(root)
    }
  }
  return unique
}

private func bundledResourceURL(named name: String, subdirectory: String? = nil) -> URL? {
  let fm = FileManager.default

  for root in localResourceRoots() {
    if let subdirectory {
      let url = root.appendingPathComponent(subdirectory, isDirectory: true).appendingPathComponent(name)
      if fm.fileExists(atPath: url.path) {
        return url
      }
    }

    let directURL = root.appendingPathComponent(name)
    if fm.fileExists(atPath: directURL.path) {
      return directURL
    }
  }

  return nil
}

private func bundledImage(named name: String) -> NSImage? {
  guard let url = bundledResourceURL(named: name) else {
    return nil
  }
  return NSImage(contentsOf: url)
}

private func bundledDocumentText(named name: String, fallback: String = "") -> String {
  if let helpURL = bundledResourceURL(named: name, subdirectory: bundledHelpDirectory),
     let contents = try? String(contentsOf: helpURL, encoding: .utf8),
     contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
    return contents
  }

  if let directURL = bundledResourceURL(named: name),
     let contents = try? String(contentsOf: directURL, encoding: .utf8),
     contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
    return contents
  }

  return fallback
}

private func attributedMarkdown(_ markdown: String) -> AttributedString {
  if let parsed = try? AttributedString(
    markdown: markdown,
    options: AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .full,
      failurePolicy: .returnPartiallyParsedIfPossible
    )
  ) {
    return parsed
  }

  return AttributedString(markdown)
}

private func redactSensitiveText(_ text: String) -> String {
  let replacements: [(pattern: String, replacement: String)] = [
    ("ghp_[A-Za-z0-9]{20,}", "[REDACTED_GITHUB_TOKEN]"),
    ("github_pat_[A-Za-z0-9_]{20,}", "[REDACTED_GITHUB_TOKEN]"),
    ("gho_[A-Za-z0-9]{20,}", "[REDACTED_GITHUB_TOKEN]"),
    ("AKIA[0-9A-Z]{16}", "[REDACTED_AWS_KEY]"),
    ("AIza[0-9A-Za-z\\-_]{20,}", "[REDACTED_API_KEY]"),
    ("(?i)authorization:\\s*bearer\\s+[A-Za-z0-9._\\-]+", "Authorization: Bearer [REDACTED]"),
    ("(?i)(gh_token|github_token|access_token|client_secret|api_key)\\s*[:=]\\s*[^\\s\\n]+", "$1=[REDACTED]")
  ]

  var sanitized = text
  for item in replacements {
    guard let regex = try? NSRegularExpression(pattern: item.pattern, options: []) else {
      continue
    }
    let range = NSRange(sanitized.startIndex..., in: sanitized)
    sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: item.replacement)
  }

  return sanitized
}

private enum DashboardTheme {
  static let navyOutline = Color(red: 31 / 255, green: 77 / 255, blue: 134 / 255)
  static let deepBlue = Color(red: 21 / 255, green: 80 / 255, blue: 143 / 255)
  static let brightPink = Color(red: 246 / 255, green: 95 / 255, blue: 165 / 255)
  static let accentPink = Color(red: 217 / 255, green: 44 / 255, blue: 123 / 255)
  static let coolWhite = Color(red: 247 / 255, green: 248 / 255, blue: 250 / 255)
  static let gridGray = Color(red: 216 / 255, green: 221 / 255, blue: 227 / 255)

  static let canvasTop = Color(red: 15 / 255, green: 23 / 255, blue: 32 / 255)
  static let canvasBottom = Color(red: 17 / 255, green: 25 / 255, blue: 35 / 255)
  static let panel = Color(red: 24 / 255, green: 32 / 255, blue: 43 / 255)
  static let panelAlt = Color(red: 27 / 255, green: 37 / 255, blue: 49 / 255)
  static let panelStrong = Color(red: 20 / 255, green: 28 / 255, blue: 38 / 255)
  static let field = Color(red: 30 / 255, green: 40 / 255, blue: 53 / 255)
  static let border = Color.white.opacity(0.08)
  static let text = coolWhite
  static let muted = Color(red: 211 / 255, green: 219 / 255, blue: 230 / 255)
  static let subtle = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
  static let accent = Color(red: 125 / 255, green: 178 / 255, blue: 239 / 255)
  static let success = Color(red: 42 / 255, green: 110 / 255, blue: 88 / 255)
  static let warning = Color(red: 209 / 255, green: 165 / 255, blue: 82 / 255)
  static let danger = Color(red: 133 / 255, green: 49 / 255, blue: 94 / 255)
  static let link = Color(red: 141 / 255, green: 198 / 255, blue: 255 / 255)
  static let warningSurface = Color(red: 250 / 255, green: 239 / 255, blue: 219 / 255)
  static let warningText = Color(red: 74 / 255, green: 54 / 255, blue: 24 / 255)
  static let warningSubtle = Color(red: 107 / 255, green: 83 / 255, blue: 46 / 255)
}

private extension View {
  func dashboardFieldStyle() -> some View {
    self
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(DashboardTheme.field)
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(DashboardTheme.border, lineWidth: 1)
          )
      )
  }
}

struct PanelCard<Content: View>: View {
  let title: String
  let subtitle: String
  let compact: Bool
  @ViewBuilder let content: Content

  init(title: String, subtitle: String, compact: Bool = false, @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.compact = compact
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 14 : 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
        Text(subtitle)
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineSpacing(2)
      }

      content
    }
    .padding(compact ? 18 : 22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(DashboardTheme.panelAlt)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct PillBadge: View {
  let text: String
  let tint: Color

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold, design: .rounded))
      .foregroundStyle(DashboardTheme.text)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(DashboardTheme.field)
      .overlay(
        Capsule()
          .stroke(tint.opacity(0.38), lineWidth: 1)
      )
      .clipShape(Capsule())
  }
}

struct BannerCard: View {
  let title: String
  let detail: String
  let kind: StatusKind

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: kind.icon)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(kind.tint)
        .frame(width: 36, height: 36)
        .background(DashboardTheme.panelStrong)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
        Text(detail)
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineSpacing(3)
      }

      Spacer(minLength: 0)
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(DashboardTheme.field)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(kind.tint.opacity(0.30), lineWidth: 1)
        )
    )
  }
}

struct BrandMarkSquareView: View {
  let image: NSImage?
  let size: CGFloat
  let cornerRadius: CGFloat

  init(image: NSImage?, size: CGFloat, cornerRadius: CGFloat = 24) {
    self.image = image
    self.size = size
    self.cornerRadius = cornerRadius
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )

      if let image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
          .frame(width: size, height: size)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      } else {
        Image(systemName: "app.dashed")
          .font(.system(size: size * 0.24, weight: .semibold))
          .foregroundStyle(DashboardTheme.subtle)
      }
    }
    .frame(width: size, height: size)
  }
}

struct HeaderPanel: View {
  let brandMark: NSImage?
  let compact: Bool

  var body: some View {
    ZStack(alignment: .topTrailing) {
      HStack(spacing: 0) {
        Color.clear
          .frame(width: compact ? 120 : 200, height: 1)

        VStack(alignment: .center, spacing: compact ? 8 : 10) {
          Text(appTitle)
            .font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .multilineTextAlignment(.center)
            .lineLimit(2)

          Text(appFullName)
            .font(.system(size: compact ? 14 : 16, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .multilineTextAlignment(.center)
            .lineLimit(2)

          Text(appSubtitle)
            .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.warning)
            .multilineTextAlignment(.center)

          Text("Provided by: \(companyName) · \(companyWebsite)")
            .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        BrandMarkSquareView(
          image: brandMark,
          size: compact ? 120 : 200,
          cornerRadius: compact ? 20 : 26
        )
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, compact ? 18 : 20)
    .frame(minHeight: compact ? 132 : 164)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(DashboardTheme.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct DashboardShell<Content: View>: View {
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      content
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(DashboardTheme.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
    .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
  }
}

private struct MenuSectionHeader: View {
  let text: String

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 11, weight: .bold, design: .rounded))
      .foregroundStyle(DashboardTheme.subtle)
  }
}

private struct DestinationMenuButton: View {
  let destination: AppDestination
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: destination.icon)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(isSelected ? DashboardTheme.text : destination.tint)
          .frame(width: 20)

        Text(destination.title)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
          .lineLimit(1)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(isSelected ? destination.tint.opacity(0.42) : DashboardTheme.field)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(isSelected ? destination.tint.opacity(0.65) : DashboardTheme.border, lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }
}

private struct WorkspaceToolbarStrip: View {
  let destination: AppDestination
  let menuVisible: Bool
  let usesSidebar: Bool
  let toggleMenu: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(menuVisible ? "Hide Menu" : "Show Menu") {
        toggleMenu()
      }
      .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

      PillBadge(text: destination.title, tint: destination.tint)

      Spacer(minLength: 0)

      Text(menuVisible ? (usesSidebar ? "Sidebar menu" : "Top menu") : "Focus mode")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(1)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DashboardTheme.panelAlt)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

private struct BottomStatusBar: View {
  let kind: StatusKind
  let status: String
  let session: String
  let selection: String
  let destination: AppDestination

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: kind.icon)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(kind.tint)

      Text(status)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
        .lineLimit(1)
        .minimumScaleFactor(0.85)

      Text("•")
        .foregroundStyle(DashboardTheme.subtle)

      Text(session)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .truncationMode(.middle)

      Text("•")
        .foregroundStyle(DashboardTheme.subtle)

      Text(selection)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .truncationMode(.middle)

      Spacer(minLength: 0)

      PillBadge(text: destination.title, tint: destination.tint)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DashboardTheme.panelAlt)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

private struct CompactDestinationBar: View {
  let selection: AppDestination
  let onSelect: (AppDestination) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(AppDestination.allCases) { destination in
          Button(action: { onSelect(destination) }) {
            HStack(spacing: 8) {
              Image(systemName: destination.icon)
                .font(.system(size: 12, weight: .bold))
              Text(destination.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selection == destination ? DashboardTheme.text : DashboardTheme.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
              Capsule()
                .fill(selection == destination ? destination.tint.opacity(0.42) : DashboardTheme.field)
                .overlay(
                  Capsule()
                    .stroke(selection == destination ? destination.tint.opacity(0.65) : DashboardTheme.border, lineWidth: 1)
                )
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 4)
    }
  }
}

private struct AppSidebarMenu: View {
  let selection: AppDestination
  let onSelect: (AppDestination) -> Void

  var body: some View {
    PanelCard(title: "App Menu", subtitle: "Move between the main product pages and the bundled in-app reference pages.", compact: true) {
      VStack(alignment: .leading, spacing: 12) {
        MenuSectionHeader(text: "Main Pages")
        ForEach(workspaceDestinations) { destination in
          DestinationMenuButton(destination: destination, isSelected: selection == destination) {
            onSelect(destination)
          }
        }

        Divider().overlay(DashboardTheme.border)

        MenuSectionHeader(text: "Reference")
        ForEach(knowledgeDestinations) { destination in
          DestinationMenuButton(destination: destination, isSelected: selection == destination) {
            onSelect(destination)
          }
        }
      }
    }
  }
}

private struct DocumentReaderCard: View {
  let destination: AppDestination
  let markdown: String

  var body: some View {
    PanelCard(title: destination.title, subtitle: destination.subtitle) {
      BannerCard(
        title: destination.title,
        detail: "This page is bundled inside the native app and stays available without leaving the interface.",
        kind: .ready
      )

      Text(attributedMarkdown(markdown))
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .lineSpacing(4)
        .padding(18)
        .background(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(DashboardTheme.panelStrong)
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DashboardTheme.border, lineWidth: 1)
            )
        )
    }
  }
}

private struct DestinationShortcutTile: View {
  let destination: AppDestination
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: destination.icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isSelected ? DashboardTheme.text : destination.tint)
          Spacer(minLength: 0)
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(destination.tint)
          }
        }

        Text(destination.title)
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.text)
          .multilineTextAlignment(.leading)

        Text(destination.subtitle)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineLimit(3)
          .multilineTextAlignment(.leading)
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(isSelected ? destination.tint.opacity(0.18) : DashboardTheme.field)
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(isSelected ? destination.tint.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }
}

struct FieldLabel: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .semibold, design: .rounded))
      .foregroundStyle(DashboardTheme.muted)
  }
}

struct FixedValueRow: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(text: label)

      Text(value)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardFieldStyle()
    }
  }
}

struct RepoSelectionRow: View {
  let repo: RepoCatalogEntry
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? DashboardTheme.success : DashboardTheme.subtle)

        VStack(alignment: .leading, spacing: 4) {
          Text(repo.shortName)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .lineLimit(1)

          Text(repo.nameWithOwner)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 12)

        VStack(alignment: .trailing, spacing: 4) {
          Text(repo.visibilityLabel)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(repo.isPrivate == true ? DashboardTheme.warning : DashboardTheme.accent)

          Text(repo.updatedLabel)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.subtle)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(isSelected ? DashboardTheme.field.opacity(1.0) : DashboardTheme.panelStrong)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(isSelected ? DashboardTheme.success.opacity(0.45) : DashboardTheme.border, lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }
}

struct LocalProjectRow: View {
  let project: LocalProjectEntry
  let isTargeted: Bool
  let isFavorite: Bool
  let toggleTarget: () -> Void
  let toggleFavorite: () -> Void
  let openRuntime: () -> Void
  let openCode: () -> Void
  let reveal: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Image(systemName: isTargeted ? "checkmark.circle.fill" : "circle")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(isTargeted ? DashboardTheme.success : DashboardTheme.subtle)

            Text(project.repo)
              .font(.system(size: 14, weight: .bold, design: .rounded))
              .foregroundStyle(DashboardTheme.text)
              .lineLimit(1)
          }

          Text(project.slug)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        HStack(spacing: 6) {
          Button(action: toggleFavorite) {
            Image(systemName: isFavorite ? "star.fill" : "star")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(isFavorite ? DashboardTheme.warning : DashboardTheme.subtle)
              .padding(8)
              .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .fill(DashboardTheme.field)
              )
          }
          .buttonStyle(.plain)

          ForEach(project.badges, id: \.self) { badge in
            PillBadge(text: badge, tint: badge == "runner" ? DashboardTheme.warning : DashboardTheme.accent)
          }
        }
      }

      HStack(spacing: 10) {
        Button(isTargeted ? "Untarget" : "Target") {
          toggleTarget()
        }
        .buttonStyle(DashboardButtonStyle(tint: isTargeted ? DashboardTheme.success : DashboardTheme.warning, bordered: true))

        Button("Runtime") {
          openRuntime()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Code") {
          openCode()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Finder") {
          reveal()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isTargeted ? DashboardTheme.success.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct LiveContainerRow: View {
  let container: LiveContainerEntry
  let openRuntime: () -> Void
  let openCode: () -> Void
  let reveal: () -> Void
  let logs: () -> Void
  let stop: () -> Void
  let remove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(container.repo)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .lineLimit(1)

          Text(container.slug)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 6) {
          PillBadge(text: "container", tint: DashboardTheme.deepBlue)
          PillBadge(text: container.status, tint: DashboardTheme.success)
        }
      }

      Text("\(container.name) · \(container.image)")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.subtle)
        .lineLimit(2)

      HStack(spacing: 10) {
        Button("Runtime") {
          openRuntime()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Code") {
          openCode()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Finder") {
          reveal()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Logs") {
          logs()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Stop") {
          stop()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))

        Button("Remove") {
          remove()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct RunnerServiceRow: View {
  let runner: RunnerServiceEntry
  let openRuntime: () -> Void
  let openCode: () -> Void
  let reveal: () -> Void
  let start: () -> Void
  let restart: () -> Void
  let verify: () -> Void
  let stop: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(runner.repo)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.text)
            .lineLimit(1)

          Text(runner.slug)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 6) {
          PillBadge(text: "runner", tint: DashboardTheme.warning)
          PillBadge(text: runner.statusLabel, tint: runner.isRunning ? DashboardTheme.success : DashboardTheme.subtle)
        }
      }

      Text(runner.serviceLabel)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.subtle)
        .lineLimit(2)

      HStack(spacing: 10) {
        Button("Runtime") {
          openRuntime()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Code") {
          openCode()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Finder") {
          reveal()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Start") {
          start()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        .disabled(runner.isRunning)

        Button("Restart") {
          restart()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Verify") {
          verify()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Stop") {
          stop()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
        .disabled(!runner.isRunning)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(runner.isRunning ? DashboardTheme.success.opacity(0.35) : DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct MetricTile: View {
  let label: String
  let value: String
  let tint: Color
  let icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(tint)
          .frame(width: 34, height: 34)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(tint.opacity(0.18))
          )

        Spacer(minLength: 0)
      }

      Text(value)
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundStyle(DashboardTheme.text)

      Text(label)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineLimit(2)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DashboardTheme.panelStrong)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DashboardTheme.border, lineWidth: 1)
        )
    )
  }
}

struct DashboardButtonStyle: ButtonStyle {
  let tint: Color
  let bordered: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .bold, design: .rounded))
      .foregroundStyle(DashboardTheme.text)
      .padding(.horizontal, 16)
      .padding(.vertical, 11)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(
            bordered
              ? DashboardTheme.panelStrong.opacity(configuration.isPressed ? 0.88 : 1.0)
              : tint.opacity(configuration.isPressed ? 0.82 : 1.0)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(bordered ? tint.opacity(0.72) : tint.opacity(0.95), lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
  }
}

struct SafetyCard: View {
  @Binding var isArmed: Bool
  let dryRun: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(DashboardTheme.warningSurface)
          .frame(width: 40, height: 40)
          .background(DashboardTheme.warningText)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text("Warning: Permanent Delete")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(DashboardTheme.warningText)

          Text(dryRun ? "Dry run is enabled, but this app is built for destructive cleanup. Confirm the repo and account before you continue." : "This will permanently delete GitHub Actions data. Workflow runs, artifacts, caches, and disabled workflows cannot be restored.")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(DashboardTheme.warningSubtle)
            .lineSpacing(3)
        }
      }

      Toggle(isOn: $isArmed) {
        Text("Arm destructive cleanup")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(DashboardTheme.warningText)
      }
      .toggleStyle(.switch)
      .tint(DashboardTheme.deepBlue)

      Text(isArmed ? "Safety lock is OFF. Cleanup buttons are unlocked." : "Safety lock is ON. Turn this switch on before cleanup can run.")
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(isArmed ? DashboardTheme.warningText : DashboardTheme.warningSubtle)
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(DashboardTheme.warningSurface)
        .overlay(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(DashboardTheme.warning.opacity(0.65), lineWidth: 1)
        )
    )
  }
}

struct LaunchWarningSheet: View {
  @Binding var acceptedRisk: Bool
  @Binding var acceptedPurpose: Bool
  let brandMark: NSImage?
  let continueAction: () -> Void
  let quitAction: () -> Void

  private let termsText = bundledTermsOfServiceText()

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [DashboardTheme.canvasTop, DashboardTheme.canvasBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack(alignment: .top, spacing: 18) {
            BrandMarkSquareView(image: brandMark, size: 92, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 8) {
              Text("Warning!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)

              Text("This is a destructive admin tool. Use at your own risk.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.warning)

              Text("\(appTitle) is a professional migration, cleanup, and local-actions management tool provided by \(companyName). Review the terms below every time before using the product.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
                .lineSpacing(3)

              Link(companyWebsite, destination: URL(string: companyWebsiteURL)!)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tint(DashboardTheme.link)
            }
          }

          PanelCard(title: "Terms of Service", subtitle: "You must accept responsibility and intended-use conditions before the tool unlocks.") {
            ScrollView {
              Text(termsText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 280, maxHeight: 320)
            .padding(2)
            .background(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DashboardTheme.panelStrong)
                .overlay(
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DashboardTheme.border, lineWidth: 1)
                )
            )

            Toggle("I understand this tool can permanently delete GitHub Actions data and I accept full responsibility for its use.", isOn: $acceptedRisk)
              .toggleStyle(.switch)
              .tint(DashboardTheme.danger)
              .foregroundStyle(DashboardTheme.text)

            Toggle("I will use this product only for its intended professional migration, cleanup, and local-actions management purpose and only where I am authorized to make these changes.", isOn: $acceptedPurpose)
              .toggleStyle(.switch)
              .tint(DashboardTheme.accent)
              .foregroundStyle(DashboardTheme.text)
          }

          HStack(spacing: 12) {
            Button("Quit App") {
              quitAction()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

            Button("Accept and Continue") {
              continueAction()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: false))
            .disabled(!(acceptedRisk && acceptedPurpose))
          }

          Text("Acceptance is required every time the app is opened.")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(DashboardTheme.subtle)
        }
        .padding(24)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity)
      }
    }
    .frame(minWidth: 920, minHeight: 760)
    .preferredColorScheme(.dark)
  }
}

struct LogConsoleView: NSViewRepresentable {
  let text: String

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder

    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = true
    textView.backgroundColor = NSColor(calibratedRed: 20 / 255, green: 28 / 255, blue: 38 / 255, alpha: 1)
    textView.textColor = NSColor(calibratedRed: 247 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1)
    textView.insertionPointColor = .clear
    textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.textContainerInset = NSSize(width: 12, height: 12)
    textView.isRichText = false
    textView.string = text

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }
    textView.string = text
    textView.backgroundColor = NSColor(calibratedRed: 20 / 255, green: 28 / 255, blue: 38 / 255, alpha: 1)
    textView.textColor = NSColor(calibratedRed: 247 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1)
    textView.scrollToEndOfDocument(nil)
  }
}

struct ContentView: View {
  @StateObject private var model = CleanupViewModel()
  @State private var selectedDestination: AppDestination = .home
  @State private var isMenuVisible = true
  @State private var showLaunchWarning = true
  @State private var acceptedRisk = false
  @State private var acceptedPurpose = false

  private var actionToggleTint: Color { DashboardTheme.accent }

  var body: some View {
    GeometryReader { geometry in
      let canUseSidebarMenu = geometry.size.width >= 1440
      let showSidebarMenu = canUseSidebarMenu && isMenuVisible
      let showCompactMenu = !canUseSidebarMenu && isMenuVisible
      let detailWidth = max(geometry.size.width - (showSidebarMenu ? 360 : 32), 640)

      ZStack {
        LinearGradient(
          colors: [DashboardTheme.canvasTop, DashboardTheme.canvasBottom],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 12) {
          Group {
            if showSidebarMenu {
              HStack(alignment: .top, spacing: 18) {
                AppSidebarMenu(selection: selectedDestination) { destination in
                  selectedDestination = destination
                }
                .frame(width: 320)

                pageContainer(for: detailWidth, usesSidebar: canUseSidebarMenu)
                  .frame(maxWidth: .infinity, alignment: .topLeading)
              }
            }
            else {
              VStack(spacing: 12) {
                if showCompactMenu {
                  CompactDestinationBar(selection: selectedDestination) { destination in
                    selectedDestination = destination
                  }
                }

                pageContainer(for: detailWidth, usesSidebar: canUseSidebarMenu)
                  .frame(maxWidth: .infinity, alignment: .topLeading)
              }
            }
          }

          BottomStatusBar(
            kind: model.statusKind,
            status: model.statusCompactLabel,
            session: model.sessionCompactLabel,
            selection: model.selectionCompactLabel,
            destination: selectedDestination
          )
        }
        .padding(16)
      }
    }
    .frame(minWidth: 760, minHeight: 640)
    .preferredColorScheme(.dark)
    .tint(DashboardTheme.link)
    .sheet(isPresented: $showLaunchWarning) {
      LaunchWarningSheet(
        acceptedRisk: $acceptedRisk,
        acceptedPurpose: $acceptedPurpose,
        brandMark: model.bundledBrandMark,
        continueAction: {
          showLaunchWarning = false
        },
        quitAction: {
          NSApp.terminate(nil)
        }
      )
      .interactiveDismissDisabled(true)
    }
  }

  @ViewBuilder
  private func pageContainer(for width: CGFloat, usesSidebar: Bool) -> some View {
    ScrollView {
      VStack(spacing: 18) {
        switch selectedDestination {
        case .home:
          homePage(for: width, usesSidebar: usesSidebar)
        case .jobs:
          jobsPage(for: width, usesSidebar: usesSidebar)
        case .githubAccount:
          githubAccountPage(for: width, usesSidebar: usesSidebar)
        case .projects:
          projectsPage(for: width, usesSidebar: usesSidebar)
        case .localFiles:
          localFilesPage(for: width, usesSidebar: usesSidebar)
        case .cleanup:
          cleanupPage(for: width, usesSidebar: usesSidebar)
        case .workspace:
          workspacePage(for: width, usesSidebar: usesSidebar)
        case .settings:
          settingsPage(for: width, usesSidebar: usesSidebar)
        case .about:
          aboutPage(usesSidebar: usesSidebar)
        case .helpCenter, .terms, .security, .brandSystem, .macOSNotes, .projectInfo:
          documentPage(for: selectedDestination, usesSidebar: usesSidebar)
        }
      }
      .frame(maxWidth: 3200)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  private func homePage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: selectedDestination,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      homeLayout(for: width)
    }
  }

  private func jobsPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .jobs,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1500 {
        HStack(alignment: .top, spacing: 18) {
          jobsCenterPanel
            .frame(maxWidth: 520, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            repoHealthPanel
            logPanel(minHeight: 420)
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          jobsCenterPanel
          repoHealthPanel
          logPanel(minHeight: 320)
        }
      }
    }
  }

  private func projectsPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .projects,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        if width >= 1400 {
          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
              overviewPanel
              rootsPanel
              favoritesAndViewsPanel
            }
            .frame(maxWidth: 420, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
              localProjectsPanel
              projectQuickActionsPanel
              taskTemplatesPanel
            }
              .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          overviewPanel
          rootsPanel
          favoritesAndViewsPanel
          localProjectsPanel
          projectQuickActionsPanel
          taskTemplatesPanel
        }

        liveServicesPanel

        if width >= 1450 {
          HStack(alignment: .top, spacing: 18) {
            projectSyncPanel
            storageInsightsPanel
            portMonitorPanel
          }
        } else {
          projectSyncPanel
          storageInsightsPanel
          portMonitorPanel
        }
      }
    }
  }

  private func githubAccountPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .githubAccount,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        if width >= 1500 {
          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
              authPanel
              contextsPanel
            }
            .frame(maxWidth: 440, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
              githubAccountInsightsPanel
              repositoryPanel
              repoHealthPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          authPanel
          contextsPanel
          githubAccountInsightsPanel
          repositoryPanel
          repoHealthPanel
        }

        workflowControlPanel
        workflowRunsPanel
        codespacesPanel
        secretsAndVariablesPanel
        rulesetsPanel
      }
    }
  }

  private func localFilesPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .localFiles,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      VStack(alignment: .leading, spacing: 18) {
        if width >= 1500 {
          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
              rootsPanel
              localFilesRelocationPanel
              backupPresetsPanel
            }
            .frame(maxWidth: 520, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
              localFilesExportPanel
              localFilesPreviewPanel
              snapshotsPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          rootsPanel
          localFilesRelocationPanel
          backupPresetsPanel
          localFilesExportPanel
          localFilesPreviewPanel
          snapshotsPanel
        }

        if width >= 1500 {
          HStack(alignment: .top, spacing: 18) {
            localProjectsPanel
            projectQuickActionsPanel
          }
        } else {
          localProjectsPanel
          projectQuickActionsPanel
        }
      }
    }
  }

  private func cleanupPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .cleanup,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1560 {
        HStack(alignment: .top, spacing: 18) {
          VStack(alignment: .leading, spacing: 18) {
            authPanel
            repositoryPanel
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            cleanupPanel
            executionPanel
          }
          .frame(width: 460, alignment: .topLeading)

          logPanel(minHeight: 720)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          authPanel
          repositoryPanel
          cleanupPanel
          executionPanel
          logPanel(minHeight: 360)
        }
      }
    }
  }

  private func workspacePage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .workspace,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1400 {
        HStack(alignment: .top, spacing: 18) {
          workspaceSetupPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            rootsPanel
            if model.appSettings.showAdvancedTools || model.appSettings.keepTerminalFallbacksVisible {
              advancedToolsPanel
            } else {
              settingsPanel
            }
          }
          .frame(maxWidth: 520, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          workspaceSetupPanel
          rootsPanel
          if model.appSettings.showAdvancedTools || model.appSettings.keepTerminalFallbacksVisible {
            advancedToolsPanel
          } else {
            settingsPanel
          }
        }
      }
    }
  }

  private func settingsPage(for width: CGFloat, usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: width < 1280
      )

      WorkspaceToolbarStrip(
        destination: .settings,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      if width >= 1500 {
        HStack(alignment: .top, spacing: 18) {
          VStack(alignment: .leading, spacing: 18) {
            settingsPanel
            contextsPanel
          }
          .frame(maxWidth: 520, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            favoritesAndViewsPanel
            libraryPanel
            advancedToolsPanel
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      } else {
        VStack(alignment: .leading, spacing: 18) {
          settingsPanel
          contextsPanel
          favoritesAndViewsPanel
          libraryPanel
          advancedToolsPanel
        }
      }
    }
  }

  private func documentPage(for destination: AppDestination, usesSidebar: Bool) -> some View {
    let markdown = bundledDocumentText(
      named: destination.bundleDocumentName ?? "",
      fallback: destination.fallbackDocumentText
    )

    return DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: false
      )

      WorkspaceToolbarStrip(
        destination: destination,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      DocumentReaderCard(destination: destination, markdown: markdown)
    }
  }

  private func aboutPage(usesSidebar: Bool) -> some View {
    DashboardShell {
      HeaderPanel(
        brandMark: model.bundledBrandMark,
        compact: false
      )

      WorkspaceToolbarStrip(
        destination: .about,
        menuVisible: isMenuVisible,
        usesSidebar: usesSidebar
      ) {
        isMenuVisible.toggle()
      }

      PanelCard(title: "About \(appTitle)", subtitle: "Product identity, bundle metadata, local storage path, and utility actions without leaving the app shell.") {
        BannerCard(
          title: "Native macOS Workspace App",
          detail: "\(model.bundleIdentitySummary)\nProvided by \(companyName) · \(companyWebsite)",
          kind: .ready
        )

        if let brandMark = model.bundledBrandMark {
          HStack(alignment: .center, spacing: 16) {
            BrandMarkSquareView(image: brandMark, size: 120, cornerRadius: 24)

            VStack(alignment: .leading, spacing: 8) {
              Text("Official press-kit artwork loaded")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)

              Text("This screen stays inside the native app. Use the left-side menu or the compact top menu to move between Home, Projects, Cleanup, Workspace, Help, and About without external file popups.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
                .lineSpacing(3)
            }

            Spacer(minLength: 0)
          }
          .padding(16)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(DashboardTheme.panelStrong)
              .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .stroke(DashboardTheme.border, lineWidth: 1)
              )
          )
        }

        FixedValueRow(label: "App Version", value: appVersion)
        FixedValueRow(label: "Product", value: appFullName)
        FixedValueRow(label: "Tagline", value: appSubtitle)
        FixedValueRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.waynetechlab.csaiem")
        FixedValueRow(label: "Company", value: companyName)
        FixedValueRow(label: "Website", value: companyWebsite)
        FixedValueRow(label: "Local Session Storage", value: appSupportDir)

        HStack(spacing: 10) {
          Button("Open Website") {
            model.openCompanyWebsite()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Reveal Session Storage") {
            model.revealSessionStorage()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        }
      }
    }
  }

  @ViewBuilder
  private func homeLayout(for width: CGFloat) -> some View {
    if width >= 1500 {
      HStack(alignment: .top, spacing: 18) {
        VStack(alignment: .leading, spacing: 18) {
          homeSummaryPanel
          accountSummaryPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)

        VStack(alignment: .leading, spacing: 18) {
          overviewPanel
          quickStartPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)

        logPanel(minHeight: 540)
          .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    } else {
      VStack(alignment: .leading, spacing: 18) {
        homeSummaryPanel
        accountSummaryPanel
        overviewPanel
        quickStartPanel
        logPanel(minHeight: 280)
      }
    }
  }

  private var authPanel: some View {
    PanelCard(title: "GitHub Auth", subtitle: "Clear account state, login controls, and fixed-value handling.") {
      FixedValueRow(label: "Current GitHub Session", value: model.sessionCompactLabel)

      if model.availableHosts.count > 1 {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Detected GitHub Hosts")
          Picker("", selection: $model.host) {
            ForEach(model.availableHosts, id: \.self) { host in
              Text(host).tag(host)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
        }
      } else if let onlyHost = model.availableHosts.first {
        FixedValueRow(label: "Detected GitHub Host", value: onlyHost)
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "GitHub Host")
        TextField("github.com", text: $model.host)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      if model.availableAccounts.count > 1 {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Authenticated Account")
          Picker("", selection: $model.account) {
            ForEach(model.availableAccounts, id: \.self) { account in
              Text(account).tag(account)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
        }
      } else if let onlyAccount = model.availableAccounts.first {
        FixedValueRow(label: "Authenticated Account", value: onlyAccount)
      } else {
        FixedValueRow(label: "Authenticated Account", value: "No logged-in account found for this host")
      }

      Text("Account state is mirrored in the bottom status bar. Refresh or re-login here only when you need to change the active GitHub session.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 10) {
          Button("Refresh") {
            model.refreshAuthStatus()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button(model.isAuthenticated ? "Re-Login" : "Login") {
            model.openGitHubLogin()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        }

        Button("Logout Selected Account") {
          model.logoutSelectedAccount()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(!model.isAuthenticated || model.isLoggingOut || model.account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private var accountSummaryPanel: some View {
    PanelCard(title: "GitHub Account", subtitle: "Connected account summary and fast access to the full account-management page.") {
      BannerCard(
        title: model.authHeadline,
        detail: model.authSummary + "\n" + model.githubAccountStatus,
        kind: model.isAuthenticated ? .ready : .warning
      )

      if let lastSession = model.lastSessionSummary {
        FixedValueRow(label: "Last Session", value: lastSession)
      }

      HStack(spacing: 10) {
        Button("Open Account Page") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: false))

        Button("Refresh") {
          model.refreshAuthStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }
    }
  }

  private var githubAccountInsightsPanel: some View {
    PanelCard(title: "Connected Account", subtitle: "Inspect the current GitHub session, organization memberships, and account-level entry points without leaving the app.") {
      FixedValueRow(label: "Current Session", value: model.sessionCompactLabel)
      FixedValueRow(label: "Target Owner or Org", value: model.repoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? model.account : model.repoOwner)
      FixedValueRow(label: "Loaded Repository Count", value: "\(model.availableRepos.count)")
      FixedValueRow(label: "Organizations", value: model.viewerOrganizationsSummary)

      if let lastSession = model.lastSessionSummary {
        FixedValueRow(label: "Last Session", value: lastSession)
      }

      BannerCard(
        title: model.isLoadingGitHubAccountDetails ? "Refreshing connected account details" : "Connected account status",
        detail: model.githubAccountStatus,
        kind: model.isAuthenticated ? .ready : .warning
      )

      HStack(spacing: 10) {
        Button("Refresh Account") {
          model.refreshAuthStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Load Organizations") {
          model.fetchViewerOrganizations()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(!model.isAuthenticated || model.isLoadingGitHubAccountDetails)

        Button("Load Repositories") {
          model.fetchAvailableRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        .disabled(!model.isAuthenticated)
      }

      HStack(spacing: 10) {
        Button("Open GitHub") {
          model.openGitHubHostPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))

        Button("Open Account") {
          model.openGitHubAccountPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.link, bordered: true))

        Button("Open Owner/Org") {
          model.openRepoOwnerPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Open Repositories") {
          model.openGitHubRepositoriesPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

        Button("Open Settings") {
          model.openGitHubSettingsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accentPink, bordered: true))
      }

      Text("This page is the dedicated place for host, account, org, and repository management. Cleanup can still use the same connected session, but the home screen stays simpler.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var homeSummaryPanel: some View {
    PanelCard(title: "Workspace Overview", subtitle: "The app now speaks in simple workspace terms instead of exposing internal preset details.") {
      BannerCard(
        title: model.workspaceHeadline,
        detail: model.workspaceSummary,
        kind: .ready
      )

      if let detected = model.detectedWorkspaceSuggestion {
        BannerCard(
          title: detected.title,
          detail: detected.detail,
          kind: .ready
        )
      } else {
        BannerCard(
          title: "Standard local setup available",
          detail: "The standard setup uses \(publicDefaultRoot). You can switch to split folders later if you want code and runtime separated.",
          kind: .warning
        )
      }

      Text("Custom-drive layouts are still supported, but the GUI now treats them as detected workspace examples instead of product-facing presets.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var quickStartPanel: some View {
    PanelCard(title: "Quick Start", subtitle: "Move into the exact page you need instead of working from one crowded dashboard.") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
        ForEach([AppDestination.githubAccount, .projects, .jobs, .localFiles, .cleanup, .workspace, .settings]) { destination in
          DestinationShortcutTile(destination: destination, isSelected: selectedDestination == destination) {
            selectedDestination = destination
          }
        }
      }

      Text("Projects stays fully on-screen for browsing local workspaces, active devcontainers, and runner services. Jobs tracks long-running work, Cleanup runs the CLI engine in the background, and Workspace/Settings handle paths, onboarding, and advanced behavior.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var jobsCenterPanel: some View {
    PanelCard(title: "Jobs Center", subtitle: "Central queue for background work with state, logs, retries, and safe cancellation where supported.") {
      BannerCard(
        title: model.recentJobSummary,
        detail: model.jobCenterStatus,
        kind: model.runningJobCount > 0 ? .running : .ready
      )

      HStack(spacing: 10) {
        Button("Refresh Local Data") {
          model.refreshLocalProjects()
          model.loadStorageInsights()
          model.loadProjectSyncStatus()
          model.loadPortMonitor()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Clear Completed") {
          model.clearCompletedJobs()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.backgroundJobs.isEmpty)
      }

      if let selectedJob = model.selectedJob {
        BannerCard(
          title: "\(selectedJob.title) · \(selectedJob.state.label)",
          detail: [selectedJob.target, selectedJob.detail, selectedJob.progressText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n"),
          kind: selectedJob.state.statusKind
        )

        HStack(spacing: 10) {
          Button("Retry") {
            model.retryJob(selectedJob)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Cancel") {
            model.cancelJob(selectedJob)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
          .disabled(model.selectedJob?.state != .running)
        }
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.backgroundJobs.isEmpty {
            Text("No jobs recorded yet. Workflow scans, local analysis, task runs, and file operations will appear here.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ForEach(model.backgroundJobs) { job in
              Button {
                model.selectedJobID = job.id
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text(job.title)
                      .font(.system(size: 14, weight: .bold, design: .rounded))
                      .foregroundStyle(DashboardTheme.text)
                    Spacer(minLength: 8)
                    PillBadge(text: job.state.label, tint: job.state.statusKind.tint)
                  }

                  Text([job.kind, job.target, job.detail].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                    .lineLimit(3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(model.selectedJobID == job.id ? DashboardTheme.field : DashboardTheme.panelStrong)
                    .overlay(
                      RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(model.selectedJobID == job.id ? job.state.statusKind.tint.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
                    )
                )
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .frame(minHeight: 220, idealHeight: 320, maxHeight: 420)
    }
  }

  private var settingsPanel: some View {
    PanelCard(title: "Settings & Onboarding", subtitle: "Control default host, preferred tools, auto-load behavior, and how much advanced surface area stays visible.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Default GitHub Host")
        TextField("github.com", text: $model.appSettings.defaultGitHubHost)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Preferred Editor Path (optional)")
        TextField("Auto-detect Visual Studio Code CLI", text: $model.appSettings.preferredEditorPath)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      Toggle("Prefer detected workspace on this Mac", isOn: $model.appSettings.preferDetectedWorkspace)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Prefer VS Code CLI when opening folders", isOn: $model.appSettings.preferVSCodeCLI)
        .toggleStyle(.switch)
        .tint(DashboardTheme.accent)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Run Docker checks during refresh", isOn: $model.appSettings.runDockerChecksOnRefresh)
        .toggleStyle(.switch)
        .tint(DashboardTheme.deepBlue)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Auto-load repo health after repo scans", isOn: $model.appSettings.autoLoadRepoHealth)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Auto-load workflow runs after workflow catalog loads", isOn: $model.appSettings.autoLoadWorkflowRuns)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Show advanced tools in the workspace page", isOn: $model.appSettings.showAdvancedTools)
        .toggleStyle(.switch)
        .tint(DashboardTheme.accentPink)
        .foregroundStyle(DashboardTheme.text)

      Toggle("Keep terminal fallbacks visible", isOn: $model.appSettings.keepTerminalFallbacksVisible)
        .toggleStyle(.switch)
        .tint(DashboardTheme.accentPink)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: "Prerequisites",
        detail: [
          "gh: \(model.ghPath ?? "Not found")",
          "docker: \(model.dockerPath ?? "Not found")",
          "code: \(model.executablePath(named: "code") ?? "Not found")",
          "devcontainer: \(model.executablePath(named: "devcontainer") ?? "Not found")"
        ].joined(separator: "\n"),
        kind: .ready
      )

      HStack(spacing: 10) {
        Button("Save Settings") {
          model.saveSettings()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Open Workspace Page") {
          selectedDestination = .workspace
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      Text(model.settingsStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
  }

  private var contextsPanel: some View {
    PanelCard(title: "Saved Contexts", subtitle: "Store named GitHub host/account/owner combinations so you can switch focus quickly without retyping.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Context Name")
        TextField("WayneTechLab Production", text: $model.contextNameDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Save Current Context") {
          model.saveCurrentContext()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Refresh GitHub") {
          model.refreshAuthStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      if model.savedContexts.isEmpty {
        Text("No saved contexts yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.savedContexts) { context in
          HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
              Text(context.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("\(context.host) · \(context.account) · \(context.owner)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }

            Spacer(minLength: 8)

            Button("Apply") {
              model.applyContext(context)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

            Button("Delete") {
              model.deleteContext(context)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var repoHealthPanel: some View {
    PanelCard(title: "Repo Health Dashboard", subtitle: "Read-first GitHub Actions health, self-hosted coverage, Codespaces activity, and likely cost/risk signals.") {
      HStack(spacing: 10) {
        Button(model.isLoadingRepoHealth ? "Loading..." : "Load Selected") {
          model.loadRepoHealthForSelectedRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingRepoHealth)

        Button("Load Visible") {
          model.loadRepoHealthForVisibleRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        .disabled(model.isLoadingRepoHealth || model.filteredRepos.isEmpty)
      }

      BannerCard(
        title: "Actions cost & risk analyzer",
        detail: model.repoHealthStatus,
        kind: model.repoHealthEntries.isEmpty ? .warning : .ready
      )

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.repoHealthEntries.isEmpty {
            Text("Load repo health to see enabled workflows, recent run volume, active Codespaces, self-hosted coverage, and risk score.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ForEach(model.repoHealthEntries) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(entry.slug)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: "\(entry.riskLabel) \(entry.riskScore)", tint: entry.riskScore >= 50 ? DashboardTheme.warning : DashboardTheme.success)
                }

                Text(entry.summary)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(3)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 240, maxHeight: 320)
    }
  }

  private var workflowControlPanel: some View {
    PanelCard(title: "Workflow Control Center", subtitle: "Load repository workflows, open YAML locally, enable or disable them, or dispatch supported manual workflows.") {
      FixedValueRow(label: "Target Repository", value: model.primaryRepoSlug ?? "Select or target a repository first")

      HStack(spacing: 10) {
        Button(model.isLoadingWorkflowData ? "Loading..." : "Load Workflows") {
          model.loadWorkflowCatalog()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingWorkflowData)

        Button("Open GitHub Account") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.workflowStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.workflows.isEmpty {
            Text("No workflows loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.workflows) { workflow in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(workflow.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: workflow.state, tint: workflow.state.lowercased() == "active" ? DashboardTheme.success : DashboardTheme.warning)
                }

                Text(workflow.path)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)

                HStack(spacing: 10) {
                  Button("Open YAML") {
                    model.openWorkflowSource(workflow)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

                  Button("Dispatch") {
                    model.runWorkflow(workflow)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

                  Button(workflow.state.lowercased() == "active" ? "Disable" : "Enable") {
                    if workflow.state.lowercased() == "active" {
                      model.disableWorkflow(workflow)
                    } else {
                      model.enableWorkflow(workflow)
                    }
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 260, maxHeight: 340)
    }
  }

  private var workflowRunsPanel: some View {
    PanelCard(title: "Workflow Runs Explorer", subtitle: "Review recent runs, open them on GitHub, and cancel, rerun, or delete them without leaving the app.") {
      HStack(spacing: 10) {
        Button(model.isLoadingWorkflowData ? "Loading..." : "Load Runs") {
          model.loadWorkflowRuns()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingWorkflowData)

        Button("Preview Cleanup") {
          selectedDestination = .cleanup
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.workflowRuns.isEmpty {
            Text("No workflow runs loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.workflowRuns) { run in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(run.workflowName ?? run.name ?? "Workflow Run")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: run.status ?? "unknown", tint: (run.conclusion ?? "").lowercased() == "success" ? DashboardTheme.success : DashboardTheme.warning)
                }

                Text([run.displayTitle ?? "", run.headBranch ?? "", run.event ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)

                HStack(spacing: 10) {
                  Button("Open") {
                    model.openWorkflowRunInBrowser(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

                  Button("Rerun") {
                    model.rerunWorkflowRun(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

                  Button("Cancel") {
                    model.cancelWorkflowRun(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

                  Button("Delete") {
                    model.deleteWorkflowRun(run)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 260, maxHeight: 340)
    }
  }

  private var codespacesPanel: some View {
    PanelCard(title: "Codespaces Inventory", subtitle: "List, stop, and delete live Codespaces and compare them to the local runtime workspace.") {
      HStack(spacing: 10) {
        Button(model.isLoadingCodespaces ? "Loading..." : "Load Codespaces") {
          model.loadCodespaces()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingCodespaces)

        Button("Open Projects") {
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.codespacesStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.codespaces.isEmpty {
            Text("No Codespaces loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.codespaces) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(entry.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: entry.state, tint: entry.state.lowercased().contains("available") ? DashboardTheme.success : DashboardTheme.warning)
                }

                Text([entry.repo, entry.machineName, entry.lastUsedAt].filter { !$0.isEmpty }.joined(separator: " · "))
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)

                HStack(spacing: 10) {
                  Button("Stop") {
                    model.stopCodespace(entry)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

                  Button("Delete") {
                    model.deleteCodespace(entry)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 120, idealHeight: 220, maxHeight: 280)
    }
  }

  private var secretsAndVariablesPanel: some View {
    PanelCard(title: "Secrets & Variables", subtitle: "Compare repo and organization-level secret/variable presence without exposing secret values.") {
      HStack(spacing: 10) {
        Button(model.isLoadingSecretsData ? "Loading..." : "Load Secrets & Variables") {
          model.loadSecretsAndVariables()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingSecretsData)

        Button("Open Repo Settings") {
          model.openRepoSettingsPage()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      BannerCard(
        title: "Repo \(model.repoSecrets.count) secrets · \(model.repoVariables.count) variables",
        detail: model.secretsStatus + "\nOrg \(model.orgSecrets.count) secrets · \(model.orgVariables.count) variables",
        kind: .ready
      )

      FixedValueRow(label: "Repo Secret Names", value: model.repoSecrets.isEmpty ? "None loaded" : model.repoSecrets.map(\.name).joined(separator: ", "))
      FixedValueRow(label: "Repo Variable Names", value: model.repoVariables.isEmpty ? "None loaded" : model.repoVariables.map(\.name).joined(separator: ", "))
      FixedValueRow(label: "Org Secret Names", value: model.orgSecrets.isEmpty ? "None loaded" : model.orgSecrets.map(\.name).joined(separator: ", "))
      FixedValueRow(label: "Org Variable Names", value: model.orgVariables.isEmpty ? "None loaded" : model.orgVariables.map(\.name).joined(separator: ", "))
    }
  }

  private var rulesetsPanel: some View {
    PanelCard(title: "Branch Protection & Rulesets", subtitle: "Read-first view of required checks, review policy, admin enforcement, and repo rulesets.") {
      HStack(spacing: 10) {
        Button(model.isLoadingRulesData ? "Loading..." : "Load Rules") {
          model.loadBranchProtectionAndRulesets()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingRulesData)

        Button("Open Cleanup") {
          selectedDestination = .cleanup
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
      }

      if let protection = model.branchProtectionSummary {
        BannerCard(
          title: "Default branch: \(protection.branch)",
          detail: "Required status checks: \(protection.requiredStatusChecks)\nRequired PR reviews: \(protection.requiredPullRequestReviews ? "yes" : "no")\nEnforce admins: \(protection.enforceAdmins ? "yes" : "no")",
          kind: .ready
        )
      } else {
        BannerCard(
          title: "No branch protection loaded",
          detail: model.rulesStatus,
          kind: .warning
        )
      }

      if model.rulesets.isEmpty {
        Text("No rulesets loaded yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.rulesets) { ruleset in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(ruleset.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("\(ruleset.target) · \(ruleset.enforcement) · \(ruleset.source)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }
            Spacer(minLength: 8)
            PillBadge(text: ruleset.enforcement, tint: DashboardTheme.warning)
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var workspaceSetupPanel: some View {
    let standardSuggestion = model.standardWorkspaceSuggestion
    let detectedSuggestion = model.detectedWorkspaceSuggestion

    return PanelCard(title: "Workspace Setup", subtitle: "Choose one simple storage style, use the standard path, or apply the setup this Mac already has.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Workspace Style")
        Picker("", selection: Binding(
          get: { model.selectedWorkspaceStyle },
          set: { model.setWorkspaceStyle($0) }
        )) {
          ForEach(WorkspaceStyle.allCases) { style in
            Text(style.label).tag(style)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
      }

      Toggle("Follow the current saved workspace automatically", isOn: $model.useCurrentRoot)
        .toggleStyle(.switch)
        .tint(DashboardTheme.success)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: standardSuggestion.title,
        detail: standardSuggestion.detail + "\n" + (model.selectedWorkspaceStyle == .single
          ? standardSuggestion.runtimeRoot
          : "Code: \(standardSuggestion.codeRoot)\nRuntime: \(standardSuggestion.runtimeRoot)"),
        kind: .ready
      )

      if let detectedSuggestion {
        BannerCard(
          title: detectedSuggestion.title,
          detail: detectedSuggestion.detail + "\n" + (detectedSuggestion.style == .single
            ? detectedSuggestion.runtimeRoot
            : "Code: \(detectedSuggestion.codeRoot)\nRuntime: \(detectedSuggestion.runtimeRoot)"),
          kind: .ready
        )
      }

      if model.selectedWorkspaceStyle == .single {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Workspace Folder")
          TextField("Choose a single local root", text: $model.workspaceSingleRootDraft)
            .textFieldStyle(.plain)
            .foregroundStyle(DashboardTheme.text)
            .dashboardFieldStyle()
        }

        HStack(spacing: 10) {
          Button("Choose Folder") {
            model.chooseSingleWorkspaceFolder()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button("Use Standard") {
            model.applyStandardWorkspace()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))

          if detectedSuggestion != nil {
            Button("Use Detected Setup") {
              model.applyDetectedWorkspace()
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Code Folder")
          TextField("Choose the folder for plain repos", text: $model.workspaceCodeRootDraft)
            .textFieldStyle(.plain)
            .foregroundStyle(DashboardTheme.text)
            .dashboardFieldStyle()
        }

        VStack(alignment: .leading, spacing: 6) {
          FieldLabel(text: "Runtime Folder")
          TextField("Choose the folder for devcontainers, reports, and runners", text: $model.workspaceRuntimeRootDraft)
            .textFieldStyle(.plain)
            .foregroundStyle(DashboardTheme.text)
            .dashboardFieldStyle()
        }

        HStack(spacing: 10) {
          Button("Choose Code") {
            model.chooseCodeWorkspaceFolder()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button("Choose Runtime") {
            model.chooseRuntimeWorkspaceFolder()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Use Standard") {
            model.applyStandardWorkspace()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        }

        if detectedSuggestion != nil {
          Button("Use Detected Setup") {
            model.applyDetectedWorkspace()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        }
      }

      HStack(spacing: 10) {
        Button("Save Workspace") {
          model.saveWorkspaceDrafts()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Open Projects Page") {
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      Text("The standard setup is concrete and generic. Your external-drive layout is still detected automatically on this Mac, but it is now presented as an optional detected setup instead of a product preset.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var localFilesRelocationPanel: some View {
    PanelCard(title: "Relocate Workspace", subtitle: "Move the current workspace roots to a new base folder and update the saved workspace so the app follows the new location.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "New Base Folder")
        TextField("Choose a destination for the moved workspace", text: $model.workspaceMoveDestinationDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      Toggle("Allow overwrite if destination folders already exist", isOn: $model.overwriteLocalFileDestination)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: model.workspaceExecutionLabel == "single-folder workspace" ? "Move the full workspace root" : "Move one root or both roots",
        detail: model.localFilesStatus,
        kind: model.isRunningLocalFileOperation ? .running : .ready
      )

      HStack(spacing: 10) {
        Button("Choose Destination") {
          model.chooseWorkspaceMoveDestinationFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Move Workspace") {
          model.relocateWorkspace(.workspace)
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: false))
        .disabled(model.isRunningLocalFileOperation)
      }

      if model.selectedWorkspaceStyle == .split {
        HStack(spacing: 10) {
          Button("Move Code Root Only") {
            model.relocateWorkspace(.codeRoot)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
          .disabled(model.isRunningLocalFileOperation)

          Button("Move Runtime Root Only") {
            model.relocateWorkspace(.runtimeRoot)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          .disabled(model.isRunningLocalFileOperation)
        }
      }

      Text("When you move workspace roots here, the app updates the saved workspace to point at the new location. This is the right path when you are relocating your active setup to another drive.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var localFilesExportPanel: some View {
    PanelCard(title: "Backup & Export", subtitle: "Copy or move selected projects or workspace content into a structured export bundle for another drive, archive, or handoff.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Export Destination")
        TextField("Choose where the export bundle should be created", text: $model.localExportDestinationDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Choose Destination") {
          model.chooseLocalExportDestinationFolder()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button(model.localFilesPrimaryActionTitle) {
          model.runLocalExport()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.isRunningLocalFileOperation)
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Transfer Mode")
        Picker("", selection: $model.localFileTransferMode) {
          ForEach(LocalFileTransferMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Export Scope")
        Picker("", selection: $model.localFileExportScope) {
          ForEach(LocalFileExportScope.allCases) { scope in
            Text(scope.label).tag(scope)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .dashboardFieldStyle()
      }

      if model.localFileExportScope == .selectedProjects {
        Toggle("Include code paths", isOn: $model.includeProjectCodeExport)
          .toggleStyle(.switch)
          .tint(DashboardTheme.deepBlue)
          .foregroundStyle(DashboardTheme.text)

        Toggle("Include runtime paths", isOn: $model.includeProjectRuntimeExport)
          .toggleStyle(.switch)
          .tint(DashboardTheme.success)
          .foregroundStyle(DashboardTheme.text)

        Toggle("Include runner folders", isOn: $model.includeProjectRunnerExport)
          .toggleStyle(.switch)
          .tint(DashboardTheme.warning)
          .foregroundStyle(DashboardTheme.text)
      }

      Toggle("Allow overwrite if export targets already exist", isOn: $model.overwriteLocalFileDestination)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      BannerCard(
        title: model.localFilesScopeSummary,
        detail: model.localFilesStatus,
        kind: model.isRunningLocalFileOperation ? .running : .ready
      )

      Text("Selected-project exports preserve a concrete structure under `Code/Repos`, `Runtime/Repos`, and `Runtime/Runners`. Use `Copy Backup` for safe archives and `Move` when you want to relocate items out of the current workspace.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var backupPresetsPanel: some View {
    PanelCard(title: "Backup Presets", subtitle: "Reusable local-file presets for common archive and transfer combinations.") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
        ForEach(BackupPreset.allCases) { preset in
          Button {
            model.applyBackupPreset(preset)
          } label: {
            HStack {
              Text(preset.label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Spacer(minLength: 8)
              if model.selectedBackupPreset == preset {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(DashboardTheme.success)
              }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(model.selectedBackupPreset == preset ? DashboardTheme.field : DashboardTheme.panelStrong)
                .overlay(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(model.selectedBackupPreset == preset ? DashboardTheme.success.opacity(0.55) : DashboardTheme.border, lineWidth: 1)
                )
            )
          }
          .buttonStyle(.plain)
        }
      }

      Text("Use a preset first, then preview the export or snapshot before you move or copy local data.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
    }
  }

  private var localFilesPreviewPanel: some View {
    PanelCard(title: "Preview & Move Wizard", subtitle: "Inspect destination, size, and collision risk before you move workspace roots or export local data.") {
      HStack(spacing: 10) {
        Button("Preview Workspace Move") {
          model.previewWorkspaceMove(.workspace)
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("Preview Export") {
          model.previewLocalExport()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      if let preview = model.localOperationPreview {
        BannerCard(
          title: preview.title,
          detail: "Destination: \(preview.destinationPath)\nItems: \(preview.itemCount)\nEstimated size: \(preview.totalSizeLabel)",
          kind: preview.collisions.isEmpty ? .ready : .warning
        )

        if !preview.collisions.isEmpty {
          FixedValueRow(label: "Existing Destination Conflicts", value: preview.collisions.joined(separator: "\n"))
        }
      } else {
        Text("No preview generated yet. Use preview first, then run the move or export.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
    }
  }

  private var snapshotsPanel: some View {
    PanelCard(title: "Workspace Snapshots", subtitle: "Create point-in-time archives before major changes, then restore or remove them later.") {
      HStack(spacing: 10) {
        Button("Create Snapshot") {
          model.createSnapshot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))
        .disabled(model.isRunningLocalFileOperation)

        Button("Refresh Storage") {
          model.loadStorageInsights()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      Text(model.snapshotStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      if model.snapshots.isEmpty {
        Text("No snapshots saved yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(model.snapshots.sorted(by: { $0.createdAt > $1.createdAt })) { snapshot in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(snapshot.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: snapshot.sourceScope, tint: DashboardTheme.warning)
                }

                Text("\(snapshot.itemCount) items · \(snapshot.destinationPath)")
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
                  .lineLimit(3)

                HStack(spacing: 10) {
                  Button("Restore") {
                    model.restoreSnapshot(snapshot)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

                  Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: snapshot.destinationPath)])
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

                  Button("Delete") {
                    model.removeSnapshot(snapshot)
                  }
                  .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
        .frame(minHeight: 150, idealHeight: 220, maxHeight: 280)
      }
    }
  }

  private var projectQuickActionsPanel: some View {
    PanelCard(title: "Project Quick Actions", subtitle: "Native operator console for the selected local project: open, inspect, build, up, rebuild, and manage linked local services.") {
      if let project = model.primaryLocalProject {
        BannerCard(
          title: project.slug,
          detail: "Code: \(project.codePath ?? "Unavailable")\nRuntime: \(project.runtimePath ?? "Unavailable")",
          kind: .ready
        )

        HStack(spacing: 10) {
          Button("Open Runtime") {
            model.openLocalProject(project, preferRuntime: true)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

          Button("Open Code") {
            model.openLocalProject(project, preferRuntime: false)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button("Finder") {
            model.revealLocalProject(project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

          Button(model.favoriteProjects.contains(project.slug) ? "Unfavorite" : "Favorite") {
            model.toggleFavorite(project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        }

        HStack(spacing: 10) {
          Button("Open Devcontainer") {
            model.openDevcontainerConfig(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
          .disabled(!project.hasDevcontainer)

          Button("Build") {
            model.buildDevcontainer(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
          .disabled(project.preferredOpenPath == nil)

          Button("Up") {
            model.upDevcontainer(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
          .disabled(project.preferredOpenPath == nil)

          Button("Rebuild") {
            model.rebuildDevcontainer(for: project)
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          .disabled(project.preferredOpenPath == nil)
        }
      } else {
        Text("Target or search to one local project to unlock quick actions.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      }
    }
  }

  private var favoritesAndViewsPanel: some View {
    PanelCard(title: "Favorites, Views & Quick Actions", subtitle: "Pin common repos, save library filters, and recall them instantly.") {
      BannerCard(
        title: "\(model.favoriteProjectCount) favorites · \(model.savedProjectViews.count) saved views",
        detail: "Local library filter: \(model.localProjectSearch.isEmpty ? "none" : model.localProjectSearch)\nFavorites only: \(model.showFavoritesOnly ? "on" : "off")",
        kind: .ready
      )

      Toggle("Show favorites only in Local Project Library", isOn: $model.showFavoritesOnly)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Save Current Project View")
        TextField("Favorites + self-hosted runners", text: $model.savedViewNameDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button("Save View") {
          model.saveCurrentProjectView()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        Button("Open Projects") {
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
      }

      if model.savedProjectViews.isEmpty {
        Text("No saved views yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.savedProjectViews) { view in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(view.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("Query: \(view.query.isEmpty ? "none" : view.query) · Favorites only: \(view.favoritesOnly ? "yes" : "no")")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
            }

            Spacer(minLength: 8)

            Button("Apply") {
              model.applyProjectView(view)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

            Button("Delete") {
              model.deleteProjectView(view)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var taskTemplatesPanel: some View {
    PanelCard(title: "Task Templates", subtitle: "Store reusable local project commands such as install, build, test, deploy, or Docker actions.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Task Name")
        TextField("Install dependencies", text: $model.taskNameDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Command")
        TextField("npm install && npm test", text: $model.taskCommandDraft)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Run In")
        Picker("", selection: $model.taskLocationDraft) {
          ForEach(ProjectTaskLocation.allCases) { location in
            Text(location.label).tag(location)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
      }

      HStack(spacing: 10) {
        Button("Save Task") {
          model.addTaskTemplate()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: false))

        if model.isRunningTask {
          Button("Cancel Task") {
            model.cancelRun()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        }
      }

      Text(model.taskStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      if model.filteredTaskTemplates.isEmpty {
        Text("No saved tasks for the currently targeted project.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.filteredTaskTemplates) { task in
          HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
              Text(task.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DashboardTheme.text)
              Text("\(task.location.label) · \(task.command)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardTheme.muted)
                .lineLimit(3)
            }

            Spacer(minLength: 8)

            Button("Run") {
              model.runTaskTemplate(task)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))

            Button("Delete") {
              model.removeTaskTemplate(task)
            }
            .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var storageInsightsPanel: some View {
    PanelCard(title: "Disk Usage & Storage Insights", subtitle: "Local storage reporting for workspace roots, runners, snapshots, and major local service footprints.") {
      HStack(spacing: 10) {
        Button(model.isLoadingStorageInsights ? "Loading..." : "Load Storage") {
          model.loadStorageInsights()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingStorageInsights)

        Button("Open Local Files") {
          selectedDestination = .localFiles
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.storageStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      if model.storageInsights.isEmpty {
        Text("No storage insights loaded yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
      } else {
        ForEach(model.storageInsights) { entry in
          FixedValueRow(label: "\(entry.label) · \(entry.sizeLabel)", value: entry.path)
        }
      }
    }
  }

  private var projectSyncPanel: some View {
    PanelCard(title: "Project Sync Status", subtitle: "Compare code and runtime worktrees for ahead/behind/dirty state to spot drift before cleanup or backup.") {
      HStack(spacing: 10) {
        Button(model.isLoadingProjectSync ? "Loading..." : "Load Sync Status") {
          model.loadProjectSyncStatus()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingProjectSync)

        Button("Open GitHub Account") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.syncStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.projectSyncEntries.isEmpty {
            Text("No project sync data loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.projectSyncEntries) { entry in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(entry.slug)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Spacer(minLength: 8)
                  PillBadge(text: entry.codeDirty || entry.runtimeDirty ? "dirty" : "clean", tint: entry.codeDirty || entry.runtimeDirty ? DashboardTheme.warning : DashboardTheme.success)
                }
                Text(entry.summary)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(DashboardTheme.muted)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 160, idealHeight: 220, maxHeight: 280)
    }
  }

  private var portMonitorPanel: some View {
    PanelCard(title: "Service & Port Monitor", subtitle: "Native view of listening local services and exposed development ports on this Mac.") {
      HStack(spacing: 10) {
        Button(model.isLoadingPorts ? "Loading..." : "Scan Ports") {
          model.loadPortMonitor()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingPorts)

        Button("Refresh Services") {
          model.refreshLiveServices()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.portsStatus)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.portMonitorEntries.isEmpty {
            Text("No port scan results loaded yet.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
          } else {
            ForEach(model.portMonitorEntries.prefix(20)) { entry in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("\(entry.processName) · \(entry.proto)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DashboardTheme.text)
                  Text("PID \(entry.pid) · Port \(entry.port)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.muted)
                }
                Spacer(minLength: 8)
                PillBadge(text: entry.port, tint: DashboardTheme.accent)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(DashboardTheme.panelStrong)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .stroke(DashboardTheme.border, lineWidth: 1)
                  )
              )
            }
          }
        }
      }
      .frame(minHeight: 140, idealHeight: 220, maxHeight: 280)
    }
  }

  private var advancedToolsPanel: some View {
    PanelCard(title: "Advanced Tools", subtitle: "Use native pages first. Terminal fallbacks stay optional for edge cases and power workflows.") {
      HStack(spacing: 10) {
        Button("Projects Page") {
          model.refreshLocalProjects()
          model.refreshLiveServices()
          selectedDestination = .projects
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Cleanup Page") {
          selectedDestination = .cleanup
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      HStack(spacing: 10) {
        Button("Jobs Page") {
          selectedDestination = .jobs
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

        Button("GitHub Account") {
          selectedDestination = .githubAccount
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
      }

      Text("Normal use should stay inside the native app: Projects for local work, Cleanup for GitHub cost-control, Jobs for execution state, and GitHub Account for repo administration.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)

      if model.appSettings.keepTerminalFallbacksVisible {
        Divider()
          .overlay(DashboardTheme.border)

        HStack(spacing: 10) {
          Button("Interactive CLI") {
            model.openCLIInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

          Button("Terminal Browser") {
            model.openProjectBrowserInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
        }

        HStack(spacing: 10) {
          Button("Terminal Cost-Control") {
            model.openCostControlReviewInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))

          Button("Terminal Devcontainers") {
            model.openInstalledDevcontainersInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        }
      } else {
        Text("Terminal fallback buttons are hidden by default. You can re-enable them in Settings if you still want the legacy edge-case launchers.")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .lineSpacing(2)
      }
    }
  }

  private var rootsPanel: some View {
    let roots = model.profileRootSummary

    return PanelCard(title: "Active Workspace Paths", subtitle: "These are the live local paths the GUI is using right now for imported projects, runtime work, reports, and runners.") {
      FixedValueRow(label: "Code Root", value: roots.codeRoot)
      FixedValueRow(label: "Runtime Root", value: roots.runtimeRoot)

      HStack(spacing: 10) {
        Button("Reveal Code Root") {
          model.revealCodeRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Reveal Runtime Root") {
          model.revealRuntimeRoot()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      Text(model.useCurrentRoot
        ? "The app is following your saved workspace setup. Use the Workspace page when you want to change paths or apply a different detected setup."
        : "The app is showing the built-in standard paths. Turn the saved-workspace toggle back on when you want the GUI to follow your stored setup again.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var overviewPanel: some View {
    let metricColumns = [
      GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12, alignment: .top)
    ]

    return PanelCard(title: "Local Inventory", subtitle: "Fast production snapshot of imported project coverage for the current workspace setup.") {
      LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
        MetricTile(
          label: "Imported Projects",
          value: "\(model.localProjects.count)",
          tint: DashboardTheme.accent,
          icon: "shippingbox"
        )

        MetricTile(
          label: "Split Code + Runtime",
          value: "\(model.localProjectSplitCount)",
          tint: DashboardTheme.deepBlue,
          icon: "square.split.2x1"
        )

        MetricTile(
          label: "Ready Devcontainers",
          value: "\(model.localProjectDevcontainerCount)",
          tint: DashboardTheme.success,
          icon: "shippingbox.circle"
        )

        MetricTile(
          label: "Local Runners",
          value: "\(model.localProjectRunnerCount)",
          tint: DashboardTheme.warning,
          icon: "bolt.shield"
        )

        MetricTile(
          label: "Active Devcontainers",
          value: "\(model.activeContainerCount)",
          tint: DashboardTheme.deepBlue,
          icon: "shippingbox.fill"
        )

        MetricTile(
          label: "Running Runner Services",
          value: "\(model.runningRunnerServiceCount)",
          tint: DashboardTheme.success,
          icon: "bolt.horizontal.circle"
        )
      }

      BannerCard(
        title: "Generated starters: \(model.localProjectGeneratedStarterCount) · Runtime-only workspaces: \(model.localProjectRuntimeOnlyCount)",
        detail: "\(model.localProjectStatus)\n\(model.liveServiceSummary)",
        kind: model.localProjects.isEmpty ? .warning : .ready
      )
    }
  }

  private var localProjectsPanel: some View {
    PanelCard(title: "Local Project Library", subtitle: "Search imported local workspaces and open them directly from the native app.") {
      HStack(spacing: 10) {
        Button(model.isLoadingLocalProjects ? "Refreshing..." : "Refresh Local Projects") {
          model.refreshLocalProjects()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingLocalProjects)

        Button(model.areAllVisibleLocalProjectsSelected ? "Untarget Visible" : "Target Visible") {
          model.setFilteredLocalProjectsSelected(!model.areAllVisibleLocalProjectsSelected)
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.filteredLocalProjects.isEmpty)
      }

      Toggle("Favorites only", isOn: $model.showFavoritesOnly)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Search Imported Projects")
        TextField("Filter by owner, repo name, workspace type, runner, or devcontainer", text: $model.localProjectSearch)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      BannerCard(
        title: model.localProjectSummary,
        detail: "\(model.localProjectStatus)\nCleanup targets from local library: \(model.selectedLocalProjectCount)",
        kind: model.localProjects.isEmpty ? .warning : .ready
      )

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.filteredLocalProjects.isEmpty {
            Text(model.localProjects.isEmpty ? "No imported local projects were found yet." : "No imported local projects match the current search.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 4)
          } else {
            ForEach(model.filteredLocalProjects) { project in
              LocalProjectRow(
                project: project,
                isTargeted: model.selectedRepos.contains(project.slug),
                isFavorite: model.favoriteProjects.contains(project.slug),
                toggleTarget: { model.toggleLocalProjectTarget(project) },
                toggleFavorite: { model.toggleFavorite(project) },
                openRuntime: { model.openLocalProject(project, preferRuntime: true) },
                openCode: { model.openLocalProject(project, preferRuntime: false) },
                reveal: { model.revealLocalProject(project) }
              )
            }
          }
        }
      }
      .frame(minHeight: 180, idealHeight: 260, maxHeight: 320)

      Text("This native library follows the active workspace setup, so you can search imported projects and jump straight into the code or runtime folder without leaving the app.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var liveServicesPanel: some View {
    PanelCard(title: "Live Local Services", subtitle: "Native view of active devcontainers and local runner services for the current workspace.") {
      HStack(spacing: 10) {
        Button(model.isLoadingLiveServices ? "Refreshing..." : "Refresh Live Services") {
          model.refreshLiveServices()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingLiveServices)

        Button("Open Advanced Tools") {
          selectedDestination = .workspace
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.deepBlue, bordered: true))
      }

      BannerCard(
        title: model.liveServiceSummary,
        detail: model.liveServicesStatus,
        kind: (model.activeContainers.isEmpty && model.runnerServices.isEmpty) ? .warning : .ready
      )

      if model.activeContainers.isEmpty && model.runnerServices.isEmpty {
        Text("No active devcontainers or configured runner services were detected for the current workspace yet.")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(DashboardTheme.muted)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        if !model.activeContainers.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "Active Devcontainers")

            ScrollView {
              LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(model.activeContainers) { container in
                  LiveContainerRow(
                    container: container,
                    openRuntime: { model.openContainerProject(container, preferRuntime: true) },
                    openCode: { model.openContainerProject(container, preferRuntime: false) },
                    reveal: { model.revealContainer(container) },
                    logs: { model.openContainerLogs(container) },
                    stop: { model.stopContainer(container) },
                    remove: { model.removeContainer(container) }
                  )
                }
              }
            }
            .frame(minHeight: 120, idealHeight: 180, maxHeight: 220)
          }
        }

        if !model.runnerServices.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "Local Runner Services")

            ScrollView {
              LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(model.runnerServices) { runner in
                  RunnerServiceRow(
                    runner: runner,
                    openRuntime: { model.openRunnerProject(runner, preferRuntime: true) },
                    openCode: { model.openRunnerProject(runner, preferRuntime: false) },
                    reveal: { model.revealRunnerService(runner) },
                    start: { model.startRunnerService(runner) },
                    restart: { model.restartRunnerService(runner) },
                    verify: { model.verifyRunnerService(runner) },
                    stop: { model.stopRunnerService(runner) }
                  )
                }
              }
            }
            .frame(minHeight: 120, idealHeight: 180, maxHeight: 220)
          }
        }
      }

      Text("Use this page for the common local actions: inspect what is currently active, open the linked workspace, reveal it in Finder, or stop the container or runner without leaving the native app.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var repositoryPanel: some View {
    PanelCard(title: "Repository Targets", subtitle: "Browse repositories for the selected account or owner, then check one, many, or all.") {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Owner or Org to List")
        TextField("Defaults to the selected GitHub account", text: $model.repoOwner)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      HStack(spacing: 10) {
        Button(model.isLoadingRepos ? "Loading..." : "Load Repositories") {
          model.fetchAvailableRepos()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))
        .disabled(model.isLoadingRepos || !model.isAuthenticated)

        Button("Clear All Targets") {
          model.selectedRepos.removeAll()
        }
        .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        .disabled(model.selectedRepos.isEmpty)
      }

      Toggle(
        "Select all loaded repositories (\(model.availableRepos.count))",
        isOn: Binding(
          get: { model.areAllLoadedReposSelected },
          set: { model.setAllLoadedReposSelected($0) }
        )
      )
      .toggleStyle(.switch)
      .tint(DashboardTheme.success)
      .foregroundStyle(DashboardTheme.text)
      .disabled(model.availableRepos.isEmpty)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Search Loaded Repositories")
        TextField("Filter by owner, repo name, or visibility", text: $model.repoSearch)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
          .disabled(model.availableRepos.isEmpty)
      }

      BannerCard(
        title: model.selectedRepoSummary,
        detail: model.repoCatalogStatus,
        kind: model.cleanupTargets.isEmpty ? .warning : .ready
      )

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if model.filteredRepos.isEmpty {
            Text(model.availableRepos.isEmpty ? "No repositories loaded yet." : "No repositories match the current search.")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(DashboardTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 4)
          } else {
            ForEach(model.filteredRepos) { repo in
              RepoSelectionRow(
                repo: repo,
                isSelected: model.selectedRepos.contains(repo.nameWithOwner)
              ) {
                model.toggleRepoSelection(repo)
              }
            }
          }
        }
      }
      .frame(minHeight: 180, idealHeight: 260, maxHeight: 320)

      Divider().overlay(DashboardTheme.border)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Manual Repository or URL Fallback")
        TextField("OWNER/REPO or https://github.com/OWNER/REPO", text: $model.repoTarget)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      Text("If one or more repositories are checked above, the manual field is ignored. Use the manual field only when you want a one-off target that is not in the loaded list.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private var cleanupPanel: some View {
    PanelCard(title: "Cleanup Scope", subtitle: "Single control panel for actions, filters, and destructive state.") {
      Toggle("Full cleanup", isOn: $model.fullCleanup)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)

      Divider().overlay(DashboardTheme.border)

      Toggle("Disable workflows", isOn: $model.disableWorkflows)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete workflow runs", isOn: $model.deleteRuns)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete artifacts", isOn: $model.deleteArtifacts)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete caches", isOn: $model.deleteCaches)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)
        .disabled(model.fullCleanup)

      Toggle("Delete Codespaces", isOn: $model.deleteCodespaces)
        .toggleStyle(.switch)
        .tint(actionToggleTint)
        .foregroundStyle(DashboardTheme.text)

      Divider().overlay(DashboardTheme.border)

      Toggle("Dry run only", isOn: $model.dryRun)
        .toggleStyle(.switch)
        .tint(DashboardTheme.warning)
        .foregroundStyle(DashboardTheme.text)

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Specific Run ID or Run URL")
        TextField("Optional exact run target", text: $model.runTarget)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }

      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(text: "Run Filter")
        TextField("Optional run name filter", text: $model.runFilter)
          .textFieldStyle(.plain)
          .foregroundStyle(DashboardTheme.text)
          .dashboardFieldStyle()
      }
    }
  }

  private var executionPanel: some View {
    VStack(alignment: .leading, spacing: 18) {
      SafetyCard(isArmed: $model.safetyArmEnabled, dryRun: model.dryRun)

      PanelCard(title: "Execution", subtitle: "The native app runs the bundled CSA-iEM CLI engine and keeps the raw terminal fallback available.", compact: true) {
        HStack(spacing: 10) {
          Button(model.dryRun ? "Preview Cleanup" : "Execute Cleanup") {
            model.runCleanup()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.danger, bordered: false))
          .disabled(!model.canRunCleanup)

          Button("Open CLI") {
            model.openCLIInTerminal()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.accent, bordered: true))

        Button("Clear Log") {
            model.logText = "[gui] \(appTitle) ready.\n"
        }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.success, bordered: true))
        }

        if model.isRunning {
          Button("Cancel Active Run") {
            model.cancelRun()
          }
          .buttonStyle(DashboardButtonStyle(tint: DashboardTheme.warning, bordered: true))
        }

        Text(model.safetyArmEnabled ? "Safety arm is ON. Cleanup is unlocked for the selected target." : "Safety arm is OFF. Turn on the destructive cleanup switch before execution.")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(model.safetyArmEnabled ? DashboardTheme.success : DashboardTheme.warning)
      }
    }
  }

  private var libraryPanel: some View {
    PanelCard(title: "In-App Pages", subtitle: "Navigate to Help, Terms, Security, Brand, project notes, and About without leaving the app window.") {
      BannerCard(
        title: selectedDestination == .home ? "Home Active" : "\(selectedDestination.title) Active",
        detail: "Use the app menu to move between bundled pages. Documentation and product info now live inside the native interface instead of opening external markdown windows.",
        kind: .ready
      )

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
        ForEach(knowledgeDestinations + [.about]) { destination in
          DestinationShortcutTile(
            destination: destination,
            isSelected: selectedDestination == destination
          ) {
            selectedDestination = destination
          }
        }
      }

      Text("The app now uses a native multi-page menu system. Help, legal, security, brand, and project pages stay inside the product instead of opening external document windows.")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(DashboardTheme.muted)
        .lineSpacing(2)
    }
  }

  private func logPanel(minHeight: CGFloat) -> some View {
    PanelCard(title: "Live Output", subtitle: "Readable, high-contrast CLI output streamed into the native app.") {
      LogConsoleView(text: model.logText)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: minHeight)
        .background(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(DashboardTheme.panelStrong)
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DashboardTheme.border, lineWidth: 1)
            )
        )
    }
  }
}

@main
struct CSAiEMMacApp: App {
  @NSApplicationDelegateAdaptor(CSAiEMAppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup(appTitle) {
      ContentView()
    }
    .commands {
      CommandGroup(replacing: .newItem) { }
    }
  }
}

@MainActor
final class CSAiEMAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
       let iconImage = NSImage(contentsOf: iconURL) {
      NSApplication.shared.applicationIconImage = iconImage
    }

    DispatchQueue.main.async {
      for window in NSApp.windows {
        self.configure(window)
      }
    }
  }

  private func configure(_ window: NSWindow) {
    let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1600, height: 920)
    let targetSize = idealWindowSize(for: visibleFrame.size)
    let targetOrigin = NSPoint(
      x: visibleFrame.origin.x + ((visibleFrame.width - targetSize.width) / 2),
      y: visibleFrame.origin.y + ((visibleFrame.height - targetSize.height) / 2)
    )

    window.minSize = NSSize(width: 760, height: 640)
    window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: true)
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.toolbarStyle = .unified
    window.backgroundColor = NSColor(calibratedRed: 9 / 255, green: 21 / 255, blue: 38 / 255, alpha: 1)
    window.isMovableByWindowBackground = false
    window.tabbingMode = .disallowed
  }

  private func idealWindowSize(for screenSize: NSSize) -> NSSize {
    let widthRatio: CGFloat
    let heightRatio: CGFloat

    switch screenSize.width {
    case ..<900:
      widthRatio = 0.98
      heightRatio = 0.94
    case ..<1280:
      widthRatio = 0.96
      heightRatio = 0.92
    case ..<1800:
      widthRatio = 0.92
      heightRatio = 0.90
    case ..<2600:
      widthRatio = 0.90
      heightRatio = 0.90
    default:
      widthRatio = 0.88
      heightRatio = 0.90
    }

    let width = min(max(screenSize.width * widthRatio, 760), 3200)
    let height = min(max(screenSize.height * heightRatio, 640), 1440)
    return NSSize(width: width, height: height)
  }
}
