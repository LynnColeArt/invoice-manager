# Implementation Plan: P4 Reporting Dashboard

**Branch**: `feat/p4-reporting-dashboard` | **Date**: 2026-07-19 | **Spec**: [spec.md](spec.md)  
**Contract state**: `0.1.0-draft.1` (planning only)  
**Consumes**: P0 `0.1.0-draft.1`; P4 synthetic normalized inputs  
**Status**: Planned; implementation blocked until P0 is Frozen and the P4 input Draft is reviewed

## Summary

Build a deterministic Zig reporting ingress, replayable projection, exact metric
kernel, read-only API, and accessible Next.js dashboard. P4 consumes P0 common
values/event envelope plus its own normalized absolute snapshots rather than
inventing P5/P6 source events. P7 later maps real producer events into the Frozen
P4 seam without changing metric semantics.

## Technical Context

**Language/Version**: Zig 0.16.0; TypeScript 6.0.3; Node.js 24.18.0 LTS  
**Primary Dependencies**: Next.js 16.2.10; React/React DOM 19.2.7; P0
`0.1.0-draft.1`; ShovelerDB commit
`fc7539a3874293540a4de6d228b3ea670a8ca2e8`; OpenAPI 3.1; JSON Schema 2020-12  
**Storage**: P0-serialized ShovelerDB accepted-input log plus derived versioned
reporting projections; no second analytics database  
**Testing**: Pure Zig metric/property/coverage tests, schema fixtures, replay and
close/reopen, shadow rebuild, black-box queries, cross-view reconciliation,
representative performance, component/keyboard/axe/Playwright accessibility  
**Target Platform**: Linux x86_64 local/private deployment  
**Project Type**: One repository with Zig projection/API and Next.js dashboard  
**Performance Goals**: Representative core queries p95 under one second; initial
dashboard usable within two seconds; 45,000-record rebuild under 60 seconds  
**Constraints**: GPL-2.0-only, read-only source behavior, USD/EUR separated, no FX,
no browser money arithmetic, Draft inputs only until freeze  
**Scale/Scope**: 1,000 clients, 2,500 projects, 10,000 invoices, 25,000 allocations,
10,000 work items, 24 months

## Charter Check

| Rule | Plan evidence | Result |
| --- | --- | --- |
| Zig authority | Ingest, revisions, replay, dates, metrics, sorting, pagination, and reconciliation are Zig. | Pass |
| Exact money | Checked integer accumulation, canonical strings, no float/FX/cross-currency totals. | Pass |
| ShovelerDB only | Accepted log/projection share the P0 serialized handle; no analytics sidecar. | Pass |
| Durable success | Accepted inputs commit/checkpoint before acknowledgment and survive close/reopen. | Pass |
| Test-first critical behavior | Metric boundaries, replay, correction, overflow, and reconciliation begin red-first. | Pass |
| 90% Zig coverage | Projection/metric/query branches are gated. | Pass |
| Accessibility | Every chart has exact semantic table/text and keyboard/non-color/zoom acceptance. | Pass |
| Swarm isolation | P4 owns normalized input/projection/UI paths; P7 owns producer adapters. | Pass |

No charter exception is planned.

## Data Flow and Ownership

```text
Synthetic JSONL loader or future P7 adapter
                    |
        P0 envelope + P4 snapshot schema
                    |
       ID/digest/exact-next-revision check
                    |
      durable accepted-input log + checkpoint
                    |
       incremental or shadow rebuild projection
                    |
             pure Zig metric kernel
                    |
         read-only /api/v1/reporting/*
                    |
       Next.js cards/charts/semantic tables
```

Owned paths:

```text
contracts/api/v1/fragments/p4/
contracts/events/v1/payloads/p4/
contracts/fixtures/p4/v1/
contracts/manifests/p4.json
services/api/migrations/p4/<uuidv7>/
services/api/src/domains/reporting/
services/api/tests/reporting/
apps/web/src/features/reporting/
```

The aggregate contract/router, generated client, global navigation, root builds,
locks, and CI are steward-owned. P4 supplies one mount/integration request.

## Normalized Input Contract

P4 defines absolute snapshot payloads inside the unchanged P0 event envelope:

- Client: ID, display label, Active/Archived.
- Project: ID, Client ID, label, USD/EUR currency, monthly/quarterly cadence,
  lifecycle.
