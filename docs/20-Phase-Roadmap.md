# CSA-iEM 20-Phase Product Roadmap

`CSA-iEM` is already strong as a macOS-first GitHub/local-ops tool with a growing Windows shell path. This roadmap is the next major step: turn it into a deeply capable cross-platform operator console where the GUI is the primary product and shell routes exist mainly as backend execution and recovery tools.

This plan is intentionally phased. Each phase should leave the product in a better, releasable state instead of stacking unfinished work for later.

## Execution Overlay

The roadmap remains the phase source of truth. CSA-iEM also carries a
machine-readable forward execution overlay at
[.SYSTEMX/AI/10000-TASK-PLAN.md](../.SYSTEMX/AI/10000-TASK-PLAN.md) with five
groups, ten waves, and ten todo tasks per phase. The overlay provides Agent 0
coordination, IDE Copilot handoffs, evidence gates, and a local cursor; it does
not claim that the underlying product work is already complete.

## Product Direction

Core goals:
- GUI first on both macOS and Windows
- shared backend contracts across platforms
- preview-first and rollback-aware destructive operations
- research, diagnostics, and GitHub admin tooling visible in-app
- terminal routes hidden behind native job execution wherever possible

## Codex ~ GPT Add-on Master Plan

This is the product overlay for the complex CODEX ~ GPT PORTAL. It applies to
the native CSA-iLEM application in this repository only. CSA-iLEM is not a
website application: the native client is SwiftUI/AppKit, the package identity
is Package.swift, and package.json/Firebase/Vite markers are only optional
evidence used when the app inspects an imported project from another checkout.

### Operator experience

The primary workflow is intentionally visual and narrow:

1. **Import sources on the left** — choose one bounded source set, or select
   several folders that the user already knows are representations of one
   project.
2. **Smart Logic in the middle** — build a cheap evidence index, group
   candidates by identity, show confidence and ambiguity, and route uncertain
   material to review instead of silently merging it.
3. **One final destination on the right** — choose one canonical destination
   for the selected project identity. Extra files never disappear into the
   repository; they go to the explicit .SYSTEMX/Archive_Data review lane.
4. **A lower status rail** — show the current stage, source count, destination
   count, index reuse, recoverable warnings, fatal blockers, receipt state, and
   the exact next action.

Every page should keep this same dashboard grammar: a persistent top bar and
hamburger menu, a left-to-right source/decision/output flow where applicable,
stage cards that can be expanded into detail, and a bottom operational status
rail. The Project Backups page composes these stages instead of creating a
second backup engine.

### Smart Logic and the five-second decision pass

Smart Logic is a deterministic local decision engine first, with optional AI
assistance only after facts have been collected. The first pass should inspect
metadata and bounded markers rather than opening an entire directory:

- normalized path, volume, file count, byte estimate, and recent-change stamp;
- Git remote URL, repository ID when available, branch, HEAD, local
  origin/main, dirty/staged state, and ancestry;
- owner/account hints, SYSTEMX identity, transfer receipts, IDE registry
  links, devcontainer/runner markers, and known workspace roots;
- active application/process evidence for Codex, Visual Studio Code/Copilot,
  Claude, LM Studio, and other known harness directories;
- file-versus-folder conflicts, broken metadata, duplicate destination
  identities, and cloud-provider paths such as iCloud Drive or OneDrive.

The output is a snapshot decision, not a guess:

- **canonical** — one identity and one destination are strongly supported;
- **merge candidate** — the source is a compatible representation of the same
  project and can be selected with other sources;
- **shadow copy** — a tool-created worktree or editor copy with a known parent;
- **same-name/unknown** — a folder name matches but identity evidence is weak;
- **broken metadata** — a partial wiki or damaged registry record that must not
  be promoted to a repository;
- **unrelated** — no sufficient project identity;
- **fatal** — the operation cannot continue safely, such as an active target,
  unresolved duplicate canonical destinations, or a protected checkout.

The five-second target is for the first decision pass per folder on a warm
index, not a promise that a full content checksum or archive will finish in
five seconds. The app must show whether it is using a fresh index, a verified
cache hit, a changed-folder recheck, or a full audit.

### Scan and verification profiles

The UI exposes explicit profiles rather than forcing an operator to abandon
the workflow when verification is slow:

- **Fast Index** — metadata-first planning with existing final verification
  before any cleanup-capable receipt;
