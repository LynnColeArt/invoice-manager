---
affected_files:
  - path: services/api/src/platform/persistence/shovelerdb_coverage_runner_core.zig
  - path: services/api/src/platform/persistence/shovelerdb_persistence_coverage_runner.zig
  - path: services/api/src/platform/persistence/shovelerdb_shared_coverage_runner.zig
  - path: services/api/src/platform/persistence/shovelerdb_coverage_runner.zig
blocking_findings: 1
cycle_number: 7
implementation_commit: 0ebca6980952af20c19ff09ace42731b7b6359f9
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command: 'remove only createAdapterModule .fuzz=false in an isolated lane-f archive; run zig build coverage-persistence --summary all'
reviewed_at: '2026-07-21T03:15:23Z'
reviewed_lane_tip: c2eaeff
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 7

Verdict: **REJECT**

Correction reviewed: `0ebca6980952af20c19ff09ace42731b7b6359f9`.

The cycle-six sanitizer-PC isolation defect is corrected. The committed binary
contains only WP06-owned persistence PCs, and the new runtime ownership guard
rejects deliberate adapter contamination before evaluating a ratio. One
acceptance-critical diagnostic defect remains in that rejection path.

## Blocking finding: ownership errors disclose absolute checkout paths

`validatePcOwnership` prints `location.file_name` and the raw PC address:

```text
[coverage-persistence:error] sanitizer PC 15/356 at 0x1205520 resolves outside the owned production scope: /tmp/wp04-cycle7-adversarial/services/api/src/platform/persistence/shovelerdb.zig
```

This contradicts T016's explicit diagnostic contract: diagnostics must name
the stable step, expected root/pattern, owning WP, and observed evidence, and
must not print absolute checkout paths. The message identifies the stable step
and observed PC, but it leaks the absolute DWARF path and does not name owning
WP06 or the expected persistence source pattern. The raw address is also
checkout/build-specific rather than stable evidence.

### Required correction

1. Supply each runner configuration with its owning WP and expected source
   pattern: WP05 plus `src/shared/**`; WP06 plus `root.zig`, `store*`,
   `durability*`, `directory_sync*`, and `diagnostic*`; WP07 plus
   `migrations*.zig`.
2. Emit stable, sanitized observed-source evidence only. A basename such as
   `shovelerdb.zig` is sufficient. Do not emit an absolute path or raw PC
   address.
3. Preserve `OutOfScopeCoverageSite` and the fail-before-ratio order. In an
   isolated real lane-f producer, removing only adapter `.fuzz = false` must
   still fail after prerequisites but before any `observed` or `measured`
   percentage line.
4. Assert the adversarial diagnostic contains the stable step, expected
   pattern, owning WP, and sanitized observed basename, and contains neither
   the temporary checkout prefix nor an address.
5. Preserve the accepted binary proof: the committed lane-f denominator must
   remain 205/205 WP06-owned sites, zero adapter/other sites, with measured
   185/205 and all 20/20 critical probes.

## Accepted cycle-six correction evidence

- Live lane-f `coverage-persistence` passed 42/42 tests and measured 185/205
  owned production sites (90.24%) with 20/20 critical probes.
- The complete `__sancov_pcs1` section has exactly 205 entries. Independent
  `addr2line` resolution mapped all of them to WP06-owned files: `store.zig`
  140, `durability.zig` 38, `directory_sync.zig` 17, `root.zig` 9, and
  `diagnostics.zig` 1. Adapter count is 0; other count is 0.
- In a clean isolated lane-f archive, removing only adapter `.fuzz = false`
  preserved all 42/42 prerequisite tests, then failed at PC 15/356 with
  `OutOfScopeCoverageSite` before printing a ratio. Restoring the committed
  build returned 185/205 and 20/20.
- Lane-f contains no `src/shared/**`; unit passed 39/39, real integration 1/1,
  crash 2/2, and focused coverage passed. The dependency-clean seam remains
  correct.
- A fresh three-domain fixture passed deterministic aggregate coverage:
  shared 24/24 sites plus 24/24 probes, persistence 20/20 plus 20/20, and
  migration 73/73 plus 36/36.

## Regression, provenance, and ownership evidence

- Zig `0.16.0` format/build passed; all 16 stable step names are present;
  discovery passed 17/17.
- Adapter tests passed 4/4. Real ABI integration passed 3/3 in Debug and 3/3
  in ReleaseSafe from a fresh source-only archive.
- Public `refs/heads/main` resolves exactly
  `021e3b3d9247a181252329d6ba7ec8d2ed943a97`. A fresh detached fetch matched
  the vendored `LICENSE`, header, and C ABI source byte-for-byte. Both public
  and vendored deterministic source digests are
  `6bb2b4215aa50a8ffbbff3278aea4f32c4fc0f906da817037c44095cfd19480b`.
- Implementation commit `0ebca69` changes only WP04-owned `build.zig` and
  `shovelerdb_*` runner files. No dependency snapshot, notice, adapter ABI,
  domain record, schema, route, or root package file changed.

## Contract round-trip disposition

- `p0-contract-manifest.json`: **PASS** — every correction path remains inside
  its declared `services/api/build.zig` or
  `services/api/src/platform/persistence/**` ownership surface.
- `README.md`, `api-v1.openapi.yaml`, `common-v1.schema.json`,
  `contract-manifest-v1.schema.json`, `event-catalog-v1.schema.json`,
  `event-envelope-v1.schema.json`, `governed-doc-sync-v1.schema.json`,
  `migration-manifest-v1.schema.json`, and
  `module-contribution-v1.schema.json`: **ORTHOGONAL** — no wire value, schema,
  event, manifest, CLI invocation, or documentation receipt changed.

## Subtask disposition

- T015: **PASS** — exact public provenance remains intact.
- T016: **FAIL** — the new ownership-error diagnostic violates the required
  stable owner/pattern fields and absolute-path prohibition.
- T017: **PASS** — adapter behavior is unchanged and focused tests pass.
- T018: **PASS** — clean-copy real-ABI Debug and ReleaseSafe tests pass.
- T019: **PASS** — notice and full-license evidence remain intact.

## Anti-pattern checklist

1. Dead code: **PASS** — the runtime ownership gate executes in every measured
   domain runner; the live adversarial control proves reachability.
2. Synthetic-fixture test: **PASS** — the real WP06 producer and complete live
   PC table, not only a synthetic fixture, prove the correction.
3. Silent empty return: **PASS** — no silent fallback was introduced.
4. FR coverage: **PASS** — the correction has live positive and adversarial
   evidence through the production coverage entry point.
5. Frozen surface: **PASS** — only WP04-owned build/runner files changed.
6. Locked decision: **FAIL** — the emitted absolute checkout path contradicts
   T016's explicit MUST-NOT diagnostic rule.
7. Shared-file ownership: **PASS** — implementation stays inside WP04-owned
   files; lane-f is used only as the dependency consumer/producer evidence.
8. Production fragility: **N/A** — no application request, worker, CLI, or
   storage-success path changed.
