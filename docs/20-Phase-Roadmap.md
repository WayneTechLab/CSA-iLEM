# CSA-iEM 20-Phase Product Roadmap

`CSA-iEM` is already strong as a macOS-first GitHub/local-ops tool with a growing Windows shell path. This roadmap is the next major step: turn it into a deeply capable cross-platform operator console where the GUI is the primary product and shell routes exist mainly as backend execution and recovery tools.

This plan is intentionally phased. Each phase should leave the product in a better, releasable state instead of stacking unfinished work for later.

## Product Direction

Core goals:
- GUI first on both macOS and Windows
- shared backend contracts across platforms
- preview-first and rollback-aware destructive operations
- research, diagnostics, and GitHub admin tooling visible in-app
- terminal routes hidden behind native job execution wherever possible

## Phase 1: Unified Backend Contract

Goal:
- define one stable execution contract shared by macOS Bash, Windows PowerShell, and future GUI-native clients

Deliverables:
- operation schema for import, cleanup, patch, browse, runner, devcontainer, and file actions
- normalized job result shape with status, logs, warnings, report path, and recovery hints
- shared argument naming across Bash and PowerShell backends

Exit criteria:
- every major operation has the same conceptual inputs and outputs on both operating systems

## Phase 2: Native Job Engine Everywhere

Goal:
- route all long-running work through a visible jobs center instead of ad hoc terminal launches

Deliverables:
- queued, running, completed, cancelled, failed job states
- retry and cancel support
- structured logs with filtering
- saved history for recent jobs

Exit criteria:
- import, cleanup, patch, backup, runner, and devcontainer operations all appear in a unified jobs surface

## Phase 3: GUI Terminal Console Layer

Goal:
- preserve shell power without forcing users to leave the GUI

Deliverables:
- embedded operation console for advanced output
- copyable command transcript
- safe “show backend command” toggle for power users
- per-job raw output and parsed output tabs

Exit criteria:
- terminal routes are optional diagnostics, not the normal workflow

## Phase 4: Native Import Center

Goal:
- make import the first-class entry point for repo migration and local setup

Deliverables:
- owner/org repo loader
- one-repo, batch, and full-auto GUI modes
- resume-from-index support
- import summaries with success/failure reasons

Exit criteria:
- the import page can fully replace the current menu-driven import flow for normal users

## Phase 5: Project Library 2.0

Goal:
- turn the project browser into the main operating surface

Deliverables:
- grouped views by owner, language, workspace type, devcontainer status, runner status
- advanced search and saved filters
- favorites, recents, pinned repos, and bulk selection
- richer project cards with health and risk summaries

Exit criteria:
- most daily project actions start from the project library, not command entrypoints

## Phase 6: Devcontainer Control Center

Goal:
- make local container work completely visible and manageable in-app

Deliverables:
- build, rebuild, up, stop, remove, inspect, and log actions
- container health indicators
- repo-to-container mapping
- config preview and warnings for risky patterns like docker-in-docker conflicts

Exit criteria:
- a user can manage local devcontainer lifecycle without dropping to Terminal

## Phase 7: Runner Fleet Manager

Goal:
- make self-hosted runner management feel like a real control plane

Deliverables:
- install, repair, relabel, remove, start, stop, restart
- service health and registration state
- linked repo view
- runner activity, last-seen status, and local path inspection

Exit criteria:
- runner operations are as approachable as project browsing

## Phase 8: Workflow Control Center

Goal:
- make workflow state and execution manageable from the GUI

Deliverables:
- workflow inventory
- enable, disable, dispatch, open YAML, and patch actions
- patch preview before write
- runner target analysis for each workflow

Exit criteria:
- workflow admin becomes a page-level GUI workflow instead of a backend side effect

## Phase 9: Workflow Runs Explorer

Goal:
- make runs and failures explorable like a real incident console

Deliverables:
- run list with filters
- status timeline
- per-run logs and metadata links
- rerun, cancel, delete, artifact browse, and cache visibility

Exit criteria:
- the app can answer “what ran, what failed, what cost money, and what should we do next?”

## Phase 10: Cleanup and Cost-Control Command Center

Goal:
- turn cost-control into a safe, understandable GUI system

Deliverables:
- preview-first cleanup planner
- cost/risk score per repo
- recommended no-spend mode
- hosted-runner detection, run-volume detection, cache/artifact pressure, Codespaces usage

Exit criteria:
- the product can clearly show why a repo is costing money and how to stop it safely

## Phase 11: GitHub Account and Org Admin Hub

Goal:
- elevate the current account page into a full operations/admin hub

