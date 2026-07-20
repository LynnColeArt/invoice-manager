# Mission Specification: P4 Reporting Dashboard

**Mission Branch**: `feat/p4-reporting-dashboard`  
**Created**: 2026-07-19  
**Status**: Ready for Planning  
**Input**: Provide deterministic per-currency revenue, collection, outstanding,
aging, forecast, client/project, and due-work analytics with accessible charts.

## Intent Summary

The owner opens one dashboard and understands what was invoiced, what was
collected, what remains outstanding or overdue, which clients/projects drive the
business, and what work is due next. Every monetary answer is exact and separated
by currency. Every chart has an equivalent accessible table.

P4 owns a derived, rebuildable reporting projection and query surface. It does
not issue invoices, record/reverse payments, decide schedules, mutate source
domains, or convert currencies. During concurrent planning it consumes P4-owned
synthetic normalized reporting snapshots carried in the P0 event envelope; P7
later maps real P1/P5/P6 producer contracts into this frozen seam.

## User Scenarios & Testing

### User Story 1 - See Revenue and Collections (Priority: P1)

As the owner, I can choose a date range and see invoiced and collected amounts
over time, per currency, with exact definitions and source-detail links.

**Independent Test**: Replay issue, payment-allocation, reversal, void, and
correction fixtures and compare exact USD/EUR series and tables.

**Acceptance Scenarios**:

1. **Given** an issued non-void invoice, **When** its issue date is in range,
   **Then** its exact total contributes to Invoiced in its currency.
2. **Given** an active payment allocation, **When** its receipt date is in range,
   **Then** its exact amount contributes to Collected in the invoice currency.
3. **Given** a reversed allocation, void, or correction, **When** projected,
   **Then** the current projection restates the affected historical bucket rather
   than adding an unexplained current-period delta.
4. **Given** USD and EUR facts, **When** viewed, **Then** they are never summed or
   converted into one number.

---

### User Story 2 - Understand Outstanding and Aging (Priority: P1)

As the owner, I can select an as-of date and see outstanding balances, overdue
amounts, aging buckets, and invoice/client detail.

**Independent Test**: Project partial/full/reversed allocations and due-date
boundaries at a fixed as-of date.

**Acceptance Scenarios**:

1. **Given** an issued invoice and allocations received on or before as-of,
   **When** outstanding is calculated, **Then** it equals exact invoice total
   minus active eligible allocations.
2. **Given** outstanding above zero and due date before as-of, **When** summarized,
   **Then** it is overdue; due date equal to as-of is not overdue.
3. **Given** an overdue invoice, **When** aged, **Then** it appears in exactly one
   of 1–30, 31–60, 61–90, or 91+ days.
4. **Given** a void invoice, **When** reported, **Then** it contributes no current
   invoiced, outstanding, overdue, or aging amount.

---

### User Story 3 - See Forecast and Due Work (Priority: P1)

As the owner, I can see overdue backlog, work due today, and upcoming billable
work without P4 advancing a project or creating an invoice.

**Independent Test**: Replay priced/unpriced due-work snapshots around a fixed
as-of date and horizon.

**Acceptance Scenarios**:

1. **Given** open priced work before as-of, **When** forecasted, **Then** its amount
   appears in Backlog in its currency.
2. **Given** work on as-of, **Then** it appears in Due Today; after as-of through
   the selected horizon appears in Upcoming.
3. **Given** unpriced due work, **Then** it increments an explicit unpriced count
   but contributes to no monetary total.
4. **Given** the dashboard, **When** due work is viewed, **Then** P4 performs no
   schedule advancement, draft generation, completion, or source mutation.

---

### User Story 4 - Compare Clients and Projects (Priority: P2)

As the owner, I can rank/filter clients and projects by invoiced, collected,
outstanding, overdue, and forecast amounts per currency.

**Independent Test**: Query a synthetic portfolio with inactive clients,
completed projects, multiple currencies, corrections, and equal-value ties.

**Acceptance Scenarios**:

