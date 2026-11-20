export const NAVIGATION_EVENT = 'sfwa-wtl:navigation'

export function normalizePath(pathname: string) {
  if (!pathname || pathname === '/') return '/'
  return pathname.replace(/\/+$/, '') || '/'
}

export function isActivePath(
  currentPath: string,
  targetPath: string,
  end = false,
) {
  const current = normalizePath(currentPath)
  const target = normalizePath(targetPath)

  if (target === '/') return current === '/'
  return end
    ? current === target
    : current === target || current.startsWith(`${target}/`)
}

export function navigate(
  to: string,
  { replace = false }: { replace?: boolean } = {},
) {
  const target = to.startsWith('/') ? to : `/${to}`
  if (replace) window.history.replaceState({}, '', target)
  else window.history.pushState({}, '', target)
  window.dispatchEvent(new Event(NAVIGATION_EVENT))
  window.scrollTo({ top: 0, behavior: 'instant' })
}
