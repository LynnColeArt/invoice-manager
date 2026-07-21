---
affected_files:
  - services/api/build.zig
  - services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 1
correction_commits: []
cycle_number: 21
implementation_commit: fd3f82919136565ee3587594ff5dc753977e6ce3
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T12:31:00Z'
reviewed_lane_tip: ac4398727e547764b2966817672dbf66acb9d1ce
reviewer_agent: codex-wp08-aggregate-audit
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 21 — REJECTED

WP08's aggregate acceptance gate exposed one remaining production build-graph
defect. The focused repository-root command is green, but WP04's aggregate
runner changes the nested service working directory without giving HTTP run
artifacts a canonical working directory. The emitted API therefore resolves
its repository-relative migration root from the wrong directory and fails
before readiness.

## Blocking finding

1. **Aggregate HTTP execution has invocation-dependent working-directory
   semantics.** `addSequentialGate` launches `zig build test-http` from
   `services/api`, while the HTTP test artifacts and their emitted API child
   inherit that directory. WP08's composition root then resolves
   `services/api/migrations/p0` as
   `services/api/services/api/migrations/p0`. The exact focused command
   `zig build test-http --build-file services/api/build.zig` remains green
   because it runs from the repository root, but the mandatory aggregate
   `zig build test --build-file services/api/build.zig` reaches the real
   black-box child and fails with `UnexpectedStartupDiagnostic`. This makes
   the stable aggregate gate disagree with the independently runnable HTTP
   gate and leaves `run`/test behavior dependent on the caller's cwd.

## Required correction

- Give production HTTP test/run artifacts an explicit canonical repository
  working directory through the WP04 build graph; do not add a WP08 production
  fault environment, duplicate migration roots, or cwd guessing.
- Add a permanent deletion-sensitive discovery regression proving the nested
  aggregate/service invocation launches the emitted API against the real
  canonical migration root.
- Preserve the accepted least-authority graph, exact materializer dependency,
  emitted executable mapping, run argument forwarding, and fail-closed
  producer diagnostics.
- Record chronological test-only RED and product GREEN commits and replay the
  focused and aggregate HTTP gates from clean output.

## Verdict

Reject WP04 cycle 21 and reopen only the HTTP run-artifact cwd seam. WP08 must
remain in progress until this upstream correction is independently reviewed
and merged into its dependency lane.
