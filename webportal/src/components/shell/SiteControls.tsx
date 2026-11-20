import { useCallback, useEffect, useRef, useState } from 'react'
import { ArrowDown, ArrowUp, CircleHelp, List, MessageCircle, Settings2, X } from 'lucide-react'
import { AppLink } from '@/components/navigation/AppLink'
import type { HelpDeskMode } from '@/config/siteControls'
import { useAccessibilityPreferences } from '@/hooks/useAccessibilityPreferences'

type PageSnapMenuProps = { pathname: string }
type SnapPoint = { id: string; label: string }

function slugify(value: string) {
  return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60)
}

export function PageSnapMenu({ pathname }: PageSnapMenuProps) {
  const [open, setOpen] = useState(false)
  const [points, setPoints] = useState<SnapPoint[]>([])
  const [activeId, setActiveId] = useState('')
  const menuRef = useRef<HTMLDivElement>(null)

  const scanSections = useCallback(() => {
    const content = document.getElementById('content')
    if (!content) return
    const used = new Set<string>()
    const next: SnapPoint[] = []
    content.querySelectorAll<HTMLElement>('section').forEach((section, index) => {
      const label = section.dataset.snapLabel?.trim() || section.querySelector('h1, h2, h3')?.textContent?.trim()
      if (!label) return
      const base = section.id || slugify(label) || `section-${index + 1}`
      let id = base
      let count = 2
      while (used.has(id)) id = `${base}-${count++}`
      used.add(id)
      if (!section.id) section.id = id
      section.style.scrollMarginTop = '6rem'
      next.push({ id, label: label.length > 52 ? `${label.slice(0, 52)}…` : label })
    })
    setPoints(next)
    const requested = window.location.hash.slice(1)
    if (requested && next.some((point) => point.id === requested)) {
      window.setTimeout(() => document.getElementById(requested)?.scrollIntoView({ block: 'start' }), 0)
    }
  }, [])

  useEffect(() => {
    const frame = window.requestAnimationFrame(scanSections)
    const timer = window.setTimeout(scanSections, 300)
    return () => { window.cancelAnimationFrame(frame); window.clearTimeout(timer) }
  }, [pathname, scanSections])

  useEffect(() => {
    if (points.length === 0) return
    const observer = new IntersectionObserver((entries) => {
      const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)
      if (visible[0]) setActiveId(visible[0].target.id)
    }, { rootMargin: '-16% 0px -72% 0px', threshold: 0 })
    points.forEach((point) => document.getElementById(point.id) && observer.observe(document.getElementById(point.id)!))
    return () => observer.disconnect()
  }, [points])

  useEffect(() => {
    if (!open) return
    const onPointer = (event: MouseEvent) => { if (menuRef.current && !menuRef.current.contains(event.target as Node)) setOpen(false) }
    const onEscape = (event: KeyboardEvent) => { if (event.key === 'Escape') setOpen(false) }
    document.addEventListener('mousedown', onPointer)
    document.addEventListener('keydown', onEscape)
    return () => { document.removeEventListener('mousedown', onPointer); document.removeEventListener('keydown', onEscape) }
  }, [open])

  if (points.length < 2) return null
  return (
    <div
      ref={menuRef}
      className="fixed left-3 top-20 z-40 sm:left-4"
      {...(import.meta.env.DEV
        ? {
            'data-systemx-component': 'Page Snap Menu',
            'data-systemx-source': 'src/components/shell/SiteControls.tsx',
            'data-systemx-reusable': 'shell',
          }
        : {})}
    >
      <button type="button" aria-controls="wtl-page-snap-panel" aria-expanded={open} aria-label={open ? 'Close page sections menu' : 'Open page sections menu'} onClick={() => setOpen((current) => !current)} className="inline-flex min-h-11 min-w-11 items-center justify-center gap-0 overflow-hidden rounded-full border border-neutral-300 bg-white px-3 text-sm font-semibold text-neutral-900 shadow-lg hover:bg-neutral-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-950">
        {open ? <X className="h-5 w-5" aria-hidden="true" /> : <List className="h-5 w-5" aria-hidden="true" />}
        <span className={`max-w-0 overflow-hidden whitespace-nowrap opacity-0 transition-all duration-200 ${open ? 'ml-2 max-w-24 opacity-100' : ''}`}>On this page</span>
      </button>
      {open && <nav id="wtl-page-snap-panel" aria-label="On this page" className="mt-2 w-72 max-w-[calc(100vw-1.5rem)] rounded-2xl border border-neutral-200 bg-white p-2 shadow-xl">
        <p className="px-3 pb-2 pt-1 text-xs font-semibold uppercase tracking-wide text-neutral-500">Jump to section</p>
        <ul className="max-h-[60vh] space-y-1 overflow-y-auto">{points.map((point) => <li key={point.id}><button type="button" onClick={() => { const section = document.getElementById(point.id); if (!section) return; section.scrollIntoView({ behavior: document.documentElement.dataset.wtlMotion === 'reduced' ? 'auto' : 'smooth', block: 'start' }); window.history.replaceState(null, '', `${pathname}#${point.id}`); setActiveId(point.id); setOpen(false) }} className={`w-full rounded-lg px-3 py-2 text-left text-sm transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-950 ${activeId === point.id ? 'bg-neutral-950 font-semibold text-white' : 'text-neutral-700 hover:bg-neutral-100'}`}>{point.label}</button></li>)}</ul>
      </nav>}
    </div>
  )
}

