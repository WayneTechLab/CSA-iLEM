## Security Notes

`CSA-iEM` uses the existing GitHub CLI authentication state instead of embedding or storing GitHub tokens itself.

Privacy-First Mode is enabled by default in the macOS app. Startup checks report only local tool readiness and whether GitHub CLI has an active session; they do not import or persist account identity, repository inventory, organization data, API keys, or tokens. Active GitHub identity is redacted from the app's live and job logs.

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

### Firebase Apple Client Configuration

The native app ships Firebase's Apple client configuration file and pins the
Firebase Apple SDK. Firebase client API keys identify a project and app; they
are not backend authorization credentials. Access to any future Firebase data
service must be enforced with Firebase Security Rules, IAM where applicable,
and App Check rather than by hiding the client file.

The current integration initializes `FirebaseCore` only. It does not include
Analytics, Authentication, Firestore, Realtime Database, Cloud Storage,
Messaging, or Firebase Hosting. Do not place service-account JSON, private
keys, OAuth client secrets, Gemini Developer API keys, or unrestricted Google
Cloud API keys in `GoogleService-Info.plist` or anywhere in the app bundle.
Before enabling another Firebase product, review its rules, App Check support,
API-key restrictions, macOS entitlements, privacy disclosure, and test lane.

`.SYSTEMX/scripts/verify-firebase-apple-config.sh` checks the required client
fields and exact CSA-iLEM bundle/project identity without printing the field
values. The release preflight and GUI builder both run that verifier.

### GUI Log Handling

The native app redacts common token and secret patterns before showing command output in its live log panel.

Examples of redacted patterns include:

- GitHub PAT formats such as `ghp_` and `github_pat_`
- bearer authorization headers
- common `access_token`, `client_secret`, and `api_key` assignments

### Operational Risk

Checkout Review compares explicit local roots and live github.com repository
IDs without fetching, resetting, pulling, or publishing. Read-only inspection
disables repository hooks, fsmonitor, custom clean/process filters, and lazy
fetching. Its complete physical manifest includes generated and hidden data;
missing, changed, unreadable, or bounded evidence cannot authorize retirement.
Retirement uses a same-volume exclusive rename into private recovery storage,
full read-back verification, and durable restore receipts. The active app,
protected paths, active files/process working directories, shared Git storage,
overlapping paths, and changed physical recovery parents remain guarded.
Provider identity and similar names are review evidence, not deletion authority.

Transfer-artifact cleanup requires exact transaction names, approved physical
containers, complete source/canonical inventories, inactive sources, and fresh
pre/post checks. Canonical symlinks into artifacts, shared Git storage, changed
evidence, unknown parents, and incomplete scans remain blocked. Full prepared
proof and a pending ledger precede each exclusive recovery rename. Recovery
verification retains previously completed archive records and starts no new
moves. The opt-in completion hook excludes read-only, failed, cancelled,
dry-run, startup, and undo work, and waits for other local writers.

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
