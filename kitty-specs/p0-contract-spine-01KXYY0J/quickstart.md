# P0 Contract Spine Quickstart

This document describes the developer experience P0 must implement. During the
planning phase the commands and paths are contractual targets; they are not yet
evidence that source code exists.

## Supported baseline

- Linux x86_64
- Node.js 24.18.0 LTS with npm 11.16.0
- Zig 0.16.0
- Git with submodule support if the upstream ShovelerDB package metadata has not
  landed

Docker and LuaLaTeX are intentionally not P0 prerequisites. P3 owns the
reference deployment and P2 owns the document runtime.

## Planned clean-clone flow

```bash
git clone --recurse-submodules <invoice-manager-repository>
cd invoice-manager
npm run verify:foundation:clean
```

`verify:foundation:clean` starts from the empty clean-checkout dependency/build
cache state, runs `npm ci` inside its measured boundary, and then delegates to
`verify:foundation`. The HTTP stage installs the exact Chromium revision selected
by the locked Playwright 1.61.1 package inside that same boundary; it never falls
back to a system browser. The aggregate will run deterministic contract composition, generated type
checks, web validation/build, Zig formatting/build/tests/coverage, migration
negative tests, real ShovelerDB persistence integration, black-box HTTP/proxy
smoke, and runtime-license validation.

## Planned focused commands

```bash
npm run contracts:check
npm run contracts:generate
npm run web:check
npm run api:check
npm run persistence:integration
npm run migration:negative
npm run browser:install
npm run http:smoke
npm run licenses:check
```

Each command must be independently diagnosable and use the same underlying
commands as CI. `http:smoke` invokes the idempotent `browser:install` stage itself,
so the bare smoke command is complete after `npm ci`; the focused install command
exists for contributors who want to prepare the pinned browser artifact early.

The separate NFR-001 first-run measurement invokes `npm run
bootstrap:foundation`; that wrapper also runs `npm ci` inside the monotonic
timer, performs all required validation, starts production-shaped Zig/Next.js,
and stops after the same-origin health smoke succeeds.

## Planned local run

```bash
INVOICE_API_BIND=127.0.0.1 \
INVOICE_API_PORT=8080 \
INVOICE_DATABASE_PATH=.local/invoice-manager.db \
npm run dev:api

INVOICE_MANAGER_API_ORIGIN=http://127.0.0.1:8080 \
npm run dev:web
```

Run the two commands in separate terminals after creating the local database
parent directory. These runtime variables are server-only and must not use a
`NEXT_PUBLIC_*` name.

The web shell owns an App Router handler for `/api/v1/*`. The handler reads one
validated server-only Zig origin at request time, never from browser-controlled
input or `NEXT_PUBLIC_*`, and the normal lint/typecheck/build gates do not require
that runtime variable. The Playwright smoke starts production Next.js with the
fixed origin, starts and later stops a real Ready Zig process, and rejects
redirects, unbounded responses, and noncanonical upstream failures. A successful
smoke path returns structured health data from:

```text
http://localhost:3000/api/v1/health
```

No billing identity, client, project, invoice, authentication, reporting, PDF,
or recurrence routes exist in P0.

## Contract contribution flow

1. Add a namespaced fragment under the mission-owned API or event directory.
2. Add valid and invalid synthetic fixtures under the same owner/version.
3. Update only that owner's contract manifest.
4. Run `npm run contracts:generate`, then `npm run contracts:check`.
5. If the mission needs a shared/root change, route it to the integration
   steward instead of editing the aggregate directly.

Generated aggregate schemas, TypeScript types, and runtime route inventory are
build outputs and must not be committed.

## Storage acceptance flow

The persistence integration will:

1. create a temporary store;
2. apply the bootstrap migration and checkpoint it;
3. prove a second migration run is a no-op;
4. commit and checkpoint a synthetic record;
5. synchronize the database parent directory on Linux;
6. close and reopen the store;
7. verify the record through the application storage boundary;
8. separately prove rollback, corrupt-file refusal, checkpoint failure,
   directory-sync failure, and process termination at persistence boundaries.

The service must never acknowledge durable success before both checkpoint and
supported parent-directory synchronization complete.

## Expected planning-to-implementation handoff

P1-P4 may plan against the `0.1.0-draft.1` schemas in this mission. They may
begin implementation only after P0 promotes the consumed versions to Frozen,
records immutable digests, and merges on the current program baseline.
