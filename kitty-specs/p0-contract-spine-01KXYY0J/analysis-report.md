---
schema_version: 1
artifact_type: spec-kitty.analysis-report
command: /spec-kitty.analyze
mission_slug: p0-contract-spine-01KXYY0J
mission_id: 01KXYY0J76QBNSWXX0SHMZNXC4
generated_at: '2026-07-21T00:47:00.874390+00:00'
analyzer_agent: codex
input_artifacts:
  spec.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/spec.md
    sha256: cbf96c32d255558dd1464b73a21ad4d101c171f0e3af45823b85823dfbf87420
  plan.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/plan.md
    sha256: 6657c06b221b6df52a8ef3eae0121069e15fbadc44b7df060630e1cfecb11e87
  tasks.md:
    path: /home/lynn/projects/invoice-manager/kitty-specs/p0-contract-spine-01KXYY0J/tasks.md
    sha256: ddea351d2076cb75e47146fa2b735626bf36273d4c8537d83703d1f481eba67b
  charter:
    path: /home/lynn/projects/invoice-manager/.kittify/charter/charter.md
    sha256: a1176517b273e322d3dc408e369ef836c40e3bb84c69ae140ad554cffbb53f0f
verdict: blocked
issue_counts:
  medium: 1
  high: 3
  low: 0
  critical: 1
  info: 0
findings:
- id: C1
  severity: critical
  category: charter-alignment
  summary: WP04's shared and persistence coverage hooks execute ordinary tests without measuring coverage or enforcing critical branches.
- id: H1
  severity: high
  category: coverage-integrity
  summary: The migration declaration-analysis contract does not require `migrations` to be bound to the instrumented module.
- id: H2
  severity: high
  category: boundary-integrity
  summary: Migration coverage import isolation is weaker in build.zig than the amended WP07 contract.
- id: H3
  severity: high
  category: dependency
  summary: WP05 and WP06 require aggregate gates that deliberately fail before downstream producers exist.
- id: M1
  severity: medium
  category: traceability
  summary: WP04 and IC-05 omit the requirements implemented by their validation-gate ownership, while IC-04 omits NFR-006.
---

## Specification Analysis Report

