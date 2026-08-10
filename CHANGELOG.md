# Changelog

## 0.7.0

- Added the verified repository-consolidation recovery lifecycle for identity-bound many-source-to-one-repository reconciliation, complete source representation proofs, Git object validation, transaction receipts, and fail-closed global retirement.
- Added exact-transaction checkpoint resume for finalized destination groups. Resume revalidates the source map, source filesystem identity, GitHub identity, Git state, destination receipt, remote state, and representation evidence; partial staging and transactions that entered retirement cannot resume.
- Corrected global retirement workspace-proof forwarding and made deletion eligibility derive only from each mapping's reviewed retirement authorization. Retained or protected sources can satisfy representation requirements but cannot become deletion candidates.
- Added bounded stable-file and metadata caches for repeated verification passes while retaining before-and-after filesystem mutation checks and clearing caches at transaction boundaries.
- Replaced per-file macOS ACL subprocess probes with a native extended-ACL presence check. Files with no ACL avoid process launch while real ACLs retain the existing byte-compatible receipt digest path.
- Added bounded two-worker repository-group processing with disjoint-path auditing, conflict-component serialization for nested or shared-Git sources, deterministic result collection, exact receipt rehashing, and a mandatory coordinator-only barrier before retirement. Duplicate destination or report lanes automatically fall back to one worker.
- Fixed final representation verification for directory-metadata conflicts so a source directory represented by its exact recovery variant is recognized and revalidated instead of incorrectly failing against the canonical directory metadata.
- Fixed two-worker runner-proof revalidation so only transaction-owned descendant tools are ignored during active reads while global retirement still blocks on every child process. Exact Git snapshots now reapply copied root-directory metadata, and isolated recovery variants reapply then revalidate security provenance xattrs before cleanup proofs finalize.
- Added a persistent stat-bound SHA-256 index under managed `Runtime/Indexes` with before/after mutation checks, thread-safe two-lane access, fail-safe direct-hash fallback, bounded stale-key replacement, durable batching, and per-transaction hit/miss/write/error reports. Documented the repeated scan-plan-execute-verify-clean-final-sweep lifecycle.
- Added repeatable `--protected-checkout` boundaries to recovery and cleanup. Git launch checkouts are protected automatically, and every destructive rename, replacement, unlink, directory removal, and recursive deletion now rejects the protected path plus all ancestors and descendants independently of discovery or source-map classification.
- Bound metadata-cache entries to freshly measured nonvolatile extended attributes. The asynchronously managed macOS `com.apple.provenance` digest is recorded in representation proofs but excluded from exact equality and deletion authorization, preventing APFS provenance races while retaining exact content, regular xattr, resource-fork, ACL, ownership, mode, flag, timestamp, and hardlink checks.
- Added post-success local and external temporary-data cleanup gates. Cleanup accepts only exact recovery receipts and completed local-retirement evidence, preserves failed or incomplete transactions, and requires `DELETE-VERIFIED-EXTERNAL-TEMP-PAYLOADS` before deleting allowlisted transaction payloads.
- Added receipt-driven Full Auto lifecycle controls to the native `CODEX ~ GPT PORTAL` with Selected Projects and All Eligible Projects scope. The active CSA-iEM/Codex workspace is excluded from automatic batches.
- Added independent Stage 1 and Stage 2 verified-ZIP policies, Stage 1 original deletion, Stage 2 Keep/Retire/Permanent Delete policies, and Stage 3 current-transaction or all-verified-temp cleanup selectors.
- Stage 1 now writes one machine-readable receipt per verified project under `_temp/Transfer-Receipts`, recording original/current source, destination, exact tested archive, Git identity, transfer plan and indexes, preservation policy, and verification time.
- Fixed Fast Mode's final-audit path so a same-size, same-timestamp content mutation is checksum-preserved on the destination side, repaired with an exact targeted transfer, and whole-tree verified again instead of merely stopping after the fast preflight missed it.
- Stage 2 can now create and test a source ZIP, write canonical verification receipts, permanently remove an intermediate source only after same-volume quarantine and a second verification, and clean only its current successful transaction.
- Added `stage3-cleanup.sh` and `stage3-cleanup.ps1`. Stage 3 accepts selected receipts, project filters, or all verified receipts; performs a fresh preflight; follows Stage 1-to-Stage 2 receipt chains; and deletes only receipt-linked sources, indexes, and transaction folders after live verification.
- Added explicit `VERIFIED-STAGE2` and `VERIFIED-STAGE3` confirmation tokens. Permanent source cleanup fails closed on missing destinations, unverified archives, identity mismatches, active CSA-iEM, boundary failures, or any changed source file.
- Added Stage 3 commands and interactive menus to the shell and PowerShell CLIs, controls to both macOS menu-bar implementations, and matching preflight, temp-cleanup, and double-confirmed source-cleanup actions to the Windows notification-area tray.
- Fixed PowerShell Stage 2/Stage 3 subcommand forwarding so GNU-style arguments are passed as an actual string array to a child PowerShell host instead of being split into characters.
- Bundled both Stage 3 engines into macOS app builds and macOS/Windows versioned installs.

