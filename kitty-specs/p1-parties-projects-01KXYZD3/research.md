# P1 Parties and Projects Research

## Research question

What configuration model gives one consulting-business owner an unsurprising
client manager while producing stable, privacy-safe inputs for document,
issuance, scheduling, and reporting missions?

## Decision 1: Bounded context and ownership

**Decision:** P1 owns Billing Identity, Postal Address, Remittance Profile,
Logo Asset metadata/content ingestion, Client, Billing Contact, Project, and a
resolved invoice-configuration view. It does not own invoice lines, snapshots,
PDFs, numbering, issuance, payments, schedule advancement, or analytics.

**Rationale:** The owner needs all consequential “who bills whom, under which
contract defaults” facts in one context. Keeping downstream lifecycle behavior
out of P1 lets P2, P5, and P6 consume a stable configuration snapshot without
competing for master-data files.

## Decision 2: Launch currencies

**Decision:** Launch with USD and EUR enabled. The wire format remains an ISO
4217-style uppercase code from P0; the enabled-currency allowlist is
configuration owned by P1. No FX conversion exists.

**Rationale:** USD covers domestic billing and EUR covers the stated European
workflow. Adding a currency later is an allowlist/configuration change, not a
wire-contract change. Every project selects exactly one currency.

**Alternatives considered:** Enabling every structurally valid currency was
rejected because minor-unit rules and real acceptance fixtures would be
unbounded. GBP was not assumed to be European billing currency because the
user asked for Europe generally, not a UK-specific launch requirement.

## Decision 3: Billing Identity

**Decision:** A Billing Identity is either Personal or Company and stores a
display label, legal name, postal address, email/phone, optional tax identifiers,
default payment terms, optional default logo, and active state. Invoice-number
sequence configuration is reserved for P5; P1 may store an operator-facing
preferred prefix but cannot allocate or mutate a counter.

Deactivation prevents selection for new clients/projects and resolution for new
drafts. It never changes historical documents. Deletion is allowed only before
any references exist; otherwise the identity is deactivated.

## Decision 4: Explicit billing market and remittance

**Decision:** Client billing market is `domestic`, `europe`, or `other` and is
never inferred from an address. `other` requires an explicit show/hide choice.

The European Remittance Profile requires:

- account holder;
- bank name;
- IBAN;
- BIC/SWIFT;
- remittance currency (USD or EUR).

Bank address and short payment instructions are optional. The profile is
stored on a Billing Identity. P1 validates completeness and canonicalizes IBAN
and BIC spacing/case, but does not claim banking-network or legal certification.

Resolution returns no remittance fields at all for `domestic`, returns a
complete profile for `europe`, and follows the explicit flag for `other`.
Required-but-incomplete resolution is an error. Logs, list responses, audit
summaries, and validation messages redact account data.

## Decision 5: Client defaults

**Decision:** Every active Client has one active default Billing Identity, one
enabled default currency, default payment terms in whole calendar days, a
structured billing address, and at least one billing contact email before it is
ready for project creation. Draft clients may be incomplete; readiness is an
explicit validated state rather than a partial-save failure.

**Rationale:** This supports incremental data entry while preventing downstream
configuration errors from being discovered only at invoice time.

## Decision 6: Project overrides and cadence facts

**Decision:** Project identity mode is `client_default` or `explicit`. Explicit
mode requires an active Billing Identity and is visibly labeled in the editor
and resolved view. Project logo mode is `on` or `off`; `on` may select a
project-specific approved asset or fall back to the effective identity's active
default asset. Missing asset is a readiness error.

P1 stores cadence (`monthly` or `quarterly`), schedule anchor, next billing
date, optional end date, default currency, payment terms, default service
description, and optional default amount. P1 validates these facts but never
advances the schedule or creates a draft; P6 owns that behavior.

## Decision 7: Logo assets

**Decision:** MVP accepts PNG logo assets up to 2 MiB. The Zig service
validates declared and decoded type, size, and dimensions, computes
SHA-256, assigns an application-owned opaque path, and records active state.
Original filenames are never used as storage paths. P2 owns sandboxed rendering
and may impose stricter render compatibility.

**Rationale:** PNG provides a bounded raster baseline and avoids the active
content, parser, and external-reference risks of PDF and SVG inputs.

## Decision 8: Resolved configuration contract

**Decision:** P1 publishes a versioned resolved configuration for one Project:
effective Billing Identity, Client recipient/contact/address, billing market,
remittance visibility and complete block when allowed, currency, payment terms,
cadence facts, logo mode/asset metadata and digest, and source provenance for
every inherited/overridden value.

The view is current configuration, not an invoice snapshot. P2 may preview it;
P5 freezes it during issuance. All consumers must treat master-data edits as new
configuration rather than retroactive history.

## Decision 9: API, events, and migrations

**Decision:** P1 contributes namespaced `/billing-identities`, `/clients`,
`/projects`, and `/logo-assets` OpenAPI fragments beneath P0 `/api/v1`. Mutations
use P0 envelopes, stable error codes, and idempotency keys where file ingestion
or retry could duplicate state.

P1 owns configuration lifecycle events such as identity/client/project changed
or deactivated. These are business facts for consumers, not reporting
projections. Each payload version is mission-owned and uses the P0 event
envelope. P1 migrations live under its owner directory with UUIDv7 IDs and no
edits to P0's registry or bootstrap migration.

## Decision 10: UI behavior

**Decision:** Provide searchable lists and focused detail/edit forms for
identities, clients, contacts, assets, and projects. Consequential choices use
the label “Invoice header / billed from,” show inheritance versus override, and
display a resolved invoice-configuration summary before a project is marked
ready.

Bank values are masked by default with a deliberate reveal action. Keyboard
operation, visible focus, error summaries, field associations, and non-color
override indicators are acceptance requirements.

## Risks and routed follow-ups

- Actual tax/VAT calculation and invoice fields belong to P2/P5; P1 stores only
  party tax identifiers as opaque labeled values.
- P5 owns immutable snapshots and invoice-number sequence allocation.
- P6 owns billing periods, advancement, due-state derivation, and idempotent
  draft proposals.
- P3 owns authentication, authorization enforcement, filesystem permissions,
  backups, and restore. P1 still prevents sensitive values from logs/responses.
- IBAN/BIC validation checks structure/check digits only and is not proof that
  an account exists or is legally sufficient.
- P0 contracts are Draft. P1 planning may proceed; implementation waits for the
  consumed P0 versions to become Frozen.
