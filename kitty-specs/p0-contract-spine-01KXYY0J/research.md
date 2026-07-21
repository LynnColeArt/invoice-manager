# P0 Contract Spine Research

## Research question

What is the smallest reproducible foundation that lets P1 through P4 specify,
plan, and later implement concurrently without sharing business logic, file
ownership, migration numbers, or hand-maintained registries?

## Decision summary

P0 will establish a buildable repository shell and freeze four wire contracts,
three composition conventions, and one persistence seam. It will prove those
boundaries with real contract, HTTP, and checkpoint-close-reopen tests. It will
not implement any invoice-manager feature behavior.

## Decision 1: Foundation scope

**Decision:** P0 owns only the repository/build shell, shared JSON primitives,
HTTP envelope, event envelope, additive contract composition, collision-safe
migration protocol, serialized ShovelerDB gateway, health/proxy smoke path, and
CI harnesses.

**Rationale:** These are the shared dependencies in the program ledger. Adding
feature behavior would turn P0 into the serial bottleneck the program design is
intended to remove.

**Alternatives considered:**

- A complete vertical invoice preview was rejected because it would absorb P1
  and P2 ownership.
- A generic application framework, event bus, ORM, or service container was
  rejected as speculative infrastructure.

**Explicit exclusions:** Billing Identity, Client, Project, Invoice, Payment,
tax, remittance, logo, authentication, sessions, CSRF, dashboard projections,
charts, LaTeX/PDF rendering, invoice numbering, recurrence, due-work logic,
feature database tables, and real feature-event payloads.

## Decision 2: Repository and ownership convention

**Decision:** Use independently buildable `apps/web/` and `services/api/`
roots, an additive `contracts/` tree, domain-owned feature directories, and
build-time generated aggregates. P0 owns root locks, shared primitives,
contract tooling, the persistence seam, and CI. Feature missions own their
domain files, contract fragments, fixtures, and migrations.

**Rationale:** A deterministic directory scan removes hand-edited route,
schema, and migration registries from the concurrency path. Generated OpenAPI,
route, and TypeScript aggregates remain build artifacts rather than committed
shared files.

**Alternatives considered:**

- One manually maintained OpenAPI document was rejected because parallel
  missions would edit the same file.
- A single global route registry was rejected for the same reason.
- Committing generated aggregates was rejected because it creates noisy merge
  conflicts and stale derived state.

## Decision 3: Toolchain baseline

**Decision:** Pin Node.js 24.18.0 LTS, npm 11.16.0, Next.js 16.2.10,
React/React DOM 19.2.7, TypeScript 6.0.3, ESLint 9.39.5, and Zig 0.16.0.
Commit the npm lockfile and use exact toolchain versions in CI and containers.

**Rationale:** Node 24 is the production LTS line; local Node 26 is a Current
release. TypeScript 6.0.3 remains compatible with the current lint/tooling
programmatic API while TypeScript 7.0 does not yet provide that API. Zig 0.16.0
is both the current stable toolchain and the toolchain used by local
ShovelerDB. ESLint 9.39.5 is the newest registry release compatible without
peer overrides with `eslint-config-next` 16.2.10 and its imported React,
accessibility, and import plugins; ESLint 10.7.0 was rejected after npm 11
resolution proved those transitive peers remain capped at ESLint 9.

**Deferred to owning missions:** P2 will own the pinned TeX Live 2026 package
manifest and LuaLaTeX container. P3 will own Docker Compose deployment. P0 may
validate future extension points but must not install speculative PDF or
deployment dependencies.

## Decision 4: Shared wire primitives

**Decision:** Freeze these version-one JSON representations:

- `EntityId`: canonical lowercase hyphenated UUIDv7 string. It is opaque and
  never used as a business-ordering guarantee.
- `Money`: `{ "currency": "USD", "minor_units": "12500" }`, where
  `minor_units` is the canonical base-10 spelling of a signed 64-bit integer.
  Zig uses checked `i64`; TypeScript uses `bigint`, never `number`.
