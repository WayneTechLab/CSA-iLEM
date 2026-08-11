#!/usr/bin/env node

import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(scriptDir, '../..')
const systemxDir = path.join(rootDir, '.SYSTEMX')
const planPath = path.join(systemxDir, 'AI', '10000-task-plan.json')
const cursorPath = path.join(rootDir, '.SYSTEMX', 'state', '10000-forward-cursor.json')
const logPath = path.join(rootDir, '.SYSTEMX', 'logs', '10000-forward-todo.jsonl')

function loadPlan() {
  if (!existsSync(planPath)) throw new Error('Plan is missing. Run node .SYSTEMX/scripts/build-10000-task-plan.mjs first.')
  return JSON.parse(readFileSync(planPath, 'utf8'))
}

function flattenTasks(plan) {
  return plan.phases.flatMap((phase) => phase.groups.flatMap((group) => group.waves.flatMap((wave) => wave.tasks)))
}

function parseArguments(argv) {
  const command = argv[0] || 'status'
  const options = {}
  for (let index = 1; index < argv.length; index += 1) {
    const argument = argv[index]
    if (!argument.startsWith('--')) throw new Error('Unknown argument: ' + argument)
    const equalsIndex = argument.indexOf('=')
    if (equalsIndex >= 0) {
      options[argument.slice(2, equalsIndex)] = argument.slice(equalsIndex + 1)
      continue
    }
    const key = argument.slice(2)
    if (key === 'force' || key === 'json') {
      options[key] = true
      continue
    }
    const value = argv[index + 1]
    if (!value || value.startsWith('--')) throw new Error('Missing value for --' + key)
    options[key] = value
    index += 1
  }
  return { command, options }
}

function sanitizeText(value) {
  if (!value) return null
  return String(value)
    .replace(/(ghp_|github_pat_|sk-|AIza)[A-Za-z0-9_./-]+/g, '$1[REDACTED]')
    .replace(/(Bearer\s+)[A-Za-z0-9._-]+/gi, '$1[REDACTED]')
    .replace(/((?:token|password|secret|api[_-]?key)\s*[=:]\s*)[^\s,;]+/gi, '$1[REDACTED]')
}

function writeCursor(cursor) {
  mkdirSync(path.dirname(cursorPath), { recursive: true })
  writeFileSync(cursorPath, JSON.stringify(cursor, null, 2) + '\n')
}

function appendEvent(event) {
  mkdirSync(path.dirname(logPath), { recursive: true })
  appendFileSync(logPath, JSON.stringify({ ...event, createdAt: new Date().toISOString() }) + '\n')
}

function readCursor(plan) {
  if (!existsSync(cursorPath)) return null
  const cursor = JSON.parse(readFileSync(cursorPath, 'utf8'))
  if (cursor.planId !== plan.planId) throw new Error('Cursor belongs to a different plan: ' + cursor.planId)
  if (cursor.mode !== plan.mode) throw new Error('Cursor mode does not match the plan')
  if (cursor.currentTaskId !== null && typeof cursor.currentTaskId !== 'string') throw new Error('Cursor currentTaskId is invalid')
  if (!Number.isInteger(cursor.completedCount) || cursor.completedCount < 0 || cursor.completedCount > plan.hierarchy.totalTasks) {
    throw new Error('Cursor completedCount is invalid')
  }
  return cursor
}

function taskById(tasks, taskId) {
  const task = tasks.find((candidate) => candidate.id === taskId)
  if (!task) throw new Error('Unknown task ID: ' + taskId)
  return task
}

function taskView(task) {
  if (!task) return null
  return {
    id: task.id,
    forwardIndex: task.forwardIndex,
    phaseId: task.phaseId,
    milestoneId: task.milestoneId,
    missionId: task.missionId,
    groupId: task.groupId,
    waveId: task.waveId,
    step: task.step,
    title: task.title,
    lane: task.lane,
    actor: task.actor,
    status: task.status,
    todo: task.todo,
    acceptance: task.acceptance,
    nextAction: task.nextAction,
    copilotPrompt: task.copilotPrompt,
  }
}

