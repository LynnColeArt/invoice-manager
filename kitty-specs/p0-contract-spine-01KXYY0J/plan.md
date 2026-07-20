# Implementation Plan: P0 Contract Spine

**Branch**: `feat/p0-contract-spine` | **Date**: 2026-07-19 | **Spec**: [spec.md](spec.md)
**Input**: Approved mission specification and the concurrent program contracts
in `docs/program-ledger.md`.

## Summary

Create the smallest runnable foundation that makes parallel Invoice Manager
missions safe: independent Next.js and Zig shells, canonical cross-language
value representations, additive API/event contracts, immutable fixtures,
parallel-safe migrations, a narrow durable ShovelerDB seam, and focused CI
gates. Generated aggregates are build outputs. Feature behavior remains in
P1-P8.

The service dependency direction is strict: the pinned ShovelerDB adapter feeds
the durable serialized store, migration application consumes that public durable
store seam, and HTTP readiness consumes both durable-store and migration
readiness. The durable store never imports or depends on migration behavior.

P0 publishes contract version `0.1.0-draft.1` for P1-P4 planning. The version
may become Frozen only after P0 implementation proves every valid/invalid
fixture and clean-clone command. Downstream implementation may not begin against
Draft state.

## Engineering Alignment

- The web shell uses the Next.js App Router and communicates only through the
  same-origin `/api/v1` contract.
- The Zig service owns all future authoritative behavior and is the only
  process allowed to access ShovelerDB.
- Shared wire values favor canonical strings where JSON numbers would lose
  precision or textual variation would create incompatible signatures.
- Domain missions contribute additive files discovered by convention. They do
  not edit root registries, generated aggregates, or each other's directories.
- On Linux, a mutation is successful only after commit, explicit checkpoint,
  and synchronization of the database parent directory after snapshot rename.
  A committed mutation with a failed checkpoint or directory sync is a
  distinct recovery state.
- P0 implements only health, foundation contracts, migrations, and synthetic
  persistence proof. Billing and operational behavior is out of scope.

## Technical Context

**Language/Version**: Zig 0.16.0; TypeScript 6.0.3; Node.js 24.18.0 LTS
**Primary Dependencies**: Next.js 16.2.10; React/React DOM 19.2.7; ESLint
10.7.0; npm 11.16.0; ShovelerDB commit
`fc7539a3874293540a4de6d228b3ea670a8ca2e8`; OpenAPI 3.1; JSON Schema
2020-12
**Storage**: One serialized ShovelerDB handle per database path; binary
artifacts remain outside the database
**Testing**: Zig unit/coverage tests, contract-schema and fixture validation,
deterministic composition tests, migration negative tests, real ShovelerDB
checkpoint-directory-sync-close-reopen integration, process-crash boundary
tests, black-box HTTP and same-origin proxy smoke, web
format/lint/type/component/accessibility/build, Playwright foundation workflow,
mandatory `migration:negative`, and runtime-license audit
**Target Platform**: Linux x86_64 development and CI baseline
**Project Type**: Single repository with independently buildable web and API
applications plus repository-owned contract tooling
**Performance Goals**: Health p99 under one second for 100 local requests;
complete P0 validation within 15 minutes on the reference CI runner
**Constraints**: GPL-2.0-only distribution; exact integer money; no floating
dependency revisions; no feature behavior; one storage process/handle per path;
generated aggregates are not committed
**Scale/Scope**: One internal organization and administrator, four Wave A
consumer missions, one local database file, and only foundation entities in P0

## Charter Check

### Pre-design gate

| Charter rule | Plan evidence | Result |
| --- | --- | --- |
| Next.js presents; Zig owns behavior | One JSON boundary; web has no persistence or authoritative domain services | Pass |
| ShovelerDB is the embedded transactional store | Exact commit pin and one application-owned adapter | Pass |
| Consequential success is durably checkpointed | Durable-write seam distinguishes commit from checkpoint | Pass |
| Exact money and separated currencies | Canonical decimal-string minor units plus checked signed 64-bit parsing | Pass |
| Test-first critical persistence, migration, and route-policy behavior | Reviewable red-first evidence names the failing case and command before production changes, then records the green result | Pass |
| 90% Zig domain coverage | Coverage gate applies to P0 shared value/migration/durability logic | Pass |
| GPL-2.0-only and dependency notices | Dedicated runtime compatibility/notice gate | Pass |
| Living behavior documentation | Versioned schemas/fixtures plus orchestrator pre-acceptance sync for governed mission docs/quickstart/glossary; closure updates README and ledger | Pass |
| Frontend accessibility and Playwright workflow | The real shell/proxy integration owns component accessibility checks and a same-origin Playwright health workflow | Pass |
| Persistence concurrency and idempotency | Durable-store tests exercise serialization/competing handles; migration tests prove repeatable no-op application | Pass |
| Concurrent mission ownership | Convention discovery, owner directories, no shared registries, integration steward | Pass |

No charter exception is required.

### Post-design re-check

The concrete structure and contracts preserve every pre-design rule. Build-time
Node tooling validates schemas but does not become a second business backend.
The ShovelerDB source shim, if needed, remains pinned and hidden behind the Zig
adapter. P2 and P3 own TeX and deployment respectively, so P0 does not create
empty or misleading future gates. Result: Pass.

## Project Structure

### Documentation for this mission

```text
kitty-specs/p0-contract-spine-01KXYY0J/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
├── contracts/
│   ├── README.md
│   ├── common-v1.schema.json
│   ├── api-v1.openapi.yaml
│   ├── event-envelope-v1.schema.json
│   ├── event-catalog-v1.schema.json
│   ├── module-contribution-v1.schema.json
│   ├── migration-manifest-v1.schema.json
│   ├── contract-manifest-v1.schema.json
│   └── p0-contract-manifest.json
└── research/
    ├── evidence-log.csv
    └── source-register.csv
```

### Planned source tree

