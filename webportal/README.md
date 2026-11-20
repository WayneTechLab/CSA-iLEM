# CSA-iEM web portal

The portal is based on the WayneTechLab/WebAppX 3.4.0 starter at
`4ec10ea11857c756f686233ddcc905a99781e7b6`. The production site is
[CSA-iEM](https://csa-ilem.web.app).

## Start the local workspace

Use the project's Node version for Vite, Firebase CLI, and Java 21 for the
Firestore emulator. Functions targets Node 22. If your shell uses another
Node version, set `CSA_PORTAL_FUNCTIONS_NODE` to the absolute path to a Node
22 executable for the emulator.

```bash
npm --prefix webportal ci
npm --prefix webportal/functions ci
npm --prefix webportal run dev:local
```

Open the local owner preview printed by the launcher. It signs in a disposable
Level 5 account against the demo project. Starting a new session reseeds data.
Use `npm --prefix webportal run dev:status` to find the URL and
`npm --prefix webportal run dev:stop` to stop the owned processes.

```bash
npm --prefix webportal run typecheck
npm --prefix webportal run lint
npm --prefix webportal run build
npx --prefix webportal playwright install chromium
npm --prefix webportal run test:portal
```

Set `CSA_BROWSER_CHANNEL=chrome` for the test command to use an installed
Google Chrome instead. The tests require an active local emulator session.
They exercise all 38 routes on desktop and mobile, browser account workflows,
role and record isolation, and the device protocol against the demo project.

## Pair the isolated Mac app

Run `npm --prefix webportal run dev:mac` on macOS while the local session is
running. This opens a separate debug bundle and a synthetic project under the
ignored local session directory. In the local dashboard, select **Pair a Mac**
and generate a code. Enter the code in the debug app's Settings, select the
fixture project, and approve sharing. Enable automatic sync or use **Sync now**.
The debug app can create a real fixture backup and verify its copy locally.
It also includes a lost-connection switch for testing the persistent upload
queue. Revoke the device from its portal details to check that its next upload
is denied and the existing receipt remains visible.

## Data and rollout

The browser matches the existing named `portal` database. Existing records
remain in `users/{uid}/projects|devices|backups`. Paired devices write linked
device, project, and backup metadata to separate collections under the same
UID. Only verified account holders can read their workspace. Callable
Functions validate record changes and enforce owner role management, recent
authentication, and audited role writes. Pairing codes expire after ten minutes.
The Mac stores its device credential in Keychain and the backend stores its
digest. Exact paths require approval in the browser and on the Mac. Roles 2
and 3 are owner assigned. The CSV export escapes spreadsheet formulas.

The dashboard counts records in the signed-in workspace. Backup coverage is
the number of tracked projects with a linked verified receipt divided by all
tracked projects. Activity keeps the most recent 150 displayed events. Manual
save points do not contribute to verified coverage.

Deploy the `portal` Functions codebase and Firestore rules before promoting a
verified Hosting preview to live. The `csa-ilem` project uses Blaze, with the
Functions and the `portal` database in `us-west1`. The
`csa-portal-runtime` service account can read Firebase Auth accounts and can
read and write the named `portal` database.

Cloud Run uses service-level public HTTPS access for the portal Functions
under the project's domain-restricted IAM policy. For a newly created portal
service, use `gcloud run services update SERVICE --no-invoker-iam-check
--region=us-west1 --project=csa-ilem`. The callables enforce Firebase Auth
and role checks. Native endpoints require a pairing code or a device credential.
Firebase Auth emails use its hosted action handler. The portal's `/auth/action`
page also accepts Firebase verification and password reset links.

A signed macOS installer requires separate Developer ID packaging and
notarization. The public Downloads page links to the checked GitHub releases.
No Actions workflow is used.

The workspace preview is a browser screenshot using fixture records.
The home hero uses this built-in ImageGen prompt.

> Wide landscape editorial product photograph for the public home page of a professional Mac workspace and backup application. A modern Apple-style aluminum desktop workstation and exactly two distinct compact external backup drives on a clean desk, cool slate navy lighting with one restrained warm amber practical light, credible materials, sophisticated but realistic, slightly oblique straight-on camera view. Keep the equipment grouped near the center for responsive cropping. Screen has a subtle abstract dark gradient with no simulated UI. No words, no logos, no people, no watermark, no simulated dashboard. Landscape 3:2.
