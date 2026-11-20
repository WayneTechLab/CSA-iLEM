import { useEffect, useState, type FormEvent } from "react";
import {
  collection,
  doc,
  onSnapshot,
  query,
  limit,
  setDoc,
  deleteDoc,
  serverTimestamp,
} from "firebase/firestore";
import { signOut, sendEmailVerification } from "firebase/auth";
import { auth, db } from "@/config/firebase";
import { useSession } from "@/portal/useSession";
import { ACCOUNT_LEVELS } from "@/auth/accountLevels";
import { AppLink } from "@/components/navigation/AppLink";
type RecordEntry = {
  id: string;
  name: string;
  location: string;
  notes: string;
  kind: string;
};
export function DashboardPage() {
  const { user } = useSession();
  return <DashboardContent key={user?.uid || "guest"} />;
}
function DashboardContent() {
  const { user, level, loading } = useSession();
  const [tab, setTab] = useState("projects");
  const [rows, setRows] = useState<RecordEntry[]>([]);
  const [name, setName] = useState("");
  const [location, setLocation] = useState("");
  const [notes, setNotes] = useState("");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!user?.emailVerified) return;
    return onSnapshot(
      query(collection(db, "users", user.uid, tab), limit(100)),
      (snap) => {
        setRows(
          snap.docs.map((d) => ({ id: d.id, ...d.data() }) as RecordEntry),
        );
        setStatus("Cloud records up to date");
      },
      (e) => setStatus(e.message),
    );
  }, [user, tab]);
  async function save(e: FormEvent) {
    e.preventDefault();
    if (!user?.emailVerified) return;
    setBusy(true);
    try {
      await setDoc(doc(collection(db, "users", user.uid, tab)), {
        name,
        location,
        notes,
        kind: tab,
        updatedAt: serverTimestamp(),
      });
      setName("");
      setLocation("");
      setNotes("");
      setStatus("Saved to your private cloud workspace");
    } catch (e) {
      setStatus(e instanceof Error ? e.message : "Save failed");
    } finally {
      setBusy(false);
    }
  }
  if (loading)
    return <section className="portal-wrap">Loading account…</section>;
  if (!user)
    return (
      <section className="portal-wrap">
        <h1>Your workspace dashboard</h1>
        <p>Log in to see your private projects and devices.</p>
        <AppLink to="/login">Log in →</AppLink>
      </section>
    );
  return (
    <section className="portal-wrap">
      <header className="dashboard-heading">
        <div>
          <p className="eyebrow">Workspace control center</p>
          <h1>Welcome, {user.displayName || user.email?.split("@")[0]}</h1>
          <p>
            {user.email} · Level {level} · {ACCOUNT_LEVELS[level]?.label}
          </p>
        </div>
        <button className="secondary" onClick={() => signOut(auth)}>
          Sign out
        </button>
      </header>
      <div className="metric-grid">
        <div className="portal-card">
          <strong>{rows.length}</strong>
          <p>{tab} in cloud</p>
        </div>
        <div className="portal-card">
          <strong>Private</strong>
          <p>Account-scoped records</p>
        </div>
        <div className="portal-card">
          <strong>Metadata sync</strong>
          <p>Files stay on your drives</p>
        </div>
      </div>
      {!user.emailVerified && (
        <div className="portal-card">
          <p>
            Verify your email before saving cloud records. Reload this page
            after verification.
          </p>
          <button
            onClick={() =>
              sendEmailVerification(user)
                .then(() => setStatus("Verification email sent"))
                .catch((e) => setStatus(e.message))
            }
          >
            Send verification email
          </button>
        </div>
      )}
      <div className="dashboard-tabs">
        {["projects", "devices", "backups"].map((t) => (
          <button
            className={tab === t ? "" : "secondary"}
            key={t}
            onClick={() => {
              setRows([]);
              setTab(t);
            }}
          >
            {t}
          </button>
        ))}
        <AppLink to="/downloads">Downloads →</AppLink>
      </div>
      <div className="workspace-grid">
        <div className="portal-card">
          <h2>Saved {tab}</h2>
          <p role="status">{status}</p>
          {rows.length === 0 && (
            <p>No {tab} saved yet. Add a checkpoint to start.</p>
          )}
          {rows.map((r) => (
            <article className="record" key={r.id}>
              <h3>{r.name}</h3>
              <p>{r.location}</p>
              <p>{r.notes}</p>
              <button
                className="text-button"
                onClick={async () => {
                  if (
                    !confirm(
                      "Remove this cloud record? Local files are unaffected.",
                    )
                  )
                    return;
                  try {
                    await deleteDoc(doc(db, "users", user.uid, tab, r.id));
                  } catch (e) {
                    setStatus(e instanceof Error ? e.message : "Delete failed");
                  }
                }}
              >
                Remove record
              </button>
            </article>
          ))}
        </div>
        <form className="portal-card" onSubmit={save}>
          <h2>
            Add{" "}
            {tab === "devices"
              ? "device"
              : tab === "backups"
                ? "backup save point"
                : "project"}
          </h2>
          <label>
            Name
            <input
              required
              maxLength={120}
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </label>
          <label>
            {tab === "devices" ? "Device details" : "Location / backup path"}
            <input
              maxLength={1000}
              value={location}
              onChange={(e) => setLocation(e.target.value)}
              placeholder={
                tab === "backups"
                  ? "/Volumes/Drive/Backups/Project"
                  : "Repository URL or local path"
              }
            />
          </label>
          <label>
            Notes
            <textarea
              maxLength={4000}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </label>
          <button disabled={busy || !user.emailVerified}>
            {busy ? "Saving…" : "Save to cloud"}
          </button>
          <p>
            Save paths and recovery notes. Do not include passwords, tokens, or
            private keys.
          </p>
        </form>
      </div>
      {level >= 4 && (
        <div className="portal-card">
          <h2>{level === 5 ? "Owner" : "Employee"} workspace</h2>
          <p>
            Your private role is assigned by the backend. Paid plan upgrades and
            staff provisioning are managed separately.
          </p>
        </div>
      )}
      <div className="portal-card">
        <h2>Pair with the native app</h2>
        <p>
          Use the same project names and save verified backup paths from the
          native app here. Automatic device pairing and native background sync
          are not connected yet.
        </p>
      </div>
    </section>
  );
}
