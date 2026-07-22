---
affected_files:
  - kitty-specs/p0-contract-spine-01KXYY0J/tasks/WP07-parallel-safe-migration-runner.md
blocking_findings: 1
cycle_number: 2
implementation_commit: efbecdc84f1f2645506afe0ec85db666ee138b70
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T10:16:22Z'
reviewed_lane_tip: 5d863da4c688a2a3f330d796c70b3bc0d0e5d31b
reviewer_agent: 'codex:reviewer-renata'
verdict: rejected
wp_id: WP07
---

# WP07 Review Cycle 2 — REJECTED

The correction product at `efbecdc` passes semantic review and closes all six
cycle-1 product blockers. The review is rejected on one hard evidence-governance
gate: part of the required RED Activity Log was reconstructed after the product
commit.

## Blocking finding

### G1 — later correction RED evidence was entered after the product commit

The WP requires a timestamped Activity Log `RED:` entry for each behavior before
the related production edit and directs reviewers to reject missing,
nonchronological, or reconstructed evidence. Commit chronology proves that the
permanent test-only commits `f21afe9..a31b80b` precede the production correction,
but commit chronology is not a substitute for the stricter Activity Log gate.

The Activity Log records individual RED entries only through `c009114`. The later
test-only corrections `cfa3758`, `29a7af1`, `f5b8484`, `ba2ba29`, `747191c`,
`4b4a210`, `1765187`, `c8028d2`, and `a31b80b` are covered only by the consolidated
entry at `2026-07-21T10:04:28Z`. The production commit `efbecdc` has commit time
`2026-07-21T10:03:59Z`, so that RED entry is 29 seconds later and explicitly
reconstructs the missing evidence from earlier commits. The GREEN entry follows at
`2026-07-21T10:04:30Z`.

This is a hard failure of the WP's Chronological Red-First Evidence and Definition
of Done gates even though the tests themselves were committed first. Do not add a
second retrospective RED note or relabel the existing entry. Because past
contemporaneous evidence cannot be recreated, resubmission needs a
governance-authorized fresh correction lineage/work package in which each public
RED Activity Log entry is emitted before its production correction, or an explicit
project-authority amendment to the gate. The reviewer cannot infer a waiver.

## Cycle-1 blocker disposition

- B1 false Ready / skipped continuation: **CLOSED** — successful durability
  completion returns `revalidation_required`; first- and middle-migration cases
  re-run discovery/history, never replay the durable migration, and apply later
  work exactly once.
- B2 synthetic public categories: **CLOSED** — `RunDiagnostic` exposes the actual
  primary and consequence; DDL remains primary while later-work blocking is a
  consequence, reopen failure carries quarantine, and durability boundaries are
  typed on the public result.
- B3 unsafe owner roots: **CLOSED** — roots are normalized, basename-bound, opened
  component-by-component without symlink following, aliases collide on normalized
  descriptor identity, and recursive discovery remains valid.
- B4 ambiguous fresh bootstrap: **CLOSED** — exact bootstrap application is gated
  through WP06 `initializeFresh`; nonempty, malformed, and deleted-history stores
  fail as corruption with zero replacement migration DDL.
- B5 partial DDL recovery: **CLOSED** — the permanent multi-statement case creates a
  visible partial object before failure, then proves discard/reopen restores the
  byte-identical durable snapshot, omits the history row, and blocks later schema.
- B6 no-op and allocation cleanup: **CLOSED** — identical rerun performs zero DDL
  and preserves durable bytes; allocation/discard/reopen paths return typed cleanup
  diagnostics and retain balanced/recoverable state in the exercised sweeps.

## Independent evidence

- Debug and ReleaseSafe `test-migration`, `test-migration-integration`,
  `migration-negative`, and `coverage-migration` pass. The mandatory root
  `npm run migration:negative` passes with all 36 cases.
- Debug aggregate `coverage` passes: migration `571/631` (90.49%) with `36/36`
  critical branches and 38 tests; shared `221/243`; persistence `577/641`.
- Formatting and owned-file diff checks pass.
- Independent exact-byte recomputation gives 119 script bytes and
  `sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3`;
  the six-field sorted canonical bootstrap projection is 224 bytes and
  `sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877`.
  The independent published JCS vector is 295 bytes and
  `sha256:2e13316049752ad3eb2b249b89373bd30b540e00397b6010da571ba19032c021`.
- Mission contract round-trip is in scope only for the migration manifest schema;
  the implementation matches its required fields, closed owner set, exact
  `up.sql` value, digest forms, and additional-field rejection. Other mission
  contracts are orthogonal to WP07.
- Temporary public-boundary reviewer probes on pinned Zig 0.16/Linux confirmed
  both a symlinked `manifest.json` and a symlinked `up.sql` return exact
  `SymlinkEscape`; outside bytes are not accepted. The probes were removed before
  verdict and lane-g is clean.
- Product/test correction commits remain within WP07-owned migration files. The
  WP06 fresh-initialization and WP04 build-graph commits are explicit approved
  dependency composition, not unowned WP07 edits.

## Requirement and subtask verdicts

- T031: **PASS** — exact generic bootstrap only, immutable digests, no down script.
- T032: **PASS** — normalized component-safe recursive owner discovery.
- T033: **PASS** — deterministic dependency DAG, collisions, missing edges, cycles,
  and bounded allocation diagnostics.
- T034: **PASS** — immutable five-field history, exact no-op, and correct counts.
- T035: **PASS** — discard/reopen safety, typed durable boundary, and mandatory
  revalidation before readiness.
- T036 / NFR-006: **PASS semantically** — honest 90.49% production-PC coverage and
  all 36 exact public critical scenarios.
- Chronological Red-First Evidence / WP Definition of Done: **REJECTED** — G1.

## Anti-pattern checklist

1. Dead code: **N/A** — this is the explicit producer seam for dependent WP08;
   production-internal paths call the discovery, plan, and run surfaces.
2. Synthetic-fixture test: **PASS** — corrected critical outcomes are asserted from
   public errors/readiness/diagnostics rather than manufactured expected results.
3. Silent empty return: **PASS** — optional lookup nulls are explicit states; no
   swallowed empty failure return was introduced.
4. FR coverage: **PASS** — FR-009/FR-010 and cited NFR behavior have direct public
   assertions.
5. Frozen surface: **PASS** — no WP07 correction commit edits WP03 schemas, WP04
   wiring, WP05 values, or WP06 internals.
6. Locked decision: **PASS** — no registry/down/reset path, raw adapter access, or
   pre-directory-sync Ready state exists.
7. Shared-file ownership: **PASS** — dependency composition is explicit and the
   WP07 test/product commits stay owned.
8. Production fragility: **PASS** — failures are typed and fail loud through the
   recovery facade; no bare transient-race propagation was introduced.

The WP frontmatter still resolves `implementer-ivan` during review. Reviewer Renata
was explicitly loaded for this cycle; retaining `implementer-ivan` is correct for
the rollback to implementation/planning state.
