---
affected_files:
  - services/api/src/platform/persistence/diagnostics.zig
  - services/api/src/platform/persistence/directory_sync.zig
  - services/api/src/platform/persistence/durability.zig
  - services/api/src/platform/persistence/root.zig
  - services/api/src/platform/persistence/store.zig
  - services/api/tests/persistence/directory_sync_test.zig
  - services/api/tests/persistence/durability_coverage_test.zig
  - services/api/tests/persistence/durability_executor_test.zig
  - services/api/tests/persistence/durability_integration_test.zig
  - services/api/tests/persistence/durability_test.zig
  - services/api/tests/persistence/store_crash_helper.zig
  - services/api/tests/persistence/store_test.zig
blocking_findings: 0
cycle_number: 2
implementation_commit: 8f0bded353a94da9762f2ae8705e4e370ce13dae
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T06:46:07Z'
reviewed_lane_tip: 5c5ffeb110e97f322838d7ad06b7bd2b8a0f76e5
reviewer_agent: 'codex-wp06-fresh-review:reviewer-renata:reviewer'
verdict: approved
wp_id: WP06
---

# WP06 Review Cycle 2

Verdict: **APPROVE**

Product correction: `8f0bded353a94da9762f2ae8705e4e370ce13dae`.
Final test-only predecessor: `49234b5b7068aa1ac877e17be8f304d0495ed3d5`.
The reviewed lane tip adds only Spec Kitty coordination metadata after the product
commit; it does not change the reviewed persistence source or tests.

## Lifecycle, capability, and reclamation audit

- `Store`, `Executor`, and `StartupExecutor` are opaque `u128` nonce values, not
  addresses or field-visible pointer wrappers. Normal executor tokens cannot be
  cast into the startup-only runtime-script capability.
- Store and executor registries are allocator-owned linked registries with no
  256-live-capacity ceiling. Admissions increment under the registry lock and
  remain active for the entire implementation or adapter call; close first marks
  the slot closing, refuses later token use, drains admitted calls, removes the
  slot, and only then frees it.
- Store shutdown closes admission before waiting for active work. Concurrent
  shutdown callers enroll stack-owned waiters, consume one stable terminal
  outcome, and cannot return or tear down their allocator until the leader has
  removed and destroyed the allocator-owned slot and published reclamation.
  Repeated calls use bounded terminal tombstones; evicted or forged tokens remain
  closed and cannot reach registry state.
- The tests exercise more than 256 simultaneously live stores and executor
  scopes, non-head removal, repeated churn, stale/zero/forged tokens, an admitted
  executor call racing scope close, retained use before and after the receipt,
  active shutdown, concurrent terminal waiters, and allocator teardown after
  reclamation.

## Lease, durability, recovery, and public-boundary audit

- Canonical pathname locking is paired with an exclusive inode lease. Existing
  multi-link files fail closed, renamed live files retain inode exclusion, and
  the inode lease is refreshed after checkpoint before directory synchronization
  and receipt issuance.
- A receipt is reachable only through confirmed commit, real ShovelerDB
  checkpoint, inode-lease refresh, and Linux parent-directory `fsync`. Failures
  after commit preserve their typed causal diagnostic and enter uncertainty;
  later writes are refused without overwriting that cause.
- `completeDurability` retries only the eligible checkpoint, lease-refresh, or
  directory-sync stage. It cannot replay the application callback or startup
  script, and commit ambiguity is intentionally ineligible.
- Failed pre-checkpoint startup work closes/discards the dirty adapter and reopens
  the durable snapshot without checkpointing. Reopen/discard failures quarantine
  with distinct typed diagnostics. Shutdown closes without promoting uncertain
  or dirty work.
- Public signatures expose application-neutral result, row, diagnostic, receipt,
  and nonce-capability types only. `RowView` is opaque, ordinary executors have no
  runtime-script operation, startup scripts are exact runtime inputs, and stable
  parse/object/binding/NUL categories are mapped without leaking adapter results,
  SQL, raw pointers, or engine buffers.
- Corrupt existing storage is rejected with bytes, inode, size, timestamps, and
  permissions unchanged. Child-process tests use monotonic timeouts plus kill/reap
  cleanup. The real engine test performs 20 acknowledged durability/reopen cycles,
  and crash fixtures cover all four specified boundaries.

## Independent verification