1. **Given** tied metrics, **When** ranked, **Then** deterministic secondary keys
   produce stable order.
2. **Given** archived labels, **When** history is viewed, **Then** historical facts
   retain meaningful source labels without reopening mutable domain state.
3. **Given** a summary row, **When** opened, **Then** detail reconciles exactly to
   the displayed aggregate at the same as-of date and projection watermark.

---

### User Story 5 - Trust Replay and Freshness (Priority: P1)

As the owner/operator, I can see projection freshness and rebuild analytics from
the normalized input log without changing the result.

**Independent Test**: Ingest duplicates, out-of-order source revisions,
corrections, reversals, and a full replay at a fixed clock.

**Acceptance Scenarios**:

1. **Given** the same source kind/ID/revision repeats, **When** ingested, **Then**
   it is idempotent and does not double count.
2. **Given** a stale aggregate revision, **When** received, **Then** it cannot
   overwrite a newer normalized snapshot.
3. **Given** the durable normalized log and projection version, **When** rebuilt in
   local ingest sequence, **Then** canonical projection/query results are identical.
4. **Given** a query, **Then** it exposes both business `as_of_date` and projection
   watermark/freshness; neither is substituted for the other.

---

### User Story 6 - Use Charts Accessibly (Priority: P1)

As the owner, I can understand and operate every dashboard view with keyboard,
screen reader, high zoom, and non-color cues.

**Independent Test**: Complete range/currency/filter/drill-down workflows with
keyboard and use only table alternatives at 200% zoom.

### Edge Cases

- Payment is received after the selected as-of date.
- Allocation is reversed after an earlier report period.
- Invoice correction changes amount, issue date, due date, Client, or Project.
- Source revisions arrive out of order or duplicate after restart.
- Invoice is due exactly on as-of date.
- A due-work item is unpriced or changes currency/amount before billing.
- The selected range crosses month, quarter, year, leap-day, or daylight changes.
- One currency has data while another has none.
- An aggregate overflows signed `i64` even though individual facts fit.
- Projection is rebuilding or behind the latest durable ingest.
- A chart has hundreds of categories or all values are zero.

## Metric Definitions

- **Invoiced**: current non-void issued invoice total, bucketed by `issue_date`.
- **Collected**: current non-reversed payment allocation amount, bucketed by
  allocation `receipt_date`, denominated in the invoice currency.
- **Outstanding as of**: non-void invoice total minus active allocations received
  on/before `as_of_date`, per invoice and currency.
- **Overdue as of**: outstanding above zero where `due_date < as_of_date`.
- **Aging**: overdue day difference in 1–30, 31–60, 61–90, or 91+.
- **Forecast**: open normalized due-work amount split into Backlog
  (`due_date < as_of_date`), Due Today (`=`), and Upcoming (`>` through horizon).
  Unpriced work is counted but excluded from money.

Corrections/reversals update the current projection and restate history at the
current projection watermark. Reports are reproducible only when both query
parameters and watermark/projection version are identified.

## Requirements

### Functional Requirements

