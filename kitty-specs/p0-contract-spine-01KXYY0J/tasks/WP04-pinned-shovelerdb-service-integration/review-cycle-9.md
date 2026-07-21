---
affected_files:
  - path: services/api/src/platform/persistence/shovelerdb.zig
  - path: services/api/tests/persistence/shovelerdb_integration.zig
blocking_findings: 0
cycle_number: 9
implementation_commit: 69458f99517c8e431a5c4fccf1cbcd0fc7de6b64
mission_slug: p0-contract-spine-01KXYY0J
red_commit: 0c320989cbe2f697151eab28027e6855e599bcee
reviewed_at: '2026-07-21T04:39:00Z'
reviewed_lane_tip: 0eb4bfe8b674472c29d1750b018deceecbee438b
reviewer_agent: 'codex:gpt-5:reviewer-renata:reviewer'
verdict: approved
wp_id: WP04
---

# WP04 Review Cycle 9

Verdict: **APPROVE**

Cycle-eight correction commits `0c32098` and `69458f9` close the runtime
statement capability blocker in `review-cycle-8.md`. No blocking finding
remains.

## Chronology and deletion proof

- The cycle-eight rejection was committed before implementation. Commit
  `0c32098` then adds only the public-adapter integration tests and chronological
  RED log entry; its parent still has neither `executeBound` nor
  `executeScript`. Commit `69458f9` is its direct child and adds production.
- A clean archive of `0c32098` failed
  `zig build test-shovelerdb-integration --summary all` at both committed calls:
  `Adapter.executeBound` and `Adapter.executeScript` did not exist. This is a
  real test-only RED, not reconstructed evidence.
- `83a6d20` records the post-GREEN clean-source verification, and `0eb4bfe`
  removes lane planning artifacts after production. The required order is
  rejection -> RED test -> production -> GREEN verification -> cleanup.

## Runtime statement boundary

- `executeBound` accepts only compile-time fragments, requires exactly one more
  fragment than values, prevalidates NUL in every fragment and value, and sends
  each value through the existing single-quote encoder. A reviewer compile
  negative using a runtime fragment failed with `argument to comptime parameter
  must be comptime-known`.
- The real ABI integration round-trips five independent values byte-for-byte:
  canonical ID, apostrophe, empty text, injection-shaped digest, and
  newline-bearing UTC text. Arity, NUL, and allocation errors occur before an
  engine mutation; the handle remains usable.
- A reviewer-only exhaustive `checkAllAllocationFailures` probe passed every
  `executeBound` allocation site, reported no leaks, and left exactly the one
  successful control insertion. A bound SELECT remained valid after the
  adapter was closed, proving the returned columns and values are owned copies.
- `executeScript` copies one NUL-free byte sequence into sentinel form without
  trim, newline conversion, splitting, or identifier construction. The real
  engine accepts one statement with leading/trailing CR/LF/tab/space, rejects a
  second statement before creating the first table, rejects NUL, survives
  allocation failure, and remains usable.
- Legacy `execute`, `executeText`, transaction, checkpoint, close/reopen,
  diagnostic, and owned-result behavior remains live. `executeText` now
  delegates to the same bound-value path without changing its public contract.
- No new signature contains a C handle, C result, runtime fragment, or dynamic
  identifier. Current WP06 production consumers call both capabilities through
  its application-neutral persistence facade.

## Independent build, ABI, coverage, and provenance evidence

- Zig `0.16.0` clean archives pass the base ABI build, adapter 4/4 and real ABI
  integration 5/5 in Debug and ReleaseSafe, plus discovery 17/17. The linked
  archive exports real `shovelerdb_execute`, `shovelerdb_open_or_create`,
  `shovelerdb_checkpoint`, and `shovelerdb_result_release` symbols.
- The accepted coverage build and runner files are byte-unchanged from
  `40d6661` through `69458f9`. A realistic WP06 producer with the final runner
  passed 42/42 tests, measured 185/205 WP06-owned PCs (90.24%), and passed
  20/20 probes. Removing only adapter `.fuzz = false` failed before ratio at
  `shovelerdb.zig` with stable `coverage-persistence`, owning `WP06`, expected
  source pattern, and `OutOfScopeCoverageSite` fields. The diagnostic contained
  no absolute path, raw address, or source trace.
- Public GitHub `main` and the fetched detached revision both resolve exactly
  `021e3b3d9247a181252329d6ba7ec8d2ed943a97`. Public and vendored export digests
  both equal `6bb2b4215aa50a8ffbbff3278aea4f32c4fc0f906da817037c44095cfd19480b`.
  LICENSE and header hashes remain `240a15a...` and `177535ee...`; the exported
  payload is byte-identical, with no symlink, nested Git state, sibling path,
  private registry, or floating revision.
- Both implementation commits pass `git show --check`; cycle-eight changes do
  not modify the vendored source, build registry, coverage runners, notice,
  license, root package files, domain records, schema, routes, or migration
  implementation.

## Contract round-trip disposition

- `p0-contract-manifest.json`: **PASS** - both changed production/test paths are
  inside the declared P0 persistence ownership surface.
- `README.md`, `api-v1.openapi.yaml`, `common-v1.schema.json`,
  `contract-manifest-v1.schema.json`, `event-catalog-v1.schema.json`,
  `event-envelope-v1.schema.json`, `governed-doc-sync-v1.schema.json`,
  `migration-manifest-v1.schema.json`, and
  `module-contribution-v1.schema.json`: **ORTHOGONAL** - no wire shape, closed
  vocabulary, event, migration descriptor, CLI, or documentation receipt is
  changed by this adapter correction.

## Subtask disposition

- T015: **PASS** - exact public pin and deterministic export remain intact.
- T016: **PASS** - stable build/discovery and accepted ownership/privacy gates
  remain unchanged and independently green.
- T017: **PASS** - bound values and the one-statement startup seam preserve the
  narrow borrow-safe adapter, centralized encoding, and stable errors.
- T018: **PASS** - clean Debug/ReleaseSafe real-ABI tests exercise the new paths,
  owned copies, failure cleanup, and continued handle use.
- T019: **PASS** - full GPL-2.0 license and third-party notice remain unchanged.

## Anti-pattern checklist

1. Dead code: **PASS** - `executeBound` serves legacy `executeText` and both new
   operations have live WP06 production callers.
2. Synthetic-fixture test: **PASS** - tests call the real adapter and pinned C
   ABI against filesystem databases; deleting production reproduces RED.
3. Silent empty return: **PASS** - no empty-success or swallowed-error path was
   introduced.
4. FR coverage: **PASS** - FR-011, FR-012, FR-015 and the associated pin, ABI,
   ownership, reproducibility, and coverage constraints retain executable proof.
5. Frozen surface: **PASS** - production changes are confined to the WP04-owned
   adapter; tests are in the WP04-owned persistence integration surface.
6. Locked decision: **PASS** - identifiers/fragments remain compile-time,
   runtime values are quoted centrally, scripts stay one-statement, and no raw
   dependency detail crosses the downstream facade.
7. Shared-file ownership: **PASS** - no shared implementation file changed; the
   WP06 callers are downstream consumption evidence only.
8. Production fragility: **PASS** - typed preflight errors occur before engine
   execution, and no request/worker fallback or bare transient raise was added.
