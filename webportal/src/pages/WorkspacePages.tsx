import { useState, type FormEvent, type ReactNode } from 'react'
import {
  ArrowDownToLine,
  ArrowRight,
  ArrowUpRight,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  CircleHelp,
  Cloud,
  Copy,
  FolderGit2,
  HardDrive,
  Laptop2,
  Plus,
  Search,
  ShieldCheck,
} from 'lucide-react'
import { AppLink } from '@/components/navigation/AppLink'
import { useSession } from '@/portal/useSession'
import {
  call,
  dateLabel,
  kindLabels,
  type Activity,
  type RecordKind,
  type WorkspaceEntry,
  useWorkspace,
} from '@/portal/workspace'
import { ProfileForm, SecurityForm } from './AccountPages'
import { errorMessage } from '@/portal/authActions'
import { navigate } from '@/lib/navigation'
import { ACCOUNT_LEVELS } from '@/auth/accountLevels'

const icons = { projects: FolderGit2, devices: Laptop2, backups: HardDrive }
const descriptions = {
  projects: 'Find your repositories and see where each workspace is saved.',
  devices: 'Track computers and check when your paired Macs last synced.',
  backups: 'Record recovery locations and see what a paired Mac has verified.',
}
const pageSize = 12

function recordURL(kind: RecordKind, row: WorkspaceEntry) {
  return `/${kind}/${row.source === 'mac' ? 'mac-' : ''}${row.id}`
}

export function PageHeader({
  title,
  description,
  action,
}: {
  title: string
  description: string
  action?: ReactNode
}) {
  return (
    <header className="workspace-heading">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      {action && <div className="actions">{action}</div>}
    </header>
  )
}

export function Empty({
  title,
  children,
}: {
  title: string
  children: ReactNode
}) {
  return (
    <div className="empty">
      <CircleHelp size={26} aria-hidden="true" />
      <h2>{title}</h2>
      <p>{children}</p>
    </div>
  )
}

function releaseFilename(kind: string) {
  const date = new Date().toISOString().slice(0, 10)
  return `csa-iem-${kind}-${date}.csv`
}

