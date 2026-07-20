---
work_package_id: WP07
title: Durable Serialized Storage Boundary
dependencies:
- WP04
- WP06
requirement_refs:
- FR-012
- FR-013
- FR-014
- NFR-005
- NFR-006
- NFR-009
- C-003
- C-004
- C-005
tracker_refs: []
planning_base_branch: feat/p0-contract-spine
merge_target_branch: feat/p0-contract-spine
branch_strategy: Planning artifacts for this mission were generated on feat/p0-contract-spine. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/p0-contract-spine unless the human explicitly redirects the landing branch.
subtasks:
- T031
- T032
- T033
- T034
- T035
- T036
phase: Phase 4
assignee: ''
agent: codex
history: []
agent_profile: implementer-ivan
authoritative_surface: services/api/src/platform/persistence/
create_intent:
- services/api/src/platform/persistence/root.zig
- services/api/src/platform/persistence/store.zig
- services/api/src/platform/persistence/durability.zig
- services/api/src/platform/persistence/directory_sync.zig
- services/api/src/platform/persistence/diagnostics.zig
- services/api/tests/persistence/store_test.zig
- services/api/tests/persistence/store_crash_helper.zig
- services/api/tests/persistence/durability_test.zig
- services/api/tests/persistence/durability_integration_test.zig
- services/api/tests/persistence/directory_sync_test.zig
execution_mode: code_change
model: ''
owned_files:
- services/api/src/platform/persistence/root.zig
- services/api/src/platform/persistence/store*
- services/api/src/platform/persistence/durability*
- services/api/src/platform/persistence/directory_sync*
- services/api/src/platform/persistence/diagnostic*
- services/api/tests/persistence/store*
- services/api/tests/persistence/durability*
- services/api/tests/persistence/directory_sync*
role: implementer
tags: []
task_type: implement
---

# Work Package Prompt: WP07 – Durable Serialized Storage Boundary

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## ⚠️ IMPORTANT: Review Feedback

Check `spec-kitty agent status` and the Activity Log before implementation.
If a reviewer returned this WP, treat every feedback item as required work.
Append the response and its verification evidence at the end of the Activity Log.

## Objectives & Success Criteria

Implement the one application-owned storage boundary that serializes each ShovelerDB handle and makes commit, checkpoint, Linux parent-directory synchronization, close, and reopen explicit.
Return durable success only after the state reaches `DirectorySynchronized`.
Represent a committed mutation whose checkpoint or directory sync is incomplete as `DurabilityUnconfirmed`, quarantine ordinary writes, and retry persistence completion without replaying business work.

Success requires real ShovelerDB evidence over at least 20 consecutive commit-checkpoint-directory-sync-close-reopen cycles.
Crash-boundary and injected-failure tests must distinguish rollback, commit, checkpoint, directory synchronization, and acknowledgment.
Every documented critical error branch must be covered, and durability code must meet the mission's 90% coverage threshold.

## Context & Constraints

This package implements plan concern `IC-06`.
WP04 provides the pinned ShovelerDB C-ABI adapter, owned result copies, literal encoder, service build, and integration hooks.
WP06 provides the parallel-safe migration runner and bootstrap migration.
WP07 composes those seams; it must not bypass or rewrite them.

The supported P0 production and acceptance platform is Linux x86_64.
On that platform, ShovelerDB `COMMIT` publishes an in-memory generation.
ShovelerDB checkpoint persists its snapshot, but close does not checkpoint.
The snapshot is installed by filesystem rename, so the database parent directory must be opened and `fsync`ed after checkpoint returns success.
Only then may the application report durable success.

The normative state path is:

```text
Ready
  -> TransactionActive
  -> Committed
  -> Checkpointed
  -> DirectorySynchronized
  -> Acknowledged

TransactionActive -> RolledBack
Committed -> DurabilityUnconfirmed -> Checkpointed -> DirectorySynchronized
Checkpointed -> DurabilityUnconfirmed -> DirectorySynchronized
```

There is no success transition directly from `Committed` or `Checkpointed`.
There is no silent non-Linux fallback in P0.
An unsupported platform or filesystem fails readiness with a stable diagnostic.

## Strict Scope and Ownership Boundary

Stay within the exact frontmatter ownership patterns.
Do not edit WP04's ShovelerDB adapter or service build files.
Do not edit WP06's migration sources, descriptors, or tests.
Register WP07 modules and tests through the extension surface already established by WP04.
If a necessary build hook is absent, record an integration-owner handoff; do not make an out-of-map build edit.

