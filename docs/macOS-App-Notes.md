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
- `Incidents`
- `GitHub Issues`
- `Import`
- `GitHub Account`
- `GitHub Billing Reports`
- `Projects`
- `CODEX ~ GPT PORTAL`
- `Project Backups`
- `Local Files`
- `Cleanup`
- `Workspace`
- `Settings`
- `About`

The bundled reference pages are `Help Center`, `Terms of Service`,
`Security Notes`, `Brand System`, `macOS App Notes`, and `Project Info`.

Projects, account management, local file operations, and cleanup stay on-screen, while the CLI remains the backend and advanced fallback.

## Checkout and Leftover Review

**Projects** and **Local Files** expose **Checkout Review & Recovery**. Compare
two folders with live GitHub repository IDs, immutable default-branch file
evidence, local changes, separate Git-history status, and complete physical
manifests. Folder names and configured origins are review evidence; matching
working files alone do not prove matching history. Reviewed retirement preserves
the complete other checkout in same-volume Runtime recovery storage with a
receipt and verified restore action. It does not delete a GitHub repository or
overwrite the keeper. Exact transaction staging and backup folders remain
visible separately from the active project count and require their own review.

**Staging & Backup Cleanup** in Projects and Local Files provides **Review
Staging / Backup Folders**, **Preserve & Clean Reviewed Folders**, per-item
restore, and **Verify Interrupted Cleanup**. It verifies complete source and
canonical trees, preserves the whole eligible folder under
`Runtime/Recovery/TransferArtifacts`, and retains all review rows and partial
failure results. Canonical checkouts remain unchanged. Full manifests live in
`Runtime/Reports/TransferArtifacts`; a small Application Support session pointer
is saved before moves. Interrupted verification checks prepared/archived
receipts without starting new moves; remaining sources need a fresh review.

Optional automatic staging/backup preservation is off by default. When enabled,
it follows eligible successful, non-dry-run in-app import, migration/export,
CODEX, or applied-cleanup operations after other mutating jobs finish. It does
not run on startup, read-only work, failed/cancelled runs, restore/undo, another
artifact pass, or unobserved standalone Terminal Stage 2/3 completion. Remaining
source paths and artifact failures keep the cleanup warning visible.

**Local Files** and **Jobs** expose **Old Source Leftovers** for hidden files,
dependency-only trees, cloud placeholders, and incomplete source cleanup. This
scan reads metadata only and retains unreadable or bounded results as
unverified. Its saved reports survive restarts. Moves report **Cleanup
incomplete** when old roots remain; rescan after recovery or removal to obtain
a fresh **Verified absent** result. See the bundled Help Center for the two
review workflows and their preservation requirements.

The shared catalog is `matrix-1.4` with 24 module tags. About identifies the
installed payload separately from the unchanged `0.8.0` version baseline.
The packaged manifest fingerprint is a diagnostic aid; public signing,
notarization, and release acceptance remain separate gates.

## Bundled Resources

The `.app` bundle includes:

- CLI engine scripts
- help markdown files
- legal/product docs
- app icon assets
- brand images
- the validated `GoogleService-Info.plist` Apple client configuration
- FirebaseCore and GoogleUtilities SwiftPM resource/privacy bundles under the
  signed `Contents/Resources` envelope
- `Firebase-Apple-SDK-NOTICES.txt`, copied from the exact resolved 12.18.0
  CoreOnly distribution and accepted only when its pinned SHA-256 matches

## Firebase Apple Setup

CSA-iLEM is registered in Firebase project `csa-ilem` as the Apple app with
bundle ID `com.waynetechlab.csa-iem`. `Package.swift` pins Firebase Apple SDK
12.18.0 and links only `FirebaseCore`. Initialization runs once through the
existing `NSApplicationDelegateAdaptor` lifecycle. Missing, malformed,
wrong-bundle, or wrong-project configuration fails safely and remains visible
as a menu-bar status instead of crashing the native app.

Validate the checked-in client file without displaying its client fields:

```bash
bash .SYSTEMX/scripts/verify-firebase-apple-config.sh
```

Import a freshly downloaded replacement only after registering the exact same
Apple bundle ID:

```bash
bash .SYSTEMX/scripts/verify-firebase-apple-config.sh --import /path/to/GoogleService-Info.plist
```

This setup adds no Firebase Analytics, Auth, database, Storage, Hosting, web
server, or port. A future Firebase product is a separate feature and security
change, including any required Keychain Sharing entitlement, Security Rules,
App Check, API restrictions, and privacy disclosure.

## Public release gate

Repository GitHub Actions workflows were removed on 2026-10-07 for the
Firebase/Google Cloud project direction. Run native acceptance checks locally
with `bash .SYSTEMX/scripts/release-preflight.sh`. That gate rejects any
reintroduced GitHub Actions workflow.

A public macOS release still requires Developer ID signing, notarization,
stapling, Gatekeeper assessment, and a versioned artifact with a published
checksum. No Google Cloud build pipeline or Firebase deployment is configured
by removing GitHub Actions. Firebase Hosting does not package or sign the
native macOS app.

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

During installation, the native app is built into a disposable temporary
directory, verified, and atomically moved to the canonical Applications
location. The temporary bundle is removed, and older install-tree bundles are
not retained as runnable copies. A per-user runtime lock provides a second
defense: if an old copy is opened, it activates the existing app and exits
before creating another menu-bar toolbar.

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
