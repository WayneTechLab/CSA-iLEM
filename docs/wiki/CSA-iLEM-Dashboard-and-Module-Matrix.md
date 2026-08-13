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

The matrix is an identity and triage aid. It does not authorize writes,
replace Git history, bypass Smart Logic, or override receipt and cleanup
gates.

## GitHub issue actions

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

## Install and update invariant

The installer reads `VERSION`, builds one `CSA-iEM.app`, replaces the target
installed app, removes older version folders from the managed install root,
and launches one canonical app instance. Verification must check the installed
bundle version, codesign, checksum manifest, and process count together.