```text
/
├── .github/workflows/
├── apps/
│   └── web/
│       ├── src/app/
│       ├── src/features/
│       └── src/lib/
│           ├── api/
│           └── contracts/          # handwritten workspace adapters
├── contracts/
│   ├── common/v1/
│   ├── conformance/
│   │   └── p0-p4-inputs.json       # committed immutable input pins
│   ├── api/v1/
│   │   ├── base.openapi.yaml
│   │   └── fragments/<owner>/
│   ├── events/v1/
│   │   ├── envelope.schema.json
│   │   ├── catalogs/<owner>/
│   │   └── payloads/<owner>/
│   ├── modules/<owner>/module.json
│   ├── fixtures/<owner>/v1/
│   ├── manifests/v1/schema.json
│   ├── manifests/drafts/p0.json    # WP03 validation input
│   ├── manifests/p0.json           # WP12 canonical closure record
│   └── migrations/v1/manifest.schema.json
├── deps/
│   └── shovelerdb/                 # exact-commit submodule/source shim
├── services/
│   └── api/
│       ├── build.zig
│       ├── build.zig.zon
│       ├── migrations/<owner>/
│       ├── src/
│       │   ├── main.zig
│       │   ├── domains/<owner>/
│       │   ├── platform/persistence/
│       │   └── shared/
│       └── tests/
├── tools/contracts/
│   ├── .gitignore
│   ├── package.json                # workspace/export boundary
│   ├── src/
│   └── .generated/                 # sole ignored derived-output root
│       ├── typescript/v1/
│       └── runtime/v1/route-inventory.json
├── package.json
└── package-lock.json
```

**Structure Decision**: Use one repository with separate web and API build
roots and a neutral contract tree. P0 creates only shared/platform paths. P1-P4
later create their own feature/domain subdirectories. The contract tool scans
owner directories deterministically, so adding a mission does not modify a
shared registry.

`tools/contracts/.generated/typescript/v1/` is the only generated TypeScript
contract location; `tools/contracts/.generated/runtime/v1/route-inventory.json`
is the only generated Zig route-inventory input; and the contract generator is
the only writer of either derived surface. The literal root command
`npm run contracts:generate` materializes both outputs deterministically before
any Zig HTTP compile or web typecheck/build. `npm run contracts:check` runs that
materialization twice and compares bytes in addition to validating inputs.
`tools/contracts/.gitignore` excludes the generated tree while the
`tools/contracts` workspace exposes the version-one output through a stable
package export. The web application imports that workspace export and must not
copy generated bindings into `apps/web/` or create another generated output.

## Boundary and Data Flow

```text
Browser or Next.js rendering
          |
          | same-origin JSON /api/v1/*
          v
      Zig HTTP boundary
          |
          v
  Zig shared/domain services
          |
          v
serialized ShovelerDB adapter
          |
          v
transaction commit -> explicit checkpoint -> parent-directory sync -> acknowledgement
```

The startup dependency graph is separate from request flow and is always:

```text
pinned ShovelerDB adapter
          -> migration-agnostic durable store
          -> migration discovery/application/readiness
          -> HTTP listen/accept readiness
```

Arrows mean “consumes the public seam of.” No reverse import is permitted.

The web application may perform usability checks, render safe server errors,
and generate clients from contracts. It may not authorize a request, calculate
authoritative money, transition domain state, persist data, or call the storage
engine. P0 proves the boundary with `GET /api/v1/health`; it adds no feature
mutation.

## Contract Strategy

### Versioning and lifecycle

- Wire protocol major is `/api/v1`.
- P0 planning publishes `0.1.0-draft.1`.
- Draft permits specification and planning only.
- Frozen permits downstream implementation against immutable source/fixture
  digests.
- Implemented means producer/consumer code exists.
- Verified means the real integration and acceptance suite pass.
- Additive optional fields are minor changes. Meaning, requiredness, removal,
  rename, or formerly-valid input tightening is a major change.
- `baseline_commit` is the exact program base consumed by planning. Publication
  identity is recorded by Git and the program ledger, avoiding an impossible
  self-reference to the commit containing the manifest.
- One canonical manifest records contract identity, owner and mission,
  lifecycle, base commit, stable content digest, dependencies, exact consumed
  content digests, outputs, owned paths, shared touchpoints, migration strategy,
  and integration fixtures. P1-P8 may not invent a second manifest dialect.
- At freeze, `content_digest` is SHA-256 over RFC 8785 JCS bytes for contract
  ID, version, inputs, outputs, and integration fixtures after deterministic
  identity sorting. It excludes mutable state, base, ownership metadata, and
  itself, so consumer pins remain valid as Frozen advances to Implemented and
  Verified. Any content change creates a new contract version.
- Legal transitions are Draft -> Frozen -> Implemented -> Verified, with any
  non-Superseded state also able to advance to terminal Superseded. Regression,
  skipping a normal state, or changing content after Frozen is rejected.
- JSON Schema rejects pending evidence outside Draft. The runtime lifecycle gate
  also resolves normalized repository-relative paths, rejects duplicate paths,
  verifies every file and digest, requires valid and invalid integration
  fixtures, verifies input states/content digests, and enforces legal
  transitions. It also requires the dependency-owner set to equal the input-
  owner set, exactly one input per dependency, and no duplicate or conflicting
  contract identity.

### Composition

- P0 owns base/common schemas, stable schema identifiers, contribution schemas,
  and the composition command. Canonical common values resolve from
  `https://invoice-manager.invalid/contracts/common/v1/schema.json`.
- Each owner contributes `contracts/modules/<owner>/module.json`, OpenAPI under
  `contracts/api/v1/fragments/<owner>/`, event catalogs under
  `contracts/events/v1/catalogs/<owner>/`, payload schemas under
  `contracts/events/v1/payloads/<owner>/`, fixtures under
  `contracts/fixtures/<owner>/v1/`, and migrations below
  `services/api/migrations/<owner>/`.
- The module contribution declares its unique mount key, fragment/catalog
  paths, migration root, protected-by-default route policy, and explicit public
  operation IDs. Every OpenAPI operation carries
  `x-invoice-manager-access: protected|public`; missing metadata is treated as
  protected, and a public declaration must agree with the module manifest.