- **Full Verification** — checksum-audit metadata matches during planning;
- **Full Verification, no ZIP** — the same verification without producing an
  interchange archive;
- **Full Verification + ZIP** — verified source/destination archive as an
  optional recovery artifact;
- **YOLO / skip deep preflight** — a clearly marked, non-destructive
  acceleration profile for Backup or Copy. It never authorizes Stage 2,
  Stage 3, source retirement, or a write without the existing final
  verification gate. A future truly verification-free mode must remain
  isolated behind an explicit operator policy and cannot silently weaken
  cleanup safety.

Warnings are recoverable by default. A failed source scan, one malformed
metadata record, one unavailable IDE registry, one missing optional CLI, or
one project conflict should produce a per-source result and allow unrelated
sources to finish. Fatal errors stop only the affected transaction when they
threaten identity, destination integrity, authorization, or deletion safety.
The Jobs surface records the distinction and offers resume/retry.

### Index, session, and recovery model

The current JSON transfer tables and receipt/checkpoint paths remain the
foundation. The next index layer should add a local SQLite catalog with
human-readable JSON/CSV export, not replace the existing evidence artifacts:

- one stable scan index per source root and project identity;
- content and metadata fingerprints with device/inode/link safeguards where
  available;
- changed-only rechecks and invalidation when a root, remote, branch, or
  policy changes;
- resumable session checkpoints for each source, destination, and stage;
- source/destination/decision tables that are visible in the UI;
- recovery that resumes from the last finalized transaction checkpoint without
  rescanning unchanged sources;
- no credentials, prompt content, or raw conversation data in the index.

### GitHub and editor interoperability

CSA-iLEM should metamorphose existing tools into native bridges rather than
reimplementing them:

- use the installed gh CLI for authentication status, repository identity,
  repository inventory, Actions, issues, and remote checks while keeping
  tokens outside CSA-iLEM;
- use git/rsync/APFS clone operations already present for local transfer,
  receipts, and verification;
- use code and open -a "Visual Studio Code" for VS Code/Copilot handoff,
  and the Dev Containers CLI for container lifecycle;
- read Codex, VS Code/Copilot, Claude, LM Studio, and similar standard
  directories as bounded, read-only evidence sources; never treat an editor's
  shadow folder as a second canonical repository without identity proof;
- offer a tree view in the native Project Library that mirrors the useful
  affordance of the VS Code extension while keeping CSA-iLEM's receipts,
  recovery, account contexts, and destination policy visible.

### Workspace and account policy

The default local workspace must avoid iCloud Drive and OneDrive unless the
operator explicitly chooses and passes a provider-health check. The app should
prefer a local ~/CSA-iEM (or an explicitly selected external volume) with
Code, Import, Runtime, and .SYSTEMX/Archive_Data lanes. Multiple GitHub
accounts and business/personal profiles are normal: save host/account/owner
contexts, ask how projects outside the active account should be treated, and
use unknown/review rather than assigning them to WayneTechLab by assumption.

### Backup page and canonical-state rule

The dedicated Project Backups page composes Import, Index, Decision, Transfer,
Stage 2, Stage 3, Local Files, Snapshots, Jobs, and Recovery. A raw directory
snapshot is the canonical preservation medium because it retains the selected
tree without repackaging it. ZIP is an optional verified interchange artifact.
On macOS, APFS clone or sparse image/disk-image support can be evaluated as a
later exact-volume option; ISO is not a universal substitute for a live
directory tree and must not be presented as a no-change canonical state.

### Server mode boundary

Local-only operation is the current release boundary. A later phase may add a
local host/server mode so another CSA-iLEM installation on macOS or Windows can
discover approved roots and exchange receipts over a secured local channel.
Cloud buckets are a future raw-storage adapter, not a reason to move the
current index or credentials off the user's machine.

### Phase 12 and Phase 13 relationship

The phrase “stage 12 and 3” is split deliberately:

- **Phase 12 — Issues, Bugs, and Incident Hub** turns recoverable and fatal
  results into actionable incident records, issue drafts, and operator
  explanations.
- **Phase 13 — Deep Research Workspace** supplies the identity, dependency,
  documentation, active-tool, and change evidence that Smart Logic uses to
  avoid false-positive repositories.
- **Current lifecycle Stage 1/2/3** remains the transfer → canonical merge →
  receipt-bound cleanup pipeline. Phase 12/13 improve how those stages reason
  and explain; they do not create a second pipeline.

