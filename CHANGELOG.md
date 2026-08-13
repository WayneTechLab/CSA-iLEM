# Changelog

## Unreleased

- Added Phase 13.25 compatibility states for retained evidence imports, distinguishing complete profile metadata from partial metadata and legacy exports in the native inspection UI.
- Added Phase 13.26 deterministic Smart Logic route plans showing metadata triage, targeted verification, and deep-scan avoidance before an operation is run.
- Added Phase 13.27 SQLite-backed per-source route receipts with planned, skipped, completed, interrupted, and failed states so stopped operations retain resumable route evidence.
- Added Phase 13.28 selective resume for pending route receipts; completed and skipped sources stay outside the resumed run and the prior operator selection is restored afterward.
- Added Phase 13.29 receipt-level resume audit preview showing pending paths, route, state, attempt count, and last detail before selective resume.
- Added Phase 13.30 portable route-receipt JSON/CSV exports from the local SQLite catalog, preserving deterministic receipt order and bounded audit detail without exporting source files.
- Added Phase 13.31 read-only route-receipt bundle inspection with retained local history and an explicit live-catalog authority boundary.
- Added Phase 13.32 live-versus-imported route-receipt comparison, classifying unchanged, changed, live-only, and imported-only sources without allowing imported evidence into execution.
- Added Phase 13.33 explicit operator acceptance of an imported bundle as a comparison baseline only, with a persisted audit decision and no promotion into live execution state.
- Added Phase 13.34 explicit comparison-baseline revocation with retained accepted/revoked audit events; revocation clears only the decision and preserves imported evidence.
- Added Phase 13.35 read-only baseline-history inspection and selection, with explicit non-reactivation messaging and no change to live execution authority.
- Added Phase 13.36 portable baseline-audit JSON/CSV export from the local catalog, preserving accepted/revoked decision history as read-only handoff evidence without reactivating a baseline or exporting source files.
- Added Phase 13.37 read-only inspection of exported baseline-audit JSON bundles, keeping imported handoff evidence separate from live audit history and baseline authority.
- Added Phase 13.38 bounded local history for imported baseline-audit bundles, with inspect, remove, and clear controls that survive app restart without changing live audit authority.
- Added Phase 13.39 baseline-audit compatibility metadata, retaining bundle schema version and accepted/revoked counts so imported handoffs can be triaged before event inspection.
- Added Phase 13.40 deterministic content fingerprints for imported baseline-audit bundles, allowing duplicate handoffs to be recognized independently of filename and import time.
- Added Phase 13.41 fingerprint-based history upsert, refreshing an existing duplicate handoff entry with the latest source provenance instead of creating redundant local records.
- Added Phase 13.42 structural validation for imported baseline-audit bundles, rejecting malformed IDs, duplicate event IDs, missing metadata, and oversized payloads before local retention while leaving unknown schemas reviewable.
- Added Phase 13.43 persisted validation-state metadata for imported audit history, labeling new records as structure validated and older cached records as legacy review-required.
- Added Phase 13.44 bounded rejected-import evidence, retaining only source name, timestamp, and validation reasons so malformed handoffs remain diagnosable without storing raw bundle content.