- `LocalDate`: semantically valid Gregorian `YYYY-MM-DD`.
- `UtcInstant`: canonical UTC `YYYY-MM-DDTHH:mm:ss.SSSZ`.
- Aggregate revisions and other potentially 64-bit counters use canonical
  decimal strings at the JSON boundary.

**Rationale:** JSON and JavaScript numbers cannot preserve every signed 64-bit
integer. Canonical strings prevent precision loss and cross-language ambiguity.
P0 defines structural currency validation only; P1 owns the launch allowlist.

**Alternatives considered:** ULIDs were considered but rejected for the shared
wire contract because UUIDv7 has a standard canonical textual form and avoids a
custom prefix registry. Numeric minor units were rejected due to JavaScript
precision limits.

## Decision 5: HTTP contract composition

**Decision:** Use OpenAPI 3.1 with JSON Schema 2020-12, rooted at `/api/v1`.
P0 owns the base envelope and deterministic composition tool. Each mission owns
namespaced domain fragments. CI rejects duplicate paths, methods, operation
IDs, schema IDs, and component names, then composes twice and compares bytes.

JSON success responses use `data` plus `meta.request_id`. JSON failures use a
stable `error.code`, safe `error.message`, optional field failures addressed by
JSON Pointer, and the same request metadata. Binary artifacts may use typed
headers rather than the JSON envelope. P0 exposes only a health operation.

**Rationale:** Domain fragments allow additive ownership. Stable error codes
let the Next.js UI provide accessible feedback without repeating Zig business
rules.

## Decision 6: Event and fixture contract

**Decision:** Define an immutable version-one event envelope with event ID,
event type and payload version, source, aggregate type/ID/revision, occurred and
recorded instants, correlation/causation IDs, and data. Ordering is promised
only within one aggregate revision; no global order is implied.

Fixture batches are UTF-8 JSONL with one LF-terminated envelope per line.
Contract manifests use one canonical swarm shape for lifecycle, base, immutable
content identity, dependencies, inputs, outputs, ownership, shared touchpoints,
migrations, and valid/invalid fixtures. The content digest excludes mutable
lifecycle state and stays stable from Frozen through Verified. Valid and invalid
fixtures are immutable once frozen; invalid cases pair input with stable error
code and JSON Pointer.

**Rationale:** P4 can implement projection behavior against synthetic reporting
inputs without claiming ownership of future P5/P6 events. P7 later maps the
real producer events into that reporting boundary.

## Decision 7: Parallel-safe migration protocol

**Decision:** Discover migrations recursively beneath owner directories. Each
migration uses a UUIDv7 ID, immutable manifest, lexicographically ordered
dependency IDs, an exact script digest, an RFC 8785 JCS descriptor digest, and a
forward-only script. The runner topologically sorts dependencies, uses the ID
only as a deterministic tie-break, and rejects duplicates, missing dependencies,
cycles, and either digest drifting.

Applied migration ID, owner, both digests, and instant are recorded in
`app_schema_migrations`. Re-running is an observable no-op. P0 owns only the
runner and bootstrap schema; feature tables belong to feature missions.

**Rationale:** A global `0001`, `0002` sequence and shared registry would force
parallel missions to coordinate every new migration.

## Decision 8: ShovelerDB consumption and durability seam

**Decision:** Pin public ShovelerDB commit
`20dced69738bfce08f94368b8d017cfc283747fe`, the accepted GPL-3.0-only engine
commit. Consume it through one narrow invoice-manager adapter; domain code must
not import its handles, SQL, results, or borrowed values. Own one handle per
path and serialize access. The reference deployment runs one Zig API replica
per database path.

Consequential mutation follows this boundary:

`BEGIN -> domain writes/event/idempotency record -> COMMIT -> CHECKPOINT -> acknowledge`

On the supported Linux baseline the application performs one additional step:

`CHECKPOINT -> fsync(database parent directory) -> acknowledge`

