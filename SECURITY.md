## Security Notes

`CSA-iEM` uses the existing GitHub CLI authentication state instead of embedding or storing GitHub tokens itself.

### What This Project Stores

The project stores only the last-used:

- GitHub host
- GitHub account name
- repository target

That data is stored in:

- `~/Library/Application Support/CSA-iEM/last-session.env`

For compatibility, the app can also read older non-secret session values from:

- `~/Library/Application Support/CSA-iLEM/last-session.env`
- `~/Library/Application Support/GH Workflow Clean/last-session.env`
- `~/Library/Application Support/GitHub Action Clean-Up Tool/last-session.env`

### What This Project Does Not Intentionally Store

This project does not intentionally store:

- GitHub personal access tokens
- GitHub API keys
- private SSH keys
- cloud provider secret keys

### GUI Log Handling

The native app redacts common token and secret patterns before showing command output in its live log panel.

Examples of redacted patterns include:

- GitHub PAT formats such as `ghp_` and `github_pat_`
- bearer authorization headers
- common `access_token`, `client_secret`, and `api_key` assignments

### Operational Risk

The primary risk in `CSA-iEM` is destructive workflow and environment change, not secret storage.

The app can:

- disable GitHub Actions at repo scope
- delete workflow runs, artifacts, caches, and Codespaces
- patch workflow files
- stop local runners and containers

Use dry runs and scoped review before destructive changes.

### Review Summary

Review pass completed: March 9, 2026

Checks performed:

- shell script syntax review
- native app log redaction review
- installer and bundle resource review
- session persistence path review
- direct cleanup flag surface review

### Reporting

If you discover a security issue, review the repository owner and contact channels at:

- [www.WayneTechLab.com](https://www.WayneTechLab.com)
