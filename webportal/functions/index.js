const { createHash, randomBytes, timingSafeEqual } = require('node:crypto')
const { initializeApp } = require('firebase-admin/app')
const { getAuth } = require('firebase-admin/auth')
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require('firebase-admin/firestore')
const { setGlobalOptions } = require('firebase-functions/v2')
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https')

setGlobalOptions({
  serviceAccount: 'csa-portal-runtime@csa-ilem.iam.gserviceaccount.com',
})

const app = initializeApp()
const db = getFirestore(app, 'portal')
const auth = getAuth(app)
const region = 'us-west1'
const memberKinds = new Set(['projects', 'devices', 'backups'])
const scopes = ['nativeProjects', 'linkedDevices', 'nativeBackups']
const stamp = () => FieldValue.serverTimestamp()
const hash = (value) => createHash('sha256').update(value).digest('hex')
const secret = (length = 32) => randomBytes(length).toString('base64url')
const userRoot = (uid) => db.collection('users').doc(uid)
const roleRef = (uid) => db.collection('roles').doc(uid)
const roleAudit = db.collection('roleAudit')
const deviceCredentials = db.collection('deviceCredentials')
const pairCodes = db.collection('devicePairCodes')

function fail(code, message) {
  throw new HttpsError(code, message)
}

function inputString(value, max, label, required = false) {
  if (
    typeof value !== 'string' ||
    value.length > max ||
    (required && !value.trim())
  ) {
    fail('invalid-argument', `Enter a valid ${label}.`)
  }
  return value.trim()
}

function id(value, label = 'ID') {
  const parsed = inputString(value, 150, label, true)
  if (!/^[a-zA-Z0-9_-]+$/.test(parsed))
    fail('invalid-argument', `Invalid ${label}.`)
  return parsed
}

function token(value, length, label) {
  const parsed = inputString(value, length, label, true)
  if (parsed.length !== length || !/^[a-zA-Z0-9_-]+$/.test(parsed))
    fail('invalid-argument', `Invalid ${label}.`)
  return parsed
}

function readRole(snapshot) {
  const level = snapshot.get('level')
  return Number.isInteger(level) && level >= 1 && level <= 5 ? level : 1
}

async function verifiedAccount(uid) {
  let account
  try {
    account = await auth.getUser(uid)
  } catch (error) {
    if (error.code === 'auth/user-not-found')
      fail('permission-denied', 'This account is unavailable.')
    throw error
  }
  if (account.disabled || !account.emailVerified)
    fail('permission-denied', 'An active verified account is required.')
  return account
}

async function actor(request, minimum = 1) {
  if (!request.auth) fail('unauthenticated', 'Sign in to continue.')
  if (request.auth.token.email_verified !== true)
    fail('permission-denied', 'Verify your email to continue.')
  const uid = id(request.auth.uid, 'account ID')
  await verifiedAccount(uid)
  const level = readRole(await roleRef(uid).get())
  if (level < minimum)
    fail('permission-denied', 'Your account level does not allow this action.')
  return { uid, level }
}

function activity(uid, action, label, subjectId, kind) {
  return { uid, action, label, subjectId, kind, updatedAt: stamp() }
}

function timestamp(value) {
  return value?.toDate?.()?.toISOString() ?? null
}

exports.saveWorkspaceRecord = onCall({ region }, async (request) => {
  const { uid } = await actor(request)
  const { kind, operation, record } = request.data ?? {}
  if (
    !memberKinds.has(kind) ||
    !['create', 'update', 'delete'].includes(operation)
  ) {
    fail('invalid-argument', 'Choose a supported workspace action.')
  }
  const owner = userRoot(uid)
  const collection = owner.collection(kind)
  const target =
    operation === 'create'
      ? collection.doc()
      : collection.doc(id(request.data.id))
  const log = owner.collection('activity').doc()
  const values =
    operation === 'delete'
      ? null
      : {
          name: inputString(record?.name, 120, 'name', true),
          location: inputString(record?.location ?? '', 1000, 'location'),
          notes: inputString(record?.notes ?? '', 4000, 'notes'),
          kind,
          updatedAt: stamp(),
          ...(kind === 'backups' && record?.projectId
            ? { projectId: id(record.projectId, 'project ID') }
            : {}),
          ...(kind === 'backups' && record?.deviceId
            ? { deviceId: id(record.deviceId, 'device ID') }
            : {}),
        }
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(target)
    if (operation !== 'create' && !existing.exists)
      fail('not-found', 'This record is no longer available.')
    const label = values?.name ?? existing.get('name')
    if (operation === 'delete') tx.delete(target)
    else if (operation === 'create') tx.create(target, values)
    else tx.set(target, values)
    tx.create(log, activity(uid, operation, label, target.id, kind))
  })
  return { id: target.id }
})