This package owns a generic persistence boundary, not domain storage.
Do not add client, project, invoice, billing identity, payment, analytics, authentication, logo, PDF, or recurrence repositories.
Do not define feature tables, domain records, domain commands, or event payloads.
Do not add an ORM, query builder, general-purpose repository registry, or dynamic SQL identifier API.
Do not add HTTP status mapping, routes, middleware, handlers, response envelopes, or retry policy.
Do not make the web application aware of ShovelerDB.

Tests may use synthetic probe records and operation IDs only.
The probe schema remains test-only and must not be exported as application schema.

## Branch Strategy

- **Strategy**: `wp_branch`
- **Planning base branch**: `feat/p0-contract-spine`
- **Merge target branch**: `feat/p0-contract-spine`
- **Required dependency outputs**: accepted WP04 and WP06 changes

Begin the governed implementation with:

```bash
spec-kitty agent action implement WP07 --agent codex
```

Allow Spec Kitty to select the dependency-aware branch base.
Do not manually land on `main` or bypass work-package review.
Completed changes merge back into `feat/p0-contract-spine` unless the human explicitly redirects them.

## Subtasks & Detailed Guidance

### Subtask T031 – Enforce a Single-Process Writer Lease

- **Purpose**: guarantee at most one owned ShovelerDB handle and one active operation for each canonical database path within the service process.
- **Primary files**: `store.zig`, `root.zig`, and `store_test.zig`.

#### Steps

1. Canonicalize the configured database path before using it as a lease key.
2. Preserve the canonical path privately for filesystem operations and internal diagnostics.
3. Maintain one process-local lease registry or manager keyed by canonical path.
4. Acquire the lease before opening ShovelerDB.
5. Refuse a second open for the same canonical path with `database_path_already_leased`.
6. Permit independent handles for distinct canonical paths.
7. Treat lexical aliases, relative paths, and symlink-resolved equivalents as the same path when the platform can resolve them safely.
8. Hold the lease until the handle has completed its verified close path.
9. Release the lease on safe open failure and after successful close.
10. Do not release it while a quarantined handle still owns unresolved durable state.
11. Serialize every migration, read, mutation, checkpoint, recovery, and close operation through one operation gate.
12. Keep the WP04 raw handle private and prevent copying the store owner.
13. Reject operations in `Opening`, `Closing`, `Closed`, or `Quarantined` with stable errors.
14. Make lock ordering explicit so shutdown cannot deadlock with an active mutation.
15. Avoid a global database singleton; the registry coordinates paths, not application domains.

This is an in-process ownership invariant.
P0 does not claim a distributed writer lease.
The reference deployment still requires one API process/replica per database path.
Do not silently support multiple replicas on one path.

#### Validation

- Open the same path through absolute, relative, and canonical aliases and permit only one lease.
- Open two different temporary paths concurrently and permit both.
- Prove two concurrent operations on one store never overlap inside the adapter.
- Prove an open failure does not leak a lease.
- Prove closing waits for or safely rejects an active operation.
- Prove no raw ShovelerDB handle crosses the module boundary.

### Subtask T032 – Build the Serialized Receipt Transaction Boundary

- **Purpose**: execute one consequential mutation exactly once inside a serialized transaction and return an evidence-rich receipt.
- **Primary files**: `store.zig`, `durability.zig`, `store_test.zig`, and `durability_test.zig`.

#### Steps

1. Accept a synthetic/application-provided `operation_id` and a mutation callback or command object.
2. Acquire the path's operation gate before starting `BEGIN`.
3. Transition `Ready -> TransactionActive` before invoking mutation work.
4. Execute `BEGIN` through the WP04 adapter.
5. Invoke the mutation work once while the serialized boundary is held.
6. Let later domain services perform writes, event insertion, and idempotency recording inside that callback.
7. Do not implement those domain writes in P0.
8. On any pre-commit failure, attempt `ROLLBACK` and return `RolledBack` only when rollback is confirmed.
9. If rollback itself fails, quarantine the store and return a distinct diagnostic.
10. Execute `COMMIT` once after the callback succeeds.
11. Once commit is confirmed, never call the mutation callback again as recovery.
12. Initialize the receipt as committed with checkpoint unconfirmed and directory sync not attempted.
13. Invoke the T033 persistence-completion stages in strict order.
14. Return acknowledged success only from `DirectorySynchronized`.
15. Preserve the exact stage states and stable error category in non-success receipts.
16. Release the operation gate only after state and receipt are internally consistent.

