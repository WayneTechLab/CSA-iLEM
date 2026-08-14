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

## Public release gate

The repository's `CSA-iLEM macOS release` workflow is intentionally separate
from the normal native preflight. It accepts a `vX.Y.Z` tag only when the tag
matches the first line of `VERSION`, runs the full non-destructive preflight,
then stops unless Apple Developer distribution credentials are configured.

When the required repository secrets are present, the workflow signs with a
Developer ID Application identity, notarizes and staples the app, verifies it
with `spctl`, creates a versioned macOS ZIP, writes a SHA-256 sidecar, and
publishes those artifacts to the matching GitHub release. Missing credentials
fail closed before any release is created; an ad-hoc local signature is never
treated as a public distribution signature.

Required release secrets are:

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `DEVELOPER_ID_APPLICATION`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`

The current branch installer remains a development/update path. It should not
be described as an immutable public release installer until a versioned,
notarized artifact and an independently published checksum are available.

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

The `CODEX ~ GPT Portal` includes Stage 2 source and managed-root controls, selected and Full Auto GitHub-identity preflight, optional verified ZIPs, Runtime mirrors, and Keep/Retire/Delete source policies. Stage 3 adds receipt-linked source and temporary-data cleanup. The Full Auto Lifecycle can run selected or all eligible projects through all three stages with independent ZIP and cleanup controls. Both macOS menu-bar surfaces expose Stage 2 and Full Lifecycle preflight/run entry points; destructive actions still require arming in the app.

## Icon Packaging

`build-gui-app.sh` converts `assets/AppIcon.appiconset` into `AppIcon.icns` for Finder and Dock use when `iconutil` is available.

## Scratch Path

SwiftPM builds use a temp scratch directory by default so the GUI remains usable even when the source tree lives on an external drive.