- Invoice: ID, Client/Project IDs, issue/due dates, total Money, Issued/Void.
- PaymentAllocation: allocation/payment/invoice IDs, receipt date, Money,
  Applied/Reversed.
- DueWork: item/Project ID, due date, optional Money, Open/Billed/Cancelled.

The payload contains a source aggregate ID and canonical revision. Accepted
revision must be exactly the preceding accepted revision plus one. Identical
event ID/content is a no-op; event/content conflict, type conflict, stale/gap
revision, currency mismatch, orphan/overapplication, and overflow are explicit
errors or integrity exceptions per the frozen fixture.

Local ingest sequence is assigned within the durable P0 mutation and is the
canonical replay order. Synthetic JSONL line order is authoritative. Absolute
snapshots allow correction, void, reversal, billed, and cancelled state without
P4 importing producer transition rules.

## Projection Design

Owner-scoped tables store accepted input/digest, last accepted aggregate revision,
projection generation/checkpoint, dimensions, invoice/allocation/due-work facts,
health, and integrity exceptions. Current facts contain one latest snapshot per
aggregate per generation.

Normal application advances incrementally. A rebuild creates a shadow generation,
replays all accepted records in local sequence, verifies counts/canonical digest,
then atomically changes the active-generation pointer. Failure leaves the previous
generation readable. Derived projection state can be discarded; accepted input
is the replay source.

Every query returns active generation, projected and accepted watermarks, lag,
rebuild/stale state, reporting timezone, exact business dates, and filters.
`as_of_date` controls business inclusion and never substitutes for watermark.
Current-knowledge corrections restate earlier date buckets at the current
watermark; P4 does not promise bitemporal accounting history.

## Metric Kernel

All formulas use checked wider intermediates and return P0 Money or a stable
overflow error. Each response is partitioned by currency.

- Invoiced: current Issued/non-Void totals by issue date.
- Collected: current Applied/non-Reversed allocation Money by receipt date.
- Outstanding: valid invoice total minus eligible allocations received on/before
  as-of. Overapplication is an integrity exception, not silently hidden.
- Overdue: positive outstanding with due date strictly before as-of.
- Aging: calendar days past due in 1–30, 31–60, 61–90, or 91+ exactly once.
- Forecast: open due work through the horizon, split before/equal/after as-of.
  Unpriced work increments count and never contributes Money.
- Next due: earliest open work date without a horizon restriction.

Trends bucket Invoiced by issue date and Collected by receipt date. Range dates
are inclusive and period end may not exceed as-of. Month/quarter boundaries use
the configured reporting timezone; the browser sends concrete LocalDates.
Client/Project summaries and detail reconciliation call the same pure kernel.

## Read API

- `GET /api/v1/reporting/overview`
- `GET /api/v1/reporting/clients`
- `GET /api/v1/reporting/projects`
- `GET /api/v1/reporting/due-work`
- `GET /api/v1/reporting/projection-health`

Queries accept concrete as-of, inclusive period start/end, inclusive horizon,
month/quarter grouping, and optional currency/Client/Project filters. Omitting
currency returns a stable array of partitions, never combined Money. Detail uses
bounded cursor pagination and deterministic ID tie-breaks. All endpoints are
read-only and later attach to P3's Zig authorization hook.

## Dashboard UX

The dashboard presents explicit as-of/range/horizon/filter/freshness, separate
currency sections, Invoiced/Collected/Outstanding/Overdue/Forecast cards,
invoiced-versus-collected trend, aging, due-work partition, Client/Project tables,
and projection/integrity status.

Each chart is paired with the exact semantic table driving it and a concise text
summary. Series use label/marker/line differences in addition to color. All
filters, details, tooltips/equivalents, sorting, pagination, and drill-down are
keyboard operable. Loading/refreshed/stale/empty/error states are announced
without surprise focus movement. Money strings use BigInt-safe formatters; chart
geometry may approximate pixels but never labels/sorts/totals/thresholds.

## Golden Fixtures

At as-of 2026-07-20, the golden USD ledger proves:

- Invoice A: total `100000`, due 2026-06-30; allocation `25000` on 2026-07-05.
- Invoice B: total `50000`, due 2026-07-20; later allocation excluded.
- Expected: Invoiced `150000`, Collected `25000`, Outstanding `125000`,
  Overdue/1–30 `75000`, Current `50000`, older aging zero.

