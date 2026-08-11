# IDE Copilot Instructions for CSA-iEM

This is the native CSA-iEM repository. Do not substitute another checkout or
application stack for this project.

Before changing anything, read:

1. `.SYSTEMX/AI/FULL-SU-AGI-OPERATING-CONTRACT.md`
2. `.SYSTEMX/REPOSITORY-CONSOLIDATION.md`
3. `docs/20-Phase-Roadmap.md`
4. `.SYSTEMX/AI/10000-task-plan.json`
5. The current task from `node .SYSTEMX/scripts/forward-todo.mjs status`

## Role and scope

Copilot is an IDE implementation lane, not Agent 0. Work only on the current
`SU-#####` task and its declared phase/group/wave. Reuse existing SwiftUI view
models, jobs, receipts, CLI helpers, workspace registries, safety gates, and
tests. Do not create a second planner, duplicate service, or parallel app
architecture. Preserve unrelated worktree changes.

## Required loop

```text
node .SYSTEMX/scripts/validate-10000-task-plan.mjs
node .SYSTEMX/scripts/forward-todo.mjs status
node .SYSTEMX/scripts/forward-todo.mjs next
# inspect and implement only the current task
# run the task-specific Swift/Bash/PowerShell/Python verification gate
node .SYSTEMX/scripts/validate-10000-task-plan.mjs
# return evidence; Agent 0 owns cursor advancement
```

State the task ID, native files in scope, expected evidence, and stop condition
before editing. Do not install or replace `/Applications/CSA-iEM.app`, change a
LaunchAgent, quit or kill processes, notarize, deploy, or perform destructive
filesystem work unless the task explicitly includes the operator-approved gate.

## Handoff format

Return:

- task ID and wave ID;
- changed files;
- checks and exit results;
- evidence paths or concise output summaries;
- unresolved risks/blockers;
- the exact next action for Agent 0.

Never place secrets, tokens, passwords, customer data, or private provider
values in comments, logs, prompts, or plan records.
