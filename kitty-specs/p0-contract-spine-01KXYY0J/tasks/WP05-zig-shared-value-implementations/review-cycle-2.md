---
affected_files:
  - services/api/tests/shared/boundary_fixtures_test.zig
blocking_findings: 1
cycle_number: 2
implementation_commit: 610c72cac06b2058a4074d5fc09ce670f607cf73
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T13:34:00Z'
reviewed_lane_tip: 2ca1b7751008ffc02e91a00a316c5d43d6a7cdf1
reviewer_agent: codex-wp05-cycle2-reviewer
verdict: rejected
wp_id: WP05
---

# WP05 Review Cycle 2 — REJECTED

The EntityId correction at `610c72c` remains behaviorally sound, and the
focused shared suite passes from the service directory. Approval is blocked by
one integrated fixture-path defect at downstream tip `2ca1b77`: the same exact
WP05 suite fails from the canonical repository-root build surface.

## Blocking finding

### B1 — canonical boundary fixtures are coupled to the process working directory

`services/api/tests/shared/boundary_fixtures_test.zig:5`, line 39, and the
reader at line 201 pass `../../contracts/...` directly to
`std.Io.Dir.cwd().readFileAlloc`. Those paths reach the frozen WP02 fixtures
only when the test process inherits `services/api` as its working directory.
They point outside the repository when the exact service build file is invoked
from the repository root.

Fresh Zig 0.16.0 evidence against exact integrated tip `2ca1b77`:

- `cd services/api && zig build test-shared --summary all` — **PASS**,
  15/15 build steps and 41/41 tests.
- `zig build test-shared --build-file services/api/build.zig --summary all`
  from the repository root — **FAIL**, 25/27 tests passed. The only failures
  are `all declared valid boundary fixture cases are visited and accepted` and
  `all declared invalid boundary fixture cases are visited and rejected`; both
  return `error.FileNotFound` from `readFixture` before reaching the frozen
  corpora.

This violates T024 steps 2, 5, and 6: the fixture consumer is not
repository-relative at runtime, and the canonical integrated build cannot
prove that every declared valid and invalid case reaches the production shared
parsers. It also leaves the Definition of Done's fixture and focused-test gates
red on the build surface now consumed by downstream WP08.

Required narrow correction:

1. Change only
   `services/api/tests/shared/boundary_fixtures_test.zig`. Anchor fixture
   discovery to that source file, for example with
   `std.fs.path.dirname(@src().file)` plus the source-relative traversal to
   `contracts/fixtures/p0/v1`. Continue consuming the exact WP02 files in
   place; do not copy payloads or edit WP02 contracts.
2. Preserve WP ownership. Do not repair this by changing WP04's build graph or
   by imposing a hidden process cwd on every shared test.
3. Treat the current repository-root failure as RED, commit the source-anchored
   reader, and prove GREEN through both exact invocation roots:
   `cd services/api && zig build test-shared --summary all`, then repository-
   root `zig build test-shared --build-file services/api/build.zig --summary
   all`. Rerun repository-root aggregate `zig build test --build-file
   services/api/build.zig` to prove downstream composition proceeds past WP05.
4. Perform a deletion replay: restore only the old cwd-relative
   `../../contracts/...` behavior while leaving the permanent fixture tests
   unchanged. The repository-root focused command must reproduce the exact two
   `FileNotFound` failures while the service-root command remains green. Restore
   the source-anchored correction before handoff.

Zig 0.16's observed compile paths support this correction: the repository-root
invocation compiles the root as
`services/api/tests/shared/boundary_fixtures_test.zig`, while the service-root
invocation supplies the absolute source path. A source-directory anchor
therefore resolves the same repository fixture root in both modes without a
build-file crossing.

## Requirement and subtask verdicts

- T020: passed prior correction evidence; malformed canonical-length UUID
  hyphens now return the stable typed syntax error.
- T021: passed; exact signed Money, checked arithmetic, and open structural
  Currency behavior remain covered.
- T022: passed; date, exact UTC millisecond, and digest semantics are unchanged.
- T023: passed; RequestId and JSON/HTTP conversion behavior are unchanged.
- T024: **REJECTED** — the canonical integrated build cannot load either frozen
  boundary corpus, so its all-case acceptance/rejection proof is unavailable.

## Anti-pattern checklist

1. Dead code: **PASS** — the shared types remain exported and consumed through
   the public shared module; this finding adds no product surface.
2. Synthetic-fixture test: **FAIL** for integrated T024 evidence — the tests
   target the real frozen corpora and production parsers, but the canonical
   repository-root runner cannot reach those corpora at all.
3. Silent empty return: **PASS** — no silent empty/null production return is
   introduced by the reviewed WP05 changes.
4. FR coverage: **FAIL** transitively for FR-003 at the integrated boundary;
   both all-case fixture assertions abort during file discovery before testing
   the authoritative Zig values.
5. Frozen surface: **PASS** — WP05 changed only its owned shared source/test
   paths and did not modify the WP02 fixtures or WP04 build surface.
6. Locked decision: **PASS** — no float, FX, currency allowlist, invoice policy,
   or alternate wire representation is introduced.
7. Shared-file ownership: **PASS** — the required correction is wholly within
   WP05's exclusive `services/api/tests/shared/**` ownership.
8. Production fragility: **PASS** — the blocker is test fixture discovery, not
   a new production raise, panic, fallback, or transient-race path.

## Verdict

Return WP05 to `planned` for the single source-anchored fixture-reader
correction and deletion-sensitive two-root replay. Downstream WP08 must consume
the corrected WP05 test surface before its aggregate gate can be accepted.