const helpAnswers = [
  ['What is this template?', 'A Firebase-ready React, TypeScript, and Vite starting point with SYSTEMX setup guidance.'],
  ['Where do I start?', 'Open the docs page, then follow the SYSTEMX guided setup process before connecting production services.'],
  ['Can I get project help?', 'Use the contact route for a human handoff. Generated projects can connect approved support workflows later.'],
] as const

export function HelpDeskChat({ mode }: { mode: HelpDeskMode }) {
  const [open, setOpen] = useState(false)
  const [answer, setAnswer] = useState<(typeof helpAnswers)[number]>(helpAnswers[0])
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onPointer = (event: MouseEvent) => { if (panelRef.current && !panelRef.current.contains(event.target as Node)) setOpen(false) }
    const onEscape = (event: KeyboardEvent) => { if (event.key === 'Escape') setOpen(false) }
    document.addEventListener('mousedown', onPointer); document.addEventListener('keydown', onEscape)
    return () => { document.removeEventListener('mousedown', onPointer); document.removeEventListener('keydown', onEscape) }
  }, [open])

  if (mode === 'off') return null
  return <div
    ref={panelRef}
    className="group fixed bottom-3 left-3 z-40 sm:bottom-4 sm:left-4"
    {...(import.meta.env.DEV
      ? {
          'data-systemx-component': 'Help Desk',
          'data-systemx-source': 'src/components/shell/SiteControls.tsx',
          'data-systemx-reusable': 'shell',
        }
      : {})}
  >
    {open && <section id="wtl-help-desk-panel" aria-label="Self-service help desk" className="mb-2 w-[min(25rem,calc(100vw-1.5rem))] rounded-2xl border border-neutral-200 bg-white p-4 shadow-xl">
      <div className="flex items-start justify-between gap-4"><div className="flex items-start gap-3"><span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-neutral-950 text-white"><MessageCircle className="h-5 w-5" aria-hidden="true" /></span><div><h2 className="font-bold text-neutral-950">Help desk</h2><p className="mt-0.5 text-sm text-neutral-600">Self-service help for this site.</p></div></div><button type="button" onClick={() => setOpen(false)} aria-label="Close help desk" className="grid min-h-10 min-w-10 place-items-center rounded-full text-neutral-700 hover:bg-neutral-100"><X className="h-5 w-5" aria-hidden="true" /></button></div>
      <div className="mt-4 rounded-xl bg-neutral-50 p-3"><p className="text-sm font-semibold text-neutral-900">{answer[0]}</p><p className="mt-1 text-sm leading-6 text-neutral-700">{answer[1]}</p></div>
      <div className="mt-3 grid gap-2">{helpAnswers.map((item) => <button key={item[0]} type="button" onClick={() => setAnswer(item)} className="min-h-11 rounded-lg border border-neutral-200 px-3 text-left text-sm font-medium text-neutral-800 hover:bg-neutral-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-950">{item[0]}</button>)}</div>
      <AppLink to="/contact" onClick={() => setOpen(false)} className="mt-4 inline-flex min-h-10 items-center rounded-md bg-neutral-950 px-3 text-sm font-semibold text-white hover:bg-neutral-800">Contact support</AppLink>
      <p className="mt-3 text-xs text-neutral-500">Approved help content only. No private CMS data or provider keys are exposed.</p>
    </section>}
    <button type="button" aria-controls="wtl-help-desk-panel" aria-expanded={open} aria-label={open ? 'Close help desk' : 'Open help desk'} onClick={() => setOpen((current) => !current)} className="inline-flex min-h-11 items-center justify-center gap-0 overflow-hidden rounded-full bg-neutral-950 px-3 text-sm font-semibold text-white shadow-lg hover:bg-neutral-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-950 group-hover:gap-2 group-focus-within:gap-2"><CircleHelp className="h-5 w-5" aria-hidden="true" /><span className={`max-w-0 overflow-hidden whitespace-nowrap opacity-0 transition-all duration-200 group-hover:max-w-12 group-hover:opacity-100 group-focus-within:max-w-12 group-focus-within:opacity-100 ${open ? 'max-w-12 opacity-100' : ''}`}>Help</span></button>
  </div>
}

