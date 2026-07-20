---
work_package_id: "WP06"
title: "Owner-Scoped Migrations and Repositories"
dependencies: ["WP01"]
requirement_refs: ["FR-015", "FR-017", "FR-018", "NFR-004", "NFR-005", "NFR-009", "C-001", "C-002", "C-008", "C-009"]
subtasks: ["T027", "T028", "T029", "T030", "T031", "T032"]
owned_files:
  - "services/api/migrations/p1/**"
  - "services/api/src/domains/parties_projects/persistence/**"
  - "services/api/tests/parties_projects/persistence/**"
authoritative_surface: "services/api/"
execution_mode: "code_change"
agent_profile: "implementer-ivan"
role: "implementer"
agent: "codex"
model: ""
---

# Work Package Prompt: WP06 – Owner-Scoped Migrations and Repositories

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Create P1's forward-only owner migrations and repository adapters through P0's serialized durable-store seam. This lane must prove checkpoint-close-reopen behavior and cross-row integrity without importing ShovelerDB outside the P0 adapter boundary.

## Context

WP06 addresses `IC-06` and runs in parallel with WP03–WP05 after WP01. It may consume P0 migration/persistence APIs and WP01 contract metadata, but it cannot depend on another parallel domain implementation. Repository records use neutral row/value structures until WP07 maps complete aggregates.

## Mandatory Entry, Red-First, and Evidence Gates

1. Stop unless the current baseline contains merged P0 and exact Frozen-or-later P0 manifest/digest evidence, including the public pinned persistence seam.
2. Verify WP01 is accepted and P0 migration, persistence-integration, crash, and coverage hooks exist. Missing hooks are a P0 blocker; never edit `build.zig`.
3. Add a failing public migration/repository/durability case before production work and record chronological `RED:` evidence; append matching `GREEN:` after the smallest change.
4. Use only P0's serialized store interface. No ShovelerDB handle, result, borrowed slice, raw engine diagnostic, or sibling source path may escape into P1.
5. Every successful consequential repository operation is acknowledged only after commit, checkpoint, and supported directory sync; failure returns `durability_unconfirmed` without blind replay.
6. Stay inside WP06-owned paths and use temporary synthetic databases.

```bash
spec-kitty agent action implement WP06 --agent codex
```

### Subtask T027: Author forward-only P1 migrations

**Purpose**: Define owner-scoped storage for all P1 aggregates and durable command facts.

**Steps**:

1. Create UUIDv7-named migrations under `services/api/migrations/p1/` using P0 descriptors/dependency schema.
2. Add tables/indexes for identities, remittance, tax IDs, logo metadata, Clients, contacts, Projects, idempotency records, and P1 event records where P0 does not supply them.
3. Encode IDs, revisions, statuses, canonical decimal strings, dates/instants, and bounded text explicitly.
4. Do not assume foreign keys, global sequences, or session-transactional DDL.
5. Make each migration idempotent under P0 runner semantics and immutable after application.
6. Add corrupt descriptor, dependency, duplicate ID, partial DDL, and re-run negative cases.

**Files**: `services/api/migrations/p1/**`.

**Validation**: Fresh migrate, repeated no-op, dependency order, failed-startup discard/reopen, and descriptor-negative commands pass.

### Subtask T028: Implement aggregate repository row mappings

**Purpose**: Isolate storage representation from P1 domain/application layers.

**Steps**:

1. Define repository interfaces and private row codecs for each aggregate family.
2. Copy all borrowed query values before releasing results through P0's seam.
3. Encode text only through P0's tested literal/parameter boundary; identifiers remain compile-time constants.
4. Preserve canonical IDs, revisions, Money strings, dates, status literals, digest bytes, and deterministic child ordering.
5. Map missing/duplicate/malformed rows to stable P1 categories without raw SQL, paths, or engine prose.
6. Keep domain conversions in explicit adapter functions suitable for WP07 composition.

**Files**: `persistence/repositories.zig`, `persistence/row_codec.zig`, split modules/tests as needed.

**Validation**: Round-trip each record family, apostrophes/backslashes/Unicode, malformed rows, borrowed-value lifetime, and diagnostic redaction pass through the public repository seam.

### Subtask T029: Implement serialized cross-row integrity queries

**Purpose**: Counter the database's lack of foreign keys and application-column uniqueness.

