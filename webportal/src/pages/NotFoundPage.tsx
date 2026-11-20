import { AppLink } from '@/components/navigation/AppLink'

export function NotFoundPage() {
  return (
    <section className="mx-auto flex max-w-3xl flex-col items-center px-4 py-24 text-center">
      <p className="text-6xl font-extrabold text-neutral-950">404</p>
      <h1 className="mt-4 text-2xl font-bold">Page not found</h1>
      <p className="mt-2 text-neutral-600">
        The page you're looking for doesn't exist or has moved.
      </p>
      <AppLink
        to="/"
        className="mt-8 inline-flex items-center rounded-md bg-neutral-950 px-5 py-3 text-sm font-semibold text-white transition hover:bg-neutral-800"
      >
        Back to home
      </AppLink>
    </section>
  )
}
