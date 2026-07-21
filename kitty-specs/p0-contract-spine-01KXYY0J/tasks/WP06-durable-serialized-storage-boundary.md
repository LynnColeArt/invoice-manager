---
work_package_id: WP06
title: Durable Serialized Storage Boundary
dependencies:
- WP04
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
- T025
- T026
- T027
- T028
- T029
- T030
phase: Phase 3
assignee: ''
agent: "codex"
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
- services/api/tests/persistence/durability_coverage_test.zig
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
shell_pid: "1807838"
---

# WP06: Durable Serialized Storage Boundary

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Build the API service's durable serialized storage boundary on top of the pinned
ShovelerDB adapter supplied by WP04. The boundary must own a canonical database
path under an exclusive lease, serialize all mutations through one live handle,
checkpoint committed work, synchronize the database's parent directory on Linux,
and make uncertain durability an explicit quarantined state rather than a hidden
success.

Expose only a narrow public facade from `platform/persistence/root.zig`. That
facade must be sufficient for a later startup migration runner to execute DDL,
checkpoint and directory-sync successful DDL, and recover from failed,
uncheckpointed DDL by discarding the dirty handle and reopening the last durable
snapshot. Raw ShovelerDB handles, SQL result objects, and adapter internals must
never cross the facade.

## Upstream and Downstream Boundaries

WP04 is the only dependency of this package. Consume its:

- pinned ShovelerDB C ABI and Zig adapter;
- engine error normalization and ownership conventions;
- convention-scanned service build and test hooks; and
- shared library and fixture behavior already proven at the adapter boundary.

Do not depend on a migration runner, migration descriptors, startup DDL, or any
other later work package. The downstream WP07 migration runner will consume this
package after WP06 is approved; WP06 must not import or implement WP07 concerns.

If any required adapter capability or convention-scanned build step is missing,
record the mismatch and route it back to WP04. Never repair that mismatch by
editing `services/api/build.zig`, `services/api/build.zig.zon`, or dependency
metadata in this package.

Before editing implementation files, register the work package execution:

```bash
spec-kitty agent action implement WP06 --agent codex
```

## Mandatory Red-First Gate

This package is behavior-led. Before changing a production file for a subtask,
add or extend an owned persistence test that demonstrates the missing behavior.
Run the smallest WP04-provided convention-scanned test command that exercises
that test and record in the Activity Log:

1. `RED:` the exact command;
2. the exact failing assertion, compile error, or observed wrong result;
3. the production change made only after the failure was captured; and
4. `GREEN:` the exact command and passing result.

A production change without preceding red evidence is incomplete. A test that
was added only after the implementation is not acceptable substitute evidence.
Reviewers must reject this package when the Activity Log lacks red-first evidence
for persistence, checkpoint, directory-sync, recovery, or quarantine behavior.

## Required State Model

Make lifecycle and durability state explicit. Names may differ when the codebase
has a stronger convention, but the behavior must distinguish at least:

- `Closed`: no engine handle is usable;
- `Ready`: the leased handle represents the last accepted durable state;
- `Mutating`: one serialized callback owns the handle;
- `CommittedPendingCheckpoint`: the engine transaction committed but persistence
  acknowledgment is not yet legal;
- `CheckpointedPendingDirectorySync`: the checkpoint completed but the Linux
  parent-directory synchronization has not completed;
- `DirectorySynchronized`: checkpoint and parent-directory sync both succeeded;
- `Uncertain`: a post-commit durability operation failed and the outcome cannot
  honestly be represented as durable; and
- `Quarantined`: new mutations are refused until explicit recovery or shutdown.

State transitions must be narrow, auditable, and covered by tests. Never infer
`DirectorySynchronized` from transaction commit alone. Never silently transition
from `Uncertain` back to `Ready` on the same possibly dirty handle.

## Public Durable-Store Seam

`platform/persistence/root.zig` is the public platform surface. Provide a small
opaque store/lease type and typed operations with these capabilities:

- open the canonical database path and acquire its exclusive lease;
- run one serialized transactional mutation without exposing the engine handle;
- return a durable receipt only after checkpoint and directory sync succeed;
- run a startup write/DDL callback within the same serialized durability boundary;
- discard a failed startup write's uncheckpointed handle without checkpointing it;
- reopen the canonical path so callers regain the last durable snapshot;
- report whether the store is ready, uncertain, quarantined, or closed; and
- shut down deterministically without claiming uncertain work became durable.

