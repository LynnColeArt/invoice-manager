---
affected_files:
  - services/api/build.zig
  - services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 0
correction_commits:
  - 1e9027dc94fcb175caadb5d4e6460517ed8fb0f5
  - da7e7e359abac13bd2f438ef877b4845e35d7f63
cycle_number: 18
implementation_commit: da7e7e359abac13bd2f438ef877b4845e35d7f63
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T11:20:48Z'
reviewed_lane_tip: dc1ff413e17701c79571a8a45b4d272fee2aba92
reviewer_agent: codex-wp04-cycle18-reviewer
verdict: approved
wp_id: WP04
---

# WP04 Review Cycle 18 — APPROVED

Cycle 17's sole least-authority blocker is closed. The production `http`
module now receives only `shared`; `composition` retains `shared`,
`persistence`, `migrations`, and `http`; and HTTP test roots retain those
public modules plus `composition` and `http_test_config`. The chronological
negative is public, exact, and non-vacuous. No blocking finding remains.

## Correction verification

- Test-first chronology — PASS. `1e9027d` is a direct child of the pre-fix lane
  tip and changes only the permanent discovery test. `da7e7e3` is its direct
  child and changes production only by deleting the two `persistence` and
  `migrations` entries from `http_imports`.
- Real RED — PASS. A clean `git archive 1e9027d` replay of `zig build
  test-build-discovery --summary all` fails exactly 19/20. The new negative
  reports `UnexpectedCommandSuccess` because the nested `test-http` build
  succeeds 8/8 and its HTTP test passes 1/1 under the old over-capable graph.
- Current discovery — PASS, 20/20. The negative now observes a nonzero nested
  build with exact `no module named 'persistence'` stderr.
- Non-vacuous deletion test — PASS. The same committed fixture fails against
  the old graph and passes only after the two capability deletions.
- Positive graph and execution — PASS. The permanent positive fixture gives
  synthetic HTTP only `shared`; synthetic composition directly imports and
  touches `shared`, `persistence`, `migrations`, and `http`; the HTTP test
  imports all required public/test modules and launches the emitted
  `invoice-manager-api` successfully within the fresh 20/20 discovery run.
- Preserved cycle-17 behavior — PASS. `getEmittedBin()` test configuration,
  direct materializer prerequisites, executable construction, test imports,
  run forwarding, and fail-closed producer handling are unchanged. Fresh
  absent-producer `test-http` and `run -- forwarded-token` checks both fail
  nonzero with their owning-WP08 diagnostics.
- Regression scope — PASS. Fresh Zig `0.16.0` format checks, base build, and
  `git diff --check` pass. The correction does not touch the adapter, ABI
  integration, vendored source, provenance, license, coverage runner, or
  instrumentation. The immediately preceding recorded cold-cache and ABI
  matrix therefore remains applicable; source inspection found no regression
  trigger requiring that expensive matrix to be repeated.
- Worktree hygiene — PASS. Generated Zig cache/output from review were removed;
  pre-existing `.spec-kitty/` state was preserved.

## Anti-pattern checklist

1. Dead code — PASS. The authority split is exercised through nested builds,
   test compilation, composition compilation, and emitted executable launch.
2. Synthetic-fixture test — PASS. The fixture drives the production
   `services/api/build.zig` graph; the old graph demonstrably fails the test.
3. Silent empty return — N/A.
4. FR coverage — PASS for the WP08 least-authority consumer boundary.
5. Frozen surface — PASS. Test RED and two-line product deletion stay within
   the WP04-owned build/discovery surfaces.
6. Locked decision — PASS. HTTP cannot name persistence or migrations while
   the composition root and tests retain their required capabilities.
7. Shared-file ownership — PASS. `services/api/build.zig` remains WP04's
   authoritative build graph.
8. Production fragility — N/A; no production exception or fallback path was
   added.

## Verdict

Approve WP04. Commits `1e9027d` and `da7e7e3` close the sole cycle-17 blocker
with a chronological public RED, a two-deletion product correction, and an
exact permanent regression proof while preserving every previously accepted
HTTP consumer, executable, ordering, fail-closed, ABI, and coverage behavior.
