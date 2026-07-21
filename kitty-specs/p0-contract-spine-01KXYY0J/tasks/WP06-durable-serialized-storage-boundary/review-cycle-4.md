---
affected_files:
  - services/api/src/platform/persistence/diagnostics.zig
  - services/api/src/platform/persistence/store.zig
  - services/api/tests/persistence/durability_coverage_test.zig
  - services/api/tests/persistence/store_test.zig
blocking_findings: 0
cycle_number: 4
implementation_commit: 2a68b9e52a746e99db5326312cf302ffde20bad6
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T08:52:50Z'
reviewed_lane_tip: e2b0c4b1e8717188c73fdc29440fc8d4a0f92b1e
reviewer_agent: 'codex:reviewer-renata:reviewer'
verdict: approved
wp_id: WP06
---

# WP06 Review Cycle 4

Verdict: **APPROVE**

Product correction: `2a68b9e52a746e99db5326312cf302ffde20bad6`.
Test-first commits: `4310d014d69cca2514904855eabe92b0a1fb1823`,
`61cbec1328d6704c7c47a09d12f41ab22079df54`,
`366bc1445c3a0ab8917ae56d743584dddb8490e8`, and
`7a56b2ce40ded2525ad99728eb6d0316af22c32a`.

Cycle 4 closes the single dependency-integration blocker in cycle 3 without
weakening the cycle-2 durability, capability, lease, recovery, or coverage
approval.

## Cycle-3 blocker closure

- `Store.initializeFresh(StartupWriteOperation)` is the only new public
  capability. It returns the existing application-neutral durable receipt or a
  typed `NotFresh` error; it does not expose a path, adapter, raw handle, origin
  flag, or freshness boolean.
- Open-origin capture occurs after the canonical `.lock` lease has been acquired
  and directly before `shovelerdb.Adapter.open`. Existing empty, nonempty, and
  reopened files therefore record a false private origin; only an absent
  canonical path in the lease-protected open sequence records true.
- `fresh_origin` and `durable_operation_completed` are private `StoreImpl`
  fields. `initializeFresh` checks both while holding the existing Store mutex
  and invokes the inherited startup-write choreography without releasing that
  mutex, so eligibility and callback execution are one atomic operation.
- Every durable receipt flows through `finishDirectorySync`, which permanently
  sets `durable_operation_completed` before returning. This covers ordinary
  mutation, ordinary startup write, successful fresh initialization, and
  checkpoint/directory-sync completion after uncertainty.
- Existing empty/nonempty/reopened stores return `NotFresh` without invoking the
  callback. A successful first call makes concurrent and later calls ineligible;
  the concurrent test proves the second caller waits behind the first rather
  than reading a race-prone flag.
- A failed pre-commit fresh callback reuses the approved dirty-handle
  discard/reopen recovery. The same still-live original Store remains eligible
  because no durable receipt exists. After shutdown and reopen, the now-existing
  file has a new false origin and retry is denied without callback execution.
- Post-commit checkpoint failure is quarantined; `completeDurability` performs
  persistence-only completion, never replays the callback, returns the durable
  receipt, and permanently closes fresh eligibility.
- `NotFresh` records a typed `.not_fresh` diagnostic in `.ready` state. It does
  not quarantine or close the Store. The next ordinary mutation/startup operation
  passes `requireReady`, resets the operation diagnostic, and proceeds normally.

## Independent behavioral evidence

- The permanent public-facade suite covers newly-created success, existing-empty
  denial, existing-nonempty/reopened denial, concurrent and second-call denial,
  failed-callback recovery and same-Store retry, completion without callback
  replay, shutdown cleanup, reopened denial, and closed/quarantined refusal.
- A reviewer-only temporary public-facade probe additionally proved that
  `NotFresh` leaves the Store usable and its diagnostic is cleared by the next
  successful ordinary mutation. The same probe proved that an ordinary mutation
  receipt and an ordinary startup-write receipt each permanently deny a later
  fresh callback on the same newly-created Store. The temporary worktree was
  removed and no probe code entered the product branch.
- Store admission spans the entire `initializeFresh` call, so the existing
  closing/admission protocol drains an active fresh callback before allocator,
  capability, adapter, inode lease, and path ownership are reclaimed. The new
  method adds no alternate shutdown or capability-cleanup path.

## RED chronology and ownership

- All four test commits precede product commit `2a68b9e`; they modify only
  WP06-owned persistence tests. The product commit modifies only
  `diagnostics.zig` and `store.zig`, both WP06-owned.
- A fresh detached execution at final test-only commit `7a56b2c` failed before
  product code with seven `Store has no member initializeFresh` errors in the
  permanent store root and one in the exact coverage root. Pre-existing roots
  remained green. The same suite passes at `2a68b9e`.
- `git diff --check` and `zig fmt --check` pass. No build, dependency, adapter,
  migration, HTTP, domain, frontend, contract, or generated mission file is
  changed by the fresh-initialization product/test commits.

## Regression and coverage verification

- Debug `test-persistence`, `test-persistence-integration`,
  `test-persistence-crash`, and `coverage-persistence`: pass.
- ReleaseSafe `test-persistence`, `test-persistence-integration`,
  `test-persistence-crash`, and `coverage-persistence`: pass.
- `test-shovelerdb-adapter` and `test-shovelerdb-integration`: pass against the
  pinned real ABI.
- Exact coverage is 577/641 owned production PCs (90.02%), with 20/20 required
  critical branches, 42 tests passed, and zero skipped. The exact-PC runner fails
  on any non-owned source, so the passing run contains zero adapter or other
  out-of-scope PCs.
- The prior 20-cycle real durability/reopen test, four crash boundaries,
  hard-link/rename/canonical lease tests, dynamic registry and stale-token tests,
  executor admission/expiry tests, concurrent shutdown/allocator reclamation,
  corrupt-file preservation, causal diagnostics, startup discard/reopen, and
  no-callback-replay cases remain green in Debug and ReleaseSafe.

## Contract and anti-pattern checklist

- Contract round-trip: **PASS** — the change remains inside the manifest-owned
  persistence surface and introduces no migration descriptor, wire payload,
  error-text, enum-value, or CLI contradiction. Migration schemas remain
  downstream and orthogonal.
- Dead code: **PASS** — the public seam is required by dependent WP07 and all new
  private state/functions have production callers.
- Synthetic fixture: **PASS** — tests execute the real public Store path and the
  existing pinned adapter choreography rather than constructing expected shapes.
- Silent empty return: **PASS** — freshness denial is explicit and typed; origin
  inspection fails closed to not-fresh rather than granting initialization.
- FR coverage: **PASS** — FR-012 through FR-014 and the cycle-3 integration
  correction have direct behavioral assertions.
- Frozen surface: **PASS** — no frozen or forbidden file is modified.
- Locked decision: **PASS** — no raw adapter/path/origin flag escapes, no callback
  replay is introduced, and one leased serialized handle remains authoritative.
- Shared-file ownership: **PASS** — lane-f is exclusive and all substantive files
  are WP06-owned.
- Production fragility: **PASS** — the new branch returns a typed application-
  neutral refusal while retaining the established lifecycle and diagnostics.

Reviewer Renata was explicitly loaded for this governed review. The review
worktree and all temporary `.spec-kitty`, Zig cache, output, and detached probe
artifacts were removed before verdict persistence.
