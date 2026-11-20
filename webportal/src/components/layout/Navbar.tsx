import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { Menu, X } from 'lucide-react'
import { AppLink } from '@/components/navigation/AppLink'
import { isActivePath } from '@/lib/navigation'
import { siteControls } from '@/config/siteControls'

const links = [
  { to: '/', label: 'Home', end: true },
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/downloads', label: 'Downloads' },
  { to: '/about', label: 'About' },
  { to: '/services', label: 'Services' },
  { to: '/docs', label: 'Docs' },
  { to: '/login', label: 'Login' },
  { to: '/contact', label: 'Contact' },
]

type NavbarProps = {
  currentPath: string
}

export function Navbar({ currentPath }: NavbarProps) {
  const [openPath, setOpenPath] = useState<string | null>(null)
  const open = openPath === currentPath
  const drawerRef = useRef<HTMLElement>(null)
  const triggerRef = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (!open) return
    drawerRef.current?.querySelector<HTMLAnchorElement>('a')?.focus()
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return
      setOpenPath(null)
      triggerRef.current?.focus()
    }
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.body.style.overflow = previousOverflow
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [open])

  const linkClass = (isActive: boolean) =>
    `rounded-md px-3 py-2 text-sm font-medium transition-colors ${
      isActive
        ? 'bg-neutral-950 text-white'
        : 'text-neutral-600 hover:bg-neutral-100 hover:text-neutral-950'
    }`

  const navigationOverlay = open && typeof document !== 'undefined'
    ? createPortal(<div className="fixed inset-0 z-[70] isolate" role="presentation">
        <button type="button" aria-label="Dismiss site navigation overlay" className="absolute inset-0 cursor-pointer bg-neutral-950/45 backdrop-blur-sm" onClick={() => setOpenPath(null)} />
        <aside ref={drawerRef} id="wtl-site-navigation" role="dialog" aria-modal="true" aria-label="Site navigation" className="fixed right-0 top-0 z-[71] flex h-dvh w-full max-w-sm flex-col overflow-y-auto border-l border-neutral-200 bg-white px-5 pb-6 pt-20 shadow-2xl">
          <p className="text-xs font-semibold uppercase tracking-wide text-neutral-500">Site navigation</p>
          <nav aria-label="Primary navigation" className="mt-4 flex flex-col gap-1">{links.map((link) => <AppLink key={link.to} to={link.to} aria-current={isActivePath(currentPath, link.to, link.end) ? 'page' : undefined} className={linkClass(isActivePath(currentPath, link.to, link.end))} onClick={() => setOpenPath(null)}>{link.label}</AppLink>)}</nav>
          <p className="mt-auto border-t border-neutral-200 pt-4 text-xs leading-5 text-neutral-500">CSA-iEM · .SYSTEMX Forever WebApp<br />Provided by Wayne Tech Lab LLC.</p>
        </aside>
      </div>, document.body)
    : null

  return (
    <>
      <header
        className="sticky top-0 z-30 border-b border-neutral-200 bg-white/95 backdrop-blur"
        {...(import.meta.env.DEV
          ? {
              'data-systemx-component': 'Site Header',
              'data-systemx-source': 'src/components/layout/Navbar.tsx',
              'data-systemx-reusable': 'global',
            }
          : {})}
      >
        <nav aria-label="Brand" className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 pr-18 sm:pr-20">
          <AppLink to="/" className="flex items-center gap-2 font-bold">
            <span className="grid h-8 w-8 place-items-center rounded border border-neutral-950 bg-neutral-950 text-xs font-semibold text-white">
              C
            </span>
            <span className="truncate">CSA-iEM</span>
          </AppLink>
        </nav>
      </header>

      {siteControls.siteNavigation && <button ref={triggerRef} type="button" className="fixed right-3 top-3 z-[72] inline-flex min-h-11 min-w-11 items-center justify-center rounded-full bg-neutral-950 text-white shadow-lg transition hover:bg-neutral-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-950 sm:right-4 sm:top-4" aria-controls="wtl-site-navigation" aria-expanded={open} aria-label={open ? 'Close site navigation' : 'Open site navigation'} onClick={() => setOpenPath(open ? null : currentPath)}>
        {open ? <X className="h-5 w-5" aria-hidden="true" /> : <Menu className="h-5 w-5" aria-hidden="true" />}
      </button>}

      {navigationOverlay}
    </>
  )
}
