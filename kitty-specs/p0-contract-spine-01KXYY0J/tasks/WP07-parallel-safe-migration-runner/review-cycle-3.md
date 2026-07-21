---
affected_files:
  - services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/manifest.json
  - services/api/migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/up.sql
  - services/api/src/platform/persistence/migrations.zig
  - services/api/tests/persistence/migrations_test.zig
  - services/api/tests/persistence/migrations_integration_test.zig
  - services/api/tests/persistence/migrations_negative_test.zig
  - services/api/tests/persistence/migrations_coverage_test.zig
  - services/api/tests/persistence/migrations_digest_vector.json
blocking_findings: 0
cycle_number: 3
implementation_commit: 42f375bd39aaf07f4f7ff9ae9e3ac3bc876fd7ff
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T10:35:29Z'
reviewed_lane_tip: e9f2812d38c4ad4270b716c9a96c328fbec7917b
reviewer_agent: 'codex:cycle3-independent-reviewer'
verdict: approved
wp_id: WP07
---

# WP07 Review Cycle 3 — APPROVED

WP07 is approved. The sole cycle-2 governance blocker is closed by a transparent,
non-rewritten correction lineage, and the effective correction remains semantically and
byte-for-byte equivalent to the cycle-2-reviewed product on every WP07 product and test
surface.

## Cycle-2 blocker disposition

### G1 — chronological RED evidence: CLOSED

Git and Activity Log evidence now establish the required execution order:

1. `ce4b886` at `2026-07-21T10:20:06Z` reverted the correction product while retaining
   the permanent public-boundary correction tests.
2. With that reverted product checked out, the public Debug gates genuinely failed:
   `test-migration` ran 10 tests with 4 passes and 6 root/discovery failures;
   `test-migration-integration` failed compilation on the absent `RunDiagnostic`,
   `durability_boundary`, and scheduled application-fault seams. The root negative and
   exact coverage gates failed transitively for the same missing public behavior.
3. The contemporaneous Activity Log entry is timestamped `2026-07-21T10:20:39Z` and is
   committed by `cbfc861` (author `10:21:20Z`, committer `10:22:38Z`).
4. Only afterward, `42f375b` at `2026-07-21T10:22:45Z` reapplied the effective product
   correction.
5. The later GREEN entry at `2026-07-21T10:25:54Z` records the complete passing matrix.

The reviewer independently repeated the deletion test in a detached `ce4b886` worktree.
The unit gate failed exactly 4/10 with the six recorded root/discovery assertions, and
the integration gate failed on the six recorded missing public declarations. No commit
dates or history were rewritten. `git diff --exit-code efbecdc 42f375b` over all WP07
product, fixture, and test paths returned zero, proving effective tree equivalence.

## Cycle-1 product and safety findings

- **B1 false Ready / lost continuation: CLOSED.** `completeDurability` returns
  `revalidation_required`, never Ready. First- and middle-migration checkpoint,
  directory-sync, and unsupported-sync cases revalidate, do not replay committed DDL,
  and apply later work exactly once.
- **B2 synthetic categories: CLOSED.** Public `RunDiagnostic` and `Readiness` values carry
  the actual primary, consequence, and durability-boundary categories. Dedicated tests
  assert those public results rather than manufacture expected errors.
- **B3 root containment: CLOSED.** Roots are normalized and owner-basename-bound, each
  component is opened without symlink following, file opens use no-follow plus
  resolve-beneath, lexical aliases collapse to one descriptor identity, recursive
  discovery works, and unsupported/unknown directory entries fail closed. Final-root,
  ancestor, manifest-file, and script-file symlink behavior is covered; the latter two
  public probes from cycle 2 remain applicable because the product/test tree is identical.
- **B4 ambiguous fresh bootstrap: CLOSED.** A history-query `StatementObjectFailed` can
  bootstrap only through WP06 `initializeFresh`; nonempty, malformed-history, and
  deleted-history stores return corruption with zero replacement migration DDL.
- **B5 partial DDL recovery: CLOSED.** The public multi-statement case creates a visible
  partial object before failure, then proves discard/reopen removes it, preserves the
  byte-identical durable snapshot and prior history, and blocks later schema.
