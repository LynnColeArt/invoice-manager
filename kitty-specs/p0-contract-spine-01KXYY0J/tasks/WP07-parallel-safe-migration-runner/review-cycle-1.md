---
affected_files:
  - services/api/src/platform/persistence/migrations.zig
  - services/api/tests/persistence/migrations_integration_test.zig
  - services/api/tests/persistence/migrations_negative_test.zig
  - services/api/tests/persistence/migrations_coverage_test.zig
blocking_findings: 6
cycle_number: 1
implementation_commit: 64524c3b29333684b44cfca51e280c7a5c89e1a9
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-21T08:25:24Z'
reviewed_lane_tip: 6b5112ab6759d0d108cbf104b8152dac84dec8d7
reviewer_agent: 'codex:reviewer-renata'
verdict: rejected
wp_id: WP07
---

# WP07 Review Cycle 1 — REJECTED

Reviewed test commit `6d959bd`, implementation/bootstrap commit `64524c3`,
and approved WP04 composition at `6b5112a`. The action command subsequently
merged status-only coordination commits into the review workspace; no product
finding depends on those commits.

## Blocking findings

### B1 — durability completion can report Ready while planned migrations never ran

`applyPending` returns immediately when one migration's `startupWrite` reaches
a committed-but-not-durable boundary. It reports counts from before that
migration was acknowledged. `completeDurability` then completes only WP06's
persistence boundary and unconditionally constructs a Ready result from the
prior counts. It retains neither the validated plan nor a continuation index,
and it never resumes later migrations.

A temporary black-box reviewer regression created an exact bootstrap plus one
dependent migration, injected a checkpoint failure, cleared the fault, and
called `completeDurability`. The first call returned
`durability_unconfirmed` after exactly one DDL application. Completion then
returned `isReady() == true` with the application count still unchanged, while
`SELECT body FROM wp07_later` returned `QueryFailed` because the later table had
never been created. The correct assertion that completion must remain non-ready
failed:

```text
test-migration-integration
+- run test migration_integration-migrations_integration_test 5 pass, 1 fail
error: '...durability completion must not skip later planned migrations' failed
  migrations_integration_test.zig:436: try std.testing.expect(!completed.isReady());
```

This violates T034/T035, FR-009/FR-010, NFR-009, and the locked rule that
traffic readiness follows the complete migration set. It also makes
`applied_count` false after completion even for a one-migration root.

Required correction: preserve or reconstruct a validated continuation after
persistence-only completion, resume every still-pending descriptor without
replaying the committed migration, and return Ready only after the complete
plan is durable. Add permanent red-first cases for checkpoint, directory-sync,
and unsupported-sync failure on the first and a middle migration, asserting
DDL call order, counts, history, later schema, and no replay.

### B2 — exact critical tests manufacture caller-visible categories in test code

Several exact critical tests do not assert the category returned by the public
migration boundary. `completionFailure` validates only a generic
`durability_unconfirmed` status, then returns
`migrations.expectedError(category)` itself. `ddlFailure` catches the public
`DdlFailure` and manufactures `LaterMigrationBlocked`; `reopenFailure` catches
`ReopenFailure` and manufactures `RecoveryQuarantine`. The negative matrix
reuses the same helpers.

WP04's runner genuinely observes the matching production probe bits, but that
does not make these test-created errors caller-visible. A mutation that leaves
the probe hit intact while removing or changing `Readiness.category` remains
green. This fails the prompt's public-boundary, stable-result-category, and
anti-synthetic-fixture requirements.

Required correction: make every exact critical test assert the actual public
error or typed readiness/diagnostic category produced by `run` or
`completeDurability`. Do not return the expected category from a test helper.
Expose enough typed state to distinguish later-work blocking, quarantine,
Committed-not-durable, and Checkpointed-not-durable without inference from a
private probe.

### B3 — owner roots are not normalized, basename-bound, or component-safe

Discovery validates the caller-supplied `OwnerRoot.owner`, but never proves
that the normalized root basename is that owner. It concatenates the raw root
string into `source_path`, so lexical aliases such as `migrations/p0` and
`migrations/./p0` are not the same physical descriptor path and are diagnosed
only later as duplicate IDs. Opening the complete path with no-follow on the
final open and checking walker entries does not establish that every ancestor
component is non-symlink or that the opened directory remains beneath the
configured repository root.

This leaves T032's normalized repository-relative path, exact owner-directory
agreement, symlink-escape, and normalized duplicate-path rules unproved.

Required correction: normalize and validate each owner-root component, bind
the normalized basename to `owner`, open/verify components without following
symlinks (or prove canonical containment with an equivalent race-safe seam),
and key duplicate-path detection on normalized physical descriptor identity.
Add aliases, wrong owner basename, final/root symlink, and symlinked ancestor
cases through public discovery.

### B4 — any StatementObjectFailed can be mistaken for a fresh bootstrap store

When the applied-history query returns `StatementObjectFailed`, the runner
treats the store as fresh whenever the discovered set contains the exact
bootstrap descriptor. `hasExactBootstrap` proves descriptor identity only; it
does not prove that `app_schema_migrations` is absent or that storage is empty.
A nonempty or malformed history table whose shape makes the SELECT fail can
therefore enter bootstrap DDL, then surface as `DdlFailure`, instead of being
rejected as corrupt applied history before application.

