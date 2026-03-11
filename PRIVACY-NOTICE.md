CSA-iEM Privacy Notice
Full name: Container Setup & Action Import Engine Manager
Version: 0.0.14
Provider: Wayne Tech Lab LLC
Website: https://www.WayneTechLab.com

Important:
- This notice describes the software's practical data behavior.
- It is not legal advice.
- Wayne Tech Lab LLC should have this notice reviewed by qualified legal counsel before broad public release.

1. Local-First Operation

CSA-iEM primarily operates on the local Mac where it is run. It can read and write local filesystem paths in order to:
- clone and update repositories
- create runtime workspaces
- create reports, backups, scripts, and runner folders
- create or inspect devcontainer files
- install and manage local self-hosted runner services
- build and package a local macOS app bundle

2. Local Paths And Artifacts

Depending on the selected edition and actions taken, CSA-iEM may write to:
- the configured workspace root
- ~/.config/csa-iem/
- legacy compatibility settings under ~/.config/csa-ilem/
- ~/.local/bin/
- ~/Library/LaunchAgents/
- ~/Library/Logs/
- build output such as .build/ and dist/

3. Network Activity

CSA-iEM may initiate network activity through the tools it invokes, including GitHub CLI, Git, Docker, Homebrew, npm, Swift Package Manager, and related package or registry systems. That network activity may involve:
- repository metadata
- repository cloning and fetching
- GitHub API requests
- runner registration requests
- container image pulls
- package downloads
- Swift package dependency resolution and build traffic

4. Credentials And Tokens

CSA-iEM does not implement its own separate identity system. It relies on credentials already managed by the third-party tools it uses, especially GitHub CLI. You are responsible for:
- securing tokens and credentials
- managing GitHub scopes and access
- understanding which account is active
- ensuring you have authorization to act on the target repositories and systems

5. Sensitive Data

CSA-iEM may operate in directories that contain source code, secrets, environment files, generated reports, build output, workflow configuration, or packaged `.app` artifacts. You are responsible for reviewing what is stored in those directories and for protecting sensitive information.

6. Third-Party Services

When CSA-iEM uses third-party tools or services, data handling is also subject to the privacy terms and operational behavior of those third parties. Wayne Tech Lab LLC does not control third-party privacy practices.

7. User Responsibility

Before using CSA-iEM in a regulated, enterprise, or production environment, review:
- what directories it writes to
- what reports and logs it creates
- what third-party services it contacts
- whether your organization requires additional notices, approvals, or retention controls

8. Contact

Wayne Tech Lab LLC
https://www.WayneTechLab.com
