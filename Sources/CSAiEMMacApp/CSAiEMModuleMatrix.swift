import Foundation

struct CSAiEMModuleTag: Identifiable, Hashable, Codable {
  let id: String
  let name: String
  let area: String
  let version: String
  let tag: String
  let state: String
  let lastUpdated: String

  static let matrixVersion = "matrix-1.4"

  static let catalog: [CSAiEMModuleTag] = [
    .init(id: "dashboard-shell", name: "Dashboard shell", area: "UI", version: appVersion, tag: "ui.dashboard", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "navigation", name: "Navigation and menus", area: "UI", version: appVersion, tag: "ui.navigation", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "status-surface", name: "Top and bottom status", area: "UI", version: appVersion, tag: "ui.status", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "page-scroll", name: "Page scrolling", area: "UI", version: appVersion, tag: "ui.scroll", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "codex-portal", name: "Codex project portal", area: "Feature", version: appVersion, tag: "feature.codex", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "smart-logic", name: "Smart Logic and decision matrix", area: "Engine", version: CodexSmartLogicEngine.ruleVersion, tag: "engine.smart-logic", state: "phase-13.35", lastUpdated: "2026-10-31"),
    .init(id: "index-catalog", name: "Local index catalog", area: "Engine", version: "catalog-v1.1", tag: "engine.index", state: "phase-13.45", lastUpdated: "2026-10-31"),
    .init(id: "transfer-receipts", name: "Transfer receipts", area: "Engine", version: "receipt-v3.17", tag: "engine.receipts", state: "phase-13.44", lastUpdated: "2026-08-13"),
    .init(id: "stage2", name: "Stage 2 reconciliation", area: "Feature", version: appVersion, tag: "feature.stage2", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "stage3", name: "Stage 3 cleanup", area: "Feature", version: appVersion, tag: "feature.stage3", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "github-bridge", name: "GitHub bridge", area: "Bridge", version: "issues-v1.4", tag: "bridge.github", state: "phase-12.8", lastUpdated: "2026-08-13"),
    .init(id: "firebase-core", name: "Firebase Apple bootstrap", area: "Bridge", version: "firebase-apple-v1.0", tag: "bridge.firebase", state: "phase-13.47", lastUpdated: "2026-08-22"),
    .init(id: "research-workspace", name: "Deep research workspace", area: "Feature", version: "research-v3.4", tag: "feature.research", state: "phase-13.35", lastUpdated: "2026-08-13"),
    .init(id: "local-files", name: "Local files and workspace roots", area: "Feature", version: appVersion, tag: "feature.local-files", state: "primary", lastUpdated: "2026-10-31"),
    .init(id: "checkout-review", name: "Checkout review and recovery", area: "Feature", version: "checkout-review-v1.0", tag: "feature.checkout-review", state: "local-hardening", lastUpdated: "2026-10-31"),
    .init(id: "source-residuals", name: "Old source leftovers", area: "Feature", version: "source-residuals-v1.0", tag: "feature.source-residuals", state: "local-hardening", lastUpdated: "2026-10-31"),
    .init(id: "transfer-artifacts", name: "Staging and backup cleanup", area: "Feature", version: "transfer-artifacts-v1.0", tag: "feature.transfer-artifacts", state: "local-hardening", lastUpdated: "2026-10-31"),
    .init(id: "app-settings", name: "Settings and privacy persistence", area: "Feature", version: "settings-v1.1", tag: "feature.settings", state: "phase-13.45", lastUpdated: "2026-08-19"),
    .init(id: "runner-bridge", name: "Runner and devcontainer bridge", area: "Bridge", version: appVersion, tag: "bridge.runners", state: "primary", lastUpdated: "2026-08-11"),
    .init(id: "recovery", name: "Recovery and resume", area: "Engine", version: appVersion, tag: "engine.recovery", state: "primary", lastUpdated: "2026-10-31"),
    .init(id: "macos-install", name: "macOS install and update", area: "Runtime", version: appVersion, tag: "runtime.install", state: "phase-13.45", lastUpdated: "2026-08-19"),
    .init(id: "toolbar", name: "Menu-bar toolbar", area: "Runtime", version: appVersion, tag: "runtime.toolbar", state: "phase-13.45", lastUpdated: "2026-08-19"),
    .init(id: "release-gate", name: "macOS publication gate", area: "Runtime", version: "release-gate-v1.3", tag: "runtime.release", state: "phase-13.47", lastUpdated: "2026-08-22"),
    .init(id: "incident-hub", name: "Incident and recovery hub", area: "Feature", version: "incident-v1.2", tag: "feature.incidents", state: "phase-12.4", lastUpdated: "2026-08-13")
  ]
}
