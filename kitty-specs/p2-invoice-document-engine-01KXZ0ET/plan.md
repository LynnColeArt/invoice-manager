# Implementation Plan: P2 Invoice Document Engine

**Branch**: `feat/p2-invoice-document-engine` | **Date**: 2026-07-19 | **Spec**: [spec.md](spec.md)  
**Contract state**: `0.1.0-draft.1` (planning only)  
**Consumes**: P0 `0.1.0-draft.1`; P1 `0.1.0-draft.1`  
**Status**: Planned; implementation blocked until consumed contracts are Frozen and merged

## Summary

Build a stateless Zig invoice-document engine that accepts structured data,
calculates exact line/tax/totals, freezes an immutable display snapshot, and
renders a restrained Letter/A4 PDF through a pinned LuaLaTeX runtime inside an
OS-enforced sandbox. Next.js supplies an accessible review and preview surface.
P2 hands P5 verified staged bytes and a content-addressed receipt but never
allocates a number, issues an invoice, or retains an issued artifact.

## Technical Context

**Language/Version**: Zig 0.16.0; TypeScript 6.0.3; Node.js 24.18.0 LTS;
LuaLaTeX from an exact TeX Live 2026 runtime digest  
**Primary Dependencies**: Next.js 16.2.10; React/React DOM 19.2.7; P0/P1
`0.1.0-draft.1`; OpenAPI 3.1; JSON Schema 2020-12; RFC 8785; RFC 9530  
**Storage**: No ShovelerDB table; request-private temporary workspaces and a
short-lived content-addressed staged handoff owned by the issuance integration  
**Testing**: Zig unit/property/coverage tests, schema fixtures, real sandbox
attacks, LuaLaTeX semantic/raster fixtures, deterministic-byte runs, black-box
HTTP, Next.js accessibility/browser tests, and runtime/font/package license audit  
**Target Platform**: Linux x86_64 with required namespace/filesystem/process
sandbox capabilities; unsupported platforms fail closed for rendering  
**Project Type**: One repository with Next.js presentation, Zig API, and pinned
renderer/template assets  
**Performance Goals**: evaluation under 100 ms; normal preview under ten seconds;
hard render timeout fifteen seconds  
**Constraints**: GPL-2.0-only; exact integer money; USD/EUR; no raw TeX; no
ambient filesystem/network; PNG only; no issuance or business persistence  
**Scale/Scope**: one synchronous owner preview at a time per bounded worker;
maximum 200 lines, 64 KiB text, 20 pages, 10 MiB PDF

## Charter Check

| Rule | Plan evidence | Result |
| --- | --- | --- |
| Zig owns authoritative behavior | Parsing, calculation, snapshot, digest, asset verification, process control, and response validation are Zig. | Pass |
| Next.js is presentation | Web renders returned evaluation and never recalculates totals. | Pass |
| Exact money | P0 decimal-string `i64`, checked `i128` intermediates, one rounding rule, no FX. | Pass |
| Test-first critical logic | Arithmetic, TeX encoding, sandbox, and prohibited-data paths begin red-first. | Pass |
| 90% Zig domain coverage | Calculation/normalization/security branches are explicitly gated. | Pass |
| Privacy | Domestic absence asserted in normalized data, TeX, diagnostics, and PDF text. | Pass |
| GPL-2.0-only | Exact TeX/package/font/rasterizer notices and compatibility are release evidence. | Pass |
| Swarm isolation | Additive P2 paths; root composition and shared router remain steward-owned. | Pass |

No charter exception is planned.

## Owned Structure

```text
contracts/api/v1/fragments/p2/
contracts/documents/v1/p2/
contracts/fixtures/p2/v1/
contracts/manifests/p2.json
services/api/src/domains/invoice_document/
services/api/src/platform/render_process/
services/api/tests/invoice_document/
apps/web/src/features/invoice-document-review/
renderer/templates/invoice-v1/<version>/
renderer/runtime/
```

P2 publishes an integration request for the aggregate API, generated client,
shared router, root build, container composition, and CI. It does not edit those
steward-owned surfaces directly.

## Architecture

