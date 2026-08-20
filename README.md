# CSA-iEM

`CSA-iEM` means `Container Setup & Action Import Engine Manager`.

Version: `0.8.0`
Canonical version source: [`VERSION`](./VERSION)
Provided by `Wayne Tech Lab LLC`  
Website: [www.WayneTechLab.com](https://www.WayneTechLab.com)  
Notice: `Use at your own risk.`

`CSA-iEM` is now a cross-platform toolset with:
- a production CLI backend
- a SwiftUI macOS GUI with native `Home`, `Import`, `Projects`, `CODEX ~ GPT PORTAL`, `Cleanup`, `Local Files`, `Workspace`, `Settings`, `GitHub Account`, and `GitHub Billing Reports` pages
- a macOS menu-bar mini control app plus a Windows notification-area tray companion for opening CSA-iEM/OpenProject tooling, controlling local GitHub Actions runners, and opening GitHub billing reports
- toolbar quick actions for opening the loaded repo or active container in VS Code, Codex, GitHub Copilot, Finder, CLI, or the project browser
- GitHub account and repo shortcuts for login, org/repo navigation, workflow and run loading, Codespaces, secrets, rulesets, repo settings, and direct tab links for Actions, Issues, Pull Requests, Projects, Security, and Insights
- GitHub billing reports for Actions minutes, paid minutes, storage, Packages, project-level usage signals, and direct account or organization billing links
- Privacy-First startup checks that verify local tools and GitHub CLI login state without importing or saving GitHub tokens, API keys, account identity, repository inventory, or organization data
- index-first CODEX transfers that reuse verified zero-delta plans, skip unchanged destination files, prepare planned iCloud placeholders in bounded parallel batches, and by default omit rebuildable dependencies, compiler output, coverage, and tool caches
- separate CODEX discovery, IDE-link, and Git-main status so the selected Codex workspace, other linked projects, unlinked disk projects, local changes, and local `origin/main` parity remain distinguishable
- Stage 2 GitHub-identity reconciliation from a `CODEX PROJECTS` preservation folder into canonical `Code/Repos`, with selected or Full Auto execution and fail-closed worktree/history checks
- receipt-linked Stage 3 cleanup and end-to-end Full Auto controls for selected or all eligible CODEX projects, with independent ZIP, source-retention, intermediate-retention, and verified-temp policies
- mounted external-drive controls for previewed full-workspace or selected-project backups and moves from the GUI, CLI, and macOS toolbar
- external-drive Default workspace controls that can save a stable `DRIVE/CSA-iEM` layout without moving data, or stage and relocate all `Code`, `Import`, and `Runtime` roots after explicit confirmation
- runner fleet controls for stopping all active runners or starting only one selected runner
- old-workspace migration tools for scanning Diamond, WTL, CSA-iLEM, and other legacy roots and importing projects into Default or Custom paths
- opt-in auto-confirm support for simple terminal yes/no gates; with auto-confirm off, or whenever a sudo/password/security prompt appears, the native job stops safely and directs the user to a visible Terminal instead of hanging on hidden input
- an opt-in Administrator Terminal mode that requests `sudo` authorization in a visible Terminal without capturing or storing passwords
- terminal installers for macOS
- a Windows 11 admin-shell PowerShell backend with matching install/update scripts
- compatibility wrappers for the earlier `CSA-iLEM` command names

It is built for:
- cloning and organizing GitHub repos locally
- preparing local devcontainers
- installing self-hosted GitHub Actions runners on macOS and Windows
- patching workflow `runs-on` targets to self-hosted labels
- previewing or running GitHub cleanup flows
- browsing imported local workspaces, containers, and runners
- stepping through one-project-at-a-time cost-control reviews

## Current Status

The current native dashboard release is `0.8.0`. Every page carries the
shared dashboard shell: persistent top navigation, a responsive sidebar or
compact menu, a fixed bottom status surface, visible page scrolling, and the
same unified module matrix strip. Home expands the matrix so operators can
see the version, tag, area, state, and last-updated date for UI pages, engines,
bridges, runtimes, receipts, recovery, and install/update surfaces.

The matrix contract is documented in
[`docs/wiki/CSA-iLEM-Dashboard-and-Module-Matrix.md`](./docs/wiki/CSA-iLEM-Dashboard-and-Module-Matrix.md).

For the current production-status snapshot, see:
- [`STATUS.md`](./STATUS.md)
- [`docs/20-Phase-Roadmap.md`](./docs/20-Phase-Roadmap.md)
- [`docs/Windows-Contributor-Setup.md`](./docs/Windows-Contributor-Setup.md)

The active Codex project checkout is the checkout containing this README.
Treat it as protected operator infrastructure: it is not a legacy project
source, a Stage 1 input, or a receipt-linked cleanup target. Machine-specific
absolute paths belong only in the local reviewed source map and receipts.

The native CSA-iEM roadmap also has a machine-readable Full SU execution overlay.

- [10000-TASK-PLAN.md](./.SYSTEMX/AI/10000-TASK-PLAN.md) — 20 phases,
  five groups per phase, ten waves per group, and ten todo tasks per wave
- [FULL-SU-AGI-OPERATING-CONTRACT.md](./.SYSTEMX/AI/FULL-SU-AGI-OPERATING-CONTRACT.md)
  — Agent 0, IDE Copilot, operator-approval, and forward-loop rules
- [copilot-instructions.md](./.github/copilot-instructions.md) — native
  CSA-iEM IDE Copilot scope and handoff rules
- [CODEX-GPT-ADDON-MASTER-PLAN.md](./.SYSTEMX/AI/CODEX-GPT-ADDON-MASTER-PLAN.md)
  — native dashboard UX, Smart Logic, index/recovery, interoperability, and
  Project Backups direction

The overlay is an execution index, not a claim that all product work is
complete. Validate its exact count and bindings with
Run: node .SYSTEMX/scripts/validate-10000-task-plan.mjs

This is a native macOS application repository, not a website checkout.
Web-oriented project markers in the scanner describe imported external
projects only and do not change the identity of this repository.

The fail-closed one-folder-per-repository lifecycle, GitHub identity rules,
local-source retirement gates, and final `_temp` cleanup contract are recorded
in [`.SYSTEMX/REPOSITORY-CONSOLIDATION.md`](./.SYSTEMX/REPOSITORY-CONSOLIDATION.md).

## Git Project

Primary GitHub project:
- [`WayneTechLab/CSA-iLEM`](https://github.com/WayneTechLab/CSA-iLEM)

Recommended local checkout update:

Windows 11 PowerShell or Windows Terminal:

```powershell
cd C:\Code\CSA-iEM
git switch main
git pull --ff-only origin main
```

macOS Terminal:

```bash
cd ~/CSA-iEM
git switch main
git pull --ff-only origin main
```

## Primary Commands

Preferred commands:
- [`csa-iem`](./csa-iem)
- [`csa-iem-update`](./csa-iem-update)
- [`csa-iem-gui`](./csa-iem-gui)
- [`csa-iem-build-gui`](./csa-iem-build-gui)
- [`csa-iem-open`](./csa-iem-open)
- [`csa-iem-tray.ps1`](./csa-iem-tray.ps1)
- [`openproj`](./openproj)

Core scripts:
- [`CSA-iEM.ps1`](./CSA-iEM.ps1)
- [`CSA-iLEM.sh`](./CSA-iLEM.sh)
- [`CSA-iLEM-Open.sh`](./CSA-iLEM-Open.sh)
- [`install.ps1`](./install.ps1)
- [`install-remote.ps1`](./install-remote.ps1)
- [`update-win.ps1`](./update-win.ps1)
- [`uninstall.ps1`](./uninstall.ps1)
- [`install-remote.sh`](./install-remote.sh)
- [`install.sh`](./install.sh)
- [`uninstall.sh`](./uninstall.sh)
- [`run-gui.sh`](./run-gui.sh)
- [`build-gui-app.sh`](./build-gui-app.sh)

Compatibility wrappers still ship for older installed commands:
- [`csa-ilem`](./csa-ilem)
- [`csa-ilem-update`](./csa-ilem-update)
- [`csa-ilem-open`](./csa-ilem-open)
- [`csa-ilem-gui`](./csa-ilem-gui)
- [`csa-ilem-build-gui`](./csa-ilem-build-gui)

## Install On macOS Terminal

Use Terminal with `zsh` or `bash`.

Install the latest published `main` build:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash
```

The same command also updates an existing install to the latest published `main` build. The installer replaces the target version, repoints `~/.local/share/csa-iem/current`, and removes older installed version folders automatically.
On macOS, update also builds and installs `CSA-iEM.app` into `/Applications` when writable, or `~/Applications` otherwise, starts it so the menu-bar toolbar appears, and registers a LaunchAgent so the toolbar returns at login.

Force a reinstall of the latest published `main` build:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --force
```

Install a specific release, branch, or commit:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --ref your-tag-or-branch
```

Install from a local checkout:

```bash
cd '/path/to/CSA-iEM'
chmod +x ./install.sh
./install.sh
```

The installer:
- scans for missing Mac dependencies and installs what it can before laying down the app files
- falls back to a user-local npm prefix for `@devcontainers/cli` when the system npm global prefix is not writable
- copies the production bundle into `~/.local/share/csa-iem/<version>`
- creates a stable `current` symlink under `~/.local/share/csa-iem/`
- removes older installed version folders after the new version is active
- builds and installs `CSA-iEM.app` into Applications when Swift is available
- starts the app after install so the menu-bar toolbar appears
- registers `~/Library/LaunchAgents/com.waynetechlab.csa-iem.toolbar.plist` so the toolbar opens again at login
- links commands into `~/.local/bin`
- installs `csa-iem-update` and `csa-ilem-update` so an installed Mac can update from the shipped remote installer without recloning first
- adds `~/.local/bin` to `~/.zprofile`
- adds macOS Terminal aliases so `CSA-IEM`, `CSA-iEM`, `CSA-ILEM`, and `CSA-iLEM` resolve to the installed lowercase commands after the shell profile is reloaded
- installs the Swift package sources, assets, and docs needed for the GUI and app-bundle builder
- ships the remote installer too, so an installed machine can update again later without recloning first
- bootstraps Homebrew, git, GitHub CLI, Node.js, Dev Containers CLI, Visual Studio Code, and Docker Desktop when they are missing
- still warns if Swift is not installed yet so the CLI can still be installed cleanly while the GUI path remains explicit

If you want a file-only install with no dependency bootstrap:

```bash
./install.sh --no-deps
```

After install:

```bash
source ~/.zprofile
csa-iem --version
csa-iem-update --help
CSA-IEM --version
```

Update an installed macOS copy from any Terminal window:

```bash
csa-iem-update
```

Update to a specific tag, branch, or commit:

```bash
csa-iem-update --ref your-tag-or-branch
```

From an installed copy, you can also inspect the shipped remote installer directly:

```bash
~/.local/share/csa-iem/current/install-remote.sh --help
```

Uninstall:

```bash
cd '/path/to/CSA-iEM'
./uninstall.sh
```

## Install On Windows 11 PowerShell

Use Windows Terminal or PowerShell. Run install commands from an Administrator shell when bootstrapping dependencies or services.

Remote install from the latest published `main` build:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1"
```

The same command also updates an existing install to the latest published `main` build. The installer replaces the target version, refreshes `%LOCALAPPDATA%\CSA-iEM\current.txt`, and removes older installed version folders automatically.

Force a reinstall of the latest published `main` build:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1 --force"
```

Install a specific release, branch, or commit:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1 --ref your-tag-or-branch"
```

Local repo install:

```powershell
cd C:\Code\CSA-iEM
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

If you are not already in the repo root, use the absolute path instead:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Code\CSA-iEM\install.ps1
```

The Windows installer:
- installs into `%LOCALAPPDATA%\CSA-iEM\<version>`
- creates `csa-iem.cmd`, `csa-iem-open.cmd`, `csa-iem-tray.cmd`, `csa-iem-update.cmd`, and `openproj.cmd`
- removes older installed version folders after the new version is active while keeping the shared `bin` directory
- adds the chosen bin directory to the user PATH
- bootstraps `git`, `gh`, `node`, `code`, `docker`, and `devcontainer` when possible
- is designed for Windows Terminal and PowerShell admin-shell usage
- works with `csa-iem`, `CSA-IEM`, or `CSA-iEM` because Windows command lookup is case-insensitive

After install, open a new PowerShell window and verify:

```powershell
csa-iem --version
csa-iem-update --help
openproj
csa-iem-tray
```

Installed Windows update command from any PowerShell window:

```powershell
csa-iem-update
```

Update to a specific tag or version:

```powershell
csa-iem-update --ref your-tag-or-branch
```

Important:
- `csa-iem-update` pulls from the published GitHub repo state.
- if your local checkout contains newer unpushed work, keep that build with the repo-local reinstall command instead of `csa-iem-update`

Windows local checkout refresh:

```powershell
cd C:\Code\CSA-iEM
git switch main
git pull --ff-only origin main
powershell -ExecutionPolicy Bypass -File .\install.ps1 --force
```

macOS local checkout refresh:

```bash
git switch main
git pull --ff-only origin main
./install.sh --force
```

## macOS GUI

Run the GUI directly from the repo:

```bash
./run-gui.sh
```

Run the installed GUI launcher:

```bash
csa-iem-gui
```

By default, `csa-iem-gui` now opens the native `.app` bundle. If the bundle does not exist yet, it builds it first and then opens it.

Build a standalone `.app` bundle:

```bash
./build-gui-app.sh
```

Or after install:

```bash
csa-iem-build-gui
```

That creates:

```text
dist/CSA-iEM.app
```

If you want the direct foreground Swift target run for debugging:

```bash
csa-iem-gui --source-run
```

The GUI is a SwiftUI macOS app that:
- uses simple task pages for `Home`, `Jobs`, `GitHub Account`, `GitHub Billing Reports`, `Projects`, `Local Files`, `Cleanup`, `Workspace`, `Settings`, and `About`
- keeps project browsing on-screen with native search, targeting, and direct VS Code / Finder open actions
- adds GitHub quick actions for host, account, repo, workflow, Codespaces, rules, issues, pull requests, projects, and security page jumps
- adds a native jobs center for background operations, status, retries, and logs
- adds a dedicated `GitHub Account` page for host, account, organization, and repository management while staying connected to the same `gh` session
- adds `GitHub Billing Reports` for API-backed Actions, storage, and Packages usage plus direct GitHub billing-summary navigation; currency totals remain GitHub's plan-adjusted source of truth
- adds native GitHub admin surfaces for repo health, workflows, workflow runs, Codespaces, secrets/variables inventory, and rulesets
- adds a dedicated `Local Files` page for moving workspace roots, moving selected projects, and exporting code/import/runtime/runner combinations to another folder or external drive
- adds a dedicated `CODEX ~ GPT PORTAL` that scans selected custom folders first, accepts a pasted path, Finder folder picker, or dropped folders, and discovers only project roots with Git, manifests, or generic on-disk project context before supporting single, multi, visible, and all-project targeting
- adds a GUI-only local development runner inside the CODEX portal that detects known `package.json` scripts such as `npm run dev:firebase`, runs the selected project in the background without opening Terminal or requiring ChatGPT/code assistance, captures output in Jobs, and refreshes the native port monitor
- reads Codex's local project registry to label the selected workspace `Active here`, other registered local projects `Codex linked`, and filesystem-only discoveries `Unlinked`; historical sessions and saved-root history do not count as current links
- reports each project's branch, tracked or untracked local changes, and ahead/behind/diverged state against the locally stored `origin/main` reference through bounded parallel checks without performing a fetch or changing the repository
- packages each selected Codex project through preflight, isolated `_temp` staging, checksum verification, optional `.git` and generated-dependency preservation, a tested ZIP backup, and `Transfer_Note.MD` plus `Prompt_Inject.MD` handoff files
- writes a Stage 1 receipt for every verified result so later cleanup can identify the exact original, current source, destination, tested ZIP, file indexes, and preservation policy without rescanning unrelated folders
- adds Stage 2 selected-project and Full Auto controls that match by GitHub repository ID, canonical owner/name, remote HEAD, and commit ancestry before promoting a project into `Code/Repos/<owner>/<repo>`
- blocks the active CSA-iEM checkout, dirty or staged canonical destinations, dirty source merges into an existing destination, archived repositories, identity conflicts, duplicate destinations, and divergent or unverified history
- stages new canonical projects under `Import/Stage2`, uses APFS clone-copy acceleration when available, verifies the complete staged tree and Git object database, then promotes atomically; existing clean projects receive only proven fast-forwards and additive missing-file healing
- can create a missing GitHub repository as private and empty, attach the local canonical project, and leave commit/push to the operator so local files are never uploaded implicitly
- can optionally prepare `Runtime/Repos` mirrors, retire completed Stage 1 sources into `_temp/Stage2-Completed`, and open the managed project in Codex, Visual Studio Code, GitHub Copilot, Finder, or its devcontainer
- can create and verify a Stage 2 ZIP, keep or retire the intermediate project, or permanently delete it only after canonical verification, same-volume quarantine, and a second verification
- adds Stage 3 selected/all receipt cleanup for original source folders, Stage 2 inputs, current transaction data, or all receipt-linked temporary indexes while preserving canonical repositories, archives, reports, receipts, failed transactions, unreferenced temp data, and active CSA-iEM
- adds a single Full Auto lifecycle control that runs Stage 1, requires one receipt per result, sends only those destinations to Stage 2, preflights Stage 3 from the exact receipts emitted by the current run, and stops at the first blocked stage
- can preserve Finder sidecars, re-arm a copied project to the detected `origin/main` by rebuilding only the Git index, and keep the original source untouched until final verification completes
- Preflight builds persistent source/destination file-index JSON and a virtual transfer plan under the output `_temp/Transfer-Indexes` folder before it changes a project; the on-screen table shows indexed entries, planned paths, and destination-only recovery data
- Auto All reuses a uniquely matching Git destination even when its folder was renamed, validates saved zero-delta indexes with native rsync, and turns unchanged projects into no-op cache hits; changed projects fall back to the complete index and targeted manifest path
- planned iCloud placeholders are downloaded in bounded parallel batches before rsync runs, with visible progress, a per-batch timeout, and narrow retries for transient local-provider failures; permission, conflict, and checksum failures still stop fail-closed
- the CODEX portal remembers its local output folder, transfer mode, and safety toggles across relaunches without storing project content, prompts, GitHub identity, tokens, or API keys
- fast preflight compares relative path, type, size, whole-second date, and symlink target to match macOS rsync's timestamp precision; the optional deep checksum audit detects rare same-size, same-second changes during planning, while the mandatory final audit preserves the prior destination variant, repairs any checksum-only miss, and repeats whole-tree verification before a cleanup-capable receipt can be written
- exact verification ignores ordinary directory timestamp normalization on external filesystems while continuing to fail on changed regular files, symlinks, missing paths, and file-versus-folder conflicts
- supports five explicit transfer modes: Backup Only, Copy to Output, Sync and Move, Sync and Sync, and Scan & Backup (Auto Merge)
- Sync and Move auto-resumes an existing output, verifies the reconciled result, and retires the source only after success; Sync and Sync keeps both folders and auto-heals one-sided changes without deleting either side
- Scan & Backup creates verified source and destination recovery archives, merges missing or changed files, retains destination-only data, and never removes the source
- two-way sync uses rsync metadata candidates, timestamps for the fast path, targeted manifests for one-sided updates, optional deep content audit, and `_temp` conflict quarantine with `Conflict_Report.MD` when both sides changed the same file
- detects mounted external drives, shows capacity, and lets you choose one for a timestamped full-workspace or selected-project backup/move bundle
- can make a mounted drive the saved Default workspace, prepare a full collision-aware relocation preview, move all current roots only after a separate confirmation, reveal the new workspace, or restore internal Default paths without moving files
- macOS upgrades build in disposable staging, keep one canonical `/Applications/CSA-iEM.app`, remove the legacy runnable bundle from the versioned install tree, stop the prior app before replacement, remove stale CSA-iEM/CSA-iLEM backup bundles, and refresh the single toolbar login launcher
- the app also holds a per-user process lock, so launching a stale copy activates the existing native app instead of creating a second menu-bar toolbar
- adds native backup presets, previews, snapshots, restore actions, storage insights, sync status, per-project task templates, and local port monitoring
- lets the native local project library feed cleanup and local-file targeting directly
- treats custom-drive setups as auto-detected workspace examples instead of exposing internal preset names
- keeps terminal launchers in an advanced area instead of making them the main navigation model
- runs the CLI engine in the background for cleanup and file operations while the user stays in the GUI
- displays bundled docs inside the app
- resolves the local CLI bundle automatically from either the repo or the packaged `.app`
- uses a temp SwiftPM scratch path by default so GUI builds stay fast even when the repo is on an external drive

Optional override:

```bash
export CSA_IEM_SCRATCH_PATH="/your/custom/swiftpm-scratch"
```

GUI build and source-run requirements:
- macOS
- Swift available in `PATH`
- Xcode Command Line Tools or Xcode installed

## Stage 2 Managed Workspace

Stage 1 preserves projects in a selected output folder such as `CODEX PROJECTS`. Stage 2 separately plans and applies reconciliation into a managed CSA-iEM workspace. Preflight leaves project content unchanged and writes its report under `Runtime/Reports/Stage2`.

```bash
csa-iem stage2 \
  --source "/Volumes/DRIVE/CODEX PROJECTS" \
  --managed-root "/Volumes/DRIVE/CSA-iEM" \
  --preflight --all

csa-iem stage2 \
  --source "/Volumes/DRIVE/CODEX PROJECTS" \
  --managed-root "/Volumes/DRIVE/CSA-iEM" \
  --apply --project "Project Folder" --yes

csa-iem stage2 \
  --source "/Volumes/DRIVE/CODEX PROJECTS" \
  --managed-root "/Volumes/DRIVE/CSA-iEM" \
  --full-auto --yes
```

`--create-missing-repos` creates private empty repositories by default and does not upload files. `--prepare-runtime` prepares a runtime mirror. `--archive-sources` creates and tests a Stage 2 ZIP. `--retire-sources` moves verified Stage 1 folders under `_temp`; `--delete-sources --confirm-delete VERIFIED-STAGE2` permanently removes only a twice-verified intermediate source.

## Stage 3 Verified Cleanup

Stage 3 does not discover deletion targets from arbitrary folder names. It reads verified Stage 1 and Stage 2 receipts, resolves a completed Stage 1-to-canonical chain, performs a fresh live verification, and then applies only planned receipt-linked rows.

```bash
csa-iem stage3 \
  --source "/Volumes/DRIVE/CODEX PROJECTS" \
  --managed-root "/Volumes/DRIVE/CSA-iEM" \
  --preflight --all --cleanup-all-verified-temp

csa-iem stage3 \
  --source "/Volumes/DRIVE/CODEX PROJECTS" \
  --managed-root "/Volumes/DRIVE/CSA-iEM" \
  --apply --all \
  --delete-stage1-originals --delete-stage2-inputs \
  --cleanup-all-verified-temp \
  --yes --confirm-delete VERIFIED-STAGE3
```

Use repeatable `--receipt PATH` for exact current-run scope or `--project NAME_OR_SLUG` with `--all` to filter verified receipts. Stage 3 preserves ZIPs, reports, receipts, canonical repositories, active CSA-iEM, failed transactions, and unreferenced temporary data.

## Verified Repository Consolidation Recovery

The bundled repository-consolidation helpers reconcile reviewed legacy folders and worktrees by verified GitHub identity into one canonical `Code/Repos/<owner>/<repository>` directory. A merge is complete only when every source entry has a verified canonical or conflict-preservation representation and the Git object database, remote identity, and destination receipts pass the final audit.

Interrupted apply runs may use `repo-consolidation-recovery.py --resume` only with the exact transaction ID. Resume accepts fully finalized destination-group checkpoints after revalidating source filesystem identity, the reviewed source-map digest, Git/GitHub identity, remote state, destination content, and representation receipts. Partial staging and any transaction that entered global retirement remain blocked.

For a large reviewed inventory, `--group-workers 2` enables bounded repository-level parallelism. Each worker owns one disjoint canonical repository, staging tree, rollback lane, report lane, receipt, and checkpoint; sources targeting the same repository remain serialized. Source, inode, destination, or shared-Git overlaps are assigned to a shared serial conflict component while unrelated repositories continue on both lanes; duplicate destination or report lanes fall back to one worker. Every worker is joined and every final receipt is rehashed before the single coordinator may begin global retirement. Values above two are rejected to avoid checksum and metadata contention on one external volume.

Recovery maintains a cross-transaction SHA-256 index under `Runtime/Indexes/RepoConsolidation`. A hit is accepted only for the same absolute path and complete device, inode, type, link-count, ownership, size, mode, flags, mtime, and ctime identity, with fresh `lstat` checks before and after lookup. Changed or uncertain files are read and hashed again. This supports the lifecycle loop—scan, identity review, plan, execute changed paths, verify, receipt-bound cleanup, then a final source/root sweep—without weakening the final canonical or deletion proof.

Exact-metadata cache entries also bind a freshly measured extended-attribute signature. Content, regular extended attributes, resource forks, ACLs, ownership, modes, flags, timestamps, and hardlink topology remain exact. macOS may asynchronously add or clear the system-managed `com.apple.provenance` attribute after a filesystem operation, so its digest is recorded in representation proofs but excluded from exact equality and deletion authorization.

Pass the active operator source with repeatable `--protected-checkout PATH` on recovery and cleanup commands. The launch checkout is also protected automatically when it is a Git worktree. This is a filesystem-level boundary: every rename, replacement, unlink, directory removal, and recursive deletion rejects the protected path plus every ancestor and descendant, even when discovery or a reviewed source map accidentally includes it.

After a successful recovery, `repo-consolidation-local-cleanup.py` performs separate receipt-bound phases for local retirement, local quarantine deletion, and external temporary-payload deletion. The external cleanup preflight and `DELETE-VERIFIED-EXTERNAL-TEMP-PAYLOADS` token select only exact paths from completed receipts and audits; canonical repositories, active workspaces, archives, reports, receipts, failed or incomplete transactions, and unrelated `_temp` data remain protected.

## Windows 11 Admin Shell

The Windows release is PowerShell-first today.

It supports:
- preflight scans
- workspace setup with public `Code`, `Import`, and `Runtime` roots
- repo import into `Code`, staging into `Import`, and runtime mirror creation in `Runtime`
- starter devcontainer generation
- quick local devcontainer startup checks
- repo-level self-hosted Windows runner install as a service
- workflow patching to self-hosted Windows labels
- GitHub cleanup actions for workflows, runs, artifacts, caches, and Codespaces
- local project browsing with VS Code and File Explorer
- Stage 2 GitHub-identity preflight, selected/Full Auto canonical reconciliation, optional verified ZIP/private-repository/Runtime preparation, and verified source-retention policies
- Stage 3 receipt preflight, source and transaction cleanup, PowerShell reports/audits, and Windows notification-area tray entry points

Windows documentation:
- [`docs/Windows-11-Notes.md`](./docs/Windows-11-Notes.md)
- [`docs/Windows-Contributor-Setup.md`](./docs/Windows-Contributor-Setup.md)

## Workspace Setup

The published app is generic by default.

Standard public workspace roots:
- code root: `~/CSA-iEM/Code`
- import root: `~/CSA-iEM/Import`
- runtime root: `~/CSA-iEM/Runtime`

Workspace modes:
- `Default` uses `~/CSA-iEM/Code`, `~/CSA-iEM/Import`, and `~/CSA-iEM/Runtime`
- `Custom` lets you enter explicit Code, Import, and Runtime roots
- `--auto-mode` uses Default mode and current saved roots without stopping for workspace prompts
- `--single-root PATH` still works as a compatibility alias and expands to `Code`, `Import`, and `Runtime` under that base path
- the GUI presents explicit `Code`, `Import`, and `Runtime` paths with `Auto Mode`, `Use Standard`, and `Save Workspace`

## Main CLI Modes

- `Codespace -> Local`
- `Repo -> Local`
- `Repo -> Local + local devcontainer + local Actions prep`
- `Cleanup only`

Supported batch behavior:
- one repo at a time
- all repos one by one
- `FULL AUTO`
- `FULL AUTO + CLEANUP PREVIEW`
- resume from a repo number in all-repos mode
- post-batch one-by-one review in VS Code
- one-by-one cost-control review with yes / ok / no / skip flow

## Native GUI Surfaces

The current GUI-first production surface includes:
- `Home` for summary, session state, and next actions
- `Jobs` for background operations, logs, and retries
- `GitHub Account` for host/account/org/repo inventory plus workflow/runs/Codespaces/admin views
- `Projects` for searchable imported projects, favorites, task templates, live devcontainers, and runner services
- `Local Files` for move/export previews, backup presets, and snapshots
- `Cleanup` for preview-first destructive flows
- `Workspace` for `Code`, `Import`, and `Runtime` setup plus detected migration suggestions
- `Settings` for onboarding defaults, tool paths, and saved contexts/views

## Direct Cleanup CLI

`CSA-iEM` also supports direct cleanup commands without entering the menu flow.

Examples:

```bash
csa-iem --repo OWNER/REPO --all --yes
```

```bash
csa-iem --repo OWNER/REPO --disable-workflows --delete-runs --delete-artifacts --delete-caches --delete-codespaces --dry-run --yes
```

```bash
csa-iem --host github.com --account USER --repo https://github.com/OWNER/REPO --delete-runs --run-filter "release" --yes
```

Default auto-mode example:

```bash
csa-iem --auto-mode --repo OWNER/REPO --dry-run --yes
```

Full-auto cleanup sweep:

```bash
csa-iem --profile default --repo OWNER/REPO --cleanup-full-auto
```

That mode walks every selected repo and requires a second literal `Y` before it starts deleting GitHub Actions resources.

## Browser And Open Flows

The browser can show:
- imported projects
- installed local devcontainers
- active local containers
- local Actions runners
- one-project-at-a-time cost-control review

Project status tags include:
- `split`
- `code`
- `runtime`
- `codespaces-ready`
- `local-starter`
- `active:<n>`
- `runner`

Useful opener commands:

```bash
csa-iem-open
```

```bash
openproj
```

Both jump straight into the full local project browser using the active saved workspace roots.
`openproj` now opens the imported-project list directly using the generic opener path by default.
Use `csa-iem --browse` when you want the full browser menu instead.
From the imported-project list or full browser you can:
- open a plain repo or runtime workspace in VS Code
- run `Cost-control review (one project at a time)`

The native GUI now also exposes:
- active workspace-path inspection for the current setup
- local inventory metrics for imported projects, multi-root workspaces, devcontainers, and runners
- a searchable local project library that opens runtime or code workspaces directly in VS Code
- a live local services panel for active devcontainers and runner services with native refresh, open, reveal, and stop actions
- native imported-project targeting for cleanup and cost-control flows
- on-screen task navigation instead of relying on the CLI browser as the main UI

The recommended no-spend safeguard plan can:
- disable GitHub Actions at the repo settings level
- disable workflows and delete workflow runs, artifacts, caches, and Codespaces
- stop the local runner service
- stop active local devcontainer containers
- patch workflow files to self-hosted labels for future use
- optionally commit and push the workflow patch after the hard stop is in place

Important:
- disabling GitHub Actions at the repo settings level is a hard stop; self-hosted runners also stop receiving jobs until you re-enable Actions for that repo

## Terminal Install Requirements

Remote install requires:
- macOS
- `bash`
- `curl`
- `tar`
- `mktemp`

GUI use or `.app` builds additionally require:
- Swift in `PATH`
- Xcode Command Line Tools or full Xcode

## Metadata And Legal Flags

The CLI can print bundled docs directly:

```bash
csa-iem --about
csa-iem --notice
csa-iem --terms
csa-iem --privacy
csa-iem --disclaimer
```

## Included Documents

- [`NOTICE.md`](./NOTICE.md)
- [`LICENSE.txt`](./LICENSE.txt)
- [`TERMS-OF-SERVICE.md`](./TERMS-OF-SERVICE.md)
- [`PRIVACY-NOTICE.md`](./PRIVACY-NOTICE.md)
- [`DISCLAIMER.md`](./DISCLAIMER.md)
- [`CHANGELOG.md`](./CHANGELOG.md)
- [`VERSION`](./VERSION)
- [GitHub Wiki](https://github.com/WayneTechLab/CSA-iLEM/wiki)

## Notes

- macOS GUI plus Windows 11 PowerShell and notification-area companion flows
- intended for technical users
- relies on GitHub CLI, Git, Docker, Homebrew, Node.js, npm, Visual Studio Code, and the macOS Swift toolchain for the GUI
- the app keeps legacy `CSA-iLEM` wrappers so older installed commands continue to work
- legal documents included here are practical production-distribution templates and should still be reviewed by counsel before broad public release
