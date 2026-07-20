# Data Model: P2 Invoice Document Engine

## CanonicalQuantity

A positive canonical decimal string with one to six optional fractional digits.
No sign, exponent, whitespace, trailing decimal point, or noncanonical leading
zero is accepted. Zig parses it into a scaled `i128` numerator and decimal scale.

## InvoiceLineDraft

- `id`, `display_order`, bounded plain-text `description`.
- `pricing` tagged union:
  - `fixed.amount: Money`; or
  - `quantity_rate.quantity`, `unit_label`, `unit_rate: Money`.
- `tax: TaxTreatment`.

Amounts/rates are non-negative in v1. All Money currencies equal the document
currency. At least one and at most 200 lines are accepted.

## TaxTreatment

- `treatment`: Standard, ZeroRated, Exempt, ReverseCharge, or OutOfScope.
- `label`: bounded plain text.
- `rate_ppm`: present for Standard (`1..1000000`) and ZeroRated (`0`).
- `note`: required for ReverseCharge and optional only where the schema permits.

Calculated tax is stored per line. The invoice total is the checked sum of
already-rounded line tax, never a second aggregate tax calculation.

## InvoiceDocumentDraftV1

- schema version, document ID, English language, Letter/A4 paper.
- optional document number for preview; final freeze requires one.
- issue/due dates and optional billing period/reference.
- P1 source identifiers/revisions plus complete displayed issuer/recipient.
- identity provenance, explicit Billing Market, coherent remittance variant.
- Project display context; logo mode plus digest-addressed PNG reference.
- USD/EUR document currency and frozen minor-unit exponent.
- ordered line inputs, payment terms, bounded notes.
- server-known template ID/version.

The draft has no trusted subtotal, tax, total, TeX, path, or runtime option.

## EvaluatedInvoiceDocumentV1

Contains normalized draft fields, each original pricing/tax expression, each
authoritative net/tax/gross Money, checked subtotal/tax/total, grouped tax
summaries, evaluation revision, and render-payload digest. It has no PDF or
issued lifecycle state.

## InvoiceDocumentSnapshotV1

An immutable value object with all displayed text and calculations, source IDs
and revisions for traceability, currency/display exponent, explicit remittance
absence or complete block, logo digest/reference, template ID/version/source
digest, schema version, snapshot digest, and render-payload digest. Rendering
never rereads mutable P1 records.

## TemplateManifest

- immutable template family/version and source digest.
- supported document-schema versions and paper sizes.
- exact TeX runtime/source image digest and package manifest digest.
- font files, digests, licenses, and missing-glyph policy.
- fixture catalog, semantic assertions, rasters, pagination limits.

## RenderRecipe

A canonical record binding render-payload, template source, font/package
manifest, normalized logo, and renderer-runtime digests. Its SHA-256 digest is
separate from both snapshot and PDF artifact digests.

## StagedArtifactReceipt

- artifact digest and byte length.
- snapshot digest and render-recipe digest.
- template source, font/package, runtime, and optional logo digests.
- private staged reference valid only for P5's controlled handoff.

The receipt conveys no issued state, durable number ownership, or retention
guarantee.

## Renderer Workspace

Ephemeral, mode-0700, request-unique workspace containing fixed-name generated
TeX, optional normalized logo, and output. It is reachable only inside the
child's OS sandbox. It is deleted on every success/error/timeout path and never
appears in public responses.
