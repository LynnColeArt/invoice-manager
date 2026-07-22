# WP08 Review Cycle 1

**Verdict: REJECTED**

**Reviewer:** Reviewer Renata (`codex-wp08-cycle1-reviewer`)
**Reviewed implementation:** product tip `54f90ed`; lane coordination tip reviewed after the WP08 action rebase
**Authoritative activity evidence:** `22fded6`

## Blocking finding

### 1. The listener-before-store shutdown proof is not deletion-sensitive

The production order in `services/api/src/main.zig` is correct: `Started.shutdown`
closes the listener, releases the inventory, and then closes the durable store.
The required error-path test does not currently prove the listener close.

In a disposable worktree at `54f90ed`, the reviewer deleted only
`self.listener.deinit(io)` from `Started.shutdown`, retained
`self.inventory.deinit()`, retained `store.shutdown()`, and discarded the now
unused `io` parameter. The exact command

```text
zig build test-http --build-file services/api/build.zig --summary all
```

still exited `0` with `20/20` build steps and `31/31` tests passing.

The claimed proof in
`services/api/tests/http/startup_readiness_test.zig` rebinds after an injected
store-shutdown failure with `.reuse_address = true`. That rebind succeeds even
when the original listener remains open, and the test performs no subsequent
accept/connect check against the original listener. The spawned SIGTERM case
also cannot expose this deletion because process exit lets the operating system
close the socket.

This blocks approval under the mandatory deletion-test gate and WP08's explicit
requirements to stop accepting before store close, prove graceful shutdown on
error paths, and release process resources.

**Required remediation:** strengthen the shutdown-failure test only. Rebind
without address reuse (`.reuse_address = false`) or add an equivalent bounded
proof that the original listener cannot accept after `Started.shutdown` returns
the injected store-close error. Replay the deletion above and record the
expected failure. The current production shutdown order should remain unchanged
unless the stronger test reveals a separate defect.

## Subtask verdicts

- **T037 — PASS:** the real listener serves only `GET /api/v1/health`; parsing,
  request sizes, the header deadline, generated RequestIds, and response cleanup
  are bounded. The shutdown error-path evidence gap above prevents the package
  from being approved.
- **T038 — PASS:** success and 400/404/405/500/503 failure envelopes are closed,
  deterministic, use one canonical RequestId, validate field pointers, bound
  public output, and suppress typed handler/store diagnostics.
- **T039 — PASS:** the canonical generated inventory has one embed and one public
  operation, validates one-to-one bindings, defaults invalid access to protected,
  and reaches the real dispatch boundary. Qualifying RED commits `6a63d78` and
  `f58f651` are ancestors of GREEN commit `febfd2d`.
- **T040 — PASS:** black-box tests spawn the real executable, traverse loopback
  TCP, validate complete wire responses, exercise malformed/disconnected/slow
  clients, and issue exactly 100 sequential measured requests.
- **T041 — REJECT:** typed WP06/WP07 readiness, no-bind failure composition,
  seeded snapshot preservation, corruption handling, DDL recovery, and fallback
  refusal pass. The listener-close-on-store-shutdown-error proof is vacuous under
  the deletion replay above.

## Independent execution evidence

All commands ran from the dependency-resolved lane with pinned Node.js 24.18.0,
npm 11.16.0, and Zig 0.16.0.

- `npm run contracts:generate` — PASS (`modules=1 routes=1 conformance=4`).
- `zig build test-http --build-file services/api/build.zig` — PASS twice in
  Debug, each with `100/100` valid responses and zero failures:
  - min/median/p99/max `261/296/435/459 us`;
  - min/median/p99/max `256/289/357/376 us`.
- `zig build -Doptimize=ReleaseSafe test-http --build-file services/api/build.zig --summary all`
  — PASS after removing local build caches.
- `zig build test --build-file services/api/build.zig --summary all` — PASS.
- `npm run contracts:check` — PASS (`modules=1 routes=1 conformance=4`).
- `npm run api:check` — PASS.
- `zig fmt --check services/api/src/main.zig services/api/src/http services/api/tests/http`
  — PASS.
- `git diff --check` — PASS.

The performance test was inspected for threshold honesty: it measures exactly
100 sequential real TCP responses after warmup, counts request errors and invalid
responses as failures, requires all 100 responses to be valid, and separately
requires at least 99 responses within one second.

## Deletion and adversarial evidence

- Removed route-policy classification from real dispatch: focused HTTP gate
  failed exactly the protected canonical and invalid-access cases, each observing
  `handler_calls=1` instead of `0`.
- Removed the typed readiness check from `listenWhenReady` while retaining
  compilability: readiness test failed with an unexpected bound `Listener`.
- Extended the server header deadline from two seconds beyond the three-second
  observer: the spawned slow-client test failed with
  `HeaderDeadlineNotEnforced`.
- Deleted only listener deinitialization from `Started.shutdown`: all `31/31`
  HTTP tests still passed. This is the blocking result.

Static adversarial review also confirmed that only `main.zig` imports WP06/WP07,
the only production listener call follows typed readiness and inventory/binding
validation, startup diagnostics are stable and path-free, and no fallback,
authentication machinery, or invoice-manager domain route was added.

## Anti-pattern checklist

1. **Dead code — PASS.** All production modules and production entry points have
   live production callers. Explicit inventory-clone and direct-not-ready test
   seams exist to satisfy required boundary tests and do not implement dormant
   feature behavior.
2. **Synthetic-fixture test — PASS.** FR evidence reaches production envelope,
   inventory, dispatch, listener, store, and migration paths. The standalone
   hostile-string assertion is weak by itself, but real failing-handler and
   corrupt-process tests supply deletion-sensitive diagnostic-leak coverage.
3. **Silent empty return — PASS.** Optional lookup `null` and the platform no-op
   signal-handler value are intentional; no new error path silently returns an
   empty success value.
4. **FR coverage — PASS.** FR-002, FR-004, FR-006, FR-015, NFR-007, NFR-009, and
   C-003 each have behavioral assertions against the named boundary.
5. **Frozen surface — PASS.** WP08 product commits modify only the owned HTTP
   source/test surface and `main.zig`; no contract, generated artifact, shared
   value, persistence/migration source, or build file is changed by WP08.
6. **Locked decision — PASS.** The implementation preserves sole health scope,
   protected default, one canonical inventory, no pre-readiness bind, and no
   storage fallback.
7. **Shared-file ownership — PASS.** Replayed WP04/WP05/WP07 changes are approved
   dependency inputs. WP08 product changes stay within its owned files; Activity
   Log commits are governance evidence, not product-surface crossings.
8. **Production fragility — N/A.** Zig has no `raise` path; production errors are
   propagated or mapped fail-closed with stable public diagnostics.

## Nonblocking observations

- The action prompt retained `implementer-ivan` / `role: implementer` in WP08
  frontmatter. The reviewer explicitly loaded `reviewer-renata`; this governance
  metadata oversight did not affect the independent verdict.
- Per-class process exit/log proof is factorized through the common `main` catch,
  while representative real-process corruption proves the shared exit and safe
  diagnostic path. The in-process composition matrix proves each typed cause
  remains before bind.
- `ReadyContext` is an opaque safe-call capability with one repository production
  caller. A deliberate unsafe pointer cast could forge it, which is outside the
  safe-call contract and is not a current repository bypass.

No task state was moved and no product file was modified during review.
