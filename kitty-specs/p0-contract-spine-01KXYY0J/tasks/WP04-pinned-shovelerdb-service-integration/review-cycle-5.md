---
affected_files:
  - path: services/api/build.zig
  - path: services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 1
cycle_number: 5
implementation_commit: 44d61117251d8aefa1c6492dd5cd67b1bf101668
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command: 'zig build coverage-persistence --summary all; break shovelerdb_coverage_runner_core.zig:77 and map the live pcs table with addr2line'
reviewed_at: '2026-07-21T02:49:41Z'
reviewed_lane_tip: f96df7a6387c3f4507bd0a3b438cf369b2602c59
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 5

Verdict: **REJECT**

Correction reviewed: `44d61117251d8aefa1c6492dd5cd67b1bf101668`.

The cycle-four dependency-clean persistence seam is corrected, but live
sanitizer-PC mapping found one acceptance-critical defect in the persistence
coverage boundary.

## Blocking finding: adapter PCs contaminate the persistence denominator

`coverage-persistence` must measure only WP06-owned persistence production and
must keep the WP04 ShovelerDB adapter, runner, probes, contracts, tests, and
other dependencies uninstrumented. The current build does not satisfy that
contract.

Independent reproduction used lane-f's current dependency-clean WP06 producer:

- `src/shared/**` is absent.
- Focused unit passed 36/36, real integration passed 1/1 and then passed 20
  consecutive cycles, and crash passed 2/2. This confirms the missing-shared
  compile blocker is closed.
- `coverage-persistence` ran all 39 ordinary tests, then reported 237/364
  production PCs and all 20/20 critical probes before correctly rejecting the
  below-threshold result.
- At `shovelerdb_coverage_runner_core.zig:77`, the live aggregate and `pcs`
  table contained exactly 364 entries. Pairing every PC with the aggregate byte
  and resolving every address through the artifact's own DWARF data showed:
  - 151/364 denominator PCs map directly to
    `src/platform/persistence/shovelerdb.zig`;
  - 213/364 map to WP06-owned `root.zig`, `store.zig`, `durability.zig`,
    `directory_sync.zig`, or `diagnostics.zig`;
  - 80/127 missed PCs map directly to the adapter, including `copyRows`,
    `copyValue`, `Adapter.open`, `executeOwned`, `copyRow`,
    `encodeTextLiteral`, checkpoint, transaction helpers, and result-copying
    paths.
- These are adapter-function DWARF locations, not WP06 call-site attribution.

The static cause is consistent with the executable evidence:
`createAdapterModule` constructs `shovelerdb.zig` without `.fuzz = false`, while
the probe modules and coverage root explicitly disable fuzz instrumentation.
The adapter therefore contributes sanitizer PCs to the denominator despite
being an out-of-scope dependency.

This violates T016 steps 26 and 28: the persistence gate does not measure only
the scope's owned production PCs, and its adapter dependency is not actually
uninstrumented. It also makes the 90% result depend on WP04 adapter branches
rather than solely on WP06 persistence behavior.

### Required correction

1. Ensure the ShovelerDB adapter contributes **zero sanitizer PCs** to the
   persistence coverage denominator, including when imported into the
   instrumented persistence module. An explicit `.fuzz = false` on the adapter
   module is the evident missing build declaration, but acceptance is based on
   the resulting binary rather than that line alone.
2. Add an executable regression that uses a realistic persistence producer and
   proves the complete live PC table resolves only to WP06-owned production
   files (`root`, `store*`, `durability*`, `directory_sync*`, and
   `diagnostic*`). Merely checking build-graph syntax is insufficient.
3. Re-run the current dependency-clean WP06 unit/integration/crash/coverage
   surface. The coverage denominator and 90% verdict must reflect only WP06
   production while preserving all 20 exact critical probes.
4. Preserve the now-correct optional shared seam, WP07 shared wiring, and the
   accepted shared/migration measurement boundaries.

## Cycle-four seam closure evidence

