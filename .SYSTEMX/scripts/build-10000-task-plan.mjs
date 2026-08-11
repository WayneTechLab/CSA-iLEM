#!/usr/bin/env node

import { mkdirSync, writeFileSync } from 'node:fs'
import path from 'node:path'

const rootDir = process.cwd()
const outputDir = path.join(rootDir, '.SYSTEMX', 'AI')

const phases = [
  ['Unified Backend Contract', 'Every major operation has one stable conceptual input, output, status, log, report, and recovery shape across native clients and shell backends.'],
  ['Native Job Engine Everywhere', 'Long-running import, cleanup, patch, backup, runner, and devcontainer work is visible through one jobs model.'],
  ['GUI Terminal Console Layer', 'Advanced shell output remains available in the app while terminal fallback becomes optional diagnostics.'],
  ['Native Import Center', 'Normal repo migration and local setup can be completed from the native import workflow with resumable evidence.'],
  ['Project Library 2.0', 'The project library becomes the primary operating surface for grouped views, search, filters, favorites, and health.'],
  ['Devcontainer Control Center', 'Devcontainer lifecycle, health, mapping, configuration, and warnings are controllable in-app.'],
  ['Runner Fleet Manager', 'Self-hosted runner installation, repair, labels, services, health, activity, and paths are managed visibly.'],
  ['Workflow Control Center', 'Workflow inventory, enable/disable, dispatch, patch preview, YAML, and runner-target analysis are native flows.'],
  ['Workflow Runs Explorer', 'The app explains what ran, what failed, the relevant logs and artifacts, and the safe next action.'],
  ['Cleanup and Cost-Control Command Center', 'Cost and cleanup decisions are preview-first, risk-scored, no-spend-aware, and receipt-bound.'],
  ['GitHub Account and Org Admin Hub', 'Multi-account and organization contexts, inventory, roles, scopes, and context switching are clear and safe.'],
  ['Issues, Bugs, and Incident Hub', 'Recoverable and fatal results become understandable incident records with resume, retry, evidence, and optional issue drafts while safe unrelated work continues.'],
  ['Deep Research Workspace', 'Metadata-first source snapshots, deterministic Smart Logic, local research, active-tool discovery, and evidence views prevent false-positive repository promotion.'],
  ['Secrets, Variables, Policies, and Rules', 'High-impact GitHub governance is visible, permission-aware, and explicitly reviewed before writes.'],
  ['Local Files, Backups, Snapshots, and Restore', 'A dedicated Project Backups dashboard composes import, index, decision, transfer, merge, verify, archive, jobs, snapshots, and recovery without repackaging canonical directories.'],
  ['Native Windows Desktop GUI', 'Windows receives the same GUI-first operator experience over the existing PowerShell backend contract.'],
  ['Packaging, Signing, Notarization, and Trusted Updates', 'macOS and Windows distribution is verifiable, signed or trust-anchored, versioned, and update-safe.'],
  ['Automated QA and Recovery Testing', 'Install, GUI, backend, GitHub permission, identity false-positive, index reuse, continuation, move/export, and rollback behavior has repeatable preflight coverage.'],
  ['Collaboration, Templates, and Automation', 'Teams can reuse task templates, project presets, workspace configurations, interoperable CLI/editor bridges, and approved automation hooks.'],
  ['Product Polish and Best-in-Class Pass', 'The dashboard grammar, deterministic Smart Logic boundary, onboarding, language, accessibility, recovery, consistency, and public release readiness are complete.'],
]

const groups = [
  ['contract', 'Cross-platform contract and domain model', 'Resolve the operation, job, receipt, workspace, and recovery contract for the phase.'],
  ['gui', 'Native GUI and operator UX', 'Make the phase observable, usable, accessible, and safely actionable in the native app.'],
  ['operations', 'GitHub and local operations', 'Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication.'],
  ['platform', 'Platform runtime and packaging', 'Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries.'],
  ['assurance', 'QA, security, docs, and handoff', 'Verify behavior, protect the operator boundary, document evidence, and prepare the next mission.'],
]

