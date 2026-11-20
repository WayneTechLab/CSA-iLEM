import type { ReactNode } from 'react'
import { Navbar } from './Navbar'
import { Footer } from './Footer'
import { AccessibilityPageControl, HelpDeskChat, PageSnapMenu } from '@/components/shell/SiteControls'
import { siteControls } from '@/config/siteControls'

type LayoutProps = {
  children: ReactNode
  currentPath: string
}

export function Layout({ children, currentPath }: LayoutProps) {
  return (
    <div
      className="flex min-h-full flex-col bg-white text-neutral-950"
      {...(import.meta.env.DEV ? { 'data-systemx-name': 'App Layout' } : {})}
    >
      <Navbar key={`navbar:${currentPath}`} currentPath={currentPath} />
      <main
        id="content"
        tabIndex={-1}
        className="flex-1 focus:outline-none"
        {...(import.meta.env.DEV ? { 'data-systemx-region': 'page-content' } : {})}
      >
        {children}
      </main>
      <Footer />
      {siteControls.pageSnap && <PageSnapMenu key={`page-snap:${currentPath}`} pathname={currentPath} />}
      {siteControls.helpDesk !== 'off' && <HelpDeskChat mode={siteControls.helpDesk} />}
      {siteControls.accessibility && <AccessibilityPageControl showPageTravel={siteControls.showPageTravel} />}
    </div>
  )
}
