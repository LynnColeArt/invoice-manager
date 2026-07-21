---
affected_files:
  - services/api/tests/persistence/migrations_test.zig
  - services/api/tests/persistence/migrations_coverage_test.zig
blocking_findings: 0
correction_commits:
  - 2e478dc353eae5907bb8f293e10bd29e75468209
cycle_number: 5
implementation_commit: 2e478dc353eae5907bb8f293e10bd29e75468209
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T14:02:11Z'
reviewed_lane_tip: 74e3afe072ff9f2abd69b75342786a89e8837b50
reviewer_agent: codex-wp07-cycle5-reviewer
verdict: approved
wp_id: WP07
---

# WP07 Review Cycle 5 — APPROVED

Commit `2e478dc` closes cycle 4's sole invocation-portability blocker with a
two-file, test-only correction. The committed migration implementation, WP04
build graph, bootstrap bytes, fixed digest vector, and every deliberate invalid
fixture remain unchanged. Both supported invocation roots and measured
repository-root coverage are green, and focused deletion replays prove the unit
and coverage corrections are independently causal. No blocking findings remain.

## Sole-blocker verification

- **Exact scope — PASS.** `2e478dc^..2e478dc` modifies only WP07-owned
  `services/api/tests/persistence/migrations_test.zig` and
  `services/api/tests/persistence/migrations_coverage_test.zig`. No production
  `migrations*.zig`, migration descriptor/script, digest vector, contract,
  build file, package script, or dependency source changed.
- **Two supported layouts, fail loud elsewhere — PASS.** Each helper contains
  exactly two source-layout candidates: repository-root
  `services/api/tests/persistence` paired with
  `services/api/migrations/p0`, and service-root `tests/persistence` paired
  with `migrations/p0`. A candidate is returned only after opening the source
  directory and confirming it contains the executing test basename. A
  non-`FileNotFound` access error propagates, and no match returns
  `SourceDirectoryNotFound`. An independent absolute-build-file invocation
  from `/tmp` failed exactly the bootstrap and vector cases with that error,
  confirming no third ambient-cwd fallback is accepted.
- **One coherent unit fixture layout — PASS.** `sourceAnchoredFixtures` returns
  migration root and digest-vector path as one matched tuple. Bootstrap
  discovery uses that root, and the `down.sql` absence assertion joins the same
  root with the exact bootstrap ID. The JCS test reads the adjacent committed
  vector from the same selected source layout; it does not embed or copy the
  vector.
- **Bootstrap and digest invariants — PASS.** Exact `up.sql` bytes still hash to
  `68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3`,
  matching manifest `script_digest`. Manifest `descriptor_digest` remains
  `sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877`,
  `depends_on` remains empty, `script_path` remains exact `up.sql`, and no
  `down.sql` exists. Current unit tests revalidate exact bytes, final LF,
  generic schema-only content, JCS bytes, and both digests.
- **Adversarial fixtures preserved — PASS.** The zero-context commit diff adds
  only the two layout helpers and replaces committed-root consumers. Unit
  temporary roots, normalized-alias and symlink cases are unchanged. Coverage
  temporary trees, malformed/oversized manifests, owner mismatches, explicit
  `migrations/../p0` path traversal, `../up.sql`, DDL/recovery faults, and
  allocation-failure scenarios are unchanged. Coverage substitutions occur
  only where a helper intentionally consumes the live committed bootstrap root.
- **Current focused gates — PASS.** Service-root `zig build test-migration
  --summary all` passed 10/10. Repository-root `zig build test-migration
  --build-file services/api/build.zig --summary all` also passed 10/10.
  Repository-root `test-migration-integration` passed 15/15.
  Repository-root `coverage-migration` passed 14/14 steps and 41/41 prerequisite
  tests, measuring 571/631 owned production control-flow sites (90.49%), all
  36/36 critical branches, 38 coverage tests passed, and zero skipped.
- **Unit deletion sensitivity — PASS.** In a disposable `2e478dc` export, I
  restored only the old service-cwd bootstrap root, `down.sql`, and digest-vector
  reads. The service-root unit gate remained 10/10. The repository-root unit
  gate exited 1 at exactly 8/10; the sole failures were bootstrap discovery and
  the fixed JCS vector, matching cycle 4.
- **Coverage-consumer deletion sensitivity — PASS.** In a separate disposable
  export, I removed only the repository-root migration mapping from the coverage
  helper. Unit, integration, and negative prerequisites all remained green at
  41/41, but the coverage executable exited 1 when a committed-root consumer
  observed `DiscoveryFailure` instead of required `RecoveryQuarantine`. This
  proves the helper changes participate in live coverage behavior rather than
  merely changing unused fixture text.
- **Chronology and quality — PASS.** Authoritative rejection `7cdd7b3` is an
  ancestor of `2e478dc`. Zig formatting and `git diff --check` pass. Both
  disposable trees and generated caches were removed after review.

## Review identity metadata

The generated WP prompt still names `implementer-ivan` despite the governed
action resolving WP07 in the review lane. This gate followed the explicit
assignment and loaded `reviewer-renata`. The stale task-profile metadata is
recorded here and was not edited into the dirty task mirror.

## Anti-pattern checklist

1. Dead code — N/A. No production declaration or module was added.
2. Synthetic-fixture test — PASS. Unit tests call public discovery and
   canonicalization over committed bytes; coverage calls the public migration
   boundary and deletion makes the real runner fail.
3. Silent empty return — PASS. Layout and fixture errors propagate explicitly;
   no empty result, skip, or catch-all success was introduced.
4. FR coverage — PASS. Previously accepted FR-009/FR-010 behavior and all 36
   critical branches remain live from the canonical repository-root gate.
5. Frozen surface — PASS. No contract, dependency, build, bootstrap, or digest
   fixture changed.
6. Locked decision — PASS. Forward-only, owner-scoped, registry-free,
   durability-gated migration behavior is unchanged; no down/reset path exists.
7. Shared-file ownership — PASS. Both changed files are exclusive WP07 test
   surfaces.
8. Production fragility — N/A. No production exception, fallback, or runtime
   path changed.

## Verdict

**APPROVED.** `2e478dc` is a narrow, fail-loud, deletion-sensitive correction
for the sole cycle-4 blocker. WP07 is ready for its governing state transition;
this review intentionally does not perform that transition.