Deliverables:
- multi-account and multi-org saved contexts
- repo inventory and health at org scale
- role/scope diagnostics
- context switcher without losing page state

Exit criteria:
- account switching and org inspection feel native and low-friction

## Phase 12: Issues, Bugs, and Incident Hub

Goal:
- add deep issue and bug tooling directly into the product

Deliverables:
- GitHub issues viewer and creator
- issue templates and saved labels
- bug report drafting from local diagnostics
- failure-to-issue workflow from jobs, runs, and devcontainers

Exit criteria:
- a user can turn a failed operation into a well-formed issue without leaving the app

## Phase 13: Deep Research Workspace

Goal:
- make the app useful for understanding a repo or org, not just operating it

Deliverables:
- repo intelligence summaries
- local codebase search and dependency summaries
- release-note and changelog aggregation
- security advisory and workflow surface review
- documentation snapshot panel

Exit criteria:
- the app can help answer “what is this repo, how does it work, what changed, what is risky?”

## Phase 14: Secrets, Variables, Policies, and Rules

Goal:
- finish the GitHub admin layer for high-impact settings

Deliverables:
- repo/org secrets and variables inventory
- create/update flows where safe
- branch protection and ruleset editing for common cases
- drift detection across repos

Exit criteria:
- common GitHub governance tasks are handled in-app with clear warnings and permission checks

## Phase 15: Local Files, Backups, Snapshots, and Restore

Goal:
- make filesystem operations safe enough for daily use

Deliverables:
- guided move/copy/export wizards
- collision detection and size estimates
- snapshots, restore, and rollback history
- external-drive validation and health warnings

Exit criteria:
- file movement becomes reliable, previewable, and recoverable

## Phase 16: Native Windows Desktop GUI

Goal:
- give Windows the same GUI-first experience as macOS

Deliverables:
- native Windows app shell
- project library, jobs, import, cleanup, local files, account pages
- shared backend contract with the PowerShell engine
- Windows-first service and Docker status panels

Exit criteria:
- Windows users no longer need to treat the app as a shell script product

## Phase 17: Packaging, Signing, Notarization, and Trusted Updates

Goal:
- make distribution trustworthy and production-grade

Deliverables:
- macOS signing and notarization
- Windows packaging and trusted install/update flow
- release checksum verification everywhere
- release manifest and version channel handling

Exit criteria:
- public installs are verifiable and professional on both operating systems

## Phase 18: Automated QA and Recovery Testing

Goal:
- turn reliability from manual checking into repeatable assurance

Deliverables:
- install/update/uninstall smoke suite
- GUI flow regression coverage
- backend contract tests
- move/export/restore rollback tests
- mocked GitHub permission and rate-limit scenarios

Exit criteria:
- releases have a real preflight bar before publish

## Phase 19: Collaboration, Templates, and Automation

Goal:
- make the app useful for teams instead of just solo operators

Deliverables:
- shared task templates
- reusable project presets
- exportable workspace configs
- automation hooks and scheduled maintenance plans

Exit criteria:
- teams can reuse and standardize workflows instead of rebuilding them manually

## Phase 20: Product Polish and “Best-in-Class” Pass

Goal:
- finish the experience quality, not just the feature list

Deliverables:
- onboarding that explains the product clearly for public users
- zero-confusion workspace language
- better visual hierarchy, accessibility, empty states, and error recovery
- consistent terminology across macOS, Windows, CLI, and docs
- public release readiness review

Exit criteria:
- new users can install, understand, trust, and use the app without internal context

## Recommended Delivery Order

Recommended high-return sequence:
1. phases 1-5
2. phases 6-10
3. phases 11-15
4. phase 16
5. phases 17-20

## Platform Notes

Why these phases matter:
- Apple’s notarization workflow is required for polished macOS distribution: [Apple Developer Documentation](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- Microsoft’s current native desktop direction is WinUI via Windows App SDK: [Windows App SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/) and [WinUI](https://learn.microsoft.com/en-us/windows/apps/winui/)
- GitHub’s current Actions administration surface includes official APIs for workflows, runs, artifacts, caches, and related controls: [GitHub Docs](https://docs.github.com/en/rest/actions/cache)
- Dev Containers remain a first-class local development path through VS Code and the Dev Containers ecosystem: [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)

## Definition of Success

The “best app ever” version of `CSA-iEM` means:
- a user can install it cleanly on macOS or Windows
- a user can understand the workspace model immediately
- a user can import, inspect, patch, run, clean up, research, diagnose, and recover from the GUI
- the shell remains powerful, but mostly invisible unless explicitly needed
