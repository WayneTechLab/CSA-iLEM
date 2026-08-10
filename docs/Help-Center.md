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

The portal scans selected folders first using on-disk project context, then uses local Codex session history only when no source folder has been selected. It can also scan common local/external development locations. It reads Codex's local project registry only to distinguish the selected active workspace, other currently linked projects, and unlinked disk projects. It does not upload Codex history, Git data, prompts, or credentials.

Use the portal to:

- select one project, several projects, all visible results, or every discovered project
- use Auto All to select active discovered projects, reuse a uniquely matching Git destination even when its folder was renamed, and resume existing destination folders; clearly marked bad, moved-backup, partial-backup, and randomized temporary work folders remain visible for manual selection
- add a custom search root by pasting a readable parent-folder path, choosing a folder, or dropping one or more Finder folders onto `Drop Folder`; the local root list is saved across restarts and folders are offered only when they have project evidence
- find unlinked projects from Git, manifests, source folders, editor settings, Docker/config files, managed-workspace folders, or existing transfer notes; use `Common Folders` to add Documents, development, Codex worktree, and mounted-drive locations
- read `Active here` as the selected local Codex desktop project, `Codex linked` as another current local-project registry entry, and `Unlinked` as a folder found only by filesystem discovery; historical tasks and saved workspace-root history do not count as current links
- use the `Main` badge to compare the current `HEAD` with the locally stored `origin/main` reference and `Local changes` to identify tracked or untracked worktree changes. Checks run through a bounded parallel pool; the scan is read-only and never fetches, checks out, resets, or changes Git configuration.
- search by name, path, branch, Git remote, or project marker
- open a project in Finder, Codex, or Visual Studio Code
- preserve `.git`, Finder sidecars, and generated handoff notes, or re-arm a copied working tree to its detected `origin/main` by rebuilding only the Git index without checkout/reset
- keep `Include generated dependencies and build outputs` off for the fast transfer path. Preflight and rsync then omit rebuildable dependency trees, compiler output, framework build folders, coverage, and tool caches together; turn it on only when the archive must carry those generated files too.
- Preflight writes source and destination file-index JSON plus a transfer plan to the output folder's `_temp/Transfer-Indexes` directory. The on-screen table shows indexed entries, planned paths, and destination-only data before a transfer begins.
- after one complete index establishes a zero-delta plan, repeat Auto All runs validate that saved plan with native rsync. A `Verified cache` row means no path needs transfer; a detected change automatically rebuilds the complete source and destination indexes.
- auto-resume uses an rsync targeted path manifest: metadata-matched files remain in place, missing or changed files are copied, and destination-only files are retained without re-copying the full project tree
- fast comparison checks relative path, type, size, whole-second date, and symlink target to match macOS rsync's timestamp precision. Use `Deep checksum audit metadata-matched files` to detect rare same-size, same-second content changes; it deliberately reads every metadata-matched file and can take as long as a full integrity scan.
- exact verification allows ordinary directory timestamps to differ when an external filesystem normalizes them; regular files, symlink targets, missing paths, and file-versus-folder conflicts must still verify exactly
- live Unix sockets, named pipes, and device nodes are runtime endpoints and are not portable project files. The portal omits them from both preflight and transfer; Git recreates its fsmonitor socket when the destination repository is opened.
- choose one of five transfer modes: Backup Only, Copy to Output, Sync and Move, Sync and Sync, or Scan & Backup (Auto Merge)
- Sync and Move automatically reconciles an existing destination and removes the source only after final verification
- Sync and Sync reconciles one-sided changes in both directions, uses metadata and timestamps before one exact verification pass, and never overwrites an equal-timestamp conflict
- conflicts are copied to an output `_temp` quarantine with `Conflict_Report.MD`; Scan & Backup also creates verified recovery archives before merging
- run preflight before any file operation
- preflight checks external-folder write access with a direct local filesystem probe before building any transfer index
- planned iCloud placeholders are downloaded before rsync in small parallel batches. Progress is shown in the portal, each batch has a timeout, and transient File Provider failures are retried without retrying permission or integrity failures.
- the selected output folder, transfer mode, and transfer safety switches are local preferences and survive app updates. CSA-iEM does not put project content, prompts, GitHub account identity, tokens, or API keys into those preferences.
- create a verified ZIP backup without moving the source
- copy or move through an isolated `_temp` staging folder
- preserve `.git` and generated dependency/build folders when explicitly selected
- generate `Transfer_Note.MD` and `Prompt_Inject.MD` for each project
- save one Stage 1 receipt per verified project under `_temp/Transfer-Receipts`; later stages use these exact paths instead of treating every folder as disposable

