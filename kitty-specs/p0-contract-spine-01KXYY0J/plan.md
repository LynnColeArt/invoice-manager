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
- A mutation is successful only after commit and explicit checkpoint. A
  committed mutation with a failed checkpoint is a distinct recovery state.
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
checkpoint-close-reopen integration, black-box HTTP and same-origin proxy smoke,
web format/lint/type/component/build, and runtime-license audit
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
| Test-first critical persistence and contract behavior | Red-first unit, negative, black-box, and reopen acceptance cases | Pass |
| 90% Zig domain coverage | Coverage gate applies to P0 shared value/migration/durability logic | Pass |
| GPL-2.0-only and dependency notices | Dedicated runtime compatibility/notice gate | Pass |
| Living behavior documentation | Versioned schemas, fixtures, spec, research, quickstart, and ledger update together | Pass |
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
│           └── contracts/          # generated, ignored
├── contracts/
│   ├── common/v1/
│   ├── api/v1/
│   │   ├── base.openapi.yaml
│   │   └── fragments/<owner>/
│   ├── events/v1/
│   │   ├── envelope.schema.json
│   │   └── payloads/<owner>/
│   ├── fixtures/<owner>/v1/
│   └── manifests/<owner>.json
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
├── package.json
└── package-lock.json
```

**Structure Decision**: Use one repository with separate web and API build
roots and a neutral contract tree. P0 creates only shared/platform paths. P1-P4
later create their own feature/domain subdirectories. The contract tool scans
owner directories deterministically, so adding a mission does not modify a
shared registry.

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
transaction commit -> explicit checkpoint -> acknowledgement
```

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

### Composition

- P0 owns base/common schemas and the composition command.
- Missions own fragments under their owner directory and namespace component,
  operation, event, and mount names.
- Composition order is canonical path order.
- The command rejects duplicate paths/methods, operation IDs, schema IDs,
  component names, event identities/versions, and module mount keys.
- Composition runs twice in CI and compares bytes.
- OpenAPI and generated TypeScript aggregates are ignored build outputs.

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
- Translate storage diagnostics to stable application categories; do not expose
  internal file paths or engine details to HTTP clients.

### Durable mutation

```text
Idle
  -> TransactionActive
  -> Committed
  -> Checkpointed
  -> Acknowledged

TransactionActive -> RolledBack
Committed -> DurabilityUnconfirmed -> Checkpointed
```

Only Checkpointed may become Acknowledged. `DurabilityUnconfirmed` retries the
checkpoint boundary and never replays the already committed domain operation.
Shutdown stops new work, completes or rolls back the active operation,
checkpoints the committed generation, then closes.

### Migrations

- Owner-scoped directories contain UUIDv7 descriptors and forward scripts.
- Recursive discovery replaces a shared sequence/registry.
- Explicit dependencies form a DAG; UUIDv7 is only a deterministic tie-break.
- Applied ID, owner, checksum, and UTC instant are recorded.
- Applied migrations are immutable and never receive down scripts.
- Because ShovelerDB DDL is not session-transactional, startup migration failure
  discards the dirty uncheckpointed handle and reopens the last durable file.
- Traffic begins only after the full migration set is checkpointed.

## Testing and Quality Strategy

1. **Contract unit tests** validate canonical values, valid/invalid examples,
   schema references, lifecycle manifests, and collision diagnostics.
2. **Composition tests** prove byte determinism and mutate one duplicate class
   at a time so the architectural gate cannot pass vacuously.
3. **Zig unit tests** drive exact money, dates, envelopes, migration DAGs,
   diagnostics, literal encoding, and durability state transitions red-first.
4. **Persistence integration** uses real ShovelerDB through the application seam
   for first migration, no-op rerun, commit/checkpoint/reopen, rollback, corrupt
   file, and checkpoint failure.
5. **Black-box HTTP tests** call the service's public health/error boundary; a
   web smoke test calls it through the same-origin proxy.
6. **Web gates** run formatting, ESLint Flat Config, strict types, component
   tests, and the production build independently of Zig.
7. **Coverage** enforces 90%+ on P0 shared Zig behavior and 100% coverage of
   enumerated critical error branches.
8. **License audit** classifies distributed runtime packages, source dependency,
   fonts/container contents when they become applicable, and preserves notices.
9. **Mutation checks** deliberately break collision and route-count floors so a
   zero-input or allow-everything validator cannot pass.

## Implementation Concern Map

### IC-01 — Reproducible repository shell

- **Purpose**: Pin toolchains, create independent web/API builds, and provide one
  documented bootstrap/validation entry point.
- **Relevant requirements**: FR-001, FR-002, FR-015; NFR-001, NFR-008, NFR-012.
- **Affected surfaces**: root package/lock/version files, `apps/web/`,
  `services/api/build.zig*`, CI.
- **Sequencing/depends-on**: none.
- **Risks**: Root files are high-contention; only P0/integration steward edits
  them after this mission.

### IC-02 — Canonical shared values

- **Purpose**: Prevent cross-language identity, precision, date, and instant
  drift.
- **Relevant requirements**: FR-003; NFR-004, NFR-006; C-006.
- **Affected surfaces**: `contracts/common/v1/`, `services/api/src/shared/`,
  generated web contract types.
- **Sequencing/depends-on**: IC-01.
- **Risks**: Schema validation cannot prove signed 64-bit range alone; runtime
  parsers and boundary fixtures must.