exports.workspaceExport = onCall({ region }, async (request) => {
  const { uid } = await actor(request, 2)
  const kind = request.data?.kind
  if (!memberKinds.has(kind))
    fail('invalid-argument', 'Choose a workspace inventory.')
  const native = scopes[['projects', 'devices', 'backups'].indexOf(kind)]
  const snapshots = await Promise.all(
    [kind, native].map((name) =>
      userRoot(uid).collection(name).limit(1001).get(),
    ),
  )
  if (snapshots.some((snapshot) => snapshot.size > 1000))
    fail('resource-exhausted', 'Export is limited to 1,000 entries per source.')
  return snapshots.flatMap((snapshot, index) =>
    snapshot.docs.map((doc) => {
      const row = doc.data()
      return [
        row.name,
        row.location ?? '',
        row.notes ?? '',
        index ? 'Mac' : 'Manual',
        timestamp(row.updatedAt),
      ]
    }),
  )
})

exports.operationsStatus = onCall({ region }, async (request) => {
  const { level } = await actor(request, 4)
  return {
    database: 'portal',
    service: 'Available',
    level,
    checkedAt: new Date().toISOString(),
  }
})

exports.listAccounts = onCall({ region }, async (request) => {
  await actor(request, 5)
  const email = inputString(request.data?.email ?? '', 254, 'email')
  let users, next
  if (email) {
    try {
      users = [await auth.getUserByEmail(email)]
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error
      users = []
    }
  } else {
    const pageToken = request.data?.cursor
      ? inputString(request.data.cursor, 2048, 'page cursor')
      : undefined
    const page = await auth.listUsers(20, pageToken)
    users = page.users
    next = page.pageToken
  }
  const rows = await Promise.all(
    users.map(async (user) => ({
      uid: user.uid,
      email: user.email ?? '',
      verified: user.emailVerified,
      disabled: user.disabled,
      level: readRole(await roleRef(user.uid).get()),
    })),
  )
  return { rows, next: next ?? null }
})

exports.assignRole = onCall({ region }, async (request) => {
  const { uid } = await actor(request, 5)
  const age = Date.now() / 1000 - Number(request.auth.token.auth_time)
  if (!Number.isFinite(age) || age < -60 || age > 600)
    fail('failed-precondition', 'Confirm your sign-in before changing a role.')
  const targetID = id(request.data?.uid, 'target account')
  const level = request.data?.level
  if (!Number.isInteger(level) || level < 1 || level > 4 || targetID === uid) {
    fail(
      'invalid-argument',
      'Select a different account and a level from 1 to 4.',
    )
  }
  const target = await verifiedAccount(targetID)
  const audit = roleAudit.doc()
  await db.runTransaction(async (tx) => {
    const [owner, previous] = await tx.getAll(roleRef(uid), roleRef(targetID))
    if (readRole(owner) !== 5 || readRole(previous) === 5)
      fail(
        'permission-denied',
        'Owner roles are maintained by trusted provisioning.',
      )
    const oldLevel = readRole(previous)
    if (oldLevel === level) return
    tx.set(roleRef(targetID), { level, updatedAt: stamp() }, { merge: true })
    tx.create(audit, {
      actor: uid,
      target: targetID,
      email: target.email ?? '',
      previousLevel: oldLevel,
      level,
      updatedAt: stamp(),
    })
  })
  return { level }
})

