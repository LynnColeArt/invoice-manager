---
affected_files:
  - path: services/api/build.zig
  - path: services/api/src/platform/persistence/shovelerdb_coverage_contract.zig
  - path: services/api/src/platform/persistence/shovelerdb_coverage_runner.zig
blocking_findings: 2
cycle_number: 2
implementation_commit: 9bd5806c09ae639e03315fd0ee2272bf92d49756
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T00:41:27Z'
reviewed_lane_tip: b9dfb780382a7e8bdbbcb0a5bfae55698259b7af
reviewer_agent: codex
verdict: rejected
wp_id: WP04
review_artifact_override_at: "2026-07-21T02:06:18Z"
review_artifact_override_actor: "operator"
review_artifact_override_wp_id: "WP04"
review_artifact_override_reason: "Arbiter override: review-cycle-3.md at coordination commit 28ca0f7 independently verifies that implementation 1dbfd1a closes every cycle-2 blocker. Exact shared/persistence/migration PC and critical-probe gates plus structural, runner, ABI, provenance, clean-copy, tamper, and pinned npm adversarial checks pass with zero blocking findings."
---

# WP04 Review Cycle 2

Verdict: **REJECT**

The corrected migration gate now uses live Zig 0.16 PC counters, rejects low
coverage and missing critical branches, and propagates failures through the
aggregate gate. Two acceptance-critical coverage gaps remain.

## Blocking findings

### 1. `coverage-shared` and `coverage-persistence` are ordinary test aliases

`configureShared` makes `coverage-shared` depend only on `test-shared`.
`configurePersistence` makes `coverage-persistence` depend only on its ordinary
unit, integration, and crash tests. Neither hook instruments or even requires
its owned production modules, measures production coverage, enforces the
mission-wide 90% threshold, or verifies enumerated critical error branches.

This contradicts spec NFR-006, the plan's 90% shared/durability requirement,
WP05's mandatory `coverage-shared` report and critical-branch gate, and WP06's
required persistence coverage through the immutable WP04 build surface.

Independent reproduction used a complete synthetic producer matrix, replaced
`src/shared/root.zig` with a top-level `@compileError` sentinel, and added
`src/platform/persistence/store.zig` with another top-level `@compileError`
sentinel. `zig build coverage-shared --summary all` still succeeded (4/4 build
steps, 1/1 ordinary test), and `zig build coverage-persistence --summary all`
still succeeded (12/12 build steps, 3/3 ordinary tests). The production sources
were not compiled, so both hooks can report green with zero production evidence.

Required correction:

- make both stable hooks compile and instrument their owned production modules;
- produce reproducible measured coverage and reject less than 90%;
- require every documented shared/durability critical error branch regardless
  of aggregate percentage;
- fail on missing source, missing measurement, missing dedicated evidence, or
  fabricated/empty evidence; and
- prove the aggregate `coverage` step propagates low shared and low persistence
  failures, not only migration failures.

### 2. Commented declaration analysis can erase uncovered migration sites

`coverageTestContractValid` accepts
`std.testing.refAllDecls(migrations);` by raw substring search. A comment
satisfies that check even though Zig performs no declaration analysis.

Independent reproduction began with the low-coverage fixture containing 33
uncovered production PCs (normally measured as 73/106 and rejected). Replacing
the executable `refAllDecls` call with the same text in a comment made
`coverage-migration` incorrectly succeed at 73/73 with all 36 critical probes.
The uncovered declaration disappeared from the denominator.

Required correction:

- make declaration analysis structurally executable rather than a raw textual
  sentinel (for example, from a WP04-controlled wrapper or parsed Zig syntax);
- add a negative fixture where the required text exists only in a comment and
  an unreferenced migration declaration contains uncovered control flow; and
- require that fixture to retain the production sites in the denominator and
  fail below 90%.

## Verified passing evidence

- Zig 0.16 valid migration producer: 73/73 live production PCs, 36/36 exact
  critical branch tests, 37 tests passed, zero skipped.
- Low 73/106, wrong critical probe, zero per-test production delta, unknown
  label, missing source, missing dedicated root, renamed root, forbidden
  relative import, impossible measurement values, critical skip, logged error,
  allocator leak, and ordinary test failure all returned nonzero.
- Aggregate `coverage` propagated migration `BelowThreshold` after the shared
  and persistence commands succeeded.
- Formatting passed; discovery passed 10/10, adapter passed 4/4, and real ABI
  integration passed 3/3 in Debug and ReleaseSafe.
- A fresh public fetch resolved commit
  `021e3b3d9247a181252329d6ba7ec8d2ed943a97`; vendored LICENSE/include/src were
  byte-identical. Source digest
  `6bb2b4215aa50a8ffbbff3278aea4f32c4fc0f906da817037c44095cfd19480b`,
  license digest `240a15a1d0f34d3abca462cdb7e5fb89470967563f16b0e71169e51c1e74cf2b`,
  and header digest `177535ee08de90ee3f68f708046f19815e283f1072102afb594f6697708f676a`
  matched the pin.
- Exact Node 24.18.0/npm 11.16.0 offline install and substrate verification
  passed; full and production audits reported zero vulnerabilities.
- Mission `contracts/` artifacts remain orthogonal to WP04: no wire payload,
  schema, command, or closed allowed-value set changed.

## Anti-pattern checklist

1. Dead code: **PASS** for the adapter; **FAIL** for the coverage hooks because
   shared/persistence production modules are not live inputs.
2. Synthetic-fixture test: **FAIL** for shared/persistence coverage; ordinary
   passing tests can masquerade as coverage without production execution.
3. Silent empty return: **PASS**.
4. FR coverage: **PASS** for WP04's ShovelerDB requirements; downstream NFR-006
   coverage consumption is blocked as described above.
5. Frozen surface: **PASS**.
6. Locked decision: **FAIL** for the required non-vacuous 90% shared/durability
   coverage surface.
7. Shared-file ownership: **PASS**; correction changes remain in WP04-owned
   paths.
8. Production fragility: **PASS**; fail-loud build assertions are appropriate
   for build-gate violations.