An independent EUR invoice/allocation proves Invoiced/Collected `80000` and zero
outstanding without any USD+EUR field. Forecast fixtures prove Backlog `120000`,
Due Today `10000`, Upcoming `30000`, Total `160000`, plus one unpriced item.

Invalid fixtures cover duplicate/conflicting event IDs, revision gaps/stale data,
orphan/overapplied/cross-currency allocations, date/range boundaries, unknown
dimensions, checked overflow, interrupted ingest, projection lag, and failed
shadow rebuild.

## Verification Strategy

- Compose P0/P4 schemas and validate all valid/invalid/golden/scale fixtures.
- Pure Zig table/property tests for every metric, date, aging, correction,
  reversal, currency, allocation, and overflow boundary.
- Prove positive outstanding occupies exactly one current/aging bucket.
- Cross-check overview/trend/Client/Project/due-work detail under identical query.
- Real ShovelerDB checkpoint-close-reopen input and projection tests.
- Replay 20 times and compare fact counts, canonical projection digest, and API.
- Fail shadow rebuild at every stage and retain prior active generation.
- Black-box read API pagination/filter/error/auth-hook tests.
- Component/keyboard/table-equality/axe/zoom/responsive/status tests.
- Run the 45,000-record scale corpus against p95/rebuild/browser targets.

## Contract Lifecycle and Handoff

P4 `0.1.0-draft.1` permits planning and synthetic consumer/producer review only.
Implementation waits for Frozen P0 plus approval of the normalized Draft. P4
promotion requires real ingest/replay/metric/query/accessibility/scale evidence.

P7 later consumes Frozen P1/P5/P6 events and produces each normalized P4 payload.
Adapter verification must use mutual fixtures and cannot edit P4 metric semantics
or storage. P4 remains read-only and does not dual-write source domains.

## Implementation Concerns

| Concern | Scope | Depends on | Parallel opportunity |
| --- | --- | --- | --- |
| IC-01 | P4 schemas/manifest plus golden/invalid/scale fixtures | P0 Draft | Opens all lanes |
| IC-02 | Pure Zig date/money/metric/aging/forecast/grouping kernel | IC-01 | Parallel with ingress and web shell |
| IC-03 | Durable ingest, exact revisions, accepted log, replay | IC-01; P0 Frozen for implementation | Parallel with metrics |
| IC-04 | Versioned projections, queries, read APIs, health | IC-02, IC-03 | Query groups parallelize |
| IC-05 | Fixture-backed typed client, formatters, dashboard shell | IC-01 | Parallel before live API |
| IC-06 | Shadow rebuild, integrity, durability, performance | IC-03, IC-04 | Failure and scale lanes |
| IC-07 | End-to-end reconciliation, accessibility, docs, handoff | IC-04–IC-06 | Integration lane |

These are concerns, not work packages. Task generation waits for the Draft review.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| P5/P6 meanings drift | P4 normalized contract plus P7 adapter/fixture review. |
| Draft P0 changes | Exact version/digest gate and revalidation before tasking. |
| Corrections surprise historical viewers | Current-knowledge definition and visible generation/watermark. |
| Missing/reordered revisions corrupt facts | Exact-next validation before durable append. |
| Projection bug silently changes totals | Accepted log, golden ledger, canonical digest, shadow rebuild, reconciliation. |
| Integer/browser precision loss | Checked Zig arithmetic and string/BigInt-safe presentation. |
| Currency mixing | Currency partitions and explicit prohibition on combined totals/ranking. |
| Forecast mistaken for guaranteed revenue | Label Expected billing and expose horizon/backlog/unpriced counts. |
| Charts exclude users | Equivalent table/text, keyboard, non-color, focus/zoom acceptance. |
| Large scans slow UI | Indexed current facts, bounded pages, scale corpus, p95 gate. |
| P3 security is not ready | No public exposure; attach to Frozen auth hook at integration. |

## Planning Exit Criteria

- Metric/date/correction/replay definitions agree across spec, model, and plan.
- Draft input schema/manifest parse and record the P0 planning dependency.
- Golden expected values are independently calculable.
- P4/P7/source-domain boundaries are explicit.
- Accessibility and representative-scale evidence are planned.
- Mission is parked before task generation pending cross-mission Draft review.