function Choice({ active, children, onClick }: { active: boolean; children: string; onClick: () => void }) {
  return <button type="button" aria-pressed={active} onClick={onClick} className={`min-h-10 rounded-md border px-3 text-sm font-medium ${active ? 'border-neutral-950 bg-neutral-950 text-white' : 'border-neutral-300 bg-white text-neutral-800 hover:bg-neutral-100'}`}>{children}</button>
}

export function AccessibilityPageControl({ showPageTravel }: { showPageTravel: boolean }) {
  const [open, setOpen] = useState(false)
  const panelRef = useRef<HTMLDivElement>(null)
  const { preferences, resetPreferences, updatePreference } = useAccessibilityPreferences()
  useEffect(() => {
    const frame = window.requestAnimationFrame(() => setOpen(false))
    return () => window.cancelAnimationFrame(frame)
  }, [])
  useEffect(() => {
    if (!open) return
    const onPointer = (event: MouseEvent) => { if (panelRef.current && !panelRef.current.contains(event.target as Node)) setOpen(false) }
    const onEscape = (event: KeyboardEvent) => { if (event.key === 'Escape') setOpen(false) }
    document.addEventListener('mousedown', onPointer); document.addEventListener('keydown', onEscape)
    return () => { document.removeEventListener('mousedown', onPointer); document.removeEventListener('keydown', onEscape) }
  }, [open])
  const scroll = (position: 'top' | 'bottom') => window.scrollTo({ top: position === 'top' ? 0 : document.documentElement.scrollHeight, behavior: document.documentElement.dataset.wtlMotion === 'reduced' ? 'auto' : 'smooth' })
  return <div
    ref={panelRef}
    className="fixed bottom-3 right-3 z-40 flex flex-col items-end gap-2 sm:bottom-4 sm:right-4"
    {...(import.meta.env.DEV
      ? {
          'data-systemx-component': 'Accessibility Controls',
          'data-systemx-source': 'src/components/shell/SiteControls.tsx',
          'data-systemx-reusable': 'shell',
        }
      : {})}
  >
    {open && <section id="wtl-accessibility-panel" aria-label="Accessibility and page controls" className="w-[min(23rem,calc(100vw-1.5rem))] rounded-2xl border border-neutral-200 bg-white p-4 shadow-xl"><div className="flex items-start justify-between gap-4"><div><h2 className="text-base font-bold text-neutral-950">Accessibility</h2><p className="mt-1 text-sm leading-5 text-neutral-600">Save reading preferences on this device.</p></div><button type="button" onClick={() => setOpen(false)} aria-label="Close accessibility controls" className="grid min-h-10 min-w-10 place-items-center rounded-full text-neutral-700 hover:bg-neutral-100"><X className="h-5 w-5" aria-hidden="true" /></button></div><div className="mt-4 space-y-4"><fieldset><legend className="text-sm font-semibold">Text size</legend><div className="mt-2 flex flex-wrap gap-2"><Choice active={preferences.textScale === 'default'} onClick={() => updatePreference('textScale', 'default')}>Default</Choice><Choice active={preferences.textScale === 'large'} onClick={() => updatePreference('textScale', 'large')}>Large</Choice><Choice active={preferences.textScale === 'x-large'} onClick={() => updatePreference('textScale', 'x-large')}>Extra large</Choice></div></fieldset><fieldset><legend className="text-sm font-semibold">Reading spacing</legend><div className="mt-2 flex flex-wrap gap-2"><Choice active={preferences.lineSpacing === 'default'} onClick={() => { updatePreference('lineSpacing', 'default'); updatePreference('letterSpacing', 'default') }}>Default</Choice><Choice active={preferences.lineSpacing === 'relaxed'} onClick={() => { updatePreference('lineSpacing', 'relaxed'); updatePreference('letterSpacing', 'relaxed') }}>Relaxed</Choice></div></fieldset><fieldset><legend className="text-sm font-semibold">Contrast and motion</legend><div className="mt-2 flex flex-wrap gap-2"><Choice active={preferences.contrast === 'high'} onClick={() => updatePreference('contrast', preferences.contrast === 'high' ? 'default' : 'high')}>High contrast</Choice><Choice active={preferences.motion === 'reduced'} onClick={() => updatePreference('motion', preferences.motion === 'reduced' ? 'system' : 'reduced')}>Reduce motion</Choice></div></fieldset></div><button type="button" onClick={resetPreferences} className="mt-4 min-h-10 rounded-md border border-neutral-300 px-3 text-sm font-semibold text-neutral-800 hover:bg-neutral-100">Reset preferences</button></section>}
    <div className="flex items-center gap-2">{showPageTravel && <div className={`flex min-w-0 items-center gap-2 overflow-hidden transition-all duration-200 ${open ? 'w-24 opacity-100' : 'pointer-events-none w-0 opacity-0'}`}><button type="button" onClick={() => scroll('top')} aria-label="Scroll to top of page" className="grid min-h-11 min-w-11 place-items-center rounded-full border border-neutral-300 bg-white text-neutral-900 shadow-lg hover:bg-neutral-100"><ArrowUp className="h-5 w-5" aria-hidden="true" /></button><button type="button" onClick={() => scroll('bottom')} aria-label="Scroll to bottom of page" className="grid min-h-11 min-w-11 place-items-center rounded-full border border-neutral-300 bg-white text-neutral-900 shadow-lg hover:bg-neutral-100"><ArrowDown className="h-5 w-5" aria-hidden="true" /></button></div>}<button type="button" aria-controls="wtl-accessibility-panel" aria-expanded={open} aria-label={open ? 'Close accessibility controls' : 'Open accessibility controls'} onClick={() => setOpen((current) => !current)} className="grid min-h-11 min-w-11 place-items-center rounded-full bg-neutral-950 text-white shadow-lg hover:bg-neutral-800"><Settings2 className="h-5 w-5" aria-hidden="true" /></button></div>
  </div>
}
