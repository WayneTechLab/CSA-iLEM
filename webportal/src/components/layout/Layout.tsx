import { useEffect, useRef, useState, type ReactNode } from 'react'
import {
  Activity,
  ArrowDownToLine,
  ArrowUpRight,
  Cloud,
  FolderGit2,
  HardDrive,
  LayoutDashboard,
  Laptop2,
  Layers3,
  LogOut,
  Menu,
  Settings,
  ShieldCheck,
  Users,
  X,
} from 'lucide-react'
import { signOut } from 'firebase/auth'
import { AppLink } from '@/components/navigation/AppLink'
import { AccessibilityPageControl } from '@/components/shell/SiteControls'
import { auth } from '@/config/firebase'
import { isActivePath, navigate } from '@/lib/navigation'
import { useSession } from '@/portal/useSession'
import { useWorkspace } from '@/portal/workspace'

const workspaceLinks = [
  { path: '/dashboard', label: 'Overview', icon: LayoutDashboard },
  { path: '/projects', label: 'Projects', icon: FolderGit2 },
  { path: '/devices', label: 'Devices', icon: Laptop2 },
  { path: '/backups', label: 'Backups', icon: HardDrive },
  { path: '/activity', label: 'Activity', icon: Activity },
]
const settingsLinks = [
  { path: '/settings/profile', label: 'Profile', icon: Settings },
  { path: '/settings/security', label: 'Account security', icon: ShieldCheck },
  { path: '/settings/sync', label: 'Sync settings', icon: Cloud },
  { path: '/admin', label: 'Operations', icon: ShieldCheck, level: 4 },
  { path: '/admin/accounts', label: 'Manage accounts', icon: Users, level: 5 },
  { path: '/admin/audit', label: 'Role audit', icon: Activity, level: 5 },
]

function Brand({ to = '/' }: { to?: string }) {
  return (
    <AppLink to={to} className="portal-brand" aria-label="CSA-iEM home">
      <span className="brand-mark">
        <Layers3 size={22} aria-hidden="true" />
      </span>
      <strong>CSA-iEM</strong>
    </AppLink>
  )
}

function SkipLink() {
  return (
    <a className="skip-link" href="#content">
      Skip to content
    </a>
  )
}

export function Layout({
  children,
  currentPath,
}: {
  children: ReactNode
  currentPath: string
}) {
  const { user, verified } = useSession()
  const [open, setOpen] = useState(false)
  const links = [
    ['/features', 'Features'],
    ['/plans', 'Plans'],
    ['/docs', 'Docs'],
    ['/help', 'Help'],
  ] as const
  const account = user ? (verified ? '/dashboard' : '/verify-email') : '/login'
  return (
    <div className="portal-app public-layout">
      <SkipLink />
      <header className="public-topbar">
        <div className="public-top-inner">
          <Brand />
          <nav className="public-nav" aria-label="Public navigation">
            {links.map(([to, label]) => (
              <AppLink
                to={to}
                key={to}
                aria-current={
                  isActivePath(currentPath, to) ? 'page' : undefined
                }
              >
                {label}
              </AppLink>
            ))}
          </nav>
          <div className="header-actions">
            <AppLink className="button text" to={account}>
              {user ? 'Workspace' : 'Log in'}
            </AppLink>
            <AppLink className="button primary header-download" to="/downloads">
              <ArrowDownToLine size={16} /> Download
            </AppLink>
            <button
              className="icon-button mobile-toggle"
              type="button"
              aria-label={open ? 'Close navigation' : 'Open navigation'}
              aria-expanded={open}
              onClick={() => setOpen((value) => !value)}
            >
              {open ? <X size={23} /> : <Menu size={23} />}
            </button>
          </div>
        </div>
        {open && (
          <nav className="mobile-public-nav" aria-label="Mobile navigation">
            {[...links, ['/downloads', 'Downloads'] as const].map(
              ([to, label]) => (
                <AppLink key={to} to={to} onClick={() => setOpen(false)}>
                  {label}
                </AppLink>
              ),
            )}
          </nav>
        )}
      </header>
      <main id="content" tabIndex={-1}>
        {children}
      </main>
      <footer className="portal-footer">
        <div>
          <Brand />
          <p>Workspace and backup tools by Wayne Tech Lab LLC.</p>
        </div>
        <nav aria-label="Footer navigation">
          {[
            ['/about', 'About'],
            ['/contact', 'Contact'],
            ['/security', 'Security'],
            ['/privacy', 'Privacy'],
            ['/terms', 'Terms'],
            ['/releases', 'Releases'],
          ].map(([to, label]) => (
            <AppLink key={to} to={to}>
              {label}
            </AppLink>
          ))}
        </nav>
      </footer>
      <AccessibilityPageControl showPageTravel={false} />
    </div>
  )
}

