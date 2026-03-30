# CSA-iEM

`CSA-iEM` means `Container Setup & Action Import Engine Manager`.

Version: `0.3.1`
Provided by `Wayne Tech Lab LLC`  
Website: [www.WayneTechLab.com](https://www.WayneTechLab.com)  
Notice: `Use at your own risk.`

`CSA-iEM` is now a cross-platform toolset with:
- a production CLI backend
- a SwiftUI macOS GUI with native `Home`, `Import`, `Projects`, `Cleanup`, `Local Files`, `Workspace`, `Settings`, and `GitHub Account` pages
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

For the current production-status snapshot, see:
- [`STATUS.md`](./STATUS.md)
- [`docs/20-Phase-Roadmap.md`](./docs/20-Phase-Roadmap.md)

## Primary Commands

Preferred commands:
- [`csa-iem`](./csa-iem)
- [`csa-iem-gui`](./csa-iem-gui)
- [`csa-iem-build-gui`](./csa-iem-build-gui)
- [`csa-iem-open`](./csa-iem-open)
- [`openproj`](./openproj)

Core scripts:
- [`CSA-iEM.ps1`](./CSA-iEM.ps1)
- [`CSA-iLEM.sh`](./CSA-iLEM.sh)
- [`CSA-iLEM-Open.sh`](./CSA-iLEM-Open.sh)
- [`install.ps1`](./install.ps1)
- [`install-remote.ps1`](./install-remote.ps1)
- [`uninstall.ps1`](./uninstall.ps1)
- [`install-remote.sh`](./install-remote.sh)
- [`install.sh`](./install.sh)
- [`uninstall.sh`](./uninstall.sh)
- [`run-gui.sh`](./run-gui.sh)
- [`build-gui-app.sh`](./build-gui-app.sh)

Advanced compatibility wrappers still ship:
- [`csa-iem-public`](./csa-iem-public)
- [`csa-iem-wtl`](./csa-iem-wtl)
- [`csa-iem-diamond`](./csa-iem-diamond)
- [`CSA-iLEM-Public.sh`](./CSA-iLEM-Public.sh)
- [`CSA-iLEM-WTL.sh`](./CSA-iLEM-WTL.sh)
- [`CSA-iLEM-Diamond.sh`](./CSA-iLEM-Diamond.sh)
- [`csa-ilem`](./csa-ilem)
- [`csa-ilem-public`](./csa-ilem-public)
- [`csa-ilem-wtl`](./csa-ilem-wtl)
- [`csa-ilem-diamond`](./csa-ilem-diamond)
- [`csa-ilem-open`](./csa-ilem-open)
- [`csa-ilem-gui`](./csa-ilem-gui)
- [`csa-ilem-build-gui`](./csa-ilem-build-gui)

## Install On Any Supported Mac

Stable public install from any supported Mac terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/0.3.1/install-remote.sh | bash -s -- --ref 0.3.1
```

Install the latest `main` build:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash
```

Update an existing install to the latest `main` build:

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
- copies the production bundle into `~/.local/share/csa-iem/0.3.1`
- creates a stable `current` symlink under `~/.local/share/csa-iem/`
- links commands into `~/.local/bin`
- adds `~/.local/bin` to `~/.zprofile`
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
```

From an installed copy, you can also inspect the shipped remote installer:

```bash
~/.local/share/csa-iem/current/install-remote.sh --help
```

Uninstall:

```bash
cd '/path/to/CSA-iEM'
./uninstall.sh
```

## Install On Windows 11

Run the Windows installer from an Administrator PowerShell window.

Stable public install:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/0.3.1/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1 --ref 0.3.1"
```

Install the latest `main` build:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1"
```

Update an existing Windows install:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1 --force"
```

Install from a local checkout:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The Windows installer:
- installs into `%LOCALAPPDATA%\CSA-iEM\<version>`
- creates `csa-iem.cmd`, `csa-iem-open.cmd`, and `openproj.cmd`
- adds the chosen bin directory to the user PATH
- bootstraps `git`, `gh`, `node`, `code`, `docker`, and `devcontainer` when possible
- is designed for Windows Terminal and PowerShell admin-shell usage

After install, open a new PowerShell window and verify:

```powershell
csa-iem --version
openproj
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
- uses simple task pages for `Home`, `Jobs`, `GitHub Account`, `Projects`, `Local Files`, `Cleanup`, `Workspace`, `Settings`, and `About`
- keeps project browsing on-screen with native search, targeting, and direct VS Code / Finder open actions
- adds a native jobs center for background operations, status, retries, and logs
- adds a dedicated `GitHub Account` page for host, account, organization, and repository management while staying connected to the same `gh` session
- adds native GitHub admin surfaces for repo health, workflows, workflow runs, Codespaces, secrets/variables inventory, and rulesets
- adds a dedicated `Local Files` page for moving workspace roots, moving selected projects, and exporting code/runtime/runner combinations to another folder or external drive
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

## Windows 11 Admin Shell

The Windows release is PowerShell-first today.

It supports:
- preflight scans
- workspace setup with generic `Single Folder` or split code/runtime roots
- repo import and runtime mirror creation
- starter devcontainer generation
- quick local devcontainer startup checks
- repo-level self-hosted Windows runner install as a service
- workflow patching to self-hosted Windows labels
- GitHub cleanup actions for workflows, runs, artifacts, caches, and Codespaces
- local project browsing with VS Code and File Explorer

Windows documentation:
- [`docs/Windows-11-Notes.md`](./docs/Windows-11-Notes.md)

## Workspace Setup

The published app is generic by default.

Standard public options:
- single workspace folder: `~/CSA-iEM`
- split example:
  - code folder: `~/CSA-iEM/Code`
  - runtime folder: `~/CSA-iEM/Runtime`

Current-machine auto-detection:
- if the app finds an existing custom external-drive setup on your Mac, it offers that as `Detected current Mac setup`
- this keeps custom layouts working without requiring end users to understand legacy preset names

Advanced CLI compatibility:
- the CLI still supports the older `public`, `wtl`, and `diamond` profile names for compatibility
- the GUI now presents workspace choices as `Single Folder` or `Split Folders` instead

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
- `Workspace` for simple single-folder or split-folder setup
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

Advanced compatibility example for an existing split-workspace install:

```bash
csa-iem --profile diamond --repo OWNER/REPO --dry-run --yes
```

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
- local inventory metrics for imported projects, split workspaces, devcontainers, and runners
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

## Notes

- macOS only
- intended for technical users
- relies on GitHub CLI, Git, Docker, Homebrew, Node.js, npm, Visual Studio Code, and the macOS Swift toolchain for the GUI
- the app keeps legacy `CSA-iLEM` wrappers so older installed commands continue to work
- legal documents included here are practical production-distribution templates and should still be reviewed by counsel before broad public release