- Event catalogs bind `source`, `event_type`, `event_version`, aggregate type,
  and payload schema ID. Full-envelope validation first checks the P0 envelope,
  then resolves exactly one catalog entry and validates `data`; an unconstrained
  object alone never proves event compatibility.
- Composition order is canonical path order.
- The command rejects duplicate paths/methods, operation IDs, schema IDs,
  component names, event identities/versions, and module mount keys.
- Composition runs twice in CI and compares bytes.
- OpenAPI aggregates are ignored build outputs. `npm run contracts:generate`
  writes generated TypeScript only to
  `tools/contracts/.generated/typescript/v1/` and the canonical route inventory
  only to `tools/contracts/.generated/runtime/v1/route-inventory.json`; both are
  ignored by `tools/contracts/.gitignore`. The TypeScript output is exported
  through the `tools/contracts` workspace, while WP04 makes HTTP build/test
  hooks depend on route-inventory materialization before Zig compilation.
- Commit `contracts/conformance/p0-p4-inputs.json` as the authoritative P0-P4
  conformance-input lock. It contains exactly one canonically sorted record per
  P0-P4 input with owner, contract ID/version, repository-relative manifest
  path, full lowercase 40-hex Git commit, manifest SHA-256, and contract content
  digest. Branch names, tags, abbreviated commits, `HEAD`, working-tree paths,
  and any other moving reference are forbidden.
- Contract checks resolve every conformance record at its exact commit and
  verify both recorded digests before composition. Missing owners, extra owners,
  repeated commits with conflicting digests, unavailable commits, or digest
  drift fail before output is written.
- The task contract uses those pinned P1-P4 Draft schemas and manifests as real
  conformance inputs plus synthetic mutation cases. Toy-only fragments or a scan
  of moving mission heads do not satisfy P0 acceptance.

### Producer/consumer fixtures

- Valid fixtures contain canonical accepted inputs and outputs.
- Invalid fixtures pair one input with a stable error code and JSON Pointer.
- Event batches are UTF-8 JSONL with one LF-terminated envelope per line.
- Frozen fixtures are append-only; changed behavior creates a new case/version.
- Every manifest records exact source and fixture SHA-256 digests.
- P4 owns reporting-input fixtures. P5/P6 later own real domain events. P7 owns
  the adapters between those contracts.

## Persistence and Migration Strategy

### ShovelerDB boundary

- Pin `fc7539a3874293540a4de6d228b3ea670a8ca2e8`.
- Prefer a small upstream package-metadata release. Until available, use an
  exact-commit submodule/source module under `deps/shovelerdb/`; never use a
  sibling checkout or floating branch.
- Import through one module boundary and call only the documented embedding ABI
  behavior from the invoice adapter.
- Copy borrowed result data before releasing a result.
- One process owns one handle per path and serializes all operations.
- Compile-time SQL identifiers and one tested text-literal encoder are the only
  permitted SQL construction path until bound parameters exist upstream.
- Translate storage diagnostics to stable application categories. Production
  logs and HTTP responses contain only the stable category plus correlation
  metadata; raw engine prose, SQL, paths, values, and user or sensitive data are
  forbidden. Synthetic adapter tests prove those sentinels never leak.
- WP04 owns `services/api/build.zig` and publishes a convention-scanned test
  hook surface once. Test roots below `services/api/tests/shared/`,
  `services/api/tests/persistence/`, and `services/api/tests/http/` are
  discovered deterministically by canonical repository-relative path, with
  duplicate logical test names rejected.
- The stable service build surface includes `zig build test`,
  `zig build test-shared`, `zig build test-persistence`,
  `zig build test-migration`, `zig build test-migration-integration`,
  `zig build migration-negative`, `zig build coverage-migration`,
  `zig build test-http`, and `zig build coverage`. The HTTP hook depends on
  `npm run contracts:generate` before Zig compilation. The aggregate coverage
  hook includes shared, persistence, and migration logic, with migration at
  90% or better and every enumerated critical branch covered. WP04 supplies the
  hooks even when a later category is initially empty; a required gate fails on
  an empty category once its producer WP is present rather than reporting
  vacuous success.
- Later shared, durable-store, migration, and HTTP packages add tests only below
  their owned convention roots. They do not edit `build.zig`, add one-off build
  steps, or replace these command names.
- The root command `npm run migration:negative` is mandatory and delegates to
  `zig build migration-negative --build-file services/api/build.zig`. Missing
  wiring, zero executed negative cases, or a swallowed nonzero status fails the
  focused gate.

### Durable mutation

```text
Idle
  -> TransactionActive
  -> Committed
  -> Checkpointed
  -> DirectorySynchronized
  -> Acknowledged

TransactionActive -> RolledBack
Committed -> DurabilityUnconfirmed -> Checkpointed -> DirectorySynchronized
```

Only DirectorySynchronized may become Acknowledged on the supported Linux
baseline. After ShovelerDB returns from checkpoint, the adapter opens and
`fsync`s the database parent directory so the snapshot rename is part of the
acknowledgment boundary. A checkpoint or directory-sync failure returns
`DurabilityUnconfirmed`, retries only persistence completion, and never replays
the already committed domain operation. Shutdown stops new work, completes or
rolls back the active operation, checkpoints and directory-syncs the committed
generation, then closes. Unsupported filesystems or directory-sync behavior
fail readiness rather than weakening the guarantee silently.

The durable store exposes a migration-agnostic public seam for serialized
operations, transaction outcomes, checkpoint, directory synchronization,
discard/reopen, close, and typed diagnostics. It owns no descriptor discovery,
DAG planning, applied-migration schema, or migration policy, and therefore has
no dependency on the migration package. Persistence red-first tests exercise
the state machine, competing-handle serialization, checkpoint/sync failures,
shutdown during an active operation, and close/reopen through this public seam.

### Migrations