export function WorkspaceLayout({
  children,
  currentPath,
}: {
  children: ReactNode
  currentPath: string
}) {
  const { level, user } = useSession()
  const { offline, error } = useWorkspace()
  const [open, setOpen] = useState(false)
  const [signOutError, setSignOutError] = useState('')
  const navigation = useRef<HTMLElement>(null)
  const menuButton = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (!open || !navigation.current) return
    const drawer = navigation.current
    const desktop = window.matchMedia('(min-width: 801px)')
    const controls = () =>
      Array.from(
        drawer.querySelectorAll<HTMLElement>('a[href], button:not([disabled])'),
      )
    const first = controls().find(
      (control) =>
        control.getAttribute('aria-label') === 'Close workspace navigation',
    )
    first?.focus()
    function keydown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        event.preventDefault()
        setOpen(false)
        return
      }
      if (event.key !== 'Tab') return
      const links = controls()
      const focused = document.activeElement
      if (event.shiftKey && focused === links[0]) {
        event.preventDefault()
        links.at(-1)?.focus()
      } else if (!event.shiftKey && focused === links.at(-1)) {
        event.preventDefault()
        links[0]?.focus()
      }
    }
    const resize = () => {
      if (desktop.matches) setOpen(false)
    }
    drawer.addEventListener('keydown', keydown)
    desktop.addEventListener('change', resize)
    const trigger = menuButton.current
    return () => {
      drawer.removeEventListener('keydown', keydown)
      desktop.removeEventListener('change', resize)
      trigger?.focus()
    }
  }, [open])

  async function logout() {
    try {
      await signOut(auth)
      navigate('/login', { replace: true })
    } catch {
      setSignOutError('Could not sign out. Try again.')
    }
  }
  return (
    <div className="portal-app workspace-layout">
      <SkipLink />
      <aside
        className={`workspace-sidebar ${open ? 'mobile-open' : ''}`}
        id="workspace-sidebar"
        ref={navigation}
        role={open ? 'dialog' : undefined}
        aria-modal={open || undefined}
        aria-label="Workspace sidebar"
      >
        <div className="sidebar-brand">
          <Brand to="/dashboard" />
          <button
            className="icon-button mobile-toggle"
            onClick={() => setOpen(false)}
            aria-label="Close workspace navigation"
          >
            <X size={21} />
          </button>
        </div>
        <nav aria-label="Workspace navigation">
          <p className="sidebar-label">Workspace</p>
          {workspaceLinks.map(({ path, label, icon: Icon }) => (
            <AppLink
              key={path}
              to={path}
              onClick={() => setOpen(false)}
              aria-current={
                isActivePath(currentPath, path, path === '/dashboard')
                  ? 'page'
                  : undefined
              }
            >
              <Icon size={18} />
              {label}
            </AppLink>
          ))}
          <p className="sidebar-label">Account</p>
          {settingsLinks
            .filter((item) => level >= (item.level ?? 1))
            .map(({ path, label, icon: Icon }) => (
              <AppLink
                key={path}
                to={path}
                onClick={() => setOpen(false)}
                aria-current={
                  isActivePath(currentPath, path, true) ? 'page' : undefined
                }
              >
                <Icon size={18} />
                {label}
              </AppLink>
            ))}
        </nav>
        <div className="sidebar-footer">
          <AppLink to="/downloads">
            Downloads <ArrowUpRight size={16} />
          </AppLink>
          <AppLink to="/help">
            Help <ArrowUpRight size={16} />
          </AppLink>
        </div>
      </aside>
      <div className="workspace-body" inert={open}>
        <header className="workspace-topbar">
          <button
            className="icon-button mobile-toggle"
            aria-label="Open workspace navigation"
            aria-expanded={open}
            aria-controls="workspace-sidebar"
            ref={menuButton}
            onClick={() => setOpen(true)}
          >
            <Menu size={23} />
          </button>
          {import.meta.env.DEV && (
            <span className="badge warning local-environment">
              Local emulator
            </span>
          )}
          <div className="workspace-account">
            <span className="avatar" aria-hidden="true">
              {(user?.displayName || user?.email || 'M')
                .slice(0, 1)
                .toUpperCase()}
            </span>
            <AppLink to="/settings/profile">
              {user?.displayName || user?.email}
            </AppLink>
            <button
              type="button"
              title="Sign out"
              aria-label="Sign out"
              className="icon-button"
              onClick={() => void logout()}
            >
              <LogOut size={19} />
            </button>
          </div>
        </header>
        <main id="content" className="workspace-main" tabIndex={-1}>
          {offline && (
            <p role="status" className="notice warning">
              Offline. Showing available cached records. Reconnect to make
              changes.
            </p>
          )}
          {error && (
            <p role="alert" className="notice error">
              Some records could not load. {error}
            </p>
          )}
          {signOutError && (
            <p role="alert" className="notice error">
              {signOutError}
            </p>
          )}
          {children}
        </main>
      </div>
      <AccessibilityPageControl showPageTravel={false} />
    </div>
  )
}
