# CSA-iEM SYSTEMX AI Operating Layer

This folder defines the bounded coordination contract used by Agent 0 and IDE
Copilot while extending the native CSA-iEM application.

| File | Purpose |
| --- | --- |
| `FULL-SU-AGI-OPERATING-CONTRACT.md` | Full SatoshiUNO mode, lane ownership, approvals, evidence, and the forward todo loop. |
| `10000-task-plan.json` | Machine-readable 20-phase, 100-group, 1,000-wave, 10,000-task plan. |
| `10000-TASK-PLAN.md` | Human-readable phase, milestone, group, and wave index. |
| `agent-mesh.schema.json` | Task/checkpoint/handoff envelope schema for Agent 0 and Copilot lanes. |

IDE Copilot follows the repository-level [Copilot instructions](../../.github/copilot-instructions.md).
It does not become an unbounded operator, deployment authority, or hidden
second task system.

The native dashboard/module identity contract is maintained in
`../../docs/wiki/CSA-iLEM-Dashboard-and-Module-Matrix.md` and implemented by
`Sources/CSAiEMMacApp/CSAiEMModuleMatrix.swift`. UI, engine, bridge, runtime,
and install/update work should update that matrix after verification.