const waves = [
  ['scope', 'Scope and objective', 'Turn the phase milestone into a bounded wave objective and stop condition.'],
  ['inventory', 'Evidence inventory', 'Inspect current source, runtime state, dependencies, reports, and prior evidence.'],
  ['contract', 'Contract and acceptance', 'Define interfaces, invariants, acceptance criteria, risk, and ownership.'],
  ['design', 'Native design', 'Choose the smallest extension of existing models, helpers, views, and scripts.'],
  ['implement', 'Scoped implementation', 'Implement one bounded change in the declared files and lane.'],
  ['integrate', 'Architecture integration', 'Connect the change through existing registries, jobs, receipts, and user flows.'],
  ['verify', 'Behavior verification', 'Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior.'],
  ['harden', 'Security and release hardening', 'Run secret, authorization, destructive-action, packaging, and regression gates.'],
  ['handoff', 'Evidence and Copilot handoff', 'Record commands, artifacts, decisions, limits, risks, and operator instructions.'],
  ['gate', 'Wave exit gate', 'Close only when every task is evidenced and the next forward mission is explicit.'],
]

const steps = [
  ['frame', 'Frame the objective', 'research', 'agent_0'],
  ['inspect', 'Inspect current evidence', 'research', 'agent_0'],
  ['specify', 'Specify the contract', 'docs', 'agent_0'],
  ['prepare', 'Prepare the bounded change', 'code', 'ide_copilot'],
  ['execute', 'Execute the scoped change', 'code', 'ide_copilot'],
  ['test', 'Run focused verification', 'test', 'ide_copilot'],
  ['secure', 'Run security and operator gates', 'security', 'agent_0'],
  ['handoff', 'Prepare the IDE Copilot handoff', 'docs', 'ide_copilot'],
  ['evidence', 'Record evidence and next action', 'docs', 'agent_0'],
  ['gate', 'Apply the task gate', 'release', 'agent_0'],
]

const pad = (value, width) => String(value).padStart(width, '0')
const phaseRecords = []
let taskNumber = 0
let previousTaskId = null

