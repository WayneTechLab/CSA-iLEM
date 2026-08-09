# CSA-iEM Help Center

## What This App Does

`CSA-iEM` is a macOS operations tool for moving GitHub repo, Actions, and Codespaces-style workflows into local development and self-hosted runner environments.

It can:

- verify `gh` authentication first
- show authenticated GitHub hosts and accounts
- list repositories for an owner or organization
- import repos into Public, WTL, or Diamond layouts
- prepare local devcontainers
- install and manage repo-level self-hosted runners
- patch workflow `runs-on` values to self-hosted labels
- run cleanup for workflows, runs, artifacts, caches, and Codespaces
- review projects one at a time for cost control
- discover and transfer local Codex projects with verified backups and handoff notes

## Safe First Run

1. Install GitHub CLI if it is not already present.
2. Authenticate with `gh auth login -h github.com`.
3. Open the app and review the warning and Terms screen.
4. Select the correct GitHub host and account.
5. Pick the correct Default or Custom workspace root.
6. Use `Dry run` first for destructive cleanup.
7. Review the live output before applying permanent changes.

## Workspaces

- `Default`: portable `Code`, `Import`, and `Runtime` roots under `~/CSA-iEM`
- `Custom`: operator-selected roots, including mounted external drives

## CODEX ~ GPT PORTAL

The portal scans selected folders first using on-disk project context, then uses local Codex session history only when no source folder has been selected. It can also scan common local/external development locations. It does not upload Codex history, Git data, prompts, or credentials.

Use the portal to:

- select one project, several projects, all visible results, or every discovered project
- use Auto All to select every discovered project and resume existing destination folders
- add a custom search root by pasting a readable parent-folder path, choosing a folder, or dropping one or more Finder folders onto `Drop Folder`; the local root list is saved across restarts and folders are offered only when they have project evidence
- find unlinked projects from Git, manifests, source folders, editor settings, Docker/config files, managed-workspace folders, or existing transfer notes; use `Common Folders` to add Documents, development, Codex worktree, and mounted-drive locations
- search by name, path, branch, Git remote, or project marker
- open a project in Finder, Codex, or Visual Studio Code
- preserve `.git`, dependency trees, Finder sidecars, and generated handoff notes, or re-arm a copied working tree to its detected `origin/main` by rebuilding only the Git index without checkout/reset
- Preflight writes source and destination file-index JSON plus a transfer plan to the output folder's `_temp/Transfer-Indexes` directory. The on-screen table shows indexed entries, planned paths, and destination-only data before a transfer begins.
- auto-resume uses an rsync targeted path manifest: metadata-matched files remain in place, missing or changed files are copied, and destination-only files are retained without re-copying the full project tree
- fast comparison checks relative path, type, size, date, and symlink target. Use `Deep checksum audit metadata-matched files` to detect rare same-size, same-date content changes; it deliberately reads every metadata-matched file and can take as long as a full integrity scan.
- choose one of five transfer modes: Backup Only, Copy to Output, Sync and Move, Sync and Sync, or Scan & Backup (Auto Merge)
- Sync and Move automatically reconciles an existing destination and removes the source only after final verification
- Sync and Sync reconciles one-sided changes in both directions, uses metadata and timestamps before one exact verification pass, and never overwrites an equal-timestamp conflict
- conflicts are copied to an output `_temp` quarantine with `Conflict_Report.MD`; Scan & Backup also creates verified recovery archives before merging
- run preflight before any file operation
- create a verified ZIP backup without moving the source
- copy or move through an isolated `_temp` staging folder
- preserve `.git` and generated dependency folders when explicitly selected
- generate `Transfer_Note.MD` and `Prompt_Inject.MD` for each project

Only Sync and Move removes the source, and only after staged and final checksum verification succeeds. It always performs a full checksum comparison before source retirement, even when the fast index says no copy is needed. A brand-new destination also needs one complete staged baseline mirror because there are no existing files to skip. The compatibility-link option keeps the old filesystem path pointing to the new destination. Backup Only, Copy to Output, Sync and Sync, and Scan & Backup retain recoverable originals.

## Administrator Terminal

Administrator Terminal mode is off by default. When enabled in Settings, CLI launchers open a visible Terminal and run `sudo -v` before continuing. CSA-iEM does not read, type, store, or log administrator passwords. This option does not bypass macOS privacy controls or disk permissions.

## Cleanup Scope

You can run:

- full cleanup
- workflows only
- runs only
- artifacts only
- caches only
- Codespaces only
- one specific run by ID or run URL
- filtered runs by name text

## Direct CLI Cleanup

The CLI also supports cleaner-style direct cleanup commands such as:

- `--host`
- `--account`
- `--repo`
- `--disable-workflows`
- `--delete-runs`
- `--run`
- `--run-filter`
- `--delete-artifacts`
- `--delete-caches`
- `--delete-codespaces`
- `--all`
- `--dry-run`
- `--yes`

## Cost Control

From the project browser, the one-by-one cost-control review can:

- disable GitHub Actions in repo settings
- disable workflows
- delete runs, artifacts, caches, and Codespaces
- stop local runner services
- stop active local devcontainer containers
- patch workflows to self-hosted labels

## Stored Data

Privacy-First Mode does not persist GitHub account identity, repository inventory, organizations, tokens, or API keys. Workspace paths, local UI preferences, task templates, favorites, saved views, and accepted onboarding state can be stored in the local application-support profile. Administrator Terminal mode is stored as a local boolean preference only.

## Support

Provided by Wayne Tech Lab LLC  
[www.WayneTechLab.com](https://www.WayneTechLab.com)