exports.listRoleAudit = onCall({ region }, async (request) => {
  await actor(request, 5)
  let query = roleAudit.orderBy('updatedAt', 'desc')
  if (request.data?.cursor) {
    const cursor = await roleAudit
      .doc(id(request.data.cursor, 'audit cursor'))
      .get()
    if (!cursor.exists)
      fail('invalid-argument', 'This page has changed. Reload the audit.')
    query = query.startAfter(cursor)
  }
  const docs = (await query.limit(21).get()).docs
  return {
    rows: docs
      .slice(0, 20)
      .map((doc) => ({
        id: doc.id,
        ...doc.data(),
        updatedAt: timestamp(doc.get('updatedAt')),
      })),
    next: docs.length > 20 ? docs[19].id : null,
  }
})

exports.createDevicePairCode = onCall({ region }, async (request) => {
  const { uid } = await actor(request)
  const code = secret(24)
  const expiresAt = Date.now() + 10 * 60 * 1000
  await pairCodes.doc(hash(code)).create({
    uid,
    expiresAt: Timestamp.fromMillis(expiresAt),
    allowPaths: request.data?.allowPaths === true,
  })
  return { code, expiresAt }
})

exports.revokeLinkedDevice = onCall({ region }, async (request) => {
  const { uid } = await actor(request)
  const deviceID = id(request.data?.deviceId, 'device ID')
  const key = deviceCredentials.doc(deviceID)
  const owner = userRoot(uid)
  const device = owner.collection('linkedDevices').doc(deviceID)
  const log = owner.collection('activity').doc()
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(key)
    if (!doc.exists || doc.get('uid') !== uid)
      fail('not-found', 'This device is unavailable.')
    if (doc.get('revoked')) return
    tx.update(key, { revoked: true })
    tx.update(device, { status: 'revoked', updatedAt: stamp() })
    tx.create(
      log,
      activity(uid, 'revoked', doc.get('name'), deviceID, 'devices'),
    )
  })
  return { revoked: true }
})

function handleNative(task) {
  return onRequest({ region, cors: false }, async (request, response) => {
    response.set('Cache-Control', 'no-store')
    if (request.method !== 'POST')
      return response.status(405).json({ error: 'Use POST.' })
    if (
      !request.is('application/json') ||
      request.rawBody?.length > 96 * 1024
    ) {
      return response
        .status(400)
        .json({ error: 'Send a bounded JSON request.' })
    }
    try {
      return response.json(await task(request))
    } catch (error) {
      const status = {
        'invalid-argument': 400,
        unauthenticated: 401,
        'permission-denied': 403,
        'not-found': 404,
        'failed-precondition': 409,
      }
      return response.status(status[error.code] ?? 500).json({
        error: status[error.code]
          ? error.message
          : 'Sync service is temporarily unavailable.',
      })
    }
  })
}

exports.claimDevicePairCode = handleNative(async (request) => {
  const code = token(request.body?.code, 32, 'pairing code')
  const deviceID = id(request.body?.deviceId, 'device ID')
  const keyHash = inputString(
    request.body?.credentialHash,
    64,
    'credential digest',
    true,
  )
  if (!/^[a-f0-9]{64}$/.test(keyHash))
    fail('invalid-argument', 'Invalid credential digest.')
  const name = inputString(request.body?.name, 120, 'device name', true)
  const reference = pairCodes.doc(hash(code))
  const pending = await reference.get()
  if (!pending.exists) fail('not-found', 'This pairing code is unavailable.')
  const uid = pending.get('uid')
  await verifiedAccount(uid)
  const owner = userRoot(uid)
  return db.runTransaction(async (tx) => {
    const pairing = await tx.get(reference)
    if (pairing.get('expiresAt').toMillis() <= Date.now())
      fail('failed-precondition', 'This code expired. Create another code.')
    const credentials = deviceCredentials.doc(deviceID)
    const sharePaths =
      pairing.get('allowPaths') === true && request.body?.sharePaths === true
    if (pairing.get('deviceId')) {
      if (
        pairing.get('deviceId') === deviceID &&
        pairing.get('credentialHash') === keyHash
      )
        return { deviceId: deviceID, sharePaths: pairing.get('sharePaths') }
      fail('failed-precondition', 'This code was already used.')
    }
    tx.create(credentials, {
      uid,
      name,
      keyHash,
      sharePaths,
      revoked: false,
      createdAt: stamp(),
    })
    tx.create(owner.collection('linkedDevices').doc(deviceID), {
      name,
      status: 'paired',
      location: 'macOS',
      sharePaths,
      updatedAt: stamp(),
    })
    tx.update(reference, {
      deviceId: deviceID,
      credentialHash: keyHash,
      sharePaths,
    })
    tx.create(
      owner.collection('activity').doc(),
      activity(uid, 'paired', name, deviceID, 'devices'),
    )
    return { deviceId: deviceID, sharePaths }
  })
})

