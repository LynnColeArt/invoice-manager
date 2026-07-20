# Implementation Plan: P1 Parties and Projects

**Mission**: `p1-parties-projects-01KXYZD3`  
**Branch**: `feat/p1-parties-projects`  
**Contract state**: `0.1.0-draft.1` (planning only)  
**Consumes**: P0 `0.1.0-draft.1` from `feat/p0-contract-spine`  
**Status**: Planned; implementation blocked until the consumed P0 contracts are Frozen and merged

## Outcome

P1 establishes the mutable master-data boundary for Billing Identities, Clients,
Billing Contacts, Logo Assets, and Projects. It gives the owner an internal
Next.js manager backed by Zig-owned validation and publishes one authoritative
Resolved Invoice Configuration contract for P2, P5, and P6.

P1 does not create invoice documents, allocate invoice numbers, advance billing
schedules, authenticate users, or calculate dashboard metrics.

## Technical Context

**Language/Version**: Zig 0.16.0; TypeScript 6.0.3; Node.js 24.18.0 LTS  
**Primary Dependencies**: Next.js 16.2.10; React/React DOM 19.2.7;
ShovelerDB commit `fc7539a3874293540a4de6d228b3ea670a8ca2e8`; P0
`0.1.0-draft.1`; OpenAPI 3.1; JSON Schema 2020-12  
**Storage**: One P0-serialized ShovelerDB handle plus content-addressed PNG
assets in an application-owned private artifact root  
**Testing**: Zig unit/property/coverage tests, schema and fixture composition,
checkpoint-close-reopen integration, black-box HTTP, TypeScript contract tests,
axe/keyboard/Playwright owner workflows, and license audit  
**Target Platform**: Linux x86_64 development and CI baseline  
**Project Type**: One repository with a Next.js application and Zig API  
**Performance Goals**: Search/filter/detail interactions within two seconds for
500 Clients and 2,000 Projects on the reference deployment  
**Constraints**: GPL-2.0-only, USD/EUR only, integer minor units, no FX,
planning-only until P0 is Frozen, no P2/P3/P5/P6 behavior  
**Scale/Scope**: One internal organization and administrator; 500 Clients,
2,000 Projects, and one serialized database handle

P1 uses the P0 repository layout and toolchain without introducing new root
build, lockfile, aggregate-contract, navigation, or CI ownership. The service is
Zig; Next.js is a presentation client. ShovelerDB is accessed only through P0's
single serialized persistence seam. All accepted mutations follow P0's durable
sequence: begin, validate and write domain state plus idempotency/event facts,
commit, checkpoint, and only then acknowledge success.

Planning consumes these P0 Draft primitives unchanged:

- UUIDv7 `EntityId`, canonical decimal-string `i64`, `Money`, `LocalDate`, and
  `UtcInstant`;
- P0 success/error envelopes and JSON Pointer field errors;
- the versioned domain-event envelope;
- owner-scoped UUIDv7 migrations and generated aggregate conventions;
- manifest lifecycle states and exact consumed-contract digests.

Before implementation, the integration steward must revalidate the P1 Draft
against the Frozen P0 artifacts and record exact digests. P1 implementation is
not authorized against Draft contracts.

## Constitution and Charter Check

| Gate | Design response |
| --- | --- |
| Zig-first backend | Domain rules, asset ingestion, resolution, persistence, queries, and HTTP validation live in Zig. |
| Next.js presentation | Forms and tables use generated contracts and never become the authority for policy or money. |
| ShovelerDB discipline | One shared handle, serialized writes, explicit checkpoint-before-success, close/reopen tests. |
| Exact money | USD/EUR only; canonical integer minor units; no floating point, FX, or cross-currency totals. |
| Privacy | Domestic/hidden variants structurally omit remittance; logs/events/fixtures deny sensitive values. |
| Open-source licensing | GPL-2.0-only compatible runtime dependencies, notices, synthetic fixtures. |
| Swarm safety | P1 writes only its additive feature/contract/migration paths; shared surfaces are steward-owned. |
| Verification | Red-first domain policy tests, HTTP persistence tests, accessibility checks, contract composition. |

No charter exception is planned.

## Ownership and Repository Shape

```text
contracts/api/v1/fragments/p1/
contracts/events/v1/payloads/p1/
contracts/fixtures/p1/v1/
contracts/manifests/p1.json
services/api/migrations/p1/<uuidv7>/
services/api/src/domains/parties_projects/
services/api/tests/parties_projects/
apps/web/src/features/billing-identities/
apps/web/src/features/clients/
apps/web/src/features/projects/
apps/web/src/app/**/billing-identities/
apps/web/src/app/**/clients/
apps/web/src/app/**/projects/
```

