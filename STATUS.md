# CSA-iEM Status

Version baseline: `0.8.0`
Updated: `2026-08-13`

This file is the current production-status snapshot for `CSA-iEM`.

Milestone status: the local macOS 0.8.0 CODEX ~ GPT Add-on milestone is
closed on `main`. The merged commit has complete local and hosted acceptance
evidence, recorded in `.SYSTEMX/AI/CODEX-GPT-ADDON-MASTER-PLAN.md`. The
remaining production gaps listed below are post-milestone work, not evidence
that the implemented local dashboard slice is incomplete.

Next phase: Phase 13.39 baseline-audit compatibility triage is in progress. The native app now
groups repeated failures by operation, lifecycle stage, source, and
destination, retains GitHub issue labels, and provides explicitly armed
comment, close, reopen, add-label, and remove-label actions through `gh`.
Accepted mutations now require automatic `gh issue view` read-back confirmation;
provider rejection, malformed responses, and state mismatches remain
operator-visible through the Jobs Center and Incident Hub. GitHub issue
commands are bounded to 60 seconds, retry restores the exact payload for
review and re-arming, and the remote smoke harness is restricted to retained
temporary repositories and never deletes test data. Failed mutation payloads
and redacted provider outcomes now persist locally across app restarts without
storing credentials. The GitHub account dashboard also provides a bounded,
read-only repository intelligence snapshot that combines provider metadata
with exact local path matches, conservative relationship notes, and review
flags without selecting a canonical source or authorizing a write.
Matched local paths now also receive bounded codebase and dependency summaries
with generated-tree exclusions, file/source/byte counts, manifest evidence, and
review warnings. Dependency extraction is limited to common local manifests and
does not install, resolve, or contact package providers.
Research snapshots now also retain bounded remote release entries and local
CHANGELOG/HISTORY/RELEASES heading evidence with explicit provenance,
Unreleased detection, and truncation warnings. Remote release read failures do
not suppress local evidence. Phase 13.4 adds a bounded GitHub Actions workflow
inventory, local workflow-surface flags for action references, permissions,
`pull_request_target`, secrets, and fork context, plus availability-only
security endpoint outcomes. The security surface is explicitly read-only: no
secret values, workflow writes, alert dismissal, or administrative changes are
performed.
Phase 13.5 adds bounded local documentation evidence from README, security,
contribution, release-note, `.github`, `docs`, and `.SYSTEMX/Wiki` paths, a
remote GitHub contents inventory limited to documentation candidates, and
native repository links for Actions, Issues, Pull Requests, Projects,
Security, and Insights. These remain read-only research surfaces.
Phase 13.6 adds bounded source snapshots to the Smart Logic decision table and
separates project-local tool markers from host activity evidence for Codex, VS
Code/Copilot, Claude, and LM Studio. The decision panel shows these facts for
operator context, but running tools never establish repository identity or
authorize a merge, write, or deletion.
Phase 13.7 adds one deterministic summary per identity group with source count,
review/fatal blockers, bounded snapshot coverage, latest observed change, and
ranked lead candidate. The decision panel shows this group-level readiness
before source details; an obvious lead does not unblock a group while another
source remains unresolved.
Phase 13.8 adds persisted defer/exclude dispositions for review sources,
restore-to-review controls, and targeted group re-evaluation from existing
indexed rows. Deferred sources continue to block readiness; explicit
exclusions leave source data untouched and remove the source from active
transfer selection until restored.
Phase 13.9 adds a local review audit ledger with reversible disposition
actions, plus a persisted source-fingerprint baseline. Subsequent scans report
added, changed, unchanged, and removed source rows and re-evaluate only the
affected identity groups while retaining unchanged decision evidence. A delta
scan never authorizes a transfer, merge, deletion, or remote write by itself.
Phase 13.10 persists session delta rows and discovery/decision timing in the
SQLite catalog, compares the current scan with the previous catalog session,
and exposes evaluated-versus-reused counts and recent session history in the
dashboard. Timing is evidence of the local scan path, not permission to bypass
verification or write gates.
Phase 13.12 adds arbitrary two-session source comparison. Operators can inspect
added, removed, changed, and unchanged sources, identity-group transitions,
classification transitions, and fingerprint changes with explanations. The
comparison is read-only evidence and does not alter either session or grant
write authority.
Phase 13.13 adds local JSON and CSV evidence exports for the selected current
and baseline sessions. Exports retain the compared session IDs, Smart Logic
rule-version provenance, source-level transition rows, fingerprints, and
operator-readable explanations. Export is read-only and does not copy source
files, alter catalog sessions, or authorize transfer, cleanup, deletion, or
remote mutation.
Phase 13.14 adds a native file-picker path to inspect an exported JSON bundle
after restart or handoff. The imported bundle is held only as read-only UI
evidence, with session IDs, rule versions, and transition rows visible. It is
not merged into SQLite, re-evaluated as a live scan, or used to authorize any
canonical selection, transfer, cleanup, deletion, or remote mutation.
Phase 13.15 adds a bounded local history of imported evidence bundles under
the app's Application Support directory. Operators can reopen a history entry,
remove one entry, or clear the full imported-evidence history. These controls
affect only the local evidence cache; the live SQLite catalog and project files
remain untouched.
Phase 13.16 adds an explicit authority boundary panel showing the live catalog
session as authoritative and retained imported bundles as read-only. It reports
current-session identity match, overlapping source paths, live-only sources,
and imported-only sources. The panel is informational and cannot promote an
imported bundle into the catalog or authorize any write operation.
Phase 13.17 adds a deterministic provenance filter for overlapping, live-only,
and imported-only source paths, with live and imported transition kinds shown
side by side. Filtering is read-only and cannot promote evidence, select a
canonical source, or authorize transfer, cleanup, deletion, or remote mutation.
Phase 13.18 adds actionability labels for those rows: live review required,
compare with live catalog, or imported context only. These labels route
operator attention but cannot select a source or authorize any operation.
Phase 13.19 adds bounded scan-route guidance for metadata triage, targeted
verification, and no deep scan. This is guidance only; the app does not
schedule a scan or authorize any mutation from the route label.
Phase 13.20 summarizes those routes before execution, including the number of
deep scans avoided. The summary is informational and does not dispatch work.
Phase 13.21 compares the selected Fast Index, Full Verification, or YOLO
profile with the route summary and recommends Full Verification when targeted
routes remain. The recommendation does not change the profile or override
existing safety gates.
Phase 13.22 persists the selected profile and profile assessment in comparison
JSON evidence and shows them again when imported read-only evidence is opened.
This preserves audit context without promoting imported evidence or authorizing
any operation.
Phase 13.23 adds the same profile and assessment labels to retained local
evidence-history entries, so an operator can triage a handoff before opening
the bundle. The history remains local, bounded, and read-only.
Phase 13.24 adds read-only filters for Full Verification recommended, profile
matched, and legacy or unknown entries. Filtering changes only the visible
history list and never changes retained evidence or live catalog state.

