# macOS App Notes

## GUI Build

Build the standalone app bundle with:

```bash
./build-gui-app.sh
```

This creates:

```text
dist/CSA-iEM.app
```

## GUI Runtime

Run the native app from source with:

```bash
./run-gui.sh
```

The source-run path uses Swift Package Manager and points the app at the local repo via `CSA_IEM_ROOT`.

The GUI is now organized around task pages instead of one overloaded dashboard:

- `Home`
- `Jobs`
- `Import`
- `GitHub Account`
- `Projects`
- `Local Files`
- `Cleanup`
- `Workspace`
- `Settings`
- `About`

Projects, account management, local file operations, and cleanup stay on-screen, while the CLI remains the backend and advanced fallback.

## Bundled Resources

The `.app` bundle includes:

- CLI engine scripts
- help markdown files
- legal/product docs
- app icon assets
- brand images

## Installer Notes

Use Terminal with `zsh` or `bash`.

Latest published `main` install:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash
```

Latest published `main` update:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --force
```

Specific release, branch, or commit install:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --ref your-tag-or-branch
```

Local repo install:

```bash
./install.sh
```

Local git update:

```bash
git switch main
git pull --ff-only origin main
./install.sh --force
```

After reloading the shell profile, macOS Terminal also accepts:

```bash
csa-iem-update
CSA-IEM --version
CSA-iEM --version
```

`install.sh` copies the app source, CLI scripts, assets, and docs into the versioned install root so a clean Mac can:

- run the CLI immediately
- launch the native SwiftUI app from the installed tree
- build a standalone `.app` later with `csa-iem-build-gui`
- update later with `csa-iem-update` or rerun the shipped `install-remote.sh` from the installed copy if needed
- install `@devcontainers/cli` into a user-local npm prefix automatically if the machine blocks system-wide npm global installs

## Workspace Setup

The published GUI now defaults to a generic public three-root model:

- standard code root: `~/CSA-iEM/Code`
- standard import root: `~/CSA-iEM/Import`
- standard runtime root: `~/CSA-iEM/Runtime`

If the app detects a current custom-drive setup on the machine, it presents that as a detected workspace migration example instead of surfacing legacy preset names in the main UX.

## Icon Packaging

`build-gui-app.sh` converts `assets/AppIcon.appiconset` into `AppIcon.icns` for Finder and Dock use when `iconutil` is available.

## Scratch Path

SwiftPM builds use a temp scratch directory by default so the GUI remains usable even when the source tree lives on an external drive.
