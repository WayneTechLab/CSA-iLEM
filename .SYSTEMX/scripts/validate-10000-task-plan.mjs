#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(scriptDir, '../..')
const planPath = path.join(rootDir, '.SYSTEMX', 'AI', '10000-task-plan.json')
const planMarkdownPath = path.join(rootDir, '.SYSTEMX', 'AI', '10000-TASK-PLAN.md')

const failures = []

function requireCondition(condition, message) {
  if (!condition) failures.push(message)
}

function requireFile(relativePath) {
  requireCondition(existsSync(path.join(rootDir, relativePath)), 'Missing required file: ' + relativePath)
}

function expectedId(prefix, sequence, width) {
  return prefix + String(sequence).padStart(width, '0')
}

function readPlan() {
  requireCondition(existsSync(planPath), 'Missing generated plan: .SYSTEMX/AI/10000-task-plan.json')
  if (!existsSync(planPath)) return null
  try {
    return JSON.parse(readFileSync(planPath, 'utf8'))
  } catch (error) {
    failures.push('Plan JSON is not valid: ' + error.message)
    return null
  }
}

function validate() {
  const plan = readPlan()
  requireFile('.SYSTEMX/README.md')
  requireFile('.SYSTEMX/REPOSITORY-CONSOLIDATION.md')
  requireFile('.SYSTEMX/AI/README.md')
  requireFile('.SYSTEMX/AI/FULL-SU-AGI-OPERATING-CONTRACT.md')
  requireFile('.SYSTEMX/AI/agent-mesh.schema.json')
  requireFile('.github/copilot-instructions.md')
  requireFile('.SYSTEMX/scripts/build-10000-task-plan.mjs')
  requireFile('.SYSTEMX/scripts/forward-todo.mjs')
  requireCondition(existsSync(planMarkdownPath), 'Missing generated plan index: .SYSTEMX/AI/10000-TASK-PLAN.md')
  if (!plan) return

  const hierarchy = plan.hierarchy || {}
  requireCondition(plan.schemaVersion === '1.0.0', 'Unexpected plan schema version')
  requireCondition(plan.planId === 'csa-iem-systemx-10000-forward-su', 'Unexpected plan ID')
  requireCondition(plan.project === 'CSA-iLEM', 'Plan project must be CSA-iLEM')
  requireCondition(plan.scopeRoot === 'CSA-iLEM', 'Plan scope root must be CSA-iLEM')
  requireCondition(plan.mode === 'FULL_SU', 'Plan mode must be FULL_SU')
  requireCondition(hierarchy.phaseCount === 20, 'Hierarchy must contain 20 phases')
  requireCondition(hierarchy.groupsPerPhase === 5, 'Hierarchy must contain 5 groups per phase')
  requireCondition(hierarchy.wavesPerGroup === 10, 'Hierarchy must contain 10 waves per group')
  requireCondition(hierarchy.tasksPerWave === 10, 'Hierarchy must contain 10 tasks per wave')
  requireCondition(hierarchy.tasksPerPhase === 500, 'Hierarchy must contain 500 tasks per phase')
  requireCondition(hierarchy.totalTasks === 10000, 'Hierarchy must contain 10,000 total tasks')

  const suMode = plan.suMode || {}
  requireCondition(suMode.mode === 'FULL_SU', 'SU mode must be FULL_SU')
  requireCondition(suMode.coordinator === 'agent_0', 'Agent 0 must coordinate the plan')
  requireCondition(suMode.implementationLane === 'ide_copilot', 'IDE Copilot must be the implementation lane')
  requireCondition(suMode.nativeAppOnly === true, 'Plan must be native-app-only')
  requireCondition(suMode.localFirst === true, 'Plan must be local-first')
  requireCondition(suMode.secretSafe === true, 'Plan must be secret-safe')

  const forwardLoop = plan.forwardLoop || {}
  requireCondition(forwardLoop.noSkip === true, 'Forward loop must prohibit skips')
  requireCondition(forwardLoop.oneTaskAtATime === true, 'Forward loop must allow one task at a time')
  requireCondition(forwardLoop.evidenceBeforeAdvance === true, 'Forward loop must require evidence before advance')
  requireCondition(forwardLoop.initialStatus === 'planned', 'Forward loop must start at planned')
  requireCondition(forwardLoop.cursorFile === '.SYSTEMX/state/10000-forward-cursor.json', 'Unexpected cursor path')
  requireCondition(forwardLoop.logFile === '.SYSTEMX/logs/10000-forward-todo.jsonl', 'Unexpected log path')

  const transitions = forwardLoop.transitions || {}
  requireCondition(Array.isArray(transitions.planned) && transitions.planned.includes('in_progress'), 'planned must transition to in_progress')
  requireCondition(Array.isArray(transitions.planned) && transitions.planned.includes('blocked'), 'planned must transition to blocked')
  requireCondition(Array.isArray(transitions.in_progress) && transitions.in_progress.includes('needs_review'), 'in_progress must transition to needs_review')
  requireCondition(Array.isArray(transitions.in_progress) && transitions.in_progress.includes('blocked'), 'in_progress must transition to blocked')
  requireCondition(Array.isArray(transitions.needs_review) && transitions.needs_review.includes('done'), 'needs_review must transition to done')
  requireCondition(Array.isArray(transitions.needs_review) && transitions.needs_review.includes('blocked'), 'needs_review must transition to blocked')
  requireCondition(Array.isArray(transitions.blocked) && transitions.blocked.includes('in_progress'), 'blocked must resume through in_progress')
  requireCondition(!((transitions.planned || []).includes('done')), 'planned must not transition directly to done')
  requireCondition(!((transitions.in_progress || []).includes('done')), 'in_progress must not transition directly to done')

  const phases = Array.isArray(plan.phases) ? plan.phases : []
  requireCondition(phases.length === 20, 'Plan has exactly 20 phase records')

  const allTasks = []
  const seenTaskIds = new Set()
  const expectedGroupKeys = ['contract', 'gui', 'operations', 'platform', 'assurance']

  phases.forEach((phase, phaseIndex) => {
    const phaseSequence = phaseIndex + 1
    const phaseId = expectedId('P', phaseSequence, 2)
    requireCondition(phase.id === phaseId, 'Unexpected phase ID at sequence ' + phaseSequence)
    requireCondition(phase.sequence === phaseSequence, 'Unexpected phase sequence for ' + phaseId)
    requireCondition(typeof phase.title === 'string' && phase.title.length > 0, 'Missing title for ' + phaseId)
    requireCondition(phase.milestone && phase.milestone.id === expectedId('M', phaseSequence, 2), 'Missing milestone for ' + phaseId)
    requireCondition(phase.milestone && phase.milestone.taskCount === 500, 'Milestone task count must be 500 for ' + phaseId)
    requireCondition(phase.milestone && Array.isArray(phase.milestone.exitGate) && phase.milestone.exitGate.length === 3, 'Milestone must have three exit gates for ' + phaseId)

    const groups = Array.isArray(phase.groups) ? phase.groups : []
    requireCondition(groups.length === 5, phaseId + ' must contain 5 groups')
    groups.forEach((group, groupIndex) => {
      const groupSequence = groupIndex + 1
      const groupId = phaseId + '-G' + String(groupSequence).padStart(2, '0')
      requireCondition(group.id === groupId, 'Unexpected group ID at ' + phaseId + ' sequence ' + groupSequence)
      requireCondition(group.sequence === groupSequence, 'Unexpected group sequence for ' + groupId)
      requireCondition(group.key === expectedGroupKeys[groupIndex], 'Unexpected group key for ' + groupId)

      const waves = Array.isArray(group.waves) ? group.waves : []
      requireCondition(waves.length === 10, groupId + ' must contain 10 waves')
      waves.forEach((wave, waveIndex) => {
        const waveSequence = waveIndex + 1
        const waveId = groupId + '-W' + String(waveSequence).padStart(2, '0')
        requireCondition(wave.id === waveId, 'Unexpected wave ID at ' + groupId + ' sequence ' + waveSequence)
        requireCondition(wave.sequence === waveSequence, 'Unexpected wave sequence for ' + waveId)
        requireCondition(wave.taskCount === 10, waveId + ' must contain 10 tasks')

        const tasks = Array.isArray(wave.tasks) ? wave.tasks : []
        requireCondition(tasks.length === 10, waveId + ' must contain 10 tasks')
        tasks.forEach((task, taskIndex) => {
          const expectedNumber = allTasks.length + 1
          const taskId = expectedId('SU-', expectedNumber, 5)
          const expectedTaskId = taskId
          requireCondition(task.id === expectedTaskId, 'Unexpected task ID at forward index ' + expectedNumber)
          requireCondition(task.forwardIndex === expectedNumber, 'Unexpected forward index for ' + expectedTaskId)
          requireCondition(task.todo === true, expectedTaskId + ' must remain todo')
          requireCondition(task.status === 'planned', expectedTaskId + ' must start planned')
          requireCondition(task.phaseId === phaseId, expectedTaskId + ' has the wrong phase binding')
          requireCondition(task.missionId === phase.milestone.id, expectedTaskId + ' has the wrong mission binding')
          requireCondition(task.groupId === groupId, expectedTaskId + ' has the wrong group binding')
          requireCondition(task.waveId === waveId, expectedTaskId + ' has the wrong wave binding')
          requireCondition(task.phaseSequence === phaseSequence, expectedTaskId + ' has the wrong phase sequence')
          requireCondition(task.groupSequence === groupSequence, expectedTaskId + ' has the wrong group sequence')
          requireCondition(task.waveSequence === waveSequence, expectedTaskId + ' has the wrong wave sequence')
          requireCondition(task.taskSequence === taskIndex + 1, expectedTaskId + ' has the wrong task sequence')
          requireCondition(typeof task.acceptance === 'string' && task.acceptance.length > 0, expectedTaskId + ' is missing acceptance')
          requireCondition(typeof task.nextAction === 'string' && task.nextAction.length > 0, expectedTaskId + ' is missing next action')
          requireCondition(['research', 'code', 'test', 'security', 'docs', 'release'].includes(task.lane), expectedTaskId + ' has an invalid lane')
          requireCondition(['agent_0', 'ide_copilot'].includes(task.actor), expectedTaskId + ' has an invalid actor')
          const expectedDependency = expectedNumber === 1 ? [] : [expectedId('SU-', expectedNumber - 1, 5)]
          requireCondition(JSON.stringify(task.dependsOn) === JSON.stringify(expectedDependency), expectedTaskId + ' has an invalid predecessor')
          requireCondition(!seenTaskIds.has(task.id), 'Duplicate task ID: ' + task.id)
          seenTaskIds.add(task.id)
          allTasks.push(task)
        })
      })
    })
  })

  requireCondition(allTasks.length === 10000, 'Flattened task count must be 10,000')
  requireCondition(seenTaskIds.size === 10000, 'Task IDs must be unique')
  requireCondition(plan.phases.every((phase) => phase.groups.every((group) => group.waves.every((wave) => wave.tasks.length === 10))), 'Every wave must retain ten task records')
  requireCondition(plan.sourceOfTruth && plan.sourceOfTruth.includes('.github/copilot-instructions.md'), 'Plan must bind the Copilot instructions')
  requireCondition(plan.sourceOfTruth && plan.sourceOfTruth.includes('.SYSTEMX/REPOSITORY-CONSOLIDATION.md'), 'Plan must bind the consolidation contract')

  if (failures.length > 0) {
    throw new Error(failures.join('\n'))
  }

  console.log('PASS: CSA-iLEM FULL_SU plan validated')
  console.log('PASS: 20 phases x 5 groups x 10 waves x 10 tasks = 10,000 todo tasks')
  console.log('PASS: strict predecessor chain SU-00001 through SU-10000')
  console.log('PASS: Agent 0 coordination, IDE Copilot implementation lane, native-app-only scope')
  console.log('PASS: forward loop requires evidence and blocks direct completion skips')
}

try {
  validate()
} catch (error) {
  console.error('FAIL: ' + error.message)
  process.exitCode = 1
}