P1 must not directly edit the aggregate OpenAPI document, generated TypeScript,
global navigation, root builds, or shared router. It publishes fragments and an
integration request; the P0-named steward composes shared outputs.

## Domain Architecture

The `parties_projects` bounded context is divided into four aggregates and one
read-only resolver:

1. **BillingIdentity** owns personal/company legal display data, tax identifiers,
   optional European remittance, default terms, and an optional default logo.
2. **Client** owns recipient data, contacts, explicit market, currency, terms,
   default identity, Draft/Active/Archived status, and readiness diagnostics.
3. **Project** owns client association, cadence facts, amount/description,
   inherited or explicit identity choice, logo On/Off, and lifecycle status.
4. **LogoAsset** owns immutable content digest and safe application path. V1
   accepts decoded, bounded PNG only; replacement creates a new asset.
5. **ResolvedInvoiceConfiguration** combines current aggregate revisions and
   provenance for downstream use. It is mutable master data, not an issued
   invoice snapshot.

The application layer owns commands, idempotency, optimistic revision checks,
readiness transitions, durable event append, and query pagination. Repositories
depend on P0 persistence interfaces; ShovelerDB handles and SQL do not escape the
adapter layer.

## Policy Decision Tables

### Effective Billing Identity

| Project choice | Client default | Result |
| --- | --- | --- |
| Active explicit override | any active default | override; provenance `project_override` |
| No override | active default | client identity; provenance `client_default` |
| Missing/inactive selected identity | any | structured configuration error |

### Remittance

| Billing Market | Other choice | Resolved shape |
| --- | --- | --- |
| Domestic | not permitted | `remittance` property absent |
| Europe | not permitted | complete remittance object or readiness failure |
| Other | Hide | `remittance` property absent |
| Other | Show | complete remittance object or readiness failure |
| Other | missing | readiness failure |

Completeness requires account holder, bank name, canonical checksum-valid IBAN,
8- or 11-character uppercase BIC/SWIFT, and remittance currency. P1 validates
shape and checksum, not account ownership or regulatory compliance.

### Logo

| Mode | Project asset | Identity default | Result |
| --- | --- | --- | --- |
| Off | ignored | ignored | no logo reference |
| On | active compatible asset | any | project asset |
| On | absent | active compatible asset | identity default |
| On | absent/inactive | absent/inactive | readiness failure |

## Data and Persistence Plan

P1 contributes forward-only owner `p1` migrations for billing identities,
remittance profiles, tax identifiers, logo assets, clients, contacts, projects,
and any P1-specific idempotency/event records not supplied by P0.

ShovelerDB does not supply all referential or cross-row constraints needed here,
so the serialized Zig mutation enforces:

- active referenced identity/client/asset checks;
- at most one active primary billing contact per client;
- unique idempotency key and stable replay outcome;
- optimistic expected revision;
- deletion/deactivation guards and atomic reassignment;
- exact enum, date, currency, and Money invariants.

Applied migration contents are immutable. Manifest dependencies are explicit and
UUIDv7-identified; P1 never claims a global migration sequence.

## API and Event Integration

P1 publishes additive `/api/v1` operations for Billing Identities, remittance,
logo assets, Clients/contacts, Projects/status, and resolved configuration.
Creates/uploads/state transitions require an idempotency key; updates require an
expected revision. Lists use a stable opaque cursor and explicit sort.

Stable errors include `validation_failed`, `revision_conflict`,
`idempotency_conflict`, `identity_in_use`, `asset_in_use`, `inactive_reference`,
`unsupported_currency`, `remittance_incomplete`, `logo_unavailable`,
`billing_configuration_incomplete`, and `durability_unconfirmed`.

Events use the P0 envelope and expose only consumer-safe projection facts. No
bank values, notes, postal addresses, tax values, contact emails, or raw asset
paths enter events. P2/P5 use the synchronous resolved contract for sensitive
display data rather than reconstructing it from lossy events.

## Web Plan

Next.js routes provide:

- Billing Identity list/detail/edit/remittance/logo workflows;
- Client search/filter/detail/contact/readiness workflows;
- Project search/filter/detail/edit/resolution workflows;
- explicit labels for “Invoice header / billed from,” inherited versus override,
  remittance inclusion, logo decision, currency, terms, and readiness blockers.