## 0.6.0

- Added `CODEX ~ GPT Portal` Stage 2 for reconciling verified Stage 1 project backups into the canonical `Code/Repos/<owner>/<repo>` workspace under a selected CSA-iEM root.
- Added GitHub-backed identity preflight using repository node ID, canonical owner/name, default branch, archived state, remote HEAD, local worktree state, and commit ancestry. Folder names are only a fallback; ambiguous identities remain blocked.
- Added safety-gated selected-project and Full Auto execution. Active CSA-iEM checkouts, dirty or staged canonical destinations, dirty source merges into an existing canonical project, divergent history, archived repositories, duplicate destinations, and identity conflicts are skipped and reported instead of overwritten.
- Added isolated Stage 2 transactions under `Import/Stage2`, atomic promotion for new canonical projects, APFS clone-copy acceleration, path/type/size/symlink verification, Git object verification, clean local fast-forward, and additive-only healing for existing destinations.
- Added optional Runtime mirror preparation and optional Stage 1 retirement into `CODEX PROJECTS/_temp/Stage2-Completed`; Stage 1 remains untouched by default.
- Added explicit private empty-repository creation for projects with no verified GitHub repository. CSA-iEM attaches the local canonical copy but does not commit or upload project files automatically.
- Added Stage 2 controls to the native macOS portal, both macOS toolbar surfaces, the shell CLI and interactive menu, the Windows PowerShell CLI, and the Windows notification-area tray.
- Added project quick actions for GitHub Copilot and devcontainer launch alongside Finder, Codex, and Visual Studio Code.
- Hardened ordinary CLI repo updates so untracked files now block automatic pulls together with staged and modified files.
- Added per-transaction Markdown reports under `Runtime/Reports/Stage2` with live `PLAN`, `PROGRESS`, and summary output.

## 0.5.18

- Separated CODEX project discovery from current Codex desktop linkage. The portal now reads the local Codex project registry and labels the selected IDE workspace `Active here`, other current local-project entries `Codex linked`, and disk-only discoveries `Unlinked`; historical task records and saved workspace-root history do not falsely relink a project.
- Added read-only local Git health to every discovered project row. CSA-iEM reports branch, working-tree changes, and ahead/behind/diverged state against the locally stored `origin/main` reference without fetching, changing Git configuration, reading prompts, or storing account data.
- Parallelized project Git-health reads through a bounded six-project worker pool, with an eight-second per-command limit, so one slow or cloud-backed worktree cannot serialize the entire discovery result.
- Expanded CODEX project search and summary counts with IDE-link and Git-main status, including an unavailable state that avoids presenting an unreadable Codex registry or timed-out Git check as a confirmed result.

## 0.5.17

