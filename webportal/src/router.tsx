import { useEffect, useState, type ReactNode } from 'react'
import { Layout, WorkspaceLayout } from '@/components/layout/Layout'
import { AppLink } from '@/components/navigation/AppLink'
import { NAVIGATION_EVENT, navigate, normalizePath } from '@/lib/navigation'
import { useSession } from '@/portal/useSession'
import { resolveRoute } from '@/portal/routes'
import { WorkspaceProvider } from '@/portal/WorkspaceProvider'
import type { RecordKind } from '@/portal/workspace'
import {
  AuthActionPage,
  ForgotPasswordPage,
  LoginPage,
  SignupPage,
  VerifyEmailPage,
} from '@/pages/AccountPages'
import { PublicPage } from '@/pages/PublicPages'
import {
  ActivityPage,
  DashboardPage,
  Empty,
  InventoryPage,
  PairDevicePage,
  RecordDetailPage,
  SettingsPage,
} from '@/pages/WorkspacePages'
import { AccountsPage, AuditPage, OperationsPage } from '@/pages/AdminPages'

function currentLocation() {
  return location.pathname + location.search
}

function Redirect({ to }: { to: string }) {
  useEffect(() => {
    navigate(to, { replace: true })
  }, [to])
  return (
    <p className="public-content" role="status">
      Opening page…
    </p>
  )
}

function publicPage(path: string) {
  switch (path) {
    case '/login':
      return <LoginPage />
    case '/signup':
      return <SignupPage />
    case '/forgot-password':
      return <ForgotPasswordPage />
    case '/verify-email':
      return <VerifyEmailPage />
    case '/auth/action':
      return <AuthActionPage />
    default:
      return <PublicPage path={path} />
  }
}

function workspacePage(path: string, id: string) {
  switch (path) {
    case '/dashboard':
      return <DashboardPage />
    case '/devices/pair':
      return <PairDevicePage />
    case '/activity':
      return <ActivityPage />
    case '/admin':
      return <OperationsPage />
    case '/admin/accounts':
      return <AccountsPage />
    case '/admin/audit':
      return <AuditPage />
    case '/settings/profile':
    case '/settings/security':
    case '/settings/sync':
      return <SettingsPage path={path} />
    default: {
      const kind = path.split('/')[1] as RecordKind
      return id ? (
        <RecordDetailPage kind={kind} id={id} />
      ) : (
        <InventoryPage kind={kind} />
      )
    }
  }
}

function ProtectedPage({
  level,
  path,
  children,
}: {
  level: number
  path: string
  children: ReactNode
}) {
  const session = useSession()
  if (session.loading)
    return (
      <Layout currentPath={path}>
        <p className="public-content" role="status">
          Checking workspace access…
        </p>
      </Layout>
    )
  if (!session.user)
    return <Redirect to={`/login?next=${encodeURIComponent(path)}`} />
  if (!session.verified) return <Redirect to="/verify-email" />
  return (
    <WorkspaceProvider key={session.user.uid} uid={session.user.uid}>
      <WorkspaceLayout key={path} currentPath={path}>
        {session.level >= level ? (
          children
        ) : (
          <Empty title="Access unavailable">
            This page requires Level {level} access.{' '}
            <AppLink to="/dashboard">Back to overview</AppLink>
          </Empty>
        )}
      </WorkspaceLayout>
    </WorkspaceProvider>
  )
}

export function AppRouter() {
  const [locationKey, setLocationKey] = useState(currentLocation)
  const path = normalizePath(locationKey.split('?')[0])
  const resolved = resolveRoute(path)

  useEffect(() => {
    const onNavigation = () => {
      setLocationKey(currentLocation())
      requestAnimationFrame(() =>
        document.getElementById('content')?.focus({ preventScroll: true }),
      )
    }
    window.addEventListener('popstate', onNavigation)
    window.addEventListener(NAVIGATION_EVENT, onNavigation)
    return () => {
      window.removeEventListener('popstate', onNavigation)
      window.removeEventListener(NAVIGATION_EVENT, onNavigation)
    }
  }, [])

  useEffect(() => {
    document.title = `${resolved?.route.title ?? 'Page unavailable'} · CSA-iEM`
    const meta = document.querySelector('meta[name=robots]')
    meta?.setAttribute(
      'content',
      resolved?.route.level ||
        [
          '/login',
          '/signup',
          '/forgot-password',
          '/verify-email',
          '/auth/action',
        ].includes(path)
        ? 'noindex,nofollow'
        : 'index,follow',
    )
  }, [path, resolved?.route.title, resolved?.route.level])

  if (path === '/services') return <Redirect to="/features" />
  if (!resolved)
    return (
      <Layout key={locationKey} currentPath={path}>
        <div className="public-content">
          <Empty title="Page unavailable">
            Check the address or <AppLink to="/">return home</AppLink>.
          </Empty>
        </div>
      </Layout>
    )
  if (!resolved.route.level)
    return (
      <Layout key={locationKey} currentPath={path}>
        {publicPage(path)}
      </Layout>
    )
  return (
    <ProtectedPage level={resolved.route.level} path={path}>
      {workspacePage(resolved.route.path, resolved.id)}
    </ProtectedPage>
  )
}
