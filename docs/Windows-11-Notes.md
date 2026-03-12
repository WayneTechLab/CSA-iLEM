# Windows 11 Admin Shell Notes

`CSA-iEM` now ships with a Windows 11 admin-shell backend in PowerShell.

The Windows path is intended for:
- Windows Terminal
- PowerShell
- Administrator shell sessions when installing dependencies or services

## Main Windows Commands

From a local repo checkout:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

From GitHub:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.ps1 -OutFile $env:TEMP\csa-iem-install.ps1; & $env:TEMP\csa-iem-install.ps1"
```

After install:

```powershell
csa-iem --version
openproj
```

## Windows Scope

The Windows backend supports:
- preflight scans
- GitHub CLI authentication checks
- local repo import into code/runtime roots
- starter devcontainer generation
- quick devcontainer startup checks
- repo-level self-hosted Windows runner install and service start
- workflow patching to self-hosted Windows labels
- repo-scoped GitHub cleanup actions
- local project browsing with VS Code and File Explorer

## Current Windows Defaults

Generic default workspace:
- single folder root: `~/CSA-iEM`
- internal code root: `~/CSA-iEM/Code`
- internal runtime root: `~/CSA-iEM/Runtime`

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
