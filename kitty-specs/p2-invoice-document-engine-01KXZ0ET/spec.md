# Mission Specification: P2 Invoice Document Engine

**Mission Branch**: `feat/p2-invoice-document-engine`  
**Created**: 2026-07-19  
**Status**: Ready for Planning  
**Input**: Build exact structured invoice calculation and typographically
beautiful PDF preview with Zig-orchestrated, OS-sandboxed LuaLaTeX.

## Intent Summary

The consulting-business owner reviews a structured invoice before issuance.
Zig calculates every authoritative amount, freezes every displayed value into a
document snapshot, and renders a polished PDF through one pinned template and
runtime. A successful preview is not an issued invoice: P2 allocates no number,
changes no lifecycle state, and retains no issued artifact.

Unsafe, incomplete, inconsistent, or unrenderable input fails closed with a
structured error and no successful artifact. Callers cannot submit raw TeX,
paths, templates, process flags, totals, or arbitrary logo formats.

## User Scenarios & Testing

### User Story 1 - Evaluate an Exact Invoice Draft (Priority: P1)

As the owner, I can enter fixed-price and quantity/rate lines with explicit tax
treatments and see exact Zig-calculated totals.

**Independent Test**: Evaluate fixed, quantity/rate, rounding-boundary,
mixed-tax, currency-mismatch, and overflow fixtures without invoking TeX.

**Acceptance Scenarios**:

1. **Given** quantity `37.5` at USD `22500` minor units, **When** evaluated,
   **Then** the authoritative line net is USD `843750`.
2. **Given** a fixed line, **When** evaluated, **Then** the supplied Money is the
   line net and no caller-supplied total is trusted.
3. **Given** a calculation outside signed `i64`, **When** evaluated, **Then**
   `calculation_overflow` identifies the exact JSON Pointer.
4. **Given** unchanged canonical input, **When** evaluated repeatedly, **Then**
   normalized bytes and digests are identical.

---

### User Story 2 - Preview a Beautiful Invoice Safely (Priority: P1)

As the owner, I can preview a Letter or A4 invoice with restrained typography,
clear totals, optional logo, and correct multipage behavior.

**Independent Test**: Render the canonical fixture catalog in the pinned
LuaLaTeX runtime and compare PDF text, page counts, raster references, and bytes.

**Acceptance Scenarios**:

1. **Given** a normal structured draft, **When** previewed, **Then** a PDF is
   returned within ten seconds with exact digest headers and `no-store` caching.
2. **Given** no number, **When** previewed, **Then** every page is conspicuously
   marked `DRAFT — NOT AN INVOICE`.
3. **Given** long content, **When** the document spans pages, **Then** table
   headings repeat and totals/footer never overlap content.
4. **Given** TeX-like user text, **When** rendered, **Then** it is inert displayed
   text or a field error and cannot read files, execute Lua/shell, or alter layout.

---

### User Story 3 - Preserve Remittance Policy (Priority: P1)

As the owner, I can trust that bank details appear only when the resolved market
policy requires them.

**Independent Test**: Assert normalized data, generated TeX, diagnostics, and
extracted PDF text across Domestic, Europe, Other/Show, and Other/Hide fixtures.

**Acceptance Scenarios**:

1. **Given** Domestic or Other/Hide, **When** any remittance block is supplied,
   **Then** P2 rejects it as `remittance_forbidden`.
2. **Given** Europe or Other/Show, **When** a required bank field is missing,
   **Then** P2 rejects the document as `remittance_incomplete`.
3. **Given** a valid European document, **When** rendered, **Then** the complete
   configured block appears and no value enters public diagnostics.

---

### User Story 4 - Freeze a Downstream-Safe Snapshot (Priority: P1)

As the issuance domain, I can consume a complete immutable display/calculation
snapshot plus a content-addressed staged-artifact receipt.

**Independent Test**: Freeze an evaluated final input, mutate every source
fixture, and prove the snapshot and staged PDF remain unchanged.

**Acceptance Scenarios**:

1. **Given** final render inputs, **When** frozen, **Then** issuer, recipient,
   lines, taxes, dates, remittance, logo digest, template, and runtime identities
   are values, not live P1 pointers.
2. **Given** a final snapshot without a document number, **When** requested,
   **Then** it is rejected; numberless data is preview-only.
3. **Given** successful rendering, **When** a staged receipt is created, **Then**
   it records snapshot, recipe, template/runtime, PDF digest, and exact length.
4. **Given** a receipt, **When** P5 consumes it, **Then** P2 has not marked it
   issued or retained it as an issued record.

---

### User Story 5 - Review Accessibly in Next.js (Priority: P2)

As the owner, I can review the authoritative breakdown and PDF with keyboard,
screen-reader, and structured-error support.

**Independent Test**: Complete evaluation/preview with keyboard only, force each
field error, and use the full HTML summary without an embedded PDF viewer.

**Acceptance Scenarios**:

1. **Given** an evaluated document, **When** reviewed, **Then** issuer source,
   recipient, currency, dates, lines, tax, remittance/logo decisions, and totals
   are visible in HTML.
2. **Given** a structured Zig error, **When** displayed, **Then** it is associated
   with and can focus the corresponding field.
3. **Given** no PDF embedding support, **When** preview succeeds, **Then** the
   complete accessible HTML summary remains usable.

### Edge Cases

- Quantity/tax value lies just below, at, or above a half-minor-unit tie.
- Multiplication fits `i128` but the rounded `i64` result does not.
- A line currency differs from the document currency.
- Due date precedes issue date or a period is inverted.
- Domestic input contains a bank field hidden by the UI.
- Logo digest, decoded media, dimensions, or byte length disagree.
- Unicode lacks a pinned font glyph; bidirectional/control text is supplied.
- Content reaches line, text, page, output, time, or process limits.
- The sandbox capability, template version, or runtime digest is unavailable.
- LuaLaTeX exits zero but emits no PDF, multiple PDFs, a symlink, or oversize data.
- Cleanup is interrupted after success, timeout, or process termination.

## Requirements

### Functional Requirements