- Owner-scoped directories contain UUIDv7 descriptors and forward scripts.
- Recursive discovery replaces a shared sequence/registry.
- Explicit dependencies form a DAG; UUIDv7 is only a deterministic tie-break.
- Every descriptor carries `script_path`, `script_digest`, and
  `descriptor_digest`. Dependencies are stored in ascending UUID string order;
  the descriptor digest covers RFC 8785 JSON Canonicalization Scheme bytes for
  ID, owner, name, dependencies, script path, and script digest while excluding
  only itself. A fixed fixture publishes canonical bytes and the expected
  digest.
- Applied ID, owner, descriptor digest, script digest, and UTC instant are
  recorded; mutation of any covered field is a hard failure.
- Applied migrations are immutable and never receive down scripts.
- Migration application imports only the durable store's public seam; it never
  opens ShovelerDB directly or reaches into adapter/store implementation files.
- Because ShovelerDB DDL is not session-transactional, startup migration failure
  discards the dirty uncheckpointed handle and reopens the last durable file.
- Traffic begins only after the full migration set is checkpointed and its
  snapshot rename is directory-synchronized.
- The migration runner returns an explicit readiness result covering discovery,
  validation, application/no-op, checkpoint, directory synchronization, and
  durable reopen state. The HTTP composition root requires both the durable
  store readiness result and this migration readiness result before binding or
  accepting traffic.

## Testing and Quality Strategy

1. **Contract unit tests** validate canonical values, valid/invalid examples,
   schema references, lifecycle manifests, and collision diagnostics.
2. **Composition tests** prove byte determinism against real P1-P4 Draft
   artifacts pinned by `contracts/conformance/p0-p4-inputs.json` and mutate one
   duplicate, external-reference, discriminator, route-access, manifest, mount,
   moving-commit, and digest-drift class at a time so the architectural gate
   cannot pass vacuously.
3. **Zig unit tests** drive exact money, dates, envelopes, migration DAGs,
   diagnostics, literal encoding, and durability state transitions red-first.
4. **Persistence integration** uses real ShovelerDB through the application seam
   for first migration, no-op rerun, commit/checkpoint/directory-sync/reopen,
   rollback, corrupt file, checkpoint failure, injected directory-sync failure,
   and process termination after each durability boundary.
5. **Black-box HTTP tests** call the service's public health/error boundary; a
   web smoke test calls it through the same-origin proxy.
6. **Web gates** run formatting, ESLint Flat Config, strict types, component
   accessibility tests, and the production build independently of Zig. The
   application-integration package adds the real shell/proxy and a Playwright
   same-origin health workflow only after the Zig HTTP boundary is ready.
   Accessibility targets WCAG 2.2 AA: zero configured automated serious or
   critical violations, normal-text contrast at least 4.5:1, large-text contrast
   at least 3:1, keyboard-visible focus/skip-link operation, 200% zoom, and no
   horizontal overflow at 320 CSS pixels.
7. **Coverage** enforces 90%+ on P0 shared Zig behavior and 100% coverage of
   enumerated critical error branches.
8. **Lifecycle mutation tests** prove Frozen and later states cannot contain
   pending, missing, duplicate, non-repository, or mismatched evidence and
   cannot skip legal transitions.
9. **License audit** classifies distributed runtime packages, source dependency,
   fonts/container contents when they become applicable, and preserves notices.
10. **Mutation checks** deliberately break collision and route-count floors so a
   zero-input or allow-everything validator cannot pass.
11. **Focused migration rejection** runs `npm run migration:negative`, which
    must execute the convention-discovered Zig negative suite and report a
    nonzero result for every controlled missing-dependency, cycle, collision,
    digest-drift, DDL, checkpoint, and directory-sync mutation.

### Red-first evidence protocol

- ShovelerDB adapter persistence/checkpoint/literal behavior, durable-store
  behavior, migration behavior, route policy, and Next.js proxy security each
  begin with a named behavior case that fails for the intended reason through
  the package's public boundary.
- Before production changes for that case, the implementing agent records the
  stable case ID, exact focused command, expected observable failure, and actual
  failing result in the WP Activity Log. Temporary failing source need not be
  committed.
- The same entry is followed chronologically by the production change and green
  result. A test first observed only after the production behavior exists does
  not satisfy the evidence requirement.
- Review rejects tautological, inside-boundary, mocked-away, or zero-case tests.
  Route policy is exercised through composed metadata and dispatch, migrations
  through the durable store seam, adapter persistence through its public adapter
  API, durable persistence through its public store API, and proxy security
  through the public same-origin route with attacker-controlled inputs.

### Reference performance protocol

- The reference environment is Linux x86_64 with at least four logical CPUs,
  16 GiB RAM, and local ephemeral SSD storage. CI records the runner image,
  kernel, CPU model/count, memory, filesystem, Node/npm/Zig versions, and exact
  commit with each benchmark result; undersized or concurrently loaded runners
  do not produce acceptance evidence.
- The synthetic dataset is the committed P0 bootstrap migration plus an empty
  feature-domain store. No private or randomly sized dataset participates.
- The first-run 15-minute clock uses a monotonic wall clock, starts immediately
  before `npm run bootstrap:foundation` in a clean checkout with dependency/build
  caches disabled, and that wrapper runs `npm ci` before build, all required
  foundation validation, service/web startup, and one valid same-origin health
  response, and stops only after all complete successfully. Installation of the
  documented prerequisite toolchains is outside the clock.
- The validation-duration 15-minute clock uses a monotonic wall clock and starts
  immediately before `npm run verify:foundation:clean` from a clean checkout
  with empty dependency and build caches. That wrapper runs `npm ci` and then
  `npm run verify:foundation`; dependency resolution, builds, tests, audits, and
  every independently required gate are inside the boundary, which stops only
  after the final gate reports a result on the same reference runner.
- Health responsiveness is measured through the real same-origin proxy with a
  ready ReleaseSafe Zig service and production Next.js build. After ten
  unmeasured warm-up requests, issue exactly 100 sequential requests. Measure
  each complete request/response body with a monotonic clock, discard no samples,
  require all responses to be valid, sort durations ascending, and define p99 as
  the 99th observation (one-based). At least 99 observations must be at or below
  1,000 ms.