- Added a verified repeat-run cache to CODEX Auto All. When transfer settings and roots match a saved plan, CSA-iEM validates the current source-to-destination state with native rsync and returns a zero-copy plan without rebuilding both Swift file trees. Changed projects automatically fall back to the complete index.
- Added a true no-op execution path for unchanged existing destinations when no backup, Git re-arm, bidirectional sync, or source removal is requested.
- Added automatic preparation of planned iCloud placeholders in bounded parallel batches before transfer. The UI reports download progress, stalled batches time out and clean up their workers, and transient local-provider rsync failures receive narrow retries without relaxing conflict or checksum gates.
- Prevented rsync's informational `skipping non-regular file` message for live Git fsmonitor sockets from being parsed as a changed project path, allowing socket-bearing repositories to use the verified zero-delta cache.
- Saved the CODEX portal's local output folder, transfer mode, and transfer safety toggles across app upgrades and relaunches. These preferences contain paths and booleans only; project content, prompts, GitHub identity, and credentials remain outside app storage.

## 0.5.16

- Replaced the CODEX preflight write probe's Foundation protected-temporary-file path with a direct POSIX `touch` check. This prevents the native UI from freezing inside `FileManager.createFile` on writable external volumes while preserving the same fail-closed output-folder gate.

## 0.5.15

- Made CODEX transfers portable across volumes when a project contains live Unix sockets, named pipes, or device nodes. The virtual file table now records directories, regular files, and symlinks only; rsync explicitly omits runtime-only special nodes, and checksum verification continues to fail closed for every portable project path.
- Fixed Git repositories with an active `.git/fsmonitor--daemon.ipc` socket so Full Auto no longer stops with `mkstempsock: Invalid argument`.

## 0.5.14

- Fixed staged and final checksum verification for projects containing symbolic links. Verification now preserves and compares link targets instead of treating valid links as skipped non-regular files; real missing, changed, or wrong-target links still fail closed.

## 0.5.13

- Expanded the CODEX transfer fast-path filter so virtual preflight and rsync both skip rebuildable dependency trees, compiler output, framework build folders, coverage, and tool caches when generated content is disabled. This prevents large `dist`, `.build`, `DerivedData`, and cache trees from dominating Auto All while preserving source files, Git metadata, Finder metadata, and project assets.
- Renamed the portal control and transfer-note field to make build-output handling explicit; generated content can still be included deliberately for a byte-for-byte archival transfer.

## 0.5.12

- Aligned the fast CODEX transfer index with macOS rsync's whole-second timestamp precision. Checksum-identical files whose destination timestamp lost only fractional seconds are now skipped instead of being recopied on every Auto All resume.

## 0.5.11

- Fixed targeted checksum verification on existing destinations so external-filesystem directory timestamp normalization does not stop an otherwise exact transfer. Regular files, symlinks, missing paths, and type conflicts remain fail-closed.

## 0.5.10

- Made CODEX ~ GPT PORTAL Auto All destination-aware by Git identity. When a project already exists under an older folder name, the preflight now reuses the one matching destination instead of scheduling a duplicate initial mirror.
- Auto All now leaves folders explicitly marked as bad, prior move sources, partial backups, and randomized temporary work clones available for manual selection without including them in the automatic batch.
- Added fail-closed Git identity checks for same-name destinations, ambiguous external-drive matches, and multiple active sources that could otherwise write to one project folder.

## 0.5.9

- Saves the CODEX ~ GPT PORTAL's custom scan-root list locally. A pasted, picked, or dropped folder remains available after the app restarts without saving GitHub identity, credentials, prompt contents, or project files.

## 0.5.8

- Added explicit custom project-search roots to the CODEX ~ GPT PORTAL: paste a readable folder path, choose a folder, or drag and drop one or more Finder folders. The scanner retains its evidence requirement, so adding Documents as a search boundary does not classify every subfolder as a Codex project.

## 0.5.7

- Made selected-folder discovery deterministic and fast. CSA-iEM now scans the selected source folders' on-disk context first and skips expensive Codex session-history parsing when a source scope is present, so unlinked projects are not held behind large or cloud-backed session JSONL files.

## 0.5.6

- Fixed index path handling on macOS paths such as `/tmp` that Foundation resolves through `/private`. The walker now retains the filesystem-provided relative path (for example, `src/changed.txt`) in the saved JSON table and in targeted rsync manifests.

## 0.5.5

- Fixed index recursion for projects that contain symlinks. The virtual file table now continues through ordinary project directories after recording a symlink, so nested source files, generated folders when included, and empty directories are all represented in the preflight plan.

## 0.5.4