| ID | Title | User Story | Priority | Status |
| --- | --- | --- | --- | --- |
| FR-001 | Normalized input contract | As P7, I can supply versioned Client, Project, Invoice, PaymentAllocation, and DueWork snapshots in the P0 envelope. | High | Approved |
| FR-002 | Durable idempotent ingest | As the owner, snapshots are durably sequenced locally and deduplicated by source kind/ID/revision. | High | Approved |
| FR-003 | Revision monotonicity | As the owner, accepted aggregate revisions advance exactly by one; stale, conflicting, and gap inputs reject before append. | High | Approved |
| FR-004 | Rebuildable projection | As the operator, I can rebuild the derived projection from normalized inputs for a named projection version. | High | Approved |
| FR-005 | Invoiced metric | As the owner, non-void issued totals are reported by issue date and currency. | High | Approved |
| FR-006 | Collected metric | As the owner, active allocations are reported by receipt date and invoice currency. | High | Approved |
| FR-007 | Outstanding metric | As the owner, invoice total less eligible allocations is exact at an explicit as-of date. | High | Approved |
| FR-008 | Overdue/aging | As the owner, positive outstanding past due is partitioned into four exact aging buckets. | High | Approved |
| FR-009 | Forecast metric | As the owner, open due work is split into backlog/due-today/upcoming; unpriced work is counted separately. | High | Approved |
| FR-010 | Per-currency isolation | As the owner, every amount/series/ranking is currency-qualified and currencies are never netted or converted. | High | Approved |
| FR-011 | Client/project summaries | As the owner, I can rank/filter/drill into exact Client and Project metrics with stable ordering. | High | Approved |
| FR-012 | Source reconciliation | As the owner, every aggregate can drill to contributing normalized facts at the same query/watermark. | High | Approved |
| FR-013 | Time controls | As the owner, I can choose range, bucket grain, as-of date, and forecast horizon with explicit LocalDate semantics. | High | Approved |
| FR-014 | Freshness metadata | As the owner, every response exposes projection version, durable ingest watermark, projected watermark, and rebuild state. | High | Approved |
| FR-015 | Exact Zig queries | As the owner, all metric, date, grouping, sorting, and pagination logic is authoritative in Zig. | High | Approved |
| FR-016 | Dashboard API | As the web, I receive versioned overview, trends, aging, forecast, Client, Project, due-work, and reconciliation queries through P0 envelopes. | High | Approved |
| FR-017 | Accessible chart/table pairs | As the owner, every visualization has an equivalent semantic table, text summary, labels, and non-color cues. | High | Approved |
| FR-018 | Keyboard dashboard | As the owner, all filters, series choices, tooltips/details, tables, pagination, and drill-down are keyboard operable. | High | Approved |
| FR-019 | Empty/error/rebuild states | As the owner, I can distinguish no data, zero values, stale data, rebuild, and query failure. | Medium | Approved |
| FR-020 | Synthetic fixtures | As concurrent missions, we share valid/invalid normalized snapshots and expected exact query results before real P5/P6 producers exist. | High | Approved |
| FR-021 | Projection migrations | As the operator, P4 projection tables use forward-only owner-scoped migrations and can be discarded/rebuilt without source loss. | High | Approved |
| FR-022 | No source mutation | As the owner, reporting endpoints and UI cannot alter Invoice, Payment, Project, Client, or schedule state. | High | Approved |
| FR-023 | Integrity exceptions | As the owner, currency mismatch, orphan/overapplied allocation, unknown dimension, overflow, and projection lag are explicit rather than hidden. | High | Approved |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| NFR-001 | Exact arithmetic | All per-fact and aggregate Money uses checked signed integers; overflow is a visible failure, never wrap/saturation. | Correctness | High | Approved |
| NFR-002 | Replay determinism | Twenty rebuilds of the same normalized log/version yield byte-equivalent canonical query fixtures. | Determinism | High | Approved |
| NFR-003 | Idempotency | Duplicate input produces zero duplicate facts or metric change in 100% of tests. | Integrity | High | Approved |
| NFR-004 | Metric reconciliation | Every displayed aggregate exactly equals its contributing detail for the same parameters/watermark. | Correctness | High | Approved |
| NFR-005 | Query responsiveness | Representative 10,000-invoice/allocation and 5,000-due-work data returns overview/trends/aging within one second p95 locally. | Performance | High | Approved |
| NFR-006 | Dashboard responsiveness | Initial representative dashboard content is usable within two seconds after response on the reference browser. | Performance | Medium | Approved |
| NFR-007 | Projection recovery | Restart/replay after each durable ingest boundary loses zero acknowledged inputs. | Durability | High | Approved |
| NFR-008 | Domain coverage | P4 Zig projection/metric/query code maintains at least 90% coverage and covers every boundary/correction/reversal/overflow branch. | Testability | High | Approved |
| NFR-009 | Accessibility | Dashboard meets WCAG 2.2 AA automated checks plus keyboard, screen-reader table, focus, zoom, and non-color acceptance. | Accessibility | High | Approved |
| NFR-010 | Privacy | Reporting inputs/outputs/logs contain no bank details, PDF contents, session secrets, or unnecessary contact/address fields. | Privacy | High | Approved |
| NFR-011 | Contract isolation | P4 modifies no source-domain path/registry and composes deterministically with P0. | Delivery | High | Approved |
| NFR-012 | Synthetic public data | All fixture clients/projects/invoices/payments are invented and safe for the GPL repository. | Privacy | High | Approved |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| C-001 | Draft gate | P4 plans against P0 `0.1.0-draft.1`; implementation waits for Frozen P0 and a reviewed synthetic input contract. | Dependency | High | Approved |
| C-002 | Synthetic producer seam | P4 must not invent final P5/P6 events; P7 later maps frozen real producer contracts into the P4 normalized seam. | Architecture | High | Approved |
| C-003 | Zig authority | Ingest, projection, metrics, dates, sorting, pagination, and reconciliation are Zig-owned; Next.js only presents. | Architecture | High | Approved |
| C-004 | P0 Money | Canonical decimal-string signed-`i64` Money and LocalDate semantics are reused unchanged. | Correctness | High | Approved |
| C-005 | No FX | USD and EUR are always separate; no conversion, base currency, or cross-currency ranking/net total. | Scope | High | Approved |
| C-006 | Derived storage | P4 projection state is rebuildable and never the source of truth for business lifecycle. | Architecture | High | Approved |
| C-007 | Read-only domain behavior | P4 cannot issue/void/correct invoices, allocate/reverse payments, or create/advance/complete due work. | Scope | High | Approved |
| C-008 | Owner-scoped additions | P4 contributes additive contracts, projection migrations/modules, query/UI paths, and fixtures; shared surfaces use the steward. | Delivery | High | Approved |
| C-009 | As-of separation | Business `as_of_date` and projection watermark are always separate explicit concepts. | Correctness | High | Approved |

