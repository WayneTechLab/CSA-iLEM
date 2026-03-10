# Changelog

## 0.0.13

- added a production remote installer so any supported Mac can install from Terminal with `curl ... | bash`
- updated the local installer to ship `install-remote.sh` inside installed copies and packaged `.app` resources
- rewrote the install documentation to lead with the one-line remote install and update flow
- hardened the remote installer with retry logic, basic tool validation, and explicit verification guidance

## 0.0.12

- made the native local project library feed the cleanup engine directly
- added native imported-project targeting and visible-target bulk selection inside the GUI
- kept the GUI-first cleanup workflow aligned while the CLI remains the backend and fallback path

## 0.0.10

- fixed the native macOS dashboard so the imported local project library is rendered in every responsive layout
- added active-root inspection in the GUI with direct Finder reveal actions for the current code and runtime roots
- added native local inventory metric cards for imported projects, split workspaces, devcontainers, generated starters, and runners
- upgraded the GUI into a more complete operations control center with searchable imported projects and direct VS Code open actions
- optimized the imported-project opener flow so `openproj` lands directly in the project list and local project detection stays fast on larger repo sets

## 0.0.09

- tightened the GUI helper scripts with explicit `--help` and `--version` support, macOS-only checks, and Swift/Xcode guidance
- made the standalone `.app` bundle ship the GUI helper wrappers as part of the embedded CLI resource set
- updated icon metadata and production packaging details for Wayne Tech Lab LLC branding consistency
- refreshed installer messaging so GUI prerequisites are called out during terminal installs on supported Macs

## 0.0.08

- added cleaner-style direct cleanup flags to the production CLI for host, account, repo, workflows, runs, artifacts, caches, Codespaces, dry-run, and assume-yes flows
- changed `Cleanup only` so it no longer clones or updates local repositories before running GitHub cleanup
- wired the native macOS GUI cleanup workspace to the direct cleanup CLI contract and forced `--no-color` for clean in-app logs
- updated the GUI resource search path to work from bundled app resources, installed copies, and source-tree launches
- upgraded the `.app` bundle build to ship help docs, product docs, brand assets, and an `AppIcon.icns`
- updated the installer to ship `assets/`, `docs/`, `Sources/`, `SECURITY.md`, and `PROJECT-INFO.md`
- refreshed the packaged docs so they now describe `CSA-iEM`, not `GH Workflow Clean`

## 0.0.07

- rebranded the product user-facing name to `CSA-iEM` with the full title `Container Setup & Action Import Engine Manager`
- added the SwiftUI macOS GUI package, launcher, and app-bundle build flow
- added `csa-iem-gui`, `csa-iem-build-gui`, and matching legacy compatibility wrappers
- updated install and uninstall flows to ship the GUI sources and launchers
- refreshed the README and legal/notice docs for the new branding and GUI distribution path
- updated user-facing CLI text so the app now presents itself as `CSA-iEM`

## 0.0.06

- added a one-project-at-a-time cost-control review flow from the browser and `openproj`
- added a recommended no-spend safeguard plan that can disable repo Actions, stop local runners and containers, and clean up Actions state
- updated the opener flow to land in the full project browser instead of only the devcontainer list

## 0.0.05

- prepared the CLI for terminal installation on supported Macs
- added stable lowercase command wrappers for installed use
- added `install.sh` and `uninstall.sh`
- added `NOTICE.md`, `TERMS-OF-SERVICE.md`, `PRIVACY-NOTICE.md`, and `DISCLAIMER.md`
- added built-in CLI flags for `--about`, `--notice`, `--terms`, `--privacy`, and `--disclaimer`
- updated product branding to Wayne Tech Lab LLC / WayneTechLab.com
- kept the Diamond, WTL, Public, and opener flows aligned with the production CLI surface