- **B6 no-op/OOM cleanup: CLOSED.** Identical reruns execute zero DDL and preserve durable
  bytes. Executor OOM, dirty-discard, reopen, discovery/planning/projection allocation,
  and startup cleanup paths assert exact diagnostics, balanced allocations where exposed,
  and recoverable or explicitly quarantined state.

## Independent verification

- Debug: `test-migration`, `test-migration-integration`, `migration-negative`, and
  `coverage-migration` passed.
- ReleaseSafe: the same four focused gates passed.
- Mandatory repository-root `npm run migration:negative` passed and exercised the
  convention-scanned nonempty 36-category matrix.
- Exact migration coverage passed at `571/631` owned production control-flow sites
  (90.49%), `36/36` exact critical branches, 38 tests passed, and zero skipped.
- Serial aggregate coverage passed: shared `221/243`, persistence `577/641`, migration
  `571/631`.
- Pinned Zig 0.16 check, `zig fmt --check`, and owned-file `git diff --check` passed.
- Bootstrap script independently recomputed to 119 bytes with exactly one final LF and
  `sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3`.
- Independent sorted canonicalization produced the 224-byte bootstrap projection and
  `sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877`.
  The published vector matched its canonical UTF-8, hex, 295-byte length, and
  `sha256:2e13316049752ad3eb2b249b89373bd30b540e00397b6010da571ba19032c021`.
- The in-scope migration-manifest contract round-trips its closed fields, P0 owner,
  canonical UUID/digest values, exact `up.sql`, sorted dependencies, and
  additional-field rejection. Other mission contracts are orthogonal to WP07.
- No down migration, destructive reset/repair, shared migration sequence, registry,
  feature-domain schema, raw adapter import, or pre-directory-sync Ready path exists.

## Requirement and subtask verdicts

- T031: **PASS** — generic bootstrap only, exact immutable digests, no down script.
- T032: **PASS** — normalized, recursive, no-follow, owner-scoped discovery.
- T033: **PASS** — deterministic dependency DAG, collisions, missing/self edges, cycles,
  bounded graph handling, and stable diagnostics.
- T034: **PASS** — immutable five-field applied history, exact no-op, drift refusal, and
  correct counts.
- T035: **PASS** — dirty discard/reopen safety, explicit durability boundary,
  revalidation, later-work continuation, and no replay.
- T036 / NFR-006: **PASS** — non-vacuous 90.49% production-PC coverage and all 36 public
  critical scenarios.
- FR-009, FR-010, NFR-003, NFR-006, NFR-009, C-003, and C-005: **PASS** through the
  public migration and WP06 durability boundaries.
- Chronological Red-First Evidence / Definition of Done: **PASS** via the transparent
  `ce4b886 -> cbfc861 -> 42f375b -> GREEN` lineage.

## Anti-pattern checklist

1. Dead code: **N/A** — WP07 intentionally publishes the migration-readiness producer
   seam consumed by dependent WP08; internal discovery, planning, and application paths
   have live production calls.
2. Synthetic-fixture test: **PASS** — FR and critical outcomes execute the public
   production boundary and assert returned errors/readiness/diagnostics.
3. Silent empty return: **PASS** — optional lookup nulls are explicit search results; no
   failure is swallowed into an empty success value.
4. FR coverage: **PASS** — each cited functional and durability behavior has direct public
   assertions.
5. Frozen surface: **PASS** — WP07 correction commits do not edit WP03 schemas, WP04 build
   wiring, WP05 values, or WP06 persistence internals.
6. Locked decision: **PASS** — no registry/down/reset/raw-adapter path or premature Ready
   state contradicts the mission decisions.
7. Shared-file ownership: **PASS** — WP07 test/product changes remain owned; approved WP04
   and WP06 dependency composition is explicit in lane history.
8. Production fragility: **PASS** — failures remain typed and fail loud through WP06's
   recovery facade; no bare transient-race propagation was added.

The generated review prompt still resolved `implementer-ivan` from WP07 frontmatter. The
declared profile was loaded as required, but this session performed review only. The
profile mismatch is a non-blocking metadata oversight and does not alter the verdict.
