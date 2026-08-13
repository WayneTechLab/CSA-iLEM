# CSA-iEM Status

Version baseline: `0.8.0`
Updated: `2026-08-12`

This file is the current production-status snapshot for `CSA-iEM`.

Milestone status: the local macOS 0.8.0 CODEX ~ GPT Add-on milestone is a
closure candidate on branch `agent/csa-iem-0.8-dashboard-hardening`. Its
acceptance evidence is recorded in
`.SYSTEMX/AI/CODEX-GPT-ADDON-MASTER-PLAN.md`. The remaining production gaps
listed below are post-milestone work, not evidence that the implemented local
dashboard slice is incomplete.

Long-range product roadmap:
- [`docs/20-Phase-Roadmap.md`](./docs/20-Phase-Roadmap.md)

Native execution overlay:

- [10000-TASK-PLAN.md](./.SYSTEMX/AI/10000-TASK-PLAN.md) contains the
  10,000-task Full SU index derived from the roadmap.
- The overlay is planning and coordination metadata; it does not mark the
  underlying product milestones complete.

## Done

These major product areas are built into the app now:

- production CLI engine for import, local prep, cleanup, and review flows
- SwiftUI macOS GUI with `Home`, `Import`, `Projects`, `CODEX ~ GPT PORTAL`, `GitHub Account`, `GitHub Billing Reports`, `Local Files`, `Cleanup`, `Workspace`, `Settings`, and `About`
- Windows 11 admin-shell PowerShell backend for import, cleanup, browsing, devcontainer prep, and repo-level self-hosted runner setup
- explicit public workspace roots for `Code`, `Import`, and `Runtime` across the shared app model
- local project browsing with native search, favorites, targeting, and direct open actions
- local runner and devcontainer inspection/control from the GUI
- GitHub admin surfaces for repo health, workflows, runs, Codespaces, secrets/variables inventory, and rules/rulesets viewing
- local move/export/snapshot flows with preview-first behavior
- local CODEX project discovery, index-first preflight, verified backup, copy, sync, move, conflict quarantine, and handoff-note workflows
- Stage 2 GitHub-identity preflight and safety-gated selected/Full Auto reconciliation from preservation folders into canonical Code / Import / Runtime workspaces
- Stage 1 and Stage 2 verification receipts, Stage 3 receipt-linked cleanup, and selected/all end-to-end Full Auto lifecycle controls
- identity-bound repository consolidation from reviewed legacy sources into one canonical folder per GitHub repository, with complete representation proofs and fail-closed global retirement
- exact-transaction recovery resume from fully finalized destination-group checkpoints, including fresh source, Git, GitHub, receipt, remote, and representation revalidation
- native no-ACL fast-path verification that preserves the existing receipt digest for files carrying extended ACL entries
- receipt-bound local retirement and exact allowlisted external `_temp` payload cleanup after a successful recovery and fresh canonical audit
- custom local scan roots that can be entered, selected, or dropped into the portal and persist only in the local app profile
- mounted-drive Default workspace, backup, relocation, migration, and recovery flows
- native macOS menu-bar controls and Windows notification-area companion entry points
- native Codex control-plane dashboard with left-side import sources, right-side
  final output, connecting Smart Logic, scan profiles, cache visibility, and a
  dedicated Project Backups page composed from existing transfer/recovery flows
- unified module/version/tag matrix shown on every native dashboard page and
  fully expanded on Home for page, engine, bridge, runtime, and install state
- explicit vertical page scroll indicators with fixed top navigation and bottom
  status surfaces kept outside the page scroll region
- native Smart Logic decision records now persist to `.SYSTEMX/Index/catalog.sqlite`
  with JSON/CSV exports and Stage 1 preflight checkpoints; verified remote
  identity is required for automatic grouping
- durable transfer-index records now persist source/destination artifact
  digests, option sets, counts, and paths in the same SQLite catalog; saved
  cache reuse requires that catalog record and current artifact digests
- native Swift test target now covers Smart Logic grouping/classification,
  deterministic advisory non-authority, catalog session/checkpoint exports,
  module matrix contracts, review semantics, and backup-medium policy labels
- non-destructive native release preflight is now repeatable locally and in
  GitHub Actions through `.SYSTEMX/scripts/release-preflight.sh` and the
  macOS `CSA-iLEM native preflight` workflow
- CODEX transfer progress/status callbacks use explicit Swift 6 main-actor
  boundaries and pass the hosted macOS Swift 6 compiler gate locally
- isolated install/update/uninstall and GUI bundle lifecycle smoke now passes
  under temporary roots without touching the installed app or user profile
- blocked Stage 2 recovery safety smoke now preserves partial-metadata source
  trees and writes only an isolated preflight report with no apply mutation
- local GitHub identity-scope smoke now exercises two owner/login bindings and
  a mismatched token response without contacting GitHub or changing gh auth
- post-promotion transfer rollback now removes a newly promoted destination and
  restores a parked source if recovery capture, Git re-arm, or final proof
  fails; a regression fixture covers the parked-source/symlink case