Phase 13.25 adds read-only compatibility labels for retained evidence imports:
complete when both profile fields are present, partial when exactly one is
present, and legacy when the export predates profile metadata. Partial and
legacy evidence remain non-authoritative and require operator review.

Phase 13.26 adds a deterministic route plan for the current indexed decisions.
Unchanged safe candidates stay on metadata triage, changed or review-blocked
sources receive targeted verification, and explicitly excluded sources avoid
deep scans. The plan is explanatory only: it does not dispatch work, change
the selected profile, or authorize a write or cleanup.

Phase 13.27 persists one route receipt per indexed source in the existing local
SQLite catalog. Receipts retain planned, skipped, completed, interrupted, and
failed state plus attempt count and detail. Transfer completion and safe-stop
paths update the receipts, allowing a restarted session to see pending work
without treating transient UI state as recovery evidence.

Phase 13.28 adds an explicit Resume Pending Routes action. It selects only
planned, interrupted, and failed receipts that still match indexed local
projects, reuses the existing transfer path without starting Full Auto, and
restores the prior operator selection when the run ends. Completed and skipped
routes remain outside the resumed operation.

Phase 13.29 adds a read-only audit preview immediately above Resume Pending
Routes. It lists matching source paths, route type, current receipt state,
attempt count, and bounded last detail, with failed routes ordered first. The
preview uses the same predicate as the action so what the operator sees is what
the resume operation will select.

Phase 13.36 adds portable baseline-audit JSON/CSV export from the local catalog.
The export preserves accepted/revoked events, session identifiers, source names,
timestamps, and bounded operator detail as read-only handoff evidence. It never
reactivates a baseline, changes the live catalog, or exports project files.

Phase 13.37 adds a native file-picker path to inspect exported baseline-audit
JSON bundles. Imported events remain visibly separate from live history and
cannot replace the current audit, reactivate a baseline, or authorize any
operation.

Phase 13.38 adds a bounded local history for imported baseline-audit bundles.
Entries can be inspected, removed, or cleared after restart; these actions only
change the local handoff cache and never change live audit history or authority.

Phase 13.39 adds schema-version and accepted/revoked-count metadata to imported
audit history entries. Compatible and unknown schemas are labeled before event
inspection; this metadata remains informational and cannot grant authority.
not discard available local research evidence.

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
- the native catalog suite now proves a later `stage2-reconcile=interrupted`
  checkpoint remains the visible resume state after a fresh catalog restart
- non-destructive native release preflight is now repeatable locally and in
  GitHub Actions through `.SYSTEMX/scripts/release-preflight.sh` and the
  macOS `CSA-iLEM native preflight` workflow
