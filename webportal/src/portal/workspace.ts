import { createContext, useContext } from 'react'
import { httpsCallable } from 'firebase/functions'
import { functions } from '@/config/firebase'

export const kindLabels = {
  projects: 'Project',
  devices: 'Device',
  backups: 'Backup',
}
export type RecordKind = keyof typeof kindLabels
export const workspaceAreaLabels = {
  code: 'Code workspace',
  import: 'Import staging',
  runtime: 'Runtime workspace',
  local: 'Local checkout',
} as const
export type WorkspaceArea = keyof typeof workspaceAreaLabels
export type WorkspaceEntry = {
  id: string
  name: string
  location: string
  notes: string
  source: 'manual' | 'mac'
  projectId?: string
  deviceId?: string
  repository?: string
  area?: WorkspaceArea
  available?: boolean
  isExport?: boolean
  verifiedAt?: Date
  updatedAt?: Date
  lastSyncAt?: Date
  sharePaths?: boolean
  status?: 'paired' | 'revoked'
}
export type Activity = {
  id: string
  action: string
  label: string
  kind: RecordKind
  updatedAt?: Date
  count?: number
}
export type WorkspaceData = {
  records: Record<RecordKind, WorkspaceEntry[]>
  activity: Activity[]
  loading: boolean
  offline: boolean
  error: string
}
export const Workspace = createContext<WorkspaceData>({
  records: { projects: [], devices: [], backups: [] },
  activity: [],
  loading: true,
  offline: false,
  error: '',
})
export const useWorkspace = () => useContext(Workspace)

export async function call<Out, In = Record<string, unknown>>(
  name: string,
  data: In,
) {
  const result = await httpsCallable<In, Out>(functions, name)(data)
  return result.data
}

export const dateLabel = (date?: Date | null) =>
  date
    ? new Intl.DateTimeFormat(undefined, {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(date)
    : '—'