- Acceptance evidence records the commands, min/median/p99/max, invalid/slow
  count, and total wall time in machine-readable CI output. Direct Zig health
  timing may be diagnostic but cannot replace the same-origin acceptance path.

## Implementation Concern Map

### IC-01 — Reproducible repository shell

- **Purpose**: Pin the root Node/Zig toolchain substrate and declare one
  documented bootstrap plus focused validation command surface.
- **Relevant requirements**: FR-001, FR-002, FR-015; NFR-001, NFR-008, NFR-012.
- **Affected surfaces**: root `package.json`, the sole immutable root
  `package-lock.json`, exact `tools/contracts/package.json`, exact
  `apps/web/package.json`, tool-version files, and root bootstrap commands.
  WP01 declares the complete npm graph before locking it; later concerns own
  implementation/configuration but never mutate package metadata or the lock.
- **Sequencing/depends-on**: none.
- **Risks**: Package metadata is high-contention; predeclaring both workspaces
  and exact tool versions once prevents later phased lock ownership and cyclic
  execution-lane collapse.

### IC-02 — Canonical shared values

- **Purpose**: Prevent cross-language identity, precision, date, and instant
  drift.
- **Relevant requirements**: FR-003; NFR-004, NFR-006; C-006.
- **Affected surfaces**: `contracts/common/v1/`, `services/api/src/shared/`,
  and the contract-workspace generated type consumer boundary.
- **Sequencing/depends-on**: The contract/fixture portion follows IC-01. The Zig
  runtime portion also follows IC-05 so it can use the stable shared-value test
  hook without editing service build integration.
- **Risks**: Schema validation cannot prove signed 64-bit range alone; runtime
  parsers and boundary fixtures must.

### IC-03 — Additive API and event composition

- **Purpose**: Let missions add namespaced fragments without shared registries.
- **Relevant requirements**: FR-004-FR-008; NFR-002, NFR-003.
- **Affected surfaces**: `contracts/api/`, `contracts/events/`,
  `contracts/modules/`, `contracts/fixtures/`, `contracts/manifests/v1/`,
  `contracts/manifests/drafts/`,
  `contracts/conformance/p0-p4-inputs.json`, `tools/contracts/`,
  `tools/contracts/.gitignore`, contract-tool source/tests, and the sole ignored
  generated outputs below `tools/contracts/.generated/`. WP01 owns the workspace
  package metadata; WP03 consumes it read-only.
- **Sequencing/depends-on**: IC-01, IC-02.
- **Risks**: Generated aggregate or route registry must remain deterministic and
  uncommitted; conformance inputs must never resolve moving heads; non-vacuity
  checks need real pinned reference fragments.

### IC-04 — Parallel-safe migration runner

- **Purpose**: Discover and validate owner-scoped forward migrations without a
  shared number or registry.
- **Relevant requirements**: FR-009, FR-010; NFR-003, NFR-009.
- **Affected surfaces**: `services/api/migrations/`,
  `services/api/src/platform/persistence/migrations.zig`.
- **Sequencing/depends-on**: IC-02, IC-03, IC-05, and IC-06. IC-03 supplies the
  canonical migration descriptor schema. Migration application
  consumes the durable store's public operation/readiness seam and never the raw
  adapter; IC-05 supplies the stable migration test hook.
- **Risks**: ShovelerDB DDL is not transaction-scoped; failure recovery must
  request discard/reopen through the durable seam before checkpoint. The
  mandatory `migration:negative` gate and red-first evidence cover each failure.

### IC-05 — Reproducible ShovelerDB consumption

- **Purpose**: Prove a public clean clone can build the pinned engine without a
  sibling path or floating revision.
- **Relevant requirements**: FR-011, FR-012; NFR-012; C-004, C-005.
- **Affected surfaces**: `deps/shovelerdb/`, `services/api/build.zig`,
  `services/api/build.zig.zon`, the storage dependency adapter, and its
  attribution. IC-05 is the sole owner of service build integration and the
  convention-scanned stable Zig test/coverage hooks.
- **Sequencing/depends-on**: IC-01.
- **Risks**: Upstream lacks consumer package metadata and a linkable library;
  source shim must remain narrow and replaceable.

### IC-06 — Durable storage seam

- **Purpose**: Make commit, checkpoint, uncertainty, close, and reopen explicit
  to future domain services.
- **Relevant requirements**: FR-012-FR-014; NFR-005, NFR-006, NFR-009.
- **Affected surfaces**: `services/api/src/platform/persistence/` and real
  integration tests, explicitly excluding `migrations*` files.
- **Sequencing/depends-on**: IC-05 only. The durable store is migration-agnostic
  and exports the public seam consumed later by IC-04.
- **Risks**: Blind replay after persistence failure duplicates business effects;
  directory-sync omission, borrowed ABI values, and concurrent handles can
  corrupt assumptions. Red-first state, competing-handle, crash, and reopen
  cases are required before production behavior.

### IC-07 — Zig HTTP readiness boundary

- **Purpose**: Prove the real Zig health/error boundary and refuse readiness
  until both durable-store and migration readiness are successful.
- **Relevant requirements**: FR-002, FR-004, FR-015; NFR-007.
- **Affected surfaces**: `services/api/src/main.zig`, Zig HTTP modules, route
  policy, and black-box service tests.
- **Sequencing/depends-on**: IC-02, IC-03, IC-04, and IC-06. The HTTP composition
  root consumes both readiness results before binding or accepting traffic.
  Task generation must make WP08 depend on the durable-storage and migration
  packages and require this consumption explicitly.
- **Risks**: A health-only application can create vacuous architecture gates;
  red-first route-policy mutations and real socket tests must prove the route
  path and protected-default policy are real.

### IC-08 — Web configuration substrate

- **Purpose**: Publish static Next.js/tool configuration against the exact app
  package metadata and lock already owned by IC-01, without claiming the real
  application integration is ready.
- **Relevant requirements**: FR-001, FR-015; NFR-001, NFR-004, NFR-012; C-002.
- **Affected surfaces**: App-local configuration files required for formatting,
  lint, strict types,
  accessibility tests, production build, and Playwright.