**Verdict: BLOCKED.** The corrected migration mechanism is materially stronger and demonstrates real measured coverage, but WP04 is not ready for approval because its other two coverage hooks cannot satisfy the charter or NFR-006. Two migration-contract bypasses and an intermediate-WP gate deadlock also require correction.

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|---|---|---|---|---|---|
| C1 | Charter alignment | CRITICAL | charter:9,13; spec.md:191; plan.md:341-359,448-449; WP05:332-347,394; WP06:354-372,439; build.zig:459-486,489-525,353-354 | `coverage-shared` only depends on `test-shared`. `coverage-persistence` only depends on the three ordinary persistence test groups. Neither instruments production code, measures a denominator, applies a 90% threshold, or verifies critical branches. The aggregate `coverage` step therefore has only one genuinely measured member: `coverage-migration`. This directly conflicts with the charter MUST and NFR-006. | Before WP04 approval, add source-scoped measured PC coverage for shared and persistence code, a nonzero/minimum denominator, >=90% enforcement, explicit critical-branch inventories, production-side probes, dedicated coverage roots, and adversarial low/missing-branch tests. Keep harnesses, probes, tests, ShovelerDB adapter, migrations, and cross-domain dependencies outside each measured denominator. Aggregate `coverage` must propagate all three measured results. Amend WP05/WP06 prompts with the executable contracts. |
| H1 | Coverage integrity | HIGH | WP07:370-377; build.zig:767-786 | WP07 requires the canonical `const migrations = @import("migrations");` binding and `std.testing.refAllDecls(migrations)`. The validator checks only that `@import("migrations")` occurs somewhere and that `refAllDecls(migrations)` occurs. A root can bind the real module to another name, bind `migrations` to an empty struct, and satisfy the textual checks while uncalled public declarations remain outside the denominator. | Require exactly one canonical `const migrations = @import("migrations");` declaration and exactly the canonical declaration-analysis test. Reject alternate/duplicate migration bindings. Add an adversarial fixture using `const real = @import("migrations"); const migrations = struct {};` and require failure. Prefer token/AST validation over unrelated substring matching. |
| H2 | Boundary integrity | HIGH | WP07:371; build.zig:629-640,745-764,767-786 | WP07 says the dedicated root may import only `migrations` and must consume shared/persistence solely through production's named imports. The build nevertheless exposes `shovelerdb_adapter`, `shared`, `persistence`, and `migration_coverage_contract` directly to the coverage root, and its validator does not reject those imports. Production import validation also accepts every string beginning with `migrations` and ending in `.zig` without path normalization, syntactically admitting traversal-shaped imports such as `migrations_helpers/../store.zig`. This weakens the "only migrations*.zig is instrumented" denominator guarantee. | Expose only `migrations` to the coverage root. Validate its imports as exactly `std` plus the canonical named migration module. Normalize every production relative import, reject absolute paths, separators/backtracking that escape the migration namespace, and verify the resolved file belongs to the scanned `migrations*.zig` set. Add adversarial direct shared/persistence/adapter imports and traversal-shaped imports. |
| H3 | Dependency sequencing | HIGH | plan.md:341-359,683-699; WP05:349-365,395; WP06:358-377,439; build.zig:432-447,459-565 | WP04 intentionally makes absent producer gates fail closed. WP05 nevertheless requires aggregate `zig build test`, which must fail while WP06/WP07/WP08 are absent. WP06 requires aggregate `zig build coverage`, which must fail while downstream WP07 is absent, and recommends aggregate `test`, which also awaits WP07/WP08. Since WP07 depends on approved WP05 and WP06, these commands create impossible intermediate acceptance conditions. | WP05 should require `test-shared` and measured `coverage-shared`; WP06 should require its three focused test groups and measured `coverage-persistence`. Reserve migration-inclusive aggregate coverage for WP07 or later, and full aggregate service tests for WP08/WP12 after every producer exists. Remove aggregate success from WP05/WP06 DoD while retaining focused regression gates. |
| M1 | Traceability | MEDIUM | tasks.md:54-59,92-99; plan.md:559-582; WP04:6-15 | WP04/IC-05 own and implement the service validation and coverage surface but omit FR-015 and NFR-006 from their requirement references. IC-04 likewise omits NFR-006 even though WP07 correctly includes it. The missing ownership trace helps conceal C1. | Add FR-015 and NFR-006 to WP04/IC-05 traceability, and NFR-006 to IC-04. Preserve WP05/WP06/WP07 as producer-level NFR-006 owners while identifying WP04 as the exclusive enforcement-infrastructure owner. |

## Coverage Summary

| Requirement | Has Task? | Work Packages | Assessment |
|---|---:|---|---|
| FR-015 — Independent validation gates | Nominally | WP01, WP03, WP08, WP10, WP11, WP12 | Actual Zig gate infrastructure belongs to WP04 but is not traced there. Focused names exist, but H3 makes intermediate acceptance inconsistent. |
| NFR-006 — >=90% plus every critical branch | Nominally | WP02, WP05, WP06, WP07 | Migration has a measured mechanism, subject to H1/H2. Shared and persistence have no measured enforcement, so substantive coverage is incomplete. |
| C-007 — Additive ownership | Yes | WP03, WP10, WP11, WP12 and ownership contracts | WP04 remains sole `build.zig` owner; WP07 remains consumer-only. No file-pattern overlap was found. |
| Remaining FR/NFR/C requirements | Yes | WP01–WP12 | No new focused inconsistency found in this pass. |

## Migration Gate Assessment

The cycle-two mechanism has several sound properties:

- Only the migration module is configured with Zig instrumentation; the runner, root, probe, contract, shared module, and persistence module are uninstrumented.
- The runner resets counters and probe bits per test and rejects leaks, logged errors, critical skips, duplicate/unknown names, missing probes, and zero production-PC deltas.
- Aggregate coverage is computed from live sanitizer counters and enforces a nonzero denominator, a minimum of 36 production sites, >=90% execution, and all 36 branch bits.
- The amended WP07 prompt now names all 36 tags, the dedicated root, production probe convention, per-test PC requirement, named-module boundaries, and Zig 0.16 `refAllDecls` call.
- Existing adversarial evidence demonstrates missing measurement, low coverage, missing critical execution, fabricated names, and ordinary relative `store.zig` imports fail.

