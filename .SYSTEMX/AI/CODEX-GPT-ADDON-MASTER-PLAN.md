# CODEX ~ GPT Add-on Master Plan

Status: 0.8.0 local macOS milestone closure candidate; future phases remain separately tracked
Product: CSA-iLEM / CSA-iEM native macOS operator application
Repository scope: this CSA-iLEM checkout only
Current baseline: 0.8.0

## Closure scope

This document closes the current local macOS CODEX ~ GPT Add-on milestone:

- native dashboard shell and Project Backups composition;
- bounded source-to-destination Smart Logic flow;
- deterministic identity grouping and review-only ambiguity handling;
- local SQLite index, JSON/CSV exports, and session checkpoints;
- receipt-linked verification and fail-closed transfer/cleanup boundaries;
- module/version/tag matrix, single-app install lifecycle, and local release
  verification;
- native regression coverage for the decision and catalog contracts.

The following are deliberately post-milestone phases, not hidden blockers to
the 0.8.0 local close: a native Windows GUI, notarized public distribution,
multi-account GitHub administration, broad rollback chaos testing, and local
network/server mode. They remain in the roadmap and must not be represented as
implemented by this milestone.

## Repository boundary

CSA-iLEM is a native SwiftUI/AppKit macOS application with Bash, Python, and
PowerShell support. It is not a website repository. Package.swift is the
native package identity and there is no package.json application in this
checkout. package.json, Firebase, Vite, and similar markers are valid only as
bounded evidence when CSA-iLEM inspects an imported project from another
checkout.

The add-on must never confuse:

- the CSA-iLEM application with an imported project;
- a project source with its canonical destination;
- a GitHub wiki, partial metadata folder, or same-name directory with a
  verified repository;
- an editor or AI harness shadow copy with the lead repository;
- a ZIP interchange artifact with the original directory state;
- a recoverable warning with a fatal identity or integrity failure.

## Product outcome

The user opens one native app, selects a source set, selects one final
destination, and sees the entire operation as a dashboard:

    IMPORT SOURCES  ->  SMART LOGIC / EVIDENCE  ->  FINAL OUTPUT
       left                    middle                  right

The lower area exposes index state, project identity, branches, source count,
file count, size, dates, active tools, warnings, fatal blockers, receipts,
recovery checkpoints, archive routing, and the next action. The operator does
not need to remember a shell command or ask an AI coding assistant to perform
the normal flow.

## First implementation slice

The native app now contains the first coherent slice:

- persistent top navigation with a right-side hamburger menu;
- a Project Backups page that composes the existing Codex, local-file,
  snapshot, Stage 2, Stage 3, Jobs, and recovery surfaces;
- a left/right Codex control-plane dashboard with connecting Smart Logic;
- explicit Fast Index, Full Verification, and YOLO / Skip Deep Preflight
  profiles;
- saved-index visibility under the existing Transfer-Indexes evidence path;
- ready/review/output counters derived from the existing local project model;
- visible .SYSTEMX/Archive_Data policy path for extra or ambiguous material;
- conservative YOLO behavior: only non-destructive Backup or Copy is allowed;
  final write verification and all cleanup gates remain enforced.
- versioned Smart Logic decisions persisted to a local SQLite catalog with
  JSON/CSV exports and Stage 1 preflight checkpoints;
- strict remote-identity grouping with review-only classifications for weak,
  dirty, shadow, broken-metadata, and unknown-owner sources;
- an operational Project Backups Backup Medium selector: raw directory
  snapshots are copied and verified, APFS clones use macOS clone semantics,
  sparse images are mounted read-only for verification, and ZIP remains
  optional interchange.

This slice deliberately extends CleanupViewModel, CodexFileIndexSnapshot,
CodexTransferPlan, BackgroundJobEntry, receipts, and existing transfer
helpers. It does not create a second transfer engine.

## Dashboard information architecture

### Persistent shell

- top bar: CSA-iEM identity, current page, navigation menu, and menu visibility;
- left sidebar on wide windows, compact horizontal navigation on smaller
  windows;
- page header that explains the operator outcome in plain language;
- bottom status rail with health, GitHub context, selection, page, and current
  operation;
- Jobs page as the single place for progress, output, retry, cancel, and
  recovery status.

### Codex Project Control Plane

Left card: Import Sources

- saved source roots and drop-folder entry;
- one scan action that is read-only;
- discovered candidate count and selected source count;
- source folder identity hints and active-tool evidence.

Middle: Smart Logic

- scan profile;
- cache hit or changed-folder state;
- identity confidence and ambiguity count;
- decision explanation;
- recoverable versus fatal classification;
- no hidden merge decision.

Right card: Final Output

- one output root;
- one destination candidate per project identity;
- saved index/checkpoint state;
- Runtime/Reports and .SYSTEMX/Archive_Data lanes;
- open/reveal action.

### Project Backups page

The page is a composition, not a duplicate implementation:

