# CSA-iLEM Dashboard and Module Matrix

Status: primary native macOS dashboard contract
Version: 0.8.0
Matrix revision: matrix-1.0
Updated: 2026-08-13

## Purpose

CSA-iLEM is one native macOS application with one canonical dashboard shell.
The shell keeps the top navigation, responsive side/compact menu, page body,
and fixed bottom status surface in one state flow. Individual pages may have
their own layout, but they must not invent a second navigation or status
contract.

## Synchronized UI contract

- The top navigation owns page selection and the menu/sidebar toggle.
- The left sidebar is used on wide windows; the compact horizontal menu is used
  on narrower windows.
- The page body is the only primary vertical scroll region for a page.
- The vertical scroll indicator is visible so operators can tell where they
  are in a long operational page.
- Activity state is shown above the page body while a background operation is
  active.
- The bottom status bar remains outside the page scroll region and mirrors the
  selected page, session, selection, and current operation status.
- No page-level feature may silently replace the fixed status or navigation
  surfaces.

## Matrix fields

Every tracked entry carries:

- `area`: UI, Feature, Engine, Bridge, or Runtime;
- `version`: app or subsystem version;
- `tag`: stable diagnostic identifier such as `engine.smart-logic`;
- `state`: currently `primary` or a future review state;
- `lastUpdated`: the last intentional change date.

The native source of truth is `CSAiEMModuleTag.catalog` in
`Sources/CSAiEMMacApp/CSAiEMModuleMatrix.swift`. The Home page renders the
full table. Every `DashboardShell` page renders the compact matrix strip.

## Triage workflow

When an operator reports a broken surface:

1. Record the page/module tag from the matrix.
2. Record the displayed app and module version.
3. Record the fixed bottom status and active job/session identifier.
4. Compare the relevant receipt, index, or runtime log.
5. Update the module entry and CHANGELOG only after the fix is verified.

## Phase 13.4 research and security boundary

The research workspace includes a bounded `gh workflow list` inventory for the
selected repository and a bounded local scan of exact-match `.github/workflows`
files. The local evidence records action references and flags explicit
permissions, `pull_request_target`, secret references, and fork context so an
operator can review workflow risk without opening a deep scan.

Security endpoints are queried only for availability and permission status for
vulnerability alerts, secret-scanning alerts, and code-scanning alerts. The
native app does not read secret values, edit workflows, dismiss alerts, or
perform administrative changes in this research phase. Remote failures are
categorized and retained alongside available local evidence.

## Phase 13.5 documentation and repository navigation

Research snapshots now include bounded documentation evidence from exact local
matches. Candidate paths include README, contribution, security, release-note,
`.github`, `docs`, and `.SYSTEMX/Wiki` material. The panel retains the path,
document kind, headings, byte limit, and any truncation or encoding warning.

The same snapshot can inventory documentation candidates from the selected
repository's GitHub contents endpoint without downloading the repository tree.
The provider result is shown as available or categorized unavailable; it is
never treated as proof of canonical ownership.

Native Actions, Issues, Pull Requests, Projects, Security, and Insights links
use the selected repository and GitHub host already bound in the app. They are
navigation shortcuts only and do not dispatch workflows, edit files, dismiss
alerts, or authorize any other remote operation.

## Phase 13.6 source snapshot and active-tool boundary

The Smart Logic source record now carries a bounded warm-index snapshot for
each discovered folder: file count, byte estimate, latest modification, and a
truncation flag. Generated and dependency trees remain excluded so this first
pass is suitable for fast grouping rather than deep verification.

Project-local markers (for example `.vscode`, `.claude`, or `lmstudio.json`)
remain separate from host activity evidence. The app may report that Codex,
VS Code/Copilot, Claude, or LM Studio is running on the Mac, but it does not
claim that the process opened a specific folder. Host activity is review
context only and cannot establish repository identity, select a canonical
source, authorize a merge, or authorize deletion.