- Focused `configurePersistence` passes `null` for shared in ordinary and
  instrumented modules. Neither its tests nor WP06 production requires
  `src/shared/**`.
- Named `@import("shared")` and relative
  `@import("../../shared/root.zig")` persistence sources both fail closed at
  `coverage-persistence` with the scoped-import diagnostic.
- The WP07 path still constructs the shared module, passes it to persistence,
  and passes both shared and persistence into migrations. An adversarial
  synthetic producer that makes persistence expose a shared-owned type passed
  `test-migration` and measured migration coverage at 73/74 PCs with all 36/36
  probes, proving the optional wiring remains live.
- Discovery passed 17/17. The correction changes only `services/api/build.zig`
  and its WP04-owned discovery test and passes scoped `git diff --check`.

## Regression evidence

- Zig `0.16.0` format/build passed; all 16 stable step names remain present.
- Adapter tests passed 4/4. Real ABI integration passed 3/3 in Debug and 3/3
  in ReleaseSafe.
- A fresh source-only archive with no `.git`, symlink, sibling ShovelerDB, or
  private path passed build, discovery 17/17, adapter 4/4, and real ABI 3/3 in
  both optimization modes.
- The independent three-domain fixture remains unchanged: shared measured
  24/24 PCs plus 24/24 probes, synthetic persistence measured 20/20 plus
  20/20, and migration measured 73/73 plus 36/36 in deterministic aggregate
  order. This small synthetic persistence fixture did not expose the adapter
  contamination because it did not exercise adapter paths.
- Public pin `021e3b3d9247a181252329d6ba7ec8d2ed943a97`, LICENSE, header, and ABI source
  remain byte-identical to the detached public checkout. Changed provenance
  and changed vendored source each failed before storage use.
- Exact Node.js `24.18.0` / npm `11.16.0` immutable offline install,
  `verify:substrate`, full dependency tree, full audit, and production audit
  passed with zero vulnerabilities.

## Contract round-trip disposition

- `p0-contract-manifest.json`: **PASS** — the two-file correction remains
  inside WP04's declared build/discovery ownership.
- `README.md`, `api-v1.openapi.yaml`, `common-v1.schema.json`,
  `contract-manifest-v1.schema.json`, `event-catalog-v1.schema.json`,
  `event-envelope-v1.schema.json`, `governed-doc-sync-v1.schema.json`,
  `migration-manifest-v1.schema.json`, and
  `module-contribution-v1.schema.json`: **ORTHOGONAL** — no wire value, schema,
  event, migration manifest, CLI example, or documentation receipt changed.

## Subtask disposition

- T015: **PASS** — exact public provenance remains intact.
- T016: **FAIL** — the persistence coverage artifact includes 151 adapter PCs,
  contradicting the owned-production-only denominator and uninstrumented
  dependency requirements.
- T017: **PASS** — the adapter implementation itself is unchanged and its
  focused tests remain green.
- T018: **PASS** — clean-copy real-ABI Debug and ReleaseSafe evidence remains
  green.
- T019: **PASS** — notice and license evidence remains intact.

## Anti-pattern checklist

1. Dead code: **PASS** — corrected build branches are exercised by focused
   persistence and migration producers.
2. Synthetic-fixture test: **FAIL** — the small 20-PC synthetic persistence
   fixture passes while the realistic producer reveals 151 out-of-scope
   adapter PCs; it does not prove the claimed production-only boundary.
3. Silent empty return: **PASS** — no silent fallback was introduced.
4. FR coverage: **FAIL** — T016's scope-specific executable coverage proof is
   invalid because the denominator includes another component.
5. Frozen surface: **PASS** — only two WP04-owned files changed.
6. Locked decision: **FAIL** — the locked coverage decision requires
   uninstrumented adapter/dependency modules and owned persistence PCs only.
7. Shared-file ownership: **PASS** — the correction is confined to WP04-owned
   build/discovery files; lane-f was used only as a producer for seam evidence.
8. Production fragility: **N/A** — no request, worker, CLI, or runtime error
   path changed.