function nativeRows(values, kind, sharePaths, deviceID) {
  if (!Array.isArray(values) || values.length > 40)
    fail('invalid-argument', 'A batch accepts up to 40 records of each type.')
  const seen = new Set()
  return values.map((row) => {
    const rowID = id(row?.id, 'record ID')
    if (seen.has(rowID)) fail('invalid-argument', 'Duplicate record ID.')
    seen.add(rowID)
    const destination = `${deviceID}_${hash(rowID).slice(0, 24)}`
    const record = {
      kind,
      name: inputString(row.name, 120, 'record name', true),
      location: sharePaths
        ? inputString(row.location ?? '', 1000, 'location')
        : '',
      deviceId: deviceID,
      updatedAt: stamp(),
    }
    if (kind === 'backups') {
      const nativeProject = id(row.projectId, 'project ID')
      const verifiedAt = Date.parse(
        inputString(row.verifiedAt, 40, 'verification date', true),
      )
      if (!Number.isFinite(verifiedAt) || verifiedAt > Date.now() + 300_000)
        fail('invalid-argument', 'Invalid verification date.')
      Object.assign(record, {
        projectId: `${deviceID}_${hash(nativeProject).slice(0, 24)}`,
        verifiedAt: Timestamp.fromMillis(verifiedAt),
      })
    }
    return { destination, record }
  })
}

exports.syncLinkedDevice = handleNative(async (request) => {
  const authorization =
    /^Bearer ([a-zA-Z0-9_-]{1,150})\.([a-zA-Z0-9_-]{43})$/.exec(
      request.get('Authorization') ?? '',
    )
  if (!authorization) fail('unauthenticated', 'Connect this Mac in the portal.')
  const [, deviceID, key] = authorization
  const credential = deviceCredentials.doc(deviceID)
  const keyHash = hash(key)
  function verifyCredential(doc) {
    const expected = doc.get('keyHash')
    if (
      !doc.exists ||
      doc.get('revoked') ||
      typeof expected !== 'string' ||
      expected.length !== 64 ||
      !timingSafeEqual(Buffer.from(expected), Buffer.from(keyHash))
    ) {
      fail('permission-denied', 'This device is disconnected. Pair it again.')
    }
  }
  const existing = await credential.get()
  verifyCredential(existing)
  const uid = existing.get('uid')
  await verifiedAccount(uid)
  if (request.body?.version !== 1)
    fail('invalid-argument', 'This sync protocol version is unsupported.')
  const batchID = id(request.body?.batchId, 'batch ID')
  const owner = userRoot(uid)
  const log = owner
    .collection('activity')
    .doc(`sync_${deviceID}_${hash(batchID).slice(0, 24)}`)
  const result = await db.runTransaction(async (tx) => {
    const [current, previous] = await tx.getAll(credential, log)
    verifyCredential(current)
    if (previous.exists)
      return { replayed: true, synced: previous.get('count') }
    const projects = nativeRows(
      request.body.projects,
      'projects',
      current.get('sharePaths'),
      deviceID,
    )
    const backups = nativeRows(
      request.body.backups,
      'backups',
      current.get('sharePaths'),
      deviceID,
    )
    const count = projects.length + backups.length
    if (!count)
      fail('invalid-argument', 'Choose project or backup metadata to sync.')
    for (const [collection, rows] of [
      ['nativeProjects', projects],
      ['nativeBackups', backups],
    ]) {
      for (const { destination, record } of rows)
        tx.set(owner.collection(collection).doc(destination), record)
    }
    tx.update(owner.collection('linkedDevices').doc(deviceID), {
      lastSyncAt: stamp(),
      updatedAt: stamp(),
    })
    tx.create(log, {
      ...activity(uid, 'synced', current.get('name'), deviceID, 'devices'),
      count,
    })
    return { replayed: false, synced: count }
  })
  return result
})