## Phase 13.7 grouped readiness

Smart Logic derives a single summary row for each identity group from the
existing decision table. It reports source count, review-only blockers, fatal
blockers, bounded snapshot coverage, latest observed modification, and the
ranked lead candidate. The dashboard shows these rows before the individual
source decisions so the operator can understand the one-group/one-destination
state quickly.

A ranked lead is evidence, not permission. If any source in the group remains
review-only or fatal, the group stays blocked until the operator resolves or
explicitly excludes it. The summary reuses the persisted decision/catalog
path and does not represent missing or unavailable index state as a cache hit.

## Phase 13.8 review resolution boundary

Review sources now have explicit local dispositions. `Deferred` keeps the
source in the active group and continues to block readiness. `Explicitly
excluded` removes the source from active transfer selection, persists the
decision, and retains the source and evidence for restoration; it never deletes
or moves the source. A restore action returns the source to active review.

The group `Re-evaluate` action evaluates only the existing indexed source rows
for that group. It does not rescan unrelated folders, and it resets transfer
and Stage 2 arms after changing the decision state. Canonical selection,
disposition, and remote mutation remain separate confirmations.

The matrix is an identity and triage aid. It does not authorize writes,
replace Git history, bypass Smart Logic, or override receipt and cleanup
gates.

## Phase 13.9 indexed review recovery boundary

Review disposition changes and targeted group re-evaluations are written to a
bounded local audit ledger. The dashboard exposes the latest entries and can
undo the last disposition action after confirming that its source remains in
the current decision table. A separate local fingerprint baseline classifies
the next scan as added, changed, unchanged, or removed. Only affected identity
groups are evaluated again; unchanged decision rows remain retained for the
current session. This optimization does not bypass canonical selection, Stage
2 preflight, transfer verification, or any remote write gate.

## Phase 13.10 session-diff observability boundary

The SQLite catalog now retains each scan's source delta rows and timing
evidence. The dashboard compares the current session with the prior saved
session and shows added, changed, unchanged, and removed rows, affected groups,
evaluated-versus-reused sources, and discovery/decision durations. Recent
session history remains available after restart. These measurements describe
work avoided by the index; they never authorize a merge, transfer, cleanup,
deletion, or provider mutation.

## Phase 13.12 cross-session evidence boundary

Operators can select a saved session and an independent comparison baseline.
The dashboard compares decision snapshots and indexed fingerprints by source
path, then reports added, removed, changed, and unchanged rows. Changed rows
explain identity-group moves, classification transitions, and evidence
fingerprint changes. The comparison reads the local SQLite catalog only; it
does not rewrite sessions, choose a canonical source, or authorize any
transfer, cleanup, deletion, or remote provider mutation.

## Phase 13.13 portable session evidence boundary

The dashboard can export the selected current and baseline comparison as a
local JSON and CSV pair under `.SYSTEMX/Index/Exports`. The JSON bundle keeps
the session IDs, rule-version provenance, and complete transition rows; the
CSV is convenient for review or handoff. The export contains evidence and
metadata only: it does not copy project files, rewrite SQLite sessions, select
a canonical source, or authorize transfer, cleanup, deletion, or remote
provider mutation.

## Phase 13.14 read-only evidence inspection boundary

The dashboard can open a previously exported comparison JSON through the
native file picker. The bundle is decoded and displayed as transient evidence
with its current and baseline session IDs, rule-version provenance, and a
bounded list of transition rows. It is never inserted into the live SQLite
catalog, treated as a new scan, or used to authorize canonical selection,
transfer, cleanup, deletion, or remote provider mutation. Malformed JSON is
rejected and reported in the dashboard and local log.

## Phase 13.15 imported-evidence history boundary

