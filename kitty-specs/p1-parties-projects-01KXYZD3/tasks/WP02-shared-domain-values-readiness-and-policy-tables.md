---
work_package_id: "WP02"
title: "Shared Domain Values, Readiness, and Policy Tables"
dependencies: ["WP01"]
requirement_refs: ["FR-004", "FR-006", "FR-007", "FR-008", "FR-010", "FR-011", "FR-012", "FR-013", "FR-014", "NFR-005", "NFR-008", "NFR-009", "C-002", "C-003", "C-004"]
subtasks: ["T007", "T008", "T009", "T010", "T011"]
owned_files:
  - "services/api/src/domains/parties_projects/root.zig"
  - "services/api/src/domains/parties_projects/shared/**"
  - "services/api/tests/parties_projects/shared/**"
create_intent:
  - "services/api/src/domains/parties_projects/root.zig"
authoritative_surface: "services/api/src/domains/parties_projects/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP02 – Shared Domain Values, Readiness, and Policy Tables

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Implement the small Zig value and policy foundation shared by all P1 aggregates. The output must make readiness, remittance, logo, currency, cadence, lifecycle, and field-error rules explicit without depending on storage or HTTP details.

## Context

WP02 consumes WP01's exact Frozen-P0-composed contracts and addresses `IC-02`. WP03, WP04, and WP05 begin in parallel after this package. WP02 owns only the P1 root module and `shared/` value/policy code; later domain packages own their aggregate directories and must not edit this surface.

## Mandatory Entry, Red-First, and Evidence Gates

1. Verify the current baseline contains merged P0 and an exact Frozen-or-later P0 manifest matching WP01's consumed version and digest. Otherwise stop without code changes.
2. Verify WP01 is accepted and its contract/decision fixtures are present on the dependency base.
3. Invoke P0's stable P1-compatible Zig test hook before editing; a missing hook or root-module convention is a P0 handoff blocker.
4. For each value or policy rule, first add a failing public test through the exported P1 shared surface and append chronological `RED:` evidence.
5. Make the smallest implementation change, append matching `GREEN:` evidence, then run the complete shared group.
6. No SQL, ShovelerDB handle, HTTP envelope, Next.js logic, or aggregate state belongs in this package.
7. Do not edit P0 build files. Tests must be discovered through the convention established by P0.

Start only after the gate passes:

```bash
spec-kitty agent action implement WP02 --agent codex
```

### Subtask T007: Define canonical P1 enums and identifiers

**Purpose**: Represent approved closed vocabularies and P0-backed identifiers without string drift.

**Steps**:

1. Define Billing Identity kind/status, Client status, Project status, Billing Market, remittance mode, identity mode, logo mode, cadence, and provenance enums.
2. Reuse P0 `EntityId`, `LocalDate`, `UtcInstant`, Money, and decimal-string types rather than wrapping incompatible alternatives.
3. Provide strict wire parse/serialize mappings matching WP01 contract literals exactly.
4. Reject aliases, unknown case, whitespace, numeric coercion, and illegal terminal-state transitions.
5. Export only stable domain-facing names from `root.zig`; do not expose P0 or ShovelerDB internals.

**Files**: `services/api/src/domains/parties_projects/shared/enums.zig`, `root.zig`, matching tests.

**Validation**: Round-trip every valid wire literal and reject every near miss; compile-time tests prove no floating-point amount type enters the surface.

### Subtask T008: Implement exact currency, Money, terms, and date rules

**Purpose**: Centralize exact defaults and cadence-fact validation used by Client and Project.

**Steps**:

1. Accept only USD and EUR as launch currencies while retaining P0's structural wire representation.
2. Require canonical signed-64-bit decimal minor units and matching amount/project currency.
3. Validate payment terms as whole calendar days from 0 through 365.
4. Validate monthly/quarterly cadence, schedule anchor, next billing date, and optional end-date ordering without computing recurrence.
5. Return stable P1 errors with JSON Pointer-compatible field paths.
6. Add boundary/property cases for min/max amounts, leading zeros, overflow, leap dates, equal dates, and next-date-after-end.

