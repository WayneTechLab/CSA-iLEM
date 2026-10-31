# CSA-iEM Project Info

## Product

- App name: `CSA-iEM`
- Full name: `Container Setup & Action Import Engine Manager`
- Version source: [`VERSION`](./VERSION)
- Native executable: `CSAiEMMacApp`
- CLI engine: `CSA-iLEM.sh`
- Bundle ID: `com.waynetechlab.csa-iem`
- Category: `public.app-category.developer-tools`
- Minimum macOS: `13.0`
- Firebase project: `csa-ilem`
- Firebase Apple SDK: `12.18.0` (`FirebaseCore` only)

## Product Scope

The `0.8.0` native dashboard uses a single module/version/tag matrix across
pages, engines, bridges, runtimes, recovery, and install/update surfaces. The
matrix is a diagnostic identity layer; it does not replace Git, receipts, or
the installed bundle version.

`CSA-iEM` provides:

- GitHub repo import and local workspace preparation
- local devcontainer setup and validation
- self-hosted GitHub Actions runner install and service control on macOS and Windows
- workflow `runs-on` patching to self-hosted labels
- GitHub cleanup for workflows, runs, artifacts, caches, and Codespaces
- one-project-at-a-time cost-control review
- a native macOS GUI for Home, Jobs, Incidents, GitHub Issues, GitHub Account, GitHub Billing Reports, Import, Projects, CODEX ~ GPT PORTAL, Project Backups, Local Files, Cleanup, Workspace, Settings, and About
- Checkout Review & Recovery for live GitHub identity/file comparison, separate Git-history findings, complete physical manifests, recoverable retirement, and verified restoration
- Old Source Leftovers for metadata-only inspection of hidden and dependency-only remnants, saved reports, and incomplete-cleanup results
- Staging & Backup Cleanup for verified whole-folder recovery archives, per-item restore, interruption verification, and optional follow-up after eligible observed app runs
- a Windows 11 admin-shell PowerShell backend for import, cleanup, browsing, and runner/devcontainer prep

Bundled reference pages cover Help Center, Terms of Service, Security Notes,
Brand System, macOS App Notes, and Project Info. Matrix `matrix-1.4` tracks 24
modules, including `feature.checkout-review`, `feature.source-residuals`, and
`feature.transfer-artifacts` (`transfer-artifacts-v1.0`).
About distinguishes the installed payload from the unchanged app-version
baseline. A payload fingerprint identifies the packaged manifest; it does not
replace binary signature, notarization, or release acceptance checks.

Checkout review preserves a selected extra local checkout in same-volume
Runtime recovery storage and retains a restore receipt. Configured origins,
live repository IDs, working-file equality, and Git history are distinct
findings. Exact native transaction staging and backup directories remain on
disk for separate review rather than being counted as normal active projects.

Staging/backup preservation stores complete trees in
`Runtime/Recovery/TransferArtifacts` and full per-item manifests in
`Runtime/Reports/TransferArtifacts`. A lightweight Application Support session
pointer is written before moves. Interrupted verification checks the recorded
receipts without starting new moves. Automation is off by default, follows only
eligible observed non-dry-run mutation completions after other mutating jobs
finish, and excludes startup, scans, failures/cancellations, restores/undo, and
unobserved standalone Terminal Stage 2/3 sessions. Sources blocked by active use,
shared Git storage, cloud placeholders, unreadable content, or protection remain
in place; canonical checkouts remain unchanged.

## Repository Boundary

This checkout is the native CSA-iLEM application repository, not a website
application. Package.swift and Sources/CSAiEMMacApp are the product identity.
The scanner recognizes package.json, Vite, Hosting, and other web markers only
when inspecting an imported project outside this repository. CSA-iLEM's own
`GoogleService-Info.plist` and FirebaseCore dependency are native Apple client
configuration and do not indicate that CSA-iLEM is a web app.

The CODEX ~ GPT Add-on master plan lives at
.SYSTEMX/AI/CODEX-GPT-ADDON-MASTER-PLAN.md. It defines the native dashboard,
Smart Logic, index/recovery, interoperability, Archive_Data, and Project
Backups direction.

Current production-status tracking lives in:

- [`STATUS.md`](./STATUS.md)

## Build Inputs

The repo ships:

- the macOS Bash backend and wrappers
- the native SwiftUI macOS app
- the Windows 11 PowerShell backend and installers
- repo-local and remote installers for both operating systems

## Bundle Resources

The packaged `.app` includes:

- the CLI engine and wrappers under `Contents/Resources/CLI`
- root product docs such as `README.md`, `SECURITY.md`, `PROJECT-INFO.md`, and legal files
- help markdown files under `Contents/Resources/Help`
- brand and icon assets under `Contents/Resources/assets`
- `AppIcon.icns` for Finder and Dock
- the validated Firebase Apple client plist under `Contents/Resources`
- Firebase/SwiftPM privacy and resource bundles under `Contents/Resources`
- the checksum-pinned Firebase Apple SDK third-party notice aggregation

## Runtime Resource Resolution

The native app resolves resources in this order:

1. bundled app resources
2. `CSA_IEM_ROOT` when launched from a source or installed tree
3. current working directory fallbacks

That allows:

- `swift run` from the repo
- installed command launchers
- standalone `.app` bundle use

## Local State

The app stores non-secret last-session metadata in:

- `~/Library/Application Support/CSA-iEM/last-session.env`

That saved state now carries explicit public workspace roots for:

- `CodeRoot`
- `ImportRoot`
- `RuntimeRoot`

It also reads legacy session paths for compatibility with:

- earlier `CSA-iLEM` builds
- `GH Workflow Clean`

## Packaging Notes

- `build-gui-app.sh` creates `dist/CSA-iEM.app`
- `install.sh` installs the terminal and GUI source bundle into `~/.local/share/csa-iem/<version>`
- `install-remote.sh` lets any supported Mac pull and install the app directly from GitHub with `curl ... | bash`
- `csa-iem-update` lets installed macOS and Windows copies update from the published GitHub repo without recloning first
- `csa-iem-build-gui` builds the standalone `.app` from an installed copy

## Terminal Distribution

Recommended latest published macOS install path:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash
```

Recommended latest published macOS update path:

```bash
csa-iem-update
```

Specific tagged release, branch, or commit install path:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --ref your-tag-or-branch
```

Recommended latest published Windows 11 admin-shell install path:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1"
```

Recommended latest published Windows 11 update path:

```powershell
csa-iem-update
```

## Workspace Model

The public app now presents storage as an explicit three-root workspace:

- `Code`
- `Import`
- `Runtime`

It also auto-detects this Mac's current custom-drive setup and offers it as a detected migration example, while keeping the older CLI preset names and `--single-root` only for advanced terminal compatibility.