- **Sequencing/depends-on**: IC-01, IC-02, and IC-03. It may proceed in parallel
  with service work and does not update package metadata/the root lock or create the real
  shell/proxy/E2E implementation.
- **Risks**: Configuration may request an undeclared tool. Static validation
  rejects any package/version expectation not already present in IC-01's lock.

### IC-09 — Shell, proxy, and E2E integration

- **Purpose**: Integrate the real Next.js shell with the ready Zig boundary and
  prove the same-origin public workflow through production-shaped processes.
- **Relevant requirements**: FR-001, FR-002, FR-004, FR-015; NFR-001, NFR-004,
  NFR-007, NFR-012; C-002.
- **Affected surfaces**: Real `apps/web/src/app/` shell/style files,
  `apps/web/src/lib/api/`, handwritten generated-contract
  adapters, foundation component/accessibility tests, and Playwright E2E.
- **Sequencing/depends-on**: IC-07 and IC-08, plus IC-03's generated workspace
  export. It begins only after WP08's Zig HTTP/readiness package is accepted and
  materializes contracts before typecheck/build.
- **Risks**: The real proxy/security boundary can be hidden by mocks. Red-first
  attacker-input tests and production-process E2E must prove it without editing
  package metadata or the root lock.

### IC-10 — Governed documentation sync attestation

- **Purpose**: Reconcile shipped behavior with the closed governed-artifact set and
  produce one schema-validated attestation and committed drift baseline before acceptance.
- **Relevant requirements**: FR-015, FR-016; NFR-010; C-007, C-010.
- **Affected surfaces**: The exact read-only inventory in `Pre-Acceptance Governance
  Sync` plus the sole WP-owned receipt at
  `docs/governance/p0-governed-doc-sync.json`. The project charter is checked
  read-only; there is no tracked project glossary or architecture-note artifact at
  this baseline, so those categories require explicit `not_applicable` rationales.
- **Sequencing/depends-on**: IC-03 through IC-09. This is a Spec Kitty
  `planning_artifact` work package after every producer is reviewed, not an informal
  acceptance assumption and not a code package. Spec Kitty forbids a WP from owning
  its mission definition, so any required mission-document correction is committed by
  the authorized orchestrator through the literal sync command before WP11 resumes.
- **Risks**: A partial receipt could hide drift. The formal schema, closed literal
  inventory, exact commit command, and WP dependency make omissions fail before
  closure starts.

### IC-11 — Program gates and ownership handoff

- **Purpose**: Make validation, GPL compatibility, shared-file ownership, and
  P1-P4 readiness auditable.
- **Relevant requirements**: FR-015, FR-016; NFR-008, NFR-010-NFR-012;
  C-001, C-007, C-010.
- **Affected surfaces**: final cross-cutting validation aggregation, CI
  orchestration, runtime/license tooling, `README.md`,
  `docs/program-ledger.md`, and explicit manifest promotion at
  `contracts/manifests/p0.json`.
- **Sequencing/depends-on**: IC-01 through IC-10. WP12 cannot begin until the
  governed-document sync WP11 is accepted and committed.
- **Risks**: This is an explicit codebase-wide closure package and depends on
  every producing package. Tests, notices, fixtures, and focused commands stay
  with their producing concerns; closure runs the full gate, promotes exact
  evidence, and records readiness rather than absorbing unfinished work.

## Parallel Delivery Shape

After IC-01 creates only the substrate, IC-02's contract portion and IC-05
proceed in parallel. IC-02's Zig runtime portion then consumes both, while
IC-06 follows IC-05 and delivers the migration-agnostic durable store. IC-03
follows the contract portion of IC-02 and may run beside IC-05/IC-06; it pins
all P0-P4 conformance inputs and exposes the sole generated TypeScript workspace
outputs. IC-08 may start after IC-02/IC-03 while service work continues. IC-04
consumes IC-02, IC-03, IC-05, and IC-06 to apply migrations through the public
durable seam and canonical descriptor schema.

IC-07 waits for IC-02, IC-03, IC-04, and IC-06 so HTTP readiness cannot outrun
durable/migration readiness. IC-09 waits for IC-07 and IC-08, then performs the
real shell/proxy/E2E integration without touching package metadata or the lock.
IC-10's governed-doc planning package follows reviewed producer work. IC-11
is the final codebase-wide closure after that sync and every producer. All code
WP ownership is disjoint, so lane computation must remain acyclic.

## Task Ownership Contract

Task generation must preserve these primary owners; dependencies never excuse
two narrow work packages claiming the same file:

| Concern package | Exclusive primary surfaces |
| --- | --- |
| Repository substrate | Root `package.json`, sole root lock, exact contract-tool/web workspace package manifests, npm policy, and tool-version files; declares the complete npm graph and focused commands once |
| Shared values | `contracts/common/v1/`, Zig shared values, and their tests |
| Contract composition | API/event/module/fixture trees, manifest schema plus Draft `contracts/manifests/drafts/p0.json`, conformance lock, contract-tool source/tests, and sole writer of ignored TypeScript/runtime generated outputs; package metadata remains read-only |
| Migration runner | P0 descriptors, migration application/readiness, and migration tests through the public durable seam; excludes adapter/store/directory-sync implementation |
| ShovelerDB consumption | Dependency source, service build files, dependency adapter, dependency notice, and convention-scanned stable Zig test/coverage hooks |
| Durable storage | Migration-agnostic persistence state machine, serialized store, directory sync, diagnostics, and store tests; excludes every `migrations*` file |
| Zig HTTP boundary | `services/api/src/main.zig`, HTTP modules, and black-box service tests |
| Web configuration substrate | App-local configuration only; no package metadata, root lock, shell, proxy, or E2E source |
| Application integration | Narrow app-owned shell/style, proxy/client adapters, accessibility tests, and Playwright E2E after Zig HTTP; package metadata and lock remain read-only |
| Pre-acceptance planning sync | One `planning_artifact` WP owns only `docs/governance/p0-governed-doc-sync.json`: it checks the exact mission spec/plan/data model/quickstart/research/contracts inventory read-only, blocks for an authorized exact sync commit when corrections are needed, records absent glossary/architecture categories, and commits a formal attestation |
| Program closure | One `scope: codebase-wide` package owning foundation CI, full-gate execution, license tooling, `README.md`, `docs/program-ledger.md`, and sole creation/promotion of canonical `contracts/manifests/p0.json` from WP03's disjoint Draft input after all producers and planning sync |