## Phase 1: Unified Backend Contract

Goal:
- define one stable execution contract shared by macOS Bash, Windows PowerShell, and future GUI-native clients

Deliverables:
- operation schema for import, cleanup, patch, browse, runner, devcontainer, and file actions
- normalized job result shape with status, logs, warnings, report path, and recovery hints
- shared argument naming across Bash and PowerShell backends

Current Phase 13.19 slice:
- assign each provenance row a bounded scan route: metadata triage, targeted
  verification, or no deep scan;
- route imported-only context away from expensive deep verification and route
  changed live evidence toward focused review;
- keep route guidance informational and operator-controlled, with no automatic
  scan scheduling, merge, transfer, cleanup, deletion, or remote write.

Current Phase 13.20 slice:
- summarize the visible route decisions before execution with metadata-triage,
  targeted-verification, and deep-scan-avoided counts;
- expose the fast-path savings without dispatching a scan or treating the
  summary as permission;
- preserve operator control and the existing merge, transfer, cleanup,
  deletion, and remote-write gates.

Current Phase 13.21 slice:
- compare the selected Fast Index, Full Verification, or YOLO profile with
  the route summary;
- recommend Full Verification when targeted routes remain, while leaving the
  selected profile and operator decision unchanged;
- keep the recommendation explanatory and subordinate to existing preflight,
  final-verification, cleanup, deletion, and remote-write gates.

Current Phase 13.22 slice:
- include the selected scan profile and profile-suitability assessment in
  exported comparison JSON evidence;
- show that context again when a read-only evidence bundle is inspected after
  restart or handoff;
- preserve the evidence-only boundary: imported profile context cannot change
  the live catalog, profile selection, or any operation gate.

Current Phase 13.23 slice:
- show the exported scan profile and profile-assessment state in retained local
  evidence-history entries;
- let operators triage old handoff evidence before opening the full bundle;
- keep history bounded, local, read-only, and unable to alter catalog state or
  authorize an operation.

Current Phase 13.24 slice:
- filter retained evidence history by Full Verification recommendation, profile
  match, or legacy or unknown profile context;
- keep filtering local, bounded, read-only, and limited to the visible history
  list;
- preserve the live catalog, retained bundles, profile selection, and all
  operation gates unchanged.

Current Phase 13.25 slice:
- label retained evidence as complete, partial, or legacy based on the presence
  of scan-profile metadata;
- expose the compatibility state before opening an imported bundle;
- keep compatibility assessment read-only and unable to alter catalog state or
  authorize an operation.

Current Phase 13.26 slice:
- derive one deterministic route plan from indexed decisions, source deltas, and
  explicit review dispositions;
- route unchanged safe candidates to metadata triage, changed or review-blocked
  sources to targeted verification, and excluded sources away from deep scans;
- show the plan and profile guidance before execution without dispatching work or
  changing any safety gate.

Current Phase 13.27 slice:
- persist one route receipt per indexed source in the existing SQLite catalog;
- update receipts to completed, failed, or interrupted when the selected
  operation reaches or stops before a source;
- restore route state after catalog restart and expose pending counts without
  relying on transient UI state or forcing a full source rescan.

Current Phase 13.28 slice:
- provide an explicit Resume Pending Routes action from the persisted receipt
  summary;
- select only planned, interrupted, and failed receipts that still match local
  indexed sources;
- reuse the existing non-lifecycle transfer path and restore the operator's
  previous selection after the run.

Current Phase 13.29 slice:
- show a read-only receipt audit preview before selective resume;
- list matching source path, route, state, attempt count, and last detail;
- share one deterministic pending-receipt predicate between the preview and the
  resume action so the UI cannot promise a different source set than execution.

Current Phase 13.30 slice:
- export the active session's route receipts as read-only JSON and CSV evidence;
- preserve deterministic source ordering, route state, attempt count, timestamp,
  and bounded detail in the exported bundle;
- keep the SQLite catalog authoritative and export no source files or credentials.

Current Phase 13.31 slice:
- inspect exported route-receipt JSON bundles without mutating the live catalog;
- retain a bounded local history with remove and clear controls;
- label imported receipts as read-only provenance and keep them separate from live
  pending-route selection and execution.

Exit criteria:
- every major operation has the same conceptual inputs and outputs on both operating systems

## Phase 2: Native Job Engine Everywhere