If commit succeeds but checkpoint or parent-directory sync fails, retry only the
persistence-completion boundary and report `durability_unconfirmed`; do not
replay the mutation blindly. During ordinary successful shutdown, checkpoint
and directory-sync committed durable state before close. A dirty failed-startup
or durability-uncertain handle must instead be discarded/closed without a new
checkpoint and reopened from the last confirmed durable snapshot; never persist
the state being rejected. Startup migrations are forward-only, idempotent, checkpointed, and
directory-synchronized before traffic is served. Since ShovelerDB DDL is not
session-transactional, a failed migration discards the dirty handle without
checkpointing and reopens the last durable snapshot.

**Rationale:** ShovelerDB commit publishes an in-memory generation while an
explicit checkpoint persists it. Close does not checkpoint. The ABI requires
shared-handle serialization, has no foreign keys or application-column
uniqueness, and accepts SQL strings without bound parameters.

**Packaging resolution:** WP04 consumes the pin as an unmodified `git archive`
source export committed under `deps/shovelerdb/`. `deps/shovelerdb/PROVENANCE`
records the public source URL, exact commit, included paths, and deterministic
source-tree digest. The build uses no submodule, sibling checkout, or floating
branch and remains reproducible from a clean clone.

**Safety requirements:** IDs, references, deletion guards, idempotency, and
application uniqueness are enforced by Zig while holding the serialized write
boundary. SQL identifiers are compile-time constants. One centralized literal
encoder rejects embedded NUL and is tested against quotes, semicolons, comment
markers, slashes, Unicode, and newlines. PDFs and logos stay outside the
database; only metadata, paths, versions, and digests are stored.

## Decision 9: Validation and licensing

**Decision:** Establish independent contract, Zig, web, persistence-integration,
HTTP-contract, migration-negative, and license jobs. P0 creates real assertions
for current surfaces, not empty future PDF or browser jobs.

The GPL-3.0-only audit covers runtime npm/Zig dependencies, fonts, TeX packages,
and distributed container contents. Under the owner-approved GPL-3.0-only
policy, Apache-2.0 runtime code is compatible when its license and notice
evidence is preserved. GPL-2.0-only combined-runtime material remains
incompatible and must be excluded. The distributed ShovelerDB engine is
GPL-3.0-only at the accepted pin; its separately GPL-2.0-only MariaDB reference
material remains outside the engine and runtime export.

## Acceptance evidence required from P0

1. A clean-clone build using only documented pinned inputs.
2. Deterministic contract composition and generated-type compilation.
3. Duplicate contract and invalid fixture rejection.
4. Migration first-run, second-run no-op, duplicate, missing-dependency, cycle,
   and checksum-drift cases.
5. Real ShovelerDB create/migrate, transaction, rollback, checkpoint,
   parent-directory sync, close, reopen, and verification through the public
   storage seam.
6. Corrupt-file refusal, checkpoint failure, injected directory-sync failure,
   and process termination at each persistence boundary.
7. Black-box Zig health and Next.js same-origin proxy smoke tests.
8. License audit with preserved dependency notices.

## Open risks and routed follow-ups

- The ShovelerDB packaging blocker is resolved for P0 by the committed
  exact-commit source export. Any future upstream package adoption must preserve
  the source pin, provenance, and clean-clone reproducibility.
- ShovelerDB does not sync the containing directory after snapshot rename. P0's
  Linux adapter therefore syncs the database parent directory before
  acknowledgment; P3 later verifies the deployed filesystem and mount preserve
  that supported behavior.
- ShovelerDB snapshots are capped at 128 MiB. P3 must monitor the database and
  document backup/restore limits; binary artifacts remain external.
- P1-P6 may occasionally need shared build changes after P0. Assign a persistent
  integration steward rather than making P7, whose domain is reporting
  integration, the implicit owner of all root files.
- Exact invoice-domain rules remain owned by their feature missions and are not
  pre-decided here.