function downloadCSV(rows: (string | null)[][], kind: string) {
  function quote(value: string | null) {
    let text = value ?? ''
    if (/^[\s]*[=+@-]|^[\t\r\n]/.test(text)) text = "'" + text
    return '"' + text.replaceAll('"', '""') + '"'
  }
  const file = [['Name', 'Location', 'Notes', 'Source', 'Updated'], ...rows]
    .map((row) => row.map(quote).join(','))
    .join('\r\n')
  const link = document.createElement('a')
  const url = URL.createObjectURL(
    new Blob([file], { type: 'text/csv;charset=utf-8' }),
  )
  link.href = url
  link.download = releaseFilename(kind)
  link.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

function RecordBadge({ row, kind }: { row: WorkspaceEntry; kind: RecordKind }) {
  if (row.status === 'revoked')
    return <span className="badge warning">Access revoked</span>
  if (kind === 'backups' && row.verifiedAt)
    return (
      <span className="badge positive">
        <Check size={13} /> Verified by Mac
      </span>
    )
  if (kind === 'devices' && row.source === 'mac')
    return <span className="badge positive">Paired Mac</span>
  if (kind === 'backups')
    return (
      <span className="badge subdued">
        {row.source === 'manual' ? 'Manual save point' : 'Verification unknown'}
      </span>
    )
  return (
    <span className="badge subdued">
      {row.source === 'mac' ? 'From Mac' : 'Manual'}
    </span>
  )
}

function RecordForm({
  kind,
  row,
  onComplete,
  onCancel,
}: {
  kind: RecordKind
  row?: WorkspaceEntry
  onComplete: (id: string) => void
  onCancel: () => void
}) {
  const { records, offline } = useWorkspace()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const fields = Object.fromEntries(new FormData(event.currentTarget))
    setBusy(true)
    setError('')
    try {
      const result = await call<{ id: string }>('saveWorkspaceRecord', {
        kind,
        operation: row ? 'update' : 'create',
        id: row?.id,
        record: fields,
      })
      onComplete(result.id)
    } catch (problem) {
      setError(errorMessage(problem))
    } finally {
      setBusy(false)
    }
  }
  return (
    <form className="field-stack" onSubmit={submit}>
      <label>
        Name
        <input name="name" required maxLength={120} defaultValue={row?.name} />
      </label>
      <label>
        {kind === 'devices' ? 'Device details' : 'Location'}
        <input
          name="location"
          maxLength={1000}
          defaultValue={row?.location}
          placeholder={
            kind === 'devices'
              ? 'MacBook Pro · Studio'
              : 'Volume label, path, or repository URL'
          }
        />
      </label>
      {kind === 'backups' && (
        <>
          <label>
            Project
            <select name="projectId" defaultValue={row?.projectId ?? ''}>
              <option value="">No linked project</option>
              {records.projects.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Device
            <select name="deviceId" defaultValue={row?.deviceId ?? ''}>
              <option value="">No linked device</option>
              {records.devices.map((device) => (
                <option key={device.id} value={device.id}>
                  {device.name}
                </option>
              ))}
            </select>
          </label>
        </>
      )}
      <label>
        Notes
        <textarea
          name="notes"
          maxLength={4000}
          defaultValue={row?.notes}
          rows={3}
        />
        <small>Keep passwords, tokens, and keys out of notes and paths.</small>
      </label>
      <div className="actions">
        <button className="button primary" disabled={busy || offline}>
          {busy ? 'Saving…' : 'Save record'}
        </button>
        <button type="button" className="button secondary" onClick={onCancel}>
          Cancel
        </button>
      </div>
      {error && (
        <p className="notice error" role="alert">
          {error}
        </p>
      )}
    </form>
  )
}

function Pagination({
  page,
  total,
  change,
}: {
  page: number
  total: number
  change: (next: number) => void
}) {
  if (total <= pageSize) return null
  const pages = Math.ceil(total / pageSize)
  return (
    <nav className="pagination" aria-label="List pages">
      <button
        className="button secondary"
        disabled={page === 0}
        onClick={() => change(page - 1)}
      >
        <ChevronLeft size={15} /> Previous
      </button>
      <span>
        Page {page + 1} of {pages}
      </span>
      <button
        className="button secondary"
        disabled={page + 1 >= pages}
        onClick={() => change(page + 1)}
      >
        Next <ChevronRight size={15} />
      </button>
    </nav>
  )
}

export function InventoryPage({ kind }: { kind: RecordKind }) {
  const { records, loading, offline } = useWorkspace()
  const { level } = useSession()
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('')
  const [page, setPage] = useState(0)
  const [adding, setAdding] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [error, setError] = useState('')
  const available = records[kind]
  const title =
    kind === 'backups' ? 'Backup save points' : kindLabels[kind] + 's'
  const needle = search.trim().toLocaleLowerCase()
  const filtered = available.filter((row) => {
    if (filter === 'verified' && !row.verifiedAt) return false
    if (filter === 'manual' && row.source !== 'manual') return false
    if (filter === 'mac' && row.source !== 'mac') return false
    return [row.name, row.location, row.notes].some((value) =>
      value.toLocaleLowerCase().includes(needle),
    )
  })
  const current = Math.min(
    page,
    Math.max(0, Math.ceil(filtered.length / pageSize) - 1),
  )
  const rows = filtered.slice(current * pageSize, (current + 1) * pageSize)
  async function exportRows() {
    setExporting(true)
    setError('')
    try {
      const entries = await call<(string | null)[][]>('workspaceExport', {
        kind,
      })
      downloadCSV(entries, kind)
    } catch (problem) {
      setError(errorMessage(problem))
    } finally {
      setExporting(false)
    }
  }
  return (
    <>
      <PageHeader
        title={title}
        description={descriptions[kind]}
        action={
          <>
            {level >= 2 && (
              <button
                className="button secondary"
                onClick={() => void exportRows()}
                disabled={exporting || offline}
              >
                <ArrowDownToLine size={17} />{' '}
                {exporting ? 'Exporting…' : 'Export CSV'}
              </button>
            )}
            {kind === 'devices' && (
              <AppLink to="/devices/pair" className="button secondary">
                Pair a Mac
              </AppLink>
            )}
            <button
              className="button primary"
              disabled={offline}
              onClick={() => setAdding((value) => !value)}
            >
              <Plus size={17} /> Add {kindLabels[kind].toLowerCase()}
            </button>
          </>
        }
      />
      {error && (
        <p className="notice error" role="alert">
          {error}
        </p>
      )}
      {adding && (
        <section className="surface record-editor">
          <h2>New {kindLabels[kind].toLowerCase()}</h2>
          <RecordForm
            kind={kind}
            onComplete={(id) => navigate(`/${kind}/${id}`)}
            onCancel={() => setAdding(false)}
          />
        </section>
      )}
      <section className="surface inventory">
        <div className="table-tools">
          <label className="search-field">
            <Search size={17} />
            <input
              aria-label={`Search ${kind}`}
              type="search"
              value={search}
              placeholder={`Search ${kind}`}
              onChange={(event) => {
                setPage(0)
                setSearch(event.target.value)
              }}
            />
          </label>
          <select
            aria-label="Filter by record source"
            value={filter}
            onChange={(event) => {
              setPage(0)
              setFilter(event.target.value)
            }}
          >
            <option value="">All sources</option>
            <option value="manual">Manual</option>
            <option value="mac">From Mac</option>
            {kind === 'backups' && (
              <option value="verified">Verified by Mac</option>
            )}
          </select>
          <span className="muted">
            {loading
              ? 'Loading…'
              : `${filtered.length} ${filtered.length === 1 ? 'record' : 'records'}`}
          </span>
        </div>
        {loading && !available.length ? (
          <p className="list-state" role="status">
            Loading {kind}…
          </p>
        ) : !rows.length ? (
          <Empty
            title={
              available.length
                ? 'No matching records'
                : `No ${kind} recorded yet`
            }
          >
            {available.length
              ? 'Try another search or clear the source filter.'
              : `Add a ${kindLabels[kind].toLowerCase()} to start your inventory.`}
          </Empty>
        ) : (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th scope="col">Name</th>
                  <th scope="col">Location</th>
                  <th scope="col">Status</th>
                  <th scope="col">Updated</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={recordURL(kind, row)}>
                    <th scope="row">
                      <AppLink
                        className="record-link"
                        to={recordURL(kind, row)}
                      >
                        {row.name} <ArrowUpRight size={15} />
                      </AppLink>
                    </th>
                    <td>{row.location || 'Not shared'}</td>
                    <td>
                      <RecordBadge kind={kind} row={row} />
                    </td>
                    <td>{dateLabel(row.updatedAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Pagination total={filtered.length} page={current} change={setPage} />
      </section>
    </>
  )
}

function Related({
  title,
  kind,
  rows,
}: {
  title: string
  kind: RecordKind
  rows: WorkspaceEntry[]
}) {
  return (
    <section className="surface panel">
      <h2>{title}</h2>
      {rows.length ? (
        <ul className="related-list">
          {rows.map((row) => (
            <li key={recordURL(kind, row)}>
              <AppLink to={recordURL(kind, row)}>
                {row.name}
                <ArrowUpRight size={15} />
              </AppLink>
              <RecordBadge kind={kind} row={row} />
            </li>
          ))}
        </ul>
      ) : (
        <p className="muted">No linked records.</p>
      )}
    </section>
  )
}

export function RecordDetailPage({
  kind,
  id,
}: {
  kind: RecordKind
  id: string
}) {
  const { loading, records, offline } = useWorkspace()
  const [editing, setEditing] = useState(false)
  const [confirming, setConfirming] = useState(false)
  const [busy, setBusy] = useState(false)
  const [status, setStatus] = useState({ text: '', error: false })
  const row = records[kind].find(
    (entry) => recordURL(kind, entry) === `/${kind}/${id}`,
  )
  if (!row)
    return (
      <>
        <AppLink className="back-link" to={`/${kind}`}>
          <ChevronLeft size={16} /> {kindLabels[kind]}s
        </AppLink>
        {loading ? (
          <p role="status">Loading record…</p>
        ) : (
          <Empty title="Record unavailable">
            This entry may have been removed or belongs to another workspace.
          </Empty>
        )}
      </>
    )
  const item = row
  const canRevoke = kind === 'devices' && item.status === 'paired'
  const canEdit = item.source === 'manual'
  async function remove() {
    setBusy(true)
    setStatus({ text: '', error: false })
    try {
      if (canRevoke) {
        await call('revokeLinkedDevice', { deviceId: item.id })
        setConfirming(false)
        setStatus({ text: 'Device access revoked.', error: false })
      } else {
        await call('saveWorkspaceRecord', {
          kind,
          id: item.id,
          operation: 'delete',
        })
        navigate(`/${kind}`)
      }
    } catch (error) {
      setStatus({ text: errorMessage(error), error: true })
    } finally {
      setBusy(false)
    }
  }
  return (
    <>
      <AppLink className="back-link" to={`/${kind}`}>
        <ChevronLeft size={16} /> {kindLabels[kind]}s
      </AppLink>
      <PageHeader
        title={item.name}
        description={
          canEdit
            ? 'Manually recorded in your private workspace.'
            : 'Reported by a paired Mac.'
        }
        action={<RecordBadge kind={kind} row={item} />}
      />
      <section className="surface panel">
        <div className="section-title">
          <h2>Details</h2>
          {canEdit && (
            <button
              className="button secondary"
              onClick={() => {
                setEditing(true)
                setConfirming(false)
              }}
              disabled={offline || editing}
            >
              Edit record
            </button>
          )}
        </div>
        {editing ? (
          <RecordForm
            kind={kind}
            row={item}
            onCancel={() => setEditing(false)}
            onComplete={() => {
              setEditing(false)
              setStatus({ text: 'Record saved.', error: false })
            }}
          />
        ) : (
          <dl className="detail-list">
            <div>
              <dt>Location</dt>
              <dd>{item.location || 'Exact path not shared'}</dd>
            </div>
            <div>
              <dt>Updated</dt>
              <dd>{dateLabel(item.updatedAt)}</dd>
            </div>
            {kind === 'devices' && item.source === 'mac' && (
              <>
                <div>
                  <dt>Last successful sync</dt>
                  <dd>
                    {item.lastSyncAt
                      ? dateLabel(item.lastSyncAt)
                      : 'Waiting for first sync'}
                  </dd>
                </div>
                <div>
                  <dt>Exact paths</dt>
                  <dd>
                    {item.sharePaths ? 'Sharing allowed' : 'Private on the Mac'}
                  </dd>
                </div>
              </>
            )}
            {kind === 'backups' && (
              <div>
                <dt>Verification</dt>
                <dd>
                  {item.verifiedAt
                    ? dateLabel(item.verifiedAt)
                    : 'No native verification recorded'}
                </dd>
              </div>
            )}
            {item.notes && (
              <div>
                <dt>Notes</dt>
                <dd>{item.notes}</dd>
              </div>
            )}
          </dl>
        )}
        {!editing &&
          (canEdit || canRevoke) &&
          (confirming ? (
            <div className="notice warning">
              <p>
                {canRevoke
                  ? 'Revoke this device’s ability to upload? Its previous save points stay in your workspace.'
                  : 'Remove this record from the portal? The folder and its files stay on your device.'}
              </p>
              <div className="actions">
                <button
                  className="button danger"
                  disabled={busy || offline}
                  onClick={() => void remove()}
                >
                  {canRevoke ? 'Confirm revocation' : 'Confirm removal'}
                </button>
                <button
                  className="button secondary"
                  disabled={busy}
                  onClick={() => setConfirming(false)}
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <button
              className="button danger-text"
              disabled={offline}
              onClick={() => setConfirming(true)}
            >
              {canRevoke ? 'Revoke device access' : 'Remove record'}
            </button>
          ))}
        {status.text && (
          <p
            className={status.error ? 'notice error' : 'notice'}
            role={status.error ? 'alert' : 'status'}
          >
            {status.text}
          </p>
        )}
      </section>
      {kind !== 'backups' && (
        <Related
          title="Backup save points"
          kind="backups"
          rows={records.backups.filter((backup) =>
            kind === 'projects'
              ? backup.projectId === item.id
              : backup.deviceId === item.id,
          )}
        />
      )}
      {kind === 'devices' && (
        <Related
          title="Projects from this Mac"
          kind="projects"
          rows={records.projects.filter(
            (project) => project.deviceId === item.id,
          )}
        />
      )}
      {kind === 'backups' && (
        <div className="split-panels">
          <Related
            title="Related project"
            kind="projects"
            rows={records.projects.filter(
              (project) => project.id === item.projectId,
            )}
          />
          <Related
            title="Related device"
            kind="devices"
            rows={records.devices.filter(
              (device) => device.id === item.deviceId,
            )}
          />
        </div>
      )}
    </>
  )
}

export function PairDevicePage() {
  const { offline } = useWorkspace()
  const [allowPaths, setAllowPaths] = useState(false)
  const [secret, setSecret] = useState<{
    code: string
    expiresAt: number
  } | null>(null)
  const [status, setStatus] = useState({ text: '', error: false })
  const [busy, setBusy] = useState(false)
  async function create() {
    setBusy(true)
    setSecret(null)
    setStatus({ text: '', error: false })
    try {
      setSecret(await call('createDevicePairCode', { allowPaths }))
    } catch (error) {
      setStatus({ text: errorMessage(error), error: true })
    } finally {
      setBusy(false)
    }
  }
  async function copy() {
    if (!secret) return
    try {
      await navigator.clipboard.writeText(secret.code)
      setStatus({ text: 'Code copied. Paste it in the Mac app.', error: false })
    } catch {
      setStatus({ text: 'Select and copy the code shown above.', error: false })
    }
  }
  return (
    <>
      <AppLink className="back-link" to="/devices">
        <ChevronLeft size={16} /> Devices
      </AppLink>
      <PageHeader
        title="Pair a Mac"
        description="Approve selected metadata from the native CSA-iEM app."
      />
      <section className="surface panel pair-panel">
        <h2>Connect from Settings</h2>
        <ol className="steps">
          <li>Generate a single-use code below.</li>
          <li>
            Open <strong>Settings → Cloud workspace sync</strong> in CSA-iEM on
            the Mac.
          </li>
          <li>
            Paste the code and review the device, projects, and fields before
            approving the connection.
          </li>
        </ol>
        <label className="check-row">
          <input
            type="checkbox"
            checked={allowPaths}
            onChange={(event) => setAllowPaths(event.target.checked)}
          />{' '}
          Allow this Mac to share exact paths after a second confirmation
        </label>
        <button
          className="button primary"
          disabled={busy || offline}
          onClick={() => void create()}
        >
          {busy
            ? 'Generating…'
            : secret
              ? 'Generate another code'
              : 'Generate pairing code'}
        </button>
        {secret && (
          <div className="pair-code">
            <label>
              Pairing code
              <input
                aria-label="Pairing code"
                readOnly
                value={secret.code}
                spellCheck={false}
              />
            </label>
            <button className="button secondary" onClick={() => void copy()}>
              <Copy size={16} /> Copy code
            </button>
            <small>Expires {dateLabel(new Date(secret.expiresAt))}.</small>
          </div>
        )}
        {status.text && (
          <p
            role={status.error ? 'alert' : 'status'}
            className={status.error ? 'notice error' : 'notice'}
          >
            {status.text}
          </p>
        )}
      </section>
    </>
  )
}

function ActivityRows({ rows }: { rows: Activity[] }) {
  return (
    <ul className="activity-list">
      {rows.map((row) => (
        <li key={row.id}>
          <span
            className={`activity-icon ${row.action === 'synced' ? 'green' : ''}`}
          >
            {row.action === 'synced' ? (
              <Cloud size={17} />
            ) : (
              <CheckCircle2 size={17} />
            )}
          </span>
          <div>
            <strong>{row.label}</strong>
            <p>
              {row.action === 'synced'
                ? `Synced ${row.count ?? 0} records`
                : `${row.action[0]?.toUpperCase() ?? ''}${row.action.slice(1)} · ${row.kind}`}
            </p>
          </div>
          <time dateTime={row.updatedAt?.toISOString()}>
            {dateLabel(row.updatedAt)}
          </time>
        </li>
      ))}
    </ul>
  )
}

export function ActivityPage() {
  const { activity, loading } = useWorkspace()
  const [page, setPage] = useState(0)
  const [filter, setFilter] = useState('')
  const records = activity.filter((row) =>
    [row.label, row.kind, row.action].some((value) =>
      value.toLowerCase().includes(filter.toLowerCase()),
    ),
  )
  return (
    <>
      <PageHeader
        title="Activity"
        description="Review recent changes, device pairing, and uploads from your workspace."
      />
      <section className="surface inventory">
        <div className="table-tools">
          <label className="search-field">
            <Search size={17} />
            <input
              type="search"
              placeholder="Search activity"
              aria-label="Search activity"
              value={filter}
              onChange={(event) => {
                setFilter(event.target.value)
                setPage(0)
              }}
            />
          </label>
        </div>
        {loading && !activity.length ? (
          <p className="list-state" role="status">
            Loading activity…
          </p>
        ) : records.length ? (
          <ActivityRows
            rows={records.slice(page * pageSize, (page + 1) * pageSize)}
          />
        ) : (
          <Empty title="No matching activity">
            Actions appear here after you save a record or sync a paired Mac.
          </Empty>
        )}
        <Pagination page={page} total={records.length} change={setPage} />
      </section>
    </>
  )
}

export function DashboardPage() {
  const { user, level } = useSession()
  const { records, activity, loading, error } = useWorkspace()
  const verified = records.backups.filter((row) => row.verifiedAt)
  const protectedIds = new Set(verified.map((row) => row.projectId))
  const covered = records.projects.filter((project) =>
    protectedIds.has(project.id),
  ).length
  const percentage = records.projects.length
    ? Math.round((100 * covered) / records.projects.length)
    : 0
  const latestSync = records.devices.reduce<Date | undefined>(
    (latest, row) =>
      row.lastSyncAt && (!latest || row.lastSyncAt > latest)
        ? row.lastSyncAt
        : latest,
    undefined,
  )
  const pairedCount = records.devices.filter(
    (row) => row.status === 'paired',
  ).length
  const metrics = [
    {
      kind: 'projects',
      title: 'Tracked projects',
      detail: `${records.projects.filter((row) => row.source === 'mac').length} synced from Macs`,
    },
    {
      kind: 'devices',
      title: 'Devices',
      detail: `${pairedCount} paired ${pairedCount === 1 ? 'Mac' : 'Macs'}`,
    },
    {
      kind: 'backups',
      title: 'Backup save points',
      detail: `${verified.length} verified by a Mac`,
    },
  ] as const
  return (
    <>
      <PageHeader
        title={`Welcome, ${user?.displayName || user?.email?.split('@')[0] || 'member'}`}
        description="See what’s tracked, what’s backed up, and which Mac last checked in."
        action={
          <AppLink className="button primary" to="/devices/pair">
            <Plus size={17} /> Pair a Mac
          </AppLink>
        }
      />
      <div className="dashboard-strip">
        <span>
          <ShieldCheck size={16} /> Level {level} ·{' '}
          {ACCOUNT_LEVELS[level]?.label}
        </span>
        <span>
          <Cloud size={16} />{' '}
          {latestSync
            ? `Last device sync ${dateLabel(latestSync)}`
            : 'No Mac sync recorded'}
        </span>
      </div>
      <div className="dashboard-metrics">
        {metrics.map(({ kind, title, detail }) => {
          const Icon = icons[kind]
          return (
            <AppLink className="surface metric-card" to={`/${kind}`} key={kind}>
              <div>
                <span className="icon-box">
                  <Icon size={21} />
                </span>
                <ArrowUpRight size={16} />
              </div>
              <strong>{loading || error ? '—' : records[kind].length}</strong>
              <h2>{title}</h2>
              <p>{loading || error ? 'Waiting for records' : detail}</p>
            </AppLink>
          )
        })}
      </div>
      <div className="split-panels dashboard-panels">
        <section className="surface panel">
          <div className="section-title">
            <h2>Recent activity</h2>
            <AppLink to="/activity" className="inline-link">
              View all <ArrowRight size={15} />
            </AppLink>
          </div>
          {activity.length ? (
            <ActivityRows rows={activity.slice(0, 5)} />
          ) : (
            <Empty title="Nothing recorded yet">
              Add a project or pair a Mac to see activity here.
            </Empty>
          )}
        </section>
        <section className="surface panel">
          {level >= 3 ? (
            <>
              <div className="section-title">
                <h2>Backup coverage</h2>
                <span className="badge subdued">Verified receipts</span>
              </div>
              <strong className="coverage-number">
                {loading || error || !records.projects.length
                  ? '—'
                  : `${percentage}%`}
              </strong>
              <progress
                aria-label="Projects with verified backups"
                value={percentage}
                max={100}
              />
              <p className="muted">
                {covered} of {records.projects.length} tracked projects have a
                backup reported as verified by a Mac.
              </p>
              {records.devices.some((row) => row.source === 'mac') && (
                <ul className="coverage-list">
                  {records.devices
                    .filter((row) => row.source === 'mac')
                    .map((device) => (
                      <li key={device.id}>
                        <AppLink to={recordURL('devices', device)}>
                          {device.name}
                        </AppLink>
                        <span>
                          {
                            verified.filter((row) => row.deviceId === device.id)
                              .length
                          }{' '}
                          verified
                        </span>
                      </li>
                    ))}
                </ul>
              )}
              <AppLink className="inline-link" to="/backups">
                Review save points <ArrowRight size={16} />
              </AppLink>
            </>
          ) : (
            <>
              <h2>Recovery workspace</h2>
              <p className="muted">
                Record where backups live. Open any save point for its notes and
                native verification status.
              </p>
              <AppLink className="inline-link" to="/backups">
                Open backups <ArrowRight size={16} />
              </AppLink>
            </>
          )}
        </section>
      </div>
      <Related
        title="Recently updated projects"
        kind="projects"
        rows={records.projects.slice(0, 5)}
      />
    </>
  )
}

export function SettingsPage({ path }: { path: string }) {
  const { user, level } = useSession()
  const { records } = useWorkspace()
  if (!user) return null
  if (path === '/settings/sync')
    return (
      <>
        <PageHeader
          title="Sync settings"
          description="Review connected Macs, their path permissions, and their last successful uploads."
          action={
            <AppLink className="button primary" to="/devices/pair">
              <Plus size={16} /> Pair a Mac
            </AppLink>
          }
        />
        <Related
          title="Paired device access"
          kind="devices"
          rows={records.devices.filter((row) => row.source === 'mac')}
        />
        <div className="surface panel">
          <h2>Sharing controls</h2>
          <p>
            Choose projects and turn automatic sync on or off in the Mac app’s
            Settings. Open a device above to review access or revoke its
            credential.
          </p>
        </div>
      </>
    )
  if (path === '/settings/security')
    return (
      <>
        <PageHeader
          title="Account security"
          description="Review your sign-in method and manage your password."
        />
        <section className="surface panel narrow">
          <SecurityForm user={user} />
        </section>
      </>
    )
  return (
    <>
      <PageHeader
        title="Profile"
        description="Update the name shown in your workspace."
      />
      <section className="surface panel narrow">
        <p className="badge subdued">
          Level {level} · {ACCOUNT_LEVELS[level]?.label}
        </p>
        <ProfileForm user={user} />
      </section>
    </>
  )
}
