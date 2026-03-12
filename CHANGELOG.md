# Changelog

## 0.2.3

- fixed `openproj` so it auto-detects the current saved or detected workspace profile instead of forcing the public single-folder profile
- added GUI workspace recovery when the current workspace scan comes back empty but a detected workspace on the same Mac already contains imported projects
- updated versioned install and product docs for the `0.2.3` recovery fix

## 0.2.2

- reduced Terminal-first behavior in the GUI by shifting the advanced tools panel toward native page navigation and hiding terminal fallback launchers unless explicitly enabled in Settings
- made local export and backup flows transactional across multi-item operations so failures roll back staged destinations instead of leaving partial move/export state behind
- added checksum verification to the remote installer so extracted public/tag installs are validated before the local installer runs
- started shipping `STATUS.md` and `SHA256SUMS` with installed copies and packaged app resources
- updated production docs and version metadata for the `0.2.2` hardening pass

## 0.2.1

- made workspace relocation safer by staging multi-root moves before switching destinations and reporting cleanup warnings instead of leaving a silent half-moved state
- fixed the local-file export preview so the previewed destination matches the execution destination for the prepared export run
- corrected the GitHub admin panels to report partial failures for secrets, variables, rulesets, and branch protection instead of silently showing empty results as success
- stopped requesting GitHub variable values in the GUI inventory so the app only loads the metadata it actually displays
- fixed the native `Open Repo Settings` action so it opens repository settings instead of the owner page
- fixed terminal installs with custom `--bin-dir` values so the profile PATH update matches the actual chosen command directory
- made the uninstaller preserve command links and the shared `current` symlink when they belong to another installed version
- added a remote installer version/ref sanity check for tag-based installs

## 0.2.0

- added native `Jobs` and `Settings` pages so the GUI can manage background work, onboarding, saved contexts, and GUI-first defaults without forcing users into the CLI
- expanded the `GitHub Account` page into a real admin surface with repo health, workflow control, workflow runs, Codespaces, secrets/variables inventory, and branch protection/ruleset views
- expanded the `Projects` page with favorites, saved views, task templates, sync status, storage insights, port monitoring, and richer local devcontainer/runner controls
- expanded the `Local Files` page with backup presets, preview-first move/export flows, and snapshot/restore controls
- added native background job retry/cancel/clear flows and integrated more local operations into the GUI instead of Terminal fallbacks
- updated production docs and install metadata for the `0.2.0` GUI-first release

## 0.1.1

- added a dedicated `GitHub Account` page so host, account, organization, and repository management no longer has to live on the main dashboard
- added a dedicated `Local Files` page for moving workspace roots, moving selected projects, and exporting code/runtime/runner combinations to another location or external drive
- polished the `Local Files` UX with clearer action labels for copy vs move operations and one-project vs full-workspace flows
- kept the GUI as the primary surface while the CLI continues to run in the background for cleanup and file operations
- updated the public install and product docs to reflect the new GUI page model and `0.1.1` production bundle

## 0.1.0

- redesigned the native app into task pages for `Home`, `Projects`, `Cleanup`, `Workspace`, and `About`
- removed `WTL / Diamond / Public` from the main GUI flow and replaced them with a generic workspace model using `Single Folder` or `Split Folders`
- added workspace setup controls that use standard public paths or the detected current-machine setup without forcing end users into the CLI model
- added a native live-services view for active devcontainers and runner services directly inside the `Projects` page
- simplified the public command surface and install messaging so the generic GUI-first commands are the obvious entry points
- moved terminal launchers into an advanced area so the GUI is the primary navigation surface
- switched the public opener flow to the generic workspace path by default

## 0.0.14

- fixed the remote installer for stock macOS Bash 3.2 so the one-line `curl ... | bash` path works when no optional install arguments are passed
- published the terminal install path as a patch release after verifying it against GitHub `main` and the version tag flow

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
