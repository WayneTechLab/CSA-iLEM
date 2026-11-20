import { useState, type FormEvent } from "react";
import {
  GoogleAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  sendEmailVerification,
  sendPasswordResetEmail,
  signOut,
} from "firebase/auth";
import { auth } from "@/config/firebase";
import { useSession } from "@/portal/useSession";
import { navigate } from "@/lib/navigation";
export function LoginPage() {
  const { user } = useSession();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [create, setCreate] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  async function run(action: () => Promise<unknown>) {
    setBusy(true);
    setMessage("");
    try {
      await action();
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Sign-in failed");
    } finally {
      setBusy(false);
    }
  }
  async function submit(e: FormEvent) {
    e.preventDefault();
    await run(async () => {
      if (create) {
        const c = await createUserWithEmailAndPassword(auth, email, password);
        await sendEmailVerification(c.user);
        setMessage(
          "Verification email sent. Verify your email to enable cloud saves.",
        );
      } else await signInWithEmailAndPassword(auth, email, password);
      navigate("/dashboard");
    });
  }
  return (
    <section className="portal-wrap">
      <div className="portal-card login-card">
        <p className="eyebrow">Your workspace, connected</p>
        <h1>{user ? "You are signed in" : "Welcome to CSA-iEM"}</h1>
        <p>
          Save project checkpoints and keep track of where your backups live.
        </p>
        {user ? (
          <>
            <p>{user.email}</p>
            <button onClick={() => navigate("/dashboard")}>
              Open dashboard
            </button>
            <button
              className="secondary"
              onClick={() => run(() => signOut(auth))}
            >
              Sign out
            </button>
          </>
        ) : (
          <>
            <button
              disabled={busy}
              onClick={() =>
                run(async () => {
                  await signInWithPopup(auth, new GoogleAuthProvider());
                  navigate("/dashboard");
                })
              }
            >
              Continue with Google
            </button>
            <form onSubmit={submit}>
              <label>
                Email
                <input
                  type="email"
                  autoComplete="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </label>
              <label>
                Password
                <input
                  type="password"
                  minLength={8}
                  autoComplete={create ? "new-password" : "current-password"}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </label>
              <button disabled={busy}>
                {busy
                  ? "Please wait…"
                  : create
                    ? "Create free account"
                    : "Log in"}
              </button>
            </form>
            <button className="text-button" onClick={() => setCreate(!create)}>
              {create
                ? "Already have an account? Log in"
                : "Create a free member account"}
            </button>
            <button
              className="text-button"
              disabled={!email || busy}
              onClick={() =>
                run(async () => {
                  await sendPasswordResetEmail(auth, email);
                  setMessage("Password reset requested. Check your email.");
                })
              }
            >
              Reset password
            </button>
          </>
        )}
        <p role="status">{message}</p>
      </div>
    </section>
  );
}