**Steps**:

1. Add serialized checks for active references, one primary contact, unique idempotency key, expected revision, and immutable asset digest/path.
2. Add deterministic reference enumeration for identity/asset deactivation and reassignment.
3. Ensure checks and writes run on the same serialized handle/transaction boundary.
4. Reject duplicate or dangling records before mutation and return stable conflict facts.
5. Do not implement aggregate policy; accept validated command facts from WP07 later.

**Files**: `persistence/integrity.zig`, focused tests.

**Validation**: Duplicate, dangling, concurrent-reference, primary-contact, stale-revision, and reassignment enumeration cases pass.

### Subtask T030: Implement durable repository transaction completion

**Purpose**: Expose one safe unit-of-work boundary for WP07.

**Steps**:

1. Begin a P0 durable transaction and group row changes, idempotency result, and event append.
2. Commit, checkpoint, and parent-directory-sync before returning confirmed success.
3. Distinguish validation/write/commit failure from committed-but-checkpoint/sync-uncertain state.
4. On uncertainty, retain completion metadata for safe retry and never replay domain mutation blindly.
5. On failed startup/migration, discard/close dirty state without checkpoint and reopen last confirmed snapshot.

**Files**: `persistence/unit_of_work.zig`, `persistence/durability.zig`, tests.

**Validation**: Fault injection at begin/write/commit/checkpoint/sync/close boundaries produces documented, non-destructive outcomes.

### Subtask T031: Prove close/reopen, rollback, and crash boundaries

**Purpose**: Demonstrate real persistence behavior, not an in-memory repository substitute.

**Steps**:

1. Run migrations and repository writes against the real P0 ShovelerDB-backed seam in a temporary path.
2. Checkpoint, close, reopen, and compare exact records/revisions/digests.
3. Roll back failed writes and prove no partial row/idempotency/event state survives.
4. Exercise committed-but-uncheckpointed, failed directory sync, process termination, and dirty failed-startup recovery.
5. Verify retrying persistence completion confirms the original mutation without duplication.

**Files**: Integration/crash tests in `tests/parties_projects/persistence/**`.

**Validation**: P0 persistence integration/crash hooks pass with real files and synthetic values.

### Subtask T032: Prove repository coverage, privacy, and ownership

**Purpose**: Leave a reusable, independently reviewed persistence lane for application convergence.

**Steps**:

1. Cover every migration, row codec, integrity, transaction, durability, and diagnostic branch.
2. Add deletion tests for copied borrowed values, literal encoding, duplicate guards, rollback, and checkpoint-before-success.
3. Scan source/log capture for SQL text, private paths, raw engine diagnostics, bank/contact/tax canaries, and sibling checkout references.
4. Run migration-negative, persistence-integration, persistence-crash, coverage, and aggregate Zig commands.
5. Require 90% or better domain persistence coverage and all enumerated critical branches.
6. Record exact public P0 pin/digest and clean WP06-owned diff.

**Files**: WP06-owned tests only.

**Validation**: All focused/aggregate gates, scans, coverage, and `git diff --check` pass.

## Definition of Done

- [ ] Exact P0 Frozen/merged persistence evidence precedes edits.
- [ ] P1 migrations are owner-scoped, UUIDv7, forward-only, and idempotent.
- [ ] Repositories hide SQL/engine lifetimes and copy borrowed values.
- [ ] Cross-row guards prevent duplicates and dangling references.
- [ ] Success follows commit → checkpoint → directory sync.
- [ ] Restart/rollback/crash/uncertainty cases use the real P0 seam.
- [ ] RED/GREEN, coverage, privacy, and ownership evidence pass.

## Risks

- **DDL partial failure**: discard dirty handles and reopen last durable snapshot.
- **Blind retry duplication**: retry completion boundary, not the domain command.
- **ABI leakage**: P1 imports only P0 persistence interfaces.
- **Parallel model drift**: keep adapters neutral; WP07 performs domain mapping after convergence.

## Reviewer Guidance

Focus on exact P0 seam use, migration immutability, borrowed-value lifetime, SQL literal safety, serialized cross-row guards, fault-injection outcomes, close/reopen evidence, sensitive diagnostic scans, and path ownership. Reject in-memory-only proof or any ShovelerDB direct import.