The closure package rejects or routes unfinished producer work back to its
owner. It does not become the routine author of another package's tests,
notices, fixtures, source, or governed mission planning documents. There are no
phase-scoped shared-file handoffs: WP01 is the only package/lock writer, WP03
owns only `contracts/manifests/drafts/p0.json`, and WP12 alone creates the
disjoint canonical `contracts/manifests/p0.json` closure record.

P1-P4 may begin specification and planning as soon as this draft contract set is
committed. Their implementation remains blocked until their consumed contracts
are Frozen and P0 is merged/revalidated on the program baseline.

## Pre-Acceptance Governance Sync

After all producer WPs are implemented and reviewed, but before the acceptance
gate, WP11 performs one governed planning-document reconciliation and attestation in
`planning_artifact` mode. It owns only the receipt under `docs/governance/`; it is not
a code WP and is not assigned to the program-closure package.
It compares shipped observable behavior and canonical terminology with
the exact inventory below; then it updates every affected writable artifact
together through the authorized orchestrator or records an explicit no-change
rationale. The charter and all mission artifacts remain read-only to WP11 itself.
When a correction is required, WP11 pauses, identifies the exact change, and resumes
only after the orchestrator commits the corrected mission artifacts with the schema's
literal `sync_safe_commit` command. If no correction is required, the synchronized
baseline equals the producer baseline.
Because this baseline has no tracked project glossary or architecture-note file,
the receipt records both categories as `not_applicable` with nonempty rationales;
an implementation may not invent or omit paths to make the check pass.

The resolver is closed: `required_artifacts` and `checked_artifacts` must each
contain exactly these paths, once, in this bytewise canonical order, with no glob,
directory walk, optional entry, or additional path:

