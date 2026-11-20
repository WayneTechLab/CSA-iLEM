import { useEffect, useState, type FormEvent } from 'react'
import {
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Search,
  ShieldCheck,
} from 'lucide-react'
import { AppLink } from '@/components/navigation/AppLink'
import { useSession } from '@/portal/useSession'
import { call, dateLabel } from '@/portal/workspace'
import { ACCOUNT_LEVELS } from '@/auth/accountLevels'
import { confirmIdentity, errorMessage } from '@/portal/authActions'
import { Empty, PageHeader } from './WorkspacePages'

type Account = {
  uid: string
  email: string
  verified: boolean
  disabled: boolean
  level: number
}
type Audit = {
  id: string
  actor: string
  target: string
  email: string
  previousLevel: number
  level: number
  updatedAt: string
}
type Page<T> = { rows: T[]; next: string | null }

export function OperationsPage() {
  const { level } = useSession()
  const [status, setStatus] = useState<{
    service: string
    database: string
    checkedAt: string
  } | null>(null)
  const [error, setError] = useState('')
  useEffect(() => {
    let current = true
    void call<NonNullable<typeof status>>('operationsStatus', {})
      .then((result) => {
        if (current) setStatus(result)
      })
      .catch((problem) => {
        if (current) setError(errorMessage(problem))
      })
    return () => {
      current = false
    }
  }, [])
  return (
    <>
      <PageHeader
        title="Operations"
        description="Check service availability and open the staff tools available to your account."
      />
      <section className="surface panel">
        <h2>
          <CheckCircle2 size={19} /> Workspace service
        </h2>
        {error ? (
          <p className="notice error" role="alert">
            {error}
          </p>
        ) : !status ? (
          <p role="status">Checking service…</p>
        ) : (
          <dl className="detail-list">
            <div>
              <dt>Status</dt>
              <dd>{status.service}</dd>
            </div>
            <div>
              <dt>Database</dt>
              <dd>{status.database}</dd>
            </div>
            <div>
              <dt>Checked</dt>
              <dd>{dateLabel(new Date(status.checkedAt))}</dd>
            </div>
          </dl>
        )}
      </section>
      {level === 5 && (
        <div className="split-panels">
          <AppLink className="surface feature-card" to="/admin/accounts">
            <h2>Account management</h2>
            <p>Find verified accounts and assign member or staff access.</p>
          </AppLink>
          <AppLink className="surface feature-card" to="/admin/audit">
            <h2>Role audit</h2>
            <p>Review access changes recorded by the service.</p>
          </AppLink>
        </div>
      )}
    </>
  )
}

function CursorNav({
  previous,
  next,
  loading,
  onPrevious,
  onNext,
}: {
  previous: boolean
  next: boolean
  loading: boolean
  onPrevious: () => void
  onNext: () => void
}) {
  if (!previous && !next) return null
  return (
    <nav aria-label="List pages" className="pagination">
      <button
        className="button secondary"
        disabled={!previous || loading}
        onClick={onPrevious}
      >
        <ChevronLeft size={16} /> Previous
      </button>
      <button
        className="button secondary"
        disabled={!next || loading}
        onClick={onNext}
      >
        Next <ChevronRight size={16} />
      </button>
    </nav>
  )
}

type PaginationState = {
  email: string
  stack: (string | null)[]
  revision: number
}

function useServicePage<T>(name: string) {
  const initial: PaginationState = { email: '', stack: [null], revision: 0 }
  const [request, setRequest] = useState(initial)
  const [response, setResponse] = useState<{
    request: PaginationState
    page?: Page<T>
    error?: string
  } | null>(null)
  useEffect(() => {
    let current = true
    void call<Page<T>>(name, {
      email: request.email,
      cursor: request.stack.at(-1),
    })
      .then((page) => {
        if (current) setResponse({ request, page })
      })
      .catch((error) => {
        if (current) setResponse({ request, error: errorMessage(error) })
      })
    return () => {
      current = false
    }
  }, [name, request])
  const page = response?.request === request ? response.page : undefined
  const error = response?.request === request ? (response.error ?? '') : ''
  const loading = response?.request !== request
  return {
    page,
    error,
    loading,
    previous: request.stack.length > 1,
    back: () =>
      setRequest((value) => ({ ...value, stack: value.stack.slice(0, -1) })),
    advance: () => {
      if (page?.next)
        setRequest((value) => ({
          ...value,
          stack: [...value.stack, page.next],
        }))
    },
    search: (email: string) =>
      setRequest((value) => ({
        email,
        stack: [null],
        revision: value.revision + 1,
      })),
    refresh: () =>
      setRequest((value) => ({ ...value, revision: value.revision + 1 })),
  }
}

