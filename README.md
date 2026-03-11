# CSA-iEM

`CSA-iEM` means `Container Setup & Action Import Engine Manager`.

Version: `0.0.14`  
Provided by `Wayne Tech Lab LLC`  
Website: [www.WayneTechLab.com](https://www.WayneTechLab.com)  
Notice: `Use at your own risk.`

`CSA-iEM` is a macOS toolset with:
- a production CLI
- a SwiftUI macOS GUI control center
- terminal installers for supported Macs
- compatibility wrappers for the earlier `CSA-iLEM` command names

It is built for:
- cloning and organizing GitHub repos locally
- preparing local devcontainers
- installing self-hosted GitHub Actions runners
- patching workflow `runs-on` targets to self-hosted labels
- previewing or running GitHub cleanup flows
- browsing imported local workspaces, containers, and runners
- stepping through one-project-at-a-time cost-control reviews

## Primary Commands

Preferred commands:
- [`csa-iem`](./csa-iem)
- [`csa-iem-public`](./csa-iem-public)
- [`csa-iem-wtl`](./csa-iem-wtl)
- [`csa-iem-diamond`](./csa-iem-diamond)
- [`csa-iem-open`](./csa-iem-open)
- [`csa-iem-gui`](./csa-iem-gui)
- [`csa-iem-build-gui`](./csa-iem-build-gui)
- [`openproj`](./openproj)

Core scripts:
- [`CSA-iLEM.sh`](./CSA-iLEM.sh)
- [`CSA-iLEM-Public.sh`](./CSA-iLEM-Public.sh)
- [`CSA-iLEM-WTL.sh`](./CSA-iLEM-WTL.sh)
- [`CSA-iLEM-Diamond.sh`](./CSA-iLEM-Diamond.sh)
- [`CSA-iLEM-Open.sh`](./CSA-iLEM-Open.sh)
- [`install-remote.sh`](./install-remote.sh)
- [`install.sh`](./install.sh)
- [`uninstall.sh`](./uninstall.sh)
- [`run-gui.sh`](./run-gui.sh)
- [`build-gui-app.sh`](./build-gui-app.sh)

Legacy compatibility wrappers still ship:
- [`csa-ilem`](./csa-ilem)
- [`csa-ilem-public`](./csa-ilem-public)
- [`csa-ilem-wtl`](./csa-ilem-wtl)
- [`csa-ilem-diamond`](./csa-ilem-diamond)
- [`csa-ilem-open`](./csa-ilem-open)
- [`csa-ilem-gui`](./csa-ilem-gui)
- [`csa-ilem-build-gui`](./csa-ilem-build-gui)

## Install On Any Supported Mac

Fastest path from any supported Mac terminal:

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
- copies the production bundle into `~/.local/share/csa-iem/0.0.14`
- creates a stable `current` symlink under `~/.local/share/csa-iem/`
- links commands into `~/.local/bin`
- adds `~/.local/bin` to `~/.zprofile`
- installs the Swift package sources, assets, and docs needed for the GUI and app-bundle builder
- ships the remote installer too, so an installed machine can update again later without recloning first
- warns if Swift is not installed yet so the CLI can still be installed cleanly while the GUI path remains explicit

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

## macOS GUI

Run the GUI directly from the repo:

```bash
./run-gui.sh
```

Run the installed GUI launcher:

```bash
csa-iem-gui
```

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

The GUI is a SwiftUI macOS app that:
- provides a native cleanup and repository-selection workspace
- provides a native local project library with search, root awareness, and direct VS Code / Finder open actions
- lets the native local project library feed cleanup targeting directly
- launches the full interactive CLI in Terminal
- opens the project browser, cost-control review, and installed-devcontainer flows
- runs `--about`, `--help`, and `--version` directly inside the app
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

## Editions

### Public

- default root: `~/CSA-iEM`
- intended for portable single-root usage on supported Macs

### WTL

- default root: `/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH`
- intended for the Wayne Tech Lab external-drive layout

### Diamond

- code root: `/Volumes/WTL - MACmini EXT/MM-WTL-CODE-X/GH`
- runtime root: `/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH`
- keeps plain repo work separate from runtime/container work

Diamond layout:

```text
Code root
  Repos/<owner>/<repo>

Runtime root
  Repos/<owner>/<repo>
  Reports/
  Backups/
  Runners/<owner>/<repo>
  Scripts/
```

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

## Direct Cleanup CLI

`CSA-iEM` also supports direct cleanup commands without entering the menu flow.

Examples:

```bash
csa-iem --repo OWNER/REPO --all --yes
```

```bash
csa-iem --profile diamond --repo OWNER/REPO --disable-workflows --delete-runs --delete-artifacts --delete-caches --delete-codespaces --dry-run --yes
```

```bash
csa-iem --host github.com --account USER --repo https://github.com/OWNER/REPO --delete-runs --run-filter "release" --yes
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

Both jump straight into the full local project browser using the saved Diamond roots.
`openproj` now opens the imported-project list directly using the saved Diamond roots.
Use `csa-iem --browse` when you want the full browser menu instead.
From the imported-project list or full browser you can:
- open a plain repo or runtime workspace in VS Code
- inspect active local containers and local runner state
- run `Cost-control review (one project at a time)`

The native GUI now also exposes:
- active code/runtime root inspection for the selected profile
- local inventory metrics for imported projects, split workspaces, devcontainers, and runners
- a searchable local project library that opens runtime or code workspaces directly in VS Code
- native imported-project targeting for cleanup and cost-control flows

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