| ID | Title | User Story | Priority | Status |
| --- | --- | --- | --- | --- |
| FR-001 | Additive P2 contracts | As a consumer, I receive versioned document, API, digest, receipt, and fixture contracts composed with P0/P1. | High | Approved |
| FR-002 | Tagged line pricing | As the owner, I can use fixed or quantity/rate lines without cosmetic or overridden calculation metadata. | High | Approved |
| FR-003 | Canonical quantities | As the owner, quantities are positive canonical decimal strings with at most six fractional digits and no exponent/sign/whitespace variation. | High | Approved |
| FR-004 | Exact line calculation | As the owner, quantity/rate lines use an `i128` intermediate and round once to minor units, ties away from zero. | High | Approved |
| FR-005 | Explicit tax treatment | As the owner, each line is standard, zero-rated, exempt, reverse-charge, or out-of-scope with validated rate/note rules. | High | Approved |
| FR-006 | Exact tax calculation | As the owner, tax is calculated per line from integer parts-per-million, rounded ties away from zero, then summed. | High | Approved |
| FR-007 | Checked totals | As the owner, all line, subtotal, tax, and total operations reject overflow and currency disagreement. | High | Approved |
| FR-008 | Normalized evaluation | As a caller, I receive authoritative normalized inputs/results while caller totals are ignored or rejected. | High | Approved |
| FR-009 | Remittance defense | As the owner, Domestic/hidden remittance is forbidden and Europe/show requires a complete block. | High | Approved |
| FR-010 | Immutable snapshot | As P5, I receive complete displayed/calculated values, source revisions, and exact schema/template/runtime identities. | High | Approved |
| FR-011 | Canonical digests | As P5, snapshot and render recipe use RFC 8785 canonical JSON and `sha256:<lowercase hex>` identities. | High | Approved |
| FR-012 | Logo verification | As the owner, P2 accepts only digest-verified, bounded normalized PNG selected by P1. | High | Approved |
| FR-013 | TeX encoding | As the owner, every user field is encoded for its exact TeX context and no raw TeX/control sequence is accepted. | High | Approved |
| FR-014 | Template registry | As a contributor, only immutable server-owned template/font/package/runtime versions may render. | High | Approved |
| FR-015 | OS render sandbox | As the owner, LuaLaTeX has OS-enforced filesystem, network, process, descriptor, time, and resource isolation. | High | Approved |
| FR-016 | Fail-closed rendering | As the owner, unavailable sandboxing or any output/process anomaly yields a safe error and no artifact. | High | Approved |
| FR-017 | Evaluation endpoint | As the web client, I can synchronously evaluate a structured draft through the P0 JSON envelope. | High | Approved |
| FR-018 | Preview endpoint | As the web client, I can synchronously obtain a verified PDF or P0-structured JSON failure. | High | Approved |
| FR-019 | Safe preview headers | As the owner, preview returns `no-store`, strong ETag, RFC 9530 Content-Digest, and constant inline disposition. | Medium | Approved |
| FR-020 | Staged artifact receipt | As P5, I can receive verified PDF bytes plus exact snapshot/recipe/artifact identities without issuance side effects. | High | Approved |
| FR-021 | Accessible review | As the owner, I can review all authoritative content and errors without relying on PDF embedding or a mouse. | Medium | Approved |
| FR-022 | Semantic/visual fixtures | As a contributor, released templates pass extracted-text, pagination, raster, security, and deterministic-byte fixtures. | High | Approved |
| FR-023 | Sanitized diagnostics | As the owner, public errors/logs expose no paths, bank values, document text, TeX, or raw engine output. | High | Approved |
| FR-024 | Immutable template evolution | As a contributor, changing a released template requires a new version and full compatibility evidence. | High | Approved |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| NFR-001 | Exact round-trip | All supported signed-`i64` values round-trip exactly through schema, Zig, JSON, and TypeScript. | Correctness | High | Approved |
| NFR-002 | Evaluation determinism | Unchanged valid input produces identical normalized bytes and digests in 100% of repeated tests. | Determinism | High | Approved |
| NFR-003 | Render determinism | Each canonical fixture produces identical PDF bytes in 20 consecutive pinned-runtime renders. | Determinism | High | Approved |
| NFR-004 | Preview latency | A normal one-page preview completes within ten seconds; hard wall timeout is fifteen seconds. | Performance | High | Approved |
| NFR-005 | Evaluation latency | Maximum supported draft evaluation excluding rendering completes within 100 ms on the reference runner. | Performance | Medium | Approved |
| NFR-006 | Resource ceilings | V1 accepts at most 200 lines, 64 KiB aggregate text, 20 pages, and a 10 MiB PDF. | Safety | High | Approved |
| NFR-007 | Sandbox proof | Tests prove no external canary read/write, network socket, extra process, inherited descriptor, or workspace escape. | Security | High | Approved |
| NFR-008 | Cleanup reliability | One hundred success/failure/timeout cycles leave no child process or private workspace. | Reliability | High | Approved |
| NFR-009 | Domain coverage | Zig calculation, normalization, encoding, digest, and execution-control code maintains at least 90% coverage. | Testability | High | Approved |
| NFR-010 | PDF fidelity | Required commercial text is present, prohibited domestic data absent, and raster changes require explicit approval. | Fidelity | High | Approved |
| NFR-011 | Synthetic evidence | Every public document, logo, address, identifier, and bank value is invented. | Privacy | High | Approved |
| NFR-012 | Accessibility | Review/preview satisfies WCAG 2.2 AA automated and keyboard/fallback acceptance. | Accessibility | High | Approved |
| NFR-013 | License gate | TeX runtime, packages, fonts, rasterizer, and distributed notices are GPL-2.0-only compatible. | Compliance | High | Approved |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| C-001 | Draft dependency gate | P2 may plan against P0/P1 Draft contracts but may not implement until consumed versions are Frozen and merged/revalidated. | Dependency | High | Approved |
| C-002 | Zig authority | Zig owns calculation, validation, snapshot, digest, asset verification, and render orchestration. | Architecture | High | Approved |
| C-003 | No browser arithmetic | Next.js formats returned totals but performs no authoritative money/tax calculation. | Correctness | High | Approved |
| C-004 | P0 Money | Money is canonical decimal-string signed-`i64` minor units plus USD/EUR currency; no binary floating point or FX. | Correctness | High | Approved |
| C-005 | Stateless engine | P2 has no ShovelerDB business table or persistent preview job; temporary/staged files are private and bounded. | Scope | High | Approved |
| C-006 | No raw TeX | Users cannot select templates, paths, package names, commands, lengths, filenames, or control sequences. | Security | High | Approved |
| C-007 | Direct execution | LuaLaTeX is invoked directly after sandbox setup with a fixed argument vector; no shell or runtime `latexmk`. | Security | High | Approved |
| C-008 | No ambient filesystem | A private working directory and `--no-shell-escape` are necessary but not the security boundary; OS isolation is mandatory. | Security | High | Approved |
| C-009 | PNG only | P2 accepts only normalized digest-verified PNG logos; SVG and PDF inputs are excluded. | Safety | High | Approved |
| C-010 | Sensitive temporary data | Generated TeX and raw engine logs are deleted and are not logged or retained by default. | Privacy | High | Approved |
| C-011 | P2 ownership | P2 contributes only its additive contracts, feature paths, templates, fixtures, and renderer modules; shared files use the steward. | Delivery | High | Approved |
| C-012 | No issuance | P2 allocates no number, issues/voids no invoice, records no payment, emits no financial event, and retains no issued artifact. | Scope | High | Approved |