Keep the transaction callback generic and storage-scoped.
Do not encode HTTP idempotency, job retries, or business policy here.
Do not collapse `RolledBack` and `DurabilityUnconfirmed` into one error.

#### Validation

- Count callback invocations and prove exactly one on success and post-commit failure.
- Prove callback failure triggers rollback, no checkpoint, and no directory sync.
- Prove commit failure never returns a committed receipt.
- Prove checkpoint starts only after confirmed commit.
- Prove directory sync starts only after confirmed checkpoint.
- Prove acknowledgment is impossible unless both persistence stages are confirmed.

### Subtask T033 – Checkpoint and Synchronize the Linux Parent Directory

- **Purpose**: make ShovelerDB's snapshot rename durable on the supported Linux baseline before acknowledgment.
- **Primary files**: `durability.zig`, `directory_sync.zig`, `directory_sync_test.zig`, and integration tests.

#### Steps

1. Call the WP04 adapter's real ShovelerDB checkpoint after confirmed commit.
2. Treat an ABI checkpoint error as `checkpoint_state = Unconfirmed`.
3. Set directory sync to `NotAttempted` when checkpoint is unconfirmed.
4. After checkpoint succeeds, transition to `Checkpointed`.
5. Derive the parent directory from the already canonical database path.
6. Open that directory itself, not merely the database file.
7. Use the Zig `0.16.0` Linux file-descriptor API to call `fsync` on the open directory.
8. Close the directory descriptor on every path.
9. Transition to `DirectorySynchronized` only after `fsync` returns success.
10. Return acknowledgment eligibility only from that state.
11. Use a narrow injectable checkpoint and directory-sync interface for deterministic fault tests.
12. Bind production wiring to the real WP04 checkpoint and real Linux directory sync.
13. Reject unsupported operating systems or filesystem behavior explicitly.
14. Never replace directory `fsync` with file-only `fsync`, `syncfs`, sleep, close, or optimistic logging.
15. Use the same completion sequence after committed startup migrations and before clean shutdown close.

P0 supports Linux x86_64 only.
Do not add unverified macOS or Windows branches that report the same durability guarantee.
Do not weaken the guarantee when a filesystem rejects directory synchronization.

#### Validation

- Unit-test exact checkpoint-before-directory-sync call order.
- Inject checkpoint failure and assert directory sync was never called.
- Inject directory open, `fsync`, and close-path failures separately.
- On sync failure, assert checkpoint remains confirmed while sync is unconfirmed.
- Run the real implementation on a Linux temporary directory.
- Assert success receipts always end in `DirectorySynchronized`.

### Subtask T034 – Model Durability Uncertainty, Quarantine, and Shutdown

- **Purpose**: prevent blind mutation replay and unsafe close after a commit whose durable completion is unknown.
- **Primary files**: `durability.zig`, `store.zig`, `diagnostics.zig`, and their tests.

#### Failure semantics

- Commit not confirmed: roll back when possible; do not claim the mutation committed.
- Commit confirmed, checkpoint failed: `DurabilityUnconfirmed`, checkpoint unconfirmed, sync not attempted.
- Checkpoint confirmed, directory sync failed: `DurabilityUnconfirmed`, checkpoint confirmed, sync unconfirmed.
- Directory sync confirmed: `DirectorySynchronized`; only this state may be acknowledged.

#### Steps

1. Move the store to `DurabilityUnconfirmed` after either post-commit failure.
2. Quarantine ordinary mutations and migration starts while durable completion is unresolved.
3. Fail readiness through a storage status; do not add HTTP policy here.
4. Permit only the exact remaining persistence-completion work and shutdown inspection.
5. For checkpoint failure, retry checkpoint and then directory sync without rerunning the mutation.
6. For directory-sync failure, retry directory sync only; do not repeat commit or business work.
7. Retain the receipt and operation ID across the in-process recovery attempt.
8. Make recovery idempotent with stage call counts asserted in tests.
9. On shutdown, reject new work and transition to `Closing` under the operation gate.
10. Let an active pre-commit transaction finish or roll back deterministically.
11. If commit already happened, complete checkpoint and directory sync before close.
12. Close the ShovelerDB handle only after durable completion is confirmed.
13. If completion remains impossible, return `shutdown_durability_unconfirmed`, keep the state quarantined, and never log a clean shutdown.
14. Ensure shutdown and recovery cannot deadlock or acknowledge the same operation twice.
15. Preserve enough stable diagnostic state for an operator to distinguish the failed stage.

