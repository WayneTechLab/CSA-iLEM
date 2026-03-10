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

## Safe First Run

1. Install GitHub CLI if it is not already present.
2. Authenticate with `gh auth login -h github.com`.
3. Open the app and review the warning and Terms screen.
4. Select the correct GitHub host and account.
5. Pick the correct edition and workspace root.
6. Use `Dry run` first for destructive cleanup.
7. Review the live output before applying permanent changes.

## Profiles

- `Public`: portable single-root layout under `~/CSA-iEM`
- `WTL`: Wayne Tech Lab single-root external-drive layout
- `Diamond`: split code and runtime roots for cleaner repo vs container separation

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

The app stores only the last selected:

- host
- account
- repository target

It does not intentionally store GitHub tokens.

## Support

Provided by Wayne Tech Lab LLC  
[www.WayneTechLab.com](https://www.WayneTechLab.com)