Remittance values are masked by default and require an explicit reveal. Form
checks improve usability only; the Zig response supplies authoritative errors.
Structured JSON Pointer errors map to labeled controls and focus summaries.

## Contract Lifecycle and Consumer Handoff

P1 planning artifacts use `0.1.0-draft.1`. The implementation lane will publish
valid and invalid synthetic fixtures and immutable digests before promotion.

Consumer seams:

- P2 consumes displayed issuer/recipient, market/remittance, logo digest,
  currency/terms, and source revisions to create document snapshots.
- P5 consumes master-data identifiers and a resolved configuration snapshot at
  issuance; it never points issued records at live mutable display data.
- P6 consumes Project status, cadence, anchor, next/end dates, currency,
  recurring amount, and description; only P6 calculates and advances periods.
- P4 may consume minimal Client/Project labels and configuration events but owns
  its own normalized reporting projection.

Any P0 or P1 Draft change requires consumer fixture regeneration and review
before tasking or implementation.

## Implementation Concerns and Dependency Graph

| Concern | Scope | Depends on | Parallel opportunity |
| --- | --- | --- | --- |
| IC-01 | Compose P0 primitives into P1 Draft schemas, API/event fragments, decision fixtures | P0 Draft | Opens all other lanes |
| IC-02 | Shared domain values, readiness and policy tables | IC-01 | Can proceed with migration design |
| IC-03 | Billing Identity, remittance, and Logo Asset domains | IC-02 | Parallel with Clients and Projects |
| IC-04 | Client and Billing Contact domains | IC-02 | Parallel with IC-03/IC-05 |
| IC-05 | Project domain and current resolver | IC-02 | Parallel with IC-03/IC-04 |
| IC-06 | Owner-scoped migrations and repositories | IC-01 | Split by aggregate, integrate before services |
| IC-07 | Durable application services, idempotency, events | IC-03–IC-06 | Commands split by aggregate |
| IC-08 | Resolved configuration and negative security fixtures | IC-03–IC-07 | Can harden in parallel with HTTP |
| IC-09 | HTTP queries/mutations and black-box contracts | IC-01, IC-07, IC-08 | Route groups independently reviewable |
| IC-10 | Identity and Client manager UI | IC-09 | Parallel with Project UI |
| IC-11 | Project manager/resolution UI | IC-09 | Parallel with IC-10 |
| IC-12 | Compatibility, accessibility, durability, and consumer handoff | IC-08–IC-11; P0 Frozen | Integration lane |

This table describes planning concerns, not work packages. The task phase will
slice them only after the Draft contract review is complete.

## Verification Strategy

- Unit/property tests for IBAN/BIC normalization, exact Money/date rules,
  readiness, inheritance, remittance omission, logo resolution, and lifecycle.
- Race/model tests for concurrent deactivation, reassignment, and activation.
- Persistence tests that checkpoint, close, reopen, and compare accepted results.
- Black-box HTTP tests through published envelopes; no repository shortcuts.
- Schema/fixture composition tests against exact P0 digests.
- Secret/canary scans proving bank and asset path values stay out of logs/events.
- TypeScript contract, format, lint, type, unit, build, axe, keyboard, and
  Playwright owner-workflow checks.
- License/notice review for every distributed dependency and PNG decoder.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| P1 absorbs scheduling, rendering, or issuance | Enforce exclusions and owned-path review at every gate. |
| Deactivation breaks future billing | Guard active references and support atomic reassignment. |
| Domestic bank details leak as nullable fields | Distinct omitted/included schema branches and red-first absence tests. |
| P2/P5/P6 reproduce policy differently | One resolver plus frozen decision-table fixtures. |
| Logo decoding expands attack surface | PNG only, bounded bytes/pixels, decoded-type checks, immutable digests. |
| Missing DB constraints create dangling records | Serialize writes and enforce cross-row invariants in Zig. |
| Draft P0 changes underneath P1 | Block implementation; revalidate and regenerate fixtures after P0 freeze. |
| P3 is concurrent and auth is unavailable | Keep P1 test/internal-only; do not invent temporary auth. |
| Shared files collide across missions | Additive fragments; integration steward alone composes shared surfaces. |

## Exit Criteria for Planning

- Specification and requirements checklist contain no unresolved marker.
- Data model, API outline, event vocabulary, and resolved schema agree.
- Draft contracts parse and validate, and consume the exact P0 Draft version.
- Ownership boundaries and integration requests are explicit.
- Implementation remains blocked on P0 Frozen/merged evidence.
- The mission is parked before task generation for cross-mission Draft review.