- local export/workspace transactions now have injected later-failure coverage
  proving all promoted outputs roll back while every source remains available
- snapshot restore now backs up the affected workspace roots before merge and
  restores those roots on a later failure; a regression fixture covers partial
  Code/Import restore rollback
- external workspace relocation now has injected cross-root failure coverage;
  staged Code/Import/Runtime promotions restore prior destinations and retain
  every source root
- direct cleanup CLI flags for repo-scoped GitHub cleanup actions
- install, uninstall, and remote install/update scripts for macOS and Windows 11
- packaged `.app` build flow with bundled docs, assets, icon, and CLI resources
- compatibility wrappers for earlier `CSA-iLEM` naming

## Is Done

These items are currently tracked as working in the repo at the `0.8.0` baseline:

- local install from repo via `install.sh`
- remote install bootstrap via `install-remote.sh`
- Windows installer and remote installer script generation from `install.ps1` and `install-remote.ps1`
- uninstall safety for versioned installs without blindly removing newer command links
- custom `--bin-dir` install path updates in shell profile output
- GUI build from source and from an installed copy
- versioned command wrappers:
  - `csa-iem`
  - `csa-iem-gui`
  - `csa-iem-build-gui`
  - `openproj`
- migration of older workspace settings into explicit `CodeRoot`, `ImportRoot`, and `RuntimeRoot` state
- safer split-root move staging compared to earlier partial-move behavior
- export preview destination consistency
- clearer partial-failure reporting in the GitHub admin panels for secrets, variables, branch protection, and rulesets
- canonical macOS app replacement that removes stale app bundles and refreshes the single toolbar launcher
- selected-root project discovery without a broad Codex-history scan
- separate CODEX registry status for the selected active workspace, other linked local projects, unlinked disk discoveries, and unavailable registry reads
- read-only per-project branch, local-change, and local `origin/main` ahead/behind/diverged status with a bounded parallel Git-check pool and no network fetch
- persistent source/destination file tables, targeted rsync manifests, optional deep checksum audit, and mandatory full checksum verification before a source is retired
- Git-identity destination reuse for renamed CODEX project folders, with fail-closed ambiguity checks and automatic exclusion of clearly stale transfer/work folders from Auto All
- checksum verification that tolerates directory-only timestamp normalization on external filesystems without relaxing regular-file, symlink, missing-path, or type-conflict checks
- whole-second metadata matching aligned with macOS rsync so fractional timestamp truncation does not schedule checksum-identical files for repeat copies
- one shared generated-content filter for CODEX preflight and rsync, excluding rebuildable dependency, build, coverage, and cache trees unless the operator explicitly includes them
- checksum verification that preserves and validates symbolic-link targets during both staged and final project checks
- portable transfer handling that excludes live sockets, pipes, and device nodes from both the virtual index and rsync while retaining regular files, directories, and symlinks
- an external-volume preflight write probe that avoids Foundation's protected temporary-file path and returns control to the native UI reliably
- verified zero-delta CODEX plan reuse that validates the current source-to-destination state with native rsync before skipping Swift tree re-indexing and transfer work
- bounded parallel iCloud-placeholder preparation for planned files, with progress, timeout cleanup, and transient rsync retry handling
- local persistence for CODEX output path, transfer mode, and transfer safety switches without storing project content or GitHub credentials
- generated `Transfer_Note.MD` and `Prompt_Inject.MD` files at verified project destinations
- GitHub repository-ID matching, active-project exclusion, dirty/staged/diverged/archived/identity-conflict blocks, APFS clone staging, atomic promotion, additive healing, optional Runtime mirrors, and Stage 2 transaction reports
- matching Stage 2 shell, PowerShell, native macOS portal, macOS toolbar, and Windows tray entry points
- matching Stage 3 Bash/PowerShell engines, reports, audit receipts, direct CLI commands, interactive menus, native lifecycle panel, macOS toolbar controls, and Windows tray controls
- optional Stage 1/Stage 2 ZIPs, two-pass permanent source deletion, exact current-run receipt scope, Stage 1-to-Stage 2 receipt-chain resolution, and receipt-linked current/all temp cleanup
- repository-consolidation retirement authorization that keeps retained/protected sources out of deletion scope even when their content is fully represented
- transaction-bound runner drain/restore evidence and a separate confirmation token for deleting only completed recovery payloads from external temporary storage

## Broken

These are the known production gaps or weak spots still open:

- some advanced GUI actions still rely on Terminal fallback helpers instead of staying fully native end to end
- the native desktop GUI is still macOS-only; Windows currently ships as a PowerShell-first admin-shell experience
- the public remote install path still relies on a GitHub source archive and does not yet provide signed releases or a checksum retrieved from an independent trust source; the local manifest contract now has deterministic tamper-rejection coverage
- destructive workspace/file flows are safer than before, but still need broader rollback and recovery coverage under interrupted or cross-device failures; the currently exercised post-promotion, export, snapshot-restore, and cross-root relocation boundaries are covered
- GitHub admin features have local multi-account binding and mismatch fixtures,
  and the opt-in live read-only smoke now verifies two live owner/account
  bindings plus repository identity, branch, content, organization, and rate
  limit reads; intentionally limited token scope behavior remains untested