- Added Phase 13.9 indexed delta evaluation, persisted review audit history, and an undo path for the last review disposition.
- Added Phase 13.10 SQLite-backed session diffs, source-delta persistence, and discovery/decision timing evidence in the dashboard.
- Added Phase 13.12 arbitrary session comparison with source-level group/classification/fingerprint transition explanations.
- Added Phase 13.13 local JSON/CSV evidence exports for selected cross-session comparisons, including rule-version provenance and transition explanations.
- Added Phase 13.14 read-only dashboard inspection for exported JSON comparison evidence without importing it into the live SQLite catalog.
- Added Phase 13.15 persisted local imported-evidence history with inspect, remove, and clear controls that never mutate the live catalog.
- Added Phase 13.16 live-versus-imported evidence authority labels and source-overlap counts so read-only bundles cannot be mistaken for catalog authority.
- Added Phase 13.17 provenance filtering for overlapping, live-only, and imported-only sources, preserving the live catalog as the sole authority while making handoff differences fast to triage.
- Added Phase 13.18 actionability labels that distinguish live review, live comparison, and imported-context-only evidence without granting imported rows operation authority.
- Added Phase 13.19 bounded scan-route guidance: metadata triage, targeted verification, or no deep scan, derived from evidence provenance and transition state without scheduling work automatically.
- Added Phase 13.20 route summaries showing metadata-triage, targeted-verification, and deep-scan-avoided counts before execution.
- Added Phase 13.21 scan-profile suitability guidance so Fast Index and YOLO visibly recommend Full Verification when targeted routes remain, without changing the selected profile automatically.
- Added Phase 13.22 export provenance for the selected scan profile and suitability assessment so handoff evidence preserves the operator context for later audit.
- Added Phase 13.23 retained-history labels for exported scan profile and profile assessment so operators can triage old evidence before opening it.
- Added Phase 13.24 read-only retained-history filters for Full Verification recommendations, matched profiles, and legacy or unknown profile context.
- Extended Phase 13.8 review handling with persisted defer/exclude
  dispositions, restore-to-review controls, and affected-group re-evaluation
  from existing indexed rows. Deferred sources remain blockers; exclusions are
  removed from active transfer selection without deleting source data.
- Extended Phase 13.7 Smart Logic with deterministic identity-group summaries
  showing source count, review/fatal blockers, bounded-snapshot coverage,
  freshness, and ranked lead candidates before source-level details. Group
  readiness remains fail-closed and does not authorize a merge or deletion.
- Extended Phase 13.6 Smart Logic with bounded warm-index source snapshots
  (file count, byte estimate, latest modification, and truncation state) and
  separate host activity evidence for Codex, VS Code/Copilot, Claude, and LM
  Studio. Runtime activity is explanatory only and cannot establish identity,
  select a lead, authorize a merge, or authorize deletion.
- Extended Phase 13.5 research with bounded local and remote documentation
  snapshots plus native repository navigation links for Actions, Issues, Pull
  Requests, Projects, Security, and Insights. Documentation remains bounded
  read-only evidence and never authorizes a merge or remote mutation.
- Extended Phase 13.4 research with bounded GitHub Actions workflow inventory,
  local workflow security-surface flags, and availability-only vulnerability,
  secret-scanning, and code-scanning outcomes. The surface remains read-only
  and never reads secret values or performs workflow/security administration.
- Added the Phase 13.1 Deep Research Workspace slice: a read-only GitHub
  repository intelligence snapshot in the native dashboard. It combines
  bounded `gh repo view` metadata with exact local path matches, highlights
  archived/forked/duplicate-looking evidence, records the operation in Jobs,
  and never promotes a source or authorizes a write.
- Extended the research snapshot for Phase 13.2 with bounded local codebase
  and dependency summaries. The native scanner reports file/source/byte counts,
  manifests, source extensions, Git/README evidence, and common dependency
  names while excluding generated/vendor trees and avoiding package installs.
- Extended Phase 13.3 research with bounded GitHub release history and local
  changelog evidence. Remote tags/titles/dates/draft state retain provider
  provenance, while local CHANGELOG/HISTORY/RELEASES headings and Unreleased
  detection remain separate and visibly bounded.
- Started Phase 12.1 Incident Hub with a local persisted ledger, automatic
  failed/cancelled-job records, fatal-versus-recoverable classification,
  redacted issue drafts, retry-originating-job, resolve, and retention
  controls in the native dashboard.
- Extended the Incident Hub for Phase 12.2 with structured lifecycle-stage,
  source, destination, receipt, checkpoint, and next-action evidence; older
  incident records migrate safely with an unknown-stage fallback.
- Added the Phase 12.3 native GitHub Issues surface with read-only issue
  listing, local incident/bug/recovery templates, reviewed clipboard drafts,
  and an explicit arm/authentication/repository gate before `gh issue create`.
- Added Phase 12.4 incident clustering so repeated failures on the same
  operation/stage/source/destination chain roll up with open and fatal counts
  while individual job evidence remains available.
- Added the Phase 12.5 native GitHub issue-action surface for reviewed comments,
  close/reopen lifecycle changes, and label additions/removals. Each provider
  mutation is validated, explicitly armed, routed through the existing `gh`
  bridge, and recorded in the local Jobs Center for reload-based verification.
