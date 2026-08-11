# CSA-iEM SYSTEMX Control Layer

This directory is the native `CSA-iEM` operator application's durable planning
and safety layer. CSA-iLEM is not a website checkout and contains no website
application code. Its
product identity is SwiftUI/AppKit plus Bash/Python/PowerShell support.
Web-oriented markers such as package.json, Firebase, or Vite are only bounded
evidence for an imported project and do not change this repository's identity.

## Source contracts

- [`REPOSITORY-CONSOLIDATION.md`](./REPOSITORY-CONSOLIDATION.md) — protected
  checkout, identity-bound consolidation, receipts, recovery, and cleanup
  boundaries.
- [`AI/FULL-SU-AGI-OPERATING-CONTRACT.md`](./AI/FULL-SU-AGI-OPERATING-CONTRACT.md)
  — Full SU mode and the bounded Agent 0/IDE Copilot loop.
- [`AI/10000-TASK-PLAN.md`](./AI/10000-TASK-PLAN.md) — 20-phase, 10,000-task
  execution index.
- [`../docs/20-Phase-Roadmap.md`](../docs/20-Phase-Roadmap.md) — native product
  roadmap used as the phase source of truth.
- AI/CODEX-GPT-ADDON-MASTER-PLAN.md — dashboard UX, Smart Logic, index/recovery,
  interoperability, and Project Backups operating plan.
- `../docs/wiki/CSA-iLEM-Dashboard-and-Module-Matrix.md` — the shared UI,
  engine, bridge, runtime, and install/update identity matrix.

## Native-app scope

The plan covers SwiftUI macOS surfaces, the Bash/Python/PowerShell backends,
GitHub/local operations, packaging, Windows parity, recovery, and operator
handoff. The app remains GUI-first, preview-first, rollback-aware, and
fail-closed around destructive or external-account actions.

Validate the plan with:

```bash
node .SYSTEMX/scripts/validate-10000-task-plan.mjs
node .SYSTEMX/scripts/forward-todo.mjs status
```
