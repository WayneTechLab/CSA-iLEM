import { test, expect } from '@playwright/test'
import { readFileSync } from 'node:fs'
import { createHash, randomBytes, randomUUID } from 'node:crypto'
import { routes } from '../src/portal/routes.ts'

const local = JSON.parse(
  readFileSync(
    new URL('../.portal-local/session.json', import.meta.url),
    'utf8',
  ),
)
const fixture = (level) =>
  local.accounts.find((account) => account.level === level)
const database = `http://${local.firestore}/v1/projects/${local.project}/databases/portal/documents`
const accountAPI = `http://${local.auth}/identitytoolkit.googleapis.com/v1/accounts:`
const service = `http://${local.functions}/${local.project}/us-west1`
const authAdmin = `http://${local.auth}/emulator/v1/projects/${local.project}`

function digest(value) {
  return createHash('sha256').update(value).digest('hex')
}
function request(url, data, bearer, method = 'POST') {
  return fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}),
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
  })
}
async function call(name, data, bearer) {
  return request(`${service}/${name}`, { data }, bearer)
}

async function signInToken(account) {
  const response = await request(
    `${accountAPI}signInWithPassword?key=emulator-only`,
    {
      email: account.email,
      password: account.password,
      returnSecureToken: true,
    },
  )
  expect(response.status).toBe(200)
  return (await response.json()).idToken
}

async function signIn(page, account) {
  await page.goto('/login')
  await page.getByLabel('Email', { exact: true }).fill(account.email)
  await page.getByLabel('Password', { exact: true }).fill(account.password)
  await page.getByRole('button', { name: 'Log in', exact: true }).click()
  await page.waitForURL('**/dashboard')
  await expect(
    page.getByText(new RegExp(`Level ${account.level} ·`)).first(),
  ).toBeVisible()
}

const examples = {
  '/projects/:id': '/projects/project-atlas',
  '/devices/:id': '/devices/mac-fixture-mac',
  '/backups/:id': '/backups/mac-atlas-verified',
}
const expectedHeadings = {
  '/projects/:id': 'Atlas Studio',
  '/devices/:id': 'Studio Mac',
  '/backups/:id': 'Atlas verification archive',
  '/devices/pair': 'Pair a Mac',
  '/dashboard': 'Welcome, Local Owner',
}

for (const viewport of [
  { width: 1360, height: 960 },
  { width: 390, height: 844 },
]) {
  test(`all 38 routes render at ${viewport.width}px with local network isolation`, async ({
    page,
  }) => {
    test.setTimeout(130_000)
    await page.setViewportSize(viewport)
    const offsite = []
    const errors = []
    page.on('pageerror', (error) => errors.push(error.message))
    page.on('request', (req) => {
      if (
        ['http:', 'https:'].includes(new URL(req.url()).protocol) &&
        new URL(req.url()).hostname !== '127.0.0.1'
      )
        offsite.push(new URL(req.url()).hostname)
    })
    await page.goto('/')
    await expect(
      page.getByRole('heading', { name: 'Know where every project lives.' }),
    ).toBeVisible()
    await page.keyboard.press('Tab')
    await expect(
      page.getByRole('link', { name: 'Skip to content' }),
    ).toBeFocused()
    await page.getByRole('link', { name: 'Log in to workspace' }).click()
    await expect(page.getByRole('heading', { name: 'Log in' })).toBeVisible()
    await signIn(page, fixture(5))
    if (viewport.width < 800) {
      const navigation = page.getByRole('button', {
        name: 'Open workspace navigation',
      })
      await navigation.click()
      await expect(
        page.getByRole('dialog', { name: 'Workspace sidebar' }),
      ).toBeVisible()
      await page.keyboard.press('Escape')
      await expect(navigation).toBeFocused()
    }
    expect(routes).toHaveLength(38)
    for (const route of routes) {
      const path = examples[route.path] ?? route.path
      const response = await page.goto(path)
      expect(response.status(), path).toBe(200)
      const heading = page.locator('main h1')
      await expect(heading, path).toBeVisible()
      if (expectedHeadings[route.path])
        await expect(heading, path).toHaveText(expectedHeadings[route.path])
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
        path,
      ).toBe(true)
    }
    await page.goto('/services')
    await page.waitForURL('**/features')
    expect(offsite).toEqual([])
    expect(errors).toEqual([])
  })
}

