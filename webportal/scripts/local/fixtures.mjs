import { createRequire } from 'node:module'
import { randomBytes } from 'node:crypto'

const require = createRequire(
  new URL('../../functions/index.js', import.meta.url),
)

export function assertLocal(scope) {
  if (
    scope.project !== 'demo-csa-iem' ||
    !/^127\.0\.0\.1:\d+$/.test(scope.auth) ||
    !/^127\.0\.0\.1:\d+$/.test(scope.firestore)
  ) {
    throw new Error('Fixtures require the isolated CSA-iEM emulator.')
  }
}

export async function seedFixtures(scope) {
  assertLocal(scope)
  process.env.FIREBASE_AUTH_EMULATOR_HOST = scope.auth
  process.env.FIRESTORE_EMULATOR_HOST = scope.firestore
  const { initializeApp, deleteApp } = require('firebase-admin/app')
  const { getAuth } = require('firebase-admin/auth')
  const { getFirestore, Timestamp } = require('firebase-admin/firestore')
  const app = initializeApp({ projectId: scope.project }, 'local-fixtures')
  const auth = getAuth(app)
  const database = getFirestore(app, 'portal')
  const accounts = []
  try {
    const batch = database.batch()
    for (let level = 1; level <= 5; level += 1) {
      const uid = `fixture-level-${level}`
      const email = `level${level}@csa-iem.example.test`
      const password = randomBytes(24).toString('base64url')
      await auth.createUser({
        uid,
        email,
        password,
        displayName: level === 5 ? 'Local Owner' : `Level ${level} Fixture`,
        emailVerified: true,
      })
      accounts.push({ uid, email, password, level })
      batch.set(database.doc(`roles/${uid}`), { level })
    }
    const uid = accounts[4].uid
    const owner = database.collection('users').doc(uid)
    const now = Date.now()
    const earlier = (days) => Timestamp.fromMillis(now - days * 86_400_000)
    const row = (kind, name, location, notes, days) => ({
      kind,
      name,
      location,
      notes,
      updatedAt: earlier(days),
    })
    const rows = [
      [
        'projects',
        'project-atlas',
        row(
          'projects',
          'Atlas Studio',
          '/Volumes/Studio/Atlas',
          'Design system and customer portal source.',
          1,
        ),
      ],
      [
        'projects',
        'project-harbor',
        row(
          'projects',
          'Harbor Docs',
          '/Volumes/Studio/Harbor',
          'Documentation and release guides.',
          2,
        ),
      ],
      [
        'projects',
        'project-orbit',
        row(
          'projects',
          'Orbit Tools',
          '/Volumes/Lab/Orbit',
          'Local operator tools and test fixtures.',
          7,
        ),
      ],
      [
        'projects',
        'project-lumen',
        row(
          'projects',
          'Lumen Archive',
          '/Volumes/Lab/Lumen',
          'Historical release archive.',
          9,
        ),
      ],
      [
        'devices',
        'field-notebook',
        row(
          'devices',
          'Field notebook',
          'Portable workstation',
          'Manually tracked inventory.',
          4,
        ),
      ],
      [
        'backups',
        'harbor-manual',
        {
          ...row(
            'backups',
            'Harbor offsite save point',
            '/Volumes/Offsite/Harbor',
            'Location recorded by operator.',
            3,
          ),
          projectId: 'project-harbor',
        },
      ],
      [
        'linkedDevices',
        'fixture-mac',
        {
          name: 'Studio Mac',
          status: 'paired',
          location: 'macOS',
          lastSyncAt: earlier(1),
          updatedAt: earlier(1),
          sharePaths: true,
        },
      ],
      [
        'nativeProjects',
        'atlas-mac',
        {
          ...row(
            'projects',
            'Atlas Build Tools',
            '/Volumes/Studio/Atlas/Tools',
            '',
            1,
          ),
          deviceId: 'fixture-mac',
        },
      ],
      [
        'nativeBackups',
        'atlas-verified',
        {
          ...row(
            'backups',
            'Atlas verification archive',
            '/Volumes/Recovery/Atlas-Archive',
            '',
            1,
          ),
          verifiedAt: earlier(1),
          deviceId: 'fixture-mac',
          projectId: 'atlas-mac',
        },
      ],
      [
        'activity',
        'fixture-synced',
        {
          uid,
          label: 'Studio Mac',
          action: 'synced',
          kind: 'devices',
          subjectId: 'fixture-mac',
          count: 2,
          updatedAt: earlier(1),
        },
      ],
    ]
    for (const [kind, key, value] of rows)
      batch.set(owner.collection(kind).doc(key), value)
    await batch.commit()
    return accounts
  } finally {
    await deleteApp(app)
  }
}
