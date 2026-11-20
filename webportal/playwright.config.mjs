import { defineConfig } from '@playwright/test'
import { readFileSync } from 'node:fs'

const state = JSON.parse(
  readFileSync(
    new URL('./.portal-local/session.json', import.meta.url),
    'utf8',
  ),
)
if (
  state.project !== 'demo-csa-iem' ||
  !state.ready ||
  !/^http:\/\/127\.0\.0\.1:\d+$/.test(state.url) ||
  !['auth', 'firestore', 'functions'].every((name) =>
    /^127\.0\.0\.1:\d+$/.test(state[name]),
  )
) {
  throw new Error('Start an isolated CSA-iEM session with npm run dev:local.')
}

export default defineConfig({
  testDir: './tests',
  workers: 1,
  fullyParallel: false,
  timeout: 55_000,
  reporter: 'list',
  use: {
    baseURL: state.url,
    ...(process.env.CSA_BROWSER_CHANNEL
      ? { channel: process.env.CSA_BROWSER_CHANNEL }
      : {}),
  },
})