Required correction: distinguish an explicitly absent bootstrap table from an
existing malformed/nonempty history object through the public persistence
seam. Add missing-column, wrong-object, malformed-schema, and nonempty-history
cases and prove they return stable corruption categories with zero migration
DDL and zero destructive replacement attempts.

### B5 — the DDL recovery test never creates a visible partial effect or checks the durable snapshot

The DDL fixture is only `CREATE TABLE broken (\n`, which can fail during parse
before any visible schema change. The test checks discard/reopen counters, but
does not assert that a successfully executed earlier DDL statement disappears,
that the failed migration has no applied-history row, that the durable file
matches the pre-run snapshot, or that later schema remains absent. This does
not satisfy T035's explicit partial-DDL recovery validation.

Required correction: use a multi-statement migration whose first DDL creates a
queryable object and whose later statement fails. After public discard/reopen,
prove the partial object and history row are absent, the pre-run durable schema
and bytes remain intact, no checkpoint acknowledged rejected state, and no
later migration ran.

### B6 — no-op and allocation-failure cleanup evidence is incomplete

The rerun test checks only aggregate counts. It does not use the observed-call
seam to require zero DDL, query and compare the immutable five-field history
row, or prove that `applied_at` was not rewritten. The allocation scenario
passes after observing any allocation failure; the broader coverage sweep also
accepts `CorruptAppliedHistory` during an OOM run and does not require every
injected failure point to retain a ready/recoverable store with exact handle
and directory cleanup.

Required correction: assert zero application calls and byte-for-byte unchanged
history on an identical rerun. Make allocator sweeps exhaustive across
discovery, planning, history materialization, and application setup; require
the stable allocation category where promised and assert no leaked allocation,
handle, directory descriptor, or poisoned store state at each injected point.

## Fresh passing evidence

- Exact bootstrap script: 119 bytes and
  `sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3`.
- Independent sorted canonical projection: 224 bytes without a trailing LF and
  `sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877`.
- Independent published vector: 295 bytes and
  `sha256:2e13316049752ad3eb2b249b89373bd30b540e00397b6010da571ba19032c021`.
- Debug unit, integration, mandatory negative, coverage-migration, aggregate
  coverage, formatting, and diff checks passed before the adversarial repro.
- ReleaseSafe unit, integration, negative, and coverage-migration gates passed
  from `services/api`.
- Exact measured migration coverage is genuinely 488/542 production PCs
  (90.04%), with 36 unique critical names, 36 unique production probe calls,
  36/36 critical tests, 37 tests passed, and zero skipped. Tests import only
  the public `migrations` module; no test imports or mutates the probe.
- Production imports only `shared`, `persistence`, and the mandated coverage
  probe. No raw adapter, ShovelerDB handle/result, down migration, reset,
  destructive repair, shared sequence, or registry path was found.
- Test commits precede product commit `64524c3`; the recorded RED chronology is
  corroborated by commit order.
- WP07 product/test commits stay inside owned files. The only outside change at
  the reviewed lane tip is the explicitly coordinated, approved WP04 build
  composition merge.

## Requirement and subtask verdicts

- T031: **PASS** — generic bootstrap only; exact digests and no down script.
- T032: **REJECTED** — root normalization, owner-basename binding, and full
  component symlink containment are incomplete.
- T033: **PASS with correction dependency** — deterministic Kahn planning,
  duplicate IDs/paths, missing/self edges, cycles, bounded graph, and sorted
  diagnostics pass current focused tests.
- T034: **REJECTED** — false Ready after persistence completion and incomplete
  no-op/history evidence.
- T035: **REJECTED** — continuation is lost and partial-DDL durable rollback is
  not demonstrated.
- T036 / NFR-006: **REJECTED despite honest 90.04% PC coverage** — exact probe
  execution passes, but several public-result assertions are synthetic and
  required behavioral cases remain missing.

## Anti-pattern checklist

1. Dead code: **N/A** — this is the explicit producer seam for dependent WP08.
2. Synthetic-fixture test: **FAIL** — several exact expected errors originate
   in test helpers rather than the public migration result.
3. Silent empty return: **PASS** — optional diagnostic lookup nulls and empty
   discovery are explicit contract states, not swallowed failures.
4. FR coverage: **FAIL** — FR-009/FR-010 readiness, path integrity, corrupt
   history, and recovery behavior have blocking gaps.
5. Frozen surface: **PASS** — WP07 did not edit WP03 schemas, WP04 build wiring,
   WP05 shared values, or WP06 persistence internals.
6. Locked decision: **FAIL** — Ready can precede the complete migration set,
   and root containment/owner agreement is not fully enforced.
7. Shared-file ownership: **PASS** — WP07 commits are owned; the WP04 merge is
   explicitly coordinated dependency composition.
8. Production fragility: **FAIL** — a recoverable checkpoint/sync fault can
   leave unapplied migrations behind while enabling traffic readiness.

The WP frontmatter still names `implementer-ivan` for a review action. Reviewer
Renata was loaded explicitly for this cycle; keep `implementer-ivan` on rollback
so the correction cycle resumes with the proper implementation profile.