export function AccountsPage() {
  const { user } = useSession()
  const results = useServicePage<Account>('listAccounts')
  const [email, setEmail] = useState('')
  const [selection, setSelection] = useState<Account | null>(null)
  const [message, setMessage] = useState({ text: '', error: false })
  const [reauth, setReauth] = useState(false)
  const [busy, setBusy] = useState(false)
  if (!user) return null
  const currentUser = user
  const passwordAccount = user.providerData.some(
    (value) => value.providerId === 'password',
  )

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!selection) return
    const form = new FormData(event.currentTarget)
    setBusy(true)
    setMessage({ text: '', error: false })
    try {
      if (reauth)
        await confirmIdentity(currentUser, String(form.get('password') ?? ''))
      const level = Number(form.get('level'))
      await call('assignRole', { uid: selection.uid, level })
      setSelection(null)
      setReauth(false)
      setMessage({
        text: `Saved Level ${level} for ${selection.email}.`,
        error: false,
      })
      results.refresh()
    } catch (error) {
      if ((error as { code?: string }).code === 'functions/failed-precondition')
        setReauth(true)
      setMessage({ text: errorMessage(error), error: true })
    } finally {
      setBusy(false)
    }
  }
  return (
    <>
      <PageHeader
        title="Account management"
        description="Find accounts and manage member, paid, and employee access. Owner assignments are provisioned separately."
        action={
          <AppLink className="button secondary" to="/admin/audit">
            View role audit
          </AppLink>
        }
      />
      <section className="surface inventory">
        <form
          className="table-tools"
          onSubmit={(event) => {
            event.preventDefault()
            setSelection(null)
            results.search(email.trim())
          }}
        >
          <label className="search-field">
            <Search size={17} />
            <input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              type="email"
              aria-label="Find account email"
              placeholder="Find by exact email address"
            />
          </label>
          <button className="button primary">Find account</button>
          <button
            type="button"
            className="button secondary"
            onClick={() => {
              setEmail('')
              setSelection(null)
              results.search('')
            }}
          >
            Show all
          </button>
        </form>
        {results.error && (
          <p role="alert" className="notice error">
            {results.error}
          </p>
        )}
        {results.loading ? (
          <p className="list-state" role="status">
            Loading accounts…
          </p>
        ) : results.page?.rows.length ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th scope="col">Account</th>
                  <th scope="col">Verification</th>
                  <th scope="col">Level</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {results.page.rows.map((row) => (
                  <tr key={row.uid}>
                    <th scope="row">{row.email || row.uid}</th>
                    <td>
                      {row.disabled
                        ? 'Disabled'
                        : row.verified
                          ? 'Verified'
                          : 'Pending'}
                    </td>
                    <td>
                      <span
                        className={`badge ${row.level === 5 ? 'positive' : 'subdued'}`}
                      >
                        Level {row.level} · {ACCOUNT_LEVELS[row.level]?.label}
                      </span>
                    </td>
                    <td>
                      {row.uid === user.uid || row.level === 5 ? (
                        'Trusted provisioning'
                      ) : (
                        <button
                          className="button secondary"
                          aria-label={`Change level for ${row.email}`}
                          disabled={row.disabled || !row.verified}
                          onClick={() => {
                            setSelection(row)
                            setReauth(false)
                            setMessage({ text: '', error: false })
                          }}
                        >
                          Change level
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          !results.error && (
            <Empty title="No matching accounts">
              Check the address or browse all accounts.
            </Empty>
          )
        )}
        <CursorNav
          previous={results.previous}
          next={Boolean(results.page?.next)}
          loading={results.loading}
          onPrevious={results.back}
          onNext={results.advance}
        />
      </section>
      {selection && (
        <section className="surface panel narrow">
          <h2>Change level for {selection.email}</h2>
          <form className="field-stack" onSubmit={submit}>
            <label>
              Account level
              <select name="level" defaultValue={selection.level}>
                {ACCOUNT_LEVELS.slice(1, 5).map((item) => (
                  <option key={item.level} value={item.level}>
                    Level {item.level} · {item.label}
                  </option>
                ))}
              </select>
            </label>
            {reauth &&
              (passwordAccount ? (
                <label>
                  Your current password
                  <input
                    type="password"
                    required
                    name="password"
                    autoComplete="current-password"
                  />
                </label>
              ) : (
                <p>Continue to confirm your Google sign-in.</p>
              ))}
            <div className="actions">
              <button className="button primary" disabled={busy}>
                {reauth ? 'Confirm sign-in and save' : 'Save role change'}
              </button>
              <button
                type="button"
                className="button secondary"
                disabled={busy}
                onClick={() => {
                  setSelection(null)
                  setMessage({ text: '', error: false })
                }}
              >
                Cancel
              </button>
            </div>
          </form>
        </section>
      )}
      {message.text && (
        <p
          className={message.error ? 'notice error' : 'notice'}
          role={message.error ? 'alert' : 'status'}
        >
          {message.text}
        </p>
      )}
    </>
  )
}

export function AuditPage() {
  const results = useServicePage<Audit>('listRoleAudit')
  return (
    <>
      <PageHeader
        title="Role audit"
        description="Review account level changes that were saved by the owner."
        action={
          <AppLink className="button secondary" to="/admin/accounts">
            Manage accounts
          </AppLink>
        }
      />
      <section className="surface inventory">
        <div className="table-tools">
          <ShieldCheck size={18} />
          <strong>Role changes</strong>
          <button
            className="button secondary"
            disabled={results.loading}
            onClick={results.refresh}
          >
            Refresh
          </button>
        </div>
        {results.error && (
          <p role="alert" className="notice error">
            {results.error}
          </p>
        )}
        {results.loading ? (
          <p className="list-state" role="status">
            Loading audit…
          </p>
        ) : results.page?.rows.length ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th scope="col">Account</th>
                  <th scope="col">Change</th>
                  <th scope="col">Changed by</th>
                  <th scope="col">Time</th>
                </tr>
              </thead>
              <tbody>
                {results.page.rows.map((event) => (
                  <tr key={event.id}>
                    <th scope="row">{event.email || event.target}</th>
                    <td>
                      Level {event.previousLevel} → Level {event.level}
                    </td>
                    <td>{event.actor}</td>
                    <td>{dateLabel(new Date(event.updatedAt))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          !results.error && (
            <Empty title="No role changes yet">
              Changes appear here after the owner saves an assignment.
            </Empty>
          )
        )}
        <CursorNav
          previous={results.previous}
          next={Boolean(results.page?.next)}
          loading={results.loading}
          onPrevious={results.back}
          onNext={results.advance}
        />
      </section>
    </>
  )
}
