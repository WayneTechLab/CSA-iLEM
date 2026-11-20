import {
  ArrowDownToLine,
  ArrowRight,
  BookOpen,
  Check,
  ChevronRight,
  ExternalLink,
  FolderGit2,
  HardDrive,
  Laptop2,
  Layers3,
  ShieldCheck,
} from 'lucide-react'
import { AppLink } from '@/components/navigation/AppLink'
import { useSession } from '@/portal/useSession'
import { ACCOUNT_LEVELS } from '@/auth/accountLevels'

const repository = 'https://github.com/WayneTechLab/CSA-iLEM'
const guidance = [
  {
    href: '/docs/projects',
    name: 'Track projects',
    description:
      'Record the location of each workspace and give your future self the context to reopen it.',
    icon: FolderGit2,
  },
  {
    href: '/docs/devices',
    name: 'Connect your Macs',
    description:
      'See which device holds the workspace and when it last sent an update.',
    icon: Laptop2,
  },
  {
    href: '/docs/backups',
    name: 'Find your backups',
    description:
      'Keep recovery notes and the location of the last copy your Mac verified.',
    icon: HardDrive,
  },
] as const

const docs = [
  [
    '/docs/getting-started',
    'Getting started',
    'Go from a new account to your first project and backup save point.',
  ],
  [
    '/docs/install',
    'Install CSA-iEM',
    'Find the app source, installation checks, and public release options.',
  ],
  [
    '/docs/projects',
    'Projects',
    'Organize a stable inventory across workspace folders and devices.',
  ],
  [
    '/docs/devices',
    'Pair your Mac',
    'Review sharing, create a pairing code, and check that sync worked.',
  ],
  [
    '/docs/backups',
    'Backup and recovery',
    'Find, interpret, and safely use a recorded backup.',
  ],
  [
    '/docs/file-safety',
    'File safety',
    'Use previews and verification before removing a local copy.',
  ],
] as const

const articles: Record<
  string,
  {
    title: string
    summary: string
    sections: [string, string][]
    action: [string, string]
  }