### Key Entities

- **InvoiceDocumentDraftV1**: Structured mutable input with no trusted derived totals.
- **InvoiceLineDraft**: Ordered fixed or quantity/rate pricing plus one explicit tax treatment.
- **EvaluatedInvoiceDocumentV1**: Normalized input and authoritative calculated line/tax/totals.
- **InvoiceDocumentSnapshotV1**: Immutable final displayed/calculated values and exact render identities.
- **TemplateManifest**: Append-only source/font/package/runtime identity and compatible schema versions.
- **RenderRecipe**: Canonical record binding snapshot payload, template, fonts/packages, logo, and runtime.
- **StagedArtifactReceipt**: Exact PDF digest/length plus snapshot and recipe identities for P5.

## Success Criteria

- **SC-001**: All canonical fixed, quantity/rate, tax, rounding, and overflow
  fixtures produce the specified exact outcomes.
- **SC-002**: Domestic/hidden normalized data, TeX, diagnostics, and PDF text
  contain zero remittance field names or values.
- **SC-003**: The real renderer cannot access external files/network/processes
  and cleans all resources across success, failure, and timeout tests.
- **SC-004**: Normal one-page previews complete within ten seconds and each
  canonical fixture is byte-deterministic for 20 pinned-runtime renders.
- **SC-005**: Letter/A4, logo/no-logo, tax, Unicode, long, and multipage fixtures
  pass semantic, page-count, and approved raster comparisons.
- **SC-006**: P5 can validate the frozen snapshot and staged-receipt fixtures
  without P2 implementing issuance or persistent artifact retention.

## Assumptions

- V1 output language is English and ships one restrained template family.
- Currency code is always displayed; symbols may supplement but not replace it.
- Prices are tax-exclusive. Discounts, negative lines, credits, retainers,
  withholding, and compounded taxes require a later version.
- P1 selects market/remittance/logo/current party configuration; P2 validates
  the render invariant and freezes display values.

## Explicit Exclusions

Client/project/identity CRUD; tax-jurisdiction selection or compliance advice;
invoice numbering/issuance/voiding/payments; durable issued-artifact retention;
recurrence and schedule advancement; auth/deployment/backup; analytics; email;
arbitrary templates; SVG/PDF logos; electronic-invoice XML; PDF/A or PDF/UA
certification; signatures; localization; discounts, credits, and withholding.