1. Import and source selection
2. metadata-first index
3. identity and merge decision
4. copy/sync/backup transfer
5. Stage 1 verification and optional ZIP
6. Stage 2 canonical Code/Import/Runtime reconciliation
7. Stage 3 receipt-bound cleanup
8. local raw-directory export or snapshot
9. Jobs, reports, receipts, and recovery

Raw directory preservation is the canonical no-repackaging path. ZIP remains an
optional verified interchange artifact. APFS clone and sparse disk-image
options are later macOS media adapters; ISO is not treated as a universal
replacement for a live directory tree.

## Smart Logic decision engine

### Fast evidence pass

The first pass reads only bounded metadata and known markers:

- normalized path, volume, provider, file count, byte estimate, mtime range;
- Git remote, repository ID, owner/name, branch, HEAD, local origin/main,
  dirty/staged state, and ancestry;
- Package.swift, Git, SYSTEMX, devcontainer, runner, receipts, transfer
  notes, editor registries, and known harness directories;
- active process/app evidence for Codex, VS Code/Copilot, Claude, LM Studio,
  and other supported tools;
- cloud-provider indicators such as iCloud Drive and OneDrive;
- duplicate destinations, type conflicts, partial metadata, and broken links.

Warm-index target: a decision snapshot within approximately five seconds per
folder. This target excludes full checksums, cloud hydration, ZIP creation, and
large content reads.

### Decision classes

canonical
: Identity and destination are strongly supported.

merge_candidate
: A compatible source of the same project; eligible for explicit grouping.

shadow_copy
: A tool or editor worktree with a known parent or derived relationship.

same_name_unknown
: A matching name without enough identity evidence; review required.

broken_metadata
: A partial wiki, damaged registry row, or invalid marker; never promote.

unrelated
: No sufficient project identity; preserve outside the canonical repo.

recoverable_warning
: One source or optional tool failed; continue unrelated work and record it.

fatal
: Protected checkout, active destination, unresolved duplicate identity,
  authorization failure, or verification/deletion proof failure.

### AI boundary

The deterministic facts remain authoritative. An optional AI adapter may:

- summarize an indexed decision;
- explain why a source was classified or blocked;
- propose a review order;
- draft an issue or recovery note;
- suggest an existing tool/bridge to call.

It must not silently choose a canonical destination, invent a repository
identity, delete a source, upload data, or replace a receipt/checksum proof.
Only redacted indexed facts are eligible for an AI request; credentials,
prompts, raw conversation logs, and file content stay local by default.

The deterministic review UI provides the operator action **Use as canonical**
for a source inside a verified remote-identity group. Exactly one source may be
selected per group before merge or move preflight. This is an explicit identity
decision, not an authorization to write: the existing backup, destination,
checksum, Stage 2, and Stage 3 gates still apply. Changing the source selection
clears canonical choices so a stale decision cannot be reused for a different
scan.

## Verification and continuation policy

Default Fast Index performs metadata planning and uses the existing final
whole-tree verification before any cleanup-capable receipt. Full Verification
adds checksum comparison during planning. The operator can request:

- full verification with ZIP;
- full verification without ZIP;
- fast index with final verification;
- YOLO / skip deep preflight for a non-destructive Backup or Copy.

YOLO is not a hidden destructive bypass. In the current release it blocks
Sync and Move, bidirectional sync, Scan & Backup, Stage 2, Stage 3, source
retirement, and Full Auto. A future verification-free profile requires a
separate operator policy, a per-run acknowledgement, and an explicit
non-cleanup receipt.

Every task returns:

- status: queued, running, succeeded, warning, failed, cancelled, or blocked;
- stage, source, destination, project identity, and selected policy;
- structured log, report path, receipt path, and checkpoint;
- recoverable warnings and fatal blockers separately;
- exact next action and resume/retry availability.

One failed verification must not erase completed results for unrelated
projects. The current job model is the natural integration point for this
continuation policy.

## Index and session recovery

Keep the existing JSON transfer tables and receipts as portable evidence.
Extend them with a local SQLite catalog and JSON/CSV export when the catalog
work begins:

- scan key: normalized path + device/inode when available + project identity;
- source fingerprint, destination fingerprint, policy, and tool evidence;
- changed-only invalidation;
- stage checkpoint and finalized receipt link;
- cache reuse reason visible to the operator;
- session resume without a full rescan;
- no credentials or raw conversation data.

The source/destination tables live in the existing output _temp area during a
transaction. Extra, unknown, or quarantined material routes to
.SYSTEMX/Archive_Data instead of being dropped into a canonical repository.

## GitHub and editor bridges

Use the tools already present:

- gh CLI for authentication status, repository inventory, repository identity,
  Actions, issues, and remote data;
- git, rsync, APFS clone, and existing receipt/checkpoint helpers for local
  operations;
- code/open -a Visual Studio Code for VS Code/Copilot handoff;
- Dev Containers CLI for container lifecycle;
- Codex registry and bounded local markers for active-project evidence;
- future adapters for Claude and LM Studio standard directories, read-only.

