---
work_package_id: "WP04"
title: "Client and Billing Contact Domain"
dependencies: ["WP02"]
requirement_refs: ["FR-006", "FR-007", "FR-008", "FR-009", "FR-015", "NFR-001", "NFR-003", "NFR-005", "NFR-009", "C-002", "C-004", "C-005", "C-009"]
subtasks: ["T017", "T018", "T019", "T020", "T021"]
owned_files:
  - "services/api/src/domains/parties_projects/client/**"
  - "services/api/src/domains/parties_projects/billing_contact/**"
  - "services/api/tests/parties_projects/client/**"
  - "services/api/tests/parties_projects/billing_contact/**"
authoritative_surface: "services/api/src/domains/parties_projects/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP04 – Client and Billing Contact Domain

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Implement Client and Billing Contact domain behavior with saveable drafts, explicit Billing Market, exact defaults, deterministic readiness, and safe archive/restore rules. This parallel lane must not depend on WP03 or WP05 implementation details.

## Context

WP04 addresses `IC-04` after WP02. It consumes shared values and pure policy tables while referring to identities only by typed ID/status facts. WP07 later coordinates repositories and atomic cross-aggregate commands; WP09 owns HTTP and WP10 owns the manager UI.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless merged/revalidated P0 Frozen-or-later evidence and accepted WP02 output are on the current dependency base.
2. Use P0's convention-scanned P1 domain test hook; never edit service build files.
3. Write a failing public aggregate/query-model test and Activity Log `RED:` record before each production rule; append matching `GREEN:` after the minimal change.
4. Draft preservation, readiness errors, market/remittance behavior, contact uniqueness, and archive/restore each require independent failure-path evidence.
5. Use synthetic client/contact/address data and never log notes, emails, tax values, or remittance values.
6. Do not write repositories, SQL, events, HTTP, UI, shared policy, or other domain-lane files.

```bash
spec-kitty agent action implement WP04 --agent codex
```

### Subtask T017: Implement saveable Client drafts and readiness

**Purpose**: Preserve incomplete owner input while preventing incomplete Clients from becoming Active.

**Steps**:

1. Model ID/revision, legal/display name, structured billing address, tax identifiers, explicit market, optional Other choice, default identity/currency/terms, internal notes, and status.
2. Allow incomplete Draft saves while computing stable readiness errors.
3. Require valid name/address, Active default identity fact, USD/EUR currency, terms, exactly one primary valid contact, and complete market decision before Active.
4. Sort readiness errors deterministically and exclude rejected values.
5. Keep market explicit; never infer from address country.

**Files**: `client/model.zig`, `client/readiness.zig`, focused tests.

**Validation**: Domestic, Europe, Other, incomplete Draft, and Active transition matrices pass with stable error paths.

### Subtask T018: Implement Billing Contact ownership and primary rules

**Purpose**: Maintain usable billing recipients without duplicating or orphaning primary contacts.

**Steps**:

1. Model typed Client ownership, name/email, optional role/phone, active state, primary flag, and display order.
2. Validate bounded values and a conservative email shape without claiming delivery.
3. Require exactly one active Primary contact for a Ready/Active Client; allow Draft zero/multiple candidates only with readiness errors.
4. Define deterministic add/update/deactivate/reorder transformations with expected revision inputs.
5. Reject cross-client contact movement, duplicate IDs, and removal of the only primary during activation.

**Files**: `billing_contact/model.zig`, `billing_contact/policy.zig`, tests.

**Validation**: Contact lifecycle, ownership, primary uniqueness, draft-versus-active, and deterministic-order cases pass.

### Subtask T019: Apply explicit market and remittance readiness

**Purpose**: Connect Client facts to WP02's remittance decision without exposing bank data.

**Steps**:

1. Domestic must resolve Hide and forbid an explicit Other choice.
2. Europe must resolve Require Show and require a complete Active profile fact from the selected identity.
3. Other must require explicit Show/Hide; Show requires a complete Active profile fact.
4. Return only the decision and readiness errors; never copy account values into Client state.
5. Add market-change cases that remove stale Other choice and re-evaluate readiness.

**Files**: `client/remittance_readiness.zig`, focused tests.

**Validation**: Every WP01 remittance decision fixture passes, and hidden results contain no remittance field name or value.

### Subtask T020: Implement archive, restore, and identity reassignment rules

**Purpose**: Keep references intact while supporting owner corrections and lifecycle changes.

**Steps**:

1. Implement Draft → Active → Archived and Archived → Draft-for-revalidation transitions.
2. Reject deletion once referenced; expose archive instead.
3. Validate a proposed default-identity reassignment against Active identity facts and expected revisions.
4. Require reassignment and any affected Project review to occur atomically in WP07; this package returns a deterministic plan/result only.
5. Ensure archive never mutates historical invoice data or creates billing/schedule events.

**Files**: `client/lifecycle.zig`, `client/reassignment.zig`, tests.

**Validation**: Legal/illegal transitions, stale revisions, inactive replacement, referenced deletion, and restore-to-Draft cases pass.

### Subtask T021: Define deterministic client-manager query models

**Purpose**: Supply transport-neutral list/detail facts needed to meet the 500-Client/2,000-Project manager target.

**Steps**:

1. Define bounded query input for search, status, market, readiness, cursor, limit, and stable sort.
2. Define summary/detail projections with IDs, labels, status, readiness counts/codes, default identity label/ID, and masked-only sensitive indicators.
3. Exclude notes, bank values, tax values, and contact email from list projections.
4. Specify deterministic tie-breaking by stable ID and opaque cursor contents without HTTP encoding.
5. Add generated synthetic 500-Client cases to test filtering/order under the domain performance budget.
6. Run coverage and forbidden-data/import scans and record focused evidence.

**Files**: `client/query.zig`, tests under WP04-owned directories.

**Validation**: Query determinism and domain-stage performance pass; canary values are absent from summaries and diagnostics.

## Definition of Done

- [ ] P0 Frozen/merged/revalidated and WP02 acceptance evidence precedes edits.
- [ ] Incomplete Clients remain saveable Drafts with actionable errors.
- [ ] Active Clients have exact identity/currency/terms/contact/market readiness.
- [ ] Market is explicit and hidden remittance is structurally absent.
- [ ] Contact ownership and one-primary rules are exhaustive.
- [ ] Archive/restore/reassignment rules preserve references.
- [ ] Query models are deterministic, bounded, and privacy-safe.
- [ ] RED/GREEN evidence, 90% domain coverage, and owned-file isolation pass.

## Risks

- **Address inference**: tests must prove country changes do not silently change market.
- **Sensitive list data**: list models use masks/indicators only.
- **Cross-aggregate race**: WP04 validates a plan; WP07 serializes the operation.
- **Parallel collision**: no imports from or writes into WP03/WP05 internals.

## Reviewer Guidance

Review Draft/Active semantics, primary-contact uniqueness, market decision exhaustiveness, readiness ordering, privacy-safe summaries, lifecycle/reassignment boundaries, performance evidence, and deletion tests. Reject any repository/HTTP behavior or inferred market.