Successfully decoded comparison bundles are retained in a bounded local
history under the CSA-iEM Application Support directory. The dashboard can
reopen an entry, remove one entry, or clear the history. This cache stores
evidence for operator review only; it does not populate SQLite, become a live
scan baseline, alter project files, or authorize canonical selection, transfer,
cleanup, deletion, or remote provider mutation.

## Phase 13.16 evidence authority boundary

When a retained imported bundle is open beside the catalog comparison, the
dashboard labels the live SQLite session as authoritative and the imported
bundle as read-only. It reports current-session identity match plus overlapping,
live-only, and imported-only source counts. This comparison is informational;
an imported bundle cannot override catalog evidence, become a scan baseline,
or authorize canonical selection, transfer, cleanup, deletion, or remote
provider mutation.

## Phase 13.17 provenance filtering

When imported evidence is open, the authority panel provides deterministic
filters for all provenance, overlapping sources, live-only sources, and
imported-only sources. Each visible source retains its live and imported
transition kinds, making handoff drift reviewable quickly while preserving the
fail-closed authority boundary. Filtering does not alter the SQLite catalog,
source files, canonical selections, transfer plans, or remote state.

## Phase 13.18 actionability routing

Every visible provenance row is also labeled as live review required, compare
with live catalog, or imported context only. The label is an explanatory
routing signal for the operator: imported-only context can never become a
source of action, and neither provenance nor actionability can authorize a
merge, transfer, cleanup, deletion, or remote mutation.

## Phase 13.19 bounded scan routing

The same evidence row now carries a bounded scan-route suggestion: metadata
triage, targeted verification, or no deep scan. Imported-only context is kept
out of expensive deep verification, while changed live evidence is routed to
focused review. The label does not schedule work and cannot authorize any
merge, transfer, cleanup, deletion, or remote mutation.

## Phase 13.20 route summary

The authority panel summarizes the visible route decisions before execution:
metadata triage, targeted verification, and deep scans avoided. This makes the
fast path measurable without scheduling work. The summary remains evidence
only and does not grant permission for merge, transfer, cleanup, deletion, or
remote mutation.

## Phase 13.21 scan-profile suitability

The authority panel compares the selected Fast Index, Full Verification, or
YOLO profile with the route summary. If targeted routes remain, Fast Index and
YOLO display a recommendation for Full Verification. The recommendation does
not switch profiles, schedule work, or override the existing safety gates.

## Phase 13.22 profile assessment provenance

Comparison JSON exports retain the selected scan profile and its suitability
assessment. When the file is reopened as read-only evidence, CSA-iLEM displays
that context alongside the session and rule-version metadata. The imported
context cannot change the live profile, catalog, or operation gates.

## Phase 13.23 retained-history provenance

Retained imported-evidence entries show the exported scan profile and whether
the profile matched the route assessment or Full Verification was recommended.
Operators can triage a handoff before opening it. The bounded local history is
read-only and cannot modify the live catalog or authorize an operation.

## Phase 13.24 retained-history filtering

The retained imported-evidence history can be filtered by Full Verification
recommended, profile matched, or legacy or unknown profile context. The filter
only changes the visible list; it does not mutate retained bundles, the live
catalog, profile selection, or operation gates.

## GitHub issue actions

## Phase 13.25 evidence compatibility labeling

Retained comparison imports now expose a read-only compatibility state beside
the scan profile and assessment:

- `profile metadata complete`: both fields are available.
- `profile metadata partial`: exactly one field is available and the operator
  should review the evidence before relying on the route assessment.
- `legacy profile metadata`: both fields are absent because the export predates
  the profile metadata contract.

This is a triage aid only. It does not modify imported JSON, merge anything into
the live catalog, or change the authority boundary.

## Phase 13.26 deterministic route planning

The Smart Scan Profile section now shows a route plan derived from current saved
decisions, source deltas, and explicit review dispositions:

- unchanged safe candidates use metadata triage;
- changed or review-blocked sources use targeted verification;
- explicitly excluded sources avoid deep scans.

