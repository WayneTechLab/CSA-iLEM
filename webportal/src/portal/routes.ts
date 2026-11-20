export type PortalRoute = { path: string; title: string; level: number }

export const publicRoutes = [
  ['/', 'Home'],
  ['/features', 'Features'],
  ['/plans', 'Plans'],
  ['/downloads', 'Downloads'],
  ['/releases', 'Release history'],
  ['/docs', 'Documentation'],
  ['/docs/getting-started', 'Getting started'],
  ['/docs/install', 'Install CSA-iEM'],
  ['/docs/projects', 'Projects guide'],
  ['/docs/devices', 'Pair your Mac'],
  ['/docs/backups', 'Backup and recovery'],
  ['/docs/file-safety', 'File safety'],
  ['/help', 'Help center'],
  ['/contact', 'Contact'],
  ['/about', 'About CSA-iEM'],
  ['/security', 'Security'],
  ['/privacy', 'Privacy'],
  ['/terms', 'Terms'],
] as const

export const accountRoutes = [
  ['/login', 'Log in'],
  ['/signup', 'Create an account'],
  ['/forgot-password', 'Reset your password'],
  ['/verify-email', 'Verify your email'],
  ['/auth/action', 'Account action'],
] as const

export const workspaceRoutes = [
  ['/dashboard', 'Overview'],
  ['/projects', 'Projects'],
  ['/projects/:id', 'Project detail'],
  ['/devices', 'Devices'],
  ['/devices/:id', 'Device detail'],
  ['/devices/pair', 'Pair a Mac'],
  ['/backups', 'Backups'],
  ['/backups/:id', 'Backup detail'],
  ['/activity', 'Activity'],
  ['/settings/profile', 'Profile'],
  ['/settings/security', 'Account security'],
  ['/settings/sync', 'Sync settings'],
] as const

export const adminRoutes = [
  { path: '/admin', title: 'Operations', level: 4 },
  { path: '/admin/accounts', title: 'Accounts', level: 5 },
  { path: '/admin/audit', title: 'Role audit', level: 5 },
] as const

export const routes: PortalRoute[] = [
  ...[...publicRoutes, ...accountRoutes].map(([path, title]) => ({
    path,
    title,
    level: 0,
  })),
  ...workspaceRoutes.map(([path, title]) => ({ path, title, level: 1 })),
  ...adminRoutes,
]

export function resolveRoute(path: string) {
  const exact = routes.find((route) => route.path === path)
  if (exact) return { route: exact, id: '' }
  const match = /^\/(projects|devices|backups)\/([a-zA-Z0-9_-]{1,150})$/.exec(
    path,
  )
  if (match) {
    const route = routes.find(
      (candidate) => candidate.path === `/${match[1]}/:id`,
    )
    if (route) return { route, id: match[2] }
  }
  return null
}