- Added Phase 12.6 provider-state confirmation. Accepted mutations now read
  back the exact issue through `gh issue view` and verify state, labels, or
  comment presence before marking the job successful; rejected, malformed, or
  mismatched provider responses become visible failed jobs/incidents.
- Added Phase 12.7 controlled retry and retention coverage. GitHub issue
  commands now have a 60-second timeout boundary, failed mutation payloads can
  be restored for review and re-arming from Jobs Center, and an allowlisted
  never-delete smoke harness covers the three retained temporary test repos.
- Added Phase 12.8 restart-safe retry records and provider-outcome categories.
  Failed issue mutations now persist their credential-free reviewed payload and
  redacted error across launches, while authentication, permission, not-found,
  timeout, and generic provider failures are shown as distinct recovery paths.
- Closed the 0.8.0 local macOS CODEX ~ GPT Add-on milestone on `main` after
  rerunning the full local release preflight and the hosted native macOS gate
  against the exact merged commit; deferred roadmap phases remain separately
  tracked.
- Repeated Smart Logic identity-group blocker explanations on the native Stage 2 apply surface beside the write-arm control, and normalized the decision-review grouping key path.
- Disabled native Stage 2 write arming and apply execution while grouped Smart Logic blockers remain unresolved; diagnostic preflight remains available.
- Added read-only tool-context evidence for linked Codex and project-local VS Code/Copilot, Claude, and LM Studio markers to Smart Logic decisions and the native review panel.
- Bumped the Smart Logic rule and module version to `smart-logic-v2.1` so persisted decisions cannot be mistaken for the prior evidence schema.
- Added an explicit localhost LM Studio/Ollama advisory action. It sends only redacted indexed evidence, filters returned IDs, and cannot choose canonical sources or authorize writes/deletion; Smart Logic remains authoritative.
- Bumped the Smart Logic rule and module version to `smart-logic-v2.2` for the advisory contract.
- Verified the installed 0.8.0 dashboard against the retained nine-folder
  Flowers/Space/Birds corpus: Fast Index, Full Verification, and YOLO all
  preserved six identity groups and three review-only blockers without
  transfer or cleanup mutation.
- Added a catalog restart regression proving an interrupted Stage 2 checkpoint
  remains visible as the latest resume state instead of forcing a full rescan.
- Hardened the optional live GitHub limited-token smoke so supplied classic
  tokens advertising `delete_repo`, `gist`, `repo`, or `workflow` fail closed;
  no token is inferred or fabricated and fine-grained tokens with no classic
  scope header remain eligible for the later manual gate.
- Added a local fake-`gh` contract check for the limited-token guard, covering
  both forbidden-scope rejection and the unchanged no-token read-only path.
- Added a reproducible PowerShell parser smoke to the release preflight and
  verified an isolated current-branch GUI bundle with the available Apple
  Development signing identity and hardened runtime; public notarization and
  independent distribution trust remain separate release gates.
- Hardened Windows installer, updater, and uninstaller `--version`/`--help`
  paths to tolerate a non-Windows host without `LOCALAPPDATA`; actual Windows
  lifecycle actions remain fail-closed outside Windows.
- Promoted the Windows CLI inspection and non-Windows mutation checks into the
  repeatable PowerShell release smoke instead of relying only on manual checks.
- Fixed remote macOS installs so the installed GUI builder retains all
  manifest-covered tracked payload roots and can pass its own source checksum
  verification after installation.
- Added a direct installed-payload checksum assertion to the disposable
  lifecycle gate.
- Added an opt-in networked remote-install smoke for temporary-root payload,
  checksum, and GUI-build verification.
- Added explicit `--no-gui-app` and `--no-open` options to the macOS remote
  installer for safe headless automation.

## 0.8.0

- Added the native Swift regression target covering Smart Logic identity
  grouping, broken-metadata and shadow-copy classification, deterministic
  advisory boundaries, SQLite session/checkpoint/export persistence, module
  matrix contracts, review semantics, and backup-medium policy labels.
- Added a bounded native project-tree disclosure to the Local Project Library;
  Code and Runtime roots now expose an expandable, hidden/build-artifact-aware
  snapshot on demand without replacing the indexed scan path or requiring
  Terminal/editor assistance.