- Added index-first preflight for the CODEX ~ GPT PORTAL. Before execution, CSA-iEM now records a source file table, destination file table when present, and a transfer plan JSON under the selected output folder's `_temp/Transfer-Indexes` directory.
- Existing destinations now use a targeted `rsync --files-from` manifest so repeat Copy, Scan & Backup, and Sync and Move runs transfer only missing, metadata-changed, or deep-audit-failed paths instead of re-copying the full project tree.
- Added an optional deep checksum audit for metadata-matched paths. Fast preflight compares relative path, type, size, date, and symlink target; the deep audit is available when an operator needs to detect same-size, same-date content changes and accepts the full read cost.
- Kept the stronger safety boundary for destructive moves: Sync and Move still runs a full checksum comparison before it can retire a source. A new output folder also still requires one complete staged baseline mirror because no destination files exist yet to skip.
- Expanded discovery beyond active Codex session links. The portal now recognizes project-folder context from Git, manifests, source folders, editor settings, Docker/config files, managed-workspace folders, and prior transfer notes; it can fall back to common Documents, development, Codex worktree, and mounted-drive locations.
- Added the on-screen virtual file table, index-folder reveal action, preflight indexing progress, targeted-transfer status, and safe blocking for file-versus-folder conflicts.

## 0.5.3

- Expanded the CODEX ~ GPT PORTAL to five explicit transfer modes: Backup Only, Copy to Output, Sync and Move, Sync and Sync, and Scan & Backup (Auto Merge).
- Added fast bidirectional reconciliation that uses rsync metadata dry-run candidates, timestamp fast paths, and one exact verification pass for ambiguous files.
- Added auto-heal behavior for one-sided changes, verified pre-sync backups for both folders, conflict quarantine under `_temp`, and `Conflict_Report.MD` with both preserved file versions.
- Sync and Move now resumes existing destinations automatically and removes the source only after final verification; Sync and Sync never removes either side.
- Scan & Backup always creates a verified archive while merging missing or changed source files into the output and retaining destination-only recovery data.

## 0.5.2

- Added Auto All for the CODEX ~ GPT PORTAL: select every discovered project and enable destination-aware resume in one action.
- Existing destination folders are now reconciled with checksum-aware rsync; identical files stay in place, missing or changed files are copied, and existing destination-only files are preserved.
- Added resume-aware progress summaries, reconciled-file counts, destination safety checks, and resumable failure behavior for interrupted multi-project transfers.

## 0.5.1

- Fixed Codex project transfers so the rsync process drains output without pipe deadlocks and preserves complete generic project trees, including optional `.git`, `node_modules`, `.DS_Store`, and `._*` files.
- Added a generic post-copy Git recovery path that fetches the detected `origin/main`, activates local `main`, rebuilds only the Git index, and preserves the transferred working tree without checkout or overwrite.
- Added explicit Finder-metadata and Git-main-rearm controls to the macOS CODEX ~ GPT PORTAL and carried the settings into `Transfer_Note.MD` and `Prompt_Inject.MD`.
- Bumped the installed macOS app, CLI, toolbar, and Windows-shipped version metadata to `0.5.1`.

## 0.5.0

- Added the native `CODEX ~ GPT PORTAL` for discovering projects from local Codex session history and multiple operator-selected scan roots.
- Added one, multi, visible, and all-project selection with search, Finder, Codex, and Visual Studio Code quick actions.
- Added preflighted Backup Only, Copy, and Move workflows with isolated `_temp` staging, checksum comparison, verified ZIP backups, optional `.git` and generated-dependency preservation, and source removal only after final verification.
- Added per-project `Transfer_Note.MD` and `Prompt_Inject.MD` handoff files so relocated projects carry their source, destination, Git, dependency, verification, and reconnect context.
- Added opt-in Administrator Terminal mode. CLI launchers use a visible `sudo -v` authorization gate and never read, type, store, or log the administrator password.

## 0.4.9

- Fixed macOS upgrade hygiene: the installer now stops the old app, replaces the canonical app bundle, removes stale CSA-iEM/CSA-iLEM backup bundles, and reloads the single toolbar launch agent.

## 0.4.8

