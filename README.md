# CSA-iLEM

`CSA-iLEM` means `Codespaces & Actions -> Into Local Environment Mac`.

Version: `0.0.06`  
Provided by `Wayne Tech Lab LLC`  
Website: [www.WayneTechLab.com](https://www.WayneTechLab.com)  
Notice: `Use at your own risk.`

`CSA-iLEM` is a macOS CLI for:
- cloning GitHub repos locally
- preparing local devcontainers
- installing self-hosted GitHub Actions runners
- patching workflow `runs-on` targets
- previewing or running GitHub cleanup flows
- browsing imported local workspaces, installed devcontainers, active containers, and local runners

## Production CLI Entry Points

Primary commands in this repo:
- [`csa-ilem`](./csa-ilem)
- [`csa-ilem-public`](./csa-ilem-public)
- [`csa-ilem-wtl`](./csa-ilem-wtl)
- [`csa-ilem-diamond`](./csa-ilem-diamond)
- [`csa-ilem-open`](./csa-ilem-open)
- [`openproj`](./openproj)

Compatibility wrappers also remain available:
- [`CSA-iLEM.sh`](./CSA-iLEM.sh)
- [`CSA-iLEM-Public.sh`](./CSA-iLEM-Public.sh)
- [`CSA-iLEM-WTL.sh`](./CSA-iLEM-WTL.sh)
- [`CSA-iLEM-Diamond.sh`](./CSA-iLEM-Diamond.sh)
- [`CSA-iLEM-Open.sh`](./CSA-iLEM-Open.sh)

## Install On Any Supported Mac

This distribution is installable from Terminal with the included installer.

Local install from a checked-out or copied folder:

```bash
cd '/path/to/CSA-iEM'
chmod +x ./install.sh
./install.sh
```

The installer:
- copies the production CLI bundle into `~/.local/share/csa-ilem/0.0.06`
- creates a stable `current` symlink under `~/.local/share/csa-ilem/`
- links commands into `~/.local/bin`
- adds `~/.local/bin` to `~/.zprofile`

After install:

```bash
source ~/.zprofile
csa-ilem --version
```

Uninstall:

```bash
cd '/path/to/CSA-iEM'
./uninstall.sh
```

## Editions

### Public

- default root: `~/CSA-iLEM`
- intended for portable single-root usage on any supported Mac

### WTL

- default root: `/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH`
- intended for the Wayne Tech Lab external-drive layout

### Diamond

- code root: `/Volumes/WTL - MACmini EXT/MM-WTL-CODE-X/GH`
- runtime root: `/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH`
- keeps plain repo work separate from runtime/container work

Diamond layout:

```text
Code root
  Repos/<owner>/<repo>

Runtime root
  Repos/<owner>/<repo>
  Reports/
  Backups/
  Runners/<owner>/<repo>
  Scripts/
```

## Main CLI Modes

- `Codespace -> Local`
- `Repo -> Local`
- `Repo -> Local + local devcontainer + local Actions prep`
- `Cleanup only`

Supported batch behavior:
- one repo at a time
- all repos one by one
- `FULL AUTO`
- `FULL AUTO + CLEANUP PREVIEW`
- resume from a repo number in all-repos mode
- post-batch one-by-one review in VS Code
- one-by-one cost-control review with yes / ok / no / skip flow

## Browser And Open Flows

The browser can show:
- imported projects
- installed local devcontainers
- active local containers
- local Actions runners
- a one-project-at-a-time cost-control review

Project status tags include:
- `split`
- `code`
- `runtime`
- `codespaces-ready`
- `local-starter`
- `active:<n>`
- `runner`

Useful opener commands:

```bash
csa-ilem-open
```

```bash
openproj
```

Both jump straight into the full local project browser using the saved Diamond roots.

From that browser you can:
- open a plain repo or runtime workspace in VS Code
- inspect active local containers and local runner state
- run `Cost-control review (one project at a time)`

The recommended no-spend safeguard plan can:
- disable GitHub Actions at the repo settings level
- disable workflows and delete workflow runs, artifacts, caches, and Codespaces
- stop the local runner service
- stop active local devcontainer containers
- patch workflow files to self-hosted labels for future use
- optionally commit and push the workflow patch after the hard stop is in place

Important:
- disabling GitHub Actions at the repo settings level is a hard stop; self-hosted runners also stop receiving jobs until you re-enable Actions for that repo

## Built-In Metadata And Legal Flags

The CLI can print bundled metadata and docs directly:

```bash
csa-ilem --about
csa-ilem --notice
csa-ilem --terms
csa-ilem --privacy
csa-ilem --disclaimer
```

## Included Documents

- [`NOTICE.md`](./NOTICE.md)
- [`LICENSE.txt`](./LICENSE.txt)
- [`TERMS-OF-SERVICE.md`](./TERMS-OF-SERVICE.md)
- [`PRIVACY-NOTICE.md`](./PRIVACY-NOTICE.md)
- [`DISCLAIMER.md`](./DISCLAIMER.md)
- [`CHANGELOG.md`](./CHANGELOG.md)
- [`VERSION`](./VERSION)

## Notes

- macOS only
- intended for technical users
- relies on third-party tools such as GitHub CLI, Git, Docker, Homebrew, Node.js, npm, and Visual Studio Code
- legal documents included here are practical production-distribution templates and should still be reviewed by counsel before broad public release
