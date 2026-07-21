---
affected_files:
- services/api/build.zig
blocking_findings: 3
cycle_number: 13
implementation_commit: 69458f99517c8e431a5c4fccf1cbcd0fc7de6b64
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T07:23:03Z'
reviewed_lane_tip: 25cf951a24af910dde27402a0b6188fefe85649a
reviewer_agent: 'codex-wp04-http-readiness:reviewer-renata'
verdict: rejected
wp_id: WP04
---

# WP04 Review Cycle 13

Verdict: **REJECT — the published HTTP build seam cannot compile or run WP08 safely**

WP08 readiness exposed three build-graph defects in WP04's sole-owned
`services/api/build.zig`. They are bounded corrections to T016's promised HTTP
consumer surface; no HTTP application behavior belongs in this remediation.

## Blocking findings

### 1. HTTP compile roots do not receive the public service module graph

`configureHttp` creates only `shovelerdb_adapter` and passes that single import
to every discovered HTTP test root. A valid WP08 root importing the public
`shared`, `persistence`, or `migrations` modules therefore fails at compile
time, even though readiness is defined to consume the durable-store and
migration boundaries. The existing module factories also require their
coverage-probe dependencies, but the HTTP path does not instantiate those
probes as uninstrumented support modules.

Required correction: construct the existing uninstrumented shared,
persistence, and migrations module graph, including its uninstrumented probes,
and give every HTTP test compile root the same named public modules. Do not
expose probe modules as HTTP-root imports and do not add HTTP coverage here.

### 2. Route-inventory materialization is not a compile prerequisite

`test-http` depends independently on the materializer and on the final test-run
chain. This sibling topology allows Zig compilation to race
`npm run contracts:generate`; the aggregate step's dependency does not require
the generated route inventory to exist before each `std.Build.Step.Compile`
starts. The plan and T016 require materialization *before Zig HTTP compile*.

Required correction: make every HTTP test compile step depend directly on the
one exact repository-root materializer. Apply the same prerequisite to the
runtime executable compile step. A delayed materializer regression must prove
that compilation cannot begin early.

### 3. The stable runtime `run` surface is absent

`build()` publishes `test-http` but no `run` step or executable rooted at
`src/main.zig`. The Next.js `dev:api` consumer consequently has no stable Zig
service command to invoke, and the foundation cannot reach the spec's runnable
application-shell outcome.

Required correction: publish an unconditional, fail-closed `run` step. Before
WP08's producer exists it must fail with an owner-specific missing-producer
diagnostic. Once the producer exists, compile `src/main.zig` with the same
target, optimization, named public module graph, uninstrumented probes, and
materializer prerequisite as HTTP tests; forward `b.args` through
`addRunArtifact`.

## Required permanent RED evidence

Add public discovery regressions before production changes for:

1. the missing stable `run` step;
2. an isolated HTTP root that imports `shared`, `persistence`, and `migrations`;
3. a delayed materializer proving the compile step cannot race generated
   route-inventory creation.

Commit those tests while RED, then make only the build correction above. Also
run a synthetic runtime, module-removal negatives, Debug/ReleaseSafe adapter and
integration regression, and two clean-cache `-j16` HTTP replays.

## Anti-pattern checklist

1. Dead code: **FAIL** — WP08's runtime root has no published executable/run consumer.
2. Synthetic-fixture test: **FAIL** — current discovery assertions do not exercise a compiling HTTP consumer or materialization order.
3. Silent empty return: **PASS** — the issue is missing/wrong wiring, not swallowed failure.
4. FR coverage: **FAIL** — FR-015's separately runnable HTTP/service gate is incomplete.
5. Frozen surface: **PASS** — no frozen file finding.
6. Locked decision: **FAIL** — materialization-before-compile and runnable-shell decisions are not implemented.
7. Shared-file ownership: **PASS** — `services/api/build.zig` remains explicitly owned by WP04.
8. Production fragility: **FAIL** — sibling dependency ordering makes clean builds nondeterministic.

## Scope boundary

Correct only `services/api/build.zig` and WP04's existing build-discovery test
surface. Do not edit package metadata, add `coverage-http`, implement WP08
routes, or merge this lane into WP07's active lane.
