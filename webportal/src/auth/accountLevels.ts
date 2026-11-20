export type AccountLevel = 0 | 1 | 2 | 3 | 4 | 5

export type AccountLevelDefinition = {
  level: AccountLevel
  key: string
  label: string
  account: string
  billing: string
  loginState: 'public' | 'logged-in'
  description: string
}

export const ACCOUNT_LEVELS: AccountLevelDefinition[] = [
  {
    level: 0,
    key: 'public',
    label: 'Guest / Public',
    account: 'Free Account',
    billing: 'Free',
    loginState: 'public',
    description: 'Public content only. No authenticated Firebase user required.',
  },
  {
    level: 1,
    key: 'member',
    label: 'User / Member',
    account: 'Free Account',
    billing: 'Free',
    loginState: 'logged-in',
    description: 'Member profile, saved preferences, and free authenticated areas.',
  },
  {
    level: 2,
    key: 'pro',
    label: 'User / Pro',
    account: 'Paid Account',
    billing: 'Paid',
    loginState: 'logged-in',
    description: 'Paid user access for pro workflows and commerce entitlements.',
  },
  {
    level: 3,
    key: 'diamond',
    label: 'User / Diamond',
    account: 'Paid Account',
    billing: 'Paid',
    loginState: 'logged-in',
    description: 'Premium paid access for highest customer tier workflows.',
  },
  {
    level: 4,
    key: 'admin',
    label: 'Employee / Private',
    account: 'Admin Account',
    billing: 'Private',
    loginState: 'logged-in',
    description: 'Employee/admin access. Requires server-side checks and MFA guidance.',
  },
  {
    level: 5,
    key: 'owner',
    label: 'Owner / Private',
    account: 'Super Admin Account',
    billing: 'Private',
    loginState: 'logged-in',
    description: 'Owner-only controls, break-glass operations, and full administrative access.',
  },
]

export const TEST_ACCOUNTS = [
  { email: 'Test-SU@example.test', level: 5 as AccountLevel, role: 'owner' },
  { email: 'Test-Admin@example.test', level: 4 as AccountLevel, role: 'admin' },
  { email: 'Test-Pro@example.test', level: 3 as AccountLevel, role: 'diamond' },
  { email: 'Test-User_Paid@example.test', level: 2 as AccountLevel, role: 'pro' },
  { email: 'Test-User_Free@example.test', level: 1 as AccountLevel, role: 'member' },
  { email: 'Test-User_Public@example.test', level: 0 as AccountLevel, role: 'public' },
]

export function normalizeAccountLevel(value: unknown): AccountLevel {
  const numeric = Number(value)
  if ([0, 1, 2, 3, 4, 5].includes(numeric)) return numeric as AccountLevel
  return 0
}

export function getAccountLevelDefinition(level: unknown): AccountLevelDefinition {
  const normalized = normalizeAccountLevel(level)
  return ACCOUNT_LEVELS.find((item) => item.level === normalized) ?? ACCOUNT_LEVELS[0]
}

export function hasMinimumLevel(currentLevel: unknown, requiredLevel: AccountLevel) {
  return normalizeAccountLevel(currentLevel) >= requiredLevel
}

export function getAccountCapabilities(level: unknown) {
  const normalized = normalizeAccountLevel(level)
  return {
    canViewPublic: true,
    canViewMember: normalized >= 1,
    canUsePaidFeatures: normalized >= 2,
    canUsePremiumFeatures: normalized >= 3,
    canAccessAdmin: normalized >= 4,
    canAccessOwner: normalized >= 5,
    requiresMfa: normalized >= 4,
  }
}