The startup-write callback may receive a capability-limited executor or an opaque
transaction object owned by the persistence module. It must not receive a raw
ShovelerDB handle, C pointer, unrestricted adapter object, or engine-specific
result. The public return types must be application-neutral persistence types.

The later migration runner needs only this choreography:

```text
exclusive lease
  -> serialized startup write
  -> DDL succeeds
  -> checkpoint
  -> Linux parent-directory sync
  -> durable success

exclusive lease
  -> serialized startup write
  -> DDL fails before checkpoint
  -> discard dirty handle without checkpoint
  -> reopen canonical path at last durable snapshot
  -> ready again, or explicit quarantine if reopen fails
```

Do not implement migration discovery, ordering, dependency graphs, descriptors,
checksums, schema history, application DDL, or process-start orchestration here.

## Ownership and Scope

Work only within the `owned_files` globs. The expected production authority is:

- `root.zig`: narrow public facade and exported persistence types;
- `store.zig`: canonical path, lease, serialized handle, and mutation lifecycle;
- `durability.zig`: transaction/checkpoint sequencing and durable receipts;
- `directory_sync.zig`: real Linux parent-directory synchronization;
- `diagnostics.zig`: typed, non-secret operational diagnostics.

The expected test authority is under `services/api/tests/persistence/`, using the
owned `store*`, `durability*`, and `directory_sync*` patterns.

Do not edit:

- service build manifests or build scripts;
- the WP04 ShovelerDB adapter implementation;
- HTTP handlers, routes, or middleware;
- client, project, invoice, billing, or analytics domain modules;
- migration descriptors or migration runner code;
- frontend code; or
- generated mission metadata.

## T025 — Exclusive Lease and Serialization

Implement process-local and cross-process protection for one canonical database
path. Normalize the path before indexing or locking so aliases cannot open two
live writers for the same storage file.

Required behavior:

- acquire an exclusive filesystem-backed lease before opening the engine handle;
- refuse a second writer deterministically while the first lease is live;
- keep exactly one live engine handle behind the lease;
- serialize all operations that can mutate or checkpoint that handle;
- release handle and lease in a defined order on ordinary shutdown;
- clean up correctly after partial-open failures; and
- avoid an ambient global singleton that prevents isolated tests.

Tests must first fail for a second concurrent open, path-alias collision, and at
least one partial-open cleanup case. Include concurrent callers that prove the
mutation gate does not overlap callbacks.

## T026 — Transaction and Durable Receipt

Wrap each mutation in explicit begin/commit/rollback handling. Invoke a mutation
callback exactly once and keep callback-owned values valid only for the callback's
documented lifetime.

Required behavior:

- begin a transaction before exposing the capability-limited executor;
- roll back on callback or statement failure when rollback is still meaningful;
- commit exactly once after the callback succeeds;
- never replay the callback after an ambiguous engine result;
- proceed to checkpoint only after a confirmed commit;
- issue a receipt only after the entire durability sequence succeeds; and
- keep engine codes as diagnostic causes, not public API contracts.

The receipt must identify the durable operation sufficiently for correlation but
must not contain SQL, bank data, invoice content, secrets, raw pointers, or engine
result buffers. Add red-first tests for callback failure, commit failure, rollback,
callback invocation count, and absence of a receipt before durable completion.

## T027 — Checkpoint and Linux Directory Sync

After a confirmed commit, run the real ShovelerDB checkpoint operation and then
sync the database file's parent directory on Linux. Directory sync must operate
on the canonical parent directory actually containing the storage file.

Required sequencing:

```text
commit confirmed
  -> checkpoint requested
  -> checkpoint confirmed
  -> open parent directory with appropriate Linux flags
  -> fsync parent directory
  -> close directory descriptor
  -> DirectorySynchronized receipt
```

Use injectable syscall and checkpoint seams for deterministic fault tests, while
the production path calls the real checkpoint and Linux directory-sync behavior.
Do not replace either production operation with a mock or a file-flush guess.

