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

From any supported Mac terminal, install with:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/0.3.3/install-remote.sh | bash -s -- --ref 0.3.3
```

Update with:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --force
```

`install.sh` copies the app source, CLI scripts, assets, and docs into the versioned install root so a clean Mac can:

- run the CLI immediately
- launch the native SwiftUI app from the installed tree
- build a standalone `.app` later with `csa-iem-build-gui`
- rerun the shipped `install-remote.sh` later from the installed copy if needed
- install `@devcontainers/cli` into a user-local npm prefix automatically if the machine blocks system-wide npm global installs

## Workspace Setup

The published GUI now defaults to a generic public model:

- standard single-folder setup: `~/CSA-iEM`
- standard split setup:
  - `~/CSA-iEM/Code`
  - `~/CSA-iEM/Runtime`

If the app detects a current custom-drive setup on the machine, it presents that as a detected workspace example instead of surfacing legacy preset names in the main UX.

## Icon Packaging

`build-gui-app.sh` converts `assets/AppIcon.appiconset` into `AppIcon.icns` for Finder and Dock use when `iconutil` is available.

## Scratch Path

SwiftPM builds use a temp scratch directory by default so the GUI remains usable even when the source tree lives on an external drive.
