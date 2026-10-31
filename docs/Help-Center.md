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
- compare local checkouts against live GitHub identity and file evidence, then preserve a reviewed extra checkout in recoverable storage
- detect old source leftovers, including dependency-only folders, hidden files, and incomplete cleanup

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

## Checkout Review & Recovery

Open **Projects** or **Local Files** to find **Checkout Review & Recovery**.
Choose the keeper and other checkout, or use a selected local project and a
similar-name suggestion, then select **Compare with GitHub**. The review shows
sanitized configured origins, live GitHub repository IDs and default-branch
file evidence, local Git changes, and a comparison of all physical entries.
Similar folder names may belong to different GitHub repositories. A configured
origin is a local identity claim; the live provider result is shown separately.
Matching working-file bytes do not establish matching commit history, so the
history status remains a separate finding.

After reviewing the evidence, arm **Retire Other Checkout to Recovery** to move
the complete other checkout into the configured Runtime recovery area on the
same volume. Hidden files, dependencies, Git metadata, links, and extended
attributes remain in the preserved checkout. Fresh verification, protected-root,
active-use, and shared-worktree checks can block retirement. The keeper and
GitHub repositories remain unchanged. The recovery path and receipt survive a
restart; **Restore Retired Checkout** verifies the preserved tree and refuses
to overwrite an existing original path.

Exact native transaction staging and backup names are listed separately from
active projects. Use Staging & Backup Cleanup for their own comparison and
recoverable preservation. Their names alone do not authorize cleanup.

## Staging & Backup Cleanup

Open **Projects** or **Local Files** and select **Review Staging / Backup
Folders**. Every reviewed row remains visible, including blocked items and
their reasons. The app recognizes exact transaction-shaped stage and backup
names, then compares complete source and canonical manifests. This includes
file hashes, hidden and generated content, links, and extended attributes.
Matching names or working bytes alone do not establish which historical run
left a folder behind. Older workflows, including the 0.2.3-era naming form,
can leave recognizable folders without proving a particular failure cause.

**Preserve & Clean Reviewed Folders** removes eligible entries from active
repository locations by moving each complete tree into same-volume
`Runtime/Recovery/TransferArtifacts` storage. The canonical checkout is checked
again and remains unchanged; unique or different source content stays in the
preserved tree. Active use, shared Git storage, cloud placeholders, unreadable
entries, and protected source paths block the affected item. A protected
canonical checkout may be read for verification but is never overwritten.
Each successful item has a verified receipt and its own restore action;
restoration refuses to overwrite an existing original path. Partial failures
remain visible and do not discard successful preservation receipts.

The toggle **Automatically preserve and clean staging / backup folders after
successful local runs** is off by default. Enable it to request the same
verified workflow after eligible non-dry-run imports, native workspace
migrations/exports, CODEX transfers or Full Auto, and applied GitHub cleanup.
The pass waits for other mutating app jobs to finish. It never starts from
startup, read-only scans, failed or cancelled runs, restore/undo, or another
artifact pass. A migration cleanup warning can also receive this check;
remaining original source paths still retain **Cleanup incomplete**. Standalone
Terminal Stage 2/3 sessions are not observed completion triggers.

Full manifests and per-item evidence are saved under
`Runtime/Reports/TransferArtifacts`. A lightweight Application Support session
pointer is saved before moves begin. After a crash or interruption, use
**Verify Interrupted Cleanup** to verify prepared or archived receipts and
recover the recorded results. This action starts no new moves. Items still in
their original locations require a fresh review before another cleanup pass.

## Old Source Leftovers

Use **Scan Old Source Leftovers** in **Local Files** or **Jobs**. Leave the
source field blank to scan known old roots, or enter one exact old folder.
This read-only metadata scan includes hidden and dependency entries even when
normal project discovery finds no repository or manifest. It does not read
file payloads, follow directory symlinks, or download cloud placeholders.
Unreadable entries and time, depth, or entry limits remain explicitly unverified.

Native moves recheck the physical old source after cleanup. Any retained root
is reported as **Cleanup incomplete**, with a saved source-specific report in
`Application Support/CSA-iEM/source-residuals.json`. A warning survives an app
restart; scan again after recovery or removal to verify the current state.
**Verified absent** requires a successful fresh check of that exact path.
The scan does not prove that another copy preserves every file: checksum
preservation and the appropriate cleanup confirmation are still required.

## CODEX Dashboard Quick Start

### Dashboard and module matrix

CSA-iEM uses one native dashboard grammar across every page. The top bar owns
navigation and the hamburger/sidebar state; the page body owns the current
workflow; and the bottom status bar remains fixed while the page content
scrolls. On narrow windows the sidebar becomes a compact horizontal menu.
Page scrolling is explicit and keeps its vertical indicator visible so long
forms and operational panels do not hide their position.

