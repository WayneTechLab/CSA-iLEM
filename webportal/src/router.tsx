import { useEffect, useState } from 'react'
import { Layout } from '@/components/layout/Layout'
import { NAVIGATION_EVENT, normalizePath } from '@/lib/navigation'
import { HomePage } from '@/pages/HomePage'
import { AboutPage } from '@/pages/AboutPage'
import { ServicesPage } from '@/pages/ServicesPage'
import { DocsPage } from '@/pages/DocsPage'
import { ContactPage } from '@/pages/ContactPage'
import { LoginPage } from '@/pages/LoginPage'
import { NotFoundPage } from '@/pages/NotFoundPage'

function getPathname() {
  return normalizePath(window.location.pathname)
}

function renderPage(pathname: string) {
  switch (pathname) {
    case '/':
      return <HomePage />
    case '/about':
      return <AboutPage />
    case '/services':
      return <ServicesPage />
    case '/docs':
      return <DocsPage />
    case '/login':
      return <LoginPage />
    case '/contact':
      return <ContactPage />
    default:
      return <NotFoundPage />
  }
}

export function AppRouter() {
  const [pathname, setPathname] = useState(getPathname)

  useEffect(() => {
    const handleNavigation = () => setPathname(getPathname())

    window.addEventListener('popstate', handleNavigation)
    window.addEventListener(NAVIGATION_EVENT, handleNavigation)

    return () => {
      window.removeEventListener('popstate', handleNavigation)
      window.removeEventListener(NAVIGATION_EVENT, handleNavigation)
    }
  }, [])

  return (
    <Layout currentPath={pathname}>
      {renderPage(pathname)}
    </Layout>
  )
}
