---
affected_files:
  - path: services/api/build.zig
  - path: services/api/src/platform/persistence/shovelerdb_coverage_probe.zig
  - path: services/api/src/platform/persistence/shovelerdb_coverage_runner.zig
  - path: services/api/src/platform/persistence/shovelerdb_coverage_runner_core.zig
  - path: services/api/src/platform/persistence/shovelerdb_persistence_coverage_contract.zig
  - path: services/api/src/platform/persistence/shovelerdb_persistence_coverage_probe.zig
  - path: services/api/src/platform/persistence/shovelerdb_persistence_coverage_runner.zig
  - path: services/api/src/platform/persistence/shovelerdb_shared_coverage_contract.zig
  - path: services/api/src/platform/persistence/shovelerdb_shared_coverage_probe.zig
  - path: services/api/src/platform/persistence/shovelerdb_shared_coverage_runner.zig
  - path: services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 0
cycle_number: 3
implementation_commit: 1dbfd1ae6bd7214db6cec86e5dabc2bfa25642fd
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T02:04:20Z'
reviewed_lane_tip: 7e36fcb0712e3feebaad97aaf0af947f3104cfe5
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: approved
wp_id: WP04
---

# WP04 Review Cycle 3

Verdict: **APPROVE**

Correction commit: `1dbfd1ae6bd7214db6cec86e5dabc2bfa25642fd`.

## Prior-blocker closure

1. **Shared and persistence aliases: closed.** Each measured scope now has a
   dedicated contract, probe registry, runner, and coverage module. The build
   instruments only the scope-owned production module; roots, runners, probes,
   contracts, and dependencies are explicitly uninstrumented.
2. **Comment-only declaration bypass: closed.** Discovery validates exact Zig
   AST/token structure: one public module binding per dedicated root and one
   exact top-level `std.testing.refAllDecls(module)` call. Comments, strings,
   alternate names, empty shadows, duplicate bindings, and disabled analysis
   do not satisfy the contract.
3. **Vacuous migration coverage: closed.** Migration now measures 73/73 owned
   production PCs and requires all 36 declared critical probes; shared measures
   24/24 PCs and 24/24 probes; persistence measures 20/20 PCs and 20/20 probes.

## Coverage and structural evidence

- A fresh source-only fixture passed the aggregate in deterministic
  shared -> persistence -> migration order. Shared ran 25 tests, persistence
  ran 21 coverage tests after its ordinary unit/integration/crash prerequisites,
  and migration ran 37 tests. No critical test was skipped.
- Independently enlarged denominators failed closed at shared 24/37,
  persistence 20/33, and migration 73/106 with `BelowThreshold`. Aggregate
  runs propagated the first failing shared or persistence scope.
- Swapping real production probe tags while preserving the static inventories
  failed every scope with `CriticalBranchProbeNotHit`.
- A skipped critical test, a logging test, an allocator leak, a zero-PC critical
  test, and a preload-then-wrong-probe sequence were rejected respectively as
  `CriticalBranchTestSkipped`, `TestLoggedError`, `TestMemoryLeak`,
  `CriticalBranchDidNotExecuteProductionLogic`, and
  `CriticalBranchProbeNotHit`. The preload case proves per-test probe reset.
- Disabling the exact declaration still allowed each ordinary focused gate to
  run, while its coverage gate failed the static declaration contract. The
  discovery suite passed all 16 cases and directly covers comments/strings,
  alternate and duplicate bindings, empty shadows, disabled declarations,
  exact critical inventories, and sanitizer manipulation.
- Extra public modules in all three roots, traversal and prefix-lookalike
  imports, a direct shared-to-persistence import, a fabricated critical label,
  a renamed shared root, and a missing migration source all failed before
  accepting coverage. Scope normalization rejects absolute, backslash,
  traversal, cross-scope, and prefix-confusable paths.

## Integration, provenance, and reproducibility evidence

- Zig `0.16.0` formatting/build, discovery 16/16, adapter tests 4/4, and real
  ShovelerDB ABI integration 3/3 passed in Debug and explicitly in ReleaseSafe.
  The stable build help surface exposes all 16 required steps.
- The adapter uses only `@cImport("shovelerdb.h")`, validates ABI 0.1.0,
  serializes handle access, copies result data into Zig-owned storage, releases
  C results on success/error paths, closes handles idempotently, and constrains
  dynamic SQL to the reviewed text-literal encoder.
