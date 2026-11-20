import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from 'react'
import {
  GoogleAuthProvider,
  applyActionCode,
  confirmPasswordReset,
  createUserWithEmailAndPassword,
  reload,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
  updatePassword,
  updateProfile,
  verifyPasswordResetCode,
  type User,
} from 'firebase/auth'
import { ArrowRight, Fingerprint } from 'lucide-react'
import { auth } from '@/config/firebase'
import { useSession } from '@/portal/useSession'
import { AppLink } from '@/components/navigation/AppLink'
import { navigate } from '@/lib/navigation'
import { resolveRoute } from '@/portal/routes'
import { confirmIdentity, errorMessage } from '@/portal/authActions'

function afterLogin() {
  const next = new URLSearchParams(location.search).get('next')
  return next && resolveRoute(next)?.route.level ? next : '/dashboard'
}

async function signInLocalOwner() {
  if (import.meta.env.DEV) {
    const response = await fetch('/__csa_local_owner', {
      credentials: 'same-origin',
      cache: 'no-store',
    })
    if (!response.ok)
      throw new Error(
        'The local owner fixture is unavailable. Check dev:status.',
      )
    const { email, password } = await response.json()
    await signInWithEmailAndPassword(auth, email, password)
    navigate('/dashboard', { replace: true })
  }
}

function AccountCard({
  title,
  description,
  children,
}: {
  title: string
  description: string
  children: ReactNode
}) {
  return (
    <div className="account-scene">
      <section className="account-card surface">
        <span className="account-emblem">
          <Fingerprint size={25} aria-hidden="true" />
        </span>
        <h1>{title}</h1>
        <p className="page-lede">{description}</p>
        {children}
      </section>
      <aside className="account-aside">
        <img
          src="/images/workstation.jpg"
          alt="Mac workstation and two external backup drives"
        />
        <p>Projects, devices, and recovery details in one private workspace.</p>
      </aside>
    </div>
  )
}

function Status({ message, error }: { message: string; error: boolean }) {
  if (!message) return null
  return (
    <p
      className={error ? 'notice error' : 'notice'}
      role={error ? 'alert' : 'status'}
    >
      {message}
    </p>
  )
}

export function LoginPage() {
  const { user, loading } = useSession()
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const autoSignIn = useRef(false)
  useEffect(() => {
    if (
      import.meta.env.DEV &&
      !autoSignIn.current &&
      new URLSearchParams(location.search).get('localOwner') === '1'
    ) {
      autoSignIn.current = true
      void signInLocalOwner().catch((error) => setMessage(errorMessage(error)))
    }
  }, [])

  async function signIn(action: () => Promise<unknown>) {
    setBusy(true)
    setMessage('')
    try {
      await action()
      navigate(afterLogin())
    } catch (error) {
      setMessage(errorMessage(error))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AccountCard
      title={user ? 'Welcome back' : 'Log in'}
      description={
        user
          ? `Signed in as ${user.email ?? user.displayName ?? 'member'}.`
          : 'Open your private CSA-iEM workspace.'
      }
    >
      {loading ? (
        <p role="status">Checking your session…</p>
      ) : user ? (
        <div className="actions">
          <AppLink
            className="button primary"
            to={user.emailVerified ? '/dashboard' : '/verify-email'}
          >
            Open workspace <ArrowRight size={16} />
          </AppLink>
          <button
            className="button secondary"
            onClick={() => void signOut(auth)}
          >
            Sign out
          </button>
        </div>
      ) : (
        <>
          <button
            className="button secondary wide"
            disabled={busy}
            onClick={() =>
              void signIn(() => signInWithPopup(auth, new GoogleAuthProvider()))
            }
          >
            Continue with Google
          </button>
          <div className="or-divider">or use email</div>
          <form
            className="field-stack"
            onSubmit={(event) => {
              event.preventDefault()
              const input = new FormData(event.currentTarget)
              void signIn(() =>
                signInWithEmailAndPassword(
                  auth,
                  String(input.get('email')),
                  String(input.get('password')),
                ),
              )
            }}
          >
            <label>
              Email
              <input required name="email" type="email" autoComplete="email" />
            </label>
            <label>
              Password
              <input
                required
                name="password"
                type="password"
                autoComplete="current-password"
              />
            </label>
            <button className="button primary wide" disabled={busy}>
              {busy ? 'Signing in…' : 'Log in'}
            </button>
          </form>
          <p className="account-links">
            <AppLink to="/forgot-password">Forgot password?</AppLink>
            <AppLink to="/signup">Create an account</AppLink>
          </p>
          {import.meta.env.DEV && (
            <button
              className="button secondary wide"
              onClick={() =>
                void signInLocalOwner().catch((error) =>
                  setMessage(errorMessage(error)),
                )
              }
            >
              Use local Level 5 owner
            </button>
          )}
        </>
      )}
      <Status message={message} error />
    </AccountCard>
  )
}

export function SignupPage() {
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const input = new FormData(event.currentTarget)
    setBusy(true)
    setMessage('')
    try {
      const result = await createUserWithEmailAndPassword(
        auth,
        String(input.get('email')),
        String(input.get('password')),
      )
      // Keep the signed-in account usable even if the initial email is delayed.
      await Promise.allSettled([
        updateProfile(result.user, {
          displayName: String(input.get('name')).trim(),
        }),
        sendEmailVerification(result.user),
      ])
      navigate('/verify-email')
    } catch (error) {
      setMessage(errorMessage(error))
    } finally {
      setBusy(false)
    }
  }
  return (
    <AccountCard
      title="Create a free account"
      description="Get a private workspace for projects, devices, and backup save points."
    >
      <form className="field-stack" onSubmit={submit}>
        <label>
          Name
          <input required name="name" autoComplete="name" maxLength={120} />
        </label>
        <label>
          Email
          <input required name="email" type="email" autoComplete="email" />
        </label>
        <label>
          Password
          <input
            required
            name="password"
            type="password"
            minLength={8}
            autoComplete="new-password"
            aria-describedby="signup-password-help"
          />
        </label>
        <small id="signup-password-help" className="muted">
          Use at least eight characters.
        </small>
        <button className="button primary wide" disabled={busy}>
          {busy ? 'Creating account…' : 'Create account'}
        </button>
      </form>
      <p className="account-links">
        <AppLink to="/login">Already have an account? Log in</AppLink>
      </p>
      <Status message={message} error />
    </AccountCard>
  )
}