- CODEX transfer progress/status callbacks use explicit Swift 6 main-actor
  boundaries and pass the hosted macOS Swift 6 compiler gate locally
- remote-installer argument inspection plus isolated install/update/uninstall
  and GUI bundle lifecycle smoke now passes under temporary roots without
  touching the installed app or user profile
- the lifecycle smoke now checks the installed copy’s complete `SHA256SUMS`
  payload after install, directly guarding against incomplete runtime
  allowlists
- an opt-in `.SYSTEMX/scripts/remote-install-live-smoke.sh` now covers the
  networked GitHub archive path, temporary-root install, installed payload
  checksum, GUI build, and strict bundle verification without changing the
  shell profile or installed app
- `install-remote.sh` now exposes `--no-gui-app` and `--no-open` passthroughs,
  so automated or headless installs can explicitly avoid building or launching
  the native app
- the macOS installer now preserves all manifest-covered tracked payload roots
  (`.devcontainer`, `Tests`, `Prompt_Inject.MD`, and `Transfer_Note.MD`) so an
  installed remote copy can re-run GUI source checksum verification
- blocked Stage 2 recovery safety smoke now preserves partial-metadata source
  trees and writes only an isolated preflight report with no apply mutation
- installed-app smoke now confirms the native dashboard, Import page, CODEX ~
  GPT PORTAL, Project Backups page, persistent navigation, matrix strip,
  bottom status rail, Smart Logic status, and the left-source/right-output
  flow in `/Applications/CSA-iEM.app` version `0.8.0`
- the retained private `Flowers-Field-Guide`, `Space-Field-Guide`, and
  `Birds-Field-Guide` repositories were cloned into an isolated temporary
  nine-folder corpus containing a clean lead, dirty copy, and metadata-broken
  shadow for each identity; the installed app classified 9 candidates into 6
  identity groups with 3 review-only blockers in Fast Index, Full Verification,
  and YOLO modes without transfer, merge, upload, or deletion
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
- the current Mac host has a valid Apple Development signing identity; an
  isolated current-branch bundle was signed with the hardened runtime and
  passed strict verification, but public distribution signing, notarization,
  and an independent trust anchor remain open
- destructive workspace/file flows are safer than before, but still need broader rollback and recovery coverage under interrupted or cross-device failures; the currently exercised post-promotion, export, snapshot-restore, and cross-root relocation boundaries are covered
- GitHub admin features have local multi-account binding and mismatch fixtures,
  and the opt-in live read-only smoke now verifies two live owner/account
  bindings plus repository identity, branch, content, organization, and rate
  limit reads; an optional limited-token guard now fails closed when a supplied
  classic token advertises `delete_repo`, `gist`, `repo`, or `workflow`, while
  intentionally limited-token behavior remains untested until such a token is
  supplied; a local fake-`gh` contract test now proves the guard rejects
  `repo` and preserves the no-token path
- there is still no deep automated regression suite for install, uninstall, GUI actions, and GitHub-side operations

## Almost Done

These areas are close, but not fully finished to the standard the app is aiming for:

- GUI-first product direction is established, but a few legacy CLI concepts and compatibility entry points still exist around the edges
- Windows now has core operational parity for shell usage, but not a native desktop GUI layer yet
- the release preflight now runs a reproducible PowerShell parser and CLI
  inspection smoke when `pwsh` is available; it exercises all three Windows
  lifecycle `--version`/`--help` paths and the non-Windows mutation guard, but
  does not replace real Windows 11 runtime validation
- Windows lifecycle `--version` and `--help` commands now remain inspectable
  from macOS when `LOCALAPPDATA` is absent, while install/update/uninstall
  mutations still reject non-Windows hosts before acting
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
  is deterministic, and a 60-project / 720-file corpus verifies aggregate
  project coverage; large real-world timing and external-volume evidence is
  still open
- the SQLite catalog now exposes the latest persisted session checkpoint after
  reopen, and the native Smart Index status reports that checkpoint so an
  interrupted or resumed session is visible without rebuilding its index
- extend deterministic identity grouping from lead ranking to a grouped
  apply-block explanation when one candidate remains unresolved; the native
  decision-review card and Stage 2 apply surface now repeat the same
  fail-closed explanation, while legacy shell/report surfaces remain to be
  audited for equivalent wording
- native Stage 2 arming and apply execution now remain disabled while those
  grouped blockers are present; non-destructive preflight remains available
  to produce the evidence needed for resolution
- Smart Logic now carries bounded, read-only project-local tool context for
  linked Codex, VS Code/Copilot, Claude, and LM Studio markers into the
  decision evidence and review panel; tool context is explanatory only and
  never becomes an identity or write-authority signal
- the native review panel now offers an explicit local LM Studio/Ollama
  advisory action using redacted indexed metadata only; returned suggestions
  are filtered to current decision IDs, labeled non-authoritative, and cannot
  select a canonical source, authorize writes, or authorize deletion
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
