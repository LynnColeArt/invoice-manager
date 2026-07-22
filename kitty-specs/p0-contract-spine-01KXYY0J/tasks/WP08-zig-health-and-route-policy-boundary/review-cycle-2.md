---
affected_files:
  - services/api/tests/http/startup_readiness_test.zig
blocking_findings: 0
correction_commits:
  - a43e658e79ea345d23593d45f255f4e56e4cb128
cycle_number: 2
implementation_commit: a43e658e79ea345d23593d45f255f4e56e4cb128
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T14:40:26Z'
reviewed_lane_tip: b1fe515d07c081106c9c01a0c056789402386f43
reviewer_agent: codex-wp08-cycle2-reviewer
verdict: approved
wp_id: WP08
---

# WP08 Review Cycle 2

**Verdict: APPROVED**

**Reviewer:** Reviewer Renata (`codex-wp08-cycle2-reviewer`)
**Reviewed correction:** `a43e658`
**Prior rejection:** `0d8f1d7`

## Remediation verdict

Cycle 1's sole blocker is resolved. Commit `a43e658` changes exactly one line in
`services/api/tests/http/startup_readiness_test.zig`: the shutdown-error rebind
now uses `.reuse_address = false`. No production source, dependency source,
build hook, contract, generated artifact, or unrelated test changed.

The corrected test proves the production `Started.shutdown` order rather than
merely permitting a second reusable bind. With the product implementation
unchanged, the test closes the listener before releasing inventory and before
surfacing the injected durable-store shutdown error.

## Deletion-sensitive proof

In a disposable worktree at `a43e658`, the reviewer deleted only
`self.listener.deinit(io)` from `Started.shutdown`, added `_ = io` solely to keep
that deletion compilable, and retained both `self.inventory.deinit()` and
`store.shutdown()`.

The exact command

```text
zig build test-http --build-file services/api/build.zig --summary all
```

exited `1` with exactly one failing test and `30/31` tests passing. The sole
failure was:

```text
startup_readiness_test.test.graceful Started shutdown stops listener before surfacing store close failure
error.AddressInUse
```

The error arose at the corrected non-reusable rebind. Route policy, readiness,
envelope, health, performance, process-fixture, and black-box tests remained
green. This is the causal failure required by the cycle-1 review.

## Independent green evidence

- `zig version` — PASS (`0.16.0`).
- `npm ci` under Node.js `24.18.0` and npm `11.16.0` — PASS, zero audit findings.
- `zig build test-http --build-file services/api/build.zig --summary all` — PASS
  twice in Debug, `20/20` build steps and `31/31` tests each time.
  - Run 1: `100/100` valid responses, zero failures,
    min/median/p99/max `254/285/368/385 us`.
  - Run 2: `100/100` valid responses, zero failures,
    min/median/p99/max `245/273/339/362 us`.
- `zig build -Doptimize=ReleaseSafe test-http --build-file services/api/build.zig --summary all`
  — PASS.
- `zig build test --build-file services/api/build.zig --summary all` — PASS.
- `npm run api:check` — PASS.
- `zig fmt --check services/api/src/main.zig services/api/src/http services/api/tests/http`
  — PASS.
- `git diff --check` and the isolated correction diff check — PASS.
- Commit scope assertion — PASS: `a43e658` changes only
  `services/api/tests/http/startup_readiness_test.zig`.

## Subtask verdicts

- **T037 — PASS:** listener lifecycle and resource cleanup are now covered by a
  deletion-sensitive shutdown-error test.
- **T038 — PASS:** cycle-1 envelope and safe-diagnostic evidence remains valid;
  this correction does not touch the surface.
- **T039 — PASS:** cycle-1 canonical inventory, binding, protected-default, and
  RED-before-GREEN evidence remains valid; this correction does not touch it.
- **T040 — PASS:** both current Debug runs and ReleaseSafe exercise the spawned
  real service and honest 100-request measurement.
- **T041 — PASS:** the prior typed readiness, no-bind matrix, snapshot,
  corruption, DDL recovery, and graceful shutdown evidence is intact, and the
  formerly vacuous listener-close error path now fails causally on deletion.

## Anti-pattern checklist

1. **Dead code — PASS.** The correction introduces no function, type, module, or
   product path.
2. **Synthetic-fixture test — PASS.** The corrected test executes the real
   `Started.shutdown`, real listener handle, injected public store seam, and
   operating-system bind behavior.
3. **Silent empty return — PASS.** No return or error-handling path changed.
4. **FR coverage — PASS.** Existing cycle-1 coverage remains intact; the
   correction strengthens NFR-009 and C-003 shutdown evidence.
5. **Frozen surface — PASS.** Only a WP08-owned HTTP test changed.
6. **Locked decision — PASS.** No product decision changed; listener-before-store
   shutdown is now enforced more strongly.
7. **Shared-file ownership — PASS.** The correction touches no shared or
   dependency-owned file.
8. **Production fragility — N/A.** No production code or Zig error path changed.

The action prompt still carries `implementer-ivan` / `role: implementer`; the
reviewer explicitly loaded `reviewer-renata`. This metadata oversight is
nonblocking and did not affect the review.

No task state was moved and no product file was modified during review. Review
caches, generated inventory, `node_modules`, `.spec-kitty`, and the disposable
deletion worktree were removed before committing this artifact.
