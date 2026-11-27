import { execFile, spawn } from 'node:child_process'
import { realpathSync } from 'node:fs'
import { createServer } from 'node:http'
import { createConnection, createServer as createTCP } from 'node:net'
import { mkdir, open, readFile, rm, writeFile } from 'node:fs/promises'
import { delimiter, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { randomBytes } from 'node:crypto'
import { setTimeout as delay } from 'node:timers/promises'
import { promisify } from 'node:util'
import { seedFixtures } from './fixtures.mjs'

const isWindows = process.platform === 'win32'
const scriptRoot = fileURLToPath(new URL('../../', import.meta.url))
// Vite requires the long filesystem path when Windows supplies a DOS alias.
const root = isWindows ? realpathSync.native(scriptRoot) : scriptRoot
const local = resolve(root, '.portal-local')
const lock = resolve(local, 'running.lock')
const stateFile = resolve(local, 'session.json')
const configName = '.firebase.portal-local.json'
const configFile = resolve(root, configName)
const host = '127.0.0.1'
const project = 'demo-csa-iem'
const runFile = promisify(execFile)
const children = []
const env = { ...process.env }
const isolatedEnvironmentKeys = new Set([
  'GOOGLE_APPLICATION_CREDENTIALS',
  'GOOGLE_CLOUD_PROJECT',
  'GCLOUD_PROJECT',
  'FIREBASE_CONFIG',
  'FIREBASE_TOKEN',
  'GOOGLE_CLOUD_QUOTA_PROJECT',
  'FIREBASE_AUTH_EMULATOR_HOST',
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_EMULATOR_HUB',
  'HTTPS_PROXY',
  'HTTP_PROXY',
  'ALL_PROXY',
])
for (const key of Object.keys(env)) {
  if (isolatedEnvironmentKeys.has(key.toUpperCase())) delete env[key]
}

async function request(url, options) {
  return fetch(url, { signal: AbortSignal.timeout(1300), ...options })
}

async function sessionCommand(command) {
  const session = JSON.parse(
    await readFile(stateFile, 'utf8').catch(() => '{}'),
  )
  if (
    !session.control ||
    !session.token ||
    !/^http:\/\/127\.0\.0\.1:\d+$/.test(session.control)
  ) {
    throw new Error('No owned CSA-iEM session was found.')
  }
  const response = await request(`${session.control}/${command}`, {
    method: command === 'stop' ? 'POST' : 'GET',
    headers: { Authorization: `Bearer ${session.token}` },
    signal: AbortSignal.timeout(command === 'stop' ? 25_000 : 1300),
  })
  if (response.status === 403)
    throw new Error(
      'The running process did not accept ownership of this session.',
    )
  const message = await response.text()
  if (!response.ok) {
    throw new Error(message || `Local session returned HTTP ${response.status}.`)
  }
  console.log(message)
}

function listen(server, port) {
  return new Promise((resolvePort, reject) => {
    server.once('error', reject)
    server.listen({ host, port, exclusive: true }, () =>
      resolvePort(server.address().port),
    )
  })
}

async function reservePorts() {
  const reservations = []
  async function hold(port) {
    const server = createTCP()
    const actual = await listen(server, port)
    reservations.push(server)
    return actual
  }
  try {
    let vite = 5184
    for (;;) {
      try {
        await hold(vite)
        break
      } catch (error) {
        if (error.code !== 'EADDRINUSE' || vite >= 5299) throw error
        vite += 1
      }
    }
    const result = { vite }
    for (const name of [
      'auth',
      'firestore',
      'functions',
      'hub',
      'logging',
      'firestoreWs',
    ])
      result[name] = await hold(0)
    return result
  } finally {
    await Promise.all(
      reservations.map((server) => new Promise((done) => server.close(done))),
    )
  }
}

let controller, ownership, waiting, state, ports
function child(command, args, options = {}) {
  if (stopping) throw new Error('This local session is stopping.')
  const process = spawn(command, args, {
    cwd: root,
    env,
    // A detached Windows console can bypass the pipes used for readiness.
    detached: !isWindows,
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe'],
    ...options,
  })
  children.push(process)
  process.on('error', (error) => {
    waiting = error
  })
  process.on('exit', (code, signal) => {
    waiting = new Error(`${command} exited (${code ?? signal}).`)
    if (state?.ready) void shutdown(1)
  })
  return process
}

async function until(label, probe) {
  for (let attempt = 0; attempt < 210; attempt += 1) {
    if (waiting) throw waiting
    try {
      if (await probe()) return
    } catch {
      /* Wait for the service to bind. */
    }
    await delay(330)
  }
  throw new Error(`${label} did not become ready.`)
}

let stopping = false
function isRunning(subprocess) {
  return (
    subprocess.pid &&
    subprocess.exitCode === null &&
    subprocess.signalCode === null
  )
}

async function stopChild(subprocess) {
  if (!isRunning(subprocess)) return
  if (!isWindows) {
    // Let the Firebase CLI wait for its emulators and workers to stop.
    subprocess.kill('SIGTERM')
    return
  }
  try {
    await runFile(
      'taskkill.exe',
      ['/pid', String(subprocess.pid), '/t', '/f'],
      { windowsHide: true, timeout: 10_000 },
    )
  } catch (error) {
    if (isRunning(subprocess)) throw error
  }
}

function portClosed(port) {
  return new Promise((resolveClosed) => {
    const socket = createConnection({ host, port, timeout: 300 })
    const stillListening = () => {
      socket.destroy()
      resolveClosed(false)
    }
    socket.once('connect', stillListening)
    socket.once('timeout', stillListening)
    socket.once('error', (error) => resolveClosed(error.code === 'ECONNREFUSED'))
  })
}

async function waitForShutdown() {
  const activePorts = state?.ready ? Object.values(ports) : []
  const deadline = Date.now() + 10_000
  do {
    if (!children.some(isRunning)) {
      const closed = await Promise.all(activePorts.map(portClosed))
      if (closed.every(Boolean)) return
    }
    await delay(100)
  } while (Date.now() < deadline)
  throw new Error('The owned services did not stop in time.')
}

async function shutdown(code, response) {
  if (stopping) {
    response?.writeHead(409).end('This local session is already stopping.')
    return
  }
  stopping = true
  try {
    const results = await Promise.allSettled(children.map(stopChild))
    const failure = results.find((result) => result.status === 'rejected')
    if (failure) throw failure.reason
    await waitForShutdown()
    if (ownership) {
      await Promise.all(
        [stateFile, configFile].map((file) => rm(file, { force: true })),
      )
      await ownership.close()
      await rm(lock, { force: true })
    }
  } catch (error) {
    console.error(`Local session shutdown failed: ${error.message}`)
    if (response) {
      stopping = false
      response.writeHead(500).end(
        'Local session shutdown failed. See the launcher log for details.',
      )
      return
    }
    code = 1
  }
  controller?.close()
  if (response) {
    response.end('Stopped the owned CSA-iEM session.', () => process.exit(code))
  } else {
    process.exit(code)
  }
}

async function start() {
  await mkdir(local, { recursive: true, mode: 0o700 })
  ownership = await open(lock, 'wx', 0o600).catch((error) => {
    if (error.code !== 'EEXIST') throw error
    throw new Error(
      'A CSA-iEM session owns the local lock. Check dev:status or run dev:stop.',
    )
  })
  await ownership.writeFile(String(process.pid))
  process.on('SIGINT', () => void shutdown(0))
  process.on('SIGTERM', () => void shutdown(0))
  ports = await reservePorts()
  const emulator = (name) => ({ host, port: ports[name] })
  const config = {
    firestore: {
      database: 'portal',
      edition: 'enterprise',
      rules: 'portal.rules',
      indexes: 'firestore.indexes.json',
    },
    functions: { source: 'functions', runtime: 'nodejs22' },
    emulators: {
      auth: emulator('auth'),
      firestore: {
        ...emulator('firestore'),
        edition: 'enterprise',
        websocketPort: ports.firestoreWs,
      },
      functions: emulator('functions'),
      hub: emulator('hub'),
      logging: emulator('logging'),
      ui: { enabled: false },
      singleProjectMode: true,
    },
  }
  await writeFile(configFile, JSON.stringify(config, null, 2), { mode: 0o600 })
  const key = randomBytes(32).toString('base64url')
  controller = createServer((req, res) => {
    if (req.headers.authorization !== `Bearer ${key}`) {
      res.writeHead(403).end()
      return
    }
    if (req.url === '/stop' && req.method === 'POST') {
      void shutdown(0, res)
      return
    }
    if (req.url === '/status' && req.method === 'GET') {
      const { token: _token, accounts: _accounts, ...readback } = state
      res.setHeader('Content-Type', 'application/json')
      res.end(JSON.stringify(readback, null, 2))
      return
    }
    res.writeHead(404).end()
  })
  const controlPort = await listen(controller, 0)
  const scope = {
    project,
    auth: `${host}:${ports.auth}`,
    firestore: `${host}:${ports.firestore}`,
    functions: `${host}:${ports.functions}`,
  }
  state = {
    ready: false,
    pid: process.pid,
    url: `http://${host}:${ports.vite}`,
    control: `http://${host}:${controlPort}`,
    token: key,
    ...scope,
  }
  await writeFile(stateFile, JSON.stringify(state, null, 2), { mode: 0o600 })

  const emulatorConfig = resolve(local, 'emulator-config')
  await mkdir(emulatorConfig, { recursive: true, mode: 0o700 })
  const firebaseEnv = {
    ...env,
    XDG_CONFIG_HOME: emulatorConfig,
    CLOUDSDK_CONFIG: emulatorConfig,
    // An explicit nonexistent ADC file prevents discovery of live credentials.
    GOOGLE_APPLICATION_CREDENTIALS: resolve(
      emulatorConfig,
      'no-live-credentials.json',
    ),
    NO_UPDATE_NOTIFIER: '1',
  }
  if (env.CSA_PORTAL_FUNCTIONS_NODE) {
    const pathKey = isWindows
      ? Object.keys(firebaseEnv).find((key) => key.toUpperCase() === 'PATH') ?? 'PATH'
      : 'PATH'
    firebaseEnv[pathKey] = [
      dirname(resolve(env.CSA_PORTAL_FUNCTIONS_NODE)),
      firebaseEnv[pathKey],
    ].filter(Boolean).join(delimiter)
  }
  const firebaseArguments = [
    'emulators:start',
    '--only',
    'auth,firestore,functions',
    '--project',
    project,
    '--config',
    configName,
  ]
  // npm installs a firebase.cmd shim on Windows. These arguments are constants
  // and the config is relative to the child's working directory.
  const emulators = isWindows
    ? child('cmd.exe', ['/d', '/s', '/c', `"firebase ${firebaseArguments.join(' ')}"`], {
        env: firebaseEnv,
        windowsVerbatimArguments: true,
      })
    : child('firebase', firebaseArguments, { env: firebaseEnv })
  let emulatorReadback = ''
  emulators.stdout.on('data', (chunk) => {
    const text = chunk.toString()
    process.stdout.write(text)
    emulatorReadback = (emulatorReadback + text).slice(-50_000)
  })
  emulators.stderr.pipe(process.stderr)
  const callableURL = `http://${scope.functions}/${project}/us-west1/operationsStatus`
  await until(
    'Authentication, named Firestore and Functions emulators',
    async () => {
      const [auth, database, fn] = await Promise.all([
        request(`http://${scope.auth}/emulator/v1/projects/${project}/config`),
        request(
          `http://${scope.firestore}/v1/projects/${project}/databases/portal/documents/roles/no-session`,
        ),
        request(callableURL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: '{"data":{}}',
        }),
      ])
      return (
        auth.ok &&
        database.status === 403 &&
        fn.status === 401 &&
        emulatorReadback.includes('All emulators ready')
      )
    },
  )
  const accounts = await seedFixtures(scope)
  const vite = child(
    process.execPath,
    [
      resolve(root, 'node_modules/vite/bin/vite.js'),
      root,
      '--host',
      host,
      '--port',
      String(ports.vite),
      '--strictPort',
    ],
    {
      env: {
        ...env,
        VITE_CSA_LOCAL_PROJECT: project,
        VITE_CSA_LOCAL_AUTH: scope.auth,
        VITE_CSA_LOCAL_FIRESTORE: scope.firestore,
        VITE_CSA_LOCAL_FUNCTIONS: scope.functions,
        CSA_LOCAL_VITE_ORIGIN: state.url,
        CSA_LOCAL_OWNER: JSON.stringify(accounts[4]),
      },
    },
  )
  vite.stdout.pipe(process.stdout)
  vite.stderr.pipe(process.stderr)
  await until('CSA-iEM Vite app', async () => {
    const [status, page] = await Promise.all([
      request(`${state.url}/__csa_status`),
      request(`${state.url}/`),
    ])
    return status.ok && page.ok
  })
  state = {
    ...state,
    ready: true,
    accounts,
    children: { emulators: emulators.pid, vite: vite.pid },
  }
  await writeFile(stateFile, JSON.stringify(state, null, 2), { mode: 0o600 })
  console.log(`CSA-iEM local owner preview: ${state.url}/login?localOwner=1`)
  console.log('Use dev:status or dev:stop to operate only this session.')
}

try {
  const command = process.argv[2] ?? 'start'
  if (command === 'start') await start()
  else if (['status', 'stop'].includes(command)) await sessionCommand(command)
  else throw new Error('Use start, status or stop.')
} catch (error) {
  console.error(error.message)
  await shutdown(1)
}
