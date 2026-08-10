# Repository Consolidation Lifecycle

## Active Project Boundary

The active Codex project checkout is the checkout containing this policy and
the operator application. Its machine-specific absolute path is resolved at
runtime and recorded only in local reviewed configuration and receipts.

This checkout contains the operator application and lifecycle implementation.
It is protected from project discovery, source retirement, quarantine cleanup,
and compatibility-link replacement. A path match to the active checkout must
block the affected operation rather than treating the checkout as old project
data.

## Canonical Result

Each GitHub repository resolves to exactly one canonical project directory:

```text
<managed-root>/Code/Repos/<canonical-owner>/<canonical-repository>
```

Folder names, local aliases, historical owners, worktrees, Stage 1 copies, and
legacy workspace roots do not create additional canonical projects. They are
source variants whose non-conflicting content is reconciled into the single
identity-bound destination. File-versus-directory conflicts, divergent Git
history, dirty canonical worktrees, incomplete object databases, and content
that cannot be represented without loss stop the project fail-closed.

The lifecycle does not declare success from a folder copy alone. It requires a
complete source inventory, deterministic destination manifests, content and
symlink verification, Git object verification where applicable, and a final
audit proving that every eligible repository has one canonical directory.

## GitHub Identity

Repository identity is resolved in this order:

1. GitHub repository database ID and node ID when available.
2. Canonical owner and repository name returned by GitHub.
3. Verified remote URL, remote HEAD, and local commit ancestry.
4. An explicit reviewed identity mapping for a legacy or renamed source.

Case-only path differences, renamed local folders, and legacy remotes are not
separate repositories when the GitHub identity is the same. Conflicting IDs,
owners, remotes, archived state, or unrelated histories block automatic merge.
A missing repository may be created only as a private, empty repository under
the approved account; creation does not authorize an implicit commit or push.
Historical identities remain receipt evidence and must not replace the approved
canonical WayneTechLab identity.

## Receipt-Bound Local Retirement

Local and Stage 1 sources remain in place until the external managed workspace
contains a verified representation of every source entry and the transaction
has emitted its success marker. Retirement is allowed only for exact paths
listed by the successful transaction receipts.

Before any original is retired, the lifecycle must prove:

- the source path and filesystem identity still match the preflight record;
- the canonical destination has the expected repository identity;
- every source file, directory, and symlink is represented in the canonical
  destination or in an explicit, verified conflict-preservation record;
- Git objects and required worktree state are valid;
- no failed or incomplete project remains in the transaction; and
- the active project checkout is not the source or a descendant of the source.

Retirement is a separate receipt-linked phase. A partial copy, preflight
report, staged destination, ZIP archive, matching folder name, or successful
GitHub lookup is not permission to remove local data. If verification changes
or any receipt cannot be revalidated, the source is retained.

## Receipt-Linked `_temp` Cleanup

Temporary data is cleaned only after canonical consolidation and receipt-bound
local retirement have both completed and a fresh end-to-end audit succeeds.
Cleanup selects exact transaction paths from receipts; it does not delete an
entire `_temp` root and does not infer targets from age or folder name.

Final cleanup may remove verified staging trees, source quarantines, and indexes
that belong exclusively to the completed transaction. It preserves canonical
repositories, active workspaces, failed or incomplete transactions, unrelated
temporary data, ZIP archives unless explicitly selected, and the final reports
and receipts needed to prove what was merged and removed.

The safe lifecycle order is therefore:

```text
inventory -> identity bind -> stage -> merge -> verify canonical result
          -> write success receipts -> retire exact local/Stage 1 sources
          -> reverify -> delete exact receipt-linked temporary data
          -> preserve final audit evidence
```

Any missing proof stops the lifecycle at its current phase with sources and
cleanup evidence retained.

## Bounded Parallel Recovery

Large inventories may use two repository-group workers. A worker owns exactly
one canonical destination and its transaction-specific staging, rollback,
report, receipt, and checkpoint lanes. Copies that target the same repository
remain serialized so no two streams write one project tree. Recovery audits
normalized destinations, group keys, source IDs, physical inodes, Git common
directories, source paths, and cross-group source/destination containment.
Overlapping groups share a serial conflict-component lock while unrelated
repositories continue on both lanes. Duplicate destination or report lanes
reduce the complete run to one worker.

Repository creation completes before workers start. Workers may assemble,
verify, promote, and finalize only their own destination group. The coordinator
joins all workers, requires the exact planned group count, and rehashes every
final group receipt before it can enter global retirement. Workspace swaps,
source retirement, transaction success, local deletion, and external temporary
cleanup always remain single-coordinator phases. A worker failure retains all
sources and blocks every cleanup authorization.

Repeated scans use a persistent SHA-256 index in managed `Runtime/Indexes`.
Index keys bind the absolute path to device, inode, type, links, ownership,
size, mode, flags, mtime, and ctime. Recovery re-stats before and after every
lookup; a changed or unindexed path is fully read and hashed. Index failures
fall back to direct hashing and never count as verification. Every transaction
writes hit, miss, write, error, and entry counts into its report.

The operator loop is `scan -> review identity -> plan -> execute deltas ->
verify receipts -> retire proven copies -> clean receipt-linked temp -> sweep
original roots`. Any newly discovered project or changed path begins another
scan pass. Success requires zero eligible missed sources, zero staging copies,
one canonical folder per repository, and preserved reports/receipts.

## Interrupted Transactions

An apply transaction may resume only from destination groups that emitted a
final receipt before interruption. The exact transaction identifier and source
map must be reused, and the lifecycle must freshly verify source filesystem
identity, Git and GitHub identity, remote state, canonical content, and complete
representation evidence. Partial staging is never a checkpoint. Once global
retirement or workspace promotion begins, resume is blocked and the retained
evidence requires operator review.

Failed and incomplete transaction directories are not general cleanup targets.
External temporary payload deletion requires a successful recovery marker, the
completed local-retirement audit, a fresh canonical audit, and the explicit
`DELETE-VERIFIED-EXTERNAL-TEMP-PAYLOADS` token. Only receipt-enumerated staging,
retirement, and local-evidence payloads are eligible; reports, receipts,
archives, canonical repositories, and unrelated temporary paths remain.