The plan reports the counts and explains whether the selected profile matches the
evidence. It does not schedule a scan, change profile selection, promote a lead,
or authorize transfer, cleanup, deletion, or remote writes.

## Phase 13.27 persisted route receipts

Each indexed source now has a route receipt in the existing local SQLite catalog.
The receipt records its route, state, attempt count, update time, and bounded
detail. States are `planned`, `skipped`, `completed`, `interrupted`, and `failed`.

The dashboard shows the receipt summary beside the route plan. Successful and
safe-stop transfer paths update the receipt state. Reopening the catalog restores
the receipt state and pending count, so the operator can resume from known route
evidence without treating an interrupted UI session as a completed operation.

The GitHub Issues page is a native bridge to the authenticated `gh` session.
It reads provider labels and supports reviewed comments, close/reopen actions,
and label additions or removals. A selected issue, repository, host, and valid
payload are required. The operator must explicitly arm each remote mutation;
the arm state resets when the issue, action, or payload changes. After GitHub
accepts a mutation, CSA-iLEM reads the exact issue back through `gh issue view`
and verifies the requested state, labels, or comment presence before marking
the Jobs Center operation successful. Rejected, malformed, or mismatched
provider responses remain failed and visible for incident review.

Failed issue mutations also persist a local retry record under the CSA-iEM
Application Support directory. The record contains no token or credential; it
stores only the host, repository, issue, reviewed action payload, attempt
count, and redacted provider error. After restart, the Issues page can prepare
the exact action again, but the operator must review and re-arm it. Provider
errors are categorized as authentication-required, permission-denied,
not-found, timeout, or generic failure.

## Repository intelligence snapshot

The GitHub account dashboard includes a read-only Repository Intelligence
Snapshot for one selected repository. It uses a bounded `gh repo view` call to
collect provider metadata, then compares the repository slug with exact local
project identities already present in the workspace model. The result shows
branch, language, license, activity, issue/PR counts, local path evidence, and
conservative review flags for archived, forked, incomplete, or duplicate-looking
evidence.

The snapshot is evidence only. It does not choose a canonical source, merge
folders, start a backup, perform cleanup, or authorize a GitHub write. The
operation is recorded in Jobs so a failed read can be retried without silently
expanding scope.

## Local codebase and dependency summary

For each exact local path match, the research snapshot performs a bounded
read-only scan. It reports file count, source-file count, byte size, source
extensions, top-level entries, manifest/dependency-file evidence, Git and README
presence, and review warnings. It excludes generated and vendor trees such as
`.git`, `node_modules`, `.build`, `DerivedData`, `Pods`, `vendor`, `dist`, and
`build`, and enforces file-count and depth caps.

Common `package.json`, `requirements.txt`, `go.mod`, and `Cargo.toml` dependency
names are extracted only from bounded local manifest content. CSA-iLEM does not
install, resolve, fetch, or modify dependencies during research. These results
are evidence for review and cannot authorize a merge, backup, cleanup, or
remote write.

## Release and changelog evidence

The research snapshot reads at most 20 remote releases for the selected
repository through `gh release list`. Each entry retains its tag, title,
publication date, draft/prerelease state, and provider URL. This is remote
provider evidence and is not merged with local documentation.

For each matched local path, bounded candidate files such as `CHANGELOG.md`,
`HISTORY.md`, `RELEASES.md`, and `docs/CHANGELOG.md` are inspected. CSA-iLEM
retains headings, whether an `Unreleased` section exists, and explicit byte or
heading caps. A provider release-read failure is reported without discarding
local codebase or changelog evidence. Neither release source authorizes a
canonical source, merge, backup, cleanup, or remote write.

## Install and update invariant

The installer reads `VERSION`, builds one `CSA-iEM.app`, replaces the target
installed app, removes older version folders from the managed install root,
and launches one canonical app instance. Verification must check the installed
bundle version, codesign, checksum manifest, and process count together.
