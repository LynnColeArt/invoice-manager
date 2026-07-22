---
affected_files:
  - services/api/build.zig
  - services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 1
correction_commits:
  - be9af8d3fef1a6146505a973fc7524f168d37be3
  - 1a453e5c25588442bf075d8abbb8d5728821191d
  - 1d97a2aea78e44b80a535a771a6cb7a089ee4934
cycle_number: 17
implementation_commit: 1d97a2aea78e44b80a535a771a6cb7a089ee4934
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T11:07:53Z'
reviewed_lane_tip: 1b12e2882a4959c192d09b6fcf4b4b7e880bcf60
reviewer_agent: codex-wp04-cycle16-reviewer
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 17 — REJECTED

Cycle 16's consumer correction has a real test-first RED and correctly exposes
the production HTTP module, composition root, and emitted API executable to
HTTP tests. The graph is acyclic, contract materialization precedes affected
compiles, and the existing adapter, ABI, discovery, and coverage ownership
surfaces remain green. One least-authority graph violation blocks approval.

## Blocking finding

### B1 — The production `http` module is granted persistence and migration capabilities

`services/api/build.zig:1401-1410` constructs the named production `http`
module with `shared`, `persistence`, and `migrations`. This contradicts WP08's
locked boundary: `src/http/**` must remain independent of WP06/WP07 internals,
and only `src/main.zig` may call those public seams. A named import is a module
capability; granting it is an architectural dependency even if a particular
source revision does not currently exercise it.

The permanent discovery fixture codifies the same violation at
`services/api/tests/persistence/shovelerdb_build_discovery.zig:182-195`: its
synthetic `src/http/root.zig` imports and touches persistence and migrations,
while its composition root imports only `http`. The test therefore proves the
inverse of the required least-authority boundary and would allow a future HTTP
module to bypass the startup/readiness composition root.

Required narrow correction:

1. Give the named production `http` module only `shared`.
2. Keep `composition` rooted at `src/main.zig` with `shared`, `persistence`,
   `migrations`, and `http`.
3. HTTP test roots may retain all public dependency modules plus `http`,
   `composition`, and `http_test_config`.
4. Change the positive fixture so synthetic HTTP imports only `shared`, while
   synthetic composition directly imports/touches persistence, migrations,
   and HTTP.
5. Before the product correction, commit a public build-discovery negative
   case which attempts to import persistence or migrations from the named
   `http` module and observes that the current graph incorrectly permits it.
   Record the real RED, then remove those imports and record GREEN.
6. Preserve the already-correct emitted executable option, materializer
   dependencies, run forwarding, and fail-closed producer behavior.

## Verified correction behavior

- Test-first chronology: PASS. At pre-product commit `1a453e5`, a clean archive
  replay of `zig build test-build-discovery --summary all` fails exactly 18/19
  because the isolated HTTP root has no named `http` module. Product commit
  `1d97a2a` follows both test commits.
- Current discovery: PASS, 19/19.
- Cold source-only archive at `1d97a2a`: PASS, 19/19 with no pre-existing
  `.zig-cache` or `zig-out`.
- Named graph: acyclic. `composition` imports `http`; `http` does not import
  `composition`. The least-authority contents of `http_imports` are the sole
  graph blocker.
- Emitted executable: PASS. `addOptionPath("api_executable_path",
  executable.getEmittedBin())` uses Zig 0.16's dependency-adding API; the
  fixture resolves the basename and executes that emitted API successfully.
- Materialization ordering: PASS. Both the API compile and every HTTP test
  compile depend on the exact repository-root materializer; the delayed
  materialization fixture passes.
- HTTP consumer execution: PASS. HTTP tests can `refAllDecls` the named HTTP
  and composition modules and spawn the emitted real fixture API.
- Run behavior: PASS. `run.addArgs(b.args)` remains intact and unchanged from
  the previously accepted run-forwarding correction. Fresh absent-producer
  `test-http` and `run -- forwarded-token` both fail nonzero with stable owning-
  WP diagnostics.
- Zig formatting and diff checks: PASS.
- Base Zig build and stable 17-step help inventory: PASS.
- Adapter: PASS, 4/4 Debug and 4/4 ReleaseSafe.
- Real ABI integration: PASS, 5/5 Debug and 5/5 ReleaseSafe.
- Coverage/discovery ownership regression: PASS. Correction commits alter
  only HTTP graph construction and its permanent discovery fixture; fresh
  discovery retains all 19 adversarial cases, and the adapter's `fuzz=false`
  isolation/ownership runner is unchanged.

## Anti-pattern checklist

1. Dead code — PASS. The new named modules are imported by the executable or
   test roots, and the emitted executable is run.
2. Synthetic-fixture test — PASS for the cycle-16 consumer defect. The fixture
   compiles the production build graph and executes its emitted artifact.
3. Silent empty return — N/A.
4. FR coverage — PASS for FR-015 consumer/executable reachability.
5. Frozen surface — PASS. Only WP04-owned build/discovery files changed.
6. Locked decision — **FAIL**. Persistence/migrations are exposed directly to
   the production HTTP module despite WP08's composition-root-only rule.
7. Shared-file ownership — PASS. `services/api/build.zig` remains WP04's
   authoritative surface, and the correction is explicitly coordinated for
   WP08 consumption.
8. Production fragility — N/A; no production exception/raise path was added.

## Verdict

Return WP04 to `planned` for the single least-authority graph correction. Do
not change the adapter, ABI, executable-path option, materialization ordering,
test-root public imports, run wiring, or coverage machinery.