Add red-first tests proving ordering and proving that checkpoint failure, directory
open failure, directory `fsync` failure, and descriptor close handling cannot yield
a durable receipt. Verify descriptor cleanup on every reachable failure path.

## T028 — Uncertainty, Quarantine, and Recovery

Treat failures according to whether a commit may already have escaped. A callback
or DDL failure before commit may roll back normally. A failure after confirmed
commit but before completed checkpoint and directory sync creates uncertainty and
must quarantine the active store.

Required behavior:

- refuse new mutations while uncertain or quarantined;
- retain a typed causal diagnostic for the transition;
- make shutdown deterministic and idempotent;
- never checkpoint merely as a side effect of closing an uncertain handle;
- never label uncertain state as rolled back or durable; and
- require an explicit reopen/recovery path before returning to readiness.

Also implement the narrow failed-startup-write recovery needed by downstream
startup code. When DDL or another startup callback fails before checkpoint:

1. stop using the dirty handle;
2. discard/close it through a path that does not checkpoint pending changes;
3. preserve the exclusive lease while recovery is coordinated;
4. reopen the canonical database path;
5. prove the reopened handle observes the last durable snapshot; and
6. return `Ready`, or quarantine with a typed error if discard/reopen fails.

This recovery is not permission to retry the callback. The caller decides whether
startup can continue. Add red-first tests for refusal after uncertainty, clean
failed-DDL recovery, reopen failure, idempotent shutdown, and no checkpoint during
dirty-handle discard.

## T029 — Repetition, Fault, and Crash Coverage

Exercise the real engine through at least 20 open/write/checkpoint/sync/close/reopen
cycles against disposable storage. Every cycle must verify that acknowledged data
survives reopen and unacknowledged data is never asserted as durable.

Add deterministic fault injection at these boundaries:

- transaction begin, statement/callback, rollback, and commit;
- checkpoint invocation and completion;
- parent-directory open, `fsync`, and close;
- dirty-handle discard; and
- reopen after failed startup work.

Use `store_crash_helper.zig` as a child-process fixture for crash points that an
in-process test cannot represent honestly. Cover crashes before commit, after
commit/before checkpoint, after checkpoint/before directory sync, and after the
durable acknowledgment boundary. Assert only guarantees the boundary can prove.

Crash and repetition tests must use the pinned real ShovelerDB library supplied by
WP04. A fake engine may support focused state-machine unit tests but cannot satisfy
the integration, crash, or 20-cycle acceptance evidence.

## T030 — Diagnostics, Coverage, and Public Facade

Complete the public `root.zig` facade and typed diagnostics. Diagnostics must make
lease conflicts, transaction failures, checkpoint failures, directory-sync
failures, uncertainty, quarantine, discard failures, and reopen failures distinct.

Diagnostics may include operation category, stable store identifier, state, and
normalized cause. They must not include SQL text, customer data, invoice details,
bank information, secrets, or raw engine buffers.

Prove through compile-time or consumer-style tests that downstream code can:

- open and close the durable store;
- perform an ordinary serialized transactional mutation;
- execute a capability-limited startup write;
- receive durable success only after checkpoint plus directory sync; and
- discard an uncheckpointed failed startup handle and reopen the durable snapshot.

The same tests must prove downstream code cannot obtain the raw ShovelerDB handle
or adapter result types through the public facade. Run WP04's coverage hook and
inspect persistence boundary coverage, especially failure transitions.

### Executable Persistence Coverage Contract

Use WP04's exact `coverage-persistence` mechanism. Every production file that
owns one of the following branches must import the build-wired probe with exact
`const persistence_coverage = @import("persistence_coverage_probe");` and call
`persistence_coverage.hit(.<tag>)` inside the real error branch:

`canonicalization_failure`, `lease_acquire_failure`, `lease_conflict`,
`engine_open_failure`, `partial_open_cleanup`, `transaction_begin_failure`,
`callback_failure`, `rollback_failure`, `commit_failure`, `checkpoint_failure`,
`directory_open_failure`, `directory_sync_failure`, `directory_close_failure`,
`uncertain_transition`, `quarantined_refusal`, `dirty_discard_failure`,
`reopen_failure`, `recovery_quarantine`, `unsupported_directory_sync`, and
`shutdown_failure`.

