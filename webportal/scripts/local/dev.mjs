import { spawn } from 'node:child_process'
import { createServer } from 'node:http'
import { createServer as createTCP } from 'node:net'
import { mkdir, open, readFile, rm, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { randomBytes } from 'node:crypto'
import { setTimeout as delay } from 'node:timers/promises'
import { seedFixtures } from './fixtures.mjs'

const root = fileURLToPath(new URL('../../', import.meta.url))
const local = resolve(root, '.portal-local')
const lock = resolve(local, 'running.lock')
const stateFile = resolve(local, 'session.json')
const configFile = resolve(root, '.firebase.portal-local.json')
const host = '127.0.0.1'
const project = 'demo-csa-iem'
const children = []
const env = { ...process.env }
for (const key of [
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
  'https_proxy',
  'http_proxy',
  'all_proxy',
])
  delete env[key]

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
  })
  if (!response.ok)
    throw new Error(
      'The running process did not accept ownership of this session.',
    )
  console.log(await response.text())
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

let controller, ownership, waiting, state
function child(command, args, options = {}) {
  const process = spawn(command, args, {
    cwd: root,
    env,
    detached: true,
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
async function shutdown(code) {
  if (stopping) return
  stopping = true
  for (const process of children) {
    if (
      process.pid &&
      process.exitCode === null &&
      process.signalCode === null
    ) {
      try {
        globalThis.process.kill(-process.pid, 'SIGTERM')
      } catch {
        /* Group has already stopped. */
      }
    }
  }
  controller?.close()
  if (ownership) {
    await Promise.all(
      [stateFile, configFile].map((file) => rm(file, { force: true })),
    )
    await ownership.close()
    await rm(lock, { force: true })
  }
  process.exit(code)
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
  const ports = await reservePorts()
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
      res.end('Stopping the owned CSA-iEM session.', () => void shutdown(0))
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
    // An explicit nonexistent ADC file prevents discovery of this Mac's live credentials.
    GOOGLE_APPLICATION_CREDENTIALS: resolve(
      emulatorConfig,
      'no-live-credentials.json',
    ),
    NO_UPDATE_NOTIFIER: '1',
  }
  if (env.CSA_PORTAL_FUNCTIONS_NODE) {
    firebaseEnv.PATH =
      dirname(resolve(env.CSA_PORTAL_FUNCTIONS_NODE)) + ':' + env.PATH
  }
  const emulators = child(
    'firebase',
    [
      'emulators:start',
      '--only',
      'auth,firestore,functions',
      '--project',
      project,
      '--config',
      configFile,
    ],
    { env: firebaseEnv },
  )
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
      'node_modules/vite/bin/vite.js',
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
  await until(
    'CSA-iEM Vite app',
    async () => (await request(`${state.url}/__csa_status`)).ok,
  )
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
