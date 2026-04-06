# Windows 11 Admin Shell Notes

`CSA-iEM` now ships with a Windows 11 admin-shell backend in PowerShell.

The Windows path is intended for:
- Windows Terminal
- PowerShell
- Administrator shell sessions when installing dependencies or services

## Main Windows Commands

Use Windows Terminal or PowerShell. Run install and service-related commands from an Administrator shell.

From a local repo checkout:

```powershell
cd H:\WTL-CODE-X\CSA-iEM
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

If you launch PowerShell from somewhere else such as `C:\WINDOWS\system32`, either change into the repo first or run:

```powershell
powershell -ExecutionPolicy Bypass -File H:\WTL-CODE-X\CSA-iEM\install.ps1
```

Latest published `main` install from GitHub:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1"
```

Latest published `main` update from GitHub:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1 --force"
```

Specific release, branch, or commit install:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1 --ref your-tag-or-branch"
```

Local git update:

```powershell
cd H:\WTL-CODE-X\CSA-iEM
git switch main
git pull --ff-only origin main
```

After install:

```powershell
csa-iem --version
csa-iem-update --help
openproj
```

Installed Windows update command:

```powershell
csa-iem-update
```

Update to a specific version or tag:

```powershell
csa-iem-update --ref your-tag-or-branch
```

`csa-iem-update` updates from the published GitHub repo. If you are actively working in a newer local checkout that is not pushed yet, use the repo-local installer instead:

```powershell
cd H:\WTL-CODE-X\CSA-iEM
powershell -ExecutionPolicy Bypass -File .\install.ps1 --force
```

Windows command lookup is case-insensitive, so these also resolve to the same installed CLI:

```powershell
CSA-IEM --version
CSA-iEM --version
```

## Windows Scope

The Windows backend supports:
- preflight scans
- GitHub CLI authentication checks
- local repo import into `Code`, staging into `Import`, and runtime prep in `Runtime`
- starter devcontainer generation
- quick devcontainer startup checks
- repo-level self-hosted Windows runner install and service start
- workflow patching to self-hosted Windows labels
- repo-scoped GitHub cleanup actions
- local project browsing with VS Code and File Explorer

## Current Windows Defaults

Generic default workspace roots:
- `Code`: `~/CSA-iEM/Code`
- `Import`: `~/CSA-iEM/Import`
- `Runtime`: `~/CSA-iEM/Runtime`

`--single-root PATH` is still supported as a compatibility shortcut and expands to those three subfolders under the chosen base path.

This keeps the public Windows setup generic while still allowing custom roots.

## Windows Dependency Bootstrap

The Windows installer tries to bootstrap:
- `git`
- `gh`
- `node`
- `code`
- `docker`
- `devcontainer`

It uses `winget` for system packages and `npm` for the Dev Containers CLI.

## Current Windows Limits

The macOS SwiftUI GUI is still macOS-only.

Windows today is a PowerShell-first implementation. The goal is to keep the same operator model as macOS, but the native desktop GUI layer is not part of this Windows release yet.

Contributor setup for local Windows work lives in:

- [`docs/Windows-Contributor-Setup.md`](./Windows-Contributor-Setup.md)