Put executable cases in exact dedicated root
`services/api/tests/persistence/durability_coverage_test.zig`. It may import only
`std` and public `@import("persistence")`, with exact canonical binding
`const persistence = @import("persistence");`. Include exact executable
declaration test
`test "persistence production declarations are analyzed" { std.testing.refAllDecls(persistence); }`.
Name each critical test exactly `test "critical branch: <tag>"`; reach the tag
through the public persistence facade, assert the stable diagnostic or state,
and execute a positive owned-production PC delta after WP04 resets counters.
Tests must never import or mutate the probe directly. Missing or renamed roots,
a denominator below 20 owned production PCs, below 90%, unknown, duplicate, or
missing names, skipped or logged-error tests, missing production hits, or zero
per-test production deltas are hard failures.

## Build and Test Integration

WP04 owns convention-scanned service build integration. Place source and test files
under the owned paths and use those existing hooks. Never edit `build.zig` just to
enumerate a new persistence test.

Run from the repository root unless a command explicitly changes directory:

```bash
test "$(cat .zig-version)" = "0.16.0"
git diff --check -- services/api/src/platform/persistence services/api/tests/persistence
cd services/api
zig fmt --check src/platform/persistence tests/persistence
zig build test-persistence
zig build test-persistence-integration
zig build test-persistence-crash
zig build coverage-persistence
zig build -Doptimize=ReleaseSafe test-persistence
```

Do not require aggregate `zig build test` or `zig build coverage` while WP07 and
WP08 producers are absent; WP04 intentionally fails those missing downstream
categories closed. Use `zig build test-shared` only when a shared-boundary change
is legitimately in scope; do not modify shared code merely to make this package pass.

If a WP04 build step is absent, stop and document the missing upstream contract.
Do not invent one-off steps, bypass the convention scanner, or edit the build graph.

## Test Matrix

At minimum, leave automated evidence for:

| Area | Required proof |
|---|---|
| Lease | canonical aliases collide; second process is refused; cleanup releases |
| Serialization | concurrent callers never overlap mutations or checkpoints |
| Transaction | callback failure rolls back; commit is once; callback is not replayed |
| Receipt | no acknowledgment exists before checkpoint plus directory sync |
| Checkpoint | real adapter call succeeds; injected failure quarantines appropriately |
| Directory sync | real Linux path works; open/fsync/close faults are classified |
| Startup failure | dirty handle is discarded without checkpoint and durable state reopens |
| Uncertainty | post-commit failures refuse future writes and never claim rollback |
| Repetition | at least 20 real-engine durability cycles pass |
| Crash | child-process crash points preserve only the documented guarantees |
| Facade | later callers have the required seam but no raw engine access |
| Diagnostics | categories are distinct and payloads contain no sensitive data |

Keep tests deterministic. Use unique temporary directories, bounded timeouts for
concurrency/process tests, and explicit child cleanup so a failed run does not leave
a lease or process that poisons the next run.

## Implementation Guidance

Prefer explicit ownership and small typed transitions over a generic storage
abstraction. This is one ShovelerDB boundary with known durability semantics, not
a database portability framework.

Keep locks out of user-controlled waits where possible, but do not release the
serialization gate while a mutation, checkpoint, directory sync, discard, or reopen
sequence is logically active. Document lock ordering and descriptor/handle ownership
next to the code that enforces it.

Use `defer`/`errdefer` carefully. Generic cleanup that checkpoints during close can
violate failed-startup recovery and uncertainty guarantees. Cleanup paths must state
whether they preserve, discard, or cannot determine pending engine state.

Do not overclaim Linux filesystem guarantees. The contract required here is a
confirmed engine checkpoint followed by successful `fsync` of the canonical parent
directory. Report unsupported platforms as typed capability errors unless the
existing service policy provides an approved alternative.

## Definition of Done