- Added deterministic review-only lead ranking for verified Smart Logic
  identity groups. The native decision panel now labels the strongest clean,
  synchronized, linked candidate as the recommended lead and shows lower-ranked
  sources as review candidates; no automatic merge, move, or deletion is
  authorized by the recommendation.
- Added group-level review banners so a same-identity collision with an
  unresolved shadow, broken-metadata, unknown-owner, same-name, or fatal
  identity source explains why automatic apply remains blocked.
- Added a 250-file native index regression corpus that runs twice, verifies
  stable file and byte counts, and proves generated dependency/build trees are
  excluded from the fast index path.
- Added a 60-project / 720-file aggregate index corpus proving project-level
  coverage and generated-tree exclusion without claiming real external-volume
  timing equivalence.
- Refined grouped Smart Logic classification so a clean, synchronized,
  unlinked same-remote copy is explicitly treated as a shadow-copy review
  candidate, with regression coverage for the group-level apply block.
- Added latest-checkpoint recovery status to the SQLite catalog and native
  Smart Index status. After reopening the catalog, the app can show the most
  recent persisted stage/state/timestamp without rebuilding the scan index.
- Added a non-destructive local/GitHub native release preflight covering tests,
  release build, SYSTEMX validation, shell syntax, checksums, whitespace, and
  repository-boundary checks.
- Added a deterministic release-manifest smoke test that validates the
  installer payload contract and proves a tampered installer is rejected;
  signing, notarization, and an independently distributed trust anchor remain
  explicit follow-up work.
- Hardened CODEX transfer progress callbacks for the Swift 6 concurrency model
  by making main-actor UI hops explicit instead of relying on legacy dispatch
  inference.
- Added an isolated install/update/uninstall and GUI bundle lifecycle smoke
  harness with temporary roots, signature verification, and sentinel checks.
- Added a recovery safety smoke harness proving weak/partial Stage 2 sources
  remain unchanged when preflight blocks them and no canonical output is made.
- Added a disposable GitHub identity-scope smoke harness covering two owner /
  login bindings and fail-closed mismatched-login behavior without contacting
  GitHub or changing global `gh` authentication state.
- Added an opt-in Bash 3-compatible live GitHub read-only smoke harness for
  real owner/account bindings, rate limits, organization reads, repository
  identity, default branches, commit reachability, and content inventory;
  it performs no GitHub mutation and does not infer a limited token.
- Added durable SQLite transfer-index records containing source/destination
  artifact digests, option sets, counts, and paths; saved changed-only cache
  reuse now requires a matching catalog record and current artifact digests.
- Added post-promotion rollback for native project transfers so failures during
  recovery capture, Git re-arm, or final verification remove the new destination
  and restore a parked source; added a symlink/parked-source regression test.
- Added injected later-failure coverage for local export transactions, proving
  multi-output promotion rolls back completely without removing source folders.
- Added a temporary workspace-root backup envelope around snapshot restore so a
  later merge failure restores Code, Import, and Runtime to their pre-restore
  state; added partial Code/Import rollback coverage.
- Added injected cross-root workspace-relocation coverage proving staged Code,
  Import, and Runtime promotion restores prior destinations and retains sources
  when a later relocation step fails.
- Added the unified native dashboard shell contract: persistent top navigation,
  side/compact menus, fixed bottom status, explicit page scroll indicators,
  and a shared matrix strip across every dashboard and reference page.
- Added the `CSAiEMModuleTag` matrix so UI pages, engines, bridges, runtimes,
  receipts, recovery, and install/update surfaces carry a stable area, version,
  tag, state, and last-updated identity.
- Added the Home dashboard module/runtime matrix for at-a-glance tracking of
  primary versus unfinished surfaces without duplicating feature registries.
- Kept the single native macOS app lifecycle and installer boundary intact;
  updates replace the installed app before launching one verified instance.
- Synchronized the README, status snapshot, and dashboard/wiki contract.

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
- Preserved macOS modes and file flags on individually copied symlinks, including non-default npm link permissions and the Finder hidden flag, so legacy link metadata is represented exactly instead of failing after a byte-identical copy.
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
- Added a disposable GitHub identity-scope smoke test covering two-account
  binding and fail-closed mismatched-login behavior.
