# Research: P4 Reporting Dashboard

## Scope and Dependency Strategy

P4 can specify and plan concurrently from P0's event envelope and value types,
but P5/P6 producer events do not yet exist. P4 therefore owns a normalized
snapshot contract and synthetic fixtures. P7 later maps frozen producer contracts
into that seam. This avoids both blocking dashboard design and stealing lifecycle
ownership from future missions.

## Decision 1: Snapshot Projection, Not Delta Arithmetic

Each source aggregate publishes a versioned current normalized snapshot for
Client, Project, Invoice, PaymentAllocation, or DueWork. P4 durably assigns a
local monotonic ingest sequence, deduplicates by source kind/ID/revision, and
applies only increasing revisions. Corrections/reversals replace current facts;
metrics are derived from current facts, preventing double-applied deltas.

The normalized log is source evidence; materialized projection tables are
discardable and rebuilt by local ingest sequence for a named projection version.

## Decision 2: Business Date and Freshness Are Separate

`as_of_date` decides which business facts count. Projection watermark identifies
how much normalized input has been applied. Every query/response records range,
grain, as-of date, forecast horizon, projection version, durable ingest watermark,
projected watermark, and rebuild status. Corrections restate history at the
current watermark; a historical report is reproducible only with both dimensions.

## Decision 3: Exact Per-Currency Metrics

Invoiced uses current non-void issued total by issue date. Collected uses active
payment allocations by receipt date. Outstanding subtracts eligible allocations
received on/before as-of. Overdue requires positive outstanding and due date
strictly before as-of. Aging is 1–30, 31–60, 61–90, and 91+ overdue days.

Forecast uses open normalized due work: Backlog before as-of, Due Today equal to
as-of, Upcoming after as-of through the horizon. Unpriced work is counted but
excluded from monetary totals. USD/EUR are never converted, combined, or ranked
against each other.

## Decision 4: Current Projection Restates History

Void, correction, allocation reversal, and source reclassification update the
historical bucket of the current report instead of adding artificial “change”
revenue to the ingestion date. The displayed watermark makes this explicit.
P4 is operational analytics, not an immutable accounting ledger.

## Decision 5: Accessible Visualization Is Table-First

Charts summarize data already returned by Zig. Each chart has a semantic table,
text summary, explicit units/currency, non-color series styles, keyboard-operable
controls/details, stable ordering, and bounded category counts. No metric exists
only in canvas/SVG pixels. WCAG 2.2 is the accessibility baseline:
https://www.w3.org/TR/WCAG22/

## Decision 6: Representative Scale

Acceptance fixtures model 10,000 invoices/payment allocations and 5,000 due-work
facts across 500 clients/2,000 projects. Core local queries target p95 under one
second and initial rendered content under two seconds. Projection indexes serve
date/currency/client/project/status queries; no browser downloads the full fact set.