**Files**: `shared/money_policy.zig`, `shared/date_policy.zig`, tests under `tests/parties_projects/shared/`.

**Validation**: Property/boundary suite passes with no binary floating point or schedule advancement behavior.

### Subtask T009: Model readiness diagnostics and revisions

**Purpose**: Give aggregates one deterministic way to report incomplete Draft versus invalid activation.

**Steps**:

1. Define stable readiness/error codes used by identity, client, project, remittance, and logo decisions.
2. Store errors as deterministic `(code, field_path)` values with no sensitive rejected input.
3. Define expected-revision comparison and conflict output independent of transport.
4. Sort multi-field diagnostics by canonical field path and code so unchanged state is byte-equivalent.
5. Separate saveable Draft incompleteness from command rejection and inactive-reference failures.

**Files**: `shared/readiness.zig`, `shared/revision.zig`, focused tests.

**Validation**: Permuted validation order yields identical diagnostics; canary account values never appear in messages.

### Subtask T010: Implement pure remittance and logo decision tables

**Purpose**: Encode the approved policy matrix once for aggregate and resolver reuse.

**Steps**:

1. Implement Domestic → Hide with no remittance shape, Europe → Require Show, and Other → explicit Show/Hide or readiness error.
2. Implement Logo Off → no reference, Logo On → active project asset then active identity default then readiness error.
3. Return decisions/provenance only; do not load rows, files, or serialize response objects here.
4. Use exhaustive switches so new enum values fail compilation until policy is updated.
5. Drive tests from WP01 decision fixtures, including omitted-field expectations.

**Files**: `shared/remittance_policy.zig`, `shared/logo_policy.zig`, fixture-driven tests.

**Validation**: Every decision row passes and deleting any branch makes its named test fail.

### Subtask T011: Prove shared-policy determinism and critical-branch coverage

**Purpose**: Establish a stable foundation before four parallel implementation lanes begin.

**Steps**:

1. Run all shared value/policy cases through the public P1 root module.
2. Cover every readiness, parsing, lifecycle, currency, date, remittance, logo, and revision branch.
3. Add deterministic-repeat and randomized-order tests where validation aggregates multiple errors.
4. Run the P0-provided P1/shared coverage hook and require at least 90% domain coverage.
5. Scan production/test paths for SQL, storage handles, HTTP responses, floating point, schedule advancement, and sensitive fixture values.
6. Record exact commands, coverage evidence, and the clean owned-file diff in the handoff.

**Files**: Tests within `services/api/tests/parties_projects/shared/**` only.

**Validation**: Focused tests, aggregate Zig check, coverage threshold, forbidden-import scan, and `git diff --check` pass.

## Definition of Done

- [ ] Exact Frozen P0 and accepted WP01 evidence is recorded before edits.
- [ ] Closed enums and wire literals match the composed contracts.
- [ ] Money/date/terms/currency rules are exact and contain no recurrence behavior.
- [ ] Readiness errors are stable, deterministic, and redact rejected values.
- [ ] Remittance and logo tables cover every approved case.
- [ ] Chronological RED/GREEN evidence exists for every behavior.
- [ ] Public tests and critical branches meet the 90% domain threshold.
- [ ] Only WP02-owned files changed; P0 build and other P1 lanes remain untouched.

## Risks

- **Policy duplication**: all downstream aggregates must consume these pure tables.
- **Wire drift**: compare enum mappings to WP01 exact fragments/fixtures.
- **Sensitive diagnostics**: store codes and paths, never rejected account values.
- **Schedule scope creep**: validate facts only; P6 owns periods and advancement.
- **Parallel overlap**: later lanes may import but never modify `shared/**` or `root.zig`.

## Reviewer Guidance

Review exhaustive enum switches, exact P0 type reuse, amount/date boundary tests, deterministic error ordering, absence-versus-null semantics, forbidden imports, deletion-test evidence, and the coverage result. Reject any business rule living only in tests or duplicated into downstream packages.
