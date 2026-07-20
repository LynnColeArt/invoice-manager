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
npm ci
npm run verify:foundation
```

`verify:foundation` will run deterministic contract composition, generated type
checks, web validation/build, Zig formatting/build/tests/coverage, migration
negative tests, real ShovelerDB persistence integration, black-box HTTP/proxy
smoke, and runtime-license validation.

## Planned focused commands

```bash
npm run contracts:check
npm run web:check
npm run api:check
npm run persistence:integration
npm run http:smoke
npm run licenses:check
```

Each command must be independently diagnosable and use the same underlying
commands as CI.

## Planned local run

```bash
npm run dev:api
npm run dev:web
```

The web shell will proxy `/api/v1/*` to the Zig service. A successful smoke path
returns structured health data from:

```text
http://localhost:3000/api/v1/health
```

No billing identity, client, project, invoice, authentication, reporting, PDF,
or recurrence routes exist in P0.

## Contract contribution flow

1. Add a namespaced fragment under the mission-owned API or event directory.
2. Add valid and invalid synthetic fixtures under the same owner/version.
3. Update only that owner's contract manifest.
4. Run `npm run contracts:check`.
5. If the mission needs a shared/root change, route it to the integration
   steward instead of editing the aggregate directly.

Generated aggregate schemas and TypeScript types are build outputs and must not
be committed.

## Storage acceptance flow

The persistence integration will:

1. create a temporary store;
2. apply the bootstrap migration and checkpoint it;
3. prove a second migration run is a no-op;
4. commit and checkpoint a synthetic record;
5. close and reopen the store;
6. verify the record through the application storage boundary;
7. separately prove rollback, corrupt-file refusal, and durability uncertainty.

The service must never acknowledge durable success before the checkpoint.

## Expected planning-to-implementation handoff

P1-P4 may plan against the `0.1.0-draft.1` schemas in this mission. They may
begin implementation only after P0 promotes the consumed versions to Frozen,
records immutable digests, and merges on the current program baseline.