- A fresh public checkout at pinned commit
  `021e3b3d9247a181252329d6ba7ec8d2ed943a97` matches the vendored tree digest
  `6bb2b4215aa50a8ffbbff3278aea4f32c4fc0f906da817037c44095cfd19480b`.
  `LICENSE`, the public header, and `src/c_api` are byte-identical; there are no
  nested repositories or symlinks.
- A clean `git archive` copy with no sibling repository or `.git` directory
  passed the build/discovery/adapter/Debug/ReleaseSafe sequence before and
  after deleting Zig caches. No private registry or sibling checkout path is
  referenced.
- Changed provenance, changed vendored C API bytes, a missing C API directory,
  a changed ABI header, and a damaged notice all failed before storage use.
- Under exact Node.js `24.18.0` and npm `11.16.0`, immutable offline install,
  `verify:substrate`, the full dependency tree, full audit, and production audit
  passed; both audit scopes report zero vulnerabilities.
- The correction commit passes `git show --check` and scoped `git diff --check`.
  The accumulated WP04 diff retains one upstream blank line at EOF verbatim;
  changing it would break the independently verified vendored-tree identity.

## Architectural pre-review disposition

The host reported `outcome: no_coverage`, `block_enabled: false`, and
`blocked: false` because consumer repositories do not provide Spec Kitty's own
repo-local `tests.architectural._gate_coverage` module. Source inspection of
the host gate confirms this is a lazy, opt-in Spec Kitty CI-topology hook that
degrades to an advisory warning for consumer repositories. It is therefore
non-applicable here and neither replaces nor invalidates the Zig architectural
and coverage gates reviewed above.

## Contract round-trip disposition

- `p0-contract-manifest.json`: **PASS** — the WP04 dependency, build, adapter,
  integration-test, and coverage paths stay within the declared P0 ownership.
- `README.md`, `api-v1.openapi.yaml`, `common-v1.schema.json`,
  `contract-manifest-v1.schema.json`, `event-catalog-v1.schema.json`,
  `event-envelope-v1.schema.json`, `governed-doc-sync-v1.schema.json`,
  `migration-manifest-v1.schema.json`, and
  `module-contribution-v1.schema.json`: **ORTHOGONAL** — this correction changes
  no payload, closed vocabulary, wire schema, event, migration-manifest shape,
  documentation receipt, or public API value.

## Subtask disposition

- T015: **PASS** — exact public provenance and license bytes are pinned and
  fail-closed.
- T016: **PASS** — the Zig build owns a reproducible vendored ABI artifact and
  stable verification steps.
- T017: **PASS** — the single adapter provides reviewed ownership, locking,
  error, result-copying, and SQL-boundary behavior.
- T018: **PASS** — Debug and ReleaseSafe tests exercise the real original C ABI.
- T019: **PASS** — shared, persistence, and migration gates measure owned
  production PCs and exact critical branches, with adversarial fail-closed
  validation and ordinary focused prerequisites.

## Anti-pattern checklist

1. Dead code: **PASS** — build entrypoints, adapter APIs, and coverage machinery
   are compiled and exercised by the stable verification surface.
2. Synthetic-fixture test: **PASS** — synthetic domain inputs compile the real
   production modules; the real C ABI integration independently exercises
   vendored ShovelerDB. Removing execution or changing probes makes gates fail.
3. Silent empty return: **PASS** — no swallowed error or empty-success fallback
   was found; error paths are explicit and fail loudly.
4. FR coverage: **PASS** — FR-011, FR-012, FR-015 and their reproducibility,
   licensing, ABI, and coverage constraints have executable evidence.
5. Frozen surface: **PASS** — the cycle-three commit changes only WP04-owned
   implementation/test files and no Frozen contract.
6. Locked decision: **PASS** — exact upstream commit, original public C ABI,
   one Zig adapter, vendored-only resolution, and measured domain gates remain
   intact without sibling or fallback integration.
7. Shared-file ownership: **PASS** — WP01 substrate inputs remain distinguishable;
   the correction touches only the WP04-owned build and coverage surface.
8. Production fragility: **PASS** — build assertions intentionally fail before
   runtime; adapter locking and ownership avoid request-time shared-state races.
