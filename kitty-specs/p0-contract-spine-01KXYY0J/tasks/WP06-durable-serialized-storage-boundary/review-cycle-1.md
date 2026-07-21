---
affected_files:
  - services/api/src/platform/persistence/store.zig
  - services/api/src/platform/persistence/durability.zig
  - services/api/src/platform/persistence/root.zig
  - services/api/tests/persistence/store_test.zig
  - services/api/tests/persistence/durability_test.zig
  - services/api/tests/persistence/store_crash_helper.zig
  - kitty-specs/p0-contract-spine-01KXYY0J/tasks/WP06-durable-serialized-storage-boundary.md
cycle_number: 1
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command: cd services/api && zig build test-persistence
reviewed_at: '2026-07-21T03:21:41Z'
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: rejected
wp_id: WP06
---

# WP06 Review Cycle 1 — REJECTED

Reviewed implementation commit: `3af20f3` (`feat(WP06): add durable serialized store boundary`), verification-evidence commit `bb299c2`, and the WP04 coverage-isolation dependency at `e725562`.

## Blocking findings

### B1 — hard-link aliases bypass the exclusive canonical lease

`canonicalize` resolves lexical and symbolic-link aliases, but an existing hard link remains a distinct canonical pathname (`services/api/src/platform/persistence/store.zig:359-397`). `openWithFaults` then derives the exclusive lease path from that pathname (`store.zig:302-326`). Two names for the same inode therefore receive different `.lock` files and two live ShovelerDB handles.

A fresh reviewer test created a database, shut it down, hard-linked the database file to a second path, opened the original, and then required the alias open to return `LeaseConflict`. Debug `zig build test-persistence` failed:

```text
expected error.LeaseConflict, found .{ ._implementation = anyopaque@..., ._terminal_state = .ready, ... }
store_reviewer_alias_test.zig:23
```

This violates T025's path-alias collision rule, FR-012, and C-005's one serialized handle per database path.

Required remediation:

1. Reject or identity-normalize existing multi-link database files before opening the adapter, so two names for one inode cannot acquire independent writer leases. Do not weaken this to process-local bookkeeping; the guard must remain cross-process.
2. Add a permanent red-first hard-link regression through public `persistence.Store.open`, alongside the existing lexical-alias, symbolic-path/canonical-parent, and cross-process cases.
3. Prove the lease/handle cleanup path remains exact when the alias rejection occurs.

### B2 — concurrent shutdown can race a caller into freed `StoreImpl` memory

Public operations first load `_implementation` without an admission/lifetime guard (`store.zig:21-38`). `StoreImpl.mutate` acquires only the implementation mutex (`store.zig:81-86`). `Store.shutdown` independently loads the same pointer, calls an implementation-local shutdown, then destroys the allocation and nulls the public pointer after the implementation mutex has been released (`store.zig:41-49`, `116-129`).

A valid interleaving is:

1. a mutation caller reads the non-null implementation pointer;
2. shutdown acquires the implementation mutex, closes the handle/lease, releases the mutex, and destroys `StoreImpl`;
3. the mutation caller resumes and locks or dereferences the freed implementation.

The same unsynchronized pointer/state access affects `state` and `lastDiagnostic`. Shutdown also has no closing/admission state that prevents new callers from racing while an active mutation finishes. No committed test exercises the plan's explicit `shutdown during an active operation` requirement.

Required remediation:

1. Add a lifetime-safe admission/closing protocol that marks shutdown before waiting, rejects later entrants, keeps the implementation allocation alive until every admitted caller exits, and synchronizes state/diagnostic reads.
2. Add deterministic red-first concurrent tests for shutdown while a callback is blocked, a second mutation arriving after shutdown begins, state/diagnostic observation during mutation, and idempotent repeated shutdown. The tests must use bounded waits and prove no callback, checkpoint, or directory sync starts after closing admission.
3. Preserve the required handle-before-lease release order and never checkpoint uncertain/dirty state as cleanup.

### B3 — quarantine refusal overwrites the required causal diagnostic

`transitionUncertain` records the actual post-commit cause, but `requireReady` changes the state to `quarantined` and replaces that diagnostic with generic `.quarantine` on the next refused operation (`store.zig:233-260`). T028 requires the typed causal diagnostic to be retained.

