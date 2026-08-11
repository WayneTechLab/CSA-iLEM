# CSA-iEM Full SU AGI-Style Operating Contract

This contract extends the native CSA-iEM roadmap with a bounded execution loop.
`AGI` means coordinated planning, evidence routing, dependency awareness, and
next-action selection. It does not grant hidden autonomy, production authority,
or permission to bypass the operator.

## Scope boundary

This plan belongs to the native CSA-iEM repository only:

```text
/Volumes/WTL - Backup 2026/CSA-iEM/Code/Repos/WayneTechLab/CSA-iLEM
```

Unrelated application work and other checkouts are out of scope unless a task
explicitly names an approved integration contract.

## Full SU mode

`FULL_SU` means the `SatoshiUNO`-style human/AI contract is applied at every
task:

- Agent 0 coordinates, routes, checkpoints, reviews evidence, and owns the
  forward cursor.
- IDE Copilot is a scoped `code`, `test`, or `docs` lane for Swift, Bash,
  PowerShell, Python, JSON, Markdown, and native-app support files.
- The operator owns credentials, external accounts, production deploys,
  destructive filesystem actions, paid services, notarization, and final
  acceptance.
- Native macOS UI and local backends stay fail-closed; a visible control is not
  evidence that a privileged operation executed.
- No secret, token, password, customer data, or private provider value is put
  into the plan, Copilot instructions, or durable logs.
- Existing architecture, helpers, receipts, registries, schemas, and tests are
  extended before a new parallel system is considered.
- The active CSA-iLEM checkout is protected from discovery, retirement,
  cleanup, replacement, and compatibility-link operations.

## Exact hierarchy

The generated plan is fixed at:

```text
20 phases
  x 5 groups per phase
  x 10 waves per group
  x 10 todo tasks per wave
  = 10,000 tasks
```

The phases come from [`docs/20-Phase-Roadmap.md`](../../docs/20-Phase-Roadmap.md).
The task-level source of truth is [`10000-task-plan.json`](./10000-task-plan.json),
with a readable index in [`10000-TASK-PLAN.md`](./10000-TASK-PLAN.md).

## Forward todo loop

Every task is initially visible as `todo` with canonical Agent Mesh status
`planned`. The only allowed transitions are:

```text
planned -> in_progress -> needs_review -> done -> archived
planned -> blocked
in_progress -> blocked
needs_review -> blocked
blocked -> in_progress
```

Blocked work resumes after the concrete blocker and evidence are recorded; it
does not reset to todo or silently skip forward. There is no direct
`planned -> done` path.

For every cursor step Agent 0 must:

1. Read the phase milestone, group objective, wave objective, task acceptance,
   and predecessor evidence.
2. Record the task ID, `missionId`, `waveId`, lane, actor, status, summary,
   blockers, evidence, and `nextAction`.
3. Assign IDE Copilot only the current task's declared file and behavior scope.
4. Run task-specific verification and the relevant native-app or backend gate.
5. Record sanitized evidence before changing the task status.
6. Advance exactly one task through
   `node .SYSTEMX/scripts/forward-todo.mjs advance`.

The mutable cursor lives in ignored local state at
`.SYSTEMX/state/10000-forward-cursor.json`; the plan and rules remain tracked.
The append-only local loop log is under `.SYSTEMX/logs/`.

## IDE Copilot handoff

Before editing, Copilot must read this contract, the current task record, the
relevant roadmap phase, and the current worktree state. It must state:

- task and wave IDs;
- native files in scope;
- expected evidence and stop condition;
- commands/tests it will run;
- any operator approval boundary.

Copilot must preserve unrelated changes, avoid broad rewrites, avoid a second
registry or task planner, and return changed files, checks, evidence, risks,
blockers, and the exact next action to Agent 0.

## Gate meanings

- `planned`: todo and not started;
- `in_progress`: one lane owns the task;
- `needs_review`: output exists but Agent 0/operator review is pending;
- `blocked`: a concrete blocker is recorded and speculative work stops;
- `done`: acceptance and evidence pass;
- `archived`: the completed task has been summarized into durable history.

Generating the plan does not complete product work. A phase milestone closes
only after its 500 tasks pass their gates and the milestone evidence is recorded.
