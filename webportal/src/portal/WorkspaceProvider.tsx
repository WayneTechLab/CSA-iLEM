import { useEffect, useState, type ReactNode } from 'react'
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  type DocumentData,
} from 'firebase/firestore'
import { db } from '@/config/firebase'
import {
  Workspace,
  type Activity,
  type RecordKind,
  type WorkspaceEntry,
  type WorkspaceArea,
  workspaceAreaLabels,
} from './workspace'

const sources = [
  'projects',
  'devices',
  'backups',
  'nativeProjects',
  'linkedDevices',
  'nativeBackups',
  'activity',
] as const
type Source = (typeof sources)[number]
type Snapshot = {
  documents: { id: string; fields: DocumentData }[]
  cached: boolean
  error: string
}

function date(value: unknown) {
  return value instanceof Timestamp ? value.toDate() : undefined
}

function text(value: unknown) {
  return typeof value === 'string' ? value : ''
}

function entry(
  doc: Snapshot['documents'][number],
  native: boolean,
): WorkspaceEntry {
  const row = doc.fields
  return {
    id: doc.id,
    name: text(row.name),
    notes: text(row.notes),
    location: text(row.location),
    source: native ? 'mac' : 'manual',
    projectId: text(row.projectId) || undefined,
    deviceId: text(row.deviceId) || undefined,
    repository: native ? text(row.repository) || undefined : undefined,
    area:
      native && typeof row.area === 'string' && Object.hasOwn(workspaceAreaLabels, row.area)
        ? (row.area as WorkspaceArea)
        : undefined,
    available: native && typeof row.available === 'boolean' ? row.available : undefined,
    isExport: native && row.isExport === true,
    verifiedAt: native ? date(row.verifiedAt) : undefined,
    status:
      row.status === 'revoked'
        ? 'revoked'
        : row.status === 'paired'
          ? 'paired'
          : undefined,
    updatedAt: date(row.updatedAt),
    lastSyncAt: date(row.lastSyncAt),
    sharePaths: row.sharePaths === true,
  }
}

export function WorkspaceProvider({
  uid,
  children,
}: {
  uid: string
  children: ReactNode
}) {
  const [snapshots, setSnapshots] = useState<Partial<Record<Source, Snapshot>>>(
    {},
  )
  const [network, setNetwork] = useState(navigator.onLine)

  useEffect(() => {
    const children = sources.map((source) => {
      const path = collection(db, 'users', uid, source)
      const docs =
        source === 'activity'
          ? query(path, orderBy('updatedAt', 'desc'), limit(150))
          : path
      return onSnapshot(
        docs,
        { includeMetadataChanges: true },
        (values) => {
          setSnapshots((previous) => ({
            ...previous,
            [source]: {
              documents: values.docs.map((doc) => ({
                id: doc.id,
                fields: doc.data(),
              })),
              cached: values.metadata.fromCache,
              error: '',
            },
          }))
        },
        (error) => {
          setSnapshots((previous) => ({
            ...previous,
            [source]: { documents: [], cached: false, error: error.message },
          }))
        },
      )
    })
    const networkChanged = () => setNetwork(navigator.onLine)
    window.addEventListener('online', networkChanged)
    window.addEventListener('offline', networkChanged)
    return () => {
      children.forEach((stop) => stop())
      window.removeEventListener('online', networkChanged)
      window.removeEventListener('offline', networkChanged)
    }
  }, [uid])

  function read(manual: Source, native: Source) {
    return [
      ...(snapshots[manual]?.documents ?? []).map((doc) => entry(doc, false)),
      ...(snapshots[native]?.documents ?? []).map((doc) => entry(doc, true)),
    ].sort(
      (a, b) =>
        (b.updatedAt?.getTime() ?? 0) - (a.updatedAt?.getTime() ?? 0) ||
        a.name.localeCompare(b.name),
    )
  }

  const activity = (snapshots.activity?.documents ?? []).map(
    (doc) =>
      ({
        id: doc.id,
        action: text(doc.fields.action),
        label: text(doc.fields.label),
        kind: doc.fields.kind as RecordKind,
        updatedAt: date(doc.fields.updatedAt),
        count:
          typeof doc.fields.count === 'number' ? doc.fields.count : undefined,
      }) satisfies Activity,
  )
  const loading = sources.some((source) => !snapshots[source])
  const offline =
    !network ||
    (!loading && Object.values(snapshots).some((value) => value.cached))
  const error =
    Object.values(snapshots).find((value) => value.error)?.error ?? ''
  return (
    <Workspace.Provider
      value={{
        records: {
          projects: read('projects', 'nativeProjects'),
          devices: read('devices', 'linkedDevices'),
          backups: read('backups', 'nativeBackups'),
        },
        activity,
        loading,
        offline,
        error,
      }}
    >
      {children}
    </Workspace.Provider>
  )
}