Only Sync and Move removes the source, and only after staged and final checksum verification succeeds. It always performs a full checksum comparison before source retirement, even when the fast index says no copy is needed. If Fast Mode discovers a rare same-size, same-date content change only during that final audit, it checksum-preserves the prior destination version, copies just the affected path, and repeats whole-tree verification before issuing any cleanup-capable receipt. A brand-new destination also needs one complete staged baseline mirror because there are no existing files to skip. The compatibility-link option keeps the old filesystem path pointing to the new destination. Backup Only, Copy to Output, Sync and Sync, and Scan & Backup retain recoverable originals.

## Stage 2 Managed Workspace

Use Stage 2 after the portal has preserved projects in a `CODEX PROJECTS` folder. Set the Stage 1 source and managed CSA-iEM root, scan the source, then choose selected projects or Full Auto.

Stage 2 checks GitHub repository ID, canonical owner/name, default branch, archived state, remote HEAD, local status, and commit ancestry before it changes a canonical project. It automatically excludes the active CSA-iEM checkout and blocks dirty or staged destinations, dirty source merges into an existing project, duplicate identities, archived repositories, identity conflicts, and divergent or unverified history.

New canonical projects are staged under `Import/Stage2`, verified, and promoted to `Code/Repos/<owner>/<repo>`. Existing clean projects receive only proven fast-forwards and additive missing-file healing. Reports are written to `Runtime/Reports/Stage2`.

Optional controls can create a private empty GitHub repository without uploading files, prepare a `Runtime/Repos` mirror, create and test a source ZIP, keep or retire the intermediate folder, permanently delete it after two verification passes, clean the successful transaction, or open the managed project in Codex, Visual Studio Code, GitHub Copilot, Finder, or a devcontainer.

```bash
csa-iem stage2 --source "/path/to/CODEX PROJECTS" --managed-root "/path/to/CSA-iEM" --preflight --all
csa-iem stage2 --source "/path/to/CODEX PROJECTS" --managed-root "/path/to/CSA-iEM" --apply --project "/path/to/project" --yes
csa-iem stage2 --source "/path/to/CODEX PROJECTS" --managed-root "/path/to/CSA-iEM" --full-auto --yes
```

## Stage 3 and Full Auto Lifecycle

The Full Auto Lifecycle panel runs the selected Stage 1 transfer mode for Selected Projects or All Eligible Projects, requires a receipt from every project, sends only those verified destinations into Stage 2, and then preflights Stage 3 from the exact current-run receipts. The active CSA-iEM project is never part of All Eligible Projects.

Choose Stage 1 ZIP, Stage 1 original deletion, Stage 2 on/off, Stage 2 ZIP, Stage 2 Keep/Retire/Delete, and Stage 3 Keep/Current Transaction/All Verified Temp independently. The lifecycle must be armed before execution.

Stage 3 can also run by itself:

```bash
csa-iem stage3 --source "/path/to/CODEX PROJECTS" --managed-root "/path/to/CSA-iEM" --preflight --all --cleanup-all-verified-temp
csa-iem stage3 --source "/path/to/CODEX PROJECTS" --managed-root "/path/to/CSA-iEM" --apply --receipt "/path/to/project.receipt" --delete-stage1-originals --yes --confirm-delete VERIFIED-STAGE3
```

Every permanent source action uses receipt validation, a fresh source-to-destination or tested-ZIP check, same-volume quarantine, a second check, and an explicit confirmation token. Stage 3 never removes canonical repositories, archives, reports, receipts, active CSA-iEM, failed transactions, or unreferenced temporary folders.

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