```text
P0/P1 structured contracts
          |
          v
Draft parser and invariant validator
          |
          v
Exact line/tax calculator ----> normalized evaluation response
          |
          v
Snapshot freezer + RFC 8785 digests
          |
          v
Render projection ---- context-specific TeX encoders
          |                         |
          +---- PNG verifier -------+
          |
          v
Immutable template/runtime registry
          |
          v
OS-sandbox setup -> direct LuaLaTeX execve
          |
          v
PDF verifier -> exact SHA-256 -> preview or staged receipt
```

The document domain does not import P1 repositories. P1's current configuration
is projected into complete values before P2. Rendering reads only the immutable
snapshot, template bundle, font/runtime trees, and digest-verified PNG.

## Calculation Design

`CanonicalQuantity` is parsed to an integer numerator and scale (`10^0` through
`10^6`). Quantity/rate uses checked `i128` multiplication and divides once by
the scale, rounding to nearest minor unit with ties away from zero. V1 values are
non-negative, making this conventional half-up behavior while the named rule
remains correct if later signed values are introduced.

Tax-exclusive per-line tax uses:

```text
round_half_away_from_zero(net_minor * rate_ppm / 1_000_000)
```

`standard` requires `1..1_000_000`; `zero_rated` requires zero; Exempt,
ReverseCharge, and OutOfScope carry no numeric rate. ReverseCharge requires an
escaped note. Invoice tax is the checked sum of line tax, not a recalculation on
the subtotal. The snapshot retains expressions and evaluated results.

## Snapshot and Digest Design

The final snapshot contains every displayed issuer/recipient/remittance/logo,
line/tax/date/term/currency value plus source revisions and exact schema,
template, font/package, and runtime identities. It contains no pointer whose
later P1 mutation could change an issued rendering.

- Snapshot digest covers RFC 8785 canonical snapshot JSON.
- Render-recipe digest binds render payload, template, font/package, logo, and
  runtime digests.
- Artifact digest covers exact PDF bytes.

All domain digests use `sha256:<64 lowercase hex>`; preview responses use RFC
9530 `Content-Digest` and a strong ETag. A final snapshot requires a number
supplied by P5; a numberless preview is visibly marked as a draft.

## TeX Projection and Template Design

The template receives a fixed typed render projection. Each plain-text value is
encoded for its exact TeX context. User data cannot select a control sequence,
dimension, filename, package, font, hyperlink, path, or command. Unsupported
control characters, bidirectional controls, malformed Unicode, and missing
glyphs are field errors.

The initial immutable template family includes:

- pinned OFL sans fonts with tabular figures;
- restrained grayscale hierarchy and one server-owned accent;
- Letter and A4 variants from the same semantic source;
- repeating table headings, bounded notes, and non-overlapping totals/footer;
- explicit three-letter currency codes and no internal identifiers;
- no remote resources, attachments, scripts, dynamic packages, or user links.

Every version binds source, package, font/license, runtime, fixture, semantic
text, raster, and known-pagination evidence. Released contents never change.

## Sandbox and Process Contract

The parent validates all inputs and creates a mode-0700 request workspace. The
child sandbox is established before `execve` and provides:

- unprivileged identity and no inherited file descriptors;
- no network namespace/access and no extra process creation;
- read-only exact TeX/font/template trees;
- read/write access only to the request workspace;
- allowlisted deterministic environment including stable `SOURCE_DATE_EPOCH`;
- CPU, address-space, output-size, file-count, process-count, and wall limits.

LuaLaTeX receives a fixed argument vector with no shell escape, noninteractive
halt-on-error behavior, fixed output directory, and fixed `main.tex`. The parent
requires successful exit, exactly one bounded regular PDF, valid signature, and
no unexpected output class. Any unavailable isolation or anomaly fails closed.
Diagnostics are schema-allowlisted and temporary files are removed on all paths.

## API and Web Integration

- `POST /api/v1/invoice-documents/evaluations` returns a P0 JSON envelope with
  `EvaluatedInvoiceDocumentV1`; it has no side effects.
- `POST /api/v1/invoice-document-previews` reevaluates the structured request and
  returns verified `application/pdf` or a P0 JSON error. It accepts no filename,
  template path, process option, or output path.
- An internal P5 port accepts a final numbered snapshot request and returns bytes
  plus `StagedArtifactReceipt`; it performs no lifecycle write.

The Next.js feature renders an HTML calculation summary, identity provenance,
market/remittance/logo decisions, dates/terms/lines/tax/totals, structured field
errors, loading state, and safe object-URL lifecycle. PDF embedding is optional;
the HTML review remains complete.