The shared matrix strip identifies the installed app version, matrix revision,
and primary module count. Home expands it into the full matrix. Each entry has
an area, version, stable tag, state, and last-updated date. Use the matrix when
triaging a broken page or runtime: compare the tag first, then the module
version, then the relevant job/receipt log. The canonical matrix is maintained
in [`docs/wiki/CSA-iLEM-Dashboard-and-Module-Matrix.md`](./wiki/CSA-iLEM-Dashboard-and-Module-Matrix.md).

The CODEX control plane is organized left to right:

1. **Import Sources** on the left: add one folder, a bounded set of source
   folders, or a saved scan root. Scan is read-only.
2. **Smart Logic** in the middle: review identity, branch, local-change,
   cache, and ambiguity evidence. A same-name folder is not automatically a
   repository.
3. **Final Output** on the right: choose one destination for the project
   identity. Extra, unknown, or quarantined material is routed to
   .SYSTEMX/Archive_Data.

Use Fast Index for ordinary work, Full Verification when identity or integrity
is uncertain, and YOLO / Skip Deep Preflight only for a non-destructive Backup
or Copy. YOLO never bypasses the existing final write verification and cannot
run Stage 2, Stage 3, source retirement, or Full Auto.

The Project Backups page composes the same import, index, transfer, Stage 2,
Stage 3, Jobs, snapshots, and recovery controls. It does not create a second
backup engine. Saved Transfer-Indexes tables are reused when the current source
and destination still match, so a later session can recheck only changed
folders instead of rescanning every project.

Each source scan also writes a versioned Smart Logic decision table to the
selected output root under `.SYSTEMX/Index/catalog.sqlite`. JSON and CSV
exports are written beside the catalog for manual review. The catalog records
source evidence, identity classification, confidence, reasons, session ID, and
Stage 1 preflight checkpoints. A normalized configured Git origin is required
for origin-based grouping; live provider verification is a separate check.
Same-name, broken-metadata, shadow-copy, dirty, or
unknown-owner folders remain review-only.

When multiple sources share one normalized configured origin, Smart Logic presents an
explicit **Use as canonical** action for each identity group. Select exactly one
source per group before a merge or move preflight. The choice is local to the
current decision session, clears when the source selection changes, and never
authorizes a write by itself. Dirty sources, non-main branches, and external
unlinked copies remain visible in the decision reasons so the operator can
choose the intended lead repository deliberately.

The Backup Medium selector controls the artifact created by Project Backups.
Raw directory snapshots are the canonical no-repackaging form and are copied
and checksum-verified. APFS clone uses macOS `cp -cR` and is verified when the
destination supports clones. Sparse-image mode uses `hdiutil`, mounts the
image read-only, and verifies the mounted tree before it is accepted. Verified
ZIP remains an optional portable interchange artifact. Selecting a medium
never overrides the existing final verification or cleanup gates; an
unsupported APFS or image operation fails safely and retains the source.

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

Among Stage 1 transfer modes, only Sync and Move retires the source, and only after staged and final checksum verification succeeds. It always performs a full checksum comparison before source retirement, even when the fast index says no copy is needed. If Fast Mode discovers a rare same-size, same-date content change only during that final audit, it checksum-preserves the prior destination version, copies just the affected path, and repeats whole-tree verification before issuing any cleanup-capable receipt. A brand-new destination also needs one complete staged baseline mirror because there are no existing files to skip. The compatibility-link option keeps the old filesystem path pointing to the new destination. Backup Only, Copy to Output, Sync and Sync, and Scan & Backup retain recoverable originals. Full Auto can separately request receipt-linked Stage 3 deletion; Checkout Review uses the reversible recovery workflow described above.

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

Privacy-First Mode does not persist background GitHub account identity, owner repository catalogs, organizations, tokens, or API keys. Workspace paths, local UI preferences, task templates, favorites, saved views, and accepted onboarding state can be stored in the local application-support profile. Explicit checkout reviews save sanitized repository identity, file metadata, hashes, and recovery receipts locally; the preserved checkout itself remains in the displayed recovery folder. Staging/backup cleanup stores complete manifests and receipts in the displayed Runtime report/recovery folders, with a small session pointer and automation preference in Application Support. Old-source scan reports save paths, metadata counts, and review status. Administrator Terminal mode is stored as a local boolean preference only.

## Support

Provided by Wayne Tech Lab LLC  
[www.WayneTechLab.com](https://www.WayneTechLab.com)
