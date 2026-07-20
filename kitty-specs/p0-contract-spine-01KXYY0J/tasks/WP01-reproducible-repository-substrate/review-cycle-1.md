# WP01 Review Cycle 1

Verdict: changes requested.

## Blocking issues

**Issue 1 — dependency tree is not internally valid**

Under the pinned Node.js 24.18.0/npm 11.16.0 toolchain, `npm ci` succeeds and both full and production-only `npm audit --json` report zero vulnerabilities, but `npm ls --all` exits nonzero with `ELSPROBLEMS`:

```text
invalid: postcss@8.5.10 .../node_modules/postcss
```

The root override forces `postcss@8.5.10` while the locked graph records Next.js requesting exact `8.4.31` and Vite requesting `^8.5.17`; the forced version satisfies neither request. `verify:substrate` still reports success because it asserts that this override exists instead of detecting the invalid dependency tree.

Required correction:

- select and lock an exact public-registry dependency/override graph that satisfies every requested range;
- regenerate the sole root lock with npm 11.16.0;
- require `npm ls --all` to exit zero as well as retaining zero-vulnerability full and production audit results; and
- make `verify:substrate` reject an invalid dependency/peer tree rather than canonizing the broken override.

**Issue 2 — `persistence:integration` delegates to the unit/aggregate persistence hook**

The root command checks `services/api/tests/persistence/store_test.zig` and runs:

```text
zig build test-persistence --build-file services/api/build.zig
```

The stable WP04 surface provides the distinct `test-persistence-integration` hook, and WP06's integration producer is `durability_integration_test.zig`. The current root command can therefore succeed without exercising the required integration boundary.

Required correction: preflight the actual WP06 integration producer and delegate to exact `zig build test-persistence-integration --build-file services/api/build.zig`, preserving the child exit status.

**Issue 3 — `bootstrap:foundation` schedules the same-origin smoke twice**

`verify:foundation` already includes `npm run http:smoke`, but `bootstrap:foundation` runs `verify:foundation` and then schedules a second `http:smoke` stage. The WP contract requires the timed first-run boundary to include one valid production same-origin health smoke.

Required correction: structure the bootstrap stages so install, complete validation, production startup/readiness, and exactly one complete same-origin response-body smoke remain inside the monotonic boundary without duplicate startup/smoke execution.

## Subtask disposition

- T001: PASS — exact Node/npm/Zig, Linux, and x64 policy plus actionable wrong-version/missing-Zig diagnostics verified.
- T002: FAIL — clean/offline installs and immutable hashes pass, but the installed dependency tree is invalid.
- T003: FAIL — missing-producer diagnostics and migration delegation pass; persistence delegation and bootstrap smoke cardinality do not.
- T004: FAIL — repeated install/hash and audit evidence pass, but the required complete-graph validation misses `npm ls` failure.

## Anti-pattern checklist

1. Dead code: N/A — no public source module was added.
2. Synthetic-fixture test: N/A — the WP is restricted to executable metadata checks.
3. Silent empty return: PASS — no silent empty-return path was introduced.
4. FR coverage: FAIL — FR-015's stable focused command surface is not satisfied by the incorrect persistence integration delegation.
5. Frozen surface: PASS — the lane diff contains exactly the seven WP01-owned paths.
6. Locked decision: FAIL — the immutable graph is invalid and the one-smoke bootstrap contract is contradicted.
7. Shared-file ownership: PASS — lane-a is exclusive and no out-of-map implementation file changed.
8. Production fragility: N/A — validation failures are deliberate fail-loud metadata gates, not request/worker code.

## Passing evidence retained

- Exact owned-file boundary and `git diff --check`: pass.
- `npm ci` under Node 24.18.0/npm 11.16.0: pass, 496 packages, zero audit findings.
- Second `npm ci --offline`: pass; all seven metadata hashes remain byte-identical.
- Full and `--omit=dev` audits: zero findings.
- Wrong Node, missing Zig, missing WP03 generator, missing WP04 migration hook, and first aggregate missing producer: actionable nonzero diagnostics.
- `verify:foundation:clean` and `bootstrap:foundation`: monotonic timing and first child failure propagation observed on the current missing-WP03 path.
- Lifecycle-script policy: `strict-allow-scripts=true`; the explicit allow/deny policy permits the clean install.

The requested charter section fetch `spec-kitty charter context --include section:code-review-checklist` returned no matching section; the generated review prompt's embedded gates and project action context were applied instead.