test('workspace changes survive reload and enter activity', async ({
  page,
}) => {
  await signIn(page, fixture(5))
  await page.getByRole('link', { name: 'Projects', exact: true }).click()
  await page.getByRole('button', { name: 'Add project' }).click()
  await page.getByLabel('Name', { exact: true }).fill('Portal browser test')
  await page
    .getByLabel('Location', { exact: true })
    .fill('/Volumes/Fixture/Browser')
  await page.getByRole('button', { name: 'Save record' }).click()
  await expect(
    page.getByRole('heading', { name: 'Portal browser test' }),
  ).toBeVisible()
  await page.reload()
  await expect(
    page.getByText('/Volumes/Fixture/Browser', { exact: true }),
  ).toBeVisible()
  await page.getByRole('button', { name: 'Edit record' }).click()
  await page.getByLabel('Notes').fill('Retained after edit')
  await page.getByRole('button', { name: 'Save record' }).click()
  await expect(
    page.getByText('Retained after edit', { exact: true }),
  ).toBeVisible()
  await page.getByRole('link', { name: 'Activity', exact: true }).click()
  await expect(
    page.getByText('Portal browser test', { exact: true }).first(),
  ).toBeVisible()
  await page.goBack()
  await page.getByRole('button', { name: 'Remove record' }).click()
  await page.getByRole('button', { name: 'Confirm removal' }).click()
  await page.waitForURL('**/projects')
  await page.getByRole('button', { name: 'Sign out' }).click()
  await page.waitForURL('**/login')
})

test('verification and password reset work with emulator email links', async ({
  page,
}) => {
  const email = `portal-${Date.now()}@csa-iem.example.test`
  const password = 'Portal-fixture-initial-09'
  const replacement = 'Portal-fixture-replaced-11'
  async function actionCode(requestType) {
    const res = await fetch(`${authAdmin}/oobCodes`)
    const codes = (await res.json()).oobCodes ?? []
    return codes.findLast(
      (item) => item.email === email && item.requestType === requestType,
    )?.oobCode
  }
  await page.goto('/signup')
  await page.getByLabel('Name', { exact: true }).fill('Verification Fixture')
  await page.getByLabel('Email', { exact: true }).fill(email)
  await page.getByLabel('Password', { exact: true }).fill(password)
  await page.getByRole('button', { name: 'Create account' }).click()
  await page.waitForURL('**/verify-email')
  await expect.poll(() => actionCode('VERIFY_EMAIL')).toBeTruthy()
  await page.goto(
    `/auth/action?mode=verifyEmail&oobCode=${encodeURIComponent(await actionCode('VERIFY_EMAIL'))}`,
  )
  await page.getByRole('button', { name: 'Verify email', exact: true }).click()
  await expect(page.getByText('Your account change is complete.')).toBeVisible()
  await page.goto('/dashboard')
  await expect(
    page.getByRole('heading', { name: 'Welcome, Verification Fixture' }),
  ).toBeVisible()
  await page.getByRole('button', { name: 'Sign out' }).click()
  await page.waitForURL('**/login')
  await page.goto('/forgot-password')
  await page.getByLabel('Email', { exact: true }).fill(email)
  await page.getByRole('button', { name: 'Send reset link' }).click()
  await expect.poll(() => actionCode('PASSWORD_RESET')).toBeTruthy()
  await page.goto(
    `/auth/action?mode=resetPassword&oobCode=${encodeURIComponent(await actionCode('PASSWORD_RESET'))}`,
  )
  await page.getByLabel('New password').fill(replacement)
  await page.getByRole('button', { name: 'Set password' }).click()
  await expect(page.getByText('Your account change is complete.')).toBeVisible()
  await signIn(page, { email, password: replacement, level: 1 })
})

