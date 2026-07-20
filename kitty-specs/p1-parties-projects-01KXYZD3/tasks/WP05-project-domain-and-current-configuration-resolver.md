---
work_package_id: "WP05"
title: "Project Domain and Current Configuration Resolver"
dependencies: ["WP02"]
requirement_refs: ["FR-010", "FR-011", "FR-012", "FR-013", "FR-014", "FR-015", "NFR-005", "NFR-008", "NFR-009", "C-002", "C-003", "C-004", "C-005", "C-007"]
subtasks: ["T022", "T023", "T024", "T025", "T026"]
owned_files:
  - "services/api/src/domains/parties_projects/project/**"
  - "services/api/src/domains/parties_projects/resolution/**"
  - "services/api/tests/parties_projects/project/**"
  - "services/api/tests/parties_projects/resolution/**"
authoritative_surface: "services/api/src/domains/parties_projects/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP05 – Project Domain and Current Configuration Resolver

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Implement the Project aggregate and pure current Resolved Invoice Configuration resolver. The resolver must make issuer inheritance/override, remittance, currency/terms, cadence, and logo provenance explicit without freezing an invoice snapshot or advancing a schedule.

## Context

WP05 is the `IC-05` parallel domain lane after WP02. It consumes only shared types/policies and typed facts for Client, Identity, Remittance, and Logo Asset. WP07 later loads those facts durably; WP08 owns frozen fixtures/security hardening, WP09 HTTP, and WP11 UI.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless merged/revalidated exact P0 Frozen-or-later evidence and accepted WP02 output are present.
2. Use P0's P1 domain test hook without build-file edits.
3. Before each Project/resolver rule, add a failing public test driven by WP01 decision fixtures and record chronological `RED:` evidence; append matching `GREEN:` after minimal production work.
4. Resolution must be pure and deterministic for an explicit input fact set. No repositories, global clock, filesystem, SQL, HTTP, or mutable cache.
5. P1 stores cadence facts only. Period derivation, due-state calculation, date advancement, invoice creation, and immutable issuance snapshots are prohibited.
6. Stay inside WP05-owned files and use only synthetic facts.

```bash
spec-kitty agent action implement WP05 --agent codex
```

### Subtask T022: Implement Project lifecycle and billing facts

**Purpose**: Model one billable engagement with valid mutable defaults.

**Steps**:

1. Define Project ID/revision, Client ID, name/description, status, identity mode/override, currency/terms, service description/optional amount, cadence/anchor/next/end dates, logo mode/project asset, and audit facts.
2. Support Draft → Active ↔ Paused → Completed → Archived with only explicitly approved transitions.
3. Require Active Client/effective identity facts and valid dates/currency/amount/terms before Active.
4. Preserve next billing date as owner-managed configuration; never advance it automatically.
5. Return stable readiness errors sorted by field path/code.

**Files**: `project/model.zig`, `project/lifecycle.zig`, `project/readiness.zig`, tests.

**Validation**: All lifecycle, date, currency, amount, and Draft/Active cases pass through public aggregate methods.

### Subtask T023: Resolve identity inheritance and explicit override

**Purpose**: Make “Invoice header / billed from” behavior visible and deterministic.

**Steps**:

1. Resolve Active explicit Project override first when mode is Explicit.
2. Resolve Active Client default when mode is ClientDefault.
3. Reject missing/inactive selected identity and invalid mode/reference combinations.
4. Return typed provenance `project_override` or `client_default` with source revision.
5. Prove a Client default change affects inherited projects but not explicit overrides.

**Files**: `resolution/identity.zig`, focused tests.

**Validation**: WP01 identity decision fixtures plus inactive/concurrent-revision cases pass byte-equivalently.

### Subtask T024: Resolve remittance, currency/terms, and logo

**Purpose**: Apply approved policies to effective facts without leaking hidden data.

**Steps**:

1. Feed explicit Client market choice to WP02 remittance policy and include a complete block only for Show.
2. Build distinct output variants so Domestic and Other/Hide cannot contain a remittance member.
3. Resolve Project currency/terms and their source provenance; reject mismatched default amount currency.
4. Resolve Logo Off to no reference; Logo On to active Project asset, then active identity default, then readiness error.
5. Return asset metadata/digest/path only when logo resolves On; never read the asset file here.
6. Preserve exact issuer/recipient/tax/contact values supplied by input facts without historical claims.

**Files**: `resolution/remittance.zig`, `resolution/defaults.zig`, `resolution/logo.zig`, tests.

**Validation**: Every remittance/logo/default decision fixture passes; hidden variants serialize without remittance/logo references.

### Subtask T025: Compose Resolved Invoice Configuration with provenance

**Purpose**: Produce P1's authoritative current configuration view for P2/P5/P6.

**Steps**:

1. Combine Project/Client/Identity revisions, effective issuer, recipient/contact/address, tax identifiers, market decision, defaults, cadence facts, logo decision, and readiness errors.
2. Attach provenance for every inherited/overridden value using WP01 wire literals.
3. Use stable field order and canonical P0 wire serialization inputs.
4. Distinguish current mutable configuration from immutable invoice snapshot in type/API naming.
5. Return all readiness errors for Draft review, but reject an Active/consumer-ready request when any blocker remains.

**Files**: `resolution/resolved_configuration.zig`, fixture adapters/tests.

**Validation**: Repeated resolution against unchanged revisions is byte-equivalent; changed revisions/provenance affect only documented fields.

### Subtask T026: Prove race-model, determinism, and coverage behavior

**Purpose**: Demonstrate resolver correctness before storage/application convergence.

**Steps**:

1. Model default-change, override deactivation, client archive, asset deactivation, and Project activation interleavings as explicit input snapshots.
2. Require each snapshot to resolve one valid outcome or a stable readiness/conflict result, never a dangling reference.
3. Run decision fixtures in randomized input order and compare canonical outputs.
4. Add deletion tests for identity precedence, omitted remittance, logo fallback, date guard, and provenance.
5. Run domain coverage at 90% or better and scan for persistence/schedule/issuance imports.
6. Record focused/aggregate commands and owned-file diff.

**Files**: Tests within WP05-owned directories.

**Validation**: Race-model, determinism, deletion, coverage, forbidden-import, and `git diff --check` gates pass.

## Definition of Done

- [ ] Exact P0/WP02 gates precede edits.
- [ ] Project lifecycle/default/cadence facts match the specification.
- [ ] Identity precedence and provenance are explicit.
- [ ] Hidden remittance/logo shapes are structurally absent.
- [ ] Current resolved configuration is deterministic and not an issued snapshot.
- [ ] No schedule advancement, issuance, persistence, or HTTP behavior exists.
- [ ] RED/GREEN evidence and 90% domain coverage pass.
- [ ] Only WP05-owned files changed.

## Risks

- **Snapshot confusion**: name and document the output as current configuration only.
- **Policy drift**: call WP02 policy functions instead of duplicating branches.
- **Hidden-data leakage**: use distinct output variants and structural tests.
- **Concurrent stale facts**: carry all source revisions for WP07 to validate atomically.

## Reviewer Guidance

Review lifecycle transitions, identity precedence, hidden-field structure, logo fallback, amount/date rules, provenance completeness, deterministic/race-model evidence, and forbidden scope. Reject schedule advancement or immutable-history claims.