export function ForgotPasswordPage() {
  const [note, setNote] = useState({ text: '', error: false })
  const [busy, setBusy] = useState(false)
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    try {
      await sendPasswordResetEmail(
        auth,
        String(new FormData(event.currentTarget).get('email')),
      )
      setNote({
        text: 'If an account exists for that address, check your inbox for a reset link.',
        error: false,
      })
    } catch (error) {
      if ((error as { code?: string }).code === 'auth/user-not-found') {
        setNote({
          text: 'If an account exists for that address, check your inbox for a reset link.',
          error: false,
        })
      } else setNote({ text: errorMessage(error), error: true })
    } finally {
      setBusy(false)
    }
  }
  return (
    <AccountCard
      title="Reset your password"
      description="Enter the email address for your CSA-iEM account."
    >
      <form className="field-stack" onSubmit={submit}>
        <label>
          Email
          <input required name="email" type="email" autoComplete="email" />
        </label>
        <button className="button primary" disabled={busy}>
          Send reset link
        </button>
      </form>
      <p className="account-links">
        <AppLink to="/login">Back to login</AppLink>
      </p>
      <Status message={note.text} error={note.error} />
    </AccountCard>
  )
}

export function VerifyEmailPage() {
  const { user, verified } = useSession()
  const [note, setNote] = useState({ text: '', error: false })
  const [busy, setBusy] = useState(false)
  async function check(send: boolean) {
    if (!user) return
    setBusy(true)
    try {
      if (send) {
        await sendEmailVerification(user)
        setNote({
          text: 'Verification email requested. Check your inbox.',
          error: false,
        })
      } else {
        await reload(user)
        await user.getIdToken(true)
        if (user.emailVerified) navigate('/dashboard')
        else
          setNote({
            text: 'Your email still needs verification. Open the link in your inbox, then try again.',
            error: false,
          })
      }
    } catch (error) {
      setNote({ text: errorMessage(error), error: true })
    } finally {
      setBusy(false)
    }
  }
  return (
    <AccountCard
      title={verified ? 'Your email is verified' : 'Verify your email'}
      description={
        verified
          ? 'Your private workspace is ready.'
          : `Confirm ${user?.email ?? 'your email address'} to save records or pair a Mac.`
      }
    >
      {verified ? (
        <AppLink className="button primary" to="/dashboard">
          Open dashboard
        </AppLink>
      ) : user ? (
        <div className="actions">
          <button
            className="button primary"
            disabled={busy}
            onClick={() => void check(false)}
          >
            I verified my email
          </button>
          <button
            className="button secondary"
            disabled={busy}
            onClick={() => void check(true)}
          >
            Resend email
          </button>
          <button
            className="button text"
            onClick={() => void signOut(auth).then(() => navigate('/login'))}
          >
            Sign out
          </button>
        </div>
      ) : (
        <AppLink className="button primary" to="/login">
          Log in
        </AppLink>
      )}
      <Status message={note.text} error={note.error} />
    </AccountCard>
  )
}