Do not delete, replace, truncate, or recreate a corrupt database automatically.
Do not treat process restart as proof that an uncertain operation failed.
Do not replay a mutation because an acknowledgment was not observed.

### Subtask T035 – Add Real Reopen, Crash-Boundary, and Fault Coverage

- **Purpose**: prove durability with the pinned engine and verify every persistence boundary under realistic failure.
- **Primary files**: `durability_integration_test.zig`, `store_crash_helper.zig`, `store_test.zig`, and `directory_sync_test.zig`.

#### Twenty-cycle acceptance test

1. Create one temporary Linux database and synthetic probe schema.
2. For each cycle from 1 through 20, open one store lease.
3. Begin a serialized mutation with a unique synthetic operation ID.
4. Insert the cycle record and commit.
5. Run real ShovelerDB checkpoint.
6. Run real parent-directory `fsync`.
7. Assert the receipt is `DirectorySynchronized` before treating it as acknowledged.
8. Cleanly close the store and release the lease.
9. Reopen through a new lease.
10. Verify every previously acknowledged cycle record remains present.
11. Repeat without deleting or reseeding the database.
12. Report zero acknowledged record loss across all 20 cycles.

#### Fault-injection matrix

- mutation callback failure before commit;
- rollback failure;
- commit failure;
- checkpoint failure after commit;
- directory open failure after checkpoint;
- directory `fsync` failure after checkpoint;
- shutdown while a transaction is active;
- shutdown while durability completion is quarantined;
- corrupt-store open refusal without destructive replacement.

For each case, assert receipt fields, final state, call order, call count, and whether reopening may observe the probe.
Assert no post-commit case invokes the mutation callback twice.

#### Process-termination matrix

Use a real child-process helper, not a panic caught in the same process.
Terminate the child at controlled boundaries:

- after `BEGIN`/write and before `COMMIT`;
- after confirmed `COMMIT` and before checkpoint;
- after checkpoint and before parent-directory sync;
- after directory sync and before acknowledgment reporting.

After each termination, reopen from a separate process and inspect the real store.
Assert that only records whose durable stage completed are eligible for acknowledgment.
The last case may reveal a persisted record without a delivered acknowledgment; recovery must deduplicate at a future domain boundary rather than replay it here.
Keep all subprocess controls test-only and unreachable from production configuration.

### Subtask T036 – Stabilize Diagnostics and Acceptance Coverage

- **Purpose**: make failures independently diagnosable without leaking engine internals or adding transport policy.
- **Primary files**: `diagnostics.zig`, `root.zig`, and package-owned test files.

Define stable categories for at least:

- path lease conflict;
- store not ready or closing;
- transaction begin failure;
- mutation failure;
- rollback failure;
- commit failure;
- checkpoint failure;
- directory open/sync failure;
- durability unconfirmed;
- quarantined store;
- corrupt-store refusal;
- unsupported platform/filesystem;
- shutdown durability unconfirmed.

Retain internal causes for structured service logging, but keep raw ShovelerDB diagnostics and canonical database paths out of caller-facing text.
Never include SQL literals, client-like data, secrets, or temporary absolute paths in stable messages.
Keep diagnostic mapping deterministic across equivalent failures.

`root.zig` must expose the intended persistence facade and keep implementation modules private where possible.
It must not re-export WP04 raw handles or migration internals.
Tests should import the facade for acceptance and individual modules only for focused white-box coverage.

Measure durability/store/directory-sync branch coverage with the repository's Zig coverage hook.
Reach at least 90% for the WP07 durability surface.
Cover every enumerated state transition, injected failure, shutdown branch, and diagnostic category even if aggregate coverage already exceeds 90%.
If the build hook is missing, route it to the service-build owner instead of editing WP04 files.

## Test Strategy and Exact Commands

Use Zig `0.16.0` on Linux x86_64.
From the repository root, first run:

```bash
test "$(cat .zig-version)" = "0.16.0"
git diff --check -- services/api/src/platform/persistence services/api/tests/persistence
```

From `services/api/`, run the focused steps established by the service build:

```bash
zig version
zig fmt --check src/platform/persistence/root.zig src/platform/persistence/store.zig src/platform/persistence/durability.zig src/platform/persistence/directory_sync.zig src/platform/persistence/diagnostics.zig tests/persistence/store_test.zig tests/persistence/store_crash_helper.zig tests/persistence/durability_test.zig tests/persistence/durability_integration_test.zig tests/persistence/directory_sync_test.zig
zig build test-persistence-unit
zig build test-persistence-integration
zig build test-persistence-crash
zig build coverage-persistence
zig build -Doptimize=ReleaseSafe test-persistence-integration
```