Goal:
- route all long-running work through a visible jobs center instead of ad hoc terminal launches

Deliverables:
- queued, running, completed, cancelled, failed job states
- retry and cancel support
- structured logs with filtering
- saved history for recent jobs

Exit criteria:
- import, cleanup, patch, backup, runner, and devcontainer operations all appear in a unified jobs surface

## Phase 3: GUI Terminal Console Layer

Goal:
- preserve shell power without forcing users to leave the GUI

Deliverables:
- embedded operation console for advanced output
- copyable command transcript
- safe “show backend command” toggle for power users
- per-job raw output and parsed output tabs

Exit criteria:
- terminal routes are optional diagnostics, not the normal workflow

## Phase 4: Native Import Center

Goal:
- make import the first-class entry point for repo migration and local setup

Deliverables:
- owner/org repo loader
- one-repo, batch, and full-auto GUI modes
- resume-from-index support
- import summaries with success/failure reasons

Exit criteria:
- the import page can fully replace the current menu-driven import flow for normal users

## Phase 5: Project Library 2.0

Goal:
- turn the project browser into the main operating surface

Deliverables:
- grouped views by owner, language, workspace type, devcontainer status, runner status
- advanced search and saved filters
- favorites, recents, pinned repos, and bulk selection
- richer project cards with health and risk summaries

Exit criteria:
- most daily project actions start from the project library, not command entrypoints

## Phase 6: Devcontainer Control Center

Goal:
- make local container work completely visible and manageable in-app

Deliverables:
- build, rebuild, up, stop, remove, inspect, and log actions
- container health indicators
- repo-to-container mapping
- config preview and warnings for risky patterns like docker-in-docker conflicts

Exit criteria:
- a user can manage local devcontainer lifecycle without dropping to Terminal

## Phase 7: Runner Fleet Manager

Goal:
- make self-hosted runner management feel like a real control plane

Deliverables:
- install, repair, relabel, remove, start, stop, restart
- service health and registration state
- linked repo view
- runner activity, last-seen status, and local path inspection

Exit criteria:
- runner operations are as approachable as project browsing

## Phase 8: Workflow Control Center

Goal:
- make workflow state and execution manageable from the GUI

Deliverables:
- workflow inventory
- enable, disable, dispatch, open YAML, and patch actions
- patch preview before write
- runner target analysis for each workflow

Exit criteria:
- workflow admin becomes a page-level GUI workflow instead of a backend side effect

## Phase 9: Workflow Runs Explorer

Goal:
- make runs and failures explorable like a real incident console

Deliverables:
- run list with filters
- status timeline
- per-run logs and metadata links
- rerun, cancel, delete, artifact browse, and cache visibility

Exit criteria:
- the app can answer “what ran, what failed, what cost money, and what should we do next?”

## Phase 10: Cleanup and Cost-Control Command Center

Goal:
- turn cost-control into a safe, understandable GUI system

Deliverables:
- preview-first cleanup planner
- cost/risk score per repo
- recommended no-spend mode
- hosted-runner detection, run-volume detection, cache/artifact pressure, Codespaces usage

Exit criteria:
- the product can clearly show why a repo is costing money and how to stop it safely

## Phase 11: GitHub Account and Org Admin Hub

Goal:
- elevate the current account page into a full operations/admin hub

Deliverables:
- multi-account and multi-org saved contexts
- repo inventory and health at org scale
- role/scope diagnostics
- context switcher without losing page state

Exit criteria:
- account switching and org inspection feel native and low-friction

## Phase 12: Issues, Bugs, and Incident Hub

Goal:
- turn recoverable and fatal automation results into understandable operator
  incidents without stopping unrelated work

Deliverables:
- GitHub issues viewer and creator
- issue templates and saved labels
- bug report drafting from local diagnostics
- failure-to-issue workflow from jobs, runs, and devcontainers
- per-source recovery/fatal classification with resume and retry actions
- incident cards that carry source, destination, stage, receipt, checkpoint,
  and next-action evidence without credentials or raw prompts
- optional issue draft handoff through the existing GitHub CLI bridge

Current Phase 12.1 slice:
- local incident ledger persisted under Application Support;
- automatic records for failed and cancelled background jobs;
- deterministic recoverable-warning versus fatal-blocker classification;
- redacted issue drafts with no credentials, prompt content, or raw
  conversation data;
- retry-originating-job, resolve, and local retention controls in the native
  Incidents dashboard page.