- Fixed macOS launch persistence: after the local agreement/startup check is completed, future launches open directly to the app instead of repeatedly reopening the splash or startup sheet.

## 0.4.7

- Added external-drive Default workspace controls: save a stable `DRIVE/CSA-iEM` path without touching files, prepare a full relocation preview, move all workspace roots after explicit confirmation, reveal the new workspace, and restore internal default paths without moving data.
- Added workspace-size feedback, external-drive default controls in both macOS toolbar surfaces, Windows external-drive discovery/default/move CLI support, and Windows tray entry points.

## 0.4.6

- added mounted external-drive selection to the Local Files page and macOS toolbar, with capacity display and one-click destination selection
- added CLI external-drive list, full-workspace backup/move, and repeatable selected-project backup/move commands
- added a Privacy-First startup readiness check with Auto Fix, manual setup guidance, and Ignore and Continue choices
- stopped using legacy GitHub session files to prefill macOS app identity or repository targets; saved GitHub contexts are disabled by default and active identities are redacted from GUI logs
- added a native GitHub Billing Reports page for Actions minutes, paid minute usage, storage, Packages, and per-project Actions activity signals
- added GitHub billing usage and billing-summary shortcuts to both macOS toolbar menus
- wired the AppDelegate to the shared GUI model at launch so the native status-bar toolbar is installed with its runner controls
- added Stop All Active Runners to the native status-bar toolbar menu
- added matching Windows CLI and tray entry points for GitHub billing and Actions usage reports, plus tray stop-all runner control

## 0.4.3

- expanded the macOS toolbar into a window-style mini control app instead of a plain dropdown menu
- added toolbar quick actions for opening the loaded repo in VS Code, Codex, GitHub Copilot, Finder, the CLI, or the project browser
- added toolbar active-container controls for opening the linked workspace, viewing logs, and stopping the container
- kept runner fleet controls in the toolbar, including stop-all, start-only, open-in-VS-Code, open-in-Codex, reveal, start, stop, and restart

## 0.4.2

- fixed GUI-launched Terminal fallback windows so they stay open after auto-confirmed CLI runs
- changed the Terminal hold prompt to accept Enter or `y`, which keeps custom shell/security prompts visible instead of closing immediately

## 0.4.1

- added auto-confirm support for simple terminal yes/no gates during GUI-launched CLI work and Terminal fallback commands
- added Settings control for auto-confirming terminal gates, with sudo/password/auth prompts treated as manual security gates
- taught the macOS CLI and installer scripts to honor `CSA_IEM_AUTO_CONFIRM_TERMINAL_GATES=1`

## 0.4.0

- added toolbar and GUI runner fleet controls: stop all active runners and start only one selected runner
- added old workspace migration scanning for previous Diamond, WTL, CSA-iLEM, and saved profile roots
- added copy-or-move migration into the active Default or Custom workspace roots, including project and runner folders
- changed the menu-bar extra label to a visible `CSA` badge so the toolbar is easier to find

## 0.3.9

- changed the macOS toolbar to a native SwiftUI `MenuBarExtra` so it appears independently from the main window lifecycle
- keeps the same toolbar actions for opening CSA-iEM, opening the CLI/project browser, inspecting workspace roots, and controlling local GitHub Actions runner services

## 0.3.8

- fixed macOS updates so they build and install `CSA-iEM.app` automatically instead of only updating CLI files
- installs the app into `/Applications` when possible or `~/Applications` as a user-safe fallback
- starts the app after install and registers a LaunchAgent so the menu-bar toolbar appears after update and returns at login
- updated `csa-iem-gui` to prefer the installed Applications app before falling back to the versioned build folder

## 0.3.7

- simplified workspace selection to Default and Custom modes and removed WTL/Diamond/Public presets from the active install and user-facing help
- fixed `openproj` so stale Diamond/WTL config can no longer force inaccessible external-volume roots
- added CLI `--auto-mode` and a GUI Auto Mode action for using the Default workspace/current roots without extra workspace prompts

## 0.3.6