for (let phaseIndex = 0; phaseIndex < phases.length; phaseIndex += 1) {
  const [phaseTitle, phaseOutcome] = phases[phaseIndex]
  const phaseId = `P${pad(phaseIndex + 1, 2)}`
  const phaseRecord = {
    id: phaseId,
    sequence: phaseIndex + 1,
    title: phaseTitle,
    milestone: {
      id: `M${pad(phaseIndex + 1, 2)}`,
      title: `Phase ${pad(phaseIndex + 1, 2)} exit — ${phaseTitle}`,
      outcome: phaseOutcome,
      taskCount: groups.length * waves.length * steps.length,
      exitGate: [
        'All phase tasks are done with task-scoped evidence.',
        'No unresolved security, runtime, or operator blocker is hidden by a green command.',
        'The milestone summary and next native-app mission are recorded.',
      ],
    },
    groups: [],
  }

  for (let groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
    const [groupKey, groupTitle, groupObjective] = groups[groupIndex]
    const groupId = `${phaseId}-G${pad(groupIndex + 1, 2)}`
    const groupRecord = {
      id: groupId,
      sequence: groupIndex + 1,
      key: groupKey,
      title: groupTitle,
      objective: `${groupObjective} Phase context: ${phaseTitle}.`,
      waves: [],
    }

    for (let waveIndex = 0; waveIndex < waves.length; waveIndex += 1) {
      const [waveKey, waveTitle, waveObjective] = waves[waveIndex]
      const waveId = `${groupId}-W${pad(waveIndex + 1, 2)}`
      const waveRecord = {
        id: waveId,
        sequence: waveIndex + 1,
        key: waveKey,
        title: waveTitle,
        objective: `${waveObjective} Group context: ${groupTitle}.`,
        taskCount: steps.length,
        tasks: [],
      }

      for (let stepIndex = 0; stepIndex < steps.length; stepIndex += 1) {
        const [stepKey, stepTitle, lane, actor] = steps[stepIndex]
        taskNumber += 1
        const taskId = `SU-${pad(taskNumber, 5)}`
        const task = {
          id: taskId,
          forwardIndex: taskNumber,
          todo: true,
          status: 'planned',
          phaseId,
          milestoneId: phaseRecord.milestone.id,
          missionId: phaseRecord.milestone.id,
          groupId,
          waveId,
          phaseSequence: phaseIndex + 1,
          groupSequence: groupIndex + 1,
          waveSequence: waveIndex + 1,
          taskSequence: stepIndex + 1,
          step: stepKey,
          title: `${stepTitle}: ${phaseTitle} / ${groupTitle} / ${waveTitle}`,
          lane,
          actor,
          dependsOn: previousTaskId ? [previousTaskId] : [],
          acceptance: `The ${stepKey} evidence is recorded for ${waveId}; the change remains bounded to this native-app wave and no secret or unapproved external mutation is introduced.`,
          nextAction: `Work on ${taskId} only, then record evidence before advancing the forward cursor.`,
          copilotPrompt: actor === 'ide_copilot'
            ? `Read the Full SU contract and work only on ${taskId} in ${waveId}; return files, checks, evidence, risks, and the next action to Agent 0.`
            : `Agent 0 coordinates ${taskId} in ${waveId}, validates the evidence, and decides whether the cursor may advance.`,
        }
        waveRecord.tasks.push(task)
        previousTaskId = taskId
      }
      groupRecord.waves.push(waveRecord)
    }
    phaseRecord.groups.push(groupRecord)
  }
  phaseRecords.push(phaseRecord)
}

const manifest = {
  schemaVersion: '1.0.0',
  planId: 'csa-iem-systemx-10000-forward-su',
  title: 'CSA-iEM SYSTEMX Full SU 10,000-Task Forward Execution Plan',
  project: 'CSA-iLEM',
  mode: 'FULL_SU',
  objective: 'Operate the native CSA-iEM product through bounded Agent 0 coordination and IDE Copilot lanes using a forward-only todo loop.',
  scopeRoot: 'CSA-iLEM',
  sourceOfTruth: [
    'docs/20-Phase-Roadmap.md',
    '.SYSTEMX/REPOSITORY-CONSOLIDATION.md',
    '.SYSTEMX/AI/FULL-SU-AGI-OPERATING-CONTRACT.md',
    '.SYSTEMX/AI/CODEX-GPT-ADDON-MASTER-PLAN.md',
    '.github/copilot-instructions.md',
  ],
  hierarchy: {
    phaseCount: phases.length,
    groupsPerPhase: groups.length,
    wavesPerGroup: waves.length,
    tasksPerWave: steps.length,
    tasksPerPhase: groups.length * waves.length * steps.length,
    totalTasks: taskNumber,
  },
  suMode: {
    name: 'SatoshiUNO',
    mode: 'FULL_SU',
    coordinator: 'agent_0',
    implementationLane: 'ide_copilot',
    nativeAppOnly: true,
    operatorApprovalRequiredFor: ['credentials', 'destructive_actions', 'production_deploy', 'paid_services', 'notarization', 'LaunchAgent_changes', 'Applications_replacement'],
    localFirst: true,
    secretSafe: true,
  },
  forwardLoop: {
    cursorFile: '.SYSTEMX/state/10000-forward-cursor.json',
    logFile: '.SYSTEMX/logs/10000-forward-todo.jsonl',
    initialStatus: 'planned',
    transitions: {
      planned: ['in_progress', 'blocked'],
      in_progress: ['needs_review', 'blocked'],
      needs_review: ['done', 'blocked'],
      blocked: ['in_progress'],
      done: ['archived'],
      archived: [],
    },
    noSkip: true,
    oneTaskAtATime: true,
    evidenceBeforeAdvance: true,
  },
  phases: phaseRecords,
}

