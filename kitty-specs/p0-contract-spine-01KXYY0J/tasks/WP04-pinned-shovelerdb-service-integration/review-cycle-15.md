---
affected_files:
- services/api/build.zig
- services/api/tests/persistence/shovelerdb_build_discovery.zig
blocking_findings: 0
cycle_number: 15
implementation_commit: 9b9b7d9de5c539895d0be0abc5f816c4a324a66d
red_commit: 5bca0ba1d149b51ee43310bf64fe8a9e8d3b5db4
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T07:48:53Z'
reviewer_agent: 'codex-wp04-cycle15:reviewer-renata'
verdict: approved
wp_id: WP04
---

# WP04 Review Cycle 15

Verdict: **APPROVE — all three cycle-13 HTTP build blockers are closed**

The permanent RED commit `5bca0ba` is the direct parent of product commit
`9b9b7d9`. Replaying `zig build test-build-discovery --summary all` at RED
produced exactly 16/19 passing tests and the intended three failures: the
stable inventory lacked `run`, an isolated HTTP root could not import
`shared`, and a delayed materializer lost the compile race for the embedded
route inventory. The same command at the reviewed lane tip passed 19/19.

## Independent correction evidence

- The HTTP and runtime roots receive only the named public `shared`,
  `persistence`, and `migrations` modules. Their adapter and three probe
  dependencies are constructed uninstrumented (`fuzz = false`) below that
  public graph. Independent compile negatives proved that HTTP roots cannot
  import `shovelerdb_adapter`, `shared_coverage_probe`,
  `persistence_coverage_probe`, or `migration_coverage_probe`; the stable step
  set contains no `coverage-http`.
- Static DAG inspection found one exact `npm run contracts:generate`
  materializer. Every discovered HTTP `Step.Compile` depends directly on it,
  and the `src/main.zig` executable compile does likewise. In a disposable
  producer fixture whose test and runtime roots embed files written after a
  900 ms delay, two cache/output-deleted `zig build test-http -j16 --summary
  all` replays each passed 6/6 steps and 1/1 test. The summary nested the npm
  run under the compile prerequisite.
- `run` is registered unconditionally. On the reviewed pre-WP08 lane,
  `zig build run --summary all` failed closed with the owning-WP08 missing
  `src/main.zig`/`src/http/**` diagnostic. In the producer fixture, `zig build
  run -- forwarded-token` compiled `src/main.zig` with the same three public
  modules and succeeded; `zig build run -- wrong-token` reached the executable
  and failed `WrongForwardedArgument`, independently proving `b.args`
  forwarding.
- Removing `src/platform/persistence/migrations.zig` from the fixture made
  `zig build test-http -j16 --summary all` fail before compilation with the
  named public-graph diagnostic. There is no partial or empty-success path.
- A proportional synthetic producer composition ran `test-shared`, all three
  persistence gates, and the migration unit/integration/negative gates in one
  invocation: 27/27 steps and 9/9 tests passed.
- `zig fmt --check`, the base Zig build, adapter Debug/ReleaseSafe (4/4 each),
  and real ABI integration Debug/ReleaseSafe (5/5 each) passed on Zig 0.16.0.
- The correction diff is limited to the two owned WP04 files above. Package
  manifests, `package-lock.json`, and `services/api/build.zig.zon` are
  byte-unchanged; no WP07 path is touched; `git diff --check` is clean.

## Contract round-trip

`contracts/p0-contract-manifest.json` is in scope only for its ownership of
`services/api/build.zig` and remains consistent. The common, API, event,
module, migration, and manifest schema examples are orthogonal to this
build-graph-only correction; none of their runtime payloads or closed value
sets changed. The plan's exact materializer and materialization-before-Zig-
compile decisions round-trip in the observed command/DAG evidence.

## Anti-pattern checklist

1. Dead code: **PASS** — both new build helpers have live production callers;
   `run` is consumed by the existing root `dev:api` command.
2. Synthetic-fixture test: **PASS** — the committed isolated tests execute the
   copied production `build.zig`; replay at RED proves they fail without the
   implementation.
3. Silent empty return: **PASS** — no swallowed or empty-success path was added.
4. FR coverage: **PASS** — FR-015's independent HTTP/service build surface is
   exercised through actual Zig compile and run commands.
5. Frozen surface: **PASS** — no frozen or package-metadata surface changed.
6. Locked decision: **PASS** — exact materialization ordering and fail-closed
   runnable-service decisions are implemented.
7. Shared-file ownership: **PASS** — `services/api/build.zig` is explicitly
   WP04-owned and the correction touches no WP07 path.
8. Production fragility: **PASS** — missing producers and incomplete public
   graphs fail deterministically with owner-specific diagnostics.

No blocking findings remain.
