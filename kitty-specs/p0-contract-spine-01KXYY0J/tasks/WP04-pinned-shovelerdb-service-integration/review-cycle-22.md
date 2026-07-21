---
affected_files:
  - services/api/build.zig
  - services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 1
correction_commits:
  - f98ecfc379ca60e61ea7904d4dbf9a4f85116d4f
  - 53111be273a5373ad0a4787fcc172fed1198a413
  - 76dddae9350762c846b5738bfa0e8eb5adb1ea2b
  - ac3d45c27d5cb02a1a819ffa093a8d3809a0e44a
cycle_number: 22
implementation_commit: 76dddae9350762c846b5738bfa0e8eb5adb1ea2b
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T13:05:27Z'
reviewed_lane_tip: a07f0556dd201a9dc7d469d439b2d5763706379f
reviewer_agent: codex-wp04-cycle22-reviewer
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 22 — REJECTED

Cycle 21's production cwd correction is narrow and appears correct: aggregate
child builds are described with the canonical build file and repository cwd,
the configured API `run` artifact uses the repository cwd, and the previously
accepted emitted-path, materializer, module-capability, and fail-closed graph is
preserved. One missing deletion-sensitive aggregate regression blocks approval.

## Blocking finding

### B1 — No permanent test executes the aggregate consumer being corrected

The new test at
`services/api/tests/persistence/shovelerdb_build_discovery.zig:338-352`
asserts the literal fields returned by `aggregateInvocation`, but it does not
execute `addSequentialGate`. The behavioral fixture at lines 394-461 separately
executes focused `test-http` from the repository root and `run` from the service
root. Neither command invokes aggregate `test`, so neither reaches HTTP through
the production aggregate command construction at
`services/api/build.zig:493-503`.

The deletion test proves the gap. In a detached `ac3d45c` workspace, only the
three production lines consuming `aggregateInvocation` were restored to the
cycle-21 behavior:

```zig
const command = b.addSystemCommand(&.{ "zig", "build", step_name, optimize_arg });
command.setCwd(b.path("."));
```

The helper, its literal assertion, the canonical HTTP fixture, and every other
new test remained unchanged. `zig build test-build-discovery --summary all`
still passed 23/23. The original aggregate cwd defect can therefore return
without failing the permanent suite.

Required narrow correction:

1. Add a public behavioral fixture that invokes the real aggregate command,
   including `zig build test --build-file services/api/build.zig`, and reaches
   the emitted API migration-root sentinel through `addSequentialGate`.
2. Prove the fixture fails when aggregate command consumption uses the service
   cwd without the canonical build-file arguments, then passes with the current
   repository-root descriptor consumption.
3. Keep the existing direct `test-http` and `run` checks if useful, but do not
   treat them or a helper-literal assertion as aggregate coverage.
4. Preserve the current product wiring, emitted executable mapping, run
   argument forwarding, exact materializer, least-authority module graph,
   source-root fixture portability, and fail-closed diagnostics.

## Verified correction behavior

- Chronology — PASS. `f98ecfc` and `53111be` are test-only commits before
  production commit `76dddae`; `ac3d45c` then makes fixture source discovery
  invocation-independent without changing the aggregate product correction.
- Current discovery — PASS from both supported invocation locations. Service-
  root `zig build test-build-discovery --summary all` and repository-root
  `zig build test-build-discovery --build-file services/api/build.zig --summary
  all` each pass 23/23.
- Product aggregate wiring — PASS by inspection. `addSequentialGate` consumes
  `aggregateInvocation`, sets the child cwd to repository root, pins
  `--build-file services/api/build.zig`, and preserves deterministic dependency
  chaining.
- Direct run cwd — PASS. `configureHttp` uses one repository-root lazy path for
  both contract materialization and `run.setCwd`, while retaining `b.args`.
- Emitted path — PASS. `http_test_config.api_executable_path` remains sourced
  from `executable.getEmittedBin()`; no guessed or duplicated output path was
  introduced.
- Authority graph — PASS. Production `http` retains only `shared` plus the
  exact read-only route-inventory mapping; `composition` retains `shared`,
  `persistence`, `migrations`, and `http`.
- Scope and formatting — PASS. The four correction commits modify only WP04-
  owned `services/api/build.zig` and its discovery test; `git diff --check`
  passes.
- Permanent aggregate deletion sensitivity — **FAIL**. Reverting only the real
  aggregate descriptor consumption leaves the complete 23/23 suite green.

## Anti-pattern checklist

1. Dead code — PASS. The descriptor is currently consumed by the production
   aggregate step builder.
2. Synthetic-fixture test — **FAIL** for the cycle-21 aggregate behavior. The
   descriptor assertion checks a returned value, while the behavioral fixture
   bypasses the aggregate production caller.
3. Silent empty return — N/A.
4. FR coverage — **FAIL** for FR-015's aggregate independently runnable build
   boundary; direct HTTP/run coverage does not exercise the aggregate entry.
5. Frozen surface — PASS. Only WP04-owned build/discovery files changed.
6. Locked decision — PASS. The product change preserves the exact canonical
   path, module boundaries, and fail-closed behavior.
7. Shared-file ownership — PASS. `services/api/build.zig` remains WP04's
   authoritative graph and the correction is explicitly coordinated for WP08.
8. Production fragility — N/A; no production exception or fallback path was
   added.

## Verdict

Return WP04 to `planned` for one permanent behavioral aggregate regression.
Do not redesign or revert the current cwd correction: make the public fixture
drive the real aggregate consumer so deletion of the three descriptor-
consumption lines reproduces cycle 21 and fails the suite.