H1 and H2 are nevertheless structural holes in the static contract and should be closed before WP07 relies on it.

## Dependency and Ownership Review

- The core DAG is correct: WP07 depends on WP03, WP04, WP05, and WP06.
- Coverage helper files named `shovelerdb_coverage_*` remain inside WP04's `shovelerdb*` ownership. WP07's production and dedicated coverage files remain inside its `migrations*` ownership.
- WP04 is the only package authorized to repair all three coverage hooks.
- WP05 and WP06 may still be implemented concurrently after WP04, but their current acceptance commands must first be corrected as described in H3.
- WP07 should remain blocked until WP05/WP06 are approved and the WP04 gate contract is complete.

## Charter Alignment

C1 violates the charter's explicit requirement that the Zig domain layer maintain at least 90% coverage and cover every critical invariant/error branch. Because the named shared and persistence "coverage" gates currently provide only test execution, this is a charter MUST conflict and therefore critical.

No charter exception is documented or appropriate.

## Unmapped Tasks

No task ID is wholly unmapped. T001–T057 remain contiguous and all 38 requirements/constraints have nominal WP references. M1 concerns missing enforcement-owner traceability, not a zero-task requirement.

## Metrics

- Total requirements and constraints: 38
- Total tasks: 57
- Nominal requirement mapping: 100%
- Substantively satisfied focused requirements: FR-015 partial; NFR-006 blocked
- Critical findings: 1
- High findings: 3
- Medium findings: 1
- Ambiguity findings: 0
- Duplication findings: 0

## Input Artifact Hashes

Planning checkout HEAD: `fef1a503f032e60929f187350931a09e1b42569c`

| Artifact | SHA-256 |
|---|---|
| `.kittify/charter/charter.md` | `a1176517b273e322d3dc408e369ef836c40e3bb84c69ae140ad554cffbb53f0f` |
| `spec.md` | `cbf96c32d255558dd1464b73a21ad4d101c171f0e3af45823b85823dfbf87420` |
| `plan.md` | `6657c06b221b6df52a8ef3eae0121069e15fbadc44b7df060630e1cfecb11e87` |
| `tasks.md` | `19b1881fa8f9c5917438215691f9885951e257256840d95512cce78c4e9984d2` |
| `WP04` | `2bbedf67707fbef3d98b74a6057d0c9d18c4d5e4e54b0dffded0735799e446d0` |
| `WP05` | `35c4bf4ba952d26c0430349d6dff7179c95daa3fdb6011834c6470a1e74c3eab` |
| `WP06` | `cc315a532bf754a443fee31dd380400678602b4561c2f3fcb995f54400d3a9e3` |
| `WP07` | `86c898c63e126f49d9b8d6222ae8665095a0b3d8d6293d932497792134f00d75` |

Implementation checkout HEAD: `b9dfb78299c7008e4c7a67b53ef4640cf15b606f`

| Artifact | SHA-256 |
|---|---|
| `services/api/build.zig` | `8fdf91c1c0896200a5790788b0db90a1223c38ae2c7eed9267aa01a72c5888f9` |
| `shovelerdb_coverage_contract.zig` | `f248b7bc3df5181e49e64f2f4c339e44a7f85291b0881a34f40513be8b9086cd` |
| `shovelerdb_coverage_probe.zig` | `ae3b4d3b37128325b08345232a645cc263df58654b762707b3457a027d2d4588` |
| `shovelerdb_coverage_runner.zig` | `d1eb2dd96fcf33c971af08c7b255f8b797e965015167c6aa363529f2a185d6b7` |
| `shovelerdb_build_discovery.zig` | `eca07647fdcf6ffbfd73ba0b44f9214fb62b0695fc82a6084e95a929cde3c4e8` |

## Next Actions

1. Reject or hold WP04 cycle two on C1, H1, and H2.
2. Correct all three measured coverage hooks and their adversarial contracts under WP04 ownership.
3. Amend WP05/WP06 focused command/DoD sequencing and the missing traceability references.
4. Re-run independent WP04 review.
5. Re-run and record cross-artifact analysis before dispatching WP05/WP06.

No files or Spec Kitty state were modified during this analysis.