1. `.kittify/charter/charter.md`
2. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/README.md`
3. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/api-v1.openapi.yaml`
4. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json`
5. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/contract-manifest-v1.schema.json`
6. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-catalog-v1.schema.json`
7. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-envelope-v1.schema.json`
8. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/governed-doc-sync-v1.schema.json`
9. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/migration-manifest-v1.schema.json`
10. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/module-contribution-v1.schema.json`
11. `kitty-specs/p0-contract-spine-01KXYY0J/contracts/p0-contract-manifest.json`
12. `kitty-specs/p0-contract-spine-01KXYY0J/data-model.md`
13. `kitty-specs/p0-contract-spine-01KXYY0J/plan.md`
14. `kitty-specs/p0-contract-spine-01KXYY0J/quickstart.md`
15. `kitty-specs/p0-contract-spine-01KXYY0J/research.md`
16. `kitty-specs/p0-contract-spine-01KXYY0J/research/evidence-log.csv`
17. `kitty-specs/p0-contract-spine-01KXYY0J/research/source-register.csv`
18. `kitty-specs/p0-contract-spine-01KXYY0J/spec.md`

WP11 creates `docs/governance/p0-governed-doc-sync.json` with schema
`invoice-manager.governed-doc-sync/v1`, the producer and synchronized baseline full
commits, a
`required_artifacts` array equal to the inventory above, a canonically sorted
`checked_artifacts` array with every path and SHA-256, `changed`/`no_change` status
plus rationale, example-to-requirement/acceptance mappings, glossary and
architecture decisions, and a `commands` object whose `resolver`, `sync_safe_commit`,
`drift`, and `receipt_safe_commit` values equal the schema's literal constants. The
receipt must validate against
`contracts/governed-doc-sync-v1.schema.json` before commit.

When reconciliation requires mission-document corrections, the literal orchestrator
sync operation is the following command with every writable argument shown. Unchanged
writable files are intentionally included so Spec Kitty reports the closed scope. The
read-only charter and WP-owned receipt are deliberately absent:

```bash
spec-kitty safe-commit kitty-specs/p0-contract-spine-01KXYY0J/contracts/README.md kitty-specs/p0-contract-spine-01KXYY0J/contracts/api-v1.openapi.yaml kitty-specs/p0-contract-spine-01KXYY0J/contracts/common-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/contract-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-catalog-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/event-envelope-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/governed-doc-sync-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/migration-manifest-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/module-contribution-v1.schema.json kitty-specs/p0-contract-spine-01KXYY0J/contracts/p0-contract-manifest.json kitty-specs/p0-contract-spine-01KXYY0J/data-model.md kitty-specs/p0-contract-spine-01KXYY0J/plan.md kitty-specs/p0-contract-spine-01KXYY0J/quickstart.md kitty-specs/p0-contract-spine-01KXYY0J/research.md kitty-specs/p0-contract-spine-01KXYY0J/research/evidence-log.csv kitty-specs/p0-contract-spine-01KXYY0J/research/source-register.csv kitty-specs/p0-contract-spine-01KXYY0J/spec.md --message "docs: synchronize governed P0 artifacts" --to-branch feat/p0-contract-spine
```

WP11 then validates and commits only its attestation with the schema's literal
`receipt_safe_commit` command:

```bash
spec-kitty safe-commit docs/governance/p0-governed-doc-sync.json --message "docs: attest governed P0 artifacts" --to-branch feat/p0-contract-spine
```

WP12 validates the formal schema and exact inventory, recomputes every recorded digest,
and runs the receipt's self-contained command beginning
`receipt_commit="$(git log -1 --format=%H -- docs/governance/p0-governed-doc-sync.json)" && git diff --exit-code "$receipt_commit" --`
with all 18 required paths and the receipt path fully expanded to prove no later drift. Missing or
additional artifacts, unsorted/duplicate paths, digest differences, an empty
rationale, a command mismatch, or an unmapped example fail closure. WP12 has a
hard WP11 dependency, so the sync must finish before IC-11 begins final
acceptance. Code WPs may cite a needed planning correction in their Activity
Log, but they do not claim `quickstart.md` or other governed planning paths
merely to close their own package.

## Risks and Mitigations

| Risk | Mitigation | Routed owner |
| --- | --- | --- |
| ShovelerDB packaging blocks clean clone | Exact-commit source/submodule shim; pursue a small upstream package release separately | P0 / upstream dependency |
| Commit succeeds but checkpoint or parent-directory sync fails | Durable state machine, Linux directory sync, and persistence-boundary-only recovery | P0 |
| DDL failure leaves dirty in-memory schema | Migration application uses the durable store seam to discard uncheckpointed state and reopen; HTTP remains unready | P0 |
| Durable storage imports migration policy and creates a dependency cycle | Keep durable storage migration-agnostic; migration depends on its public seam, never the inverse | P0 |
| HTTP binds before durable/migration readiness | IC-07 depends on IC-04 and IC-06 and requires both explicit readiness results before listen/accept | P0 |
| Later WPs edit `build.zig` for each test | WP04 publishes convention-scanned stable shared/persistence/migration unit/integration/negative/HTTP/coverage hooks once | P0 |
| Shared registries reintroduce merge conflicts | Convention scanning, collision checks, generated ignored aggregates | P0 |
| Generated contracts gain multiple writers or are absent at compile time | `contracts:generate` is the sole writer of TypeScript and runtime route inventory; HTTP/web hooks depend on it | P0 |
| Conformance silently follows a moving mission head | Commit and validate full commits plus manifest/content digests in `contracts/conformance/p0-p4-inputs.json` | P0 / program orchestrator |
| Workspace metadata and root lock race with later work | WP01 predeclares both exact workspace manifests and is the only lock writer; all consumers verify read-only | P0 substrate |
| Proxy accepts attacker-controlled destinations or leaks internal origin | Require charter-mandated red-first public-route security cases and production E2E | P0 web integration |
| Timing gates vary by machine or discard slow samples | Enforce the reference runner, cache, dataset, monotonic timing, sample, and evidence protocol above | P0 closure |
| Governed docs drift or closure absorbs quickstart | Run planning-artifact WP11 before IC-11; WP12 closure owns only README, ledger, CI/license tooling, and P0 manifest | Program orchestrator |
| P0 absorbs feature behavior | Explicit exclusions and requirement/path review | Program orchestrator |
| GPLv2-only incompatibility enters runtime | Runtime dependency classifier, license allow/deny evidence, notices | P0 then integration steward |
| ShovelerDB snapshot cap is reached | Store binary artifacts externally; monitoring and operational limits | P3 |
| Snapshot rename lacks directory sync guarantee | P0 durable store syncs the parent directory through its public seam before acknowledgment; P3 validates deployed filesystem support | P0/P3 |
| Downstream plan assumes Draft means implementable | Contract state gate: only Frozen permits implementation | Program orchestrator |

## Planning Completion Gate

- Specification and requirements checklist are complete and committed.
- Research decisions and evidence sources are recorded.
- Data model contains only foundation records.
- Draft schemas are syntactically valid and mutually resolvable; P1-P4 use the
  canonical manifest shape and P0 common schema IDs.
- `contracts/conformance/p0-p4-inputs.json` is specified as a committed,
  canonically ordered set of exact full commits and verified digests with no
  moving references.
- Module, event-catalog, route-access, migration-digest, and freeze semantics
  are normative rather than left to work-package implementers.
- The dependency graph is adapter -> durable store -> migration application ->
  HTTP readiness; the durable store has no migration dependency.
- WP04's convention-scanned stable build/test surface names migration
  unit/integration/negative/coverage plus the mandatory root gate.
- `contracts:generate`, `tools/contracts/.generated/{typescript,runtime}/`, and
  `tools/contracts/.gitignore` define the sole generated writers/materialization
  order for both consumers.
- WP01 alone owns the complete package graph and lock; web configuration and
  later shell/proxy/E2E packages have disjoint ownership after IC-07.
- Adapter persistence/checkpoint, durable store, migration, route policy, and
  proxy security require chronological red-first public-boundary evidence.
- The reference first-run, validation-duration, and health-p99 protocols define
  runner, dataset, cache state, timing boundaries, sample handling, and evidence.
- Quickstart describes planned commands without claiming implementation exists.
- The pre-acceptance governed-doc sync is a formal `planning_artifact` WP with a
  closed resolver, schema, exact safe-commit call, and dependency before closure;
  program closure explicitly owns
  `contracts/manifests/p0.json`, README, and ledger evidence.
- Decision verifier reports no deferred or stale decisions.
- Program ledger records P0 handle, baseline, Draft contract version, ownership,
  and downstream planning readiness.
- Task generation follows this gate; the plan itself does not create or mutate
  work packages.

## Implementation Acceptance Completion Gate

- Every producer package passes its stable focused hook without editing
  `services/api/build.zig`; `npm run migration:negative` executes nonzero case
  counts and all expected rejection categories.
- Adapter persistence/checkpoint/literal, durable-store, migration, route-policy,
  and proxy-security reviews contain chronological red-first then green evidence
  for every critical case.
- Durable store and migration readiness are both successful before the Zig HTTP
  process accepts traffic; injected store/migration failures prove no listener
  reports ready.
- The application integration leaves package metadata/root lock unchanged,
  materializes/imports generated contracts through the contract-tool workspace,
  and passes WCAG 2.2 AA component accessibility, production build, red-first
  proxy security, real proxy, and Playwright E2E.
- Reference first-run, full-validation, and 100-request same-origin health
  measurements pass using the defined protocol and publish complete evidence.
- WP11 attestation completes after any required orchestrator planning sync and
  reports governed docs/examples/glossary aligned or an approved explicit
  `no_change` rationale.
- Closure runs every independent gate, verifies the immutable conformance lock,
  promotes exactly `contracts/manifests/p0.json`, and updates README/ledger
  evidence without taking ownership of producer tests or quickstart.