const markdown = [
  '# CSA-iEM SYSTEMX Full SU 10,000-Task Forward Execution Plan',
  '',
  '> Generated from the native CSA-iEM 20-Phase Product Roadmap. The JSON manifest is the task-level source of truth.',
  '',
  '## Exact allocation',
  '',
  '| Layer | Count |',
  '| --- | ---: |',
  `| Phases | ${phases.length} |`,
  `| Groups per phase | ${groups.length} |`,
  `| Waves per group | ${waves.length} |`,
  `| Todo tasks per wave | ${steps.length} |`,
  `| Tasks per phase | ${groups.length * waves.length * steps.length} |`,
  `| Total tasks | ${taskNumber} |`,
  '',
  'Every task has `todo: true`, canonical status `planned`, a lane, an actor, a predecessor, an acceptance condition, and a next action.',
  '',
  '## Forward loop',
  '',
  '`planned → in_progress → needs_review → done → archived`; blocked work resumes only after its blocker and evidence are recorded. The loop never silently skips or resets a task.',
  '',
  'Use:',
  '',
  '```bash',
  'node .SYSTEMX/scripts/validate-10000-task-plan.mjs',
  'node .SYSTEMX/scripts/forward-todo.mjs init',
  'node .SYSTEMX/scripts/forward-todo.mjs status',
  'node .SYSTEMX/scripts/forward-todo.mjs next',
  '```',
  '',
  '## Phase and milestone index',
  '',
  '| Phase | Milestone | Groups | Waves | Tasks |',
  '| --- | --- | ---: | ---: | ---: |',
]

for (const phase of phaseRecords) {
  markdown.push(`| ${phase.id} — ${phase.title} | ${phase.milestone.id} — ${phase.milestone.title} | ${phase.groups.length} | ${phase.groups.length * waves.length} | ${phase.milestone.taskCount} |`)
}

markdown.push('', '## Group and wave todo index', '')
for (const phase of phaseRecords) {
  markdown.push(`### ${phase.id} — ${phase.title}`, '', `Milestone: **${phase.milestone.title}** — ${phase.milestone.outcome}`, '')
  for (const group of phase.groups) {
    markdown.push(`#### ${group.id} — ${group.title}`, '', group.objective, '')
    for (const wave of group.waves) {
      const firstTask = wave.tasks[0]
      const lastTask = wave.tasks.at(-1)
      markdown.push(`- **${wave.id} — ${wave.title}** — ${wave.taskCount} todo tasks, ${firstTask.id} through ${lastTask.id}. ${wave.objective}`)
    }
    markdown.push('')
  }
}

markdown.push(
  '## Machine-readable source',
  '',
  '- [`10000-task-plan.json`](./10000-task-plan.json) contains every task record.',
  '- [`FULL-SU-AGI-OPERATING-CONTRACT.md`](./FULL-SU-AGI-OPERATING-CONTRACT.md) defines the operating rules.',
  '- [`../scripts/forward-todo.mjs`](../scripts/forward-todo.mjs) enforces the local cursor transitions.',
  '- [`../../.github/copilot-instructions.md`](../../.github/copilot-instructions.md) scopes IDE Copilot to the current task.',
  '',
)

mkdirSync(outputDir, { recursive: true })
writeFileSync(path.join(outputDir, '10000-task-plan.json'), `${JSON.stringify(manifest, null, 2)}\n`)
writeFileSync(path.join(outputDir, '10000-TASK-PLAN.md'), `${markdown.join('\n')}\n`)
console.log(`Generated ${taskNumber} tasks across ${phases.length} phases at .SYSTEMX/AI/10000-task-plan.json`)
