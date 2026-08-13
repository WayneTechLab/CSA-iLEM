# GitHub Issue Provider Smoke Test

This test is intentionally separate from the normal release preflight because
it performs remote writes. It is restricted to the three temporary CSA-iLEM
repositories:

- `WayneTechLab/Flowers-Field-Guide`
- `WayneTechLab/Space-Field-Guide`
- `WayneTechLab/Birds-Field-Guide`

Run it only when those repositories are still designated as temporary test
repositories:

```bash
bash .SYSTEMX/scripts/github-issue-provider-smoke.sh \
  --confirm-retained-test-repos --all
```

The harness reuses or creates one clearly marked issue per repository, adds a
known comment and the existing `bug` label, transitions the issue through
closed and reopened states, and verifies the final provider response. It never
deletes issues, repositories, labels, or local project folders. The test
repositories and their issues remain available for operator review and must be
removed only after explicit confirmation.

The native app applies the same provider contract through its `gh` bridge. A
non-zero provider result is a failed job; a 60-second command limit is reported
as a timeout; and a failed or mismatched read-back creates an Incident Hub
record rather than a false success. Jobs Center retry restores the exact
reviewed mutation payload but requires the operator to review and re-arm it.
