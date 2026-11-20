import { AppLink } from "@/components/navigation/AppLink";
import { FolderGit2, ShieldCheck, Monitor, Cloud } from "lucide-react";
export function HomePage() {
  return (
    <section className="portal-wrap">
      <p className="eyebrow">CSA-iEM · Native + Cloud workspace</p>
      <h1>
        Every project.
        <br />A clear path home.
      </h1>
      <p className="max-w-2xl text-xl">
        Keep your projects, devices, and backup locations together. Work locally
        with verified preservation, then save the details that help you pick up
        where you left off.
      </p>
      <div className="dashboard-tabs mt-8">
        <AppLink
          to="/login"
          className="rounded-lg bg-slate-950 px-6 py-4 font-semibold !text-white"
        >
          Log in to your workspace →
        </AppLink>
        <AppLink to="/downloads">Get the Mac app</AppLink>
      </div>
      <div className="metric-grid mt-12">
        {[
          [
            FolderGit2,
            "Project checkpoints",
            "Save repository locations and recovery notes.",
          ],
          [
            Monitor,
            "Your devices",
            "Keep a private inventory of your workstations.",
          ],
          [
            ShieldCheck,
            "Backup save points",
            "Remember where verified copies live.",
          ],
        ].map(([Icon, title, body]) => {
          const I = Icon as typeof Cloud;
          return (
            <div className="portal-card" key={String(title)}>
              <I className="mb-5 h-8 w-8 text-sky-700" />
              <h2>{String(title)}</h2>
              <p>{String(body)}</p>
            </div>
          );
        })}
      </div>
      <div className="portal-card">
        <p className="eyebrow">Designed for continuity</p>
        <h2>Local files. Connected records.</h2>
        <p>
          The Mac app handles discovery, preservation, verification, and
          recovery. Your cloud dashboard saves project, device, and backup
          metadata under your account. File uploads and automatic native pairing
          are planned separately.
        </p>
        <AppLink to="/docs">Explore the workflow →</AppLink>
      </div>
    </section>
  );
}