> = {
  '/docs/getting-started': {
    title: 'Getting started',
    summary:
      'Set up the portal in three steps and use it to find your first project later.',
    sections: [
      [
        'Set up your account',
        'Create a free member account with email and password or sign in with Google. Confirm your email before adding any records.',
      ],
      [
        'Record a project',
        'Open Projects, add a recognizable name and the repository or folder location, and include just enough detail to reopen it later.',
      ],
      [
        'Create a save point',
        'Use the native app to create and verify a backup. Pair the Mac to send its receipt to the portal, or add the recovery location by hand in Backups.',
      ],
    ],
    action: ['/signup', 'Create an account'],
  },
  '/docs/install': {
    title: 'Install CSA-iEM',
    summary:
      'Choose a published build or use the repository’s reviewed source installation path.',
    sections: [
      [
        'Check releases',
        'The Releases page lists published source versions. The Downloads page distinguishes those from signed installer availability.',
      ],
      [
        'Review the source',
        'Open the repository README and follow its macOS prerequisites, checksum verification, and installer instructions.',
      ],
      [
        'Choose workspace roots',
        'In the native app, confirm your Code, Import, and Runtime locations in Workspace before scanning or moving files.',
      ],
    ],
    action: ['/downloads', 'Open downloads'],
  },
  '/docs/projects': {
    title: 'Track projects',
    summary:
      'Use a project record as a pointer to the work you keep on your own device.',
    sections: [
      [
        'Create or edit a record',
        'Add a stable project name and a safe repository URL, volume label, or path. Use Notes for setup and recovery context without credentials.',
      ],
      [
        'Link save points',
        'Set the project on a manual backup entry. Synced backups present the project and device reported by the Mac.',
      ],
      [
        'Review cloud origin',
        'An entry marked From Mac is maintained by its paired device. Change its sharing selection in native Settings. Entries marked Manual can be edited from the portal.',
      ],
    ],
    action: ['/projects', 'Open projects'],
  },
  '/docs/devices': {
    title: 'Pair your Mac',
    summary:
      'Link a device once, then keep selected project metadata and backup receipts up to date.',
    sections: [
      [
        'Create a fresh code',
        'In Devices, select Pair a Mac. Decide whether this device may include exact paths, then copy the code. It expires in ten minutes.',
      ],
      [
        'Review and connect',
        'Open Cloud workspace sync in the Mac app’s Settings. Paste the code, check your device name and selected projects, then approve the fields you want to share.',
      ],
      [
        'Verify or disconnect',
        'Use Sync now for the first upload. Open the device in the portal to check its last successful sync. Revoke access there when you retire a Mac.',
      ],
    ],
    action: ['/devices/pair', 'Pair a device'],
  },
  '/docs/backups': {
    title: 'Backup and recovery',
    summary:
      'Use each save point to locate a backup and decide the next recovery step.',
    sections: [
      [
        'Interpret the evidence',
        'Verified by Mac means the device reported a completed read-back. A manual entry is a location you recorded and has no verification attached.',
      ],
      [
        'Find the copy',
        'Open a backup detail and check its device, project, verification date, and location. Exact locations are visible only when they were entered or shared.',
      ],
      [
        'Restore locally',
        'Mount the corresponding drive and inspect the archive in the native app. Verify the copy before you restore or remove an older folder.',
      ],
    ],
    action: ['/backups', 'Open backup save points'],
  },
  '/docs/file-safety': {
    title: 'File safety',
    summary: 'Keep a recoverable copy before any workspace move or cleanup.',
    sections: [
      [
        'Preview and compare',
        'Review source, destination, and remaining capacity. Confirm which tree is canonical and inspect any differences.',
      ],
      [
        'Check the receipt',
        'An interrupted or failed transfer can leave a partial copy. Look for successful native verification before relying on the destination.',
      ],
      [
        'Preserve recovery evidence',
        'Keep backups and receipts available until a restore has been verified. Removing a portal entry only removes its metadata.',
      ],
    ],
    action: ['/docs/backups', 'Read the recovery guide'],
  },
  '/about': {
    title: 'About CSA-iEM',
    summary:
      'A Wayne Tech Lab workspace tool for people who keep source, build work, and backups across drives.',
    sections: [
      [
        'Native workspace operations',
        'CSA-iEM discovers local checkouts, reviews changes, and verifies preserved copies before cleanup.',
      ],
      [
        'A companion workspace',
        'The web portal ties cloud metadata to projects, devices, and save points so you can find the right copy later.',
      ],
    ],
    action: ['/features', 'Explore the features'],
  },
  '/security': {
    title: 'Security',
    summary:
      'Access to workspace records follows the verified Firebase account and its assigned role.',
    sections: [
      [
        'Account isolation',
        'Projects, devices, and backup metadata are scoped to the signed-in account. Owner role controls are checked by the backend.',
      ],
      [
        'Device credentials',
        'A paired Mac keeps its own credential in Keychain. Revoking a device ends its ability to upload. Paths require consent on both the portal and the Mac.',
      ],
      [
        'Report a concern',
        'Use the repository’s security reporting instructions. Include the affected version and steps to observe the problem without publishing credentials or private data.',
      ],
    ],
    action: ['/contact', 'Find support'],
  },
  '/privacy': {
    title: 'Privacy',
    summary:
      'What the CSA-iEM workspace stores and what stays with your local copy.',
    sections: [
      [
        'Account and workspace records',
        'The portal uses Firebase Authentication for account identity. Firestore stores the project, device, and backup metadata you enter or authorize a paired Mac to send.',
      ],
      [
        'Local files',
        'Backup payloads and recovery actions live on the drives configured in the native app. A save point contains metadata about that copy.',
      ],
      [
        'Manage what you share',
        'Remove your manual entries from their details. Open Sync Settings to review or revoke device access and Contact for account or data questions.',
      ],
    ],
    action: ['/settings/sync', 'Review sync settings'],
  },
  '/terms': {
    title: 'Terms of service',
    summary:
      'Read the project’s terms for permitted use, responsibilities, and distribution.',
    sections: [
      [
        'Using CSA-iEM',
        'Use the app only for devices, data, and repositories you are authorized to manage. Inspect work before applying filesystem changes.',
      ],
      [
        'Source document',
        'Wayne Tech Lab LLC maintains the current project terms in the CSA-iEM source repository.',
      ],
    ],
    action: ['/about', 'About the project'],
  },
}

