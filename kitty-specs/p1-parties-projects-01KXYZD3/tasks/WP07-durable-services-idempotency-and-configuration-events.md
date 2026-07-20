---
work_package_id: "WP07"
title: "Durable Services, Idempotency, and Configuration Events"
dependencies: ["WP03", "WP04", "WP05", "WP06"]
requirement_refs: ["FR-001", "FR-005", "FR-006", "FR-009", "FR-010", "FR-015", "FR-016", "FR-017", "FR-018", "NFR-003", "NFR-004", "NFR-009", "C-002", "C-005", "C-006", "C-007", "C-008"]
subtasks: ["T033", "T034", "T035", "T036", "T037", "T038"]
owned_files:
  - "services/api/src/domains/parties_projects/application/**"
  - "services/api/src/domains/parties_projects/events/**"
  - "services/api/tests/parties_projects/application/**"
  - "services/api/tests/parties_projects/events/**"
authoritative_surface: "services/api/src/domains/parties_projects/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP07 – Durable Services, Idempotency, and Configuration Events

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Converge the four parallel domain/persistence lanes into durable application commands, queries, idempotent retries, optimistic revisions, atomic reassignments, and privacy-safe configuration events. A command succeeds only after its state, replay result, and event are durably confirmed together.

## Context

WP07 implements `IC-07` after WP03–WP06 are independently accepted. It may import their public surfaces but owns the orchestration and event-projection code. WP08 hardens resolved/security fixtures; WP09 adds transport. Invoice issuance, rendering, scheduling, authentication, and analytics remain outside P1.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless exact P0 Frozen/merged/revalidated evidence and accepted WP03, WP04, WP05, and WP06 commits are present on the dependency base.
2. Run all four producer-focused test groups and the P0 persistence integration gate before editing.
3. Before each command/query/event behavior, add a failing public application test with `RED:` evidence; append matching `GREEN:` only after the minimal production change.
4. Test state, idempotency result, and event append through one real serialized unit of work; mocks cannot satisfy durability acceptance.
5. Never acknowledge before checkpoint/directory sync. Never blindly replay after `durability_unconfirmed`.
6. Events and logs must exclude bank, address, tax, contact, note, asset-path, SQL, and raw engine values.

```bash
spec-kitty agent action implement WP07 --agent codex
```

### Subtask T033: Implement aggregate command and query services

**Purpose**: Provide one application boundary for identity, asset, Client/contact, Project, and resolved-configuration use cases.

**Steps**:

1. Define typed commands for create/update/status/reassign/upload/archive/restore operations and typed queries for list/detail/resolve.
2. Load repository facts, invoke the owning aggregate policy, and persist only a validated result.
3. Keep each command bounded to one serialized unit of work and pass explicit expected revisions.
4. Return stable application result/error types independent of HTTP envelopes.
5. Prevent commands from reaching issuance, rendering, numbering, payment, schedule, or reporting behavior.

**Files**: `application/commands/**`, `application/queries/**`, focused tests.

**Validation**: Happy/error cases for every FR-backed owner action pass through public service interfaces.

### Subtask T034: Implement idempotent create/upload/transition retries

**Purpose**: Return the original durable result for a repeated identical request and reject conflicting reuse.

**Steps**:

1. Define canonical request fingerprint inputs that exclude volatile correlation metadata.
2. Within the unit of work, claim a key, store fingerprint and canonical result, and commit it with domain/event state.
3. Return the original result when key/fingerprint match; return `idempotency_conflict` when content differs.
4. Handle concurrent claims with one winner and a deterministic loser/replay path.
5. On durability uncertainty, inspect completion metadata rather than rerunning domain mutation.

**Files**: `application/idempotency.zig`, command integration tests.

**Validation**: Identical retry, conflicting retry, concurrent retry, crash boundary, and close/reopen cases produce exactly one domain result/event.

### Subtask T035: Enforce expected revisions and atomic reassignments

