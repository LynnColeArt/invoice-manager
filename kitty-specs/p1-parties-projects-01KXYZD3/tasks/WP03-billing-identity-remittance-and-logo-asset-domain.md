---
work_package_id: "WP03"
title: "Billing Identity, Remittance, and Logo Asset Domain"
dependencies: ["WP02"]
requirement_refs: ["FR-001", "FR-002", "FR-003", "FR-004", "FR-005", "FR-015", "NFR-003", "NFR-005", "NFR-007", "NFR-009", "C-002", "C-005", "C-009"]
subtasks: ["T012", "T013", "T014", "T015", "T016"]
owned_files:
  - "services/api/src/domains/parties_projects/billing_identity/**"
  - "services/api/src/domains/parties_projects/remittance/**"
  - "services/api/src/domains/parties_projects/logo_asset/**"
  - "services/api/tests/parties_projects/billing_identity/**"
  - "services/api/tests/parties_projects/remittance/**"
  - "services/api/tests/parties_projects/logo_asset/**"
authoritative_surface: "services/api/src/domains/parties_projects/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP03 – Billing Identity, Remittance, and Logo Asset Domain

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Implement the Zig domain rules for Personal/Company Billing Identities, European Remittance Profiles, and immutable PNG Logo Assets. These aggregates must validate and protect consequential issuer data without owning persistence orchestration, HTTP, or UI behavior.

## Context

This `IC-03` package is one of four parallel lanes after WP02. It may import WP02 shared policies and WP01 contract fixtures but owns only its aggregate directories and tests. WP07 later supplies commands, idempotency, durable events, and repository orchestration.

## Mandatory Entry, Red-First, and Evidence Gates

1. Hard stop unless exact P0 Frozen-or-later manifest evidence is merged and revalidated on this baseline and WP02 is accepted.
2. Run the P0-provided P1 domain test hook before edits; do not change build files to make the hook pass.
3. Before every production rule, add a failing test through a public aggregate operation and append `RED:` command/expected/observed evidence.
4. Append matching `GREEN:` evidence after the smallest implementation; test-after-code or private-helper-only evidence is invalid.
5. Use synthetic remittance/logo inputs. Logs, diagnostics, and event-like test summaries must not expose full account-holder, IBAN, BIC, instruction, filename, or storage-path values.
6. Do not write repositories, SQL, application services, HTTP handlers, contracts, root modules, or another parallel lane's files.

```bash
spec-kitty agent action implement WP03 --agent codex
```

### Subtask T012: Implement Billing Identity lifecycle and legal details

**Purpose**: Model the Personal/Company issuer and its activation/deactivation invariants.

**Steps**:

1. Define identity state with P0 ID/revision/timestamps, kind, display/legal name, structured address reference/value, contact fields, labeled tax identifiers, payment terms, optional prefix, remittance reference, and default logo reference.
2. Permit incomplete construction only in a deliberate draft/edit value; require legal name/address and valid defaults before Active.
3. Normalize display-only whitespace without altering opaque tax values.
4. Make Active/Inactive transitions explicit and reject unknown or duplicate transitions.
5. Return stable readiness errors with field paths and no rejected values.

**Files**: `billing_identity/model.zig`, `billing_identity/policy.zig`, focused tests.

**Validation**: Personal and Company happy paths, incomplete activation, revision conflict inputs, and transition matrix pass through public aggregate methods.

### Subtask T013: Validate and canonicalize European remittance profiles

**Purpose**: Produce complete, canonical remittance values suitable only when policy resolves to Show.

**Steps**:

1. Require account holder, bank name, IBAN, BIC/SWIFT, and USD/EUR remittance currency.
2. Canonicalize IBAN/BIC case and spacing; validate IBAN structure/check digits and BIC length/character rules.
3. Bound optional bank address and payment instructions and reject control characters.
4. Separate profile completeness/active state from market visibility decisions in WP02.
5. Provide masked display values without exposing raw values in errors or formatting/debug output.
6. Add country-length, checksum, overflow, Unicode/control, and inactive-profile cases.