export function AuthActionPage() {
  const query = new URLSearchParams(location.search)
  const mode = query.get('mode')
  const code = query.get('oobCode') ?? ''
  const [note, setNote] = useState({ text: '', error: false })
  const [busy, setBusy] = useState(false)
  const [complete, setComplete] = useState(false)
  async function apply(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const values = new FormData(event.currentTarget)
    setBusy(true)
    setNote({ text: '', error: false })
    try {
      if (mode === 'resetPassword') {
        await verifyPasswordResetCode(auth, code)
        await confirmPasswordReset(auth, code, String(values.get('password')))
        if (auth.currentUser) await signOut(auth)
      } else {
        await applyActionCode(auth, code)
        if (auth.currentUser) {
          await reload(auth.currentUser)
          await auth.currentUser.getIdToken(true)
        }
      }
      setComplete(true)
    } catch (error) {
      setNote({ text: errorMessage(error), error: true })
    } finally {
      setBusy(false)
    }
  }
  const valid = code && (mode === 'resetPassword' || mode === 'verifyEmail')
  return (
    <AccountCard
      title={
        mode === 'resetPassword'
          ? 'Choose a new password'
          : 'Confirm your email'
      }
      description={
        complete
          ? 'Your account change is complete.'
          : valid
            ? 'Continue to apply the link from your email.'
            : 'Open the link from your verification or password reset email.'
      }
    >
      {valid && !complete ? (
        <form className="field-stack" onSubmit={apply}>
          {mode === 'resetPassword' && (
            <label>
              New password
              <input
                name="password"
                type="password"
                required
                minLength={8}
                autoComplete="new-password"
              />
            </label>
          )}
          <button className="button primary" disabled={busy}>
            {mode === 'resetPassword' ? 'Set password' : 'Verify email'}
          </button>
        </form>
      ) : (
        <AppLink className="button primary" to="/login">
          Continue to login
        </AppLink>
      )}
      <Status message={note.text} error={note.error} />
    </AccountCard>
  )
}

export function ProfileForm({ user }: { user: User }) {
  const [message, setMessage] = useState('')
  const [failed, setFailed] = useState(false)
  return (
    <form
      className="field-stack"
      onSubmit={async (event) => {
        event.preventDefault()
        setFailed(false)
        try {
          await updateProfile(user, {
            displayName: String(
              new FormData(event.currentTarget).get('name'),
            ).trim(),
          })
          await user.getIdToken(true)
          setMessage('Profile saved.')
        } catch (error) {
          setFailed(true)
          setMessage(errorMessage(error))
        }
      }}
    >
      <label>
        Name
        <input
          name="name"
          defaultValue={user.displayName ?? ''}
          maxLength={120}
          required
          autoComplete="name"
        />
      </label>
      <label>
        Email
        <input value={user.email ?? ''} readOnly />
      </label>
      <button className="button primary">Save profile</button>
      <Status message={message} error={failed} />
    </form>
  )
}

export function SecurityForm({ user }: { user: User }) {
  const hasPassword = user.providerData.some(
    (provider) => provider.providerId === 'password',
  )
  const [note, setNote] = useState({ text: '', error: false })
  const [busy, setBusy] = useState(false)
  return (
    <>
      <p className="notice">
        {hasPassword ? 'Email and password sign-in' : 'Google sign-in'} ·{' '}
        {user.emailVerified ? 'Email verified' : 'Verification required'}
      </p>
      {hasPassword && (
        <form
          className="field-stack"
          onSubmit={async (event) => {
            event.preventDefault()
            const form = event.currentTarget
            const values = new FormData(form)
            setBusy(true)
            try {
              await confirmIdentity(user, String(values.get('current')))
              await updatePassword(user, String(values.get('next')))
              form.reset()
              setNote({ text: 'Password updated.', error: false })
            } catch (error) {
              setNote({ text: errorMessage(error), error: true })
            } finally {
              setBusy(false)
            }
          }}
        >
          <label>
            Current password
            <input
              name="current"
              type="password"
              required
              autoComplete="current-password"
            />
          </label>
          <label>
            New password
            <input
              name="next"
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
            />
          </label>
          <button className="button primary" disabled={busy}>
            Update password
          </button>
        </form>
      )}
      {!hasPassword && (
        <p>
          Manage your password and sign-in verification in your Google Account.
        </p>
      )}
      <Status message={note.text} error={note.error} />
    </>
  )
}