**Purpose**: Serialize consequential cross-aggregate changes without dangling references.

**Steps**:

1. Require expected revisions for updates, deactivation, archive/restore, and atomic reassignment.
2. Reload and validate all affected Identity/Asset/Client/Project facts on the same handle immediately before writes.
3. Apply reassignment plus deactivation in one unit of work or apply neither.
4. Return deterministic conflict facts for stale/missing/inactive references.
5. Add concurrency cases for default change versus Project activation and override/asset deactivation.

**Files**: `application/revisions.zig`, `application/reassignment.zig`, race/integration tests.

**Validation**: Covered interleavings yield one valid serialized outcome and zero dangling references after reopen.

### Subtask T036: Project privacy-safe configuration events

**Purpose**: Emit P1 business facts using WP01 schemas without leaking display/sensitive state.

**Steps**:

1. Map successful changes to the exact P1 event name/version and P0 envelope.
2. Include identifiers, revision, lifecycle status, safe market/cadence/choice facts, and causation/correlation metadata only.
3. Exclude all sensitive/data-heavy fields listed in the entry gate.
4. Append events in the same transaction as state/idempotency result.
5. Validate serialized payloads against exact WP01 schemas before commit or in a deterministic producer test path.

**Files**: `events/projection.zig`, `events/append.zig`, event tests.

**Validation**: Schema validation, order, retry deduplication, and sentinel scans pass; failed commands emit no event.

### Subtask T037: Implement checkpoint-before-success completion semantics

**Purpose**: Make FR-018 observable at the application boundary.

**Steps**:

1. Execute validated writes, replay record, and event append through WP06 unit of work.
2. Return success only after commit, checkpoint, and directory sync confirmation.
3. Translate pre-commit failures to stable command errors and post-commit uncertainty to `durability_unconfirmed` with safe completion token/metadata.
4. Implement completion retry that confirms the original result without duplicating mutation/event.
5. Keep raw engine diagnostics, paths, SQL, and values out of results/logs.

**Files**: `application/durable_execution.zig`, fault-injection tests.

**Validation**: Faults at every boundary plus restart prove no false success and no duplicate replay.

### Subtask T038: Prove service integration, concurrency, and coverage

**Purpose**: Establish application readiness for resolved fixture and HTTP work.

**Steps**:

1. Run representative full commands for every aggregate against the real P0-backed WP06 repository.
2. Checkpoint, close, reopen, and compare state, replay result, and events.
3. Run concurrent default/override/deactivation/activation/idempotency model cases repeatedly.
4. Add deletion tests for validation-before-write, expected revision, atomicity, event redaction, and checkpoint-before-success.
5. Run application/event coverage at 90% or better and all producer/aggregate gates.
6. Record exact commits/commands, canary scans, and clean owned-file diff.

**Files**: WP07-owned application/event tests.

**Validation**: Focused, real persistence, concurrency, restart, coverage, privacy, and `git diff --check` gates pass.

## Definition of Done

- [ ] P0 and all four producer-lane acceptance evidence precedes edits.
- [ ] All owner use cases pass through typed application services.
- [ ] Idempotent retries return one durable result/event.
- [ ] Revisions/reassignments serialize without dangling references.
- [ ] Events match WP01 and contain no sensitive fields.
- [ ] Success is impossible before durable confirmation.
- [ ] RED/GREEN, restart, concurrency, privacy, and 90% coverage evidence pass.
- [ ] Only WP07-owned files changed.

## Risks

- **Mock-only durability**: require real P0 seam close/reopen evidence.
- **Retry duplication**: persist replay facts in the original unit of work.
- **TOCTOU references**: reload/validate/write on one serialized handle.
- **Event privacy**: maintain strict allowlist and canary tests.

## Reviewer Guidance

Review unit-of-work boundaries, idempotency fingerprints, concurrency outcomes, event schema/redaction, failure translation, and checkpoint-before-success. Delete each critical guard and prove its public integration case fails.