If the established build step names differ, use the documented WP04 extension names and record them.
Do not edit `services/api/build.zig` from WP07 merely to rename a step.
Run the real 20-cycle test on a local Linux filesystem that supports directory `fsync`.
Run fault tests with deterministic injected stage failures.
Run crash tests as actual subprocesses and remove every temporary database afterward.
Record durations, cycle count, crash points, coverage percentage, and final outcomes.

## Risks & Mitigations

- **Commit is mistaken for durability**: encode explicit receipt stages and make acknowledgment constructible only from all three confirmations.
- **Checkpoint succeeds but rename is not directory-durable**: open and `fsync` the parent directory before acknowledgment.
- **A post-commit retry duplicates business effects**: quarantine the store and retry only unfinished persistence stages.
- **Two handles race on one path**: canonical path lease plus one serialized operation gate.
- **Path aliases bypass the lease**: canonicalize and test relative, absolute, and symlink aliases.
- **Shutdown closes an uncheckpointed generation**: drain/rollback pre-commit work and finish durable completion before close.
- **Fault injection contaminates production**: pass explicit test doubles through narrow internal interfaces; expose no runtime crash flag.
- **Crash tests pass vacuously**: verify child exit boundary markers and inspect the real reopened database from another process.
- **Unsupported filesystem weakens guarantees**: fail readiness explicitly; P0 promises only verified Linux behavior.
- **Persistence facade absorbs domain policy**: keep callbacks generic and prohibit repositories, tables, HTTP mapping, and business retries.
- **Build ownership conflicts with WP04**: consume established hooks or route a handoff; never make an unowned edit.

## Definition of Done

- [ ] One process-local lease owns one handle for each canonical database path.
- [ ] All operations sharing a handle are serialized.
- [ ] Mutation callbacks run once inside explicit `BEGIN`/`COMMIT` control.
- [ ] Pre-commit failures roll back or quarantine on rollback failure.
- [ ] Confirmed commit is followed by real ShovelerDB checkpoint.
- [ ] Confirmed checkpoint is followed by real Linux parent-directory `fsync`.
- [ ] Only `DirectorySynchronized` can become acknowledged.
- [ ] Checkpoint and directory-sync failures return distinct `DurabilityUnconfirmed` receipts.
- [ ] Recovery retries only unfinished persistence stages and never replays mutation work.
- [ ] Shutdown blocks new work and does not report clean close before durable completion.
- [ ] Corrupt storage is refused without delete, replacement, or silent fallback.
- [ ] Twenty consecutive real checkpoint-sync-close-reopen cycles lose zero acknowledged records.
- [ ] Real subprocess termination is covered at every required persistence boundary.
- [ ] Fault injection covers rollback, commit, checkpoint, sync, shutdown, and quarantine branches.
- [ ] WP07 durability code reaches at least 90% coverage and every critical branch is exercised.
- [ ] Stable diagnostics distinguish every documented failure stage without leaking paths or engine prose.
- [ ] No domain repository, feature schema, application API, or HTTP policy was added.
- [ ] Only WP07-owned paths changed.
- [ ] The Activity Log records exact commands, platform, cycle count, crash evidence, and coverage.

## Review Guidance

Trace the state machine before reviewing code style.
Search for every path that can construct or return acknowledged success.
Reject any path that omits checkpoint or Linux parent-directory `fsync`.
Verify directory sync targets the database parent directory after ShovelerDB's checkpoint returns.
Inspect each post-commit error path and prove it cannot replay the callback.
Verify receipt fields distinguish rolled back, checkpoint-unconfirmed, and sync-unconfirmed outcomes.
Test a second lease against canonical aliases of the same path.
Review shutdown lock ordering and ensure no close occurs while durability is unresolved.
Run the 20-cycle test and independently inspect cycle/reopen assertions.
Confirm crash tests use child-process termination and real reopen, not only mocks.
Confirm production wiring uses real WP04 ShovelerDB and real Linux sync while fault seams remain test-only.
Check coverage evidence for all critical branches, not merely the aggregate percentage.
Reject domain tables, repository methods, HTTP mappings, or application retry policy in this WP.
Check the diff against every `owned_files` pattern before approval.

## Activity Log

> Append new entries at the bottom in chronological order using `YYYY-MM-DDTHH:MM:SSZ – agent_id – action`.

- 2026-07-20T07:12:34Z – system – Prompt created for WP07 durable serialized storage boundary.
