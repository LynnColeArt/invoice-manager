# WP10 Review Cycle 1

**Verdict:** Changes requested  
**Reviewer:** `codex-wp10-independent-review`  
**Implementation:** `170d25364b9d2055f1d2d3f68f73d84436295ce9`  
**Implementation tree:** `82ba874b30a55652bd391bce8eeb881fe9616ad0`

## Blocking finding

### 1. Remove the unused contracts re-export facade

`apps/web/src/lib/contracts/index.ts` has no production or test caller. A targeted
call-site search finds only declarations inside that file, while the live client,
envelope, and server adapters correctly import the canonical
`@invoice-manager/contracts/v1` package directly. The module therefore fails the
mandatory WP dead-code anti-pattern gate.

Delete `apps/web/src/lib/contracts/index.ts`. No replacement or import rewrite is
needed. Keep `wire-values.ts`: unlike the unused facade, its checked canonical int64
and display behavior is explicitly required by T045/NFR-004 and is covered by the
boundary tests. Re-run the focused web gates and return the package with a reviewer
profile selected for the next review invocation.

## Independent evidence

- Provenance and scope: approved WP09 tip `9799b00` is an ancestor; the implementation
  parent-to-commit diff contains exactly 18 WP10-owned `apps/web/src/**` and
  `apps/web/tests/foundation/**` paths. `170d253..HEAD -- apps/web` is empty.
- Immutable SHA-256 values remained exact before and after review:
  - root package `816264f8552943384dad5e4a72502b95c8975568487308115dc5481298a37bfd`
  - contracts package `ee7fcc2fa81cf2b8884cbc54ab3a01a5c8f30a400dabb5afdced384dc9f508f0`
  - web package `f31c4513240ee6dbd76796d6e846901446df69bed46a0ac2871bfb006b492db2`
  - lock `6ea2ffb829843f8f67f407754166ca52c1556ddfc9164f6b1b2c4d5e3dc257f7`
  - Next config `a6fbd459fab2c5103b177f0d50d19e7941e006a91a7aece417be37ecd6319496`
  - TypeScript config `c36224bb0c4a2546c56709a2bfbca4c39b6c73f8945569fcd18c33e3e75b43f8`
  - Next declaration `7b550dda9686c16f36a17bf9051d5dbf31e98555b30d114ac49fc49a1e712651`
- Exact Node 24.18.0/npm 11.16.0 `npm ci`: 496 packages added, 499
  audited, zero vulnerabilities.
- Clean no-`.next`, origin-unset `npm run web:check`: PASS. Contract generation,
  formatting, lint, strict typecheck, 24 Vitest tests, and production build all pass.
- Bare `npm run http:smoke`: PASS. It reproduced private-network-namespace
  attestation, failure/timeout/signal cleanup, real WP08 Ready separately from all
  hostile sockets, stopped/missing/invalid configuration, redirect, deadline and
  abort, declared and streamed 16 KiB overflow, exact JSON-media rejection,
  malformed and unexpected envelopes/status, header/origin leakage prevention,
  framework pre-routing zero-I/O behavior, same-origin accessibility, responsive
  layout, and released ports/temp data.
- Diagnostic-only NFR-007 evidence: 10 sequential warmups discarded; exactly 100
  sequential complete-body samples retained; min `2.110 ms`, median `2.602 ms`,
  nearest-rank sample-99 `8.166 ms`, max `11.891 ms`, slow `0`, invalid `0`.
- Generated build, dependency, test, contract, and Zig-cache outputs were removed
  after review. The only remaining untracked lane file was Spec Kitty's active
  review lock.

## Anti-pattern checklist

1. **Dead code — FAIL:** unused `src/lib/contracts/index.ts` facade.
2. **Synthetic-fixture test — PASS:** public production Next/Zig and hostile-socket
   paths independently exercise the behavior asserted by unit tests.
3. **Silent empty return — PASS:** null/empty decode sentinels are explicit
   fail-closed inputs to canonical unavailability handling.
4. **FR coverage — PASS:** T043-T047 gates cover every WP requirement reference.
5. **Frozen surface — PASS:** no manifest, lock, WP09 config, Zig, contract, or
   generated surface changed in the implementation commit.
6. **Locked decision — PASS:** no external rewrite, browser origin, business rule,
   unsafe numeric coercion, unbounded body, redirect following, or final WP12 claim.
7. **Shared-file ownership — PASS:** all implementation paths are WP10-owned; the
   accepted WP09 dependency was merged unchanged.
8. **Production fragility — PASS:** validation throws are explicit fail-loud int64
   boundaries; request and transport failures map to bounded safe envelopes.

## Governance note

The governed review action resolved the implementation profile `node-norris` rather
than a reviewer profile. This did not alter the independent result, but the next
review handoff should select a reviewer profile before invoking review. Do not rewrite
implementation ownership metadata from this review cycle.
