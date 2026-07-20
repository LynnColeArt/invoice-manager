---
affected_files:
  - contracts/events/v1/fixtures/runtime-catalog.json
  - contracts/events/v1/fixtures/runtime-events.jsonl
  - contracts/events/v1/payloads/p0/foundation-ready.schema.json
  - tools/contracts/src/conformance.ts
  - tools/contracts/src/event-conformance.ts
  - tools/contracts/src/events.ts
  - tools/contracts/src/fixtures.ts
  - tools/contracts/src/generate.ts
  - tools/contracts/src/json.ts
  - tools/contracts/src/lifecycle.ts
  - tools/contracts/src/main.ts
  - tools/contracts/src/migrations.ts
  - tools/contracts/src/modules.ts
  - tools/contracts/src/paths.ts
  - tools/contracts/src/real-conformance.ts
  - tools/contracts/src/registry.ts
  - tools/contracts/tests/conformance-generation.test.ts
  - tools/contracts/tests/lifecycle.test.ts
  - tools/contracts/tests/migrations.test.ts
  - tools/contracts/tests/path-security.test.ts
blocking_findings: 2
cycle_number: 2
implementation_commit: 563a8b8fd27c3b3595e9be874a5c95fe8fd926e8
mission_slug: p0-contract-spine-01KXYY0J
reviewed_at: '2026-07-20T21:32:50Z'
reviewed_lane_tip: cb7f9d0f1f841edad4d184f76a6b5661126dad8d
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: rejected
wp_id: WP03
---

# WP03 Review Cycle 2

Verdict: **REJECT**

Implementation commit: `563a8b8fd27c3b3595e9be874a5c95fe8fd926e8`.

The correction closes four of the five cycle-one defect classes and improves the
baseline-refresh orchestration. Two blocking gaps remain under T013 and the
fail-loud path/snapshot requirements.

## Blocking findings

### 1. The P1-P4 collision layer still substitutes fabricated adapters for actual downstream shapes and integration edges

`verifyConformanceLock` now verifies the exact four manifests, their dependency/input
edges, exact output bytes, stable schema IDs, and schema references. That is useful real
input validation. `buildValidatedBaselineRefreshCandidate` also runs `preflightContracts`
with the candidate lock before it upgrades the validation receipt, so the old false
`all-pins-and-fixtures-revalidated` shortcut is gone.

The concurrent collision matrix, however, is built by `buildRealOwnerSurface` from
uniform tool-authored substitutes. For every owner it invents a
`/conformance/pN` route, `PNConformance` operation, `pN-pinned-conformance` module,
`conformance.pN_snapshot` event, and owner-named component. The tests then mutate those
invented documents. Only the `$ref`/payload target is anchored to each real pinned output
schema. The exact pinned commits contain one domain/document schema apiece and Draft
manifest fixture paths, but no OpenAPI fragments, module contributions, or event catalogs;
all eight pinned integration-fixture paths are absent at those commits. Consequently the
new matrix does not exercise actual downstream route/event shapes or pinned integration
fixtures, despite T013's explicit requirement to exercise actual shapes and integration
edges and the review rule to reject toy-only substitution.

Required correction:

- distinguish exact pinned material from synthetic collision scaffolding in both code and
  evidence;
- exercise every real artifact that exists at the pins directly, including each manifest,
  dependency/input edge, complete output schema shape/reference graph, declared fixture
  edge, and migration strategy;
- do not claim real route/event collision evidence until immutable downstream artifacts
  exist; either provide an accepted contract-derived representation that preserves actual
  owner semantics or narrow/defer those cases explicitly through the mission contract; and
- retain the clean rerun and stable code/pointer assertions for each real mutation.

### 2. Declared directories and snapshot I/O failures bypass the stable, fail-loud path contract

`resolveRepositoryFile` proves containment but never proves that the resolved object is a
regular file. An independent reproduction supplied a module fragment path whose final
component was a directory. `composeModules` passed the path helper, then leaked Node's raw
filesystem error:

```text
DIRECTORY_NAME=Error
DIRECTORY_CODE=EISDIR
DIRECTORY_POINTER=undefined
```

This violates T008's stable machine-readable error-code and actionable JSON-Pointer rule
for every rejection. The same helper is used by lifecycle evidence, conformance-lock,
fixture, registry, migration, and CLI reads, so file-kind validation belongs in the
centralized boundary rather than in individual parsers.

Separately, `snapshotTree` still catches every `readdir` failure and returns silently.
With a prior generated directory made unreadable, the exported production snapshotter
reported an empty snapshot and omitted the existing output:

```text
SNAPSHOT_FILES=0
CAPTURED_PRIOR=false
```

`checkContracts` uses that snapshot for byte-identity comparison and rollback. Treating
permission/I/O failures as absence invalidates its all-or-nothing preservation evidence and
is the silent-empty-return anti-pattern. Only a true missing optional root may be treated as
empty; all other errors must fail loudly before generation or restoration.

