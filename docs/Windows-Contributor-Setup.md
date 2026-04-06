# Windows Contributor Setup

## Local Flow

Use this repo from Windows with:

- Visual Studio Code
- the integrated PowerShell terminal
- the Codex CLI already installed on the machine

Open the repo:

```powershell
code H:\WTL-CODE-X\CSA-iEM
```

Inside the VS Code terminal:

```powershell
codex
```

That is the supported local Codex workflow for this repo. It does not depend on a separate VS Code extension.

## Recommended First Commands

Run the repo-local installer:

```powershell
cd H:\WTL-CODE-X\CSA-iEM
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

If your shell starts somewhere else, use the full path:

```powershell
powershell -ExecutionPolicy Bypass -File H:\WTL-CODE-X\CSA-iEM\install.ps1
```

Check the local CLI:

```powershell
cd H:\WTL-CODE-X\CSA-iEM
powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1 --version
powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1 --help
```

Update an installed Windows copy from any PowerShell window:

```powershell
csa-iem-update
csa-iem-update --ref your-tag-or-branch
```

Browse imported projects with the saved workspace roots:

```powershell
cd H:\WTL-CODE-X\CSA-iEM
powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1 --browse-projects --use-current-root
```

Safe cleanup example:

```powershell
cd H:\WTL-CODE-X\CSA-iEM
powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1 --repo OWNER/REPO --all --dry-run --yes
```

## VS Code Tasks

This repo ships these tasks:

- `CSA-iEM: Install Windows`
- `CSA-iEM: Update Windows Install`
- `CSA-iEM: CLI Version`
- `CSA-iEM: CLI Help`
- `CSA-iEM: Open Project Browser`
- `CSA-iEM: Cleanup Dry Run Example`

Open them from `Terminal > Run Task`.

## Workspace Model

The public Windows model is now:

- `Code`: plain repo clones
- `Import`: Codespaces exports, zip drops, and staging
- `Runtime`: devcontainers, reports, logs, backups, and runners

Default roots:

- `%USERPROFILE%\\CSA-iEM\\Code`
- `%USERPROFILE%\\CSA-iEM\\Import`
- `%USERPROFILE%\\CSA-iEM\\Runtime`
