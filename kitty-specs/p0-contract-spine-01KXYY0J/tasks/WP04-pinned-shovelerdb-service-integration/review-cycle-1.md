---
affected_files:
  - path: services/api/build.zig
  - path: services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 1
cycle_number: 1
implementation_commit: 31408bc8c782458fde6fdab33cd9104d4285178c
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-20T23:54:09Z'
reviewed_lane_tip: c6a98c8fada669e81f5be1a03a9a56562e71a20e
reviewer_agent: codex-wp04-review
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 1

Verdict: **REJECT**

The exact ShovelerDB pin, vendored source, ABI adapter, real integration, and
fail-closed provenance checks pass. One acceptance-critical build-graph gap
remains.

## Blocking finding

### `coverage-migration` does not measure or enforce coverage

`configureMigration` in `services/api/build.zig` makes `coverage-migration`
depend only on the three ordinary migration test steps. It has no coverage
collection, threshold comparison, production-source requirement, or critical-
branch assertion. The aggregate `coverage` step therefore cannot enforce the
WP04/plan requirement of at least 90% migration coverage plus every enumerated
critical branch.

Independent reproduction in a clean temporary checkout created only a
`migrations/p0` sentinel and copied the existing ShovelerDB integration test
under the three expected migration test basenames; no
`src/platform/persistence/migrations.zig` existed. `zig build
coverage-migration --summary all` nevertheless succeeded (12/12 build steps,
9/9 unrelated tests). This is a vacuous coverage pass, not a coverage gate.

Required correction:

- make `coverage-migration` consume reproducible, non-vacuous coverage evidence
  for the owned migration production logic;
- fail when migration production input is absent, measured coverage is below
  90%, or any enumerated critical branch lacks evidence;
- preserve nonzero failures through aggregate `coverage`; and
- add focused RED/GREEN discovery/build tests proving an ordinary passing test
  matrix cannot masquerade as coverage.

## Verified passing evidence

- Fresh public fetch resolved `main` and the required full commit to
  `021e3b3d9247a181252329d6ba7ec8d2ed943a97`.
- Vendored `LICENSE`, `include/**`, and `src/**` are byte-identical to that
  commit; the deterministic tree digest is
  `6bb2b4215aa50a8ffbbff3278aea4f32c4fc0f906da817037c44095cfd19480b`.
- No nested Git metadata, symlink, sibling dependency, private source, upstream
  modification, or out-of-scope implementation path was found.
- Exact Node 24.18.0/npm 11.16.0 offline install and substrate verification
  passed for the canonical 610-entry lock; full and production audits reported
  zero vulnerabilities.
- Zig formatting passed; adapter tests passed 4/4; real ABI integration passed
  3/3 in Debug and ReleaseSafe; discovery tests passed 8/8.
- A fresh isolated source export with independent Zig caches passed build,
  adapter, discovery, and both real-ABI integration modes.
- Changed provenance, source, notice, missing `c_api.zig`, and changed ABI
  header cases all failed before storage use.
- Mission `contracts/` artifacts are orthogonal to WP04: this package changes
  no contract payload, schema, CLI, allowed-value set, or wire example.