const releases = [
  {
    tag: '0.2.3',
    date: 'March 12, 2026',
    summary: 'Workspace detection and local project recovery fixes.',
  },
  {
    tag: '0.0.06',
    date: 'March 7, 2026',
    summary: 'Earlier local workspace and cost-control release.',
  },
  {
    tag: '0.0.05',
    date: 'March 7, 2026',
    summary: 'Earlier CSA-iEM source release.',
  },
]

export function HomePage() {
  const { user } = useSession()
  return (
    <>
      <section className="portal-hero">
        <div className="hero-inner">
          <div className="hero-copy">
            <p className="eyebrow">
              <span className="signal-dot" /> CSA-iEM for macOS
            </p>
            <h1>Know where every project lives.</h1>
            <p>
              Keep your projects, devices, and backup locations in one private
              workspace. Find the right copy when you need to get back to work.
            </p>
            <div className="actions">
              <AppLink
                className="button primary"
                to={user ? '/dashboard' : '/login'}
              >
                {user ? 'Open workspace' : 'Log in to workspace'}{' '}
                <ArrowRight size={17} />
              </AppLink>
              <AppLink className="button inverse" to="/downloads">
                <ArrowDownToLine size={17} /> Get the Mac app
              </AppLink>
            </div>
          </div>
          <div className="hero-photo">
            <img
              src="/images/workstation.jpg"
              width="1440"
              height="960"
              fetchPriority="high"
              alt="A Mac workstation beside two external backup drives"
            />
          </div>
        </div>
      </section>
      <section className="public-content home-features">
        <div className="section-title">
          <h2>Pick up where you left off</h2>
          <AppLink to="/features" className="inline-link">
            See all features <ArrowRight size={16} />
          </AppLink>
        </div>
        <div className="feature-grid">
          {guidance.map(({ href, name, description, icon: Icon }) => (
            <AppLink className="surface feature-card" key={href} to={href}>
              <span className="icon-box">
                <Icon size={22} />
              </span>
              <h3>{name}</h3>
              <p>{description}</p>
              <span className="inline-link">
                Read the guide <ChevronRight size={15} />
              </span>
            </AppLink>
          ))}
        </div>
      </section>
      <section className="public-content product-preview">
        <div>
          <p className="eyebrow">Workspace dashboard</p>
          <h2>See the copies you can recover.</h2>
          <p className="page-lede">
            Open a project to see its save points, verification dates, and the
            Mac that reported them.
          </p>
          <AppLink className="button secondary" to="/docs/getting-started">
            Get started <ArrowRight size={16} />
          </AppLink>
        </div>
        <figure>
          <img
            src="/images/workspace-preview.jpg"
            width="1280"
            height="900"
            loading="lazy"
            alt="CSA-iEM workspace dashboard showing fictional projects, devices and backup save points"
          />
          <figcaption>Portal preview with sample records</figcaption>
        </figure>
      </section>
    </>
  )
}

function Header({
  title,
  summary,
  section,
}: {
  title: string
  summary: string
  section: string
}) {
  return (
    <header className="public-page-header">
      <p className="eyebrow">{section}</p>
      <h1>{title}</h1>
      <p className="page-lede">{summary}</p>
    </header>
  )
}