A fresh public-facade reviewer test injected checkpoint failure, observed `.checkpoint_failure`, cleared the fault, attempted a second mutation, and then required the causal category to remain `.checkpoint_failure`. Debug `zig build test-persistence` failed:

```text
expected .checkpoint_failure, found .quarantine
durability_reviewer_diagnostic_test.zig:30
```

Required remediation:

1. Keep the originating commit/checkpoint/directory-sync/rollback/discard/reopen diagnostic available across every quarantined refusal and shutdown. A refusal may update state, but it must not erase the cause operators need for recovery.
2. Add permanent table-driven regressions for each uncertainty/quarantine origin and repeated refused operations.
3. Keep diagnostics redacted: no SQL, paths, client/invoice/bank data, secrets, raw pointers, or engine buffers.

### B4 — the mandatory behavior-level red-first gate is not evidenced

The Activity Log records one pre-production failure: the WP04 discovery hook reported incomplete unit/integration/crash classification and zero integration/crash roots. That failure did not compile or execute the lease, transaction, checkpoint, directory-sync, recovery, or quarantine behavior tests. The next entry records the entire production boundary as implemented. Apart from the later allocator regression, there is no exact failing assertion, missing-production compile error, or observed wrong result for the behaviors the Review Guidance explicitly requires reviewers to gate.

The generic classification failure is red evidence for test-root wiring, not evidence that the persistence behaviors were absent. WP06's Mandatory Red-First Gate says a production change without corresponding behavior-level red evidence is incomplete and directs reviewers to reject when persistence/checkpoint/directory-sync/recovery/quarantine evidence is missing.

Required remediation:

1. For the corrective work in this cycle, record each permanent B1-B3/B5/B6 regression failing against `3af20f3` before changing production code, then record the exact focused green command and result.
2. Expand the Activity Log into a T025-T030 behavior map. Each row must identify the test root, exact red command/result, production correction, and exact green command/result; a discovery-classification error cannot stand in for a behavior result.
3. Keep the implementation and permanent tests in reviewable commits whose chronology corroborates the correction-cycle red-first evidence.

### B5 — the nominally opaque facade exposes its implementation pointers, and its negative test checks the wrong construct

`persistence.Store` publicly exposes `_implementation: ?*anyopaque` (`store.zig:8-11`) and `persistence.Executor` publicly exposes `_context: *anyopaque`, which is the ShovelerDB adapter address (`durability.zig:21-30`, `100-102`). Zig struct fields remain accessible to downstream importers despite the leading underscore.

A temporary consumer root importing only `@import("persistence")` compiled and passed while it read both fields and forged `persistence.Store{ ._implementation = null }`. The committed opacity check uses `@hasDecl(..., "adapter")`; fields are not declarations, so it would also pass if a raw adapter field were added. This does not prove the T030 requirement that adapter internals cannot cross the facade.

Required remediation:

1. Replace the field-visible wrappers with an actually opaque public representation/capability boundary. Downstream callbacks must be able to invoke only the reviewed executor operations and must not extract or forge implementation storage.
2. Add consumer-style structural/negative compilation evidence that checks fields and the reachable public type graph, not only declaration names, while importing only the public persistence module.
3. Keep ShovelerDB adapter/result/C-handle types absent from every public signature and returned value.

### B6 — required failure-safety and bounded-process acceptance cases are missing

The committed suite has no durable-boundary test for corrupt existing storage remaining byte-for-byte untouched after open refusal, despite NFR-009 and the spec's independent storage test. It also has no active-shutdown case from the plan. Both child-process fixtures wait without a timeout or kill/reap fallback (`store_test.zig:75-82`, `store_crash_helper.zig:46-59`), contrary to WP06's deterministic-test rule requiring bounded timeouts and explicit cleanup.

Required remediation:

1. Add a real public-boundary corrupt-file test that snapshots the original bytes/metadata, requires typed open failure, and proves no replacement/truncation/fallback occurred.
2. Cover active shutdown through the B2 admission protocol.
3. Give lease/crash child processes bounded monotonic deadlines plus deterministic kill and reap cleanup on timeout/error so a failure cannot leave a process or lease behind.