Current Phase 12.2 slice:
- structured incident evidence ties the originating job to a lifecycle stage,
  source, destination, receipt hint, checkpoint hint, and next action;
- persisted incidents remain backward-compatible with Phase 12.1 records that
  do not yet contain structured evidence;
- the dashboard and redacted issue draft expose the correlated evidence while
  keeping credentials and raw prompts outside the ledger.

Current Phase 12.3 slice:
- native read-only GitHub issue list through the existing `gh` bridge;
- local incident, bug, and recovery templates;
- reviewed local title/body/label composer with clipboard handoff;
- remote `gh issue create` available only after an explicit arm toggle,
  authenticated context, selected repository, and non-empty reviewed draft.

Current Phase 12.4 slice:
- deterministic incident clusters group repeated failures by operation,
  lifecycle stage, source, and destination;
- grouped open and fatal counts make repeated failures visible as one chain
  without hiding the individual job records;
- selecting a cluster focuses the first incident for retry, resolution, and
  redacted issue handoff.

Current Phase 12.5 slice:
- the native issue list retains provider labels while remaining backward-
  compatible with older issue-list payloads;
- a reviewed issue-action surface supports comments, close, reopen, add-label,
  and remove-label operations through the existing authenticated `gh` bridge;
- every remote mutation requires a selected issue, an authenticated host and
  repository, validated action payload, and a fresh explicit arm toggle;
- each mutation is recorded in the local Jobs Center and requires a deliberate
  issue-list reload to verify provider-side state.

Current Phase 12.6 slice:
- accepted issue mutations perform an automatic provider read-back through
  `gh issue view` for the exact issue and host/repository context;
- state changes, label additions/removals, and submitted comment presence are
  checked against the requested mutation before the job is marked successful;
- provider rejection, malformed read-back, or state mismatch becomes a local
  failed job/incident instead of a false success, while the issue list is
  refreshed for operator review.

Current Phase 12.7 slice:
- GitHub issue mutations use a bounded 60-second command window and classify
  timeout exit status separately from ordinary provider rejection;
- Jobs Center retry retains the exact failed issue mutation payload, restores
  it into the Issues page, and requires a fresh review and arm before replay;
- an allowlisted, never-delete provider smoke harness exercises the three
  retained temporary test repositories without entering the release preflight.

Current Phase 12.8 slice:
- failed GitHub issue mutations persist a local, credential-free retry record
  containing the host, repository, issue, action, reviewed payload, attempts,
  and redacted last error;
- saved retry records reload after an app restart and can be prepared from the
  Issues page without silently re-arming or replaying a remote write;
- provider failures are classified as authentication-required, permission-
  denied, not-found, timeout, or generic failure so operators can choose the
  correct recovery path without changing active credentials.

Current Phase 13.1 slice:
- the GitHub account dashboard provides a read-only Repository Intelligence
  Snapshot for one selected repository using bounded `gh repo view` metadata;
- the snapshot combines provider metadata with exact local project path
  matches, and reports conservative risk and relationship notes for archived,
  forked, incomplete, or duplicate-looking evidence;
- the snapshot never chooses a canonical source, authorizes a merge, or
  triggers a backup, cleanup, or remote write, and its result is recorded in
  the Jobs Center for retry and audit context.

Current Phase 13.2 slice:
- each exact local path match can produce a bounded codebase summary with file
  and source counts, byte size, top-level entries, source extensions, Git and
  README presence, and review warnings;
- common dependency manifests are identified without traversing generated or
  vendor trees, and bounded package, Python, Go, and Cargo dependency names
  are extracted for research context;
- traversal is capped by file count and depth, and the resulting evidence is
  read-only metadata that cannot select a canonical source or authorize a
  transfer, merge, backup, or cleanup.

Current Phase 13.3 slice:
- the selected-repository research snapshot reads a bounded list of GitHub
  releases through `gh release list`, retaining tag, title, publication date,
  draft/prerelease state, and provider URL provenance;
- local `CHANGELOG`, `HISTORY`, and `RELEASES` files are inspected only at
  bounded candidate paths, with heading, Unreleased-section, byte-cap, and
  truncation evidence retained separately from remote release data;
- release-history read failure is visible as a provider outcome while local
  codebase and changelog evidence remains available, and neither source is
  treated as an authorization or canonical-source decision.

