# CSA-iEM macOS Project Info

## Product

- App name: `CSA-iEM`
- Full name: `Container Setup & Action Import Engine Manager`
- Native executable: `CSAiEMMacApp`
- CLI engine: `CSA-iLEM.sh`
- Bundle ID: `com.waynetechlab.csa-iem`
- Category: `public.app-category.developer-tools`
- Minimum macOS: `13.0`

## Product Scope

`CSA-iEM` is the production macOS package for:

- GitHub repo import and local workspace preparation
- local devcontainer setup and validation
- self-hosted GitHub Actions runner install and service control
- workflow `runs-on` patching to self-hosted labels
- GitHub cleanup for workflows, runs, artifacts, caches, and Codespaces
- one-project-at-a-time cost-control review
- a multi-page native GUI for Home, GitHub Account, Projects, Local Files, Cleanup, Workspace, and About

Current production-status tracking lives in:

- [`STATUS.md`](./STATUS.md)

## Build Inputs

The repo ships both the terminal engine and the native macOS app:

- `CSA-iLEM.sh`
- edition wrappers and openers
- `Package.swift`
- `Sources/CSAiEMMacApp/`
- `build-gui-app.sh`
- `run-gui.sh`
- `install.sh`
- `install-remote.sh`

## Bundle Resources

The packaged `.app` includes:

- the CLI engine and wrappers under `Contents/Resources/CLI`
- root product docs such as `README.md`, `SECURITY.md`, `PROJECT-INFO.md`, and legal files
- help markdown files under `Contents/Resources/Help`
- brand and icon assets under `Contents/Resources/assets`
- `AppIcon.icns` for Finder and Dock

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

It also reads legacy session paths for compatibility with:

- earlier `CSA-iLEM` builds
- `GH Workflow Clean`

## Packaging Notes

- `build-gui-app.sh` creates `dist/CSA-iEM.app`
- `install.sh` installs the terminal and GUI source bundle into `~/.local/share/csa-iem/<version>`
- `install-remote.sh` lets any supported Mac pull and install the app directly from GitHub with `curl ... | bash`
- `csa-iem-build-gui` builds the standalone `.app` from an installed copy

## Terminal Distribution

Recommended production install path:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/0.2.3/install-remote.sh | bash -s -- --ref 0.2.3
```

Recommended production update path:

```bash
curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --force
```

## Workspace Model

The public app now presents storage as a generic workspace choice:

- `Single Folder`
- `Split Folders`

It also auto-detects this Mac's current custom-drive setup and offers it as a detected example, while keeping the older CLI preset names only for advanced terminal compatibility.