test('Level 5 can assign Levels 1–4 with an audit event', async ({ page }) => {
  await signIn(page, fixture(5))
  await page.getByRole('link', { name: 'Manage accounts' }).click()
  await page
    .getByRole('textbox', { name: 'Find account email' })
    .fill(fixture(1).email)
  await page.getByRole('button', { name: 'Find account' }).click()
  await page
    .getByRole('button', { name: `Change level for ${fixture(1).email}` })
    .click()
  await page.getByLabel('Account level').selectOption('2')
  await page.getByRole('button', { name: 'Save role change' }).click()
  await expect(
    page.getByRole('status').filter({ hasText: 'Saved Level 2' }),
  ).toBeVisible()
  await page.getByRole('link', { name: 'View role audit' }).click()
  await expect(
    page.getByRole('cell', { name: 'Level 1 → Level 2' }).first(),
  ).toBeVisible()
  const owner = await signInToken(fixture(5))
  expect(
    (await call('assignRole', { uid: fixture(1).uid, level: 1 }, owner)).status,
  ).toBe(200)
})

test('member, paid and employee paths enforce their privileges', async ({
  browser,
}) => {
  for (const level of [1, 2, 3, 4]) {
    const context = await browser.newContext()
    try {
      const page = await context.newPage()
      await signIn(page, fixture(level))
      await expect(
        page.getByRole('heading', { name: 'Backup coverage' }),
      ).toHaveCount(level >= 3 ? 1 : 0)
      await page.goto('/projects')
      await expect(
        page.getByRole('button', { name: 'Export CSV' }),
      ).toHaveCount(level >= 2 ? 1 : 0)
      if (level === 2) {
        const download = page.waitForEvent('download')
        await page.getByRole('button', { name: 'Export CSV' }).click()
        expect((await download).suggestedFilename()).toMatch(
          /csa-iem-projects-\d{4}-\d{2}-\d{2}.csv/,
        )
      }
      await page.goto('/admin')
      if (level >= 4)
        await expect(page.getByText('Available', { exact: true })).toBeVisible()
      else
        await expect(
          page.getByRole('heading', { name: 'Access unavailable' }),
        ).toBeVisible()
      await page.goto('/admin/accounts')
      await expect(
        page.getByRole('heading', { name: 'Access unavailable' }),
      ).toBeVisible()
    } finally {
      await context.close()
    }
  }
})

test('Firestore and callable guards preserve ownership', async () => {
  const member = await signInToken(fixture(1))
  const owner = await signInToken(fixture(5))
  const target = `${database}/users/${fixture(5).uid}/projects/project-atlas`
  expect((await request(target, null, owner, 'GET')).status).toBe(200)
  expect((await request(target, null, member, 'GET')).status).toBe(403)
  expect((await request(target, null, null, 'GET')).status).toBe(403)
  expect(
    (
      await request(
        `${database}/roles/${fixture(1).uid}`,
        { fields: { level: { integerValue: '5' } } },
        member,
        'PATCH',
      )
    ).status,
  ).toBe(403)
  expect(
    (await call('assignRole', { uid: fixture(1).uid, level: 5 }, owner)).status,
  ).toBe(400)
  expect(
    (await call('assignRole', { uid: fixture(2).uid, level: 4 }, member))
      .status,
  ).toBe(403)
  expect((await call('listAccounts', {}, member)).status).toBe(403)
  expect(
    (await call('workspaceExport', { kind: 'projects' }, member)).status,
  ).toBe(403)
  expect(
    (
      await request(
        `${database}/users/${fixture(5).uid}/nativeBackups/atlas-verified`,
        { fields: { name: { stringValue: 'Edited' } } },
        owner,
        'PATCH',
      )
    ).status,
  ).toBe(403)
})