Current Phase 13.4 slice:
- the selected-repository research snapshot reads a bounded GitHub Actions
  workflow inventory through `gh workflow list`, retaining workflow identity,
  path, and state without dispatching or editing workflows;
- exact local matches receive bounded `.github/workflows` evidence including
  action references, explicit permissions, `pull_request_target`, secret, and
  fork-context flags, with hidden workflow directories included intentionally;
- GitHub vulnerability-alert, secret-scanning, and code-scanning endpoints are
  queried only for availability and permission outcomes, never for secret
  values, alert dismissal, workflow writes, or administrative changes;
- remote failures remain categorized while local workflow evidence remains
  available, and all workflow/security evidence stays research context rather
  than a canonical-source or authorization decision.

Current Phase 13.5 slice:
- the research snapshot reads bounded local documentation from README,
  contribution, security, changelog, `.github`, `docs`, and `.SYSTEMX/Wiki`
  paths while preserving file identity, headings, byte caps, and warnings;
- a bounded GitHub contents inventory identifies remote documentation entries
  without downloading or rewriting repository content, and provider failures
  remain visible as availability status;
- the snapshot exposes direct native links for Actions, Issues, Pull Requests,
  Projects, Security, and Insights so operators can continue provider review
  without copying repository URLs or leaving the selected repository context;
- documentation and navigation remain research/read-only surfaces and do not
  choose a canonical source, merge files, or authorize a remote mutation.

Current Phase 13.6 slice:
- each discovered source carries a bounded warm-index snapshot of file count,
  byte estimate, latest modification, and truncation state while excluding
  generated and dependency trees;
- the Smart Logic decision record separates project-local tool markers from
  bounded host activity evidence for Codex, VS Code/Copilot, Claude, and LM
  Studio, so running tools are visible without being treated as identity or
  write-authority proof;
- the decision review panel shows source snapshot size and host activity next
  to each classification, and the persisted rule version advances with the
  evidence contract;
- deterministic grouping and canonical/merge/shadow/broken metadata decisions
  remain authoritative; host activity can explain review priority but cannot
  promote a source, merge a folder, or authorize deletion.

Current Phase 13.7 slice:
- Smart Logic now produces one deterministic summary per identity group with
  source count, review and fatal blocker counts, bounded-snapshot coverage,
  latest observed modification, and the ranked lead candidate;
- the native decision panel shows group readiness before individual source
  details, making the one-group/one-destination rule visible without hiding
  the underlying evidence;
- group summaries are derived from the existing persisted decision table and
  source snapshots, so this phase adds no second scanner and does not claim a
  cache hit when the underlying index state is unavailable;
- a group remains blocked when any review-only or fatal source remains, even
  when a lead candidate is obvious; selecting a lead remains an explicit
  operator action.

Current Phase 13.8 slice:
- review-classified sources can be explicitly deferred or excluded from the
  active group readiness view, with dispositions persisted locally and the
  source retained in the review ledger;
- deferred sources remain blockers, while explicitly excluded sources are
  removed from the active transfer selection and can be restored to review;
- a group can be re-evaluated from its existing indexed source rows without
  rescanning unrelated folders, and write arms reset after the re-evaluation;
- the dashboard shows the before/after group state and keeps exclusion,
  canonical selection, and remote mutation as separate operator decisions.

Current Phase 13.9 slice:
- review disposition changes and targeted group re-evaluations are retained in
  a bounded local audit ledger with an undo path for the last disposition;
- source fingerprints classify later scans as added, changed, unchanged, or
  removed without reading full project contents again;
- only affected identity groups are evaluated again, while unchanged decision
  rows remain retained for the current session and removed rows leave the
  active table;
- the delta path remains advisory and fail-closed: it does not authorize a
  merge, transfer, deletion, or remote write without downstream gates.

Current Phase 13.10 slice:
- persist source delta classifications and scan timing beside the existing
  SQLite session and decision rows;
- show the current-versus-previous session counts, evaluated and reused rows,
  affected groups, and discovery/decision durations in the dashboard;
- retain recent session history so a restart can recover the evidence instead
  of presenting an in-memory-only performance claim;
- keep timing and session comparison informational; canonical selection,
  verification, transfer, cleanup, and remote write gates remain unchanged.

Current Phase 13.12 slice:
- compare any two saved catalog sessions rather than only the latest session
  against its immediate predecessor;
- show source-level added, removed, changed, and unchanged rows with prior and
  current identity groups, classifications, confidence, and fingerprints;
