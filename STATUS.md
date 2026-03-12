# CSA-iEM Status

Version baseline: `0.3.0`
Updated: `2026-03-12`

This file is the current production-status snapshot for `CSA-iEM`.

Long-range product roadmap:
- [`docs/20-Phase-Roadmap.md`](./docs/20-Phase-Roadmap.md)

## Done

These major product areas are built into the app now:

- production CLI engine for import, local prep, cleanup, and review flows
- SwiftUI macOS GUI with `Home`, `Jobs`, `GitHub Account`, `Projects`, `Local Files`, `Cleanup`, `Workspace`, `Settings`, and `About`
- Windows 11 admin-shell PowerShell backend for import, cleanup, browsing, devcontainer prep, and repo-level self-hosted runner setup
- local project browsing with native search, favorites, targeting, and direct open actions
- local runner and devcontainer inspection/control from the GUI
- GitHub admin surfaces for repo health, workflows, runs, Codespaces, secrets/variables inventory, and rules/rulesets viewing
- local move/export/snapshot flows with preview-first behavior
- direct cleanup CLI flags for repo-scoped GitHub cleanup actions
- install, uninstall, and remote install/update scripts for macOS and Windows 11
- packaged `.app` build flow with bundled docs, assets, icon, and CLI resources
- compatibility wrappers for earlier `CSA-iLEM` naming

## Is Done

These items are currently verified as working in the repo at `0.3.0`:

- local install from repo via `install.sh`
- remote install bootstrap via `install-remote.sh`
- Windows installer and remote installer script generation from `install.ps1` and `install-remote.ps1`
- uninstall safety for versioned installs without blindly removing newer command links
- custom `--bin-dir` install path updates in shell profile output
- GUI build from source and from an installed copy
- versioned command wrappers:
  - `csa-iem`
  - `csa-iem-gui`
  - `csa-iem-build-gui`
  - `openproj`
- safer split-root move staging compared to earlier partial-move behavior
- export preview destination consistency
- clearer partial-failure reporting in the GitHub admin panels for secrets, variables, branch protection, and rulesets

## Broken

These are the known production gaps or weak spots still open:

- some advanced GUI actions still rely on Terminal fallback helpers instead of staying fully native end to end
- the native desktop GUI is still macOS-only; Windows currently ships as a PowerShell-first admin-shell experience
- the public remote install path still trusts downloaded GitHub content rather than signed or checksummed release artifacts
- destructive workspace/file flows are safer than before, but still need broader rollback and recovery coverage under interrupted or cross-device failures
- GitHub admin features have not yet been fully smoke-tested across multiple accounts, organizations, and intentionally limited token scopes
- there is still no deep automated regression suite for install, uninstall, GUI actions, and GitHub-side operations

## Almost Done

These areas are close, but not fully finished to the standard the app is aiming for:

- GUI-first product direction is established, but a few legacy CLI concepts and compatibility entry points still exist around the edges
- Windows now has core operational parity for shell usage, but not a native desktop GUI layer yet
- `GitHub Account` is now a real admin page, but editing flows are still lighter than the read/inspect surfaces
- `Local Files` now has safer previews, moves, exports, and snapshots, but needs more polished recovery UX and more guided validation
- `Projects` has strong browsing and local operations, but still needs deeper native import and one-by-one management flows
- `Jobs` exists, but not every long-running background action is routed through it yet
- `Settings` is present, but onboarding and preference explanations can still be cleaner for public users

## Needs Done

These are the next production-hardening tasks with the best return:

- replace more Terminal fallback flows with fully native GUI actions
- add deeper Windows smoke coverage for runner install/service behavior and Docker/devcontainer lifecycle on real Windows 11 hardware
- add signed release artifacts or checksum verification to the public installer/update path
- add a rollback/recovery layer for move/export operations when later steps fail
- add an end-to-end production smoke suite for:
  - install
  - remote install
  - uninstall
  - GUI build
  - local file move/export/restore
  - runner lifecycle
  - devcontainer lifecycle
  - GitHub cleanup dry-run
- add clearer permission/scope diagnostics everywhere GitHub API data can be partially unavailable
- reduce advanced/legacy wrapper visibility in the public-facing UX
- expand first-run onboarding so a new user can understand workspace setup without knowing the older internal models

## Future Things

These are solid next-wave features after the remaining production-hardening work:

- fully native repo import/migration wizard in the GUI
- fully native one-project-at-a-time cost-control review in the GUI
- workflow dispatch and richer workflow editing from the app
- secrets/variables creation and update flows from the app
- branch protection and ruleset editing for common policies
- multi-account and multi-context management with saved GitHub contexts
- richer disk-usage analysis and storage charts
- better task-template authoring and reusable automation per project
- notification center for long-running jobs and completion states
- packaging/signing/notarization for broader public distribution

## Current Direction

Recommended direction for `CSA-iEM`:

- GUI first
- CLI as execution backend and fallback
- preview before destructive actions
- stronger recovery/rollback on file operations
- stronger release/install trust model for public distribution