**Files**: `remittance/model.zig`, `remittance/validation.zig`, `remittance/masking.zig`, tests.

**Validation**: Known synthetic valid/invalid vectors pass; canary scans find zero complete sensitive values in diagnostics.

### Subtask T014: Implement bounded PNG Logo Asset ingestion

**Purpose**: Validate immutable artwork content without trusting filenames, declared MIME type, or unbounded decoders.

**Steps**:

1. Accept only nonempty PNG up to 2 MiB and configured decoded dimension/pixel bounds.
2. Validate signature/chunk structure and decoded media agreement through the approved bounded decoder on the baseline.
3. Compute SHA-256 over exact bytes and derive an opaque application-owned path; never use the original filename as a path.
4. Treat content/digest/path as immutable; replacement creates a new asset version.
5. Model Active/Inactive state and a sanitized optional display name.
6. Reject malformed/truncated files, polyglot/discordant media, decompression bombs, traversal filenames, and inactive selection.

**Files**: `logo_asset/model.zig`, `logo_asset/png_validation.zig`, `logo_asset/path_policy.zig`, tests.

**Validation**: Positive PNG plus size, type, content, dimension, digest, replacement, and path-negative cases pass without writing outside a temporary artifact root.

### Subtask T015: Enforce deactivation and atomic reassignment preconditions

**Purpose**: Prevent active Clients/Projects from becoming unresolved when identity or asset state changes.

**Steps**:

1. Define pure guard inputs that summarize active references without importing repositories.
2. Reject deactivation when an active default/override/logo reference remains and no complete reassignment set is supplied.
3. Validate proposed replacement identities/assets are Active and compatible before permitting the transition.
4. Return deterministic conflict lists sorted by entity ID and reference kind.
5. Keep actual atomic persistence in WP07; this package supplies validated state transitions only.

**Files**: Guard modules under the three aggregate directories and focused tests.

**Validation**: Missing, partial, stale-revision, inactive-replacement, complete-reassignment, and concurrent-snapshot model cases pass.

### Subtask T016: Prove aggregate safety and branch coverage

**Purpose**: Establish complete domain evidence before services or HTTP can depend on issuer data.

**Steps**:

1. Run model/property tests for every lifecycle, readiness, remittance, masking, asset, and reassignment branch.
2. Drive relevant cases from WP01 decision fixtures and WP02 policy outputs.
3. Add deletion tests for IBAN checksum, diagnostic redaction, PNG size/type/dimension, immutable digest, and deactivation guards.
4. Run P1 domain coverage and require at least 90% with every security-critical branch represented.
5. Scan owned source/tests for raw secret logging, unsafe path construction, SQL, HTTP, and persistence imports.
6. Record exact focused/aggregate commands and clean owned-file diff.

**Files**: Tests in WP03-owned test directories.

**Validation**: Focused tests, coverage, canary/path scans, aggregate Zig gate, and `git diff --check` pass.

## Definition of Done

- [ ] P0 Frozen/merged/revalidated and WP02 acceptance evidence precedes edits.
- [ ] Identity kind/details/lifecycle and readiness rules are explicit.
- [ ] Remittance validation is canonical, complete, and redacted.
- [ ] Logo ingestion is PNG-only, bounded, immutable, and path-safe.
- [ ] Deactivation cannot leave active references unresolved.
- [ ] Every production rule has chronological RED/GREEN evidence.
- [ ] Domain coverage is at least 90% with critical branches covered.
- [ ] Only WP03-owned files changed.

## Risks

- **Sensitive-data leakage**: use stable codes, paths, masks, and canary scans.
- **Unsafe image parsing**: strict byte/pixel limits and decoded-type agreement.
- **Cross-lane coupling**: accept pure reference summaries; persistence stays in WP06/WP07.
- **Historical mutation**: these are mutable master-data rules only; issued documents are out of scope.

## Reviewer Guidance

Focus on IBAN/BIC correctness, redaction, bounded PNG handling, digest/path immutability, deactivation/reassignment semantics, exhaustive tests, and forbidden-layer imports. Delete each critical guard to prove its public test fails.
