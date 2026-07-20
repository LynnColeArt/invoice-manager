# Data Model: P4 Reporting Dashboard

## NormalizedReportingSnapshot

Common fields: schema version, source kind, source ID, canonical revision,
source occurrence instant, payload digest, and typed payload. It is carried in
the P0 event envelope. Types are Client, Project, Invoice, PaymentAllocation, and
DueWork. Payloads include only metric/reconciliation facts, never sensitive bank,
PDF, session, or unnecessary contact/address content.

## IngestRecord

- monotonic local sequence assigned in the P0 durable mutation.
- P0 event identity and source kind/ID/revision.
- payload digest and accepted/duplicate/stale/gap outcome.
- received instant.

Accepted records are immutable. Rebuild replays accepted payloads by local
sequence. Duplicate event identity/digest is idempotent; conflicting content,
stale revision, or any non-next revision is rejected before append.

## ClientFact and ProjectFact

Current reporting labels/status and relationship identifiers. Project additionally
contains configured currency/cadence only when needed for grouping. These facts
do not resolve billing identity or drive scheduling.

## InvoiceFact

- invoice/client/project IDs and stable display labels.
- status: Issued, Void, or Corrected/Superseded representation defined by seam.
- issue and due LocalDates.
- exact total Money and currency.
- source revision and current projection metadata.

Only current non-void issued state contributes to business metrics.

## PaymentAllocationFact

- allocation/payment/invoice IDs.
- receipt LocalDate.
- exact allocated Money matching invoice currency.
- Active or Reversed state and source revision.

P4 does not infer payment ownership or create/reverse allocations.

## DueWorkFact

- work item, Client, and Project IDs/labels.
- Open or Closed state.
- due LocalDate and optional exact Money.
- optional description/cadence label safe for dashboard detail.
- source revision.

Missing Money makes the item Unpriced: counted, never included in money.

## ProjectionWatermark

- projection schema/version.
- highest contiguous fully applied local ingest sequence.
- durable ingest high-water mark and rebuild status.
- last successful rebuild instant and error-safe state.

## Query Models

`ReportingQueryContext` contains inclusive range start/end, bucket grain
(day/month/quarter), as-of date, forecast horizon end, selected currencies,
Client/Project filters, stable sort, cursor, and expected projection version or
watermark where reproducibility is required.

Responses return exact per-currency Money series/summaries, contributing counts,
unpriced counts, table rows, and the complete freshness context.