- there is still no deep automated regression suite for install, uninstall, GUI actions, and GitHub-side operations

## Almost Done

These areas are close, but not fully finished to the standard the app is aiming for:

- GUI-first product direction is established, but a few legacy CLI concepts and compatibility entry points still exist around the edges
- Windows now has core operational parity for shell usage, but not a native desktop GUI layer yet
- The CODEX ~ GPT Add-on master plan now defines deterministic five-second
  source decisions, false-positive protection, recoverable versus fatal
  continuation, explicit YOLO limits, Archive_Data routing, native tool
  bridges, and the local-only/server-mode boundary
- Smart Logic now computes a deterministic review-only lead rank within each
  verified identity group and labels the strongest candidate in the native
  decision panel; the operator still has to confirm the canonical source
- synchronized, clean, unlinked copies inside a multi-source verified group
  are now classified as `shadowCopy` review rather than generic merge
  candidates, so editor/tool shadow folders participate in the group blocker
  explanation
- The native decision panel now also explains when a group-level apply is
  blocked by shadow, broken-metadata, unknown-owner, same-name, or fatal
  identity evidence instead of showing lower-risk rows as independently safe.
- the public 3-root workspace model is now the primary path, but broader end-to-end smoke coverage is still needed before calling the migration layer fully hardened
- `GitHub Account` is now a real admin page, but editing flows are still lighter than the read/inspect surfaces
- `CODEX ~ GPT PORTAL` and `Local Files` now have safer previews, moves, exports, snapshots, and recovery flows, but need more polished cross-platform validation
- `Projects` has strong browsing and local operations, including a bounded native project tree disclosure for Code and Runtime roots; deeper native import and one-by-one management flows remain
- `Jobs` exists, but not every long-running background action is routed through it yet
- `Settings` is present, but onboarding and preference explanations can still be cleaner for public users

## Needs Done

These are the next production-hardening tasks with the best return:

- replace more Terminal fallback flows with fully native GUI actions
- add deeper Windows smoke coverage for runner install/service behavior and Docker/devcontainer lifecycle on real Windows 11 hardware
- add signed release artifacts or an independently distributed checksum to the public installer/update path
- extend rollback/recovery coverage to injected failures across every move,
  export, restore, and cross-device operation boundary; the native snapshot
  restore and cross-root relocation boundaries are now covered
- keep the release manifest smoke in the hosted gate and add a separately
  published trust anchor before calling public distribution signed
- add an end-to-end production smoke suite for:
  - install
  - remote install
  - uninstall
  - GUI build
  - local file move/export/restore
  - runner lifecycle
  - devcontainer lifecycle
  - GitHub cleanup dry-run
- add clearer permission/scope diagnostics everywhere GitHub API data can be partially unavailable
- run `.SYSTEMX/scripts/github-live-readonly-smoke.sh` with an intentionally
  limited token and record the expected read/write boundary without mutating
  any test repository
- extend changed-only resume coverage with timing and mutation fixtures across
  large multi-source projects; durable catalog-backed cache reuse is now in the
  runtime path but still needs broader performance evidence
- the native index regression suite now exercises a 250-file corpus twice and
  proves generated dependency/build trees are skipped and the repeated result
  is deterministic; large real-world timing and external-volume evidence is
  still open
- extend deterministic identity grouping from lead ranking to a grouped
  apply-block explanation when one candidate remains unresolved; current
  collision fixtures correctly fail closed but still need the group-level UI
  explanation wired through every Stage 2 surface
- reduce advanced/legacy wrapper visibility in the public-facing UX
- extend the native project tree from bounded top-level inspection to indexed
  file-level evidence only when a user expands a path; avoid full-directory
  rescans during normal project browsing
- expand first-run onboarding so a new user can understand `Code`, `Import`, and `Runtime` without knowing the older internal models

## Future Things

These are solid next-wave features after the remaining production-hardening work:

- fully native repo import/migration wizard in the GUI
- fully native one-project-at-a-time cost-control review in the GUI
- workflow dispatch and richer workflow editing from the app
- secrets/variables creation and update flows from the app
- branch protection and ruleset editing for common policies
- multi-account and multi-context management with saved GitHub contexts
- richer disk-usage analysis and storage charts
- better task-template authoring and reusable automation per project
- notification center for long-running jobs and completion states
- packaging/signing/notarization for broader public distribution

## Current Direction

Recommended direction for `CSA-iEM`:

- GUI first
- CLI as execution backend and fallback
- preview before destructive actions
- stronger recovery/rollback on file operations
- Smart Logic uses indexed facts to reduce wasted verification while receipts
  and final proofs remain authoritative
- one source group maps to one final destination; unknown or extra material is
  routed to .SYSTEMX/Archive_Data
- stronger release/install trust model for public distribution