### IC-03 — Additive API and event composition

- **Purpose**: Let missions add namespaced fragments without shared registries.
- **Relevant requirements**: FR-004-FR-008; NFR-002, NFR-003.
- **Affected surfaces**: `contracts/api/`, `contracts/events/`,
  `contracts/fixtures/`, `contracts/manifests/`, `tools/contracts/`.
- **Sequencing/depends-on**: IC-01, IC-02.
- **Risks**: Generated aggregate or route registry must remain deterministic and
  uncommitted; non-vacuity checks need real reference fragments.

### IC-04 — Parallel-safe migration runner

- **Purpose**: Discover and validate owner-scoped forward migrations without a
  shared number or registry.
- **Relevant requirements**: FR-009, FR-010; NFR-003, NFR-009.
- **Affected surfaces**: `services/api/migrations/`,
  `services/api/src/platform/persistence/migrations.zig`.
- **Sequencing/depends-on**: IC-01, IC-02.
- **Risks**: ShovelerDB DDL is not transaction-scoped; failure recovery must
  discard the dirty handle before checkpoint.

### IC-05 — Reproducible ShovelerDB consumption

- **Purpose**: Prove a public clean clone can build the pinned engine without a
  sibling path or floating revision.
- **Relevant requirements**: FR-011, FR-012; NFR-012; C-004, C-005.
- **Affected surfaces**: `deps/shovelerdb/`, service build and attribution.
- **Sequencing/depends-on**: IC-01.
- **Risks**: Upstream lacks consumer package metadata and a linkable library;
  source shim must remain narrow and replaceable.

### IC-06 — Durable storage seam

- **Purpose**: Make commit, checkpoint, uncertainty, close, and reopen explicit
  to future domain services.
- **Relevant requirements**: FR-012-FR-014; NFR-005, NFR-006, NFR-009.
- **Affected surfaces**: `services/api/src/platform/persistence/` and real
  integration tests.
- **Sequencing/depends-on**: IC-04, IC-05.
- **Risks**: Blind replay after checkpoint failure duplicates business effects;
  borrowed ABI values and concurrent handles can corrupt assumptions.

### IC-07 — Black-box boundary proof

- **Purpose**: Prove the real web-to-Zig contract and error envelope without
  introducing feature behavior.
- **Relevant requirements**: FR-002, FR-004, FR-015; NFR-007.
- **Affected surfaces**: Zig health HTTP entry, web proxy/client, contract tests.
- **Sequencing/depends-on**: IC-02, IC-03.
- **Risks**: A health-only application can create vacuous architecture gates;
  fixture/mutation tests must prove the route path is real.

### IC-08 — Program gates and ownership handoff

- **Purpose**: Make validation, GPL compatibility, shared-file ownership, and
  P1-P4 readiness auditable.
- **Relevant requirements**: FR-015, FR-016; NFR-008, NFR-010-NFR-012;
  C-001, C-007, C-010.
- **Affected surfaces**: CI, notices, quickstart, contract manifests,
  `docs/program-ledger.md`.
- **Sequencing/depends-on**: IC-01-IC-07.
- **Risks**: Apache-2.0 code must not enter the combined GPL-2.0-only runtime;
  generic shared-file ownership must not be misassigned to P7 reporting.

## Parallel Delivery Shape

After IC-01 creates the skeleton, IC-02, IC-04, and IC-05 can proceed in
parallel. IC-03 consumes IC-02; IC-06 consumes IC-04/IC-05; IC-07 consumes
IC-02/IC-03. IC-08 integrates evidence. `/spec-kitty.tasks` must translate this
graph into disjoint lanes and must not group all shared contracts into one long
serial work package.

P1-P4 may begin specification and planning as soon as this draft contract set is
committed. Their implementation remains blocked until their consumed contracts
are Frozen and P0 is merged/revalidated on the program baseline.

## Risks and Mitigations

| Risk | Mitigation | Routed owner |
| --- | --- | --- |
| ShovelerDB packaging blocks clean clone | Exact-commit source/submodule shim; pursue a small upstream package release separately | P0 / upstream dependency |
| Commit succeeds but checkpoint fails | Durable state machine and checkpoint-only recovery | P0 |
| DDL failure leaves dirty in-memory schema | Startup-only migrations; discard uncheckpointed handle and reopen | P0 |
| Shared registries reintroduce merge conflicts | Convention scanning, collision checks, generated ignored aggregates | P0 |
| P0 absorbs feature behavior | Explicit exclusions and requirement/path review | Program orchestrator |
| GPLv2-only incompatibility enters runtime | Runtime dependency classifier, license allow/deny evidence, notices | P0 then integration steward |
| ShovelerDB snapshot cap is reached | Store binary artifacts externally; monitoring and operational limits | P3 |
| Snapshot rename lacks directory sync guarantee | Document and harden power-loss strategy | P3 |
| Downstream plan assumes Draft means implementable | Contract state gate: only Frozen permits implementation | Program orchestrator |

## Planning Completion Gate

- Specification and requirements checklist are complete and committed.
- Research decisions and evidence sources are recorded.
- Data model contains only foundation records.
- Draft schemas are syntactically valid and mutually resolvable.
- Quickstart describes planned commands without claiming implementation exists.
- Decision verifier reports no deferred or stale decisions.
- Program ledger records P0 handle, baseline, Draft contract version, ownership,
  and downstream planning readiness.
- No tasks or work packages are created in this phase.