Required correction:

- make the centralized read resolver require the expected file/directory kind and translate
  failures to a stable code and caller pointer;
- make snapshot absence explicit and limited to `ENOENT` at the optional snapshot root;
- propagate every permission, I/O, and nested traversal failure instead of returning an
  incomplete snapshot; and
- add focused directory-as-file and snapshot-error tests with stable diagnostics and exact
  prior-pair preservation assertions.

## Corrected cycle-one blockers verified

- **Symlink and encoding:** the prior external-fragment symlink now fails with
  `path_symlink_escape`; invalid schema bytes now fail with `utf8_invalid`. Declared JSON,
  YAML, conformance, registry, migration, fixture, and event reads use fatal UTF-8 decoding.
- **Paired publication:** all five injected points before, between, and after the two
  publications restore both prior outputs byte-for-byte. The old deterministic stale-backup
  collision reproduction now succeeds without loss (`TYPES_PRESENT=true`,
  `INVENTORY_PRESENT=true`).
- **Concrete Draft evidence:** a pending Draft remains valid; a concrete wrong content
  digest fails at `/content_digest`; a concrete missing output fails with `path_missing` at
  `/outputs/0/path`.
- **Live event validation:** canonical catalog and JSONL fixtures are called from
  `preflightContracts`. An isolated invocation of the focused `check` command with an invalid
  payload exits 3 and includes the nested `event_payload_invalid` diagnostic at
  `/data/status`, line 1.
- **Baseline refresh orchestration:** candidate construction now reuses the candidate lock in
  full preflight before emitting the expanded validation receipt. Exact P1-P4 manifest and
  content hashes still recompute correctly, and the lock remains unchanged.

## Verification evidence

- Toolchain: Node.js `24.18.0`, npm `11.16.0`, Zig `0.16.0`.
- Offline `npm ci`: pass, zero install/audit vulnerabilities.
- Strict TypeScript source-and-test compile: pass.
- Vitest: 6 files, 39 tests, all pass.
- `npm run verify:substrate`: pass.
- Literal `npm run contracts:generate` twice: pass with identical diagnostics and identical
  hashes for inventory, `index.ts`, and `types.gen.ts`.
- `npm run contracts:check`: pass.
- Independent P1 manifest recomputation matches
  `3f28ddb033e5259163671b34c8c64f6214c5524f0f941e4dc5d03c38485a7987` and content
  `73457636636187ff5537564a0f13ed29030d931746dbcc2740da3636cb2747f5`.
- `git diff --check b79af5c..HEAD`: pass.
- Generated outputs remain ignored and absent from `git ls-files`.
- All seven WP01 substrate hashes are unchanged before and after review.
- Substantive correction commit `563a8b8` changes only WP03-owned contracts/tooling/tests;
  the additional net-diff paths are Spec Kitty WP03 status/activity metadata.
- Charter selector `section:code-review-checklist` was unavailable; the full generated WP03
  review prompt and its anti-pattern checklist governed this review.

## Anti-pattern checklist

1. Dead code: **PASS** - event validation is now reachable from production preflight and the
   focused command.
2. Synthetic-fixture test: **FAIL** - real pins anchor schemas/manifests, but fabricated
   route/module/catalog adapters still substitute for the required actual downstream shapes.
3. Silent empty return: **FAIL** - `snapshotTree` suppresses every `readdir` failure.
4. FR coverage: **FAIL** - T013 real-input evidence and T014 fail-loud snapshot behavior remain
   incomplete as described above.
5. Frozen surface: **PASS** - substantive implementation changes remain inside WP03 ownership;
   WP01 manifests/lock are unchanged.
6. Locked decision: **FAIL** - toy-only real-owner claims and unstable directory-path errors
   contradict explicit MUST/MUST NOT review rules.
7. Shared-file ownership: **PASS** - no implementation path outside WP03 ownership changed;
   Spec Kitty status files are workflow metadata.
8. Production fragility: **FAIL** - incomplete snapshots can be compared or restored as if
   they were exact.

## Subtask disposition

- T008: **FAIL** - concrete Draft verification is fixed, but directory-as-file evidence leaks
  an unstable raw filesystem rejection.
- T009: **PASS** for the cycle-one escape/UTF-8 correction.
- T010: **PASS** - runtime event validation is live in focused preflight.
- T011: **PASS** for deterministic local composition; real-input evidence remains blocked by
  T013.
- T012: **FAIL** - paired publish rollback is fixed, but `snapshotTree` can silently omit prior
  outputs.
- T013: **FAIL** - exact pin and baseline-refresh validation pass; actual-shape/integration-edge
  collision evidence remains synthetic.
- T014: **FAIL** - the happy-path command passes and event validation is live, but snapshot I/O
  is not fail-loud.