function ArticlePage({ path }: { path: string }) {
  const article = articles[path]
  return (
    <article className="public-content readable">
      <Header
        title={article.title}
        summary={article.summary}
        section={path.startsWith('/docs') ? 'Documentation' : 'CSA-iEM'}
      />
      <div className="article-sections">
        {article.sections.map(([title, detail]) => (
          <section key={title}>
            <h2>{title}</h2>
            <p>{detail}</p>
          </section>
        ))}
      </div>
      {path === '/privacy' && (
        <p>
          <a href={`${repository}/blob/main/PRIVACY-NOTICE.md`}>
            Read the native app privacy notice <ExternalLink size={14} />
          </a>
        </p>
      )}
      {path === '/terms' && (
        <p>
          <a href={`${repository}/blob/main/TERMS-OF-SERVICE.md`}>
            Read the published terms <ExternalLink size={14} />
          </a>
        </p>
      )}
      <AppLink className="button secondary" to={article.action[0]}>
        {article.action[1]} <ArrowRight size={16} />
      </AppLink>
    </article>
  )
}

function FeaturesPage() {
  return (
    <section className="public-content">
      <Header
        title="A workspace you can recover"
        summary="CSA-iEM connects local project operations with a private inventory you can open from a browser."
        section="Features"
      />
      <div className="feature-grid">
        {guidance.map(({ href, name, description, icon: Icon }) => (
          <AppLink className="surface feature-card" key={href} to={href}>
            <span className="icon-box">
              <Icon size={22} />
            </span>
            <h2>{name}</h2>
            <p>{description}</p>
            <span className="inline-link">
              Read guide <ChevronRight size={16} />
            </span>
          </AppLink>
        ))}
      </div>
      <div className="callout">
        <ShieldCheck size={25} />
        <div>
          <h2>Review before you remove</h2>
          <p>
            Use the native preview, checksum verification, and recovery receipts
            before cleaning up old copies.
          </p>
          <AppLink to="/docs/file-safety">Review file safety</AppLink>
        </div>
      </div>
    </section>
  )
}

function PlansPage() {
  const details = [
    'See product documentation and release history.',
    'Keep private projects, devices, backups, and a paired Mac.',
    'Export workspace inventories as CSV.',
    'Review backup coverage across projects and devices.',
    'Check private service status.',
    'Assign member and staff levels and review the role audit.',
  ]
  return (
    <section className="public-content">
      <Header
        title="Plans and account levels"
        summary="Start with a free account. Your owner manages paid and staff access."
        section="CSA-iEM"
      />
      <div className="feature-grid">
        {ACCOUNT_LEVELS.map(({ level, label, account }) => (
          <section
            className={`surface feature-card ${level === 1 ? 'recommended-plan' : ''}`}
            key={level}
          >
            <p className="eyebrow">
              Level {level} · {account}
            </p>
            <h2>{label}</h2>
            <p>{details[level]}</p>
            {level === 1 && (
              <AppLink className="button primary" to="/signup">
                Create a free account
              </AppLink>
            )}
          </section>
        ))}
      </div>
    </section>
  )
}

function DownloadsPage() {
  return (
    <section className="public-content">
      <Header
        title="Download CSA-iEM"
        summary="Run CSA-iEM on a Mac to discover workspaces and verify backups."
        section="Native app"
      />
      <div className="download-grid">
        <article className="surface feature-card">
          <Laptop2 size={30} />
          <h2>macOS source install</h2>
          <p>
            Use the repository installation guide and verify its documented
            prerequisites and checksums.
          </p>
          <a className="button primary" href={`${repository}#readme`}>
            Open install instructions <ExternalLink size={16} />
          </a>
        </article>
        <article className="surface feature-card">
          <Layers3 size={30} />
          <h2>Published versions</h2>
          <p>
            The current releases contain source archives. A signed macOS
            installer has yet to be published.
          </p>
          <AppLink className="button secondary" to="/releases">
            Browse releases <ArrowRight size={16} />
          </AppLink>
        </article>
      </div>
    </section>
  )
}