function output(value, asJson) {
  if (asJson) {
    console.log(JSON.stringify(value, null, 2))
    return
  }
  if (typeof value === 'string') {
    console.log(value)
    return
  }
  console.log(JSON.stringify(value, null, 2))
}

function makeInitialCursor(plan, firstTask) {
  return {
    planId: plan.planId,
    mode: plan.mode,
    currentTaskId: firstTask.id,
    currentStatus: firstTask.status,
    completedCount: 0,
    lastCompletedTaskId: null,
    updatedAt: new Date().toISOString(),
    nextAction: firstTask.nextAction,
  }
}

function status(plan, tasks, options) {
  const cursor = readCursor(plan)
  if (!cursor) {
    output({
      planId: plan.planId,
      mode: plan.mode,
      cursorExists: false,
      completedCount: 0,
      totalTasks: tasks.length,
      currentTask: taskView(tasks[0]),
      nextAction: 'Run node .SYSTEMX/scripts/forward-todo.mjs init to create the local cursor.',
    }, options.json)
    return
  }
  const currentTask = cursor.currentTaskId ? taskById(tasks, cursor.currentTaskId) : null
  output({
    planId: plan.planId,
    mode: plan.mode,
    cursorExists: true,
    cursor,
    totalTasks: tasks.length,
    currentTask: taskView(currentTask),
  }, options.json)
}

function next(plan, tasks, options) {
  const cursor = readCursor(plan)
  if (!cursor) {
    output({
      action: 'init',
      task: taskView(tasks[0]),
      command: 'node .SYSTEMX/scripts/forward-todo.mjs init',
    }, options.json)
    return
  }
  const currentTask = cursor.currentTaskId ? taskById(tasks, cursor.currentTaskId) : null
  output({
    action: cursor.currentStatus === 'complete' ? 'closeout' : 'work-current-task',
    status: cursor.currentStatus,
    task: taskView(currentTask),
    nextAction: cursor.nextAction,
    command: currentTask ? 'node .SYSTEMX/scripts/forward-todo.mjs advance --task ' + currentTask.id + ' --to in_progress' : null,
  }, options.json)
}