- provide operator-readable explanations for group transitions,
  classification transitions, and changed indexed evidence;
- keep comparison strictly read-only and independent of canonical selection,
  transfer, cleanup, deletion, and remote mutation gates.

Current Phase 13.13 slice:
- export the selected current and baseline session comparison as local JSON
  and CSV evidence files under the catalog's `Exports` directory;
- retain session IDs, rule-version provenance, fingerprints, classifications,
  identity groups, and operator-readable transition explanations;
- make export available directly from the dashboard after a comparison is
  selected, without opening a terminal or copying project source files;
- keep the export read-only and independent of canonical selection, transfer,
  cleanup, deletion, and remote mutation gates.

Current Phase 13.14 slice:
- let operators choose a previously exported comparison JSON from the native
  file picker after restart or handoff;
- inspect session IDs, baseline identity, rule-version provenance, row count,
  and bounded transition rows in the dashboard;
- keep imported evidence transient and read-only, separate from the live
  SQLite catalog and current scan decisions;
- reject malformed bundles visibly and preserve the authority boundary around
  canonical selection, transfer, cleanup, deletion, and remote mutation.

Current Phase 13.15 slice:
- retain up to ten imported comparison bundles in the local app profile for
  restart-safe review and handoff continuity;
- allow an operator to reopen a retained entry, remove one entry, or clear
  the entire imported-evidence history;
- keep the history bounded and separate from the live SQLite catalog,
  decisions, source files, and all mutation gates;
- make clear/remove status explicit so operators know exactly what local
  evidence was removed and what was not affected.

Current Phase 13.16 slice:
- label the live SQLite catalog as authoritative and retained imported
  bundles as read-only evidence in the dashboard;
- report whether the imported current session matches the selected live
  session and show overlapping, live-only, and imported-only source counts;
- keep the authority comparison informational, with no promotion, catalog
  merge, canonical selection, transfer, cleanup, deletion, or remote write;
- make provenance visible at the point where operators compare evidence from
  different machines, sessions, or handoff files.

Current Phase 13.17 slice:
- provide a deterministic provenance filter for overlapping, live-only, and
  imported-only source paths;
- show each filtered source with its live and imported transition kinds so an
  operator can triage handoff drift without opening a deep scan;
- keep filtering read-only and session-scoped, with no catalog promotion,
  canonical selection, transfer, cleanup, deletion, or remote write.

Current Phase 13.18 slice:
- classify every provenance row as live review required, compare with live
  catalog, or imported context only;
- surface the actionability label beside the live/imported transition kinds so
  operators can route attention without opening a deep scan;
- keep actionability explanatory only: it cannot select a source, authorize a
  merge, transfer, cleanup, deletion, or remote mutation.

Exit criteria:
- a user can turn a failed operation into a well-formed issue or local recovery
  task without leaving the app, while unrelated sources continue when safe

## Phase 13: Deep Research Workspace

Goal:
- make the app useful for understanding a repo, org, source group, or shadow
  copy before operating it

Deliverables:
- repo intelligence summaries
- local codebase search and dependency summaries
- release-note and changelog aggregation
- security advisory and workflow surface review
- documentation snapshot panel
- GitHub tab shortcuts for Actions, Issues, Pull Requests, Projects, Security, and Insights
- copy-to-clipboard utilities for host, account, repo slug, repo URL, and selected repo sets
- five-second metadata-first source snapshots for identity grouping
- deterministic Smart Logic classifications for canonical, merge candidate,
  shadow copy, same-name/unknown, broken metadata, unrelated, and fatal
- bounded read-only discovery of Codex, VS Code/Copilot, Claude, LM Studio,
  devcontainer, runner, and workspace markers
- explicit ambiguity panels for partial wiki metadata and duplicate-looking
  folders instead of auto-promoting false positives

Exit criteria:
- the app can help answer “what is this source, how does it relate to the
  project chain, what changed, what is risky, and what should be backed up?”

## Phase 14: Secrets, Variables, Policies, and Rules

Goal:
- finish the GitHub admin layer for high-impact settings

Deliverables:
- repo/org secrets and variables inventory
- create/update flows where safe
- branch protection and ruleset editing for common cases
- drift detection across repos

Exit criteria:
- common GitHub governance tasks are handled in-app with clear warnings and permission checks

## Phase 15: Local Files, Backups, Snapshots, and Restore

