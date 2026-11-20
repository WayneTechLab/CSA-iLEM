# CSA-iEM web portal

Live: https://csa-ilem.web.app

Adopted from WayneTechLab/WebAppX standalone starter 3.4.0 at 4ec10ea11857c756f686233ddcc905a99781e7b6. Template license retained in TEMPLATE-LICENSE. Layout/account patterns reviewed against WayneTechLab.com, Networks.Chat, and MKWgear; provider secrets and their application-specific backends were not copied.

## Account and data model

Firebase Auth supports Google and email/password. Verified accounts can read and write their own projects, devices and backup location records under users/{uid}/{projects|devices|backups}/{id}. Each record stores name, location, notes, kind and a server updatedAt timestamp. Live listeners are intentional for dashboard sync across signed-in browsers. Lists are bounded to 100 records per category.

Roles live at roles/{uid}, with integer level 1–5. Only trusted backend credentials can assign them; clients cannot self-promote. Unauthenticated visitors have Level 0. Paid billing/entitlement automation and employee management are not implemented. No cross-user administrative data access is granted by the current prototype rules.

Database: portal, Enterprise Native mode, us-west1, free tier at provisioning. Owner Lucas@WayneTechLab.com has a backend-provisioned Level 5 role. Email verification is required before role read and cloud saves.

## Current boundaries

Cloud sync stores metadata only. Local files, backup archives and filesystem operations remain in the native app. Automatic native device pairing/background sync and downloadable signed installers are pending. Downloads links to actual GitHub releases and build guidance.

Build: npm ci && npm run typecheck && npm run lint && npm run build.
Deploy from repository root: firebase deploy --only hosting,auth,firestore --project csa-ilem. Review service scope before each deploy; no Functions, Storage, billing provider or GitHub Actions are configured here.

## Verification on 2026-11-20

TypeScript, ESLint and production build passed. Live browser login, verified member project creation, reload readback, record deletion and sign-out passed with a disposable test account. Deployed rules rejected guests, cross-account reads, stale timestamps and self-promotion; own verified save/read/delete passed. Disposable accounts and successful probe records were removed. Owner interactive Google login still requires the owner.