- added a native macOS menu-bar toolbar for opening CSA-iEM, launching the CLI/project browser, inspecting loaded workspace roots, and controlling local GitHub Actions runner services
- added a Windows notification-area tray companion with `csa-iem-tray` for opening CSA-iEM/OpenProject tooling and starting, stopping, or restarting installed `actions.runner.*` services
- changed macOS and Windows installs so the latest install command also updates by default, replaces the target version, repoints the active install marker, and removes older installed version folders
- updated README installer guidance and refreshed checksum metadata for the `0.3.6` release

## 0.3.5

- repaired Windows imports for repositories that contain Windows-incompatible checkout paths by excluding only the invalid paths instead of failing the whole run
- fixed the Windows FULL AUTO devcontainer startup check so successful runs no longer produce a false failure warning
- fixed Windows Docker Desktop startup from `openproj` and other devcontainer entry points by resolving the actual installed Docker Desktop executable path and waiting for the engine to come online before falling back to manual retry prompts
- added macOS updater command parity by shipping installed `csa-iem-update` and `csa-ilem-update` wrappers on macOS
- refreshed install, update, and release metadata so the macOS GUI bundle, Windows installer/update help text, and shipped docs all report the `0.3.5` release consistently

## 0.3.4

- improved shell PATH persistence on macOS installs by updating common startup files for `zsh`, `bash`, and generic profile loading
- added clearer end-of-install guidance for cases where a newly opened shell still has not picked up `~/.local/bin` yet
- updated the stable public install commands and versioned install paths to `0.3.4`

## 0.3.3

- fixed remaining hardcoded version fallbacks in the main CLI backend, GUI helpers, and macOS app so installed builds report the correct stable version
- updated the stable public install commands and versioned install paths to `0.3.3`

## 0.3.2

- fixed the stable release packaging so the checksum manifest matches the published GitHub source archive
- updated the stable public install commands and versioned install paths to `0.3.2`

## 0.3.1

- improved the macOS installer messaging when `@devcontainers/cli` cannot be installed into the system npm prefix
- added a clearer fallback message that tells the user CSA-iEM is retrying with a user-local install path and does not usually need admin rights
- updated the stable public install commands and versioned install paths to `0.3.1`

## 0.3.0

- fixed the macOS installer so Dev Containers CLI falls back to a user-local npm prefix when the system npm global prefix is not writable
- updated the installer output and docs with a stable release install command that matches the published tag
- added a Windows 11 admin-shell PowerShell backend in `CSA-iEM.ps1` for interactive and direct import, cleanup, browsing, devcontainer, workflow patching, and self-hosted runner flows
- added Windows-native install, uninstall, and remote install scripts: `install.ps1`, `uninstall.ps1`, and `install-remote.ps1`
- updated the public product docs so `CSA-iEM` is described as a cross-platform toolset: macOS GUI plus Windows 11 admin-shell operations
- started shipping Windows notes and Windows scripts inside the installed source bundle and packaged macOS app resources
- bumped the production version to `0.3.0`

## 0.2.6

- taught `install.sh` to scan for missing Mac dependencies and bootstrap them when possible
- added automatic Homebrew, git, GitHub CLI, Node.js, npm-based Dev Containers CLI, VS Code, and Docker Desktop detection/install handling
- added `code` and `docker` CLI linking from installed app bundles when the apps exist but the shell command is missing
- added `--no-deps` to skip dependency bootstrap when you want a pure file install only

## 0.2.5

- added a native `Import` page to the macOS GUI so repository import is now a first-class on-screen workflow instead of being cleanup-only
- added direct CLI import flags for GUI/background execution: `--import-mode`, `--import-full-auto`, and `--import-cleanup-preview`
- wired GUI imports to the bundled CLI backend as background jobs using the selected GitHub account, selected repositories, and current workspace roots
- fixed the installed `csa-iem-open` and `csa-ilem-open` wrappers so they follow the detected/saved workspace instead of forcing the public profile

## 0.2.4

- changed `csa-iem-gui` to open the native `.app` bundle by default instead of running the SwiftUI target in the foreground through `swift run`
- made `csa-iem-gui` auto-build the app bundle if it does not exist yet, so installed Macs launch the GUI like a normal app
- kept `--source-run` as an explicit debug path for direct Swift target execution
- updated versioned install and product docs for the `0.2.4` GUI launch fix

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