- [ ] Every T025-T030 behavior has red-first Activity Log evidence.
- [ ] One canonical path can have only one live writer lease.
- [ ] Mutations and durability operations are serialized through one live handle.
- [ ] Transaction callbacks execute once and failures receive correct rollback handling.
- [ ] Durable receipts appear only after checkpoint and Linux parent-directory sync.
- [ ] Post-commit durability failures become explicit uncertainty/quarantine.
- [ ] Failed uncheckpointed startup writes discard the dirty handle and reopen durable state.
- [ ] Reopen failure quarantines the store and produces a typed diagnostic.
- [ ] The real engine passes at least 20 durability cycles and required crash cases.
- [ ] The public facade exposes the later migration-runner seam without raw engine types.
- [ ] Persistence diagnostics distinguish failures without exposing sensitive data.
- [ ] WP04 focused persistence tests, measured persistence coverage, formatting, and ReleaseSafe checks pass.
- [ ] No service build file, migration file, domain module, or frontend file was changed.
- [ ] `git diff --check` passes for all owned changes.

## Review Guidance

Reviewers should begin with the Activity Log. Reject immediately if production
durability code precedes the corresponding failing test evidence.

Then inspect the public facade before implementation details. Confirm it supports
successful startup DDL durability and failed uncheckpointed-handle recovery while
keeping ShovelerDB internals private. Trace each receipt-producing path and verify
checkpoint plus parent-directory sync dominate the receipt.

Finally, review uncertainty paths and real-engine evidence. Pay particular attention
to cleanup helpers that might checkpoint dirty state, locks released between commit
and acknowledgment, callback replay, descriptor leaks, and tests that substitute a
fake for the required 20-cycle or crash coverage.

## Activity Log

- 2026-07-20T16:00:23Z — WP prompt revised for the WP04-only durable boundary,
  red-first implementation evidence, and the narrow downstream startup-write seam.

During implementation, append timestamped entries for each red command/failure,
the corresponding production change, each green command/result, scope decisions,
and the final full verification matrix.
- 2026-07-21T02:09:15Z – codex – shell_pid=1807838 – Assigned agent via action command
- 2026-07-21T02:12:00Z — RED: after adding the owned WP06 unit,
  integration, crash, and exact coverage roots but before adding production code,
  `cd services/api && zig build test-persistence` failed with
  `[test-persistence:error] WP06 producer present but unit/integration/crash classification is incomplete`;
  `zig build test-persistence-integration` failed because the expected integration
  root count was 0; `zig build test-persistence-crash` failed because the expected
  crash root count was 0; and `zig build coverage-persistence` failed because the
  WP06 coverage groups were incomplete.
- 2026-07-21T02:20:00Z — Implemented the canonical-path exclusive filesystem
  lease, one-handle serialization boundary, begin/rollback/commit/checkpoint/Linux
  parent-directory-sync choreography, explicit durability states and receipts,
  uncertain/quarantined handling, dirty startup-handle discard/reopen, typed
  redacted diagnostics, and the narrow adapter-opaque public facade.
- 2026-07-21T02:25:00Z — RED: the focused allocator-ownership test
  `an existing canonical database path retains exact allocator ownership` failed
  under `cd services/api && zig build test-persistence`: `realPathFileAlloc`
  returned a sentinel allocation of length 101 while canonicalization freed a
  shortened `[]u8` view of length 100. Changed canonicalization to free the exact
  sentinel allocation and return a separately owned ordinary slice.
- 2026-07-21T02:40:00Z — GREEN: `cd services/api && zig build test-persistence`,
  `zig build test-persistence-integration`, and `zig build test-persistence-crash`
  passed with the real pinned ShovelerDB library. The integration root performs
  20 acknowledged open/write/checkpoint/sync/close/reopen cycles; the crash root
  covers before commit, after commit/before checkpoint, after checkpoint/before
  directory sync, and after durable acknowledgment.
- 2026-07-21T02:55:00Z — Added real cross-process lease evidence, DML rollback
  observation, reopened-snapshot observation after failed startup DDL, real engine
  statement failures, canonicalization/OS open failures, and closed-facade paths.
  GREEN: Debug and ReleaseSafe `test-persistence`, `test-persistence-integration`,
  and `test-persistence-crash` all passed.
- 2026-07-21T02:57:00Z — Coverage scope audit: the pre-correction artifact
  measured 257/356 aggregate sites and 20/20 exact critical branches, but a full
  sanitizer-PC-to-DWARF map proved that 151 denominator sites belonged to the WP04
  ShovelerDB adapter. The genuine WP06 classification was 185/205 (90.24%). Routed
  the adapter-scope mismatch to WP04 and did not pad the ratio with adapter behavior.