The native Project Library should provide the tree-view affordance the user
gets in Visual Studio Code, but keep CSA-iLEM's identity, account, stage,
receipt, recovery, and destination rules in the same view.

## Roots, accounts, and ownership

Default storage must avoid iCloud Drive and OneDrive unless explicitly chosen
and health-checked. Prefer local ~/CSA-iEM or a selected external volume with:

- Code for canonical repositories;
- Import for staged inputs and incoming material;
- Runtime for reports, runners, jobs, and recovery;
- .SYSTEMX/Archive_Data for extra or ambiguous data.

Profiles store host, account, owner, and workspace context locally. Business
and personal GitHub accounts are normal. When a project is outside the active
account, ask whether to keep by project name, bind to another saved owner,
route to unknown/review, or exclude. Never silently assign it to WayneTechLab.

## Recovery research item

The Dark Labs Research / Dark Labs loss is a read-only recovery investigation:

1. search known CSA-iEM roots, external volumes, Downloads, Documents, and
   recoverable Trash entries for exact identity evidence;
2. inspect local Git remotes and GitHub CLI inventory without mutating GitHub;
3. compare repository ID, owner/name, remote, receipts, and file fingerprints;
4. if found, add it to the source inventory as a review candidate;
5. never restore, upload, delete, or recreate a repository automatically.

Current local evidence confirms that WayneTechLab/DarkLabResearch exists on
GitHub but is empty, while a recoverable local Git object store in Trash has
origin DARQ-Labs-LLC/DarkLabResearch.git, a main branch, multiple source
refs, release tags, and a complete commit history. The owner mismatch means it
is a review candidate, not an automatic WayneTechLab merge or upload target.
This is the exact false-positive/identity case Smart Logic must surface.

## Delivery order

1. dashboard shell and Project Backups composition;
2. deterministic five-second source fingerprint and decision table;
3. index catalog, changed-only recheck, session checkpoints, and resume;
4. fatal/recoverable continuation and incident cards;
5. GitHub/VS Code/Copilot/Dev Containers native bridges;
6. Archive_Data routing and raw-directory/APFS snapshot options;
7. multi-account/unknown-owner policy;
8. local host/server mode and remote raw-storage adapters as a later phase.

## Current acceptance gates

- repository identity remains CSA-iLEM native app only;
- no unrelated website source or external application data is introduced;
- one source group maps to one final destination per identity;
- false-positive same-name or partial-metadata folders remain review-only;
- index reuse and changed-only state are visible;
- recoverable warnings do not cancel unrelated safe work;
- fatal identity/integrity/deletion conditions remain fail-closed;
- all writes remain receipt-linked and recoverable;
- build, install, single-app replacement, and live UI verification pass.

## 0.8.0 closure evidence

The current branch has direct evidence for each local milestone gate:

- native release build: `swift build -c release`;
- native regression suite: `swift test` with five passing Smart Logic/catalog
  tests under `Tests/CSAiEMMacAppTests`;
- plan integrity: `node .SYSTEMX/scripts/validate-10000-task-plan.mjs`;
- repository/file integrity: `shasum -a 256 -c --strict SHA256SUMS` and
  `git diff --check`;
- repository boundary: HEAD contains no unrelated-project matches;
- installed runtime: `/Applications/CSA-iEM.app` reports 0.8.0, one native
  process, and a valid strict code signature;
- live UI: Home, Import, Projects, CODEX ~ GPT PORTAL, and Project Backups
  expose the matrix, status rail, source/output flow, Smart Logic, and index
  state;
- disposable safety fixtures: dirty and history-unavailable destinations were
  blocked with zero applied mutations and preserved receipts/fixtures.
- repeatable release gate: `.SYSTEMX/scripts/release-preflight.sh` runs the
  native checks locally and `.github/workflows/csa-ilem-preflight.yml` runs the
  same non-destructive gate on macOS for pushes and pull requests.
- isolated lifecycle smoke: `.SYSTEMX/scripts/install-lifecycle-smoke.sh`
  exercises CLI install, same-version replacement/update, wrapper identity,
  GUI bundle build and signature verification, uninstall, and sentinel
  preservation under temporary install/bin/app/dist roots.
- recovery safety smoke: `.SYSTEMX/scripts/recovery-safety-smoke.sh` runs a
  partial-metadata Stage 2 preflight in temporary roots and proves the report
  is retained while the source and `.git` tree remain unchanged and no
  canonical destination is created.
- GitHub identity-scope smoke: `.SYSTEMX/scripts/github-identity-scope-smoke.sh`
  validates two owner/login bindings, records independent binding digests, and
  blocks a mismatched token response without contacting GitHub or changing
  global `gh` authentication state.

When these checks are run on the merged `main` commit, the 0.8.0 local
milestone is closed. Any remaining items belong to the explicitly deferred
roadmap phases above.
