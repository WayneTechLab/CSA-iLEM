import { AppLink } from '@/components/navigation/AppLink'

export function Footer() {
  const year = new Date().getFullYear()
  return (
    <footer
      className="border-t border-neutral-200 bg-neutral-50"
      {...(import.meta.env.DEV
        ? {
            'data-systemx-component': 'Site Footer',
            'data-systemx-source': 'src/components/layout/Footer.tsx',
            'data-systemx-reusable': 'global',
          }
        : {})}
    >
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-4 py-8 text-sm text-neutral-500 sm:flex-row">
        <p>&copy; {year} CSA-iEM. Template provided by Wayne Tech Lab LLC.</p>
        <div className="flex gap-4">
          <AppLink to="/about" className="hover:text-neutral-950">
            About
          </AppLink>
          <AppLink to="/services" className="hover:text-neutral-950">
            Services
          </AppLink>
          <AppLink to="/docs" className="hover:text-neutral-950">
            Docs
          </AppLink>
          <AppLink to="/contact" className="hover:text-neutral-950">
            Contact
          </AppLink>
        </div>
      </div>
    </footer>
  )
}
