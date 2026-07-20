---
work_package_id: "WP08"
title: "Resolved Configuration and Negative Security Fixtures"
dependencies: ["WP03", "WP04", "WP05", "WP07"]
requirement_refs: ["FR-004", "FR-008", "FR-013", "FR-014", "FR-016", "NFR-002", "NFR-003", "NFR-005", "NFR-007", "NFR-008", "C-004", "C-009"]
subtasks: ["T039", "T040", "T041", "T042", "T043"]
owned_files:
  - "contracts/fixtures/p1/v1/valid/**"
  - "contracts/fixtures/p1/v1/invalid/**"
  - "contracts/fixtures/p1/v1/security/**"
  - "services/api/tests/parties_projects/resolved_configuration/**"
  - "services/api/tests/parties_projects/security/**"
authoritative_surface: "contracts/fixtures/p1/v1/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP08 – Resolved Configuration and Negative Security Fixtures

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Freeze a complete synthetic valid/invalid/security fixture catalog for current Resolved Invoice Configuration and prove the real WP07 application boundary produces it safely. These fixtures become the stable P2/P5/P6 planning and later implementation handoff.

## Context

WP08 addresses `IC-08` after domain/application convergence. It does not change resolver or service production code; any discovered producer defect must be routed back to its owning WP and re-reviewed. WP09 consumes the accepted cases for black-box HTTP.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless exact P0 Frozen/merged/revalidated and accepted WP03–WP07 outputs are on the baseline.
2. Run all producer-focused tests before adding fixtures; fixtures cannot redefine behavior to accommodate a failing producer.
3. For each security/readiness invariant, first add a fixture-driven failing public application assertion and `RED:` evidence; then route/fix the producer or add the missing expected fixture and record `GREEN:`.
4. Fixtures must be fully synthetic. Use recognizable canaries to prove logs/events/hidden outputs omit bank, contact, tax, note, path, SQL, and engine data.
5. Do not edit WP01 decision fixtures or production sources. Valid/invalid/security subtrees are disjoint and canonical.

```bash
spec-kitty agent action implement WP08 --agent codex
```

### Subtask T039: Publish complete valid resolved configurations

**Purpose**: Give downstream consumers stable examples for every successful policy shape.

**Steps**:

1. Create valid Domestic client-default, Domestic explicit-override, Europe complete, Other/Show, and Other/Hide cases.
2. Cover Personal and Company issuers, USD/EUR, monthly/quarterly cadence, logo Off/project asset/identity default, and terms provenance.
3. Include Project/Client/source revisions and all inheritance/override provenance required by the schema.
4. Use structurally absent remittance/logo members where policy hides them.
5. Validate each fixture against exact composed P0+P1 schemas offline.

**Files**: `contracts/fixtures/p1/v1/valid/**`.

**Validation**: Every valid fixture round-trips through the real application resolver and matches canonical bytes.

### Subtask T040: Publish invalid readiness and lifecycle matrices

**Purpose**: Make every activation/resolution failure stable and testable.

**Steps**:

1. Add incomplete identity, missing/inactive default/override, invalid contact primary, missing Other choice, incomplete Europe remittance, currency/amount mismatch, date-order, and logo-unavailable cases.
2. Add stale revision, referenced deactivation without reassignment, illegal lifecycle transition, and idempotency-conflict cases.
3. Record stable error category and JSON Pointer field paths, never rejected values.
4. Ensure each invalid fixture fails for its intended reason before any unrelated later validation.
5. Keep valid/invalid fixtures immutable once accepted; behavior changes create new case/version.

**Files**: `contracts/fixtures/p1/v1/invalid/**`.

**Validation**: Exact expected errors match the real application boundary; removing each producer guard makes its named fixture fail differently or pass unexpectedly.

### Subtask T041: Prove structural sensitive-data absence

**Purpose**: Enforce Domestic and hidden privacy beyond masking.

**Steps**:

1. Create security cases with unique synthetic IBAN, BIC, holder, bank instruction, email, tax, notes, path, SQL, and engine canaries.
2. Run Domestic and Other/Hide resolution and recursively reject remittance field names as well as values.
3. Scan application results, errors, captured logs, events, snapshots, and review summaries for every canary.
4. For Show cases, require complete data only in the resolved response and nowhere else.
5. Add deletion tests for the structural omission and allowlist scans.

**Files**: `contracts/fixtures/p1/v1/security/remittance-*`, security tests.

**Validation**: Zero hidden field names/values and zero canaries outside explicitly allowed Show response paths.

### Subtask T042: Prove logo and input security boundaries

**Purpose**: Freeze hostile asset/path/text cases without placing unsafe content in public fixtures.

**Steps**:

1. Add tiny synthetic malformed/truncated/discordant/oversized/dimension-bomb PNG descriptors or bounded fixture assets as policy permits.
2. Add traversal filename, control-character instructions, overlong fields, malformed IDs/dates/Money, and Unicode normalization cases.
3. Assert stable field errors and absence of raw filenames, paths, bytes, and rejected text from logs.
4. Prove an accepted logo fixture records digest/media/dimensions and a safe opaque reference only.
5. Keep actual binary size bounded and document synthetic generation provenance.

**Files**: `contracts/fixtures/p1/v1/security/logo-*`, input security tests.

**Validation**: All hostile cases reject before persistence/artifact exposure; valid case remains byte-deterministic.

### Subtask T043: Prove fixture completeness and consumer stability

**Purpose**: Close the decision-to-fixture matrix and produce immutable handoff evidence.

**Steps**:

1. Map every WP01 decision row and P1 readiness/security branch to at least one accepted fixture.
2. Validate the complete catalog twice offline and compare inventory/order/bytes.
3. Replay valid/invalid cases through real WP07 services with checkpoint-close-reopen where mutation is involved.
4. Mutate one schema ID, expected error, omission rule, digest, and provenance value; each must fail.
5. Run producer coverage and require every enumerated security branch plus 90% domain coverage.
6. Record exact P0/P1 pins, commands, fixture hashes, canary scan, and clean owned-file diff.

**Files**: Catalog/index files within WP08-owned fixture/test paths.

**Validation**: Coverage map is complete, repeated catalog bytes match, replay is stable, and no generated/shared files change.

## Definition of Done

- [ ] P0 and producer WP acceptance evidence precedes fixture work.
- [ ] Valid catalog spans all issuer/market/override/logo/currency/cadence shapes.
- [ ] Invalid catalog spans every readiness/lifecycle/concurrency error.
- [ ] Hidden payloads omit sensitive fields structurally.
- [ ] Hostile logo/input cases reject safely.
- [ ] Fixtures are deterministic, immutable, synthetic, and exact-schema validated.
- [ ] RED/GREEN/deletion, replay, coverage, and canary evidence pass.
- [ ] Only WP08-owned files changed.

## Risks

- **Fixture-authority inversion**: producer behavior remains authoritative to spec/contracts; route defects back.
- **Synthetic secret leakage**: canaries are invented but still must be absent from prohibited surfaces.
- **False omission**: scan keys and values recursively, not serialized substring only.
- **Consumer drift**: record exact content hashes and source revisions.

## Reviewer Guidance

Review decision/error coverage, exact schema validation, structural omission, canary allowlists, hostile input boundaries, real-service replay, mutation/deletion evidence, deterministic fixture hashes, and strict owned-file isolation.