## Fresh passing evidence before rejection

- `.zig-version` and `zig version`: exact `0.16.0`.
- `git diff --check -- services/api/src/platform/persistence services/api/tests/persistence`: passed.
- `zig fmt --check src/platform/persistence tests/persistence`: passed.
- Debug `zig build test-persistence`, `test-persistence-integration`, and `test-persistence-crash`: passed before adversarial fixtures.
- ReleaseSafe `test-persistence`, `test-persistence-integration`, and `test-persistence-crash`: passed.
- `zig build coverage-persistence`: 185/205 owned production PCs (90.24%), 20/20 critical branches, 26 coverage tests, zero skipped.
- Independent extraction of the final sanitizer PC table produced exactly 205 records: 140 `store.zig`, 38 `durability.zig`, 17 `directory_sync.zig`, 9 `root.zig`, and 1 `diagnostics.zig`; zero adapter, test, dependency, or other out-of-scope PCs.
- The real integration root completed 20 acknowledged open/write/checkpoint/directory-sync/close/reopen cycles. The crash root covered all four documented boundaries and asserted only the guaranteed result.
- Allocator ownership tests and the full Debug suite reported no leaks on the committed implementation.
- The WP06 implementation commit changed only its owned persistence source/tests plus its own WP activity artifact. No build, dependency, migration, HTTP, domain, or frontend file changed.

The separate WP04 coverage-runner diagnostic-format finding is upstream dependency feedback and is not a reason for this WP06 rejection.

## Contract round-trip

- `contracts/p0-contract-manifest.json` includes the exact owned path `services/api/src/platform/persistence/**`; the WP06 commit stays within it.
- The remaining mission contract schemas and OpenAPI examples are orthogonal to WP06's internal Zig persistence facade and pin no conflicting storage payload, enum, CLI, or error text.

## Requirement and subtask verdicts

- T025 / C-005 / FR-012: **REJECTED** — hard-link aliases allow two live writers; shutdown lifetime is unsafe.
- T026: transaction/callback/rollback/commit ordering passes current focused tests, but the red-first evidence is incomplete.
- T027 / FR-013: commit -> checkpoint -> Linux parent-directory sync -> receipt ordering and injected fault classification pass current tests.
- T028 / FR-014: **REJECTED** — causal diagnostics are overwritten and concurrent shutdown/recovery admission is unsafe.
- T029 / NFR-005 / NFR-009: **REJECTED** — 20 real cycles and crash boundaries pass, but corrupt-file acceptance and bounded child cleanup are absent.
- T030 / NFR-006: **REJECTED** — measured coverage is genuinely 185/205 with all probes, but the public facade is field-visible and the opacity assertion is non-probative.

## Anti-pattern checklist

1. Dead code: **N/A** — the currently unconsumed public seam is an explicit producer for dependent WP07/WP08, which cannot consume it until WP06 is approved.
2. Synthetic-fixture test: **FAIL** — the adapter-opacity assertion checks declarations rather than fields and does not detect the actual exposed implementation pointers.
3. Silent empty return: **PASS** — idempotent closed-store returns and test-only zero/empty observations are deliberate; no production error is silently converted to an empty success.
4. FR coverage: **FAIL** — FR-012 path identity, FR-014 causal retention, concurrent shutdown, and NFR-009 corrupt refusal lack correct acceptance coverage.
5. Frozen surface: **PASS** — the WP06 implementation commit does not modify frozen contracts, build integration, dependency metadata, or migration files.
6. Locked decision: **FAIL** — hard-link aliases contradict the one-handle locked decision, and field-visible adapter context contradicts the public-seam boundary.
7. Shared-file ownership: **PASS** — WP06 product paths are disjoint and lane-f is exclusive; the WP04 correction is a dependency commit, not a WP06-owned edit.
8. Production fragility: **FAIL** — concurrent shutdown can invalidate a pointer already admitted by a public operation.

Downstream WP07, WP08, WP11, and WP12 depend on WP06 and must not consume this cycle as approved work. Rebase those lanes after a corrected WP06 cycle is approved.
