---
affected_files:
  - services/api/tests/persistence/migrations_test.zig
  - services/api/tests/persistence/migrations_digest_vector.json
  - services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/manifest.json
  - services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/up.sql
blocking_findings: 1
correction_commits: []
cycle_number: 4
implementation_commit: 42f375bd39aaf07f4f7ff9ae9e3ac3bc876fd7ff
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T13:35:10Z'
reviewed_lane_tip: 2ca1b7751008ffc02e91a00a316c5d43d6a7cdf1
reviewer_agent: codex-wp07-cycle4-reviewer
verdict: rejected
wp_id: WP07
---

# WP07 Review Cycle 4 — REJECTED

WP07's migration product remains correct, and its accepted service-root suite remains
green. The newly integrated repository-root aggregate exposes one test-fixture portability
defect: the WP07 unit root resolves committed fixtures through the ambient process working
directory. The same literal `test-migration` hook therefore passes from `services/api` but
fails when WP04's aggregate invokes it from the canonical repository root.

## Blocking finding

### B1 — Migration unit fixtures depend on ambient CWD

`services/api/tests/persistence/migrations_test.zig` contains two independent
service-root assumptions:

1. The bootstrap discovery test passes `migrations/p0` to the public discovery boundary
   and checks the absent `down.sql` at the same CWD-relative root.
2. The fixed JCS test reads `tests/persistence/migrations_digest_vector.json` through
   `std.Io.Dir.cwd()`.

At integrated lane-h tip `2ca1b7751008ffc02e91a00a316c5d43d6a7cdf1`, the reviewer
independently observed:

- From `services/api`, `zig build test-migration --summary all` passed `10/10`.
- From the repository root, `zig build test-migration --build-file
  services/api/build.zig --summary all` failed exactly `2/10`: bootstrap discovery could
  not open `migrations/p0`, and the fixed-vector test could not open
  `tests/persistence/migrations_digest_vector.json`. The remaining `8/10` passed.
- From the repository root, `zig build test-migration-integration --build-file
  services/api/build.zig --summary all` passed `15/15`. Its `migrationRoot` seam already
  probes service-root `migrations/p0` and falls back to repository-root
  `services/api/migrations/p0`.

The failure is confined to WP07's unit-fixture path construction. No production
`migrations*.zig` code hard-codes either test path, the public migration behavior passes
when supplied the real canonical root, and the real-adapter integration remains green
from the repository root. This is not a migration-product or WP04 build-graph defect.

## Required correction

1. Within WP07's owned test surface, replace both ambient-CWD fixture assumptions with
   source-anchored paths. Derive the canonical migration fixture root from the test source
   location, and resolve or embed the adjacent digest vector from its source location.
   Do not add CWD guessing, duplicate fixture contents, a fallback migration root in
   production, or an edit to WP04's build graph.
2. Use the same source-anchored bootstrap root for discovery and for the absent
   `down.sql` assertion so the test cannot accidentally validate different trees.
3. Preserve the existing production assertions: exact script and descriptor digests,
   one final LF, generic schema only, fixed JCS bytes, and no down migration.
4. Add chronological, deletion-sensitive evidence. Before the correction, retain the
   repository-root `8/10` failure as RED. Afterward, run the literal focused hook from
   both the service root and repository root and require `10/10` in each location. Prove
   that restoring either CWD-relative fixture read makes the repository-root replay fail
   while the source-anchored version passes.
5. Replay `test-migration-integration`, `migration-negative`, and `coverage-migration`
   after the correction to demonstrate that only fixture location changed and no product
   behavior or coverage was weakened.

## Requirement disposition

- T031 and T036: **BLOCKED at the integrated gate** — their committed bootstrap and JCS
  fixtures are correct, but their unit assertions are not invocation-independent.
- FR-009, FR-010, NFR-003, NFR-006, NFR-009, C-003, and C-005: **product behavior remains
  accepted** from cycle 3; no contradictory production evidence was found.
- Definition of Done, literal hook/aggregate compatibility, and DIRECTIVE_030: **FAIL** —
  the relevant integrated test gate is red from the canonical repository-root invocation.
- DIRECTIVE_041: **FAIL until corrected** — these valid tests currently false-red solely
  because fixture resolution is coupled to ambient CWD; preserve their behavioral
  assertions and replace the path coupling.

## Anti-pattern checklist

1. Dead code: **N/A** — no new product dead-code finding; WP08 consumes the published
   readiness seam.
2. Synthetic-fixture test: **PASS** — the bootstrap case calls public production
   discovery, and the JCS case calls the production canonicalizer.
3. Silent empty return: **PASS** — no empty-success masking is involved.
4. FR coverage: **PASS** — the required behaviors have direct assertions when their
   fixtures can be opened; the blocker is invocation portability.
5. Frozen surface: **PASS** — no frozen dependency surface must change for this fix.
6. Locked decision: **PASS** — the product retains forward-only, owner-scoped,
   registry-free migration behavior.
7. Shared-file ownership: **PASS** — the required correction fits WP07-owned
   `services/api/tests/persistence/migrations*`; WP04 must remain unchanged.
8. Production fragility: **PASS** — no production raise/error-path regression was found.

## Verdict

Reject WP07 cycle 4. Preserve the cycle-3-approved migration implementation and correct
only WP07's source-fixture anchoring, with red-first and deletion-sensitive green replay
from both supported invocation roots.