function ReleasesPage() {
  return (
    <section className="public-content readable">
      <Header
        title="Release history"
        summary="Published versions and source archive availability from the project repository."
        section="Native app"
      />
      <ol className="release-list">
        {releases.map((release) => (
          <li className="surface feature-card" key={release.tag}>
            <p className="eyebrow">{release.date} · Source archive</p>
            <h2>CSA-iEM {release.tag}</h2>
            <p>{release.summary}</p>
            <a
              href={`${repository}/releases/tag/${release.tag}`}
              className="inline-link"
            >
              View on GitHub <ExternalLink size={15} />
            </a>
          </li>
        ))}
      </ol>
      <a href={`${repository}/releases`} className="button secondary">
        All GitHub releases
      </a>
    </section>
  )
}

function DocsPage() {
  return (
    <section className="public-content">
      <Header
        title="Documentation"
        summary="Set up the Mac app, start a workspace, and find or recover your saved copies."
        section="Learn CSA-iEM"
      />
      <div className="feature-grid">
        {docs.map(([href, name, summary]) => (
          <AppLink className="surface feature-card" key={href} to={href}>
            <span className="icon-box">
              <BookOpen size={21} />
            </span>
            <h2>{name}</h2>
            <p>{summary}</p>
            <span className="inline-link">
              Read guide <ChevronRight size={15} />
            </span>
          </AppLink>
        ))}
      </div>
    </section>
  )
}

function HelpPage() {
  const faqs = [
    [
      'Why does a backup show “Manual save point”?',
      'The record was added by hand. A completed Mac receipt is required to display a verification date.',
    ],
    [
      'My pairing code expired. What should I do?',
      'Open Devices → Pair a Mac and generate a new code. Paste it into Settings and confirm what to share.',
    ],
    [
      'Why is a location blank?',
      'The device may have shared a receipt without the exact path. Check its sharing settings, or open the project in the native app.',
    ],
    [
      'Where is the installer?',
      'Use Downloads to see whether the current release has a signed installer or source instructions.',
    ],
  ]
  return (
    <section className="public-content">
      <Header
        title="Help center"
        summary="Find answers about accounts, device pairing, and backup evidence."
        section="Support"
      />
      <div className="help-grid">
        <div className="surface faq-list">
          {faqs.map(([question, answer]) => (
            <details key={question}>
              <summary>{question}</summary>
              <p>{answer}</p>
            </details>
          ))}
          <AppLink className="button secondary" to="/contact">
            Contact support
          </AppLink>
        </div>
        <figure className="help-figure">
          <img
            src="/images/workspace-preview.jpg"
            width="1280"
            height="900"
            loading="lazy"
            alt="Example CSA-iEM workspace with synthetic backup data"
          />
          <figcaption>Workspace preview with sample records</figcaption>
        </figure>
      </div>
    </section>
  )
}

function ContactPage() {
  return (
    <section className="public-content readable">
      <Header
        title="Contact Wayne Tech Lab"
        summary="Choose the right channel for product questions or a reproducible issue."
        section="Support"
      />
      <div className="download-grid">
        <section className="surface feature-card">
          <Check size={22} />
          <h2>Product inquiries</h2>
          <p>Use the contact information on Wayne Tech Lab’s website.</p>
          <a className="button primary" href="https://www.waynetechlab.com/">
            Wayne Tech Lab <ExternalLink size={15} />
          </a>
        </section>
        <section className="surface feature-card">
          <BookOpen size={22} />
          <h2>Technical issues</h2>
          <p>
            Include the app version, what you expected, and a short way to
            reproduce the problem.
          </p>
          <a className="button secondary" href={`${repository}/issues`}>
            Open GitHub Issues <ExternalLink size={15} />
          </a>
        </section>
      </div>
    </section>
  )
}

export function PublicPage({ path }: { path: string }) {
  switch (path) {
    case '/':
      return <HomePage />
    case '/features':
      return <FeaturesPage />
    case '/plans':
      return <PlansPage />
    case '/downloads':
      return <DownloadsPage />
    case '/releases':
      return <ReleasesPage />
    case '/docs':
      return <DocsPage />
    case '/help':
      return <HelpPage />
    case '/contact':
      return <ContactPage />
    default:
      return <ArticlePage path={path} />
  }
}