- `zig fmt --check src/platform/persistence tests/persistence`: pass.
- `git diff --check` for all WP06-owned source and tests: pass.
- Debug `test-persistence`, `test-persistence-integration`, and
  `test-persistence-crash`: pass.
- ReleaseSafe `test-persistence`, `test-persistence-integration`,
  `test-persistence-crash`, and `coverage-persistence`: pass.
- Debug `test-shovelerdb-adapter` and `test-shovelerdb-integration`: pass against
  the pinned real ABI.
- Exact coverage: 562/624 owned production control-flow PCs (90.06%), 20/20
  critical branch tests, 41 tests passed, zero skipped. The runner resolves every
  sanitizer PC through DWARF and fails on any non-WP06 source; this successful run
  therefore contains zero adapter or other out-of-scope PCs.
- Fresh detached execution at test-only commit `49234b5` failed before product
  commit `8f0bded`, including missing value-token signatures, startup executor,
  executor-registration faults, completion API, shutdown barriers, and registry
  capability behavior. Commit chronology and the Activity Log corroborate the
  correction-cycle RED-before-product sequence.
- The lane was clean after removing `.spec-kitty/`, `.zig-cache/`, `zig-out`, and
  the temporary detached RED worktree.

## Contract round-trip

- `contracts/p0-contract-manifest.json` names
  `services/api/src/platform/persistence/**` as the owned implementation surface;
  WP06 product and test commits stay within the WP-owned persistence globs.
- `migration-manifest-v1.schema.json` pins later owner-scoped migration descriptor
  data, not this internal Zig facade. The remaining OpenAPI, event, module,
  lifecycle, and governed-document examples are orthogonal and pin no conflicting
  persistence payload, enum, CLI invocation, or error message.
- No WP06 product commit modifies frozen contracts, migration descriptors, build
  integration, dependency metadata, HTTP/domain/frontend code, or generated
  mission metadata. The merged WP04 commits are dependency history, not WP06 edits.

## Requirement and subtask verdicts

- T025 / FR-012 / C-005: **PASS** — canonical and inode leases, one serialized
  handle, cross-process/alias exclusion, dynamic registries, and safe shutdown.
- T026: **PASS** — begin/callback/rollback/commit sequencing, exactly-once
  callback execution, scoped capability lifetime, and receipt privacy.
- T027 / FR-013: **PASS** — checkpoint and real Linux parent-directory sync
  dominate acknowledgment, including inode replacement protection.
- T028 / FR-014: **PASS** — causal uncertainty, quarantine refusal, explicit
  persistence-only completion, and dirty startup discard/reopen.
- T029 / NFR-005 / NFR-009: **PASS** — real 20-cycle persistence, crash points,
  corrupt-file preservation, deterministic faults, and bounded child cleanup.
- T030 / NFR-006: **PASS** — adapter-opaque public seam, typed redacted
  diagnostics, 90.06% exact owned-PC coverage, and every required probe.
- C-003 / C-004: **PASS** — the authoritative boundary is Zig and consumes the
  approved pinned ShovelerDB adapter without substitute.

## Anti-pattern checklist

1. Dead code: **PASS** — each new internal module/function has a production call
   path; the public seam is the explicit producer for dependent WP07/WP08.
2. Synthetic-fixture test: **PASS** — FR cases invoke the real public persistence
   facade and, for integration/crash evidence, the pinned engine and child process.
3. Silent empty return: **PASS** — deliberate closed/idempotent observations are
   documented; operational failures remain typed and fail loud.
4. FR coverage: **PASS** — FR-012, FR-013, and FR-014 each have behavior assertions
   through the production seam.
5. Frozen surface: **PASS** — no WP06 product commit touches a frozen or forbidden
   surface.
6. Locked decision: **PASS** — no raw adapter escape, callback replay, checkpoint-on-
   close, migration absorption, alternate store, or multi-handle path exists.
7. Shared-file ownership: **PASS** — lane-f is exclusive; WP04 changes are approved
   dependency merges and are identified in the Activity Log.
8. Production fragility: **PASS** — no bare raise analogue or silent transient-race
   path was introduced; allocation, I/O, lease, and lifecycle failures are typed.

## Governance note

The WP frontmatter still named `implementer-ivan` when review was claimed. The
recorded profile was inspected as required, then `reviewer-renata` was loaded and
used for this independent quality gate. This metadata oversight did not alter the
review criteria or implementation and is non-blocking.