### Key Entities

- **NormalizedReportingSnapshot**: Versioned P4-owned Client/Project/Invoice/PaymentAllocation/DueWork source snapshot inside P0 event envelope.
- **IngestRecord**: Durable local sequence, source identity/revision, payload digest, and acceptance outcome.
- **InvoiceFact**: Current issued/void/corrected invoice amount/date/due/client/project/currency state.
- **PaymentAllocationFact**: Current allocated/reversed amount and receipt date tied to an invoice.
- **DueWorkFact**: Current open/closed, due date, optional Money, Client/Project state.
- **ProjectionWatermark**: Projection version and highest fully applied local ingest sequence.
- **ReportingQueryContext**: Range, grain, as-of, horizon, currencies, filters, and watermark.

## Success Criteria

- **SC-001**: Exact expected USD/EUR invoiced, collected, outstanding, overdue,
  aging, and forecast fixtures pass including void/correction/reversal boundaries.
- **SC-002**: Twenty full rebuilds produce byte-equivalent canonical outputs and
  duplicates/stale revisions never double count or overwrite newer state.
- **SC-003**: Every aggregate/detail reconciliation is exact and exposes the same
  as-of date and projection watermark.
- **SC-004**: Representative-scale core queries meet one-second p95 and initial
  dashboard usability meets two seconds.
- **SC-005**: Every chart is fully understandable through keyboard-operable
  semantic tables/text at 200% zoom without color-only meaning.
- **SC-006**: P7 can map frozen P1/P5/P6 fixtures into the P4 normalized contract
  without changing metric semantics or source-domain ownership.

## Explicit Exclusions

Invoice/payment lifecycle; schedule calculation/advancement; accounting ledger,
general ledger, profit, expenses, taxes payable, cash forecasting beyond explicit
due-work facts; FX/consolidated currency; external BI/export; email/alerts;
machine-learning forecasts; source-data editing; auth/deployment/backup; and
final P5/P6 producer event definitions.