## Fixture and Verification Matrix

Canonical business fixtures cover Domestic personal fixed/no-logo, European LLC
VAT/logo, quantity/rate consulting, rounding ties, zero-rated, reverse charge,
Other Show/Hide, mixed lines, maximum multipage, long/unicode content, and both
paper sizes.

Negative fixtures cover canonical quantity, overflow, currency/date/tax rules,
remittance coherence, logo corruption/decompression, modified template/runtime,
missing final number, and every request/output ceiling.

Security fixtures exercise TeX metacharacters, apparent `input`/`write18`/
`directlua`, path traversal, controls/bidi/malformed UTF-8, an external file
canary, network/process attempts, infinite execution, and log redaction.

Each visual fixture retains canonical Draft/Evaluated/Snapshot JSON, exact
digests, positive/negative PDF text assertions, page count, pinned raster PNGs,
and the exact PDF digest inside the pinned runtime.

## Contract Lifecycle and Consumer Handoff

P2 begins at `0.1.0-draft.1`. Its implementation lane opens only after exact P0
and P1 Frozen digests are present on the current baseline. P2 contract promotion
requires real calculator, sandbox, PDF, semantic/raster, and license evidence.

P5 consumes `InvoiceDocumentSnapshotV1` and `StagedArtifactReceipt`; P6 consumes
the structured line/draft input seam. Synthetic consumer fixtures are exchanged
before freeze. P2 owns no P5 storage, number counter, issuance event, or orphan
reconciliation behavior.

## Implementation Concerns

| Concern | Scope | Depends on | Parallel opportunity |
| --- | --- | --- | --- |
| IC-01 | P2 schema/API/digest/fixture vocabulary and P1 projection | P0/P1 Draft | Opens all lanes |
| IC-02 | Fixed/quantity/tax exact calculation and error model | IC-01 | Parallel with template manifest |
| IC-03 | Normalization, snapshot, RFC 8785, digest vectors | IC-01, IC-02 | Parallel with runtime bundle |
| IC-04 | Immutable template/font/package/runtime manifests | IC-01 | Parallel with calculator |
| IC-05 | Render projection and context-specific TeX encoders | IC-02, IC-03 | Does not require live TeX initially |
| IC-06 | Linux OS sandbox and direct LuaLaTeX executor | IC-04, IC-05 | Security lane |
| IC-07 | PDF verification and staged receipt | IC-03, IC-06 | Parallel tamper tests |
| IC-08 | Evaluation/preview HTTP operations | IC-02, IC-03, IC-07 | Black-box API lane |
| IC-09 | Accessible Next.js review/preview | IC-08 | Web-owned paths only |
| IC-10 | Full semantic/raster/security/determinism/license harness | IC-04, IC-06, IC-07 | Fixture groups parallelize |
| IC-11 | Frozen contract and P5/P6 handoff | IC-01–IC-10 | Integration lane |

These are implementation concerns, not work packages. Task slicing waits for the
cross-mission Draft review.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| TeX reads host files without shell escape | External OS filesystem sandbox and canary acceptance. |
| Configured restricted commands remain available | Explicit no-shell-escape plus process/network isolation. |
| Rounding differs by a cent | One per-line algorithm and below/tie/above fixtures. |
| P1/P2 configuration drifts | Frozen projection fixtures; no P1 repository reads. |
| Browser shows stale/recomputed totals | Zig response is authoritative; browser formats only. |
| Runtime timestamps/packages change PDF bytes | Exact runtime/font/package pins and deterministic environment. |
| Long content becomes denial of service | Input/page/output/process/time ceilings and maximum fixtures. |
| Logo parsing expands attack surface | Decoded bounded PNG only, fixed filename, digest verification. |
| Engine diagnostics expose data | Stable allowlisted errors, redaction canaries, ephemeral raw logs. |
| P2 absorbs issuance | Stateless preview and explicit P5 receipt boundary. |
| Shared integration conflicts in the swarm | P2 additive paths; steward composes shared outputs. |

## Planning Exit Criteria

- Specification, data model, arithmetic, security, and typography decisions agree.
- Draft schema/manifest parse and record exact P0/P1 Draft dependencies.
- Sandbox contract is OS-enforced and fail closed.
- P2/P5 lifecycle and retention boundary is explicit.
- No unresolved marker or charter exception remains.
- Mission is parked before task generation pending Draft contract review.