test('pairing expiry, replay, upload consent and revocation are enforced', async () => {
  const account = fixture(3)
  const bearer = await signInToken(account)
  const deviceId = randomUUID()
  const secret = randomBytes(32).toString('base64url')
  const device = `${deviceId}.${secret}`
  const pair = async (allowPaths) => {
    const response = await call('createDevicePairCode', { allowPaths }, bearer)
    expect(response.status).toBe(200)
    return (await response.json()).result.code
  }
  const claim = (code) => ({
    code,
    deviceId,
    credentialHash: digest(secret),
    name: 'Protocol Fixture Mac',
    sharePaths: true,
  })
  const expired = await pair(false)
  const privilegedFixture = 'owner'
  // Firestore's emulator-only Admin token adjusts a synthetic code to test the expiry branch.
  const altered = await request(
    `${database}/devicePairCodes/${digest(expired)}?updateMask.fieldPaths=expiresAt`,
    {
      fields: { expiresAt: { timestampValue: '2001-01-01T00:00:00Z' } },
    },
    privilegedFixture,
    'PATCH',
  )
  expect(altered.status).toBe(200)
  expect(
    (await request(`${service}/claimDevicePairCode`, claim(expired))).status,
  ).toBe(409)
  const code = await pair(false)
  const result = await request(`${service}/claimDevicePairCode`, claim(code))
  expect(result.status).toBe(200)
  expect((await result.json()).sharePaths).toBe(false)
  expect(
    (
      await request(`${service}/claimDevicePairCode`, {
        ...claim(code),
        deviceId: randomUUID(),
      })
    ).status,
  ).toBe(409)
  expect(
    (await request(`${service}/claimDevicePairCode`, claim(code))).status,
  ).toBe(200)
  const batch = {
    version: 1,
    batchId: randomUUID(),
    projects: [
      {
        id: 'fixture-project',
        name: 'Paired project',
        location: '/Volumes/Fixture/ShouldBePrivate',
      },
    ],
    backups: [
      {
        id: 'fixture-backup',
        projectId: 'fixture-project',
        name: 'Verified backup',
        location: '/Volumes/Fixture/PrivateBackup',
        verifiedAt: new Date().toISOString(),
      },
    ],
  }
  const synced = await request(`${service}/syncLinkedDevice`, batch, device)
  expect(await synced.json()).toEqual({ replayed: false, synced: 2 })
  const retried = await request(`${service}/syncLinkedDevice`, batch, device)
  expect(await retried.json()).toEqual({ replayed: true, synced: 2 })
  const recordPath = `${database}/users/${account.uid}/nativeBackups/${deviceId}_${digest('fixture-backup').slice(0, 24)}`
  const record = await request(recordPath, null, bearer, 'GET')
  expect(record.status).toBe(200)
  expect((await record.json()).fields.location.stringValue).toBe('')
  expect((await call('revokeLinkedDevice', { deviceId }, bearer)).status).toBe(
    200,
  )
  expect(
    (
      await request(
        `${service}/syncLinkedDevice`,
        { ...batch, batchId: randomUUID() },
        device,
      )
    ).status,
  ).toBe(403)
})

test('Google sign-in completes with a synthetic Auth Emulator identity', async ({ page }) => {
  await page.goto('/login')
  const pending = page.waitForEvent('popup')
  await page.getByRole('button', { name: 'Continue with Google' }).click()
  const provider = await pending
  expect(new URL(provider.url()).origin).toBe(`http://${local.auth}`)
  await expect(provider.locator('#title')).toContainText('Google.com', { timeout: 15_000 })
  await provider.getByRole('button', { name: /Add new account/ }).click()
  await provider.locator('#email-input').fill(`google-${Date.now()}@csa-iem.example.test`)
  await provider.locator('#display-name-input').fill('Local Google Member')
  await provider.locator('#sign-in').click()
  await page.waitForURL('**/dashboard')
  await expect(page.getByRole('heading', { name: 'Welcome, Local Google Member' })).toBeVisible()
  await expect(page.getByText('Level 1 · User / Member', { exact: true })).toBeVisible()
})
