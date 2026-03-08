# PRD: Pipeline Smoke Canary

## Overview
Build a minimal web app that proves the autonomous pipeline can bootstrap a greenfield project, open a pull request, review it, and hand it back to the merge path. The app only needs a homepage and a health-check API, but it must follow the standard Node.js and Vercel deployment path used by the template.

## Tech Stack
- Runtime: Node.js 20+
- Framework: Next.js Pages Router + Express-compatible API entrypoint
- Language: TypeScript
- Testing: Vitest
- Storage: In-memory only

## Validation Commands
- Build: `npm run build`
- Test: `npm test`
- Run: `npm run dev`

## Deployment
- Platform: Vercel
- Notes:
  - Include the standard Vercel-compatible `api/index.ts` entrypoint.
  - Include the Vercel API rewrite so `/api/*` routes are handled by the server entrypoint.

## Non-Functional Requirements
- Keep the implementation intentionally small so the first PR arrives quickly.
- Use clear file structure and lightweight tests.
- Do not add database, auth, or external API dependencies.

## Out of Scope
- User accounts
- Persistent storage
- Background jobs
- Third-party APIs

## Features

### 1. Project Scaffold and API Entrypoint
- Create the base Next.js + TypeScript project scaffold.
- Add the `api/index.ts` entrypoint and the active deploy profile configuration.
- Ensure the project builds and runs on Vercel.

#### Acceptance Criteria
- [ ] The repository contains a valid Next.js + TypeScript scaffold with package scripts for build, test, and dev.
- [ ] `api/index.ts` exists and routes API traffic into the server application.
- [ ] `.deploy-profile` is set for the Vercel deployment profile used by the template.
- [ ] `vercel.json` rewrites `/api/(.*)` to `/api`.

### 2. Health Check API
- Add a health endpoint that returns a simple JSON payload for smoke verification.

#### Acceptance Criteria
- [ ] `GET /api/health` returns HTTP 200.
- [ ] The response body includes `{ "status": "ok" }`.
- [ ] Automated tests cover the health endpoint.

### 3. Smoke Dashboard
- Add a homepage that explains this is a pipeline smoke canary and links to the health endpoint.

#### Acceptance Criteria
- [ ] `/` renders the heading `Pipeline Smoke Canary`.
- [ ] The page includes visible text `Autonomy smoke test`.
- [ ] The page includes a link to `/api/health`.