Goal:
- make filesystem operations safe enough for daily use

Deliverables:
- guided move/copy/export wizards
- collision detection and size estimates
- snapshots, restore, and rollback history
- external-drive validation and health warnings
- dedicated Project Backups page composing Import, Index, Decision, Transfer,
  Stage 2, Stage 3, Jobs, and Recovery
- raw-directory preservation mode separate from optional ZIP interchange
  artifacts
- explicit .SYSTEMX/Archive_Data routing for extra, unknown, or quarantined
  material instead of repository pollution
- changed-only resume from local index/checkpoint state

Exit criteria:
- file movement and project preservation become reliable, previewable,
  recoverable, and understandable without repackaging the canonical tree

## Phase 16: Native Windows Desktop GUI

Goal:
- give Windows the same GUI-first experience as macOS

Deliverables:
- native Windows app shell
- project library, jobs, import, cleanup, local files, account pages
- shared backend contract with the PowerShell engine
- Windows-first service and Docker status panels

Exit criteria:
- Windows users no longer need to treat the app as a shell script product

## Phase 17: Packaging, Signing, Notarization, and Trusted Updates

Goal:
- make distribution trustworthy and production-grade

Deliverables:
- macOS signing and notarization
- Windows packaging and trusted install/update flow
- release checksum verification everywhere
- release manifest and version channel handling

Exit criteria:
- public installs are verifiable and professional on both operating systems

## Phase 18: Automated QA and Recovery Testing

Goal:
- turn reliability from manual checking into repeatable assurance

Deliverables:
- install/update/uninstall smoke suite
- GUI flow regression coverage
- backend contract tests
- move/export/restore rollback tests
- mocked GitHub permission and rate-limit scenarios
- false-positive identity fixtures for broken wiki metadata, same-name folders,
  multi-account ownership, editor shadow copies, and deleted/recovered sources
- scan-index reuse and changed-only recheck timing tests
- recoverable-warning versus fatal-blocker continuation tests

Exit criteria:
- releases have a real preflight bar before publish and the automation can
  finish safe work without masking a fatal identity or integrity failure

## Phase 19: Collaboration, Templates, and Automation

Goal:
- make the app useful for teams instead of just solo operators

Deliverables:
- shared task templates
- reusable project presets
- exportable workspace configs
- automation hooks and scheduled maintenance plans
- interoperable command palette for gh, git, VS Code/Copilot, Dev Containers,
  Codex, and future local harness adapters
- per-user and per-GitHub-context profiles with explicit unknown-owner policy

Exit criteria:
- teams can reuse and standardize workflows instead of rebuilding them manually

## Phase 20: Product Polish and “Best-in-Class” Pass

Goal:
- finish the experience quality, not just the feature list

Deliverables:
- onboarding that explains the product clearly for public users
- zero-confusion workspace language
- better visual hierarchy, accessibility, empty states, and error recovery
- consistent terminology across macOS, Windows, CLI, and docs
- public release readiness review
- dashboard grammar shared across pages: persistent top bar, left/right flow,
  stage cards, connecting evidence, and bottom status rail
- AI assistance constrained to redacted indexed facts, with deterministic
  decisions and visible evidence remaining authoritative
- local host/server mode design kept as a separately gated follow-on

Exit criteria:
- new users can install, understand, trust, and use the app without internal context

## Recommended Delivery Order

Recommended high-return sequence:
1. phases 1-5
2. phases 6-10
3. phases 11-15
4. phase 16
5. phases 17-20

## Platform Notes

Why these phases matter:
- Apple’s notarization workflow is required for polished macOS distribution: [Apple Developer Documentation](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- Microsoft’s current native desktop direction is WinUI via Windows App SDK: [Windows App SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/) and [WinUI](https://learn.microsoft.com/en-us/windows/apps/winui/)
- GitHub’s current Actions administration surface includes official APIs for workflows, runs, artifacts, caches, and related controls: [GitHub Docs](https://docs.github.com/en/rest/actions/cache)
- Dev Containers remain a first-class local development path through VS Code and the Dev Containers ecosystem: [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)

## Definition of Success

The “best app ever” version of `CSA-iEM` means:
- a user can install it cleanly on macOS or Windows
- a user can understand the workspace model immediately
- a user can import, inspect, patch, run, clean up, research, diagnose, and recover from the GUI
- the shell remains powerful, but mostly invisible unless explicitly needed
