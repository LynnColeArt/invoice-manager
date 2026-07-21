---
affected_files: []
cycle_number: 11
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command:
reviewed_at: '2026-07-21T04:55:48Z'
reviewer_agent: codex
verdict: rejected
wp_id: WP04
---

---
affected_files:
  - path: services/api/src/platform/persistence/shovelerdb_coverage_runner_core.zig
  - path: services/api/src/platform/persistence/shovelerdb_persistence_coverage_runner.zig
  - path: services/api/build.zig
blocking_findings: 1
cycle_number: 10
implementation_commit: 40d6661
mission_slug: p0-contract-spine-01KXYY0J
reproduction_command: gdb direct-origin map of the live persistence-production-coverage sanitizer PC table
reviewed_at: '2026-07-21T04:51:00Z'
reviewer_agent: 'codex:gpt-5:adversarial-preflight'
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 10

Verdict: **REJECT — coverage ownership and denominator are unsound**

The cycle-nine approval correctly accepts the adapter's bound-value and exact
one-statement runtime capabilities. Those capabilities, the public dependency
pin, ABI, provenance, licensing, and sanitized diagnostic work remain accepted.
This rejection is limited to the WP04-owned coverage runner/build boundary.

## Blocking finding: non-owned PCs inflate the reported WP06 denominator

The live WP06 correction artifact reported `352/435` owned production PCs and
passed the current ownership validator. An independent direct-origin map of the
same sanitizer PC table proves that only 363 PCs originate in WP06 production:

| Direct source | Hit / total |
|---|---:|
| WP06 `store.zig` | 183 / 219 |
| WP06 `durability.zig` | 80 / 122 |
| WP06 `directory_sync.zig` | 13 / 16 |
| WP06 `root.zig` | 6 / 6 |
| ShovelerDB adapter | 25 / 27 |
| coverage probe | 6 / 6 |
| coverage test root | 9 / 9 |
| Zig standard library | 28 / 28 |
| unknown | 2 / 2 |

The true direct-owned result is therefore `282/363 = 77.7%`, not
`352/435 = 80.9%`. Seventy of 72 non-owned PCs happened to execute and inflated
both the numerator and denominator.

The sanitizer PC table contains return-address-style PCs. GDB's canonical
source lookup at `pc - 1` produces the table above. The runner instead resolves
the unadjusted `pc` and accepts ownership when its symbol walk reaches an owned
source. At inline/call boundaries this can attribute a dependency or harness PC
to the following/outer WP06 location. The earlier 205/205 ownership proof and
cycle-nine regression inherited this same address-classification error.

## Required correction

1. Resolve each sanitizer PC at its canonical originating instruction (including
   the required one-byte return-address bias) and define a deterministic direct-
   origin rule across supported debug backends.
2. Build an ownership mask from that direct origin. Coverage deltas, aggregate
   hits, and the denominator must consume only owned production PCs. An outer or
   later inline/caller frame must never make a dependency PC owned.
3. Keep the gate fail-closed for missing or ambiguous debug ownership. If Zig
   necessarily emits non-owned generic/harness PCs in the artifact, exclude them
   from both numerator and denominator and separately enforce the existing
   uninstrumented dependency/root build wiring. Do not silently count them.
4. Preserve privacy: failure diagnostics may name only the stable coverage
   label, owning WP, expected relative pattern, safe basename/category, and typed
   error. Never print an absolute path, PC/address, or source trace.
5. Add a chronological RED test/artifact proving that adapter, probe, test-root,
   standard-library, unknown, and inline/caller PCs cannot inflate a domain's
   ratio. Include an adversarial case whose unadjusted PC appears owned but whose
   `pc - 1` direct origin is out of scope.
6. Re-run the real WP05, WP06, and synthetic WP07 coverage gates. Report direct
   owned hit/total counts, exact critical probes, and a source map that reconciles
   to the denominator. Low coverage and fabricated/instrumented dependency
   fixtures must remain unable to pass.
7. Keep the accepted runtime adapter operations, pin, digests, ABI, notices, and
   licensing byte-unchanged except where an explicit instrumentation boundary is
   required and independently regression-tested.

## Reproduction

The direct-source denominator was reproduced read-only against the cached live
artifact by breaking after aggregation, reading the sanitizer PC table, and
classifying each entry with `gdb.find_pc_line(pc - 1)`. The resulting totals are
435 overall, 363 direct WP06 production, and 72 non-owned, exactly reconciling
the table above.

WP06 must not receive final coverage approval until this runner correction is
accepted and its coverage is remeasured with the corrected ownership mask.