function advance(plan, tasks, options) {
  const cursor = readCursor(plan)
  if (!cursor) throw new Error('Cursor is not initialized. Run node .SYSTEMX/scripts/forward-todo.mjs init first.')
  if (cursor.currentStatus === 'complete') throw new Error('All tasks are complete; no forward task remains.')
  if (!options.task) throw new Error('advance requires --task SU-xxxxx')
  if (!options.to) throw new Error('advance requires --to <in_progress|needs_review|done|blocked>')
  if (options.task !== cursor.currentTaskId) {
    throw new Error('Forward-only cursor is on ' + cursor.currentTaskId + '; received ' + options.task)
  }

  const task = taskById(tasks, cursor.currentTaskId)
  const from = cursor.currentStatus
  const to = options.to
  const allowed = plan.forwardLoop.transitions[from] || []
  if (!allowed.includes(to)) throw new Error('Invalid transition ' + from + ' -> ' + to + ' for ' + task.id)
  const evidence = sanitizeText(options.evidence)
  const blocker = sanitizeText(options.blocker)
  if (to === 'done' && !evidence) throw new Error('done requires --evidence')
  if (to === 'blocked' && !blocker) throw new Error('blocked requires --blocker')
  if (from === 'blocked' && to === 'in_progress' && !evidence) {
    throw new Error('Resuming a blocked task requires --evidence describing the unblock')
  }

  const now = new Date().toISOString()
  const nextTask = to === 'done' ? tasks[task.forwardIndex] : null
  appendEvent({
    id: plan.planId + '-' + task.id + '-' + Date.now(),
    missionId: task.missionId,
    waveId: task.waveId,
    taskId: task.id,
    lane: task.lane,
    actor: 'agent_0',
    type: to === 'blocked' ? 'blocked' : to === 'done' ? 'complete' : 'checkpoint',
    status: to,
    summary: 'Agent 0 moved ' + task.id + ' from ' + from + ' to ' + to + '.',
    evidence: evidence ? [evidence] : [],
    blockers: blocker ? [blocker] : [],
    nextAction: to === 'blocked'
      ? 'Resolve the recorded blocker, then resume this same task with evidence.'
      : task.nextAction,
  })

  if (to === 'done') {
    appendEvent({
      id: plan.planId + '-' + task.id + '-' + Date.now() + '-archive',
      missionId: task.missionId,
      waveId: task.waveId,
      taskId: task.id,
      lane: task.lane,
      actor: 'agent_0',
      type: 'archive',
      status: 'archived',
      summary: 'Archived completed task ' + task.id + ' after acceptance evidence was recorded.',
      evidence: evidence ? [evidence] : [],
      blockers: [],
      nextAction: nextTask
        ? nextTask.nextAction
        : 'All 10,000 tasks are complete; retain evidence and record the final milestone closeout.',
    })
    cursor.completedCount += 1
    cursor.lastCompletedTaskId = task.id
    if (nextTask) {
      cursor.currentTaskId = nextTask.id
      cursor.currentStatus = nextTask.status
      cursor.nextAction = nextTask.nextAction
    } else {
      cursor.currentTaskId = null
      cursor.currentStatus = 'complete'
      cursor.nextAction = 'All 10,000 tasks are complete; retain evidence and record the final milestone closeout.'
    }
  } else {
    cursor.currentStatus = to
    cursor.nextAction = to === 'blocked'
      ? 'Resolve the recorded blocker, then resume this same task with evidence.'
      : task.nextAction
  }
  cursor.updatedAt = now
  writeCursor(cursor)
  output({
    updated: true,
    taskId: task.id,
    from,
    to,
    archived: to === 'done',
    cursor,
    nextTask: cursor.currentTaskId ? taskView(taskById(tasks, cursor.currentTaskId)) : null,
  }, options.json)
}

function init(plan, tasks, options) {
  if (existsSync(cursorPath) && !options.force) {
    throw new Error('Cursor already exists. Use --force only when intentionally resetting local progress.')
  }
  const cursor = makeInitialCursor(plan, tasks[0])
  writeCursor(cursor)
  appendEvent({
    id: plan.planId + '-' + tasks[0].id + '-' + Date.now(),
    missionId: tasks[0].missionId,
    waveId: tasks[0].waveId,
    taskId: tasks[0].id,
    lane: tasks[0].lane,
    actor: 'agent_0',
    type: 'task',
    status: 'planned',
    summary: 'Initialized the local CSA-iLEM FULL_SU forward cursor.',
    evidence: ['Local cursor initialized for CSA-iLEM FULL_SU execution.'],
    blockers: [],
    nextAction: tasks[0].nextAction,
  })
  output({ initialized: true, cursor }, options.json)
}

try {
  const parsed = parseArguments(process.argv.slice(2))
  const plan = loadPlan()
  const tasks = flattenTasks(plan)
  if (tasks.length !== plan.hierarchy.totalTasks) throw new Error('Plan task count does not match its hierarchy')

  if (parsed.command === 'init') init(plan, tasks, parsed.options)
  else if (parsed.command === 'status') status(plan, tasks, parsed.options)
  else if (parsed.command === 'next') next(plan, tasks, parsed.options)
  else if (parsed.command === 'advance') advance(plan, tasks, parsed.options)
  else throw new Error('Unknown command: ' + parsed.command)
} catch (error) {
  console.error('FAIL: ' + error.message)
  process.exitCode = 1
}
